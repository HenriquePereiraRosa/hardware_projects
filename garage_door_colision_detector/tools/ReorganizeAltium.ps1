param([switch]$Apply, [switch]$TestRollback)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$altium = Join-Path $taskRoot 'hardware\altium'
$archiveRel = 'hardware\altium\deprecated\2026-09-10-folder-reorganization'
$archive = Join-Path $taskRoot $archiveRel
function Resolve-InProject([string]$rel) {
    $p = [IO.Path]::GetFullPath((Join-Path $taskRoot $rel))
    if (-not $p.StartsWith($taskRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Outside project: $p" }
    return $p
}
$plan = [Collections.Generic.List[object]]::new()
function Plan-Move([string]$source,[string]$target) {
    $src = Resolve-InProject $source; $dst = Resolve-InProject $target
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing source: $src" }
    if (Test-Path -LiteralPath $dst) { throw "Destination exists: $dst" }
    $plan.Add([pscustomobject]@{source=$source; target=$target; sha256=(Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash})
}
$sheets = @('00_Mounting_Overview.SchDoc','01_Power_Control.SchDoc','02_Beam_Inputs.SchDoc','03_UI_Outputs.SchDoc','04_Optical_Heads.SchDoc','05_Installation.SchDoc')
foreach ($n in $sheets) { Plan-Move "hardware\altium\$n" "hardware\altium\sch\$n" }
Plan-Move 'hardware\altium\GarageBeamSafety.PcbDoc' 'hardware\altium\pcb\GarageBeamSafety.PcbDoc'
Plan-Move 'hardware\altium\GarageBeamSafety.BomDoc' 'hardware\altium\bom\GarageBeamSafety.BomDoc'
Plan-Move 'hardware\altium\GarageBeamSafety.SchDoc' "$archiveRel\unused-documents\GarageBeamSafety.SchDoc"
Plan-Move 'hardware\altium\GarageBeamSafety.PrjPcbStructure' "$archiveRel\cache\GarageBeamSafety.PrjPcbStructure"
Plan-Move 'hardware\altium\README.md' "$archiveRel\guides\altium-README.md"
Plan-Move 'README.md' "$archiveRel\guides\root-README.md"
Plan-Move 'hardware\altium\ALTIUM_QUICK_REFERENCE.md' "$archiveRel\guides\ALTIUM_QUICK_REFERENCE.md"
foreach ($n in @('ALTIUM_QUICK_REFERENCE.html','SCHEMATIC_REPAIR_STATUS.html')) { Plan-Move "hardware\altium\$n" "docs\$n" }
foreach ($f in Get-ChildItem -LiteralPath $altium -File) {
    if ($f.Extension -in @('.txt','.log','.png','.pdf')) { Plan-Move "hardware\altium\$($f.Name)" "output\altium-reports\before-folder-reorganization\$($f.Name)" }
}
# Preserve old generators and the deferred capacitor repair together; do not
# silently adapt obsolete circuit-generating scripts to the live project.
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $altium 'scripts') -File) {
    Plan-Move "hardware\altium\scripts\$($f.Name)" "$archiveRel\legacy-scripts\$($f.Name)"
}
$latin = [Text.Encoding]::GetEncoding(28591)
function Read-Text([string]$rel) { return $latin.GetString([IO.File]::ReadAllBytes((Resolve-InProject $rel))) }
# Prepare every text edit in memory. Nothing is changed during preflight.
$drafts = @{}
function Write-Text([string]$rel,[string]$value) { $drafts[$rel] = $value }
$oldRoot = 'C:\dev\projects\h\garage_door_colision_detector'
$prj = Read-Text 'hardware\altium\GarageBeamSafety.PrjPcb'
$job = Read-Text 'hardware\altium\GarageBeamSafety.OutJob'
$prj = $prj.Replace($oldRoot,$taskRoot)
$job = $job.Replace($oldRoot,$taskRoot)
foreach ($n in $sheets) { $prj = $prj.Replace("DocumentPath=$n","DocumentPath=sch\$n") }
foreach ($n in @('GarageBeamSafety.PcbDoc','GarageBeamSafety.BomDoc')) {
    $dir = if ($n.EndsWith('.PcbDoc')) {'pcb'} else {'bom'}
    $prj = $prj.Replace("DocumentPath=$n","DocumentPath=$dir\$n").Replace("$altium\$n","$altium\$dir\$n")
    $job = $job.Replace("$altium\$n","$altium\$dir\$n")
}
$job = $job.Replace('OutputDocumentPath2=GarageBeamSafety.PcbDoc','OutputDocumentPath2=pcb\GarageBeamSafety.PcbDoc')
# Remove the retired carrier print task, retaining its original in the backup;
# renumber the following BOM task to keep the output sequence contiguous.
$job = [regex]::Replace($job,'(?ms)^OutputType3=PCB Print\r?\n.*?(?=^OutputType4=)','')
$job = [regex]::Replace($job,'(?m)^(OutputType|OutputName|OutputCategory|OutputDocumentPath|OutputVariantName|OutputEnabled|OutputDefault|PageOptions|Configuration)4(?==|_)','${1}3')
$job = $job.Replace('OutputDocumentPath3=GarageBeamSafety.BomDoc','OutputDocumentPath3=bom\GarageBeamSafety.BomDoc').Replace('OutputEnabled3_OutputMedium2=4','OutputEnabled3_OutputMedium2=3')
$drawings = Join-Path $taskRoot 'hardware\manufacturing\drawings'
foreach ($key in @('OutputFilePath2','OutputBasePath2','RelativeOutputPath2')) { $job = [regex]::Replace($job,"(?m)^$key=.*$", "$key=$drawings") }
if ($job.Contains('ReflectorCarrier') -or $job.Contains($oldRoot)) { throw 'Stale OutJob references remain.' }
Write-Text 'hardware\altium\GarageBeamSafety.PrjPcb' $prj
Write-Text 'hardware\altium\GarageBeamSafety.OutJob' $job
$pas = Read-Text 'hardware\altium\scripts\PCBFirstPass\PCBFirstPass.pas'
foreach ($n in $sheets) { $pas = $pas.Replace("'$n'","'sch\$n'") }
$pas = $pas.Replace("'GarageBeamSafety.PcbDoc'","'pcb\GarageBeamSafety.PcbDoc'")
Write-Text 'hardware\altium\scripts\PCBFirstPass\PCBFirstPass.pas' $pas
$guide = Read-Text 'docs\RUN_PCB_FIRST_PASS.html'
$guide = $guide.Replace('<h2>Validation status</h2>', '<h2>Folder reorganization</h2><p>10 September 2026: active schematics now live in hardware/altium/sch, the PCB in pcb, and ActiveBOM in bom. This script has been updated for those locations. Old scripts were archived; do not run them. <a href="PROJECT_LAYOUT.html">Current folder guide</a>.</p><h2>Validation status</h2>')
$guide = [regex]::Replace($guide,'(?s)<h2>Validation status</h2><p>.*?</p>','<h2>Validation status</h2><p>The user successfully ran the original package in Altium on 10 September 2026 at 19:36:21. Both GPIO34/35 corrections were saved; 50 PCB components were audited read-only. The folder-adjusted package has passed static checks but has not been rerun natively. Full ERC, PCB grouping and model corrections remain pending.</p>')
Write-Text 'docs\RUN_PCB_FIRST_PASS.html' $guide
$decisions = Read-Text 'docs\DESIGN_DECISIONS.html'
$decisions = $decisions.Replace('</body>','<h2>10 September 2026 - physical folder organization</h2><p>User approved real disk folders and confirmed Altium closed. Six active SchDoc files moved together to sch; the single PcbDoc to pcb; ActiveBOM to bom. Libraries and 3D source folders retained. Old scripts and unused standalone schematic archived, not deleted. Project and output paths updated; retired carrier print removed. No native CAD binary content changed. Existing stale library source paths are separately reported, not silently rewritten. See <a href="PROJECT_LAYOUT.html">folder guide</a>. This entry supersedes older file-location and two-PCB-document descriptions above.</p></body>')
Write-Text 'docs\DESIGN_DECISIONS.html' $decisions
$ignore = Read-Text '.gitignore'
Write-Text '.gitignore' ($ignore + "`r`n# Altium per-document caches after physical folder organization.`r`n**/History/`r`n**/__Previews/`r`n")
# Rebase links in all current HTML guides to moved documents/reports. Archived
# scripts and historical text snapshots are intentionally not modernized.
$movesByFullPath = @{}
foreach ($m in $plan) { $movesByFullPath[(Resolve-InProject $m.source)] = (Resolve-InProject $m.target) }
$htmlSources = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'docs') -File -Filter '*.html') +
    @(Get-Item -LiteralPath (Join-Path $altium 'ALTIUM_QUICK_REFERENCE.html')) +
    @(Get-Item -LiteralPath (Join-Path $altium 'SCHEMATIC_REPAIR_STATUS.html'))
$linkFixCount = 0
foreach ($f in $htmlSources) {
    $src = $f.FullName
    $dst = if ($movesByFullPath.ContainsKey($src)) { $movesByFullPath[$src] } else { $src }
    $rel = [IO.Path]::GetRelativePath($taskRoot,$dst)
    $old = if ($drafts.ContainsKey($rel)) { $drafts[$rel] } else { $latin.GetString([IO.File]::ReadAllBytes($src)) }
    $new = [regex]::Replace($old,'(?i)(href|src)="([^"#]+)(#[^"]*)?"', {
        param($match)
        $url = $match.Groups[2].Value
        if ($url -match '^[a-z][a-z0-9+.-]*:' -or $url.StartsWith('//')) { return $match.Value }
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $src) ([Uri]::UnescapeDataString($url))))
        if ($movesByFullPath.ContainsKey($target)) { $target = $movesByFullPath[$target] }
        if ($dst -eq $src -and -not $movesByFullPath.ContainsValue($target)) { return $match.Value }
        $rebase = [IO.Path]::GetRelativePath((Split-Path $dst),$target).Replace('\','/')
        return $match.Groups[1].Value + '="' + $rebase + $match.Groups[3].Value + '"'
    })
    if ($new -cne $old) { $linkFixCount++; Write-Text $rel $new }
}
# All six active sheet-symbol targets must resolve in the new sibling folder.
foreach ($n in $sheets) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $altium $n))
    $text = $latin.GetString($bytes)
    foreach ($m in [regex]::Matches($text,'\|RECORD=33\|[^\x00]*?\|Text=([^|\x00-\x1f]+\.SchDoc)(?=\||\x00)')) {
        if ($sheets -notcontains $m.Groups[1].Value) { throw "Unresolved sheet reference: $($m.Groups[1].Value)" }
    }
}
# Validate staged project paths against either planned targets or existing files.
$targets = @($plan | ForEach-Object { Resolve-InProject $_.target })
foreach ($match in [regex]::Matches($prj,'(?m)^DocumentPath=([^\r\n]+)')) {
    $target = Join-Path $altium $match.Groups[1].Value
    if ($target -notin $targets -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Project document missing: $target" }
}
$plan | ForEach-Object { Write-Output "$($_.source) -> $($_.target)" }
Write-Output "PREFLIGHT PASS: $($plan.Count) relocations, $($drafts.Count) text drafts, $linkFixCount HTML link updates."
if (-not $Apply) { Write-Output 'DRY RUN: no files changed.'; exit 0 }
if (Get-Process X2 -ErrorAction SilentlyContinue) { throw 'Close Altium before applying this migration.' }
if (Test-Path -LiteralPath $archive) { throw "Archive already exists; do not rerun: $archive" }
New-Item -ItemType Directory -Path $archive | Out-Null
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $archive 'move-manifest.json') -Encoding utf8
$before = @{}
# All edited originals have a byte-for-byte backup. All moved originals remain
# in place until the staged files and the live project references pass checks.
foreach ($rel in $drafts.Keys) {
    $src = Resolve-InProject $rel
    if (-not (Test-Path -LiteralPath $src)) {
        $item = $plan | Where-Object target -EQ $rel
        $src = Resolve-InProject $item.source
    }
    $backup = Resolve-InProject "$archiveRel\before\$rel"
    New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $backup
    if ((Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) { throw "Backup failure: $rel" }
    $before[$rel] = $backup
}
$created = [Collections.Generic.List[object]]::new()
$edited = [Collections.Generic.List[string]]::new()
$retired = [Collections.Generic.List[object]]::new()
try {
    # Phase 1: copy only. All original files remain usable at the original paths.
    foreach ($m in $plan) {
        $src = Resolve-InProject $m.source; $dst = Resolve-InProject $m.target
        if ((Get-FileHash -LiteralPath $src).Hash -ne $m.sha256) { throw "Source changed: $src" }
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        $created.Add($m)
        Copy-Item -LiteralPath $src -Destination $dst
        if ((Get-FileHash -LiteralPath $dst).Hash -ne $m.sha256) { throw "Copy hash mismatch: $dst" }
    }
    # Phase 2: apply prepared text edits. Native CAD files are never rewritten.
    foreach ($rel in $drafts.Keys) {
        $edited.Add($rel)
        [IO.File]::WriteAllBytes((Resolve-InProject $rel),$latin.GetBytes($drafts[$rel]))
    }
    foreach ($match in [regex]::Matches($prj,'(?m)^DocumentPath=([^\r\n]+)')) {
        if (-not (Test-Path -LiteralPath (Join-Path $altium $match.Groups[1].Value) -PathType Leaf)) { throw 'Live project target missing.' }
    }
    foreach ($m in $plan | Where-Object source -Match '\.(SchDoc|PcbDoc|BomDoc)$') {
        if ((Get-FileHash -LiteralPath (Resolve-InProject $m.target)).Hash -ne $m.sha256) { throw 'Native content changed.' }
    }
    # Phase 3: archive originals only after the new project resolves completely.
    foreach ($m in $plan) {
        $src = Resolve-InProject $m.source
        if ((Get-FileHash -LiteralPath $src).Hash -ne $m.sha256) { throw "Source changed during migration: $src" }
        $retirePath = Resolve-InProject "$archiveRel\originals\$($m.source)"
        New-Item -ItemType Directory -Path (Split-Path $retirePath) -Force | Out-Null
        Move-Item -LiteralPath $src -Destination $retirePath
        $retired.Add([pscustomobject]@{source=$src; backup=$retirePath})
        if ($TestRollback) { throw 'Intentional recovery test after first retirement.' }
    }
    foreach ($dir in @('gerbers','drill','pick-place','bom','drawings')) { New-Item -ItemType Directory -Path (Resolve-InProject "hardware\manufacturing\$dir") -Force | Out-Null }
    'COMPLETE: staged copies, hashes and project references verified; originals archived.' | Set-Content -LiteralPath (Join-Path $archive 'status.txt') -Encoding utf8
    Write-Output "SUCCESS: $($plan.Count) files reorganized; native CAD hashes unchanged."
    Write-Output "Recovery copies and manifest: $archive"
} catch {
    $failure = $_
    # Restore original locations and text. Keep failed staging for inspection;
    # never recursively delete files or overwrite a changed user document.
    foreach ($r in $retired) { Move-Item -LiteralPath $r.backup -Destination $r.source }
    foreach ($rel in $edited) {
        if ((Resolve-InProject $rel) -notin $targets) { Copy-Item -LiteralPath $before[$rel] -Destination (Resolve-InProject $rel) -Force }
    }
    foreach ($m in $created) {
        $dst = Resolve-InProject $m.target
        if (Test-Path -LiteralPath $dst) {
            $failed = Resolve-InProject "$archiveRel\failed-staging\$($m.target)"
            New-Item -ItemType Directory -Path (Split-Path $failed) -Force | Out-Null
            Move-Item -LiteralPath $dst -Destination $failed
        }
    }
    "ROLLED BACK: $failure" | Set-Content -LiteralPath (Join-Path $archive 'status.txt') -Encoding utf8
    throw $failure
}

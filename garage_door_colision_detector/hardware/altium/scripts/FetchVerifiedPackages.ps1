$ErrorActionPreference = 'Stop'
$destination = Join-Path $PSScriptRoot '../lib/upstream-kicad'
$assets = @(
    @('Resistor_SMD','R_0805_2012Metric'),
    @('Capacitor_SMD','C_0805_2012Metric'),
    @('Diode_SMD','D_SOD-123'),
    @('Package_DIP','DIP-4_W7.62mm_SMD')
)
foreach ($item in $assets) {
    foreach ($kind in @('footprints','packages3D')) {
        $suffix = if ($kind -eq 'footprints') { '.pretty' } else { '.3dshapes' }
        $extension = if ($kind -eq 'footprints') { '.kicad_mod' } else { '.step' }
        $url = 'https://raw.githubusercontent.com/KiCad/kicad-' + $kind + '/master/' + $item[0] + $suffix + '/' + $item[1] + $extension
        $target = Join-Path $destination ($item[1] + $extension)
        Invoke-WebRequest -Uri $url -OutFile $target
        Get-FileHash -LiteralPath $target -Algorithm SHA256 | Select-Object Path, Hash
    }
}

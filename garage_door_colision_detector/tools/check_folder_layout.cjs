// Read-only CAD inspection; --report writes only a generated JSON report.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const base = path.join(root, 'hardware/altium');
const read = p => fs.readFileSync(p, 'latin1');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
const project = read(path.join(base, 'GarageBeamSafety.PrjPcb'));
const job = read(path.join(base, 'GarageBeamSafety.OutJob'));
const documents = [...project.matchAll(/^DocumentPath=([^\r\n]+)/gm)].map(m => m[1]);
assert.equal(documents.length, 15);
for (const d of documents) assert(fs.existsSync(path.join(base, d)), `Missing project file ${d}`);
assert.equal(documents.filter(d => /\.PcbDoc$/i.test(d)).length, 1);
const archive = path.join(base, 'deprecated/2026-09-10-folder-reorganization');
const manifest = JSON.parse(fs.readFileSync(path.join(archive, 'move-manifest.json'), 'utf8').replace(/^\uFEFF/, ''));
const nativeHashes = [];
for (const m of manifest.filter(m => /\.(SchDoc|PcbDoc|BomDoc)$/i.test(m.source))) {
  assert.equal(hash(path.join(root, m.target)), m.sha256, `Native file changed: ${m.target}`);
  assert.equal(hash(path.join(archive, 'originals', m.source)), m.sha256);
  assert(!fs.existsSync(path.join(root, m.source)), `Old active path still exists: ${m.source}`);
  nativeHashes.push({file:m.target, sha256:m.sha256});
}
const sheetLinks = [];
const preExistingLibraryPaths = [];
for (const d of documents.filter(d => /\.(SchDoc|PcbDoc)$/i.test(d))) {
  const text = read(path.join(base, d));
  for (const m of text.matchAll(/\|RECORD=33\|[^\x00]*?\|Text=([^|\x00]+\.SchDoc)(?=\||\x00)/g)) {
    assert(fs.existsSync(path.join(path.dirname(path.join(base,d)),m[1])), `Missing child sheet ${m[1]}`);
    sheetLinks.push({parent:d, child:m[1]});
  }
  const seen = new Set();
  for (const m of text.matchAll(/\|(SourceLibraryName|ModelDatafile\d+|SOURCEFOOTPRINTLIBRARY|SOURCECOMPONENTLIBRARY|SOURCECOMPLIBRARYIDENTIFIER)=([^|\x00\r\n]+)/gi)) {
    const p = m[2];
    if (/^[A-Z]:\\/i.test(p) && !fs.existsSync(p) && !seen.has(p)) {
      seen.add(p); preExistingLibraryPaths.push({document:d, field:m[1], path:p});
    }
  }
}
assert.equal(sheetLinks.length,5);
assert(!job.includes('ReflectorCarrier'));
assert(!job.includes('C:\\dev\\projects\\h\\garage_door_colision_detector\\'));
const outputTypes = [...job.matchAll(/^OutputType(\d+)=/gm)].map(m=>Number(m[1]));
assert.deepEqual(outputTypes,[1,2,3]);
for (const m of job.matchAll(/^OutputDocumentPath\d+=([^\r\n]+)/gm)) {
  if (!m[1].startsWith('[')) assert(fs.existsSync(path.join(base,m[1])), `Missing output source ${m[1]}`);
}
for (const text of [project,job]) for (const m of text.matchAll(/\|DocumentPath=([^|\r\n]+)/g)) {
  if (m[1]) assert(fs.existsSync(path.resolve(base,m[1])), `Missing print reference ${m[1]}`);
}
for (const rel of ['README.html','docs/PROJECT_LAYOUT.html','docs/RUN_PCB_FIRST_PASS.html']) {
  for (const m of read(path.join(root,rel)).matchAll(/(?:href|src)="([^"#]+)(?:#[^"]*)?"/g)) {
    if (/^[a-z]+:/i.test(m[1])) continue;
    if (m[1].endsWith('folder-layout-check.json')) continue; // report is written below
    assert(fs.existsSync(path.resolve(path.dirname(path.join(root,rel)),decodeURIComponent(m[1]))),`Missing guide link ${rel}: ${m[1]}`);
  }
}
const report = {checkedAt:new Date().toISOString(),folderChecks:'PASS',nativeAltiumReopen:'PENDING',projectDocuments:documents,nativeHashes,sheetLinks,outputTypes,preExistingLibraryPaths,
  limits:['Raw saved-field scan, not a full Altium compiler/library-resolution check.','Circuit contents unchanged. Existing library links still require native review.','No routing, ECO, ERC or 3D repair performed.']};
if (process.argv.includes('--report')) fs.writeFileSync(path.join(root,'output/altium-reports/folder-layout-check.json'),JSON.stringify(report,null,2)+'\n');
console.log(`PASS: ${documents.length} document paths; ${nativeHashes.length} native hashes; ${sheetLinks.length} sheet links; output references and current guide links.`);
console.log(`REVIEW: ${preExistingLibraryPaths.length} pre-existing unavailable absolute library paths. Native Altium reopen pending.`);

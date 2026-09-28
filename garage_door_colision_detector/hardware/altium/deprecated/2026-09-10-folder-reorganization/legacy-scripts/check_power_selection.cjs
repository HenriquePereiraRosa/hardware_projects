// Read-only regression checks. Does not certify ratings, footprints or Altium ERC.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(__dirname, 'RebuildRealSchematics.pas'), 'utf8');
const audit = fs.readFileSync(path.join(root, '01_Power_Control.SchDoc.audit.txt'), 'utf8');
assert.equal((audit.match(/^COMP\|A2\|.*OKI-78SR-5\/1\.5-W36-C\r?$/gm) || []).length, 1);
assert.match(audit, /COMP\|C1\|470uF \/ 25V\|EEU-FR1E471/);
assert.match(audit, /COMP\|C5\|470uF \/ 10V\|EEU-FR1A471/);
assert.match(source, /'C1', '470uF \/ 25V', 'Panasonic', 'EEU-FR1E471', 'CAP_RADIAL_D10_P5'/);
assert.match(source, /'C5', '470uF \/ 10V', 'Panasonic', 'EEU-FR1A471', 'CAP_RADIAL_D8_P3\.5'/);
assert.ok(Math.abs(470e-6 * 0.2 / 0.2 - 470e-6) < 1e-12);
console.log('PASS: single selected buck, retained bulk values, corrected generator package requirements.');
for (const [ref, required] of [['C1','CAP_RADIAL_D10_P5'],['C5','CAP_RADIAL_D8_P3.5']]) {
  const found = audit.split(/\r?\n/).find(l => l.startsWith(`PARAM|${ref}|Intended footprint|`));
  if (found !== `PARAM|${ref}|Intended footprint|${required}`)
    console.log(`PENDING native metadata migration: ${ref} requires ${required}; no footprint verified.`);
}
console.log('Not a fresh native export or an electrical/thermal qualification.');

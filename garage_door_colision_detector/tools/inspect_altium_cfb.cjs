// Read-only directory/stream inspector for Altium OLE compound files.
// It never writes to the inspected file.
const fs = require('node:fs');
const assert = require('node:assert/strict');

const file = process.argv[2];
assert(file, 'Usage: node inspect_altium_cfb.cjs <file>');
const b = fs.readFileSync(file);
assert.equal(b.subarray(0, 8).toString('hex'), 'd0cf11e0a1b11ae1');
const size = 2 ** b.readUInt16LE(30);
const sector = i => b.subarray((i + 1) * size, (i + 2) * size);
const u32s = x => Array.from({ length: x.length / 4 }, (_, i) => x.readUInt32LE(i * 4));
let difat = u32s(b.subarray(76, 512)).filter(i => i < 0xfffffffa);
let next = b.readUInt32LE(68);
for (let i = 0; i < b.readUInt32LE(72); i++) {
  const s = u32s(sector(next));
  difat.push(...s.slice(0, -1).filter(x => x < 0xfffffffa));
  next = s.at(-1);
}
const fat = difat.flatMap(i => u32s(sector(i)));
function chain(first, table, get) {
  const chunks = [], seen = new Set();
  for (let i = first; i !== 0xfffffffe; i = table[i]) {
    assert(Number.isInteger(i) && i < 0xfffffffa && !seen.has(i), 'Invalid/cyclic CFB chain');
    seen.add(i);
    chunks.push(get(i));
  }
  return Buffer.concat(chunks);
}
const directory = chain(b.readUInt32LE(48), fat, sector);
const entries = [];
for (let i = 0; i + 128 <= directory.length; i += 128) {
  const d = directory.subarray(i, i + 128), n = d.readUInt16LE(64);
  entries.push(n ? {
    index: i / 128,
    name: d.subarray(0, n - 2).toString('utf16le'),
    type: d[66],
    left: d.readUInt32LE(68),
    right: d.readUInt32LE(72),
    child: d.readUInt32LE(76),
    start: d.readUInt32LE(116),
    size: Number(d.readBigUInt64LE(120)),
  } : { index: i / 128, empty: true });
}
console.log(JSON.stringify(entries.filter(e => !e.empty), null, 2));

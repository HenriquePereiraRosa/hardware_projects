// Read-only verification of native Altium-generated exports, not full DRC/ERC.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const pcb = read('OpticalHardwarePCB.audit.txt').trim().split(/\r?\n/).map(l => l.split('|'));
const heads = read('04_Optical_Heads.SchDoc.audit.txt');
const inputs = read('02_Beam_Inputs.SchDoc.audit.txt');
const refs = ['J2', 'J3', 'J4', 'J6'];
const near = (a,b) => assert(Math.abs(+a-b)<0.0001, `${a} != ${b}`);
for (let i=0;i<4;i++) {
  const ref=refs[i];
  const comp=pcb.filter(r=>r[0]==='COMP'&&r[1]===ref);
  assert.equal(comp.length,1);
  assert.equal(comp[0][2],'PHOENIX_1715734_MKDS_3_508');
  const pads=pcb.filter(r=>r[0]==='PAD'&&r[1]===ref);
  assert.equal(pads.length,3);
  pads.sort((a,b)=>+a[2]-+b[2]);
  assert.deepEqual(pads.map(r=>r[3]),['12V_SENSOR','GND',`BEAM${i+1}_SIG`]);
  for(const p of pads) { near(p[4],15); near(p[6],1.3); }
  near(pads[1][5]-pads[0][5],5.08); near(pads[2][5]-pads[1][5],5.08);
  assert.equal(pcb.filter(r=>r[0]==='STEPBODY'&&r[1]===ref).length,1);
  assert(inputs.includes(`MODEL|${ref}|PCBLIB|PHOENIX_1715734_MKDS_3_508`));
  assert(inputs.includes(`PARAM|${ref}|Manufacturer Part Number|1715734`));
  for(const [role,suffix,pins] of [['TX','L',2],['RX','D',3]]) {
    const r=role+(i+1);
    assert(heads.includes(`COMP|${r}|E3Z-T61-${suffix} 2M|E3Z-T61-${suffix} 2M`));
    assert.equal(heads.split(/\r?\n/).filter(l=>l.startsWith(`PIN|${r}|`)).length,pins);
    assert(heads.includes(`PARAM|${r}|Intended footprint|NONE - external wired device`));
    assert(!heads.includes(`MODEL|${r}|PCBLIB|`));
  }
}
for(const name of ['04_Optical_Heads.SchDoc','lib/OpticalHardware.SchLib','lib/OpticalHardware.PcbLib','GarageBeamSafety.PcbDoc']) {
  const buf=fs.readFileSync(path.join(root,name));
  assert.equal(buf.subarray(0,8).toString('hex'),'d0cf11e0a1b11ae1',name+' is not a compound document');
  assert(buf.length>10000);
}
const project=read('GarageBeamSafety.PrjPcb');
for(const name of ['04_Optical_Heads.SchDoc','lib\\OpticalHardware.SchLib','lib\\OpticalHardware.PcbLib']) assert(project.includes(`DocumentPath=${name}`));
console.log('PASS: eight identified optical heads, four native footprint links, twelve pad/net/drill checks, four 3D bodies, and project document links.');
console.log('Not covered: model-to-pad 3D registration, full PCB synchronization/routing/DRC, physical optical performance or fail-safe certification.');

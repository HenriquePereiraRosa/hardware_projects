// Verify native Altium exports, with sheet-local labels and explicit hierarchy.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const top='00_Mounting_Overview.SchDoc';
const read=(f)=>fs.readFileSync(path.join(root,f),'utf8').trim().split(/\r?\n/).filter(Boolean).map(l=>l.split('|'));
const objects=read(top+'.hierarchy.txt');
const sheets=objects.filter(a=>a[0]==='SHEET').map(a=>a[2]);
assert.equal(sheets.length,5); assert.equal(new Set(sheets).size,5);
const project=fs.readFileSync(path.join(root,'GarageBeamSafety.PrjPcb'),'utf8');
const projectDocuments=[...project.matchAll(/^DocumentPath=(.+)$/gm)].map(m=>m[1].trim());
for(const sheet of [top,...sheets]){
  assert.equal(projectDocuments.filter(p=>p===sheet).length,1,'Missing/duplicate project document '+sheet);
}
let checked=0;
for(const sheet of sheets){
  assert(fs.existsSync(path.join(root,sheet)),'Missing child '+sheet);
  const ports=read(sheet+'.hierarchy.txt').filter(a=>a[0]==='PORT');
  const entries=objects.filter(a=>a[0]==='ENTRY'&&a[1]===sheet);
  assert.equal(ports.length,entries.length,'Entry/port count mismatch '+sheet);
  const child=read(sheet+'.audit.txt');
  const parent=read(top+'.audit.txt');
  function wireAt(rows,x,y){return rows.some(a=>a[0]==='WIRE'&&a[2]===x&&a[3]===y);}
  for(const entry of entries){
    const matches=ports.filter(p=>p[1]===entry[2]);
    assert.equal(matches.length,1,'Missing/duplicate port '+sheet+':'+entry[2]);
    const p=matches[0]; assert.equal(p[4],entry[3],'Direction mismatch');
    assert(wireAt(parent,entry[4],entry[5]),'Unwired sheet entry '+entry[2]);
    assert(wireAt(child,p[2],p[3]),'Unwired child port '+entry[2]);
    assert(child.filter(a=>a[0]==='NET'&&a[1]===p[1]).length>=2,'Port has no existing circuit label '+p[1]);
    checked++;
  }
}
assert.equal(checked,35);
console.log(`PASS: 5 native sheet links; ${checked} uniquely matched wired ports/entries; matching directions and existing net labels.`);
console.log('PASS: top sheet and all five child sheets are included exactly once in the saved project.');
console.log('Structural hierarchy check only. Existing pin connectivity/ERC issues are NOT waived.');

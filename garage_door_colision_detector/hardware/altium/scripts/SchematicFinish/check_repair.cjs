const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
const {records}=require(path.join(root,'tools/read_altium_schematic.cjs'));
const {graph}=require(path.join(root,'tools/audit_saved_connectivity.cjs'));
const pas=fs.readFileSync(path.join(__dirname,'SchematicFinish.pas'),'utf8');
assert(!/RemoveSchObject|UnRegisterSchObject|PCBServer|eNoERC|\.Electrical\s*:=|\.Designator\s*:=|\.OwnerPartDisplayMode\s*:=/i.test(pas));
assert(pas.includes('Not Result.Modified'));
assert(pas.indexOf("Backup('02_Beam_Inputs.SchDoc')")<pas.indexOf("Try InputLinks(D)"));
assert(pas.includes("Begin RunCapRepair(False); End;"));
assert(pas.includes("Begin RunCapRepair(True); End;"));
let text=pas.replace(/\{[\s\S]*?\}|\(\*[\s\S]*?\*\)|\/\/[^\r\n]*/g,'').replace(/'(?:''|[^'])*'/g,"''");
assert.equal((text.match(/\(/g)||[]).length,(text.match(/\)/g)||[]).length);
let blocks=[];for(const m of text.matchAll(/\b(Begin|Try|Case|End)\b/gi)){if(m[1].toLowerCase()==='end')assert(blocks.pop());else blocks.push(m[1]);}assert.equal(blocks.length,0);
function patch(rows,procedure){
 const body=pas.slice(pas.indexOf('Procedure '+procedure+'(D);'));
 const calls=[...body.slice(0,body.indexOf('\nEnd;')).matchAll(/Link\(D,(\d+),(\d+),(\d+),(\d+)\)/g)];
 assert.equal(calls.length,procedure==='InputLinks'?8:6);
 return [...rows,...calls.map(m=>({fields:{RECORD:'27',LOCATIONCOUNT:'2',X1:m[1],Y1:m[2],X2:m[3],Y2:m[4]}}))];
}
let count=0;
for(const [name,proc,expected]of [
 ['02_Beam_Inputs','InputLinks',{'C2.1':'GND','C2.2':'BEAM1_GPIO32','C3.1':'GND','C3.2':'BEAM2_GPIO33','C4.1':'GND','C4.2':'BEAM3_GPIO34','C6.1':'GND','C6.2':'BEAM4_GPIO35'}],
 ['01_Power_Control','PowerLinks',{'C1.1':'12V_SENSOR','C1.2':'GND','C5.1':'5V_LOGIC','C5.2':'GND'}]
]){
 const rows=records(path.join(root,'hardware/altium/sch',name+'.SchDoc'));
 const before=graph(rows),after=graph(patch(rows,proc));
 assert.deepEqual(after.duplicatePins,[]);assert.deepEqual(after.shorts,[]);assert.equal(after.pins.length,before.pins.length);
 for(const p of after.pins){const key=p.ref+'.'+p.pin,old=before.pins.find(q=>q.ref===p.ref&&q.pin===p.pin);
  assert(old);const {nets,...pin}=p,{nets:oldNets,...oldPin}=old;assert.deepEqual(pin,oldPin);
  if(expected[key]){assert.deepEqual(p.nets,[expected[key]],key);count++;}else assert.deepEqual(p.nets,old.nets,'Unexpected changed net '+key);
 }
}
// Synthetic regression tests: display-mode records must not be counted twice;
// wires that reach the pin body but not the hotspot must NOT connect the pin.
const rows=[{index:0,fields:{RECORD:'1',CURRENTPARTID:'1'}},{fields:{RECORD:'34',OWNERINDEX:'0',TEXT:'C9'}},
 {fields:{RECORD:'2',OWNERINDEX:'0',OWNERPARTID:'1',DESIGNATOR:'1','LOCATION.X':'10','LOCATION.Y':'10',PINLENGTH:'10',PINCONGLOMERATE:'3'}},
 {fields:{RECORD:'2',OWNERINDEX:'0',OWNERPARTID:'1',OWNERPARTDISPLAYMODE:'1',DESIGNATOR:'1','LOCATION.X':'10','LOCATION.Y':'10',PINLENGTH:'10',PINCONGLOMERATE:'3'}},
 {fields:{RECORD:'27',LOCATIONCOUNT:'2',X1:'10',Y1:'10',X2:'20',Y2:'10'}},{fields:{RECORD:'25',TEXT:'GND','LOCATION.X':'20','LOCATION.Y':'10'}}];
assert.equal(graph(rows).pins.length,1);assert.deepEqual(graph(rows).pins[0].nets,[]);
assert.deepEqual(graph([...rows,{fields:{RECORD:'27',LOCATIONCOUNT:'2',X1:'10',Y1:'0',X2:'10',Y2:'10'}}]).pins[0].nets,['GND']);
console.log(`PASS: ${count} intended capacitor pin nets restored in geometry model, all other pin nets/identities preserved, no shorts, alternate-mode/hotspot tests passed.`);
console.log('PASS: script scope, backup order and lexical checks. Native Altium compilation/execution remains untested.');

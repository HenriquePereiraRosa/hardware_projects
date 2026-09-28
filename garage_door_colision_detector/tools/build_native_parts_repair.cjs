// Generates a native Altium script. Never edits a SchDoc, PcbDoc or source library.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {records}=require('./read_altium_schematic.cjs');
const root=fs.realpathSync(path.resolve(__dirname,'..'));
const base=path.join(root,'hardware/altium');
const out=path.join(base,'scripts/RestoreNativeParts');
const baseline=require('../hardware/altium/scripts/ComponentRefresh/manifest.json');
const parts=baseline.parts.filter(p=>p.action!=='retain'&&p.action!=='ptc');
assert.equal(parts.length,39);
const names=[...new Set(parts.map(p=>p.sheet))]; assert.equal(names.length,3);
const q=s=>"'"+String(s??'').replaceAll("'","''")+"'";
const xy=f=>[+(f['LOCATION.X']||0)*100000+(+f['LOCATION.X_FRAC']||0),+(f['LOCATION.Y']||0)*100000+(+f['LOCATION.Y_FRAC']||0)];
const data=Object.fromEntries(names.map(n=>[n,records(path.join(base,'sch',n))]));
const lines=names.map((n,i)=>` OpenCopy(${i},${q(n)});`);
const audit=[];
parts.forEach((p,n)=>{
 const rows=data[p.sheet];
 const comp=rows.find(r=>r.fields.RECORD==='1'&&r.fields.UNIQUEID===p.uid);
 let params=p.params,designator=p.position.map((v,i)=>v+(i?3000000:0)),comment=p.position.map((v,i)=>v-(i?3000000:0));
 if(comp){
  const ch=rows.filter(r=>+r.fields.OWNERINDEX===comp.index);
  params=Object.fromEntries(ch.filter(r=>['34','41'].includes(r.fields.RECORD)).map(r=>[r.fields.NAME,r.fields.TEXT]));
  assert.equal(params.Designator,p.ref); assert.equal(params['Manufacturer Part Number'],p.mpn,'Part changed: '+p.ref);
  const d=ch.find(r=>r.fields.NAME==='Designator'),c=ch.find(r=>r.fields.NAME==='Comment');
  if(d)designator=xy(d.fields); if(c)comment=xy(c.fields);
  for(const pin of p.active){const f=ch.find(r=>r.fields.RECORD==='2'&&r.fields.DESIGNATOR===pin.id&&+(r.fields.OWNERPARTDISPLAYMODE||0)===0);assert(f,p.ref+' missing baseline pin');assert.deepEqual(xy(f.fields),pin.xy,p.ref+' moved connection; regenerate baseline');}
 }
 assert(fs.existsSync(path.join(base,'lib/reviewed-sources',p.import.source)));
 assert(fs.existsSync(path.join(base,p.footprint.file)));
 assert.equal(p.kind,0,'Nonstandard component must not be put onto PCB');
 assert(!p.models[0].MAPDEFINER,'Explicit pin map requires review');
 const pos=[...designator,...comment].join(',');
 lines.push(` LoadPart(${n},${names.indexOf(p.sheet)},${q(p.ref)},${q(p.uid)},${q(p.import.source)},${q(p.import.libref)},${p.import.rotation},${q(params.Comment)},${pos});`);
 for(const pin of p.import.pins){const old=p.active.find(x=>x.id===pin.target);lines.push(` MapPin(${n},${q(pin.source)},${q(pin.target)},${old.xy.join(',')});`);}
 lines.push(` PositionPart(${n},${p.active.length},${pos});`);
 for(const [key,val] of Object.entries(params)){
  if(['Designator','Comment','Symbol source','Symbol adaptation','Component refresh','CAD status','Symbol source status'].includes(key))continue;
  if(val!==undefined)lines.push(` Param(${n},${q(key)},${q(val)});`);
 }
 lines.push(` Param(${n},'Symbol source',${q('Celestial / '+p.import.source+' / '+p.import.libref)});`);
 lines.push(` Param(${n},'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');`);
 lines.push(` Footprint(${n},${q(p.footprint.name)},${q(p.footprint.file)});`);
 audit.push({ref:p.ref,sheet:p.sheet,mpn:p.mpn,source:p.import.source,sourceRef:p.import.libref,footprint:p.footprint.name,wasPresent:!!comp,pinMap:p.import.pins.map(x=>[x.source,x.target])});
});
const template=fs.readFileSync(path.join(out,'RestoreNativeParts.template.pas'),'utf8');
const pas=template.replace('@@BASE@@',base+'\\').replace('@@BUILD@@',lines.join('\n'));
assert(!pas.includes('@@'));
assert(!/\b(?:Replicate|Abort|Raise)\s*[;(]/i.test(pas),'Forbidden old copying/abort path');
assert.equal((pas.match(/^ LoadPart\(/gm)||[]).length,39);
assert.equal((pas.match(/^ Footprint\(/gm)||[]).length,39);
assert.equal((pas.match(/^ MapPin\(/gm)||[]).length,89);
assert(!pas.includes('C=NewParts[N]'),'Do not compare scripting interface references for component identity');
for(const check of ['VERIFY_OK|','UIDCount=1',"C.UniqueId<>''",'C.LibReference=ExpectedSource[N]','Count=PinCounts[N]',"Failure:=Phase+' | '+S"])
 assert(pas.includes(check),'Missing final verification or diagnostic: '+check);
for(const check of ['VERIFY_SUMMARY|','VERIFY_ERROR|','VerifyRegisteredPart(N);','Finally CollectingVerification:=False; End;','UID_AFTER_REGISTER|'])
 assert(pas.includes(check),'Missing aggregate verification feature: '+check);
assert(pas.indexOf('If VerifyIssues>0 Then Begin')<pas.indexOf("DoFileSave('SCHBinary5.0')"),'Verification failures must block saving');
const apply=pas.slice(pas.indexOf('Procedure ApplyCopies;'),pas.indexOf('Procedure BuildAll;'));
const registerAt=apply.indexOf('RegisterSchObjectInContainer(C);');
const removeAt=apply.indexOf('UnRegisterSchObjectFromContainer(OldParts[N]);');
assert(registerAt>=0 && removeAt>registerAt,'Add complete native component before removing old component on copy');
assert(!/\.UniqueId\s*:=/i.test(pas),'Do not overwrite native IDs');
assert(!pas.includes('C.UniqueId=ExpectedUID[N]'),'Do not reject new IDs');
assert(!/\bWireSegment\s*\(/.test(pas) && !pas.includes('SchObjectFactory(eWire'),'Existing wires must remain unchanged');
assert(pas.includes('UID_MAP|'),'Log old-to-new IDs for PCB link reconciliation');
for(const check of ['WS.DM_GenerateUniqueID','C.SetState_UniqueId(NewUID)','SCHM_BeginModify','SCHM_EndModify','UID_COLLISION_REPAIR|','Registered:=FindPart','CountComponentUID(NewUID)=0'])
 assert(pas.includes(check),'Missing collision repair safeguard: '+check);
assert(apply.indexOf('RepairIDCollisions;')<apply.indexOf('VerifyRegisteredPart(N);'),'Collision repair must precede final verification');
if(process.argv.includes('--write')){
 fs.writeFileSync(path.join(out,'RestoreNativeParts.pas'),pas);
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({generatedAt:new Date().toISOString(),runtimeTested:false,scope:'39 full native components on repair copies; no source CAD writes',parts:audit},null,2)+'\n');
}
console.log(JSON.stringify({parts:parts.length,pins:(pas.match(/^ MapPin\(/gm)||[]).length,sheets:names,sha256:crypto.createHash('sha256').update(pas).digest('hex'),nativeExecution:'NOT RUN'},null,2));

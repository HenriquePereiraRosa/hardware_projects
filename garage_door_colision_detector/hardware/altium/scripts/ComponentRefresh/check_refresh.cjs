const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../../..'),base=path.join(root,'hardware/altium');
const m=require('./manifest.json'),pas=fs.readFileSync(path.join(__dirname,'ComponentRefresh.pas'),'utf8');
const {records}=require(path.join(root,'tools/read_altium_schematic.cjs'));
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
assert.equal(m.parts.length,60);assert.equal(m.sheets.length,6);
for(const s of m.sheets)assert.equal(hash(path.join(base,'sch',s.file)),s.sha256,'Native sheet changed since manifest generation: '+s.file);
for(const s of Object.values(m.sources))assert.equal(hash(path.join(base,'lib/reviewed-sources',s.name)),s.sha256);
for(const p of m.parts){
 assert(p.manufacturer&&p.mpn);assert(p.pins.length>0);
 assert.equal(new Set(p.active.map(p=>p.id)).size,p.active.length);
 if(p.kind===2){assert(!p.footprint);assert.equal(p.models.length,0);}
 else {assert(p.footprint);assert.equal(hash(path.join(base,p.footprint.file)),p.footprint.sha256);}
 if(p.action==='iec-resistor'){
  assert.equal(p.active[0].xy[1],p.active[1].xy[1]);assert(Math.abs(p.active[0].xy[0]-p.active[1].xy[0])>=2400000);
 }
 if(p.import){
  assert.equal(p.import.pins.length,p.active.length);
  for(const pin of p.import.pins)assert(p.active.some(p=>p.id===pin.target));
  if(p.action==='mosfet')assert.deepEqual(Object.fromEntries(p.import.pins.map(p=>[p.source,p.target])),{G:'1',S:'2',D:'3'});
 }
}
assert.equal(m.parts.filter(p=>p.kind===2).length,10);
assert.equal(m.parts.filter(p=>p.footprint).length,50);
assert.equal(m.parts.filter(p=>p.action!=='retain').length,40);
assert.equal(m.parts.filter(p=>p.import).length,21);
assert.equal(m.parts.filter(p=>p.action==='iec-resistor').length,19);
// Polarity and physical pin mapping are deliberately explicit.
assert(m.sources.polarized.pins.find(p=>p.id==='1').x<0);
assert(m.sources.polarized.pins.find(p=>p.id==='2').x>0);
for(const ref of ['C1','C5']){const p=m.parts.find(p=>p.ref===ref);assert.equal(p.import.rotation,1);}
// No native electrical primitive is created or modified by the appearance refresh.
assert(!/SchObjectFactory\(e(Pin|Wire|NetLabel|Port|SheetSymbol|SheetEntry|NoERC)/i.test(pas));
assert(!/\.(PinLength|Electrical|Name|Designator)\s*:=/i.test(pas.replace(/P.Name:=N;/g,'')));
assert(!/B\.AddPCBObject|B\.RemovePCBObject|PCBServer\.PreProcess/.test(pas));
assert(pas.includes('StageAll; BackupAll; ExportLibrary; ApplyAll;'));
assert(pas.includes('PinsSignature(C)=BeforePins[N]'));
assert(pas.includes('NewM.MapAsString=Map'));
assert(pas.includes('Artwork[N]:=C.Replicate'));
assert(pas.includes('Clone:=O.Replicate'));
assert(pas.includes('Clone.OwnerPartDisplayMode:=Mode'));
assert(pas.includes('No substitute block generated'));
assert(!pas.includes('@@'));
let code=pas.replace(/\{[\s\S]*?\}|\(\*[\s\S]*?\*\)|\/\/[^\r\n]*/g,'').replace(/'(?:''|[^'])*'/g,"''");
assert.equal((code.match(/\(/g)||[]).length,(code.match(/\)/g)||[]).length);
const blocks=[];for(const hit of code.matchAll(/\b(Begin|Try|Case|End)\b/gi)){if(hit[1].toLowerCase()==='end')assert(blocks.pop());else blocks.push(hit[1]);}assert.equal(blocks.length,0);
// The generated pin guards cover EVERY native pin record, including alternative views.
assert.equal((pas.match(/^  ExpectPin\(/gm)||[]).length,m.parts.reduce((n,p)=>n+p.pins.length,0));
assert.equal((pas.match(/^  StagePart\(/gm)||[]).length,60);
for(const s of m.sheets){const r=records(path.join(base,'sch',s.file));assert.equal(r.filter(x=>x.fields.RECORD==='1').length,s.count);}
console.log('PASS: six native documents unchanged; 60 purchasing identities; 50 existing footprint files; 10 external devices.');
console.log('PASS: 21 attributed native-library symbol imports, 19 IEC resistor variants, explicit polarity/mapping guards.');
console.log('PASS: source hashes, all pin preflight guards, staging-before-apply and backup ordering, no electrical/PCB primitive writes.');
console.log('LIMIT: static tests are not native Altium compilation, ERC, visual QA or a manufacturing release.');

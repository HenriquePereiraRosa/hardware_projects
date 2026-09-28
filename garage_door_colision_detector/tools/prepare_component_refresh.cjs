// Read native CAD; generate an Altium-only, backed-up refresh. Never writes native CAD.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {records,stream}=require('./read_altium_schematic.cjs');
const root=path.resolve(__dirname,'..'),base=path.join(root,'hardware/altium');
const upstream='C:/dev/projects/altium_lib/altium-library-master/altium-library-master';
const out=path.join(base,'scripts/ComponentRefresh'),assets=path.join(base,'lib/reviewed-sources');
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const q=s=>"'"+String(s).replaceAll("'","''")+"'";
const point=(f,p='LOCATION')=>[+(f[p+'.X']||0)*100000+(+f[p+'.X_FRAC']||0),+(f[p+'.Y']||0)*100000+(+f[p+'.Y_FRAC']||0)];
const defs={
 resistor:'Passives/SCH - PASSIVES - RESISTOR.SCHLIB',
 capacitor:'Passives/SCH - PASSIVES - CAPACITOR.SCHLIB',
 polarized:'Passives/SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB',
 diode:'Diodes/SCH - DIODES - DIODE.SCHLIB',
 tvs:'Diodes/SCH - DIODES - DIODE TVS UNI.SCHLIB',
 fuse:'Fuse/SCH - FUSE - MOUNTED FUSE.Schlib',
 ptc:'Passives/SCH - PASSIVES - THERMISTOR PTC.SCHLIB',
 opto:'Optoisolators/SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB',
 mosfet:'FET - N-CH/SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB',
 switch:'Switch/SCH - SWITCH - SPST 2PIN.SCHLIB'
};
function library(rel){
 const f=path.join(upstream,'symbols',rel),b=stream(f,'Data'),pins=[];let libref;
 for(let o=0;o<b.length;){const w=b.readUInt32LE(o),n=w&0xffffff; o+=4; const d=b.subarray(o,o+n);o+=n;
  if(w>>>24){assert.equal(w>>>24,1);assert.equal(d.readInt32LE(0),2);assert.equal(d[5],1);assert.equal(d.readUInt16LE(8),0,'Unexpected variable pin description');
   let k=26;const read=()=>{let n=d[k++],s=d.subarray(k,k+n).toString('latin1');k+=n;return s;};const name=read(),id=read();
   pins.push({id,name,x:d.readInt16LE(18)*100000,y:d.readInt16LE(20)*100000,orientation:d[15]&3,length:d.readInt16LE(16)*100000});
  }else{const s=d.toString('latin1');if(/^\|RECORD=1\|/i.test(s))libref=/\|LIBREFERENCE=([^|\0]+)/i.exec(s)[1];}
 }
 assert(libref);assert.equal(new Set(pins.map(p=>p.id)).size,pins.length);
 return {relative:rel,file:f,name:path.basename(f),libref,pins,sha256:hash(f)};
}
const sources=Object.fromEntries(Object.entries(defs).map(([k,v])=>[k,library(v)]));
// This non-IPC variant has pin 1 at the + plate (left). The IPC variant
// reverses numbering and must NOT be interchanged without an explicit map.
assert(sources.polarized.pins.find(p=>p.id==='1').x<0);
assert(sources.polarized.pins.find(p=>p.id==='2').x>0);
const rot=([x,y],r)=>[[x,y],[-y,x],[-x,-y],[y,-x]][r];
const center=ps=>[0,1].map(i=>(Math.min(...ps.map(p=>p[i]))+Math.max(...ps.map(p=>p[i])))/2);
const files=fs.readdirSync(path.join(base,'sch')).filter(f=>/\.SchDoc$/i.test(f)).sort();
const sheets=[],parts=[];
for(const file of files){const full=path.join(base,'sch',file),rows=records(full),sheet={file,sha256:hash(full),count:0};sheets.push(sheet);
 for(const c of rows.filter(x=>x.fields.RECORD==='1')){
  const ch=rows.filter(x=>+x.fields.OWNERINDEX===c.index),params=Object.fromEntries(ch.filter(x=>['34','41'].includes(x.fields.RECORD)).map(x=>[x.fields.NAME,x.fields.TEXT]));
  const pins=ch.filter(x=>x.fields.RECORD==='2').map(x=>({id:x.fields.DESIGNATOR,name:x.fields.NAME||'',xy:point(x.fields),orientation:+(x.fields.PINCONGLOMERATE||0)&3,length:+(x.fields.PINLENGTH||0)*100000,electrical:+(x.fields.ELECTRICAL||0),mode:+(x.fields.OWNERPARTDISPLAYMODE||0),part:+(x.fields.OWNERPARTID||1),uid:x.fields.UNIQUEID}));
  const active=pins.filter(p=>p.mode===+(c.fields.DISPLAYMODE||0)&&p.part===+(c.fields.CURRENTPARTID||1));
  assert.equal(new Set(active.map(p=>p.id)).size,active.length);
  const models=rows.filter(x=>x.fields.RECORD==='45'&&ch.some(z=>z.index===+x.fields.OWNERINDEX)).map(x=>x.fields);
  const part={sheet:file,ref:params.Designator,uid:c.fields.UNIQUEID,oldReference:c.fields.LIBREFERENCE,mpn:params['Manufacturer Part Number'],manufacturer:params.Manufacturer,comment:params.Comment,kind:+(c.fields.COMPONENTKIND||0),pins,active,models,rectangles:ch.filter(x=>x.fields.RECORD==='14').length,position:point(c.fields),params};
  assert(part.mpn&&part.manufacturer,part.ref+' missing purchasing identity');assert(active.length>0);
  part.newReference=part.mpn.replace(/[^a-z0-9_-]/gi,'_')+'__'+part.ref+'_view';
  const ref=part.ref;
  part.action=/^R\d+$/.test(ref)?'resistor':/^C/.test(ref)?(['C1','C5'].includes(ref)?'polarized':'capacitor'):/^U/.test(ref)?'opto':/^Q/.test(ref)?'mosfet':ref==='F1'?'ptc':/^F/.test(ref)?'fuse':ref==='SW1'?'switch':ref==='D1'?'tvs':/^D/.test(ref)&&ref!=='D6'?'diode':'retain';
  part.note=part.action==='retain'?'Keep existing part-specific symbol; package and procurement metadata retained.':'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.';
  if(ref==='D6')part.note='Retain existing diode symbol for SS34; dedicated Schottky glyph remains a follow-up (not silently replaced with TVS/rectifier artwork).';
  if(part.kind===2)part.note+=' External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.';
  if(part.action!=='retain'){
   const source=sources[part.action];let rotation=0;
   const mapped=source.pins.map(p=>({...p,target:part.action==='mosfet'?{G:'1',S:'2',D:'3'}[p.id]:p.id}));
   assert.equal(mapped.length,active.length,ref+' pin count');for(const p of mapped)assert(active.some(t=>t.id===p.target),ref+' pin mapping');
   if(active.length===2){const a=mapped.find(p=>p.target==='1'),b=mapped.find(p=>p.target==='2'),ta=active.find(p=>p.id==='1'),tb=active.find(p=>p.id==='2');
    const desired=tb.xy.map((v,i)=>Math.sign(v-ta.xy[i]));rotation=[0,1,2,3].find(r=>rot([b.x-a.x,b.y-a.y],r).map(Math.sign).every((v,i)=>v===desired[i]));assert(rotation!==undefined,ref+' non-orthogonal pin pair');}
   const sc=center(mapped.map(p=>rot([p.x,p.y],rotation))),tc=center(active.map(p=>p.xy));
   part.import={source:source.name,libref:source.libref,rotation,offset:tc.map((v,i)=>v-sc[i]),pins:mapped.map(p=>{const xy=rot([p.x,p.y],rotation).map((v,i)=>v+tc[i]-sc[i]);return {source:p.id,target:p.target,xy};})};
   // All alternative views must have identical pin positions before any artwork replacement.
   for(const p of pins)assert.deepEqual(p.xy,active.find(x=>x.id===p.id).xy,ref+' alternative-view pin position differs');
  }
  if(part.kind!==2){assert.equal(models.length,1,ref+' ambiguous model');const m=models[0];let f=m.MODELDATAFILE0;
   if(ref==='A1')f=path.join(base,'lib/ESP32-DEVKITC-32E/MODULE_ESP32-DEVKITC-32E.PcbLib');
   else if(f)f=f.replace('C:\\dev\\projects\\h\\garage_door_colision_detector',root);
   assert(f&&fs.existsSync(f),ref+' unresolved footprint '+f);part.footprint={name:m.MODELNAME,file:path.relative(base,f),sha256:hash(f),staleLink:m.MODELDATAFILE0!==f};
  }else assert.equal(models.length,0,ref+' external item must not gain PCB pads');
  parts.push(part);sheet.count++;
 }
}
assert.equal(parts.length,60);assert.equal(new Set(parts.map(p=>p.ref)).size,parts.length);
const manifest={version:1,scope:'All six saved schematic documents; no live/native execution yet. Native pin/pad and 3D body audit required.',sheets,parts,sources};
if(process.argv.includes('--write')){
 for(const dir of [out,assets,path.join(base,'lib/reviewed')])fs.mkdirSync(dir,{recursive:true});
 for(const s of Object.values(sources)){const dest=path.join(assets,s.name);if(fs.existsSync(dest))assert.equal(hash(dest),s.sha256,'Refusing to overwrite different source');else fs.copyFileSync(s.file,dest);}
 fs.copyFileSync(path.join(upstream,'README.md'),path.join(assets,'CELESTIAL_README.md'));
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 const lines=[];
 for(let i=0;i<sheets.length;i++)lines.push(`  OpenSheet(${i},${q(sheets[i].file)},${sheets[i].count});`);
 for(let i=0;i<parts.length;i++){
  const p=parts[i],s=sheets.findIndex(s=>s.file===p.sheet);
  lines.push(`  StagePart(${i},${s},${q(p.ref)},${q(p.uid)},${q(p.oldReference)},${q(p.newReference)},${q(p.mpn)},${q(p.manufacturer)},${p.kind});`);
  for(const pin of p.pins)lines.push(`  ExpectPin(${i},${q(pin.id)},${pin.mode},${pin.part},${pin.xy[0]},${pin.xy[1]},${pin.orientation},${pin.length},${pin.electrical});`);
  lines.push(`  ExpectPinCount(${i},${p.pins.length});`);
  if(p.footprint)lines.push(`  CheckFootprint(${i},${q(p.footprint.name)},${q(p.footprint.file)});`);
  if(p.import){const imp=p.import;lines.push(`  ImportArtwork(${i},${q(imp.source)},${q(imp.libref)},${imp.rotation},${imp.offset[0]},${imp.offset[1]});`);for(const pin of imp.pins)lines.push(`  BridgePin(${i},${q(pin.source)},${q(pin.target)},${pin.xy[0]},${pin.xy[1]});`);}
  lines.push(`  FinishPart(${i},${q(p.note)});`);
 }
 let pas=fs.readFileSync(path.join(out,'ComponentRefresh.template.pas'),'utf8').replace('@@BASE@@',root.replaceAll('/','\\')+'\\hardware\\altium\\').replace('@@STAGE@@',lines.join('\n'));
 assert(!pas.includes('@@'));fs.writeFileSync(path.join(out,'ComponentRefresh.pas'),pas);
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const rows=parts.map(p=>`<tr><td>${esc(p.sheet)}</td><td>${esc(p.ref)}</td><td>${esc(p.manufacturer)}<br>${esc(p.mpn)}</td><td>${esc(p.action)}<br>${esc(p.note)}</td><td>${esc(p.footprint?.name||'External equipment — no PCB pads')}<br>3D appearance: not yet verified</td></tr>`).join('\n');
 const html=fs.readFileSync(path.join(out,'guide.template.html'),'utf8').replace('@@ROWS@@',rows).replace('@@COUNT@@',parts.length).replace('@@REPLACED@@',parts.filter(p=>p.action!=='retain').length);
 fs.writeFileSync(path.join(root,'docs/COMPONENT_REFRESH.html'),html);
}
console.log(JSON.stringify({schematics:sheets.map(s=>({file:s.file,parts:s.count})),total:parts.length,actions:parts.reduce((a,p)=>(a[p.action]=(a[p.action]||0)+1,a),{}),footprintLinks:parts.filter(p=>p.footprint).length,external:parts.filter(p=>p.kind===2).length},null,2));

// Geometric connectivity audit of saved native sheets. Read-only CAD access.
// Uses active symbol display modes and pin HOTSPOTS, not their body ends.
// This is not a replacement for Altium's hierarchical compiler or ERC.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {records}=require('./read_altium_schematic.cjs');
const root=path.resolve(__dirname,'..');
function graph(rows){
 const comps=new Map(rows.filter(r=>r.fields.RECORD==='1').map(r=>[r.index,r.fields]));
 const refs=new Map(rows.filter(r=>r.fields.RECORD==='34').map(r=>[+r.fields.OWNERINDEX,r.fields.TEXT]));
 const nodes=new Map(),pins=[],segments=[],named=[];
 const c=(f,k)=>(+(f[k]||0))*100000+(+(f[k+'_FRAC']||0));
 function pt(x,y){const k=x+','+y;if(!nodes.has(k))nodes.set(k,{x,y,parent:k});return k;}
 function find(k){const n=nodes.get(k);return n.parent===k?k:(n.parent=find(n.parent));}
 function join(a,b){nodes.get(find(a)).parent=find(b);}
 for(const {fields:f} of rows){
  if(f.RECORD==='2'){
   const comp=comps.get(+f.OWNERINDEX);assert(comp,'Orphan pin');
   if(+(f.OWNERPARTID||1)!==+(comp.CURRENTPARTID||1) || +(f.OWNERPARTDISPLAYMODE||0)!==+(comp.DISPLAYMODE||0))continue;
   let x=c(f,'LOCATION.X'),y=c(f,'LOCATION.Y'),l=c(f,'PINLENGTH');const o=+(f.PINCONGLOMERATE||0)&3;
   x+=[l,0,-l,0][o];y+=[0,l,0,-l][o];
   pins.push({ref:refs.get(+f.OWNERINDEX),pin:f.DESIGNATOR,name:f.NAME,electrical:+(f.ELECTRICAL||0),point:pt(x,y),x,y,uid:f.UNIQUEID});
  }
  if(f.RECORD==='27'){
   let last;for(let i=1;i<=+f.LOCATIONCOUNT;i++){const p=pt(c(f,'X'+i),c(f,'Y'+i));if(last){segments.push([last,p]);join(last,p);}last=p;}
  }
  if(['25','17','18'].includes(f.RECORD)&&(!f.OWNERINDEX||+f.OWNERINDEX<0))named.push({name:f.TEXT||f.NAME,point:pt(c(f,'LOCATION.X'),c(f,'LOCATION.Y')),kind:f.RECORD});
  if(f.RECORD==='29')pt(c(f,'LOCATION.X'),c(f,'LOCATION.Y'));
 }
 for(const [ak,bk] of segments){const a=nodes.get(ak),b=nodes.get(bk);assert(a.x===b.x||a.y===b.y,'Non-orthogonal wire needs native review');for(const [k,p]of nodes)if(p.x>=Math.min(a.x,b.x)&&p.x<=Math.max(a.x,b.x)&&p.y>=Math.min(a.y,b.y)&&p.y<=Math.max(a.y,b.y))join(ak,k);}
 const names=new Map();for(const n of named){if(names.has(n.name))join(names.get(n.name),n.point);else names.set(n.name,n.point);}
 const nets=new Map();for(const [name,p]of names){const k=find(p);if(!nets.has(k))nets.set(k,[]);nets.get(k).push(name);}
 const duplicatePins=[];const seen=new Set();for(const p of pins){const key=p.ref+'.'+p.pin;if(seen.has(key))duplicatePins.push(key);seen.add(key);p.nets=nets.get(find(p.point))||[];}
 const shorts=[...nets.values()].filter(n=>n.length>1);
 return {pins,duplicatePins,shorts};
}
module.exports={graph};
if(require.main===module){
 const report={scope:'Saved-sheet geometric check, active display mode only; not full native ERC',sheets:{}};
 for(const name of ['01_Power_Control','02_Beam_Inputs','03_UI_Outputs']){
  const g=graph(records(path.join(root,'hardware/altium/sch',name+'.SchDoc')));report.sheets[name]=g;
  console.log(name,'active pins',g.pins.length,'duplicate active pins',JSON.stringify(g.duplicatePins),'shorts',JSON.stringify(g.shorts));
  for(const p of g.pins)if(!p.nets.length || /^C[1-6]$|^R13$|^R20$|^Q[234]$|^R1[456]$/.test(p.ref))console.log(p.ref+'.'+p.pin,p.name,JSON.stringify(p.nets),p.x/100000,p.y/100000);
 }
 if(process.argv.includes('--report'))fs.writeFileSync(path.join(root,'output/altium-reports/saved-connectivity.json'),JSON.stringify(report,null,2)+'\n');
}

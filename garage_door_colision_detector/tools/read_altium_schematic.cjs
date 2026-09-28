// Read-only Compound File / native ASCII schematic record reader.
// Deliberately has no CAD-writing functionality. Unknown encodings fail closed.
const fs = require('node:fs');
const assert = require('node:assert/strict');
function stream(file,name) {
 const b=fs.readFileSync(file); assert.equal(b.subarray(0,8).toString('hex'),'d0cf11e0a1b11ae1');
 const size=2**b.readUInt16LE(30), miniSize=2**b.readUInt16LE(32);
 const sector=i=>{assert(i>=0 && (i+2)*size<=b.length); return b.subarray((i+1)*size,(i+2)*size);};
 const u32s=b=>Array.from({length:b.length/4},(_,i)=>b.readUInt32LE(i*4));
 let difat=u32s(b.subarray(76,512)).filter(i=>i<0xfffffffa), next=b.readUInt32LE(68);
 for(let i=0;i<b.readUInt32LE(72);i++){const s=u32s(sector(next));difat.push(...s.slice(0,-1).filter(x=>x<0xfffffffa));next=s.at(-1);}
 const fat=difat.flatMap(i=>u32s(sector(i)));
 function chain(first,table,get){let chunks=[],seen=new Set(); for(let i=first;i!==0xfffffffe; i=table[i]){assert(Number.isInteger(i)&&i<0xfffffffa&&!seen.has(i),'Invalid/cyclic CFB chain'); seen.add(i);chunks.push(get(i));}return Buffer.concat(chunks);}
 const directory=chain(b.readUInt32LE(48),fat,sector), entries=[];
 for(let i=0;i+128<=directory.length;i+=128){const d=directory.subarray(i,i+128),n=d.readUInt16LE(64);if(!n)continue; entries.push({name:d.subarray(0,n-2).toString('utf16le'),type:d[66],start:d.readUInt32LE(116),size:Number(d.readBigUInt64LE(120))});}
 const entry=entries.find(e=>e.name===name);assert(entry,`Missing stream ${name}`);
 if(entry.size>=b.readUInt32LE(56))return chain(entry.start,fat,sector).subarray(0,entry.size);
 const root=entries.find(e=>e.type===5),mini=chain(root.start,fat,sector),miniFat=u32s(chain(b.readUInt32LE(60),fat,sector));
 return chain(entry.start,miniFat,i=>mini.subarray(i*miniSize,(i+1)*miniSize)).subarray(0,entry.size);
}
function records(file){
 const b=stream(file,'FileHeader'),records=[];
 for(let off=0;off<b.length;){assert(off+4<=b.length);const word=b.readUInt32LE(off),len=word&0xffffff,flags=word>>>24;off+=4;assert(len>0&&off+len<=b.length);assert.equal(flags,0,'Binary record needs native audit');
 const raw=b.subarray(off,off+len).toString('latin1').replace(/\0+$/,'');off+=len;
 const fields={};for(const p of raw.split('|')){const i=p.indexOf('=');if(i>=0)fields[p.slice(0,i).toUpperCase()]=p.slice(i+1);}
 records.push({index:records.length-1,fields,raw});
 }
 return records;
}
module.exports={stream,records};
if(require.main===module){const r=records(process.argv[2]);console.log(JSON.stringify(r,null,2));}

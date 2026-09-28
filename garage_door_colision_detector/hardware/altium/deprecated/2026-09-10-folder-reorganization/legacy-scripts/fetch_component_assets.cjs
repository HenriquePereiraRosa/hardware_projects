// Download original public KiCad CAD; do not substitute MKDS for MKDSN terminals.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const dir=path.resolve(__dirname,'../lib/part-specific');
fs.mkdirSync(dir,{recursive:true});
(async()=>{
 const name='Converter_DCDC_Murata_OKI-78SR_Vertical';
 const sources=[
 ['oki78sr.kicad_mod',`https://raw.githubusercontent.com/KiCad/kicad-footprints/master/Converter_DCDC.pretty/${name}.kicad_mod`],
 ['oki78sr.step','https://raw.githubusercontent.com/KiCad/kicad-packages3D/master/Converter_DCDC.3dshapes/Converter_DCDC_muRata_OKI-78SR_Vertical.step'],
 ['LICENSE.md','https://raw.githubusercontent.com/KiCad/kicad-footprints/master/LICENSE.md']
 ];
 const manifest=[];
 for(const [file,url] of sources){const r=await fetch(url);if(!r.ok)throw Error(`${r.status} ${url}`);const data=Buffer.from(await r.arrayBuffer());fs.writeFileSync(path.join(dir,file),data);manifest.push({file,url,sha256:crypto.createHash('sha256').update(data).digest('hex'),bytes:data.length});}
 fs.writeFileSync(path.join(dir,'sources.json'),JSON.stringify(manifest,null,2));console.log(manifest);
})().catch(e=>{console.error(e);process.exit(1)});

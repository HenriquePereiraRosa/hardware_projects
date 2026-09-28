const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {records}=require('C:/dev/projects/h/hardware_projects/garage_door_colision_detector/tools/read_altium_schematic.cjs');
const base='C:/dev/projects/h/hardware_projects/garage_door_colision_detector/hardware/altium/sch';
const expected={
 '00_Mounting_Overview.SchDoc':8,
 '01_Power_Control.SchDoc':2,
 '02_Beam_Inputs.SchDoc':10,
 '03_UI_Outputs.SchDoc':3,
 '04_Optical_Heads.SchDoc':6
};
let old=0,modern=0,wrong=0;
for(const [file,count] of Object.entries(expected)){
 const rows=records(path.join(base,file));
 const values=[];
 for(const o of rows){const f=o.fields;if(['16','18'].includes(f.RECORD))values.push(f.NAME);if(['17','25'].includes(f.RECORD))values.push(f.TEXT);}
 const a=values.filter(x=>x==='12V_SENSOR').length,b=values.filter(x=>x==='12V').length;
 const post=rows.find(x=>x.fields.UNIQUEID==='XOGWTSCW');
 let w=0;if(file==='01_Power_Control.SchDoc'){assert(post,'post-D6 port missing');w=post.fields.TEXT==='12V_FUSED'?1:0;assert(['12V_FUSED','12V_SENSOR','12V'].includes(post.fields.TEXT));}
 assert.equal(a+b+w,count,file+' unexpected rail count');old+=a;modern+=b;wrong+=w;
 assert.equal(rows.filter(x=>x.fields.RECORD==='25'&&x.fields.TEXT==='12V_FUSED').length<=1,true);
}
assert((old===28&&modern===0&&wrong===1)||(old===0&&modern===29&&wrong===0),'partial or unexpected rail rename');
const power=records(path.join(base,'01_Power_Control.SchDoc'));
const powerNames=power.filter(x=>['17','25'].includes(x.fields.RECORD)).map(x=>x.fields.TEXT);
const logic=powerNames.filter(x=>x==='5V_LOGIC').length;
const five=powerNames.filter(x=>x==='5V').length;
const mcu=powerNames.filter(x=>x==='5V_MCU').length;
assert((logic===3&&five===0)||(logic===0&&five===3),'partial or unexpected 5 V rail rename');
assert.equal(mcu,2,'5V_MCU must remain on the ESP32 side of JP1');
if(modern===29&&five===3) console.log('PASS: main rails are 12V and 5V; jumper output remains 5V_MCU.');
else if(modern===29&&logic===3) console.log('PASS: 12V is normalized; 5V_LOGIC is ready to rename. Run FixPowerRailNames again.');
else console.log('PASS: guarded pre-fix state found. Run FixPowerRailNames.');

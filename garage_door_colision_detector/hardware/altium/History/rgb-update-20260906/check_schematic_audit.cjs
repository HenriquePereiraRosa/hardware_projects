// Read-only checks against exports from Altium's native schematic database.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const pins = new Map(), components = new Map(), points = new Map(), segments = [], names = [];
function point(sheet,x,y) { const key = `${sheet}:${x},${y}`; if (!points.has(key)) points.set(key,{x:+x,y:+y,sheet,parent:key}); return key; }
function find(k) { const p=points.get(k); return p.parent===k?k:(p.parent=find(p.parent)); }
function union(a,b) { points.get(find(a)).parent=find(b); }
for (const sheet of ['01_Power_Control','02_Beam_Inputs','03_UI_Outputs']) {
  let start;
  for(const line of fs.readFileSync(path.join(root,sheet+'.SchDoc.audit.txt'),'utf8').trim().split(/\r?\n/)) {
    const a=line.split('|');
    if(a[0]==='COMP') { assert(!components.has(a[1]),'Duplicate reference '+a[1]); components.set(a[1],a[2]); }
    if(a[0]==='PIN') { const k=point(sheet,a[4],a[5]); const ref=a[1]+'.'+a[2]; if(pins.has(ref)) assert.equal(pins.get(ref),k,'Conflicting duplicate pin '+ref); pins.set(ref,k); }
    if(a[0]==='NET') names.push([a[1],point(sheet,a[2],a[3])]);
    if(a[0]==='WIRE') { const k=point(sheet,a[2],a[3]); if(a[1]==='1') start=k; else { segments.push([start,k]); union(start,k); start=k; } }
  }
}
// Endpoints lying on a wire connect; mere interior/interior crossings do not.
for(const [a,b] of segments) {
  const p=points.get(a),q=points.get(b);
  assert(p.x===q.x||p.y===q.y,'Non-orthogonal wire');
  for(const [k,r] of points) if(r.sheet===p.sheet && r.x>=Math.min(p.x,q.x)&&r.x<=Math.max(p.x,q.x)&&r.y>=Math.min(p.y,q.y)&&r.y<=Math.max(p.y,q.y)) union(a,k);
}
const named=new Map();
for(const [name,k] of names) { if(named.has(name)) union(named.get(name),k); else named.set(name,k); }
const byRoot=new Map();
for(const [name,k] of named) { const r=find(k); if(!byRoot.has(r)) byRoot.set(r,[]); byRoot.get(r).push(name); }
for(const ns of byRoot.values()) assert.equal(ns.length,1,'Shorted named nets: '+ns.join(', '));
let checks=0;
function net(pin,name) { assert(pins.has(pin),'Missing pin '+pin); assert(named.has(name),'Missing net '+name); assert.equal(find(pins.get(pin)),find(named.get(name)),`${pin} not on ${name}`); checks++; }
function connected(a,b) { assert.equal(find(pins.get(a)),find(pins.get(b)),`${a} not connected to ${b}`); checks++; }
assert.equal([...pins.keys()].filter(k=>k.startsWith('A1.')).length,38);
for(const [p,n] of Object.entries({J2_1:'3V3',J2_19:'5V_MCU',J2_14:'GND',J3_1:'GND',J3_7:'GND',J2_7:'BEAM1_GPIO32',J2_8:'BEAM2_GPIO33',J2_5:'BEAM3_GPIO34',J2_6:'BEAM4_GPIO35',J2_9:'LED_GREEN_GPIO25',J2_10:'LED_RED_GPIO26',J2_11:'LED_AMBER_GPIO27',J2_12:'BUZZER_GPIO14',J2_15:'BUTTON_GPIO13'})) net('A1.'+p,n);
connected('J1.1','F1.1'); connected('F1.2','D6.1'); net('D6.2','12V_SENSOR'); net('A2.1','12V_SENSOR'); net('A2.2','GND'); net('A2.3','5V_LOGIC'); net('JP1.1','5V_LOGIC'); net('JP1.2','5V_MCU');
for(const [ref,p,n] of [['D1',1,'GND'],['D1',2,'12V_SENSOR'],['C1',1,'12V_SENSOR'],['C1',2,'GND'],['C5',1,'5V_LOGIC'],['C5',2,'GND']]) net(`${ref}.${p}`,n);
const channels=[['J2','U2','R5','R6','R7','C2',32],['J3','U3','R8','R9','R10','C3',33],['J4','U4','R11','R12','R13','C4',34],['J6','U5','R18','R19','R20','C6',35]];
channels.forEach(([j,u,r,rp,rs,c,g],i)=>{ const n=i+1; net(j+'.1','12V_SENSOR'); net(j+'.2','GND'); net(j+'.3',`BEAM${n}_SIG`); net(u+'.2',`BEAM${n}_SIG`); net(u+'.1',`BEAM${n}_LED_A`); connected(r+'.2',u+'.1'); net(r+'.1','12V_SENSOR'); net(u+'.3','GND'); net(u+'.4',`BEAM${n}_RAW`); net(rp+'.1','3V3'); net(rp+'.2',`BEAM${n}_RAW`); net(rs+'.1',`BEAM${n}_RAW`); net(rs+'.2',`BEAM${n}_GPIO${g}`); net(c+'.2',`BEAM${n}_GPIO${g}`); net(c+'.1','GND'); });
net('Q2.1','BUZZER_BASE'); net('Q2.2','GND'); net('Q2.3','BUZZER_LOW'); net('D5.1','BUZZER_LOW'); net('D5.2','3V3');
console.log(`PASS: ${components.size} unique components; 38 ESP32 pins; ${checks} connection assertions; no shorts between named nets.`);
console.log('This checks exported connectivity, not Altium ERC, footprint pin mapping, electrical ratings or physical safety performance.');

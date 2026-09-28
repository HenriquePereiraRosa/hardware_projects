// Static package checks only. This is NOT an Altium compiler/runtime test.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = __dirname;
const pas = fs.readFileSync(path.join(root, 'PCBFirstPass.pas'), 'utf8');
const project = fs.readFileSync(path.join(root, 'PCBFirstPass.PrjScr'), 'utf8');
assert(project.includes('StartProcName=PCBFirstPass.pas>RunPCBFirstPass'));
assert(/Procedure RunPCBFirstPass;/.test(pas));
assert(!pas.includes("C:\\dev\\projects\\h\\garage_door_colision_detector\\"));
assert(pas.includes("TargetPin(SC,'J2_5','IO34')"));
assert(pas.includes("TargetPin(SC,'J2_6','IO35')"));
assert(pas.includes("TargetPin(LC,'J2_5','IO34')"));
assert(pas.includes("TargetPin(LC,'J2_6','IO35')"));
assert(pas.includes('Require(Not SD.Modified'));
assert(pas.includes('Seen.IndexOf(P.Designator)<0'));
assert(pas.includes('Require(Total=38'));
assert(pas.indexOf("BackupFile(LIB_FILE") < pas.indexOf('ApplyInputs(L,LC'));
assert(pas.includes('Require(Signature(C)=BeforeText'));
assert(!/RemoveSchObject|UnRegisterSchObject|AddPCBObject|RemovePCBObject|MoveByXY|MoveToXY|DeleteFile|eNoERC/i.test(pas));
const pcb = pas.slice(pas.indexOf('Procedure AuditPCB;'), pas.indexOf('Procedure RunPCBFirstPass;'));
assert(!/DoFileSave|DoSafeChangeFileNameAndSave|Modified\s*:=|PCBObjectFactory|PCBServer.PreProcess/.test(pcb));
const properties = [...pas.matchAll(/\b(?:P34|P35)\.(\w+)\s*:=/g)].map(m => m[1]);
assert.deepEqual([...new Set(properties)], ['Electrical']);
// Lexical sanity check: remove Pascal comments and strings, check brackets and
// Begin/Try/Case blocks. This intentionally makes no claims about API availability.
let tokens = pas.replace(/\{[\s\S]*?\}|\(\*[\s\S]*?\*\)|\/\/[^\r\n]*/g, '');
tokens = tokens.replace(/'(?:''|[^'])*'/g, "''");
assert.equal((tokens.match(/\(/g) || []).length, (tokens.match(/\)/g) || []).length);
const stack = [];
for (const m of tokens.matchAll(/\b(Begin|Try|Case|End)\b/gi)) {
  if (m[1].toLowerCase() === 'end') assert(stack.pop(), 'Unmatched End');
  else stack.push(m[1]);
}
assert.equal(stack.length, 0, 'Unclosed Pascal block');
console.log('PASS: startup, scope, backup order, pin guards and lexical checks.');
console.log('NOT TESTED: Altium compilation, native execution, ERC, PCB changes or 3D correctness.');

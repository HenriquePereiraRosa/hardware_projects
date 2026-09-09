const fs = require('node:fs');
const path = require('node:path');
const base = fs.readFileSync(path.join(__dirname,'MacroRealUpdate.pas'),'utf8');
// Reuse only known schematic helpers, not old circuit-rebuild entry points.
const helpers = base.slice(0,base.indexOf('Function FindPin(')).replace('(OldO.ObjectId = eBus) Or','(OldO.ObjectId = eSheetSymbol) Or (OldO.ObjectId = eBus) Or');
const start = base.indexOf('Procedure AuditSheet(');
const audit = base.slice(start,base.indexOf('\nProcedure ',start+1));
if(!helpers || !audit || audit.length>5000) throw Error('Helper boundaries changed');
fs.writeFileSync(path.join(__dirname,'HierarchyUpdate.pas'),helpers+'\n'+audit+'\n'+fs.readFileSync(path.join(__dirname,'HierarchyUpdate.inc.pas'),'utf8'));

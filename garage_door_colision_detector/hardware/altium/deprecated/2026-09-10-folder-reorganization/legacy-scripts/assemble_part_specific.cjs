const fs=require('node:fs'),path=require('node:path');
const read=f=>fs.readFileSync(path.join(__dirname,f),'utf8');
// Helpers are copied, not executed. Only ReplacePlaceholderSymbols is the entry point.
const macro=read('MacroRealUpdate.pas');
const hierarchy=read('HierarchyUpdate.inc.pas').split('Procedure UpdateHierarchy;')[0];
fs.writeFileSync(path.join(__dirname,'PartSpecificSymbols.pas'),macro+'\n'+hierarchy+'\n'+read('PartSpecificSymbols.inc.pas'));

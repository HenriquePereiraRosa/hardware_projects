const fs=require('node:fs'),path=require('node:path');
const read=f=>fs.readFileSync(path.join(__dirname,f),'utf8');
fs.writeFileSync(path.join(__dirname,'CelestialApply.pas'),read('CelestialUpdate.pas')+'\n'+read('CelestialApply.inc.pas'));
const pinSignature=read('CelestialApply.inc.pas').split('Procedure BoardPinSignature')[1].split('Procedure UpdateExistingBoardPackages')[0];
fs.writeFileSync(path.join(__dirname,'CelestialNative.pas'),read('CelestialUpdate.pas')+'\nProcedure BoardPinSignature'+pinSignature+'\n'+read('CelestialNative.inc.pas'));
fs.writeFileSync(path.join(__dirname,'CelestialSafeTransfer.pas'),read('CelestialUpdate.pas')+'\n'+read('CelestialApply.inc.pas'));
fs.writeFileSync(path.join(__dirname,'CelestialRegister.pas'),read('CelestialUpdate.pas')+'\nProcedure BoardPinSignature'+pinSignature+'\n'+read('CelestialRegister.inc.pas'));

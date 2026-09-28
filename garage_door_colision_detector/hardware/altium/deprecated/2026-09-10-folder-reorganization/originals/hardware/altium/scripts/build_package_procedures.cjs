// Translate downloaded KiCad pad centres/sizes and silkscreen to native Altium API calls.
// Rectangular pads retain upstream dimensions; rounded corners are not transferred.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const names=['SOT-23','R_0805_2012Metric','C_0805_2012Metric','D_SOD-123'];
let out='\nProcedure PopulateVerifiedPackage(C, PatternName);\nVar Body : IPCB_ComponentBody; Model : IPCB_Model; ModelFile : String;\nBegin\n';
for(const name of names){
 const txt=fs.readFileSync(path.join(root,'lib/upstream-kicad',name+'.kicad_mod'),'utf8');
 out+=`    If PatternName='KICAD_${name}' Then Begin\n`;
 let count=0;
 for(const m of txt.matchAll(/\(pad (\d+) smd \w+ \(at ([-.\d]+) ([-.\d]+)\) \(size ([-.\d]+) ([-.\d]+)\)/g)){
  out+=`        PackagePad(C,'${m[1]}',${+m[2]},${-m[3]},${+m[4]},${+m[5]});\n`;count++;
 }
 if(count!==(name==='SOT-23'?3:2))throw Error('Pad parse failure '+name);
 for(const m of txt.matchAll(/\(fp_line \(start ([-.\d]+) ([-.\d]+)\) \(end ([-.\d]+) ([-.\d]+)\) \(layer F.SilkS\)/g))
  out+=`        TerminalTrack(C,${+m[1]},${-m[2]},${+m[3]},${-m[4]});\n`;
 out+=`        ModelFile:=ROOT+'lib\\upstream-kicad\\${name}.step';\n    End;\n`;
}
out+=`    If ModelFile='' Then Exit;
    Body:=PCBServer.PCBObjectFactory(eComponentBodyObject,eNoDimension,eCreate_Default);
    Model:=Body.ModelFactory_FromFilename(ModelFile,False);
    If Model=Nil Then Begin ShowMessage('Missing STEP '+ModelFile); Abort; End;
    Model.Embed:=True; Body.Model:=Model; Body.SetState_FromModel;
    Body.Layer:=eMechanical1; C.AddPCBObject(Body);
End;
`;
fs.writeFileSync(path.join(__dirname,'PackageProcedures.inc.pas'),out);

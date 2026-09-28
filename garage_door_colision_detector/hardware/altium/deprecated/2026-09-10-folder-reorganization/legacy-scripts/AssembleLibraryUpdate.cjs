const fs=require('node:fs'),path=require('node:path');
const dir=__dirname;
const helper=`
Procedure PackagePad(C,Name,X,Y,SX,SY);
Var P : IPCB_Pad;
Begin
 P:=PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
 P.Name:=Name; P.X:=MMsToCoord(X); P.Y:=MMsToCoord(Y); P.Layer:=eTopLayer;
 P.HoleSize:=0; P.TopShape:=eRectangular; P.TopXSize:=MMsToCoord(SX); P.TopYSize:=MMsToCoord(SY);
 C.AddPCBObject(P);
End;
`;
fs.writeFileSync(path.join(dir,'LibraryBoardUpdate.pas'),fs.readFileSync(path.join(dir,'MacroRealUpdate.pas'),'utf8')+helper+fs.readFileSync(path.join(dir,'PackageProcedures.inc.pas'),'utf8')+fs.readFileSync(path.join(dir,'LibraryBoardOperations.inc.pas'),'utf8'));

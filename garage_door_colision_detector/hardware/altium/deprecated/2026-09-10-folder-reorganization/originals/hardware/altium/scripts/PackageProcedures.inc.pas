
Procedure PopulateVerifiedPackage(C, PatternName);
Var Body : IPCB_ComponentBody; Model : IPCB_Model; ModelFile : String;
Begin
    If PatternName='KICAD_SOT-23' Then Begin
        PackagePad(C,'1',-1,0.95,0.9,0.8);
        PackagePad(C,'2',-1,-0.95,0.9,0.8);
        PackagePad(C,'3',1,0,0.9,0.8);
        TerminalTrack(C,0.76,-1.58,0.76,-0.65);
        TerminalTrack(C,0.76,1.58,0.76,0.65);
        TerminalTrack(C,0.76,1.58,-1.4,1.58);
        TerminalTrack(C,0.76,-1.58,-0.7,-1.58);
        ModelFile:=ROOT+'lib\upstream-kicad\SOT-23.step';
    End;
    If PatternName='KICAD_R_0805_2012Metric' Then Begin
        PackagePad(C,'1',-0.9125,0,1.025,1.4);
        PackagePad(C,'2',0.9125,0,1.025,1.4);
        TerminalTrack(C,-0.227064,0.735,0.227064,0.735);
        TerminalTrack(C,-0.227064,-0.735,0.227064,-0.735);
        ModelFile:=ROOT+'lib\upstream-kicad\R_0805_2012Metric.step';
    End;
    If PatternName='KICAD_C_0805_2012Metric' Then Begin
        PackagePad(C,'1',-0.95,0,1,1.45);
        PackagePad(C,'2',0.95,0,1,1.45);
        TerminalTrack(C,-0.261252,0.735,0.261252,0.735);
        TerminalTrack(C,-0.261252,-0.735,0.261252,-0.735);
        ModelFile:=ROOT+'lib\upstream-kicad\C_0805_2012Metric.step';
    End;
    If PatternName='KICAD_D_SOD-123' Then Begin
        PackagePad(C,'1',-1.65,0,0.9,1.2);
        PackagePad(C,'2',1.65,0,0.9,1.2);
        TerminalTrack(C,-2.25,1,-2.25,-1);
        TerminalTrack(C,-2.25,-1,1.65,-1);
        TerminalTrack(C,-2.25,1,1.65,1);
        ModelFile:=ROOT+'lib\upstream-kicad\D_SOD-123.step';
    End;
    If ModelFile='' Then Exit;
    Body:=PCBServer.PCBObjectFactory(eComponentBodyObject,eNoDimension,eCreate_Default);
    Model:=Body.ModelFactory_FromFilename(ModelFile,False);
    If Model=Nil Then Begin ShowMessage('Missing STEP '+ModelFile); Abort; End;
    Model.Embed:=True; Body.Model:=Model; Body.SetState_FromModel;
    Body.Layer:=eMechanical1; C.AddPCBObject(Body);
End;

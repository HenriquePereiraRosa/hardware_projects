{ Normalize the distributed rails without moving components or touching PCB.
  Intended topology: J1 raw input -> F1 -> D6 -> 12V -> A2 -> 5V -> JP1 -> 5V_MCU.
  The short F1-to-D6 node is deliberately unnamed. C1/C5 polarity is not changed. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Const SHEET_COUNT=5;
Var Log : TStringList; RunDir : String;
    ServerDocs : Array[0..4] Of IServerDocument;
    Docs : Array[0..4] Of ISch_Document;
    Files : Array[0..4] Of String;
    Expected : Array[0..4] Of Integer;

Procedure Need(Condition, MessageText);
Begin
 If Not Condition Then Begin
  If Log<>Nil Then Begin Log.Add('STOP|'+MessageText); If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt'); End;
  ShowMessage(MessageText); Abort;
 End;
End;

Procedure Setup;
Begin
 Files[0]:='00_Mounting_Overview.SchDoc'; Expected[0]:=8;
 Files[1]:='01_Power_Control.SchDoc'; Expected[1]:=2;
 Files[2]:='02_Beam_Inputs.SchDoc'; Expected[2]:=10;
 Files[3]:='03_UI_Outputs.SchDoc'; Expected[3]:=3;
 Files[4]:='04_Optical_Heads.SchDoc'; Expected[4]:=6;
End;

Procedure OpenAll;
Var N : Integer;
Begin
 For N:=0 To SHEET_COUNT-1 Do Begin
  Need(FileExists(BASE+'sch\'+Files[N]),'Missing schematic '+Files[N]);
  ServerDocs[N]:=Client.OpenDocument('SCH',BASE+'sch\'+Files[N]);
  Need(ServerDocs[N]<>Nil,'Could not open '+Files[N]); Client.ShowDocument(ServerDocs[N]); ServerDocs[N].Focus;
  Need(Not ServerDocs[N].Modified,'Use File > Save All before running. Unsaved sheet: '+Files[N]);
  Docs[N]:=SchServer.GetCurrentSchDocument; Need(Docs[N]<>Nil,'No schematic document for '+Files[N]);
 End;
End;

Procedure BackupOne(FileName);
Var A,B : TFileStream;
Begin
 Need(Not FileExists(RunDir+FileName),'Backup already exists: '+FileName);
 A:=TFileStream.Create(BASE+'sch\'+FileName,fmOpenRead Or fmShareDenyWrite);
 Try
  B:=TFileStream.Create(RunDir+FileName,fmCreate);
  Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Backup length mismatch: '+FileName); Finally B.Free; End;
 Finally A.Free; End;
 Log.Add('BACKUP|'+FileName); Log.SaveToFile(RunDir+'report.txt');
End;

Procedure CountRailObjects(D : ISch_Document; Var OldCount,NewCount : Integer);
Var I,SI : ISch_Iterator; O : ISch_GraphicalObject; E : ISch_SheetEntry;
Begin
 OldCount:=0; NewCount:=0; I:=D.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   If (O.ObjectId=ePowerObject) Or (O.ObjectId=eNetLabel) Then Begin
    If O.Text='12V_SENSOR' Then Inc(OldCount) Else If O.Text='12V' Then Inc(NewCount);
   End;
   If O.ObjectId=ePort Then Begin
    If O.Name='12V_SENSOR' Then Inc(OldCount) Else If O.Name='12V' Then Inc(NewCount);
   End;
   If O.ObjectId=eSheetSymbol Then Begin
    SI:=O.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSheetEntry));
    Try
     E:=SI.FirstSchObject;
     While E<>Nil Do Begin
      If E.Name='12V_SENSOR' Then Inc(OldCount) Else If E.Name='12V' Then Inc(NewCount);
      E:=SI.NextSchObject;
     End;
    Finally O.SchIterator_Destroy(SI); End;
   End;
   O:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
End;

Procedure CountFiveVoltObjects(D : ISch_Document; Var OldCount,NewCount,McuCount : Integer);
Var I,SI : ISch_Iterator; O : ISch_GraphicalObject; E : ISch_SheetEntry; S : String;
Begin
 OldCount:=0; NewCount:=0; McuCount:=0; I:=D.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   S:='';
   If (O.ObjectId=ePowerObject) Or (O.ObjectId=eNetLabel) Then S:=O.Text;
   If O.ObjectId=ePort Then S:=O.Name;
   If S='5V_LOGIC' Then Inc(OldCount) Else If S='5V' Then Inc(NewCount) Else If S='5V_MCU' Then Inc(McuCount);
   If O.ObjectId=eSheetSymbol Then Begin
    SI:=O.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSheetEntry));
    Try
     E:=SI.FirstSchObject;
     While E<>Nil Do Begin
      If E.Name='5V_LOGIC' Then Inc(OldCount) Else If E.Name='5V' Then Inc(NewCount) Else If E.Name='5V_MCU' Then Inc(McuCount);
      E:=SI.NextSchObject;
     End;
    Finally O.SchIterator_Destroy(SI); End;
   End;
   O:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
End;

Function FindPostDiodePort(D : ISch_Document) : ISch_PowerObject;
Var I : ISch_Iterator; P : ISch_PowerObject; N : Integer;
Begin
 Result:=Nil; N:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePowerObject));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   If P.UniqueId='XOGWTSCW' Then Begin
    Inc(N); Need((P.Text='12V_FUSED') Or (P.Text='12V_SENSOR') Or (P.Text='12V'),'Unexpected post-D6 rail name.');
    Need((P.Location.X=44100000) And (P.Location.Y=64100000),'Post-D6 power port moved.'); Result:=P;
   End;
   P:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Need(N=1,'Post-D6 power port is missing or duplicated.');
End;

Procedure CheckReferenceWires(D : ISch_Document);
Var I : ISch_Iterator; W : ISch_Wire; FuseWire,DiodeWire : Integer;
Begin
 FuseWire:=0; DiodeWire:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eWire));
 Try
  W:=I.FirstSchObject;
  While W<>Nil Do Begin
   If W.UniqueId='GANFVLZL' Then Begin
    Need((W.VerticesCount=2) And (W.GetState_Vertex(1).X=28000000) And (W.GetState_Vertex(1).Y=62200000) And
      (W.GetState_Vertex(2).X=36500000) And (W.GetState_Vertex(2).Y=62200000),'F1-to-D6 wire moved.'); Inc(FuseWire);
   End;
   If W.UniqueId='DRKSDPHA' Then Begin
    Need((W.VerticesCount=3) And (W.GetState_Vertex(1).X=41500000) And (W.GetState_Vertex(1).Y=62200000) And
      (W.GetState_Vertex(3).X=51800000) And (W.GetState_Vertex(3).Y=62200000),'D6-to-A2 wire moved.'); Inc(DiodeWire);
   End;
   W:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Need((FuseWire=1) And (DiodeWire=1),'Reference 12 V wires missing or duplicated.');
End;

Function ObsoleteFuseLabel(D : ISch_Document) : ISch_NetLabel;
Var I : ISch_Iterator; L : ISch_NetLabel; N : Integer;
Begin
 Result:=Nil; N:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eNetLabel));
 Try
  L:=I.FirstSchObject;
  While L<>Nil Do Begin If L.Text='12V_FUSED' Then Begin Inc(N); Result:=L; End; L:=I.NextSchObject; End;
 Finally D.SchIterator_Destroy(I); End;
 Need(N<=1,'Multiple 12V_FUSED net labels exist.');
 If N=1 Then Need((Result.Location.X=32000000) And (Result.Location.Y=62200000),'Unexpected 12V_FUSED label location.');
End;

Procedure RenameSheet(D : ISch_Document; FileName : String);
Var I,SI : ISch_Iterator; O : ISch_GraphicalObject; E : ISch_SheetEntry; N : Integer;
Begin
 N:=0; I:=D.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   If ((O.ObjectId=ePowerObject) Or (O.ObjectId=eNetLabel)) And (O.Text='12V_SENSOR') Then Begin O.Text:='12V'; Inc(N); End;
   If (O.ObjectId=ePort) And (O.Name='12V_SENSOR') Then Begin O.Name:='12V'; Inc(N); End;
   If O.ObjectId=eSheetSymbol Then Begin
    SI:=O.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSheetEntry));
    Try
     E:=SI.FirstSchObject;
     While E<>Nil Do Begin If E.Name='12V_SENSOR' Then Begin E.Name:='12V'; Inc(N); End; E:=SI.NextSchObject; End;
    Finally O.SchIterator_Destroy(SI); End;
   End;
   O:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Log.Add('RENAMED|'+FileName+'|'+IntToStr(N)+' occurrences|12V_SENSOR|12V');
End;

Procedure RenameFiveVolt(D : ISch_Document; FileName : String);
Var I,SI : ISch_Iterator; O : ISch_GraphicalObject; E : ISch_SheetEntry; N : Integer;
Begin
 N:=0; I:=D.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   If ((O.ObjectId=ePowerObject) Or (O.ObjectId=eNetLabel)) And (O.Text='5V_LOGIC') Then Begin O.Text:='5V'; Inc(N); End;
   If (O.ObjectId=ePort) And (O.Name='5V_LOGIC') Then Begin O.Name:='5V'; Inc(N); End;
   If O.ObjectId=eSheetSymbol Then Begin
    SI:=O.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSheetEntry));
    Try
     E:=SI.FirstSchObject;
     While E<>Nil Do Begin If E.Name='5V_LOGIC' Then Begin E.Name:='5V'; Inc(N); End; E:=SI.NextSchObject; End;
    Finally O.SchIterator_Destroy(SI); End;
   End;
   O:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 If N>0 Then Log.Add('RENAMED|'+FileName+'|'+IntToStr(N)+' occurrences|5V_LOGIC|5V');
End;

Procedure FixPowerRailNames;
Var N,OldCount,NewCount,FiveOld,FiveNew,FiveMcu,TotalFiveOld,TotalFiveNew,TotalFiveMcu : Integer; P : ISch_PowerObject; L : ISch_NetLabel; S : String;
Begin
 Log:=TStringList.Create; RunDir:='';
 Try
  Setup; OpenAll; CheckReferenceWires(Docs[1]); P:=FindPostDiodePort(Docs[1]); L:=ObsoleteFuseLabel(Docs[1]);
  TotalFiveOld:=0; TotalFiveNew:=0; TotalFiveMcu:=0;
  For N:=0 To SHEET_COUNT-1 Do Begin
   CountRailObjects(Docs[N],OldCount,NewCount);
   If N=1 Then Need((OldCount+NewCount+Ord(P.Text='12V_FUSED'))=Expected[N],'Unexpected 12 V rail-object count in '+Files[N])
   Else Need((OldCount+NewCount)=Expected[N],'Unexpected 12 V rail-object count in '+Files[N]);
   CountFiveVoltObjects(Docs[N],FiveOld,FiveNew,FiveMcu);
   TotalFiveOld:=TotalFiveOld+FiveOld; TotalFiveNew:=TotalFiveNew+FiveNew; TotalFiveMcu:=TotalFiveMcu+FiveMcu;
  End;
  Need((TotalFiveOld+TotalFiveNew)=3,'Unexpected main 5 V rail-object count.');
  Need(TotalFiveMcu=2,'Unexpected 5V_MCU jumper-side rail-object count.');
  S:=BASE+'History\'; If Not DirectoryExists(S) Then Need(CreateDir(S),'Cannot create History folder.');
  RunDir:=S+'power-rail-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
  Need(Not DirectoryExists(RunDir),'Run folder already exists.'); Need(CreateDir(RunDir),'Cannot create run folder.');
  Log.Add('START|J1 12V_IN -> F1 -> D6 -> 12V -> A2 -> 5V -> JP1 -> 5V_MCU'); For N:=0 To SHEET_COUNT-1 Do BackupOne(Files[N]);
  For N:=0 To SHEET_COUNT-1 Do Begin
   SchServer.ProcessControl.PreProcess(Docs[N],'Normalize 12 V and 5 V rail names');
   Try
    RenameSheet(Docs[N],Files[N]);
    RenameFiveVolt(Docs[N],Files[N]);
    If N=1 Then Begin
     If P.Text<>'12V' Then Begin Log.Add('RENAMED|post-D6 power port|'+P.Text+'|12V'); P.Text:='12V'; End;
     If L<>Nil Then Begin Docs[N].RemoveSchObject(L); Log.Add('REMOVED|unused 12V_FUSED local label'); End;
    End;
   Finally SchServer.ProcessControl.PostProcess(Docs[N],'Normalize 12 V and 5 V rail names'); End;
   Docs[N].GraphicallyInvalidate; ServerDocs[N].Modified:=True;
   Need(ServerDocs[N].DoFileSave('SCHBinary5.0'),'Save failed: '+Files[N]); Log.Add('SAVED|'+Files[N]); Log.SaveToFile(RunDir+'report.txt');
  End;
  Log.Add('PRESERVED|components, pins, wires, C1/C5 orientation, PCB and installation sheet');
  Log.Add('COMPLETE|Main rails are 12V and 5V; 5V_MCU remains after JP1. Validate PCB Project.'); Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('Power rails normalized.'+#13#10+'12V -> A2 -> 5V -> JP1 -> 5V_MCU'+#13#10+'Now Validate PCB Project.');
 Except
  If (Log<>Nil) And (RunDir<>'') Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  Log.Free; Raise;
 End;
 Log.Free;
End;

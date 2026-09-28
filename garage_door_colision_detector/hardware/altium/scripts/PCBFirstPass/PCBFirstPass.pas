{ PCB-first pass 1. Run in Altium Designer, not PowerShell.
  Changes ONLY GPIO34/35 Electrical to Input in A1 and its local SchLib.
  PCB access is read-only. No wire, model, position, footprint or ERC-rule edits.
  Save All first. A fresh backup and report folder is created on every run.
  Prepared against documented/native APIs; not executed in Altium by the author.
}
Const
 BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
 POWER_FILE='sch\01_Power_Control.SchDoc';
 LIB_FILE='lib\ESP32-DEVKITC-32E\ESP32-DEVKITC-32E.SchLib';
Var
 Log : TStringList;
 RunDir : String;

Procedure Require(Condition, MessageText);
Begin
 If Not Condition Then Begin
  Log.Add('STOP|'+MessageText);
  ShowMessage(MessageText);
  Abort;
 End;
End;

Procedure RecordLine(S);
Begin
 Log.Add(S);
 Log.SaveToFile(RunDir+'report.txt');
End;

Function OpenNative(Kind, FileName) : IServerDocument;
Var SD : IServerDocument;
Begin
 Require(FileExists(BASE+FileName),'Missing file: '+BASE+FileName);
 SD:=Client.OpenDocument(Kind,BASE+FileName);
 Require(SD<>Nil,'Cannot open: '+FileName);
 Client.ShowDocument(SD); SD.Focus;
 Require(Not SD.Modified,'Save All before running. Unsaved document: '+FileName);
 Result:=SD;
End;

Procedure BackupFile(SourceName, TargetName);
Var SourceStream, TargetStream : TFileStream;
Begin
 Require(Not FileExists(RunDir+TargetName),'Refusing to overwrite a backup.');
 SourceStream:=TFileStream.Create(BASE+SourceName,fmOpenRead Or fmShareDenyWrite);
 Try
  Require(SourceStream.Size>0,'Source file is empty: '+SourceName);
  TargetStream:=TFileStream.Create(RunDir+TargetName,fmCreate);
  Try
   TargetStream.CopyFrom(SourceStream,0);
   Require(TargetStream.Size=SourceStream.Size,'Backup size check failed.');
  Finally TargetStream.Free; End;
 Finally SourceStream.Free; End;
 RecordLine('BACKUP|'+SourceName+'|'+RunDir+TargetName);
End;

Function PlacedESP(D) : ISch_Component;
Var I : ISch_Iterator; C : ISch_Component; N : Integer;
Begin
 Result:=Nil; N:=0;
 I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin
   If C.Designator.Text='A1' Then Begin Result:=C; N:=N+1; End;
   C:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Require(N=1,'Expected exactly one A1 in the power schematic.');
 Require(Result.LibReference='ESP32-DEVKITC-32E','A1 is not the expected DevKit. No changes.');
End;

Function LibraryESP(L) : ISch_Component;
Var I : ISch_Iterator; C : ISch_Component; N : Integer;
Begin
 Result:=Nil; N:=0;
 I:=L.SchLibIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin
   If C.LibReference='ESP32-DEVKITC-32E' Then Begin Result:=C; N:=N+1; End;
   C:=I.NextSchObject;
  End;
 Finally L.SchIterator_Destroy(I); End;
 Require(N=1,'Expected exactly one ESP32-DEVKITC-32E library component.');
End;

Function TargetPin(C, NumberText, NameText) : ISch_Pin;
Var I : ISch_Iterator; P : ISch_Pin; N, Total : Integer; Seen : TStringList;
Begin
 Result:=Nil; N:=0; Total:=0; Seen:=TStringList.Create;
 I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   Require(Seen.IndexOf(P.Designator)<0,'Duplicate DevKit pin number: '+P.Designator);
   Seen.Add(P.Designator); Total:=Total+1;
   If P.Designator=NumberText Then Begin
    Require(P.Name=NameText,'Unexpected name for pin '+NumberText);
    Require((P.Electrical=eElectricIO) Or (P.Electrical=eElectricInput),
      'Unexpected electrical type for '+NumberText+'; manual review required.');
    Result:=P; N:=N+1;
   End;
   P:=I.NextSchObject;
  End;
 Finally C.SchIterator_Destroy(I); Seen.Free; End;
 Require(Total=38,'Expected 38 unique DevKit pin objects; found '+IntToStr(Total));
 Require(N=1,'Missing or duplicate pin '+NumberText);
End;

Function Signature(C) : String;
Var I : ISch_Iterator; P : ISch_Pin; M : ISch_Implementation;
 O : ISch_GraphicalObject; T : TStringList; E : Integer;
Begin
 T:=TStringList.Create;
 Try
  T.Add('IDENTITY|'+C.UniqueId+'|'+C.LibReference+'|'+C.Designator.Text);
  I:=C.SchIterator_Create; I.SetState_FilterAll;
  Try
   O:=I.FirstSchObject;
   While O<>Nil Do Begin
    If O.ObjectId=ePin Then Begin
     P:=O; E:=Ord(P.Electrical);
     { Only these two electrical-type changes are allowed by the signature. }
     If (P.Designator='J2_5') Or (P.Designator='J2_6') Then E:=-1;
     T.Add('PIN|'+P.Designator+'|'+P.Name+'|'+IntToStr(P.Location.X)+'|'+
       IntToStr(P.Location.Y)+'|'+IntToStr(Ord(P.Orientation))+'|'+
       IntToStr(P.PinLength)+'|'+IntToStr(P.OwnerPartId)+'|'+IntToStr(E));
    End;
    If O.ObjectId=eImplementation Then Begin
     M:=O; T.Add('MODEL|'+M.ModelType+'|'+M.ModelName+'|'+M.MapAsString);
    End;
    O:=I.NextSchObject;
   End;
  Finally C.SchIterator_Destroy(I); End;
  T.Sort; Result:=T.Text;
 Finally T.Free; End;
End;

Procedure ApplyInputs(D, C, P34, P35);
Var BeforeText : String; Old34, Old35 : Integer;
Begin
 BeforeText:=Signature(C); Old34:=P34.Electrical; Old35:=P35.Electrical;
 SchServer.ProcessControl.PreProcess(D,'Correct DevKit GPIO34/35 input types');
 Try
  Try
   P34.Electrical:=eElectricInput;
   P35.Electrical:=eElectricInput;
   Require(Signature(C)=BeforeText,'Unexpected identity, geometry or model change.');
  Except
   P34.Electrical:=Old34; P35.Electrical:=Old35;
   Raise;
  End;
 Finally SchServer.ProcessControl.PostProcess(D,'Correct DevKit GPIO34/35 input types'); End;
End;

Procedure AuditSheet(FileName, IntendedLocation);
Var SD : IServerDocument; D : ISch_Document; I,J : ISch_Iterator;
 C : ISch_Component; P : ISch_Pin; M : ISch_Implementation;
 O : ISch_GraphicalObject;
Begin
 SD:=OpenNative('SCH',FileName); D:=SchServer.GetCurrentSchDocument;
 Require(D<>Nil,'No schematic database for '+FileName);
 I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin
   RecordLine('SCH|'+FileName+'|'+C.Designator.Text+'|'+C.UniqueId+'|'+
     C.LibReference+'|'+C.Comment.Text+'|KIND='+IntToStr(Ord(C.ComponentKind))+'|'+IntendedLocation);
   J:=C.SchIterator_Create; J.SetState_FilterAll;
   Try
    O:=J.FirstSchObject;
    While O<>Nil Do Begin
     If O.ObjectId=ePin Then Begin
      P:=O; Log.Add('SCHPIN|'+C.Designator.Text+'|'+P.Designator+'|'+P.Name+'|'+
       IntToStr(Ord(P.Electrical))+'|'+IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y)+
       '|ORIENT='+IntToStr(Ord(P.Orientation))+'|LENGTH='+IntToStr(P.PinLength));
     End;
     If O.ObjectId=eImplementation Then Begin
      M:=O; Log.Add('SCHMODEL|'+C.Designator.Text+'|'+M.ModelName+'|'+M.MapAsString);
     End;
     O:=J.NextSchObject;
    End;
   Finally C.SchIterator_Destroy(J); End;
   C:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
End;

Procedure AuditPCB;
Var SD : IServerDocument; B : IPCB_Board; I : IPCB_BoardIterator;
 J : IPCB_GroupIterator; C : IPCB_Component; O : IPCB_Primitive; P : IPCB_Pad;
 BodyCount, PadCount, Count : Integer; N,R : String;
Begin
 SD:=OpenNative('PCB','pcb\GarageBeamSafety.PcbDoc'); B:=PCBServer.GetCurrentPCBBoard;
 Require(B<>Nil,'No native PCB database.'); Count:=0;
 I:=B.BoardIterator_Create; I.AddFilter_ObjectSet(MkSet(eComponentObject));
 I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
 Try
  C:=I.FirstPCBObject;
  While C<>Nil Do Begin
   Count:=Count+1; R:=C.SourceDesignator;
   RecordLine('PCB|'+IntToStr(Count)+'|'+R+'|'+C.Name.Text+'|'+C.SourceUniqueId+'|'+
     C.Pattern+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y))+'|'+FloatToStr(C.Rotation));
   PadCount:=0; BodyCount:=0;
   J:=C.GroupIterator_Create; J.SetState_FilterAll;
   Try
    O:=J.FirstPCBObject;
    While O<>Nil Do Begin
     If O.ObjectId=ePadObject Then Begin
      P:=O; N:=''; If P.Net<>Nil Then N:=P.Net.Name;
      PadCount:=PadCount+1; Log.Add('PAD|'+IntToStr(Count)+'|'+R+'|'+P.Name+'|'+N);
     End;
     If O.ObjectId=eComponentBodyObject Then BodyCount:=BodyCount+1;
     O:=J.NextPCBObject;
    End;
   Finally C.GroupIterator_Destroy(J); End;
   RecordLine('COUNTS|'+IntToStr(Count)+'|'+R+'|PADS='+IntToStr(PadCount)+'|BODIES='+IntToStr(BodyCount));
   If BodyCount=0 Then RecordLine('REVIEW|'+R+'|No component-owned 3D body found.');
   If R='' Then RecordLine('REVIEW|Missing PCB source designator.');
   C:=I.NextPCBObject;
  End;
 Finally B.BoardIterator_Destroy(I); End;
 RecordLine('PCB_READ_ONLY|'+IntToStr(Count)+' components; no geometry, nets or models changed.');
 RecordLine('NOTE|Body count is not proof of a correct STEP model, orientation or dimensions.');
End;

Procedure RunPCBFirstPass;
Var SD,LD : IServerDocument; D : ISch_Document; L : ISch_Lib;
 SC,LC : ISch_Component; S34,S35,L34,L35 : ISch_Pin;
 WS : IWorkspace; Prj : IProject; I, Found : Integer;
 Stamp, DirBase : String; ChangeS, ChangeL : Boolean;
Begin
 Log:=TStringList.Create; RunDir:='';
 Try
  WS:=GetWorkspace; Found:=0;
  For I:=0 To WS.DM_ProjectCount-1 Do Begin
   Prj:=WS.DM_Projects(I);
   If UpperCase(Prj.DM_ProjectFullPath)=UpperCase(BASE+'GarageBeamSafety.PrjPcb') Then Found:=Found+1;
  End;
  Require(Found=1,'Open the GarageBeamSafety project from hardware_projects first.');
  DirBase:=BASE+'History\';
  If Not DirectoryExists(DirBase) Then Require(CreateDir(DirBase),'Cannot create History folder.');
  Stamp:='pcb-first-'+FormatDateTime('yyyymmdd-hhnnss',Now);
  RunDir:=DirBase+Stamp+'\';
  Require(Not DirectoryExists(RunDir),'A run folder already exists. Wait one second and retry.');
  Require(CreateDir(RunDir),'Cannot create run/backup folder.');
  RecordLine('START|PCBFirstPass version 1; '+DateTimeToStr(Now));
  RecordLine('SCOPE|Only GPIO34/35 electrical types may change. No ERC suppression.');
  { Preflight both targets before either one is changed. }
  SD:=OpenNative('SCH',POWER_FILE); D:=SchServer.GetCurrentSchDocument;
  Require(D<>Nil,'Power schematic not available.'); SC:=PlacedESP(D);
  S34:=TargetPin(SC,'J2_5','IO34'); S35:=TargetPin(SC,'J2_6','IO35');
  LD:=OpenNative('SCHLIB',LIB_FILE); L:=SchServer.GetCurrentSchDocument;
  Require(L<>Nil,'Local ESP32 library not available.'); LC:=LibraryESP(L);
  L34:=TargetPin(LC,'J2_5','IO34'); L35:=TargetPin(LC,'J2_6','IO35');
  ChangeS:=(S34.Electrical<>eElectricInput) Or (S35.Electrical<>eElectricInput);
  ChangeL:=(L34.Electrical<>eElectricInput) Or (L35.Electrical<>eElectricInput);
  BackupFile(POWER_FILE,'01_Power_Control.before.SchDoc');
  BackupFile(LIB_FILE,'ESP32-DEVKITC-32E.before.SchLib');
  RecordLine('PRECHECK_OK|Both pin names/numbers found; backup copies written.');
  If ChangeL Then Begin
   Client.ShowDocument(LD); LD.Focus;
   ApplyInputs(L,LC,L34,L35); LD.Modified:=True;
   Require(LD.DoSafeChangeFileNameAndSave(BASE+LIB_FILE,'SCHLIB'),'Could not save local library.');
   Require(Not LD.Modified,'Library save incomplete; inspect backup and report.');
   RecordLine('SAVED_LIBRARY|GPIO34/35 are Input.');
  End Else RecordLine('UNCHANGED_LIBRARY|GPIO34/35 already Input.');
  If ChangeS Then Begin
   Client.ShowDocument(SD); SD.Focus;
   ApplyInputs(D,SC,S34,S35); D.GraphicallyInvalidate;
   SD.Modified:=True; Require(SD.DoFileSave('SCHBinary5.0'),'Could not save power schematic.');
   Require(Not SD.Modified,'Schematic save incomplete; inspect backup and report.');
   RecordLine('SAVED_SCHEMATIC|GPIO34/35 are Input.');
  End Else RecordLine('UNCHANGED_SCHEMATIC|GPIO34/35 already Input.');
  RecordLine('PIN_FIX_COMPLETE|No pin numbers, positions or model maps changed.');
  AuditSheet(POWER_FILE,'RECEIVER_CONTROLLER');
  AuditSheet('sch\02_Beam_Inputs.SchDoc','RECEIVER_CONTROLLER');
  AuditSheet('sch\03_UI_Outputs.SchDoc','RECEIVER_CONTROLLER');
  AuditSheet('sch\04_Optical_Heads.SchDoc','EXTERNAL_OPTICAL_HEADS');
  AuditSheet('sch\05_Installation.SchDoc','EXTERNAL_INSTALLATION');
  AuditPCB;
  RecordLine('COMPLETE|Run native project validation next. PCB grouping and 3D replacement remain pending.');
  ShowMessage('GPIO34/35 checked and corrected. PCB inventory saved without editing the PCB.'+#13#10+
    'Report and backups: '+RunDir+#13#10+'Run project validation and send report.txt back.');
 Except
  Log.Add('INCOMPLETE|Script stopped. Inspect earlier SAVED records for any completed changes.');
  If RunDir<>'' Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('Pass incomplete. Do not run an ECO blindly. Send the error and report.txt.'+#13#10+
    'Backups, if made: '+RunDir);
  Log.Free;
  Raise;
 End;
 Log.Free;
End;

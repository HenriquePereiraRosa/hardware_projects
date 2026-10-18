{ Match the placed DevKit (A1) pin types to the user's directional ports on 02_Power_Control,
  clearing the "IO Pin and Input/Output Port" warnings without weakening the ports:
    IO32 / IO33 / IO13 (beam 1, beam 2, align button) -> Input
    IO25 / IO26 / IO27 (RGB green, red, blue)         -> Output
  Only the placed A1 instance changes; ports, geometry and the library are untouched. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Const SHEET='02_Power_Control.SchDoc';
Var Log : TStringList; RunDir : String;

Procedure Need(Condition, MessageText);
Begin
 If Not Condition Then Begin
  If Log<>Nil Then Begin Log.Add('STOP|'+MessageText); If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt'); End;
  ShowMessage(MessageText); Abort;
 End;
End;

Function FindA1(D : ISch_Document) : ISch_Component;
Var I : ISch_Iterator; C : ISch_Component; N : Integer;
Begin
 Result:=Nil; N:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin
   If C.UniqueId='NWTYJSIX' Then Begin Inc(N); Result:=C; End;
   C:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Need(N=1,'DevKit A1 (NWTYJSIX) is missing or duplicated.');
 Need(Result.Designator.Text='A1','DevKit designator is '+Result.Designator.Text+', expected A1.');
End;

Function FindPin(C : ISch_Component; Designator, Name) : ISch_Pin;
Var I : ISch_Iterator; P : ISch_Pin; N : Integer;
Begin
 Result:=Nil; N:=0; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   If P.Designator=Designator Then Begin Inc(N); Result:=P; End;
   P:=I.NextSchObject;
  End;
 Finally C.SchIterator_Destroy(I); End;
 Need(N=1,'A1 pin '+Designator+' is missing or duplicated.');
 Need(Result.Name=Name,'A1 pin '+Designator+' is '+Result.Name+', expected '+Name);
 Need((Result.Electrical=eElectricIO) Or (Result.Electrical=eElectricInput) Or (Result.Electrical=eElectricOutput),
   'A1 pin '+Designator+' has an unexpected electrical type; review manually.');
End;

Procedure SetPinDirections;
Var SD : IServerDocument; D : ISch_Document; C : ISch_Component; S : String;
    Pins : Array[0..5] Of ISch_Pin; Types : Array[0..5] Of Integer; N : Integer;
    A,B : TFileStream;
Begin
 Log:=TStringList.Create; RunDir:='';
 Try
  Need(FileExists(BASE+'sch\'+SHEET),'Missing '+SHEET);
  SD:=Client.OpenDocument('SCH',BASE+'sch\'+SHEET); Need(SD<>Nil,'Could not open '+SHEET);
  Client.ShowDocument(SD); SD.Focus;
  Need(Not SD.Modified,'Use File > Save All before running.');
  D:=SchServer.GetCurrentSchDocument; Need(D<>Nil,'No schematic document.');
  C:=FindA1(D);
  Pins[0]:=FindPin(C,'J2_7','IO32');  Types[0]:=eElectricInput;
  Pins[1]:=FindPin(C,'J2_8','IO33');  Types[1]:=eElectricInput;
  Pins[2]:=FindPin(C,'J2_15','IO13'); Types[2]:=eElectricInput;
  Pins[3]:=FindPin(C,'J2_9','IO25');  Types[3]:=eElectricOutput;
  Pins[4]:=FindPin(C,'J2_10','IO26'); Types[4]:=eElectricOutput;
  Pins[5]:=FindPin(C,'J2_11','IO27'); Types[5]:=eElectricOutput;

  S:=BASE+'History\'; If Not DirectoryExists(S) Then Need(CreateDir(S),'Cannot create History folder.');
  RunDir:=S+'pin-directions-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
  Need(Not DirectoryExists(RunDir),'Run folder already exists.'); Need(CreateDir(RunDir),'Cannot create run folder.');
  A:=TFileStream.Create(BASE+'sch\'+SHEET,fmOpenRead Or fmShareDenyWrite);
  Try
   B:=TFileStream.Create(RunDir+SHEET,fmCreate);
   Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Backup length mismatch.'); Finally B.Free; End;
  Finally A.Free; End;
  Log.Add('BACKUP|'+SHEET);

  SchServer.ProcessControl.PreProcess(D,'Match DevKit pin types to directional ports');
  Try
   For N:=0 To 5 Do Begin
    Pins[N].Electrical:=Types[N];
    Log.Add('PIN_TYPE|A1 '+Pins[N].Designator+' '+Pins[N].Name+'|'+IntToStr(Types[N]));
   End;
  Finally SchServer.ProcessControl.PostProcess(D,'Match DevKit pin types to directional ports'); End;
  D.GraphicallyInvalidate; SD.Modified:=True;
  Need(SD.DoFileSave('SCHBinary5.0'),'Save failed: '+SHEET); Log.Add('SAVED|'+SHEET);
  Log.Add('COMPLETE|Recompile the project.'); Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('A1 pin types updated and saved.'+#13#10+'Backup: '+RunDir+#13#10+'Now Project > Validate PCB Project.');
 Except
  If (Log<>Nil) And (RunDir<>'') Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  Log.Free; Raise;
 End;
 Log.Free;
End;

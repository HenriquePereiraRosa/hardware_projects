{ Native Altium wiring repair. DOES NOT delete pins or modify display modes.
  Default entry repairs four input filters only. Bulk capacitors require the
  explicitly named RepairAllSixCapacitorConnections entry (user approval).
  No PCB writes, footprint updates, ERC suppression, or component replacement.
  Prepared and geometry-tested outside Altium; native execution still required. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Var Log : TStringList; RunDir : String;

Procedure Need(Condition, MessageText);
Begin
 If Not Condition Then Begin
  Log.Add('STOP|'+MessageText);
  If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt');
  ShowMessage(MessageText); Abort;
 End;
End;

Function OpenSheet(FileName) : IServerDocument;
Begin
 Need(FileExists(BASE+'sch\'+FileName),'Missing schematic '+FileName);
 Result:=Client.OpenDocument('SCH',BASE+'sch\'+FileName);
 Need(Result<>Nil,'Could not open schematic.');
 Client.ShowDocument(Result); Result.Focus;
 Need(Not Result.Modified,'Save All first. No changes made to unsaved documents.');
End;

Procedure Backup(FileName);
Var A,B : TFileStream;
Begin
 Need(Not FileExists(RunDir+FileName),'Backup already exists.');
 A:=TFileStream.Create(BASE+'sch\'+FileName,fmOpenRead Or fmShareDenyWrite);
 Try
  B:=TFileStream.Create(RunDir+FileName,fmCreate);
  Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Backup length mismatch.');
  Finally B.Free; End;
 Finally A.Free; End;
 Log.Add('BACKUP|'+FileName); Log.SaveToFile(RunDir+'report.txt');
End;

Procedure CheckCap(D,Ref,UID,LibName,X,Y);
Var It,CI : ISch_Iterator; C : ISch_Component; P : ISch_Pin;
 N,Total,A,B : Integer;
Begin
 N:=0; It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=It.FirstSchObject;
  While C<>Nil Do Begin
   If C.Designator.Text=Ref Then Begin
    N:=N+1;
    Need((C.UniqueId=UID) And ((C.LibReference=LibName) Or
      (C.LibReference=LibName+'__'+Ref+'_view')),'Unexpected component '+Ref);
    A:=0; B:=0; Total:=0;
    CI:=C.SchIterator_Create; CI.AddFilter_ObjectSet(MkSet(ePin));
    Try
     P:=CI.FirstSchObject;
     While P<>Nil Do Begin
      Total:=Total+1;
      Need((P.OwnerPartId=1) And (P.Location.X=X*100000) And (P.PinLength=1000000),'Unexpected pin geometry '+Ref);
      If P.Designator='1' Then Begin
       Need((P.Location.Y=Y*100000) And (Ord(P.Orientation)=3),'Unexpected pin 1 '+Ref); A:=A+1;
      End Else If P.Designator='2' Then Begin
       Need((P.Location.Y=(Y+10)*100000) And (Ord(P.Orientation)=1),'Unexpected pin 2 '+Ref); B:=B+1;
      End Else Need(False,'Unexpected pin number '+Ref);
      P:=CI.NextSchObject;
     End;
    Finally C.SchIterator_Destroy(CI); End;
    { The four records are two complete display modes, not duplicates. }
    Need((Total=4) And (A=2) And (B=2),'Unexpected display-mode pin records '+Ref);
   End;
   C:=It.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(It); End;
 Need(N=1,'Missing or duplicated component '+Ref);
End;

Procedure CheckWire(D,UID,X1,Y1,X2,Y2);
Var I : ISch_Iterator; W : ISch_Wire; N : Integer;
Begin
 N:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eWire));
 Try
  W:=I.FirstSchObject;
  While W<>Nil Do Begin
   If W.UniqueId=UID Then Begin
    N:=N+1; Need(W.VerticesCount=2,'Reference wire changed '+UID);
    Need((W.GetState_Vertex(1).X=X1*100000) And (W.GetState_Vertex(1).Y=Y1*100000) And
         (W.GetState_Vertex(2).X=X2*100000) And (W.GetState_Vertex(2).Y=Y2*100000),'Reference wire moved '+UID);
   End;
   W:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Need(N=1,'Reference wire missing '+UID);
End;

Function SameSegment(W,X1,Y1,X2,Y2) : Boolean;
Begin
 Result:=False;
 If W.VerticesCount<>2 Then Exit;
 Result:=((W.GetState_Vertex(1).X=X1) And (W.GetState_Vertex(1).Y=Y1) And (W.GetState_Vertex(2).X=X2) And (W.GetState_Vertex(2).Y=Y2)) Or
         ((W.GetState_Vertex(2).X=X1) And (W.GetState_Vertex(2).Y=Y1) And (W.GetState_Vertex(1).X=X2) And (W.GetState_Vertex(1).Y=Y2));
End;

Procedure Link(D,X1,Y1,X2,Y2);
Var I : ISch_Iterator; W : ISch_Wire; Found : Boolean;
Begin
 X1:=X1*100000; Y1:=Y1*100000; X2:=X2*100000; Y2:=Y2*100000;
 Found:=False; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eWire));
 Try
  W:=I.FirstSchObject;
  While W<>Nil Do Begin If SameSegment(W,X1,Y1,X2,Y2) Then Found:=True; W:=I.NextSchObject; End;
 Finally D.SchIterator_Destroy(I); End;
 If Found Then Begin Log.Add('EXISTING_WIRE|'+IntToStr(X1)+'|'+IntToStr(Y1)); Exit; End;
 W:=SchServer.SchObjectFactory(eWire,eCreate_GlobalCopy);
 Need(W<>Nil,'Could not create wire.'); W.Color:=8444159; W.LineWidth:=eSmall;
 W.InsertVertex(1); W.SetState_Vertex(1,Point(X1,Y1));
 W.InsertVertex(2); W.SetState_Vertex(2,Point(X2,Y2));
 D.RegisterSchObjectInContainer(W);
 Log.Add('ADDED_WIRE|'+IntToStr(X1)+'|'+IntToStr(Y1)+'|'+IntToStr(X2)+'|'+IntToStr(Y2));
End;

Procedure InputsPreflight(D);
Begin
 CheckCap(D,'C2','IZQAVBIX','GRM21BR71H104KA01L',825,580);
 CheckCap(D,'C3','MZWSXMOZ','GRM21BR71H104KA01L',825,435);
 CheckCap(D,'C4','MINBGXGG','GRM21BR71H104KA01L',825,290);
 CheckCap(D,'C6','XGLLVDFI','GRM21BR71H104KA01L',825,145);
 CheckWire(D,'BSWYTKAC',825,580,847,580);
 CheckWire(D,'PJNBXMRY',825,435,847,435);
 CheckWire(D,'RFKJMKED',825,290,847,290);
 CheckWire(D,'ZZGMBQUP',825,145,847,145);
 CheckWire(D,'LZYQEMFJ',775,590,825,590);
 CheckWire(D,'FKQCMZCY',775,445,825,445);
 CheckWire(D,'VMHVOURK',775,300,825,300);
 CheckWire(D,'AOYNSQLM',775,155,825,155);
End;

Procedure InputLinks(D);
Begin
 Link(D,825,570,825,580); Link(D,825,590,825,600);
 Link(D,825,425,825,435); Link(D,825,445,825,455);
 Link(D,825,280,825,290); Link(D,825,300,825,310);
 Link(D,825,135,825,145); Link(D,825,155,825,165);
End;

Procedure PowerPreflight(D);
Begin
 CheckCap(D,'C1','WWKCXFFV','EEU-FR1E471',433,444);
 CheckCap(D,'C5','YZOVPMIX','EEU-FR1A471',570,480);
 CheckWire(D,'XYAFXHOZ',423,449,415,449);
 CheckWire(D,'RCVBWBQJ',433,454,455,454);
 CheckWire(D,'SHPIWCTI',570,480,548,480);
 CheckWire(D,'NYXLNEFW',570,490,592,490);
End;

Procedure PowerLinks(D);
Begin
 Link(D,423,449,423,434); Link(D,423,434,433,434);
 Link(D,433,464,455,464); Link(D,455,464,455,454);
 Link(D,570,470,570,480); Link(D,570,490,570,500);
End;

Procedure RunCapRepair(IncludeBulk);
Var SD,PD : IServerDocument; D,P : ISch_Document; S : String;
Begin
 Log:=TStringList.Create; RunDir:='';
 Try
  SD:=OpenSheet('02_Beam_Inputs.SchDoc'); D:=SchServer.GetCurrentSchDocument;
  InputsPreflight(D);
  If IncludeBulk Then Begin PD:=OpenSheet('01_Power_Control.SchDoc'); P:=SchServer.GetCurrentSchDocument; PowerPreflight(P); End;
  S:=BASE+'History\'; If Not DirectoryExists(S) Then Need(CreateDir(S),'Cannot create backup parent.');
  RunDir:=S+'cap-wiring-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
  Need(Not DirectoryExists(RunDir),'Run folder already exists.'); Need(CreateDir(RunDir),'Cannot create backup folder.');
  Log.Add('START|CAP_WIRING_ONLY|'+DateTimeToStr(Now));
  Backup('02_Beam_Inputs.SchDoc'); If IncludeBulk Then Backup('01_Power_Control.SchDoc');
  Client.ShowDocument(SD); SD.Focus;
  SchServer.ProcessControl.PreProcess(D,'Connect four input-filter capacitors');
  Try InputLinks(D); Finally SchServer.ProcessControl.PostProcess(D,'Connect four input-filter capacitors'); End;
  D.GraphicallyInvalidate; SD.Modified:=True;
  Need(SD.DoFileSave('SCHBinary5.0'),'Input sheet save failed.');
  Log.Add('SAVED|02_Beam_Inputs.SchDoc'); Log.SaveToFile(RunDir+'report.txt');
  If IncludeBulk Then Begin
   Client.ShowDocument(PD); PD.Focus;
   SchServer.ProcessControl.PreProcess(P,'Connect C1 and C5 bulk capacitors');
   Try PowerLinks(P); Finally SchServer.ProcessControl.PostProcess(P,'Connect C1 and C5 bulk capacitors'); End;
   P.GraphicallyInvalidate; PD.Modified:=True;
   Need(PD.DoFileSave('SCHBinary5.0'),'Power sheet save failed.');
   Log.Add('SAVED|01_Power_Control.SchDoc');
  End;
  Log.Add('COMPLETE|Wiring pass only. Run saved connectivity audit and native ERC.');
  Log.Add('PRESERVED|All component identities, pins, display modes, models and original wires. No PCB changes.');
  Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('Capacitor wiring pass complete. No pins were deleted.'+#13#10+'Validate the project and send the report.'+#13#10+RunDir);
 Except
  Log.Add('INCOMPLETE|Some earlier sheets may be saved. Inspect SAVED records; preserve backups.');
  If RunDir<>'' Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  Log.Free; Raise;
 End;
 Log.Free;
End;

Procedure RepairInputFilterConnections;
Begin RunCapRepair(False); End;

Procedure RepairAllSixCapacitorConnections;
Begin RunCapRepair(True); End;

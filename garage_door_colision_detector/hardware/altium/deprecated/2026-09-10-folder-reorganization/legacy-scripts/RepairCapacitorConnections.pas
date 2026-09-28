{ PREPARED, NOT YET EXECUTED. Requires confirmation to remove duplicate pins.
  Scope: C1/C5 only. Keeps all component instances, pages and existing wires.
  Requires a fresh backup in History/capacitor-repair-20260910 before execution. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Var Report : TStringList;

Function FindCap(D,R) : ISch_Component;
Var I : ISch_Iterator; C : ISch_Component; N : Integer;
Begin
 Result:=Nil; N:=0; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=I.FirstSchObject;
 While C<>Nil Do Begin If C.Designator.Text=R Then Begin Result:=C; N:=N+1; End; C:=I.NextSchObject; End;
 D.SchIterator_Destroy(I); If N<>1 Then Abort;
End;

Procedure Inspect(C,X,Y1,Y2);
Var I : ISch_Iterator; P : ISch_Pin; N1,N2 : Integer; A1,A2 : Integer;
Begin
 N1:=0; N2:=0; A1:=0; A2:=0; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin)); P:=I.FirstSchObject;
 While P<>Nil Do Begin
  If (P.Location.X<>X) Or (P.PinLength<>1000000) Or (P.OwnerPartId<>1) Then Abort;
  If P.Designator='1' Then Begin
   If (P.Location.Y<>Y1) Or (Ord(P.Orientation)<>3) Then Abort;
   If N1=0 Then A1:=P.I_ObjectAddress Else If A1=P.I_ObjectAddress Then Abort;
   N1:=N1+1;
  End Else If P.Designator='2' Then Begin
   If (P.Location.Y<>Y2) Or (Ord(P.Orientation)<>1) Then Abort;
   If N2=0 Then A2:=P.I_ObjectAddress Else If A2=P.I_ObjectAddress Then Abort;
   N2:=N2+1;
  End Else Abort;
  P:=I.NextSchObject;
 End; C.SchIterator_Destroy(I);
 If (N1<>2) Or (N2<>2) Then Abort;
 Report.Add('PRECHECK|'+C.Designator.Text+'|two distinct objects per pin number');
End;

Procedure Deduplicate(C);
Var I : ISch_Iterator; P,Dup1,Dup2 : ISch_Pin; Seen1,Seen2 : Boolean;
Begin
 Seen1:=False; Seen2:=False; Dup1:=Nil; Dup2:=Nil;
 I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin)); P:=I.FirstSchObject;
 While P<>Nil Do Begin
  If P.Designator='1' Then Begin If Seen1 Then Dup1:=P; Seen1:=True; End;
  If P.Designator='2' Then Begin If Seen2 Then Dup2:=P; Seen2:=True; End;
  P:=I.NextSchObject;
 End; C.SchIterator_Destroy(I);
 If (Dup1=Nil) Or (Dup2=Nil) Then Abort;
 C.RemoveSchObject(Dup1); C.RemoveSchObject(Dup2);
 Report.Add('REMOVED_DUPLICATES|'+C.Designator.Text+'|1,2');
End;

Procedure Wire(D,X1,Y1,X2,Y2);
Var W : ISch_Wire;
Begin
 W:=SchServer.SchObjectFactory(eWire,eCreate_GlobalCopy); W.Color:=65535; W.LineWidth:=eSmall;
 W.InsertVertex(1); W.SetState_Vertex(1,Point(X1,Y1));
 W.InsertVertex(2); W.SetState_Vertex(2,Point(X2,Y2)); D.RegisterSchObjectInContainer(W);
 Report.Add('ADDED_WIRE|'+IntToStr(X1)+'|'+IntToStr(Y1)+'|'+IntToStr(X2)+'|'+IntToStr(Y2));
End;

Procedure RepairCapacitorConnections;
Var SD : IServerDocument; D : ISch_Document; C1,C5 : ISch_Component;
Begin
 If Not FileExists(BASE+'History\capacitor-repair-20260910\01_Power_Control.SchDoc') Then Begin ShowMessage('Fresh backup required. No changes made.'); Abort; End;
 If FileExists(BASE+'CapacitorRepair.audit.txt') Then Begin ShowMessage('Repair log exists; inspect before rerunning.'); Abort; End;
 SD:=Client.OpenDocument('SCH',BASE+'01_Power_Control.SchDoc'); Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
 Report:=TStringList.Create; C1:=FindCap(D,'C1'); C5:=FindCap(D,'C5');
 Inspect(C1,43300000,44400000,45400000); Inspect(C5,57000000,48000000,49000000);
 SchServer.ProcessControl.PreProcess(D,'Repair C1 and C5 pin connectivity');
 Try
  Deduplicate(C1); Deduplicate(C5);
  { Pin connection ends are Location plus length along Orientation. }
  Wire(D,42300000,44900000,42300000,43400000); Wire(D,42300000,43400000,43300000,43400000);
  Wire(D,43300000,46400000,45500000,46400000); Wire(D,45500000,46400000,45500000,45400000);
  Wire(D,57000000,47000000,54800000,47000000); Wire(D,54800000,47000000,54800000,48000000);
  Wire(D,57000000,50000000,59200000,50000000); Wire(D,59200000,50000000,59200000,49000000);
 Finally SchServer.ProcessControl.PostProcess(D,'Repair C1 and C5 pin connectivity'); End;
 D.GraphicallyInvalidate; SD.Modified:=True;
 SD.DoFileSave('SCHBinary5.0'); Report.Add('SAVED; native ERC/ECO verification required');
 Report.SaveToFile(BASE+'CapacitorRepair.audit.txt'); Report.Free;
 ShowMessage('C1/C5 duplicate pins removed and connection ends wired. Run native ERC and controller ECO.');
End;

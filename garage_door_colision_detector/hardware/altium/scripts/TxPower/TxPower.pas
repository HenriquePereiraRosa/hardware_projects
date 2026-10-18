{ D13/D14 (2026-09-28), all on 05_Optical_Heads - no new sheet.
  Heads: TX1-3 / RX1-3 become Standard components (were Graphical, so Altium ignored them):
         BN/BU -> Power pins, RX BK -> Output pin. TX_12V / TX_0V power ports on the user's TX stub wires.
  PCB2 transmitter power, in the free band under channel 3, electrically separate from the RX side:
         J7 12 V adapter in -> F3 PTC -> D7 SS34 reverse-polarity -> TX_12V ; J8/J9/J10 emitters TX1-3, J11 spare TX4.
         Parts are copies of J1 (1729128), F1 (MF-MSMF110/24X-2) and D6 (SS34) from 02_Power_Control, so they keep
         their footprints, 3D models and parameters.
  Notes: removes the outdated / redundant free text (the "Mechanical BOM items" line, the per-channel
         J-connector notes, PAGE 0 INTERFACE, and the emitter-supply note the circuit now replaces).
         The UNSAFE fault note is kept.
  Every source object is matched by UniqueId before anything changes; any mismatch aborts. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Var Log : TStringList; RunDir : String;

Procedure Need(Condition, MessageText);
Begin
 If Not Condition Then Begin
  If Log<>Nil Then Begin Log.Add('STOP|'+MessageText); If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt'); End;
  ShowMessage(MessageText); Abort;
 End;
End;

Function C(V) : Integer;
Begin
 Result:=V*100000;
End;

Function OpenSheet(FileName) : IServerDocument;
Begin
 Need(FileExists(BASE+'sch\'+FileName),'Missing schematic sch\'+FileName);
 Result:=Client.OpenDocument('SCH',BASE+'sch\'+FileName);
 Need(Result<>Nil,'Could not open '+FileName); Client.ShowDocument(Result); Result.Focus;
 Need(Not Result.Modified,'Use File > Save All before running. Unsaved sheet: '+FileName);
End;

Procedure BackupOne(FileName);
Var A,B : TFileStream;
Begin
 A:=TFileStream.Create(BASE+'sch\'+FileName,fmOpenRead Or fmShareDenyWrite);
 Try
  B:=TFileStream.Create(RunDir+FileName,fmCreate);
  Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Backup length mismatch: '+FileName); Finally B.Free; End;
 Finally A.Free; End;
 Log.Add('BACKUP|'+FileName); Log.SaveToFile(RunDir+'report.txt');
End;

Function FindUid(D : ISch_Document; Uid) : ISch_GraphicalObject;
Var I : ISch_Iterator; O : ISch_GraphicalObject; N : Integer;
Begin
 Result:=Nil; N:=0; I:=D.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   If O.UniqueId=Uid Then Begin Inc(N); Result:=O; End;
   O:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Need(N=1,'Object '+Uid+' is missing or duplicated - sheet changed since review.');
End;

Function FindComp(D : ISch_Document; Uid, Designator) : ISch_Component;
Begin
 Result:=FindUid(D,Uid);
 Need(Result.ObjectId=eSchComponent,'Object '+Uid+' is not a component.');
 Need(Result.Designator.Text=Designator,'Component '+Uid+' is '+Result.Designator.Text+', expected '+Designator);
End;

Function FindNote(D : ISch_Document; Uid, Prefix) : ISch_Label;
Begin
 Result:=FindUid(D,Uid);
 Need(Result.ObjectId=eLabel,'Object '+Uid+' is not a text note.');
 Need(Copy(Result.Text,1,Length(Prefix))=Prefix,'Note '+Uid+' reads "'+Result.Text+'", expected "'+Prefix+'..."');
End;

Function DesignatorUsed(D : ISch_Document; Designator) : Boolean;
Var I : ISch_Iterator; O : ISch_Component;
Begin
 Result:=False; I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin If O.Designator.Text=Designator Then Result:=True; O:=I.NextSchObject; End;
 Finally D.SchIterator_Destroy(I); End;
End;

Function NewUid : String;
Var N : Integer;
Begin
 Result:=''; For N:=1 To 8 Do Result:=Result+Chr(Ord('A')+Random(26));
End;

Procedure AddObject(D : ISch_Document; O);
Begin
 D.RegisterSchObjectInContainer(O);
 SchServer.RobotManager.SendMessage(D.I_ObjectAddress,c_BroadCast,SCHM_PrimitiveRegistration,O.I_ObjectAddress);
End;

Function FindPin(Comp : ISch_Component; Designator) : ISch_Pin;
Var I : ISch_Iterator; P : ISch_Pin; N : Integer;
Begin
 Result:=Nil; N:=0; I:=Comp.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   If P.Designator=Designator Then Begin Inc(N); Result:=P; End;
   P:=I.NextSchObject;
  End;
 Finally Comp.SchIterator_Destroy(I); End;
 Need(N=1,Comp.Designator.Text+' pin '+Designator+' is missing or duplicated.');
End;

{ Pin Location is where the pin meets the body; the electrical end is PinLength further out. }
Function Step(P : ISch_Pin; Distance) : TPoint;
Var X,Y,O : Integer;
Begin
 X:=P.Location.X; Y:=P.Location.Y; O:=Ord(P.Orientation);
 If O=0 Then X:=X+Distance; If O=1 Then Y:=Y+Distance;
 If O=2 Then X:=X-Distance; If O=3 Then Y:=Y-Distance;
 Result:=Point(X,Y);
End;

Procedure AddWire(D : ISch_Document; A, B : TPoint);
Var W : ISch_Wire;
Begin
 W:=SchServer.SchObjectFactory(eWire,eCreate_GlobalCopy); Need(W<>Nil,'Could not create wire.');
 W.Location:=A; W.InsertVertex:=1; W.SetState_Vertex(1,A); W.InsertVertex:=2; W.SetState_Vertex(2,B);
 AddObject(D,W);
End;

{ Direct wire between two pin ends (horizontal first, then vertical when they are not level). }
Procedure Link(D : ISch_Document; P1, P2 : ISch_Pin; Why);
Var A,B,M : TPoint;
Begin
 A:=Step(P1,P1.PinLength); B:=Step(P2,P2.PinLength);
 If A.Y=B.Y Then AddWire(D,A,B) Else Begin M:=Point(B.X,A.Y); AddWire(D,A,M); AddWire(D,M,B); End;
 Log.Add('WIRE|'+Why);
End;

{ Short stub out of the pin with a global power port on its end (IsSupply: 12 V bar up, else ground down). }
Procedure Tie(D : ISch_Document; Comp : ISch_Component; PinDes, NetName, IsSupply);
Var P : ISch_Pin; A,B : TPoint; PW : ISch_PowerObject;
Begin
 P:=FindPin(Comp,PinDes); A:=Step(P,P.PinLength); B:=Step(P,P.PinLength+C(30));
 AddWire(D,A,B);
 PW:=SchServer.SchObjectFactory(ePowerObject,eCreate_GlobalCopy); Need(PW<>Nil,'Could not create power port.');
 PW.Location:=B; PW.Text:=NetName; PW.ShowNetName:=True;
 If IsSupply Then Begin PW.Style:=ePowerBar; PW.Orientation:=eRotate90; End
 Else Begin PW.Style:=ePowerGndPower; PW.Orientation:=eRotate270; End;
 AddObject(D,PW);
 Log.Add('TIE|'+Comp.Designator.Text+'-'+PinDes+'|'+NetName);
End;

Function Place(D : ISch_Document; Source : ISch_Component; Designator, CommentText, X, Y) : ISch_Component;
Begin
 Need(Not DesignatorUsed(D,Designator),'Designator '+Designator+' is already used on this sheet.');
 Result:=Source.Replicate; Need(Result<>Nil,'Could not copy '+Source.Designator.Text);
 Result.UniqueId:=NewUid; Result.Designator.Text:=Designator; Result.Comment.Text:=CommentText;
 AddObject(D,Result); Result.MoveToXY(C(X),C(Y));
 Log.Add('PLACED|'+Designator+'|copy of '+Source.Designator.Text+'|'+CommentText);
End;

Procedure AddNote(D : ISch_Document; X, Y, Text);
Var L : ISch_Label;
Begin
 L:=SchServer.SchObjectFactory(eLabel,eCreate_GlobalCopy); Need(L<>Nil,'Could not create text note.');
 L.Location:=Point(C(X),C(Y)); L.Text:=Text; AddObject(D,L);
End;

{ Power port on the free (x=105) end of a TX stub wire the user drew from an emitter pin. }
Function CheckStub(D : ISch_Document; Uid, Y) : ISch_Wire;
Var W : ISch_Wire; A,B : TPoint;
Begin
 W:=FindUid(D,Uid); Need(W.ObjectId=eWire,'Object '+Uid+' is not a wire.'); Need(W.VerticesCount=2,'TX stub wire '+Uid+' has changed.');
 A:=W.GetState_Vertex(1); B:=W.GetState_Vertex(2);
 Need(((A.X=C(105)) And (A.Y=C(Y)) And (B.X=C(134)) And (B.Y=C(Y))) Or
      ((B.X=C(105)) And (B.Y=C(Y)) And (A.X=C(134)) And (A.Y=C(Y))),'TX stub wire '+Uid+' has moved.');
 Result:=W;
End;

Procedure PowerAtStub(D : ISch_Document; Uid, Name, Y, Style);
Var P : ISch_PowerObject;
Begin
 CheckStub(D,Uid,Y);
 P:=SchServer.SchObjectFactory(ePowerObject,eCreate_GlobalCopy); Need(P<>Nil,'Could not create power port.');
 P.Location:=Point(C(105),C(Y)); P.Text:=Name; P.Style:=Style; P.Orientation:=eRotate180; P.ShowNetName:=True;
 AddObject(D,P);
 Log.Add('TX_STUB_POWER|'+Name+'|105,'+IntToStr(Y));
End;

Procedure MakeHead(Comp : ISch_Component; IsReceiver);
Var P : ISch_Pin;
Begin
 Comp.ComponentKind:=eComponentKind_Standard;
 P:=FindPin(Comp,'BN'); P.Electrical:=eElectricPower;
 P:=FindPin(Comp,'BU'); P.Electrical:=eElectricPower;
 If IsReceiver Then Begin P:=FindPin(Comp,'BK'); P.Electrical:=eElectricOutput; End;
 Log.Add('HEAD_STANDARD|'+Comp.Designator.Text);
End;

Procedure BuildTxPower;
Var PowerSD, HeadsSD : IServerDocument; PowerD, HeadsD : ISch_Document;
    J1, F1, D6, JIn, F, DD, J : ISch_Component; Heads : Array[0..5] Of ISch_Component;
    Notes : Array[0..14] Of ISch_Label; N : Integer; S : String;
Begin
 Log:=TStringList.Create; RunDir:=''; Randomize;
 Try
  { Preflight: nothing is modified until every check passes. }
  PowerSD:=OpenSheet('02_Power_Control.SchDoc'); PowerD:=SchServer.GetCurrentSchDocument;
  J1:=FindComp(PowerD,'MPFPEHHR','J1'); F1:=FindComp(PowerD,'THVEUGSY','F1'); D6:=FindComp(PowerD,'NAQKJIPP','D6');
  FindPin(J1,'1'); FindPin(J1,'2'); FindPin(F1,'1'); FindPin(F1,'2'); FindPin(D6,'1'); FindPin(D6,'2');
  HeadsSD:=OpenSheet('05_Optical_Heads.SchDoc'); HeadsD:=SchServer.GetCurrentSchDocument;
  Heads[0]:=FindComp(HeadsD,'TMFADSTK','TX1'); Heads[1]:=FindComp(HeadsD,'SPJFOFQO','TX2'); Heads[2]:=FindComp(HeadsD,'GHTWQLMA','TX3');
  Heads[3]:=FindComp(HeadsD,'HQPUWZTI','RX1'); Heads[4]:=FindComp(HeadsD,'NFYKOJFB','RX2'); Heads[5]:=FindComp(HeadsD,'UUIMFHCZ','RX3');
  For N:=0 To 5 Do Begin FindPin(Heads[N],'BN'); FindPin(Heads[N],'BU'); If N>=3 Then FindPin(Heads[N],'BK'); End;
  CheckStub(HeadsD,'MUVXNEIK',630); CheckStub(HeadsD,'DMSEOFUG',590); CheckStub(HeadsD,'TAPPVPFV',495);
  CheckStub(HeadsD,'ISCOHTYY',455); CheckStub(HeadsD,'WOMELZAA',360); CheckStub(HeadsD,'SDVQLVRV',320);
  Notes[0]:=FindNote(HeadsD,'LYWIPMAE','2.4 m nominal span');
  Notes[1]:=FindNote(HeadsD,'ZWXKXDLU','PAGE 0 INTERFACE');
  Notes[2]:=FindNote(HeadsD,'ZUHEFGKM','Emitter supply');
  Notes[3]:=FindNote(HeadsD,'OCIETBEJ','J2 ON PCB'); Notes[4]:=FindNote(HeadsD,'YEXANHCN','1 brown');
  Notes[5]:=FindNote(HeadsD,'JPALFTXO','3 black');   Notes[6]:=FindNote(HeadsD,'RIUDNYGN','10.8 x 31');
  Notes[7]:=FindNote(HeadsD,'MDFGFZEB','J3 ON PCB'); Notes[8]:=FindNote(HeadsD,'LPHWBEJF','1 brown');
  Notes[9]:=FindNote(HeadsD,'FURCLRUT','3 black');   Notes[10]:=FindNote(HeadsD,'TCTXDCWE','10.8 x 31');
  Notes[11]:=FindNote(HeadsD,'YULWYKQB','J4 ON PCB'); Notes[12]:=FindNote(HeadsD,'YGSVLXSV','1 brown');
  Notes[13]:=FindNote(HeadsD,'KEGIPMHE','3 black');   Notes[14]:=FindNote(HeadsD,'IQNRUQKM','10.8 x 31');

  S:=BASE+'History\'; If Not DirectoryExists(S) Then Need(CreateDir(S),'Cannot create History folder.');
  RunDir:=S+'tx-power-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
  Need(Not DirectoryExists(RunDir),'Run folder already exists.'); Need(CreateDir(RunDir),'Cannot create run folder.');
  Log.Add('START|TX power on sheet 05 + standard optical heads'); BackupOne('05_Optical_Heads.SchDoc');

  Client.ShowDocument(HeadsSD); HeadsSD.Focus;
  SchServer.ProcessControl.PreProcess(HeadsD,'Standard heads and PCB2 transmitter power');
  Try
   For N:=0 To 5 Do MakeHead(Heads[N],N>=3);
   PowerAtStub(HeadsD,'MUVXNEIK','TX_12V',630,ePowerBar); PowerAtStub(HeadsD,'DMSEOFUG','TX_0V',590,ePowerGndPower);
   PowerAtStub(HeadsD,'TAPPVPFV','TX_12V',495,ePowerBar); PowerAtStub(HeadsD,'ISCOHTYY','TX_0V',455,ePowerGndPower);
   PowerAtStub(HeadsD,'WOMELZAA','TX_12V',360,ePowerBar); PowerAtStub(HeadsD,'SDVQLVRV','TX_0V',320,ePowerGndPower);
   For N:=0 To 14 Do HeadsD.RemoveSchObject(Notes[N]);
   Log.Add('REMOVED|15 outdated / redundant text notes');

   { Free band under channel 3: input chain on the left, emitter terminals on the right. }
   AddNote(HeadsD,65,280,'TX POWER - PCB2 (emitter side, separate 12 V adapter)');
   JIn:=Place(HeadsD,J1,'J7','1729128 / TX 12V INPUT',80,210);
   F:=Place(HeadsD,F1,'F3','1.1A PTC / 24V',270,222);
   DD:=Place(HeadsD,D6,'D7','SS34',400,232);
   Link(HeadsD,FindPin(JIn,'1'),FindPin(F,'1'),'J7-1 to F3-1');
   Link(HeadsD,FindPin(F,'2'),FindPin(DD,'1'),'F3-2 to D7 anode');
   Tie(HeadsD,JIn,'2','TX_0V',False); Tie(HeadsD,DD,'2','TX_12V',True);
   J:=Place(HeadsD,J1,'J8','1729128 / TX1',520,210);  Tie(HeadsD,J,'1','TX_12V',True); Tie(HeadsD,J,'2','TX_0V',False);
   J:=Place(HeadsD,J1,'J9','1729128 / TX2',650,210);  Tie(HeadsD,J,'1','TX_12V',True); Tie(HeadsD,J,'2','TX_0V',False);
   J:=Place(HeadsD,J1,'J10','1729128 / TX3',780,210); Tie(HeadsD,J,'1','TX_12V',True); Tie(HeadsD,J,'2','TX_0V',False);
   J:=Place(HeadsD,J1,'J11','1729128 / TX4 SPARE',910,210); Tie(HeadsD,J,'1','TX_12V',True); Tie(HeadsD,J,'2','TX_0V',False);
  Finally SchServer.ProcessControl.PostProcess(HeadsD,'Standard heads and PCB2 transmitter power'); End;
  HeadsD.GraphicallyInvalidate; HeadsSD.Modified:=True;
  Need(HeadsSD.DoFileSave('SCHBinary5.0'),'Save failed: 05_Optical_Heads.SchDoc'); Log.Add('SAVED|05_Optical_Heads.SchDoc');

  Log.Add('PRESERVED|02_Power_Control (read only), 03_Beam_Inputs, libraries, PCB');
  Log.Add('COMPLETE|Recompile the project.'); Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('TX power added to sheet 05 and optical heads updated.'+#13#10+'Backup: '+RunDir+#13#10+'Now Project > Validate PCB Project.');
 Except
  If (Log<>Nil) And (RunDir<>'') Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  Log.Free; Raise;
 End;
 Log.Free;
End;

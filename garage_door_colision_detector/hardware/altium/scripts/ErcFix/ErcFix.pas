{ Clear the 2026-09-28 compiler errors without moving components.
  05_Optical_Heads: 12V/GND net labels -> power ports; drop the redundant 12V/GND ports + stubs;
                    No ERC on the spare BEAM4_SIG port (firmware uses 3 beams).
  02_Power_Control: remove dangling IO35 stub; No ERC on EN (J2_2) and IO35 (J2_6);
                    GPIO ports -> Unspecified I/O type (DevKit pins are all I/O).
  01_System_Overview: remove the empty placeholder sheet symbol so the design compiles flat.
  Every object is matched by UniqueId + position before anything changes; any mismatch aborts. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Const SHEET_COUNT=3;
Var Log : TStringList; RunDir : String;
    ServerDocs : Array[0..2] Of IServerDocument;
    Docs : Array[0..2] Of ISch_Document;
    Files : Array[0..2] Of String;

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

Procedure Setup;
Begin
 Files[0]:='01_System_Overview.SchDoc';
 Files[1]:='02_Power_Control.SchDoc';
 Files[2]:='05_Optical_Heads.SchDoc';
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

Function Expect(D : ISch_Document; Uid, Kind, Name, X, Y) : ISch_GraphicalObject;
Var O : ISch_GraphicalObject; S : String;
Begin
 O:=FindUid(D,Uid);
 Need(O.ObjectId=Kind,'Object '+Uid+' has an unexpected type.');
 If Kind=ePort Then S:=O.Name Else If Kind=eNetLabel Then S:=O.Text Else S:=Name;
 Need(S=Name,'Object '+Uid+' is named '+S+', expected '+Name);
 Need((O.Location.X=C(X)) And (O.Location.Y=C(Y)),'Object '+Uid+' ('+Name+') has moved.');
 Result:=O;
End;

Function ExpectWire(D : ISch_Document; Uid, X1, Y1, X2, Y2) : ISch_Wire;
Var W : ISch_Wire;
Begin
 W:=FindUid(D,Uid); Need(W.ObjectId=eWire,'Object '+Uid+' is not a wire.');
 Need((W.VerticesCount=2) And (W.GetState_Vertex(1).X=C(X1)) And (W.GetState_Vertex(1).Y=C(Y1)) And
   (W.GetState_Vertex(2).X=C(X2)) And (W.GetState_Vertex(2).Y=C(Y2)),'Wire '+Uid+' has changed.');
 Result:=W;
End;

Procedure AddObject(D : ISch_Document; O);
Begin
 D.RegisterSchObjectInContainer(O);
 SchServer.RobotManager.SendMessage(D.I_ObjectAddress,c_BroadCast,SCHM_PrimitiveRegistration,O.I_ObjectAddress);
End;

Procedure AddNoErc(D : ISch_Document; X, Y, Why);
Var E : ISch_NoERC;
Begin
 E:=SchServer.SchObjectFactory(eNoERC,eCreate_GlobalCopy); Need(E<>Nil,'Could not create No ERC marker.');
 E.Location:=Point(C(X),C(Y)); AddObject(D,E);
 Log.Add('NOERC|'+Why);
End;

Procedure LabelToPower(D : ISch_Document; Uid, Name, X, Y, Style);
Var L : ISch_NetLabel; P : ISch_PowerObject;
Begin
 L:=Expect(D,Uid,eNetLabel,Name,X,Y);
 P:=SchServer.SchObjectFactory(ePowerObject,eCreate_GlobalCopy); Need(P<>Nil,'Could not create power port.');
 P.Location:=Point(C(X),C(Y)); P.Text:=Name; P.Style:=Style; P.Orientation:=eRotate180; P.ShowNetName:=True;
 AddObject(D,P); D.RemoveSchObject(L);
 Log.Add('LABEL_TO_POWER|'+Name+'|'+IntToStr(X)+','+IntToStr(Y));
End;

Procedure RemovePortStub(D : ISch_Document; PortUid, WireUid, LabelUid, Name, Y);
Var P, L : ISch_GraphicalObject; W : ISch_Wire;
Begin
 P:=Expect(D,PortUid,ePort,Name,925,Y); W:=ExpectWire(D,WireUid,905,Y,925,Y); L:=Expect(D,LabelUid,eNetLabel,Name,905,Y);
 D.RemoveSchObject(P); D.RemoveSchObject(W); D.RemoveSchObject(L);
 Log.Add('REMOVED|redundant '+Name+' port, stub wire and label');
End;

Procedure CheckOptical(D : ISch_Document);
Begin
 Expect(D,'CJBDUGQE',eNetLabel,'12V',500,630); Expect(D,'CDGCFDVL',eNetLabel,'12V',500,495);
 Expect(D,'MFYVTSEB',eNetLabel,'12V',500,360); Expect(D,'PDWQSNZS',eNetLabel,'12V',500,225);
 Expect(D,'FTMKHBWA',eNetLabel,'GND',500,590); Expect(D,'JMNDGHXI',eNetLabel,'GND',500,455);
 Expect(D,'NHOIXYHH',eNetLabel,'GND',500,320); Expect(D,'AGUYYFWA',eNetLabel,'GND',500,185);
 Expect(D,'WEKLHQFR',ePort,'12V',925,650); ExpectWire(D,'EHCHRCIJ',905,650,925,650); Expect(D,'LVVMCCKY',eNetLabel,'12V',905,650);
 Expect(D,'YXXJQWPO',ePort,'GND',925,605); ExpectWire(D,'KMKDPILJ',905,605,925,605); Expect(D,'BJSAXBJW',eNetLabel,'GND',905,605);
 Expect(D,'GLLBURHI',ePort,'BEAM4_SIG',925,425);
End;

Procedure FixOptical(D : ISch_Document);
Begin
 LabelToPower(D,'CJBDUGQE','12V',500,630,ePowerBar); LabelToPower(D,'CDGCFDVL','12V',500,495,ePowerBar);
 LabelToPower(D,'MFYVTSEB','12V',500,360,ePowerBar); LabelToPower(D,'PDWQSNZS','12V',500,225,ePowerBar);
 LabelToPower(D,'FTMKHBWA','GND',500,590,ePowerGndPower); LabelToPower(D,'JMNDGHXI','GND',500,455,ePowerGndPower);
 LabelToPower(D,'NHOIXYHH','GND',500,320,ePowerGndPower); LabelToPower(D,'AGUYYFWA','GND',500,185,ePowerGndPower);
 RemovePortStub(D,'WEKLHQFR','EHCHRCIJ','LVVMCCKY','12V',650);
 RemovePortStub(D,'YXXJQWPO','KMKDPILJ','BJSAXBJW','GND',605);
 AddNoErc(D,925,425,'spare BEAM4_SIG port');
End;

Procedure CheckPower(D : ISch_Document);
Begin
 ExpectWire(D,'OJWBZFNJ',820,399,847,399);
 Expect(D,'KOCSORTM',ePort,'BEAM1_GPIO32',732,389); Expect(D,'SOCRRUHP',ePort,'BEAM2_GPIO33',732,379);
 Expect(D,'HGOIXIGT',ePort,'BEAM3_GPIO34',732,409); Expect(D,'QYDFMVRU',ePort,'BUTTON_GPIO13',731,309);
 Expect(D,'UVTMXZLJ',ePort,'LED_GREEN_GPIO25',727,369); Expect(D,'YFUMCXAX',ePort,'LED_RED_GPIO26',727,359);
 Expect(D,'PUENASLN',ePort,'LED_BLUE_GPIO27',727,349);
End;

Procedure Unspecify(D : ISch_Document; Uid);
Var P : ISch_Port;
Begin
 P:=FindUid(D,Uid); P.IOType:=ePortUnspecified; Log.Add('PORT_IO_UNSPECIFIED|'+P.Name);
End;

Procedure FixPower(D : ISch_Document);
Begin
 D.RemoveSchObject(FindUid(D,'OJWBZFNJ')); Log.Add('REMOVED|dangling IO35 stub wire');
 AddNoErc(D,847,439,'A1 J2_2 EN (DevKit has its own pull-up)');
 AddNoErc(D,847,399,'A1 J2_6 IO35 (reserved, unused)');
 Unspecify(D,'KOCSORTM'); Unspecify(D,'SOCRRUHP'); Unspecify(D,'HGOIXIGT'); Unspecify(D,'QYDFMVRU');
 Unspecify(D,'UVTMXZLJ'); Unspecify(D,'YFUMCXAX'); Unspecify(D,'PUENASLN');
End;

Procedure CheckOverview(D : ISch_Document);
Var S : ISch_GraphicalObject;
Begin
 S:=FindUid(D,'LJTJAKEQ'); Need(S.ObjectId=eSheetSymbol,'Top-sheet object LJTJAKEQ is not the sheet symbol.');
 Need((S.Location.X=C(959)) And (S.Location.Y=C(567)),'Placeholder sheet symbol has moved.');
End;

Procedure FixOverview(D : ISch_Document);
Begin
 D.RemoveSchObject(FindUid(D,'LJTJAKEQ')); Log.Add('REMOVED|empty placeholder sheet symbol (-> 03_Beam_Inputs)');
End;

Procedure FixErcErrors;
Var N : Integer; S : String;
Begin
 Log:=TStringList.Create; RunDir:='';
 Try
  Setup; OpenAll;
  CheckOverview(Docs[0]); CheckPower(Docs[1]); CheckOptical(Docs[2]);
  S:=BASE+'History\'; If Not DirectoryExists(S) Then Need(CreateDir(S),'Cannot create History folder.');
  RunDir:=S+'erc-fix-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
  Need(Not DirectoryExists(RunDir),'Run folder already exists.'); Need(CreateDir(RunDir),'Cannot create run folder.');
  Log.Add('START|ERC fix'); For N:=0 To SHEET_COUNT-1 Do BackupOne(Files[N]);
  For N:=0 To SHEET_COUNT-1 Do Begin
   SchServer.ProcessControl.PreProcess(Docs[N],'Fix compiler errors');
   Try
    If N=0 Then FixOverview(Docs[N]);
    If N=1 Then FixPower(Docs[N]);
    If N=2 Then FixOptical(Docs[N]);
   Finally SchServer.ProcessControl.PostProcess(Docs[N],'Fix compiler errors'); End;
   Docs[N].GraphicallyInvalidate; ServerDocs[N].Modified:=True;
   Need(ServerDocs[N].DoFileSave('SCHBinary5.0'),'Save failed: '+Files[N]); Log.Add('SAVED|'+Files[N]); Log.SaveToFile(RunDir+'report.txt');
  End;
  Log.Add('PRESERVED|components, pins, 03_Beam_Inputs, PCB');
  Log.Add('COMPLETE|Recompile the project.'); Log.SaveToFile(RunDir+'report.txt');
  ShowMessage('ERC fixes applied and saved.'+#13#10+'Backups: '+RunDir+#13#10+'Now Project > Validate PCB Project.');
 Except
  If (Log<>Nil) And (RunDir<>'') Then If DirectoryExists(RunDir) Then Log.SaveToFile(RunDir+'report.txt');
  Log.Free; Raise;
 End;
 Log.Free;
End;

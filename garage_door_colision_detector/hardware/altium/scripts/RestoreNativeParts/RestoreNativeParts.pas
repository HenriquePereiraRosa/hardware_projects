{ Complete native library components, not artwork grafts.
  Repairs NEW COPIES only. Source SchDocs, PCB and source libraries are never saved.
  Run RestoreNativeParts. No Abort, Raise, Replicate or source-library editing.
  Generated pin contracts come from the last saved project. ERC is still required.
}
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\'; PARTS=39;
Var Log : TStringList; RunDir,Failure,Phase : String;
 Docs : Array[0..2] Of IServerDocument;
 Sheets : Array[0..2] Of ISch_Document;
 NewParts,OldParts : Array[0..38] Of ISch_Component;
 PartSheet : Array[0..38] Of Integer;
 PinCounts : Array[0..38] Of Integer;
 ExpectedRef,ExpectedUID,ExpectedSource : Array[0..38] Of String;
 SheetNames : Array[0..2] Of String;
 NeedsManual : Array[0..38] Of Boolean;
 Pins : Array[0..155] Of ISch_Pin;
 PinPart,TargetX,TargetY : Array[0..155] Of Integer;
 NP,Restored,Replaced,WireCount,ManualCount : Integer;
 CollectingVerification : Boolean;
 VerifyIssues,VerifyPassed,VerifyFailed : Integer;

Procedure Note(S);
Begin
 Log.Add(S); If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt');
End;

Function Check(OK,S) : Boolean;
Begin
 Result:=OK;
 If (Not OK) And CollectingVerification Then Begin
  VerifyIssues:=VerifyIssues+1; Note('VERIFY_ERROR|'+Phase+' | '+S); Exit;
 End;
 If (Not OK) And (Failure='') Then Begin Failure:=Phase+' | '+S; Note('STOP|'+Failure); End;
End;

Function CopyFileChecked(Source,Dest) : Boolean;
Var A,B : TFileStream;
Begin
 Result:=False;
 If Not Check(FileExists(Source),'Missing file: '+Source) Then Exit;
 If Not Check(Not FileExists(Dest),'Refusing overwrite: '+Dest) Then Exit;
 A:=TFileStream.Create(Source,fmOpenRead Or fmShareDenyWrite);
 Try
  B:=TFileStream.Create(Dest,fmCreate);
  Try B.CopyFrom(A,0); Result:=Check(A.Size=B.Size,'Copy size mismatch');
  Finally B.Free; End;
 Finally A.Free; End;
End;

Procedure OpenCopy(S,FileName);
Var SD : IServerDocument;
Begin
 If Failure<>'' Then Exit;
 SheetNames[S]:=FileName;
 SD:=Client.OpenDocument('SCH',BASE+'sch\'+FileName);
 If Not Check(SD<>Nil,'Cannot inspect saved sheet '+FileName) Then Exit;
 If Not Check(Not SD.Modified,'Unsaved changes in '+FileName+'. Save your intended work first.') Then Exit;
 If Not CopyFileChecked(BASE+'sch\'+FileName,RunDir+'original-'+FileName) Then Exit;
 If Not CopyFileChecked(BASE+'sch\'+FileName,RunDir+FileName) Then Exit;
 Docs[S]:=Client.OpenDocument('SCH',RunDir+FileName);
 If Not Check(Docs[S]<>Nil,'Cannot open repair COPY '+FileName) Then Exit;
 Client.ShowDocument(Docs[S]); Docs[S].Focus;
 Sheets[S]:=SchServer.GetCurrentSchDocument;
 Check(Sheets[S]<>Nil,'No native sheet for COPY '+FileName);
 Note('COPY|'+FileName+'|original untouched');
End;

Function FindPart(D,RefText) : ISch_Component;
Var I : ISch_Iterator; C : ISch_Component; Count : Integer;
Begin
 Result:=Nil; Count:=0; I:=D.SchIterator_Create;
 I.AddFilter_ObjectSet(MkSet(eSchComponent));
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin
   If C.Designator.Text=RefText Then Begin Result:=C; Count:=Count+1; End;
   C:=I.NextSchObject;
  End;
 Finally D.SchIterator_Destroy(I); End;
 Check(Count<=1,'Duplicate designator '+RefText);
End;

Function FindPin(C,PinText) : ISch_Pin;
Var I : ISch_Iterator; P : ISch_Pin; Count : Integer;
Begin
 Result:=Nil; Count:=0; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   If (P.Designator=PinText) And (P.OwnerPartId=1) And (P.OwnerPartDisplayMode=0) Then Begin Result:=P; Count:=Count+1; End;
   P:=I.NextSchObject;
  End;
 Finally C.SchIterator_Destroy(I); End;
 If Not Check(Count=1,'Missing/duplicate native pin '+C.LibReference+'.'+PinText) Then Result:=Nil;
End;

Function IsBody(O) : Boolean;
Begin
 Result:=(O.ObjectId=eLine) Or (O.ObjectId=ePolyline) Or (O.ObjectId=ePolygon) Or
 (O.ObjectId=eRectangle) Or (O.ObjectId=eRoundRectangle) Or (O.ObjectId=eArc) Or
 (O.ObjectId=eEllipticalArc) Or (O.ObjectId=eEllipse);
End;

Function BodyCount(C) : Integer;
Var I : ISch_Iterator; O : ISch_BasicContainer;
Begin
 Result:=0; I:=C.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin If IsBody(O) Then Result:=Result+1; O:=I.NextSchObject; End;
 Finally C.SchIterator_Destroy(I); End;
End;

Procedure Param(N,NameText,ValueText);
Var I : ISch_Iterator; P : ISch_Parameter;
Begin
 If Failure<>'' Then Exit;
 I:=NewParts[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eParameter));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin If UpperCase(P.Name)=UpperCase(NameText) Then Break; P:=I.NextSchObject; End;
 Finally NewParts[N].SchIterator_Destroy(I); End;
 If P=Nil Then Begin
  P:=SchServer.SchObjectFactory(eParameter,eCreate_GlobalCopy);
  P.Name:=NameText; NewParts[N].AddSchObject(P);
 End;
 P.Text:=ValueText; P.IsHidden:=True;
End;

Procedure LoadPart(N,S,RefText,UID,SourceFile,SourceRef,Rotation,CommentText,DX,DY,CX,CY);
Var C : ISch_Component;
Begin
 If Failure<>'' Then Exit;
 Phase:='LOAD '+RefText; Note(Phase);
 ExpectedRef[N]:=RefText; ExpectedUID[N]:=UID; ExpectedSource[N]:=SourceRef;
 PinCounts[N]:=0;
 NeedsManual[N]:=False;
 PartSheet[N]:=S; OldParts[N]:=FindPart(Sheets[S],RefText);
 If Failure<>'' Then Exit;
 If OldParts[N]<>Nil Then
  If Not Check(OldParts[N].UniqueId=UID,'Identity changed for '+RefText+'. Regenerate instead of overwriting it.') Then Exit;
 Client.ShowDocument(Docs[S]); Docs[S].Focus;
 { Load the WHOLE native symbol. Do not clone a SchLib iterator entry. }
 C:=SchServer.LoadComponentFromLibrary(SourceRef,BASE+'lib\reviewed-sources\'+SourceFile);
 If Not Check(C<>Nil,'Native library loader returned nil: '+SourceRef) Then Exit;
 NewParts[N]:=C;
 If Not Check(BodyCount(C)>0,'Native library loader returned a bodyless symbol: '+SourceRef) Then Exit;
 C.CurrentPartId:=1; C.DisplayMode:=0; C.Orientation:=Rotation;
 C.Designator.Text:=RefText; C.Comment.Text:=CommentText;
 C.SourceLibraryName:=BASE+'lib\reviewed-sources\'+SourceFile;
 C.Designator.Location:=Point(DX,DY); C.Comment.Location:=Point(CX,CY);
 Note('NATIVE_SOURCE|'+RefText+'|'+SourceFile+'|'+SourceRef+'|BODY_OBJECTS='+IntToStr(BodyCount(C)));
End;

Procedure MapPin(N,SourceID,TargetID,X,Y);
Var P,OldP : ISch_Pin;
Begin
 If Failure<>'' Then Exit;
 P:=FindPin(NewParts[N],SourceID); If P=Nil Then Exit;
 If OldParts[N]<>Nil Then Begin
  OldP:=FindPin(OldParts[N],TargetID); If OldP=Nil Then Exit;
  If Not Check((OldP.Location.X=X) And (OldP.Location.Y=Y),'Connection moved since manifest: '+NewParts[N].Designator.Text+'.'+TargetID) Then Exit;
 End;
 P.Designator:=TargetID;
 Pins[NP]:=P; PinPart[NP]:=N; TargetX[NP]:=X; TargetY[NP]:=Y;
 NP:=NP+1; PinCounts[N]:=PinCounts[N]+1;
End;

Procedure PositionPart(N,ExpectedPins,DX,DY,CX,CY);
Var K,First,MinX,MaxX,MinY,MaxY,TMinX,TMaxX,TMinY,TMaxY,X,Y : Integer;
 I : ISch_Iterator; P : ISch_Pin; Count : Integer;
Begin
 If Failure<>'' Then Exit;
 If Not Check(PinCounts[N]=ExpectedPins,'Pin contract count mismatch') Then Exit;
 I:=NewParts[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin)); Count:=0;
 Try P:=I.FirstSchObject; While P<>Nil Do Begin Count:=Count+1; P:=I.NextSchObject; End;
 Finally NewParts[N].SchIterator_Destroy(I); End;
 If Not Check(Count=ExpectedPins,'Unexpected alternate/extra native pins on '+NewParts[N].Designator.Text) Then Exit;
 First:=-1;
 For K:=0 To NP-1 Do If PinPart[K]=N Then Begin
  X:=Pins[K].Location.X; Y:=Pins[K].Location.Y;
  If First=-1 Then Begin
   First:=K; MinX:=X; MaxX:=X; MinY:=Y; MaxY:=Y;
   TMinX:=TargetX[K]; TMaxX:=TargetX[K]; TMinY:=TargetY[K]; TMaxY:=TargetY[K];
  End;
  If X<MinX Then MinX:=X; If X>MaxX Then MaxX:=X;
  If Y<MinY Then MinY:=Y; If Y>MaxY Then MaxY:=Y;
  If TargetX[K]<TMinX Then TMinX:=TargetX[K]; If TargetX[K]>TMaxX Then TMaxX:=TargetX[K];
  If TargetY[K]<TMinY Then TMinY:=TargetY[K]; If TargetY[K]>TMaxY Then TMaxY:=TargetY[K];
 End;
 NewParts[N].MoveToXY(NewParts[N].Location.X+(TMinX+TMaxX-MinX-MaxX) Div 2,
                     NewParts[N].Location.Y+(TMinY+TMaxY-MinY-MaxY) Div 2);
 NewParts[N].Designator.Location:=Point(DX,DY); NewParts[N].Comment.Location:=Point(CX,CY);
 For K:=0 To NP-1 Do If PinPart[K]=N Then
  If (Abs(Pins[K].Location.X-TargetX[K])>MilsToCoord(150)) Or
     (Abs(Pins[K].Location.Y-TargetY[K])>MilsToCoord(150)) Then NeedsManual[N]:=True;
 If NeedsManual[N] Then Begin
  ManualCount:=ManualCount+1;
  Note('MANUAL_LAYOUT|'+NewParts[N].Designator.Text+'|Native symbol exceeds old space. Placed anyway; automatic wire bridges disabled for this component. Reposition and reconnect every pin manually.');
 End;
End;

Procedure Footprint(N,Pattern,RelativeFile);
Var M : ISch_Implementation; I : ISch_Iterator;
Begin
 If Failure<>'' Then Exit;
 If Not Check(FileExists(BASE+RelativeFile),'Missing PCB library '+RelativeFile) Then Exit;
 I:=NewParts[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eImplementation));
 M:=I.FirstSchObject; NewParts[N].SchIterator_Destroy(I);
 If Not Check(M=Nil,'Unexpected model on source symbol; refusing to attach a second footprint') Then Exit;
 M:=NewParts[N].AddSchImplementation; M.ModelType:='PCBLIB'; M.ModelName:=Pattern; M.IsCurrent:=True;
 M.AddDataFileLink(Pattern,BASE+RelativeFile,'PCBLIB');
 Note('FOOTPRINT_RETAINED|'+NewParts[N].Designator.Text+'|'+Pattern+'|3D NOT CHANGED');
End;

Procedure VerifyRegisteredPart(N);
Var K,S,Count,UIDCount : Integer; C,Other : ISch_Component;
 I,J : ISch_Iterator; P : ISch_Pin;
Begin
 Phase:='VERIFY '+ExpectedRef[N]+' in '+SheetNames[PartSheet[N]]; Note(Phase);
 C:=FindPart(Sheets[PartSheet[N]],ExpectedRef[N]);
 If Not Check(C<>Nil,'Component not found on repair sheet after registration') Then Exit;
 { Fresh component IDs are allowed. Check validity, not equality to the old ID. }
 Check(C.UniqueId<>'','Registered component has an empty unique ID');
 UIDCount:=0;
 For S:=0 To 2 Do Begin
  J:=Sheets[S].SchIterator_Create; J.AddFilter_ObjectSet(MkSet(eSchComponent));
  Try
   Other:=J.FirstSchObject;
   While Other<>Nil Do Begin
    If Other.UniqueId=C.UniqueId Then UIDCount:=UIDCount+1;
    Other:=J.NextSchObject;
   End;
  Finally Sheets[S].SchIterator_Destroy(J); End;
 End;
 Check(UIDCount=1,'Registered unique ID appears '+IntToStr(UIDCount)+' times across repair sheets');
 Note('UID_MAP|'+ExpectedRef[N]+'|'+SheetNames[PartSheet[N]]+'|OLD='+ExpectedUID[N]+'|NEW='+C.UniqueId+'|PCB links require reconciliation');
 Check(C.LibReference=ExpectedSource[N],
   'Library symbol mismatch: expected '+ExpectedSource[N]+', found '+C.LibReference);
 Check(BodyCount(C)>0,'Registered component has no symbol body');
 Count:=0; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try P:=I.FirstSchObject; While P<>Nil Do Begin Count:=Count+1; P:=I.NextSchObject; End;
 Finally C.SchIterator_Destroy(I); End;
 Check(Count=PinCounts[N],
   'Registered pin count mismatch: expected '+IntToStr(PinCounts[N])+', found '+IntToStr(Count));
 For K:=0 To NP-1 Do If PinPart[K]=N Then Begin
  Phase:='VERIFY '+ExpectedRef[N]+'.'+Pins[K].Designator+' in '+SheetNames[PartSheet[N]];
  P:=FindPin(C,Pins[K].Designator);
  If P<>Nil Then
   Check((P.Location.X=Pins[K].Location.X) And (P.Location.Y=Pins[K].Location.Y),
    'Registered pin position differs from prepared native symbol');
 End;
End;

Function CountComponentUID(UIDText) : Integer;
Var S : Integer; I : ISch_Iterator; C : ISch_Component;
Begin
 Result:=0;
 For S:=0 To 2 Do Begin
  I:=Sheets[S].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
  Try
   C:=I.FirstSchObject;
   While C<>Nil Do Begin
    If C.UniqueId=UIDText Then Result:=Result+1;
    C:=I.NextSchObject;
   End;
  Finally Sheets[S].SchIterator_Destroy(I); End;
 End;
End;

Procedure RepairIDCollisions;
Var N,S,Attempts : Integer; C,Registered : ISch_Component;
 WS : IWorkspace; OldUID,NewUID : String;
Begin
 WS:=Nil;
 For N:=0 To PARTS-1 Do Begin
  S:=PartSheet[N]; Phase:='ID COLLISION CHECK '+ExpectedRef[N]+' in '+SheetNames[S];
  C:=FindPart(Sheets[S],ExpectedRef[N]); If Failure<>'' Then Exit;
  If C<>Nil Then If (C.UniqueId='') Or (CountComponentUID(C.UniqueId)>1) Then Begin
   OldUID:=C.UniqueId;
   If WS=Nil Then WS:=GetWorkspace;
   If Not Check(WS<>Nil,'Cannot obtain native ID generator') Then Exit;
   Attempts:=0;
   Repeat
    NewUID:=WS.DM_GenerateUniqueID; Attempts:=Attempts+1;
   Until ((NewUID<>'') And (CountComponentUID(NewUID)=0)) Or (Attempts>=8);
   If Not Check((NewUID<>'') And (CountComponentUID(NewUID)=0),'Native ID generator did not produce an unused ID') Then Exit;
   Client.ShowDocument(Docs[S]); Docs[S].Focus;
   SchServer.ProcessControl.PreProcess(Sheets[S],'Resolve replacement component ID collision');
   Try
    SchServer.RobotManager.SendMessage(C.I_ObjectAddress,c_BroadCast,SCHM_BeginModify,c_NoEventData);
    Try C.SetState_UniqueId(NewUID);
    Finally SchServer.RobotManager.SendMessage(C.I_ObjectAddress,c_BroadCast,SCHM_EndModify,c_NoEventData); End;
   Finally SchServer.ProcessControl.PostProcess(Sheets[S],'Resolve replacement component ID collision'); End;
   Docs[S].Modified:=True;
   Registered:=FindPart(Sheets[S],ExpectedRef[N]); If Failure<>'' Then Exit;
   If Registered<>Nil Then Begin
    Note('UID_COLLISION_REPAIR|'+ExpectedRef[N]+'|'+SheetNames[S]+'|OLD='+OldUID+'|REQUESTED='+NewUID+'|ACTUAL='+Registered.UniqueId);
    If (Registered.UniqueId<>NewUID) Or (CountComponentUID(Registered.UniqueId)<>1) Then
     Note('UID_COLLISION_UNRESOLVED|'+ExpectedRef[N]+'|Final verification will block saving if the ID is still invalid');
   End Else Note('UID_COLLISION_UNRESOLVED|'+ExpectedRef[N]+'|Component missing; final verification will block saving');
  End;
 End;
End;

Procedure ApplyCopies;
Var S,N,K,X,Y,BeforeIssues : Integer; C : ISch_Component;
Begin
 If Failure<>'' Then Exit;
 For S:=0 To 2 Do Begin
  Phase:='APPLY COPY '+IntToStr(S); Note(Phase);
  Client.ShowDocument(Docs[S]); Docs[S].Focus;
  SchServer.ProcessControl.PreProcess(Sheets[S],'Restore complete native components on repair copy');
  Try
   For N:=0 To PARTS-1 Do If PartSheet[N]=S Then Begin
    C:=NewParts[N];
    Note('UID_BEFORE_REGISTER|'+ExpectedRef[N]+'|EXPECTED='+ExpectedUID[N]+'|ACTUAL='+C.UniqueId);
    Sheets[S].RegisterSchObjectInContainer(C);
    Note('UID_AFTER_REGISTER|'+ExpectedRef[N]+'|ACTUAL='+C.UniqueId);
    If OldParts[N]<>Nil Then Begin Sheets[S].UnRegisterSchObjectFromContainer(OldParts[N]); Replaced:=Replaced+1; End
    Else Restored:=Restored+1;
    Note('UID_AFTER_REMOVE_OLD|'+ExpectedRef[N]+'|ACTUAL='+C.UniqueId);
    { Keep the fresh ID assigned by Altium. Do not modify existing wires. }
    For K:=0 To NP-1 Do If PinPart[K]=N Then Begin
     X:=Pins[K].Location.X; Y:=Pins[K].Location.Y;
     If (X<>TargetX[K]) Or (Y<>TargetY[K]) Then
      Note('MANUAL_CONNECTION|'+C.Designator.Text+'.'+Pins[K].Designator+'|Check and reconnect to original net anchor')
     Else Note('PIN_AT_OLD_ANCHOR|'+C.Designator.Text+'.'+Pins[K].Designator);
     Note('PIN|'+C.Designator.Text+'.'+Pins[K].Designator+'|OLD='+IntToStr(TargetX[K])+','+IntToStr(TargetY[K])+'|NEW='+IntToStr(X)+','+IntToStr(Y));
    End;
    Note('REPLACED_COPY|'+C.Designator.Text+'|'+C.LibReference);
   End;
  Finally SchServer.ProcessControl.PostProcess(Sheets[S],'Restore complete native components on repair copy'); End;
  Sheets[S].GraphicallyInvalidate; Docs[S].Modified:=True;
 End;
 RepairIDCollisions; If Failure<>'' Then Exit;
 { Collect all verification failures. Preflight/application errors still stop immediately. }
 CollectingVerification:=True;
 Try
  For N:=0 To PARTS-1 Do Begin
   BeforeIssues:=VerifyIssues;
   Try VerifyRegisteredPart(N);
   Except Check(False,'Runtime error while inspecting component; remaining checks for this component unavailable'); End;
   If VerifyIssues=BeforeIssues Then Begin
    VerifyPassed:=VerifyPassed+1;
    Note('VERIFY_OK|'+ExpectedRef[N]+'|'+SheetNames[PartSheet[N]]);
   End Else Begin
    VerifyFailed:=VerifyFailed+1;
    Note('VERIFY_FAILED|'+ExpectedRef[N]+'|'+SheetNames[PartSheet[N]]+'|ISSUES='+IntToStr(VerifyIssues-BeforeIssues));
   End;
  End;
 Finally CollectingVerification:=False; End;
 Note('VERIFY_SUMMARY|CHECKED='+IntToStr(VerifyPassed+VerifyFailed)+'|PASSED='+IntToStr(VerifyPassed)+'|FAILED='+IntToStr(VerifyFailed)+'|ISSUES='+IntToStr(VerifyIssues));
 If VerifyIssues>0 Then Begin
  Failure:='Verification finished: '+IntToStr(VerifyFailed)+' of '+IntToStr(PARTS)+' components failed, '+IntToStr(VerifyIssues)+' issue(s). See VERIFY_ERROR entries. Repair copies NOT saved.';
  Note('STOP|'+Failure); Exit;
 End;
 For S:=0 To 2 Do
  If Not Check(Docs[S].DoFileSave('SCHBinary5.0'),'Could not save repair copy') Then Exit;
 Note('COPIES_SAVED|Replaced='+IntToStr(Replaced)+'|Restored='+IntToStr(Restored)+'|WireSegments='+IntToStr(WireCount));
 Note('MANUAL_LAYOUT_COUNT|'+IntToStr(ManualCount)+'|Do not update PCB before manual reconnection and validation');
 Note('REQUIRED|Existing wires unchanged: manually check/reconnect all replacements. Reconcile schematic-to-PCB component links using UID_MAP before any ECO. Visual inspection and compiled connectivity/ERC required. PCB untouched.');
End;

Procedure BuildAll;
Begin
 OpenCopy(0,'01_Power_Control.SchDoc');
 OpenCopy(1,'02_Beam_Inputs.SchDoc');
 OpenCopy(2,'03_UI_Outputs.SchDoc');
 LoadPart(0,0,'D1','XLDUBJEV','SCH - DIODES - DIODE TVS UNI.SCHLIB','DIODE TVS UNI',1,'SMBJ15A',37400000,39700000,41100000,36000000);
 MapPin(0,'2','2',38800000,39400000);
 MapPin(0,'1','1',38800000,38400000);
 PositionPart(0,2,37400000,39700000,41100000,36000000);
 Param(0,'Value','SMBJ15A');
 Param(0,'Part Number','SMBJ15A');
 Param(0,'Manufacturer','Littelfuse');
 Param(0,'Manufacturer Part Number','SMBJ15A');
 Param(0,'Intended footprint','SMBJ15A_A1_K2');
 Param(0,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(0,'Symbol source','Celestial / SCH - DIODES - DIODE TVS UNI.SCHLIB / DIODE TVS UNI');
 Param(0,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(0,'SMBJ15A_A1_K2','lib\PinRepairFootprints.PcbLib');
 LoadPart(1,0,'C1','WWKCXFFV','SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB','Polarised Capacitor',1,'470uF / 25V',35000000,39100000,35200000,34100000);
 MapPin(1,'2','2',36200000,39300000);
 MapPin(1,'1','1',36200000,38300000);
 PositionPart(1,2,35000000,39100000,35200000,34100000);
 Param(1,'Part Number','EEU-FR1E471');
 Param(1,'Valor','470uF / 25V');
 Param(1,'Manufacturer','Panasonic');
 Param(1,'Manufacturer Part Number','EEU-FR1E471');
 Param(1,'Intended footprint','PANASONIC_EEUFR1E471_D10_P5');
 Param(1,'Polarity','Pin 1 positive; pin 2 negative');
 Param(1,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(1,'Value','470uF / 25V');
 Param(1,'Symbol source','Celestial / SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB / Polarised Capacitor');
 Param(1,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(1,'PANASONIC_EEUFR1E471_D10_P5','lib\PinRepairFootprints.PcbLib');
 LoadPart(2,0,'C5','YZOVPMIX','SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB','Polarised Capacitor',1,'470uF / 10V',26100000,39900000,29300000,36000000);
 MapPin(2,'2','2',27400000,40000000);
 MapPin(2,'1','1',27400000,39000000);
 PositionPart(2,2,26100000,39900000,29300000,36000000);
 Param(2,'Part Number','EEU-FR1A471');
 Param(2,'Valor','470uF / 10V');
 Param(2,'Manufacturer','Panasonic');
 Param(2,'Manufacturer Part Number','EEU-FR1A471');
 Param(2,'Intended footprint','PANASONIC_EEUFR1A471_D8_P3_5');
 Param(2,'Polarity','Pin 1 positive; pin 2 negative');
 Param(2,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(2,'Value','470uF / 10V');
 Param(2,'Symbol source','Celestial / SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB / Polarised Capacitor');
 Param(2,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(2,'PANASONIC_EEUFR1A471_D8_P3_5','lib\PinRepairFootprints.PcbLib');
 LoadPart(3,1,'R5','OPKPKOII','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'2.2k',28200000,64200000,28100000,62200000);
 MapPin(3,'2','2',30500000,62500000);
 MapPin(3,'1','1',27500000,62500000);
 PositionPart(3,2,28200000,64200000,28100000,62200000);
 Param(3,'Part number','RC0805FR-072K2L');
 Param(3,'Valor','2.2k');
 Param(3,'Manufacturer','Yageo');
 Param(3,'Manufacturer Part Number','RC0805FR-072K2L');
 Param(3,'Intended footprint','YAGEO RES 0805_2012');
 Param(3,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(3,'Value','2.2k');
 Param(3,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(3,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(3,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(4,1,'U2','YCLQQYOQ','SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,'LTV-817S',42500000,64000000,42500000,57800000);
 MapPin(4,'2','2',39600000,59500000);
 MapPin(4,'1','1',39600000,62500000);
 MapPin(4,'3','3',48400000,59500000);
 MapPin(4,'4','4',48400000,62500000);
 PositionPart(4,4,42500000,64000000,42500000,57800000);
 Param(4,'Manufacturer','Lite-On');
 Param(4,'Manufacturer Part Number','LTV-817S-TA1');
 Param(4,'Package','SMD4');
 Param(4,'Populate','Yes');
 Param(4,'Intended footprint','LITEON LTV-817');
 Param(4,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(4,'Value','LTV-817S-TA1');
 Param(4,'Valor','LTV-817S');
 Param(4,'Part Number','LTV-817S-TA1');
 Param(4,'Symbol source','Celestial / SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB / Optoisolator');
 Param(4,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(4,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
 LoadPart(5,1,'R6','LQPQFUVB','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'10k',60200000,69200000,60100000,67200000);
 MapPin(5,'2','2',62500000,67500000);
 MapPin(5,'1','1',59500000,67500000);
 PositionPart(5,2,60200000,69200000,60100000,67200000);
 Param(5,'Part number','RC0805FR-0710KL');
 Param(5,'Valor','10k');
 Param(5,'Manufacturer','Yageo');
 Param(5,'Manufacturer Part Number','RC0805FR-0710KL');
 Param(5,'Intended footprint','YAGEO RES 0805_2012');
 Param(5,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(5,'Value','10k');
 Param(5,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(5,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(5,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(6,1,'R7','WQAGWPVX','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'1k',70200000,64200000,70100000,62200000);
 MapPin(6,'2','2',72500000,62500000);
 MapPin(6,'1','1',69500000,62500000);
 PositionPart(6,2,70200000,64200000,70100000,62200000);
 Param(6,'Part number','RC0805FR-071KL');
 Param(6,'Valor','1k');
 Param(6,'Manufacturer','Yageo');
 Param(6,'Manufacturer Part Number','RC0805FR-071KL');
 Param(6,'Intended footprint','YAGEO RES 0805_2012');
 Param(6,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(6,'Value','1k');
 Param(6,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(6,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(6,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(7,1,'C2','IZQAVBIX','SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,'100nF',81700000,60200000,81100000,56300000);
 MapPin(7,'1','1',82500000,58000000);
 MapPin(7,'2','2',82500000,59000000);
 PositionPart(7,2,81700000,60200000,81100000,56300000);
 Param(7,'Part Number','GRM21BR71H104KA01L');
 Param(7,'Valor','100nF');
 Param(7,'Manufacturer','Murata');
 Param(7,'Manufacturer Part Number','GRM21BR71H104KA01L');
 Param(7,'Intended footprint','MURATA GRM21B 0805_2012');
 Param(7,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(7,'Value','100nF');
 Param(7,'Symbol source','Celestial / SCH - PASSIVES - CAPACITOR.SCHLIB / Capacitor');
 Param(7,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(7,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
 LoadPart(8,1,'D2','FPPXBLTW','SCH - DIODES - DIODE.SCHLIB','Diode',0,'1N4148W',43200000,57300000,42600000,53400000);
 MapPin(8,'2','2',44500000,55600000);
 MapPin(8,'1','1',43500000,55600000);
 PositionPart(8,2,43200000,57300000,42600000,53400000);
 Param(8,'Value','1N4148W');
 Param(8,'Part Number','1N4148W');
 Param(8,'Manufacturer','Nexperia');
 Param(8,'Manufacturer Part Number','1N4148W');
 Param(8,'Intended footprint','1N4148W_SOD123_A1_K2');
 Param(8,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(8,'Symbol source','Celestial / SCH - DIODES - DIODE.SCHLIB / Diode');
 Param(8,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(8,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
 LoadPart(9,1,'R8','YUWSQPCU','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'2.2k',28200000,49700000,28100000,47700000);
 MapPin(9,'2','2',30500000,48000000);
 MapPin(9,'1','1',27500000,48000000);
 PositionPart(9,2,28200000,49700000,28100000,47700000);
 Param(9,'Part number','RC0805FR-072K2L');
 Param(9,'Valor','2.2k');
 Param(9,'Manufacturer','Yageo');
 Param(9,'Manufacturer Part Number','RC0805FR-072K2L');
 Param(9,'Intended footprint','YAGEO RES 0805_2012');
 Param(9,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(9,'Value','2.2k');
 Param(9,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(9,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(9,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(10,1,'U3','MYWOSINS','SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,'LTV-817S',42500000,49500000,42500000,43300000);
 MapPin(10,'2','2',39600000,45000000);
 MapPin(10,'1','1',39600000,48000000);
 MapPin(10,'3','3',48400000,45000000);
 MapPin(10,'4','4',48400000,48000000);
 PositionPart(10,4,42500000,49500000,42500000,43300000);
 Param(10,'Manufacturer','Lite-On');
 Param(10,'Manufacturer Part Number','LTV-817S-TA1');
 Param(10,'Package','SMD4');
 Param(10,'Populate','Yes');
 Param(10,'Intended footprint','LITEON LTV-817');
 Param(10,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(10,'Value','LTV-817S-TA1');
 Param(10,'Valor','LTV-817S');
 Param(10,'Part Number','LTV-817S-TA1');
 Param(10,'Symbol source','Celestial / SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB / Optoisolator');
 Param(10,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(10,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
 LoadPart(11,1,'R9','LMBAJDRZ','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'10k',60200000,54700000,60100000,52700000);
 MapPin(11,'2','2',62500000,53000000);
 MapPin(11,'1','1',59500000,53000000);
 PositionPart(11,2,60200000,54700000,60100000,52700000);
 Param(11,'Part number','RC0805FR-0710KL');
 Param(11,'Valor','10k');
 Param(11,'Manufacturer','Yageo');
 Param(11,'Manufacturer Part Number','RC0805FR-0710KL');
 Param(11,'Intended footprint','YAGEO RES 0805_2012');
 Param(11,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(11,'Value','10k');
 Param(11,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(11,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(11,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(12,1,'R10','KAYRFWGZ','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'1k',70200000,49700000,70100000,47700000);
 MapPin(12,'2','2',72500000,48000000);
 MapPin(12,'1','1',69500000,48000000);
 PositionPart(12,2,70200000,49700000,70100000,47700000);
 Param(12,'Part number','RC0805FR-071KL');
 Param(12,'Valor','1k');
 Param(12,'Manufacturer','Yageo');
 Param(12,'Manufacturer Part Number','RC0805FR-071KL');
 Param(12,'Intended footprint','YAGEO RES 0805_2012');
 Param(12,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(12,'Value','1k');
 Param(12,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(12,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(12,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(13,1,'C3','MZWSXMOZ','SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,'100nF',81700000,45700000,81100000,41800000);
 MapPin(13,'1','1',82500000,43500000);
 MapPin(13,'2','2',82500000,44500000);
 PositionPart(13,2,81700000,45700000,81100000,41800000);
 Param(13,'Part Number','GRM21BR71H104KA01L');
 Param(13,'Valor','100nF');
 Param(13,'Manufacturer','Murata');
 Param(13,'Manufacturer Part Number','GRM21BR71H104KA01L');
 Param(13,'Intended footprint','MURATA GRM21B 0805_2012');
 Param(13,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(13,'Value','100nF');
 Param(13,'Symbol source','Celestial / SCH - PASSIVES - CAPACITOR.SCHLIB / Capacitor');
 Param(13,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(13,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
 LoadPart(14,1,'D3','TPVEGXUT','SCH - DIODES - DIODE.SCHLIB','Diode',0,'1N4148W',43200000,42800000,42600000,38900000);
 MapPin(14,'2','2',44500000,41100000);
 MapPin(14,'1','1',43500000,41100000);
 PositionPart(14,2,43200000,42800000,42600000,38900000);
 Param(14,'Value','1N4148W');
 Param(14,'Part Number','1N4148W');
 Param(14,'Manufacturer','Nexperia');
 Param(14,'Manufacturer Part Number','1N4148W');
 Param(14,'Intended footprint','1N4148W_SOD123_A1_K2');
 Param(14,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(14,'Symbol source','Celestial / SCH - DIODES - DIODE.SCHLIB / Diode');
 Param(14,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(14,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
 LoadPart(15,1,'R11','BNPMVCHO','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'2.2k',28200000,35200000,28100000,33200000);
 MapPin(15,'2','2',30500000,33500000);
 MapPin(15,'1','1',27500000,33500000);
 PositionPart(15,2,28200000,35200000,28100000,33200000);
 Param(15,'Part number','RC0805FR-072K2L');
 Param(15,'Valor','2.2k');
 Param(15,'Manufacturer','Yageo');
 Param(15,'Manufacturer Part Number','RC0805FR-072K2L');
 Param(15,'Intended footprint','YAGEO RES 0805_2012');
 Param(15,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(15,'Value','2.2k');
 Param(15,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(15,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(15,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(16,1,'U4','FBTKFFOT','SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,'LTV-817S',42500000,35000000,42500000,28800000);
 MapPin(16,'2','2',39600000,30500000);
 MapPin(16,'1','1',39600000,33500000);
 MapPin(16,'3','3',48400000,30500000);
 MapPin(16,'4','4',48400000,33500000);
 PositionPart(16,4,42500000,35000000,42500000,28800000);
 Param(16,'Manufacturer','Lite-On');
 Param(16,'Manufacturer Part Number','LTV-817S-TA1');
 Param(16,'Package','SMD4');
 Param(16,'Populate','Yes');
 Param(16,'Intended footprint','LITEON LTV-817');
 Param(16,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(16,'Value','LTV-817S-TA1');
 Param(16,'Valor','LTV-817S');
 Param(16,'Part Number','LTV-817S-TA1');
 Param(16,'Symbol source','Celestial / SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB / Optoisolator');
 Param(16,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(16,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
 LoadPart(17,1,'R12','IKVPXVWT','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'10k',60200000,40200000,60100000,38200000);
 MapPin(17,'2','2',62500000,38500000);
 MapPin(17,'1','1',59500000,38500000);
 PositionPart(17,2,60200000,40200000,60100000,38200000);
 Param(17,'Part number','RC0805FR-0710KL');
 Param(17,'Valor','10k');
 Param(17,'Manufacturer','Yageo');
 Param(17,'Manufacturer Part Number','RC0805FR-0710KL');
 Param(17,'Intended footprint','YAGEO RES 0805_2012');
 Param(17,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(17,'Value','10k');
 Param(17,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(17,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(17,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(18,1,'R13','YWTZULMD','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'1k',70200000,35200000,70100000,33200000);
 MapPin(18,'2','2',72500000,33500000);
 MapPin(18,'1','1',69500000,33500000);
 PositionPart(18,2,70200000,35200000,70100000,33200000);
 Param(18,'Part number','RC0805FR-071KL');
 Param(18,'Valor','1k');
 Param(18,'Manufacturer','Yageo');
 Param(18,'Manufacturer Part Number','RC0805FR-071KL');
 Param(18,'Intended footprint','YAGEO RES 0805_2012');
 Param(18,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(18,'Value','1k');
 Param(18,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(18,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(18,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(19,1,'C4','MINBGXGG','SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,'100nF',81700000,31200000,81100000,27300000);
 MapPin(19,'1','1',82500000,29000000);
 MapPin(19,'2','2',82500000,30000000);
 PositionPart(19,2,81700000,31200000,81100000,27300000);
 Param(19,'Part Number','GRM21BR71H104KA01L');
 Param(19,'Valor','100nF');
 Param(19,'Manufacturer','Murata');
 Param(19,'Manufacturer Part Number','GRM21BR71H104KA01L');
 Param(19,'Intended footprint','MURATA GRM21B 0805_2012');
 Param(19,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(19,'Value','100nF');
 Param(19,'Symbol source','Celestial / SCH - PASSIVES - CAPACITOR.SCHLIB / Capacitor');
 Param(19,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(19,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
 LoadPart(20,1,'D4','BGZYRAXD','SCH - DIODES - DIODE.SCHLIB','Diode',0,'1N4148W',43200000,28300000,42600000,24400000);
 MapPin(20,'2','2',44500000,26600000);
 MapPin(20,'1','1',43500000,26600000);
 PositionPart(20,2,43200000,28300000,42600000,24400000);
 Param(20,'Value','1N4148W');
 Param(20,'Part Number','1N4148W');
 Param(20,'Manufacturer','Nexperia');
 Param(20,'Manufacturer Part Number','1N4148W');
 Param(20,'Intended footprint','1N4148W_SOD123_A1_K2');
 Param(20,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(20,'Symbol source','Celestial / SCH - DIODES - DIODE.SCHLIB / Diode');
 Param(20,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(20,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
 LoadPart(21,1,'R18','QKHBVNDC','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'2.2k',28200000,20700000,28100000,18700000);
 MapPin(21,'2','2',30500000,19000000);
 MapPin(21,'1','1',27500000,19000000);
 PositionPart(21,2,28200000,20700000,28100000,18700000);
 Param(21,'Part number','RC0805FR-072K2L');
 Param(21,'Valor','2.2k');
 Param(21,'Manufacturer','Yageo');
 Param(21,'Manufacturer Part Number','RC0805FR-072K2L');
 Param(21,'Intended footprint','YAGEO RES 0805_2012');
 Param(21,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(21,'Value','2.2k');
 Param(21,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(21,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(21,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(22,1,'U5','JQARKEUG','SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,'LTV-817S',42500000,20500000,42500000,14300000);
 MapPin(22,'2','2',39600000,16000000);
 MapPin(22,'1','1',39600000,19000000);
 MapPin(22,'3','3',48400000,16000000);
 MapPin(22,'4','4',48400000,19000000);
 PositionPart(22,4,42500000,20500000,42500000,14300000);
 Param(22,'Manufacturer','Lite-On');
 Param(22,'Manufacturer Part Number','LTV-817S-TA1');
 Param(22,'Package','SMD4');
 Param(22,'Populate','Yes');
 Param(22,'Intended footprint','LITEON LTV-817');
 Param(22,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(22,'Value','LTV-817S-TA1');
 Param(22,'Valor','LTV-817S');
 Param(22,'Part Number','LTV-817S-TA1');
 Param(22,'Symbol source','Celestial / SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB / Optoisolator');
 Param(22,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(22,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
 LoadPart(23,1,'R19','FZANGHTO','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'10k',60200000,25700000,60100000,23700000);
 MapPin(23,'2','2',62500000,24000000);
 MapPin(23,'1','1',59500000,24000000);
 PositionPart(23,2,60200000,25700000,60100000,23700000);
 Param(23,'Part number','RC0805FR-0710KL');
 Param(23,'Valor','10k');
 Param(23,'Manufacturer','Yageo');
 Param(23,'Manufacturer Part Number','RC0805FR-0710KL');
 Param(23,'Intended footprint','YAGEO RES 0805_2012');
 Param(23,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(23,'Value','10k');
 Param(23,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(23,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(23,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(24,1,'R20','LJLJBJVM','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'1k',70200000,20700000,70100000,18700000);
 MapPin(24,'2','2',72500000,19000000);
 MapPin(24,'1','1',69500000,19000000);
 PositionPart(24,2,70200000,20700000,70100000,18700000);
 Param(24,'Part number','RC0805FR-071KL');
 Param(24,'Valor','1k');
 Param(24,'Manufacturer','Yageo');
 Param(24,'Manufacturer Part Number','RC0805FR-071KL');
 Param(24,'Intended footprint','YAGEO RES 0805_2012');
 Param(24,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(24,'Value','1k');
 Param(24,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(24,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(24,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(25,1,'C6','XGLLVDFI','SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,'100nF',81700000,16700000,81100000,12800000);
 MapPin(25,'1','1',82500000,14500000);
 MapPin(25,'2','2',82500000,15500000);
 PositionPart(25,2,81700000,16700000,81100000,12800000);
 Param(25,'Part Number','GRM21BR71H104KA01L');
 Param(25,'Valor','100nF');
 Param(25,'Manufacturer','Murata');
 Param(25,'Manufacturer Part Number','GRM21BR71H104KA01L');
 Param(25,'Intended footprint','MURATA GRM21B 0805_2012');
 Param(25,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(25,'Value','100nF');
 Param(25,'Symbol source','Celestial / SCH - PASSIVES - CAPACITOR.SCHLIB / Capacitor');
 Param(25,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(25,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
 LoadPart(26,1,'D7','FNORYNQR','SCH - DIODES - DIODE.SCHLIB','Diode',0,'1N4148W',43200000,13800000,42600000,9900000);
 MapPin(26,'2','2',44500000,12100000);
 MapPin(26,'1','1',43500000,12100000);
 PositionPart(26,2,43200000,13800000,42600000,9900000);
 Param(26,'Value','1N4148W');
 Param(26,'Part Number','1N4148W');
 Param(26,'Manufacturer','Nexperia');
 Param(26,'Manufacturer Part Number','1N4148W');
 Param(26,'Intended footprint','1N4148W_SOD123_A1_K2');
 Param(26,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(26,'Symbol source','Celestial / SCH - DIODES - DIODE.SCHLIB / Diode');
 Param(26,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(26,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
 LoadPart(27,2,'R14','OQVYWKML','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100R',17200000,62800000,17100000,60700000);
 MapPin(27,'2','2',19500000,61000000);
 MapPin(27,'1','1',16500000,61000000);
 PositionPart(27,2,17200000,62800000,17100000,60700000);
 Param(27,'Part number','RC0805FR-07100RL');
 Param(27,'Valor','100R');
 Param(27,'Manufacturer','Yageo');
 Param(27,'Manufacturer Part Number','RC0805FR-07100RL');
 Param(27,'Intended footprint','YAGEO RES 0805_2012');
 Param(27,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(27,'Value','100R');
 Param(27,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(27,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(27,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(28,2,'Q2','PEGEUYGC','SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,'AO3400A',34500000,64000000,34500000,57800000);
 MapPin(28,'G','1',32500000,61000000);
 MapPin(28,'S','2',39500000,59200000);
 MapPin(28,'D','3',39500000,62800000);
 PositionPart(28,3,34500000,64000000,34500000,57800000);
 Param(28,'Manufacturer','Alpha and Omega Semiconductor');
 Param(28,'Manufacturer Part Number','AO3400A');
 Param(28,'Package','Package_TO_SOT_SMD:SOT-23');
 Param(28,'Populate','Yes');
 Param(28,'Intended footprint','AO3400A_G1_S2_D3');
 Param(28,'Datasheet','https://www.aosmd.com/sites/default/files/res/datasheets/AO3400A.pdf');
 Param(28,'3D asset','lib/upstream-kicad/SOT-23.step; downloaded, native link pending');
 Param(28,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(28,'Part Number','AO3400A');
 Param(28,'Value','AO3400A');
 Param(28,'Symbol source','Celestial / SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB / MOSFET SINGLE GDS');
 Param(28,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(28,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
 LoadPart(29,2,'R17','PBZZMIFW','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100k',17200000,57300000,17100000,55200000);
 MapPin(29,'2','2',19500000,55500000);
 MapPin(29,'1','1',16500000,55500000);
 PositionPart(29,2,17200000,57300000,17100000,55200000);
 Param(29,'Part number','RC0805FR-07100KL');
 Param(29,'Valor','100k');
 Param(29,'Manufacturer','Yageo');
 Param(29,'Manufacturer Part Number','RC0805FR-07100KL');
 Param(29,'Intended footprint','YAGEO RES 0805_2012');
 Param(29,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(29,'Value','100k');
 Param(29,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(29,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(29,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(30,2,'R15','UTXGSSRF','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100R',17200000,50800000,17100000,48700000);
 MapPin(30,'2','2',19500000,49000000);
 MapPin(30,'1','1',16500000,49000000);
 PositionPart(30,2,17200000,50800000,17100000,48700000);
 Param(30,'Part number','RC0805FR-07100RL');
 Param(30,'Valor','100R');
 Param(30,'Manufacturer','Yageo');
 Param(30,'Manufacturer Part Number','RC0805FR-07100RL');
 Param(30,'Intended footprint','YAGEO RES 0805_2012');
 Param(30,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(30,'Value','100R');
 Param(30,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(30,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(30,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(31,2,'Q3','TXMYVVAT','SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,'AO3400A',34500000,52000000,34500000,45800000);
 MapPin(31,'G','1',32500000,49000000);
 MapPin(31,'S','2',39500000,47200000);
 MapPin(31,'D','3',39500000,50800000);
 PositionPart(31,3,34500000,52000000,34500000,45800000);
 Param(31,'Manufacturer','Alpha and Omega Semiconductor');
 Param(31,'Manufacturer Part Number','AO3400A');
 Param(31,'Package','Package_TO_SOT_SMD:SOT-23');
 Param(31,'Populate','Yes');
 Param(31,'Intended footprint','AO3400A_G1_S2_D3');
 Param(31,'Datasheet','https://www.aosmd.com/sites/default/files/res/datasheets/AO3400A.pdf');
 Param(31,'3D asset','lib/upstream-kicad/SOT-23.step; downloaded, native link pending');
 Param(31,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(31,'Part Number','AO3400A');
 Param(31,'Value','AO3400A');
 Param(31,'Symbol source','Celestial / SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB / MOSFET SINGLE GDS');
 Param(31,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(31,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
 LoadPart(32,2,'R21','YAXZPWOH','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100k',17200000,45300000,17100000,43200000);
 MapPin(32,'2','2',19500000,43500000);
 MapPin(32,'1','1',16500000,43500000);
 PositionPart(32,2,17200000,45300000,17100000,43200000);
 Param(32,'Part number','RC0805FR-07100KL');
 Param(32,'Valor','100k');
 Param(32,'Manufacturer','Yageo');
 Param(32,'Manufacturer Part Number','RC0805FR-07100KL');
 Param(32,'Intended footprint','YAGEO RES 0805_2012');
 Param(32,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(32,'Value','100k');
 Param(32,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(32,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(32,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(33,2,'R16','WRQLYKKF','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100R',17200000,38800000,17100000,36700000);
 MapPin(33,'2','2',19500000,37000000);
 MapPin(33,'1','1',16500000,37000000);
 PositionPart(33,2,17200000,38800000,17100000,36700000);
 Param(33,'Part number','RC0805FR-07100RL');
 Param(33,'Valor','100R');
 Param(33,'Manufacturer','Yageo');
 Param(33,'Manufacturer Part Number','RC0805FR-07100RL');
 Param(33,'Intended footprint','YAGEO RES 0805_2012');
 Param(33,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(33,'Value','100R');
 Param(33,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(33,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(33,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(34,2,'Q4','VNHVEVGF','SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,'AO3400A',34500000,40000000,34500000,33800000);
 MapPin(34,'G','1',32500000,37000000);
 MapPin(34,'S','2',39500000,35200000);
 MapPin(34,'D','3',39500000,38800000);
 PositionPart(34,3,34500000,40000000,34500000,33800000);
 Param(34,'Manufacturer','Alpha and Omega Semiconductor');
 Param(34,'Manufacturer Part Number','AO3400A');
 Param(34,'Package','Package_TO_SOT_SMD:SOT-23');
 Param(34,'Populate','Yes');
 Param(34,'Intended footprint','AO3400A_G1_S2_D3');
 Param(34,'Datasheet','https://www.aosmd.com/sites/default/files/res/datasheets/AO3400A.pdf');
 Param(34,'3D asset','lib/upstream-kicad/SOT-23.step; downloaded, native link pending');
 Param(34,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(34,'Part Number','AO3400A');
 Param(34,'Value','AO3400A');
 Param(34,'Symbol source','Celestial / SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB / MOSFET SINGLE GDS');
 Param(34,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(34,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
 LoadPart(35,2,'R23','KQJUNJLK','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'100k',17200000,33300000,17100000,31200000);
 MapPin(35,'2','2',19500000,31500000);
 MapPin(35,'1','1',16500000,31500000);
 PositionPart(35,2,17200000,33300000,17100000,31200000);
 Param(35,'Part number','RC0805FR-07100KL');
 Param(35,'Valor','100k');
 Param(35,'Manufacturer','Yageo');
 Param(35,'Manufacturer Part Number','RC0805FR-07100KL');
 Param(35,'Intended footprint','YAGEO RES 0805_2012');
 Param(35,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(35,'Value','100k');
 Param(35,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(35,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(35,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
 LoadPart(36,2,'F2','QRGCIIKY','SCH - FUSE - MOUNTED FUSE.Schlib','MOUNTED FUSE',0,'0.5A FAST',74500000,68000000,74500000,61800000);
 MapPin(36,'1','1',73500000,65000000);
 MapPin(36,'2','2',78500000,65000000);
 PositionPart(36,2,74500000,68000000,74500000,61800000);
 Param(36,'Manufacturer','Littelfuse');
 Param(36,'Manufacturer Part Number','0451.500MRL');
 Param(36,'Package','FUSE_2410');
 Param(36,'Populate','Yes');
 Param(36,'Intended footprint','LITTELFUSE_0451_2410');
 Param(36,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(36,'Part Number','0451.500MRL');
 Param(36,'Value','0451.500MRL');
 Param(36,'Symbol source','Celestial / SCH - FUSE - MOUNTED FUSE.Schlib / MOUNTED FUSE');
 Param(36,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(36,'LITTELFUSE_0451_2410','lib\PinRepairFootprints.PcbLib');
 LoadPart(37,2,'SW1','AFBNKUYX','SCH - SWITCH - SPST 2PIN.SCHLIB','SPST 2PIN',0,'ALIGN / TEST',19500000,30000000,19500000,23800000);
 MapPin(37,'1','1',17300000,27000000);
 MapPin(37,'2','2',24700000,27000000);
 PositionPart(37,2,19500000,30000000,19500000,23800000);
 Param(37,'Manufacturer','Omron');
 Param(37,'Manufacturer Part Number','B3FS-1000P');
 Param(37,'Package','SW_SMD_6X6');
 Param(37,'Populate','Yes');
 Param(37,'Intended footprint','OMRON_B3FS1000P_LOGICAL_1_2');
 Param(37,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
 Param(37,'Part Number','B3FS-1000P');
 Param(37,'Value','B3FS-1000P');
 Param(37,'Symbol source','Celestial / SCH - SWITCH - SPST 2PIN.SCHLIB / SPST 2PIN');
 Param(37,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(37,'OMRON_B3FS1000P_LOGICAL_1_2','lib\PinRepairFootprints.PcbLib');
 LoadPart(38,2,'R22','YVOOIDRC','SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,'10k',37200000,28800000,37100000,26700000);
 MapPin(38,'2','2',39500000,27000000);
 MapPin(38,'1','1',36500000,27000000);
 PositionPart(38,2,37200000,28800000,37100000,26700000);
 Param(38,'Part number','RC0805FR-0710KL');
 Param(38,'Valor','10k');
 Param(38,'Manufacturer','Yageo');
 Param(38,'Manufacturer Part Number','RC0805FR-0710KL');
 Param(38,'Intended footprint','YAGEO RES 0805_2012');
 Param(38,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
 Param(38,'Value','10k');
 Param(38,'Symbol source','Celestial / SCH - PASSIVES - RESISTOR.SCHLIB / Resistor');
 Param(38,'CAD status','Complete native symbol loaded; repair COPY requires visual and compiled connectivity validation');
 Footprint(38,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
End;

Procedure RestoreNativeParts;
Begin
 Log:=TStringList.Create; RunDir:=''; Failure:=''; Phase:='START'; NP:=0; Restored:=0; Replaced:=0; WireCount:=0; ManualCount:=0;
 CollectingVerification:=False; VerifyIssues:=0; VerifyPassed:=0; VerifyFailed:=0;
 Try
  Try
   RunDir:=BASE+'History\native-parts-'+FormatDateTime('yyyymmdd-hhnnss',Now)+'\';
   If Not DirectoryExists(RunDir) Then Begin
    If Not CreateDir(RunDir) Then Begin RunDir:=''; ShowMessage('Cannot create repair directory'); Exit; End;
   End Else Begin RunDir:=''; ShowMessage('Run folder already exists; retry in a few seconds'); Exit; End;
   Note('START|Revision 7: resolve only detected ID collisions with the native ID generator and explicit setter; verify all 39 components. Existing wires unchanged. Repair copies only; originals and PCB never saved. F1/PTC excluded.');
   BuildAll;
   If Failure='' Then ApplyCopies;
   If Failure='' Then ShowMessage('39 complete native components placed in COPY sheets.'+#13+
    'Existing wires unchanged: check/reconnect the replacements manually.'+#13+
    'New IDs: reconcile PCB component links before any PCB update.'+#13+
    'Original sheets and PCB are unchanged.'+#13+'Inspect copies and send report.txt before promotion:'+#13+RunDir)
   Else ShowMessage('Repair stopped: '+Failure+#13+'Original sheets and PCB unchanged.'+#13+'Report: '+RunDir+'report.txt');
  Except
   { No re-raise: leave the Altium debugger instead of trapping the user at Abort. }
   Note('RUNTIME_ERROR|'+Phase+'|No repaired result is claimed. Original files untouched.');
   ShowMessage('Altium rejected an operation at '+Phase+'. Original files are unchanged.'+#13+'Send report.txt from '+RunDir);
  End;
 Finally Log.Free; End;
End;

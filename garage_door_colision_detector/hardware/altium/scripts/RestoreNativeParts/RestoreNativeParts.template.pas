{ Complete native library components, not artwork grafts.
  Repairs NEW COPIES only. Source SchDocs, PCB and source libraries are never saved.
  Run RestoreNativeParts. No Abort, Raise, Replicate or source-library editing.
  Generated pin contracts come from the last saved project. ERC is still required.
}
Const BASE='@@BASE@@'; PARTS=39;
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
@@BUILD@@
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

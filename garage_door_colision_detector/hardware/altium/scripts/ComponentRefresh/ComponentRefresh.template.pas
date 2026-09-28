{ Native-only schematic library refresh. Generated against saved document identities.
  Existing electrical pins, net wiring, component UID and footprint mappings stay intact.
  Celestial artwork is imported by replication, not reconstructed from guessed rectangles.
  IEC resistor artwork is a documented project-authored exception requested by the user.
  All replacements are staged as detached component clones BEFORE any live sheet edit.
  This script has not been run/compiled in Altium by the author. Save All first.
}
Const BASE='@@BASE@@';
Var
 Docs : Array[0..5] Of IServerDocument;
 Sheets : Array[0..5] Of ISch_Document;
 FileNames : Array[0..5] Of String;
 Originals, Prepared, Artwork : Array[0..59] Of ISch_Component;
 SheetIndex : Array[0..59] Of Integer;
 BeforePins : Array[0..59] Of String;
 Log : TStringList;
 RunDir, LibraryFile, LastFailureText : String;
 ApplyStarted : Boolean;
 ImportedArtworkPartCount,SkippedArtworkPartCount : Integer;

Procedure Need(OK, MessageText);
Begin
 If Not OK Then Begin
  LastFailureText:=MessageText;
  Log.Add('STOP|'+MessageText);
  If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt');
  Raise('Component refresh validation stopped: '+MessageText);
 End;
End;

Function PinsSignature(C) : String;
Var I : ISch_Iterator; P : ISch_Pin; T : TStringList;
Begin
 T:=TStringList.Create; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   T.Add(P.UniqueId+'|'+P.Designator+'|'+P.Name+'|'+IntToStr(P.OwnerPartId)+'|'+IntToStr(P.OwnerPartDisplayMode)+'|'+
    IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y)+'|'+IntToStr(P.PinLength)+'|'+IntToStr(Ord(P.Orientation))+'|'+IntToStr(Ord(P.Electrical)));
   P:=I.NextSchObject;
  End;
  T.Sort; Result:=T.Text;
 Finally C.SchIterator_Destroy(I); T.Free; End;
End;

Function FindPin(C,N,Mode) : ISch_Pin;
Var I : ISch_Iterator; P : ISch_Pin; Count : Integer;
Begin
 Result:=Nil; Count:=0; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin
   If (P.Designator=N) And (P.OwnerPartDisplayMode=Mode) And (P.OwnerPartId=1) Then Begin Result:=P; Count:=Count+1; End;
   P:=I.NextSchObject;
  End;
 Finally C.SchIterator_Destroy(I); End;
 Need(Count=1,'Missing/ambiguous pin '+C.Designator.Text+'.'+N+' mode '+IntToStr(Mode));
End;

Procedure SetParam(C,N,V);
Var I : ISch_Iterator; P : ISch_Parameter;
Begin
 I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eParameter));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin If UpperCase(P.Name)=UpperCase(N) Then Break; P:=I.NextSchObject; End;
 Finally C.SchIterator_Destroy(I); End;
 If P=Nil Then Begin P:=SchServer.SchObjectFactory(eParameter,eCreate_GlobalCopy); P.Name:=N; P.IsHidden:=True; C.AddSchObject(P); End;
 P.Text:=V;
End;

Function ParamText(C,N) : String;
Var I : ISch_Iterator; P : ISch_Parameter;
Begin
 Result:=''; I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eParameter));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin If UpperCase(P.Name)=UpperCase(N) Then Begin Result:=P.Text; Break; End; P:=I.NextSchObject; End;
 Finally C.SchIterator_Destroy(I); End;
End;

Procedure RemoveExampleParameters(C);
Var I : ISch_Iterator; P,NextP : ISch_Parameter; Names : TStringList;
Begin
 Names:=TStringList.Create;
 Names.CommaText:='LatestRevisionDate,LatestRevisionNote,PackageDocument,PackageReference,Code_JEDEC,cod.,Grupo,Encapsulamento,Obs';
 I:=C.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eParameter));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin NextP:=I.NextSchObject; If Names.IndexOf(P.Name)>=0 Then C.RemoveSchObject(P); P:=NextP; End;
 Finally C.SchIterator_Destroy(I); Names.Free; End;
End;

Procedure OpenSheet(N,FileName,ExpectedCount);
Var I : ISch_Iterator; C : ISch_Component; Count : Integer;
Begin
 FileNames[N]:=FileName;
 Docs[N]:=Client.OpenDocument('SCH',BASE+'sch\'+FileName);
 Need(Docs[N]<>Nil,'Cannot open '+FileName); Client.ShowDocument(Docs[N]); Docs[N].Focus;
 Need(Not Docs[N].Modified,'Save All first: '+FileName);
 Sheets[N]:=SchServer.GetCurrentSchDocument; Need(Sheets[N]<>Nil,'No native sheet database: '+FileName);
 I:=Sheets[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); Count:=0;
 Try C:=I.FirstSchObject; While C<>Nil Do Begin Count:=Count+1; C:=I.NextSchObject; End;
 Finally Sheets[N].SchIterator_Destroy(I); End;
 Need(Count=ExpectedCount,'Component count changed in '+FileName+'; regenerate manifest rather than overwrite new work.');
End;

Procedure StagePart(N,S,Ref,UID,OldReference,NewReference,MPN,Manufacturer,Kind);
Var I : ISch_Iterator; C : ISch_Component; Count : Integer;
Begin
 I:=Sheets[S].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); Count:=0;
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin If C.Designator.Text=Ref Then Begin Originals[N]:=C; Count:=Count+1; End; C:=I.NextSchObject; End;
 Finally Sheets[S].SchIterator_Destroy(I); End;
 Need(Count=1,'Missing/duplicate component '+Ref); C:=Originals[N];
 Need((C.UniqueId=UID) And (C.LibReference=OldReference),'Component identity changed: '+Ref);
 Need((ParamText(C,'Manufacturer Part Number')=MPN) And (ParamText(C,'Manufacturer')=Manufacturer),'Purchasing part changed: '+Ref);
 Need(Ord(C.ComponentKind)=Kind,'Assembly scope changed: '+Ref);
 BeforePins[N]:=PinsSignature(C); Prepared[N]:=C.Replicate; SheetIndex[N]:=S;
 Prepared[N].LibReference:=NewReference;
 SetParam(Prepared[N],'Manufacturer',Manufacturer); SetParam(Prepared[N],'Manufacturer Part Number',MPN);
 SetParam(Prepared[N],'Part Number',MPN);
 SetParam(Prepared[N],'Value',MPN);
 RemoveExampleParameters(Prepared[N]);
 SetParam(Prepared[N],'Component refresh','2026-09-10 sourced-symbol pass; not manufacturing release');
 Artwork[N]:=Nil;
End;

Procedure ExpectPin(N,NumberText,Mode,Part,X,Y,Orientation,Length,Electrical);
Var P : ISch_Pin;
Begin
 Need(Part=1,'Only single-part variants are supported in this pass.');
 P:=FindPin(Prepared[N],NumberText,Mode);
 Need((P.Location.X=X) And (P.Location.Y=Y) And (P.PinLength=Length) And
  (Ord(P.Orientation)=Orientation) And (Ord(P.Electrical)=Electrical),'Saved/native pin mismatch: '+Prepared[N].Designator.Text+'.'+NumberText);
End;

Procedure ExpectPinCount(N,Expected);
Var I : ISch_Iterator; P : ISch_Pin; Count : Integer;
Begin
 I:=Prepared[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin)); Count:=0;
 Try P:=I.FirstSchObject; While P<>Nil Do Begin Count:=Count+1; P:=I.NextSchObject; End;
 Finally Prepared[N].SchIterator_Destroy(I); End;
 Need(Count=Expected,'Unexpected pin count '+Prepared[N].Designator.Text);
End;

Procedure CheckFootprint(N,Pattern,RelativeFile);
Var I : ISch_Iterator; M,NewM : ISch_Implementation; P : ISch_Pin;
 L : IPCB_LibComponent; GI : IPCB_GroupIterator; O : IPCB_Primitive; Pad : IPCB_Pad;
 PadNames : TStringList; Count,Bodies : Integer; Map,Ref : String;
Begin
 Ref:=Prepared[N].Designator.Text;
 Need(FileExists(BASE+RelativeFile),'Missing footprint library '+RelativeFile);
 L:=PCBServer.LoadCompFromLibrary(Pattern,BASE+RelativeFile); Need(L<>Nil,'Cannot load footprint '+Ref+': '+Pattern);
 PadNames:=TStringList.Create; Bodies:=0; GI:=L.GroupIterator_Create; GI.SetState_FilterAll;
 Try
  O:=GI.FirstPCBObject;
  While O<>Nil Do Begin
   If O.ObjectId=ePadObject Then Begin Pad:=O; PadNames.Add(Pad.Name); End;
   If O.ObjectId=eComponentBodyObject Then Bodies:=Bodies+1;
   O:=GI.NextPCBObject;
  End;
 Finally L.GroupIterator_Destroy(GI); End;
 I:=Prepared[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eImplementation)); Count:=0;
 Try
  M:=I.FirstSchObject;
  While M<>Nil Do Begin Count:=Count+1; Need(M.ModelName=Pattern,'Footprint selection changed: '+Ref); Map:=M.MapAsString; M:=I.NextSchObject; End;
 Finally Prepared[N].SchIterator_Destroy(I); End;
 Need(Count=1,'Expected one footprint for '+Ref);
 { Current project footprints were repaired to use the actual schematic pin IDs.
   Do not accept a differently numbered footprint just because its body looks correct. }
 I:=Prepared[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(ePin));
 Try
  P:=I.FirstSchObject;
  While P<>Nil Do Begin Need(PadNames.IndexOf(P.Designator)>=0,'No matching PCB pad '+Ref+'.'+P.Designator); P:=I.NextSchObject; End;
 Finally Prepared[N].SchIterator_Destroy(I); PadNames.Free; End;
 I:=Prepared[N].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eImplementation));
 M:=I.FirstSchObject; Prepared[N].SchIterator_Destroy(I); Prepared[N].RemoveSchObject(M);
 NewM:=Prepared[N].AddSchImplementation; NewM.ModelType:='PCBLIB'; NewM.ModelName:=Pattern; NewM.IsCurrent:=True;
 NewM.AddDataFileLink(Pattern,BASE+RelativeFile,'PCBLIB'); NewM.MapAsString:=Map;
 Need(NewM.MapAsString=Map,'Pin-to-pad map changed: '+Ref);
 SetParam(Prepared[N],'Intended footprint',Pattern);
 Log.Add('FOOTPRINT|'+Ref+'|'+Pattern+'|3D_BODY_COUNT='+IntToStr(Bodies)+'|Appearance and dimensions NOT verified');
 If Bodies=0 Then Log.Add('MISSING_3D|'+Ref+'|No substitute block generated');
End;

Function IsArtwork(O) : Boolean;
Begin
 Result:=(O.ObjectId=eLine) Or (O.ObjectId=ePolyline) Or (O.ObjectId=ePolygon) Or
  (O.ObjectId=eRectangle) Or (O.ObjectId=eRoundRectangle) Or (O.ObjectId=eArc) Or
  (O.ObjectId=eEllipticalArc) Or (O.ObjectId=eEllipse) Or (O.ObjectId=eLabel);
End;

Procedure ClearArtwork(C);
Var I : ISch_Iterator; O,NextO : ISch_GraphicalObject;
Begin
 I:=C.SchIterator_Create; I.SetState_FilterAll;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin NextO:=I.NextSchObject; If IsArtwork(O) Then C.RemoveSchObject(O); O:=NextO; End;
 Finally C.SchIterator_Destroy(I); End;
End;

Procedure ImportArtwork(N,FileName,SourceReference,Rotation,X,Y);
Var SD : IServerDocument; L : ISch_Lib; I,J : ISch_Iterator; C : ISch_Component;
 O,Clone : ISch_GraphicalObject; Count,Mode,SourceArtworkCount,ImportedCount : Integer;
 SourcePath,DisposablePath : String; A,B : TFileStream;
Begin
 { Work only from a disposable run-local copy. Altium may mark an opened legacy
   SchLib as modified during loading/conversion; the reviewed master must never be
   saved or have its dirty state changed by this refresh. }
 SourcePath:=BASE+'lib\reviewed-sources\'+FileName;
 DisposablePath:=RunDir+'SOURCE - '+FileName;
 Need(FileExists(SourcePath),'Missing reviewed Celestial source '+FileName);
 If Not FileExists(DisposablePath) Then Begin
  A:=TFileStream.Create(SourcePath,fmOpenRead Or fmShareDenyWrite);
  Try
   B:=TFileStream.Create(DisposablePath,fmCreate);
   Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Disposable source copy size mismatch: '+FileName);
   Finally B.Free; End;
  Finally A.Free; End;
  Log.Add('SOURCE_COPY|'+FileName+'|master preserved; disposable run copy created');
 End;
 SD:=Client.OpenDocument('SCHLIB',DisposablePath);
 Need(SD<>Nil,'Cannot open disposable Celestial source '+FileName); Client.ShowDocument(SD); SD.Focus;
 L:=SchServer.GetCurrentSchDocument; Need(L<>Nil,'No library database '+FileName);
 I:=L.SchLibIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); Count:=0;
 Try
  C:=I.FirstSchObject;
  While C<>Nil Do Begin If C.LibReference=SourceReference Then Begin Artwork[N]:=C.Replicate; Count:=Count+1; End; C:=I.NextSchObject; End;
 Finally L.SchIterator_Destroy(I); End;
 Need(Count=1,'Source symbol missing/ambiguous: '+SourceReference);
 Artwork[N].Orientation:=Rotation; Artwork[N].MoveToXY(X,Y);
 SourceArtworkCount:=0;
 J:=Artwork[N].SchIterator_Create; J.SetState_FilterAll;
 Try
  O:=J.FirstSchObject;
  While O<>Nil Do Begin
   If IsArtwork(O) And ((O.OwnerPartId=0) Or (O.OwnerPartId=1)) Then SourceArtworkCount:=SourceArtworkCount+1;
   O:=J.NextSchObject;
  End;
 Finally Artwork[N].SchIterator_Destroy(J); End;
 If SourceArtworkCount=0 Then Begin
  SkippedArtworkPartCount:=SkippedArtworkPartCount+1;
  SetParam(Prepared[N],'Symbol source status','Skipped: legacy Celestial artwork is not iterable through Altium scripting');
  Log.Add('SKIPPED_ARTWORK|'+Prepared[N].Designator.Text+'|'+FileName+'|'+SourceReference+'|existing component body retained');
  Exit;
 End;
 ClearArtwork(Prepared[N]); ImportedCount:=0;
 For Mode:=0 To Prepared[N].DisplayModeCount-1 Do Begin
  J:=Artwork[N].SchIterator_Create; J.SetState_FilterAll;
  Try
   O:=J.FirstSchObject;
   While O<>Nil Do Begin
    { Legacy Celestial primitives often omit OwnerPartDisplayMode. Import every
      genuine body primitive from the single source representation. }
    If IsArtwork(O) And ((O.OwnerPartId=0) Or (O.OwnerPartId=1)) Then Begin
     Clone:=O.Replicate; Clone.OwnerPartId:=Prepared[N].CurrentPartId; Clone.OwnerPartDisplayMode:=Mode; Clone.Color:=15263976;
     If Clone.ObjectId=ePolygon Then Clone.AreaColor:=15263976;
     Prepared[N].AddSchObject(Clone); ImportedCount:=ImportedCount+1;
    End;
    O:=J.NextSchObject;
   End;
  Finally Artwork[N].SchIterator_Destroy(J); End;
 End;
 Need(ImportedCount>0,'No Celestial artwork was imported for '+Prepared[N].Designator.Text);
 ImportedArtworkPartCount:=ImportedArtworkPartCount+1;
 SetParam(Prepared[N],'Symbol source','Celestial / Mark Harris / '+FileName+' / '+SourceReference);
 Log.Add('IMPORTED_ARTWORK|'+Prepared[N].Designator.Text+'|'+FileName+'|'+SourceReference+'|PRIMITIVES='+IntToStr(ImportedCount));
End;

Procedure BodyLine(C,X1,Y1,X2,Y2,Mode);
Var L : ISch_Line;
Begin
 If (X1=X2) And (Y1=Y2) Then Exit;
 L:=SchServer.SchObjectFactory(eLine,eCreate_GlobalCopy);
 L.Location:=Point(X1,Y1); L.Corner:=Point(X2,Y2); L.Color:=15263976; L.LineWidth:=eSmall;
 L.OwnerPartId:=1; L.OwnerPartDisplayMode:=Mode; C.AddSchObject(L);
End;

Procedure BridgePin(N,SourcePin,TargetPin,X,Y);
Var T : ISch_Pin; Mode : Integer;
Begin
 { Celestial SchLib pins are rendered by the library editor but are not exposed as
   child objects by every replicated component. X/Y is the reviewed artwork terminal
   coordinate from the import manifest. Only non-electrical component lines are added;
   the original project electrical pin and PCB mapping remain authoritative. }
 For Mode:=0 To Prepared[N].DisplayModeCount-1 Do Begin
  T:=FindPin(Prepared[N],TargetPin,Mode);
  BodyLine(Prepared[N],X,Y,T.Location.X,Y,Mode);
  BodyLine(Prepared[N],T.Location.X,Y,T.Location.X,T.Location.Y,Mode);
 End;
 Log.Add('ARTWORK_BRIDGE|'+Prepared[N].Designator.Text+'.'+TargetPin+'|source='+SourcePin+
  '|terminal='+IntToStr(X)+','+IntToStr(Y));
End;

Procedure FinishPart(N,Note);
Var C : ISch_Component;
Begin
 C:=Prepared[N]; Need(PinsSignature(C)=BeforePins[N],'Electrical pin signature changed while staging '+C.Designator.Text);
 Need(C.UniqueId=Originals[N].UniqueId,'Component UID changed');
 Need(C.ComponentKind=Originals[N].ComponentKind,'PCB/BOM scope changed');
 SetParam(C,'Symbol adaptation',Note);
 SetParam(C,'CAD status','Reusable reviewed symbol; pin/pad check performed by refresh. Native ERC, PCB ECO and 3D mechanical inspection still required.');
 If Ord(C.ComponentKind)=2 Then SetParam(C,'CAD status','External equipment symbol: no controller-PCB pads; mechanical CAD remains unverified.');
 If (Copy(C.Designator.Text,1,1)='R') Or (Copy(C.Designator.Text,1,1)='C') Then Begin
  SetParam(C,'Value',C.Comment.Text); SetParam(C,'Valor',C.Comment.Text);
 End;
 Log.Add('STAGED|'+C.Designator.Text+'|'+C.LibReference+'|PIN_SIGNATURE_UNCHANGED');
End;

Procedure StageAll;
Begin
@@STAGE@@
End;

Procedure BackupAll;
Var S : Integer; A,B : TFileStream;
Begin
 For S:=0 To 5 Do Begin
  Need(Not Docs[S].Modified,'Sheet changed during preflight: '+FileNames[S]);
  A:=TFileStream.Create(BASE+'sch\'+FileNames[S],fmOpenRead Or fmShareDenyWrite);
  Try
   B:=TFileStream.Create(RunDir+FileNames[S],fmCreate);
   Try B.CopyFrom(A,0); Need(A.Size=B.Size,'Backup size mismatch'); Finally B.Free; End;
  Finally A.Free; End;
  Log.Add('BACKUP|'+FileNames[S]);
 End;
 Log.SaveToFile(RunDir+'report.txt');
End;

Procedure ExportLibrary;
Var SD : IServerDocument; L : ISch_Lib; C : ISch_Component; N : Integer;
Begin
 Need(Not FileExists(LibraryFile),'Refusing to overwrite a reviewed library.');
 SD:=Client.OpenNewDocument('SCHLIB','ReviewedComponents','ReviewedComponents',False);
 Need(SD<>Nil,'Could not create reviewed library.'); Client.ShowDocument(SD); SD.Focus;
 L:=SchServer.GetCurrentSchDocument; Need(L<>Nil,'No new library database.');
 For N:=0 To 59 Do Begin
  Prepared[N].SourceLibraryName:=LibraryFile;
  C:=Prepared[N].Replicate; C.MoveToXY(0,0); C.Designator.Text:=Copy(Prepared[N].Designator.Text,1,1)+'?';
  L.AddSchComponent(C); L.CurrentSchComponent:=C;
  SchServer.RobotManager.SendMessage(L.I_ObjectAddress,c_BroadCast,SCHM_PrimitiveRegistration,C.I_ObjectAddress);
 End;
 L.GraphicallyInvalidate; SD.DoSafeChangeFileNameAndSave(LibraryFile,'SCHLIB');
 Need(FileExists(LibraryFile),'Reviewed library not saved.');
 Log.Add('LIBRARY_SAVED|'+LibraryFile); Log.SaveToFile(RunDir+'report.txt');
End;

Procedure ApplyAll;
Var S,N,Count : Integer;
Begin
 For S:=0 To 5 Do Begin
  Count:=0; For N:=0 To 59 Do If SheetIndex[N]=S Then Count:=Count+1;
  If Count>0 Then Begin
   Client.ShowDocument(Docs[S]); Docs[S].Focus;
   Need(Not Docs[S].Modified,'Unsaved changes appeared during staging. Stop and restore if earlier sheets were applied.');
   Log.Add('APPLY_BEGIN|'+FileNames[S]); Log.SaveToFile(RunDir+'report.txt');
   SchServer.ProcessControl.PreProcess(Sheets[S],'Import reusable part-specific symbols');
   Try
    For N:=0 To 59 Do If SheetIndex[N]=S Then Begin
     Need(PinsSignature(Originals[N])=BeforePins[N],'Original changed during staging');
     Sheets[S].UnRegisterSchObjectFromContainer(Originals[N]);
     Sheets[S].RegisterSchObjectInContainer(Prepared[N]);
     Need(PinsSignature(Prepared[N])=BeforePins[N],'Post-registration pin signature mismatch');
    End;
   Finally SchServer.ProcessControl.PostProcess(Sheets[S],'Import reusable part-specific symbols'); End;
   Sheets[S].GraphicallyInvalidate; Docs[S].Modified:=True;
   Need(Docs[S].DoFileSave('SCHBinary5.0'),'Save failed: '+FileNames[S]);
   Log.Add('SAVED|'+FileNames[S]); Log.SaveToFile(RunDir+'report.txt');
  End;
 End;
End;

Procedure PrepareSingleMacroPage;
Var I : ISch_Iterator; S,RemoveS : ISch_SheetSymbol; L : ISch_Label;
    PowerCount,BeamCount,UiCount,OpticalCount,InstallCount,TitleCount,NoteCount : Integer;
Begin
 PowerCount:=0; BeamCount:=0; UiCount:=0; OpticalCount:=0; InstallCount:=0; RemoveS:=Nil;
 SchServer.ProcessControl.PreProcess(Sheets[0],'Consolidate and renumber hierarchy overview');
 Try
  I:=Sheets[0].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSheetSymbol));
  Try
   S:=I.FirstSchObject;
   While S<>Nil Do Begin
    If S.UniqueId='DWLXVDZR' Then Begin Need(S.SheetFileName.Text='01_Power_Control.SchDoc','Unexpected power sheet link'); S.SheetFileName.Text:='02_Power_Control.SchDoc'; PowerCount:=PowerCount+1; End
    Else If S.UniqueId='BYJVEJVA' Then Begin Need(S.SheetFileName.Text='02_Beam_Inputs.SchDoc','Unexpected beam sheet link'); S.SheetFileName.Text:='03_Beam_Inputs.SchDoc'; BeamCount:=BeamCount+1; End
    Else If S.UniqueId='MHDRAYCV' Then Begin Need(S.SheetFileName.Text='03_UI_Outputs.SchDoc','Unexpected UI sheet link'); S.SheetFileName.Text:='04_UI_Outputs.SchDoc'; UiCount:=UiCount+1; End
    Else If S.UniqueId='TOSWOHOG' Then Begin Need(S.SheetFileName.Text='04_Optical_Heads.SchDoc','Unexpected optical sheet link'); S.SheetFileName.Text:='05_Optical_Heads.SchDoc'; OpticalCount:=OpticalCount+1; End
    Else If S.UniqueId='QFFLIRWG' Then Begin Need(S.SheetFileName.Text='05_Installation.SchDoc','Unexpected duplicate installation link'); RemoveS:=S; InstallCount:=InstallCount+1; End;
    S:=I.NextSchObject;
   End;
  Finally Sheets[0].SchIterator_Destroy(I); End;
  Need((PowerCount=1) And (BeamCount=1) And (UiCount=1) And (OpticalCount=1) And (InstallCount=1),'Macro sheet identity/count changed');
  Sheets[0].RemoveSchObject(RemoveS);
  TitleCount:=0; NoteCount:=0; I:=Sheets[0].SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eLabel));
  Try
   L:=I.FirstSchObject;
   While L<>Nil Do Begin
    If L.Text='00  SYSTEM HIERARCHY / NAMED SIGNALS' Then Begin L.Text:='01  SYSTEM / MOUNTING OVERVIEW'; TitleCount:=TitleCount+1; End;
    If L.Text='Real sheet symbols link to child schematics. Matching tags join nets on this page. Physical mounting: sheet 05.' Then Begin L.Text:='Real sheet symbols link to the four active design sheets. Mounting and hierarchy are consolidated here.'; NoteCount:=NoteCount+1; End;
    L:=I.NextSchObject;
   End;
  Finally Sheets[0].SchIterator_Destroy(I); End;
  Need((TitleCount=1) And (NoteCount=1),'Macro page title/note changed unexpectedly');
 Finally SchServer.ProcessControl.PostProcess(Sheets[0],'Consolidate and renumber hierarchy overview'); End;
 Sheets[0].GraphicallyInvalidate; Docs[0].Modified:=True;
 Need(Docs[0].DoFileSave('SCHBinary5.0'),'Macro sheet save failed');
 Log.Add('MACRO_PREPARED|one hierarchy/mounting overview; child links prepared for pages 02-05; duplicate installation link removed');
 Log.SaveToFile(RunDir+'report.txt');
End;

Procedure RunComponentRefresh;
Var Stamp,FailureNotice : String;
Begin
 ShowMessage('ComponentRefresh is disabled: the 2026-09-12 imported-artwork pass removed visible symbol bodies. Restore the pre-run SchDoc backups before any further component work.');
 Exit;
 Log:=TStringList.Create; RunDir:=''; LastFailureText:=''; ApplyStarted:=False;
 Try
  Try
   Stamp:=FormatDateTime('yyyymmdd-hhnnss',Now);
   RunDir:=BASE+'History\component-refresh-'+Stamp+'\';
   Need(Not DirectoryExists(RunDir),'Run directory already exists.'); Need(CreateDir(RunDir),'Cannot create report directory.');
   LibraryFile:=BASE+'lib\reviewed\ReviewedComponents_'+Stamp+'.SchLib';
   Log.Add('START|No circuit redesign, no PCB geometry edits, no ERC suppression.');
   Log.SaveToFile(RunDir+'report.txt');
   StageAll; BackupAll; ExportLibrary;
   ApplyStarted:=True; ApplyAll; ApplyStarted:=False;
   Log.Add('COMPLETE|60 part-specific library variants; all original electrical pins retained.');
   Log.Add('UNCHANGED|Original wires, ports, component UIDs, external-equipment scope. PCB NOT edited.');
   Log.Add('NEXT|Validate the genuine library-symbol refresh, then perform the separate page consolidation pass.');
   Log.SaveToFile(RunDir+'report.txt');
   ShowMessage('Genuine component-library refresh saved.'+#13+'Report and backups: '+RunDir+#13+'Page consolidation remains a separate controlled operation.');
  Except
   { DelphiScript has no typed On handlers. LastFailureText is set only by Need;
     all unrelated runtime exceptions are immediately re-raised and remain visible. }
   If LastFailureText<>'' Then Begin
    FailureNotice:='No live schematic replacement had started.';
    If ApplyStarted Then FailureNotice:='APPLY had started. Inspect the report and restore the generated backups before continuing.';
    Log.Add('RETURNED_TO_ALTIUM|'+FailureNotice);
    If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt');
    ShowMessage('Component refresh stopped safely: '+LastFailureText+#13+FailureNotice+#13+'Altium has returned to idle; this is not a successful run.');
   End
   Else Raise;
  End;
 Finally Log.Free; End;
End;

Procedure RunComponentRefreshStageOnly;
Var Stamp,FailureNotice : String;
Begin
 Log:=TStringList.Create; RunDir:=''; LastFailureText:=''; ApplyStarted:=False;
 ImportedArtworkPartCount:=0; SkippedArtworkPartCount:=0;
 Try
  Try
   Stamp:=FormatDateTime('yyyymmdd-hhnnss',Now);
   RunDir:=BASE+'History\component-stage-only-'+Stamp+'\';
   Need(Not DirectoryExists(RunDir),'Run directory already exists.'); Need(CreateDir(RunDir),'Cannot create report directory.');
   LibraryFile:=BASE+'lib\reviewed\ReviewedComponents_STAGE_ONLY_'+Stamp+'.SchLib';
   Log.Add('START_STAGE_ONLY|Build reviewed library only. No SchDoc replacement, save, PCB edit or page edit.');
   Log.SaveToFile(RunDir+'report.txt');
   StageAll; ExportLibrary;
   Log.Add('STAGE_ONLY_COMPLETE|60 variants exported for visual inspection; live schematics unchanged|IMPORTED_ARTWORK_PARTS='+IntToStr(ImportedArtworkPartCount)+'|SKIPPED_ARTWORK_PARTS='+IntToStr(SkippedArtworkPartCount));
   Log.SaveToFile(RunDir+'report.txt');
   ShowMessage('Safe stage-only library created.'+#13+'No schematic was changed.'+#13+'Imported artwork parts: '+IntToStr(ImportedArtworkPartCount)+#13+'Skipped legacy artwork parts: '+IntToStr(SkippedArtworkPartCount)+#13+'Inspect: '+LibraryFile+#13+'Report: '+RunDir);
  Except
   If LastFailureText<>'' Then Begin
    FailureNotice:='No live schematic replacement or save was permitted by this procedure.';
    Log.Add('STAGE_ONLY_STOP|'+FailureNotice);
    If RunDir<>'' Then Log.SaveToFile(RunDir+'report.txt');
    ShowMessage('Stage-only validation stopped: '+LastFailureText+#13+FailureNotice);
   End
   Else Raise;
  End;
 Finally Log.Free; End;
End;

{ Native-only schematic library refresh. Generated against saved document identities.
  Existing electrical pins, net wiring, component UID and footprint mappings stay intact.
  Celestial artwork is imported by replication, not reconstructed from guessed rectangles.
  IEC resistor artwork is a documented project-authored exception requested by the user.
  All replacements are staged as detached component clones BEFORE any live sheet edit.
  This script has not been run/compiled in Altium by the author. Save All first.
}
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
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
  OpenSheet(0,'00_Mounting_Overview.SchDoc',0);
  OpenSheet(1,'01_Power_Control.SchDoc',9);
  OpenSheet(2,'02_Beam_Inputs.SchDoc',28);
  OpenSheet(3,'03_UI_Outputs.SchDoc',13);
  OpenSheet(4,'04_Optical_Heads.SchDoc',8);
  OpenSheet(5,'05_Installation.SchDoc',2);
  StagePart(0,1,'J1','MPFPEHHR','1729128__J1_view','1729128__J1_view','1729128','Phoenix Contact',0);
  ExpectPin(0,'1',0,1,14700000,62200000,0,1000000,7);
  ExpectPin(0,'2',0,1,14700000,59800000,0,1000000,7);
  ExpectPinCount(0,2);
  CheckFootprint(0,'PHOENIX_1729128_MKDSN_2_508','lib\PartSpecificFootprints.PcbLib');
  FinishPart(0,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(1,1,'F1','THVEUGSY','MF-MSMF110_24X-2__F1_view','MF-MSMF110_24X-2__F1_view','MF-MSMF110/24X-2','Bourns',0);
  ExpectPin(1,'1',0,1,22000000,62200000,2,1000000,4);
  ExpectPin(1,'2',0,1,27000000,62200000,0,1000000,4);
  ExpectPinCount(1,2);
  CheckFootprint(1,'BOURNS_MFMSMF110_24X_STYLE2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(1,'SCH - PASSIVES - THERMISTOR PTC.SCHLIB','Thermistor PTC',0,24500000,62200000);
  BridgePin(1,'2','2',25500000,62200000);
  BridgePin(1,'1','1',23500000,62200000);
  FinishPart(1,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(2,1,'D6','NAQKJIPP','SS34-E3_57T__D6_view','SS34-E3_57T__D6_view','SS34-E3/57T','Vishay',0);
  ExpectPin(2,'1',0,1,38500000,62200000,2,2000000,4);
  ExpectPin(2,'2',0,1,39500000,62200000,0,2000000,4);
  ExpectPinCount(2,2);
  CheckFootprint(2,'SS34_A1_K2','lib\PinRepairFootprints.PcbLib');
  FinishPart(2,'Retain existing diode symbol for SS34; dedicated Schottky glyph remains a follow-up (not silently replaced with TVS/rectifier artwork).');
  StagePart(3,1,'A2','JOPZBFXL','OKI-78SR-5_1_5-W36-C__A2_view','OKI-78SR-5_1_5-W36-C__A2_view','OKI-78SR-5/1.5-W36-C','Murata',0);
  ExpectPin(3,'1',0,1,52800000,62200000,2,1000000,4);
  ExpectPin(3,'2',0,1,52800000,59200000,2,1000000,4);
  ExpectPin(3,'3',0,1,61200000,60700000,0,1000000,4);
  ExpectPinCount(3,3);
  CheckFootprint(3,'MURATA_OKI78SR_VERTICAL','lib\PartSpecificFootprints.PcbLib');
  FinishPart(3,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(4,1,'D1','XLDUBJEV','SMBJ15A__D1_view','SMBJ15A__D1_view','SMBJ15A','Littelfuse',0);
  ExpectPin(4,'1',0,1,38800000,38400000,3,2000000,4);
  ExpectPin(4,'2',0,1,38800000,39400000,1,2000000,4);
  ExpectPinCount(4,2);
  CheckFootprint(4,'SMBJ15A_A1_K2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(4,'SCH - DIODES - DIODE TVS UNI.SCHLIB','DIODE TVS UNI',1,38800000,38900000);
  BridgePin(4,'2','2',38800000,39300000);
  BridgePin(4,'1','1',38800000,38500000);
  FinishPart(4,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(5,1,'C1','WWKCXFFV','EEU-FR1E471__C1_view','EEU-FR1E471__C1_view','EEU-FR1E471','Panasonic',0);
  ExpectPin(5,'1',1,1,36200000,38300000,3,1000000,4);
  ExpectPin(5,'2',1,1,36200000,39300000,1,1000000,4);
  ExpectPin(5,'1',0,1,36200000,38300000,3,1000000,4);
  ExpectPin(5,'2',0,1,36200000,39300000,1,1000000,4);
  ExpectPinCount(5,4);
  CheckFootprint(5,'PANASONIC_EEUFR1E471_D10_P5','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(5,'SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB','Polarised Capacitor',1,36200000,38800000);
  BridgePin(5,'2','2',36200000,39800000);
  BridgePin(5,'1','1',36200000,37800000);
  FinishPart(5,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(6,1,'C5','YZOVPMIX','EEU-FR1A471__C5_view','EEU-FR1A471__C5_view','EEU-FR1A471','Panasonic',0);
  ExpectPin(6,'1',1,1,27400000,39000000,3,1000000,4);
  ExpectPin(6,'2',1,1,27400000,40000000,1,1000000,4);
  ExpectPin(6,'1',0,1,27400000,39000000,3,1000000,4);
  ExpectPin(6,'2',0,1,27400000,40000000,1,1000000,4);
  ExpectPinCount(6,4);
  CheckFootprint(6,'PANASONIC_EEUFR1A471_D8_P3_5','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(6,'SCH - PASSIVES - POLARISED CAPACITOR.SCHLIB','Polarised Capacitor',1,27400000,39500000);
  BridgePin(6,'2','2',27400000,40500000);
  BridgePin(6,'1','1',27400000,38500000);
  FinishPart(6,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(7,1,'A1','NWTYJSIX','ESP32-DevKitC-32E__A1_view','ESP32-DevKitC-32E__A1_view','ESP32-DevKitC-32E','Espressif Systems',0);
  ExpectPin(7,'J2_1',0,1,86700000,44900000,2,2000000,7);
  ExpectPin(7,'J2_2',0,1,86700000,43900000,2,2000000,0);
  ExpectPin(7,'J2_3',0,1,86700000,42900000,2,2000000,1);
  ExpectPin(7,'J2_4',0,1,86700000,41900000,2,2000000,1);
  ExpectPin(7,'J2_5',0,1,86700000,40900000,2,2000000,0);
  ExpectPin(7,'J2_6',0,1,86700000,39900000,2,2000000,0);
  ExpectPin(7,'J2_7',0,1,86700000,38900000,2,2000000,1);
  ExpectPin(7,'J2_8',0,1,86700000,37900000,2,2000000,1);
  ExpectPin(7,'J2_9',0,1,86700000,36900000,2,2000000,1);
  ExpectPin(7,'J2_10',0,1,86700000,35900000,2,2000000,1);
  ExpectPin(7,'J2_11',0,1,86700000,34900000,2,2000000,1);
  ExpectPin(7,'J2_12',0,1,86700000,33900000,2,2000000,1);
  ExpectPin(7,'J2_13',0,1,86700000,32900000,2,2000000,1);
  ExpectPin(7,'J2_14',0,1,86700000,31900000,2,2000000,7);
  ExpectPin(7,'J2_15',0,1,86700000,30900000,2,2000000,1);
  ExpectPin(7,'J2_16',0,1,86700000,29900000,2,2000000,1);
  ExpectPin(7,'J2_17',0,1,86700000,28900000,2,2000000,1);
  ExpectPin(7,'J2_18',0,1,86700000,27900000,2,2000000,1);
  ExpectPin(7,'J2_19',0,1,86700000,26900000,2,2000000,7);
  ExpectPin(7,'J3_1',0,1,98700000,44900000,0,2000000,7);
  ExpectPin(7,'J3_2',0,1,98700000,43900000,0,2000000,1);
  ExpectPin(7,'J3_3',0,1,98700000,42900000,0,2000000,1);
  ExpectPin(7,'J3_4',0,1,98700000,41900000,0,2000000,1);
  ExpectPin(7,'J3_5',0,1,98700000,40900000,0,2000000,1);
  ExpectPin(7,'J3_6',0,1,98700000,39900000,0,2000000,1);
  ExpectPin(7,'J3_7',0,1,98700000,38900000,0,2000000,7);
  ExpectPin(7,'J3_8',0,1,98700000,37900000,0,2000000,1);
  ExpectPin(7,'J3_9',0,1,98700000,36900000,0,2000000,1);
  ExpectPin(7,'J3_10',0,1,98700000,35900000,0,2000000,1);
  ExpectPin(7,'J3_11',0,1,98700000,34900000,0,2000000,1);
  ExpectPin(7,'J3_12',0,1,98700000,33900000,0,2000000,1);
  ExpectPin(7,'J3_13',0,1,98700000,32900000,0,2000000,1);
  ExpectPin(7,'J3_14',0,1,98700000,31900000,0,2000000,1);
  ExpectPin(7,'J3_15',0,1,98700000,30900000,0,2000000,1);
  ExpectPin(7,'J3_16',0,1,98700000,29900000,0,2000000,1);
  ExpectPin(7,'J3_17',0,1,98700000,28900000,0,2000000,1);
  ExpectPin(7,'J3_18',0,1,98700000,27900000,0,2000000,1);
  ExpectPin(7,'J3_19',0,1,98700000,26900000,0,2000000,1);
  ExpectPinCount(7,38);
  CheckFootprint(7,'MODULE_ESP32-DEVKITC-32E','lib\ESP32-DEVKITC-32E\MODULE_ESP32-DEVKITC-32E.PcbLib');
  FinishPart(7,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(8,1,'JP1','KQVJTBYS','TSW-102-07-G-S__JP1_view','TSW-102-07-G-S__JP1_view','TSW-102-07-G-S','Samtec',0);
  ExpectPin(8,'1',0,1,90000000,55500000,2,1000000,4);
  ExpectPin(8,'2',0,1,96000000,55500000,0,1000000,4);
  ExpectPinCount(8,2);
  CheckFootprint(8,'SAMTEC_TSW102_07_SINGLE','lib\PinRepairFootprints.PcbLib');
  FinishPart(8,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(9,2,'J2','AIHJYVMR','1715734__J2_view','1715734__J2_view','1715734','Phoenix Contact',0);
  ExpectPin(9,'1',0,1,9800000,62500000,2,1000000,4);
  ExpectPin(9,'2',0,1,9800000,59500000,2,1000000,4);
  ExpectPin(9,'3',0,1,18200000,61000000,0,1000000,4);
  ExpectPinCount(9,3);
  CheckFootprint(9,'PHOENIX_1715734_MKDS_3_508','lib\OpticalHardware.PcbLib');
  FinishPart(9,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(10,2,'R5','OPKPKOII','RC0805FR-072K2L__R5_view','RC0805FR-072K2L__R5_view','RC0805FR-072K2L','Yageo',0);
  ExpectPin(10,'1',0,1,27500000,62500000,2,1000000,4);
  ExpectPin(10,'2',0,1,30500000,62500000,0,1000000,4);
  ExpectPinCount(10,2);
  CheckFootprint(10,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(10,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,29000000,62500000);
  BridgePin(10,'2','2',30000000,62500000);
  BridgePin(10,'1','1',28000000,62500000);
  FinishPart(10,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(11,2,'U2','YCLQQYOQ','LTV-817S-TA1__U2_view','LTV-817S-TA1__U2_view','LTV-817S-TA1','Lite-On',0);
  ExpectPin(11,'1',0,1,39600000,62500000,2,1000000,4);
  ExpectPin(11,'2',0,1,39600000,59500000,2,1000000,4);
  ExpectPin(11,'3',0,1,48400000,59500000,0,1000000,4);
  ExpectPin(11,'4',0,1,48400000,62500000,0,1000000,3);
  ExpectPinCount(11,4);
  CheckFootprint(11,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
  ImportArtwork(11,'SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,44500000,62000000);
  BridgePin(11,'2','2',42700000,60000000);
  BridgePin(11,'1','1',42700000,62000000);
  BridgePin(11,'3','3',45300000,60000000);
  BridgePin(11,'4','4',45300000,62000000);
  FinishPart(11,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(12,2,'R6','LQPQFUVB','RC0805FR-0710KL__R6_view','RC0805FR-0710KL__R6_view','RC0805FR-0710KL','Yageo',0);
  ExpectPin(12,'1',0,1,59500000,67500000,2,1000000,4);
  ExpectPin(12,'2',0,1,62500000,67500000,0,1000000,4);
  ExpectPinCount(12,2);
  CheckFootprint(12,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(12,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,61000000,67500000);
  BridgePin(12,'2','2',62000000,67500000);
  BridgePin(12,'1','1',60000000,67500000);
  FinishPart(12,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(13,2,'R7','WQAGWPVX','RC0805FR-071KL__R7_view','RC0805FR-071KL__R7_view','RC0805FR-071KL','Yageo',0);
  ExpectPin(13,'1',0,1,69500000,62500000,2,1000000,4);
  ExpectPin(13,'2',0,1,72500000,62500000,0,1000000,4);
  ExpectPinCount(13,2);
  CheckFootprint(13,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(13,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,71000000,62500000);
  BridgePin(13,'2','2',72000000,62500000);
  BridgePin(13,'1','1',70000000,62500000);
  FinishPart(13,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(14,2,'C2','IZQAVBIX','GRM21BR71H104KA01L__C2_view','GRM21BR71H104KA01L__C2_view','GRM21BR71H104KA01L','Murata',0);
  ExpectPin(14,'1',1,1,82500000,58000000,3,1000000,4);
  ExpectPin(14,'2',1,1,82500000,59000000,1,1000000,4);
  ExpectPin(14,'1',0,1,82500000,58000000,3,1000000,4);
  ExpectPin(14,'2',0,1,82500000,59000000,1,1000000,4);
  ExpectPinCount(14,4);
  CheckFootprint(14,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
  ImportArtwork(14,'SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,82500000,58500000);
  BridgePin(14,'1','1',82500000,57500000);
  BridgePin(14,'2','2',82500000,59500000);
  FinishPart(14,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(15,2,'D2','FPPXBLTW','1N4148W__D2_view','1N4148W__D2_view','1N4148W','Nexperia',0);
  ExpectPin(15,'1',0,1,43500000,55600000,2,2000000,4);
  ExpectPin(15,'2',0,1,44500000,55600000,0,2000000,4);
  ExpectPinCount(15,2);
  CheckFootprint(15,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(15,'SCH - DIODES - DIODE.SCHLIB','Diode',0,44000000,55600000);
  BridgePin(15,'2','2',44400000,55600000);
  BridgePin(15,'1','1',43600000,55600000);
  FinishPart(15,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(16,2,'J3','FUKGQDJA','1715734__J3_view','1715734__J3_view','1715734','Phoenix Contact',0);
  ExpectPin(16,'1',0,1,9800000,48000000,2,1000000,4);
  ExpectPin(16,'2',0,1,9800000,45000000,2,1000000,4);
  ExpectPin(16,'3',0,1,18200000,46500000,0,1000000,4);
  ExpectPinCount(16,3);
  CheckFootprint(16,'PHOENIX_1715734_MKDS_3_508','lib\OpticalHardware.PcbLib');
  FinishPart(16,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(17,2,'R8','YUWSQPCU','RC0805FR-072K2L__R8_view','RC0805FR-072K2L__R8_view','RC0805FR-072K2L','Yageo',0);
  ExpectPin(17,'1',0,1,27500000,48000000,2,1000000,4);
  ExpectPin(17,'2',0,1,30500000,48000000,0,1000000,4);
  ExpectPinCount(17,2);
  CheckFootprint(17,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(17,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,29000000,48000000);
  BridgePin(17,'2','2',30000000,48000000);
  BridgePin(17,'1','1',28000000,48000000);
  FinishPart(17,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(18,2,'U3','MYWOSINS','LTV-817S-TA1__U3_view','LTV-817S-TA1__U3_view','LTV-817S-TA1','Lite-On',0);
  ExpectPin(18,'1',0,1,39600000,48000000,2,1000000,4);
  ExpectPin(18,'2',0,1,39600000,45000000,2,1000000,4);
  ExpectPin(18,'3',0,1,48400000,45000000,0,1000000,4);
  ExpectPin(18,'4',0,1,48400000,48000000,0,1000000,3);
  ExpectPinCount(18,4);
  CheckFootprint(18,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
  ImportArtwork(18,'SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,44500000,47500000);
  BridgePin(18,'2','2',42700000,45500000);
  BridgePin(18,'1','1',42700000,47500000);
  BridgePin(18,'3','3',45300000,45500000);
  BridgePin(18,'4','4',45300000,47500000);
  FinishPart(18,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(19,2,'R9','LMBAJDRZ','RC0805FR-0710KL__R9_view','RC0805FR-0710KL__R9_view','RC0805FR-0710KL','Yageo',0);
  ExpectPin(19,'1',0,1,59500000,53000000,2,1000000,4);
  ExpectPin(19,'2',0,1,62500000,53000000,0,1000000,4);
  ExpectPinCount(19,2);
  CheckFootprint(19,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(19,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,61000000,53000000);
  BridgePin(19,'2','2',62000000,53000000);
  BridgePin(19,'1','1',60000000,53000000);
  FinishPart(19,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(20,2,'R10','KAYRFWGZ','RC0805FR-071KL__R10_view','RC0805FR-071KL__R10_view','RC0805FR-071KL','Yageo',0);
  ExpectPin(20,'1',0,1,69500000,48000000,2,1000000,4);
  ExpectPin(20,'2',0,1,72500000,48000000,0,1000000,4);
  ExpectPinCount(20,2);
  CheckFootprint(20,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(20,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,71000000,48000000);
  BridgePin(20,'2','2',72000000,48000000);
  BridgePin(20,'1','1',70000000,48000000);
  FinishPart(20,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(21,2,'C3','MZWSXMOZ','GRM21BR71H104KA01L__C3_view','GRM21BR71H104KA01L__C3_view','GRM21BR71H104KA01L','Murata',0);
  ExpectPin(21,'1',1,1,82500000,43500000,3,1000000,4);
  ExpectPin(21,'2',1,1,82500000,44500000,1,1000000,4);
  ExpectPin(21,'1',0,1,82500000,43500000,3,1000000,4);
  ExpectPin(21,'2',0,1,82500000,44500000,1,1000000,4);
  ExpectPinCount(21,4);
  CheckFootprint(21,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
  ImportArtwork(21,'SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,82500000,44000000);
  BridgePin(21,'1','1',82500000,43000000);
  BridgePin(21,'2','2',82500000,45000000);
  FinishPart(21,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(22,2,'D3','TPVEGXUT','1N4148W__D3_view','1N4148W__D3_view','1N4148W','Nexperia',0);
  ExpectPin(22,'1',0,1,43500000,41100000,2,2000000,4);
  ExpectPin(22,'2',0,1,44500000,41100000,0,2000000,4);
  ExpectPinCount(22,2);
  CheckFootprint(22,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(22,'SCH - DIODES - DIODE.SCHLIB','Diode',0,44000000,41100000);
  BridgePin(22,'2','2',44400000,41100000);
  BridgePin(22,'1','1',43600000,41100000);
  FinishPart(22,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(23,2,'J4','HEZTXDZJ','1715734__J4_view','1715734__J4_view','1715734','Phoenix Contact',0);
  ExpectPin(23,'1',0,1,9800000,33500000,2,1000000,4);
  ExpectPin(23,'2',0,1,9800000,30500000,2,1000000,4);
  ExpectPin(23,'3',0,1,18200000,32000000,0,1000000,4);
  ExpectPinCount(23,3);
  CheckFootprint(23,'PHOENIX_1715734_MKDS_3_508','lib\OpticalHardware.PcbLib');
  FinishPart(23,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(24,2,'R11','BNPMVCHO','RC0805FR-072K2L__R11_view','RC0805FR-072K2L__R11_view','RC0805FR-072K2L','Yageo',0);
  ExpectPin(24,'1',0,1,27500000,33500000,2,1000000,4);
  ExpectPin(24,'2',0,1,30500000,33500000,0,1000000,4);
  ExpectPinCount(24,2);
  CheckFootprint(24,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(24,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,29000000,33500000);
  BridgePin(24,'2','2',30000000,33500000);
  BridgePin(24,'1','1',28000000,33500000);
  FinishPart(24,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(25,2,'U4','FBTKFFOT','LTV-817S-TA1__U4_view','LTV-817S-TA1__U4_view','LTV-817S-TA1','Lite-On',0);
  ExpectPin(25,'1',0,1,39600000,33500000,2,1000000,4);
  ExpectPin(25,'2',0,1,39600000,30500000,2,1000000,4);
  ExpectPin(25,'3',0,1,48400000,30500000,0,1000000,4);
  ExpectPin(25,'4',0,1,48400000,33500000,0,1000000,3);
  ExpectPinCount(25,4);
  CheckFootprint(25,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
  ImportArtwork(25,'SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,44500000,33000000);
  BridgePin(25,'2','2',42700000,31000000);
  BridgePin(25,'1','1',42700000,33000000);
  BridgePin(25,'3','3',45300000,31000000);
  BridgePin(25,'4','4',45300000,33000000);
  FinishPart(25,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(26,2,'R12','IKVPXVWT','RC0805FR-0710KL__R12_view','RC0805FR-0710KL__R12_view','RC0805FR-0710KL','Yageo',0);
  ExpectPin(26,'1',0,1,59500000,38500000,2,1000000,4);
  ExpectPin(26,'2',0,1,62500000,38500000,0,1000000,4);
  ExpectPinCount(26,2);
  CheckFootprint(26,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(26,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,61000000,38500000);
  BridgePin(26,'2','2',62000000,38500000);
  BridgePin(26,'1','1',60000000,38500000);
  FinishPart(26,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(27,2,'R13','YWTZULMD','RC0805FR-071KL__R13_view','RC0805FR-071KL__R13_view','RC0805FR-071KL','Yageo',0);
  ExpectPin(27,'1',0,1,69500000,33500000,2,1000000,4);
  ExpectPin(27,'2',0,1,72500000,33500000,0,1000000,4);
  ExpectPinCount(27,2);
  CheckFootprint(27,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(27,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,71000000,33500000);
  BridgePin(27,'2','2',72000000,33500000);
  BridgePin(27,'1','1',70000000,33500000);
  FinishPart(27,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(28,2,'C4','MINBGXGG','GRM21BR71H104KA01L__C4_view','GRM21BR71H104KA01L__C4_view','GRM21BR71H104KA01L','Murata',0);
  ExpectPin(28,'1',1,1,82500000,29000000,3,1000000,4);
  ExpectPin(28,'2',1,1,82500000,30000000,1,1000000,4);
  ExpectPin(28,'1',0,1,82500000,29000000,3,1000000,4);
  ExpectPin(28,'2',0,1,82500000,30000000,1,1000000,4);
  ExpectPinCount(28,4);
  CheckFootprint(28,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
  ImportArtwork(28,'SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,82500000,29500000);
  BridgePin(28,'1','1',82500000,28500000);
  BridgePin(28,'2','2',82500000,30500000);
  FinishPart(28,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(29,2,'D4','BGZYRAXD','1N4148W__D4_view','1N4148W__D4_view','1N4148W','Nexperia',0);
  ExpectPin(29,'1',0,1,43500000,26600000,2,2000000,4);
  ExpectPin(29,'2',0,1,44500000,26600000,0,2000000,4);
  ExpectPinCount(29,2);
  CheckFootprint(29,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(29,'SCH - DIODES - DIODE.SCHLIB','Diode',0,44000000,26600000);
  BridgePin(29,'2','2',44400000,26600000);
  BridgePin(29,'1','1',43600000,26600000);
  FinishPart(29,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(30,2,'J6','ZDDUMDNO','1715734__J6_view','1715734__J6_view','1715734','Phoenix Contact',0);
  ExpectPin(30,'1',0,1,9800000,19000000,2,1000000,4);
  ExpectPin(30,'2',0,1,9800000,16000000,2,1000000,4);
  ExpectPin(30,'3',0,1,18200000,17500000,0,1000000,4);
  ExpectPinCount(30,3);
  CheckFootprint(30,'PHOENIX_1715734_MKDS_3_508','lib\OpticalHardware.PcbLib');
  FinishPart(30,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(31,2,'R18','QKHBVNDC','RC0805FR-072K2L__R18_view','RC0805FR-072K2L__R18_view','RC0805FR-072K2L','Yageo',0);
  ExpectPin(31,'1',0,1,27500000,19000000,2,1000000,4);
  ExpectPin(31,'2',0,1,30500000,19000000,0,1000000,4);
  ExpectPinCount(31,2);
  CheckFootprint(31,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(31,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,29000000,19000000);
  BridgePin(31,'2','2',30000000,19000000);
  BridgePin(31,'1','1',28000000,19000000);
  FinishPart(31,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(32,2,'U5','JQARKEUG','LTV-817S-TA1__U5_view','LTV-817S-TA1__U5_view','LTV-817S-TA1','Lite-On',0);
  ExpectPin(32,'1',0,1,39600000,19000000,2,1000000,4);
  ExpectPin(32,'2',0,1,39600000,16000000,2,1000000,4);
  ExpectPin(32,'3',0,1,48400000,16000000,0,1000000,4);
  ExpectPin(32,'4',0,1,48400000,19000000,0,1000000,3);
  ExpectPinCount(32,4);
  CheckFootprint(32,'LITEON LTV-817','lib\celestial\PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB');
  ImportArtwork(32,'SCH - OPTOISOLATORS - OPTOISOLATOR.SCHLIB','Optoisolator',0,44500000,18500000);
  BridgePin(32,'2','2',42700000,16500000);
  BridgePin(32,'1','1',42700000,18500000);
  BridgePin(32,'3','3',45300000,16500000);
  BridgePin(32,'4','4',45300000,18500000);
  FinishPart(32,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(33,2,'R19','FZANGHTO','RC0805FR-0710KL__R19_view','RC0805FR-0710KL__R19_view','RC0805FR-0710KL','Yageo',0);
  ExpectPin(33,'1',0,1,59500000,24000000,2,1000000,4);
  ExpectPin(33,'2',0,1,62500000,24000000,0,1000000,4);
  ExpectPinCount(33,2);
  CheckFootprint(33,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(33,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,61000000,24000000);
  BridgePin(33,'2','2',62000000,24000000);
  BridgePin(33,'1','1',60000000,24000000);
  FinishPart(33,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(34,2,'R20','LJLJBJVM','RC0805FR-071KL__R20_view','RC0805FR-071KL__R20_view','RC0805FR-071KL','Yageo',0);
  ExpectPin(34,'1',0,1,69500000,19000000,2,1000000,4);
  ExpectPin(34,'2',0,1,72500000,19000000,0,1000000,4);
  ExpectPinCount(34,2);
  CheckFootprint(34,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(34,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,71000000,19000000);
  BridgePin(34,'2','2',72000000,19000000);
  BridgePin(34,'1','1',70000000,19000000);
  FinishPart(34,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(35,2,'C6','XGLLVDFI','GRM21BR71H104KA01L__C6_view','GRM21BR71H104KA01L__C6_view','GRM21BR71H104KA01L','Murata',0);
  ExpectPin(35,'1',1,1,82500000,14500000,3,1000000,4);
  ExpectPin(35,'2',1,1,82500000,15500000,1,1000000,4);
  ExpectPin(35,'1',0,1,82500000,14500000,3,1000000,4);
  ExpectPin(35,'2',0,1,82500000,15500000,1,1000000,4);
  ExpectPinCount(35,4);
  CheckFootprint(35,'MURATA GRM21B 0805_2012','lib\celestial\PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB');
  ImportArtwork(35,'SCH - PASSIVES - CAPACITOR.SCHLIB','Capacitor',1,82500000,15000000);
  BridgePin(35,'1','1',82500000,14000000);
  BridgePin(35,'2','2',82500000,16000000);
  FinishPart(35,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(36,2,'D7','FNORYNQR','1N4148W__D7_view','1N4148W__D7_view','1N4148W','Nexperia',0);
  ExpectPin(36,'1',0,1,43500000,12100000,2,2000000,4);
  ExpectPin(36,'2',0,1,44500000,12100000,0,2000000,4);
  ExpectPinCount(36,2);
  CheckFootprint(36,'1N4148W_SOD123_A1_K2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(36,'SCH - DIODES - DIODE.SCHLIB','Diode',0,44000000,12100000);
  BridgePin(36,'2','2',44400000,12100000);
  BridgePin(36,'1','1',43600000,12100000);
  FinishPart(36,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(37,3,'R14','OQVYWKML','RC0805FR-07100RL__R14_view','RC0805FR-07100RL__R14_view','RC0805FR-07100RL','Yageo',0);
  ExpectPin(37,'1',0,1,16500000,61000000,2,1000000,4);
  ExpectPin(37,'2',0,1,19500000,61000000,0,1000000,4);
  ExpectPinCount(37,2);
  CheckFootprint(37,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(37,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,61000000);
  BridgePin(37,'2','2',19000000,61000000);
  BridgePin(37,'1','1',17000000,61000000);
  FinishPart(37,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(38,3,'Q2','PEGEUYGC','AO3400A__Q2_view','AO3400A__Q2_view','AO3400A','Alpha and Omega Semiconductor',0);
  ExpectPin(38,'1',0,1,32500000,61000000,2,1000000,0);
  ExpectPin(38,'3',0,1,39500000,62800000,0,1000000,4);
  ExpectPin(38,'2',0,1,39500000,59200000,0,1000000,4);
  ExpectPinCount(38,3);
  CheckFootprint(38,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(38,'SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,35700000,61000000);
  BridgePin(38,'G','1',35300000,60000000);
  BridgePin(38,'S','2',36700000,60000000);
  BridgePin(38,'D','3',36700000,62000000);
  FinishPart(38,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(39,3,'R17','PBZZMIFW','RC0805FR-07100KL__R17_view','RC0805FR-07100KL__R17_view','RC0805FR-07100KL','Yageo',0);
  ExpectPin(39,'1',0,1,16500000,55500000,2,1000000,4);
  ExpectPin(39,'2',0,1,19500000,55500000,0,1000000,4);
  ExpectPinCount(39,2);
  CheckFootprint(39,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(39,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,55500000);
  BridgePin(39,'2','2',19000000,55500000);
  BridgePin(39,'1','1',17000000,55500000);
  FinishPart(39,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(40,3,'R15','UTXGSSRF','RC0805FR-07100RL__R15_view','RC0805FR-07100RL__R15_view','RC0805FR-07100RL','Yageo',0);
  ExpectPin(40,'1',0,1,16500000,49000000,2,1000000,4);
  ExpectPin(40,'2',0,1,19500000,49000000,0,1000000,4);
  ExpectPinCount(40,2);
  CheckFootprint(40,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(40,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,49000000);
  BridgePin(40,'2','2',19000000,49000000);
  BridgePin(40,'1','1',17000000,49000000);
  FinishPart(40,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(41,3,'Q3','TXMYVVAT','AO3400A__Q3_view','AO3400A__Q3_view','AO3400A','Alpha and Omega Semiconductor',0);
  ExpectPin(41,'1',0,1,32500000,49000000,2,1000000,0);
  ExpectPin(41,'3',0,1,39500000,50800000,0,1000000,4);
  ExpectPin(41,'2',0,1,39500000,47200000,0,1000000,4);
  ExpectPinCount(41,3);
  CheckFootprint(41,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(41,'SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,35700000,49000000);
  BridgePin(41,'G','1',35300000,48000000);
  BridgePin(41,'S','2',36700000,48000000);
  BridgePin(41,'D','3',36700000,50000000);
  FinishPart(41,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(42,3,'R21','YAXZPWOH','RC0805FR-07100KL__R21_view','RC0805FR-07100KL__R21_view','RC0805FR-07100KL','Yageo',0);
  ExpectPin(42,'1',0,1,16500000,43500000,2,1000000,4);
  ExpectPin(42,'2',0,1,19500000,43500000,0,1000000,4);
  ExpectPinCount(42,2);
  CheckFootprint(42,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(42,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,43500000);
  BridgePin(42,'2','2',19000000,43500000);
  BridgePin(42,'1','1',17000000,43500000);
  FinishPart(42,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(43,3,'R16','WRQLYKKF','RC0805FR-07100RL__R16_view','RC0805FR-07100RL__R16_view','RC0805FR-07100RL','Yageo',0);
  ExpectPin(43,'1',0,1,16500000,37000000,2,1000000,4);
  ExpectPin(43,'2',0,1,19500000,37000000,0,1000000,4);
  ExpectPinCount(43,2);
  CheckFootprint(43,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(43,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,37000000);
  BridgePin(43,'2','2',19000000,37000000);
  BridgePin(43,'1','1',17000000,37000000);
  FinishPart(43,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(44,3,'Q4','VNHVEVGF','AO3400A__Q4_view','AO3400A__Q4_view','AO3400A','Alpha and Omega Semiconductor',0);
  ExpectPin(44,'1',0,1,32500000,37000000,2,1000000,0);
  ExpectPin(44,'3',0,1,39500000,38800000,0,1000000,4);
  ExpectPin(44,'2',0,1,39500000,35200000,0,1000000,4);
  ExpectPinCount(44,3);
  CheckFootprint(44,'AO3400A_G1_S2_D3','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(44,'SCH - FET - N-CH - MOSFET SINGLE GDS.SCHLIB','MOSFET SINGLE GDS',0,35700000,37000000);
  BridgePin(44,'G','1',35300000,36000000);
  BridgePin(44,'S','2',36700000,36000000);
  BridgePin(44,'D','3',36700000,38000000);
  FinishPart(44,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(45,3,'R23','KQJUNJLK','RC0805FR-07100KL__R23_view','RC0805FR-07100KL__R23_view','RC0805FR-07100KL','Yageo',0);
  ExpectPin(45,'1',0,1,16500000,31500000,2,1000000,4);
  ExpectPin(45,'2',0,1,19500000,31500000,0,1000000,4);
  ExpectPinCount(45,2);
  CheckFootprint(45,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(45,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,18000000,31500000);
  BridgePin(45,'2','2',19000000,31500000);
  BridgePin(45,'1','1',17000000,31500000);
  FinishPart(45,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(46,3,'J5','QFEDJOBB','1729144__J5_view','1729144__J5_view','1729144','Phoenix Contact',0);
  ExpectPin(46,'1',0,1,80800000,58400000,2,1000000,7);
  ExpectPin(46,'2',0,1,80800000,56800000,2,1000000,4);
  ExpectPin(46,'3',0,1,80800000,55200000,2,1000000,4);
  ExpectPin(46,'4',0,1,80800000,53600000,2,1000000,4);
  ExpectPinCount(46,4);
  CheckFootprint(46,'PHOENIX_1729144_MKDSN_4_508','lib\PartSpecificFootprints.PcbLib');
  FinishPart(46,'Keep existing part-specific symbol; package and procurement metadata retained.');
  StagePart(47,3,'F2','QRGCIIKY','0451_500MRL__F2_view','0451_500MRL__F2_view','0451.500MRL','Littelfuse',0);
  ExpectPin(47,'1',0,1,73500000,65000000,2,1000000,4);
  ExpectPin(47,'2',0,1,78500000,65000000,0,1000000,4);
  ExpectPinCount(47,2);
  CheckFootprint(47,'LITTELFUSE_0451_2410','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(47,'SCH - FUSE - MOUNTED FUSE.Schlib','MOUNTED FUSE',0,76000000,65000000);
  BridgePin(47,'1','1',75000000,65000000);
  BridgePin(47,'2','2',77000000,65000000);
  FinishPart(47,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(48,3,'SW1','AFBNKUYX','B3FS-1000P__SW1_view','B3FS-1000P__SW1_view','B3FS-1000P','Omron',0);
  ExpectPin(48,'1',0,1,17300000,27000000,2,1000000,4);
  ExpectPin(48,'2',0,1,24700000,27000000,0,1000000,4);
  ExpectPinCount(48,2);
  CheckFootprint(48,'OMRON_B3FS1000P_LOGICAL_1_2','lib\PinRepairFootprints.PcbLib');
  ImportArtwork(48,'SCH - SWITCH - SPST 2PIN.SCHLIB','SPST 2PIN',0,21000000,26000000);
  BridgePin(48,'1','1',20000000,27000000);
  BridgePin(48,'2','2',22000000,27000000);
  FinishPart(48,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(49,3,'R22','YVOOIDRC','RC0805FR-0710KL__R22_view','RC0805FR-0710KL__R22_view','RC0805FR-0710KL','Yageo',0);
  ExpectPin(49,'1',0,1,36500000,27000000,2,1000000,4);
  ExpectPin(49,'2',0,1,39500000,27000000,0,1000000,4);
  ExpectPinCount(49,2);
  CheckFootprint(49,'YAGEO RES 0805_2012','lib\celestial\PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB');
  ImportArtwork(49,'SCH - PASSIVES - RESISTOR.SCHLIB','Resistor',0,38000000,27000000);
  BridgePin(49,'2','2',39000000,27000000);
  BridgePin(49,'1','1',37000000,27000000);
  FinishPart(49,'Import genuine Celestial symbol artwork; retain exact purchasing identity, physical pin identities and footprint mapping.');
  StagePart(50,4,'TX1','TMFADSTK','E3Z-T61-L_2M__TX1_view','E3Z-T61-L_2M__TX1_view','E3Z-T61-L 2M','Omron',2);
  ExpectPin(50,'BN',0,1,14400000,63000000,2,1000000,4);
  ExpectPin(50,'BU',0,1,14400000,59000000,2,1000000,4);
  ExpectPinCount(50,2);
  FinishPart(50,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(51,4,'RX1','HQPUWZTI','E3Z-T61-D_2M__RX1_view','E3Z-T61-D_2M__RX1_view','E3Z-T61-D 2M','Omron',2);
  ExpectPin(51,'BN',0,1,55400000,63000000,2,1000000,4);
  ExpectPin(51,'BU',0,1,55400000,59000000,2,1000000,4);
  ExpectPin(51,'BK',0,1,66600000,59000000,0,1000000,4);
  ExpectPinCount(51,3);
  FinishPart(51,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(52,4,'TX2','SPJFOFQO','E3Z-T61-L_2M__TX2_view','E3Z-T61-L_2M__TX2_view','E3Z-T61-L 2M','Omron',2);
  ExpectPin(52,'BN',0,1,14400000,49500000,2,1000000,4);
  ExpectPin(52,'BU',0,1,14400000,45500000,2,1000000,4);
  ExpectPinCount(52,2);
  FinishPart(52,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(53,4,'RX2','NFYKOJFB','E3Z-T61-D_2M__RX2_view','E3Z-T61-D_2M__RX2_view','E3Z-T61-D 2M','Omron',2);
  ExpectPin(53,'BN',0,1,55400000,49500000,2,1000000,4);
  ExpectPin(53,'BU',0,1,55400000,45500000,2,1000000,4);
  ExpectPin(53,'BK',0,1,66600000,45500000,0,1000000,4);
  ExpectPinCount(53,3);
  FinishPart(53,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(54,4,'TX3','GHTWQLMA','E3Z-T61-L_2M__TX3_view','E3Z-T61-L_2M__TX3_view','E3Z-T61-L 2M','Omron',2);
  ExpectPin(54,'BN',0,1,14400000,36000000,2,1000000,4);
  ExpectPin(54,'BU',0,1,14400000,32000000,2,1000000,4);
  ExpectPinCount(54,2);
  FinishPart(54,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(55,4,'RX3','UUIMFHCZ','E3Z-T61-D_2M__RX3_view','E3Z-T61-D_2M__RX3_view','E3Z-T61-D 2M','Omron',2);
  ExpectPin(55,'BN',0,1,55400000,36000000,2,1000000,4);
  ExpectPin(55,'BU',0,1,55400000,32000000,2,1000000,4);
  ExpectPin(55,'BK',0,1,66600000,32000000,0,1000000,4);
  ExpectPinCount(55,3);
  FinishPart(55,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(56,4,'TX4','LLKULIGV','E3Z-T61-L_2M__TX4_view','E3Z-T61-L_2M__TX4_view','E3Z-T61-L 2M','Omron',2);
  ExpectPin(56,'BN',0,1,14400000,22500000,2,1000000,4);
  ExpectPin(56,'BU',0,1,14400000,18500000,2,1000000,4);
  ExpectPinCount(56,2);
  FinishPart(56,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(57,4,'RX4','DUHVKZMU','E3Z-T61-D_2M__RX4_view','E3Z-T61-D_2M__RX4_view','E3Z-T61-D 2M','Omron',2);
  ExpectPin(57,'BN',0,1,55400000,22500000,2,1000000,4);
  ExpectPin(57,'BU',0,1,55400000,18500000,2,1000000,4);
  ExpectPin(57,'BK',0,1,66600000,18500000,0,1000000,4);
  ExpectPinCount(57,3);
  FinishPart(57,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(58,5,'PS1','AMRGQZZX','GST25E12-P1J__PS1_view','GST25E12-P1J__PS1_view','GST25E12-P1J','MEAN WELL',2);
  ExpectPin(58,'P',0,1,20000000,16800000,0,1000000,4);
  ExpectPin(58,'N',0,1,20000000,14200000,0,1000000,4);
  ExpectPinCount(58,2);
  FinishPart(58,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
  StagePart(59,5,'PS2','PJLXRMAS','GST25E12-P1J__PS2_view','GST25E12-P1J__PS2_view','GST25E12-P1J','MEAN WELL',2);
  ExpectPin(59,'P',0,1,91600000,16800000,0,1000000,4);
  ExpectPin(59,'N',0,1,91600000,14200000,0,1000000,4);
  ExpectPinCount(59,2);
  FinishPart(59,'Keep existing part-specific symbol; package and procurement metadata retained. External equipment: deliberately no PCB footprint. Manufacturer mechanical CAD remains separate/unverified.');
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

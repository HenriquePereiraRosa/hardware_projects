{ Targeted library repair only. No sheet rebuild, no circuit wire/pin movement,
  no PCB edits, no removal of hierarchical sheet symbols. }

Procedure SymbolCircle(C,X,Y,R);
Var E : ISch_Ellipse;
Begin
 E:=SchServer.SchObjectFactory(eEllipse,eCreate_GlobalCopy);
 E.Location:=Point(MilsToCoord(X),MilsToCoord(Y));
 E.Radius:=MilsToCoord(R); E.SecondaryRadius:=MilsToCoord(R);
 E.Color:=C_TEXT; E.AreaColor:=C_BG; E.IsSolid:=False; E.LineWidth:=eSmall;
 E.OwnerPartId:=1; E.OwnerPartDisplayMode:=0; C.AddSchObject(E);
End;

Procedure SymbolText(C,X,Y,T);
Var P : ISch_Label;
Begin
 P:=SchServer.SchObjectFactory(eLabel,eCreate_GlobalCopy);
 P.Location:=Point(MilsToCoord(X),MilsToCoord(Y)); P.Text:=T; P.Color:=C_TEXT;
 P.FontID:=SchServer.FontManager.GetFontID(8,0,False,False,False,False,'Arial');
 P.OwnerPartId:=1; P.OwnerPartDisplayMode:=0; C.AddSchObject(P);
End;

Procedure RemoveSymbolGraphics(C,OnlyRectangles);
Var It : ISch_Iterator; O,Old : ISch_GraphicalObject;
Begin
 It:=C.SchIterator_Create; It.SetState_FilterAll; O:=It.FirstSchObject;
 While O<>Nil Do Begin
  Old:=O; O:=It.NextSchObject;
  If (Old.ObjectId=eRectangle) Or (Old.ObjectId=eRoundRectangle) Or
     ((Not OnlyRectangles) And ((Old.ObjectId=eLine) Or (Old.ObjectId=ePolyline) Or
       (Old.ObjectId=eEllipse) Or (Old.ObjectId=eArc) Or (Old.ObjectId=eLabel))) Then C.RemoveSchObject(Old);
 End;
 C.SchIterator_Destroy(It);
End;

Procedure PartFootprint(C,Name,LibFile,Map);
Var It : ISch_Iterator; O,Old : ISch_GraphicalObject; M : ISch_Implementation;
Begin
 It:=C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eImplementation)); O:=It.FirstSchObject;
 While O<>Nil Do Begin Old:=O; O:=It.NextSchObject; C.RemoveSchObject(Old); End;
 C.SchIterator_Destroy(It);
 M:=C.AddSchImplementation; M.ModelType:='PCBLIB'; M.ModelName:=Name; M.IsCurrent:=True;
 M.AddDataFileLink(Name,ROOT+'lib\'+LibFile,'PCBLIB'); M.MapAsString:=Map;
 AddCompParameter(C,'Intended footprint',Name);
End;

Procedure ContactSymbol(C);
Var It : ISch_Iterator; P : ISch_Pin; X,Y,CX,Sign : Integer;
Begin
 RemoveSymbolGraphics(C,False); CX:=CoordToMils(C.Location.X);
 It:=C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(ePin)); P:=It.FirstSchObject;
 While P<>Nil Do Begin
  X:=CoordToMils(P.Location.X); Y:=CoordToMils(P.Location.Y);
  Sign:=1; If X>CX Then Sign:=-1;
  { Pins remain exactly where the existing circuit expects them. }
  SymbolLine(C,X+Sign*100,Y,X+Sign*160,Y);
  SymbolCircle(C,X+Sign*215,Y,55);
  SymbolLine(C,X+Sign*215-35,Y-35,X+Sign*215+35,Y+35);
  P.ShowName:=False;
  P:=It.NextSchObject;
 End;
 C.SchIterator_Destroy(It);
End;

Procedure ThroughHolePad(C,N,X,Pitch,Drill,Size);
Var P : IPCB_Pad;
Begin
 P:=PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
 P.Name:=IntToStr(N); P.X:=MMsToCoord(X); P.Y:=0; P.Layer:=eMultiLayer;
 P.HoleSize:=MMsToCoord(Drill); P.Plated:=True;
 P.TopXSize:=MMsToCoord(Size); P.TopYSize:=MMsToCoord(Size);
 P.MidXSize:=MMsToCoord(Size); P.MidYSize:=MMsToCoord(Size);
 P.BotXSize:=MMsToCoord(Size); P.BotYSize:=MMsToCoord(Size);
 If N=1 Then Begin P.TopShape:=eRectangular; P.MidShape:=eRectangular; P.BotShape:=eRectangular; End
 Else Begin P.TopShape:=eRounded; P.MidShape:=eRounded; P.BotShape:=eRounded; End;
 C.AddPCBObject(P);
End;

Function CreatePartFootprints : Boolean;
Var SD : IServerDocument; L : IPCB_Library; C : IPCB_LibComponent;
 Body : IPCB_ComponentBody; Model : IPCB_Model; N,I,Count : Integer; W : Real;
Begin
 Result:=False;
 SD:=Client.OpenNewDocument('PCBLIB','PartSpecificFootprints','PartSpecificFootprints',False);
 Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
 PCBServer.PreProcess;
 Try
  C:=PCBServer.CreatePCBLibComp; C.Name:='MURATA_OKI78SR_VERTICAL';
  C.Description:='OKI-78SR vertical; KiCad pad layout and embedded KiCad STEP; verify registration before manufacture';
  For N:=1 To 3 Do ThroughHolePad(C,N,(N-1)*2.54,2.54,1,1.8);
  TerminalTrack(C,-2.79,2.92,7.88,2.92); TerminalTrack(C,7.88,2.92,7.88,1.14);
  TerminalTrack(C,7.88,1.14,6.48,1.14); TerminalTrack(C,6.48,1.14,6.48,-1.1);
  TerminalTrack(C,6.48,-1.1,-1.4,-1.1); TerminalTrack(C,-1.4,-1.1,-1.4,1.14);
  TerminalTrack(C,-1.4,1.14,-2.79,1.14); TerminalTrack(C,-2.79,1.14,-2.79,2.92);
  Body:=PCBServer.PCBObjectFactory(eComponentBodyObject,eNoDimension,eCreate_Default);
  Model:=Body.ModelFactory_FromFilename(ROOT+'lib\part-specific\oki78sr.step',False);
  If Model=Nil Then Begin ShowMessage('Cannot import OKI STEP; no schematics changed'); Exit; End;
  Model.Embed:=True; Body.Model:=Model; Body.SetState_FromModel; Body.Layer:=eMechanical1;
  C.AddPCBObject(Body); C.Height:=MMsToCoord(16.5); L.RegisterComponent(C); L.CurrentComponent:=C;
  { Exact MKDSN variants: use datasheet pin pitch and drill, not the taller MKDS STEP. }
  For I:=1 To 2 Do Begin
   C:=PCBServer.CreatePCBLibComp; Count:=2; C.Name:='PHOENIX_1729128_MKDSN_2_508';
   If I=2 Then Begin Count:=4; C.Name:='PHOENIX_1729144_MKDSN_4_508'; End;
   C.Description:='MKDSN 1.5; 5.08mm pitch, 1.3mm drill, authored pads; detailed body STEP not available';
   For N:=1 To Count Do ThroughHolePad(C,N,(N-1)*5.08,5.08,1.3,2.6);
   { No invented body offset/STEP; pin layout only until manufacturer CAD is available. }
   C.Height:=MMsToCoord(10); L.RegisterComponent(C); L.CurrentComponent:=C;
  End;
 Finally PCBServer.PostProcess; End;
 Result:=SD.DoSafeChangeFileNameAndSave(ROOT+'lib\PartSpecificFootprints.PcbLib','PCBLIB');
End;

Procedure RepairPartsOnSheet(Index);
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator;
 C : ISch_Component; R,F : String; X,Y : Integer; Changed : Boolean;
Begin
 F:=ChildFile(Index); SD:=OpenSch(ROOT+F); D:=SchServer.GetCurrentSchDocument;
 SchServer.ProcessControl.PreProcess(D,'Part-specific library symbols');
 Try
  It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
  While C<>Nil Do Begin
   R:=C.Designator.Text; X:=CoordToMils(C.Location.X); Y:=CoordToMils(C.Location.Y); Changed:=False;
   If (R='J1') Or (R='J2') Or (R='J3') Or (R='J4') Or (R='J5') Or (R='J6') Then Begin
    ContactSymbol(C); Changed:=True;
    If R='J1' Then Begin
     C.LibReference:='PHOENIX_1729128'; C.Comment.Text:='1729128 / 12V INPUT';
     PartFootprint(C,'PHOENIX_1729128_MKDSN_2_508','PartSpecificFootprints.PcbLib','(1:1),(2:2)');
    End;
    If R='J5' Then Begin
     C.LibReference:='PHOENIX_1729144'; C.Comment.Text:='1729144 / RGB OUTPUT';
     PartFootprint(C,'PHOENIX_1729144_MKDSN_4_508','PartSpecificFootprints.PcbLib','(1:1),(2:2),(3:3),(4:4)');
    End;
    AddCompParameter(C,'CAD status','Native screw-terminal symbol and explicit pad mapping; verify footprint/body before production');
   End;
   If R='A2' Then Begin
    RemoveSymbolGraphics(C,False); Changed:=True;
    { Functional non-isolated DC/DC symbol, not a blank three-pin rectangle. }
    SymbolCircle(C,X,Y,240); SymbolLine(C,X-165,Y-165,X+165,Y+165);
    SymbolText(C,X-155,Y+65,'DC'); SymbolText(C,X+45,Y-130,'DC');
    SymbolLine(C,X-320,Y+150,X-188,Y+150);
    SymbolLine(C,X-320,Y-150,X-188,Y-150);
    SymbolLine(C,X+240,Y,X+320,Y);
    C.LibReference:='MURATA_OKI_78SR_5_1P5'; C.Comment.Text:='OKI-78SR-5/1.5-W36-C';
    PartFootprint(C,'MURATA_OKI78SR_VERTICAL','PartSpecificFootprints.PcbLib','(1:1),(2:2),(3:3)');
    AddCompParameter(C,'Datasheet','https://www.murata.com/products/productdata/8807037992990/oki-78sr.pdf');
    AddCompParameter(C,'CAD status','Native module symbol; verified 1 VIN / 2 GND / 3 VOUT; embedded community STEP, registration pending');
   End;
   If (Copy(R,1,2)='TX') Or (Copy(R,1,2)='RX') Then Begin
    { Preserve optical functional glyph, exact cable pins and user placement; remove blank enclosure frame. }
    RemoveSymbolGraphics(C,True); Changed:=True;
    If Copy(R,1,2)='TX' Then C.LibReference:='OMRON_E3Z_T61_L_2M'
    Else C.LibReference:='OMRON_E3Z_T61_D_2M';
    AddCompParameter(C,'Symbol representation','Complete powered photoelectric head; optical glyph is functional, not a bare discrete diode');
    AddCompParameter(C,'CAD status','Native reusable part-specific symbol. External cabled assembly: no PCB pads. Manufacturer STEP blocked by HTTP 403.');
   End;
   If Changed Then Begin
    C.SourceLibraryName:=ROOT+'lib\PartSpecificComponents.SchLib';
    AddCompParameter(C,'Symbol provenance','Project-authored native Altium library; based on identified manufacturer part and pinout, not vendor-issued CAD');
   End;
   C:=It.NextSchObject;
  End;
  D.SchIterator_Destroy(It);
 Finally SchServer.ProcessControl.PostProcess(D,'Part-specific library symbols'); End;
 SaveSch(SD,ROOT+F,'Part-specific symbols saved'); HierarchyAudit(ROOT+F);
End;

Procedure ExportPartSpecificSymbols;
Var SD,SrcSD : IServerDocument; L : ISch_Lib; D : ISch_Document;
 It : ISch_Iterator; C,Clone : ISch_Component; Seen : TStringList; I : Integer;
Begin
 Seen:=TStringList.Create;
 SD:=Client.OpenNewDocument('SCHLIB','PartSpecificComponents','PartSpecificComponents',False);
 Client.ShowDocument(SD); SD.Focus; L:=SchServer.GetCurrentSchDocument;
 For I:=1 To 4 Do Begin
  SrcSD:=OpenSch(ROOT+ChildFile(I)); D:=SchServer.GetCurrentSchDocument;
  It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
  While C<>Nil Do Begin
   If (C.SourceLibraryName=ROOT+'lib\PartSpecificComponents.SchLib') And (Seen.IndexOf(C.LibReference)<0) Then Begin
    Clone:=C.Replicate; Clone.MoveToXY(0,0); Clone.Designator.Text:=Copy(C.Designator.Text,1,1)+'?';
    Client.ShowDocument(SD); SD.Focus; L.AddSchComponent(Clone); L.CurrentSchComponent:=Clone;
    SchServer.RobotManager.SendMessage(L.I_ObjectAddress,c_BroadCast,SCHM_PrimitiveRegistration,Clone.I_ObjectAddress);
    Seen.Add(C.LibReference);
   End;
   C:=It.NextSchObject;
  End;
  D.SchIterator_Destroy(It);
 End;
 Client.ShowDocument(SD); SD.Focus; L.GraphicallyInvalidate;
 SD.DoSafeChangeFileNameAndSave(ROOT+'lib\PartSpecificComponents.SchLib','SCHLIB');
 Seen.SaveToFile(ROOT+'PartSpecificComponents.contents.txt'); Seen.Free;
End;

Procedure ReplacePlaceholderSymbols;
Var I : Integer; W : IWorkspace; P : IProject; SD : IServerDocument;
Begin
 { Save fresh native audits before changes, including open user edits. }
 For I:=1 To 4 Do Begin
  HierarchyAudit(ROOT+ChildFile(I));
  SD:=OpenSch(ROOT+ChildFile(I));
  SD.DoSafeChangeFileNameAndSave(ROOT+'History\component-symbols-20260909\live-'+ChildFile(I),'SCHBinary5.0');
  SD.DoSafeChangeFileNameAndSave(ROOT+ChildFile(I),'SCHBinary5.0');
 End;
 If Not CreatePartFootprints Then Exit;
 For I:=1 To 4 Do RepairPartsOnSheet(I);
 ExportPartSpecificSymbols;
 W:=GetWorkspace;
 For I:=0 To W.DM_ProjectCount-1 Do Begin
  P:=W.DM_Projects(I);
  If UpperCase(P.DM_ProjectFullPath)=UpperCase(ROOT+'GarageBeamSafety.PrjPcb') Then Begin
   If P.DM_IndexOfSourceDocument(ROOT+'lib\PartSpecificComponents.SchLib')<0 Then P.DM_AddSourceDocument(ROOT+'lib\PartSpecificComponents.SchLib');
   If P.DM_IndexOfSourceDocument(ROOT+'lib\PartSpecificFootprints.PcbLib')<0 Then P.DM_AddSourceDocument(ROOT+'lib\PartSpecificFootprints.PcbLib');
  End;
 End;
 OpenSch(ROOT+'04_Optical_Heads.SchDoc');
 ShowMessage('Part-specific symbols and native libraries saved. Existing pins/wires and hierarchy preserved. PCB unchanged. Save project.');
End;

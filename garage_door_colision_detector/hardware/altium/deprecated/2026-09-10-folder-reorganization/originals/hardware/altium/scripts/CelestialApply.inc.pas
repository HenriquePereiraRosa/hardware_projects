
Procedure SetParam(C,N,V);
Var It : ISch_Iterator; P : ISch_Parameter;
Begin
 It:=C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eParameter)); P:=It.FirstSchObject;
 While P<>Nil Do Begin If P.Name=N Then Break; P:=It.NextSchObject; End;
 C.SchIterator_Destroy(It);
 If P=Nil Then Begin P:=SchServer.SchObjectFactory(eParameter,eCreate_GlobalCopy); P.Name:=N; P.IsHidden:=True; C.AddSchObject(P); End;
 P.Text:=V;
End;

Procedure PinSignature(D,T);
Var It,PI : ISch_Iterator; C : ISch_Component; P : ISch_Pin;
Begin
 It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
 While C<>Nil Do Begin
  PI:=C.SchIterator_Create; PI.AddFilter_ObjectSet(MkSet(ePin)); P:=PI.FirstSchObject;
  While P<>Nil Do Begin T.Add(C.Designator.Text+'|'+P.Designator+'|'+IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y)+'|'+IntToStr(P.Orientation)); P:=PI.NextSchObject; End;
  C.SchIterator_Destroy(PI); C:=It.NextSchObject;
 End; D.SchIterator_Destroy(It); T.Sort;
End;

Procedure UpdateSheet(F,Report);
Var SD : IServerDocument; D : ISch_Document; It,MI : ISch_Iterator;
 C : ISch_Component; M : ISch_Implementation; O,NextO : ISch_GraphicalObject;
 K : Integer; BeforePins,AfterPins : TStringList; Map : String;
Begin
 SD:=Client.OpenDocument('SCH',BASE+F); Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
 SD.DoSafeChangeFileNameAndSave(BASE+'History\celestial-20260909\live-'+F,'SCHBinary5.0');
 SD.DoSafeChangeFileNameAndSave(BASE+F,'SCHBinary5.0');
 BeforePins:=TStringList.Create; AfterPins:=TStringList.Create; PinSignature(D,BeforePins);
 SchServer.ProcessControl.PreProcess(D,'Celestial footprint and model links');
 Try
  It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
  While C<>Nil Do Begin
   K:=Kind(C.Designator.Text);
   If K>0 Then Begin
    MI:=C.SchIterator_Create; MI.AddFilter_ObjectSet(MkSet(eImplementation)); O:=MI.FirstSchObject;
    While O<>Nil Do Begin NextO:=MI.NextSchObject; C.RemoveSchObject(O); O:=NextO; End; C.SchIterator_Destroy(MI);
    M:=C.AddSchImplementation; M.ModelType:='PCBLIB'; M.ModelName:=Pattern(K); M.IsCurrent:=True;
    M.AddDataFileLink(Pattern(K),BASE+'lib\celestial\'+LibFile(K),'PCBLIB');
    Map:='(1:1),(2:2)'; If K=3 Then Map:='(1:1),(2:2),(3:3),(4:4)'; M.MapAsString:=Map;
    SetParam(C,'Intended footprint',Pattern(K));
    SetParam(C,'Footprint source','Celestial Altium Library / Mark Harris / https://altiumlibrary.com');
    SetParam(C,'CAD status','Native Celestial footprint with embedded STEP; existing electrical symbol and pin positions retained; fabrication checks pending');
    { Clear stale example-library value, retaining the actual selected part number. }
    SetParam(C,'Value',C.Comment.Text); SetParam(C,'Valor',C.Comment.Text);
    Report.Add('SCH_LINK|'+F+'|'+C.Designator.Text+'|'+Pattern(K));
   End; C:=It.NextSchObject;
  End; D.SchIterator_Destroy(It);
 Finally SchServer.ProcessControl.PostProcess(D,'Celestial footprint and model links'); End;
 PinSignature(D,AfterPins);
 If BeforePins.Text<>AfterPins.Text Then Begin ShowMessage('Pin signature changed unexpectedly; stop without saving.'); Abort; End;
 Report.Add('PIN_POSITIONS_UNCHANGED|'+F+'|'+IntToStr(BeforePins.Count));
 D.GraphicallyInvalidate; SD.Modified:=True; SD.DoFileSave('SCHBinary5.0');
 BeforePins.Free; AfterPins.Free;
End;

Function PadWithName(C,N) : IPCB_Pad;
Var GI : IPCB_GroupIterator; P : IPCB_Pad;
Begin
 Result:=Nil; GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject;
 While P<>Nil Do Begin If P.Name=N Then Begin Result:=P; Break; End; P:=GI.NextPCBObject; End;
 C.GroupIterator_Destroy(GI);
End;

Procedure BoardPinSignature(B,T);
Var It : IPCB_BoardIterator; GI : IPCB_GroupIterator; C : IPCB_Component; P : IPCB_Pad; NN : String;
Begin
 It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
 While C<>Nil Do Begin
  GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject;
  While P<>Nil Do Begin
   NN:='<no net>'; If P.Net<>Nil Then NN:=P.Net.Name;
   T.Add(C.SourceDesignator+'|'+P.Name+'|'+NN); P:=GI.NextPCBObject;
  End; C.GroupIterator_Destroy(GI); C:=It.NextPCBObject;
 End; B.BoardIterator_Destroy(It); T.Sort;
End;

Procedure UpdateExistingBoardPackages(Report);
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator;
 C : IPCB_Component; L : IPCB_LibComponent; GI : IPCB_GroupIterator;
 O,NextO : IPCB_Primitive; P,OldPad : IPCB_Pad;
 K,NB,N : Integer; BeforeNets,AfterNets : TStringList;
Begin
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
 If B=Nil Then Begin ShowMessage('PCB not available'); Abort; End;
 SD.DoSafeChangeFileNameAndSave(BASE+'History\celestial-20260909\live-GarageBeamSafety.PcbDoc','PCB Binary 6.0');
 SD.DoSafeChangeFileNameAndSave(BASE+'GarageBeamSafety.PcbDoc','PCB Binary 6.0');
 BeforeNets:=TStringList.Create; AfterNets:=TStringList.Create;
 BoardPinSignature(B,BeforeNets); BeforeNets.SaveToFile(BASE+'History\celestial-20260909\pcb-pins-before.txt');
 PCBServer.PreProcess;
 Try
  It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
  While C<>Nil Do Begin
   K:=Kind(C.SourceDesignator);
   If K>0 Then Begin
    If C.Rotation<>0 Then Begin Report.Add('SKIPPED_ROTATED|'+C.SourceDesignator); End
    Else Begin
     L:=PCBServer.LoadCompFromLibrary(Pattern(K),BASE+'lib\celestial\'+LibFile(K));
     If L=Nil Then Begin ShowMessage('Cannot load '+Pattern(K)); Abort; End;
     { Validate every incoming pad before replacing any old primitive. }
     GI:=L.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject; N:=0;
     While P<>Nil Do Begin
      OldPad:=PadWithName(C,P.Name);
      If OldPad=Nil Then Begin ShowMessage('Pin mismatch '+C.SourceDesignator+'.'+P.Name); Abort; End;
      P.Net:=OldPad.Net; N:=N+1;
      Report.Add('PAD_NET_RETAINED|'+C.SourceDesignator+'|'+P.Name);
      P:=GI.NextPCBObject;
     End; L.GroupIterator_Destroy(GI);
     { Keep existing component identity/position; replace only footprint primitives. }
     L.MoveByXY(C.X-L.X,C.Y-L.Y);
     { Never mutate a group while its iterator is alive. }
     Repeat
      GI:=C.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; C.GroupIterator_Destroy(GI);
      If O<>Nil Then C.RemovePCBObject(O);
     Until O=Nil;
     NB:=0;
     Repeat
      GI:=L.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; L.GroupIterator_Destroy(GI);
      If O<>Nil Then Begin
      If O.ObjectId=eComponentBodyObject Then NB:=NB+1;
       L.RemovePCBObject(O); C.AddPCBObject(O);
      End;
     Until O=Nil;
     C.Pattern:=Pattern(K); C.CommentOn:=False; C.NameOn:=True; C.Name.Text:=C.SourceDesignator;
     C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1);
     Report.Add('PCB_PACKAGE|'+C.SourceDesignator+'|'+Pattern(K)+'|PADS='+IntToStr(N)+'|BODIES='+IntToStr(NB));
    End;
   End; C:=It.NextPCBObject;
  End; B.BoardIterator_Destroy(It);
 Finally PCBServer.PostProcess; End;
 BoardPinSignature(B,AfterNets); AfterNets.SaveToFile(BASE+'CelestialPCBPinNets.txt');
 If BeforeNets.Text<>AfterNets.Text Then Begin ShowMessage('PCB pin/net signature mismatch. Do not save. Backup available.'); Abort; End;
 Report.Add('PCB_PIN_NET_SIGNATURE_UNCHANGED|'+IntToStr(AfterNets.Count));
 BeforeNets.Free; AfterNets.Free;
 B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
End;

Procedure ApplyCelestialPackages;
Var Report : TStringList;
Begin
 Report:=TStringList.Create;
 Try
  { Schematic links were already saved in the first pass. }
  UpdateExistingBoardPackages(Report);
  Report.Add('COMPLETE_TARGETED_PASS');
 Finally Report.SaveToFile(BASE+'CelestialUpdate.audit.txt'); Report.Free; End;
 ShowMessage('Celestial package pass saved. Schematics linked; existing matching PCB parts updated. Other packages and PCB synchronization still pending.');
End;

Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';

Procedure AuditSync;
Var SD : IServerDocument; B : IPCB_Board; BI : IPCB_BoardIterator;
 GI : IPCB_GroupIterator; C : IPCB_Component; O : IPCB_Primitive; P : IPCB_Pad;
 D : ISch_Document; SI,CI : ISch_Iterator; SC : ISch_Component; SP : ISch_Pin; M : ISch_Implementation;
 L : IPCB_Library; LI : IPCB_LibraryIterator; LC : IPCB_LibComponent;
 T,Files : TStringList; I,K : Integer; NN,ID : String;
Begin
 T:=TStringList.Create; Files:=TStringList.Create;
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
 BI:=B.BoardIterator_Create; BI.AddFilter_ObjectSet(MkSet(eComponentObject)); BI.AddFilter_LayerSet(AllLayers); BI.AddFilter_Method(eProcessAll);
 C:=BI.FirstPCBObject; K:=0;
 While C<>Nil Do Begin
  ID:=IntToStr(K); T.Add('COMP|'+ID+'|'+C.SourceDesignator+'|'+C.Name.Text+'|'+C.SourceUniqueId+'|'+C.Pattern+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y))+'|'+FloatToStr(C.Rotation));
  GI:=C.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
  While O<>Nil Do Begin
   If O.ObjectId=ePadObject Then Begin P:=O; NN:=''; If P.Net<>Nil Then NN:=P.Net.Name;
    T.Add('PAD|'+ID+'|'+P.Name+'|'+NN+'|'+FloatToStr(CoordToMMs(P.X))+'|'+FloatToStr(CoordToMMs(P.Y)));
   End;
   If O.ObjectId=eComponentBodyObject Then T.Add('BODY|'+ID);
   O:=GI.NextPCBObject;
  End; C.GroupIterator_Destroy(GI); K:=K+1; C:=BI.NextPCBObject;
 End; B.BoardIterator_Destroy(BI);
 T.SaveToFile(BASE+'FinishSync.inventory.txt');
 Files.CommaText:='01_Power_Control.SchDoc,02_Beam_Inputs.SchDoc,03_UI_Outputs.SchDoc,04_Optical_Heads.SchDoc,05_Installation.SchDoc';
 For I:=0 To Files.Count-1 Do Begin
  SD:=Client.OpenDocument('SCH',BASE+Files[I]); Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
  SI:=D.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSchComponent)); SC:=SI.FirstSchObject;
  While SC<>Nil Do Begin
   T.Add('SCH|'+Files[I]+'|'+SC.Designator.Text+'|'+SC.UniqueId+'|'+SC.Comment.Text+'|'+IntToStr(Ord(SC.ComponentKind))+'|'+SC.LibReference);
   CI:=SC.SchIterator_Create; CI.AddFilter_ObjectSet(MkSet(ePin)); SP:=CI.FirstSchObject;
   While SP<>Nil Do Begin T.Add('PIN|'+SC.Designator.Text+'|'+SP.Designator+'|'+SP.Name); SP:=CI.NextSchObject; End; SC.SchIterator_Destroy(CI);
   CI:=SC.SchIterator_Create; CI.AddFilter_ObjectSet(MkSet(eImplementation)); M:=CI.FirstSchObject;
   While M<>Nil Do Begin T.Add('MODEL|'+SC.Designator.Text+'|'+M.ModelName+'|'+M.MapAsString); M:=CI.NextSchObject; End; SC.SchIterator_Destroy(CI);
   SC:=SI.NextSchObject;
  End; D.SchIterator_Destroy(SI);
 End;
 T.SaveToFile(BASE+'FinishSync.inventory.txt');
 SD:=Client.OpenDocument('PCBLIB',BASE+'lib\PartSpecificFootprints.PcbLib'); Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
 LI:=L.LibraryIterator_Create; LI.AddFilter_ObjectSet(MkSet(eComponentObject)); LC:=LI.FirstPCBObject;
 While LC<>Nil Do Begin
  T.Add('LIB|'+LC.Name); GI:=LC.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
  While O<>Nil Do Begin
   If O.ObjectId=ePadObject Then Begin P:=O; T.Add('LIBPAD|'+LC.Name+'|'+P.Name); End;
   If O.ObjectId=eComponentBodyObject Then T.Add('LIBBODY|'+LC.Name);
   O:=GI.NextPCBObject;
  End; LC.GroupIterator_Destroy(GI); LC:=LI.NextPCBObject;
 End; L.LibraryIterator_Destroy(LI);
 T.SaveToFile(BASE+'FinishSync.inventory.txt'); T.Free; Files.Free; ShowMessage('Read-only inventory saved.');
End;

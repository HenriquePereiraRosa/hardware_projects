Function FindBoardComponent(B,R) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
 Result:=Nil; It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
 While C<>Nil Do Begin If C.SourceDesignator=R Then Begin Result:=C; Break; End; C:=It.NextPCBObject; End; B.BoardIterator_Destroy(It);
End;

Procedure RegisterCelestialComponents;
Var SD : IServerDocument; B : IPCB_Board; Old,C : IPCB_Component; L : IPCB_LibComponent;
 GI : IPCB_GroupIterator; O : IPCB_Primitive; P,OP : IPCB_Pad;
 Refs,T,BeforeNets,AfterNets : TStringList; I,K,N,NB : Integer; R : String;
Begin
 T:=TStringList.Create; BeforeNets:=TStringList.Create; AfterNets:=TStringList.Create; Refs:=TStringList.Create;
 Refs.CommaText:='R5,R6,R7,R8,R9,R10,R11,R12,R13,R14,R15,R16,R17,C2,C3,C4,U2,U3,U4';
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
 BoardPinSignature(B,BeforeNets); BeforeNets.SaveToFile(BASE+'CelestialRegistered.before.txt');
 PCBServer.PreProcess;
 Try
  For I:=0 To Refs.Count-1 Do Begin
   R:=Refs[I]; K:=Kind(R); Old:=FindBoardComponent(B,R); If Old=Nil Then Abort;
   If Old.Rotation<>0 Then Abort;
   L:=PCBServer.LoadCompFromLibrary(Pattern(K),BASE+'lib\celestial\'+LibFile(K)); If L=Nil Then Abort;
   C:=PCBServer.PCBObjectFactory(eComponentObject,eNoDimension,eCreate_Default);
   C.X:=Old.X; C.Y:=Old.Y; C.Pattern:=Pattern(K); C.SourceDesignator:=R;
   C.SourceUniqueId:=Old.SourceUniqueId; C.SourceHierarchicalPath:=Old.SourceHierarchicalPath;
   C.SourceComponentLibrary:=Old.SourceComponentLibrary; C.SourceLibReference:=Old.SourceLibReference;
   C.SourceFootprintLibrary:=BASE+'lib\celestial\'+LibFile(K);
   C.Name.Text:=R; C.NameOn:=True; C.CommentOn:=False;
   C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1);
   C.Name.XLocation:=Old.X-MMsToCoord(1); C.Name.YLocation:=Old.Y+MMsToCoord(3);
   L.MoveByXY(Old.X-L.X,Old.Y-L.Y); N:=0; NB:=0;
   Repeat
    GI:=L.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; L.GroupIterator_Destroy(GI);
    If O<>Nil Then Begin
     If O.ObjectId=ePadObject Then Begin
      P:=O; OP:=Old.GetState_PadByName(P.Name); If OP=Nil Then Abort; P.Net:=OP.Net; N:=N+1;
     End;
     If O.ObjectId=eComponentBodyObject Then NB:=NB+1;
     L.RemovePCBObject(O); C.AddPCBObject(O);
    End;
   Until O=Nil;
   { Board registration must happen after all footprint primitives are attached. }
   B.RemovePCBObject(Old); B.AddPCBObject(C);
   T.Add('REGISTERED|'+R+'|'+Pattern(K)+'|PADS='+IntToStr(N)+'|BODIES='+IntToStr(NB));
   T.SaveToFile(BASE+'CelestialRegistered.audit.txt');
  End;
 Finally PCBServer.PostProcess; End;
 BoardPinSignature(B,AfterNets); AfterNets.SaveToFile(BASE+'CelestialRegistered.after.txt');
 If BeforeNets.Text<>AfterNets.Text Then Begin ShowMessage('Pin/net signature mismatch - do not save'); Abort; End;
 T.Add('PCB_PIN_NET_SIGNATURE_UNCHANGED|'+IntToStr(AfterNets.Count));
 B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
 T.Add('SAVED'); T.SaveToFile(BASE+'CelestialRegistered.audit.txt');
 ShowMessage('19 native Celestial footprints registered and saved. PCB pin/net signature unchanged.');
End;

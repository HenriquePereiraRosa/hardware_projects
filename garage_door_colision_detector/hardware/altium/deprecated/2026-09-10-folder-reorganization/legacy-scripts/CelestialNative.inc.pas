Procedure RefreshNativePackages;
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator; C : IPCB_Component;
 GI : IPCB_GroupIterator; O : IPCB_Primitive; K,N,NB : Integer;
 T,BeforeNets,AfterNets : TStringList;
Begin
 T:=TStringList.Create; BeforeNets:=TStringList.Create; AfterNets:=TStringList.Create;
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus;
 B:=PCBServer.GetCurrentPCBBoard; If B=Nil Then Exit;
 BoardPinSignature(B,BeforeNets); BeforeNets.SaveToFile(BASE+'CelestialNative.before.txt');
 It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
 PCBServer.PreProcess;
 Try
  While C<>Nil Do Begin
   K:=Kind(C.SourceDesignator);
   If K>0 Then Begin
    C.Pattern:=Pattern(K); C.SourceFootprintLibrary:=BASE+'lib\celestial\'+LibFile(K);
    If Not C.LoadFromLibrary Then Begin T.Add('FAIL|'+C.SourceDesignator); T.SaveToFile(BASE+'CelestialNative.audit.txt'); Abort; End;
    N:=0; NB:=0; GI:=C.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
    While O<>Nil Do Begin
     If O.ObjectId=ePadObject Then N:=N+1;
     If O.ObjectId=eComponentBodyObject Then NB:=NB+1;
     O:=GI.NextPCBObject;
    End; C.GroupIterator_Destroy(GI);
    C.Name.Text:=C.SourceDesignator; C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1); C.CommentOn:=False;
    T.Add('PCB_PACKAGE|'+C.SourceDesignator+'|'+Pattern(K)+'|PADS='+IntToStr(N)+'|BODIES='+IntToStr(NB));
    T.SaveToFile(BASE+'CelestialNative.audit.txt');
   End; C:=It.NextPCBObject;
  End;
 Finally PCBServer.PostProcess; B.BoardIterator_Destroy(It); End;
 BoardPinSignature(B,AfterNets); AfterNets.SaveToFile(BASE+'CelestialNative.after.txt');
 If BeforeNets.Text<>AfterNets.Text Then Begin ShowMessage('Native refresh changed pin/net signature. Do not save.'); Abort; End;
 T.Add('PCB_PIN_NET_SIGNATURE_UNCHANGED|'+IntToStr(AfterNets.Count));
 B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
 T.Add('SAVED'); T.SaveToFile(BASE+'CelestialNative.audit.txt');
 T.Free; BeforeNets.Free; AfterNets.Free;
 ShowMessage('Native Celestial packages saved. All existing PCB pin/net assignments retained.');
End;

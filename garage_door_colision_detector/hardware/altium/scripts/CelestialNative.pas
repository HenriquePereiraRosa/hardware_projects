{ Targeted native-library update. No sheet recreation; no circuit redesign. }
Const
 BASE='C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';

Function LibFile(K) : String;
Begin
 If K=1 Then Result:='PCB - RESISTOR - CHIP - YAGEO RES 0805_2012.PCBLIB';
 If K=2 Then Result:='PCB - CAPACITOR - MLCC - MURATA GRM21B 0805_2012.PCBLIB';
 If K=3 Then Result:='PCB - OPTOISOLATOR - LITEON LTV-817.PCBLIB';
End;
Function Pattern(K) : String;
Begin
 If K=1 Then Result:='YAGEO RES 0805_2012';
 If K=2 Then Result:='MURATA GRM21B 0805_2012';
 If K=3 Then Result:='LITEON LTV-817';
End;
Function Kind(R) : Integer;
Begin
 Result:=0;
 If Copy(R,1,1)='R' Then Result:=1;
 If (R='C2') Or (R='C3') Or (R='C4') Or (R='C6') Then Result:=2;
 If (R='U2') Or (R='U3') Or (R='U4') Or (R='U5') Then Result:=3;
End;

Procedure InspectCelestial;
Var K,N,NB : Integer; L : IPCB_LibComponent; GI : IPCB_GroupIterator;
 O : IPCB_Primitive; P : IPCB_Pad; T : TStringList;
Begin
 T:=TStringList.Create;
 T.Add('START'); T.SaveToFile(BASE+'CelestialInspection.txt');
 For K:=1 To 3 Do Begin
  L:=PCBServer.LoadCompFromLibrary(Pattern(K),BASE+'lib\celestial\'+LibFile(K));
  If L=Nil Then Begin T.Add('FAIL loading '+Pattern(K)); Break; End;
  T.Add('LIB|'+Pattern(K)); N:=0; NB:=0;
  GI:=L.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
  While O<>Nil Do Begin
   If O.ObjectId=ePadObject Then Begin P:=O; N:=N+1;
    T.Add('PAD|'+P.Name+'|'+FloatToStr(CoordToMMs(P.X))+'|'+FloatToStr(CoordToMMs(P.Y))+'|'+FloatToStr(CoordToMMs(P.TopXSize))+'|'+FloatToStr(CoordToMMs(P.TopYSize)));
   End;
   If O.ObjectId=eComponentBodyObject Then NB:=NB+1;
   O:=GI.NextPCBObject;
  End;
  L.GroupIterator_Destroy(GI); T.Add('COUNTS|'+IntToStr(N)+'|'+IntToStr(NB));
 End;
 T.SaveToFile(BASE+'CelestialInspection.txt'); T.Free;
 ShowMessage('Celestial library inspection complete. No design changes.');
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

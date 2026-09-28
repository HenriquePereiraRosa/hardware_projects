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

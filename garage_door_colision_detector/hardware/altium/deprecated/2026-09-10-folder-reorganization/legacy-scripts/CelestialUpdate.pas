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

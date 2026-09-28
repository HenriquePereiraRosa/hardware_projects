{ Targeted additive repair. No schematic graphics, pins, wires, pages, or existing
  PCB components are deleted. Existing PCB placement and routing are untouched.
  Backup: History\pin-repair-20260910. Run only against the repository copy. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Const LIBPATH='lib\PinRepairFootprints.PcbLib';
Var Report,Refs,UIDs,Comments : TStringList;

Function Kind(R) : Integer;
Begin
 Result:=0;
 If R='C1' Then Result:=1; If R='C5' Then Result:=2;
 If R='D1' Then Result:=3; If R='D6' Then Result:=4;
 If (R='D2') Or (R='D3') Or (R='D4') Or (R='D7') Then Result:=5;
 If (R='Q2') Or (R='Q3') Or (R='Q4') Then Result:=6;
 If R='SW1' Then Result:=7; If R='F1' Then Result:=8;
 If R='F2' Then Result:=9; If R='JP1' Then Result:=10;
End;
Function Pattern(K) : String;
Begin
 Case K Of
 1:Result:='PANASONIC_EEUFR1E471_D10_P5'; 2:Result:='PANASONIC_EEUFR1A471_D8_P3_5';
 3:Result:='SMBJ15A_A1_K2'; 4:Result:='SS34_A1_K2'; 5:Result:='1N4148W_SOD123_A1_K2';
 6:Result:='AO3400A_G1_S2_D3'; 7:Result:='OMRON_B3FS1000P_LOGICAL_1_2';
 8:Result:='BOURNS_MFMSMF110_24X_STYLE2'; 9:Result:='LITTELFUSE_0451_2410'; 10:Result:='SAMTEC_TSW102_07_SINGLE';
 End;
End;
Function SourcePattern(K) : String;
Begin
 Case K Of
 1:Result:='CAP AL TH D10 L5 H12.5'; 2:Result:='CAP TH ALUM ELEC D8.00mm S3.50mm H11.50mm';
 3:Result:='DO214AA SMB'; 4:Result:='DO214AC SMA'; 5:Result:='SOD-123';
 6:Result:='NEXPERIA SOT-23-3'; 7:Result:='OMRON B3FS-1012P';
 End;
End;
Function SourceFile(K) : String;
Begin
 Case K Of
 1:Result:='PCB - CAPACITOR - ALUMINIUM - CAP AL TH D10 L5 H12.5.PCBLIB';
 2:Result:='PCB - CAPACITOR - ALUMINIUM - CAP TH ALUM ELEC D8.00mm S3.50mm H11.50mm.PCBLIB';
 3:Result:='PCB - DIODES - DO214AA SMB.PCBLIB'; 4:Result:='PCB - DIODES - DO214AC SMA.PCBLIB';
 5:Result:='PCB - DIODES - SOD-123.PCBLIB'; 6:Result:='PCB - LEADED - SOT-23 - NEXPERIA SOT-23-3.PCBLIB';
 7:Result:='PCB - SWITCH - OMRON B3FS-1012P.PcbLib';
 End;
End;
Procedure Track(C,X1,Y1,X2,Y2);
Var T : IPCB_Track;
Begin
 T:=PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
 T.X1:=MMsToCoord(X1); T.Y1:=MMsToCoord(Y1); T.X2:=MMsToCoord(X2); T.Y2:=MMsToCoord(Y2);
 T.Width:=MMsToCoord(0.15); T.Layer:=eTopOverlay; C.AddPCBObject(T);
End;
Procedure Pad(C,N,X,Y,W,H,Drill);
Var P : IPCB_Pad;
Begin
 P:=PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
 P.Name:=N; P.X:=MMsToCoord(X); P.Y:=MMsToCoord(Y); P.Layer:=eTopLayer;
 P.TopXSize:=MMsToCoord(W); P.TopYSize:=MMsToCoord(H); P.TopShape:=eRectangular;
 P.HoleSize:=MMsToCoord(Drill);
 If Drill>0 Then Begin
  P.Layer:=eMultiLayer; P.Plated:=True;
  P.MidXSize:=P.TopXSize; P.MidYSize:=P.TopYSize; P.BotXSize:=P.TopXSize; P.BotYSize:=P.TopYSize;
  P.MidShape:=eRectangular; P.BotShape:=eRectangular;
 End;
 C.AddPCBObject(P);
End;
Procedure MakeLibrary;
Var SD : IServerDocument; L : IPCB_Library; C,S : IPCB_LibComponent;
 GI : IPCB_GroupIterator; O : IPCB_Primitive; P : IPCB_Pad; K,N : Integer; OldName : String;
Begin
 If FileExists(BASE+LIBPATH) Then Begin ShowMessage('Repair library already exists. Refusing to overwrite.'); Abort; End;
 { Load every third-party footprint before changing a design. }
 For K:=1 To 7 Do Begin
  S:=PCBServer.LoadCompFromLibrary(SourcePattern(K),BASE+'lib\celestial\'+SourceFile(K));
  If S=Nil Then Begin ShowMessage('Missing source footprint '+SourcePattern(K)); Abort; End;
 End;
 SD:=Client.OpenNewDocument('PCBLIB','PinRepairFootprints','PinRepairFootprints',False);
 Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
 PCBServer.PreProcess;
 Try
 For K:=1 To 10 Do Begin
  C:=PCBServer.CreatePCBLibComp; C.Name:=Pattern(K);
  C.Description:='Pin-repair library; see docs/PIN_REPAIR.html for source and mapping';
  If K<=7 Then Begin
   S:=PCBServer.LoadCompFromLibrary(SourcePattern(K),BASE+'lib\celestial\'+SourceFile(K));
   S.MoveByXY(-S.X,-S.Y);
   Repeat
    GI:=S.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; S.GroupIterator_Destroy(GI);
    If O<>Nil Then Begin
     If O.ObjectId=ePadObject Then Begin
      P:=O; OldName:=P.Name;
      { Celestial diode pad 1 is cathode; the circuit's pin 1 is anode. }
      If (K>=3) And (K<=5) Then Begin If OldName='1' Then P.Name:='2' Else If OldName='2' Then P.Name:='1' Else Abort; End;
      { Omron top-view: physical 1+2 are common; physical 3+4 are common. }
      If K=7 Then Begin If (OldName='1') Or (OldName='2') Then P.Name:='1' Else If (OldName='3') Or (OldName='4') Then P.Name:='2' Else Abort; End;
     End;
     S.RemovePCBObject(O);
     { The 1012P body is taller than the selected 1000P. Keep its verified
       common land pattern, but do NOT present its different STEP as exact. }
     If Not ((K=7) And (O.ObjectId=eComponentBodyObject)) Then C.AddPCBObject(O);
    End;
   Until O=Nil;
   If K=7 Then C.Height:=MMsToCoord(3.3);
  End;
  If K=8 Then Begin
   { Bourns MF-MSMF110/24X, style 2: 3.10 gap; pads 1.68 x 2.95. }
   Pad(C,'1',-2.39,0,1.68,2.95,0); Pad(C,'2',2.39,0,1.68,2.95,0);
   Track(C,-1.4,1.8,1.4,1.8); Track(C,-1.4,-1.8,1.4,-1.8); C.Height:=MMsToCoord(1.6);
  End;
  If K=9 Then Begin
   { Littelfuse 451: 2.95 gap; pads 1.96 x 3.15; 6.86 overall length. }
   Pad(C,'1',-2.455,0,1.96,3.15,0); Pad(C,'2',2.455,0,1.96,3.15,0);
   Track(C,-1.3,1.6,1.3,1.6); Track(C,-1.3,-1.6,1.3,-1.6); C.Height:=MMsToCoord(2.94);
  End;
  If K=10 Then Begin
   Pad(C,'1',0,0,1.8,1.8,1.02); Pad(C,'2',2.54,0,1.8,1.8,1.02);
   Track(C,-1.27,-1.27,3.81,-1.27); Track(C,3.81,-1.27,3.81,1.27);
   Track(C,3.81,1.27,-1.27,1.27); Track(C,-1.27,1.27,-1.27,-1.27); C.Height:=MMsToCoord(8.5);
  End;
  L.RegisterComponent(C); L.CurrentComponent:=C; Report.Add('LIB_CREATED|'+Pattern(K));
 End;
 Finally PCBServer.PostProcess; End;
 If Not SD.DoSafeChangeFileNameAndSave(BASE+LIBPATH,'PCBLIB') Then Abort;
End;
Procedure SetParam(C,N,V);
Var It : ISch_Iterator; P : ISch_Parameter;
Begin
 It:=C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eParameter)); P:=It.FirstSchObject;
 While P<>Nil Do Begin If P.Name=N Then Break; P:=It.NextSchObject; End; C.SchIterator_Destroy(It);
 If P=Nil Then Begin P:=SchServer.SchObjectFactory(eParameter,eCreate_GlobalCopy); P.Name:=N; P.IsHidden:=True; C.AddSchObject(P); End;
 P.Text:=V;
End;
Procedure Signature(D,T);
Var I,J : ISch_Iterator; C : ISch_Component; P : ISch_Pin;
Begin
 I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=I.FirstSchObject;
 While C<>Nil Do Begin
  J:=C.SchIterator_Create; J.AddFilter_ObjectSet(MkSet(ePin)); P:=J.FirstSchObject;
  While P<>Nil Do Begin T.Add(C.Designator.Text+'|'+P.Designator+'|'+IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y)+'|'+IntToStr(P.Orientation)); P:=J.NextSchObject; End;
  C.SchIterator_Destroy(J); C:=I.NextSchObject;
 End; D.SchIterator_Destroy(I); T.Sort;
End;
Procedure UpdateSheet(F);
Var SD : IServerDocument; D : ISch_Document; I,J : ISch_Iterator; C : ISch_Component; M : ISch_Implementation;
 A,Z : TStringList; R,Map : String; K,N : Integer;
Begin
 SD:=Client.OpenDocument('SCH',BASE+F); Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
 A:=TStringList.Create; Z:=TStringList.Create; Signature(D,A);
 SchServer.ProcessControl.PreProcess(D,'Repair missing physical models');
 Try
 I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=I.FirstSchObject;
 While C<>Nil Do Begin
  R:=C.Designator.Text; K:=Kind(R);
  If K>0 Then Begin
   J:=C.SchIterator_Create; J.AddFilter_ObjectSet(MkSet(eImplementation)); M:=J.FirstSchObject; C.SchIterator_Destroy(J);
   If M<>Nil Then Begin ShowMessage('Unexpected existing model on '+R+'; stopped without replacing it.'); Abort; End;
   M:=C.AddSchImplementation; M.ModelType:='PCBLIB'; M.ModelName:=Pattern(K); M.IsCurrent:=True;
   M.AddDataFileLink(Pattern(K),BASE+LIBPATH,'PCBLIB'); Map:='(1:1),(2:2)'; If K=6 Then Map:='(1:1),(2:2),(3:3)'; M.MapAsString:=Map;
   C.ComponentKind:=eComponentKind_Standard;
   SetParam(C,'Intended footprint',Pattern(K)); SetParam(C,'Footprint source','Local PinRepairFootprints.PcbLib; source and polarity checked');
   SetParam(C,'CAD status','Pin link repaired; placement/routing/DRC not released');
   If R='F1' Then Begin
    C.LibReference:='MF-MSMF110/24X-2'; C.Comment.Text:='1.1A PTC / 24V';
    SetParam(C,'Manufacturer Part Number','MF-MSMF110/24X-2'); SetParam(C,'Part Number','MF-MSMF110/24X-2');
    SetParam(C,'Voltage rating','24 V');
   End;
   N:=Refs.IndexOf(R); If N<0 Then Abort; UIDs[N]:=C.UniqueId; Comments[N]:=C.Comment.Text;
   Report.Add('SCH_LINK|'+R+'|'+Pattern(K)+'|'+M.MapAsString);
  End;
  { Installation heads/adapters remain real identified symbols in the existing
    pages. Graphical TYPE excludes them from PCB synchronization, not drawing.
    They are listed separately in the installation procurement documentation. }
  If (Copy(R,1,2)='RX') Or (Copy(R,1,2)='TX') Or (R='PS1') Or (R='PS2') Then Begin
   C.ComponentKind:=eComponentKind_Graphical; SetParam(C,'Assembly location','External installation; not mounted on controller PCB');
   SetParam(C,'Procurement list','docs/PIN_REPAIR.html - external hardware'); Report.Add('OFFBOARD_EXCLUDED|'+R);
  End;
  C:=I.NextSchObject;
 End; D.SchIterator_Destroy(I);
 Finally SchServer.ProcessControl.PostProcess(D,'Repair missing physical models'); End;
 Signature(D,Z); If A.Text<>Z.Text Then Begin ShowMessage('Pin geometry changed; do not save.'); Abort; End;
 Report.Add('PIN_GEOMETRY_UNCHANGED|'+F); D.GraphicallyInvalidate; SD.Modified:=True; SD.DoFileSave('SCHBinary5.0');
 A.Free; Z.Free;
End;
Function FindComponent(B,R) : IPCB_Component;
Var I : IPCB_BoardIterator; C : IPCB_Component;
Begin
 Result:=Nil; I:=B.BoardIterator_Create; I.AddFilter_ObjectSet(MkSet(eComponentObject)); I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
 C:=I.FirstPCBObject; While C<>Nil Do Begin
  If (C.SourceDesignator=R) Or (C.Name.Text=R) Then Begin Result:=C; Break; End; C:=I.NextPCBObject;
 End; B.BoardIterator_Destroy(I);
End;
Function NetName(R,P) : String;
Var Channel : String;
Begin
 Result:='';
 If R='C1' Then Begin If P='1' Then Result:='12V_SENSOR' Else Result:='GND'; End;
 If R='C5' Then Begin If P='1' Then Result:='5V_LOGIC' Else Result:='GND'; End;
 If R='D1' Then Begin If P='1' Then Result:='GND' Else Result:='12V_SENSOR'; End;
 If R='D6' Then Begin If P='1' Then Result:='12V_FUSED' Else Result:='12V_SENSOR'; End;
 If Kind(R)=5 Then Begin
  Channel:='1'; If R='D3' Then Channel:='2'; If R='D4' Then Channel:='3'; If R='D7' Then Channel:='4';
  If P='1' Then Result:='BEAM'+Channel+'_SIG' Else Result:='BEAM'+Channel+'_LED_A';
 End;
 If R='F1' Then Begin If P='1' Then Result:='NetF1_1' Else Result:='12V_FUSED'; End;
 If R='F2' Then Begin If P='1' Then Result:='12V_SENSOR' Else Result:='12V_RGB_FUSED'; End;
 If R='JP1' Then Begin If P='1' Then Result:='5V_LOGIC' Else Result:='5V_MCU'; End;
 If Kind(R)=6 Then Begin
  Channel:='RED'; If R='Q3' Then Channel:='GREEN'; If R='Q4' Then Channel:='BLUE';
  If P='1' Then Result:='RGB_'+Channel+'_GATE'; If P='2' Then Result:='GND'; If P='3' Then Result:='RGB_'+Channel+'_LOW';
 End;
 If R='SW1' Then Begin If P='1' Then Result:='BUTTON_GPIO13' Else Result:='GND'; End;
End;
Function FindNet(B,N) : IPCB_Net;
Var I : IPCB_BoardIterator; V : IPCB_Net;
Begin
 Result:=Nil; I:=B.BoardIterator_Create; I.AddFilter_ObjectSet(MkSet(eNetObject)); I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
 V:=I.FirstPCBObject; While V<>Nil Do Begin If V.Name=N Then Begin Result:=V; Break; End; V:=I.NextPCBObject; End;
 B.BoardIterator_Destroy(I);
End;
Procedure AddMissingBoardParts;
Var SD : IServerDocument; B : IPCB_Board; C : IPCB_Component; L : IPCB_LibComponent;
 GI : IPCB_GroupIterator; O : IPCB_Primitive; P : IPCB_Pad; Net : IPCB_Net; I,K,N,NB : Integer; R,NN : String;
Begin
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
 For I:=0 To Refs.Count-1 Do Begin
  If FindComponent(B,Refs[I])<>Nil Then Begin ShowMessage('Component '+Refs[I]+' already exists. No duplicate will be added.'); Abort; End;
  If UIDs[I]='' Then Abort;
 End;
 PCBServer.PreProcess;
 Try
 For I:=0 To Refs.Count-1 Do Begin
  R:=Refs[I]; K:=Kind(R); L:=PCBServer.LoadCompFromLibrary(Pattern(K),BASE+LIBPATH); If L=Nil Then Abort;
  C:=PCBServer.PCBObjectFactory(eComponentObject,eNoDimension,eCreate_Default);
  { Stage only the missing parts outside the board. Do not disturb the user's layout. }
  C.X:=MMsToCoord(165+(I Mod 3)*20); C.Y:=MMsToCoord(85-(I Div 3)*20);
  C.Pattern:=Pattern(K); C.SourceDesignator:=R; C.SourceUniqueId:=UIDs[I]; C.SourceFootprintLibrary:=BASE+LIBPATH;
  C.Name.Text:=R; C.Comment.Text:=Comments[I]; C.NameOn:=True; C.CommentOn:=False; C.Height:=L.Height;
  C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1);
  C.Name.XLocation:=C.X-MMsToCoord(2); C.Name.YLocation:=C.Y+MMsToCoord(6);
  L.MoveByXY(C.X-L.X,C.Y-L.Y); N:=0; NB:=0;
  Repeat
   GI:=L.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; L.GroupIterator_Destroy(GI);
   If O<>Nil Then Begin
    If O.ObjectId=ePadObject Then Begin
     P:=O; NN:=NetName(R,P.Name); Net:=FindNet(B,NN);
     If (NN='') Or (Net=Nil) Then Begin ShowMessage('Missing target net '+R+'-'+P.Name+' '+NN+'; stop without saving.'); Abort; End;
     P.Net:=Net; N:=N+1; Report.Add('ASSIGN|'+R+'|'+P.Name+'|'+NN);
    End;
    If O.ObjectId=eComponentBodyObject Then NB:=NB+1;
    L.RemovePCBObject(O); C.AddPCBObject(O);
   End;
  Until O=Nil;
  B.AddPCBObject(C); Report.Add('PCB_ADDED|'+R+'|'+Pattern(K)+'|PADS='+IntToStr(N)+'|BODIES='+IntToStr(NB));
 End;
 Finally PCBServer.PostProcess; End;
 { Verify all new pads through their registered board component ownership. }
 For I:=0 To Refs.Count-1 Do Begin
  C:=FindComponent(B,Refs[I]); If C=Nil Then Abort;
  GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject; N:=0;
  While P<>Nil Do Begin
   If P.Net=Nil Then Abort; If P.Net.Name<>NetName(Refs[I],P.Name) Then Abort;
   N:=N+1; P:=GI.NextPCBObject;
  End; C.GroupIterator_Destroy(GI); K:=Kind(Refs[I]); NB:=2; If K=6 Then NB:=3; If K=7 Then NB:=4;
  If N<>NB Then Begin ShowMessage('Pad count verification failed '+Refs[I]); Abort; End;
  Report.Add('VERIFIED|'+Refs[I]+'|'+IntToStr(N));
 End;
 B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
 Report.Add('CONTROLLER_PCB_SAVED');
End;
Procedure RepairMissingPins;
Var F : TStringList; I : Integer;
Begin
 Report:=TStringList.Create; Refs:=TStringList.Create; UIDs:=TStringList.Create; Comments:=TStringList.Create; F:=TStringList.Create;
 Refs.CommaText:='C1,C5,D1,D2,D3,D4,D6,D7,F1,F2,JP1,Q2,Q3,Q4,SW1';
 For I:=0 To Refs.Count-1 Do Begin UIDs.Add(''); Comments.Add(''); End;
 Try
  MakeLibrary;
  F.CommaText:='01_Power_Control.SchDoc,02_Beam_Inputs.SchDoc,03_UI_Outputs.SchDoc,04_Optical_Heads.SchDoc,05_Installation.SchDoc';
  For I:=0 To F.Count-1 Do UpdateSheet(F[I]);
  AddMissingBoardParts;
  Report.Add('COMPLETE_NATIVE_REPAIR');
 Finally Report.SaveToFile(BASE+'PinRepair.audit.txt'); End;
 ShowMessage('Missing footprints and pins repaired. 15 parts staged to the right of the controller PCB. Run project validation and a fresh ECO.');
 F.Free; Comments.Free; UIDs.Free; Refs.Free; Report.Free;
End;

{ Garage Beam Safety V3 controller PCB repair.

  This script deliberately does not autoroute.  It removes the previous
  demonstration lane-router copper, compacts the functional groups onto a
  110 x 85 mm controller board, restores a 12 V screw-terminal input, assigns
  meaningful component heights for 3D clearance work, and draws/selects a new
  Mechanical 1 outline.  After it finishes use:

    Design > Board Shape > Define from Selected Objects

  The unrouted connection lines are intentional: they are honest engineering
  work remaining after the exact purchased footprints have been verified. }

Const
    PCB_PATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.PcbDoc';
    LOG_PATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\PCBRepairV3.log';

Procedure V3Log(S);
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try L.Add(S); L.SaveToFile(LOG_PATH); Finally L.Free; End;
End;

Function FindComp(B, RefDes) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil;
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        If (C.SourceDesignator = RefDes) Or (C.Name.Text = RefDes) Then
        Begin Result := C; Break; End;
        C := It.NextPCBObject;
    End;
    B.BoardIterator_Destroy(It);
End;

Function FindNet(B, NetName) : IPCB_Net;
Var It : IPCB_BoardIterator; N : IPCB_Net;
Begin
    Result := Nil;
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do
    Begin
        If N.Name = NetName Then Begin Result := N; Break; End;
        N := It.NextPCBObject;
    End;
    B.BoardIterator_Destroy(It);
End;

Function EnsureNet(B, NetName) : IPCB_Net;
Var N : IPCB_Net;
Begin
    N := FindNet(B, NetName);
    If N = Nil Then
    Begin
        N := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
        N.Name := NetName; N.ConnectsVisible := True; B.AddPCBObject(N);
    End;
    Result := N;
End;

Procedure DropComp(B, RefDes);
Var C : IPCB_Component;
Begin
    C := FindComp(B, RefDes);
    If C <> Nil Then B.RemovePCBObject(C);
End;

Procedure PlaceComp(B, RefDes, Xmm, Ymm, RotDeg, Hmm);
Var C : IPCB_Component; DX, DY : TCoord;
Begin
    C := FindComp(B, RefDes); If C = Nil Then Exit;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
    { MoveByXY translates the component and all child pads/overlay primitives.
      Assigning C.X/C.Y alone only moved the origin in this generated board. }
    DX := MMsToCoord(Xmm) - C.X; DY := MMsToCoord(Ymm) - C.Y;
    C.MoveByXY(DX,DY);
    C.Rotation := RotDeg; C.Height := MMsToCoord(Hmm);
    { Replace generated placeholder text with the real reference designator.
      Use the same Arial family as the schematic sheets. }
    C.NameOn := True;
    C.Name.Text := RefDes;
    C.Name.UseTTFonts := True;
    C.Name.FontName := 'Arial';
    C.Name.Bold := True;
    C.Name.Italic := False;
    C.Name.Size := MMsToCoord(1.2);
    { Hide placeholder footprint comments; values remain available in
      Properties and the BOM without cluttering the assembly view. }
    C.CommentOn := False;
    { Generated placeholder designator/comment primitives were absolute rather
      than footprint-relative; park them beside the new component origin. }
    C.Name.XLocation := C.X - MMsToCoord(2.0);
    C.Name.YLocation := C.Y + MMsToCoord(2.5);
    C.Comment.XLocation := C.X - MMsToCoord(2.0);
    C.Comment.YLocation := C.Y - MMsToCoord(2.5);
    C.Selected := False;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
End;

Function NewPad(Xmm, Ymm, SXmm, SYmm, Holemm, PadName) : IPCB_Pad;
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    P.X := MMsToCoord(Xmm); P.Y := MMsToCoord(Ymm);
    P.TopXSize := MMsToCoord(SXmm); P.TopYSize := MMsToCoord(SYmm);
    P.HoleSize := MMsToCoord(Holemm); P.Layer := eMultiLayer; P.Name := PadName;
    Result := P;
End;

Function NewOverlayTrack(X1, Y1, X2, Y2) : IPCB_Track;
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(0.2); T.Layer := eTopOverlay; Result := T;
End;

Procedure AddPowerTerminal(B);
Var C : IPCB_Component; P : IPCB_Pad; T : IPCB_Track; N : IPCB_Net;
Begin
    C := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    T := NewOverlayTrack(-5.2,-4.0,5.2,-4.0); C.AddPCBObject(T);
    T := NewOverlayTrack(5.2,-4.0,5.2,4.0); C.AddPCBObject(T);
    T := NewOverlayTrack(5.2,4.0,-5.2,4.0); C.AddPCBObject(T);
    T := NewOverlayTrack(-5.2,4.0,-5.2,-4.0); C.AddPCBObject(T);
    P := NewPad(-2.54,0,2.4,2.4,1.3,'1'); C.AddPCBObject(P);
    P := NewPad(2.54,0,2.4,2.4,1.3,'2'); C.AddPCBObject(P);
    C.X := MMsToCoord(10); C.Y := MMsToCoord(77); C.Layer := eTopLayer;
    C.Rotation := 0; C.Height := MMsToCoord(10.0);
    C.NameOn := True; C.Name.Text := 'J1';
    C.Name.UseTTFonts := True; C.Name.FontName := 'Arial';
    C.Name.Bold := True; C.Name.Italic := False; C.Name.Size := MMsToCoord(1.2);
    C.Name.XLocation := MMsToCoord(5); C.Name.YLocation := MMsToCoord(82);
    C.CommentOn := True; C.Comment.Text := '12 V INPUT';
    C.Comment.UseTTFonts := True; C.Comment.FontName := 'Arial';
    C.Comment.Bold := False; C.Comment.Italic := False; C.Comment.Size := MMsToCoord(1.0);
    C.Comment.XLocation := MMsToCoord(5); C.Comment.YLocation := MMsToCoord(71.5);
    C.SourceDesignator := 'J1'; B.AddPCBObject(C);
    N := EnsureNet(B,'12V_IN'); P := C.GetState_PadByName('1'); P.Net := N; N.RegisterWithGroupWarehouse(P);
    N := EnsureNet(B,'GND'); P := C.GetState_PadByName('2'); P.Net := N; N.RegisterWithGroupWarehouse(P);
End;

Procedure AssignPad(B, RefDes, PadName, NetName);
Var C : IPCB_Component; P : IPCB_Pad; N : IPCB_Net;
Begin
    C := FindComp(B, RefDes); If C = Nil Then Exit;
    P := C.GetState_PadByName(PadName); If P = Nil Then Exit;
    N := EnsureNet(B,NetName); P.Net := N; N.RegisterWithGroupWarehouse(P);
End;

Procedure RemoveOldFreeGeometry(B);
Var It : IPCB_BoardIterator; O, OldO : IPCB_Primitive; RemoveIt : Boolean;
Begin
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eTrackObject,eViaObject,eTextObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    O := It.FirstPCBObject;
    While O <> Nil Do
    Begin
        OldO := O; O := It.NextPCBObject; RemoveIt := False;
        If OldO.ObjectId = eViaObject Then RemoveIt := True;
        If OldO.ObjectId = eTrackObject Then
            RemoveIt := (OldO.Layer = eTopLayer) Or (OldO.Layer = eBottomLayer) Or
                        (OldO.Layer = eMechanical1) Or
                        (((OldO.Layer = eTopOverlay) Or (OldO.Layer = eBottomOverlay)) And
                         (Not OldO.InComponent));
        If OldO.ObjectId = eTextObject Then
            RemoveIt := (OldO.Layer = eMechanical1) Or
                        (((OldO.Layer = eTopOverlay) Or (OldO.Layer = eBottomOverlay)) And
                         (Not OldO.InComponent));
        If RemoveIt Then B.RemovePCBObject(OldO);
    End;
    B.BoardIterator_Destroy(It);
End;

Function OutlineTrack(X1,Y1,X2,Y2) : IPCB_Track;
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(0.2); T.Layer := eMechanical1; T.Selected := True;
    Result := T;
End;

Procedure AddNewOutline(B);
Var T : IPCB_Track;
Begin
    T := OutlineTrack(0,0,110,0); B.AddPCBObject(T); T.Selected := True;
    T := OutlineTrack(110,0,110,85); B.AddPCBObject(T); T.Selected := True;
    T := OutlineTrack(110,85,0,85); B.AddPCBObject(T); T.Selected := True;
    T := OutlineTrack(0,85,0,0); B.AddPCBObject(T); T.Selected := True;
End;

Procedure DropFreePadByName(B; PadName : String);
Var It : IPCB_BoardIterator; P, Found : IPCB_Pad;
Begin
    Found := Nil;
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(ePadObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    P := It.FirstPCBObject;
    While P <> Nil Do
    Begin
        If (P.Name = PadName) And (P.Net = Nil) Then Begin Found := P; Break; End;
        P := It.NextPCBObject;
    End;
    B.BoardIterator_Destroy(It);
    If Found <> Nil Then B.RemovePCBObject(Found);
End;

Procedure AddMountingHole(B; Xmm, Ymm : Real; PadName : String);
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
    P.Name := PadName; P.X := MMsToCoord(Xmm); P.Y := MMsToCoord(Ymm);
    P.Layer := eMultiLayer;
    P.TopXSize := MMsToCoord(6.0); P.TopYSize := MMsToCoord(6.0);
    P.MidXSize := MMsToCoord(6.0); P.MidYSize := MMsToCoord(6.0);
    P.BotXSize := MMsToCoord(6.0); P.BotYSize := MMsToCoord(6.0);
    P.HoleSize := MMsToCoord(3.2); P.Plated := False;
    B.AddPCBObject(P);
End;

Procedure RepairMountingHoles(B);
Var It : IPCB_BoardIterator; P, OldP : IPCB_Pad; Outside : Boolean;
Begin
    { Purge legacy free mounting pads stranded outside the new 110 x 85 mm PCB. }
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(ePadObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    P := It.FirstPCBObject;
    While P <> Nil Do
    Begin
        OldP := P; P := It.NextPCBObject;
        Outside := (OldP.X < 0) Or (OldP.Y < 0) Or
                   (OldP.X > MMsToCoord(110)) Or (OldP.Y > MMsToCoord(85));
        If Outside And (Not OldP.InComponent) Then B.RemovePCBObject(OldP);
    End;
    B.BoardIterator_Destroy(It);
    DropFreePadByName(B,'H1'); DropFreePadByName(B,'H2');
    DropFreePadByName(B,'H3'); DropFreePadByName(B,'H4');
    AddMountingHole(B,5,5,'H1'); AddMountingHole(B,105,5,'H2');
    AddMountingHole(B,5,80,'H3'); AddMountingHole(B,105,80,'H4');
End;

Procedure ApplyCompactPlacement(B);
Begin
    { power across the top edge }
    PlaceComp(B,'F1',24,77,0,4.0); PlaceComp(B,'Q1',34,77,0,1.5);
    PlaceComp(B,'D1',42,72,90,2.5); PlaceComp(B,'C1',51,76,90,12.0);
    PlaceComp(B,'A2',65,75,0,10.0); PlaceComp(B,'C5',78,75,90,10.0);

    { beam terminals at the left edge, analogue chains directly behind them }
    PlaceComp(B,'J2',8,57,90,10.0); PlaceComp(B,'R5',22,60,0,1.2);
    PlaceComp(B,'U2',31,57,0,4.0); PlaceComp(B,'D2',31,51,0,1.5);
    PlaceComp(B,'R6',41,60,0,1.2); PlaceComp(B,'R7',49,60,0,1.2); PlaceComp(B,'C2',49,54,0,1.2);

    PlaceComp(B,'J3',8,39,90,10.0); PlaceComp(B,'R8',22,42,0,1.2);
    PlaceComp(B,'U3',31,39,0,4.0); PlaceComp(B,'D3',31,33,0,1.5);
    PlaceComp(B,'R9',41,42,0,1.2); PlaceComp(B,'R10',49,42,0,1.2); PlaceComp(B,'C3',49,36,0,1.2);

    PlaceComp(B,'J4',8,21,90,10.0); PlaceComp(B,'R11',22,24,0,1.2);
    PlaceComp(B,'U4',31,21,0,4.0); PlaceComp(B,'D4',31,15,0,1.5);
    PlaceComp(B,'R12',41,24,0,1.2); PlaceComp(B,'R13',49,24,0,1.2); PlaceComp(B,'C4',49,18,0,1.2);

    { ESP32 at right edge; antenna end faces the clear top edge }
    PlaceComp(B,'A1',92,48,0,13.0);

    { low-current UI group at bottom }
    PlaceComp(B,'J5',65,8,0,10.0); PlaceComp(B,'R14',62,17,0,1.2);
    PlaceComp(B,'R15',70,17,0,1.2); PlaceComp(B,'R16',78,17,0,1.2);
    PlaceComp(B,'R17',83,12,0,1.2); PlaceComp(B,'Q2',90,12,0,1.5);
    PlaceComp(B,'BZ1',100,13,0,5.0); PlaceComp(B,'D5',100,21,0,1.5);
    PlaceComp(B,'SW1',87,6,0,4.0);
End;

Procedure RepairControllerPCBv3;
Var SD : IServerDocument; B : IPCB_Board;
Begin
    Client.StartServer('PCB'); SD := Client.OpenDocument('PCB',PCB_PATH);
    If SD = Nil Then Begin V3Log('ERROR: cannot open PCB'); Exit; End;
    Client.ShowDocument(SD); SD.Focus; B := PCBServer.GetCurrentPCBBoard;
    If B = Nil Then Begin V3Log('ERROR: no current PCB'); Exit; End;
    PCBServer.PreProcess;
    Try
        RemoveOldFreeGeometry(B);
        DropComp(B,'J1'); DropComp(B,'R1'); DropComp(B,'R2');
        AddPowerTerminal(B); ApplyCompactPlacement(B); RepairMountingHoles(B);

        AssignPad(B,'F1','1','12V_IN'); AssignPad(B,'F1','2','12V_FUSED');
        AssignPad(B,'D1','1','12V_FUSED'); AssignPad(B,'D1','2','GND');
        AssignPad(B,'Q1','1','GND'); AssignPad(B,'Q1','2','12V_FUSED'); AssignPad(B,'Q1','3','12V_SENSOR');
        AssignPad(B,'C1','1','12V_SENSOR'); AssignPad(B,'C1','2','GND');
        AssignPad(B,'A2','1','12V_SENSOR'); AssignPad(B,'A2','2','GND'); AssignPad(B,'A2','3','5V_LOGIC');
        AssignPad(B,'C5','1','5V_LOGIC'); AssignPad(B,'C5','2','GND');
        AddNewOutline(B);
    Finally PCBServer.PostProcess; End;
    B.ViewManager_FullUpdate; SD.Modified := True;
    If SD.DoFileSave('PCB Binary 6.0') Then
        V3Log('OK: compact placement; 12 V terminal; heights; unrouted by design; outline selected')
    Else V3Log('ERROR: save failed');
    ResetParameters; AddStringParameter('Action','All'); RunProcess('PCB:Zoom');
End;

Procedure DumpPCBComponentIDs;
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator;
    C : IPCB_Component; L : TStringList;
Begin
    Client.StartServer('PCB'); SD := Client.OpenDocument('PCB',PCB_PATH);
    If SD = Nil Then Exit;
    Client.ShowDocument(SD); SD.Focus; B := PCBServer.GetCurrentPCBBoard;
    If B = Nil Then Exit;
    L := TStringList.Create;
    It := B.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        L.Add('SOURCE=' + C.SourceDesignator + '|NAME=' + C.Name.Text +
              '|COMMENT=' + C.Comment.Text + '|X=' + IntToStr(C.X) +
              '|Y=' + IntToStr(C.Y));
        C := It.NextPCBObject;
    End;
    B.BoardIterator_Destroy(It);
    L.SaveToFile('C:\dev\projects\h\garage_door_colision_detector\hardware\altium\PCBComponentIDs.txt');
    L.Free;
End;

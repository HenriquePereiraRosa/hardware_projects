{ Garage Beam Safety D3 - Altium PCB mechanical guide generator.
  Run one procedure with a NEW, BLANK PcbDoc focused. It draws exact outlines,
  mounting-hole centres and optical datums on Mechanical 1. It deliberately does
  not claim to place or route unverified electrical footprints. }

Procedure AddGuideTrack(Board, X1, Y1, X2, Y2, WidthMM);
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    If T = Nil Then Exit;
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(WidthMM); T.Layer := eMechanical1;
    Board.AddPCBObject(T);
End;

Procedure AddGuideArc(Board, X, Y, RadiusMM, WidthMM);
Var A : IPCB_Arc;
Begin
    A := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    If A = Nil Then Exit;
    A.XCenter := MMsToCoord(X); A.YCenter := MMsToCoord(Y);
    A.Radius := MMsToCoord(RadiusMM); A.StartAngle := 0; A.EndAngle := 360;
    A.LineWidth := MMsToCoord(WidthMM); A.Layer := eMechanical1;
    Board.AddPCBObject(A);
End;

Procedure AddGuideText(Board, X, Y, S, HeightMM);
Var T : IPCB_Text;
Begin
    T := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
    If T = Nil Then Exit;
    T.XLocation := MMsToCoord(X); T.YLocation := MMsToCoord(Y);
    T.Text := S; T.Size := MMsToCoord(HeightMM); T.Width := MMsToCoord(0.20);
    T.Layer := eMechanical1; Board.AddPCBObject(T);
End;

Procedure AddCrosshair(Board, X, Y, LabelText);
Begin
    AddGuideTrack(Board, X - 4, Y, X + 4, Y, 0.20);
    AddGuideTrack(Board, X, Y - 4, X, Y + 4, 0.20);
    AddGuideArc(Board, X, Y, 3, 0.20);
    AddGuideText(Board, X + 5, Y - 1, LabelText, 1.2);
End;

Procedure AddMountHoleGuide(Board, X, Y, LabelText);
Begin
    AddGuideArc(Board, X, Y, 1.6, 0.25);
    AddGuideArc(Board, X, Y, 5.0, 0.15);
    AddGuideText(Board, X + 2, Y + 2, LabelText + '  3.2 mm NPTH / 10 mm keepout', 0.9);
End;

Procedure RequireBlankPCB(Var Board : IPCB_Board);
Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
        ShowMessage('Open and focus a NEW BLANK PcbDoc, then run the procedure again.');
End;

Procedure BuildControllerCarrierGuide;
Var Board : IPCB_Board;
Begin
    RequireBlankPCB(Board); If Board = Nil Then Exit;
    PCBServer.PreProcess;
    Try
        AddGuideTrack(Board, 0, 0, 50, 0, 0.25);
        AddGuideTrack(Board, 50, 0, 50, 240, 0.25);
        AddGuideTrack(Board, 50, 240, 0, 240, 0.25);
        AddGuideTrack(Board, 0, 240, 0, 0, 0.25);
        AddMountHoleGuide(Board, 5, 5, 'H1');
        AddMountHoleGuide(Board, 45, 5, 'H2');
        AddMountHoleGuide(Board, 5, 235, 'H3');
        AddMountHoleGuide(Board, 45, 235, 'H4');
        AddCrosshair(Board, 25, 20, 'BEAM 1 / J2 / DATUM 0 mm');
        AddCrosshair(Board, 25, 120, 'BEAM 2 / J3 / +100 mm');
        AddCrosshair(Board, 25, 220, 'BEAM 3 / J4 / +200 mm');
        AddGuideText(Board, 3, 110, 'D3 CONTROLLER CARRIER - PLACEMENT GUIDE ONLY', 1.4);
        AddGuideText(Board, 3, 8, 'USB-C LOWER EDGE / ADVISORY ONLY / 0805 SMD', 1.1);
    Finally
        PCBServer.PostProcess;
    End;
    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView);
    ShowMessage('D3 controller carrier guide drawn on Mechanical 1. Save with a new project filename.');
End;

Procedure BuildReflectorCarrierGuide;
Var Board : IPCB_Board;
Begin
    RequireBlankPCB(Board); If Board = Nil Then Exit;
    PCBServer.PreProcess;
    Try
        AddGuideTrack(Board, 0, 0, 30, 0, 0.25);
        AddGuideTrack(Board, 30, 0, 30, 240, 0.25);
        AddGuideTrack(Board, 30, 240, 0, 240, 0.25);
        AddGuideTrack(Board, 0, 240, 0, 0, 0.25);
        AddMountHoleGuide(Board, 5, 5, 'H1');
        AddMountHoleGuide(Board, 25, 5, 'H2');
        AddMountHoleGuide(Board, 5, 235, 'H3');
        AddMountHoleGuide(Board, 25, 235, 'H4');
        AddCrosshair(Board, 15, 20, 'REFLECTOR 1 / DATUM 0 mm');
        AddCrosshair(Board, 15, 120, 'REFLECTOR 2 / +100 mm');
        AddCrosshair(Board, 15, 220, 'REFLECTOR 3 / +200 mm');
        AddGuideText(Board, 2, 110, 'D3 PASSIVE REFLECTOR CARRIER - NO POWER / NO COPPER', 1.2);
    Finally
        PCBServer.PostProcess;
    End;
    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView);
    ShowMessage('D3 passive reflector guide drawn on Mechanical 1. Save as a separate PcbDoc.');
End;

{ Garage Beam Safety D3 readable multi-sheet native schematic builder. }

Const
    ALTIUMROOT = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';
    OVERVIEWPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\00_Mounting_Overview.SchDoc';
    POWERPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\01_Power_Control.SchDoc';
    BEAMPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\02_Beam_Inputs.SchDoc';
    UIPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\03_UI_Outputs.SchDoc';
    READABLELOG = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\ReadableBuild.log';
    TEMPLATESCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\template-source\SCH\ENERGY.SchDoc';
    COL_BG = $00202020;
    COL_PANEL = $00303030;
    COL_WHITE = $00F2F2F2;
    COL_CYAN = $00FFD080;
    COL_AMBER = $0040C0FF;
    COL_RED = $004040FF;
    COL_GREEN = $0080FF80;

Procedure RLog(S);
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try L.Add(S); L.SaveToFile(READABLELOG); Finally L.Free; End;
End;

Function OpenOrCreateSheet(APath) : IServerDocument;
Var M : IServerModule; D : IServerDocument;
Begin
    Client.StartServer('SCH');
    D := Client.OpenDocument('SCH', APath);
    If D = Nil Then
    Begin
        M := Client.ServerModuleByName['SCH'];
        If M <> Nil Then D := M.CreateDocument('SCH', APath);
    End;
    If D <> Nil Then Begin Client.ShowDocument(D); D.Focus; End;
    Result := D;
End;

Procedure ClearReadableSheet(Doc);
Var It : ISch_Iterator; O, OldO : ISch_GraphicalObject;
Begin
    It := Doc.SchIterator_Create;
    If It = Nil Then Exit;
    It.SetState_FilterAll;
    Try
        O := It.FirstSchObject;
        While O <> Nil Do
        Begin
            OldO := O; O := It.NextSchObject; Doc.RemoveSchObject(OldO);
        End;
    Finally Doc.SchIterator_Destroy(It); End;
End;

Procedure AddRText(Doc, X, Y, S, AColor);
Var L : ISch_Label;
Begin
    L := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S; L.Color := AColor; L.Orientation := eRotate0;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddRRect(Doc, X1, Y1, X2, Y2, LineColor, FillColor, Solid);
Var R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    If R = Nil Then Exit;
    R.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    R.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    R.LineWidth := eMedium; R.Color := LineColor; R.AreaColor := FillColor;
    R.IsSolid := Solid; Doc.RegisterSchObjectInContainer(R);
End;

Procedure AddRLine(Doc, X1, Y1, X2, Y2, AColor, Width);
Var L : ISch_Line;
Begin
    L := SchServer.SchObjectFactory(eLine, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    L.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    L.LineWidth := Width; L.LineStyle := eLineStyleSolid; L.Color := AColor;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddRWire(Doc, X1, Y1, X2, Y2);
Var W : ISch_Wire;
Begin
    W := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    If W = Nil Then Exit;
    W.SetState_LineWidth(eSmall);
    W.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    W.InsertVertex(1); W.SetState_Vertex(1, Point(MilsToCoord(X1), MilsToCoord(Y1)));
    W.InsertVertex(2); W.SetState_Vertex(2, Point(MilsToCoord(X2), MilsToCoord(Y2)));
    W.Color := COL_CYAN; Doc.RegisterSchObjectInContainer(W);
End;

Procedure AddRNetLabel(Doc, X, Y, S, Orient);
Var L : ISch_NetLabel;
Begin
    If S = '' Then Exit;
    L := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S; L.Color := COL_CYAN; L.Orientation := Orient;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddNetStub(Doc, X, Y, NetName, Direction);
Var EndX, O : Integer;
Begin
    If NetName = '' Then Exit;
    EndX := X + (Direction * 180);
    AddRWire(Doc, X, Y, EndX, Y);
    If Direction < 0 Then O := eRotate180 Else O := eRotate0;
    AddRNetLabel(Doc, EndX, Y, NetName, O);
End;

Procedure AddRParam(C, N, V);
Var P : ISch_Parameter;
Begin
    P := SchServer.SchObjectFactory(eParameter, eCreate_GlobalCopy);
    If P = Nil Then Exit;
    P.Name := N; P.Text := V; P.OwnerPartId := 1; P.OwnerPartDisplayMode := 0;
    C.AddSchObject(P);
End;

Procedure AddRFootprint(C, FootprintName);
Var I : ISch_Implementation;
Begin
    If FootprintName = '' Then Exit;
    I := SchServer.SchObjectFactory(eImplementation, eCreate_GlobalCopy);
    If I = Nil Then Exit;
    I.ModelType := 'PCBLIB'; I.ModelName := FootprintName; C.AddSchObject(I);
End;

Procedure AddRPin(C, X, Y, PinNo, Orient);
Var P : ISch_Pin;
Begin
    P := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    If P = Nil Then Exit;
    P.Location := Point(MilsToCoord(X), MilsToCoord(Y)); P.Orientation := Orient;
    P.Designator := PinNo; P.Name := ''; P.Color := COL_WHITE;
    P.OwnerPartId := 1; P.OwnerPartDisplayMode := 0; C.AddSchObject(P);
End;

Procedure FinishRComponent(C, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName);
Begin
    C.Designator.Text := RefDes; C.Comment.Text := ValueText;
    C.Designator.Color := COL_WHITE; C.Comment.Color := COL_WHITE;
    C.LibReference := ValueText; C.ComponentDescription := Desc;
    AddRParam(C, 'Manufacturer', Manufacturer);
    AddRParam(C, 'Manufacturer Part Number', MPN);
    AddRParam(C, 'Description', Desc);
    AddRParam(C, 'Package', FootprintName);
    AddRParam(C, 'Populate', 'Yes'); AddRFootprint(C, FootprintName);
End;

Procedure AddRBody(C, X, Y, HalfW, HalfH, AColor);
Var R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - HalfW), MilsToCoord(Y - HalfH));
    R.Corner := Point(MilsToCoord(X + HalfW), MilsToCoord(Y + HalfH));
    R.LineWidth := eMedium; R.Color := AColor; R.AreaColor := COL_BG; R.IsSolid := False;
    R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0; C.AddSchObject(R);
End;

Procedure AddR2(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName, NetL, NetR);
Var C : ISch_Component;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1; C.DisplayMode := 0; C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    FinishRComponent(C, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName);
    C.Designator.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y + 150));
    C.Comment.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y - 170));
    AddRBody(C, X, Y, 110, 65, COL_WHITE);
    AddRPin(C, X - 230, Y, '1', eRotate0); AddRPin(C, X + 230, Y, '2', eRotate180);
    Doc.RegisterSchObjectInContainer(C);
    AddNetStub(Doc, X - 230, Y, NetL, -1); AddNetStub(Doc, X + 230, Y, NetR, 1);
End;

Procedure AddR3(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName, Net1, Net2, Net3);
Var C : ISch_Component;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1; C.DisplayMode := 0; C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    FinishRComponent(C, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName);
    C.Designator.Location := Point(MilsToCoord(X - 100), MilsToCoord(Y + 210));
    C.Comment.Location := Point(MilsToCoord(X - 100), MilsToCoord(Y - 230));
    AddRBody(C, X, Y, 130, 130, COL_WHITE);
    AddRPin(C, X - 250, Y + 80, '1', eRotate0); AddRPin(C, X - 250, Y - 80, '2', eRotate0);
    AddRPin(C, X + 250, Y, '3', eRotate180); Doc.RegisterSchObjectInContainer(C);
    AddNetStub(Doc, X - 250, Y + 80, Net1, -1); AddNetStub(Doc, X - 250, Y - 80, Net2, -1);
    AddNetStub(Doc, X + 250, Y, Net3, 1);
End;

Procedure AddR4(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName, Net1, Net2, Net3, Net4);
Var C : ISch_Component;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1; C.DisplayMode := 0; C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    FinishRComponent(C, RefDes, ValueText, Manufacturer, MPN, Desc, FootprintName);
    C.Designator.Location := Point(MilsToCoord(X - 100), MilsToCoord(Y + 240));
    C.Comment.Location := Point(MilsToCoord(X - 100), MilsToCoord(Y - 260));
    AddRBody(C, X, Y, 140, 150, COL_AMBER);
    AddRPin(C, X - 260, Y + 90, '1', eRotate0); AddRPin(C, X - 260, Y - 90, '2', eRotate0);
    AddRPin(C, X + 260, Y + 90, '3', eRotate180); AddRPin(C, X + 260, Y - 90, '4', eRotate180);
    Doc.RegisterSchObjectInContainer(C);
    AddNetStub(Doc, X - 260, Y + 90, Net1, -1); AddNetStub(Doc, X - 260, Y - 90, Net2, -1);
    AddNetStub(Doc, X + 260, Y + 90, Net3, 1); AddNetStub(Doc, X + 260, Y - 90, Net4, 1);
End;

Procedure AddROpto(Doc, X, Y, RefDes, A, K, Collector, Emitter);
Begin
    AddR4(Doc, X, Y, RefDes, 'LTV-817S', 'Lite-On', 'LTV-817S-TA1',
          'Phototransistor optocoupler', 'LTV817S_SMD4', A, K, Collector, Emitter);
End;

Procedure AddRESP32(Doc, X, Y);
Var C : ISch_Component;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1; C.DisplayMode := 0; C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    FinishRComponent(C, 'A1', 'ESP32 DevKit 30-pin', 'Espressif-compatible',
                     'ESP32-DevKitC / verified 30-pin', 'Socketed ESP32 controller', 'ESP32_DEVKIT_30PIN_SOCKET');
    C.Designator.Location := Point(MilsToCoord(X - 180), MilsToCoord(Y + 610));
    C.Comment.Location := Point(MilsToCoord(X - 180), MilsToCoord(Y - 630));
    AddRBody(C, X, Y, 220, 530, COL_CYAN);
    AddRPin(C, X - 340, Y + 400, '1', eRotate0); AddRPin(C, X - 340, Y + 240, '2', eRotate0);
    AddRPin(C, X - 340, Y + 80, '3', eRotate0); AddRPin(C, X - 340, Y - 80, '4', eRotate0);
    AddRPin(C, X - 340, Y - 240, '5', eRotate0); AddRPin(C, X - 340, Y - 400, '6', eRotate0);
    AddRPin(C, X + 340, Y + 400, '7', eRotate180); AddRPin(C, X + 340, Y + 240, '8', eRotate180);
    AddRPin(C, X + 340, Y + 80, '9', eRotate180); AddRPin(C, X + 340, Y - 80, '10', eRotate180);
    AddRPin(C, X + 340, Y - 240, '11', eRotate180); Doc.RegisterSchObjectInContainer(C);
    AddNetStub(Doc, X - 340, Y + 400, '5V_LOGIC', -1); AddNetStub(Doc, X - 340, Y + 240, '3V3', -1);
    AddNetStub(Doc, X - 340, Y + 80, 'GND', -1); AddNetStub(Doc, X - 340, Y - 80, 'BEAM1_GPIO32', -1);
    AddNetStub(Doc, X - 340, Y - 240, 'BEAM2_GPIO33', -1); AddNetStub(Doc, X - 340, Y - 400, 'BEAM3_GPIO34', -1);
    AddNetStub(Doc, X + 340, Y + 400, 'LED_GREEN_GPIO25', 1); AddNetStub(Doc, X + 340, Y + 240, 'LED_RED_GPIO26', 1);
    AddNetStub(Doc, X + 340, Y + 80, 'LED_AMBER_GPIO27', 1); AddNetStub(Doc, X + 340, Y - 80, 'BUZZER_GPIO14', 1);
    AddNetStub(Doc, X + 340, Y - 240, 'BUTTON_GPIO13', 1);
End;

Procedure PrepareReadable(Doc, TitleText, SubtitleText);
Begin
    ClearReadableSheet(Doc); AddRRect(Doc, 100, 100, 7800, 7900, COL_BG, COL_BG, True);
    AddRText(Doc, 300, 7600, TitleText, COL_CYAN); AddRText(Doc, 300, 7380, SubtitleText, COL_WHITE);
End;

Procedure SaveReadable(ServerDoc, APath, SuccessText);
Var Doc : ISch_Document;
Begin
    Doc := SchServer.GetCurrentSchDocument; Doc.GraphicallyInvalidate; ServerDoc.Modified := True;
    If ServerDoc.DoSafeChangeFileNameAndSave(APath, 'SCH Binary 5.0') Then RLog(SuccessText)
    Else RLog('ERROR saving ' + APath);
End;

Procedure BuildMountingOverview;
Var SD : IServerDocument; D : ISch_Document;
Begin
    RLog('START overview'); SD := OpenOrCreateSheet(OVERVIEWPATH); If SD = Nil Then Exit;
    D := SchServer.GetCurrentSchDocument; SchServer.ProcessControl.PreProcess(D, 'Build mounting overview');
    Try
        PrepareReadable(D, '00 - GARAGE MOUNTING OVERVIEW', 'Three retroreflective beams at 100 mm centres - mounting guide, not to scale');
        AddRRect(D, 650, 1250, 2350, 6750, COL_CYAN, COL_PANEL, True);
        AddRRect(D, 5550, 1250, 6750, 6750, COL_AMBER, COL_PANEL, True);
        AddRText(D, 820, 6500, 'CONTROLLER + SENSOR CARRIER', COL_CYAN);
        AddRText(D, 5700, 6500, 'PASSIVE REFLECTOR CARRIER', COL_AMBER);
        AddRText(D, 920, 6200, '50 x 240 mm PCB / wall A', COL_WHITE);
        AddRText(D, 5700, 6200, '30 x 240 mm / wall B', COL_WHITE);
        AddRRect(D, 1200, 2100, 1750, 2450, COL_CYAN, COL_BG, False);
        AddRRect(D, 1200, 3700, 1750, 4050, COL_CYAN, COL_BG, False);
        AddRRect(D, 1200, 5300, 1750, 5650, COL_CYAN, COL_BG, False);
        AddRRect(D, 5800, 2100, 6350, 2450, COL_AMBER, COL_BG, False);
        AddRRect(D, 5800, 3700, 6350, 4050, COL_AMBER, COL_BG, False);
        AddRRect(D, 5800, 5300, 6350, 5650, COL_AMBER, COL_BG, False);
        AddRLine(D, 1750, 2275, 5800, 2275, COL_RED, eMedium);
        AddRLine(D, 1750, 3875, 5800, 3875, COL_RED, eMedium);
        AddRLine(D, 1750, 5475, 5800, 5475, COL_RED, eMedium);
        AddRText(D, 2750, 2350, 'BEAM 1 - datum 0 mm', COL_WHITE);
        AddRText(D, 2750, 3950, 'BEAM 2 - +100 mm', COL_WHITE);
        AddRText(D, 2750, 5550, 'BEAM 3 - +200 mm', COL_WHITE);
        AddRLine(D, 7000, 2275, 7000, 5475, COL_WHITE, eSmall);
        AddRLine(D, 6900, 2275, 7100, 2275, COL_WHITE, eSmall);
        AddRLine(D, 6900, 3875, 7100, 3875, COL_WHITE, eSmall);
        AddRLine(D, 6900, 5475, 7100, 5475, COL_WHITE, eSmall);
        AddRText(D, 7120, 3000, '100 mm', COL_WHITE); AddRText(D, 7120, 4600, '100 mm', COL_WHITE);
        AddRText(D, 7000, 5750, '200 mm total optical span', COL_CYAN);
        AddRRect(D, 900, 1450, 1250, 1750, COL_WHITE, COL_BG, False);
        AddRText(D, 1300, 1500, 'USB-C 5 V input at lower edge', COL_WHITE);
        AddRText(D, 2600, 6750, 'GARAGE OPENING / MEASURE SPAN ON SITE', COL_CYAN);
        AddRText(D, 2600, 1200, 'Align all three sensor axes with matching reflector centres before optical validation.', COL_WHITE);
        AddRText(D, 2600, 950, 'Keep the carrier rigid; use slots or shims for yaw/pitch adjustment. Advisory system only.', COL_AMBER);
        AddRText(D, 800, 1850, 'SENSOR 1', COL_WHITE); AddRText(D, 800, 3450, 'SENSOR 2', COL_WHITE);
        AddRText(D, 800, 5050, 'SENSOR 3', COL_WHITE);
        AddRText(D, 6350, 1850, 'REF 1', COL_WHITE); AddRText(D, 6350, 3450, 'REF 2', COL_WHITE);
        AddRText(D, 6350, 5050, 'REF 3', COL_WHITE);
    Finally SchServer.ProcessControl.PostProcess(D, 'Build mounting overview'); End;
    SaveReadable(SD, OVERVIEWPATH, 'OK overview');
End;

Procedure BuildPowerControlSheet;
Var SD : IServerDocument; D : ISch_Document;
Begin
    RLog('START power'); SD := OpenOrCreateSheet(POWERPATH); If SD = Nil Then Exit;
    D := SchServer.GetCurrentSchDocument; SchServer.ProcessControl.PreProcess(D, 'Build power control');
    Try
        PrepareReadable(D, '01 - USB POWER, 12 V BOOST, AND ESP32 CONTROL', 'Power-only USB-C input; all long names are connected by native Altium net labels');
        AddRText(D, 350, 6800, 'USB-C INPUT + CC', COL_AMBER);
        AddR4(D, 1050, 6250, 'J1', 'USB-C POWER', 'GCT', 'USB4125-GF-A-0190', '6-contact charge-only USB-C receptacle', 'USB4125_6PIN', 'CC1', 'CC2', 'VBUS', 'GND');
        AddR2(D, 600, 5450, 'R1', '5.1k', 'Yageo', 'RC0805FR-075K1L', 'CC1 pull-down', 'R0805', 'CC1', 'GND');
        AddR2(D, 1500, 5450, 'R2', '5.1k', 'Yageo', 'RC0805FR-075K1L', 'CC2 pull-down', 'R0805', 'CC2', 'GND');
        AddRText(D, 2450, 6800, 'INPUT PROTECTION', COL_AMBER);
        AddR2(D, 2800, 6250, 'F1', '1.5A PTC', 'Bourns', 'MF-MSMF150-2', 'Resettable input fuse', 'F1812', 'VBUS', 'VBUS_FUSED');
        AddR2(D, 2800, 5450, 'D1', 'SMAJ5.0A', 'Littelfuse', 'SMAJ5.0A', 'VBUS TVS', 'SMA', 'VBUS_FUSED', 'GND');
        AddR3(D, 4050, 6250, 'Q1', 'DMP2035U', 'Diodes Inc', 'DMP2035U', 'Reverse-current protection MOSFET', 'SOT23', 'VBUS_FUSED', 'GND', '5V_LOGIC');
        AddR2(D, 4050, 5450, 'C1', '470uF', 'Panasonic', 'EEE-FK1A471P', '5 V bulk capacitor', 'CAP_SMD_10X10', '5V_LOGIC', 'GND');
        AddRText(D, 5000, 6800, 'SENSOR SUPPLY', COL_AMBER);
        AddR3(D, 5350, 6250, 'A2', 'U3V16F12', 'Pololu', '4945', '5-to-12 V boost module', 'POLOLU_U3V16F12', '5V_LOGIC', 'GND', '12V_SENSOR');
        AddR2(D, 5350, 5450, 'C5', '100uF', 'Panasonic', 'EEE-FK1E101P', '12 V rail bulk capacitor', 'CAP_SMD_8X10', '12V_SENSOR', 'GND');
        AddRText(D, 600, 4450, 'CONTROLLER / CROSS-SHEET SIGNALS', COL_CYAN);
        AddRESP32(D, 3900, 3150);
        AddRText(D, 600, 850, 'Use a certified 5 V >=2 A USB charger. No garage-door actuation output is provided.', COL_AMBER);
    Finally SchServer.ProcessControl.PostProcess(D, 'Build power control'); End;
    SaveReadable(SD, POWERPATH, 'OK power');
End;

Procedure AddReadableBeamChannel(D, Y, N, GPIOName);
Var P, J, U, Di, Raw, Sig, LedA : String;
Begin
    P := 'B' + IntToStr(N); J := 'J' + IntToStr(N + 1); U := 'U' + IntToStr(N + 1);
    Di := 'D' + IntToStr(N + 1); Raw := P + '_RAW'; Sig := P + '_SIG'; LedA := P + '_LED_A';
    AddRText(D, 300, Y + 450, 'BEAM ' + IntToStr(N) + ' INPUT', COL_AMBER);
    AddR3(D, 850, Y, J, 'SENSOR', 'Phoenix Contact', '1729131', '12 V / GND / NPN signal terminal', 'TERM_3_508', '12V_SENSOR', 'GND', Sig);
    AddR2(D, 2050, Y + 120, 'R' + IntToStr(2 + (N * 3)), '2.2k', 'Yageo', 'RC0805FR-072K2L', 'Optocoupler LED resistor', 'R0805', '12V_SENSOR', LedA);
    AddROpto(D, 3350, Y, U, LedA, Sig, Raw, 'GND');
    AddR2(D, 3350, Y - 520, Di, '1N4148W', 'Nexperia', '1N4148W', 'Reverse LED clamp', 'SOD123', Sig, LedA);
    AddR2(D, 4750, Y + 260, 'R' + IntToStr(3 + (N * 3)), '10k', 'Yageo', 'RC0805FR-0710KL', 'GPIO pull-up', 'R0805', '3V3', Raw);
    AddR2(D, 6100, Y + 50, 'R' + IntToStr(4 + (N * 3)), '1k', 'Yageo', 'RC0805FR-071KL', 'GPIO series resistor', 'R0805', Raw, GPIOName);
    AddR2(D, 6100, Y - 480, 'C' + IntToStr(N + 1), '100nF', 'Murata', 'GRM21BR71H104KA01L', 'GPIO filter', 'C0805', GPIOName, 'GND');
End;

Procedure BuildBeamInputsSheet;
Var SD : IServerDocument; D : ISch_Document;
Begin
    RLog('START beams'); SD := OpenOrCreateSheet(BEAMPATH); If SD = Nil Then Exit;
    D := SchServer.GetCurrentSchDocument; SchServer.ProcessControl.PreProcess(D, 'Build beam inputs');
    Try
        PrepareReadable(D, '02 - THREE FAIL-SAFE BEAM INPUT CHANNELS', 'NPN Light-ON sensors: current must flow to earn CLEAR; open/unpowered input is unsafe');
        AddReadableBeamChannel(D, 6100, 1, 'BEAM1_GPIO32');
        AddReadableBeamChannel(D, 3900, 2, 'BEAM2_GPIO33');
        AddReadableBeamChannel(D, 1700, 3, 'BEAM3_GPIO34');
        AddRText(D, 300, 500, 'Firmware requires all three inputs continuously clear for 500 ms. Any blocked/open/dead channel is unsafe.', COL_AMBER);
    Finally SchServer.ProcessControl.PostProcess(D, 'Build beam inputs'); End;
    SaveReadable(SD, BEAMPATH, 'OK beams');
End;

Procedure BuildUIOutputsSheet;
Var SD : IServerDocument; D : ISch_Document;
Begin
    RLog('START UI'); SD := OpenOrCreateSheet(UIPATH); If SD = Nil Then Exit;
    D := SchServer.GetCurrentSchDocument; SchServer.ProcessControl.PreProcess(D, 'Build UI outputs');
    Try
        PrepareReadable(D, '03 - STATUS INDICATORS, BUZZER, AND TEST BUTTON', 'Green=CLEAR only; red=BLOCKED; amber=BOOT/FAULT/UNKNOWN');
        AddRText(D, 350, 6750, 'EXTERNAL STATUS CONNECTOR', COL_CYAN);
        AddR2(D, 1200, 6150, 'R14', '330R', 'Yageo', 'RC0805FR-07330RL', 'Green LED current limit', 'R0805', 'LED_GREEN_GPIO25', 'LED_GREEN_OUT');
        AddR2(D, 1200, 5400, 'R15', '330R', 'Yageo', 'RC0805FR-07330RL', 'Red LED current limit', 'R0805', 'LED_RED_GPIO26', 'LED_RED_OUT');
        AddR2(D, 1200, 4650, 'R16', '330R', 'Yageo', 'RC0805FR-07330RL', 'Amber LED current limit', 'R0805', 'LED_AMBER_GPIO27', 'LED_AMBER_OUT');
        AddR4(D, 3200, 5400, 'J5', 'STATUS', 'Phoenix Contact', '1729144', 'Green/red/amber/GND output', 'TERM_4_508', 'LED_GREEN_OUT', 'LED_RED_OUT', 'LED_AMBER_OUT', 'GND');
        AddRText(D, 4500, 6750, 'AUDIBLE ALERT', COL_CYAN);
        AddR2(D, 4850, 6100, 'R17', '1k', 'Yageo', 'RC0805FR-071KL', 'Buzzer base resistor', 'R0805', 'BUZZER_GPIO14', 'BUZZER_BASE');
        AddR3(D, 6100, 6100, 'Q2', 'MMBT2222A', 'Diodes Inc', 'MMBT2222A', 'Buzzer low-side driver', 'SOT23', 'BUZZER_BASE', 'GND', 'BUZZER_LOW');
        AddR2(D, 6100, 5200, 'BZ1', 'CPT-9019S', 'CUI Devices', 'CPT-9019S-SMT-TR', '3 V magnetic transducer', 'BUZZER_9X9', '3V3', 'BUZZER_LOW');
        AddR2(D, 6100, 4450, 'D5', '1N4148W', 'Nexperia', '1N4148W', 'Buzzer flyback clamp', 'SOD123', 'BUZZER_LOW', '3V3');
        AddRText(D, 350, 3350, 'ALIGNMENT / TEST INPUT', COL_CYAN);
        AddR2(D, 1500, 2750, 'SW1', 'ALIGN/TEST', 'Omron', 'B3FS-1000P', 'Alignment and test button', 'SW_SMD_6X6', 'BUTTON_GPIO13', 'GND');
        AddRText(D, 350, 800, 'This board is advisory only. It does not connect to or command the garage-door motor.', COL_AMBER);
    Finally SchServer.ProcessControl.PostProcess(D, 'Build UI outputs'); End;
    SaveReadable(SD, UIPATH, 'OK UI');
End;

Procedure CountReadableObjects(APath, SheetName, L);
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator; O : ISch_GraphicalObject;
    Components, Wires, NetLabels : Integer;
Begin
    Components := 0; Wires := 0; NetLabels := 0;
    SD := Client.OpenDocument('SCH', APath);
    If SD = Nil Then Begin L.Add(SheetName + '|ERROR OPEN'); Exit; End;
    Client.ShowDocument(SD); SD.Focus; D := SchServer.GetCurrentSchDocument;
    It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    O := It.FirstSchObject; While O <> Nil Do Begin Inc(Components); O := It.NextSchObject; End;
    D.SchIterator_Destroy(It);
    It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eWire));
    O := It.FirstSchObject; While O <> Nil Do Begin Inc(Wires); O := It.NextSchObject; End;
    D.SchIterator_Destroy(It);
    It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetLabel));
    O := It.FirstSchObject; While O <> Nil Do Begin Inc(NetLabels); O := It.NextSchObject; End;
    D.SchIterator_Destroy(It);
    L.Add(SheetName + '|COMPONENTS=' + IntToStr(Components) + '|WIRES=' + IntToStr(Wires) + '|NETLABELS=' + IntToStr(NetLabels));
End;

Procedure AuditReadableProject;
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try
        CountReadableObjects(OVERVIEWPATH, '00_MOUNTING_OVERVIEW', L);
        CountReadableObjects(POWERPATH, '01_POWER_CONTROL', L);
        CountReadableObjects(BEAMPATH, '02_BEAM_INPUTS', L);
        CountReadableObjects(UIPATH, '03_UI_OUTPUTS', L);
        L.Add('EXPECTED_TOTAL_COMPONENTS=40');
        L.SaveToFile(ALTIUMROOT + 'ReadableSchematicAudit.txt');
        RLog('OK readable audit');
    Finally L.Free; End;
End;

Procedure OpenMountingOverview;
Var SD : IServerDocument;
Begin
    SD := Client.OpenDocument('SCH', OVERVIEWPATH);
    If SD = Nil Then Begin RLog('ERROR opening overview'); Exit; End;
    Client.ShowDocument(SD); SD.Focus; RLog('OK overview focused');
End;

Procedure InspectTemplateSheet;
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator;
    O : ISch_GraphicalObject; Lbl : ISch_Label; Par : ISch_Parameter;
    Tf : ISch_TextFrame; Count : Integer; R : TStringList;
Begin
    R := TStringList.Create;
    Try
        SD := Client.OpenDocument('SCH', TEMPLATESCH);
        If SD = Nil Then Begin R.Add('ERROR OPEN TEMPLATE'); Exit; End;
        Client.ShowDocument(SD); SD.Focus; D := SchServer.GetCurrentSchDocument;
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
        Count := 0; O := It.FirstSchObject; While O <> Nil Do Begin Inc(Count); O := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('COMPONENTS=' + IntToStr(Count));
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eWire));
        Count := 0; O := It.FirstSchObject; While O <> Nil Do Begin Inc(Count); O := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('WIRES=' + IntToStr(Count));
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eImage));
        Count := 0; O := It.FirstSchObject; While O <> Nil Do Begin Inc(Count); O := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('IMAGES=' + IntToStr(Count));
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eLabel));
        Count := 0; Lbl := It.FirstSchObject;
        While Lbl <> Nil Do Begin Inc(Count); R.Add('LABEL|' + Lbl.Text); Lbl := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('LABELS=' + IntToStr(Count));
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eTextFrame));
        Count := 0; Tf := It.FirstSchObject;
        While Tf <> Nil Do Begin Inc(Count); R.Add('TEXTFRAME|' + Tf.Text); Tf := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('TEXTFRAMES=' + IntToStr(Count));
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eParameter));
        Count := 0; Par := It.FirstSchObject;
        While Par <> Nil Do Begin Inc(Count); R.Add('PARAM|' + Par.Name + '=' + Par.Text); Par := It.NextSchObject; End;
        D.SchIterator_Destroy(It); R.Add('PARAMETERS=' + IntToStr(Count));
        R.SaveToFile(ALTIUMROOT + 'TemplateSchematicInspection.txt');
        RLog('OK template inspection');
    Finally R.Free; End;
End;

Procedure InspectTemplateComponents;
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator;
    C : ISch_Component; R : TStringList; Count : Integer;
Begin
    R := TStringList.Create;
    Try
        SD := Client.OpenDocument('SCH', TEMPLATESCH);
        If SD = Nil Then Begin R.Add('ERROR'); Exit; End;
        Client.ShowDocument(SD); SD.Focus; D := SchServer.GetCurrentSchDocument;
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
        Count := 0; C := It.FirstSchObject;
        While C <> Nil Do
        Begin
            Inc(Count);
            R.Add(C.Designator.Text + '|' + C.Comment.Text + '|' + C.LibReference + '|' + C.ComponentDescription);
            C := It.NextSchObject;
        End;
        D.SchIterator_Destroy(It); R.Insert(0, 'COUNT=' + IntToStr(Count));
        R.SaveToFile(ALTIUMROOT + 'TemplateComponentInspection.txt');
        RLog('OK template component inspection');
    Finally R.Free; End;
End;

Procedure InspectTemplateSeedPins;
Var SD : IServerDocument; D : ISch_Document; It, Pit : ISch_Iterator;
    C : ISch_Component; P : ISch_Pin; R : TStringList; Wanted : Boolean;
Begin
    R := TStringList.Create;
    Try
        SD := Client.OpenDocument('SCH', TEMPLATESCH);
        If SD = Nil Then Begin R.Add('ERROR'); Exit; End;
        Client.ShowDocument(SD); SD.Focus; D := SchServer.GetCurrentSchDocument;
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
        C := It.FirstSchObject;
        While C <> Nil Do
        Begin
            Wanted := (C.Designator.Text = 'R4') Or (C.Designator.Text = 'C6') Or
                      (C.Designator.Text = 'D1') Or (C.Designator.Text = 'DZ1') Or
                      (C.Designator.Text = 'U4') Or (C.Designator.Text = 'CN4') Or
                      (C.Designator.Text = 'LD1');
            If Wanted Then
            Begin
                R.Add('COMP|' + C.Designator.Text + '|X=' + IntToStr(C.Location.X) + '|Y=' + IntToStr(C.Location.Y));
                Pit := C.SchIterator_Create; Pit.AddFilter_ObjectSet(MkSet(ePin));
                P := Pit.FirstSchObject;
                While P <> Nil Do
                Begin
                    R.Add('PIN|' + C.Designator.Text + '|' + P.Designator + '|' + P.Name +
                          '|X=' + IntToStr(P.Location.X) + '|Y=' + IntToStr(P.Location.Y) +
                          '|OR=' + IntToStr(P.Orientation));
                    P := Pit.NextSchObject;
                End;
                C.SchIterator_Destroy(Pit);
            End;
            C := It.NextSchObject;
        End;
        D.SchIterator_Destroy(It);
        R.SaveToFile(ALTIUMROOT + 'TemplateSeedPinInspection.txt');
        RLog('OK template seed pin inspection');
    Finally R.Free; End;
End;

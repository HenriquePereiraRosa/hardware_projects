{ Garage Beam Safety D3 native Altium document builder. }

Const
    ROOTPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';
    SCHPATH  = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.SchDoc';
    PCBPATH  = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.PcbDoc';
    REFPCBPATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety_ReflectorCarrier.PcbDoc';
    BOMPATH  = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.BomDoc';
    LOGPATH  = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\NativeBuild.log';
    DARK_SHEET = $00202020;
    LIGHT_INK  = $00F2F2F2;
    CYAN_INK   = $00FFD080;
    AMBER_INK  = $0040C0FF;

Procedure WriteLog(S);
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try
        L.Add(S);
        L.SaveToFile(LOGPATH);
    Finally
        L.Free;
    End;
End;

Procedure ClearSheet(Doc);
Var It : ISch_Iterator; Obj, OldObj : ISch_GraphicalObject;
Begin
    It := Doc.SchIterator_Create;
    If It = Nil Then Exit;
    It.SetState_FilterAll;
    Try
        Obj := It.FirstSchObject;
        While Obj <> Nil Do
        Begin
            OldObj := Obj;
            Obj := It.NextSchObject;
            Doc.RemoveSchObject(OldObj);
        End;
    Finally
        Doc.SchIterator_Destroy(It);
    End;
End;

Procedure AddSheetLabel(Doc, X, Y, S, PtSize, Bold, AColor);
Var L : ISch_Label;
Begin
    WriteLog('LABEL factory');
    L := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    WriteLog('LABEL location');
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    WriteLog('LABEL text');
    L.Text := S;
    WriteLog('LABEL color');
    L.Color := AColor;
    WriteLog('LABEL orientation');
    L.Orientation := eRotate0;
    WriteLog('LABEL register');
    Doc.RegisterSchObjectInContainer(L);
    WriteLog('LABEL done');
End;

Procedure AddNetLabel(Doc, X, Y, S);
Var L : ISch_Label;
Begin
    L := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S;
    L.Color := CYAN_INK;
    L.Orientation := eRotate0;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddDarkBackground(Doc);
Var R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    If R = Nil Then Exit;
    R.Location := Point(MilsToCoord(100), MilsToCoord(100));
    R.Corner := Point(MilsToCoord(7800), MilsToCoord(7900));
    R.LineWidth := eSmall;
    R.Color := DARK_SHEET;
    R.AreaColor := DARK_SHEET;
    R.IsSolid := True;
    Doc.RegisterSchObjectInContainer(R);
End;

Procedure AddParameter(Comp, AName, AValue);
Var P : ISch_Parameter;
Begin
    P := SchServer.SchObjectFactory(eParameter, eCreate_GlobalCopy);
    If P = Nil Then Exit;
    P.Name := AName;
    P.Text := AValue;
    P.OwnerPartId := 1;
    P.OwnerPartDisplayMode := 0;
    Comp.AddSchObject(P);
End;

Procedure AddFootprint(Comp, FootprintName);
Var Impl : ISch_Implementation;
Begin
    If FootprintName = '' Then Exit;
    Impl := SchServer.SchObjectFactory(eImplementation, eCreate_GlobalCopy);
    If Impl = Nil Then Exit;
    Impl.ModelType := 'PCBLIB';
    Impl.ModelName := FootprintName;
    Comp.AddSchObject(Impl);
End;

Procedure AddPin(Comp, X, Y, Des, PinName, Orient);
Var P : ISch_Pin;
Begin
    WriteLog('PIN ' + Des + ' factory');
    P := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    If P = Nil Then Exit;
    WriteLog('PIN ' + Des + ' location');
    P.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    WriteLog('PIN ' + Des + ' orientation');
    P.Orientation := Orient;
    WriteLog('PIN ' + Des + ' designator');
    P.Designator := Des;
    WriteLog('PIN ' + Des + ' name');
    P.Name := PinName;
    WriteLog('PIN ' + Des + ' color');
    P.Color := LIGHT_INK;
    WriteLog('PIN ' + Des + ' ownership');
    P.OwnerPartId := 1;
    P.OwnerPartDisplayMode := 0;
    WriteLog('PIN ' + Des + ' add');
    Comp.AddSchObject(P);
    WriteLog('PIN ' + Des + ' done');
End;

Function AddTwoPinPart(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN,
                       Description, FootprintName, LeftNet, RightNet) : ISch_Component;
Var C : ISch_Component; R : ISch_Rectangle;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1;
    C.DisplayMode := 0;
    C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.LibReference := ValueText;
    C.ComponentDescription := Description;
    C.Designator.Text := RefDes;
    C.Comment.Text := ValueText;
    C.Designator.Color := LIGHT_INK;
    C.Comment.Color := LIGHT_INK;
    C.Designator.Location := Point(MilsToCoord(X - 70), MilsToCoord(Y + 105));
    C.Comment.Location := Point(MilsToCoord(X - 70), MilsToCoord(Y - 125));

    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - 70), MilsToCoord(Y - 45));
    R.Corner := Point(MilsToCoord(X + 70), MilsToCoord(Y + 45));
    R.LineWidth := eSmall;
    R.Color := LIGHT_INK;
    R.AreaColor := DARK_SHEET;
    R.IsSolid := False;
    R.OwnerPartId := 1;
    R.OwnerPartDisplayMode := 0;
    C.AddSchObject(R);
    AddPin(C, X - 170, Y, '1', LeftNet, eRotate0);
    AddPin(C, X + 170, Y, '2', RightNet, eRotate180);
    AddParameter(C, 'Manufacturer', Manufacturer);
    AddParameter(C, 'Manufacturer Part Number', MPN);
    AddParameter(C, 'Description', Description);
    AddParameter(C, 'Package', FootprintName);
    AddParameter(C, 'Populate', 'Yes');
    AddFootprint(C, FootprintName);
    Doc.RegisterSchObjectInContainer(C);
    AddNetLabel(Doc, X - 170, Y, LeftNet);
    AddNetLabel(Doc, X + 170, Y, RightNet);
    Result := C;
End;

Function AddThreePinPart(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN,
                         Description, FootprintName, Net1, Net2, Net3) : ISch_Component;
Var C : ISch_Component; R : ISch_Rectangle;
Begin
    WriteLog('3PIN ' + RefDes + ' factory');
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    WriteLog('3PIN ' + RefDes + ' identity');
    C.CurrentPartID := 1;
    C.DisplayMode := 0;
    C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.LibReference := ValueText;
    C.ComponentDescription := Description;
    WriteLog('3PIN ' + RefDes + ' designator');
    C.Designator.Text := RefDes;
    C.Comment.Text := ValueText;
    C.Designator.Color := LIGHT_INK;
    C.Comment.Color := LIGHT_INK;
    C.Designator.Location := Point(MilsToCoord(X - 80), MilsToCoord(Y + 155));
    C.Comment.Location := Point(MilsToCoord(X - 80), MilsToCoord(Y - 175));
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y - 95));
    R.Corner := Point(MilsToCoord(X + 90), MilsToCoord(Y + 95));
    R.LineWidth := eSmall; R.Color := LIGHT_INK; R.AreaColor := DARK_SHEET;
    R.IsSolid := False; R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0;
    C.AddSchObject(R);
    WriteLog('3PIN ' + RefDes + ' pins');
    AddPin(C, X - 190, Y + 60, '1', Net1, eRotate0);
    AddPin(C, X - 190, Y - 60, '2', Net2, eRotate0);
    AddPin(C, X + 190, Y, '3', Net3, eRotate180);
    AddParameter(C, 'Manufacturer', Manufacturer);
    AddParameter(C, 'Manufacturer Part Number', MPN);
    AddParameter(C, 'Description', Description);
    AddParameter(C, 'Package', FootprintName);
    AddParameter(C, 'Populate', 'Yes');
    AddFootprint(C, FootprintName);
    WriteLog('3PIN ' + RefDes + ' register');
    Doc.RegisterSchObjectInContainer(C);
    AddNetLabel(Doc, X - 190, Y + 60, Net1);
    AddNetLabel(Doc, X - 190, Y - 60, Net2);
    AddNetLabel(Doc, X + 190, Y, Net3);
    WriteLog('3PIN ' + RefDes + ' done');
    Result := C;
End;

Function AddFourPinPart(Doc, X, Y, RefDes, ValueText, Manufacturer, MPN,
                        Description, FootprintName, Net1, Net2, Net3, Net4) : ISch_Component;
Var C : ISch_Component; R : ISch_Rectangle;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    If C = Nil Then Exit;
    C.CurrentPartID := 1; C.DisplayMode := 0;
    C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.LibReference := ValueText; C.ComponentDescription := Description;
    C.Designator.Text := RefDes; C.Comment.Text := ValueText;
    C.Designator.Color := LIGHT_INK; C.Comment.Color := LIGHT_INK;
    C.Designator.Location := Point(MilsToCoord(X - 80), MilsToCoord(Y + 185));
    C.Comment.Location := Point(MilsToCoord(X - 80), MilsToCoord(Y - 205));
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y - 125));
    R.Corner := Point(MilsToCoord(X + 90), MilsToCoord(Y + 125));
    R.LineWidth := eSmall; R.Color := LIGHT_INK; R.AreaColor := DARK_SHEET;
    R.IsSolid := False; R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0;
    C.AddSchObject(R);
    AddPin(C, X - 190, Y + 75, '1', Net1, eRotate0);
    AddPin(C, X - 190, Y - 75, '2', Net2, eRotate0);
    AddPin(C, X + 190, Y + 75, '3', Net3, eRotate180);
    AddPin(C, X + 190, Y - 75, '4', Net4, eRotate180);
    AddParameter(C, 'Manufacturer', Manufacturer);
    AddParameter(C, 'Manufacturer Part Number', MPN);
    AddParameter(C, 'Description', Description);
    AddParameter(C, 'Package', FootprintName);
    AddParameter(C, 'Populate', 'Yes');
    AddFootprint(C, FootprintName);
    Doc.RegisterSchObjectInContainer(C);
    AddNetLabel(Doc, X - 190, Y + 75, Net1);
    AddNetLabel(Doc, X - 190, Y - 75, Net2);
    AddNetLabel(Doc, X + 190, Y + 75, Net3);
    AddNetLabel(Doc, X + 190, Y - 75, Net4);
    Result := C;
End;

Function AddOptocoupler(Doc, X, Y, RefDes, InA, InK, CollectorNet, EmitterNet) : ISch_Component;
Var C : ISch_Component; R : ISch_Rectangle;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    C.CurrentPartID := 1; C.DisplayMode := 0;
    C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.LibReference := 'LTV-817S';
    C.ComponentDescription := 'Phototransistor optocoupler';
    C.Designator.Text := RefDes; C.Comment.Text := 'LTV-817S';
    C.Designator.Color := LIGHT_INK; C.Comment.Color := LIGHT_INK;
    C.Designator.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y + 160));
    C.Comment.Location := Point(MilsToCoord(X - 90), MilsToCoord(Y - 180));
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - 100), MilsToCoord(Y - 100));
    R.Corner := Point(MilsToCoord(X + 100), MilsToCoord(Y + 100));
    R.LineWidth := eSmall; R.Color := AMBER_INK; R.AreaColor := DARK_SHEET;
    R.IsSolid := False; R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0;
    C.AddSchObject(R);
    AddPin(C, X - 200, Y + 60, '1', InA, eRotate0);
    AddPin(C, X - 200, Y - 60, '2', InK, eRotate0);
    AddPin(C, X + 200, Y - 60, '3', EmitterNet, eRotate180);
    AddPin(C, X + 200, Y + 60, '4', CollectorNet, eRotate180);
    AddParameter(C, 'Manufacturer', 'Lite-On');
    AddParameter(C, 'Manufacturer Part Number', 'LTV-817S-TA1');
    AddParameter(C, 'Description', 'Phototransistor optocoupler SMD-4');
    AddParameter(C, 'Package', 'LTV817S_SMD4');
    AddParameter(C, 'Populate', 'Yes');
    AddFootprint(C, 'LTV817S_SMD4');
    Doc.RegisterSchObjectInContainer(C);
    AddNetLabel(Doc, X - 200, Y + 60, InA);
    AddNetLabel(Doc, X - 200, Y - 60, InK);
    AddNetLabel(Doc, X + 200, Y - 60, EmitterNet);
    AddNetLabel(Doc, X + 200, Y + 60, CollectorNet);
    Result := C;
End;

Procedure AddESP32(Doc, X, Y);
Var C : ISch_Component; R : ISch_Rectangle;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    C.CurrentPartID := 1; C.DisplayMode := 0;
    C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.LibReference := 'ESP32-DEVKIT-30PIN';
    C.ComponentDescription := 'Socketed ESP32-WROOM development board';
    C.Designator.Text := 'A1'; C.Comment.Text := 'ESP32 DevKit 30-pin';
    C.Designator.Color := LIGHT_INK; C.Comment.Color := LIGHT_INK;
    C.Designator.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y + 520));
    C.Comment.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y - 540));
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X - 180), MilsToCoord(Y - 450));
    R.Corner := Point(MilsToCoord(X + 180), MilsToCoord(Y + 450));
    R.LineWidth := eMedium; R.Color := CYAN_INK; R.AreaColor := DARK_SHEET;
    R.IsSolid := False; R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0;
    C.AddSchObject(R);
    AddPin(C, X - 280, Y + 360, '1', '5V_LOGIC', eRotate0);
    AddPin(C, X - 280, Y + 240, '2', '3V3', eRotate0);
    AddPin(C, X - 280, Y + 120, '3', 'GND', eRotate0);
    AddPin(C, X - 280, Y, '4', 'BEAM1_GPIO32', eRotate0);
    AddPin(C, X - 280, Y - 120, '5', 'BEAM2_GPIO33', eRotate0);
    AddPin(C, X - 280, Y - 240, '6', 'BEAM3_GPIO34', eRotate0);
    AddPin(C, X + 280, Y + 300, '7', 'LED_GREEN_GPIO25', eRotate180);
    AddPin(C, X + 280, Y + 180, '8', 'LED_RED_GPIO26', eRotate180);
    AddPin(C, X + 280, Y + 60, '9', 'LED_AMBER_GPIO27', eRotate180);
    AddPin(C, X + 280, Y - 60, '10', 'BUZZER_GPIO14', eRotate180);
    AddPin(C, X + 280, Y - 180, '11', 'BUTTON_GPIO13', eRotate180);
    AddParameter(C, 'Manufacturer', 'Espressif-compatible');
    AddParameter(C, 'Manufacturer Part Number', 'ESP32-DevKitC / verified 30-pin');
    AddParameter(C, 'Description', 'Socketed ESP32-WROOM development board');
    AddParameter(C, 'Package', 'ESP32_DEVKIT_30PIN_SOCKET');
    AddParameter(C, 'Populate', 'User supplied');
    AddFootprint(C, 'ESP32_DEVKIT_30PIN_SOCKET');
    Doc.RegisterSchObjectInContainer(C);
    AddNetLabel(Doc, X - 280, Y + 360, '5V_LOGIC');
    AddNetLabel(Doc, X - 280, Y + 240, '3V3');
    AddNetLabel(Doc, X - 280, Y + 120, 'GND');
    AddNetLabel(Doc, X - 280, Y, 'BEAM1_GPIO32');
    AddNetLabel(Doc, X - 280, Y - 120, 'BEAM2_GPIO33');
    AddNetLabel(Doc, X - 280, Y - 240, 'BEAM3_GPIO34');
    AddNetLabel(Doc, X + 280, Y + 300, 'LED_GREEN_GPIO25');
    AddNetLabel(Doc, X + 280, Y + 180, 'LED_RED_GPIO26');
    AddNetLabel(Doc, X + 280, Y + 60, 'LED_AMBER_GPIO27');
    AddNetLabel(Doc, X + 280, Y - 60, 'BUZZER_GPIO14');
    AddNetLabel(Doc, X + 280, Y - 180, 'BUTTON_GPIO13');
End;

Procedure AddSensorChannel(Doc, Y, N, GPIOName);
Var Prefix, JRef, URef, DRef, RawNet : String;
Begin
    Prefix := 'BEAM' + IntToStr(N);
    JRef := 'J' + IntToStr(N + 1);
    URef := 'U' + IntToStr(N + 1);
    DRef := 'D' + IntToStr(N + 1);
    RawNet := Prefix + '_RAW';
    AddThreePinPart(Doc, 700, Y, JRef, 'SENSOR TERMINAL', 'Phoenix Contact', '1729131',
                    '5.08mm terminal 12V/0V/SIG', 'TERM_3_508', '12V_SENSOR', 'GND', Prefix + '_SIG');
    AddTwoPinPart(Doc, 1500, Y + 60, 'R' + IntToStr(2 + (N * 3)), '2.2k', 'Yageo',
                  'RC0805FR-072K2L', 'Optocoupler input resistor', 'R0805', '12V_SENSOR', Prefix + '_LED_A');
    AddOptocoupler(Doc, 2350, Y, URef, Prefix + '_LED_A', Prefix + '_SIG', RawNet, 'GND');
    AddTwoPinPart(Doc, 2350, Y - 330, DRef, '1N4148W', 'Nexperia', '1N4148W',
                  'Reverse clamp across optocoupler input', 'SOD123', Prefix + '_SIG', Prefix + '_LED_A');
    AddTwoPinPart(Doc, 3250, Y + 220, 'R' + IntToStr(3 + (N * 3)), '10k', 'Yageo',
                  'RC0805FR-0710KL', 'GPIO pull-up', 'R0805', '3V3', RawNet);
    AddTwoPinPart(Doc, 4050, Y + 60, 'R' + IntToStr(4 + (N * 3)), '1k', 'Yageo',
                  'RC0805FR-071KL', 'GPIO series resistor', 'R0805', RawNet, GPIOName);
    AddTwoPinPart(Doc, 4050, Y - 260, 'C' + IntToStr(N + 1), '100nF', 'Murata',
                  'GRM21BR71H104KA01L', 'GPIO input filter', 'C0805', GPIOName, 'GND');
    AddSheetLabel(Doc, 450, Y + 360, Prefix + '   mechanical datum +' + IntToStr((N - 1) * 100) + ' mm', 10, True, $000000FF);
End;

Procedure BuildNativeSchematic;
Var ServerDoc : IServerDocument; Doc : ISch_Document;
Begin
    WriteLog('START BuildNativeSchematic');
    Client.StartServer('SCH');
    WriteLog('STEP server started');
    ServerDoc := Client.OpenDocument('SCH', SCHPATH);
    If ServerDoc = Nil Then Begin WriteLog('ERROR open SchDoc'); Exit; End;
    WriteLog('STEP document opened');
    Client.ShowDocument(ServerDoc);
    WriteLog('STEP document shown');
    ServerDoc.Focus;
    WriteLog('STEP document focused');
    Doc := SchServer.GetCurrentSchDocument;
    If Doc = Nil Then Begin WriteLog('ERROR current SchDoc'); Exit; End;
    WriteLog('STEP current document acquired');

    SchServer.ProcessControl.PreProcess(Doc, 'Build native Garage Beam Safety D3');
    WriteLog('STEP preprocess');
    Try
        ClearSheet(Doc);
        WriteLog('STEP sheet cleared');
        AddDarkBackground(Doc);
        WriteLog('STEP dark background added');
        AddSheetLabel(Doc, 400, 7600, 'GARAGE BEAM SAFETY D3 - NATIVE ALTIUM SCHEMATIC', 18, True, CYAN_INK);
        AddSheetLabel(Doc, 400, 7350, 'Three retroreflective beams, 100 mm centres; USB-C powered; advisory only', 11, True, LIGHT_INK);
        WriteLog('STEP headings added');

        AddFourPinPart(Doc, 700, 6600, 'J1', 'USB-C POWER ONLY', 'GCT', 'USB4125-GF-A-0190',
                       '6-pin charge-only USB-C receptacle, 3A', 'USB4125_6PIN', 'VBUS', 'GND', 'CC1', 'CC2');
        AddTwoPinPart(Doc, 700, 6250, 'R1', '5.1k', 'Yageo', 'RC0805FR-075K1L',
                      'USB-C CC1 pull-down', 'R0805', 'CC1', 'GND');
        AddTwoPinPart(Doc, 700, 5950, 'R2', '5.1k', 'Yageo', 'RC0805FR-075K1L',
                      'USB-C CC2 pull-down', 'R0805', 'CC2', 'GND');
        AddTwoPinPart(Doc, 1500, 6600, 'F1', '1.5A PTC', 'Bourns', 'MF-MSMF150-2',
                      'Resettable input fuse', 'F1812', 'VBUS', 'VBUS_FUSED');
        AddTwoPinPart(Doc, 2200, 6250, 'D1', 'SMAJ5.0A', 'Littelfuse', 'SMAJ5.0A',
                      '5V VBUS TVS diode', 'SMA', 'VBUS_FUSED', 'GND');
        AddThreePinPart(Doc, 2800, 6600, 'Q1', 'DMP2035U', 'Diodes Inc', 'DMP2035U',
                        'P-channel reverse-current protection MOSFET', 'SOT23', 'VBUS_FUSED', 'GND', '5V_LOGIC');
        AddTwoPinPart(Doc, 3500, 6250, 'C1', '470uF', 'Panasonic', 'EEE-FK1A471P',
                      '5V bulk capacitor', 'CAP_SMD_10X10', '5V_LOGIC', 'GND');
        AddThreePinPart(Doc, 4300, 6600, 'A2', 'U3V16F12', 'Pololu', '4945',
                        'Regulated 5V-to-12V boost module', 'POLOLU_U3V16F12', '5V_LOGIC', 'GND', '12V_SENSOR');
        AddTwoPinPart(Doc, 5000, 6250, 'C5', '100uF', 'Panasonic', 'EEE-FK1E101P',
                      '12V sensor rail bulk capacitor', 'CAP_SMD_8X10', '12V_SENSOR', 'GND');
        AddESP32(Doc, 6100, 6450);

        AddSensorChannel(Doc, 4800, 1, 'BEAM1_GPIO32');
        AddSensorChannel(Doc, 3450, 2, 'BEAM2_GPIO33');
        AddSensorChannel(Doc, 2100, 3, 'BEAM3_GPIO34');

        AddFourPinPart(Doc, 5300, 4500, 'J5', 'STATUS LED TERMINAL', 'Phoenix Contact', '1729144',
                       'External status LED connector', 'TERM_4_508', 'LED_GREEN_GPIO25', 'LED_RED_GPIO26', 'LED_AMBER_GPIO27', 'GND');
        AddTwoPinPart(Doc, 5350, 3100, 'R14', '330R', 'Yageo', 'RC0805FR-07330RL',
                      'Green LED current limit', 'R0805', 'LED_GREEN_GPIO25', 'LED_GREEN_OUT');
        AddTwoPinPart(Doc, 5350, 2800, 'R15', '330R', 'Yageo', 'RC0805FR-07330RL',
                      'Red LED current limit', 'R0805', 'LED_RED_GPIO26', 'LED_RED_OUT');
        AddTwoPinPart(Doc, 5350, 2500, 'R16', '330R', 'Yageo', 'RC0805FR-07330RL',
                      'Amber LED current limit', 'R0805', 'LED_AMBER_GPIO27', 'LED_AMBER_OUT');
        AddTwoPinPart(Doc, 6200, 1650, 'R17', '1k', 'Yageo', 'RC0805FR-071KL',
                      'Buzzer transistor base resistor', 'R0805', 'BUZZER_GPIO14', 'BUZZER_BASE');
        AddThreePinPart(Doc, 6900, 1650, 'Q2', 'MMBT2222A', 'Diodes Inc', 'MMBT2222A',
                        'Buzzer low-side driver', 'SOT23', 'BUZZER_BASE', 'GND', 'BUZZER_LOW');
        AddTwoPinPart(Doc, 6200, 1250, 'BZ1', 'CPT-9019S', 'CUI Devices', 'CPT-9019S-SMT-TR',
                      '3V magnetic transducer', 'BUZZER_9X9', '3V3', 'BUZZER_LOW');
        AddTwoPinPart(Doc, 6900, 1250, 'D5', '1N4148W', 'Nexperia', '1N4148W',
                      'Buzzer flyback clamp', 'SOD123', 'BUZZER_LOW', '3V3');
        AddTwoPinPart(Doc, 6200, 850, 'SW1', 'ALIGN/TEST', 'Omron', 'B3FS-1000P',
                      'Alignment and test tactile switch', 'SW_SMD_6X6', 'BUTTON_GPIO13', 'GND');

        AddSheetLabel(Doc, 400, 400, 'CLEAR requires all three inputs LOW for 500 ms. Any blocked/open/dead channel is unsafe.', 10, True, LIGHT_INK);
        AddSheetLabel(Doc, 400, 180, 'USB charger: certified 5 V >=2 A. Industrial EX-L291 sensors: 12 V, <=15 mA each.', 9, True, CYAN_INK);
    Finally
        SchServer.ProcessControl.PostProcess(Doc, 'Build native Garage Beam Safety D3');
    End;
    Doc.GraphicallyInvalidate;
    ServerDoc.Modified := True;
    If Not ServerDoc.DoFileSave('SCH Binary 5.0') Then
        WriteLog('ERROR saving SchDoc')
    Else
        WriteLog('OK BuildNativeSchematic');
End;

Procedure AuditNativeSchematic;
Var ServerDoc : IServerDocument; Doc : ISch_Document; It : ISch_Iterator;
    C : ISch_Component; Count : Integer; L : TStringList;
Begin
    ServerDoc := Client.OpenDocument('SCH', SCHPATH);
    If ServerDoc = Nil Then Begin WriteLog('AUDIT ERROR open SchDoc'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    Doc := SchServer.GetCurrentSchDocument;
    L := TStringList.Create; Count := 0;
    Try
        It := Doc.SchIterator_Create;
        It.AddFilter_ObjectSet(MkSet(eSchComponent));
        C := It.FirstSchObject;
        While C <> Nil Do
        Begin
            Inc(Count);
            L.Add(C.Designator.Text + '|' + C.Comment.Text + '|' + C.ComponentDescription);
            C := It.NextSchObject;
        End;
        Doc.SchIterator_Destroy(It);
        L.Insert(0, 'COMPONENT_COUNT=' + IntToStr(Count));
        L.SaveToFile(ROOTPATH + 'NativeSchematicAudit.txt');
        WriteLog('OK AuditNativeSchematic count=' + IntToStr(Count));
    Finally
        L.Free;
    End;
End;

Procedure AddPCBGuideTrack(Board, X1, Y1, X2, Y2, WidthMM, ALayer);
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    If T = Nil Then Exit;
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(WidthMM); T.Layer := ALayer;
    Board.AddPCBObject(T);
End;

Procedure AddPCBGuideText(Board, X, Y, S, HeightMM, ALayer);
Var T : IPCB_Text;
Begin
    T := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
    If T = Nil Then Exit;
    T.XLocation := MMsToCoord(X); T.YLocation := MMsToCoord(Y);
    T.Text := S; T.Size := MMsToCoord(HeightMM); T.Width := MMsToCoord(0.20);
    T.Layer := ALayer; Board.AddPCBObject(T);
End;

Procedure AddPCBGuideArc(Board, X, Y, RadiusMM, WidthMM, ALayer);
Var A : IPCB_Arc;
Begin
    A := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    If A = Nil Then Exit;
    A.XCenter := MMsToCoord(X); A.YCenter := MMsToCoord(Y);
    A.Radius := MMsToCoord(RadiusMM); A.StartAngle := 0; A.EndAngle := 360;
    A.LineWidth := MMsToCoord(WidthMM); A.Layer := ALayer; Board.AddPCBObject(A);
End;

Procedure AddOpticalDatum(Board, X, Y, DatumText);
Begin
    AddPCBGuideTrack(Board, X - 4, Y, X + 4, Y, 0.20, eMechanical1);
    AddPCBGuideTrack(Board, X, Y - 4, X, Y + 4, 0.20, eMechanical1);
    AddPCBGuideArc(Board, X, Y, 3, 0.20, eMechanical1);
    AddPCBGuideText(Board, X + 5, Y - 1, DatumText, 0.9, eMechanical1);
End;

Function MakePCBPad(X, Y, SizeX, SizeY, HoleMM, ALayer, PadName) : IPCB_Pad;
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    If P = Nil Then Exit;
    P.X := MMsToCoord(X); P.Y := MMsToCoord(Y);
    P.TopXSize := MMsToCoord(SizeX); P.TopYSize := MMsToCoord(SizeY);
    P.HoleSize := MMsToCoord(HoleMM); P.Layer := ALayer; P.Name := PadName;
    Result := P;
End;

Function MakePCBBodyTrack(X1, Y1, X2, Y2) : IPCB_Track;
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    If T = Nil Then Exit;
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(0.20); T.Layer := eTopOverlay;
    Result := T;
End;

Procedure AddSimplePCBComponent(Board, X, Y, RefDes, ValueText, PinCount,
                                PitchMM, BodyW, BodyH, IsSMD);
Var C : IPCB_Component; P : IPCB_Pad; T : IPCB_Track; I : Integer;
    PX, PadX, PadY, HoleMM, PadSX, PadSY : Double; PadLayer : TLayer;
Begin
    C := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If C = Nil Then Exit;
    T := MakePCBBodyTrack(-BodyW/2, -BodyH/2, BodyW/2, -BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(BodyW/2, -BodyH/2, BodyW/2, BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(BodyW/2, BodyH/2, -BodyW/2, BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(-BodyW/2, BodyH/2, -BodyW/2, -BodyH/2); C.AddPCBObject(T);
    If IsSMD Then
    Begin
        HoleMM := 0; PadLayer := eTopLayer; PadSX := 1.2; PadSY := 1.5;
    End
    Else
    Begin
        HoleMM := 0.9; PadLayer := eMultiLayer; PadSX := 1.8; PadSY := 1.8;
    End;
    For I := 1 To PinCount Do
    Begin
        PX := (I - 1) - ((PinCount - 1) / 2);
        PadX := PX * PitchMM; PadY := 0;
        P := MakePCBPad(PadX, PadY, PadSX, PadSY, HoleMM, PadLayer, IntToStr(I));
        C.AddPCBObject(P);
    End;
    C.X := MMsToCoord(X); C.Y := MMsToCoord(Y); C.Layer := eTopLayer;
    C.NameOn := True; C.Name.Text := RefDes;
    C.Name.XLocation := MMsToCoord(X - BodyW/2);
    C.Name.YLocation := MMsToCoord(Y + BodyH/2 + 0.8);
    C.CommentOn := True; C.Comment.Text := ValueText;
    C.Comment.XLocation := MMsToCoord(X - BodyW/2);
    C.Comment.YLocation := MMsToCoord(Y - BodyH/2 - 0.8);
    C.SourceDesignator := RefDes;
    Board.AddPCBObject(C);
End;

Procedure AddDualRowPCBComponent(Board, X, Y, RefDes, ValueText, PinsPerSide,
                                 RowPitch, ColPitch, BodyW, BodyH);
Var C : IPCB_Component; P : IPCB_Pad; T : IPCB_Track; I : Integer; PY : Double;
Begin
    C := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If C = Nil Then Exit;
    T := MakePCBBodyTrack(-BodyW/2, -BodyH/2, BodyW/2, -BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(BodyW/2, -BodyH/2, BodyW/2, BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(BodyW/2, BodyH/2, -BodyW/2, BodyH/2); C.AddPCBObject(T);
    T := MakePCBBodyTrack(-BodyW/2, BodyH/2, -BodyW/2, -BodyH/2); C.AddPCBObject(T);
    For I := 1 To PinsPerSide Do
    Begin
        PY := ((I - 1) - ((PinsPerSide - 1) / 2)) * RowPitch;
        P := MakePCBPad(-ColPitch/2, PY, 1.8, 1.8, 0.9, eMultiLayer, IntToStr(I));
        C.AddPCBObject(P);
        P := MakePCBPad(ColPitch/2, PY, 1.8, 1.8, 0.9, eMultiLayer, IntToStr((PinsPerSide * 2) - I + 1));
        C.AddPCBObject(P);
    End;
    C.X := MMsToCoord(X); C.Y := MMsToCoord(Y); C.Layer := eTopLayer;
    C.NameOn := True; C.Name.Text := RefDes;
    C.Name.XLocation := MMsToCoord(X - BodyW/2); C.Name.YLocation := MMsToCoord(Y + BodyH/2 + 0.8);
    C.CommentOn := True; C.Comment.Text := ValueText;
    C.Comment.XLocation := MMsToCoord(X - BodyW/2); C.Comment.YLocation := MMsToCoord(Y - BodyH/2 - 0.8);
    C.SourceDesignator := RefDes; Board.AddPCBObject(C);
End;

Procedure AddPCBMountHole(Board, X, Y, HoleName);
Var P : IPCB_Pad;
Begin
    P := MakePCBPad(X, Y, 3.2, 3.2, 3.2, eMultiLayer, HoleName);
    Board.AddPCBObject(P);
End;

Procedure CreateNativePCB;
Var ServerModule : IServerModule; ServerDoc : IServerDocument; Board : IPCB_Board;
Begin
    WriteLog('PCB START server');
    Client.StartServer('PCB');
    ServerModule := Client.ServerModuleByName['PCB'];
    If ServerModule = Nil Then Begin WriteLog('PCB ERROR server module'); Exit; End;
    WriteLog('PCB STEP create document');
    ServerDoc := ServerModule.CreateDocument('PCB', PCBPATH);
    If ServerDoc = Nil Then Begin WriteLog('PCB ERROR create document'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Begin WriteLog('PCB ERROR current board'); Exit; End;
    WriteLog('PCB STEP board acquired');
    PCBServer.PreProcess;
    Try
        AddPCBGuideTrack(Board, 0, 0, 50, 0, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 50, 0, 50, 240, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 50, 240, 0, 240, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 0, 240, 0, 0, 0.25, eMechanical1);
        AddPCBGuideText(Board, 2, 237, 'GARAGE BEAM SAFETY D3 - 3 BEAMS / 100 mm CENTRES', 1.2, eMechanical1);
        AddPCBGuideText(Board, 2, 3, 'USB-C 5 V INPUT / 0805 SMD / ADVISORY SAFETY ONLY', 1.0, eMechanical1);
        AddPCBMountHole(Board, 5, 5, 'H1'); AddPCBMountHole(Board, 45, 5, 'H2');
        AddPCBMountHole(Board, 5, 235, 'H3'); AddPCBMountHole(Board, 45, 235, 'H4');
        AddOpticalDatum(Board, 25, 20, 'BEAM 1 AXIS / 0 mm');
        AddOpticalDatum(Board, 25, 120, 'BEAM 2 AXIS / +100 mm');
        AddOpticalDatum(Board, 25, 220, 'BEAM 3 AXIS / +200 mm');
        AddSimplePCBComponent(Board, 25, 8, 'J1', 'USB4125-GF-A-0190', 6, 0.65, 8.9, 7.4, True);
        AddSimplePCBComponent(Board, 8, 18, 'R1', '5.1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 15, 18, 'R2', '5.1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 22, 18, 'F1', '1.5A PTC', 2, 4.0, 6.0, 4.0, True);
        AddSimplePCBComponent(Board, 31, 18, 'D1', 'SMAJ5.0A', 2, 5.0, 6.0, 3.5, True);
        AddSimplePCBComponent(Board, 39, 18, 'Q1', 'DMP2035U', 3, 0.95, 3.0, 3.0, True);
        AddSimplePCBComponent(Board, 45, 18, 'C1', '470uF', 2, 4.0, 7.0, 7.0, True);
        AddSimplePCBComponent(Board, 10, 34, 'A2', 'U3V16F12', 3, 2.54, 12.0, 16.0, False);
        AddSimplePCBComponent(Board, 21, 34, 'C5', '100uF', 2, 3.0, 6.0, 6.0, True);
        AddDualRowPCBComponent(Board, 36, 61, 'A1', 'ESP32 DevKit 30-pin', 15, 2.54, 25.4, 28.0, 40.0);

        AddSimplePCBComponent(Board, 8, 92, 'J2', 'BEAM 1', 3, 5.08, 13.0, 8.0, False);
        AddSimplePCBComponent(Board, 20, 92, 'R5', '2.2k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 27, 92, 'U2', 'LTV-817S', 4, 2.54, 7.0, 5.0, True);
        AddSimplePCBComponent(Board, 36, 88, 'D2', '1N4148W', 2, 3.5, 4.0, 2.0, True);
        AddSimplePCBComponent(Board, 36, 93, 'R6', '10k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 93, 'R7', '1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 88, 'C2', '100nF', 2, 2.2, 3.2, 2.0, True);

        AddSimplePCBComponent(Board, 8, 120, 'J3', 'BEAM 2', 3, 5.08, 13.0, 8.0, False);
        AddSimplePCBComponent(Board, 20, 120, 'R8', '2.2k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 27, 120, 'U3', 'LTV-817S', 4, 2.54, 7.0, 5.0, True);
        AddSimplePCBComponent(Board, 36, 116, 'D3', '1N4148W', 2, 3.5, 4.0, 2.0, True);
        AddSimplePCBComponent(Board, 36, 121, 'R9', '10k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 121, 'R10', '1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 116, 'C3', '100nF', 2, 2.2, 3.2, 2.0, True);

        AddSimplePCBComponent(Board, 8, 148, 'J4', 'BEAM 3', 3, 5.08, 13.0, 8.0, False);
        AddSimplePCBComponent(Board, 20, 148, 'R11', '2.2k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 27, 148, 'U4', 'LTV-817S', 4, 2.54, 7.0, 5.0, True);
        AddSimplePCBComponent(Board, 36, 144, 'D4', '1N4148W', 2, 3.5, 4.0, 2.0, True);
        AddSimplePCBComponent(Board, 36, 149, 'R12', '10k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 149, 'R13', '1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 43, 144, 'C4', '100nF', 2, 2.2, 3.2, 2.0, True);

        AddSimplePCBComponent(Board, 10, 178, 'J5', 'STATUS', 4, 5.08, 18.0, 8.0, False);
        AddSimplePCBComponent(Board, 25, 172, 'R14', '330R', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 25, 178, 'R15', '330R', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 25, 184, 'R16', '330R', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 35, 172, 'R17', '1k', 2, 2.2, 3.2, 2.0, True);
        AddSimplePCBComponent(Board, 42, 172, 'Q2', 'MMBT2222A', 3, 0.95, 3.0, 3.0, True);
        AddSimplePCBComponent(Board, 35, 182, 'BZ1', 'CPT-9019S', 2, 5.0, 10.0, 10.0, True);
        AddSimplePCBComponent(Board, 44, 182, 'D5', '1N4148W', 2, 3.5, 4.0, 2.0, True);
        AddSimplePCBComponent(Board, 25, 200, 'SW1', 'ALIGN/TEST', 2, 4.5, 6.0, 6.0, True);
    Finally
        PCBServer.PostProcess;
    End;
    Board.ViewManager_FullUpdate;
    ServerDoc.Modified := True;
    If Not ServerDoc.DoFileSave('PCB Binary 6.0') Then
        WriteLog('PCB ERROR save')
    Else
        WriteLog('PCB OK created');
End;

Procedure AuditNativePCB;
Var ServerDoc : IServerDocument; Board : IPCB_Board; It : IPCB_BoardIterator;
    C : IPCB_Component; Count : Integer; L : TStringList;
Begin
    ServerDoc := Client.OpenDocument('PCB', PCBPATH);
    If ServerDoc = Nil Then Begin WriteLog('PCB AUDIT ERROR open'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Begin WriteLog('PCB AUDIT ERROR board'); Exit; End;
    L := TStringList.Create; Count := 0;
    Try
        It := Board.BoardIterator_Create;
        It.AddFilter_ObjectSet(MkSet(eComponentObject));
        It.AddFilter_LayerSet(AllLayers);
        It.AddFilter_Method(eProcessAll);
        C := It.FirstPCBObject;
        While C <> Nil Do
        Begin
            Inc(Count); L.Add(C.Name.Text + '|' + C.Comment.Text);
            C := It.NextPCBObject;
        End;
        Board.BoardIterator_Destroy(It);
        L.Insert(0, 'PCB_COMPONENT_COUNT=' + IntToStr(Count));
        L.SaveToFile(ROOTPATH + 'NativePCBAudit.txt');
        WriteLog('PCB AUDIT OK count=' + IntToStr(Count));
    Finally
        L.Free;
    End;
End;

Procedure CreateNativeActiveBOM;
Var ServerModule : IServerModule; ServerDoc : IServerDocument;
Begin
    WriteLog('BOM START server');
    Client.StartServer('ActiveBOM');
    ServerModule := Client.ServerModuleByName['ActiveBOM'];
    If ServerModule = Nil Then Begin WriteLog('BOM ERROR server module'); Exit; End;
    WriteLog('BOM STEP create document');
    ServerDoc := ServerModule.CreateDocument('BOM', BOMPATH);
    If ServerDoc = Nil Then Begin WriteLog('BOM ERROR create document'); Exit; End;
    WriteLog('BOM FILE before save=' + ServerDoc.FileName);
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    ServerDoc.Modified := True;
    If Not ServerDoc.DoSafeChangeFileNameAndSave(BOMPATH, 'BOM ASCII Files (*.BomDoc)') Then
        WriteLog('BOM ERROR save')
    Else
        WriteLog('BOM OK created file=' + ServerDoc.FileName);
End;

Procedure CreateNativeReflectorPCB;
Var ServerModule : IServerModule; ServerDoc : IServerDocument; Board : IPCB_Board;
Begin
    WriteLog('REFPCB START server');
    Client.StartServer('PCB');
    ServerModule := Client.ServerModuleByName['PCB'];
    If ServerModule = Nil Then Begin WriteLog('REFPCB ERROR server'); Exit; End;
    ServerDoc := ServerModule.CreateDocument('PCB', REFPCBPATH);
    If ServerDoc = Nil Then Begin WriteLog('REFPCB ERROR create'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Begin WriteLog('REFPCB ERROR board'); Exit; End;
    PCBServer.PreProcess;
    Try
        AddPCBGuideTrack(Board, 0, 0, 30, 0, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 30, 0, 30, 240, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 30, 240, 0, 240, 0.25, eMechanical1);
        AddPCBGuideTrack(Board, 0, 240, 0, 0, 0.25, eMechanical1);
        AddPCBMountHole(Board, 5, 5, 'RH1'); AddPCBMountHole(Board, 25, 5, 'RH2');
        AddPCBMountHole(Board, 5, 235, 'RH3'); AddPCBMountHole(Board, 25, 235, 'RH4');
        AddOpticalDatum(Board, 15, 20, 'REFLECTOR 1 / 0 mm');
        AddOpticalDatum(Board, 15, 120, 'REFLECTOR 2 / +100 mm');
        AddOpticalDatum(Board, 15, 220, 'REFLECTOR 3 / +200 mm');
        AddPCBGuideText(Board, 2, 237, 'D3 PASSIVE REFLECTOR CARRIER - NO POWER / NO COPPER', 1.0, eMechanical1);
    Finally
        PCBServer.PostProcess;
    End;
    Board.ViewManager_FullUpdate; ServerDoc.Modified := True;
    If Not ServerDoc.DoFileSave('PCB Binary 6.0') Then
        WriteLog('REFPCB ERROR save')
    Else
        WriteLog('REFPCB OK created');
End;

Procedure OpenNativeActiveBOM;
Var ServerDoc : IServerDocument;
Begin
    Client.StartServer('ActiveBOM');
    ServerDoc := Client.OpenDocument('BOM', BOMPATH);
    If ServerDoc = Nil Then Begin WriteLog('BOM OPEN ERROR'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    WriteLog('BOM OPEN OK project refresh requested');
End;

Procedure OpenNativeSchematic;
Var ServerDoc : IServerDocument;
Begin
    Client.StartServer('SCH');
    ServerDoc := Client.OpenDocument('SCH', SCHPATH);
    If ServerDoc = Nil Then Begin WriteLog('SCH OPEN ERROR'); Exit; End;
    Client.ShowDocument(ServerDoc); ServerDoc.Focus;
    WriteLog('SCH OPEN OK');
End;

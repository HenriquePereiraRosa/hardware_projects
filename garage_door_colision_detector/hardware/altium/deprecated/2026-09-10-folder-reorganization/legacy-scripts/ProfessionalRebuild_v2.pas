{ Garage Beam Safety - professional template-based Altium rebuild.

  The target SchDocs must first be binary copies of the user's ENERGY.SchDoc.
  This script preserves the template border, embedded images/logo and title block,
  removes the EnergyMeter circuit, applies the native dark sheet AreaColor, and
  creates clean native Altium schematic objects with electrical connectivity.

  The PCB section creates real IPCB_Net objects, assigns every electrical pad,
  and places routed copper.  It does not claim fabrication release until the
  exact user-owned ESP32 DevKit mechanics are confirmed. }

Const
    ROOT = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';
    TEMPLATE_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\template-source\SCH\ENERGY.SchDoc';
    OVERVIEW_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\00_Mounting_Overview.SchDoc';
    POWER_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\01_Power_Control.SchDoc';
    BEAMS_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\02_Beam_Inputs.SchDoc';
    UI_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\03_UI_Outputs.SchDoc';
    PCB_PATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.PcbDoc';
    BUILD_LOG = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\ProfessionalBuild.log';
    SCH_AUDIT = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\ProfessionalSchematicAudit.txt';

    C_BG = $00202020;
    C_PANEL = $00303030;
    C_TEXT = $00E8E8E8;
    C_WIRE = $0080D8FF;
    C_POWER = $0060C0FF;
    C_ACCENT = $00FFD080;
    C_WARN = $0040C0FF;
    C_RED = $004040FF;
    C_GREEN = $0080FF80;

Procedure PLog(S);
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try L.Add(S); L.SaveToFile(BUILD_LOG); Finally L.Free; End;
End;

Function OpenSch(APath) : IServerDocument;
Var D : IServerDocument;
Begin
    Client.StartServer('SCH');
    D := Client.OpenDocument('SCH', APath);
    If D <> Nil Then Begin Client.ShowDocument(D); D.Focus; End;
    Result := D;
End;

Function IsTemplateLabel(S) : Boolean;
Begin
    Result := (S <> 'FASTON') And (S <> 'RS232') And (Copy(S, 1, 3) <> 'XC=');
End;

Procedure ClearCircuitKeepTemplate(Doc);
Var It : ISch_Iterator; O, OldO : ISch_GraphicalObject; Lbl : ISch_Label; RemoveIt : Boolean;
Begin
    It := Doc.SchIterator_Create;
    If It = Nil Then Exit;
    It.SetState_FilterAll;
    O := It.FirstSchObject;
    While O <> Nil Do
    Begin
        OldO := O; O := It.NextSchObject; RemoveIt := False;
        RemoveIt := (OldO.ObjectId = eSchComponent) Or (OldO.ObjectId = eWire) Or
                    (OldO.ObjectId = eBus) Or (OldO.ObjectId = eNetLabel) Or
                    (OldO.ObjectId = ePowerObject) Or (OldO.ObjectId = ePort) Or
                    (OldO.ObjectId = eJunction);
        { Keep only the low title-block labels from the source template.  Earlier
          versions accidentally retained every generated heading and note. }
        If OldO.ObjectId = eLabel Then
        Begin
            Lbl := OldO;
            RemoveIt := Lbl.Location.Y > MilsToCoord(700);
        End;
        If RemoveIt Then Doc.RemoveSchObject(OldO);
    End;
    Doc.SchIterator_Destroy(It);
End;

Procedure RecolorTemplate(Doc);
Var It : ISch_Iterator; O : ISch_GraphicalObject;
Begin
    Doc.AreaColor := C_BG;
    Doc.VisibleGridOn := False;
    It := Doc.SchIterator_Create; It.SetState_FilterAll;
    O := It.FirstSchObject;
    While O <> Nil Do
    Begin
        If O.ObjectId <> eImage Then
        Begin
            O.Color := C_TEXT;
            If (O.ObjectId = eRectangle) Or (O.ObjectId = eRoundRectangle) Or
               (O.ObjectId = eTextFrame) Then O.AreaColor := C_BG;
        End;
        O := It.NextSchObject;
    End;
    Doc.SchIterator_Destroy(It);
    Doc.UpdateDocumentProperties;
End;

Procedure SetDocParameter(Doc, N, V);
Var It : ISch_Iterator; P : ISch_Parameter; Found : Boolean;
Begin
    Found := False;
    It := Doc.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eParameter));
    P := It.FirstSchObject;
    While P <> Nil Do
    Begin
        If P.Name = N Then Begin P.Text := V; Found := True; End;
        P := It.NextSchObject;
    End;
    Doc.SchIterator_Destroy(It);
    If Not Found Then
    Begin
        P := SchServer.SchObjectFactory(eParameter, eCreate_GlobalCopy);
        P.Name := N; P.Text := V; Doc.RegisterSchObjectInContainer(P);
    End;
End;

Procedure SetSheetIdentity(Doc, TitleText, DocNo, SheetNo);
Begin
    SetDocParameter(Doc, 'Title', TitleText);
    SetDocParameter(Doc, 'DocumentNumber', DocNo);
    SetDocParameter(Doc, 'Revision', 'A');
    SetDocParameter(Doc, 'SheetNumber', SheetNo);
    SetDocParameter(Doc, 'SheetTotal', '04');
    SetDocParameter(Doc, 'DrawnBy', 'Henq / Codex');
    SetDocParameter(Doc, 'Engineer', 'Henrique Rosa');
End;

Procedure AddText(Doc, X, Y, S, AColor);
Var L : ISch_Label;
Begin
    L := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S; L.Color := AColor; L.Orientation := eRotate0;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddLine(Doc, X1, Y1, X2, Y2, AColor, AWidth);
Var L : ISch_Line;
Begin
    L := SchServer.SchObjectFactory(eLine, eCreate_GlobalCopy);
    L.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    L.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    L.Color := AColor; L.LineWidth := AWidth; L.LineStyle := eLineStyleSolid;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddRect(Doc, X1, Y1, X2, Y2, LineColor, FillColor, Solid);
Var R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    R.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    R.LineWidth := eMedium; R.Color := LineColor; R.AreaColor := FillColor;
    R.IsSolid := Solid; Doc.RegisterSchObjectInContainer(R);
End;

Procedure AddWire(Doc, X1, Y1, X2, Y2);
Var W : ISch_Wire;
Begin
    W := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    W.SetState_LineWidth(eSmall); W.Color := C_WIRE;
    W.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    W.InsertVertex(1); W.SetState_Vertex(1, Point(MilsToCoord(X1), MilsToCoord(Y1)));
    W.InsertVertex(2); W.SetState_Vertex(2, Point(MilsToCoord(X2), MilsToCoord(Y2)));
    Doc.RegisterSchObjectInContainer(W);
End;

Procedure AddNetLabel(Doc, X, Y, S, Orient);
Var L : ISch_NetLabel;
Begin
    L := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S; L.Color := C_WIRE; L.Orientation := Orient;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddLabeledWire(Doc, X1, Y1, X2, Y2, S, Orient);
Begin
    AddWire(Doc, X1, Y1, X2, Y2); AddNetLabel(Doc, X2, Y2, S, Orient);
End;

Procedure AddCompParameter(C, N, V);
Var It : ISch_Iterator; P : ISch_Parameter; Found : Boolean;
Begin
    Found := False; It := C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eParameter));
    P := It.FirstSchObject;
    While P <> Nil Do
    Begin
        If P.Name = N Then Begin P.Text := V; Found := True; End;
        P := It.NextSchObject;
    End;
    C.SchIterator_Destroy(It);
    If Not Found Then Begin P := SchServer.SchObjectFactory(eParameter, eCreate_GlobalCopy);
        P.Name := N; P.Text := V; P.OwnerPartId := 1; P.OwnerPartDisplayMode := 0; C.AddSchObject(P); End;
End;

Procedure AddFootprint(C, Name);
Var I : ISch_Implementation;
Begin
    I := SchServer.SchObjectFactory(eImplementation, eCreate_GlobalCopy);
    I.ModelType := 'PCBLIB'; I.ModelName := Name; C.AddSchObject(I);
End;

Function CloneTemplateComp(TargetDoc, SeedDes, NewDes, NewValue, Manufacturer,
                           MPN, Footprint, Description, X, Y) : ISch_Component;
Var SSD : IServerDocument; SrcDoc : ISch_Document; It : ISch_Iterator;
    Src, C : ISch_Component;
Begin
    Result := Nil; SSD := OpenSch(TEMPLATE_SCH); If SSD = Nil Then Exit;
    SrcDoc := SchServer.GetCurrentSchDocument;
    It := SrcDoc.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    Src := It.FirstSchObject;
    While Src <> Nil Do
    Begin
        If Src.Designator.Text = SeedDes Then
        Begin
            C := Src.Replicate; C.MoveToXY(MilsToCoord(X), MilsToCoord(Y));
            C.Designator.Text := NewDes; C.Comment.Text := NewValue;
            C.Designator.Color := C_TEXT; C.Comment.Color := C_TEXT;
            C.LibReference := NewValue; C.ComponentDescription := Description;
            AddCompParameter(C, 'Manufacturer', Manufacturer);
            AddCompParameter(C, 'Manufacturer Part Number', MPN);
            AddCompParameter(C, 'Description', Description);
            AddCompParameter(C, 'Package', Footprint);
            AddCompParameter(C, 'Populate', 'Yes'); AddFootprint(C, Footprint);
            TargetDoc.RegisterSchObjectInContainer(C); Result := C; Break;
        End;
        Src := It.NextSchObject;
    End;
    SrcDoc.SchIterator_Destroy(It);
End;

Procedure AddCustomPin(C, X, Y, No, PinName, Orient, Elec);
Var P : ISch_Pin;
Begin
    P := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    P.Location := Point(MilsToCoord(X), MilsToCoord(Y)); P.Orientation := Orient;
    P.Designator := No; P.Name := PinName; P.Electrical := Elec; P.Color := C_TEXT;
    P.OwnerPartId := 1; P.OwnerPartDisplayMode := 0; C.AddSchObject(P);
End;

Procedure AddCompBody(C, X1, Y1, X2, Y2, AColor);
Var R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    R.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    R.LineWidth := eMedium; R.Color := AColor; R.AreaColor := C_BG; R.IsSolid := False;
    R.OwnerPartId := 1; R.OwnerPartDisplayMode := 0; C.AddSchObject(R);
End;

Function NewCustomComp(Doc, RefDes, ValueText, Manufacturer, MPN, Footprint,
                       Description, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    C.CurrentPartID := 1; C.DisplayMode := 0; C.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    C.Designator.Text := RefDes; C.Comment.Text := ValueText;
    C.Designator.Color := C_TEXT; C.Comment.Color := C_TEXT;
    C.Designator.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y + 300));
    C.Comment.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y - 320));
    C.LibReference := ValueText; C.ComponentDescription := Description;
    AddCompParameter(C, 'Manufacturer', Manufacturer);
    AddCompParameter(C, 'Manufacturer Part Number', MPN);
    AddCompParameter(C, 'Description', Description);
    AddCompParameter(C, 'Package', Footprint);
    AddCompParameter(C, 'Populate', 'Yes'); AddFootprint(C, Footprint);
    Result := C;
End;

Procedure FinishCustomComp(Doc, C);
Begin Doc.RegisterSchObjectInContainer(C); End;

Procedure SaveSch(SD, APath, SuccessText);
Var D : ISch_Document;
Begin
    SD.Focus; D := SchServer.GetCurrentSchDocument; D.GraphicallyInvalidate; SD.Modified := True;
    If SD.DoSafeChangeFileNameAndSave(APath, 'SCH Binary 5.0') Then PLog(SuccessText)
    Else PLog('ERROR saving ' + APath);
End;

Procedure PrepareSheet(SD, TitleText, DocNo, SheetNo);
Var D : ISch_Document;
Begin
    D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Professional rebuild');
    Try ClearCircuitKeepTemplate(D); RecolorTemplate(D); SetSheetIdentity(D, TitleText, DocNo, SheetNo);
    Finally SchServer.ProcessControl.PostProcess(D, 'Professional rebuild'); End;
End;

Procedure AddSheetHeading(D, N, TitleText, Subtitle);
Begin
    AddText(D, 650, 7350, N + '  ' + TitleText, C_ACCENT);
    AddLine(D, 650, 7240, 10400, 7240, C_ACCENT, eMedium);
    AddText(D, 650, 7050, Subtitle, C_TEXT);
End;

Function FindPin(C, PinNo) : ISch_Pin;
Var It : ISch_Iterator; P : ISch_Pin;
Begin
    Result := Nil; It := C.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(ePin));
    P := It.FirstSchObject;
    While P <> Nil Do Begin If P.Designator = PinNo Then Begin Result := P; Break; End; P := It.NextSchObject; End;
    C.SchIterator_Destroy(It);
End;

Procedure AddWireCoord(Doc, X1, Y1, X2, Y2);
Var W : ISch_Wire;
Begin
    W := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    W.SetState_LineWidth(eSmall); W.Color := C_WIRE; W.Location := Point(X1, Y1);
    W.InsertVertex(1); W.SetState_Vertex(1, Point(X1, Y1));
    W.InsertVertex(2); W.SetState_Vertex(2, Point(X2, Y2));
    Doc.RegisterSchObjectInContainer(W);
End;

Procedure AddNetLabelCoord(Doc, X, Y, S, Orient);
Var L : ISch_NetLabel;
Begin
    L := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    L.Location := Point(X, Y); L.Text := S; L.Color := C_WIRE; L.Orientation := Orient;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddPowerPortCoord(Doc, X, Y, NetName, AStyle, Orient);
Var P : ISch_PowerObject;
Begin
    P := SchServer.SchObjectFactory(ePowerObject, eCreate_GlobalCopy);
    P.Location := Point(X,Y); P.Text := NetName; P.Style := AStyle;
    P.Orientation := Orient; P.ShowNetName := True; P.Color := C_POWER;
    Doc.RegisterSchObjectInContainer(P);
End;

Procedure PowerCompPin(Doc, C, PinNo, NetName, Side, AStyle);
Var P : ISch_Pin; Ex : TCoord; O : Integer;
Begin
    P := FindPin(C,PinNo); If P = Nil Then Exit;
    Ex := P.Location.X + (Side * MilsToCoord(180));
    AddWireCoord(Doc,P.Location.X,P.Location.Y,Ex,P.Location.Y);
    If Side < 0 Then O := eRotate270 Else O := eRotate90;
    AddPowerPortCoord(Doc,Ex,P.Location.Y,NetName,AStyle,O);
End;

Procedure ConnectPins(Doc, C1, Pin1, C2, Pin2);
Var P1, P2 : ISch_Pin; MX : TCoord;
Begin
    P1 := FindPin(C1,Pin1); P2 := FindPin(C2,Pin2);
    If (P1 = Nil) Or (P2 = Nil) Then Exit;
    MX := (P1.Location.X + P2.Location.X) Div 2;
    AddWireCoord(Doc,P1.Location.X,P1.Location.Y,MX,P1.Location.Y);
    AddWireCoord(Doc,MX,P1.Location.Y,MX,P2.Location.Y);
    AddWireCoord(Doc,MX,P2.Location.Y,P2.Location.X,P2.Location.Y);
End;

Procedure LabelCompPin(Doc, C, PinNo, NetName, Side);
Var P : ISch_Pin; Ex : TCoord; O : Integer;
Begin
    P := FindPin(C, PinNo); If P = Nil Then Exit;
    Ex := P.Location.X + (Side * MilsToCoord(220));
    AddWireCoord(Doc, P.Location.X, P.Location.Y, Ex, P.Location.Y);
    If Side < 0 Then O := eRotate180 Else O := eRotate0;
    AddNetLabelCoord(Doc, Ex, P.Location.Y, NetName, O);
End;

Function AddTwoPinBare(Doc, Kind, RefDes, ValueText, Manufacturer, MPN,
                       Footprint, Description, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, RefDes, ValueText, Manufacturer, MPN, Footprint, Description, X, Y);
    AddCompBody(C, X - 180, Y - 140, X + 180, Y + 140, C_ACCENT);
    AddCustomPin(C, X - 300, Y, '1', Kind + '1', eRotate0, eElectricPassive);
    AddCustomPin(C, X + 300, Y, '2', Kind + '2', eRotate180, eElectricPassive);
    FinishCustomComp(Doc,C); Result := C;
End;

Function AddTwoPin(Doc, Kind, RefDes, ValueText, Manufacturer, MPN, Footprint,
                   Description, X, Y, Net1, Net2) : ISch_Component;
Var C : ISch_Component;
Begin
    C := AddTwoPinBare(Doc,Kind,RefDes,ValueText,Manufacturer,MPN,Footprint,Description,X,Y);
    If C <> Nil Then Begin LabelCompPin(Doc, C, '1', Net1, -1); LabelCompPin(Doc, C, '2', Net2, 1); End;
    Result := C;
End;

Function AddPowerTerminal(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'J1', '12 V INPUT', 'Phoenix Contact', '1729128',
                       'TERM_2_508', 'Two-position 5.08 mm screw terminal', X, Y);
    AddCompBody(C, X - 300, Y - 270, X + 300, Y + 270, C_ACCENT);
    AddCustomPin(C, X + 420, Y + 120, '1', '+12V', eRotate180, eElectricPower);
    AddCustomPin(C, X + 420, Y - 120, '2', '0V', eRotate180, eElectricPower);
    FinishCustomComp(Doc, C); Result := C;
End;

Function AddThreePinBlock(Doc, RefDes, ValueText, Manufacturer, MPN, Footprint,
                          Description, X, Y, P1, N1, P2, N2, P3, N3) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, RefDes, ValueText, Manufacturer, MPN, Footprint, Description, X, Y);
    AddCompBody(C, X - 300, Y - 270, X + 300, Y + 270, C_ACCENT);
    AddCustomPin(C, X - 420, Y + 150, P1, N1, eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y - 150, P2, N2, eRotate0, eElectricPassive);
    AddCustomPin(C, X + 420, Y, P3, N3, eRotate180, eElectricPassive);
    FinishCustomComp(Doc, C); Result := C;
End;

Function AddFourPinOpto(Doc, RefDes, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, RefDes, 'LTV-817S', 'Lite-On', 'LTV-817S-TA1',
                       'LTV817S_SMD4', 'Phototransistor optocoupler', X, Y);
    AddCompBody(C, X - 320, Y - 300, X + 320, Y + 300, C_ACCENT);
    AddCustomPin(C, X - 440, Y + 150, '1', 'A', eRotate0, eElectricInput);
    AddCustomPin(C, X - 440, Y - 150, '2', 'K', eRotate0, eElectricInput);
    AddCustomPin(C, X + 440, Y - 150, '3', 'E', eRotate180, eElectricOpenCollector);
    AddCustomPin(C, X + 440, Y + 150, '4', 'C', eRotate180, eElectricOpenCollector);
    FinishCustomComp(Doc, C); Result := C;
End;

Function AddESP32(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'A1', 'ESP32 DEVKIT V1 30-PIN', 'Espressif-compatible',
                       'USER-OWNED-30PIN', 'ESP32_DEVKIT_V1_30PIN_SOCKET',
                       'Socketed ESP32-WROOM development board', X, Y);
    AddCompBody(C, X - 480, Y - 750, X + 480, Y + 750, C_ACCENT);
    AddCustomPin(C, X - 600, Y + 600, '30', 'VIN/5V', eRotate0, eElectricPower);
    AddCustomPin(C, X - 600, Y + 420, '1', '3V3', eRotate0, eElectricPower);
    AddCustomPin(C, X - 600, Y + 240, '2', 'GND', eRotate0, eElectricPower);
    AddCustomPin(C, X - 600, Y + 60, '7', 'GPIO32', eRotate0, eElectricInput);
    AddCustomPin(C, X - 600, Y - 120, '8', 'GPIO33', eRotate0, eElectricInput);
    AddCustomPin(C, X - 600, Y - 300, '9', 'GPIO34', eRotate0, eElectricInput);
    AddCustomPin(C, X + 600, Y + 510, '5', 'GPIO25', eRotate180, eElectricOutput);
    AddCustomPin(C, X + 600, Y + 270, '4', 'GPIO26', eRotate180, eElectricOutput);
    AddCustomPin(C, X + 600, Y + 30, '3', 'GPIO27', eRotate180, eElectricOutput);
    AddCustomPin(C, X + 600, Y - 210, '11', 'GPIO14', eRotate180, eElectricOutput);
    AddCustomPin(C, X + 600, Y - 450, '12', 'GPIO13', eRotate180, eElectricInput);
    FinishCustomComp(Doc, C); Result := C;
End;

Procedure BuildProfessionalOverview;
Var SD : IServerDocument; D : ISch_Document;
Begin
    SD := OpenSch(OVERVIEW_SCH); If SD = Nil Then Begin PLog('ERROR open overview'); Exit; End;
    PrepareSheet(SD, 'MOUNTING OVERVIEW', 'GBS-00', '01');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Mounting overview');
    Try
        AddSheetHeading(D, '00', 'MOUNTING OVERVIEW', 'Three retroreflective beam axes; passive reflector carrier is optional FR-4.');
        AddRect(D, 850, 1500, 2850, 6800, C_ACCENT, C_PANEL, True);
        AddRect(D, 7600, 1500, 9300, 6800, C_POWER, C_PANEL, True);
        AddText(D, 1100, 6550, 'WALL A - SENSOR / CONTROLLER CARRIER', C_ACCENT);
        AddText(D, 7780, 6550, 'WALL B - PASSIVE REFLECTORS', C_POWER);
        AddText(D, 1120, 6300, '50 x 240 mm, electronics + removable sensors', C_TEXT);
        AddText(D, 7770, 6300, '30 x 240 mm carrier; no electrical PCB required', C_TEXT);
        AddRect(D, 1450, 1950, 2050, 2350, C_ACCENT, C_BG, False);
        AddRect(D, 1450, 3950, 2050, 4350, C_ACCENT, C_BG, False);
        AddRect(D, 1450, 5500, 2050, 5900, C_ACCENT, C_BG, False);
        AddRect(D, 8000, 1950, 8600, 2350, C_POWER, C_BG, False);
        AddRect(D, 8000, 3950, 8600, 4350, C_POWER, C_BG, False);
        AddRect(D, 8000, 5500, 8600, 5900, C_POWER, C_BG, False);
        AddLine(D, 2050, 2150, 8000, 2150, C_RED, eMedium);
        AddLine(D, 2050, 4150, 8000, 4150, C_RED, eMedium);
        AddLine(D, 2050, 5700, 8000, 5700, C_RED, eMedium);
        AddText(D, 4300, 2250, 'BEAM 1 - DATUM 0 mm', C_TEXT);
        AddText(D, 4300, 4250, 'BEAM 2 - +100 mm', C_TEXT);
        AddText(D, 4300, 5800, 'BEAM 3 - +200 mm', C_TEXT);
        AddLine(D, 9600, 2150, 9600, 5700, C_TEXT, eSmall);
        AddLine(D, 9480, 2150, 9720, 2150, C_TEXT, eSmall);
        AddLine(D, 9480, 4150, 9720, 4150, C_TEXT, eSmall);
        AddLine(D, 9480, 5700, 9720, 5700, C_TEXT, eSmall);
        AddText(D, 9760, 3050, '100 mm', C_TEXT); AddText(D, 9760, 4900, '100 mm', C_TEXT);
        AddText(D, 3400, 1650, 'Align by sensor optical axes - not by carrier edges. Use slots/shims for pitch and yaw.', C_WARN);
        AddText(D, 3400, 1400, 'Reflectors need only a rigid mounting plate; blank FR-4 is one convenient option.', C_TEXT);
    Finally SchServer.ProcessControl.PostProcess(D, 'Mounting overview'); End;
    SaveSch(SD, OVERVIEW_SCH, 'OK professional overview');
End;

Function AddPMOS(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'Q1', 'DMP2035U', 'Diodes Incorporated', 'DMP2035U-7',
                       'SOT23', 'P-channel MOSFET reverse-current protection', X, Y);
    AddCompBody(C, X - 260, Y - 250, X + 260, Y + 250, C_ACCENT);
    AddCustomPin(C, X - 380, Y + 120, '2', 'S', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 380, Y - 120, '1', 'G', eRotate0, eElectricInput);
    AddCustomPin(C, X + 380, Y, '3', 'D', eRotate180, eElectricPassive);
    FinishCustomComp(Doc, C); Result := C;
End;

Procedure BuildProfessionalPower;
Var SD : IServerDocument; D : ISch_Document;
    J, F, Q, Buck, MCU : ISch_Component;
Begin
    SD := OpenSch(POWER_SCH); If SD = Nil Then Begin PLog('ERROR open power'); Exit; End;
    PrepareSheet(SD, 'POWER AND CONTROL', 'GBS-01', '02');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Power sheet V3');
    Try
        AddSheetHeading(D, '01', '12 V POWER AND ESP32 CONTROL',
            'Certified external 12 V adapter; protected sensor rail and 5 V buck for the socketed ESP32.');

        AddText(D, 650, 6800, 'DIRECT POWER PATH', C_POWER);
        J := AddPowerTerminal(D, 1050, 6100);
        F := AddTwoPinBare(D, 'F', 'F1', '1.1 A PTC', 'Bourns', 'MF-MSMF110-2',
                           'F1812', 'Resettable 12 V input fuse', 2450, 6220);
        Q := AddPMOS(D, 3900, 6100);
        Buck := AddThreePinBlock(D, 'A2', '5 V BUCK', 'Murata', 'OKI-78SR-5/1.5-W36-C',
                                 'SIP3_BUCK', '12 V to regulated 5 V DC/DC module', 5700, 6100,
                                 '1', 'VIN', '2', 'GND', '3', 'VOUT');

        { The main energy path is deliberately drawn, not hidden behind labels. }
        ConnectPins(D,J,'1',F,'1'); ConnectPins(D,F,'2',Q,'2'); ConnectPins(D,Q,'3',Buck,'1');
        AddNetLabelCoord(D,FindPin(Q,'3').Location.X,FindPin(Q,'3').Location.Y,'12V_SENSOR',eRotate0);
        PowerCompPin(D,J,'2','GND',1,ePowerGndSignal);
        PowerCompPin(D,Q,'1','GND',-1,ePowerGndSignal);
        PowerCompPin(D,Buck,'2','GND',-1,ePowerGndSignal);
        PowerCompPin(D,Buck,'3','5V_LOGIC',1,ePowerBar);

        AddText(D, 2200, 5350, 'SURGE AND BULK PROTECTION', C_POWER);
        AddTwoPin(D, 'D', 'D1', 'SMBJ18A', 'Littelfuse', 'SMBJ18A', 'SMB',
                  '18 V TVS suppressor', 3000, 4850, '12V_FUSED', 'GND');
        AddTwoPin(D, 'C', 'C1', '470uF / 25V', 'Panasonic', 'EEU-FR1E471', 'CAP_RADIAL_10MM',
                  'Protected 12 V bulk capacitor', 4300, 4850, '12V_SENSOR', 'GND');
        AddTwoPin(D, 'C', 'C5', '470uF / 10V', 'Panasonic', 'EEU-FR1A471', 'CAP_RADIAL_10MM',
                  'ESP32 Wi-Fi peak-current reservoir', 5700, 4850, '5V_LOGIC', 'GND');
        AddNetLabelCoord(D,FindPin(F,'2').Location.X,FindPin(F,'2').Location.Y,'12V_FUSED',eRotate0);

        AddText(D, 650, 3900, 'SOCKETED CONTROLLER', C_POWER);
        MCU := AddESP32(D, 5400, 2600);
        PowerCompPin(D, MCU, '30', '5V_LOGIC', -1, ePowerBar);
        PowerCompPin(D, MCU, '1', '3V3', -1, ePowerBar);
        PowerCompPin(D, MCU, '2', 'GND', -1, ePowerGndSignal);
        LabelCompPin(D, MCU, '7', 'BEAM1_GPIO32', -1); LabelCompPin(D, MCU, '8', 'BEAM2_GPIO33', -1); LabelCompPin(D, MCU, '9', 'BEAM3_GPIO34', -1);
        LabelCompPin(D, MCU, '5', 'LED_GREEN_GPIO25', 1); LabelCompPin(D, MCU, '4', 'LED_RED_GPIO26', 1); LabelCompPin(D, MCU, '3', 'LED_AMBER_GPIO27', 1);
        LabelCompPin(D, MCU, '11', 'BUZZER_GPIO14', 1); LabelCompPin(D, MCU, '12', 'BUTTON_GPIO13', 1);

        AddText(D, 700, 1050, 'J1 reuses the same 5.08 mm terminal-block family as the field I/O. No mains voltage is present.', C_TEXT);
        AddText(D, 700, 820, 'DRAFT: verify the exact ESP32 DevKit, DC/DC module, terminal block and pad numbering before PCB manufacture.', C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'Power sheet V3'); End;
    SaveSch(SD, POWER_SCH, 'OK professional power V3');
End;

Procedure AddBeamChannel(D, N, Y, GPIOName, JRef, RLed, URef, DRef, RPull, RSeries, CRef);
Var C : ISch_Component; S, A, Raw : String;
Begin
    S := 'BEAM' + IntToStr(N) + '_SIG'; A := 'BEAM' + IntToStr(N) + '_LED_A'; Raw := 'BEAM' + IntToStr(N) + '_RAW';
    AddText(D, 700, Y + 620, 'BEAM ' + IntToStr(N), C_POWER);
    C := AddThreePinBlock(D, JRef, 'SENSOR ' + IntToStr(N), 'Phoenix Contact', '1729131', 'TERM_3_508',
                          '12 V / 0 V / NPN signal terminal', 1400, Y,
                          '1', '12V', '2', '0V', '3', 'SIG');
    LabelCompPin(D, C, '1', '12V_SENSOR', -1); LabelCompPin(D, C, '2', 'GND', -1); LabelCompPin(D, C, '3', S, 1);
    AddTwoPin(D, 'R', RLed, '2.2k', 'Yageo', 'RC0805FR-072K2L', 'R0805', 'Optocoupler LED resistor', 3100, Y + 180, '12V_SENSOR', A);
    C := AddFourPinOpto(D, URef, 4550, Y);
    LabelCompPin(D, C, '1', A, -1); LabelCompPin(D, C, '2', S, -1);
    LabelCompPin(D, C, '3', 'GND', 1); LabelCompPin(D, C, '4', Raw, 1);
    AddTwoPin(D, 'D', DRef, '1N4148W', 'Nexperia', '1N4148W', 'SOD123', 'Optocoupler reverse clamp', 4550, Y - 620, S, A);
    AddTwoPin(D, 'R', RPull, '10k', 'Yageo', 'RC0805FR-0710KL', 'R0805', 'GPIO pull-up', 6200, Y + 280, '3V3', Raw);
    AddTwoPin(D, 'R', RSeries, '1k', 'Yageo', 'RC0805FR-071KL', 'R0805', 'GPIO series resistor', 7900, Y + 120, Raw, GPIOName);
    AddTwoPin(D, 'C', CRef, '100nF', 'Murata', 'GRM21BR71H104KA01L', 'C0805', 'GPIO noise filter', 7900, Y - 520, GPIOName, 'GND');
    AddText(D, 9000, Y + 80, 'LOW = CLEAR', C_GREEN);
    AddText(D, 9000, Y - 180, 'HIGH/OPEN = UNSAFE', C_WARN);
End;

Procedure BuildProfessionalBeams;
Var SD : IServerDocument; D : ISch_Document;
Begin
    SD := OpenSch(BEAMS_SCH); If SD = Nil Then Begin PLog('ERROR open beams'); Exit; End;
    PrepareSheet(SD, 'BEAM INPUTS', 'GBS-02', '03');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Beam sheet');
    Try
        AddSheetHeading(D, '02', 'THREE FAIL-SAFE SENSOR INPUTS', 'NPN Light-ON sensors: current must flow for CLEAR; open or unpowered channels are unsafe.');
        AddBeamChannel(D, 1, 6000, 'BEAM1_GPIO32', 'J2', 'R5', 'U2', 'D2', 'R6', 'R7', 'C2');
        AddBeamChannel(D, 2, 4050, 'BEAM2_GPIO33', 'J3', 'R8', 'U3', 'D3', 'R9', 'R10', 'C3');
        AddBeamChannel(D, 3, 2100, 'BEAM3_GPIO34', 'J4', 'R11', 'U4', 'D4', 'R12', 'R13', 'C4');
        AddText(D, 700, 920, 'Firmware earns GREEN only after all three inputs remain LOW continuously for 500 ms.', C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'Beam sheet'); End;
    SaveSch(SD, BEAMS_SCH, 'OK professional beams');
End;

Function AddFourPinTerminal(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'J5', 'STATUS OUTPUT', 'Phoenix Contact', '1729144', 'TERM_4_508', 'Status LED terminal', X, Y);
    AddCompBody(C, X - 300, Y - 360, X + 300, Y + 360, C_ACCENT);
    AddCustomPin(C, X - 420, Y + 240, '1', 'GREEN', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y + 80, '2', 'RED', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y - 80, '3', 'AMBER', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y - 240, '4', 'GND', eRotate0, eElectricPower);
    FinishCustomComp(Doc, C); Result := C;
End;

Function AddNPN(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'Q2', 'MMBT2222A', 'Diodes Incorporated', 'MMBT2222A-7-F', 'SOT23', 'Buzzer low-side transistor', X, Y);
    AddCompBody(C, X - 250, Y - 250, X + 250, Y + 250, C_ACCENT);
    AddCustomPin(C, X - 370, Y, '1', 'B', eRotate0, eElectricInput);
    AddCustomPin(C, X + 370, Y + 130, '3', 'C', eRotate180, eElectricOpenCollector);
    AddCustomPin(C, X + 370, Y - 130, '2', 'E', eRotate180, eElectricPower);
    FinishCustomComp(Doc, C); Result := C;
End;

Procedure BuildProfessionalUI;
Var SD : IServerDocument; D : ISch_Document; C : ISch_Component;
Begin
    SD := OpenSch(UI_SCH); If SD = Nil Then Begin PLog('ERROR open UI'); Exit; End;
    PrepareSheet(SD, 'STATUS AND ALERTS', 'GBS-03', '04');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'UI sheet');
    Try
        AddSheetHeading(D, '03', 'STATUS INDICATORS AND ALERTS', 'Green=CLEAR only; red=BLOCKED; amber=BOOT, FAULT, or UNKNOWN.');
        AddText(D, 750, 6600, 'REMOTE STATUS LEDS', C_POWER);
        AddTwoPin(D, 'R', 'R14', '330R', 'Yageo', 'RC0805FR-07330RL', 'R0805', 'Green LED current limit', 1800, 6100, 'LED_GREEN_GPIO25', 'LED_GREEN_OUT');
        AddTwoPin(D, 'R', 'R15', '330R', 'Yageo', 'RC0805FR-07330RL', 'R0805', 'Red LED current limit', 1800, 5400, 'LED_RED_GPIO26', 'LED_RED_OUT');
        AddTwoPin(D, 'R', 'R16', '330R', 'Yageo', 'RC0805FR-07330RL', 'R0805', 'Amber LED current limit', 1800, 4700, 'LED_AMBER_GPIO27', 'LED_AMBER_OUT');
        C := AddFourPinTerminal(D, 3900, 5400);
        LabelCompPin(D, C, '1', 'LED_GREEN_OUT', -1); LabelCompPin(D, C, '2', 'LED_RED_OUT', -1);
        LabelCompPin(D, C, '3', 'LED_AMBER_OUT', -1); LabelCompPin(D, C, '4', 'GND', -1);

        AddText(D, 5600, 6600, 'AUDIBLE ALERT', C_POWER);
        AddTwoPin(D, 'R', 'R17', '1k', 'Yageo', 'RC0805FR-071KL', 'R0805', 'Buzzer base resistor', 6500, 6100, 'BUZZER_GPIO14', 'BUZZER_BASE');
        C := AddNPN(D, 7900, 6100);
        LabelCompPin(D, C, '1', 'BUZZER_BASE', -1); LabelCompPin(D, C, '2', 'GND', 1); LabelCompPin(D, C, '3', 'BUZZER_LOW', 1);
        AddTwoPin(D, 'R', 'BZ1', 'CPT-9019S', 'CUI Devices', 'CPT-9019S-SMT-TR', 'BUZZER_9X9', '3 V magnetic transducer', 7900, 5100, '3V3', 'BUZZER_LOW');
        AddTwoPin(D, 'D', 'D5', '1N4148W', 'Nexperia', '1N4148W', 'SOD123', 'Buzzer flyback clamp', 7900, 4400, 'BUZZER_LOW', '3V3');

        AddText(D, 750, 3300, 'ALIGNMENT / TEST', C_POWER);
        C := NewCustomComp(D, 'SW1', 'ALIGN / TEST', 'Omron', 'B3FS-1000P', 'SW_SMD_6X6', 'Momentary test switch', 2100, 2700);
        AddCompBody(C, 1850, 2500, 2350, 2900, C_ACCENT);
        AddCustomPin(C, 1730, 2700, '1', 'GPIO', eRotate0, eElectricPassive); AddCustomPin(C, 2470, 2700, '2', 'GND', eRotate180, eElectricPassive);
        FinishCustomComp(D, C); LabelCompPin(D, C, '1', 'BUTTON_GPIO13', -1); LabelCompPin(D, C, '2', 'GND', 1);
        AddText(D, 750, 1050, 'ADVISORY ONLY - no relay, motor, or garage-door actuation connection is provided.', C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'UI sheet'); End;
    SaveSch(SD, UI_SCH, 'OK professional UI');
End;

Procedure BuildAllProfessionalSchematics;
Begin
    BuildProfessionalOverview; BuildProfessionalPower; BuildProfessionalBeams; BuildProfessionalUI;
End;

Function FindPCBNet(Board, NetName) : IPCB_Net;
Var It : IPCB_BoardIterator; N : IPCB_Net;
Begin
    Result := Nil; It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do Begin If N.Name = NetName Then Begin Result := N; Break; End; N := It.NextPCBObject; End;
    Board.BoardIterator_Destroy(It);
End;

Function EnsurePCBNet(Board, NetName) : IPCB_Net;
Var N : IPCB_Net;
Begin
    N := FindPCBNet(Board, NetName);
    If N = Nil Then Begin N := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
        N.Name := NetName; N.ConnectsVisible := True; Board.AddPCBObject(N); End;
    Result := N;
End;

Function FindPCBComponent(Board, RefDes) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil; It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do Begin If (C.SourceDesignator = RefDes) Or (C.Name.Text = RefDes) Then Begin Result := C; Break; End; C := It.NextPCBObject; End;
    Board.BoardIterator_Destroy(It);
End;

Procedure AssignPCBPad(Board, RefDes, PadName, NetName);
Var C : IPCB_Component; P : IPCB_Pad; N : IPCB_Net;
Begin
    C := FindPCBComponent(Board, RefDes); If C = Nil Then Exit;
    P := C.GetState_PadByName(PadName); If P = Nil Then Exit;
    N := EnsurePCBNet(Board, NetName); P.Net := N; N.RegisterWithGroupWarehouse(P);
End;

Procedure AddRoutedTrack(Board, X1, Y1, X2, Y2, WidthMM, ALayer, N);
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    T.X1 := X1; T.Y1 := Y1; T.X2 := X2; T.Y2 := Y2; T.Width := MMsToCoord(WidthMM);
    T.Layer := ALayer; T.Net := N; Board.AddPCBObject(T);
End;

Procedure AddRoutedVia(Board, X, Y, N);
Var V : IPCB_Via;
Begin
    V := PCBServer.PCBObjectFactory(eViaObject, eNoDimension, eCreate_Default);
    V.X := X; V.Y := Y; V.Size := MMsToCoord(0.70); V.HoleSize := MMsToCoord(0.35);
    V.LowLayer := eTopLayer; V.HighLayer := eBottomLayer; V.Net := N; Board.AddPCBObject(V);
End;

Procedure RoutePCBNetLane(Board, NetName, LaneMM, Index);
Var N : IPCB_Net; It : IPCB_BoardIterator; P : IPCB_Pad; Lane, BranchY, MinY, MaxY : TCoord;
    Count : Integer; WidthMM : Double;
Begin
    N := FindPCBNet(Board, NetName); If N = Nil Then Exit;
    Lane := MMsToCoord(LaneMM); Count := 0; MinY := 2147483647; MaxY := -2147483647;
    If (NetName = 'GND') Or (NetName = 'VBUS') Or (NetName = '5V_LOGIC') Or (NetName = '12V_SENSOR') Then WidthMM := 0.60 Else WidthMM := 0.30;
    It := Board.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(ePadObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); P := It.FirstPCBObject;
    While P <> Nil Do
    Begin
        If P.Net = N Then
        Begin
            Inc(Count); BranchY := P.Y + MMsToCoord((((Index + Count) Mod 9) - 4) * 0.11);
            AddRoutedTrack(Board, P.X, P.Y, P.X, BranchY, WidthMM, eTopLayer, N);
            AddRoutedTrack(Board, P.X, BranchY, Lane, BranchY, WidthMM, eTopLayer, N);
            AddRoutedVia(Board, Lane, BranchY, N);
            If BranchY < MinY Then MinY := BranchY; If BranchY > MaxY Then MaxY := BranchY;
        End;
        P := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
    If Count > 1 Then AddRoutedTrack(Board, Lane, MinY, Lane, MaxY, WidthMM, eBottomLayer, N);
End;

Procedure AssignAllControllerNets(Board);
Begin
    AssignPCBPad(Board,'J1','1','GND'); AssignPCBPad(Board,'J1','2','VBUS'); AssignPCBPad(Board,'J1','3','CC1');
    AssignPCBPad(Board,'J1','4','CC2'); AssignPCBPad(Board,'J1','5','VBUS'); AssignPCBPad(Board,'J1','6','GND');
    AssignPCBPad(Board,'R1','1','CC1'); AssignPCBPad(Board,'R1','2','GND'); AssignPCBPad(Board,'R2','1','CC2'); AssignPCBPad(Board,'R2','2','GND');
    AssignPCBPad(Board,'F1','1','VBUS'); AssignPCBPad(Board,'F1','2','VBUS_FUSED');
    AssignPCBPad(Board,'D1','1','VBUS_FUSED'); AssignPCBPad(Board,'D1','2','GND');
    AssignPCBPad(Board,'Q1','1','GND'); AssignPCBPad(Board,'Q1','2','VBUS_FUSED'); AssignPCBPad(Board,'Q1','3','5V_LOGIC');
    AssignPCBPad(Board,'C1','1','5V_LOGIC'); AssignPCBPad(Board,'C1','2','GND');
    AssignPCBPad(Board,'A2','1','5V_LOGIC'); AssignPCBPad(Board,'A2','2','GND'); AssignPCBPad(Board,'A2','3','12V_SENSOR');
    AssignPCBPad(Board,'C5','1','12V_SENSOR'); AssignPCBPad(Board,'C5','2','GND');
    AssignPCBPad(Board,'A1','30','5V_LOGIC'); AssignPCBPad(Board,'A1','1','3V3'); AssignPCBPad(Board,'A1','2','GND');
    AssignPCBPad(Board,'A1','7','BEAM1_GPIO32'); AssignPCBPad(Board,'A1','8','BEAM2_GPIO33'); AssignPCBPad(Board,'A1','9','BEAM3_GPIO34');
    AssignPCBPad(Board,'A1','5','LED_GREEN_GPIO25'); AssignPCBPad(Board,'A1','4','LED_RED_GPIO26'); AssignPCBPad(Board,'A1','3','LED_AMBER_GPIO27');
    AssignPCBPad(Board,'A1','11','BUZZER_GPIO14'); AssignPCBPad(Board,'A1','12','BUTTON_GPIO13');

    AssignPCBPad(Board,'J2','1','12V_SENSOR'); AssignPCBPad(Board,'J2','2','GND'); AssignPCBPad(Board,'J2','3','BEAM1_SIG');
    AssignPCBPad(Board,'R5','1','12V_SENSOR'); AssignPCBPad(Board,'R5','2','BEAM1_LED_A');
    AssignPCBPad(Board,'U2','1','BEAM1_LED_A'); AssignPCBPad(Board,'U2','2','BEAM1_SIG'); AssignPCBPad(Board,'U2','3','GND'); AssignPCBPad(Board,'U2','4','BEAM1_RAW');
    AssignPCBPad(Board,'D2','1','BEAM1_SIG'); AssignPCBPad(Board,'D2','2','BEAM1_LED_A');
    AssignPCBPad(Board,'R6','1','3V3'); AssignPCBPad(Board,'R6','2','BEAM1_RAW'); AssignPCBPad(Board,'R7','1','BEAM1_RAW'); AssignPCBPad(Board,'R7','2','BEAM1_GPIO32');
    AssignPCBPad(Board,'C2','1','BEAM1_GPIO32'); AssignPCBPad(Board,'C2','2','GND');

    AssignPCBPad(Board,'J3','1','12V_SENSOR'); AssignPCBPad(Board,'J3','2','GND'); AssignPCBPad(Board,'J3','3','BEAM2_SIG');
    AssignPCBPad(Board,'R8','1','12V_SENSOR'); AssignPCBPad(Board,'R8','2','BEAM2_LED_A');
    AssignPCBPad(Board,'U3','1','BEAM2_LED_A'); AssignPCBPad(Board,'U3','2','BEAM2_SIG'); AssignPCBPad(Board,'U3','3','GND'); AssignPCBPad(Board,'U3','4','BEAM2_RAW');
    AssignPCBPad(Board,'D3','1','BEAM2_SIG'); AssignPCBPad(Board,'D3','2','BEAM2_LED_A');
    AssignPCBPad(Board,'R9','1','3V3'); AssignPCBPad(Board,'R9','2','BEAM2_RAW'); AssignPCBPad(Board,'R10','1','BEAM2_RAW'); AssignPCBPad(Board,'R10','2','BEAM2_GPIO33');
    AssignPCBPad(Board,'C3','1','BEAM2_GPIO33'); AssignPCBPad(Board,'C3','2','GND');

    AssignPCBPad(Board,'J4','1','12V_SENSOR'); AssignPCBPad(Board,'J4','2','GND'); AssignPCBPad(Board,'J4','3','BEAM3_SIG');
    AssignPCBPad(Board,'R11','1','12V_SENSOR'); AssignPCBPad(Board,'R11','2','BEAM3_LED_A');
    AssignPCBPad(Board,'U4','1','BEAM3_LED_A'); AssignPCBPad(Board,'U4','2','BEAM3_SIG'); AssignPCBPad(Board,'U4','3','GND'); AssignPCBPad(Board,'U4','4','BEAM3_RAW');
    AssignPCBPad(Board,'D4','1','BEAM3_SIG'); AssignPCBPad(Board,'D4','2','BEAM3_LED_A');
    AssignPCBPad(Board,'R12','1','3V3'); AssignPCBPad(Board,'R12','2','BEAM3_RAW'); AssignPCBPad(Board,'R13','1','BEAM3_RAW'); AssignPCBPad(Board,'R13','2','BEAM3_GPIO34');
    AssignPCBPad(Board,'C4','1','BEAM3_GPIO34'); AssignPCBPad(Board,'C4','2','GND');

    AssignPCBPad(Board,'R14','1','LED_GREEN_GPIO25'); AssignPCBPad(Board,'R14','2','LED_GREEN_OUT');
    AssignPCBPad(Board,'R15','1','LED_RED_GPIO26'); AssignPCBPad(Board,'R15','2','LED_RED_OUT');
    AssignPCBPad(Board,'R16','1','LED_AMBER_GPIO27'); AssignPCBPad(Board,'R16','2','LED_AMBER_OUT');
    AssignPCBPad(Board,'J5','1','LED_GREEN_OUT'); AssignPCBPad(Board,'J5','2','LED_RED_OUT'); AssignPCBPad(Board,'J5','3','LED_AMBER_OUT'); AssignPCBPad(Board,'J5','4','GND');
    AssignPCBPad(Board,'R17','1','BUZZER_GPIO14'); AssignPCBPad(Board,'R17','2','BUZZER_BASE');
    AssignPCBPad(Board,'Q2','1','BUZZER_BASE'); AssignPCBPad(Board,'Q2','2','GND'); AssignPCBPad(Board,'Q2','3','BUZZER_LOW');
    AssignPCBPad(Board,'BZ1','1','3V3'); AssignPCBPad(Board,'BZ1','2','BUZZER_LOW'); AssignPCBPad(Board,'D5','1','BUZZER_LOW'); AssignPCBPad(Board,'D5','2','3V3');
    AssignPCBPad(Board,'SW1','1','BUTTON_GPIO13'); AssignPCBPad(Board,'SW1','2','GND');
End;

Procedure RouteAllControllerNets(Board);
Begin
    RoutePCBNetLane(Board,'GND',1.2,1); RoutePCBNetLane(Board,'VBUS',2.8,2); RoutePCBNetLane(Board,'VBUS_FUSED',4.4,3);
    RoutePCBNetLane(Board,'5V_LOGIC',6.0,4); RoutePCBNetLane(Board,'12V_SENSOR',7.6,5); RoutePCBNetLane(Board,'3V3',9.2,6);
    RoutePCBNetLane(Board,'CC1',10.8,7); RoutePCBNetLane(Board,'CC2',12.4,8);
    RoutePCBNetLane(Board,'BEAM1_SIG',14.0,9); RoutePCBNetLane(Board,'BEAM1_LED_A',15.6,10); RoutePCBNetLane(Board,'BEAM1_RAW',17.2,11); RoutePCBNetLane(Board,'BEAM1_GPIO32',18.8,12);
    RoutePCBNetLane(Board,'BEAM2_SIG',20.4,13); RoutePCBNetLane(Board,'BEAM2_LED_A',22.0,14); RoutePCBNetLane(Board,'BEAM2_RAW',23.6,15); RoutePCBNetLane(Board,'BEAM2_GPIO33',25.2,16);
    RoutePCBNetLane(Board,'BEAM3_SIG',26.8,17); RoutePCBNetLane(Board,'BEAM3_LED_A',28.4,18); RoutePCBNetLane(Board,'BEAM3_RAW',30.0,19); RoutePCBNetLane(Board,'BEAM3_GPIO34',31.6,20);
    RoutePCBNetLane(Board,'LED_GREEN_GPIO25',33.2,21); RoutePCBNetLane(Board,'LED_GREEN_OUT',34.8,22); RoutePCBNetLane(Board,'LED_RED_GPIO26',36.4,23); RoutePCBNetLane(Board,'LED_RED_OUT',38.0,24);
    RoutePCBNetLane(Board,'LED_AMBER_GPIO27',39.6,25); RoutePCBNetLane(Board,'LED_AMBER_OUT',41.2,26); RoutePCBNetLane(Board,'BUZZER_GPIO14',42.8,27); RoutePCBNetLane(Board,'BUZZER_BASE',44.4,28);
    RoutePCBNetLane(Board,'BUZZER_LOW',46.0,29); RoutePCBNetLane(Board,'BUTTON_GPIO13',47.6,30);
End;

Procedure UpgradeControllerPCBConnectivity;
Var SD : IServerDocument; B : IPCB_Board;
Begin
    Client.StartServer('PCB'); SD := Client.OpenDocument('PCB', PCB_PATH);
    If SD = Nil Then Begin PLog('ERROR open PCB'); Exit; End;
    Client.ShowDocument(SD); SD.Focus; B := PCBServer.GetCurrentPCBBoard; If B = Nil Then Exit;
    PCBServer.PreProcess;
    Try AssignAllControllerNets(B); RouteAllControllerNets(B); Finally PCBServer.PostProcess; End;
    B.ViewManager_FullUpdate; SD.Modified := True;
    If SD.DoFileSave('PCB Binary 6.0') Then PLog('OK PCB nets and copper routing') Else PLog('ERROR saving routed PCB');
End;

Procedure AuditOneSch(APath, SheetName, R);
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator; O : ISch_GraphicalObject;
    CntComp, CntWire, CntLabel, CntImage : Integer;
Begin
    CntComp := 0; CntWire := 0; CntLabel := 0; CntImage := 0;
    SD := OpenSch(APath); If SD = Nil Then Begin R.Add(SheetName + '|ERROR_OPEN'); Exit; End;
    D := SchServer.GetCurrentSchDocument;
    It := D.SchIterator_Create; It.SetState_FilterAll; O := It.FirstSchObject;
    While O <> Nil Do
    Begin
        If O.ObjectId = eSchComponent Then Inc(CntComp);
        If O.ObjectId = eWire Then Inc(CntWire);
        If O.ObjectId = eNetLabel Then Inc(CntLabel);
        If O.ObjectId = eImage Then Inc(CntImage);
        O := It.NextSchObject;
    End;
    D.SchIterator_Destroy(It);
    R.Add(SheetName + '|AREA_COLOR=' + IntToStr(D.AreaColor) + '|IMAGES=' + IntToStr(CntImage) +
          '|COMPONENTS=' + IntToStr(CntComp) + '|WIRES=' + IntToStr(CntWire) + '|NETLABELS=' + IntToStr(CntLabel));
End;

Procedure AuditProfessionalProject;
Var R : TStringList; SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator;
    O : IPCB_Primitive; P : IPCB_Pad; Nets, CopperTracks, Vias, Pads, NettedPads : Integer;
Begin
    R := TStringList.Create;
    Try
        AuditOneSch(OVERVIEW_SCH, '00_OVERVIEW', R); AuditOneSch(POWER_SCH, '01_POWER', R);
        AuditOneSch(BEAMS_SCH, '02_BEAMS', R); AuditOneSch(UI_SCH, '03_UI', R);
        SD := Client.OpenDocument('PCB', PCB_PATH); If SD = Nil Then Begin R.Add('PCB|ERROR_OPEN'); Exit; End;
        Client.ShowDocument(SD); SD.Focus; B := PCBServer.GetCurrentPCBBoard;
        Nets := 0; CopperTracks := 0; Vias := 0; Pads := 0; NettedPads := 0;
        It := B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
        O := It.FirstPCBObject; While O <> Nil Do Begin Inc(Nets); O := It.NextPCBObject; End; B.BoardIterator_Destroy(It);
        It := B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eTrackObject)); It.AddFilter_LayerSet(MkSet(eTopLayer, eBottomLayer)); It.AddFilter_Method(eProcessAll);
        O := It.FirstPCBObject; While O <> Nil Do Begin Inc(CopperTracks); O := It.NextPCBObject; End; B.BoardIterator_Destroy(It);
        It := B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eViaObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
        O := It.FirstPCBObject; While O <> Nil Do Begin Inc(Vias); O := It.NextPCBObject; End; B.BoardIterator_Destroy(It);
        It := B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(ePadObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
        P := It.FirstPCBObject; While P <> Nil Do Begin Inc(Pads); If P.Net <> Nil Then Inc(NettedPads); P := It.NextPCBObject; End; B.BoardIterator_Destroy(It);
        R.Add('PCB|NETS=' + IntToStr(Nets) + '|COPPER_TRACKS=' + IntToStr(CopperTracks) + '|VIAS=' + IntToStr(Vias) +
              '|PADS=' + IntToStr(Pads) + '|NETTED_PADS=' + IntToStr(NettedPads));
        R.SaveToFile(ROOT + 'ProfessionalAudit.txt'); PLog('OK professional audit');
    Finally R.Free; End;
End;

Procedure OpenProfessionalOverview;
Var SD : IServerDocument;
Begin
    SD := OpenSch(OVERVIEW_SCH); If SD = Nil Then Exit;
    ResetParameters; AddStringParameter('Action', 'All'); RunProcess('Sch:Zoom');
End;

Procedure OpenProfessionalPCB;
Var SD : IServerDocument;
Begin
    SD := Client.OpenDocument('PCB', PCB_PATH); If SD = Nil Then Exit;
    Client.ShowDocument(SD); SD.Focus; ResetParameters; AddStringParameter('Action', 'All'); RunProcess('PCB:Zoom');
End;

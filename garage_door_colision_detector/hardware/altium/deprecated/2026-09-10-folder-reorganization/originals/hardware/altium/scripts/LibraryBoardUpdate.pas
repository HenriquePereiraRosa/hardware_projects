{ Schematic-only library repair. Uses the supplied ESP32 integrated-library source.
  Preserves the user's title block. Never edits or routes a PCB.
  Non-ESP32 footprint/STEP procurement remains explicitly pending. }

Const
    ROOT = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';
    TEMPLATE_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\template-source\SCH\ENERGY.SchDoc';
    OVERVIEW_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\00_Mounting_Overview.SchDoc';
    POWER_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\01_Power_Control.SchDoc';
    BEAMS_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\02_Beam_Inputs.SchDoc';
    UI_SCH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\03_UI_Outputs.SchDoc';
    PCB_PATH = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\GarageBeamSafety.PcbDoc';
    BUILD_LOG = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\SchematicRepair.log';
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
                    (OldO.ObjectId = eJunction) Or (OldO.ObjectId = eNoERC);
        { Keep only the low title-block labels from the source template.  Earlier
          versions accidentally retained every generated heading and note. }
        If OldO.ObjectId = eLabel Then
        Begin
            Lbl := OldO;
            RemoveIt := Lbl.Location.Y >= MilsToCoord(700);
        End;
        If (OldO.ObjectId = eRectangle) Or (OldO.ObjectId = eLine) Then
            RemoveIt := OldO.Location.Y > MilsToCoord(700);
        If RemoveIt Then Doc.UnRegisterSchObjectFromContainer(OldO);
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
    L.FontID := SchServer.FontManager.GetFontID(10,0,False,False,False,False,'Arial');
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
    L.Text := S; L.Color := C_WIRE; L.Orientation := eRotate0;
    L.FontID := SchServer.FontManager.GetFontID(9,0,False,False,False,False,'Arial');
    If Orient = eRotate180 Then L.Justification := eJustify_BottomRight Else L.Justification := eJustify_BottomLeft;
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
        P.Name := N; P.Text := V;
    P.OwnerPartId := 1; P.OwnerPartDisplayMode := 0; C.AddSchObject(P); End;
End;

Procedure AddFootprint(C, Name);
Begin
    { Do not invent library links. Actual ESP32 model link comes from SnapMagic. }
    AddCompParameter(C, 'Intended footprint', Name);
    AddCompParameter(C, 'CAD status', 'Symbol ready; footprint and STEP verification pending');
End;

Function CloneTemplateComp(TargetDoc, SeedDes, NewDes, NewValue, Manufacturer,
                           MPN, Footprint, Description, X, Y) : ISch_Component;
Var SSD : IServerDocument; SrcDoc : ISch_Document; It, CI : ISch_Iterator;
    Src, C : ISch_Component; O, OldO : ISch_GraphicalObject; P : ISch_Pin;
    DX, DY, Count, SumX, SumY : Integer;
Begin
    Result := Nil; SSD := OpenSch(TEMPLATE_SCH); If SSD = Nil Then Exit;
    SrcDoc := SchServer.GetCurrentSchDocument;
    It := SrcDoc.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    Src := It.FirstSchObject;
    While Src <> Nil Do Begin
        If Src.Designator.Text = SeedDes Then Begin
            C := Src.Replicate;
            CI := C.SchIterator_Create; CI.SetState_FilterAll; O := CI.FirstSchObject;
            Count := 0; SumX := 0; SumY := 0;
            While O <> Nil Do Begin
                OldO := O; O := CI.NextSchObject;
                If OldO.ObjectId = eImplementation Then C.RemoveSchObject(OldO);
                If OldO.ObjectId = eParameter Then OldO.IsHidden := True;
                If OldO.ObjectId = ePin Then Begin P := OldO;
                    SumX := SumX + P.Location.X - C.Location.X;
                    SumY := SumY + P.Location.Y - C.Location.Y; Inc(Count);
                End;
                If (OldO.ObjectId = ePin) Or (OldO.ObjectId = eLine) Or
                   (OldO.ObjectId = eRectangle) Or (OldO.ObjectId = ePolyline) Or
                   (OldO.ObjectId = eArc) Or (OldO.ObjectId = eParameter) Then Begin
                    OldO.Color := C_TEXT;
                    If OldO.ObjectId = eRectangle Then OldO.AreaColor := C_BG;
                End;
            End;
            C.SchIterator_Destroy(CI);
            If Count > 0 Then C.MoveToXY(MilsToCoord(X) - (SumX Div Count),MilsToCoord(Y) - (SumY Div Count));
            C.Designator.Text := NewDes; C.Comment.Text := NewValue;
            C.Designator.Color := C_TEXT; C.Comment.Color := C_TEXT;
            C.Comment.IsHidden := False;
            C.Designator.Location := Point(MilsToCoord(X-80),MilsToCoord(Y+170));
            C.Comment.Location := Point(MilsToCoord(X-140),MilsToCoord(Y-220));
            C.Designator.FontID := SchServer.FontManager.GetFontID(10,0,False,False,False,False,'Arial');
            C.Comment.FontID := C.Designator.FontID;
            C.LibReference := MPN; C.ComponentDescription := Description;
            AddCompParameter(C, 'Manufacturer', Manufacturer);
            AddCompParameter(C, 'Manufacturer Part Number', MPN);
            AddCompParameter(C, 'Symbol source', 'Conventional symbol reused from ENERGY.SchDoc');
            AddFootprint(C, Footprint);
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
    P.Location := Point(MilsToCoord(X), MilsToCoord(Y)); P.Orientation := (Orient + 2) Mod 4;
    P.Designator := No; P.Name := PinName; P.Electrical := Elec; P.Color := C_TEXT;
    P.PinLength := MilsToCoord(100); P.ShowName := True; P.ShowDesignator := True;
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
    C.Designator.FontID := SchServer.FontManager.GetFontID(10,0,False,False,False,False,'Arial'); C.Comment.FontID := C.Designator.FontID;
    C.Designator.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y + 300));
    C.Comment.Location := Point(MilsToCoord(X - 150), MilsToCoord(Y - 320));
    C.LibReference := MPN; C.ComponentDescription := Description;
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
    Client.ShowDocument(SD); SD.Focus; D := SchServer.GetCurrentSchDocument; D.GraphicallyInvalidate; SD.Modified := True;
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
    If (X1 = X2) And (Y1 = Y2) Then Exit;
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
    L.Location := Point(X, Y); L.Text := S; L.Color := C_WIRE; L.Orientation := eRotate0;
    L.FontID := SchServer.FontManager.GetFontID(9,0,False,False,False,False,'Arial');
    If Orient = eRotate180 Then L.Justification := eJustify_BottomRight Else L.Justification := eJustify_BottomLeft;
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
    If Side < 0 Then O := eRotate180 Else O := eRotate0;
    AddNetLabelCoord(Doc,Ex,P.Location.Y,NetName,O);
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
Var Seed : String; C : ISch_Component; L : ISch_Line;
Begin
    Seed := 'R4';
    If Kind = 'C' Then Seed := 'C6';
    If Kind = 'D' Then Seed := 'D1';
    If Kind = 'F' Then Begin
        C := NewCustomComp(Doc,RefDes,ValueText,Manufacturer,MPN,Footprint,Description,X,Y);
        AddCompBody(C,X-120,Y-60,X+120,Y+60,C_TEXT);
        AddCustomPin(C,X-250,Y,'1','',eRotate0,eElectricPassive);
        AddCustomPin(C,X+250,Y,'2','',eRotate180,eElectricPassive);
        L := SchServer.SchObjectFactory(eLine,eCreate_GlobalCopy);
        L.Location := Point(MilsToCoord(X-150),MilsToCoord(Y)); L.Corner := Point(MilsToCoord(X+150),MilsToCoord(Y));
        L.Color := C_TEXT; L.OwnerPartId := 1; C.AddSchObject(L);
        FinishCustomComp(Doc,C); Result := C;
    End Else Result := CloneTemplateComp(Doc,Seed,RefDes,ValueText,Manufacturer,MPN,Footprint,Description,X,Y);
End;

Function AddTwoPin(Doc, Kind, RefDes, ValueText, Manufacturer, MPN, Footprint,
                   Description, X, Y, Net1, Net2) : ISch_Component;
Var C : ISch_Component; Plus : ISch_Label; P : ISch_Pin;
Begin
    C := AddTwoPinBare(Doc,Kind,RefDes,ValueText,Manufacturer,MPN,Footprint,Description,X,Y);
    If (RefDes = 'C1') Or (RefDes = 'C5') Then Begin
        P := FindPin(C,'1');
        Plus := SchServer.SchObjectFactory(eLabel,eCreate_GlobalCopy);
        Plus.Location := Point(P.Location.X-MilsToCoord(100),P.Location.Y);
        Plus.Text := '+'; Plus.Color := C_TEXT; Plus.OwnerPartId := 1;
        C.AddSchObject(Plus);
        AddCompParameter(C,'Polarity','Pin 1 positive; pin 2 negative');
    End;
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


Procedure SymbolLine(C, X1, Y1, X2, Y2);
Var L : ISch_Line;
Begin
    L := SchServer.SchObjectFactory(eLine,eCreate_GlobalCopy);
    L.Location := Point(MilsToCoord(X1),MilsToCoord(Y1));
    L.Corner := Point(MilsToCoord(X2),MilsToCoord(Y2));
    L.Color := C_TEXT; L.LineWidth := eSmall; L.OwnerPartId := 1;
    C.AddSchObject(L);
End;

Procedure Arrow(C, X, Y, DX, DY);
Begin
    SymbolLine(C,X,Y,X+DX,Y+DY);
    SymbolLine(C,X+DX,Y+DY,X+DX-60,Y+DY);
    SymbolLine(C,X+DX,Y+DY,X+DX,Y+DY+60);
End;

Function AddFourPinOpto(Doc, RefDes, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc,RefDes,'LTV-817S','Lite-On','LTV-817S-TA1','SMD4','Phototransistor optocoupler',X,Y);
    AddCompBody(C,X-310,Y-280,X+310,Y+280,C_TEXT);
    AddCustomPin(C,X-440,Y+150,'1','A',eRotate0,eElectricPassive);
    AddCustomPin(C,X-440,Y-150,'2','K',eRotate0,eElectricPassive);
    AddCustomPin(C,X+440,Y-150,'3','E',eRotate180,eElectricPassive);
    AddCustomPin(C,X+440,Y+150,'4','C',eRotate180,eElectricOpenCollector);
    SymbolLine(C,X-340,Y+150,X-180,Y+150); SymbolLine(C,X-180,Y+150,X-180,Y+65);
    SymbolLine(C,X-240,Y+65,X-120,Y+65); SymbolLine(C,X-240,Y+65,X-180,Y-65);
    SymbolLine(C,X-120,Y+65,X-180,Y-65); SymbolLine(C,X-240,Y-65,X-120,Y-65);
    SymbolLine(C,X-180,Y-65,X-180,Y-150); SymbolLine(C,X-180,Y-150,X-340,Y-150);
    Arrow(C,X-60,Y+100,90,-90); Arrow(C,X-60,Y-10,90,-90);
    SymbolLine(C,X+140,Y-100,X+140,Y+100);
    SymbolLine(C,X+140,Y+60,X+250,Y+150); SymbolLine(C,X+250,Y+150,X+340,Y+150);
    Arrow(C,X+140,Y-60,110,-90); SymbolLine(C,X+250,Y-150,X+340,Y-150);
    FinishCustomComp(Doc,C); Result := C;
End;

Function AddESP32(Doc, X, Y) : ISch_Component;
Var SD : IServerDocument; L : ISch_Lib; Src,C : ISch_Component;
    It : ISch_Iterator; O : ISch_GraphicalObject;
Begin
    Result := Nil;
    SD := Client.OpenDocument('SCHLIB',ROOT+'lib\ESP32-DEVKITC-32E\ESP32-DEVKITC-32E.SchLib');
    Client.ShowDocument(SD); SD.Focus; L := SchServer.GetCurrentSchDocument;
    L.TransferComponentsPrimitivesBackFromEditor;
    It := L.SchLibIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    Src := It.FirstSchObject; L.SchIterator_Destroy(It);
    If Src = Nil Then Begin PLog('ERROR missing supplied ESP32 symbol'); Exit; End;
    C := Src.Replicate; C.MoveToXY(MilsToCoord(X),MilsToCoord(Y));
    C.CurrentPartID := 1; C.DisplayMode := 0;
    C.Designator.Text := 'A1'; C.Comment.Text := 'ESP32-DEVKITC-32E';
    C.Designator.Color := C_TEXT; C.Comment.Color := C_TEXT;
    C.Designator.Location := Point(MilsToCoord(X-450),MilsToCoord(Y+1120));
    C.Comment.Location := Point(MilsToCoord(X-450),MilsToCoord(Y-1200));
    It := C.SchIterator_Create; It.SetState_FilterAll; O := It.FirstSchObject;
    While O <> Nil Do Begin
        If (O.ObjectId = ePin) Or (O.ObjectId = eLine) Or
           (O.ObjectId = eRectangle) Or (O.ObjectId = ePolyline) Or
           (O.ObjectId = eArc) Or (O.ObjectId = eParameter) Then O.Color := C_TEXT;
        If O.ObjectId = eRectangle Then O.AreaColor := C_BG;
        O := It.NextSchObject;
    End;
    C.SchIterator_Destroy(It);
    AddCompParameter(C,'Manufacturer','Espressif Systems');
    AddCompParameter(C,'Manufacturer Part Number','ESP32-DevKitC-32E');
    AddCompParameter(C,'CAD status','Supplied SnapMagic symbol and linked native footprint');
    Doc.RegisterSchObjectInContainer(C); Result := C;
End;

Procedure BuildProfessionalOverview;
Var SD : IServerDocument; D : ISch_Document;
Begin
    SD := OpenSch(OVERVIEW_SCH); If SD = Nil Then Begin PLog('ERROR open overview'); Exit; End;
    PrepareSheet(SD, 'MOUNTING OVERVIEW', 'GBS-00', '01');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Mounting overview');
    Try
        AddSheetHeading(D, '00', 'TWO-WALL INSTALLATION / AC-DC POWER', 'Functional installation drawing, NOT to scale. Sensor part, pitch and enclosure dimensions are NOT released.');
        AddRect(D,850,3100,3550,6750,C_ACCENT,C_PANEL,True);
        AddRect(D,7700,3100,10400,6750,C_POWER,C_PANEL,True);
        AddText(D,1050,6500,'BOX A - RECEIVERS + CONTROLLER',C_ACCENT);
        AddText(D,7900,6500,'BOX B - EMITTERS',C_POWER);
        AddText(D,1050,6250,'Separate locked optical rail and short PCB',C_TEXT);
        AddText(D,7900,6250,'Powered heads; no second ESP32',C_TEXT);
        AddText(D,1050,5900,'RX3   <-- optical face',C_TEXT);
        AddText(D,1050,5200,'RX2   <-- optical face',C_TEXT);
        AddText(D,1050,4500,'RX1   <-- optical face',C_TEXT);
        AddText(D,7900,5900,'TX3   emission towards RX3',C_TEXT);
        AddText(D,7900,5200,'TX2   emission towards RX2',C_TEXT);
        AddText(D,7900,4500,'TX1   emission towards RX1',C_TEXT);
        AddLine(D,3550,5900,7700,5900,C_RED,eMedium);
        AddLine(D,3550,5200,7700,5200,C_RED,eMedium);
        AddLine(D,3550,4500,7700,4500,C_RED,eMedium);
        AddText(D,4200,6100,'OPTICAL SPAN: MEASURE ON SITE',C_WARN);
        AddText(D,4200,5550,'3 independent through-beams',C_TEXT);
        AddText(D,4200,4850,'No mirror / no cross-garage power cable',C_TEXT);
        AddText(D,4200,4000,'Head spacing: confirm 10 vs 100 mm',C_WARN);
        AddText(D,1050,3850,'12 V protection -> receivers + RGB lamp',C_TEXT);
        AddText(D,1050,3550,'Murata 5 V buck -> ESP32 DevKitC V4',C_TEXT);
        AddText(D,7900,3850,'12 V input -> fused protected distribution',C_TEXT);
        AddText(D,7900,3550,'Receiver and emitter grounds stay separate',C_TEXT);
        AddLine(D,2050,2600,2050,3100,C_POWER,eMedium);
        AddLine(D,9000,2600,9000,3100,C_POWER,eMedium);
        AddText(D,2350,2800,'12 V DC ONLY',C_POWER);
        AddText(D,9300,2800,'12 V DC ONLY',C_POWER);
        AddRect(D,850,1500,3550,2600,C_ACCENT,C_BG,False);
        AddRect(D,7700,1500,10400,2600,C_POWER,C_BG,False);
        AddText(D,1050,2350,'PS1 - MEAN WELL GST25E12-P1J',C_ACCENT);
        AddText(D,7900,2350,'PS2 - MEAN WELL GST25E12-P1J',C_POWER);
        AddText(D,1050,2100,'External intact AC/DC adapter: 12 V / 2.08 A',C_TEXT);
        AddText(D,7900,2100,'External intact AC/DC adapter: 12 V / 2.08 A',C_TEXT);
        AddText(D,1050,1800,'Installed mains outlet -> adapter AC plug',C_TEXT);
        AddText(D,7900,1800,'Installed mains outlet -> adapter AC plug',C_TEXT);
        AddText(D,4200,2350,'5.5 x 2.1 mm centre-positive DC plug',C_TEXT);
        AddText(D,4200,2070,'Panel jack -> existing 2-way terminal',C_TEXT);
        AddText(D,4200,1800,'Adapters OUTSIDE sensor boxes',C_WARN);
        AddText(D,850,1180,'NO MAINS ON EITHER CUSTOM PCB. PS1/PS2 are external equipment, not PCB footprints. Keep adapters intact.',C_WARN);
        AddText(D,850,900,'Optical heads need exact manufacturer CAD + brackets + cable clearances. J2/J3/J4/J6 are terminals, NOT sensors.',C_TEXT);
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
    J, F, Q, Buck, MCU, JP : ISch_Component;
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
        Q := AddTwoPinBare(D,'D','D6','SS34','Vishay','SS34-E3/57T','SMC','Series reverse-polarity Schottky diode',3900,6220);
        Buck := AddThreePinBlock(D, 'A2', '5 V BUCK', 'Murata', 'OKI-78SR-5/1.5-W36-C',
                                 'SIP3_BUCK', '12 V to regulated 5 V DC/DC module', 5700, 6100,
                                 '1', 'VIN', '2', 'GND', '3', 'VOUT');

        { The main energy path is deliberately drawn, not hidden behind labels. }
        ConnectPins(D,J,'1',F,'1'); ConnectPins(D,F,'2',Q,'1'); ConnectPins(D,Q,'2',Buck,'1');
        AddNetLabelCoord(D,FindPin(Q,'2').Location.X,FindPin(Q,'2').Location.Y,'12V_SENSOR',eRotate0);
        PowerCompPin(D,J,'2','GND',1,ePowerGndSignal);

        PowerCompPin(D,Buck,'2','GND',-1,ePowerGndSignal);
        PowerCompPin(D,Buck,'3','5V_LOGIC',1,ePowerBar);

        AddText(D, 2200, 5350, 'SURGE AND BULK PROTECTION', C_POWER);
        AddTwoPin(D, 'D', 'D1', 'SMBJ15A', 'Littelfuse', 'SMBJ15A', 'SMB',
                  '15 V TVS suppressor - cathode to positive rail', 3000, 4850, 'GND', '12V_SENSOR');
        AddTwoPin(D, 'C', 'C1', '470uF / 25V', 'Panasonic', 'EEU-FR1E471', 'CAP_RADIAL_D10_P5',
                  'Protected 12 V bulk capacitor', 4300, 4850, '12V_SENSOR', 'GND');
        AddTwoPin(D, 'C', 'C5', '470uF / 10V', 'Panasonic', 'EEU-FR1A471', 'CAP_RADIAL_D8_P3.5',
                  'ESP32 Wi-Fi peak-current reservoir', 5700, 4850, '5V_LOGIC', 'GND');
        AddNetLabelCoord(D,FindPin(F,'2').Location.X,FindPin(F,'2').Location.Y,'12V_FUSED',eRotate0);

        AddText(D, 650, 3900, 'SOCKETED CONTROLLER', C_POWER);
        MCU := AddESP32(D, 5400, 2600);
        PowerCompPin(D, MCU, 'J2_19', '5V_MCU', -1, ePowerBar);
        PowerCompPin(D, MCU, 'J2_1', '3V3', -1, ePowerBar);
        PowerCompPin(D, MCU, 'J2_14', 'GND', -1, ePowerGndSignal);
        LabelCompPin(D, MCU, 'J2_7', 'BEAM1_GPIO32', -1); LabelCompPin(D, MCU, 'J2_8', 'BEAM2_GPIO33', -1); LabelCompPin(D, MCU, 'J2_5', 'BEAM3_GPIO34', -1);
        LabelCompPin(D, MCU, 'J2_9', 'LED_GREEN_GPIO25', -1); LabelCompPin(D, MCU, 'J2_10', 'LED_RED_GPIO26', -1); LabelCompPin(D, MCU, 'J2_11', 'LED_BLUE_GPIO27', -1);
        LabelCompPin(D, MCU, 'J2_12', 'RESERVED_GPIO14', -1); LabelCompPin(D, MCU, 'J2_15', 'BUTTON_GPIO13', -1);

        PowerCompPin(D,MCU,'J3_1','GND',1,ePowerGndSignal);
        PowerCompPin(D,MCU,'J3_7','GND',1,ePowerGndSignal);
        LabelCompPin(D,MCU,'J2_6','BEAM4_GPIO35',-1);
        JP := NewCustomComp(D,'JP1','REMOVE FOR USB','Samtec','TSW-102-07-G-S','HEADER_1X02_2.54','External 5 V disconnect; fit shunt only without USB',1800,2700);
        AddCustomPin(JP,1500,2700,'1','5V',eRotate0,eElectricPassive);
        AddCustomPin(JP,2100,2700,'2','MCU',eRotate180,eElectricPassive);
        AddCompBody(JP,1610,2650,1690,2750,C_TEXT); AddCompBody(JP,1910,2650,1990,2750,C_TEXT);
        SymbolLine(JP,1650,2820,1950,2820);
        FinishCustomComp(D,JP);
        LabelCompPin(D,JP,'1','5V_LOGIC',-1); LabelCompPin(D,JP,'2','5V_MCU',1);
        AddText(D,700,1500,'USB programming: remove JP1 before connecting USB power. Never power from USB and 5V header together.',C_WARN);
        AddText(D,700,1270,'12V_SENSOR must measure at least 10.8 V for EX-L291. Regulated 12 V adapter only; not 24 V input.',C_WARN);
        AddText(D, 700, 1050, 'D6 replaces the incorrectly wired old Q1 stage. No mains voltage is present. 3V3 comes from A1.', C_TEXT);
        AddText(D, 700, 820, 'SCHEMATIC REVIEW: ESP32 uses supplied library. Other footprint/STEP models remain pending; PCB is unchanged.', C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'Power sheet V3'); End;
    SaveSch(SD, POWER_SCH, 'OK professional power V3');
End;

Procedure AddBeamChannel(D, N, Y, GPIOName, JRef, RLed, URef, DRef, RPull, RSeries, CRef);
Var J,R,U,RP,RS,CF : ISch_Component; S,A,Raw : String;
Begin
    S := 'BEAM'+IntToStr(N)+'_SIG'; A := 'BEAM'+IntToStr(N)+'_LED_A'; Raw := 'BEAM'+IntToStr(N)+'_RAW';
    AddText(D,700,Y+640,'BEAM '+IntToStr(N),C_POWER);
    J := AddThreePinBlock(D,JRef,'SENSOR '+IntToStr(N),'Phoenix Contact','1729131','TERM_3_508','12V / GND / NPN signal terminal',1400,Y,'1','12V','2','0V','3','SIG');
    R := AddTwoPinBare(D,'R',RLed,'2.2k','Yageo','RC0805FR-072K2L','0805','Optocoupler LED current limit',2900,Y+150);
    U := AddFourPinOpto(D,URef,4400,Y);
    RP := AddTwoPinBare(D,'R',RPull,'10k','Yageo','RC0805FR-0710KL','0805','Pull-up earns unsafe if optocoupler is off',6100,Y+650);
    RS := AddTwoPinBare(D,'R',RSeries,'1k','Yageo','RC0805FR-071KL','0805','Input current limit',7100,Y+150);
    CF := AddTwoPinBare(D,'C',CRef,'100nF','Murata','GRM21BR71H104KA01L','0805','Input RC filter',8250,Y-250);
    LabelCompPin(D,J,'1','12V_SENSOR',-1); LabelCompPin(D,J,'2','GND',-1);
    LabelCompPin(D,R,'1','12V_SENSOR',-1);
    ConnectPins(D,R,'2',U,'1'); ConnectPins(D,J,'3',U,'2');
    AddNetLabelCoord(D,FindPin(U,'2').Location.X,FindPin(U,'2').Location.Y,S,eRotate180);
    LabelCompPin(D,U,'3','GND',1);
    ConnectPins(D,U,'4',RS,'1'); ConnectPins(D,RP,'2',RS,'1');
    LabelCompPin(D,RP,'1','3V3',-1);
    AddNetLabelCoord(D,FindPin(RS,'1').Location.X,FindPin(RS,'1').Location.Y,Raw,eRotate180);
    ConnectPins(D,RS,'2',CF,'2'); LabelCompPin(D,RS,'2',GPIOName,1);
    LabelCompPin(D,CF,'1','GND',1);
    AddNetLabelCoord(D,FindPin(U,'1').Location.X,FindPin(U,'1').Location.Y,A,eRotate180);
    AddTwoPin(D,'D',DRef,'1N4148W','Nexperia','1N4148W','SOD123','Reverse clamp: A to SIG; K to opto LED anode',4400,Y-540,S,A);
    AddText(D,9100,Y+160,'LOW = CLEAR',C_GREEN);
    AddText(D,9100,Y-80,'HIGH / OPEN = UNSAFE',C_WARN);
End;

Procedure BuildProfessionalBeams;
Var SD : IServerDocument; D : ISch_Document;
Begin
    SD := OpenSch(BEAMS_SCH); If SD = Nil Then Begin PLog('ERROR open beams'); Exit; End;
    PrepareSheet(SD, 'BEAM INPUTS', 'GBS-02', '03');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'Beam sheet');
    Try
        AddSheetHeading(D, '02', 'FOUR CURRENT-PROVING SENSOR INPUTS', 'NPN Light-ON sensors: current must flow for CLEAR; open or unpowered channels are unsafe.');
        AddBeamChannel(D, 1, 6100, 'BEAM1_GPIO32', 'J2', 'R5', 'U2', 'D2', 'R6', 'R7', 'C2');
        AddBeamChannel(D, 2, 4650, 'BEAM2_GPIO33', 'J3', 'R8', 'U3', 'D3', 'R9', 'R10', 'C3');
        AddBeamChannel(D, 3, 3200, 'BEAM3_GPIO34', 'J4', 'R11', 'U4', 'D4', 'R12', 'R13', 'C4');
        AddBeamChannel(D,4,1750,'BEAM4_GPIO35','J6','R18','U5','D7','R19','R20','C6');
        AddText(D,700,790,'Enable only installed beams. LOW for 500 ms earns CLEAR. Signal-to-GND shorts / stuck-ON sensors are NOT detected.',C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'Beam sheet'); End;
    SaveSch(SD, BEAMS_SCH, 'OK professional beams');
End;

Function AddFourPinTerminal(Doc, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc, 'J5', '12V RGB STRIP', 'Phoenix Contact', '1729144', 'TERM_4_508', 'Common-anode analogue RGB strip; NOT addressable', X, Y);
    AddCompBody(C, X - 300, Y - 360, X + 300, Y + 360, C_ACCENT);
    AddCustomPin(C, X - 420, Y + 240, '1', '+12V', eRotate0, eElectricPower);
    AddCustomPin(C, X - 420, Y + 80, '2', 'R-', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y - 80, '3', 'G-', eRotate0, eElectricPassive);
    AddCustomPin(C, X - 420, Y - 240, '4', 'B-', eRotate0, eElectricPassive);
    FinishCustomComp(Doc, C); Result := C;
End;

Function AddRgbMosfet(Doc, RefDes, X, Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C := NewCustomComp(Doc,RefDes,'AO3400A','Alpha and Omega Semiconductor','AO3400A','Package_TO_SOT_SMD:SOT-23','30V NMOS; Rds(on) specified at Vgs=2.5V; limit load to 250mA/channel',X,Y);
    AddCompParameter(C,'Datasheet','https://www.aosmd.com/sites/default/files/res/datasheets/AO3400A.pdf');
    AddCompParameter(C,'3D asset','lib/upstream-kicad/SOT-23.step; downloaded, native link pending');
    AddCustomPin(C,X-350,Y,'1','G',eRotate0,eElectricInput);
    AddCustomPin(C,X+350,Y+180,'3','D',eRotate180,eElectricPassive);
    AddCustomPin(C,X+350,Y-180,'2','S',eRotate180,eElectricPassive);
    SymbolLine(C,X-250,Y,X-100,Y); SymbolLine(C,X-100,Y-160,X-100,Y+160);
    SymbolLine(C,X-50,Y+70,X-50,Y+160); SymbolLine(C,X-50,Y-40,X-50,Y+40);
    SymbolLine(C,X-50,Y-160,X-50,Y-70);
    SymbolLine(C,X-50,Y+120,X+100,Y+120); SymbolLine(C,X+100,Y+120,X+100,Y+180);
    SymbolLine(C,X+100,Y+180,X+250,Y+180);
    SymbolLine(C,X-50,Y-120,X+100,Y-120); SymbolLine(C,X+100,Y-120,X+100,Y-180);
    SymbolLine(C,X+100,Y-180,X+250,Y-180);
    Arrow(C,X+100,Y,-150,0); SymbolLine(C,X+100,Y,X+100,Y-180);
    FinishCustomComp(Doc,C); Result := C;
End;

Procedure AddRgbChannel(D, QRef, GateRef, PullRef, Colour, GpioNet, X, Y);
Var C, R : ISch_Component;
Begin
    R := AddTwoPinBare(D,'R',GateRef,'100R','Yageo','RC0805FR-07100RL','R0805','MOSFET gate series resistor',X,Y);
    LabelCompPin(D,R,'1',GpioNet,-1);
    C := AddRgbMosfet(D,QRef,X+1800,Y);
    LabelCompPin(D,C,'1','RGB_'+Colour+'_GATE',-1);
    ConnectPins(D,R,'2',C,'1');
    LabelCompPin(D,C,'2','GND',1); LabelCompPin(D,C,'3','RGB_'+Colour+'_LOW',1);
    AddTwoPin(D,'R',PullRef,'100k','Yageo','RC0805FR-07100KL','R0805','Gate-source pull-down; off while ESP32 resets',X,Y-550,'RGB_'+Colour+'_GATE','GND');
End;

Procedure FormatRgbResistors(D);
Var It, CI : ISch_Iterator; C : ISch_Component; O, OldO : ISch_GraphicalObject; P1, P2 : ISch_Pin; X, Y : Integer;
Begin
    It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    C := It.FirstSchObject;
    While C <> Nil Do Begin
        If Copy(C.Designator.Text,1,1) = 'R' Then Begin
            P1 := FindPin(C,'1'); P2 := FindPin(C,'2');
            X := CoordToMils((P1.Location.X+P2.Location.X) Div 2); Y := CoordToMils(P1.Location.Y);
            CI := C.SchIterator_Create; CI.SetState_FilterAll; O := CI.FirstSchObject;
            While O <> Nil Do Begin
                OldO := O; O := CI.NextSchObject;
                If (OldO.ObjectId <> ePin) And (OldO.ObjectId <> eParameter) And (OldO.ObjectId <> eImplementation) Then C.RemoveSchObject(OldO);
            End;
            C.SchIterator_Destroy(CI);
            AddCompBody(C,X-120,Y-70,X+120,Y+70,C_TEXT);
            C.Comment.Location := Point(MilsToCoord(X-90),MilsToCoord(Y-40));
            C.Comment.FontID := SchServer.FontManager.GetFontID(9,0,False,False,False,False,'Arial');
            C.Designator.Location := Point(MilsToCoord(X-80),MilsToCoord(Y+180));
        End;
        C := It.NextSchObject;
    End;
    D.SchIterator_Destroy(It);
End;

Procedure BuildProfessionalUI;
Var SD : IServerDocument; D : ISch_Document; C : ISch_Component;
Begin
    SD := OpenSch(UI_SCH); If SD = Nil Then Begin PLog('ERROR open UI'); Exit; End;
    PrepareSheet(SD, 'VISIBLE RGB STATUS', 'GBS-03', '04');
    SD.Focus; D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D, 'UI sheet');
    Try
        AddSheetHeading(D, '03', 'VISIBLE RGB STATUS - NO BUZZER', 'Steady green=CLEAR; steady red=BLOCKED; flashing amber=BOOT / FAULT / UNKNOWN. Dark never means clear.');
        AddText(D, 750, 6600, '3.3V GATE DRIVE / 12V LED LOAD', C_POWER);
        AddRgbChannel(D,'Q2','R14','R17','RED','LED_RED_GPIO26',1800,6100);
        AddRgbChannel(D,'Q3','R15','R21','GREEN','LED_GREEN_GPIO25',1800,4900);
        AddRgbChannel(D,'Q4','R16','R23','BLUE','LED_BLUE_GPIO27',1800,3700);
        C := AddFourPinTerminal(D,8500,5600);
        LabelCompPin(D,C,'1','12V_RGB_FUSED',-1); LabelCompPin(D,C,'2','RGB_RED_LOW',-1);
        LabelCompPin(D,C,'3','RGB_GREEN_LOW',-1); LabelCompPin(D,C,'4','RGB_BLUE_LOW',-1);
        AddTwoPin(D,'F','F2','0.5A FAST','Littelfuse','0451.500MRL','FUSE_2410','RGB cable branch fuse; verify fault clearing with selected supply',7600,6500,'12V_SENSOR','12V_RGB_FUSED');
        AddText(D,6100,4700,'J5 PINOUT CHANGED: 1=+12V  2=R-  3=G-  4=B-',C_WARN);
        AddText(D,6100,4400,'15cm of 12V 5050 RGB strip, 60 LED/m; common anode.',C_TEXT);
        AddText(D,6100,4100,'Strip MUST include its own current limiting. No bare power LEDs.',C_TEXT);
        AddText(D,6100,3800,'Short local cable; 250mA/channel maximum design load.',C_TEXT);
        AddText(D,6100,3500,'GPIO14 is spare. Lamp current/failure sensing is NOT provided.',C_WARN);

        AddText(D, 5600, 2900, 'ALIGNMENT / TEST BUTTON ON LEFT', C_POWER);
        C := NewCustomComp(D, 'SW1', 'ALIGN / TEST', 'Omron', 'B3FS-1000P', 'SW_SMD_6X6', 'Momentary test switch', 2100, 2700);
        SymbolLine(C,1830,2700,1970,2700); SymbolLine(C,2230,2700,2370,2700);
        SymbolLine(C,1970,2700,2220,2850);
        SymbolLine(C,2010,2940,2190,2940); SymbolLine(C,2100,2940,2100,3010);
        AddCustomPin(C, 1730, 2700, '1', 'GPIO', eRotate0, eElectricPassive); AddCustomPin(C, 2470, 2700, '2', 'GND', eRotate180, eElectricPassive);
        FinishCustomComp(D, C); LabelCompPin(D, C, '1', 'BUTTON_GPIO13', -1); LabelCompPin(D, C, '2', 'GND', 1);
        AddTwoPin(D,'R','R22','10k','Yageo','RC0805FR-0710KL','0805','Test button external pull-up',3800,2700,'3V3','BUTTON_GPIO13');
        FormatRgbResistors(D);
        AddText(D, 750, 1050, 'ADVISORY ONLY - no relay, motor, or garage-door actuation connection is provided.', C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D, 'UI sheet'); End;
    SaveSch(SD, UI_SCH, 'OK professional UI');
End;

Procedure AuditSheet(APath);
Var SD : IServerDocument; D : ISch_Document; It,CI : ISch_Iterator;
    O,P : ISch_GraphicalObject; C : ISch_Component; S : TStringList; I : Integer;
Begin
    SD := OpenSch(APath); D := SchServer.GetCurrentSchDocument;
    S := TStringList.Create;
    It := D.SchIterator_Create; It.SetState_FilterAll; O := It.FirstSchObject;
    While O <> Nil Do Begin
        If O.ObjectId = eSchComponent Then Begin
            C := O; S.Add('COMP|'+C.Designator.Text+'|'+C.Comment.Text+'|'+C.LibReference);
            CI := C.SchIterator_Create; CI.SetState_FilterAll; P := CI.FirstSchObject;
            While P <> Nil Do Begin
                If P.ObjectId = ePin Then S.Add('PIN|'+C.Designator.Text+'|'+P.Designator+'|'+P.Name+'|'+IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y));
                If P.ObjectId = eParameter Then S.Add('PARAM|'+C.Designator.Text+'|'+P.Name+'|'+P.Text);
                If P.ObjectId = eImplementation Then S.Add('MODEL|'+C.Designator.Text+'|'+P.ModelType+'|'+P.ModelName);
                P := CI.NextSchObject;
            End;
            C.SchIterator_Destroy(CI);
        End;
        If O.ObjectId = eNetLabel Then S.Add('NET|'+O.Text+'|'+IntToStr(O.Location.X)+'|'+IntToStr(O.Location.Y));
        If O.ObjectId = ePowerObject Then S.Add('NET|'+O.Text+'|'+IntToStr(O.Location.X)+'|'+IntToStr(O.Location.Y));
        If O.ObjectId = eWire Then Begin
            For I := 1 To O.VerticesCount Do S.Add('WIRE|'+IntToStr(I)+'|'+IntToStr(O.GetState_Vertex(I).X)+'|'+IntToStr(O.GetState_Vertex(I).Y));
        End;
        O := It.NextSchObject;
    End;
    D.SchIterator_Destroy(It); S.SaveToFile(APath+'.audit.txt'); S.Free;
End;

Procedure BuildAllProfessionalSchematics;
Begin
    BuildProfessionalPower; BuildProfessionalBeams; BuildProfessionalUI;
    AuditSheet(POWER_SCH); AuditSheet(BEAMS_SCH); AuditSheet(UI_SCH);
    PLog('OK: three schematic sheets rebuilt; PCB NOT modified');
End;

Procedure UpdateRgbIndicatorOnly;
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator; L : ISch_NetLabel;
Begin
    { Back up sheets before running. Only UI is rebuilt; power gets two net renames.
      Beam sheet and PCB are deliberately untouched. }
    SD := OpenSch(POWER_SCH); If SD = Nil Then Exit;
    D := SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D,'RGB net names');
    Try
        It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetLabel));
        L := It.FirstSchObject;
        While L <> Nil Do Begin
            If L.Text = 'LED_AMBER_GPIO27' Then L.Text := 'LED_BLUE_GPIO27';
            If L.Text = 'BUZZER_GPIO14' Then L.Text := 'RESERVED_GPIO14';
            L := It.NextSchObject;
        End;
        D.SchIterator_Destroy(It);
    Finally SchServer.ProcessControl.PostProcess(D,'RGB net names'); End;
    SaveSch(SD,POWER_SCH,'OK RGB net names');
    BuildProfessionalUI;
    AuditSheet(POWER_SCH); AuditSheet(UI_SCH);
    PLog('OK RGB update: buzzer removed; J5 pinout changed; beam sheet and PCB untouched. CAD links still pending.');
End;

{ September 2026 targeted optical hardware update. The legacy procedures above
  are helpers only: UpdateOpticalHardware does NOT rebuild the power/UI sheets. }
Procedure SensorLog(S);
Var L : TStringList;
Begin
    L := TStringList.Create;
    If FileExists(ROOT+'SensorNativeUpdate.log') Then L.LoadFromFile(ROOT+'SensorNativeUpdate.log');
    L.Add(S); L.SaveToFile(ROOT+'SensorNativeUpdate.log'); L.Free;
End;

Function FindSchRef(D, RefDes) : ISch_Component;
Var It : ISch_Iterator; C : ISch_Component;
Begin
    Result := Nil; It := D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    C := It.FirstSchObject;
    While C <> Nil Do Begin
        If C.Designator.Text = RefDes Then Begin Result := C; Break; End;
        C := It.NextSchObject;
    End;
    D.SchIterator_Destroy(It);
End;

Procedure TerminalModelLink(C);
Var M : ISch_Implementation;
Begin
    M := C.AddSchImplementation;
    M.ModelName := 'PHOENIX_1715734_MKDS_3_508'; M.ModelType := 'PCBLIB';
    M.IsCurrent := True;
    M.AddDataFileLink(M.ModelName, ROOT+'lib\OpticalHardware.PcbLib', 'PCBLIB');
    M.MapAsString := '(1:1),(2:2),(3:3)';
    AddCompParameter(C,'Manufacturer','Phoenix Contact');
    AddCompParameter(C,'Manufacturer Part Number','1715734');
    AddCompParameter(C,'Package','MKDS 1,5/3-5,08');
    AddCompParameter(C,'Intended footprint',M.ModelName);
    AddCompParameter(C,'Datasheet','https://www.phoenixcontact.com/en-us/products/printed-circuit-board-terminal-mkds-15-3-508-1715734');
    AddCompParameter(C,'CAD status','Native pin-mapped footprint; KiCad STEP; verify physical sample before fabrication');
    C.LibReference := 'PHOENIX_1715734';
End;

Procedure RepairSensorTerminal(D, RefDes, BeamNo);
Var C : ISch_Component; It : ISch_Iterator; O, OldO : ISch_GraphicalObject;
    P1,P2,P3 : ISch_Pin; X,Y : Integer;
Begin
    C := FindSchRef(D,RefDes); If C = Nil Then Exit;
    P1:=FindPin(C,'1'); P2:=FindPin(C,'2'); P3:=FindPin(C,'3');
    X := CoordToMils(C.Location.X); Y := CoordToMils(C.Location.Y);
    { Retain electrical pins and their coordinates, so existing wires stay connected. }
    It:=C.SchIterator_Create; It.SetState_FilterAll; O:=It.FirstSchObject;
    While O<>Nil Do Begin
        OldO:=O; O:=It.NextSchObject;
        If (OldO.ObjectId=eRectangle) Or (OldO.ObjectId=eLine) Or
           (OldO.ObjectId=ePolyline) Or (OldO.ObjectId=eImplementation) Then C.RemoveSchObject(OldO);
    End;
    C.SchIterator_Destroy(It);
    AddCompBody(C,X-280,Y-220,X+280,Y+220,C_TEXT);
    { Contact bars, rather than a block misleadingly labelled SENSOR. }
    SymbolLine(C,X-290,Y+210,X-290,Y+90);
    SymbolLine(C,X-290,Y-90,X-290,Y-210);
    SymbolLine(C,X+290,Y+60,X+290,Y-60);
    P1.Name := '+12V'; P2.Name := '0V'; P3.Name := 'OUT';
    C.Comment.Text := '1715734 / RX'+IntToStr(BeamNo);
    C.Comment.Location := Point(MilsToCoord(X-300),MilsToCoord(Y-380));
    TerminalModelLink(C);
    AddCompParameter(C,'Wiring','1 brown +12V; 2 blue 0V; 3 black NPN output');
    AddCompParameter(C,'Description','PCB cable terminal for external E3Z-T61-D receiver; NOT the optical head');
    SensorLog('SCH '+RefDes+' 1715734 pins retained; footprint link added');
End;

Function OpticalHead(D, RefDes, IsTX, X, Y) : ISch_Component;
Var C : ISch_Component; ModelName, Role : String;
Begin
    If IsTX Then Begin ModelName:='E3Z-T61-L 2M'; Role:='EMITTER'; End
    Else Begin ModelName:='E3Z-T61-D 2M'; Role:='RECEIVER / NPN LIGHT-ON'; End;
    C:=NewCustomComp(D,RefDes,ModelName,'Omron',ModelName,'EXTERNAL CABLED HEAD',Role,X,Y);
    C.ComponentKind := eComponentKind_Mechanical;
    C.ComponentDescription := Role+'; purchased in E3Z-T61 2M pair; frame-mounted, not PCB-mounted';
    C.Designator.Location := Point(MilsToCoord(X-350),MilsToCoord(Y+400));
    C.Comment.Location := Point(MilsToCoord(X-350),MilsToCoord(Y-450));
    AddCompBody(C,X-360,Y-330,X+360,Y+330,C_ACCENT);
    AddCustomPin(C,X-560,Y+200,'BN','+V',eRotate0,eElectricPassive);
    AddCustomPin(C,X-560,Y-200,'BU','0V',eRotate0,eElectricPassive);
    If Not IsTX Then AddCustomPin(C,X+560,Y-200,'BK','OUT',eRotate180,eElectricPassive);
    { Functional optical diode symbol. Internal amplifier is integrated in the head. }
    SymbolLine(C,X-120,Y+100,X+120,Y+100);
    SymbolLine(C,X-120,Y+100,X,Y-100); SymbolLine(C,X+120,Y+100,X,Y-100);
    SymbolLine(C,X-120,Y-100,X+120,Y-100);
    SymbolLine(C,X,Y+100,X,Y+200); SymbolLine(C,X,Y-100,X,Y-200);
    If IsTX Then Begin Arrow(C,X+100,Y+60,170,120); Arrow(C,X+100,Y-50,170,120); End
    Else Begin Arrow(C,X-270,Y+240,150,-120); Arrow(C,X-270,Y+130,150,-120); End;
    AddCompParameter(C,'Order as pair','E3Z-T61 2M');
    AddCompParameter(C,'Body dimensions mm','10.8 W x 31 H x 20 D');
    AddCompParameter(C,'Mounting','Two M3 holes at 25.4 mm centres; optical face toward opposite upright');
    AddCompParameter(C,'Cable','Integral 2 m cable; BN brown +V / BU blue 0V / receiver BK black OUT');
    AddCompParameter(C,'Supply','12-24 VDC nominal; use regulated 12 V');
    AddCompParameter(C,'Datasheet','https://industrial.omron.eu/en/products/E3Z-T61-2M');
    AddCompParameter(C,'3D download','https://download.ia.omron.com/download/zip/ST/OEE/E3Z_T61/');
    AddCompParameter(C,'CAD status','Editable native device symbol. Manufacturer STEP download blocked; no substitute body');
    AddCompParameter(C,'Intended footprint','NONE - external wired device');
    AddCompParameter(C,'BOM note','Buy one E3Z-T61 2M pair per TX/RX pair, not two pairs');
    FinishCustomComp(D,C); Result:=C;
End;

Procedure BuildOpticalHeadSheet;
Var SD : IServerDocument; D : ISch_Document; TX,RX : ISch_Component; N,Y : Integer; JRef : String;
Begin
    SD:=OpenSch(ROOT+'04_Optical_Heads.SchDoc'); D:=SchServer.GetCurrentSchDocument;
    PrepareSheet(SD,'External optical heads and cable wiring','GBS-OPT-04','05');
    SetDocParameter(D,'SheetTotal','05');
    AddSheetHeading(D,'04','OMRON E3Z-T61 - THROUGH-BEAM HEADS','2.4 m nominal span. External head components are Mechanical BOM items: no fictional PCB pads.');
    For N:=1 To 4 Do Begin
        Y:=6100-(N-1)*1350;
        TX:=OpticalHead(D,'TX'+IntToStr(N),True,2000,Y);
        RX:=OpticalHead(D,'RX'+IntToStr(N),False,6100,Y);
        If N=4 Then AddText(D,650,Y+530,'CHANNEL 4 - OPTIONAL / DNP',C_ACCENT)
        Else AddText(D,650,Y+530,'CHANNEL '+IntToStr(N),C_ACCENT);
        AddWire(D,1440,Y+200,1050,Y+200); AddNetLabel(D,1050,Y+200,'TX_12V',eRotate180);
        AddWire(D,1440,Y-200,1050,Y-200); AddNetLabel(D,1050,Y-200,'TX_0V',eRotate180);
        AddLine(D,2450,Y,5400,Y,C_WARN,eSmall);
        AddLine(D,5400,Y,5270,Y+90,C_WARN,eSmall); AddLine(D,5400,Y,5270,Y-90,C_WARN,eSmall);
        AddText(D,3050,Y-180,'MODULATED IR / NO REFLECTOR',C_WARN);
        If N=1 Then JRef:='J2'; If N=2 Then JRef:='J3'; If N=3 Then JRef:='J4'; If N=4 Then JRef:='J6';
        AddText(D,8050,Y+250,JRef+' ON PCB (sheet 02)',C_ACCENT);
        AddText(D,8050,Y+70,'1 brown +12V / 2 blue 0V',C_TEXT);
        AddText(D,8050,Y-110,'3 black OUT; LIGHT-ON',C_TEXT);
        AddText(D,8050,Y-310,'10.8 x 31 x 20 mm; 2 m cable',C_TEXT);
        AddWire(D,5540,Y+200,5000,Y+200); AddNetLabel(D,5000,Y+200,'12V_SENSOR',eRotate180);
        AddWire(D,5540,Y-200,5000,Y-200); AddNetLabel(D,5000,Y-200,'GND',eRotate180);
        AddWire(D,6660,Y-200,6900,Y-200);
        AddNetLabel(D,6900,Y-200,'BEAM'+IntToStr(N)+'_SIG',eRotate0);
        If N=4 Then Begin
            AddCompParameter(TX,'Populate','Optional channel 4'); AddCompParameter(RX,'Populate','Optional channel 4');
        End;
    End;
    AddText(D,650,1120,'Emitter supply: separate certified 12 V adapter + fused DC distribution. No ESP32 needed on emitter side.',C_TEXT);
    AddText(D,650,930,'Unpowered / broken wire / blocked = UNSAFE. Static NPN output cannot detect every stuck-ON or short-to-0V fault.',C_WARN);
    SaveSch(SD,ROOT+'04_Optical_Heads.SchDoc','Optical heads saved');
    SensorLog('SAVED native external-head schematic');
End;

Procedure ExportOpticalSchLib; Forward;

Procedure FinishOpticalQuality;
Var SD : IServerDocument; B : IPCB_Board; It,PI : IPCB_BoardIterator;
    GI : IPCB_GroupIterator; C : IPCB_Component; O : IPCB_Primitive; P : IPCB_Pad;
    D : ISch_Document; W : IWorkspace; Proj : IProject; L : TStringList;
    N : Integer; RefDes : String;
Begin
    BuildOpticalHeadSheet;
    ExportOpticalSchLib;
    SD:=Client.OpenDocument('PCB',PCB_PATH); Client.ShowDocument(SD); SD.Focus;
    B:=PCBServer.GetCurrentPCBBoard; L:=TStringList.Create;
    PCBServer.PreProcess;
    Try
        It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject));
        It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
        While C<>Nil Do Begin
            RefDes:=C.SourceDesignator;
            If (RefDes='J2') Or (RefDes='J3') Or (RefDes='J4') Or (RefDes='J6') Then Begin
                C.MoveByXY(MMsToCoord(15)-C.X,0);
                C.Name.Text:=RefDes; C.Name.XLocation:=MMsToCoord(21); C.Name.YLocation:=C.Y+MMsToCoord(4);
                L.Add('COMP|'+RefDes+'|'+C.Pattern+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y)));
                For N:=1 To 3 Do Begin
                    P:=C.GetState_PadByName(IntToStr(N));
                    If P<>Nil Then L.Add('PAD|'+RefDes+'|'+P.Name+'|'+P.Net.Name+'|'+FloatToStr(CoordToMMs(P.X))+'|'+FloatToStr(CoordToMMs(P.Y))+'|'+FloatToStr(CoordToMMs(P.HoleSize)));
                End;
                GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(eComponentBodyObject)); O:=GI.FirstPCBObject;
                While O<>Nil Do Begin L.Add('STEPBODY|'+RefDes); O:=GI.NextPCBObject; End;
                C.GroupIterator_Destroy(GI);
            End;
            C:=It.NextPCBObject;
        End;
        B.BoardIterator_Destroy(It);
        { Clear only the literal legacy placeholder text; actual labels are preserved. }
        It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eTextObject));
        It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); O:=It.FirstPCBObject;
        While O<>Nil Do Begin
            If (O.Text='Designator1') Or (O.Text='Comment') Then O.Text:='';
            O:=It.NextPCBObject;
        End;
        B.BoardIterator_Destroy(It);
    Finally PCBServer.PostProcess; End;
    B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
    L.SaveToFile(ROOT+'OpticalHardwarePCB.audit.txt'); L.Free;
    AuditSheet(BEAMS_SCH); AuditSheet(ROOT+'04_Optical_Heads.SchDoc');
    W:=GetWorkspace; Proj:=W.DM_GetProjectFromPath(ROOT+'GarageBeamSafety.PrjPcb');
    Proj.DM_AddSourceDocument(ROOT+'04_Optical_Heads.SchDoc');
    Proj.DM_AddSourceDocument(ROOT+'lib\OpticalHardware.SchLib');
    Proj.DM_AddSourceDocument(ROOT+'lib\OpticalHardware.PcbLib');
    OpenSch(ROOT+'04_Optical_Heads.SchDoc');
    SensorLog('FINISH: native audits exported; terminal clearance adjusted; wiring labels cleaned');
End;

Procedure ExportOpticalSchLib;
Var SD,SrcSD : IServerDocument; L : ISch_Lib; D : ISch_Document; C,Clone : ISch_Component; N : Integer; RefDes : String;
Begin
    SD:=Client.OpenNewDocument('SCHLIB','OpticalHardware','OpticalHardware',False);
    Client.ShowDocument(SD); SD.Focus; L:=SchServer.GetCurrentSchDocument;
    For N:=1 To 3 Do Begin
        If N=1 Then Begin SrcSD:=OpenSch(ROOT+'04_Optical_Heads.SchDoc'); RefDes:='TX1'; End;
        If N=2 Then Begin SrcSD:=OpenSch(ROOT+'04_Optical_Heads.SchDoc'); RefDes:='RX1'; End;
        If N=3 Then Begin SrcSD:=OpenSch(BEAMS_SCH); RefDes:='J2'; End;
        D:=SchServer.GetCurrentSchDocument; C:=FindSchRef(D,RefDes); Clone:=C.Replicate;
        Clone.MoveToXY(0,0); Clone.Designator.Text:=Copy(RefDes,1,Length(RefDes)-1)+'?';
        Client.ShowDocument(SD); SD.Focus;
        L.AddSchComponent(Clone); L.CurrentSchComponent:=Clone;
        SchServer.RobotManager.SendMessage(L.I_ObjectAddress,c_BroadCast,SCHM_PrimitiveRegistration,Clone.I_ObjectAddress);
    End;
    L.GraphicallyInvalidate;
    If SD.DoSafeChangeFileNameAndSave(ROOT+'lib\OpticalHardware.SchLib','SCHLIB') Then SensorLog('SAVED native OpticalHardware.SchLib');
End;

Procedure TerminalTrack(C,X1,Y1,X2,Y2);
Var T : IPCB_Track;
Begin
    T:=PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    T.X1:=MMsToCoord(X1); T.Y1:=MMsToCoord(Y1); T.X2:=MMsToCoord(X2); T.Y2:=MMsToCoord(Y2);
    T.Layer:=eTopOverlay; T.Width:=MMsToCoord(0.15); C.AddPCBObject(T);
End;

Procedure PopulateTerminalFootprint(C);
Var P : IPCB_Pad; Body : IPCB_ComponentBody; Model : IPCB_Model; N : Integer;
Begin
    For N:=1 To 3 Do Begin
        P:=PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
        P.Name:=IntToStr(N); P.X:=MMsToCoord((N-1)*5.08); P.Y:=0;
        P.Layer:=eMultiLayer; P.HoleSize:=MMsToCoord(1.3); P.Plated:=True;
        P.TopXSize:=MMsToCoord(2.6); P.TopYSize:=MMsToCoord(2.6);
        P.MidXSize:=MMsToCoord(2.6); P.MidYSize:=MMsToCoord(2.6);
        P.BotXSize:=MMsToCoord(2.6); P.BotYSize:=MMsToCoord(2.6);
        If N=1 Then Begin P.TopShape:=eRectangular; P.MidShape:=eRectangular; P.BotShape:=eRectangular; End
        Else Begin P.TopShape:=eRounded; P.MidShape:=eRounded; P.BotShape:=eRounded; End;
        C.AddPCBObject(P);
    End;
    { KiCad coordinates reflected in Y to Altium's upward-positive coordinate system. }
    TerminalTrack(C,-2.65,-4.71,12.81,-4.71); TerminalTrack(C,12.81,-4.71,12.81,5.31);
    TerminalTrack(C,12.81,5.31,-2.65,5.31); TerminalTrack(C,-2.65,5.31,-2.65,-4.71);
    Body:=PCBServer.PCBObjectFactory(eComponentBodyObject,eNoDimension,eCreate_Default);
    Model:=Body.ModelFactory_FromFilename(ROOT+'lib\phoenix\1715734.step',False);
    If Model=Nil Then Begin SensorLog('ERROR STEP import returned nil'); Exit; End;
    Model.Embed:=True; Body.Model:=Model; Body.SetState_FromModel;
    Body.Layer:=eMechanical1; C.AddPCBObject(Body);
    C.Height:=MMsToCoord(12.5);
End;

Procedure BuildTerminalPcbLib;
Var SD : IServerDocument; L : IPCB_Library; C : IPCB_LibComponent;
Begin
    SD:=Client.OpenNewDocument('PCBLIB','OpticalHardware','OpticalHardware',False);
    Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
    PCBServer.PreProcess;
    Try
        C:=PCBServer.CreatePCBLibComp; C.Name:='PHOENIX_1715734_MKDS_3_508';
        C.Description:='Phoenix Contact 1715734; KiCad matching MKDS 1.5/3-5.08 STEP and pad layout';
        PopulateTerminalFootprint(C); L.RegisterComponent(C); L.CurrentComponent:=C;
    Finally PCBServer.PostProcess; End;
    If SD.DoSafeChangeFileNameAndSave(ROOT+'lib\OpticalHardware.PcbLib','PCBLIB') Then SensorLog('SAVED native OpticalHardware.PcbLib with embedded STEP');
End;

Procedure ReplaceBoardTerminals;
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator; Old,C : IPCB_Component;
    P : IPCB_Pad; NObj : IPCB_Net; N,K : Integer; RefDes,NetName : String; YY : Real;
Begin
    SD:=Client.OpenDocument('PCB',PCB_PATH); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
    PCBServer.PreProcess;
    Try
        For N:=1 To 4 Do Begin
            If N=1 Then RefDes:='J2'; If N=2 Then RefDes:='J3'; If N=3 Then RefDes:='J4'; If N=4 Then RefDes:='J6';
            It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject));
            It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); Old:=It.FirstPCBObject;
            While Old<>Nil Do Begin If Old.SourceDesignator=RefDes Then Break; Old:=It.NextPCBObject; End;
            B.BoardIterator_Destroy(It);
            If Old<>Nil Then B.RemovePCBObject(Old);
            C:=PCBServer.PCBObjectFactory(eComponentObject,eNoDimension,eCreate_Default);
            C.Pattern:='PHOENIX_1715734_MKDS_3_508'; C.SourceDesignator:=RefDes;
            C.Name.Text:=RefDes; C.Comment.Text:='1715734'; C.NameOn:=True; C.CommentOn:=False;
            PopulateTerminalFootprint(C);
            B.AddPCBObject(C);
            { Horizontal pin row in library becomes vertical on the left board edge. }
            C.Rotation:=90; YY:=58-(N-1)*17; C.MoveByXY(MMsToCoord(8),MMsToCoord(YY));
            C.Name.Text:=RefDes; C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1.1);
            C.Name.XLocation:=MMsToCoord(14); C.Name.YLocation:=MMsToCoord(YY+4);
            For K:=1 To 3 Do Begin
                If K=1 Then NetName:='12V_SENSOR'; If K=2 Then NetName:='GND'; If K=3 Then NetName:='BEAM'+IntToStr(N)+'_SIG';
                It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetObject));
                It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); NObj:=It.FirstPCBObject;
                While NObj<>Nil Do Begin If NObj.Name=NetName Then Break; NObj:=It.NextPCBObject; End;
                B.BoardIterator_Destroy(It);
                If NObj=Nil Then Begin NObj:=PCBServer.PCBObjectFactory(eNetObject,eNoDimension,eCreate_Default); NObj.Name:=NetName; B.AddPCBObject(NObj); End;
                P:=C.GetState_PadByName(IntToStr(K)); P.Net:=NObj; NObj.RegisterWithGroupWarehouse(P);
            End;
            SensorLog('PCB '+RefDes+' real 1715734 footprint + embedded STEP; pads 1/2/3 assigned');
        End;
    Finally PCBServer.PostProcess; End;
    B.ViewManager_FullUpdate; SD.Modified:=True;
    If SD.DoFileSave('PCB Binary 6.0') Then SensorLog('SAVED controller PCB - still unrouted draft');
End;

Procedure UpdateOpticalHardware;
Var SD : IServerDocument; D : ISch_Document; W : IWorkspace; P : IProject;
Begin
    SensorLog('START targeted update');
    BuildTerminalPcbLib;
    SD:=OpenSch(BEAMS_SCH); D:=SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D,'Real sensor cable terminals');
    Try
        RepairSensorTerminal(D,'J2',1); RepairSensorTerminal(D,'J3',2);
        RepairSensorTerminal(D,'J4',3); RepairSensorTerminal(D,'J6',4);
    Finally SchServer.ProcessControl.PostProcess(D,'Real sensor cable terminals'); End;
    SaveSch(SD,BEAMS_SCH,'Real terminals linked');
    BuildOpticalHeadSheet; ExportOpticalSchLib; ReplaceBoardTerminals;
    W:=GetWorkspace; P:=W.DM_GetProjectFromPath(ROOT+'GarageBeamSafety.PrjPcb');
    If P<>Nil Then Begin
        P.DM_AddSourceDocument(ROOT+'04_Optical_Heads.SchDoc');
        P.DM_AddSourceDocument(ROOT+'lib\OpticalHardware.SchLib');
        P.DM_AddSourceDocument(ROOT+'lib\OpticalHardware.PcbLib');
    End;
    OpenSch(ROOT+'04_Optical_Heads.SchDoc');
    SensorLog('DONE - sensor STEP remains blocked at manufacturer server, not substituted');
End;

Function ExternalAdapter(D,RefDes,X,Y) : ISch_Component;
Var C : ISch_Component;
Begin
    C:=NewCustomComp(D,RefDes,'GST25E12-P1J','MEAN WELL','GST25E12-P1J',
        'EXTERNAL EQUIPMENT','Intact certified AC/DC adapter, 12 V 2.08 A',X,Y);
    C.ComponentKind:=eComponentKind_Mechanical;
    AddCompBody(C,X-570,Y-240,X+570,Y+240,C_TEXT);
    SymbolLine(C,X-570,Y-240,X+570,Y+240);
    AddCustomPin(C,X+750,Y+130,'P','+12V',eRotate180,eElectricPassive);
    AddCustomPin(C,X+750,Y-130,'N','0V',eRotate180,eElectricPassive);
    C.Designator.Location:=Point(MilsToCoord(X-570),MilsToCoord(Y+350));
    C.Comment.Location:=Point(MilsToCoord(X-570),MilsToCoord(Y-400));
    AddCompParameter(C,'Datasheet','https://www.meanwell.com/Upload/PDF/GST25E/GST25E-SPEC.PDF');
    AddCompParameter(C,'DC connector','5.5 x 2.1 mm centre positive; keep adapter intact');
    AddCompParameter(C,'Intended footprint','NONE - external plug-in adapter');
    AddCompParameter(C,'CAD status','Native external-equipment component with DC pins; no invented PCB footprint or 3D body');
    FinishCustomComp(D,C); Result:=C;
End;

Procedure MacroPageNow;
Var SD : IServerDocument; D : ISch_Document; C : ISch_Component;
    Y,N : Integer; L : TStringList; It : ISch_Iterator; O : ISch_GraphicalObject;
Begin
    SD:=OpenSch(OVERVIEW_SCH); PrepareSheet(SD,'FIXED-UPRIGHT INSTALLATION','GBS-00','01');
    D:=SchServer.GetCurrentSchDocument; SetDocParameter(D,'SheetTotal','05');
    SchServer.ProcessControl.PreProcess(D,'Updated physical overview');
    Try
        AddSheetHeading(D,'00','FIXED-UPRIGHT MOUNTING / TWO LOCAL 12 V SUPPLIES',
            'Installation overview, not to scale. Actual TX/RX electrical components and cable pinout: sheet 04.');
        AddText(D,650,6710,'LEFT FIXED METAL UPRIGHT',C_ACCENT);
        AddText(D,7740,6710,'RIGHT FIXED METAL UPRIGHT',C_ACCENT);
        AddText(D,3970,6710,'APPROX. 2.4 m OPTICAL SPAN',C_WARN);
        AddRect(D,2780,4260,3060,6470,C_TEXT,C_PANEL,True);
        AddRect(D,7900,4260,8180,6470,C_TEXT,C_PANEL,True);
        For N:=1 To 3 Do Begin
            Y:=6100-(N-1)*650;
            { Head outlines are installation references, not fake PCB components. }
            AddRect(D,3060,Y-150,3310,Y+150,C_ACCENT,C_BG,False);
            AddRect(D,7650,Y-150,7900,Y+150,C_POWER,C_BG,False);
            AddText(D,2350,Y+50,'RX'+IntToStr(4-N),C_ACCENT);
            AddText(D,8320,Y+50,'TX'+IntToStr(4-N),C_POWER);
            AddLine(D,3310,Y,7650,Y,C_RED,eSmall);
            AddLine(D,3310,Y,3450,Y+75,C_RED,eSmall);
            AddLine(D,3310,Y,3450,Y-75,C_RED,eSmall);
        End;
        AddText(D,650,6380,'E3Z-T61-D 2M receivers',C_TEXT);
        AddText(D,8350,6380,'E3Z-T61-L 2M emitters',C_TEXT);
        AddText(D,3900,4500,'3 beams shown; channel 4 optional',C_TEXT);
        AddText(D,3500,4210,'Optical faces oppose each other; no mirror',C_TEXT);
        AddText(D,650,4480,'Adjustable, lockable brackets',C_TEXT);
        AddText(D,8370,4480,'No second ESP32',C_TEXT);
        AddText(D,650,3950,'Mount on STATIONARY uprights, outside the entire roller/door travel envelope. Do not drill the roller running surface.',C_WARN);
        AddText(D,650,3720,'Heads: 10.8 W x 31 H x 20 D mm; 2 M3 holes / 25.4 mm pitch. Final heights, brackets and enclosure sizes remain open.',C_TEXT);
        AddRect(D,650,2200,3620,3410,C_ACCENT,C_PANEL,True);
        AddText(D,830,3180,'BOX A - COMPACT CONTROLLER',C_ACCENT);
        AddText(D,830,2940,'A1 ESP32-DevKitC-32E / one MCU',C_TEXT);
        AddText(D,830,2720,'A2 Murata OKI-78SR -> 5 V',C_TEXT);
        AddText(D,830,2500,'J2/J3/J4/J6 -> receiver cables',C_TEXT);
        AddText(D,830,2280,'Protected 12 V / RGB driver / test button',C_TEXT);
        AddLine(D,2780,4260,2780,3410,C_ACCENT,eSmall);
        AddRect(D,7730,2200,10400,3410,C_POWER,C_PANEL,True);
        AddText(D,7910,3180,'BOX B - DC DISTRIBUTION',C_POWER);
        AddText(D,7910,2910,'12 V -> fuse / protection -> TX1..TX4',C_TEXT);
        AddText(D,7910,2650,'Powered industrial heads only',C_TEXT);
        AddText(D,7910,2390,'No controller or Wi-Fi required',C_TEXT);
        AddLine(D,8180,4260,8180,3410,C_POWER,eSmall);
        AddText(D,4030,3220,'VISIBLE RGB INDICATOR',C_ACCENT);
        AddText(D,4030,2930,'GREEN: configured beams clear',C_GREEN);
        AddText(D,4030,2690,'RED: beam blocked / signal absent',C_RED);
        AddText(D,4030,2450,'YELLOW: startup / known fault',C_WARN);
        AddLine(D,3620,3100,3930,3100,C_ACCENT,eSmall);
        AddText(D,4030,2200,'12 V analogue RGB; wired to J5',C_TEXT);
        C:=ExternalAdapter(D,'PS1',1250,1550);
        C:=ExternalAdapter(D,'PS2',8410,1550);
        AddText(D,2280,1700,'DC cable -> J1',C_TEXT);
        AddText(D,9400,1700,'DC -> Box B',C_TEXT);
        AddText(D,650,1050,'Each adapter plugs into a local mains outlet. Only its 12 V DC lead enters the low-voltage box. No mains on either PCB.',C_WARN);
        AddText(D,4030,1610,'5.5 x 2.1 mm, centre positive',C_TEXT);
        AddText(D,4030,1360,'Separate supplies: no cross-span cable',C_TEXT);
        AddText(D,650,820,'ADVISORY ONLY. No automatic door operation. Existing door safety sensors stay untouched. Brackets and beam coverage need checking.',C_WARN);
    Finally SchServer.ProcessControl.PostProcess(D,'Updated physical overview'); End;
    SaveSch(SD,OVERVIEW_SCH,'PAGE 0 UPDATED');
    AuditSheet(OVERVIEW_SCH);
    L:=TStringList.Create; It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eLabel)); O:=It.FirstSchObject;
    While O<>Nil Do Begin L.Add(O.Text); O:=It.NextSchObject; End;
    D.SchIterator_Destroy(It); L.SaveToFile(ROOT+'00_Mounting_Overview.labels.txt'); L.Free;
End;

Procedure InspectPcbNative;
Var SD : IServerDocument; L : IPCB_Library; LC : IPCB_LibComponent;
    B : IPCB_Board; It : IPCB_BoardIterator; GI : IPCB_GroupIterator;
    C : IPCB_Component; O : IPCB_Primitive; S : TStringList;
Begin
    S:=TStringList.Create;
    SD:=Client.OpenDocument('PCBLIB',ROOT+'lib\ESP32-DEVKITC-32E\MODULE_ESP32-DEVKITC-32E.PcbLib');
    Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary; LC:=L.CurrentComponent;
    S.Add('LIB|'+LC.Name);
    GI:=LC.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
    While O<>Nil Do Begin
        If O.ObjectId=ePadObject Then S.Add('LIBPAD|'+O.Name+'|'+FloatToStr(CoordToMMs(O.X))+'|'+FloatToStr(CoordToMMs(O.Y)));
        If O.ObjectId=eComponentBodyObject Then S.Add('LIBBODY|'+IntToStr(O.ObjectId));
        O:=GI.NextPCBObject;
    End; LC.GroupIterator_Destroy(GI);
    SD:=Client.OpenDocument('PCB',PCB_PATH); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
    It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    C:=It.FirstPCBObject;
    While C<>Nil Do Begin
        S.Add('COMP|'+C.SourceDesignator+'|'+C.Pattern+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y)));
        C:=It.NextPCBObject;
    End; B.BoardIterator_Destroy(It); S.SaveToFile(ROOT+'CurrentPCBNative.audit.txt'); S.Free;
End;

Procedure UpdateMacroAndInspect;
Begin
    MacroPageNow;
    InspectPcbNative;
    OpenSch(OVERVIEW_SCH);
End;

Procedure PackagePad(C,Name,X,Y,SX,SY);
Var P : IPCB_Pad;
Begin
 P:=PCBServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
 P.Name:=Name; P.X:=MMsToCoord(X); P.Y:=MMsToCoord(Y); P.Layer:=eTopLayer;
 P.HoleSize:=0; P.TopShape:=eRectangular; P.TopXSize:=MMsToCoord(SX); P.TopYSize:=MMsToCoord(SY);
 C.AddPCBObject(P);
End;

Procedure PopulateVerifiedPackage(C, PatternName);
Var Body : IPCB_ComponentBody; Model : IPCB_Model; ModelFile : String;
Begin
    If PatternName='KICAD_SOT-23' Then Begin
        PackagePad(C,'1',-1,0.95,0.9,0.8);
        PackagePad(C,'2',-1,-0.95,0.9,0.8);
        PackagePad(C,'3',1,0,0.9,0.8);
        TerminalTrack(C,0.76,-1.58,0.76,-0.65);
        TerminalTrack(C,0.76,1.58,0.76,0.65);
        TerminalTrack(C,0.76,1.58,-1.4,1.58);
        TerminalTrack(C,0.76,-1.58,-0.7,-1.58);
        ModelFile:=ROOT+'lib\upstream-kicad\SOT-23.step';
    End;
    If PatternName='KICAD_R_0805_2012Metric' Then Begin
        PackagePad(C,'1',-0.9125,0,1.025,1.4);
        PackagePad(C,'2',0.9125,0,1.025,1.4);
        TerminalTrack(C,-0.227064,0.735,0.227064,0.735);
        TerminalTrack(C,-0.227064,-0.735,0.227064,-0.735);
        ModelFile:=ROOT+'lib\upstream-kicad\R_0805_2012Metric.step';
    End;
    If PatternName='KICAD_C_0805_2012Metric' Then Begin
        PackagePad(C,'1',-0.95,0,1,1.45);
        PackagePad(C,'2',0.95,0,1,1.45);
        TerminalTrack(C,-0.261252,0.735,0.261252,0.735);
        TerminalTrack(C,-0.261252,-0.735,0.261252,-0.735);
        ModelFile:=ROOT+'lib\upstream-kicad\C_0805_2012Metric.step';
    End;
    If PatternName='KICAD_D_SOD-123' Then Begin
        PackagePad(C,'1',-1.65,0,0.9,1.2);
        PackagePad(C,'2',1.65,0,0.9,1.2);
        TerminalTrack(C,-2.25,1,-2.25,-1);
        TerminalTrack(C,-2.25,-1,1.65,-1);
        TerminalTrack(C,-2.25,1,1.65,1);
        ModelFile:=ROOT+'lib\upstream-kicad\D_SOD-123.step';
    End;
    If ModelFile='' Then Exit;
    Body:=PCBServer.PCBObjectFactory(eComponentBodyObject,eNoDimension,eCreate_Default);
    Model:=Body.ModelFactory_FromFilename(ModelFile,False);
    If Model=Nil Then Begin ShowMessage('Missing STEP '+ModelFile); Abort; End;
    Model.Embed:=True; Body.Model:=Model; Body.SetState_FromModel;
    Body.Layer:=eMechanical1; C.AddPCBObject(Body);
End;
Function PackageForRef(R) : String;
Begin
    Result:='';
    If Copy(R,1,1)='R' Then Result:='KICAD_R_0805_2012Metric';
    If (R='C2') Or (R='C3') Or (R='C4') Or (R='C6') Then Result:='KICAD_C_0805_2012Metric';
    If (R='D2') Or (R='D3') Or (R='D4') Or (R='D7') Then Result:='KICAD_D_SOD-123';
    If (R='Q2') Or (R='Q3') Or (R='Q4') Then Result:='KICAD_SOT-23';
    If R='A1' Then Result:='MODULE_ESP32-DEVKITC-32E';
End;

Procedure BuildVerifiedLibrary;
Var SD : IServerDocument; L : IPCB_Library; C : IPCB_LibComponent; I : Integer; P : String;
Begin
    SD:=Client.OpenNewDocument('PCBLIB','VerifiedPackages','VerifiedPackages',False);
    Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
    PCBServer.PreProcess;
    Try
        For I:=1 To 4 Do Begin
            If I=1 Then P:='KICAD_SOT-23'; If I=2 Then P:='KICAD_R_0805_2012Metric';
            If I=3 Then P:='KICAD_C_0805_2012Metric'; If I=4 Then P:='KICAD_D_SOD-123';
            C:=PCBServer.CreatePCBLibComp; C.Name:=P;
            C.Description:='KiCad official community footprint and STEP; rectangular pad corners; see provenance';
            PopulateVerifiedPackage(C,P); L.RegisterComponent(C); L.CurrentComponent:=C;
        End;
    Finally PCBServer.PostProcess; End;
    SD.DoSafeChangeFileNameAndSave(ROOT+'lib\VerifiedPackages.PcbLib','PCBLIB');
End;

Procedure RepairLibraryLinks(APath);
Var SD : IServerDocument; D : ISch_Document; It,CI : ISch_Iterator;
    C : ISch_Component; O,OldO : ISch_GraphicalObject; M : ISch_Implementation;
    RefDes,Pat,MapStr,LibPath : String;
Begin
    SD:=OpenSch(APath); D:=SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D,'Assign real library footprint links');
    Try
        It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
        While C<>Nil Do Begin
            RefDes:=C.Designator.Text; Pat:=PackageForRef(RefDes);
            If (Pat<>'') And (RefDes<>'A1') Then Begin
                CI:=C.SchIterator_Create; CI.AddFilter_ObjectSet(MkSet(eImplementation)); O:=CI.FirstSchObject;
                While O<>Nil Do Begin OldO:=O; O:=CI.NextSchObject; C.RemoveSchObject(OldO); End;
                C.SchIterator_Destroy(CI);
                M:=C.AddSchImplementation; M.ModelType:='PCBLIB'; M.ModelName:=Pat; M.IsCurrent:=True;
                M.AddDataFileLink(Pat,ROOT+'lib\VerifiedPackages.PcbLib','PCBLIB');
                MapStr:='(1:1),(2:2)';
                If Copy(RefDes,1,1)='Q' Then MapStr:='(1:1),(2:2),(3:3)';
                { Existing conventional diode symbol: 1=A, 2=K. KiCad: pad 1=K, 2=A. }
                If Copy(RefDes,1,1)='D' Then MapStr:='(1:2),(2:1)';
                M.MapAsString:=MapStr;
                AddCompParameter(C,'Intended footprint',Pat);
                AddCompParameter(C,'CAD status','Native footprint link with explicit pin mapping and embedded KiCad STEP; physical validation pending');
                AddCompParameter(C,'Footprint source','KiCad official community libraries; not manufacturer-certified CAD');
            End;
            C:=It.NextSchObject;
        End; D.SchIterator_Destroy(It);
    Finally SchServer.ProcessControl.PostProcess(D,'Assign real library footprint links'); End;
    SaveSch(SD,APath,'Native library links saved'); AuditSheet(APath);
End;

Function BoardComp(B,R) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result:=Nil; It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
    While C<>Nil Do Begin If C.SourceDesignator=R Then Begin Result:=C; Break; End; C:=It.NextPCBObject; End;
    B.BoardIterator_Destroy(It);
End;

Function BoardNet(B,Name) : IPCB_Net;
Var It : IPCB_BoardIterator; N : IPCB_Net;
Begin
    It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetObject)); It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll); N:=It.FirstPCBObject;
    While N<>Nil Do Begin If N.Name=Name Then Break; N:=It.NextPCBObject; End;
    B.BoardIterator_Destroy(It);
    If N=Nil Then Begin N:=PCBServer.PCBObjectFactory(eNetObject,eNoDimension,eCreate_Default); N.Name:=Name; B.AddPCBObject(N); End;
    Result:=N;
End;

Procedure CopyEspLibraryInto(C);
Var L : IPCB_LibComponent; GI : IPCB_GroupIterator; O,NextO : IPCB_Primitive; SX,SY : Real; Count : Integer;
Begin
    L:=PCBServer.LoadCompFromLibrary('MODULE_ESP32-DEVKITC-32E',ROOT+'lib\ESP32-DEVKITC-32E\MODULE_ESP32-DEVKITC-32E.PcbLib');
    If L=Nil Then Begin ShowMessage('Supplied ESP32 footprint could not be loaded'); Abort; End;
    SX:=0; SY:=0; Count:=0;
    GI:=L.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); O:=GI.FirstPCBObject;
    While O<>Nil Do Begin SX:=SX+CoordToMMs(O.X); SY:=SY+CoordToMMs(O.Y); Count:=Count+1; O:=GI.NextPCBObject; End;
    L.GroupIterator_Destroy(GI);
    If Count<>38 Then Begin ShowMessage('Expected 38 pins in supplied ESP32 library'); Abort; End;
    { LoadCompFromLibrary returns a temporary footprint, not the editable source library. }
    GI:=L.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
    While O<>Nil Do Begin NextO:=GI.NextPCBObject; L.RemovePCBObject(O); C.AddPCBObject(O); O:=NextO; End;
    L.GroupIterator_Destroy(GI);
    C.X:=MMsToCoord(SX/Count); C.Y:=MMsToCoord(SY/Count);
End;

Procedure ReplaceKnownBoardParts;
Var SD : IServerDocument; B : IPCB_Board; Old,C : IPCB_Component; GI : IPCB_GroupIterator;
    P : IPCB_Pad; N : IPCB_Net; PinNets,Refs,Report : TStringList;
    I : Integer; R,Pat,PinName,NetName : String; XX,YY : Real;
Begin
    PinNets:=TStringList.Create; PinNets.LoadFromFile(ROOT+'NativePinNets.txt');
    Refs:=TStringList.Create;
    Refs.CommaText:='A1,R5,R6,R7,R8,R9,R10,R11,R12,R13,R14,R15,R16,R17,R18,R19,R20,R21,R22,R23,C2,C3,C4,C6,D2,D3,D4,D7,Q2,Q3,Q4';
    Report:=TStringList.Create;
    SD:=Client.OpenDocument('PCB',PCB_PATH); Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
    PCBServer.PreProcess;
    Try
        For I:=0 To Refs.Count-1 Do Begin
            R:=Refs[I]; Pat:=PackageForRef(R); Old:=BoardComp(B,R);
            XX:=55; YY:=10;
            If Old<>Nil Then Begin XX:=CoordToMMs(Old.X); YY:=CoordToMMs(Old.Y); End;
            If R='A1' Then Begin XX:=89; YY:=46; End;
            If R='R18' Then Begin XX:=27; YY:=10; End;
            If R='R19' Then Begin XX:=42; YY:=11; End;
            If R='R20' Then Begin XX:=49; YY:=11; End;
            If R='C6' Then Begin XX:=49; YY:=6; End;
            If R='D7' Then Begin XX:=35; YY:=4; End;
            If R='Q2' Then Begin XX:=61; YY:=28; End;
            If R='Q3' Then Begin XX:=68; YY:=28; End;
            If R='Q4' Then Begin XX:=75; YY:=28; End;
            If R='R17' Then Begin XX:=61; YY:=24; End;
            If R='R21' Then Begin XX:=68; YY:=24; End;
            If R='R23' Then Begin XX:=75; YY:=24; End;
            If R='R22' Then Begin XX:=84; YY:=11; End;
            C:=PCBServer.PCBObjectFactory(eComponentObject,eNoDimension,eCreate_Default);
            If R='A1' Then CopyEspLibraryInto(C) Else PopulateVerifiedPackage(C,Pat);
            C.Pattern:=Pat; C.SourceDesignator:=R; C.Name.Text:=R; C.NameOn:=True; C.CommentOn:=False;
            B.AddPCBObject(C); C.MoveByXY(MMsToCoord(XX)-C.X,MMsToCoord(YY)-C.Y);
            C.Name.UseTTFonts:=True; C.Name.FontName:='Arial'; C.Name.Size:=MMsToCoord(1);
            C.Name.XLocation:=MMsToCoord(XX-1); C.Name.YLocation:=MMsToCoord(YY+2);
            GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject;
            While P<>Nil Do Begin
                PinName:=P.Name;
                If Copy(R,1,1)='D' Then Begin If P.Name='1' Then PinName:='2' Else PinName:='1'; End;
                NetName:=PinNets.Values[R+'.'+PinName];
                If NetName='' Then Begin ShowMessage('No schematic net for '+R+'.'+PinName); Abort; End;
                N:=BoardNet(B,NetName); P.Net:=N; N.RegisterWithGroupWarehouse(P);
                Report.Add('PAD|'+R+'|'+P.Name+'|'+NetName+'|'+FloatToStr(CoordToMMs(P.X))+'|'+FloatToStr(CoordToMMs(P.Y)));
                P:=GI.NextPCBObject;
            End; C.GroupIterator_Destroy(GI);
            If Old<>Nil Then B.RemovePCBObject(Old);
            Report.Add('REPLACED|'+R+'|'+Pat);
        End;
        { Obsolete buzzer and its diode are no longer in the current schematic. }
        Old:=BoardComp(B,'BZ1'); If Old<>Nil Then B.RemovePCBObject(Old);
        Old:=BoardComp(B,'D5'); If Old<>Nil Then B.RemovePCBObject(Old);
    Finally PCBServer.PostProcess; End;
    B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0');
    Report.SaveToFile(ROOT+'LibraryBoardUpdate.audit.txt');
    PinNets.Free; Refs.Free; Report.Free;
End;

Procedure ExportControllerSchLib;
Var SD,SrcSD : IServerDocument; L : ISch_Lib; D : ISch_Document;
    It : ISch_Iterator; C,Clone : ISch_Component; Seen : TStringList; I : Integer; APath : String;
Begin
    Seen:=TStringList.Create;
    SD:=Client.OpenNewDocument('SCHLIB','ControllerComponents','ControllerComponents',False);
    Client.ShowDocument(SD); SD.Focus; L:=SchServer.GetCurrentSchDocument;
    For I:=1 To 3 Do Begin
        If I=1 Then APath:=POWER_SCH; If I=2 Then APath:=BEAMS_SCH; If I=3 Then APath:=UI_SCH;
        SrcSD:=OpenSch(APath); D:=SchServer.GetCurrentSchDocument;
        It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
        While C<>Nil Do Begin
            If Seen.IndexOf(C.LibReference)<0 Then Begin
                Clone:=C.Replicate; Clone.MoveToXY(0,0); Clone.Designator.Text:=Copy(C.Designator.Text,1,1)+'?';
                L.AddSchComponent(Clone); Seen.Add(C.LibReference);
            End;
            C:=It.NextSchObject;
        End; D.SchIterator_Destroy(It);
    End;
    Client.ShowDocument(SD); SD.Focus; L.GraphicallyInvalidate;
    SD.DoSafeChangeFileNameAndSave(ROOT+'lib\ControllerComponents.SchLib','SCHLIB'); Seen.Free;
End;

Procedure UpdateKnownLibrariesAndPCB;
Begin
    BuildVerifiedLibrary;
    RepairLibraryLinks(BEAMS_SCH); RepairLibraryLinks(UI_SCH);
    ReplaceKnownBoardParts;
    ExportControllerSchLib;
    OpenSch(OVERVIEW_SCH);
End;

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

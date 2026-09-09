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
                    (OldO.ObjectId = eSheetSymbol) Or (OldO.ObjectId = eBus) Or (OldO.ObjectId = eNetLabel) Or
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

{ Non-destructive child-sheet interface addition; page 0 replacement only.
  The former mounting page is preserved as 05_Installation.SchDoc before run.
  No PCB, component, pin, or existing child wire is changed. }

Function InterfaceNames(Index) : String;
Begin
    Case Index Of
    1: Result := '12V_SENSOR,GND,3V3,BEAM1_GPIO32,BEAM2_GPIO33,BEAM3_GPIO34,BEAM4_GPIO35,LED_RED_GPIO26,LED_GREEN_GPIO25,LED_BLUE_GPIO27,BUTTON_GPIO13';
    2: Result := '12V_SENSOR,GND,3V3,BEAM1_SIG,BEAM2_SIG,BEAM3_SIG,BEAM4_SIG,BEAM1_GPIO32,BEAM2_GPIO33,BEAM3_GPIO34,BEAM4_GPIO35';
    3: Result := '12V_SENSOR,GND,3V3,LED_RED_GPIO26,LED_GREEN_GPIO25,LED_BLUE_GPIO27,BUTTON_GPIO13';
    4: Result := '12V_SENSOR,GND,BEAM1_SIG,BEAM2_SIG,BEAM3_SIG,BEAM4_SIG';
    Else Result := '';
    End;
End;

Function ChildFile(Index) : String;
Begin
    Case Index Of
    1: Result := '01_Power_Control.SchDoc';
    2: Result := '02_Beam_Inputs.SchDoc';
    3: Result := '03_UI_Outputs.SchDoc';
    4: Result := '04_Optical_Heads.SchDoc';
    5: Result := '05_Installation.SchDoc';
    End;
End;

Function DirectionFor(Index,N) : Integer;
Begin
    Result := ePortUnspecified;
    If (N='GND') Or (N='12V_SENSOR') Or (N='3V3') Then Exit;
    If Index=1 Then Begin
        If (Copy(N,1,4)='BEAM') Or (N='BUTTON_GPIO13') Then Result:=ePortInput Else Result:=ePortOutput;
    End;
    If Index=2 Then Begin
        If Pos('_SIG',N)>0 Then Result:=ePortInput Else Result:=ePortOutput;
    End;
    If Index=3 Then Begin
        If N='BUTTON_GPIO13' Then Result:=ePortOutput Else Result:=ePortInput;
    End;
    If Index=4 Then Result:=ePortOutput;
End;

Procedure AddInterfaceBank(Index);
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator;
    O : ISch_GraphicalObject; P : ISch_Port; Names,Seen : TStringList;
    I,Y : Integer;
Begin
    SD:=OpenSch(ROOT+ChildFile(Index)); D:=SchServer.GetCurrentSchDocument;
    Names:=TStringList.Create; Seen:=TStringList.Create;
    Names.CommaText:=InterfaceNames(Index);
    It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(ePort)); O:=It.FirstSchObject;
    While O<>Nil Do Begin Seen.Add(O.Name); O:=It.NextSchObject; End;
    D.SchIterator_Destroy(It);
    SchServer.ProcessControl.PreProcess(D,'Hierarchical interfaces');
    Try
        If Seen.Count=0 Then AddText(D,9050,6850,'PAGE 0 INTERFACE',C_ACCENT);
        For I:=0 To Names.Count-1 Do If Seen.IndexOf(Names[I])<0 Then Begin
            Y:=6500-I*450;
            P:=SchServer.SchObjectFactory(ePort,eCreate_GlobalCopy);
            P.Name:=Names[I]; P.Location:=Point(MilsToCoord(9250),MilsToCoord(Y));
            P.Width:=MilsToCoord(1500); P.Style:=ePortRight;
            P.IOType:=DirectionFor(Index,Names[I]);
            P.ConnectedEnd:=ePortConnectedEnd_Origin;
            P.Color:=C_ACCENT; P.AreaColor:=C_PANEL; P.TextColor:=C_TEXT;
            P.FontID:=SchServer.FontManager.GetFontID(8,0,False,False,False,False,'Arial');
            D.RegisterSchObjectInContainer(P);
            AddWire(D,9050,Y,9250,Y);
            AddNetLabel(D,9050,Y,Names[I],eRotate180);
        End;
        SetDocParameter(D,'SheetTotal','06');
    Finally SchServer.ProcessControl.PostProcess(D,'Hierarchical interfaces'); End;
    SaveSch(SD,ROOT+ChildFile(Index),'Hierarchical interface saved');
    Names.Free; Seen.Free;
End;

Procedure HierarchyBlock(D,Index,X,TopY,W,H,TitleText);
Var S : ISch_SheetSymbol; E : ISch_SheetEntry; Names : TStringList; I,Offset : Integer;
Begin
    S:=SchServer.SchObjectFactory(eSheetSymbol,eCreate_GlobalCopy);
    S.Location:=Point(MilsToCoord(X),MilsToCoord(TopY-H));
    S.XSize:=MilsToCoord(W); S.YSize:=MilsToCoord(H);
    S.Color:=C_ACCENT; S.AreaColor:=C_PANEL; S.IsSolid:=True; S.LineWidth:=eMedium;
    S.SheetName.Text:=TitleText;
    S.SheetName.Location:=Point(MilsToCoord(X),MilsToCoord(TopY+220));
    S.SheetName.Color:=C_ACCENT;
    S.SheetName.FontID:=SchServer.FontManager.GetFontID(12,0,False,False,False,False,'Arial');
    S.SheetFileName.Text:=ChildFile(Index);
    S.SheetFileName.Location:=Point(MilsToCoord(X),MilsToCoord(TopY+60));
    S.SheetFileName.Color:=C_TEXT;
    S.SheetFileName.FontID:=SchServer.FontManager.GetFontID(9,0,False,False,False,False,'Arial');
    D.RegisterSchObjectInContainer(S);
    Names:=TStringList.Create; Names.CommaText:=InterfaceNames(Index);
    For I:=0 To Names.Count-1 Do Begin
        Offset:=200+I*170;
        E:=SchServer.SchObjectFactory(eSheetEntry,eCreate_GlobalCopy);
        E.Name:=Names[I]; E.Side:=eLeft; E.DistanceFromTop:=MilsToCoord(Offset);
        E.IOType:=DirectionFor(Index,Names[I]); E.Style:=ePortRight;
        E.Color:=C_ACCENT; E.AreaColor:=C_PANEL; E.TextColor:=C_TEXT;
        S.AddSchObject(E);
        AddWire(D,X-200,TopY-Offset,X,TopY-Offset);
        AddNetLabel(D,X-200,TopY-Offset,Names[I],eRotate180);
    End;
    Names.Free;
End;

Procedure HierarchyAudit(APath);
Var SD : IServerDocument; D : ISch_Document; It,SI : ISch_Iterator;
    O,E : ISch_GraphicalObject; S : TStringList; I : Integer;
Begin
    AuditSheet(APath);
    SD:=OpenSch(APath); D:=SchServer.GetCurrentSchDocument; S:=TStringList.Create;
    It:=D.SchIterator_Create; It.SetState_FilterAll; O:=It.FirstSchObject;
    While O<>Nil Do Begin
        If O.ObjectId=ePort Then S.Add('PORT|'+O.Name+'|'+IntToStr(O.Location.X)+'|'+IntToStr(O.Location.Y)+'|'+IntToStr(O.IOType));
        If O.ObjectId=eSheetSymbol Then Begin
            S.Add('SHEET|'+O.SheetName.Text+'|'+O.SheetFileName.Text);
            SI:=O.SchIterator_Create; SI.AddFilter_ObjectSet(MkSet(eSheetEntry)); E:=SI.FirstSchObject;
            While E<>Nil Do Begin
                S.Add('ENTRY|'+O.SheetFileName.Text+'|'+E.Name+'|'+IntToStr(E.IOType)+'|'+IntToStr(E.Location.X)+'|'+IntToStr(E.Location.Y));
                E:=SI.NextSchObject;
            End;
            O.SchIterator_Destroy(SI);
        End;
        O:=It.NextSchObject;
    End;
    D.SchIterator_Destroy(It); S.SaveToFile(APath+'.hierarchy.txt'); S.Free;
End;

Procedure UpdateHierarchy;
Var SD : IServerDocument; D : ISch_Document; WS : IWorkspace; Prj : IProject;
    I : Integer;
Begin
    { Fresh snapshots include any existing in-memory user changes. }
    For I:=1 To 4 Do Begin
        AuditSheet(ROOT+ChildFile(I));
    End;
    For I:=1 To 4 Do AddInterfaceBank(I);
    SD:=OpenSch(OVERVIEW_SCH);
    PrepareSheet(SD,'SYSTEM HIERARCHY','GBS-00','01');
    D:=SchServer.GetCurrentSchDocument;
    SchServer.ProcessControl.PreProcess(D,'System hierarchy');
    Try
        AddSheetHeading(D,'00','SYSTEM HIERARCHY / NAMED SIGNALS',
            'Real sheet symbols link to child schematics. Matching tags join nets on this page. Physical mounting: sheet 05.');
        HierarchyBlock(D,1,2400,6550,2700,2150,'POWER / ESP32');
        HierarchyBlock(D,2,8000,6550,2700,2150,'BEAM INPUTS');
        HierarchyBlock(D,3,2400,3800,2700,1600,'RGB / TEST BUTTON');
        HierarchyBlock(D,4,8000,3800,2700,1600,'EXTERNAL OPTICAL HEADS');
        HierarchyBlock(D,5,8000,1650,2700,550,'MOUNTING / AC-DC ADAPTERS');
        AddText(D,650,1760,'LOCAL TAGS: Place > Net Label',C_TEXT);
        AddText(D,650,1510,'BETWEEN PAGES: Port <-> Sheet Entry',C_TEXT);
        AddText(D,650,1260,'Same name alone does not join labels on different child sheets.',C_WARN);
        AddText(D,650,850,'ADVISORY ONLY. No automatic door operation. Separate TX power. Mounting and optical validation are still required.',C_WARN);
        SetDocParameter(D,'SheetTotal','06');
    Finally SchServer.ProcessControl.PostProcess(D,'System hierarchy'); End;
    SaveSch(SD,OVERVIEW_SCH,'Hierarchy page saved');
    SD:=OpenSch(ROOT+ChildFile(5)); D:=SchServer.GetCurrentSchDocument;
    SetDocParameter(D,'SheetNumber','06'); SetDocParameter(D,'SheetTotal','06');
    SetDocParameter(D,'DocumentNumber','GBS-05');
    SaveSch(SD,ROOT+ChildFile(5),'Installation drawing preserved');
    WS:=GetWorkspace;
    For I:=0 To WS.DM_ProjectCount-1 Do Begin
        Prj:=WS.DM_Projects(I);
        If UpperCase(Prj.DM_ProjectFullPath)=UpperCase(ROOT+'GarageBeamSafety.PrjPcb') Then Begin
            If Prj.DM_IndexOfSourceDocument(ROOT+ChildFile(5))<0 Then Prj.DM_AddSourceDocument(ROOT+ChildFile(5));
        End;
    End;
    HierarchyAudit(OVERVIEW_SCH);
    For I:=1 To 5 Do HierarchyAudit(ROOT+ChildFile(I));
    SD:=OpenSch(OVERVIEW_SCH);
    ShowMessage('Hierarchy saved: page 0 plus 4 connected child sheets and preserved installation page. Save project, then validate. PCB unchanged.');
End;

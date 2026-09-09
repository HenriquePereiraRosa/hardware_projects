{ Garage Beam Safety D3 - editable Altium concept schematic generator.
  Run BuildGarageBeamDraft while GarageBeamSafety.SchDoc is focused.
  The generated sheet is a concept drawing, not a fabrication netlist. }

Procedure AddDraftLabel(Doc, X, Y, S, PtSize, IsBold, AColor);
Var
    L : ISch_Label;
Begin
    L := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    L.Text := S;
    L.Color := AColor;
    L.Orientation := eRotate0;
    L.FontID := SchServer.FontManager.GetFontID(PtSize, 0, IsBold, False, False, False, 'Arial');
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure AddDraftBox(Doc, X1, Y1, X2, Y2, Caption, SubCaption, AColor);
Var
    R : ISch_Rectangle;
Begin
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    If R = Nil Then Exit;
    R.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    R.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    R.Color := AColor;
    R.AreaColor := $00F8F8F8;
    R.LineWidth := eMedium;
    R.IsSolid := False;
    Doc.RegisterSchObjectInContainer(R);
    AddDraftLabel(Doc, X1 + 80, Y2 - 160, Caption, 11, True, AColor);
    If SubCaption <> '' Then
        AddDraftLabel(Doc, X1 + 80, Y2 - 330, SubCaption, 8, False, $00606060);
End;

Procedure AddDraftLine(Doc, X1, Y1, X2, Y2, AColor, AWidth);
Var
    L : ISch_Line;
Begin
    L := SchServer.SchObjectFactory(eLine, eCreate_GlobalCopy);
    If L = Nil Then Exit;
    L.Location := Point(MilsToCoord(X1), MilsToCoord(Y1));
    L.Corner := Point(MilsToCoord(X2), MilsToCoord(Y2));
    L.Color := AColor;
    L.LineStyle := eLineStyleSolid;
    L.LineWidth := AWidth;
    Doc.RegisterSchObjectInContainer(L);
End;

Procedure ClearActiveSheet(Doc);
Var
    It      : ISch_Iterator;
    Obj     : ISch_GraphicalObject;
    OldObj  : ISch_GraphicalObject;
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

Procedure DrawBeamChannel(Doc, Y, Number, GPIOName);
Var
    Prefix : String;
Begin
    Prefix := 'BEAM' + IntToStr(Number);
    AddDraftBox(Doc, 500, Y, 1700, Y + 600, 'J' + IntToStr(Number + 1) + '  ' + Prefix,
                'V+ / 0V / SIG - NPN sinks when CLEAR', $000000FF);
    AddDraftBox(Doc, 2150, Y, 3350, Y + 600, 'U' + IntToStr(Number + 1) + '  LTV-817',
                '2.2k input + reverse clamp', $000080FF);
    AddDraftBox(Doc, 3800, Y, 5050, Y + 600, 'FILTER + PULL-UP',
                '10k to 3V3, 1k series, 100nF', $00A06000);
    AddDraftBox(Doc, 5500, Y, 6650, Y + 600, GPIOName,
                'LOW = proven CLEAR; HIGH = UNSAFE', $00008000);
    AddDraftLine(Doc, 1700, Y + 300, 2150, Y + 300, $000000FF, eMedium);
    AddDraftLine(Doc, 3350, Y + 300, 3800, Y + 300, $000080FF, eMedium);
    AddDraftLine(Doc, 5050, Y + 300, 5500, Y + 300, $00A06000, eMedium);
End;

Procedure BuildGarageBeamDraft;
Var
    Doc  : ISch_Document;
    View : IServerDocumentView;
Begin
    If SchServer = Nil Then
    Begin
        ShowMessage('Schematic server is not loaded. Open GarageBeamSafety.SchDoc first.');
        Exit;
    End;
    Doc := SchServer.GetCurrentSchDocument;
    If Doc = Nil Then
    Begin
        ShowMessage('Focus GarageBeamSafety.SchDoc, then run this procedure again.');
        Exit;
    End;
    If Doc.ObjectID = eSchLib Then
    Begin
        ShowMessage('The focused file is a library, not a schematic sheet.');
        Exit;
    End;

    SchServer.ProcessControl.PreProcess(Doc, 'Garage Beam Draft');
    Try
        ClearActiveSheet(Doc);
        AddDraftLabel(Doc, 500, 7450, 'GARAGE BEAM SAFETY - D3 THREE-BEAM CONCEPT', 18, True, $00804000);
        AddDraftLabel(Doc, 500, 7150, 'Advisory detector only - no mains - no automatic garage-door operation', 10, True, $000000FF);

        AddDraftBox(Doc, 500, 6200, 1700, 6900, 'J1  USB-C 5 V', 'Certified charger >=2 A; CC1/CC2 5.1k', $000000FF);
        AddDraftBox(Doc, 2150, 6200, 3350, 6900, '5 V PROTECTION', '1.5 A PTC + 5 V TVS + reverse-current FET', $000080FF);
        AddDraftBox(Doc, 3800, 6200, 5050, 6900, '12 V BOOST', 'Pololu U3V16F12; MT3608 bench only', $00A06000);
        AddDraftBox(Doc, 5500, 6100, 6900, 7000, 'U1  ESP32 DEVKIT', 'Replaceable module; Wi-Fi optional', $00008000);
        AddDraftLine(Doc, 1700, 6550, 2150, 6550, $000000FF, eMedium);
        AddDraftLine(Doc, 3350, 6550, 3800, 6550, $000080FF, eMedium);
        AddDraftLine(Doc, 5050, 6550, 5500, 6550, $00A06000, eMedium);
        AddDraftLabel(Doc, 900, 5980, 'VBUS / 5V_LOGIC', 9, True, $000000FF);
        AddDraftLabel(Doc, 4200, 5980, '12V_SENSOR', 9, True, $00A06000);
        AddDraftLabel(Doc, 6100, 5980, '3V3 / GND', 9, True, $00008000);

        DrawBeamChannel(Doc, 5000, 1, 'GPIO32  DATUM 0 mm');
        DrawBeamChannel(Doc, 4050, 2, 'GPIO33  DATUM +100 mm');
        DrawBeamChannel(Doc, 3100, 3, 'GPIO34  DATUM +200 mm');
        AddDraftLabel(Doc, 500, 2780, 'THREE BEAMS ONLY - 100 mm VERTICAL CENTRE SPACING', 10, True, $00008000);

        AddDraftBox(Doc, 500, 850, 2350, 1700, 'STATUS INDICATION',
                    'GREEN clear / RED unsafe / AMBER boot-fault', $00008000);
        AddDraftBox(Doc, 2850, 850, 4550, 1700, 'BUTTON + BUZZER',
                    'GPIO13 test; GPIO14 short 150 ms alert', $000080FF);
        AddDraftBox(Doc, 5050, 850, 6900, 1700, 'OPTIONAL RF WAKE',
                    'CC1101 receive-only + wired door reed fallback', $00804000);
        AddDraftLine(Doc, 6200, 6100, 6200, 1700, $00808080, eSmall);

        AddDraftLabel(Doc, 500, 500,
            'FAIL SAFE: blocked beam, open cable, dead transmitter or dead/open sensor = RED / NOT CLEAR.',
            10, True, $000000FF);
        AddDraftLabel(Doc, 500, 250,
            '0805 SMD. CONCEPT ONLY: verify footprints/nets and pass ERC/DRC before fabrication.',
            9, True, $000080FF);
    Finally
        SchServer.ProcessControl.PostProcess(Doc, 'Garage Beam Draft');
    End;

    Doc.GraphicallyInvalidate;
    View := Client.GetCurrentView;
    If View <> Nil Then View.OwnerDocument.SetModified(True);
    ShowMessage('Garage Beam Safety draft generated. Press Ctrl+S to save GarageBeamSafety.SchDoc.');
End;

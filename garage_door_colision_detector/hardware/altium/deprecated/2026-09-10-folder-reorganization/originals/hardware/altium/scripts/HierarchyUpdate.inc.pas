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
    S.Location:=Point(MilsToCoord(X),MilsToCoord(TopY));
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

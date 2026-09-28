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

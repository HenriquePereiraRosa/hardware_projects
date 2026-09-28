{ Targeted synchronization metadata repair. No geometry replacement or ECO execution.
  Recovery files: History\repo-sync-preparation-20260910; Git baseline 2f5708f.
  Run only against the new repository copy. }
Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';

Procedure BoardSignature(B,T);
Var It : IPCB_BoardIterator; GI : IPCB_GroupIterator; C : IPCB_Component; P : IPCB_Pad; NN : String;
Begin
 It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
 C:=It.FirstPCBObject;
 While C<>Nil Do Begin
  T.Add('COMP|'+C.SourceDesignator+'|'+IntToStr(C.X)+'|'+IntToStr(C.Y)+'|'+FloatToStr(C.Rotation)+'|'+C.Pattern);
  GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject)); P:=GI.FirstPCBObject;
  While P<>Nil Do Begin NN:=''; If P.Net<>Nil Then NN:=P.Net.Name;
   T.Add('PAD|'+C.SourceDesignator+'|'+P.Name+'|'+NN+'|'+IntToStr(P.X)+'|'+IntToStr(P.Y)); P:=GI.NextPCBObject;
  End; C.GroupIterator_Destroy(GI); C:=It.NextPCBObject;
 End; B.BoardIterator_Destroy(It); T.Sort;
End;

Procedure RepairBoardNames(Report);
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator; C : IPCB_Component;
 BeforeT,AfterT,Refs : TStringList; R : String; N : Integer; Missing : Boolean;
Begin
 SD:=Client.OpenDocument('PCB',BASE+'GarageBeamSafety.PcbDoc'); Client.ShowDocument(SD); SD.Focus;
 B:=PCBServer.GetCurrentPCBBoard; If B=Nil Then Abort;
 BeforeT:=TStringList.Create; AfterT:=TStringList.Create; Refs:=TStringList.Create;
 BoardSignature(B,BeforeT); BeforeT.SaveToFile(BASE+'RepositorySync.before.txt');
 It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
 Missing:=False; C:=It.FirstPCBObject;
 While C<>Nil Do Begin
  R:=C.SourceDesignator;
  Report.Add('PCB_BEFORE|'+R+'|NAME='+C.Name.Text+'|UID='+C.SourceUniqueId+'|PATTERN='+C.Pattern);
  If (R='') Or (Refs.IndexOf(R)>=0) Then Begin Missing:=True; Report.Add('MISSING_OR_DUPLICATE_IDENTITY|X='+IntToStr(C.X)+'|Y='+IntToStr(C.Y)+'|COMMENT='+C.Comment.Text); End;
  Refs.Add(R); C:=It.NextPCBObject;
 End; B.BoardIterator_Destroy(It);
 If Missing Then Begin
  Report.Add('PCB_REPAIR_SKIPPED: missing identities require explicit component matching; no PCB changes made');
  BeforeT.Free; AfterT.Free; Refs.Free; Exit;
 End;
 N:=0; PCBServer.PreProcess;
 Try
  It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject)); It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
  While C<>Nil Do Begin
   R:=C.SourceDesignator;
   If (C.Name.Text='') Or (C.Name.Text='Designator1') Or (C.Name.Text='Designator') Then Begin
    C.Name.Text:=R; Report.Add('RESTORED_PCB_DESIGNATOR|'+R); N:=N+1;
   End Else If C.Name.Text<>R Then Report.Add('REVIEW_NAME_CONFLICT|'+R+'|'+C.Name.Text);
   C:=It.NextPCBObject;
  End; B.BoardIterator_Destroy(It);
 Finally PCBServer.PostProcess; End;
 BoardSignature(B,AfterT); AfterT.SaveToFile(BASE+'RepositorySync.after.txt');
 If BeforeT.Text<>AfterT.Text Then Begin ShowMessage('Unexpected geometry/connectivity change: do not save'); Abort; End;
 If N>0 Then Begin B.ViewManager_FullUpdate; SD.Modified:=True; SD.DoFileSave('PCB Binary 6.0'); End;
 Report.Add('PCB_NAMES_RESTORED|'+IntToStr(N)); Report.Add('PCB_GEOMETRY_AND_NET_ASSIGNMENTS_UNCHANGED');
 BeforeT.Free; AfterT.Free; Refs.Free;
End;

Procedure MarkExternal(F,Report);
Var SD : IServerDocument; D : ISch_Document; It : ISch_Iterator; C : ISch_Component; R : String; N : Integer;
Begin
 SD:=Client.OpenDocument('SCH',BASE+F); Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
 If D=Nil Then Abort; N:=0;
 SchServer.ProcessControl.PreProcess(D,'Keep external hardware out of PCB netlist');
 Try
  It:=D.SchIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent)); C:=It.FirstSchObject;
  While C<>Nil Do Begin
   R:=C.Designator.Text;
   If (R='RX1') Or (R='RX2') Or (R='RX3') Or (R='RX4') Or (R='TX1') Or (R='TX2') Or (R='TX3') Or (R='TX4') Or (R='PS1') Or (R='PS2') Then Begin
    Report.Add('EXTERNAL_KIND|'+R+'|BEFORE='+IntToStr(Ord(C.ComponentKind)));
    If C.ComponentKind<>eComponentKind_Mechanical Then Begin C.ComponentKind:=eComponentKind_Mechanical; N:=N+1; End;
   End;
   C:=It.NextSchObject;
  End; D.SchIterator_Destroy(It);
 Finally SchServer.ProcessControl.PostProcess(D,'Keep external hardware out of PCB netlist'); End;
 If N>0 Then Begin D.GraphicallyInvalidate; SD.Modified:=True; SD.DoFileSave('SCHBinary5.0'); End;
 Report.Add('EXTERNAL_CHANGED_TO_MECHANICAL|'+F+'|'+IntToStr(N));
End;

Procedure PrepareRepositorySync;
Var T : TStringList;
Begin
 T:=TStringList.Create;
 Try
  RepairBoardNames(T);
  MarkExternal('04_Optical_Heads.SchDoc',T);
  MarkExternal('05_Installation.SchDoc',T);
  T.Add('SAVED_METADATA_ONLY; schematic-to-PCB ECO still required');
 Finally T.SaveToFile(BASE+'RepositorySync.audit.txt'); T.Free; End;
 ShowMessage('Repository synchronization metadata saved. No ECO executed. Review RepositorySync.audit.txt.');
End;

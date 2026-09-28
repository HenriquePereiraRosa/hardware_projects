Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Procedure AuditRepairParts;
Var SD : IServerDocument; L : IPCB_Library; LI : IPCB_LibraryIterator; C : IPCB_LibComponent;
 GI : IPCB_GroupIterator; O : IPCB_Primitive; P : IPCB_Pad; T,F : TStringList; I : Integer;
Begin
 T:=TStringList.Create; F:=TStringList.Create;
 F.Add('PCB - CAPACITOR - ALUMINIUM - CAP AL TH D10 L5 H12.5.PCBLIB');
 F.Add('PCB - CAPACITOR - ALUMINIUM - CAP TH ALUM ELEC D8.00mm S3.50mm H11.50mm.PCBLIB');
 F.Add('PCB - DIODES - DO214AA SMB.PCBLIB'); F.Add('PCB - DIODES - DO214AC SMA.PCBLIB'); F.Add('PCB - DIODES - SOD-123.PCBLIB');
 F.Add('PCB - LEADED - SOT-23 - NEXPERIA SOT-23-3.PCBLIB'); F.Add('PCB - SWITCH - OMRON B3FS-1012P.PcbLib');
 F.Add('PCB - FUSE - FUSE 2410_6125 2.PcbLib');
 For I:=0 To F.Count-1 Do Begin
  SD:=Client.OpenDocument('PCBLIB',BASE+'lib\celestial\'+F[I]); Client.ShowDocument(SD); SD.Focus; L:=PCBServer.GetCurrentPCBLibrary;
  If L=Nil Then Abort;
  LI:=L.LibraryIterator_Create; LI.AddFilter_ObjectSet(MkSet(eComponentObject)); C:=LI.FirstPCBObject;
  While C<>Nil Do Begin
   T.Add('LIB|'+F[I]+'|'+C.Name+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y)));
   GI:=C.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject;
   While O<>Nil Do Begin
    If O.ObjectId=ePadObject Then Begin P:=O;
     T.Add('PAD|'+P.Name+'|'+FloatToStr(CoordToMMs(P.X-C.X))+'|'+FloatToStr(CoordToMMs(P.Y-C.Y))+'|'+FloatToStr(CoordToMMs(P.TopXSize))+'|'+FloatToStr(CoordToMMs(P.TopYSize))+'|'+FloatToStr(CoordToMMs(P.HoleSize)));
    End;
    If O.ObjectId=eComponentBodyObject Then T.Add('BODY');
    O:=GI.NextPCBObject;
   End; C.GroupIterator_Destroy(GI); C:=LI.NextPCBObject;
  End; L.LibraryIterator_Destroy(LI);
 End;
 T.SaveToFile(BASE+'RepairParts.inventory.txt'); T.Free; F.Free; ShowMessage('Repair library inventory saved. No design changes.');
End;

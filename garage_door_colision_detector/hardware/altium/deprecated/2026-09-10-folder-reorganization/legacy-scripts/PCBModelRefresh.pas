{ Read-only inventory first. The update entry is added only after inventory review. }
Const ROOT = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';
Procedure InspectPCBModels;
Var SD : IServerDocument; B : IPCB_Board; It : IPCB_BoardIterator;
 C : IPCB_Component; GI : IPCB_GroupIterator; O : IPCB_Primitive; P : IPCB_Pad;
 Lines : TStringList; N : String; K : Integer;
Begin
 Lines:=TStringList.Create; Lines.Add('START'); Lines.SaveToFile(ROOT+'PCBModelInventory.txt');
 SD:=Client.OpenDocument('PCB',ROOT+'GarageBeamSafety.PcbDoc');
 Client.ShowDocument(SD); SD.Focus; B:=PCBServer.GetCurrentPCBBoard;
 Lines.Add('BOARD OPEN'); Lines.SaveToFile(ROOT+'PCBModelInventory.txt');
 It:=B.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject));
 It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll); C:=It.FirstPCBObject;
 While C<>Nil Do Begin
  Lines.Add('COMP|'+C.SourceDesignator+'|'+C.Pattern+'|'+FloatToStr(CoordToMMs(C.X))+'|'+FloatToStr(CoordToMMs(C.Y))+'|'+FloatToStr(C.Rotation));
  GI:=C.GroupIterator_Create; GI.SetState_FilterAll; O:=GI.FirstPCBObject; K:=0;
  While O<>Nil Do Begin
   If O.ObjectId=ePadObject Then Begin
    P:=O; N:='NOT_READ';
    Lines.Add('PAD|'+C.SourceDesignator+'|'+P.Name+'|'+N+'|'+FloatToStr(CoordToMMs(P.X))+'|'+FloatToStr(CoordToMMs(P.Y))+'|'+FloatToStr(CoordToMMs(P.TopXSize))+'|'+FloatToStr(CoordToMMs(P.TopYSize)));
   End;
   If O.ObjectId=eComponentBodyObject Then K:=K+1;
   O:=GI.NextPCBObject;
  End;
  C.GroupIterator_Destroy(GI); Lines.Add('BODIES|'+C.SourceDesignator+'|'+IntToStr(K));
  C:=It.NextPCBObject;
 End;
 B.BoardIterator_Destroy(It); Lines.SaveToFile(ROOT+'PCBModelInventory.txt'); Lines.Free;
End;

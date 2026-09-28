Const BASE='C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\';
Procedure AuditPowerConnections;
Var SD : IServerDocument; D : ISch_Document; It,CI : ISch_Iterator;
 O,P : ISch_GraphicalObject; C : ISch_Component; S : TStringList; I : Integer;
Begin
 SD:=Client.OpenDocument('SCH',BASE+'01_Power_Control.SchDoc'); Client.ShowDocument(SD); SD.Focus;
 D:=SchServer.GetCurrentSchDocument; S:=TStringList.Create;
 It:=D.SchIterator_Create; It.SetState_FilterAll; O:=It.FirstSchObject;
 While O<>Nil Do Begin
  If O.ObjectId=eSchComponent Then Begin
   C:=O; S.Add('COMP|'+C.Designator.Text+'|'+C.Comment.Text+'|'+C.LibReference+'|PART='+IntToStr(C.CurrentPartID));
   CI:=C.SchIterator_Create; CI.SetState_FilterAll; P:=CI.FirstSchObject;
   While P<>Nil Do Begin
    If P.ObjectId=ePin Then S.Add('PIN|'+C.Designator.Text+'|'+P.Designator+'|'+P.Name+'|'+IntToStr(P.Location.X)+'|'+IntToStr(P.Location.Y)+'|ORIENT='+IntToStr(Ord(P.Orientation))+'|PART='+IntToStr(P.OwnerPartId)+'|LENGTH='+IntToStr(P.PinLength));
    P:=CI.NextSchObject;
   End; C.SchIterator_Destroy(CI);
  End;
  If (O.ObjectId=eNetLabel) Or (O.ObjectId=ePowerObject) Then S.Add('NET|'+O.Text+'|'+IntToStr(O.Location.X)+'|'+IntToStr(O.Location.Y));
  If O.ObjectId=eWire Then For I:=1 To O.VerticesCount Do S.Add('WIRE|'+IntToStr(I)+'|'+IntToStr(O.GetState_Vertex(I).X)+'|'+IntToStr(O.GetState_Vertex(I).Y));
  O:=It.NextSchObject;
 End; D.SchIterator_Destroy(It); S.SaveToFile(BASE+'PowerConnections.audit.txt'); S.Free;
 ShowMessage('Read-only power audit saved.');
End;

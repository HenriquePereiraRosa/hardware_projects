{ Read-only native library probe. No schematic or source-library save. }
Var ProbeLog : TStringList;

Procedure CountChildren(C,TagText);
Var I : ISch_Iterator; O : ISch_BasicContainer; N : Integer;
Begin
 I:=C.SchIterator_Create; I.SetState_FilterAll; N:=0;
 Try
  O:=I.FirstSchObject;
  While O<>Nil Do Begin
   ProbeLog.Add(TagText+'|object='+IntToStr(Ord(O.ObjectId)));
   N:=N+1; O:=I.NextSchObject;
  End;
 Finally C.SchIterator_Destroy(I); End;
 ProbeLog.Add(TagText+'|TOTAL='+IntToStr(N));
End;

Procedure RunSymbolProbe;
Var SD : IServerDocument; L : ISch_Lib; I : ISch_Iterator;
 C,SelectedC,CloneC : ISch_Component;
 J : ISch_Iterator; O,NewO : ISch_BasicContainer;
Begin
 ProbeLog:=TStringList.Create;
 Try
  SD:=Client.OpenDocument('SCHLIB','C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\lib\reviewed-sources\SCH - PASSIVES - RESISTOR.SCHLIB');
  If SD=Nil Then Begin ShowMessage('Cannot open resistor source'); Exit; End;
  Client.ShowDocument(SD); SD.Focus;
  L:=SchServer.GetCurrentSchDocument;
  I:=L.SchLibIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
  SelectedC:=Nil;
  Try
   C:=I.FirstSchObject;
   While C<>Nil Do Begin
    ProbeLog.Add('LIBENTRY|'+C.LibReference);
    If C.LibReference='Resistor' Then SelectedC:=C;
    C:=I.NextSchObject;
   End;
  Finally L.SchIterator_Destroy(I); End;
  If SelectedC<>Nil Then Begin
   CountChildren(SelectedC,'DIRECT');
   L.CurrentSchComponent:=SelectedC;
   CountChildren(L.CurrentSchComponent,'CURRENT');
   CloneC:=L.CurrentSchComponent.Replicate;
   CountChildren(CloneC,'CLONE');
   J:=SelectedC.SchIterator_Create; J.SetState_FilterAll;
   Try
    O:=J.FirstSchObject;
    While O<>Nil Do Begin
     If (O.ObjectId=ePin) Or (O.ObjectId=ePolyline) Then Begin
      NewO:=O.Replicate; CloneC.AddSchObject(NewO);
     End;
     O:=J.NextSchObject;
    End;
   Finally SelectedC.SchIterator_Destroy(J); End;
   CountChildren(CloneC,'EXPLICIT_CHILD_COPY');
  End;
  ProbeLog.SaveToFile('C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\scripts\SymbolProbe\report.txt');
  ShowMessage('Symbol probe finished. No schematic edited.');
 Finally ProbeLog.Free; End;
End;

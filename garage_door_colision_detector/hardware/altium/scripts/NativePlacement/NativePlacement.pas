{ Native library loading test. Only a NEW temporary schematic is created. }
Procedure RunNativePlacement;
Var SD : IServerDocument; D : ISch_Document; C : ISch_Component;
 I : ISch_Iterator; O : ISch_BasicContainer; T : TStringList; N : Integer;
Begin
 T:=TStringList.Create;
 Try
  SD:=Client.OpenNewDocument('SCH','NativePlacementProbe','NativePlacementProbe',False);
  If SD=Nil Then Exit;
  Client.ShowDocument(SD); SD.Focus; D:=SchServer.GetCurrentSchDocument;
  IntegratedLibraryManager.PlaceLibraryComponent('Resistor',
   'C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\lib\reviewed-sources\SCH - PASSIVES - RESISTOR.SCHLIB',
   'Orientation=0|Location.X=50000000|Location.Y=50000000');
  I:=D.SchIterator_Create; I.AddFilter_ObjectSet(MkSet(eSchComponent));
  C:=I.FirstSchObject; D.SchIterator_Destroy(I);
  If C=Nil Then Begin ShowMessage('Native placement produced no component'); Exit; End;
  I:=C.SchIterator_Create; I.SetState_FilterAll; N:=0;
  Try
   O:=I.FirstSchObject;
   While O<>Nil Do Begin T.Add('OBJECT='+IntToStr(Ord(O.ObjectId))); N:=N+1; O:=I.NextSchObject; End;
  Finally C.SchIterator_Destroy(I); End;
  T.Add('TOTAL='+IntToStr(N));
  T.SaveToFile('C:\dev\projects\h\hardware_projects\garage_door_colision_detector\hardware\altium\scripts\NativePlacement\report.txt');
  D.GraphicallyInvalidate;
  ShowMessage('Native placement probe completed on a NEW unsaved sheet. Existing schematics unchanged.');
 Finally T.Free; End;
End;

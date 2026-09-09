Const
  BASE = 'C:\dev\projects\h\garage_door_colision_detector\hardware\altium\';

Procedure InspectLibraries;
Var SD : IServerDocument; L : ISch_Lib; C : ISch_Component;
    It, PI : ISch_Iterator; P : ISch_Pin; O : ISch_GraphicalObject;
    Lines : TStringList; M : ISch_Implementation;
Begin
  Lines := TStringList.Create;
  Try
    SD := Client.OpenDocument('SCHLIB', BASE + 'lib\ESP32-DEVKITC-32E\ESP32-DEVKITC-32E.SchLib');
    Client.ShowDocument(SD); SD.Focus;
    L := SchServer.GetCurrentSchDocument;
    It := L.SchLibIterator_Create; It.AddFilter_ObjectSet(MkSet(eSchComponent));
    C := It.FirstSchObject;
    While C <> Nil Do Begin
      Lines.Add('COMP|' + C.LibReference);
      PI := C.SchIterator_Create; PI.SetState_FilterAll; O := PI.FirstSchObject;
      While O <> Nil Do Begin
        If O.ObjectId = ePin Then Begin P := O;
          Lines.Add('PIN|' + P.Designator + '|' + P.Name + '|' + IntToStr(P.Location.X) + '|' + IntToStr(P.Location.Y) + '|' + IntToStr(P.Orientation)); End;
        If O.ObjectId = eImplementation Then Begin M := O; Lines.Add('MODEL|' + M.ModelType + '|' + M.ModelName); End;
        O := PI.NextSchObject;
      End;
      C.SchIterator_Destroy(PI); C := It.NextSchObject;
    End;
    L.SchIterator_Destroy(It);
    Lines.SaveToFile(BASE + 'lib\LibraryInspection.txt');
  Finally Lines.Free; End;
End;

Procedure OpenESP3D;
Var SD : IServerDocument;
Begin
  SD := Client.OpenDocument('PCBLIB', BASE + 'lib\ESP32-DEVKITC-32E\MODULE_ESP32-DEVKITC-32E.PcbLib');
  Client.ShowDocument(SD); SD.Focus;
End;

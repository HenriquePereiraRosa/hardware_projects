Procedure Probe;
Var L : TStringList;
Begin
    L := TStringList.Create;
    Try
        L.Add('ALTIUM_SCRIPT_OK');
        L.Add(DateTimeToStr(Now));
        L.SaveToFile('C:\dev\projects\h\garage_door_colision_detector\tmp\altium_probe_result.txt');
    Finally
        L.Free;
    End;
End;

# D3 PCB and optical carrier definition

This file is the authoritative layout brief until a verified native `GarageBeamSafety.PcbDoc` is generated in Altium.

## Sensor/controller carrier

- Finished outline: 50.0 mm × 240.0 mm, two-layer FR-4.
- Coordinate origin: lower-left board corner.
- Optical/mechanical centreline: X = 25.0 mm.
- Beam 1 datum: (25.0, 20.0) mm.
- Beam 2 datum: (25.0, 120.0) mm.
- Beam 3 datum: (25.0, 220.0) mm.
- Mount holes: (5, 5), (45, 5), (5, 235), (45, 235) mm; 3.2 mm drill and 10 mm copper-free diameter.
- J2/J3/J4 are placed beside their matching beam datum and ordered `12V, 0V, SIG` from left to right when viewed from the component side.
- Sensors attach with replaceable mechanical clamps/slots; their factory flying leads terminate at J2–J4. Do not solder an industrial sensor body to the PCB.
- USB-C J1 is centred on the lower edge. Put the ESP32 antenna at the opposite board edge or on a side edge with the specified antenna keepout.

## Reflector carrier

- Finished outline: 30.0 mm × 240.0 mm.
- Reflector centreline: X = 15.0 mm.
- Reflector centres: (15, 20), (15, 120), and (15, 220) mm.
- Mount holes: (5, 5), (25, 5), (5, 235), (25, 235) mm; 3.2 mm drill.
- This is a passive alignment carrier; omit copper and solder mask if the board vendor permits. White silkscreen marks beam numbers and centre crosshairs.
- Reflectors must be genuine corner-cube/polarized-sensor-compatible parts, not plain mirrors.

## Alignment tolerance

The 100 mm pitch controls only relative vertical spacing. Carrier mounting slots must allow the complete three-beam assembly to translate and rotate during alignment. Lock it after alignment and repeat the optical validation; PCB hole accuracy does not replace the on-site knife-edge test.

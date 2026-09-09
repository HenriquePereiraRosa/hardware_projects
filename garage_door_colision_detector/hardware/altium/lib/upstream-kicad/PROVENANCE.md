# Upstream CAD assets — not yet linked in Altium

Downloaded 2026-09-06 from the official KiCad GitHub library repositories.
Attribution: KiCad library contributors. CC-BY-SA 4.0 with the KiCad design
exception; see LICENSE.md. Original library files are unmodified.

| File | Source | SHA256 |
|---|---|---|
| SOT-23.kicad_mod | https://raw.githubusercontent.com/KiCad/kicad-footprints/master/Package_TO_SOT_SMD.pretty/SOT-23.kicad_mod | DB5B998F0D36708205A4B8EDC0DB1501DEB0246A81B52E9CB036CFD58B7570D3 |
| SOT-23.step | https://raw.githubusercontent.com/KiCad/kicad-packages3D/master/Package_TO_SOT_SMD.3dshapes/SOT-23.step | 9FE9AF3CC6CF3D3BC3BD3DA71731AF2037C67F690245102A20E1E39A33E9ADE4 |
| Transistor_FET.lib | https://raw.githubusercontent.com/KiCad/kicad-symbols/master/Transistor_FET.lib | 42CFF093465C37EEFFDAA56D636A0013449B878C9D26ACBE6512D55261F349B1 |

AO3400A is a symbol alias in the BSS138 definition (G=1, S=2, D=3).
That is shared graphical/pin geometry, **not permission to substitute BSS138 electrically**.
The footprint's original 3D reference is to a WRL file in the KiCad installation;
it does not automatically link this downloaded STEP. Native Altium import,
model orientation, pad/pin mapping and datasheet dimensional checks remain pending.
This is community CAD, not manufacturer-certified AO3400A CAD.

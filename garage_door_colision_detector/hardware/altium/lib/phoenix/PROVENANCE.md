# Phoenix Contact 1715734 CAD

Selected part: **MKDS 1,5/3-5,08**, green, three positions, 5.08 mm pitch.
This replaces the previous incorrect MKDS/MKDSN association with 1729131.

Manufacturer: https://www.phoenixcontact.com/en-us/products/printed-circuit-board-terminal-mkds-15-3-508-1715734

Downloaded 2026-09-08 from KiCad's public repositories:

- https://github.com/KiCad/kicad-footprints/blob/master/TerminalBlock_Phoenix.pretty/TerminalBlock_Phoenix_MKDS-1%2C5-3-5.08_1x03_P5.08mm_Horizontal.kicad_mod
- https://github.com/KiCad/kicad-packages3D/blob/master/TerminalBlock_Phoenix.3dshapes/TerminalBlock_Phoenix_MKDS-1%2C5-3-5.08_1x03_P5.08mm_Horizontal.step

These are **community KiCad models, not manufacturer-certified CAD**. Attribution: KiCad library contributors / kicad StepUp (2020). See LICENSE.md and STEP header, CC-BY-SA 4.0 with ECAD exception.

Native OpticalHardware.PcbLib reproduces the 1.3 mm drill, 2.6 mm pads, 5.08 mm pitch and body outline, and embeds this STEP. Its 2D coordinates reverse KiCad Y. Check STEP registration against all three pins in Altium and a physical sample before fabrication. Do not substitute a generic KF301 merely because its pitch matches.

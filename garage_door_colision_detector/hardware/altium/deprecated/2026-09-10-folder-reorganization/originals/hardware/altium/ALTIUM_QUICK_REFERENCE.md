# Altium Designer quick reference

This is the working cheat sheet for `GarageBeamSafety.PrjPcb`. Shortcuts are
context-sensitive: click the schematic or PCB editor first. While any placement
or routing command is active, press **Shift+F1** to see the shortcuts valid at
that exact moment.

## Open and save

| Task | Command / shortcut |
|---|---|
| Open this project | **File > Open Project**, select `GarageBeamSafety.PrjPcb` |
| Save active document | **Ctrl+S** |
| Save every changed project file | **File > Save All** or the **Save All** toolbar button |
| Show Properties panel | **F11** |
| Exit the current tool | **Esc**; press it twice if a placement tool remains active |
| Undo / redo | **Ctrl+Z** / **Ctrl+Y** |
| Context shortcut help | **Shift+F1** while a command is active |

## Schematic editor

| Task | Command / shortcut |
|---|---|
| Place a component | **Place > Part**, or drag it from the **Components** panel |
| Place an electrical wire | **P, W** (press `P`, then `W`) |
| Place a net label | **P, N** |
| Place a power port | **Place > Power Port** |
| Place a port between sheets | **Place > Port** |
| Move selected item | **M, M**, or drag it |
| Drag while preserving attached wires | **M, D** |
| Rotate item while moving/placing | **Spacebar** |
| Mirror while moving/placing | **X** or **Y** |
| Edit properties before placement | **Tab** |
| Delete selected object | **Delete** |
| Zoom to all objects | **V, F** |

Important: use **Place > Wire**, not **Place > Line**, for electrical
connections. A line is only artwork. A net label must touch a wire at its
electrical attachment point. In this project, `GND`, `3V3`, `5V`, and
`12V_SENSOR` use power ports; named signal labels are used for sheet-to-sheet
GPIO connections.

## PCB editor: viewing and layers

| Task | Command / shortcut |
|---|---|
| 2D layout mode | **2** |
| 3D layout mode | **3** |
| Board-planning mode | **1** |
| View Configuration panel | **L** |
| Next / previous enabled layer | Numpad **+** / Numpad **-** |
| Next / previous signal layer | Numpad **\*** / **Shift+Numpad \*** |
| Cycle enabled layers | **Ctrl+Shift+mouse wheel** |
| Toggle single-layer display | **Shift+S** |
| Flip board in 3D | **V, B** |
| Rotate 3D view | Hold **Shift+right mouse button**, then drag |
| Zoom to board | **V, F** |

During interactive routing, changing to another signal layer automatically
inserts a via when the routing rules allow it.

## PCB editor: placement and routing

| Task | Command / shortcut |
|---|---|
| Place component | **P, C** |
| Move component | **M, C**, then click the component |
| Move selected objects | **M, S** |
| Rotate while moving | **Spacebar** |
| Flip component to other board side | **L** while the component is floating |
| Start interactive routing | **Ctrl+W**, or **Route > Interactive Routing** |
| Place a via | **P, V**; during routing, change layer |
| Place a free track | **P, T** (not a substitute for net-aware routing) |
| Remove routed copper | **Route > Un-Route > Selected** |
| Show connection lines | **View > Connections > Show All** |
| Repour polygons | **Tools > Polygon Pours > Repour All** |
| Run design-rule check | **Tools > Design Rule Check** |
| Update PCB from schematic | **Design > Update PCB Document** |

For this controller, keep the external screw terminals at board edges, the
opto-isolators immediately behind the beam terminals, and the ESP32 antenna end
at an enclosure/board edge with no copper or tall parts beneath the antenna.

## Board outline and 3D models

| Task | Command / shortcut |
|---|---|
| Define board from selected closed outline | Select its tracks, then **Design > Board Shape > Define from Selected Objects** |
| Edit board shape | Press **1**, then **Design > Edit Board Shape** |
| Place a STEP model / 3D body | **Place > 3D Body**, select `.step`/`.stp`, then align it in the Properties panel |
| Inspect component height | Select component, press **F11**, inspect **Height** |
| Check result | Press **3** |

The generated V3 draft uses simple mechanical component envelopes so that
enclosure clearance can be checked immediately. Replace an envelope with the
manufacturer's exact STEP model only after the exact purchased part and
footprint have been verified. The STEP body belongs in the footprint library,
not as an unrelated free model on the board.

## Safe edit sequence for this project

1. Edit the schematic first.
2. Run **Project > Validate PCB Project** and resolve unintended errors.
3. Use **Design > Update PCB Document** and inspect every ECO before accepting it.
4. Place connectors and mechanical constraints first; then protection, sensor
   channels, controller, and UI parts.
5. Route power and ground first, then beam inputs, then low-current indicators.
6. Run the DRC, inspect in 3D, and generate outputs only after exact footprints
   and connector pin numbering are checked against datasheets.

## Project-specific warnings

- This is an advisory detector and must not replace the garage-door maker's
  safety system.
- `CLEAR` must require active current from every enabled sensor. Open wiring,
  missing sensor power, or ESP32 startup remains unsafe.
- Do not order the PCB from the current draft until the actual ESP32 DevKit,
  terminal blocks, DC/DC module, and sensor model have been physically checked.
- The controller PCB is not an optical mounting datum. Sensor/reflector alignment
  belongs to the separate adjustable wall brackets.


# PCB 3D model status

The controller PCB now contains component **height metadata** for clearance
planning, but it deliberately does not contain invented STEP geometry. Altium's
3D view will therefore show the 110 x 85 mm board and holes, but most parts will
remain 2D until the footprint/model pairs below are verified.

| Item | Required model decision |
|---|---|
| ESP32 DevKit | Measure the exact board owned by the builder; common 30-pin DevKit boards are not dimensionally identical. |
| J1/J2/J3/J4/J5 terminals | Use the official STEP model for the exact 5.08 mm terminal family actually purchased. Current draft choice is Phoenix Contact 1729128 or a verified compatible footprint. |
| A2 DC/DC module | Use the official Murata `OKI-78SR-5/1.5-W36-C` STEP model. |
| U2/U3/U4 optocouplers | Use an LTV-817 DIP-4 body matched to the selected footprint. |
| Remaining passives | Use standard axial, radial, TO-92, and diode models only after lead pitch/body diameter verification. |

To attach a model, open or create the footprint library, select the footprint,
choose **Place > 3D Body**, select the manufacturer's `.step`/`.stp` file, set
the standoff/rotation, save the library, then update the PCB from the library.
The exact commands are also listed in
[`../ALTIUM_QUICK_REFERENCE.html`](../ALTIUM_QUICK_REFERENCE.html).

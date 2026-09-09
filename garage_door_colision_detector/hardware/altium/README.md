# Native Altium project

New to Altium or returning after a break? Open
[`ALTIUM_QUICK_REFERENCE.html`](ALTIUM_QUICK_REFERENCE.html) for the dark-theme
schematic, PCB, layer, placement, routing, 3D, validation, and save guide.

`GarageBeamSafety.PrjPcb` is the authoritative hardware project. It contains:

- `00_Mounting_Overview.SchDoc` — first-page dark mounting guide with both
  carriers, garage span, controller location, and three beam paths at 100 mm centres.
- `01_Power_Control.SchDoc` — 12 V terminal input, protection, 5 V buck, and ESP32.
- `02_Beam_Inputs.SchDoc` — three readable isolated sensor-input channels.
- `03_UI_Outputs.SchDoc` — status connector, buzzer, and alignment/test switch.
- `GarageBeamSafety.PcbDoc` — compact 110 × 85 mm controller PCB draft. Field
  terminals are at board edges, each optocoupler is beside its beam connector,
  and the ESP32 is at the opposite edge. Previous demonstration routing was
  intentionally removed; connection lines remain until exact footprints are locked.
  It currently includes 38 automatically generated extruded clearance bodies.
  These are dimensional placeholders, not manufacturer STEP models.
- `GarageBeamSafety_ReflectorCarrier.PcbDoc` — optional passive 30 × 240 mm
  blank-FR-4 mounting carrier with matching 100 mm axes and no copper or powered
  components. The reflectors do not electrically require a PCB.
- `GarageBeamSafety.BomDoc` — native ActiveBOM configuration sourced from the
  schematic parameters.

The legacy CSV BOM and generated dark PDF are retained only as historical draft
artifacts. Do not maintain them; make hardware changes in Altium.

## Open the project

From PowerShell in the repository root:

```powershell
Start-Process -FilePath 'C:\Program Files\Altium\AD24\X2.EXE' `
  -ArgumentList '.\hardware\altium\GarageBeamSafety.PrjPcb'
```

The four schematic sheets use the EnergyMeter template's native title block,
embedded logo, author identity, and a true document `AreaColor` dark canvas.
ActiveBOM derives its parts from these project sheets.

`scripts/ProfessionalRebuild_v2.pas` rebuilds the native schematic sheets.
`scripts/RepairControllerPCB_v3.pas` applies the compact placement, reusable
power terminal, component height data, and the new selected board outline.

## Current engineering status

The native documents are an electrically connected engineering prototype, not
released manufacturing data. The V3 PCB is deliberately unrouted so that a
misleading generated route cannot be mistaken for production work. Before ordering boards:

1. Import or verify the manufacturer land pattern and pin numbering for the
   Phoenix Contact `1729128` two-way 5.08 mm power terminal.
2. Confirm the exact ESP32 DevKit 30-pin dimensions and socket pitch.
3. Replace or formally verify every scripted land pattern against the selected
   manufacturer drawing, then replace its clearance envelope with the exact
   manufacturer STEP model where available.
4. Compile the project, finish net-aware routing, and pass reviewed ERC/DRC
   after the exact ESP32 and connector footprints are locked.
5. Validate that the selected Panasonic EX-L291 sensor bodies can mount at the
   three optical datums without conflicting with electronics or the enclosure.
6. Perform the glossy-surface false-clear optical tests before treating green as
   a trustworthy advisory indication.

The system remains advisory only and must not operate or replace the garage-door
manufacturer's safety system.

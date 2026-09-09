# Garage Beam Safety controller — electrical design D3

Status: reviewable three-beam design; the Altium drawings are not yet released for fabrication.

## Fixed D3 decisions

- Three polarized retroreflective NPN Light-ON sensors on one wall.
- Beam centres form a vertical line at `0 mm`, `100 mm`, and `200 mm` relative to the lowest beam.
- A single 50 × 240 mm sensor/controller carrier PCB keeps the connector and mounting datum for all three heads. The industrial sensors remain mechanically clamped because their bodies and flying leads are not PCB-mount parts.
- A matching passive 30 × 240 mm FR-4 reflector carrier uses the same three 100 mm centre positions. Only this passive carrier/alignment is changed on the opposite wall.
- USB-C 5 V input from an external certified charger. The board does not contain mains.
- Hand-solderable SMD: 0805 resistors/capacitors, SOD-123 diodes, SO-8/SOT-23 semiconductors, and a THT ESP32 DevKit module. Do not substitute 0402 parts; 0402 is substantially smaller than 0805.

The 100 mm spacing is a reasonable compact first geometry, but it does not prove that every relevant part of the car intersects a beam. Final lowest-beam height comes from the actual bumper/body survey. All three beams must be clear to show GREEN.

## USB-C and power tree

```text
Certified USB charger (5 V, >= 2 A) and USB-C cable
 -> J1 USB-C receptacle
    CC1 -> 5.1k -> GND
    CC2 -> 5.1k -> GND
 -> F1 1.5 A resettable fuse
 -> D1 5 V TVS + Q1 reverse-current/ideal-diode stage
 -> +5V_LOGIC -> ESP32 DevKit 5V/VIN
 -> U1 5-to-12 V boost, >= 0.5 A at 12 V
 -> +12V_SENSOR -> three sensor connectors
```

Use a plain 5 V USB-C sink; USB Power Delivery is not required. A charger advertised at 2 A or more is recommended because cable loss and boost-converter startup margin matter. The selected industrial sensors still require 12–24 V, so they must never be connected directly to VBUS. D3 uses the active/preferred Pololu U3V16F12 module footprint for a reliable prototype boost stage; an MT3608 module may be fitted only for bench work after its output is set to 12.0 V. Three EX-L291 sensors draw at most 45 mA total at 12 V, well below the module capability.

Required rail test points: `VBUS`, `5V_LOGIC`, `12V_SENSOR`, `3V3`, and `GND`.

## Fail-safe sensor channels

Each `J2`–`J4` connector is labelled `12V / 0V / SIG`. Use an NPN open-collector sensor configured Light-ON:

```text
+12V_SENSOR ---- 2.2k ----|> optocoupler LED ---- SENSOR_SIGNAL
                          |<| 1N4148W antiparallel

+3V3 ---- 10k ----+---- 1k ---- ESP32 GPIO
                  |
                  +---- optocoupler collector
GND  ------------------- optocoupler emitter
GPIO ------------------- 100 nF ---- GND
```

A clear beam energizes the input and produces LOW. A blocked beam, unplugged sensor, open cable, lost 12 V sensor rail, or open optocoupler produces HIGH and cannot earn CLEAR. A simple three-wire channel cannot diagnose a signal wire shorted to 0 V; per-channel power proof testing remains a future safety improvement.

Per channel:

- LTV-817S optocoupler, SMD gull-wing package.
- 2.2 kΩ 0805, 1%, at least 0.125 W (about 49 mW at 12 V).
- 1N4148W in SOD-123, antiparallel across the optocoupler input.
- 10 kΩ pull-up, 1 kΩ series resistor, and 100 nF capacitor, all 0805.

## ESP32 allocation

| Function | Connector | ESP32 GPIO | Active state |
|---|---:|---:|---|
| Beam 1 | J2 | 32 | LOW = clear |
| Beam 2 | J3 | 33 | LOW = clear |
| Beam 3 | J4 | 34 | LOW = clear |
| Green status | J5 | 25 | HIGH |
| Red status | J5 | 26 | HIGH |
| Amber status | J5 | 27 | HIGH |
| Buzzer driver | J6 | 14 | HIGH |
| Align/test button | SW1 | 13 | LOW |

GPIO34 has no internal pull-up, so the external 10 kΩ resistor is mandatory. GPIO35 and the former fourth channel are not populated in D3.

## PCB constraints

- Controller/sensor carrier: two layers, 1.6 mm FR-4, 1 oz copper, 50 × 240 mm nominal.
- Beam connector/mount datums at Y = 20, 120, and 220 mm, giving exactly 100 mm centre spacing.
- Passive reflector carrier: 30 × 240 mm nominal with reflector centres on the same Y coordinates; it contains no copper or powered parts.
- Keep the USB-C connector and indicators at the lower edge; route sensor cables upward with strain relief.
- Four 3.2 mm mounting holes on each carrier, at least 5 mm copper keepout.
- Keep the 12 V field side and optocoupler inputs away from ESP32 antenna and logic; show the isolation boundary on silkscreen.
- Put the ESP32 antenna at a board edge with no copper beneath it.
- Use 5.08 mm pluggable terminals for sensor flying leads.
- Silkscreen must show `BEAM 1 LOW`, `BEAM 2 +100 mm`, `BEAM 3 +200 mm`, USB power rating, connector polarity, and `ADVISORY ONLY`.

## Release gates

Before fabrication, select the exact ESP32 DevKit and USB-C receptacle footprints, mechanically verify the sensor and reflector mounts, compile the real Altium schematic, pass ERC/DRC, and validate shiny-vehicle false-CLEAR behaviour. The current `.SchDoc` generator produces an editable concept drawing, not a compiled netlist, and no unrelated template PCB may be ordered.

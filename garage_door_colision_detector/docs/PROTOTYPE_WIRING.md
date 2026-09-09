# D3 three-beam prototype wiring

> SUPERSEDED HISTORICAL DRAFT — 5 September 2026: current power is independent regulated 12 V DC adapters with 5.5 × 2.1 mm centre-positive barrel plugs, one per side; controller uses a 5 V buck. USB-C/boost and retroreflector purchasing or wiring below are not current build instructions. See [CURRENT_DESIGN.html](CURRENT_DESIGN.html). Exact through-beam sensor selection and native harness drawings remain pending.

## USB-C power

Use a certified regulated 5 V USB charger rated at least 2 A. The USB-C receptacle needs separate 5.1 kΩ pull-downs from CC1 and CC2 to GND. VBUS feeds the ESP32 5V/VIN pin after the input fuse/protection and also feeds a 5-to-12 V boost converter for the industrial sensors.

Set and verify the boost output at 12.0 V before attaching any sensor. Do not connect a 12–24 V industrial sensor directly to USB VBUS or to an ESP32 pin.

```text
USB-C VBUS -> fuse/protection -> +5V_LOGIC -> ESP32 5V/VIN
                                  |
                                  +-> 5-to-12 V boost -> +12V_SENSOR
USB-C GND  ---------------------------- common power return
```

The optocouplers still separate each sensor signal circuit from the ESP32 logic. The power returns are common on this compact USB-powered D3 controller, so this is functional signal isolation rather than system-wide galvanic isolation.

## Three NPN Light-ON channels

Repeat this circuit for GPIO32, GPIO33 and GPIO34:

```text
+12V_SENSOR -> sensor brown (+V)
GND         -> sensor blue (0V)
+12V_SENSOR -> 2.2k 0805 -> LTV-817 LED anode
sensor black (SIG)       -> LTV-817 LED cathode
1N4148W across optocoupler LED, cathode at the anode side

ESP32 3V3 -> 10k 0805 -> optocoupler collector -> 1k 0805 -> GPIO
GPIO -> 100nF 0805 -> ESP32 GND
optocoupler emitter -> ESP32 GND
```

| Channel | Connector | GPIO | Vertical datum |
|---|---|---:|---:|
| Beam 1 | J2 | 32 | 0 mm |
| Beam 2 | J3 | 33 | +100 mm |
| Beam 3 | J4 | 34 | +200 mm |

Configure every sensor for Light-ON. Expected results for each input:

| Condition | Optocoupler | GPIO | System implication |
|---|---|---|---|
| Matching reflector visible | on | LOW | this beam is clear |
| Beam blocked | off | HIGH | BLOCKED |
| Sensor/cable unplugged | off | HIGH | BLOCKED/OPEN |
| 12 V boost rail lost | off | HIGH | BLOCKED/OPEN |

Only three simultaneous LOW inputs may progress to GREEN after the configured 500 ms confirmation. Validate one optical channel completely before buying and mounting all three sensors.

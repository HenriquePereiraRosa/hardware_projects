# Optical boundary validation

No sensor is approved for the 10 mm clearance installation merely from its spot-size datasheet.

## Fixture

Mount the sensor and receiver/reflector at the actual wall spacing and final height. Use the intended brackets. Place a matte-black opaque knife-edge target on a rigid linear slide with a digital caliper, dial indicator, or micrometer reference. The fixture must move perpendicular to the optical safety plane without rocking.

Mark coordinates relative to the desired forbidden plane; do not infer clearance from the sensor housing position. Log raw input and system state over serial.

## Procedure

For each beam and environmental condition:

1. Warm the powered sensor for 30 minutes.
2. Approach from CLEAR toward BLOCKED in 1 mm steps near the transition and record the first stable BLOCKED position.
3. Continue at least 10 mm beyond transition, then reverse and record the first stable CLEAR position.
4. Repeat 30 cycles from each direction without touching alignment.
5. Repeat after five cold power cycles and after at least four hours.
6. Repeat with garage lights off/on, door open with worst sunlight, and any fluorescent/LED lighting states.
7. Repeat with the target at 0°, ±15°, ±30°, and ±45°.
8. Repeat using representative vehicle surfaces: matte plastic, glossy paint, chrome, glass, and number plate. For retroreflective sensors, deliberately block the reflector while placing each shiny surface in the beam and verify that CLEAR is impossible.
9. Apply a modest repeatable bump/load to each locked bracket, remove the load, and rerun ten cycles.
10. Reduce received-light margin using a dusty transparent film, then clean it and verify recovery.

## Record

- CLEAR→BLOCKED coordinate
- BLOCKED→CLEAR coordinate
- hysteresis for every cycle
- mean, range, and standard deviation
- maximum shift by lighting, angle, time, power cycle, and bracket disturbance
- any false CLEAR with the reflector/receiver path blocked

## Acceptance criteria for a 10 mm minimum safety margin

- **Zero false CLEAR events** in all blocked-path and reflective-surface tests.
- Total transition range across all repetitions and conditions no more than 6 mm (equivalent to ±3 mm about its centre).
- Maximum hysteresis no more than 3 mm.
- Locked-mount disturbance shifts the transition no more than 2 mm.
- At least 2:1 engineering margin between measured worst-case transition uncertainty and the allocated optical uncertainty. For a 10 mm total clearance budget, reserve at least 6 mm for optical/alignment uncertainty unless the full installation tolerance stack proves better.
- Sensor stability indicator remains healthy when clear; marginal/reduced-excess-gain indication must produce FAULT or trigger maintenance, never GREEN.

Any false CLEAR is an immediate rejection. If a generic retroreflective sensor fails, test Panasonic EX-L291. If retroreflection itself fails due to shiny vehicle surfaces, use an opposed Omron E3Z-LT61 or Panasonic EX-L211/EX-L212 and solve the opposite-wall wiring mechanically.


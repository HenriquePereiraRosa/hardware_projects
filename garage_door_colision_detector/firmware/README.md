# Firmware — RGB indicator revision

Requires the new three-MOSFET 12V common-anode RGB output, not the legacy J5 circuit.
GPIO26=red gate, GPIO25=green gate, GPIO27=blue gate. GPIO14 is unused.
Steady green=CLEAR; steady red=BLOCKED; flashing amber=BOOT/SELF_TEST/FAULT.
No buzzer. Darkness is not a clear indication. Brightness and amber colour balance
are configurable in `include/configuration.h`. The blue channel is reserved.

PlatformIO with Arduino framework. The physical safety logic is local and starts with Wi-Fi disabled.

```powershell
cd firmware
pio test -e native
pio run -e esp32dev
pio device monitor
```

PlatformIO is not installed in the current shell, so the test/build commands have not yet been executed here. Tests cover delayed CLEAR, BLOCKED priority, FAULT priority, RGB mapping, dimming and fault flashing. A hardware visibility test through the closed windscreen is required.

Default D3 configuration enables three beams on GPIO32, GPIO33 and GPIO34. The complete system earns CLEAR only when all three are continuously clear. LOW means clear because the proposed NPN Light-ON sensor energizes the optocoupler.

D0 intentionally reports an electrical open as `BLOCKED/OPEN`; it cannot distinguish those two conditions using one binary output. D1 will add optional channel power proof testing and then expose confirmed diagnostic faults as yellow/FAULT.

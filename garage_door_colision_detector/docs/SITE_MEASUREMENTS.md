# Measurements and photographs needed for D1

These inputs determine the native Altium board outline, cable glands, brackets and through-beam sensor selection. The current wired architecture is recorded in [CURRENT_DESIGN.html](CURRENT_DESIGN.html); earlier retroreflective proposals are superseded.

## Measurements

1. Clear wall-to-wall optical span at the proposed lowest beam height, then at +100 mm and +200 mm, to the nearest 10 mm.
2. Distance from the intended beam plane to the closed garage door and to every moving hinge/track component.
3. Available flat mounting area on each wall: width, height, depth, and wall material.
4. Maximum allowed protrusion from each wall so the car/door cannot strike a sensor or guard.
5. Controller-to-nearest socket/USB charger distance and preferred USB cable route.
6. Possible low-voltage cable route around the door frame, even if inconvenient; record its approximate length. This preserves the opposed-beam fallback.
7. Exact ESP32 board length, width, mounting-hole positions (if any), USB connector side, and the printed board/module name.
8. Preferred status-light viewing position and approximate eye line when parking.

## Photographs

- Wide view from inside facing the closed door.
- Each side wall at the proposed beam plane with a ruler or tape visible.
- Door fully open and fully closed, showing rails, hinges, cables and seals.
- Car parked in the tightest normal position, photographed from both sides and above the front corner if possible.
- Close-up of the front surfaces that may cross each beam: paint, grille, lamps, chrome, glass and number plate.
- Exact ESP32 board, both sides, next to a ruler.

Avoid including faces, vehicle registration, house number, keys, alarm panels, or other sensitive details if they are not needed.

## Provisional mechanical direction — updated 5 September 2026

The user corrected the proposed outer enclosure envelope to approximately **100 × 100 × 300 mm** (width × depth × height), subject to component fit. Three optical axes at 100 mm centres span 200 mm. Nominal 50 mm allowances above and below that span give 300 mm overall; brackets, glands and the PCB may require more. Four beams at the same pitch would span 300 mm and need additional end allowances. This is not an approved purchasing or drilling dimension. See [the current dark-theme design decision](CURRENT_DESIGN.html).

- Use a rigid wall-mounted vertical backplate/rail with independently adjustable optical heads. Attach it to the wall, not the removable cover.
- Keep the controller PCB short and mechanically separate from the optical heads. The earlier 50 × 240 mm PCB proposal is superseded; no new PCB dimensions are frozen.
- Current architecture: matched through-beam emitter and receiver heads, with wired power on both sides. Receivers and one ESP32 are on the controller side; emitters need no second ESP32. The former EX-L291/RF-330 proposal is superseded. Exact replacement sensor is not selected yet.
- PCB orientation does not set the optical axis. Brackets set the head direction; cable bend clearance and connector access determine the required space behind it.
- The emitter-side carrier may be smaller than the controller enclosure; allow terminals, cable strain relief and individual head adjustment.
- User-confirmed nominal optical-axis spacing is 100 mm. Absolute mounting height still needs confirmation against the car and the moving-door envelope.
- Verify the entire moving-door envelope, including hinges, seals and tracks. The drawing's 43 mm dimension needs defined endpoints before setting the beam offset.

Final enclosure depth follows the selected head, bracket, cable bend envelope, connector access, PCB socket stack height and cover clearance. A cut-to-length cover is not automatically IP54; any claimed protection needs suitable closures, glands and validation.

Each optical head should use a two-axis fine mount: a rigid base, yaw and pitch flexure/slots, two opposed M3 adjustment screws or a commercial miniature pan/tilt bracket, spring preload, and separate lock screws. Friction-only ball joints are not preferred for the final 10 mm installation.

# Procurement shortlist — 23 August 2026

> SUPERSEDED HISTORICAL DRAFT — 5 September 2026: current power is independent regulated 12 V DC adapters with 5.5 × 2.1 mm centre-positive barrel plugs, one per side; controller uses a 5 V buck. USB-C/boost and retroreflector purchasing or wiring below are not current build instructions. See [CURRENT_DESIGN.html](CURRENT_DESIGN.html). Exact through-beam sensor selection and native harness drawings remain pending.

Prices and marketplace inventory change. D3 has three beams at 100 mm centres, but buy one sensor/reflector pair for the optical experiment before buying the other two.

## Recommended first purchase if both sides cannot be wired

### Panasonic EX-L291 (NPN), retroreflective laser

- 12–24 VDC, NPN open collector, Light-ON/Dark-ON selectable, response ≤0.5 ms, IP67, Class 1 red laser.
- Typical spot approximately 6 × 4 mm at 1 m, growing to approximately 18 × 10 mm at 4 m; 4 m rated range; perpendicular repeatability is specified at 0.2 mm or less; RF-330 reflector and mounting plate are included.
- Choose **EX-L291**, not EX-L291-P, for the draft's NPN input convention. The P suffix is PNP.
- Expected distributor price: roughly €90–€160; verify VAT and stock.
- Official: [Panasonic EX-L291 NPN specifications](https://industry.panasonic.com/global/en/products/fasys/sensor/photoelectric/number/ex-l291)
- EU distributor search: [TME EX-L291 family](https://www.tme.eu/en/katalog/?search=EX-L291)
- DigiKey search: [EX-L291](https://www.digikey.es/en/products/result?s=N4IgTCBcDaIIwAYCsBaAjABgEwgLoF8g)
- AliExpress search only—not assumed genuine: [EX-L291](https://www.aliexpress.com/w/wholesale-ex--l291.html)

This is a strong high-reliability same-side experiment because the emitter, receiver and cable are all in Box A and the opposite side is passive. At garage spans above roughly 1–2 m, its beam is wider than the requested 3–6 mm target, so only the knife-edge repeatability test can accept it.

## Alternative same-side industrial sensor

### Omron E3Z-LR61 2M + reflector

- 12–24 VDC, NPN, selectable Light-ON/Dark-ON, polarized/MSR retroreflective, Class 1 laser, IP67, 1 ms.
- Omron specifies a 5 mm laser spot reference and 0.2–7 m with E39-R12, or longer range with larger reflectors.
- Sensor indicative price around €122–€191 including VAT depending supplier/condition; reflector can add €20–€65.
- Official: [Omron E3Z laser specifications](https://www.ia.omron.com/products/family/1747/specification.html)
- Spain product page: [Omron Spain E3Z-LR61 2M](https://industrial.omron.es/es/products/E3Z-LR61-2M)
- Spain distributor: [RS Spain E3Z-LR61 2M](https://es.rs-online.com/web/p/fotocelulas/2147920)
- Lower-cost industrial reseller example: [Radwell E3Z-LR61 2M](https://www.radwell.de/en-DE/Buy/OMRON/OMRON/E3Z-LR61%202M)
- Reflector: [TME E39-R12](https://www.tme.eu/en/details/e39-r12/photoelectric-sensors-reflectors/omron/)
- AliExpress search only—counterfeits/clones are possible: [E3Z-LR61](https://www.aliexpress.com/w/wholesale-e3z--lr61.html)

Do not buy the expensive E39-R12 until the seller confirms whether the chosen E3Z-LR61 listing already includes a suitable reflector. A genuine E39-R1/R6 may be adequate at garage distance but the reflector size affects alignment and must be included in boundary testing.

## Preferred opposed-beam fallback

### Omron E3Z-LT61 2M

- Transmitter/receiver set, NPN receiver output, 12–24 VDC, Class 1 laser, IP67, 1 ms.
- Reference spot diameter 5 mm at 3 m and 60 m maximum rating; the huge range is not the goal, the narrow, repeatable spot is.
- Official: [Omron E3Z-LT/LR/LL datasheet](https://www.ia.omron.com/data_pdf/cat/e3z-lt_lr_ll_ds_e_7_5_csm2158.pdf)
- Distributor search: [RS Spain search](https://es.rs-online.com/web/c/?searchTerm=E3Z-LT61)
- AliExpress search only: [E3Z-LT61](https://www.aliexpress.com/w/wholesale-e3z--lt61.html)

This is optically cleaner than retroreflection, but the far-wall transmitter needs a 12 V cable. A thin two-core low-voltage cable can often be routed high around the door frame; mains must not enter either project box.

## Cheap prototype sensor

Generic marketplace descriptions are inconsistent and often use “laser” for a wide red LED. Search for all of: **red laser, retroreflective, NPN, Light-ON/Dark-ON selectable, 10–30 VDC, reflector included, IP65/IP67**. Do not accept only “E3F” or “photoelectric switch” as proof of a narrow beam.

- [AliExpress laser retroreflective NPN search](https://www.aliexpress.com/w/wholesale-laser-retroreflective-photoelectric-sensor-npn.html)
- [Amazon Spain laser photoelectric NPN search](https://www.amazon.es/s?k=sensor+fotoelectrico+laser+retroreflectivo+NPN+12V)

Budget approximately €15–€35 for one generic sensor and reflector. It is a test article, not an accepted safety sensor. Reject it if there is no credible datasheet, the spot exceeds the required geometry, it uses a relay output with poorly defined startup behavior, or it produces any false CLEAR.

## Controller and bench parts

- Primary low-cost controller: [AliExpress ESP32 DevKit V1 30-pin search](https://www.aliexpress.com/w/wholesale-esp32-devkit-v1-30-pin.html). Select the pictured 30-pin ESP-WROOM-32/DOIT-style board; allow a conservative 55 × 30 mm mechanical envelope and verify the received header spacing before ordering the controller PCB.
- Dimensionally controlled alternative: genuine [Espressif ESP32-DevKitC V4 documentation](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32/esp32-devkitc/user_guide.html) and [AliExpress search](https://www.aliexpress.com/w/wholesale-esp32-devkitc-v4.html). This is a 38-pin board and requires its own footprint; it is not a drop-in substitute for the 30-pin DevKit V1.
- A third common option, NodeMCU-32S 38-pin, is listed in `hardware/manufacturing/bom/ESP32_BUYING_OPTIONS.csv`, but is not the default PCB target.
- PC817/LTV-817 optocouplers: [AliExpress search](https://www.aliexpress.com/w/wholesale-ltv--817-optocoupler.html) or [TME LTV-817 search](https://www.tme.eu/es/katalog/?search=LTV-817).
- Certified USB 5 V charger rated at least 2 A, bought from a reputable local retailer or distributor.
- USB-C receptacle GCT USB4105-GF-A plus two 5.1 kΩ CC pull-down resistors.
- Reliable 5-to-12 V boost module: Pololu U3V16F12 or an equivalent regulated module rated for all three sensors.
- Cheap MT3608 boost modules are bench-only; set and verify 12.0 V before connecting sensors.

## Provisional enclosure and fixing hardware

- The enclosure shortlist is in `hardware/manufacturing/bom/ENCLOSURE_BUYING_OPTIONS.csv`.
- If the three sensor axes are really **100 mm apart**, target a controller PCB around 80 x 55 mm and first evaluate an IP65 ABS box around 100 x 80 x 50 mm.
- If the available gap is literally **10 mm**, no ordinary ESP32 DevKit can fit there: the common modules alone are approximately 24-30 mm wide before allowing for a PCB, terminals or enclosure walls.
- Do not order the enclosure or manufacture the PCB until the available width, depth, mounting-hole positions and cable-entry direction have been measured.
- Terminals, 0805 passives, TVS, fuse, indicators and buzzer are enumerated with exact draft part numbers in `hardware/manufacturing/bom/BOM_DRAFT.csv`; sourcing from TME, Mouser, DigiKey, Farnell or RS avoids uncertain marketplace substitutions.

## Laser installation

Use only intact Class 1 or Class 2 products with manufacturer labelling. Mount the beam below or above normal eye height where children cannot stare into the emitter, never aim it through a doorway or window, switch power off during mechanical adjustment when possible, and use a card/camera/alignment indicator rather than looking into the beam. Do not use an unclassified bare laser module in the installed system.

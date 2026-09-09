from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf" / "GarageBeamSafety_Concept_Schematic_D3_Dark.pdf"
W, H = landscape(A4)

BG = colors.HexColor("#090E14")
PANEL = colors.HexColor("#111B25")
HEADER = colors.HexColor("#13283A")
NAVY = colors.HexColor("#D9E7F2")
BLUE = colors.HexColor("#39BFF0")
GREEN = colors.HexColor("#3DDB86")
RED = colors.HexColor("#FF625D")
YELLOW = colors.HexColor("#FFC857")
LIGHT = colors.HexColor("#172431")
MID = colors.HexColor("#91A8B9")
FIELD = colors.HexColor("#2A2118")
LOGIC = colors.HexColor("#102A3A")


def line(c, x1, y1, x2, y2, width=1, color=NAVY, dash=None):
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setDash(dash or [])
    c.line(x1, y1, x2, y2)
    c.setDash([])


def text(c, x, y, value, size=8, color=NAVY, font="Helvetica", anchor="start"):
    c.setFont(font, size)
    c.setFillColor(color)
    if anchor == "middle":
        x -= stringWidth(value, font, size) / 2
    elif anchor == "end":
        x -= stringWidth(value, font, size)
    c.drawString(x, y, value)


def box(c, x, y, w, h, title, subtitle=None, fill=PANEL, stroke=NAVY, radius=5):
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(1.2)
    c.roundRect(x, y, w, h, radius, stroke=1, fill=1)
    text(c, x + w / 2, y + h - 16, title, 10, stroke, "Helvetica-Bold", "middle")
    if subtitle:
        text(c, x + w / 2, y + h - 29, subtitle, 7, MID, "Helvetica", "middle")


def terminal(c, x, y, labels, ref):
    text(c, x, y + 14, ref, 8, NAVY, "Helvetica-Bold")
    for i, label in enumerate(labels):
        yy = y - i * 18
        c.setFillColor(PANEL)
        c.setStrokeColor(NAVY)
        c.rect(x, yy, 30, 14, stroke=1, fill=1)
        text(c, x + 15, yy + 4, label, 6.5, NAVY, "Helvetica-Bold", "middle")
        c.circle(x + 26, yy + 7, 1.8, stroke=1, fill=0)


def resistor(c, x1, y, x2, label, ref, color=NAVY):
    lead = 10
    line(c, x1, y, x1 + lead, y, color=color)
    line(c, x2 - lead, y, x2, y, color=color)
    c.setStrokeColor(color)
    c.setFillColor(BG)
    c.rect(x1 + lead, y - 5, x2 - x1 - 2 * lead, 10, stroke=1, fill=1)
    text(c, (x1 + x2) / 2, y + 9, ref, 6.5, color, "Helvetica-Bold", "middle")
    text(c, (x1 + x2) / 2, y - 15, label, 6.5, color, "Helvetica", "middle")


def vertical_resistor(c, x, y1, y2, label, ref, color=NAVY):
    lead = 7
    line(c, x, y1, x, y1 - lead, color=color)
    line(c, x, y2 + lead, x, y2, color=color)
    c.setStrokeColor(color)
    c.setFillColor(BG)
    c.rect(x - 5, y2 + lead, 10, y1 - y2 - 2 * lead, stroke=1, fill=1)
    text(c, x + 8, (y1 + y2) / 2 + 4, ref, 6.2, color, "Helvetica-Bold")
    text(c, x + 8, (y1 + y2) / 2 - 6, label, 6.2, color)


def capacitor(c, x, y_top, y_bot, label, ref):
    ym = (y_top + y_bot) / 2
    line(c, x, y_top, x, ym + 4)
    line(c, x - 7, ym + 4, x + 7, ym + 4, width=1.3)
    line(c, x - 7, ym - 4, x + 7, ym - 4, width=1.3)
    line(c, x, ym - 4, x, y_bot)
    text(c, x + 10, ym + 6, ref, 6.5, NAVY, "Helvetica-Bold")
    text(c, x + 10, ym - 4, label, 6.5)


def diode(c, x1, y, x2, label, ref):
    mid = (x1 + x2) / 2
    line(c, x1, y, mid - 8, y)
    c.setStrokeColor(NAVY)
    c.setFillColor(BG)
    p = c.beginPath()
    p.moveTo(mid - 8, y - 7)
    p.lineTo(mid - 8, y + 7)
    p.lineTo(mid + 3, y)
    p.close()
    c.drawPath(p, stroke=1, fill=1)
    line(c, mid + 4, y - 7, mid + 4, y + 7, width=1.4)
    line(c, mid + 4, y, x2, y)
    text(c, mid, y + 11, ref, 6.5, NAVY, "Helvetica-Bold", "middle")
    text(c, mid, y - 16, label, 6.5, NAVY, "Helvetica", "middle")


def ground(c, x, y):
    line(c, x, y + 10, x, y)
    line(c, x - 8, y, x + 8, y)
    line(c, x - 5, y - 4, x + 5, y - 4)
    line(c, x - 2, y - 8, x + 2, y - 8)


def net_label(c, x, y, label, color=BLUE):
    c.setFillColor(color)
    c.setStrokeColor(color)
    p = c.beginPath()
    p.moveTo(x, y)
    p.lineTo(x + 7, y + 5)
    p.lineTo(x + 45, y + 5)
    p.lineTo(x + 45, y - 5)
    p.lineTo(x + 7, y - 5)
    p.close()
    c.drawPath(p, stroke=1, fill=0)
    text(c, x + 26, y - 2.5, label, 6.5, color, "Helvetica-Bold", "middle")


def page_frame(c, page, title, sheet):
    c.setFillColor(BG)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    c.setStrokeColor(NAVY)
    c.setLineWidth(1.2)
    c.rect(18, 18, W - 36, H - 36, stroke=1, fill=0)
    c.setFillColor(HEADER)
    c.rect(18, H - 58, W - 36, 40, stroke=0, fill=1)
    text(c, 32, H - 43, "GARAGE BEAM SAFETY", 16, colors.white, "Helvetica-Bold")
    text(c, W - 32, H - 41, f"D3 THREE-BEAM CONCEPT - SHEET {sheet}/7", 9, colors.white, "Helvetica-Bold", "end")
    text(c, 32, H - 72, title, 12, NAVY, "Helvetica-Bold")
    text(c, W - 32, 28, "Advisory detector only - no mains - no automatic door operation", 7, RED, "Helvetica-Bold", "end")
    text(c, 32, 28, f"Concept schematic | 24 Aug 2026 | page {page}", 7, MID)


def arrow(c, x1, y1, x2, y2, color=BLUE, width=2):
    line(c, x1, y1, x2, y2, width=width, color=color)
    import math
    a = math.atan2(y2 - y1, x2 - x1)
    for da in (2.6, -2.6):
        line(c, x2, y2, x2 + 10 * math.cos(a + da), y2 + 10 * math.sin(a + da), width=width, color=color)


def link_button(c, x, y, w, label, url, color=BLUE):
    c.setFillColor(BG)
    c.setStrokeColor(color)
    c.setLineWidth(0.8)
    c.roundRect(x, y, w, 13, 3, stroke=1, fill=1)
    text(c, x + w / 2, y + 3.5, label, 6.2, color, "Helvetica-Bold", "middle")
    c.linkURL(url, (x, y, x + w, y + 13), relative=0, thickness=0)


def sheet_mounting(c):
    page_frame(c, 1, "Mounting overview - fixed hardware, optical plane and driver indication", 1)

    # Macro top view of the garage.
    text(c, 42, 452, "TOP VIEW - NOT TO SCALE", 9, BLUE, "Helvetica-Bold")
    c.setFillColor(LIGHT)
    c.setStrokeColor(NAVY)
    c.setLineWidth(1.2)
    c.rect(42, 240, 755, 195, stroke=1, fill=1)
    line(c, 92, 250, 92, 425, 7, colors.HexColor("#405261"))
    line(c, 747, 250, 747, 425, 7, colors.HexColor("#405261"))
    text(c, 68, 417, "FIXED WALL A", 7, NAVY, "Helvetica-Bold", "middle")
    text(c, 770, 417, "FIXED WALL B", 7, NAVY, "Helvetica-Bold", "middle")

    # Closed door and required separation from moving hardware.
    line(c, 110, 402, 730, 402, 5, colors.HexColor("#8596A3"))
    text(c, 420, 409, "CLOSED METAL GARAGE DOOR - MOVING / REFLECTIVE", 7.5, NAVY, "Helvetica-Bold", "middle")
    line(c, 110, 380, 730, 380, 1, YELLOW, [5, 3])
    text(c, 420, 384, "KEEP-OUT: tracks, seals and door movement", 6.8, YELLOW, "Helvetica-Bold", "middle")

    # Optical line and side-mounted devices.
    box(c, 48, 297, 90, 55, "BOX A", "PCB + sensors", fill=LOGIC, stroke=BLUE)
    box(c, 704, 297, 87, 55, "BOX B", "reflectors only", fill=FIELD, stroke=YELLOW)
    line(c, 138, 325, 704, 325, 3, RED)
    text(c, 420, 332, "OPTICAL STOP PLANE - set from closed-door face after measurement", 7.2, RED, "Helvetica-Bold", "middle")
    arrow(c, 138, 315, 704, 315, BLUE, 1.0)
    arrow(c, 704, 306, 138, 306, colors.HexColor("#5B9BD5"), 1.0)

    # Car silhouette and driver lamp.
    c.setFillColor(colors.HexColor("#273441"))
    c.setStrokeColor(MID)
    c.roundRect(270, 250, 300, 82, 22, stroke=1, fill=1)
    c.setFillColor(BG)
    c.circle(315, 250, 15, stroke=1, fill=1)
    c.circle(525, 250, 15, stroke=1, fill=1)
    text(c, 420, 283, "CAR FRONT APPROACHES THIS LINE", 8, NAVY, "Helvetica-Bold", "middle")
    arrow(c, 420, 275, 420, 305, RED, 1.2)
    box(c, 155, 255, 82, 38, "RGB LAMPS", "visible to driver", fill=PANEL, stroke=GREEN)
    arrow(c, 237, 274, 280, 286, GREEN, 1.0)

    # Side/elevation view with experimental heights.
    text(c, 42, 214, "FRONT ELEVATION - EXPERIMENTAL BEAM HEIGHTS", 9, BLUE, "Helvetica-Bold")
    c.setFillColor(PANEL)
    c.setStrokeColor(NAVY)
    c.rect(42, 73, 475, 130, stroke=1, fill=1)
    line(c, 80, 88, 480, 88, 1.2, MID)
    line(c, 95, 88, 95, 190, 5, colors.HexColor("#405261"))
    line(c, 465, 88, 465, 190, 5, colors.HexColor("#405261"))
    heights = [(112, "datum 0 mm"), (140, "+100 mm"), (168, "+200 mm")]
    for i, (yy, label) in enumerate(heights, 1):
        line(c, 100, yy, 460, yy, 1.3, RED)
        text(c, 280, yy + 3, f"BEAM {i}  {label}", 6.7, RED, "Helvetica-Bold", "middle")
    text(c, 280, 96, "100 mm centres; choose lowest height after the car profile test", 6.8, GREEN, "Helvetica-Bold", "middle")

    box(c, 535, 73, 262, 130, "INSTALLATION RULES", fill=LIGHT)
    rules = [
        "1. Mount only to fixed masonry/reveal - never the door.",
        "2. Keep optics clear of tracks, seals and moving hardware.",
        "3. Use pan/tilt fine adjustment, then lock both axes.",
        "4. Route the 5 V USB cable safely; add strain relief.",
        "5. Use corner-cube reflector, not a plastic plain mirror.",
        "6. Test shiny-door false CLEAR before trusting GREEN.",
        "7. Measure door-to-car geometry before drilling holes.",
    ]
    for i, item in enumerate(rules):
        text(c, 550, 173 - i * 14, item, 7.1, NAVY if i not in (4, 5) else YELLOW, "Helvetica-Bold" if i in (4, 5) else "Helvetica")


def sheet_architecture(c):
    page_frame(c, 2, "System architecture - fixed polarized retroreflective trip lines", 2)
    box(c, 45, 135, 260, 325, "BOX A - CONTROLLER WALL", "All powered electronics and sensor cables", fill=LOGIC)
    box(c, 545, 135, 245, 325, "BOX B / PASSIVE WALL", "Corner-cube reflectors; no electrical wiring", fill=FIELD)

    box(c, 70, 375, 95, 55, "USB CHARGER", "Certified 5 V >=2 A", fill=PANEL)
    box(c, 185, 375, 95, 55, "CONTROLLER", "ESP32 + PCB", fill=PANEL)
    arrow(c, 165, 402, 185, 402)

    ys = [335, 255, 175]
    for i, y in enumerate(ys, 1):
        box(c, 70, y, 100, 38, f"RETRO SENSOR {i}", "polarized / MSR", fill=PANEL)
        box(c, 655, y, 100, 38, f"REFLECTOR {i}", "corner-cube", fill=PANEL)
        arrow(c, 165, y + 24, 665, y + 24, BLUE, 1.5)
        arrow(c, 665, y + 13, 165, y + 13, colors.HexColor("#5B9BD5"), 1.2)
        line(c, 185, 390, 185, y + 19, 0.8, MID)
        line(c, 185, y + 19, 165, y + 19, 0.8, MID)

    text(c, 425, 358, "THREE BEAMS - 100 mm VERTICAL CENTRES", 8, BLUE, "Helvetica-Bold", "middle")
    box(c, 335, 78, 170, 45, "OPTICAL STOP PLANE", "Any crossing -> BLOCKED", fill=colors.HexColor("#2B1719"), stroke=RED)
    line(c, 420, 123, 420, 375, 2, RED, [5, 3])

    text(c, 55, 112, "The beam is the stop line; it does not measure a 10 mm distance.", 8, GREEN, "Helvetica-Bold")
    text(c, 55, 96, "A wider but repeatable beam is acceptable after calibration.", 7.3, NAVY)
    text(c, 55, 84, "Plain mirrors are rejected; shiny-door false-CLEAR testing remains mandatory.", 7.3, NAVY)


def sheet_power(c):
    page_frame(c, 3, "USB-C input, protected 5 V rail and 12 V sensor boost", 3)
    y = 360
    box(c, 45, y - 15, 110, 58, "J1 USB-C", "VBUS + CC1/CC2", fill=FIELD)
    text(c, 55, y - 30, "R1/R2: 5.1k CC pull-downs", 6.8, NAVY)
    arrow(c, 155, y + 14, 185, y + 14)
    box(c, 185, y - 5, 70, 40, "F1", "PTC 1.5 A", fill=FIELD)
    arrow(c, 255, y + 14, 285, y + 14)
    box(c, 285, y - 5, 105, 40, "D1 / Q1", "5 V TVS + FET", fill=FIELD)
    arrow(c, 390, y + 14, 435, y + 14)
    net_label(c, 435, y + 14, "5V_LOGIC")
    capacitor(c, 500, y + 14, 285, "470u / 10V", "C1")
    ground(c, 500, 277)

    box(c, 570, y - 15, 145, 58, "A2 5-to-12 V BOOST", "Pololu U3V16F12", fill=LOGIC)
    line(c, 480, y + 14, 570, y + 14)
    arrow(c, 715, y + 14, 735, y + 14)
    net_label(c, 735, y + 14, "12V_SENSOR")

    box(c, 515, 150, 225, 75, "A1 - ESP32 DEVKIT", "replaceable module on socket headers", fill=LOGIC)
    net_label(c, 550, 242, "5V_LOGIC")
    line(c, 595, 242, 595, 225)
    text(c, 607, 230, "VIN / 5V pin", 7, NAVY)
    net_label(c, 640, 130, "3V3")
    line(c, 665, 150, 665, 130)
    line(c, 565, 150, 565, 115)
    ground(c, 565, 107)

    box(c, 65, 145, 355, 120, "POWER DESIGN NOTES", fill=LIGHT)
    notes = [
        "- External certified USB charger: regulated 5 V, at least 2 A.",
        "- Plain USB-C 5 V sink; USB Power Delivery is not required.",
        "- ESP32 uses protected 5V_LOGIC directly at VIN/5V.",
        "- Boost converter supplies 12 V only to the three sensors.",
        "- Never connect an industrial sensor directly to USB VBUS.",
        "- Test points: VBUS, 5V, 12V, 3V3 and GND.",
    ]
    for i, n in enumerate(notes):
        text(c, 82, 235 - i * 16, n, 7.4)

    box(c, 65, 78, 675, 45, "RAIL SUMMARY", fill=PANEL)
    text(c, 82, 96, "5V_LOGIC: USB/ESP32 rail     12V_SENSOR: boosted field rail     3V3: logic pull-ups     Parts: 0805/SOD-123/SOT-23", 7.8, NAVY)


def input_channel(c, y, number):
    terminal(c, 40, y + 10, ["V+", "0V", "SIG"], f"J{number+1} BEAM{number}")
    # Field terminal power and signal.
    sy = y - 26
    line(c, 70, y + 10, 85, y + 10)
    net_label(c, 85, y + 10, "12V_SENSOR")
    line(c, 70, y - 8, 125, y - 8)
    net_label(c, 125, y - 8, "0V_FIELD", color=RED)

    net_label(c, 150, y + 22, "12V_SENSOR")
    line(c, 195, y + 22, 205, y + 22)
    resistor(c, 205, y + 22, 265, "2.2k 0805", f"R{number}A")

    # Optocoupler spans the isolation boundary: LED on field side, transistor on logic side.
    c.setFillColor(PANEL)
    c.setStrokeColor(NAVY)
    c.setLineWidth(1.1)
    c.roundRect(265, y - 17, 190, 62, 5, stroke=1, fill=1)
    text(c, 360, y + 30, f"U{number+1} LTV-817", 8, NAVY, "Helvetica-Bold", "middle")
    text(c, 315, y + 5, "LED", 7, RED, "Helvetica-Bold", "middle")
    text(c, 410, y + 5, "NPN", 7, BLUE, "Helvetica-Bold", "middle")
    text(c, 315, y - 9, f"D{number} reverse clamp", 5.8, MID, "Helvetica", "middle")
    line(c, 265, y + 22, 295, y + 22)
    diode(c, 295, y + 22, 335, "", "")
    # Light arrows from the optocoupler LED toward the phototransistor.
    arrow(c, 328, y + 14, 347, y + 8, RED, 0.7)
    arrow(c, 328, y + 7, 347, y + 1, RED, 0.7)
    line(c, 335, y + 22, 350, y + 22)
    line(c, 350, y + 22, 350, sy)
    line(c, 70, sy, 350, sy)
    text(c, 170, sy + 5, "SIG sinks when CLEAR", 6.2, RED, "Helvetica-Bold", "middle")

    # Phototransistor collector node and emitter ground.
    line(c, 430, y + 22, 485, y + 22)
    line(c, 430, y - 7, 430, sy - 2)
    ground(c, 430, sy - 10)
    c.circle(485, y + 22, 2.2, stroke=1, fill=1)
    net_label(c, 460, y + 55, "3V3")
    vertical_resistor(c, 485, y + 50, y + 22, "10k", f"R{number}B")
    c.setFillColor(NAVY)
    c.circle(485, y + 22, 2.2, stroke=1, fill=1)
    resistor(c, 485, y + 22, 560, "1k series", f"R{number}C")
    line(c, 560, y + 22, 610, y + 22)
    net_label(c, 610, y + 22, f"GPIO{[32,33,34,35][number-1]}")
    capacitor(c, 585, y + 22, sy - 2, "100n", f"C{number+2}")
    ground(c, 585, sy - 10)
    text(c, 725, y + 17, "LOW = proven CLEAR", 7, GREEN, "Helvetica-Bold", "middle")
    text(c, 725, y + 4, "HIGH = blocked/open/unsafe", 7, RED, "Helvetica-Bold", "middle")


def sheet_inputs(c):
    page_frame(c, 4, "Three isolated fail-safe sensor inputs at 100 mm centres", 4)
    c.setFillColor(FIELD)
    c.rect(30, 65, 345, 405, stroke=0, fill=1)
    c.setFillColor(LOGIC)
    c.rect(375, 65, 430, 405, stroke=0, fill=1)
    text(c, 190, 452, "12 V SENSOR SIGNAL SIDE", 9, RED, "Helvetica-Bold", "middle")
    text(c, 590, 452, "3.3 V ESP32 LOGIC SIDE", 9, BLUE, "Helvetica-Bold", "middle")
    line(c, 375, 65, 375, 470, 2, RED, [5, 3])
    text(c, 375, 78, "OPTOCOUPLER SIGNAL BOUNDARY", 6.5, RED, "Helvetica-Bold", "middle")
    for i, y in enumerate([375, 255, 135], 1):
        input_channel(c, y, i)
    text(c, 43, 48, "D3: all three LOW inputs are required. Blocked/open/dead sensor remains RED / NOT CLEAR.", 7.5, RED, "Helvetica-Bold")


def sheet_control(c):
    page_frame(c, 5, "ESP32 connections, status indication and safety behavior", 5)
    box(c, 295, 165, 245, 260, "U1 - ESP32 DEVKIT", "local safety decision; Wi-Fi optional", fill=LOGIC)
    inputs = [(390, "GPIO32  BEAM1  DATUM 0"), (350, "GPIO33  BEAM2  +100 mm"), (310, "GPIO34  BEAM3  +200 mm")]
    for y, label in inputs:
        arrow(c, 150, y, 295, y, BLUE, 1.2)
        text(c, 165, y + 5, label, 7.5, NAVY, "Helvetica-Bold")
    outputs = [
        (390, "GPIO25", "Q6 -> RGB GREEN channel", GREEN),
        (355, "GPIO26", "Q7 -> RGB RED channel", RED),
        (320, "GPIO27", "Q8 -> RGB BLUE channel", BLUE),
        (285, "GPIO14", "Q9 -> BUZZER, 150 ms", NAVY),
        (250, "GPIO4", "future isolated inhibit", MID),
    ]
    for y, pin, label, color in outputs:
        arrow(c, 540, y, 675, y, color, 1.2)
        text(c, 555, y + 5, pin, 7.5, NAVY, "Helvetica-Bold")
        text(c, 680, y - 2, label, 7.2, color, "Helvetica-Bold")

    box(c, 55, 130, 190, 50, "ALIGN / TEST BUTTON", "GPIO13, active LOW", fill=PANEL)
    arrow(c, 245, 155, 330, 180, MID, 1)
    box(c, 590, 130, 195, 50, "3 x DIFFUSED RGB LAMPS", "common-anode; separate resistors", fill=PANEL)
    arrow(c, 540, 180, 590, 155, MID, 1)

    # State timeline / priority.
    y = 68
    states = [
        (55, 100, "BOOTING", YELLOW),
        (180, 100, "SELF_TEST", YELLOW),
        (305, 100, "CLEAR", GREEN),
        (430, 100, "BLOCKED", RED),
        (555, 100, "FAULT", YELLOW),
    ]
    for x, w, name, color in states:
        c.setFillColor(BG)
        c.setStrokeColor(color)
        c.setLineWidth(1.6)
        c.roundRect(x, y, w, 30, 5, stroke=1, fill=1)
        text(c, x + w / 2, y + 10, name, 8, color, "Helvetica-Bold", "middle")
    arrow(c, 155, y + 15, 180, y + 15, MID, 1)
    arrow(c, 280, y + 15, 305, y + 15, MID, 1)
    arrow(c, 405, y + 15, 430, y + 15, RED, 1)
    arrow(c, 530, y + 15, 555, y + 15, YELLOW, 1)
    text(c, 705, y + 9, "priority: FAULT > BLOCKED > CLEAR", 7.5, NAVY, "Helvetica-Bold", "middle")

    text(c, 65, 52, "GREEN=clear. RED=blocked/no signal/dead sensor. AMBER=boot/unknown (red+green channels). Dark means no power.", 7.5, NAVY)


def sheet_wake(c):
    page_frame(c, 6, "Optional RF, door-motion and manual wake system", 6)

    box(c, 55, 355, 170, 80, "CC1101 RECEIVER MODULE", "receive-only; 433/868 MHz option", fill=LOGIC)
    text(c, 50, 448, "REMOTE RF BURST", 8, BLUE, "Helvetica-Bold")
    # Simple quarter-wave antenna.
    line(c, 75, 438, 75, 462, 1.5, BLUE)
    line(c, 63, 462, 75, 450, 1.2, BLUE)
    line(c, 87, 462, 75, 450, 1.2, BLUE)
    arrow(c, 105, 438, 135, 435, BLUE, 1.2)

    box(c, 55, 245, 170, 65, "DOOR REED / HALL", "GPIO22; active LOW", fill=FIELD)
    box(c, 55, 155, 170, 65, "MANUAL WAKE / TEST", "GPIO13; active LOW", fill=PANEL)

    box(c, 325, 285, 220, 150, "ESP32 WAKE CONTROLLER", "always powered; Wi-Fi optional", fill=LOGIC)
    text(c, 350, 380, "Wake sources are ORed in firmware:", 7.5, NAVY, "Helvetica-Bold")
    text(c, 360, 362, "1. Valid RF activity", 7.2, NAVY)
    text(c, 360, 347, "2. Door movement", 7.2, NAVY)
    text(c, 360, 332, "3. Manual button", 7.2, NAVY)
    text(c, 350, 305, "RF never controls the door or CLEAR state.", 7.2, RED, "Helvetica-Bold")

    arrow(c, 225, 395, 325, 395, BLUE, 1.4)
    arrow(c, 225, 277, 325, 340, YELLOW, 1.2)
    arrow(c, 225, 187, 325, 310, MID, 1.2)

    box(c, 625, 355, 150, 80, "Q_PWR HIGH-SIDE", "switch 12V_SENSOR rail", fill=FIELD)
    arrow(c, 545, 395, 625, 395, GREEN, 1.4)
    box(c, 625, 245, 150, 65, "OPTICAL SENSORS", "startup then signal check", fill=LOGIC)
    arrow(c, 700, 355, 700, 310, GREEN, 1.4)
    box(c, 625, 155, 150, 65, "ACTIVE WINDOW", "5-10 min; extend on activity", fill=PANEL)
    arrow(c, 700, 245, 700, 220, GREEN, 1.4)

    box(c, 280, 165, 275, 85, "CC1101 HEADER - 3.3 V ONLY", fill=PANEL)
    pins = [
        "SCK GPIO18    MISO GPIO19    MOSI GPIO23",
        "CS GPIO21     GDO0 GPIO16    GDO2 GPIO17",
        "Antenna: about 17.3 cm at 433.92 MHz or 8.6 cm at 868 MHz",
    ]
    for i, item in enumerate(pins):
        text(c, 300, 218 - i * 17, item, 7.1, NAVY)

    box(c, 55, 80, 720, 55, "WAKE SEQUENCE", fill=LIGHT)
    text(c, 75, 109, "STANDBY -> wake detected -> AMBER -> sensor power ON -> startup delay -> 500 ms clear proof -> GREEN", 8, NAVY, "Helvetica-Bold")
    text(c, 75, 91, "Any missing optical signal becomes RED. A missed RF burst is covered by the door switch or manual button.", 7.5, RED)


def sheet_bom(c):
    page_frame(c, 7, "D3 purchasing summary - three beams, USB-C and hand-solderable SMD", 7)
    text(c, 42, 452, "Clickable BUY/SEARCH buttons open AliExpress searches. Prices are rough delivered-EU ranges and can change.", 7.5, YELLOW, "Helvetica-Bold")
    text(c, 42, 438, "Critical rule: the cheap optical sensor is a test article. It earns GREEN only after the repeatability and shiny-door tests.", 7.5, RED, "Helvetica-Bold")

    rows = [
        ("3", "Laser retroreflective NPN sensor", "Buy one first; validate before other two", "EUR 45-105", "https://www.aliexpress.com/w/wholesale-laser-retroreflective-photoelectric-sensor-npn.html"),
        ("3", "Corner-cube reflector", "Matched to sensor; 100 mm centres", "EUR 9-30", "https://www.aliexpress.com/w/wholesale-photoelectric-sensor-reflector.html"),
        ("1", "ESP32 DevKit V1", "ESP32-WROOM, 30-pin preferred", "owned / 4-9", "https://www.aliexpress.com/w/wholesale-esp32-devkit-v1-30-pin.html"),
        ("1", "USB-C + protected input", "5.1k CC; PTC; 5V TVS; P-FET", "EUR 3-8", "https://www.aliexpress.com/w/wholesale-usb-c-female-connector-board.html"),
        ("1", "5-to-12 V boost", "Pololu U3V16F12 preferred", "EUR 7-12", "https://www.pololu.com/product/4945"),
        ("3", "LTV-817S optocoupler", "SMD-4; three channels", "EUR 1-3", "https://www.aliexpress.com/w/wholesale-ltv-817-optocoupler.html"),
        ("1", "0805 resistor assortment", "2.2k, 10k, 5.1k, 1k, 330R", "EUR 3-8", "https://www.aliexpress.com/w/wholesale-0805-resistor-kit.html"),
        ("1", "SOD-123 diode assortment", "1N4148W plus protection spares", "EUR 1-4", "https://www.aliexpress.com/w/wholesale-1n4148w-sod-123.html"),
        ("1", "0805 capacitor assortment", "100 nF and 10 uF plus bulk caps", "EUR 4-10", "https://www.aliexpress.com/w/wholesale-0805-capacitor-kit.html"),
        ("1", "Screw terminal kit", "5.08 mm, 2-way and 3-way", "EUR 4-10", "https://www.aliexpress.com/w/wholesale-5.08mm-screw-terminal-block-kit.html"),
        ("3", "Diffused common-anode RGB LED", "5 mm plus 3 NPN driver transistors", "EUR 2-6", "https://www.aliexpress.com/w/wholesale-5mm-diffused-common-anode-rgb-led.html"),
        ("1", "Active buzzer + push button", "3-5 V buzzer; momentary test switch", "EUR 2-5", "https://www.aliexpress.com/w/wholesale-active-buzzer-push-button-kit.html"),
        ("1", "CC1101 receiver (optional)", "Match remote: 433.92 or 868 MHz", "EUR 3-9", "https://www.aliexpress.com/w/wholesale-cc1101-433mhz-antenna.html"),
        ("1", "Door reed switch (recommended)", "Normally closed, wired backup wake", "EUR 2-6", "https://www.aliexpress.com/w/wholesale-wired-door-reed-switch-nc.html"),
        ("1", "Sensor/controller carrier", "PCB 50 x 240 mm; three datums", "TBD", "https://www.aliexpress.com/w/wholesale-custom-pcb-prototype.html"),
        ("1", "Passive reflector carrier", "PCB 30 x 240 mm; no copper", "TBD", "https://www.aliexpress.com/w/wholesale-custom-pcb-prototype.html"),
        ("1", "Cable glands + low-voltage cable", "M12/M16 glands; 3-core sensor cable", "EUR 8-20", "https://www.aliexpress.com/w/wholesale-m12-m16-cable-gland-kit.html"),
        ("2", "Adjustable camera-style brackets", "Metal mini pan/tilt, lockable", "EUR 6-18", "https://www.aliexpress.com/w/wholesale-mini-camera-mount-pan-tilt-bracket.html"),
    ]

    def draw_column(x, start, subset):
        widths = (20, 142, 125, 55, 48)
        y = start
        headings = ("QTY", "ITEM", "MINIMUM DESCRIPTION", "BUDGET", "LINK")
        c.setFillColor(HEADER)
        c.rect(x, y, sum(widths), 20, stroke=0, fill=1)
        xx = x
        for heading, width in zip(headings, widths):
            text(c, xx + 3, y + 6, heading, 6.3, colors.white, "Helvetica-Bold")
            xx += width
        y -= 24
        for index, (qty, item, spec, price, url) in enumerate(subset):
            if index % 2 == 0:
                c.setFillColor(colors.HexColor("#0E1720"))
                c.rect(x, y - 3, sum(widths), 33, stroke=0, fill=1)
            text(c, x + 6, y + 13, qty, 7, NAVY, "Helvetica-Bold", "middle")
            text(c, x + widths[0] + 3, y + 17, item, 6.7, NAVY, "Helvetica-Bold")
            text(c, x + widths[0] + 3, y + 6, spec, 5.8, MID)
            text(c, x + widths[0] + widths[1] + widths[2] + 3, y + 12, price, 6.1, GREEN, "Helvetica-Bold")
            bx = x + sum(widths[:-1]) + 2
            link_button(c, bx, y + 6, widths[-1] - 5, "ALIEXPRESS", url)
            line(c, x, y - 3, x + sum(widths), y - 3, 0.35, colors.HexColor("#304150"))
            y -= 35

    draw_column(32, 408, rows[:9])
    draw_column(432, 408, rows[9:])

    # Certified USB charger is intentionally not sourced from an unknown marketplace listing.
    c.setFillColor(colors.HexColor("#2B1719"))
    c.setStrokeColor(RED)
    c.roundRect(32, 55, 768, 44, 5, stroke=1, fill=1)
    text(c, 46, 82, "BUY LOCALLY: certified regulated USB 5 V charger rated at least 2 A. No mains voltage enters the PCB.", 7.2, RED, "Helvetica-Bold")
    text(c, 46, 66, "Use 0805, not 0402. Buy only ONE sensor/reflector pair until the optical boundary and shiny-surface tests pass.", 7.1, NAVY, "Helvetica-Bold")


def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUT), pagesize=(W, H), pageCompression=1)
    c.setTitle("Garage Beam Safety Concept Schematic D3 Dark")
    c.setAuthor("Garage Beam Safety project")
    for draw in (sheet_mounting, sheet_architecture, sheet_power, sheet_inputs, sheet_control, sheet_wake, sheet_bom):
        draw(c)
        c.showPage()
    c.save()
    print(OUT)


if __name__ == "__main__":
    build()

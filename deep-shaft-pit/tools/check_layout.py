#!/usr/bin/env python3
"""Check Deep Shaft Pit's geometry against a round display.

Every screen derives its coordinates from the display size, so one layout serves
the 416x416 Venu 2 / Venu 2 Plus and the 360x360 Venu 2S. On a round screen the
corners do not exist, so this reproduces that arithmetic and asserts that each
button, panel and text row stays inside the circle.

Text rows are checked against the *chord* width of the display at their own
height, which is the same test `Theme.chordHalfWidth` performs at runtime: a row
near the top or bottom of a round screen has far less usable width than one
across the middle.

    python3 tools/check_layout.py
"""
import math
import sys


def mine_layout(size):
    """Mirror of MineView.onLayout, using the same integer arithmetic."""
    w = h = size
    lay = {"w": w, "h": h}
    lay["groundY"] = (h * 52) // 100
    lay["shaftW"] = (w * 32) // 100
    lay["shaftX"] = (w - lay["shaftW"]) // 2
    lay["diggerY"] = lay["groundY"] + (h - lay["groundY"]) * 40 // 100
    lay["crewButtonH"] = (h * 12) // 100
    lay["crewButtonW"] = (w * 38) // 100
    lay["crewButtonY"] = h - lay["crewButtonH"] - (h * 6) // 100
    lay["ringRadius"] = w // 2 - 6
    lay["ringWidth"] = 8
    return lay


def welcome_layout(size):
    """Mirror of WelcomeView.onLayout."""
    w = h = size
    return {
        "w": w,
        "h": h,
        "buttonH": (h * 14) // 100,
        "buttonW": (w * 50) // 100,
        "buttonY": (h * 70) // 100,
        "panelY": (h * 22) // 100,
        "panelH": (h * 32) // 100,
    }


def chord_half_width(radius, dy):
    """Mirror of Theme.chordHalfWidth."""
    d = abs(dy)
    if d >= radius:
        return 0
    return int(math.sqrt(float(radius * radius - d * d)))


def inside(lay, x, y, margin=0):
    radius = lay["w"] / 2.0 - margin
    return math.hypot(x - lay["w"] / 2.0, y - lay["h"] / 2.0) <= radius


def check_rect(lay, name, x, y, rw, rh, problems, margin=2):
    for cx, cy in ((x, y), (x + rw, y), (x, y + rh), (x + rw, y + rh)):
        if not inside(lay, cx, cy, margin):
            over = math.hypot(cx - lay["w"] / 2.0, cy - lay["h"] / 2.0) - (
                lay["w"] / 2.0 - margin)
            problems.append("%s corner (%d,%d) is %.1fpx outside the display"
                            % (name, cx, cy, over))


def check_text_row(lay, name, y_percent, needed, problems):
    """A centred text row must fit within the chord at its own height."""
    h = lay["h"]
    y = (h * y_percent) // 100
    half = chord_half_width(lay["w"] // 2 - 2, y - h // 2)
    if half * 2 < needed:
        problems.append("%s at %d%% has %dpx of width, needs %d"
                        % (name, y_percent, half * 2, needed))


def check_mine(size, problems):
    lay = mine_layout(size)

    # The crew button is the one tap target on this screen; it sits low, where
    # the round display is narrowing fast.
    check_rect(lay, "crew button",
               (lay["w"] - lay["crewButtonW"]) // 2, lay["crewButtonY"],
               lay["crewButtonW"], lay["crewButtonH"], problems)

    # The progress ring is drawn with a pen, so half its width sits outside the
    # nominal radius.
    if lay["ringRadius"] + lay["ringWidth"] / 2.0 > lay["w"] / 2.0:
        problems.append("depth ring (r=%d, pen %d) is clipped by the bezel"
                        % (lay["ringRadius"], lay["ringWidth"]))

    # The digger must stand on screen, between the ground line and the button.
    if lay["diggerY"] >= lay["crewButtonY"]:
        problems.append("the digger (y=%d) is drawn under the crew button (y=%d)"
                        % (lay["diggerY"], lay["crewButtonY"]))
    if lay["groundY"] >= lay["diggerY"]:
        problems.append("the digger is above the ground line")

    # HUD rows, with the widest string each realistically has to hold.
    check_text_row(lay, "layer + depth line", 11, 150, problems)
    check_text_row(lay, "gold readout", 19, 170, problems)
    check_text_row(lay, "rate line", 36, 140, problems)
    check_text_row(lay, "gem / hint line", 44, 150, problems)
    return lay


def check_welcome(size, problems):
    lay = welcome_layout(size)
    check_rect(lay, "collect button",
               (lay["w"] - lay["buttonW"]) // 2, lay["buttonY"],
               lay["buttonW"], lay["buttonH"], problems)
    if lay["panelY"] + lay["panelH"] > lay["buttonY"]:
        problems.append("welcome panel overlaps the collect button")
    return lay


def check_stats(size, problems):
    """StatsView rows start at 17% and step 12%, inset by the chord width."""
    w = h = size
    lay = {"w": w, "h": h}
    y = (h * 17) // 100
    for i in range(6):
        half = chord_half_width(w // 2 - 10, y + 12 - h // 2)
        if half < 40:
            problems.append("stats row %d (y=%d) has only %dpx of half-width"
                            % (i, y, half))
        y += (h * 12) // 100
    if y > h:
        problems.append("stats rows run off the bottom of the screen (y=%d)" % y)
    return lay


def main():
    failed = False
    for size, name in ((416, "Venu 2 / Venu 2 Plus"), (360, "Venu 2S")):
        problems = []
        mine = check_mine(size, problems)
        check_welcome(size, problems)
        check_stats(size, problems)

        print("%s (%dx%d)" % (name, size, size))
        print("   ground at %d, digger at %d, crew button at %d (%dx%d)"
              % (mine["groundY"], mine["diggerY"], mine["crewButtonY"],
                 mine["crewButtonW"], mine["crewButtonH"]))
        if problems:
            failed = True
            for problem in problems:
                print("   FAIL %s" % problem)
        else:
            print("   OK   every element fits inside the round display")
        print()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

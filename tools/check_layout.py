#!/usr/bin/env python3
"""Check the mine screen's geometry against a round display.

`MineView.onLayout` derives every coordinate from the display size so one layout
serves the 416x416 Venu 2 and the 360x360 Venu 2S. On a round screen the corners
do not exist, so this reproduces that arithmetic and asserts that each panel,
button and badge stays inside the circle and that nothing overlaps.

    python3 tools/check_layout.py
"""
import math
import sys

VISIBLE = 3


def layout(size):
    """Mirror of MineView.onLayout, using the same integer arithmetic."""
    w = h = size
    lay = {"w": w, "h": h, "cx": w // 2, "cy": h // 2}
    lay["rowX"] = w * 85 // 1000
    lay["rowW"] = w - 2 * lay["rowX"]
    lay["rowTop"] = h * 255 // 1000
    lay["rowH"] = h * 154 // 1000
    lay["rowGap"] = h * 15 // 1000
    lay["badgeR"] = lay["rowH"] * 38 // 100
    lay["btnW"] = lay["rowW"] * 24 // 100
    lay["barH"] = h * 100 // 1000
    lay["barY"] = h * 780 // 1000
    lay["actW"] = w * 180 // 1000
    lay["actGap"] = w * 22 // 1000
    lay["actX"] = lay["cx"] - (3 * lay["actW"] + 2 * lay["actGap"]) // 2
    return lay


def inside(lay, x, y, margin=0):
    """Is a point within the visible disc, keeping `margin` px of clearance?"""
    radius = lay["w"] / 2.0 - margin
    return math.hypot(x - lay["cx"], y - lay["cy"]) <= radius


def check_rect(lay, name, x, y, rw, rh, problems, margin=2):
    for cx, cy in ((x, y), (x + rw, y), (x, y + rh), (x + rw, y + rh)):
        if not inside(lay, cx, cy, margin):
            over = math.hypot(cx - lay["cx"], cy - lay["cy"]) - (lay["w"] / 2.0 - margin)
            problems.append("%s corner (%d,%d) is %.1fpx outside the display"
                            % (name, cx, cy, over))


def check(size):
    lay = layout(size)
    problems = []

    rows = []
    for slot in range(VISIBLE):
        y = lay["rowTop"] + slot * (lay["rowH"] + lay["rowGap"])
        rows.append(y)
        check_rect(lay, "shaft row %d" % slot, lay["rowX"], y, lay["rowW"], lay["rowH"],
                   problems)

        # Badge circle, drawn at the left of the row.
        bx = lay["rowX"] + lay["badgeR"] + 6
        by = y + lay["rowH"] // 2
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            if not inside(lay, bx + dx * lay["badgeR"], by + dy * lay["badgeR"], 2):
                problems.append("badge on row %d escapes the display" % slot)

        # Buy button, drawn at the right of the row.
        btn_x = lay["rowX"] + lay["rowW"] - lay["btnW"] - 6
        check_rect(lay, "buy button %d" % slot, btn_x, y + 8, lay["btnW"],
                   lay["rowH"] - 16, problems)
        if btn_x <= lay["rowX"] + 2 * lay["badgeR"] + 16:
            problems.append("row %d: buy button overlaps the text column" % slot)

        text_x = lay["rowX"] + 2 * lay["badgeR"] + 16
        text_w = lay["rowW"] - (text_x - lay["rowX"]) - lay["btnW"] - 10
        if text_w < 60:
            problems.append("row %d: only %dpx of text column left" % (slot, text_w))

    # Rows must not collide with each other or with the action bar.
    for i in range(len(rows) - 1):
        if rows[i] + lay["rowH"] > rows[i + 1]:
            problems.append("shaft rows %d and %d overlap" % (i, i + 1))
    last_bottom = rows[-1] + lay["rowH"]
    if last_bottom > lay["barY"]:
        problems.append("last shaft row (ends %d) overlaps the action bar (starts %d)"
                        % (last_bottom, lay["barY"]))

    for slot in range(3):
        x = lay["actX"] + slot * (lay["actW"] + lay["actGap"])
        check_rect(lay, "action button %d" % slot, x, lay["barY"], lay["actW"],
                   lay["barH"], problems)

    # Header: the cash line and the income line below it.
    if lay["h"] * 60 // 1000 + 44 > lay["rowTop"]:
        problems.append("header text runs into the first shaft row")

    # The scroll indicator hugs the bezel.
    if lay["cx"] - 4 + 2 > lay["w"] / 2.0:
        problems.append("scroll indicator is drawn off the edge")

    return lay, problems


def main():
    failed = False
    for size, name in ((416, "Venu 2 / Venu 2 Plus"), (360, "Venu 2S")):
        lay, problems = check(size)
        print("%s (%dx%d)" % (name, size, size))
        print("   rows at %s, height %d, action bar at %d"
              % ([lay["rowTop"] + i * (lay["rowH"] + lay["rowGap"]) for i in range(VISIBLE)],
                 lay["rowH"], lay["barY"]))
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

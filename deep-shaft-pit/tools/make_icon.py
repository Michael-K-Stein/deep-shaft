#!/usr/bin/env python3
"""Draw the Deep Shaft (pit) launcher icon - a crossed pick over a gem - at any size.

Deep Shaft Tycoon next door uses an ore cart; this one uses a pick, so the two
games are told apart at a glance in the watch's app list.

The Venu 2 family wants two sizes (70px for the 416x416 watches, 61px for the
360x360 Venu 2S), so the artwork is described once in a 60x60 design space and
rasterised with 4x supersampling at whatever size is asked for. Pure stdlib, so
it runs anywhere the build runs.

    python3 tools/make_icon.py resources-round-416x416/drawables/launcher_icon.png 70
"""
import math
import struct
import sys
import zlib

DESIGN = 60.0   # the coordinate space the shapes below are drawn in
SS = 4          # supersampling factor

BG = (0x0C, 0x0C, 0x12, 255)
GOLD = (0xFF, 0xC6, 0x1E, 255)
HANDLE = (0x8C, 0x5A, 0x3C, 255)
STEEL = (0xC8, 0xD0, 0xD8, 255)
GEM = (0x4F, 0xC3, 0xE8, 255)
CLEAR = (0, 0, 0, 0)


def in_disc(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def in_ring(px, py, cx, cy, r0, r1):
    d2 = (px - cx) ** 2 + (py - cy) ** 2
    return r0 * r0 <= d2 <= r1 * r1


def in_bar(px, py, x0, y0, x1, y1, half):
    """Distance from the segment (x0,y0)-(x1,y1) is within `half`."""
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy
    if length2 == 0.0:
        return in_disc(px, py, x0, y0, half)
    t = ((px - x0) * dx + (py - y0) * dy) / length2
    t = max(0.0, min(1.0, t))
    return (px - (x0 + t * dx)) ** 2 + (py - (y0 + t * dy)) ** 2 <= half * half


def in_pick_head(px, py, cx, cy, r, thick):
    """The blade of a pick: the lower half of a ring, so the ends dip down."""
    if not in_ring(px, py, cx, cy, r - thick, r + thick):
        return False
    return py >= cy


def in_diamond(px, py, cx, cy, rx, ry):
    if ry == 0.0 or rx == 0.0:
        return False
    return abs(px - cx) / rx + abs(py - cy) / ry <= 1.0


def sample(px, py):
    """Colour of the icon at a point in the 60x60 design space, painter's order."""
    colour = CLEAR
    if in_disc(px, py, 30, 30, 29.0):
        colour = BG
    if in_ring(px, py, 30, 30, 26.5, 29.0):
        colour = GOLD

    # The gem sits in the rock, behind the pick.
    if in_diamond(px, py, 41.0, 42.0, 7.0, 8.0):
        colour = GEM
    if in_diamond(px, py, 39.0, 40.0, 2.6, 3.2):
        colour = (0xA8, 0xE6, 0xF6, 255)

    # Handle, running from the blade down to the lower left.
    if in_bar(px, py, 31.0, 22.0, 20.0, 48.0, 2.6):
        colour = HANDLE

    # Steel blade arcing across the top, ends dipping like a real pick head.
    if in_pick_head(px, py, 31.0, 10.0, 15.0, 2.6):
        colour = STEEL

    return colour


def render(size):
    scale = DESIGN / size
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    px = (x + (sx + 0.5) / SS) * scale
                    py = (y + (sy + 0.5) / SS) * scale
                    sr, sg, sb, sa = sample(px, py)
                    weight = sa / 255.0
                    r += sr * weight
                    g += sg * weight
                    b += sb * weight
                    a += weight
            n = float(SS * SS)
            alpha = a / n
            if alpha > 0.0001:
                row += bytes((
                    min(255, int(round(r / n / alpha))),
                    min(255, int(round(g / n / alpha))),
                    min(255, int(round(b / n / alpha))),
                    int(round(alpha * 255)),
                ))
            else:
                row += bytes((0, 0, 0, 0))
        rows.append(bytes(row))
    return rows


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: make_icon.py <output.png> <size>")
    path = sys.argv[1]
    size = int(sys.argv[2])
    write_png(path, render(size), size)
    print("wrote %s (%dx%d)" % (path, size, size))


if __name__ == "__main__":
    main()

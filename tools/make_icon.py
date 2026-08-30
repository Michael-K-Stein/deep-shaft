#!/usr/bin/env python3
"""Draw the Deep Shaft launcher icon - an ore cart - at any size.

The Venu 2 family wants two sizes (70px for the 416x416 watches, 61px for the
360x360 Venu 2S), so the artwork is described once in a 60x60 design space and
rasterised with 4x supersampling at whatever size is asked for. Pure stdlib, so
it runs anywhere the build runs.

    python3 tools/make_icon.py resources-round-416x416/drawables/launcher_icon.png 70
"""
import struct
import sys
import zlib

DESIGN = 60.0   # the coordinate space the shapes below are drawn in
SS = 4          # supersampling factor

BG = (0x14, 0x16, 0x1F, 255)
GOLD = (0xFF, 0xB0, 0x20, 255)
GOLD_DARK = (0xC8, 0x84, 0x10, 255)
STEEL = (0x8A, 0x92, 0xA6, 255)
ORE = (0x4A, 0xDE, 0x80, 255)
CLEAR = (0, 0, 0, 0)


def in_disc(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def in_ring(px, py, cx, cy, r0, r1):
    d2 = (px - cx) ** 2 + (py - cy) ** 2
    return r0 * r0 <= d2 <= r1 * r1


def in_rect(px, py, x0, y0, x1, y1):
    return x0 <= px <= x1 and y0 <= py <= y1


def in_trapezoid(px, py, ytop, ybot, xtl, xtr, xbl, xbr):
    if not (ytop <= py <= ybot):
        return False
    t = (py - ytop) / (ybot - ytop)
    return (xtl + (xbl - xtl) * t) <= px <= (xtr + (xbr - xtr) * t)


def sample(px, py):
    """Colour of the icon at a point in the 60x60 design space, painter's order."""
    colour = CLEAR
    if in_disc(px, py, 30, 30, 29.0):
        colour = BG
    if in_ring(px, py, 30, 30, 26.5, 29.0):
        colour = GOLD
    if in_rect(px, py, 11, 45.5, 49, 47.5):          # rail
        colour = STEEL
    for wheel_x in (21.0, 39.0):
        if in_disc(px, py, wheel_x, 43.0, 4.6):
            colour = STEEL
        if in_disc(px, py, wheel_x, 43.0, 1.8):
            colour = BG
    for ox, oy, orr in ((22.0, 23.0, 4.2), (30.0, 19.5, 5.0), (38.0, 23.0, 4.2)):
        if in_disc(px, py, ox, oy, orr):             # ore heaped above the cart
            colour = ORE
    if in_trapezoid(px, py, 25.5, 40.5, 12.5, 47.5, 17.5, 42.5):
        colour = GOLD if py < 33 else GOLD_DARK
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

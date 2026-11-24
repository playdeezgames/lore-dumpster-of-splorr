#!/usr/bin/env python3
"""Draw every sprite in the exported Anvil world on the floor tile, as a PNG contact sheet.

Usage: python3 -I tools/preview_sheet.py art/lore-dumpster.json out.png [zoom]
Stdlib only. Palette index 0 is transparent (the floor shows through).
"""
import json, struct, sys, zlib


def pixels(img, w, h):
    rb = (w + 1) // 2
    b = img["bytes"]
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            v = b[y * rb + x // 2]
            row.append(v >> 4 if x % 2 == 0 else v & 15)
        out.append(row)
    return out


def write_png(path, w, h, rgb_rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rgb_rows)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    world = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    zoom = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    tw, th = world["tile_width"], world["tile_height"]
    pal = [(c["r"], c["g"], c["b"]) for c in world["palette"]]
    images = {}
    for ts in world["tilesets"]:
        for im in ts["tileset"]["images"]:
            images[(ts["name"], im["name"])] = pixels(im, tw, th)
    floor = images[("terrain", "floor")]
    sprites = [s for ss in world["sprite_sets"] for s in ss["sprites"]] if world["sprite_sets"] and "sprites" in world["sprite_sets"][0] else []
    if not sprites:
        for ss in world["sprite_sets"]:
            sprites += ss.get("sprite_set", {}).get("sprites", [])
    cols = 8
    rows = (len(sprites) + cols - 1) // cols
    W, H = cols * (tw + 1) + 1, rows * (th + 1) + 1
    canvas = [[pal[3]] * W for _ in range(H)]
    for i, s in enumerate(sprites):
        px = images[(s["tileset"], s["image"])]
        ox, oy = 1 + (i % cols) * (tw + 1), 1 + (i // cols) * (th + 1)
        for y in range(th):
            for x in range(tw):
                v = px[y][x]
                canvas[oy + y][ox + x] = pal[floor[y][x]] if v == s.get("transparent", 0) else pal[v]
    rgb = []
    for row in canvas:
        line = []
        for c in row:
            line += list(c) * zoom
        for _ in range(zoom):
            rgb.append(line)
    write_png(out, W * zoom, H * zoom, rgb)
    print(out, len(sprites), "sprites")


if __name__ == "__main__":
    main()

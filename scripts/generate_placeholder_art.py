#!/usr/bin/env python3
"""Generate the app's own placeholder pixel art (no third-party artwork).

Writes:
  Sources/BookAssets/Assets/textures/chest.png   16x16 chest sprite
  Packaging/AppIcon.iconset/*.png                app icon at every iconset size

Pure standard library: PNGs are encoded by hand with zlib, and every size is a
nearest-neighbour upscale of the same 16x16 grid so the pixels stay crisp.
Usage: python3 scripts/generate_placeholder_art.py <repo root>
"""
import struct
import sys
import zlib
from pathlib import Path

PALETTE = {
    ".": (0, 0, 0, 0),
    "K": (38, 24, 12, 255),     # outline
    "D": (94, 58, 26, 255),     # dark wood
    "W": (138, 90, 44, 255),    # wood
    "L": (171, 118, 62, 255),   # light wood
    "B": (64, 64, 72, 255),     # iron band
    "G": (222, 196, 92, 255),   # latch
    "H": (250, 234, 150, 255),  # latch highlight
}

CHEST = [
    "................",
    ".KKKKKKKKKKKKKK.",
    ".KLLLLLLLLLLLLK.",
    ".KLWWWWWWWWWWDK.",
    ".KLWWWWWWWWWWDK.",
    ".KLWWWWWWWWWWDK.",
    ".KBBBBBGGBBBBBK.",
    ".KKKKKKGHKKKKKK.",
    ".KLLLLLGGLLLLLK.",
    ".KLWWWWWWWWWWDK.",
    ".KLWWWWWWWWWWDK.",
    ".KLWWWWWWWWWWDK.",
    ".KLWWWWWWWWWWDK.",
    ".KDDDDDDDDDDDDK.",
    ".KKKKKKKKKKKKKK.",
    "................",
]

ICON_BACKGROUND = (52, 33, 20, 255)


def png_bytes(pixels, width, height):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def grid_pixels(grid, background=None):
    pixels = []
    for row in grid:
        for symbol in row:
            colour = PALETTE[symbol]
            if colour[3] == 0 and background is not None:
                colour = background
            pixels.append(colour)
    return pixels


def upscale(pixels, size, factor):
    out = []
    for y in range(size * factor):
        for x in range(size * factor):
            out.append(pixels[(y // factor) * size + (x // factor)])
    return out


def main(root):
    textures = root / "Sources/BookAssets/Assets/textures"
    (textures / "chest.png").write_bytes(png_bytes(grid_pixels(CHEST), 16, 16))

    iconset = root / "Packaging/AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    icon = grid_pixels(CHEST, background=ICON_BACKGROUND)
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels_per_side = points * scale
            factor = pixels_per_side // 16
            name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            image = upscale(icon, 16, factor)
            (iconset / name).write_bytes(png_bytes(image, pixels_per_side, pixels_per_side))


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())

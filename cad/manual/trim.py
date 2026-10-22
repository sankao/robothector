#!/usr/bin/env python3
"""trim.py <png> ...: crop renders to the model (anything that differs from the corner
background colour) plus a margin, in place. Used by render.sh."""
import sys
from PIL import Image, ImageChops

PAD = 48
for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    bg = Image.new("RGB", im.size, im.getpixel((0, 0)))
    box = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 6 else 0).getbbox()
    if not box:
        continue
    x0, y0, x1, y1 = box
    im.crop((max(0, x0 - PAD), max(0, y0 - PAD), min(im.width, x1 + PAD), min(im.height, y1 + PAD))).save(path, optimize=True)
    print(f"trimmed {path}: {x1 - x0 + 2 * PAD} x {y1 - y0 + 2 * PAD}")

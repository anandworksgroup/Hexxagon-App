"""Trim captured screenshots to Play Store proportions.

Google caps phone screenshots at a 2:1 aspect ratio, and this phone is
20:9, so the shots come back at 2.22:1. This removes the black band the
capture leaves where the navigation bar sits, then trims evenly from top
and bottom until the image is exactly 2:1, and finally upscales to 1080
wide so the listing images are not the phone's bare 720px.

    python tool/crop_screenshots.py [dir]
"""

import glob
import os
import sys

from PIL import Image

TARGET_RATIO = 2.0
OUT_WIDTH = 1080


def black_band(img, from_bottom=True):
    """Height of the solid-black band at the bottom (or top) of the image."""
    w, h = img.size
    px = img.convert("RGB").load()
    rows = range(h - 1, -1, -1) if from_bottom else range(h)
    count = 0
    for y in rows:
        if any(sum(px[x, y]) > 24 for x in range(0, w, 8)):
            break
        count += 1
    return count


def process(path):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    top = black_band(img, from_bottom=False)
    bottom = black_band(img, from_bottom=True)
    img = img.crop((0, top, w, h - bottom))
    w, h = img.size

    # Trim evenly top and bottom down to 2:1.
    max_h = int(w * TARGET_RATIO)
    if h > max_h:
        extra = h - max_h
        img = img.crop((0, extra // 2, w, h - (extra - extra // 2)))
        w, h = img.size

    scale = OUT_WIDTH / w
    img = img.resize((OUT_WIDTH, round(h * scale)), Image.LANCZOS)
    img.save(path)
    return img.size


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "store/screenshots"
    files = sorted(glob.glob(os.path.join(folder, "*.png")))
    if not files:
        raise SystemExit(f"no screenshots in {folder}")
    for f in files:
        size = process(f)
        print(f"{os.path.basename(f)}: {size[0]}x{size[1]} ({size[1] / size[0]:.2f}:1)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
export_variants.py — Turn one master product image (packshot or transparent
cutout) into marketplace-ready variants: correct background, aspect ratio,
product fill ratio, and minimum resolution for Amazon, Shopify, and Etsy.

Usage:
  python3 export_variants.py --input packshot.jpg --output ./out --channels amazon,shopify,etsy
  python3 export_variants.py --input cutout.png  --output ./out --channels shopify --bg transparent

Dependencies: Pillow  (pip install Pillow)
"""
import argparse
import os
from PIL import Image

# channel -> (aspect_w, aspect_h, product_fill, min_shortest_side_px)
PRESETS = {
    "amazon":  (1, 1, 0.85, 2000),   # main image: pure white, product ~85% of frame, >=1600 (2000 safe)
    "shopify": (1, 1, 0.90, 2048),   # square, consistent padding
    "etsy":    (5, 4, 0.85, 2000),   # 5:4 landscape thumbnails
}
WHITE = (255, 255, 255, 255)


def load_rgba(path):
    return Image.open(path).convert("RGBA")


def product_bbox(im, white_thresh=244):
    """Bounding box of the product. Uses alpha if present, else near-white background detection."""
    alpha = im.getchannel("A")
    if alpha.getextrema()[0] < 255:  # real transparency exists
        box = alpha.getbbox()
        if box:
            return box
    # Flatten on white, find pixels that differ from white
    rgb = Image.new("RGB", im.size, (255, 255, 255))
    rgb.paste(im, mask=im.getchannel("A"))
    gray = rgb.convert("L")
    mask = gray.point(lambda p: 255 if p < white_thresh else 0)
    box = mask.getbbox()
    return box or (0, 0, im.width, im.height)


def target_size(aw, ah, min_side):
    """Canvas size with the SHORTEST side == min_side, matching aspect aw:ah."""
    if aw >= ah:  # landscape or square -> height is the short side
        h = min_side
        w = round(min_side * aw / ah)
    else:         # portrait -> width is the short side
        w = min_side
        h = round(min_side * ah / aw)
    return w, h


def make_variant(sprite, canvas_wh, fill, bg):
    cw, ch = canvas_wh
    sw, sh = sprite.size
    # scale so the product spans `fill` of the frame in its dominant dimension
    scale = min(cw * fill / sw, ch * fill / sh)
    nw, nh = max(1, round(sw * scale)), max(1, round(sh * scale))
    resized = sprite.resize((nw, nh), Image.LANCZOS)
    if bg == "transparent":
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(resized, ((cw - nw) // 2, (ch - nh) // 2), resized)
        return canvas, "png"
    color = (255, 255, 255, 255) if bg == "white" else _hex(bg)
    canvas = Image.new("RGBA", (cw, ch), color)
    canvas.paste(resized, ((cw - nw) // 2, (ch - nh) // 2), resized)
    return canvas.convert("RGB"), "jpg"


def _hex(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="master image (packshot or transparent cutout)")
    ap.add_argument("--output", required=True, help="output directory")
    ap.add_argument("--channels", default="amazon,shopify,etsy", help="comma list: amazon,shopify,etsy")
    ap.add_argument("--bg", default="white", help="white | transparent | #RRGGBB (default white)")
    ap.add_argument("--fill", type=float, default=None, help="override product fill ratio (0-1)")
    args = ap.parse_args()

    os.makedirs(args.output, exist_ok=True)
    im = load_rgba(args.input)
    sprite = im.crop(product_bbox(im))
    stem = os.path.splitext(os.path.basename(args.input))[0]

    for ch in [c.strip() for c in args.channels.split(",") if c.strip()]:
        if ch not in PRESETS:
            print(f"! unknown channel: {ch} (skipping)")
            continue
        aw, ah, fill, min_side = PRESETS[ch]
        fill = args.fill if args.fill is not None else fill
        canvas_wh = target_size(aw, ah, min_side)
        out, ext = make_variant(sprite, canvas_wh, fill, args.bg)
        dest = os.path.join(args.output, f"{stem}_{ch}.{ext}")
        save_kwargs = {"quality": 92} if ext == "jpg" else {}
        out.save(dest, **save_kwargs)
        print(f"  {ch}: {dest}  ({out.width}x{out.height})")


if __name__ == "__main__":
    main()

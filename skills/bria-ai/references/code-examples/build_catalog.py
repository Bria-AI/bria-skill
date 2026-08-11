#!/usr/bin/env python3
"""
build_catalog.py — Batch: a folder of raw product photos -> a store-ready catalog.

For each image it runs the Bria product pipeline:
  cutout -> packshot (white) + lifestyle scenes (+ dimensions if measurements given)
  -> marketplace-ready variants (via export_variants.py)

Usage:
  python3 build_catalog.py --input ./products --output ./catalog \
      --scenes "marble bathroom shelf, soft light|bright kitchen counter, morning sun" \
      --variants amazon,shopify,etsy --dims ./dims.json

Auth: BRIA_API_KEY from env or ~/.bria/credentials.
Deps: pip install requests Pillow
"""
import argparse, base64, io, json, os, sys, time
import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_variants as ev  # noqa: E402

BASE = os.environ.get("BRIA_API_BASE", "https://engine.prod.bria-api.com")
IMG_EXT = (".jpg", ".jpeg", ".png", ".webp")

# Sensible zero-config defaults so "create a catalog for each product" just works.
DEFAULT_SCENES = ("on a clean minimal surface with soft natural light and a subtle shadow"
                  "|on a warm wooden surface with a small plant nearby, soft daylight")


def api_key():
    k = os.environ.get("BRIA_API_KEY")
    if k:
        return k
    cred = os.path.expanduser("~/.bria/credentials")
    if os.path.exists(cred):
        for line in open(cred):
            if line.startswith("api_token="):
                return line.strip().split("=", 1)[1]
    sys.exit("ERROR: BRIA_API_KEY not set and no ~/.bria/credentials. Authenticate first.")


KEY = None
def H():
    return {"api_token": KEY, "Content-Type": "application/json",
            "User-Agent": "BriaSkills/1.3.5"}


def post(path, payload, tries=3):
    for t in range(tries):
        r = requests.post(f"{BASE}{path}", headers=H(), json=payload, timeout=180)
        if r.status_code in (200, 202):
            return r.json()
        print(f"  ! {path} -> {r.status_code}: {r.text[:180]}")
        time.sleep(4)
    raise RuntimeError(f"failed {path}: {r.status_code}")


def b64_resized(path, maxside=1800):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    s = min(1.0, maxside / max(w, h))
    if s < 1.0:
        im = im.resize((int(w * s), int(h * s)), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, format="JPEG", quality=90)
    return base64.b64encode(buf.getvalue()).decode()


def result_url(j):
    if j.get("result_url"):
        return j["result_url"]
    res = j.get("result")
    if isinstance(res, list) and res:
        first = res[0]
        return first[0] if isinstance(first, list) else first
    if isinstance(res, dict):
        u = res.get("image_url") or res.get("url")
        if u:
            return u
        # Multi-image results (e.g. product_dimensions output_format=dual) use image_urls.
        urls = res.get("image_urls")
        if isinstance(urls, list) and urls:
            return urls[0]
    return None


def poll(status_url, tries=40):
    for _ in range(tries):
        j = requests.get(status_url, headers=H(), timeout=60).json()
        if str(j.get("status", "")).upper() in ("FAILED", "ERROR"):
            raise RuntimeError(f"job failed: {json.dumps(j)[:200]}")
        u = result_url(j)
        if u:
            return u
        time.sleep(3)
    raise RuntimeError("timeout polling")


def download(url, dest):
    r = requests.get(url, timeout=180); r.raise_for_status()
    # Bria's packshot/lifestyle endpoints return PNG bytes. When the caller wants a
    # .jpg, re-encode so the file's content matches its extension (flatten any alpha
    # onto white — packshots are already on a white background). For .png keep the
    # raw bytes so cutout/dimensions transparency is preserved.
    if dest.lower().endswith((".jpg", ".jpeg")):
        im = Image.open(io.BytesIO(r.content))
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            bg = Image.new("RGB", im.size, (255, 255, 255))
            bg.paste(im, mask=im.split()[-1])
            im = bg
        else:
            im = im.convert("RGB")
        im.save(dest, format="JPEG", quality=92)
    else:
        with open(dest, "wb") as f:
            f.write(r.content)
    print(f"    saved {os.path.relpath(dest)}")


def load_dims(path):
    """Load measurements from .json ({filename: {...}}) or .csv (header row with
    filename,title,height_cm,width_cm,weight_g,capacity_ml)."""
    if path.lower().endswith(".csv"):
        import csv
        out = {}
        with open(path, newline="") as f:
            for row in csv.DictReader(f):
                key = (row.get("filename") or row.get("file") or "").strip()
                if not key:
                    continue
                entry = {}
                if row.get("title"):
                    entry["title"] = row["title"].strip()
                for k in ("height_cm", "width_cm", "weight_g", "capacity_ml"):
                    v = (row.get(k) or "").strip()
                    if v:
                        entry[k] = float(v)
                out[key] = entry
        return out
    return json.load(open(path))


def dims_payload(entry):
    # Dual-unit callouts: each linear dimension is emitted twice (cm + in) with the
    # same name+position so Bria merges them into one "19 cm / 7.5 in" label.
    dims = []

    def add(name, cm, position):
        inches = round(float(cm) / 2.54, 1)
        dims.append({"name": name, "value": float(cm), "unit": "cm", "position": position})
        dims.append({"name": name, "value": inches, "unit": "in", "position": position})

    if entry.get("height_cm"):
        add("height", entry["height_cm"], "left")
    if entry.get("width_cm"):
        add("width_bottom", entry["width_cm"], "bottom")
    p = {"style": "default", "background": "white", "output_format": "png",
         "output_size": 1600, "dimensions": dims, "units_display": "dual_slash"}
    if entry.get("title"):
        p["title"] = entry["title"]
    if entry.get("weight_g"):
        p["weight"] = {"value": entry["weight_g"], "unit": "g", "label": "Net Weight"}
    if entry.get("capacity_ml"):
        p["capacity"] = {"value": entry["capacity_ml"], "unit": "ml"}
    return p


def export_variants(packshot_path, out_dir, channels):
    im = ev.load_rgba(packshot_path)
    sprite = im.crop(ev.product_bbox(im))
    for ch in channels:
        if ch not in ev.PRESETS:
            continue
        aw, ah, fill, ms = ev.PRESETS[ch]
        out, ext = ev.make_variant(sprite, ev.target_size(aw, ah, ms), fill, "white")
        dest = os.path.join(out_dir, f"{ch}.{ext}")
        out.save(dest, **({"quality": 92} if ext == "jpg" else {}))
        print(f"    variant {ch}: {os.path.relpath(dest)} ({out.width}x{out.height})")


def main():
    global KEY
    ap = argparse.ArgumentParser(description="Folder of product photos -> store-ready catalog. Runs with zero args using ./products -> ./catalog.")
    ap.add_argument("--input", default="./products", help="folder of product photos (default ./products)")
    ap.add_argument("--output", default="./catalog", help="output folder (default ./catalog)")
    ap.add_argument("--scenes", default=DEFAULT_SCENES, help="pipe-separated lifestyle scenes (has sensible defaults)")
    ap.add_argument("--variants", default="amazon,shopify,etsy", help="marketplace variants to export")
    ap.add_argument("--dims", default=None, help="measurements file (.json or .csv); auto-detects ./dims.json")
    ap.add_argument("--no-dims", action="store_true", help="skip dimension images without asking")
    args = ap.parse_args()

    KEY = api_key()
    scenes = [s.strip() for s in args.scenes.split("|") if s.strip()]
    channels = [c.strip() for c in args.variants.split(",") if c.strip()]
    # Resolve measurements: explicit --dims, else auto-detect ./dims.json or <input>/dims.json
    dims_path = args.dims
    if not dims_path:
        for cand in ("dims.json", "dims.csv",
                     os.path.join(args.input, "dims.json"), os.path.join(args.input, "dims.csv")):
            if os.path.exists(cand):
                dims_path = cand
                print(f"(using measurements from {cand})")
                break
    dims = load_dims(dims_path) if dims_path else {}
    if not dims and not args.no_dims:
        # Do NOT silently skip. Signal that measurements are needed so the caller can ask the user.
        print("NEEDS_DIMENSIONS: no measurements found. To include dimension images, re-run with "
              "--dims <file.json|file.csv>. To proceed without them, re-run with --no-dims.")
        sys.exit(2)

    imgs = sorted(f for f in os.listdir(args.input) if f.lower().endswith(IMG_EXT))
    if not imgs:
        sys.exit(f"No images in {args.input}")
    print(f"Building catalog for {len(imgs)} product(s) -> {args.output}")

    manifest = {}
    for fn in imgs:
        slug = os.path.splitext(fn)[0]
        src = os.path.join(args.input, fn)
        out_dir = os.path.join(args.output, slug)
        os.makedirs(out_dir, exist_ok=True)
        print(f"== {slug} ==")
        files = {}

        b64 = b64_resized(src)
        cut_url = result_url(post("/v1/product/cutout", {"file": b64}))
        download(cut_url, os.path.join(out_dir, "cutout.png")); files["cutout"] = "cutout.png"

        ps_url = result_url(post("/v1/product/packshot",
                                 {"image_url": cut_url, "background_color": "#FFFFFF"}))
        ps_path = os.path.join(out_dir, "packshot.jpg")
        download(ps_url, ps_path); files["packshot"] = "packshot.jpg"

        if fn in dims or slug in dims:
            entry = dims.get(fn) or dims.get(slug)
            j = post("/v2/image/edit/product_dimensions", {"image": b64, **dims_payload(entry)})
            u = result_url(j) or poll(j.get("status_url") or f"{BASE}/v2/status/{j.get('request_id')}")
            download(u, os.path.join(out_dir, "dimensions.png")); files["dimensions"] = "dimensions.png"

        for i, scene in enumerate(scenes, 1):
            j = post("/v1/product/lifestyle_shot_by_text", {
                "image_url": cut_url, "scene_description": scene, "mode": "high_control",
                "placement_type": "automatic_aspect_ratio", "aspect_ratio": "1:1",
                "num_results": 1, "sync": True, "optimize_description": True})
            u = result_url(j)
            if u:
                download(u, os.path.join(out_dir, f"lifestyle_{i}.jpg"))
                files[f"lifestyle_{i}"] = f"lifestyle_{i}.jpg"

        export_variants(ps_path, out_dir, channels)

        # Listing-copy scaffold. Bria generates images, not text — the agent (LLM)
        # fills the SEO fields below by viewing packshot.jpg. See SKILL.md "Write listing copy".
        entry = dims.get(fn) or dims.get(slug) or {}
        listing = {
            "sku": slug,
            "title": entry.get("title"),
            "seo_title": None,          # <= 60 chars, keyword-first
            "meta_description": None,   # <= 160 chars
            "description": None,        # 1-2 paragraph product description
            "bullets": [],              # 4-6 benefit-led bullet points
            "tags": [],                 # search keywords
            "dimensions": entry or None,
            "images": files,
        }
        with open(os.path.join(out_dir, "listing.json"), "w") as f:
            json.dump(listing, f, indent=2)
        files["listing"] = "listing.json"
        manifest[slug] = files

    with open(os.path.join(args.output, "catalog.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"DONE — catalog manifest at {os.path.join(args.output, 'catalog.json')}")


if __name__ == "__main__":
    main()

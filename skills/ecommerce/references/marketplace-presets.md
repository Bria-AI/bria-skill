# Marketplace Presets

Specs the variant exporter enforces per channel. Values reflect each marketplace's main-image guidance at time of writing — always confirm against the latest official policy before a large publish.

## Amazon (main product image)

| Rule | Value |
|------|-------|
| Background | Pure white `#FFFFFF` (RGB 255,255,255) |
| Aspect ratio | 1:1 (square) |
| Product fill | Product fills ~85% of the frame |
| Minimum resolution | 1600 px longest side (≥ 1000 to zoom); 2000–3000 px recommended |
| Format | JPEG (also TIFF/PNG accepted) |
| Not allowed on main | Text, logos, watermarks, props, additional objects, borders |

Notes: the main image must be the product only on pure white. Lifestyle/props belong in the secondary image slots, not the main.

## Shopify

| Rule | Value |
|------|-------|
| Background | White or transparent (be consistent across the catalog) |
| Aspect ratio | 1:1 primary; 4:5 also common for product pages |
| Product fill | ~90%, consistent padding across all products |
| Recommended resolution | 2048 × 2048 (supports zoom); max 4472 × 4472 / 20 MP |
| Format | JPEG (white bg) or PNG (transparent) |

Notes: Shopify is flexible, but a uniform background + padding across the catalog is what makes a store look professional.

## Etsy

| Rule | Value |
|------|-------|
| Aspect ratio | 5:4 landscape (thumbnail crop) |
| Background | White or lifestyle — Etsy encourages context/lifestyle shots |
| Product fill | ~85% |
| Recommended resolution | 2000 px+ on the shortest side |
| Format | JPEG or PNG |

Notes: Etsy thumbnails crop to ~5:4, so keep the product centered with margin so nothing important is clipped.

## How the exporter applies these

`export_variants.py` (and `build_catalog.py`) for each channel:
1. Finds the product's bounding box (via alpha channel, or near-white detection).
2. Builds a canvas at the channel aspect ratio with the shortest side ≥ the channel minimum.
3. Scales the product so it spans the channel's fill ratio of the frame.
4. Centers it on the channel background (white by default; `--bg transparent` for PNG).
5. Saves JPEG (white/solid bg) or PNG (transparent).

Override fill with `--fill 0.8` and background with `--bg "#F5F0E8"` when a brand needs it.

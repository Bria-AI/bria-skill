---
name: ecommerce
description: End-to-end e-commerce product catalog generation — turn a folder of raw product photos into clean packshots, product cutouts, Amazon-style dimensions images, lifestyle scenes, and marketplace-ready listing variants for Amazon, Shopify, and Etsy. Powered by Bria.ai's product pipeline. Use when building a product catalog, batch-processing product photos, or creating packshots, cutouts, dimension images, lifestyle shots, or marketplace-compliant listing images at scale.
license: MIT
metadata:
  author: Bria AI
  version: "1.3.5"
---

# Bria E-commerce — Product Catalog Builder

The full e-commerce product-catalog pipeline now lives in the **bria-ai** skill, alongside all other Bria image capabilities (generation, editing, background removal, upscaling, and more). This keeps one place to authenticate and one set of helpers to maintain.

**Use the `bria-ai` skill for all product-catalog work.** It contains:

- **Batch catalog pipeline** — `build_catalog.py`: a folder of raw product photos → per-product cutout, packshot, dimensions image, lifestyle scenes, and marketplace variants.
- **Marketplace variants** — `export_variants.py` + Marketplace Presets: Amazon / Shopify / Etsy specs (background, aspect ratio, product fill, min resolution).
- **Product endpoints** — cutout, packshot, shadow, lifestyle shot (by text or image), product integrate, and Amazon-style product dimensions images (with dual `cm / in` callouts, weight, and capacity).
- **Listing copy scaffold** — a `listing.json` per product for SEO title, description, bullets, and tags.

See the **bria-ai** skill's "Product Catalog Pipeline (batch)" section and its [API Endpoints Reference](../bria-ai/references/api-endpoints.md) for full details.

## Related Skills

- **bria-ai** — the main skill; contains the full product-catalog pipeline and all image capabilities
- **image-utils** — Pillow-based resize/crop/composite (used by the variant exporter)

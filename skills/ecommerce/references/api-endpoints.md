# E-commerce API Endpoints Reference

Base URL: `https://engine.prod.bria-api.com`
Auth header: `api_token: $BRIA_API_KEY`
Input: `image_url` (URL) or `file` (base64) on `/v1/product/*`; `image` (URL or base64) on `/v2/.../product_dimensions`. Result URLs expire after ~1 hour — download promptly.

---

## POST /v1/product/cutout

Remove the background → clean transparent PNG.

```json
{ "image_url": "https://…/raw.jpg" }        // or { "file": "BASE64" }
```
Response: `{ "result_url": "https://…png" }` (synchronous).

---

## POST /v1/product/packshot

Standardized 2000×2000 packshot on a solid/clean background.

| Param | Type | Notes |
|-------|------|-------|
| `image_url` / `file` | string | Product image (cutout recommended) |
| `background_color` | string | Hex like `#FFFFFF`, or `transparent` |
| `sku` | string | Optional label/id |

Response: `{ "result_url": "…" }` (synchronous).

---

## POST /v1/product/shadow

Add a realistic shadow to a cutout.

| Param | Type | Notes |
|-------|------|-------|
| `image_url` / `file` | string | Product cutout |
| `type` | string | `regular` (drop) or `float` (elliptical) |
| `background_color` | string | Hex or `transparent` |
| `shadow_intensity` | int | 0–100 (approx) |

Response: `{ "result_url": "…" }` (synchronous).

---

## POST /v2/image/edit/product_dimensions

Render a dimensions/measurement callout image. Background is removed automatically. Async: returns `request_id` + `status_url` (202); poll `status_url`.

| Param | Type | Notes |
|-------|------|-------|
| `image` | string | URL or base64 (**field name is `image`**) |
| `dimensions` | array | `[{ "name": "height"\|"width_bottom"\|"width_top", "value": float, "unit": "mm\|cm\|m\|in\|ft", "position": "top\|bottom\|left\|right" }]` |
| `style` | string | `default`, `childlike`, `elegant` |
| `title` | string | Optional headline (≤ 80 chars) |
| `weight` | object | `{ "value": float, "unit": "lb\|oz\|g\|kg", "label": "Weight"\|"Net Weight" }` |
| `capacity` | object | `{ "value": float, "unit": "fl_oz\|ml\|l\|qt\|gal\|cups" }` |
| `background` | string | `white`, `cream`, `charcoal`, or hex |
| `output_format` | string | `png`, `jpeg`, or `dual` |
| `output_size` | int | 256–2200 (square edge) |

Poll response contains `result_url` (or `result`).

---

## POST /v1/product/lifestyle_shot_by_text

Place the product in an AI-generated scene from a text description.

| Param | Type | Notes |
|-------|------|-------|
| `image_url` / `file` | string | Product (cutout recommended) |
| `scene_description` | string | Scene: environment + lighting + mood |
| `mode` | string | `base`, `high_control` (recommended), `fast` |
| `placement_type` | string | `automatic`, `automatic_aspect_ratio`, `manual_placement`, `custom_coordinates`, `manual_padding`, `original` |
| `aspect_ratio` | string | e.g. `1:1`, `4:5`, `16:9` (with `automatic_aspect_ratio`) |
| `num_results` | int | Number of variations |
| `sync` | bool | `true` returns results inline |
| `optimize_description` | bool | Let Bria refine the prompt |

Response: `{ "result": [[ "image_url", "seed", "session_id" ], …] }`. Extract `result[0][0]`.

---

## POST /v1/product/lifestyle_shot_by_image

Same as above but the scene comes from a reference background image.

| Param | Type | Notes |
|-------|------|-------|
| `image_url` / `file` | string | Product |
| `ref_image_urls` | array | One or more background reference URLs |
| `placement_type` | string | see above |
| `num_results` | int | variations |

Response: `{ "result": [[ "image_url", … ], …] }`.

---

## POST /image/edit/product/integrate

Composite one or more products into a scene at exact coordinates; lighting/perspective auto-matched.

| Param | Type | Notes |
|-------|------|-------|
| `scene` | string | Scene image URL/base64 |
| `products` | array | `[{ "image": "…", "coordinates": { "x","y","width","height" } }]` |
| `seed` | int | Deterministic generation |

Response: `{ "result": { "image_url": "…" } }` (sync) or `202` + `status_url`.

---

## Scene-description tips (lifestyle)

- Environment first: "marble bathroom shelf with eucalyptus", "bright kitchen counter", "warm wooden desk".
- Add lighting + mood: "soft natural light", "morning sun", "studio lighting", "cozy".
- `high_control` mode ≈ 90–110 words; `base`/`fast` ≈ 50–60 words.
- A solid-color background: put a hex in `scene_description` (only with `num_results=1`).

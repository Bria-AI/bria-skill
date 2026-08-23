# Bria.ai API Reference

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** Include these headers in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
User-Agent: BriaSkills/<version>
```

> **Required:** Always include the `User-Agent: BriaSkills/<version>` header (where `<version>` is the current skill version from `package.json`, e.g. `BriaSkills/1.3.6`) in every API call, including status polling requests.

---

## FIBO - Image Generation

### POST /v2/image/generate

Generate images from text prompts using FIBO's structured prompt system.

**Request:**
```json
{
  "prompt": "string (required)",
  "aspect_ratio": "1:1",
  "resolution": "1MP",
  "negative_prompt": "string",
  "num_results": 1,
  "seed": null
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | required* | Image description (* or use `structured_prompt`) |
| `aspect_ratio` | string | "1:1" | "1:1", "4:3", "16:9", "3:4", "9:16" |
| `resolution` | string | "1MP" | Output image resolution. "1MP" or "4MP". "4MP" improves image details, especially for photorealism, but increases latency by ~30 seconds. |
| `negative_prompt` | string | - | What to exclude |
| `num_results` | int | 1 | Number of images (1-4) |
| `seed` | int | random | For reproducibility |
| `structured_prompt` | string | - | JSON from previous generation (for refinement). Use with `prompt` to refine, or alone with `seed` to recreate. |
| `image_url` | string | - | Reference image (for inspire mode) |

**Input Combination Rules** (mutually exclusive):
- `prompt` — Generate from text
- `image_url` — Generate inspired by a reference image
- `image_url` + `prompt` — Generate inspired by image, guided by text
- `structured_prompt` + `seed` — Recreate a previous image exactly
- `structured_prompt` + `prompt` + `seed` — Refine a previous image with new instructions

All combinations support `aspect_ratio`, `negative_prompt`, `num_results`, and `seed`.

**Response:**
```json
{
  "request_id": "uuid",
  "status_url": "https://engine.prod.bria-api.com/v2/status/uuid"
}
```

**Completed Result:**
```json
{
  "status": "COMPLETED",
  "result": {
    "image_url": "https://...",
    "structured_prompt": "{...}",
    "seed": 12345
  }
}
```

---

## RMBG-2.0 - Background Removal

### POST /v2/image/edit/remove_background

Remove background from image. Returns PNG with transparency.

**Request:**
```json
{
  "image": "https://publicly-accessible-image-url"
}
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image` | string | Source image URL (JPEG, PNG, WEBP) |

**Response:**
```json
{
  "request_id": "uuid",
  "status_url": "https://..."
}
```

**Completed Result:**
```json
{
  "status": "COMPLETED",
  "result": {
    "image_url": "https://...png"
  }
}
```

---

## FIBO-Edit - Image Editing

### POST /v2/image/edit

Edit an image with a natural language instruction — no mask required. Send one image to change it,
or 2–4 images to combine them: the subject from one with an outfit, product, style, or background
from another.

**Request:**
```json
{
  "images": ["https://source-image-url"],
  "instruction": "change the mug color to red"
}
```

**Multi-reference request.** `images` is ordered, and the instruction addresses each entry by its
position — the first is "image 1", the second "image 2", and so on:
```json
{
  "images": ["https://man-image-url", "https://santa-outfit-image-url"],
  "instruction": "dress the man in image 1 in the santa outfit from image 2",
  "seed": 1234
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `images` | array | required | 1–4 image URLs or base64 data URLs. **Order matters** — the instruction refers to them as "image 1", "image 2", … in the order they are sent |
| `instruction` | string | required | Edit instruction in natural language. Refer to additional images by position |
| `seed` | int | random | For reproducibility — the same images, instruction and seed reproduce the same result |
| `aspect_ratio` | string | - | Output ratio: "1:1", "4:3", "16:9", "3:4", "9:16". Honored with 2+ images; with a single image the output follows that image and the response `warning` says so. Omit it to follow the first image |
| `model_version` | string | - | Deprecated and ignored — the service picks the edit model from the request contents. A value that is sent comes back with a notice in `warning`; omit it |

**Writing a multi-reference instruction:**
- Put the image being edited first and the references after it.
- Say what each reference contributes ("the outfit from image 2", "the background of image 3"), not
  just that it exists.
- Plain prose, plain words — "image 1", "image 2". No brackets, tags, or markup.

**Constraints** — each returns 422 with a readable message:
- More than 4 images.
- A `mask` together with 2 or more images (masked edits are single-image only).
- 2 or more images together with a tailored `model_id` or `model_version: FIBO_BBQ` — both of those
  run on the single-reference model.

**Completed Result:**
```json
{
  "status": "COMPLETED",
  "result": {
    "image_url": "https://...",
    "seed": 1234,
    "warning": null
  }
}
```

`warning` is set when a parameter was accepted but not honored — `aspect_ratio` on a single-image
request, a supplied `model_version`, or a tuning parameter the serving model does not read. Relay it
to the user rather than dropping it.

### POST /v2/image/edit/gen_fill

Generate content in a masked region (inpainting).

**Request:**
```json
{
  "image": "https://source-image-url",
  "mask": "https://mask-image-url",
  "prompt": "what to generate",
  "mask_type": "manual",
  "negative_prompt": "string",
  "num_results": 1
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Source image URL |
| `mask` | string | required | Mask URL (white=edit, black=keep) |
| `prompt` | string | required | What to generate in masked area |
| `mask_type` | string | "manual" | "manual" or "automatic" |
| `negative_prompt` | string | - | What to avoid |
| `num_results` | int | 1 | Number of variations |

**Mask Requirements:**
- White pixels (255) = area to edit
- Black pixels (0) = area to preserve
- Same aspect ratio as source image

### POST /v2/image/edit/erase

Remove objects defined by mask.

**Request:**
```json
{
  "image": "https://source-image-url",
  "mask": "https://mask-image-url"
}
```

### POST /v2/image/edit/erase_foreground

Remove primary subject and fill with background.

**Request:**
```json
{
  "image": "https://source-image-url"
}
```

### POST /v2/image/edit/replace_background

Replace background with AI-generated content.

**Request:**
```json
{
  "image": "https://source-image-url",
  "prompt": "new background description"
}
```

### POST /v2/image/edit/blur_background

Apply blur effect to image background.

**Request:**
```json
{
  "image": "https://source-image-url"
}
```

### POST /v2/image/edit/expand

Expand/outpaint an image to extend its boundaries.

**Request:**
```json
{
  "image": "base64-string-or-url",
  "aspect_ratio": "16:9",
  "prompt": "optional description for new content"
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Source image URL or base64 string |
| `aspect_ratio` | string | required | Target ratio: "1:1", "4:3", "16:9", "3:4", "9:16" |
| `prompt` | string | - | Optional - describe content to generate |

### POST /v2/image/edit/enhance

Enhance image quality (lighting, colors, details).

**Request:**
```json
{
  "image": "https://source-image-url"
}
```

### POST /v2/image/edit/increase_resolution

Upscale image resolution.

**Request:**
```json
{
  "image": "https://source-image-url",
  "desired_increase": 4,
  "preserve_alpha": true
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Source image URL |
| `desired_increase` | int | 2 | Upscale factor, range 2–4 |
| `preserve_alpha` | bool | false | Preserve transparency. Set `true` when input has an alpha channel — the API upscales and recombines the alpha server-side, so you don't need to handle it client-side. |

### POST /v1/product/cutout

Remove the background from a product photo → clean transparent PNG. The `/v1/product/*` endpoints take `image_url` (URL) or `file` (base64).

**Request:**
```json
{ "image_url": "https://…/raw.jpg" }
```
Response: `{ "result_url": "https://…png" }` (synchronous).

### POST /v1/product/packshot

Standardized 2000×2000 packshot on a solid/clean background.

| Parameter | Type | Notes |
|-----------|------|-------|
| `image_url` / `file` | string | Product image (a cutout is recommended) |
| `background_color` | string | Hex like `#FFFFFF`, or `transparent` |
| `sku` | string | Optional label/id |

Response: `{ "result_url": "…" }` (synchronous).

### POST /v1/product/shadow

Add a realistic shadow to a product cutout.

| Parameter | Type | Notes |
|-----------|------|-------|
| `image_url` / `file` | string | Product cutout |
| `type` | string | `regular` (drop) or `float` (elliptical) |
| `background_color` | string | Hex or `transparent` |
| `shadow_intensity` | int | 0–100 (approx) |

Response: `{ "result_url": "…" }` (synchronous).

### POST /v1/product/lifestyle_shot_by_text

Place a product in a lifestyle scene using text description.

**Request:**
```json
{
  "file": "BASE64_ENCODED_IMAGE",
  "scene_description": "modern kitchen countertop, natural lighting",
  "placement_type": "automatic"
}
```

**Parameters:**

| Parameter | Type | Notes |
|-----------|------|-------|
| `image_url` / `file` | string | Product (cutout recommended) |
| `scene_description` | string | Environment + lighting + mood |
| `mode` | string | `base`, `high_control` (recommended), `fast` |
| `placement_type` | string | `automatic`, `automatic_aspect_ratio`, `manual_placement`, `custom_coordinates`, `manual_padding`, `original` |
| `aspect_ratio` | string | e.g. `1:1`, `4:5`, `16:9` (with `automatic_aspect_ratio`) |
| `num_results` | int | Number of variations |
| `sync` | bool | `true` returns results inline |
| `optimize_description` | bool | Let Bria refine the prompt |

Response: `{ "result": [[ "image_url", "seed", "session_id" ], …] }` — extract `result[0][0]`.

### POST /v1/product/lifestyle_shot_by_image

Same as `lifestyle_shot_by_text`, but the scene comes from a reference background image instead of a text description.

| Parameter | Type | Notes |
|-----------|------|-------|
| `image_url` / `file` | string | Product |
| `ref_image_urls` | array | One or more background reference URLs |
| `placement_type` | string | see above |
| `num_results` | int | variations |

Response: `{ "result": [[ "image_url", … ], …] }`.

### POST /image/edit/product/integrate

Integrate and embed one or more products into a predefined scene at precise user-defined coordinates. The product is automatically matched to the scene's lighting, perspective, and aesthetics. Products are automatically cut out from their background as part of the pipeline.

**Request:**
```json
{
  "scene": "https://scene-image-url",
  "products": [
    {
      "image": "https://product-image-url",
      "coordinates": {
        "x": 100,
        "y": 200,
        "width": 300,
        "height": 400
      }
    }
  ],
  "seed": 42
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scene` | string | required | Scene image URL or base64. Accepted formats: jpeg, jpg, png, webp |
| `products` | array | required | Array of product objects (1 to N products) |
| `products[].image` | string | required | Product image URL or base64. If it has an alpha channel, no cutout is applied; otherwise automatic cutout is applied |
| `products[].coordinates` | object | required | Placement and scaling of the product within the scene |
| `products[].coordinates.x` | int | required | X-coordinate of the product's top-left corner (pixels) |
| `products[].coordinates.y` | int | required | Y-coordinate of the product's top-left corner (pixels) |
| `products[].coordinates.width` | int | required | Desired product width in pixels (must not exceed scene dimensions) |
| `products[].coordinates.height` | int | required | Desired product height in pixels (must not exceed scene dimensions) |
| `seed` | int | random | Seed for deterministic generation |

**Response:**
```json
{
  "request_id": "uuid",
  "result": {
    "image_url": "https://..."
  }
}
```

**Async Response (202):**
```json
{
  "request_id": "uuid",
  "status_url": "https://..."
}
```

### POST /v2/image/edit/product_dimensions

Render a marketplace-ready dimension image from a product photo: the background is removed automatically, then measurement callout lines + labels are drawn around the product, with an optional title and optional weight/capacity text. Three visual styles. Useful for e-commerce listings (Amazon-style "dimensions" images).

**Request:**
```json
{
  "image": "https://product-image-url",
  "style": "default",
  "dimensions": [
    {"name": "height", "value": 12, "unit": "cm", "position": "left"},
    {"name": "width_bottom", "value": 6, "unit": "cm", "position": "bottom"}
  ],
  "title": "Gummies Bottle",
  "weight": {"value": 250, "unit": "g", "label": "Net Weight"},
  "capacity": {"value": 500, "unit": "ml"},
  "background": "white",
  "output_format": "png"
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Product photo URL or base64. Background is removed automatically — no pre-cutout needed |
| `dimensions` | array | required | One or more dimension callouts (min 1) |
| `dimensions[].name` | string | required | `height`, `width_bottom`, or `width_top` (`length`/`depth` not currently enabled) |
| `dimensions[].value` | float | required | Physical measurement value (must be > 0) |
| `dimensions[].unit` | string | required | `mm`, `cm`, `m`, `in`, `"` (inches), `ft`, `'` (feet) |
| `dimensions[].position` | string | per-name | Callout side: `top`, `bottom`, `left`, `right`. Defaults: height→`left`, width_bottom→`bottom`, width_top→`top` |
| `style` | string | required | `default`, `childlike`, or `elegant` |
| `units_display` | string | "single" | `single`, `dual_bullet`, `dual_slash`, `dual_parens`. For dual modes, supply two `dimensions` entries with the same `name`+`position` but different `unit` (e.g. `in` and `cm`) — they merge into one dual-unit label |
| `background` | string | "white" | `white`, `cream`, `charcoal`, or a hex color (e.g. `#f5f0e8`) |
| `title` | string | - | Optional headline above the product (max 80 chars) |
| `title_position` | string | "top_center" | `top_left`, `top_center`, `top_right` |
| `weight` | object | - | Optional weight callout below the product |
| `weight.value` | float | required* | Weight value (> 0) *if `weight` is provided |
| `weight.unit` | string | required* | `lb`, `oz`, `g`, `kg` |
| `weight.label` | string | "Weight" | `Weight` or `Net Weight` |
| `capacity` | object | - | Optional capacity callout below the product |
| `capacity.value` | float | required* | Capacity value (> 0) *if `capacity` is provided |
| `capacity.unit` | string | required* | `fl_oz`, `ml`, `l`, `qt`, `gal`, `cups` |
| `output_format` | string | "png" | `png`, `jpeg`, or `dual` (composite PNG + a transparent overlay-only PNG, returned as two images) |
| `output_size` | int | 2200 | Square output edge length in px (256–2200) |
| `proportional_lines` | bool | true | Scale each dimension line's length to its measurement (the largest per axis spans the product) |

**Async Response (202):**
```json
{
  "request_id": "uuid",
  "status_url": "https://..."
}
```

Poll `status_url` for the result. `dual` output returns two images: `[composite, overlay]`.

---

## Text-Based Object Editing

### POST /v2/image/edit/add_object_by_text

Add a new object to an image using natural language.

**Request:**
```json
{
  "image": "base64-or-url",
  "instruction": "Place a red vase with flowers on the table"
}
```

### POST /v2/image/edit/replace_object_by_text

Replace an existing object with a new one.

**Request:**
```json
{
  "image": "base64-or-url",
  "instruction": "Replace the red apple with a green pear"
}
```

### POST /v2/image/edit/erase_by_text

Remove a specific object by name.

**Request:**
```json
{
  "image": "base64-or-url",
  "object_name": "table"
}
```

---

## Image Transformation

### POST /v2/image/edit/blend

Blend/merge images or apply textures.

**Request:**
```json
{
  "image": "base64-or-url",
  "overlay": "texture-or-art-url",
  "instruction": "Place the art on the shirt, keep the art exactly the same"
}
```

### POST /v2/image/edit/reseason

Change the season or weather of an image.

**Request:**
```json
{
  "image": "base64-or-url",
  "season": "winter"
}
```

**Seasons:** `spring`, `summer`, `autumn`, `winter`

### POST /v2/image/edit/restyle

Transform the artistic style of an image.

**Request:**
```json
{
  "image": "base64-or-url",
  "style": "oil_painting"
}
```

**Style IDs:** `render_3d`, `cubism`, `oil_painting`, `anime`, `cartoon`, `coloring_book`, `retro_ad`, `pop_art_halftone`, `vector_art`, `story_board`, `art_nouveau`, `cross_etching`, `wood_cut`

### POST /v2/image/edit/relight

Modify the lighting setup of an image.

**Request:**
```json
{
  "image": "base64-or-url",
  "light_type": "sunrise light",
  "light_direction": "front"
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Source image URL or base64 |
| `light_type` | string | required | Lighting preset (see values below) |
| `light_direction` | string | required | `front`, `side`, `bottom`, `top-down` |

**Light Types:** `midday`, `blue hour light`, `low-angle sunlight`, `sunrise light`, `spotlight on subject`, `overcast light`, `soft overcast daylight lighting`, `cloud-filtered lighting`, `fog-diffused lighting`, `side lighting`, `moonlight lighting`, `starlight nighttime`, `soft bokeh lighting`, `harsh studio lighting`

---

## Image Restoration & Conversion

### POST /v2/image/edit/sketch_to_colored_image

Convert a sketch or line drawing to a photorealistic image.

**Request:**
```json
{
  "image": "sketch-base64-or-url",
  "prompt": "optional description"
}
```

### POST /v2/image/edit/restore

Restore old/damaged photos by removing noise, scratches, and blur.

**Request:**
```json
{
  "image": "base64-or-url"
}
```

### POST /v2/image/edit/colorize

Add color to B&W photos or convert to B&W.

**Request:**
```json
{
  "image": "base64-or-url",
  "color": "contemporary color"
}
```

**Colors:** `contemporary color`, `vivid color`, `black and white colors`, `sepia vintage`

### POST /v2/image/edit/crop_foreground

Remove background and crop tightly around the foreground.

**Request:**
```json
{
  "image": "base64-or-url"
}
```

---

## Structured Instructions

### POST /v2/structured_instruction/generate

Generate a structured JSON instruction from natural language (no image generated).

**Request:**
```json
{
  "images": ["base64-or-url"],
  "instruction": "change to golden hour lighting",
  "mask": "optional-mask-url"
}
```

**Returns:** `structured_instruction` JSON that can be passed to `/v2/image/edit`

---

## Status Polling

### GET /v2/status/{request_id}

Check async request status.

**Response:**
```json
{
  "status": "IN_PROGRESS | COMPLETED | FAILED",
  "result": {
    "image_url": "https://..."
  },
  "request_id": "uuid"
}
```

**Status Values:**
- `IN_PROGRESS` - Still processing
- `COMPLETED` - Success, result available
- `FAILED` - Error occurred

**Polling Pattern:**
```python
import requests, time

def poll(status_url, api_key, timeout=120):
    headers = {"api_token": api_key, "User-Agent": "BriaSkills/1.3.6"}
    for _ in range(timeout // 2):
        r = requests.get(status_url, headers=headers)
        data = r.json()
        if data["status"] == "COMPLETED":
            return data["result"]["image_url"]
        if data["status"] == "FAILED":
            raise Exception(data.get("error"))
        time.sleep(2)
    raise TimeoutError()
```

---

## Error Handling

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad request |
| 401 | Unauthorized - invalid API key |
| 415 | Unsupported media type |
| 422 | Validation failed / Content moderation blocked |
| 429 | Rate limited |
| 500 | Server error |

### Supported Image Formats

- **Input:** JPEG, JPG, PNG, WEBP (RGB, RGBA, CMYK)
- **Output:** PNG (with transparency where applicable)

# Bria.ai API Reference

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** Include `api_token` header in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
```

---

## FIBO - Image Generation

### POST /v2/image/generate

Generate images from text prompts using FIBO's structured prompt system.

**Request:**
```json
{
  "prompt": "string (required)",
  "aspect_ratio": "1:1",
  "negative_prompt": "string",
  "num_results": 1,
  "seed": null
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | required | Image description |
| `aspect_ratio` | string | "1:1" | "1:1", "4:3", "16:9", "3:4", "9:16" |
| `negative_prompt` | string | - | What to exclude |
| `num_results` | int | 1 | Number of images (1-4) |
| `seed` | int | random | For reproducibility |
| `structured_prompt` | string | - | JSON from previous generation (for refinement) |
| `image_url` | string | - | Reference image (for inspire mode) |

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

Edit an image using natural language instructions. No mask required.

**Request:**
```json
{
  "images": ["https://source-image-url"],
  "instruction": "change the mug color to red"
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `images` | array | required | Array of image URLs or base64 data URLs |
| `instruction` | string | required | Edit instruction in natural language |

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
  "scale": 2
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image` | string | required | Source image URL |
| `scale` | int | 2 | Upscale factor (2 or 4) |

### POST /v2/image/edit/lifestyle_shot_by_text

Place a product in a lifestyle scene using text description.

**Request:**
```json
{
  "image": "https://product-image-url",
  "prompt": "modern kitchen countertop, natural lighting",
  "placement_type": "automatic"
}
```

### POST /v2/image/edit/shot_by_image

Place a product on a reference background image.

**Request:**
```json
{
  "image": "https://product-image-url",
  "background": "https://background-image-url",
  "placement_type": "automatic"
}
```

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
  "light_type": "spotlight on subject, keep background settings"
}
```

---

## Text in Images

### POST /v2/image/edit/replace_text

Replace existing text in an image with new text.

**Request:**
```json
{
  "image": "base64-or-url",
  "new_text": "FIBO Edit!"
}
```

---

## Image Restoration & Conversion

### POST /v2/image/edit/sketch_to_image

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
  "style": "color_contemporary"
}
```

**Styles:** `color_contemporary`, `bw`

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
    for _ in range(timeout // 2):
        r = requests.get(status_url, headers={"api_token": api_key})
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

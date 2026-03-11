---
name: bria-ai
description: Generate, edit, create product images with AI. Remove or replace backgrounds, lifestyle shots, transparent PNGs, visual assets, batch generation, illustrations. Controllable image editing with Bria.ai commercially-safe models — fine-grained control over what gets generated, edited, or removed. Edit by text instruction, mask specific regions, add/replace/remove individual objects, control lighting, season, and style. Use for e-commerce product photography, background removal, image upscaling, style transfer, hero images, icons, banners, and pipeline workflows. Triggers on AI image generation, controllable editing, background removal, or visual asset creation.
homepage: https://bria.ai
license: MIT
metadata:
  author: Bria AI
  version: "1.2.6"
  dependencies:
    - type: env
      name: BRIA_API_KEY
      description: "Bria AI API key (get one at https://platform.bria.ai/console/account/api-keys)"
---

# Bria — Generate, Edit & Remove Background from Images with AI

Generate, edit, and create visual assets using Bria's commercially-safe AI models (Fibo, Fibo-Edit,  RMBG-2.0, GenFill, and more). Remove or replace backgrounds, create product lifestyle shots, generate transparent PNGs, batch generate images, and build pipeline workflows. Unlike black-box generators, Bria gives you fine-grained control: edit by text instruction, mask specific regions, add/replace/remove individual objects, change lighting or season independently.

## Setup — API Key Check

Before making any Bria API call, check for the API key and help the user set it up if missing:

### Step 1: Check if the key exists

```bash
echo $BRIA_API_KEY
```

If the output is **not empty**, skip to the next section.

### Step 2: If the key is missing, guide the user

Tell the user exactly this:
> To use image generation, you need a free Bria API key.
>
> 1. Go to https://platform.bria.ai/console/account/api-keys
> 2. Sign up or log in
> 3. Click **Create API Key**

Wait for the user to provide their API key. Do not proceed until they give you the key.

**Do not proceed with any image generation or editing until the API key is confirmed set.**

---

## Core Capabilities

| Need | Capability | Use Case |
|------|------------|----------|
| Generate images from text | FIBO Generate | Hero images, product shots, illustrations, social media images, banners |
| Edit images by text instruction | FIBO-Edit | Change colors, modify objects, transform scenes |
| Edit image region with mask | GenFill/Erase | Precise inpainting, add/replace specific regions |
| Add/Replace/Remove objects | Text-based editing | Add vase, replace apple with pear, remove table |
| Remove background (transparent PNG) | RMBG-2.0 | Extract subjects for overlays, logos, cutouts |
| Replace/blur/erase background | Background ops | Change, blur, or remove backgrounds |
| Expand/outpaint images | Outpainting | Extend boundaries, change aspect ratios |
| Upscale image resolution | Super Resolution | Increase resolution 2x or 4x |
| Enhance image quality | Enhancement | Improve lighting, colors, details |
| Restyle images | Restyle | Oil painting, anime, cartoon, 3D render |
| Change lighting | Relight | Golden hour, spotlight, dramatic lighting |
| Change season | Reseason | Spring, summer, autumn, winter |
| Composite/blend images | Image Blending | Apply textures, logos, merge images |
| Restore old photos | Restoration | Fix old/damaged photos |
| Colorize images | Colorization | Add color to B&W, or convert to B&W |
| Sketch to photo | Sketch2Image | Convert drawings to realistic photos |
| Create product lifestyle shots | Lifestyle Shot | Place products in scenes for e-commerce |
| Integrate products into scenes | Product Integrate | Embed products at exact coordinates |

## Quick Reference

### Generate an Image (FIBO)

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/generate" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "prompt": "your description",
    "aspect_ratio": "16:9",
    "resolution": "1MP",
    "sync": true
  }'
```

**Aspect ratios**: `1:1` (square), `16:9` (hero/banner), `4:3` (presentation), `9:16` (mobile/story), `3:4` (portrait)

**Resolution**: `1MP` (default) or `4MP` (improved details for photorealism, adds ~30s latency)

**Sync mode**: Pass `"sync": true` in the request body for single image generation to get the result directly in the response. For batch/multiple image generation, omit `sync` (or set `false`) and use polling instead.

> **Advanced**: For precise, deterministic control over generation, use **[VGL structured prompts](../vgl/SKILL.md)** instead of natural language. VGL defines every visual attribute (objects, lighting, composition) as explicit JSON.

### Remove Background (RMBG-2.0)

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/remove_background" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{"image": "https://..."}'
```

Returns PNG with transparency.

### Edit Image (FIBO-Edit) - No Mask Required

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "images": ["https://..."],
    "instruction": "change the mug to red"
  }'
```

### Edit Image Region with Mask (GenFill)

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/gen_fill" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "image": "https://...",
    "mask": "https://...",
    "prompt": "what to generate in masked area"
  }'
```

### Expand Image (Outpainting)

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/expand" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "image": "base64-or-url",
    "aspect_ratio": "16:9",
    "prompt": "coffee shop background, wooden table"
  }'
```

### Upscale Image

```bash
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/increase_resolution" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{"image": "https://...", "scale": 2}'
```

### Create Product Lifestyle Shot

```bash
curl -X POST "https://engine.prod.bria-api.com/v1/product/lifestyle_shot_by_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "image": "https://product-with-transparent-bg.png",
    "prompt": "modern kitchen countertop, natural morning light"
  }'
```

### Integrate Products into Scene

Place one or more products at exact coordinates in a scene. Products are automatically cut out and matched to the scene's lighting and perspective.

```bash
curl -X POST "https://engine.prod.bria-api.com/image/edit/product/integrate" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.6" \
  -d '{
    "scene": "https://scene-image-url",
    "products": [
      {
        "image": "https://product-image-url",
        "coordinates": {"x": 100, "y": 200, "width": 300, "height": 400}
      }
    ]
  }'
```

---

## Response Handling

### Sync (single image generation)

For single image requests, pass `"sync": true` in the request body. The response returns the result directly — no polling needed.

### Async with polling (batch generation)

For batch or multiple image generation, omit `sync` (or set `"sync": false`). The response returns a status URL to poll:

```json
{
  "request_id": "uuid",
  "status_url": "https://engine.prod.bria-api.com/v2/status/uuid"
}
```

Poll the status_url until `status: "COMPLETED"`, then get `result.image_url`.

```python
import requests, time

def get_result(status_url, api_key):
    while True:
        r = requests.get(status_url, headers={"api_token": api_key, "User-Agent": "BriaSkills/1.2.6"})
        data = r.json()
        if data["status"] == "COMPLETED":
            return data["result"]["image_url"]
        if data["status"] == "FAILED":
            raise Exception(data.get("error"))
        time.sleep(2)
```

---

## Prompt Engineering Tips

- **Style**: "professional product photography" vs "casual snapshot", "flat design illustration" vs "3D rendered"
- **Lighting**: "soft natural light", "studio lighting", "dramatic shadows"
- **Background**: "white studio", "gradient", "blurred office", "transparent"
- **Composition**: "centered", "rule of thirds", "negative space on left for text"
- **Quality keywords**: "high quality", "professional", "commercial grade", "4K", "sharp focus"
- **Negative prompts**: "blurry, low quality, pixelated", "text, watermark, logo"

---

## API Reference

See `references/api-endpoints.md` for complete endpoint documentation.

### Key Endpoints

**Image Generation**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/generate` | Generate images from text (FIBO) |

**Edit by Text (No Mask)**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit` | Edit image with natural language instruction |
| `POST /v2/image/edit/add_object_by_text` | Add objects to image |
| `POST /v2/image/edit/replace_object_by_text` | Replace objects in image |
| `POST /v2/image/edit/erase_by_text` | Remove objects by name |

**Edit with Mask**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/gen_fill` | Inpaint/generate in masked region |
| `POST /v2/image/edit/erase` | Erase masked region |

**Background Operations**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/remove_background` | Remove background (RMBG-2.0) |
| `POST /v2/image/edit/replace_background` | Replace with AI-generated background |
| `POST /v2/image/edit/blur_background` | Apply blur to background |
| `POST /v2/image/edit/erase_foreground` | Remove foreground, fill background |
| `POST /v2/image/edit/crop_foreground` | Crop tightly around subject |

**Image Transformation**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/expand` | Outpaint to new aspect ratio |
| `POST /v2/image/edit/enhance` | Enhance quality and details |
| `POST /v2/image/edit/increase_resolution` | Upscale 2x or 4x |
| `POST /v2/image/edit/blend` | Blend/merge images or textures |
| `POST /v2/image/edit/reseason` | Change season/weather |
| `POST /v2/image/edit/restyle` | Transform artistic style |
| `POST /v2/image/edit/relight` | Modify lighting |

**Restoration**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/sketch_to_colored_image` | Convert sketch to photo |
| `POST /v2/image/edit/restore` | Restore old/damaged photos |
| `POST /v2/image/edit/colorize` | Colorize B&W or convert to B&W |

**Product Photography**
| Endpoint | Purpose |
|----------|---------|
| `POST /v1/product/lifestyle_shot_by_text` | Create product lifestyle shots by text |
| `POST /image/edit/product/integrate` | Integrate products into scene at exact coordinates |

**Utilities**
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/structured_instruction/generate` | Generate JSON instruction (no image) |
| `GET /v2/status/{id}` | Check async request status |

### Authentication

All requests need `api_token` header:
```
api_token: YOUR_BRIA_API_KEY
User-Agent: BriaSkills/<version>
```
> **Required:** Always include the `User-Agent: BriaSkills/<version>` header (where `<version>` is the current skill version from `package.json`, e.g. `BriaSkills/1.2.6`) in every API call, including status polling requests.

---

## Additional Resources

- **[API Endpoints Reference](references/api-endpoints.md)** — Complete endpoint documentation with request/response formats
- **[Workflows & Pipelines](references/workflows.md)** — Batch generation, parallel pipelines, integration examples
- **[Python Client](references/code-examples/bria_client.py)** — Full-featured async Python client
- **[TypeScript Client](references/code-examples/bria_client.ts)** — Typed Node.js client
- **[Bash/curl Reference](references/code-examples/bria_client.sh)** — Shell functions for all endpoints

## Related Skills

- **[vgl](../vgl/SKILL.md)** — Write structured VGL JSON prompts for precise, deterministic control over FIBO image generation
- **[image-utils](../image-utils/SKILL.md)** — Classic image manipulation (resize, crop, composite, watermarks) for post-processing

---
name: "bria-ai"
displayName: "Bria AI"
description: "AI image generation, editing, and background removal API via Bria.ai — remove backgrounds to get transparent PNGs and cutouts, generate images from text prompts, and edit photos with natural language instructions. Also create product photography and lifestyle shots, replace or blur backgrounds, upscale resolution, restyle, and batch-generate visual assets. Commercially safe, royalty-free. 20+ specialized endpoints for e-commerce, web design, and content pipelines."
keywords: ["image-generation", "ai-images", "bria", "background-removal", "image-editing", "product-photography", "text-to-image"]
author: "Bria AI"
---

# Bria — AI Image Generation, Editing & Background Removal

Commercially safe, royalty-free image generation and editing through 20+ API endpoints. Generate from text, edit with natural language, remove backgrounds, create product shots, and build automated image pipelines.

For additional endpoint details beyond what is documented here, see the [Bria API reference for agents](https://docs.bria.ai/llms.txt).

## When to Use This Power

Use this power when the user wants to:
- **Generate images** — "create an image of...", "make me a banner", "generate a hero image", "I need a product photo"
- **Edit images** — "change the background", "make it look like winter", "add a vase to the table", "remove the person"
- **Remove/replace backgrounds** — "make the background transparent", "cut out the product", "replace with a studio background"
- **Product photography** — "create a lifestyle shot", "place this product in a kitchen scene", "e-commerce packshot"
- **Enhance/transform** — "upscale this image", "make it higher resolution", "restyle as oil painting", "change the lighting"
- **Batch/pipeline** — "generate 10 product images", "process all these images", "remove backgrounds in bulk"

This power handles the full spectrum of AI image operations. If the user mentions images, photos, visuals, or any visual content creation — use this power.

---

## What You Can Build

- **E-commerce product catalog** — Generate product photos, remove backgrounds for transparent PNGs, place products in lifestyle scenes (kitchen, office, outdoor), create packshots with consistent style
- **Landing page visuals** — Generate hero images, abstract tech backgrounds, team photos, and section illustrations — all matching your brand aesthetic
- **Social media content** — Instagram posts (1:1), Stories/Reels (9:16), LinkedIn banners (16:9), ad creatives — batch-generate variants for A/B testing
- **Marketing campaign assets** — Seasonal transformations (summer→winter), restyle product shots for different markets, create localized visuals at scale
- **Photo restoration pipeline** — Restore old damaged photos, colorize black & white images, upscale low-res photos to 4x, enhance quality automatically
- **Brand asset toolkit** — Remove backgrounds from logos, blend artwork onto products (t-shirts, mugs), create consistent product photography across your entire catalog
- **AI-powered design workflows** — Chain operations: generate→edit→remove background→place in scene→upscale — all automated through API pipelines

---

## Setup — Authentication

Before making any API call, you need a valid Bria access token.

### Step 1: Check for existing credentials

```bash
if [ -f ~/.bria/credentials ]; then
  BRIA_ACCESS_TOKEN=$(grep '^access_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
  BRIA_API_KEY=$(grep '^api_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
fi
if [ -z "$BRIA_ACCESS_TOKEN" ]; then
  echo "NO_CREDENTIALS"
elif [ -n "$BRIA_API_KEY" ]; then
  echo "READY"
else
  echo "CREDENTIALS_FOUND"
fi
```

If the output is `READY`, skip straight to making API calls — no introspection needed.
If the output is `CREDENTIALS_FOUND`, skip to Step 3.
If the output is `NO_CREDENTIALS`, proceed to Step 2.

### Step 2: Authenticate via device authorization

Start the device authorization flow:

**2a. Request a device code:**

```bash
DEVICE_RESPONSE=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/device/authorize" \
  -H "Content-Type: application/json")
echo "$DEVICE_RESPONSE"
```

Parse the response fields:
- `device_code` — used to poll for the token (keep this, don't show to user)
- `user_code` — the code the user must enter (e.g. `BRIA-XXXX`)
- `interval` — seconds between poll attempts

**2b. Show the user a single sign-in link.** Tell them exactly this — nothing more:

> **Connect your Bria account:** [Click here to sign in](https://platform.bria.ai/device/verify?user_code={user_code})
> Your code is **{user_code}** — it's already filled in.

Do NOT show two links. Do NOT show the raw URL separately. Do NOT use `verification_uri` from the API response. Keep it to one clickable link.

**2c. Poll for the token.** After showing the user the code, immediately start polling. Try up to 60 times with the given interval (default 5 seconds):

```bash
for i in $(seq 1 60); do
  TOKEN_RESPONSE=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/token" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=$DEVICE_CODE")
  ACCESS_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$ACCESS_TOKEN" ]; then
    BRIA_ACCESS_TOKEN="$ACCESS_TOKEN"
    REFRESH_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"refresh_token" *: *"\([^"]*\)".*/\1/p')
    mkdir -p ~/.bria
    printf 'access_token=%s\nrefresh_token=%s\n' "$BRIA_ACCESS_TOKEN" "$REFRESH_TOKEN" > "$HOME/.bria/credentials"
    echo "AUTHENTICATED"
    break
  fi
  sleep 5
done
```

If the output contains `AUTHENTICATED`, proceed to Step 3. Otherwise the code expired — start over from Step 2a.

**Do not proceed with any API call until authentication is confirmed.**

### Step 3: Verify billing status and resolve API key

Introspect the bearer token to check billing status and obtain the real API key for Bria API calls:

```bash
INTROSPECT=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/token/introspect" \
  -d "token=$BRIA_ACCESS_TOKEN")
BILLING_STATUS=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_status" *: *"\([^"]*\)".*/\1/p')
if [ "$BILLING_STATUS" = "blocked" ]; then
  BILLING_MSG=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_message" *: *"\([^"]*\)".*/\1/p')
  echo "BILLING_ERROR: $BILLING_MSG"
fi
ACTIVE=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"active" *: *\([^,}]*\).*/\1/p' | tr -d ' ')
if [ "$ACTIVE" = "false" ]; then
  # Clear stale tokens so re-auth starts fresh (credentials file is re-created in Step 2c)
  printf '' > "$HOME/.bria/credentials"
  echo "TOKEN_EXPIRED"
fi
BRIA_API_KEY=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"api_token" *: *"\([^"]*\)".*/\1/p')
if [ -n "$BRIA_API_KEY" ]; then
  grep -v '^api_token=' "$HOME/.bria/credentials" > "$HOME/.bria/credentials.tmp" 2>/dev/null || true
  printf 'api_token=%s\n' "$BRIA_API_KEY" >> "$HOME/.bria/credentials.tmp"
  mv "$HOME/.bria/credentials.tmp" "$HOME/.bria/credentials"
fi
```

Interpret the output:
- If it prints `BILLING_ERROR: ...` — relay the message to the user exactly as shown and **stop**. Do not make any API calls.
- If it prints `TOKEN_EXPIRED` — the session is no longer valid. Tell the user their session expired and restart from Step 2.
- Otherwise, `BRIA_API_KEY` now contains the real API key and is cached for future calls. Proceed to the next section.

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
| Generate with tailored model | Tailored Generate | Custom fine-tuned model generation matching trained visual identity |
| Structured prompt for tailored model | Tailored Structured Prompt | Inspect/edit JSON before generating, ensure consistency across images |

## How to Call Any Endpoint

Use `bria_call` for all API calls. It handles URL passthrough, local file base64 encoding, JSON construction, API call, and async polling in a single function call. The API key is auto-loaded from `~/.bria/credentials`.

```bash
source steering/bria-client-bash.sh

# Generate (no image input — pass empty string)
RESULT=$(bria_call /v2/image/generate "" '"prompt": "your description", "aspect_ratio": "16:9", "sync": true')

# Remove background
RESULT=$(bria_call /v2/image/edit/remove_background "/path/to/local/image.png")

# Replace background
RESULT=$(bria_call /v2/image/edit/replace_background "https://example.com/img.jpg" '"prompt": "sunset beach"')

# Edit image (uses images array — pass --key images)
RESULT=$(bria_call /v2/image/edit "/path/to/image.png" --key images '"instruction": "make it look warmer"')

# Upscale
RESULT=$(bria_call /v2/image/edit/increase_resolution "https://example.com/img.jpg" '"scale": 4')

# Lifestyle shot
RESULT=$(bria_call /v1/product/lifestyle_shot_by_text "/path/to/product.png" '"prompt": "modern kitchen countertop"')

# Generate with tailored model (no image input — pass empty string)
RESULT=$(bria_call /image/generate/tailored "" '"prompt": "product photo in brand style", "model_id": "your_model_id", "sync": true')

# Generate structured prompt for tailored model (no image, no polling)
RESULT=$(bria_call /structured_prompt/generate/tailored "" '"prompt": "product photo in brand style", "model_id": "your_model_id"')

echo "$RESULT"
```

**Calling convention:** `bria_call <endpoint> <image_or_empty> [--key <json_key>] [extra JSON fields...]`
- Pass a URL, local file path, or `""` (empty) for endpoints without image input
- Use `--key images` when the endpoint expects an `images` array instead of `image`
- Extra JSON fields are appended as key-value pairs: `'"key": "value"'`
- Returns the result image URL on success, or prints an error to stderr

**Generation options:** Aspect ratios `1:1`, `16:9`, `4:3`, `9:16`, `3:4`. Resolution `1MP` (default) or `4MP` (more detail, +30s). Pass `"sync": true` for single images.

> **Advanced**: For precise control over generation, use the **vgl** power for structured VGL JSON prompts instead of natural language.

See **steering/api-endpoints.md** for full parameter documentation on all 20+ endpoints.

---

## Prompt Engineering Tips

- **Style**: "professional product photography" vs "casual snapshot", "flat design illustration" vs "3D rendered"
- **Lighting**: "soft natural light", "studio lighting", "dramatic shadows"
- **Background**: "white studio", "gradient", "blurred office", "transparent"
- **Composition**: "centered", "rule of thirds", "negative space on left for text"
- **Quality keywords**: "high quality", "professional", "commercial grade", "4K", "sharp focus"
- **Negative prompts**: "blurry, low quality, pixelated", "text, watermark, logo"

### Recipes by Use Case

**Hero banner (16:9):** `"Modern tech startup workspace with developers collaborating, bright natural lighting, clean minimal aesthetic"` — include "clean background" or "minimal" for text overlay space

**Product photo (1:1):** `"Professional product photo of [item] on white studio background, soft shadows, commercial photography lighting"` — then remove background for transparent PNG

**Presentation visual (16:9):** `"Abstract visualization of data analytics, blue and purple gradient, modern corporate style, clean composition with space for text"` — common themes: "abstract technology", "business collaboration", "minimalist geometric patterns"

**Instagram post (1:1):** `"Lifestyle photo of coffee and laptop on wooden desk, morning light, cozy atmosphere"`

**Story/Reel (9:16):** `"Vertical product showcase of smartphone, floating in gradient background, tech aesthetic"`

---

## API Reference

See `steering/api-endpoints.md` for complete endpoint documentation.

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

**Tailored Model Generation**
| Endpoint | Purpose |
|----------|---------|
| `POST /image/generate/tailored` | Generate images using a tailored (fine-tuned) model |
| `POST /structured_prompt/generate/tailored` | Generate structured prompt JSON for tailored model (no image) |

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
> **Required:** Always include the `User-Agent: BriaSkills/<version>` header (where `<version>` is the current skill version, e.g. `BriaSkills/1.3.0`) in every API call, including status polling requests.

---

## Additional Resources

- **[API Endpoints Reference](steering/api-endpoints.md)** — Complete endpoint documentation with request/response formats for all 20+ endpoints
- **[Shell Client (bria-client-bash.sh)](steering/bria-client-bash.sh)** — Single-function helper: `bria_call` handles auth, base64, JSON, polling
- **[Full API docs for agents (llms.txt)](https://docs.bria.ai/llms.txt)** — Agent-ready Bria API reference; use when this power's summary is not enough

## Related Powers

- **vgl** — Write structured VGL JSON prompts for precise, deterministic control over FIBO image generation
- **image-utils** — Classic image manipulation (resize, crop, composite, watermarks) for post-processing

## License & Attribution

**License:** MIT

**Power Author:** Bria AI

**Original Work:** This power is converted from the [bria-skill](https://github.com/bria-ai/bria-skill) Claude Code skill by Bria AI.

**Source Version:** Based on version 1.3.0.

**Update Frequency:** This power will be updated periodically.

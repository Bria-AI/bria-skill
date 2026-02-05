# Bria AI Visual Asset Generator - Complete Guide

This guide covers all capabilities of the Bria AI skill for generating and editing visual assets.

## Table of Contents

1. [Setup](#setup)
2. [Image Generation (FIBO)](#image-generation-fibo)
3. [Image Editing](#image-editing)
4. [Text-Based Object Editing](#text-based-object-editing)
5. [Background Operations](#background-operations)
6. [Image Enhancement](#image-enhancement)
7. [Image Transformation](#image-transformation)
8. [Text & Restoration](#text--restoration)
9. [Product Photography](#product-photography)
10. [Best Practices](#best-practices)

---

## Setup

### Authentication

All Bria API requests require an API key. Set it as an environment variable:

```bash
export BRIA_API_KEY="your-api-key-here"
```

### Using the Python Client

```python
from bria_client import BriaClient

client = BriaClient()  # Uses BRIA_API_KEY env var
# or
client = BriaClient(api_key="your-key")
```

### Input Formats

Bria accepts images in two formats:
- **URL**: Publicly accessible image URL
- **Base64**: Raw base64 encoded string (for most edit endpoints) or data URL `data:image/png;base64,...` (for `/v2/image/edit`)

---

## Image Generation (FIBO)

FIBO is Bria's text-to-image model that generates high-quality, commercially-safe images.

### Basic Generation

```python
result = client.generate(
    prompt="Modern coffee shop interior, warm lighting, minimalist design",
    aspect_ratio="16:9"
)
print(result['result']['image_url'])
```

### Aspect Ratios

| Ratio | Use Case |
|-------|----------|
| `1:1` | Social media posts, product photos, icons |
| `4:3` | Presentations, documents |
| `16:9` | Hero banners, website headers, videos |
| `3:4` | Portrait photos, mobile content |
| `9:16` | Stories, reels, mobile-first content |

### Using Negative Prompts

Exclude unwanted elements:

```python
result = client.generate(
    prompt="Professional headshot, studio lighting",
    aspect_ratio="1:1",
    negative_prompt="blurry, low quality, distorted, watermark"
)
```

### Refining Generated Images

Use the `structured_prompt` from a previous generation to make modifications:

```python
# First generation
result = client.generate("Red sports car in desert")
structured_prompt = result['result']['structured_prompt']

# Refine it
refined = client.refine(
    structured_prompt=structured_prompt,
    instruction="change to blue color, add mountains in background",
    aspect_ratio="16:9"
)
```

### Inspire Mode (Image-to-Image)

Generate variations based on a reference image:

```python
result = client.inspire(
    image_url="https://example.com/reference.jpg",
    prompt="same style but with autumn colors",
    aspect_ratio="1:1"
)
```

---

## Image Editing

### Edit by Instruction (No Mask Required)

The simplest way to edit - just describe what you want to change:

```python
result = client.edit_image(
    image_url="data:image/png;base64,{base64_string}",
    instruction="change the mug color to red"
)
```

**Example instructions:**
- "make the sky more dramatic"
- "change the car to silver"
- "add sunglasses to the person"
- "make it look like winter"

### Edit with Mask (Precise Control)

For precise edits, use a mask to define the region:

```python
result = client.gen_fill(
    image_url="https://example.com/image.jpg",
    mask_url="https://example.com/mask.png",  # White = edit, Black = keep
    prompt="red leather armchair",
    mask_type="manual"
)
```

**Mask requirements:**
- Same dimensions as source image
- White pixels (255) = area to edit
- Black pixels (0) = area to preserve

### Erase Objects

Remove unwanted objects from an image:

```python
result = client.erase(
    image_url="https://example.com/image.jpg",
    mask_url="https://example.com/mask.png"  # White = area to erase
)
```

---

## Text-Based Object Editing

Edit images by describing what to add, replace, or remove - no mask required.

### Add Object

Add new objects to an image using natural language:

```python
result = client.add_object(
    image_url="https://example.com/room.jpg",
    instruction="Place a red vase with flowers on the table"
)
```

**Example instructions:**
- "Add a laptop on the desk"
- "Place a cat sleeping on the couch"
- "Add a plant in the corner"

### Replace Object

Replace existing objects with new ones:

```python
result = client.replace_object(
    image_url="https://example.com/fruit.jpg",
    instruction="Replace the red apple with a green pear"
)
```

**Example instructions:**
- "Replace the wooden chair with a modern office chair"
- "Change the coffee mug to a wine glass"
- "Replace the landscape painting with abstract art"

### Erase Object by Name

Remove specific objects without needing a mask:

```python
result = client.erase_object(
    image_url="https://example.com/scene.jpg",
    object_name="table"
)
```

**Common removals:**
- "person", "car", "text", "watermark"
- "shadow", "reflection"
- Specific objects: "lamp", "chair", "tree"

---

## Background Operations

### Remove Background (RMBG-2.0)

Extract subjects with transparent backgrounds:

```python
result = client.remove_background("https://example.com/product.jpg")
# Returns PNG with transparency
```

**Use cases:**
- Product cutouts for e-commerce
- Logo extraction
- Creating stickers/overlays
- Compositing subjects into new scenes

### Replace Background

Replace the background with AI-generated content:

```python
result = client.replace_background(
    image_url="https://example.com/portrait.jpg",
    prompt="professional office environment, soft lighting"
)
```

### Blur Background

Apply a blur effect to the background (portrait mode):

```python
result = client.blur_background("https://example.com/photo.jpg")
```

### Erase Foreground

Remove the main subject and fill with background:

```python
result = client.erase_foreground("https://example.com/image.jpg")
```

---

## Image Enhancement

### Expand Image (Outpainting)

Extend image boundaries to a new aspect ratio:

```python
# Convert a 1:1 image to 16:9 banner
result = client.expand_image(
    image_url=base64_string,
    aspect_ratio="16:9",
    prompt="continue the scene with similar style"
)
```

**Common workflows:**
- Square product photo → 16:9 hero banner
- Portrait → landscape for presentations
- Add space for text overlays

### Enhance Quality

Improve lighting, colors, and details:

```python
result = client.enhance_image(base64_string)
```

### Increase Resolution (Upscale)

Upscale images 2x or 4x:

```python
result = client.increase_resolution(
    image_url=base64_string,
    scale=2  # or 4
)
```

---

## Image Transformation

Transform the style, lighting, season, or composition of images.

### Blend Images

Merge images or apply textures/overlays:

```python
result = client.blend_images(
    image_url="https://example.com/tshirt.jpg",
    overlay_url="https://example.com/design.png",
    instruction="Place the art on the shirt, keep the art exactly the same"
)
```

**Use cases:**
- Apply logos or designs to products
- Add textures to surfaces
- Composite multiple images together

### Change Season (Reseason)

Transform the season or weather atmosphere:

```python
result = client.reseason(
    image_url="https://example.com/landscape.jpg",
    season="winter"  # spring, summer, autumn, winter
)
```

**Seasons:** `spring`, `summer`, `autumn`, `winter`

### Change Style (Restyle)

Transform the artistic style of an image:

```python
result = client.restyle(
    image_url="https://example.com/photo.jpg",
    style="oil_painting"
)
```

**Available styles:**
- `render_3d` - 3D rendered look
- `oil_painting` - Classic oil painting
- `anime` - Anime/manga style
- `cartoon` - Cartoon illustration
- `coloring_book` - Line art for coloring
- `retro_ad` - Vintage advertisement
- `pop_art_halftone` - Pop art with halftone dots
- `vector_art` - Flat vector graphics
- `story_board` - Storyboard sketch
- `art_nouveau` - Art nouveau style
- `cross_etching` - Cross-hatched etching
- `wood_cut` - Woodcut print
- `cubism` - Cubist art style

### Change Lighting (Relight)

Modify the lighting setup of an image:

```python
result = client.relight(
    image_url="https://example.com/portrait.jpg",
    light_type="spotlight on subject, keep background settings"
)
```

**Lighting descriptions:**
- "golden hour warm lighting"
- "dramatic spotlight from above"
- "soft diffused studio lighting"
- "neon blue and pink rim lighting"

---

## Text & Restoration

Work with text in images and restore old photos.

### Replace Text

Replace existing text in images with new text:

```python
result = client.replace_text(
    image_url="https://example.com/sign.jpg",
    new_text="SALE 50% OFF"
)
```

**Use cases:**
- Update signage in photos
- Localize marketing materials
- Change product labels

### Sketch to Image

Convert sketches or line drawings to photorealistic images:

```python
result = client.sketch_to_image(
    image_url="https://example.com/sketch.png",
    prompt="modern living room interior, natural lighting"
)
```

**Tips:**
- Clear, well-defined sketches work best
- Use prompt to guide style and details
- Great for architectural concepts, product designs

### Restore Old Photos

Repair damaged, noisy, or blurry photos:

```python
result = client.restore_image("https://example.com/old-photo.jpg")
```

**Fixes:**
- Scratches and tears
- Noise and grain
- Blur and degradation
- Fading and discoloration

### Colorize

Add color to black & white photos or convert to B&W:

```python
# Colorize B&W photo
result = client.colorize(
    image_url="https://example.com/bw-photo.jpg",
    style="color_contemporary"  # Modern color palette
)

# Convert to B&W
result = client.colorize(
    image_url="https://example.com/color-photo.jpg",
    style="bw"
)
```

**Styles:** `color_contemporary`, `bw`

---

## Product Photography

### Lifestyle Shot by Text

Place a product in a scene using text description:

```python
# First, remove background from product
product = client.remove_background("https://example.com/product.jpg")
product_url = product['result']['image_url']

# Then place in lifestyle scene
result = client.lifestyle_shot(
    image_url=product_url,
    prompt="modern kitchen countertop, morning sunlight, minimalist style",
    placement_type="automatic"
)
```

**Example prompts:**
- "wooden desk in home office, natural lighting"
- "marble bathroom vanity, luxury spa atmosphere"
- "outdoor picnic setting, summer day"
- "gym environment, energetic atmosphere"

### Shot by Reference Image

Place a product using a reference background:

```python
result = client.shot_by_image(
    image_url=product_url,
    background_url="https://example.com/background.jpg",
    placement_type="automatic"
)
```

---

## Best Practices

### Prompt Engineering

**Be specific about style:**
```
Good: "professional product photo, white studio background, soft shadows"
Bad:  "product photo"
```

**Include technical details:**
- Lighting: "soft natural light", "dramatic studio lighting", "golden hour"
- Composition: "centered", "rule of thirds", "negative space on left"
- Style: "minimalist", "luxurious", "rustic", "modern"

**Quality keywords:**
- "high quality", "professional", "commercial grade"
- "sharp focus", "detailed", "4K"
- "award-winning photography" (for realistic photos)

### Workflow Examples

#### Website Hero Image
```python
# Generate hero banner
hero = client.generate(
    prompt="Modern tech startup office, diverse team collaborating, bright natural light, clean aesthetic",
    aspect_ratio="16:9",
    negative_prompt="cluttered, dark, low quality"
)
```

#### E-commerce Product
```python
# 1. Generate product photo
product = client.generate(
    prompt="Professional product photo of wireless headphones, white studio background",
    aspect_ratio="1:1"
)

# 2. Remove background for flexibility
transparent = client.remove_background(product['result']['image_url'])

# 3. Create lifestyle shot
lifestyle = client.lifestyle_shot(
    image_url=transparent['result']['image_url'],
    prompt="modern desk setup, morning coffee, work from home aesthetic"
)
```

#### Social Media Content
```python
# Instagram post (1:1)
post = client.generate(
    prompt="Flat lay coffee and notebook, cozy morning vibes",
    aspect_ratio="1:1"
)

# Story/Reel (9:16)
story = client.generate(
    prompt="Vertical product showcase, floating smartphone, gradient background",
    aspect_ratio="9:16"
)
```

#### Image Transformation Pipeline
```python
# Start with any image
original_url = "https://example.com/photo.jpg"

# 1. Enhance quality
enhanced = client.enhance_image(base64_encoded_image)

# 2. Expand to banner format
expanded = client.expand_image(
    enhanced['result']['image_url'],
    aspect_ratio="16:9"
)

# 3. Upscale for print
final = client.increase_resolution(
    expanded['result']['image_url'],
    scale=2
)
```

### Handling Async Responses

All Bria endpoints return async responses. The Python client handles polling automatically when `wait=True` (default).

For manual handling:
```python
result = client.generate("...", wait=False)
status_url = result['status_url']

# Poll manually
import requests, time
while True:
    status = requests.get(status_url, headers={"api_token": API_KEY}).json()
    if status['status'] == 'COMPLETED':
        image_url = status['result']['image_url']
        break
    elif status['status'] == 'FAILED':
        raise Exception(status.get('error'))
    time.sleep(2)
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| 401 | Invalid API key | Check BRIA_API_KEY |
| 422 | Invalid parameters | Check required fields and formats |
| 422 | Content moderation | Modify prompt to avoid prohibited content |
| 460 | Failed to download | Use base64 instead of URL |
| 429 | Rate limited | Add delays between requests |

---

## Quick Reference

### Generation
| Task | Method | Key Parameters |
|------|--------|----------------|
| Generate image | `generate()` | prompt, aspect_ratio |
| Refine generation | `refine()` | structured_prompt, instruction |
| Image variation | `inspire()` | image_url, prompt |

### Edit by Text (No Mask)
| Task | Method | Key Parameters |
|------|--------|----------------|
| Edit by instruction | `edit_image()` | image_url, instruction |
| Add object | `add_object()` | image_url, instruction |
| Replace object | `replace_object()` | image_url, instruction |
| Erase object by name | `erase_object()` | image_url, object_name |

### Edit with Mask
| Task | Method | Key Parameters |
|------|--------|----------------|
| Generative fill | `gen_fill()` | image, mask, prompt |
| Erase region | `erase()` | image_url, mask_url |

### Background Operations
| Task | Method | Key Parameters |
|------|--------|----------------|
| Remove background | `remove_background()` | image_url |
| Replace background | `replace_background()` | image_url, prompt |
| Blur background | `blur_background()` | image_url |
| Erase foreground | `erase_foreground()` | image_url |
| Crop foreground | `crop_foreground()` | image_url |

### Image Transformation
| Task | Method | Key Parameters |
|------|--------|----------------|
| Expand/outpaint | `expand_image()` | image_url, aspect_ratio |
| Enhance quality | `enhance_image()` | image_url |
| Upscale resolution | `increase_resolution()` | image_url, scale |
| Blend images | `blend_images()` | image_url, overlay_url, instruction |
| Change season | `reseason()` | image_url, season |
| Change style | `restyle()` | image_url, style |
| Change lighting | `relight()` | image_url, light_type |

### Text & Restoration
| Task | Method | Key Parameters |
|------|--------|----------------|
| Replace text | `replace_text()` | image_url, new_text |
| Sketch to image | `sketch_to_image()` | image_url, prompt |
| Restore photo | `restore_image()` | image_url |
| Colorize | `colorize()` | image_url, style |

### Product Photography
| Task | Method | Key Parameters |
|------|--------|----------------|
| Lifestyle shot | `lifestyle_shot()` | image_url, prompt |
| Shot by reference | `shot_by_image()` | image_url, background_url |

### Utilities
| Task | Method | Key Parameters |
|------|--------|----------------|
| Get JSON instruction | `generate_structured_instruction()` | image_url, instruction |

---

## Support

- **API Documentation**: https://docs.bria.ai/
- **API Reference**: See `api-endpoints.md`
- **Python Client**: See `code-examples/bria_client.py`

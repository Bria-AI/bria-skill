---
name: "image-utils"
displayName: "Image Utilities"
description: "Classic image manipulation with Python Pillow — resize, crop, composite, format conversion, watermarks, brightness/contrast adjustments, and web optimization. Works standalone or alongside bria-ai for post-processing."
keywords: ["image-utils", "pillow", "resize", "crop", "watermark", "image-processing", "web-optimization"]
author: "Bria AI"
---

# Image Utilities

Pillow-based utilities for deterministic pixel-level image operations. Use for resize, crop, composite, format conversion, watermarks, and other standard image processing tasks.

## When to Use This Power

- **Post-processing AI-generated images**: Resize, crop, optimize for web after generation
- **Format conversion**: PNG ↔ JPEG ↔ WEBP with quality control
- **Compositing**: Overlay images, paste subjects onto backgrounds
- **Batch processing**: Resize to multiple sizes, add watermarks
- **Web optimization**: Compress and resize for fast delivery
- **Social media preparation**: Crop to platform-specific aspect ratios

## Quick Reference

| Operation | Method | Description |
|-----------|--------|-------------|
| **Loading** | `load(source)` | Load from URL, path, bytes, or base64 |
| | `load_from_url(url)` | Download image from URL |
| **Saving** | `save(image, path)` | Save with format auto-detection |
| | `to_bytes(image, format)` | Convert to bytes |
| | `to_base64(image, format)` | Convert to base64 string |
| **Resizing** | `resize(image, width, height)` | Resize to exact dimensions |
| | `scale(image, factor)` | Scale by factor (0.5 = half) |
| | `thumbnail(image, size)` | Fit within size, maintain aspect |
| **Cropping** | `crop(image, left, top, right, bottom)` | Crop to region |
| | `crop_center(image, width, height)` | Crop from center |
| | `crop_to_aspect(image, ratio)` | Crop to aspect ratio |
| **Compositing** | `paste(bg, fg, position)` | Overlay at coordinates |
| | `composite(bg, fg, mask)` | Alpha composite |
| | `fit_to_canvas(image, w, h)` | Fit onto canvas size |
| **Borders** | `add_border(image, width, color)` | Add solid border |
| | `add_padding(image, padding)` | Add whitespace padding |
| **Transforms** | `rotate(image, angle)` | Rotate by degrees |
| | `flip_horizontal(image)` | Mirror horizontally |
| | `flip_vertical(image)` | Flip vertically |
| **Watermarks** | `add_text_watermark(image, text)` | Add text overlay |
| | `add_image_watermark(image, logo)` | Add logo watermark |
| **Adjustments** | `adjust_brightness(image, factor)` | Lighten/darken |
| | `adjust_contrast(image, factor)` | Adjust contrast |
| | `adjust_saturation(image, factor)` | Adjust color saturation |
| | `blur(image, radius)` | Apply Gaussian blur |
| **Web** | `optimize_for_web(image, max_size)` | Optimize for delivery |
| **Info** | `get_info(image)` | Get dimensions, format, mode |

## Requirements

```bash
pip install Pillow requests
```

## Basic Usage

```python
from image_utils import ImageUtils

# Load from URL
image = ImageUtils.load_from_url("https://example.com/image.jpg")

# Or load from various sources
image = ImageUtils.load("/path/to/image.png")         # File path
image = ImageUtils.load(image_bytes)                  # Bytes
image = ImageUtils.load("data:image/png;base64,...")  # Base64

# Resize and save
resized = ImageUtils.resize(image, width=800, height=600)
ImageUtils.save(resized, "output.webp", quality=90)

# Get image info
info = ImageUtils.get_info(image)
print(f"{info['width']}x{info['height']} {info['mode']}")
```

## Resizing & Scaling

```python
# Resize to exact dimensions
resized = ImageUtils.resize(image, width=800, height=600)

# Resize maintaining aspect ratio (fit within bounds)
fitted = ImageUtils.resize(image, width=800, height=600, maintain_aspect=True)

# Resize by width only (height auto-calculated)
resized = ImageUtils.resize(image, width=800)

# Scale by factor
half = ImageUtils.scale(image, 0.5)    # 50% size
double = ImageUtils.scale(image, 2.0)  # 200% size

# Create thumbnail
thumb = ImageUtils.thumbnail(image, (150, 150))
```

## Cropping

```python
# Crop to specific region
cropped = ImageUtils.crop(image, left=100, top=50, right=500, bottom=350)

# Crop from center
center = ImageUtils.crop_center(image, width=400, height=400)

# Crop to aspect ratio (for social media)
square = ImageUtils.crop_to_aspect(image, "1:1")      # Instagram
wide = ImageUtils.crop_to_aspect(image, "16:9")       # YouTube thumbnail
story = ImageUtils.crop_to_aspect(image, "9:16")      # Stories/Reels

# Control crop anchor
top_crop = ImageUtils.crop_to_aspect(image, "16:9", anchor="top")
bottom_crop = ImageUtils.crop_to_aspect(image, "16:9", anchor="bottom")
```

## Compositing

```python
# Paste foreground onto background
result = ImageUtils.paste(background, foreground, position=(100, 50))

# Alpha composite (foreground must have transparency)
result = ImageUtils.composite(background, foreground)

# Fit image onto canvas with letterboxing
canvas = ImageUtils.fit_to_canvas(
    image, width=1200, height=800,
    background_color=(255, 255, 255, 255),
    position="center"
)
```

## Format Conversion

```python
# Convert to different formats
png_bytes = ImageUtils.to_bytes(image, "PNG")
jpeg_bytes = ImageUtils.to_bytes(image, "JPEG", quality=85)
webp_bytes = ImageUtils.to_bytes(image, "WEBP", quality=90)

# Get base64 for data URLs
base64_str = ImageUtils.to_base64(image, "PNG")
data_url = ImageUtils.to_base64(image, "PNG", include_data_url=True)

# Save with format auto-detected from extension
ImageUtils.save(image, "output.png")
ImageUtils.save(image, "output.jpg", quality=85)
ImageUtils.save(image, "output.webp", quality=90)
```

## Watermarks

```python
# Text watermark
watermarked = ImageUtils.add_text_watermark(
    image, text="© 2024 My Company",
    position="bottom-right", font_size=24,
    color=(255, 255, 255, 128), margin=20
)

# Logo/image watermark
logo = ImageUtils.load("logo.png")
watermarked = ImageUtils.add_image_watermark(
    image, watermark=logo,
    position="bottom-right", opacity=0.5, scale=0.15, margin=20
)
```

## Adjustments

```python
bright = ImageUtils.adjust_brightness(image, 1.3)
dark = ImageUtils.adjust_brightness(image, 0.7)
high_contrast = ImageUtils.adjust_contrast(image, 1.5)
vivid = ImageUtils.adjust_saturation(image, 1.3)
grayscale = ImageUtils.adjust_saturation(image, 0)
sharp = ImageUtils.adjust_sharpness(image, 2.0)
blurred = ImageUtils.blur(image, radius=5)
```

## Transforms

```python
rotated = ImageUtils.rotate(image, 45)
rotated = ImageUtils.rotate(image, 90, expand=False)
mirrored = ImageUtils.flip_horizontal(image)
flipped = ImageUtils.flip_vertical(image)
```

## Borders & Padding

```python
bordered = ImageUtils.add_border(image, width=5, color=(0, 0, 0))
padded = ImageUtils.add_padding(image, padding=20)
padded = ImageUtils.add_padding(image, padding=(10, 20, 10, 20))
```

## Web Optimization

```python
optimized_bytes = ImageUtils.optimize_for_web(
    image, max_dimension=1920, format="WEBP", quality=85
)
with open("optimized.webp", "wb") as f:
    f.write(optimized_bytes)
```

## Integration with AI Image Generation

```python
from bria_client import BriaClient
from image_utils import ImageUtils

client = BriaClient()
result = client.generate("product photo of headphones", aspect_ratio="1:1")
image = ImageUtils.load_from_url(result['result']['image_url'])

sizes = {
    "large": ImageUtils.resize(image, width=1200),
    "medium": ImageUtils.resize(image, width=600),
    "thumb": ImageUtils.thumbnail(image, (150, 150))
}
for name, img in sizes.items():
    ImageUtils.save(img, f"product_{name}.webp", quality=85)
```

## Available Steering Files

- **image-utils-python** — Complete Python implementation with all methods and docstrings

## Related Powers

- **bria-ai** — AI image generation and editing API
- **vgl** — Structured VGL JSON prompts for precise image generation control

## License & Attribution

**License:** MIT

**Power Author:** Bria AI

**Original Work:** This power is converted from the [bria-skill](https://github.com/bria-ai/bria-skill) Claude Code skill by Bria AI.

**Source Version:** Based on version 1.2.7.

**Update Frequency:** This power will be updated periodically.
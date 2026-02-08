# Bria AI Skills for Claude Code

Official Claude Code skills for [Bria AI](https://bria.ai) visual asset generation and image processing utilities.

## Skills Included

| Skill | Description |
|-------|-------------|
| **[bria-ai](./skills/bria-ai/SKILL.md)** | AI-powered image generation and editing using Bria.ai APIs |
| **[vgl](./skills/vgl/SKILL.md)** | Write structured VGL prompts for precise, deterministic image generation |
| **[image-utils](./skills/image-utils/SKILL.md)** | Classic image manipulation (resize, crop, composite, watermarks) |

## Installation

### Via npx (Recommended)

```bash
npx bria-skills
```

This downloads and installs all skills to `~/.claude/skills/bria-skills/`.

To uninstall:

```bash
npx bria-skills uninstall
```

### From GitHub

```bash
claude /install gh:bria-ai/bria-skills
```

### Install Individual Skills

After adding the marketplace, install specific skills:

```bash
claude /install bria-ai      # Image generation & editing
claude /install vgl          # VGL structured prompts
claude /install image-utils  # Classic image utilities
```

### For Organizations

Share with your team by:
1. Fork/clone this repo to your org's GitHub
2. Team members install via: `claude /install gh:your-org/bria-skills`

Or upload directly to Claude for Organizations console.

## When to Use

- **Website/App Development**: Hero images, product photos, backgrounds, illustrations
- **Presentations**: Slide visuals, diagrams, icons, cover images
- **Documents**: Report graphics, infographics, headers, decorative elements
- **Marketing**: Social media assets, banners, promotional images
- **E-commerce**: Product photography, lifestyle shots, catalog images

## Core Capabilities

| Capability | Model | Use Case |
|------------|-------|----------|
| **Create new images** | FIBO Generate | Hero images, product shots, illustrations |
| **Edit by text** | FIBO-Edit | Change colors, modify objects, transform scenes |
| **Edit with mask** | GenFill/Erase | Precise inpainting, add/replace specific regions |
| **Add/Replace/Remove objects** | Text-based editing | Add vase, replace apple with pear, remove table |
| **Transparent backgrounds** | RMBG-2.0 | Extract subjects for overlays, logos, cutouts |
| **Background operations** | Replace/Blur/Erase | Change, blur, or remove backgrounds |
| **Expand images** | Outpainting | Extend boundaries, change aspect ratios |
| **Upscale images** | Super Resolution | Increase resolution 2x or 4x |
| **Enhance quality** | Enhancement | Improve lighting, colors, details |
| **Transform style** | Restyle | Oil painting, anime, cartoon, 3D render |
| **Change lighting** | Relight | Golden hour, spotlight, dramatic lighting |
| **Change season** | Reseason | Spring, summer, autumn, winter |
| **Blend/composite** | Image Blending | Apply textures, logos, merge images |
| **Text replacement** | Rewrite | Change text in images |
| **Restore photos** | Restoration | Fix old/damaged photos |
| **Colorize** | Colorization | Add color to B&W, or convert to B&W |
| **Sketch to photo** | Sketch2Image | Convert drawings to realistic photos |
| **Product photography** | Lifestyle Shot | Place products in scenes |

## API Endpoints

### Image Generation
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/generate` | Generate images from text (FIBO) |

### Edit by Text (No Mask Required)
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit` | Edit image with natural language instruction |
| `POST /v2/image/edit/add_object_by_text` | Add objects to image |
| `POST /v2/image/edit/replace_object_by_text` | Replace objects in image |
| `POST /v2/image/edit/erase_by_text` | Remove objects by name |

### Edit with Mask
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/gen_fill` | Inpaint/generate in masked region |
| `POST /v2/image/edit/erase` | Erase masked region |

### Background Operations
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/remove_background` | Remove background (RMBG-2.0) |
| `POST /v2/image/edit/replace_background` | Replace with AI-generated background |
| `POST /v2/image/edit/blur_background` | Apply blur to background |
| `POST /v2/image/edit/erase_foreground` | Remove foreground, fill background |
| `POST /v2/image/edit/crop_foreground` | Crop tightly around subject |

### Image Transformation
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/expand` | Outpaint to new aspect ratio |
| `POST /v2/image/edit/enhance` | Enhance quality and details |
| `POST /v2/image/edit/increase_resolution` | Upscale 2x or 4x |
| `POST /v2/image/edit/blend` | Blend/merge images or textures |
| `POST /v2/image/edit/reseason` | Change season/weather |
| `POST /v2/image/edit/restyle` | Transform artistic style |
| `POST /v2/image/edit/relight` | Modify lighting |

### Text & Restoration
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/replace_text` | Replace text in image |
| `POST /v2/image/edit/sketch_to_image` | Convert sketch to photo |
| `POST /v2/image/edit/restore` | Restore old/damaged photos |
| `POST /v2/image/edit/colorize` | Colorize B&W or convert to B&W |

### Product Photography
| Endpoint | Purpose |
|----------|---------|
| `POST /v2/image/edit/lifestyle_shot_by_text` | Place product in scene by text |
| `POST /v2/image/edit/shot_by_image` | Place product on reference background |

## Restyle Options

Transform images into different artistic styles:

| Style ID | Description |
|----------|-------------|
| `render_3d` | 3D rendered look |
| `oil_painting` | Classic oil painting |
| `anime` | Anime/manga style |
| `cartoon` | Cartoon illustration |
| `coloring_book` | Line art for coloring |
| `retro_ad` | Vintage advertisement |
| `pop_art_halftone` | Pop art with halftone dots |
| `vector_art` | Flat vector graphics |
| `story_board` | Storyboard sketch |
| `art_nouveau` | Art nouveau style |
| `cross_etching` | Cross-hatched etching |
| `wood_cut` | Woodcut print |
| `cubism` | Cubist art style |

## Aspect Ratios

| Ratio | Use Case |
|-------|----------|
| `1:1` | Social media posts, product photos, icons |
| `4:3` | Presentations, documents |
| `16:9` | Hero banners, website headers, videos |
| `3:4` | Portrait photos, mobile content |
| `9:16` | Stories, reels, mobile-first content |

## Documentation

### Bria AI
- [Skill Reference](./skills/bria-ai/SKILL.md)
- [Complete Guide](./skills/bria-ai/references/guide.md)
- [API Endpoints](./skills/bria-ai/references/api-endpoints.md)
- [Python Client](./skills/bria-ai/references/code-examples/bria_client.py)
- [TypeScript Client](./skills/bria-ai/references/code-examples/bria_client.ts)
- [curl/Bash Client](./skills/bria-ai/references/code-examples/bria_client.sh)

### VGL (Visual Generation Language)
- [Skill Reference](./skills/vgl/SKILL.md)
- [Schema Reference](./skills/vgl/references/schema-reference.md)

### Image Utils
- [Skill Reference](./skills/image-utils/SKILL.md)
- [Python Module](./skills/image-utils/references/code-examples/image_utils.py)

## Requirements

### Bria AI
- Bria API key (set as `BRIA_API_KEY` environment variable)
- Get your API key at [https://bria.ai](https://bria.ai)

### Image Utils
```bash
pip install Pillow requests
```

## License

MIT

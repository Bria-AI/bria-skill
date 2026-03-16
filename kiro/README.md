# Bria AI Powers — Controllable Image Generation for Kiro

Generate, edit, and precisely control images directly from [Kiro](https://kiro.dev) using [Bria.ai](https://bria.ai)'s commercially-safe models. Unlike black-box generators, Bria gives you fine-grained control: edit specific objects, mask regions, control lighting/season/style independently, and chain operations in pipelines.

**Works with:** Kiro IDE

## Quick Start

### 1. Install

Open the Kiro Powers panel, click "Add Custom Power" → "Local Directory", and add each power directory:

- `powers/bria-ai`
- `powers/vgl`
- `powers/image-utils`

### 2. Get a free API key

Sign up at [platform.bria.ai](https://platform.bria.ai/console/account/api-keys) and create an API key.

### 3. Set the key

```bash
export BRIA_API_KEY="your-key-here"
```

Or just start using the power — it will walk you through setup automatically.

### 4. Use it

Ask Kiro to generate images, remove backgrounds, edit photos, and more. The power handles the rest.

## Powers Included

| Power | Description |
|-------|-------------|
| **[bria-ai](./bria-ai/POWER.md)** | Controllable image generation & editing — 18+ capabilities including text-to-image, object-level editing, background removal, upscaling, restyling, relighting, and product photography |
| **[vgl](./vgl/POWER.md)** | Maximum generation control — structured JSON (Visual Generation Language) that explicitly defines objects, lighting, camera, composition, and style for deterministic, reproducible results |
| **[image-utils](./image-utils/POWER.md)** | Classic image manipulation — resize, crop, composite, watermarks, format conversion with Python Pillow |

## What You Can Control

| Capability | Control Level | Example |
|------------|---------------|---------|
| **Generate images from text** | Prompt + aspect ratio + VGL structured JSON | "A modern office with natural lighting, 16:9" |
| **Edit specific objects** | Object-level — add, replace, or remove by name | "Replace the red mug with a blue one" |
| **Edit by instruction** | Image-level — natural language control | "Change the mug color to red" |
| **Edit masked regions** | Pixel-level — paint exactly where to change | Inpaint only the sky, leave everything else |
| **Remove backgrounds** | Automatic — clean transparent PNGs | One API call, no manual masking |
| **Control lighting** | Independent — change light without touching content | Golden hour, spotlight, dramatic shadows |
| **Control style** | Independent — restyle without changing structure | Oil painting, anime, cartoon, 3D render |
| **Control season** | Independent — change season/weather only | Spring blossoms, winter snow |
| **Expand images** | Directional — extend boundaries with context | Outpaint to 16:9 from a square |
| **Product photography** | Scene control — place products in any setting | "Modern kitchen countertop, morning light" |
| **Upscale resolution** | 2x or 4x — preserves details | Super resolution enhancement |
| **Pipeline chaining** | Multi-step — compose operations in sequence | Generate -> remove BG -> lifestyle shot |

## Example Use Cases

**Building a website?** Ask: "Generate a hero image for a SaaS landing page, 16:9, modern and clean"

**E-commerce catalog?** Ask: "Remove the background from this product photo and place it in a kitchen scene"

**Batch assets?** Ask: "Generate product photos for these 5 items and create transparent PNGs for each"

**Presentations?** Ask: "Create a slide visual showing data analytics, blue gradient, corporate style"

## Requirements

- **Bria API key** — Free at [platform.bria.ai](https://platform.bria.ai/console/account/api-keys)
- **For image-utils:** `pip install Pillow requests`

## Documentation

- [bria-ai POWER.md](./bria-ai/POWER.md) — Core power with all capabilities
- [API Endpoints Reference](./bria-ai/steering/api-endpoints.md) — Complete API documentation
- [Workflows & Pipelines](./bria-ai/steering/workflows.md) — Batch generation, parallel pipelines, integration examples
- [VGL Schema Reference](./vgl/steering/schema-reference.md) — Full VGL JSON schema
- [Python Client](./bria-ai/steering/bria-client-python.py) — Full-featured async client
- [TypeScript Client](./bria-ai/steering/bria-client-typescript.ts) — Typed Node.js client

## License

MIT
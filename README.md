# Bria AI Skills — Controllable Image Generation for Coding Agents

Generate, edit, and precisely control images directly from your AI coding agent using [Bria.ai](https://bria.ai)'s commercially-safe models. Unlike black-box generators, Bria gives you fine-grained control: edit specific objects, mask regions, control lighting/season/style independently, and chain operations in pipelines.

**Works with:** Claude Code, Cursor, Cline, Codex, and [37+ other agents](https://skills.sh)

## Quick Start

### 1. Install

```bash
npx skills add bria-ai/bria-skill
```

### 2. Get a free API key

Sign up at [platform.bria.ai](https://platform.bria.ai/console/account/api-keys?utm_source=skill&utm_campaign=bria_skills&utm_content=readme) and create an API key.

### 3. Set the key

```bash
export BRIA_API_KEY="your-key-here"
```

Or just start using the skill — it will walk you through setup automatically.

### 4. Use it

Ask your agent to generate images, remove backgrounds, edit photos, and more. The skill handles the rest.

## Skills Included

| Skill | Description |
|-------|-------------|
| **[bria-ai](./skills/bria-ai/SKILL.md)** | Controllable image generation & editing — 18+ capabilities including text-to-image, object-level editing, background removal, upscaling, restyling, relighting, and product photography |
| **[vgl](./skills/vgl/SKILL.md)** | Maximum generation control — structured JSON (Visual Generation Language) that explicitly defines objects, lighting, camera, composition, and style for deterministic, reproducible results |
| **[image-utils](./skills/image-utils/SKILL.md)** | Classic image manipulation — resize, crop, composite, watermarks, format conversion with Python Pillow |

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

## Getting Started — Try These Prompts

Copy-paste any of these into your agent to see Bria in action:

### See What Bria Can Do
> Generate a 4MP photo of a red sneaker on a wooden floor in a gym. Then show me what you can do with it — one step at a time: remove the background, replace the background with a city street scene, restyle as a retro comic book illustration, change the season to winter, and relight with golden hour. Save each result and create a simple HTML page showing every step with a label.

### Product Shot Pipeline
> I have a product image at `https://labs-assets.bria.ai/sandbox-example-inputs/pexels-the-glorious-studio-3584518-5370644.jpg`. Remove the background, place it in a modern kitchen as a lifestyle shot, and upscale to 4x resolution. Then expand it to 1:1 for Instagram, 9:16 for Stories, and 16:9 for a website hero banner. Save each step and create a simple HTML page showing the progression.

### Sketch to Business Asset
> I have a rough sketch of a brand mascot at `https://ibb.co/n8bmQHLS`. Convert it to a polished colored illustration, enhance the quality, then create versions restyled as a 3D render and as vector art. Save each version and create a simple HTML page showing each result with a label.

### Precision Edit Chain
> Generate a photo of a modern office reception area. Then make these edits one by one, showing me the result after each: add a flower arrangement on the reception desk, replace the wall art with a minimalist logo, change the lighting to warm evening, and remove the chair in the corner. Save each step and create a simple HTML page showing the image after each edit.

### Post-Production Pipeline
> Take this image `https://labs-assets.bria.ai/sandbox-example-inputs/pexels-the-glorious-studio-3584518-5370644.jpg` and run a full post-production pipeline: first enhance the quality, then upscale to 4x resolution, then expand from 1:1 to 16:9 by extending the sides. Save each step and create a simple HTML page showing before and after for each stage.

### Build a Product Pipeline in Code
> Write a Python script that takes a list of product image URLs and processes each one through a pipeline: remove the background, place it in a lifestyle scene based on a prompt I provide, and upscale to 4x. For each step, poll the status URL until complete before moving to the next. Save all outputs to a local folder organized by product.

## Alternative Installation

### Claude Code (direct)

```bash
claude mcp add bria-skills -- npx -y bria-skills
```

### Cursor

Download the skill folders to `~/.cursor/skills/`. Each skill is a folder containing a `SKILL.md` file.

### Manual (any agent)

Copy the `skills/` directory contents to your agent's skills directory.

## Requirements

- **Bria API key** — Free at [platform.bria.ai](https://platform.bria.ai/console/account/api-keys?utm_source=skill&utm_campaign=bria_skills&utm_content=readme)
- **For image-utils:** `pip install Pillow requests`

## Documentation

- [bria-ai SKILL.md](./skills/bria-ai/SKILL.md) — Core skill with all capabilities
- [API Endpoints Reference](./skills/bria-ai/references/api-endpoints.md) — Complete API documentation
- [Workflows & Pipelines](./skills/bria-ai/references/workflows.md) — Batch generation, parallel pipelines, integration examples
- [VGL Schema Reference](./skills/vgl/references/schema-reference.md) — Full VGL JSON schema
- [Python Client](./skills/bria-ai/references/code-examples/bria_client.py) — Full-featured async client
- [TypeScript Client](./skills/bria-ai/references/code-examples/bria_client.ts) — Typed Node.js client

## License

MIT

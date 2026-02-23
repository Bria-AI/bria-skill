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

## Example Use Cases

**Building a website?** Ask: "Generate a hero image for a SaaS landing page, 16:9, modern and clean"

**E-commerce catalog?** Ask: "Remove the background from this product photo and place it in a kitchen scene"

**Batch assets?** Ask: "Generate product photos for these 5 items and create transparent PNGs for each"

**Presentations?** Ask: "Create a slide visual showing data analytics, blue gradient, corporate style"

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

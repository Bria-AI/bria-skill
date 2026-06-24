# Bria AI — OpenClaw Plugin

Commercially-safe AI image generation, editing, background removal, and **video** background removal for OpenClaw / ClawHub, powered by [Bria.ai](https://bria.ai).

This is a **skill-bundle plugin**: it ships two Bria skills and an `openclaw.plugin.json` manifest. No build step, no native code.

## Skills included

| Skill | What it does |
|-------|--------------|
| **bria-ai** | Text-to-image (FIBO), instruction-based editing (FIBO-Edit), background remove/replace, product photography & lifestyle shots, upscale, restyle, relight, inpaint/outpaint — 20+ endpoints. |
| **video-remove-background** | Remove backgrounds from video → transparent / alpha-channel clips, green-screen-free matting, solid-color backgrounds. |

## Authentication

Both skills authenticate through Bria's **device-authorization flow** on first use and cache credentials in `~/.bria/credentials` — no API key needs to be set in plugin config. The skills walk the user through a one-click sign-in link.

## Install

```bash
clawhub package install @bria/bria-ai-openclaw
```

## Publishing (for maintainers)

From a GitHub-backed checkout of this directory:

```bash
# 1. Validate the package, manifest, and artifacts
clawhub package validate ./bria-ai-openclaw

# 2. Dry-run the publish
clawhub package publish ./bria-ai-openclaw --dry-run

# 3. Publish under the @bria owner (scope must match the publish owner)
clawhub package publish ./bria-ai-openclaw
```

> The package scope `@bria` must match the selected publish owner. Claim the `@bria` namespace on ClawHub first if it isn't already owned.

New releases stay out of public install surfaces until ClawHub's automated security checks and verification finish.

## Layout

```
bria-ai-openclaw/
├── openclaw.plugin.json        # plugin manifest (id, skills, configSchema)
├── package.json                # @bria/bria-ai-openclaw + openclaw.compat/build
├── README.md
├── LICENSE
└── skills/
    ├── bria-ai/                # SKILL.md + references
    └── video-remove-background/  # SKILL.md + references
```

## License

MIT © Bria AI

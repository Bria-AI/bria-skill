---
name: bria-ai
description: >
  Bria.ai image API — generate from text prompts, edit with natural language,
  remove backgrounds for transparent PNGs, and create product lifestyle shots.
  Authenticates via OAuth device flow, caches credentials in ~/.bria/credentials,
  calls 20+ endpoints. Commercially safe, royalty-free.
  Triggers on: remove background, transparent PNG, cutout, generate image, create banner,
  edit photo, product photography, upscale, restyle, inpainting, outpainting,
  lifestyle shot, background replacement, object removal, photo restoration.
license: MIT
homepage: https://bria.ai
metadata:
  author: Bria AI
  version: "1.3.0"
  openclaw:
    requires:
      env:
        - BRIA_API_KEY
      anyBins:
        - curl
      config:
        - ~/.bria/credentials
    primaryEnv: BRIA_API_KEY
    homepage: https://bria.ai
    emoji: "\U0001F5BC"

---

# Bria — AI Image Generation, Editing & Background Removal

Commercially safe, royalty-free image generation and editing through 20+ API endpoints.

For additional endpoint details, see the [Bria API reference for agents](https://docs.bria.ai/llms.txt).

## When to Use This Skill

- **Generate images** — "create an image of...", "make me a banner", "generate a hero image", "I need a product photo"
- **Edit images** — "change the background", "make it look like winter", "add a vase to the table", "remove the person"
- **Remove/replace backgrounds** — "make the background transparent", "cut out the product", "replace with a studio background"
- **Product photography** — "create a lifestyle shot", "place this product in a kitchen scene", "e-commerce packshot"
- **Enhance/transform** — "upscale this image", "make it higher resolution", "restyle as oil painting", "change the lighting"

---

## Setup — Authentication

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

- `READY` → skip to making API calls
- `CREDENTIALS_FOUND` → skip to Step 3
- `NO_CREDENTIALS` → proceed to Step 2

### Step 2: Authenticate via device flow

Source the auth helper and run `bria_auth`:

```bash
source ~/.agents/skills/bria-ai/references/code-examples/bria_auth.sh
bria_auth
```

`bria_auth` will print `SIGN_IN_URL=...` and `USER_CODE=...`. Show the user exactly this — nothing more:

> **Connect your Bria account:** [Click here to sign in]({SIGN_IN_URL})
> Your code is **{USER_CODE}** — it's already filled in.

Then wait; `bria_auth` polls automatically and prints `AUTHENTICATED` when done.

If it prints an error, the code expired — run `bria_auth` again.

**Do not proceed with any API call until authentication is confirmed.**

### Step 3: Verify billing status and resolve API key

```bash
source ~/.agents/skills/bria-ai/references/code-examples/bria_auth.sh
bria_introspect
```

Interpret output:
- `BILLING_ERROR: ...` — relay the message to the user verbatim and **stop**. Do not make any API calls.
- `TOKEN_EXPIRED` — tell the user their session expired and restart from Step 2.
- `READY` — `BRIA_API_KEY` is now cached in `~/.bria/credentials`. Proceed.

---

## Decision Tree — Which Endpoint to Use

```
Transparent PNG / cutout / remove background?
  → /v2/image/edit/remove_background

Generate image from scratch (text → image)?
  → /v2/image/generate

Edit existing image with text instruction?
  → /v2/image/edit  (use --key images)

Change / replace / blur background?
  → /v2/image/edit/replace_background  (prompt: "blur" or describe new bg)

Place product in a lifestyle scene?
  → /v1/product/lifestyle_shot_by_text

Upscale / increase resolution?
  → /v2/image/edit/increase_resolution  (scale: 2 or 4)

Anything else (restyle, relight, reseason, restore, colorize, sketch, blend, outpaint)?
  → See references/capabilities.md for the full endpoint list
```

---

## How to Call Any Endpoint

```bash
source ~/.agents/skills/bria-ai/references/code-examples/bria_client.sh

# Generate (no image input)
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
RESULT=$(bria_call /v1/product/lifestyle_shot_by_text "/path/to/product.png" '"scene_description": "modern kitchen countertop"')

echo "$RESULT"
```

**Calling convention:** `bria_call <endpoint> <image_or_empty> [--key <json_key>] [extra JSON fields...]`
- Pass a URL, local file path, or `""` for endpoints without image input
- Use `--key images` when the endpoint expects an `images` array instead of `image`
- Returns the result image URL on success, or prints an error to stderr

**Generation options:** Aspect ratios `1:1`, `16:9`, `4:3`, `9:16`, `3:4`. Resolution `1MP` (default) or `4MP` (more detail, +30s). Pass `"sync": true` for single images.

> **Advanced**: For precise control over generation, use the **vgl** skill for structured VGL JSON prompts.

---

## Common Failures

- **`bria_call` returns empty / no URL** → `BRIA_API_KEY` was not set. Run Step 3 (`bria_introspect`) to cache it.
- **Async job times out** → Some endpoints take 60–90s. If `bria_call` reports a timeout, retry once; the job may have been queued.
- **ERROR 401** → API key is stale. Delete `~/.bria/credentials` and re-authenticate from Step 2.
- **`BILLING_ERROR`** → Relay message to user verbatim, do not retry API calls.
- **Local file not found** → Pass the absolute path; `bria_client.sh` handles base64 encoding automatically.
- **`/v2/image/edit` returns wrong result** → Confirm `--key images` flag is present; this endpoint requires the images array format.

---

## Resources

- **[Capabilities & Prompt Recipes](references/capabilities.md)** — Full endpoint table, use-case recipes, and prompt engineering tips
- **[API Endpoints Reference](references/api-endpoints.md)** — Complete parameter documentation for all 20+ endpoints
- **[Shell Client (bria_client.sh)](references/code-examples/bria_client.sh)** — `bria_call` helper: auth, base64, JSON, polling
- **[Auth Helper (bria_auth.sh)](references/code-examples/bria_auth.sh)** — `bria_auth` and `bria_introspect` functions
- **[Full API docs for agents (llms.txt)](https://docs.bria.ai/llms.txt)** — Agent-ready Bria API reference

## Related Skills

- **vgl** — Structured VGL JSON prompts for precise, deterministic control over FIBO image generation
- **image-utils** — Classic image manipulation (resize, crop, composite, watermarks) for post-processing

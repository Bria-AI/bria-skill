# Image Input Handling

This is the shared image input preamble for Bria skills that accept image parameters. It handles both public URLs and local file paths transparently.

When generating a new skill that accepts image input, include this pattern in the tool's bash block.

---

## Image Input

This API accepts images as either a **public URL** or a **local file path**. The shell block in the tool section handles both automatically:
- **URLs** are passed directly to the API
- **Local files** are base64-encoded before sending

Replace `"IMAGE_URL_OR_PATH"` with the actual URL or file path the user provided.

**Rules:**
- NEVER upload images to third-party hosting services.
- NEVER pass base64 data inline in a curl `-d` argument — always use the shell payload builder shown below.

## Shell Pattern

For a single `image` parameter:

```bash
IMAGE_INPUT="IMAGE_URL_OR_PATH"
if printf '%s' "$IMAGE_INPUT" | grep -qE '^https?://'; then
  printf '{"image": "%s"}' "$IMAGE_INPUT" > /tmp/bria_payload.json
else
  printf '{"image": "' > /tmp/bria_payload.json
  base64 < "$IMAGE_INPUT" | tr -d '\n' >> /tmp/bria_payload.json
  printf '"}' >> /tmp/bria_payload.json
fi
```

For an `images` array parameter (e.g. edit-image):

```bash
IMAGE_INPUT="IMAGE_URL_OR_PATH"
if printf '%s' "$IMAGE_INPUT" | grep -qE '^https?://'; then
  printf '{"images": ["%s"], "instruction": "your instruction"}' "$IMAGE_INPUT" > /tmp/bria_payload.json
else
  printf '{"images": ["' > /tmp/bria_payload.json
  base64 < "$IMAGE_INPUT" | tr -d '\n' >> /tmp/bria_payload.json
  printf '"], "instruction": "your instruction"}' >> /tmp/bria_payload.json
fi
```

Then pass the payload to curl:

```bash
curl -s -X POST "https://engine.prod.bria-api.com/v2/..." \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.2.7" \
  -d @/tmp/bria_payload.json
```

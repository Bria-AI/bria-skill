# Image Input Handling

This is the shared image input preamble for Bria skills that accept image parameters. It handles URLs, local file paths, and chat-attached images transparently.

When generating a new skill that accepts image input, include the resolution rules and shell pattern in the tool's section.

---

## Image Input

Determine the image source before making any API call:

1. **User provided a URL** (starts with http/https) — use it directly as `IMAGE_INPUT`.
2. **User provided a file path** (e.g. `~/Downloads/photo.png`) — use that exact path as `IMAGE_INPUT`.
3. **User pasted/attached an image in the chat** — the IDE saves it to a local path visible in the conversation context (look for `<image_files>` or `<attached_files>` in the system prompt). Use that path as `IMAGE_INPUT`.
4. **Image from a previous Bria API result** — use the `result_url` or `image_url` from the prior response directly. It is already a URL.

The shell block in the tool section handles both URLs and local files automatically:
- **URLs** are passed directly to the API
- **Local files** are base64-encoded before sending

**Rules:**
- NEVER search the filesystem (`ls`, `find`, glob patterns) to locate images. The source is always in the conversation — check the user's message for a URL or path, check `<image_files>` / `<attached_files>` tags for pasted/attached images, or use the `result_url` from a prior Bria API response.
- NEVER visually inspect multiple files to find the right one.
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

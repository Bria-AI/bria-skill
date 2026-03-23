---
name: upscale
description: Upscale image resolution 2x or 4x with AI super-resolution. Increase image quality and detail. Powered by Bria, commercially-safe.
license: MIT
metadata:
  author: Bria AI
  version: "1.0.0"
  env: "int"
---

# Upscale Image — AI Super-Resolution

Increase image resolution by 2x or 4x using AI super-resolution.

## Setup — Authentication

Before making any API call, you need a valid Bria access token.

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

If the output is `READY`, skip straight to making API calls — no introspection needed.
If the output is `CREDENTIALS_FOUND`, skip to Step 3.
If the output is `NO_CREDENTIALS`, proceed to Step 2.

### Step 2: Authenticate via device authorization

Start the device authorization flow:

**2a. Request a device code:**

```bash
DEVICE_RESPONSE=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/device/authorize" \
  -H "Content-Type: application/json")
echo "$DEVICE_RESPONSE"
```

Parse the response fields:
- `device_code` — used to poll for the token (keep this, don't show to user)
- `user_code` — the code the user must enter (e.g. `BRIA-XXXX`)
- `interval` — seconds between poll attempts

**2b. Show the user a single sign-in link.** Tell them exactly this — nothing more:

> **Connect your Bria account:** [Click here to sign in](https://platform.bria.ai/device/verify?user_code={user_code})
> Your code is **{user_code}** — it's already filled in.

Do NOT show two links. Do NOT show the raw URL separately. Do NOT use `verification_uri` from the API response. Keep it to one clickable link.

**2c. Poll for the token.** After showing the user the code, immediately start polling. Try up to 60 times with the given interval (default 5 seconds):

```bash
for i in $(seq 1 60); do
  TOKEN_RESPONSE=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/token" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=$DEVICE_CODE")
  ACCESS_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$ACCESS_TOKEN" ]; then
    BRIA_ACCESS_TOKEN="$ACCESS_TOKEN"
    REFRESH_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"refresh_token" *: *"\([^"]*\)".*/\1/p')
    mkdir -p ~/.bria
    printf 'access_token=%s\nrefresh_token=%s\n' "$BRIA_ACCESS_TOKEN" "$REFRESH_TOKEN" > "$HOME/.bria/credentials"
    echo "AUTHENTICATED"
    break
  fi
  sleep 5
done
```

If the output contains `AUTHENTICATED`, proceed to Step 3. Otherwise the code expired — start over from Step 2a.

**Do not proceed with any API call until authentication is confirmed.**

### Step 3: Verify billing status and resolve API key

Introspect the bearer token to check billing status and obtain the real API key for Bria API calls:

```bash
INTROSPECT=$(curl -s -X POST "https://engine.prod.bria-api.com/v2/auth/token/introspect" \
  -d "token=$BRIA_ACCESS_TOKEN")
BILLING_STATUS=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_status" *: *"\([^"]*\)".*/\1/p')
if [ "$BILLING_STATUS" = "blocked" ]; then
  BILLING_MSG=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_message" *: *"\([^"]*\)".*/\1/p')
  echo "BILLING_ERROR: $BILLING_MSG"
fi
ACTIVE=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"active" *: *\([^,}]*\).*/\1/p' | tr -d ' ')
if [ "$ACTIVE" = "false" ]; then
  rm -f ~/.bria/credentials
  echo "TOKEN_EXPIRED"
fi
BRIA_API_KEY=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"api_token" *: *"\([^"]*\)".*/\1/p')
if [ -n "$BRIA_API_KEY" ]; then
  grep -v '^api_token=' "$HOME/.bria/credentials" > "$HOME/.bria/credentials.tmp" 2>/dev/null || true
  printf 'api_token=%s\n' "$BRIA_API_KEY" >> "$HOME/.bria/credentials.tmp"
  mv "$HOME/.bria/credentials.tmp" "$HOME/.bria/credentials"
fi
```

Interpret the output:
- If it prints `BILLING_ERROR: ...` — relay the message to the user exactly as shown and **stop**. Do not make any API calls.
- If it prints `TOKEN_EXPIRED` — the session is no longer valid. Tell the user their session expired and restart from Step 2.
- Otherwise, `BRIA_API_KEY` now contains the real API key and is cached for future calls. Proceed to the tool section below.

## Image Input

Determine the image source before making the API call:

1. **User provided a URL** (starts with http/https) — use it directly as `IMAGE_INPUT`.
2. **User provided a file path** (e.g. `~/Downloads/photo.png`) — use that exact path as `IMAGE_INPUT`.
3. **User pasted/attached an image in the chat** — the IDE saves it to a local path visible in the conversation context (look for `<image_files>` or `<attached_files>` in the system prompt). Use that path as `IMAGE_INPUT`.
4. **Image from a previous Bria API result** — use the `result_url` or `image_url` from the prior response directly. It is already a URL.

The shell block below handles both URLs and local files automatically (URLs pass through; local files are base64-encoded).

**Rules:**
- NEVER search the filesystem (`ls`, `find`, glob patterns) to locate images. The source is always in the conversation — check the user's message for a URL or path, check `<image_files>` / `<attached_files>` tags for pasted/attached images, or use the `result_url` from a prior Bria API response.
- NEVER visually inspect multiple files to find the right one.
- NEVER upload images to third-party hosting services.
- NEVER pass base64 data inline in a curl `-d` argument — always use the shell payload builder shown in the tool section.

---

## Upscale Image

```bash
IMAGE_INPUT="IMAGE_URL_OR_PATH"
if printf '%s' "$IMAGE_INPUT" | grep -qE '^https?://'; then
  printf '{"image": "%s", "scale": 2}' "$IMAGE_INPUT" > /tmp/bria_payload.json
else
  printf '{"image": "' > /tmp/bria_payload.json
  base64 < "$IMAGE_INPUT" | tr -d '\n' >> /tmp/bria_payload.json
  printf '", "scale": 2}' >> /tmp/bria_payload.json
fi

HTTP_CODE=$(curl -s -o /tmp/bria_result.json -w "%{http_code}" -X POST \
  "https://engine.prod.bria-api.com/v2/image/edit/increase_resolution" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.0.0" \
  -d @/tmp/bria_payload.json)
RESULT=$(cat /tmp/bria_result.json)
echo "HTTP_STATUS: $HTTP_CODE"
echo "$RESULT"
```

**Parameters:**
- `image` (required) — URL or local file path of the input image
- `scale` (required) — Scale factor: 2 or 4

Interpret the response based on `HTTP_STATUS`:

- **HTTP 200** — Success — parse result from JSON.
- **HTTP 401** — API key invalid or revoked. Delete ~/.bria/credentials and tell user to re-authenticate.
- **HTTP 403** — Billing or quota issue. Show the `detail` field from the JSON and include upgrade link: https://platform.bria.ai/pricing
- **HTTP 5xx** — Temporary server error. Tell user to try again in a few minutes.

**Response:** Returns JSON with `result_url` pointing to the upscaled image.

---

## See Also

- generate-image — Generate images from text
- edit-image — Edit images with natural language
- [bria-ai](../bria-ai/SKILL.md) — Full Bria AI skill (all 20+ tools)

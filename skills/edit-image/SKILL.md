---
name: edit-image
description: Edit images using natural language instructions. No mask needed. Change colors, modify objects, transform scenes. Powered by Bria FIBO-Edit, commercially-safe.
license: MIT
metadata:
  author: Bria AI
  version: "1.0.0"
  env: "int"
---

# Edit Image — Natural Language Image Editing with AI

Edit images using plain text instructions — no masks or manual selection required. Uses Bria's FIBO-Edit model.

## Setup — Authentication

Before making any API call, you need a valid Bria access token.

### Step 1: Check for existing credentials

```bash
if [ -f ~/.bria/credentials ]; then
  BRIA_ACCESS_TOKEN=$(grep '^access_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
fi
if [ -z "$BRIA_ACCESS_TOKEN" ]; then
  echo "NO_CREDENTIALS"
else
  echo "CREDENTIALS_FOUND"
fi
```

If the output is `CREDENTIALS_FOUND`, skip to Step 3.
If the output is `NO_CREDENTIALS`, proceed to Step 2.

### Step 2: Authenticate via device authorization

Start the device authorization flow:

**2a. Request a device code:**

```bash
DEVICE_RESPONSE=$(curl -s -X POST "https://engine.int.bria-api.com/v2/auth/device/authorize" \
  -H "Content-Type: application/json")
echo "$DEVICE_RESPONSE"
```

Parse the response fields:
- `device_code` — used to poll for the token (keep this, don't show to user)
- `user_code` — the code the user must enter (e.g. `BRIA-XXXX`)
- `interval` — seconds between poll attempts

**2b. Show the user a single sign-in link.** Tell them exactly this — nothing more:

> **Connect your Bria account:** [Click here to sign in](https://int.platform.bria.ai/device/verify?user_code={user_code})
> Your code is **{user_code}** — it's already filled in.

Do NOT show two links. Do NOT show the raw URL separately. Do NOT use `verification_uri` from the API response. Keep it to one clickable link.

**2c. Poll for the token.** After showing the user the code, immediately start polling. Try up to 60 times with the given interval (default 5 seconds):

```bash
for i in $(seq 1 60); do
  TOKEN_RESPONSE=$(curl -s -X POST "https://engine.int.bria-api.com/v2/auth/token" \
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
INTROSPECT=$(curl -s -X POST "https://engine.int.bria-api.com/v2/auth/token/introspect" \
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
```

Interpret the output:
- If it prints `BILLING_ERROR: ...` — relay the message to the user exactly as shown and **stop**. Do not make any API calls.
- If it prints `TOKEN_EXPIRED` — the session is no longer valid. Tell the user their session expired and restart from Step 2.
- Otherwise, `BRIA_API_KEY` now contains the real API key. Proceed to the tool section below.

## Image Input

This API accepts images as either a **public URL** or a **local file path**. The shell block in the tool section handles both automatically:
- **URLs** are passed directly to the API
- **Local files** are base64-encoded before sending

Replace `"IMAGE_URL_OR_PATH"` with the actual URL or file path the user provided.

**Rules:**
- NEVER upload images to third-party hosting services.
- NEVER pass base64 data inline in a curl `-d` argument — always use the shell payload builder shown in the tool section.

---

## Edit Image

```bash
IMAGE_INPUT="IMAGE_URL_OR_PATH"
if printf '%s' "$IMAGE_INPUT" | grep -qE '^https?://'; then
  printf '{"images": ["%s"], "instruction": "change the mug to red"}' "$IMAGE_INPUT" > /tmp/bria_payload.json
else
  printf '{"images": ["' > /tmp/bria_payload.json
  base64 < "$IMAGE_INPUT" | tr -d '\n' >> /tmp/bria_payload.json
  printf '"], "instruction": "change the mug to red"}' >> /tmp/bria_payload.json
fi

HTTP_CODE=$(curl -s -o /tmp/bria_result.json -w "%{http_code}" -X POST \
  "https://engine.prod.bria-api.com/v2/image/edit" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: BriaSkills/1.0.0" \
  -d @/tmp/bria_payload.json)
RESULT=$(cat /tmp/bria_result.json)
echo "HTTP_STATUS: $HTTP_CODE"
echo "$RESULT"
```

**Parameters:**
- `images` (required) — Array with one image URL or local file path
- `instruction` (required) — Natural language edit instruction

Interpret the response based on `HTTP_STATUS`:

- **HTTP 200** — Success — parse result from JSON.
- **HTTP 401** — API key invalid or revoked. Delete ~/.bria/credentials and tell user to re-authenticate.
- **HTTP 403** — Billing or quota issue. Show the `detail` field from the JSON and include upgrade link: https://int.platform.bria.ai/pricing
- **HTTP 5xx** — Temporary server error. Tell user to try again in a few minutes.

**Response:** Returns JSON with the edited image URL.

---

## See Also

- generate-image — Generate images from text
- remove-bg — Remove background to transparent PNG
- [bria-ai](../bria-ai/SKILL.md) — Full Bria AI skill (all 20+ tools)

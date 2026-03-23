# Authentication — Device Authorization Flow

This is the shared authentication preamble for all Bria skills. It uses the OAuth device authorization flow so users can authenticate with a single click — no manual API key setup required.

When generating a new skill, include this auth section (with URLs resolved for the target environment) before any API call sections.

**Environment URLs:**
- Auth server: `https://engine.prod.bria-api.com`
- Verification: `https://platform.bria.ai/device/verify`
- API base (for actual API calls): `https://engine.prod.bria-api.com`

---

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
- Otherwise, `BRIA_API_KEY` now contains the real API key and is cached for future calls. Proceed to the tool section.

#!/bin/bash
# bria_auth.sh — Device authorization flow and token introspection for Bria.ai.
# Source this file, then call bria_auth to authenticate, or bria_introspect to verify.
#
# Usage:
#   source <SKILL_DIR>/references/code-examples/bria_auth.sh
#   bria_auth        # runs full device flow; sets BRIA_ACCESS_TOKEN, BRIA_API_KEY
#   bria_introspect  # verifies existing token; sets BRIA_API_KEY; prints BILLING_ERROR or TOKEN_EXPIRED

BRIA_AUTH_BASE="${BRIA_AUTH_BASE:-https://engine.prod.bria-api.com}"

bria_auth() {
  # Step 2a: request device code
  DEVICE_RESPONSE=$(curl -s -X POST "${BRIA_AUTH_BASE}/v2/auth/device/authorize" \
    -H "Content-Type: application/json")
  DEVICE_CODE=$(printf '%s' "$DEVICE_RESPONSE" | sed -n 's/.*"device_code" *: *"\([^"]*\)".*/\1/p')
  USER_CODE=$(printf '%s' "$DEVICE_RESPONSE" | sed -n 's/.*"user_code" *: *"\([^"]*\)".*/\1/p')
  INTERVAL=$(printf '%s' "$DEVICE_RESPONSE" | sed -n 's/.*"interval" *: *\([0-9]*\).*/\1/p')
  INTERVAL="${INTERVAL:-5}"

  if [ -z "$DEVICE_CODE" ] || [ -z "$USER_CODE" ]; then
    echo "ERROR: Failed to get device code. Response: $DEVICE_RESPONSE" >&2
    return 1
  fi

  # Step 2b: show user the sign-in link (caller should display this)
  echo "SIGN_IN_URL=https://platform.bria.ai/device/verify?user_code=${USER_CODE}"
  echo "USER_CODE=${USER_CODE}"

  # Step 2c: poll for token
  local i=0
  while [ "$i" -lt 60 ]; do
    sleep "$INTERVAL"
    TOKEN_RESPONSE=$(curl -s -X POST "${BRIA_AUTH_BASE}/v2/auth/token" \
      -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      -d "device_code=$DEVICE_CODE")
    BRIA_ACCESS_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
    if [ -n "$BRIA_ACCESS_TOKEN" ]; then
      REFRESH_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n 's/.*"refresh_token" *: *"\([^"]*\)".*/\1/p')
      mkdir -p ~/.bria
      printf 'access_token=%s\nrefresh_token=%s\n' "$BRIA_ACCESS_TOKEN" "$REFRESH_TOKEN" > "$HOME/.bria/credentials"
      echo "AUTHENTICATED"
      bria_introspect
      return 0
    fi
    i=$((i + 1))
  done

  echo "ERROR: Authentication timed out. Code expired — run bria_auth again." >&2
  return 1
}

bria_introspect() {
  if [ -z "$BRIA_ACCESS_TOKEN" ] && [ -f "$HOME/.bria/credentials" ]; then
    BRIA_ACCESS_TOKEN=$(grep '^access_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
  fi
  [ -z "$BRIA_ACCESS_TOKEN" ] && { echo "NO_CREDENTIALS"; return 1; }

  INTROSPECT=$(curl -s -X POST "${BRIA_AUTH_BASE}/v2/auth/token/introspect" \
    -d "token=$BRIA_ACCESS_TOKEN")

  BILLING_STATUS=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_status" *: *"\([^"]*\)".*/\1/p')
  if [ "$BILLING_STATUS" = "blocked" ]; then
    BILLING_MSG=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"billing_message" *: *"\([^"]*\)".*/\1/p')
    echo "BILLING_ERROR: $BILLING_MSG"
    return 1
  fi

  ACTIVE=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"active" *: *\([^,}]*\).*/\1/p' | tr -d ' ')
  if [ "$ACTIVE" = "false" ]; then
    printf '' > "$HOME/.bria/credentials"
    echo "TOKEN_EXPIRED"
    return 1
  fi

  BRIA_API_KEY=$(printf '%s' "$INTROSPECT" | sed -n 's/.*"api_token" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$BRIA_API_KEY" ]; then
    grep -v '^api_token=' "$HOME/.bria/credentials" > "$HOME/.bria/credentials.tmp" 2>/dev/null || true
    printf 'api_token=%s\n' "$BRIA_API_KEY" >> "$HOME/.bria/credentials.tmp"
    mv "$HOME/.bria/credentials.tmp" "$HOME/.bria/credentials"
  fi
  echo "READY"
}

#!/bin/bash
# bria_client.sh — Self-contained helper for Bria API calls.
# Zero dependencies beyond curl, base64, sed (standard on macOS/Linux).
#
# Usage:
#   source bria_client.sh
#   RESULT=$(bria_call /v2/image/generate "" '"prompt":"a sunset","aspect_ratio":"16:9","sync":true')
#   RESULT=$(bria_call /v2/image/edit/remove_background "/path/to/image.png")
#   RESULT=$(bria_call /v2/image/edit/replace_background "https://example.com/img.jpg" '"prompt":"sunset beach"')
#   RESULT=$(bria_call /v2/image/edit "/path/to/image.png" --key images '"instruction":"make it red"')
#
# BRIA_API_KEY is auto-loaded from ~/.bria/credentials if not already set.

BRIA_API_BASE="${BRIA_API_BASE:-https://engine.prod.bria-api.com}"
BRIA_USER_AGENT="BriaSkills/1.2.7"

bria_call() {
  local endpoint image key extra payload result http_code body url status_url poll i
  endpoint="$1"; image="$2"; shift 2

  key="image"; extra=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --key) key="$2"; shift 2 ;;
      *) extra="${extra:+$extra, }$1"; shift ;;
    esac
  done

  if [ -z "$BRIA_API_KEY" ] && [ -f "$HOME/.bria/credentials" ]; then
    BRIA_API_KEY=$(grep '^api_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
  fi
  [ -z "$BRIA_API_KEY" ] && { echo "ERROR: BRIA_API_KEY not set. Run auth first." >&2; return 1; }

  # --- Build JSON payload to temp file (safe for large images) ---
  payload="/tmp/bria_payload_$$.json"

  if [ -z "$image" ]; then
    printf '{' > "$payload"
  elif printf '%s' "$image" | grep -qE '^https?://'; then
    if [ "$key" = "images" ]; then
      printf '{"images": ["%s"]' "$image" > "$payload"
    else
      printf '{"%s": "%s"' "$key" "$image" > "$payload"
    fi
  else
    [ ! -f "$image" ] && { echo "ERROR: File not found: $image" >&2; return 1; }
    if [ "$key" = "images" ]; then
      printf '{"images": ["' > "$payload"
    else
      printf '{"%s": "' "$key" > "$payload"
    fi
    base64 < "$image" | tr -d '\n' >> "$payload"
    if [ "$key" = "images" ]; then
      printf '"]' >> "$payload"
    else
      printf '"' >> "$payload"
    fi
  fi

  if [ -n "$extra" ]; then
    if [ -z "$image" ]; then
      printf '%s' "$extra" >> "$payload"
    else
      printf ', %s' "$extra" >> "$payload"
    fi
  fi
  printf '}' >> "$payload"

  # --- API call ---
  result="/tmp/bria_result_$$.json"
  http_code=$(curl -s -o "$result" -w '%{http_code}' -X POST \
    "${BRIA_API_BASE}${endpoint}" \
    -H "api_token: $BRIA_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: $BRIA_USER_AGENT" \
    -d @"$payload")

  body=$(cat "$result")
  rm -f "$payload" "$result"

  # --- Error handling ---
  case "$http_code" in
    401) echo "ERROR 401: API key invalid. Delete ~/.bria/credentials and re-authenticate." >&2; return 1 ;;
    403) echo "ERROR 403: Billing/quota issue. Visit https://platform.bria.ai/pricing" >&2; echo "$body" >&2; return 1 ;;
    5*) echo "ERROR $http_code: Server error. Try again shortly." >&2; return 1 ;;
  esac

  if [ "${http_code:-0}" -ge 400 ] 2>/dev/null; then
    echo "ERROR $http_code: $body" >&2; return 1
  fi

  # --- Extract result URL (sync response) ---
  url=$(printf '%s' "$body" | sed -n 's/.*"result_url" *: *"\([^"]*\)".*/\1/p')
  [ -n "$url" ] && { echo "$url"; return 0; }
  url=$(printf '%s' "$body" | sed -n 's/.*"image_url" *: *"\([^"]*\)".*/\1/p')
  [ -n "$url" ] && { echo "$url"; return 0; }

  # --- Async: poll status_url ---
  status_url=$(printf '%s' "$body" | sed -n 's/.*"status_url" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$status_url" ]; then
    i=0
    while [ "$i" -lt 30 ]; do
      sleep 3
      poll=$(curl -s "$status_url" \
        -H "api_token: $BRIA_API_KEY" \
        -H "User-Agent: $BRIA_USER_AGENT")
      if printf '%s' "$poll" | grep -qE '"status" *: *"(ERROR|FAILED)"'; then
        echo "ERROR: Job failed. Response: $poll" >&2; return 1
      fi
      url=$(printf '%s' "$poll" | sed -n 's/.*"result_url" *: *"\([^"]*\)".*/\1/p')
      [ -z "$url" ] && url=$(printf '%s' "$poll" | sed -n 's/.*"image_url" *: *"\([^"]*\)".*/\1/p')
      [ -n "$url" ] && { echo "$url"; return 0; }
      i=$((i + 1))
    done
    echo "ERROR: Polling timed out after 90 seconds" >&2
    return 1
  fi

  echo "$body"
}

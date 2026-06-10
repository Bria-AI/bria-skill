#!/bin/bash
# bria_video_client.sh — Self-contained helper for Bria video background removal.
# Zero dependencies beyond curl, grep, sed (standard on macOS/Linux).
#
# Usage:
#   source bria_video_client.sh
#   RESULT=$(bria_video_call "/path/to/clip.mp4")
#   RESULT=$(bria_video_call "https://example.com/clip.mp4")
#   RESULT=$(bria_video_call "/path/to/clip.mp4" '"background_color":"White","output_container_and_codec":"mp4_h264"')
#   FILE_URL=$(bria_video_upload "/path/to/clip.mp4")   # upload only, returns temporary URL
#
# BRIA_API_KEY is auto-loaded from ~/.bria/credentials if not already set.

BRIA_API_BASE="${BRIA_API_BASE:-https://engine.prod.bria-api.com}"
BRIA_USER_AGENT="BriaSkills/1.3.4"
BRIA_POLL_INTERVAL="${BRIA_POLL_INTERVAL:-5}"    # seconds between status polls
BRIA_POLL_ATTEMPTS="${BRIA_POLL_ATTEMPTS:-120}"  # max polls (default 120 x 5s = 10 min)

_bria_load_key() {
  if [ -z "$BRIA_API_KEY" ] && [ -f "$HOME/.bria/credentials" ]; then
    BRIA_API_KEY=$(grep '^api_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
  fi
  [ -z "$BRIA_API_KEY" ] && { echo "ERROR: BRIA_API_KEY not set. Run auth first." >&2; return 1; }
  return 0
}

# Upload a local video file via the Local Video Upload Service.
# Echoes a temporary file_url (valid 1 day) to pass as the "video" parameter.
bria_video_upload() {
  local file media_type body upload_url file_url fields pair k v http_code
  file="$1"
  [ ! -f "$file" ] && { echo "ERROR: File not found: $file" >&2; return 1; }
  _bria_load_key || return 1

  case "$file" in
    *.mp4|*.MP4)   media_type="video/mp4" ;;
    *.mov|*.MOV)   media_type="video/quicktime" ;;
    *.webm|*.WEBM) media_type="video/webm" ;;
    *.avi|*.AVI)   media_type="video/x-msvideo" ;;
    *.gif|*.GIF)   media_type="image/gif" ;;
    *)             media_type="video/" ;;
  esac

  # --- Step 1: request presigned upload URL ---
  body=$(curl -s -X POST "${BRIA_API_BASE}/v2/video/upload" \
    -H "api_token: $BRIA_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: $BRIA_USER_AGENT" \
    -d "{\"media_type\": \"$media_type\"}")

  upload_url=$(printf '%s' "$body" | sed -n 's/.*"upload_url" *: *"\([^"]*\)".*/\1/p')
  file_url=$(printf '%s' "$body" | sed -n 's/.*"file_url" *: *"\([^"]*\)".*/\1/p')
  [ -z "$upload_url" ] && { echo "ERROR: Upload URL request failed. Response: $body" >&2; return 1; }

  # --- Step 2: multipart upload — upload_fields MUST precede the file field ---
  fields=$(printf '%s' "$body" | sed -n 's/.*"upload_fields" *: *{\([^}]*\)}.*/\1/p')
  local form_args=()
  while IFS= read -r pair; do
    k=$(printf '%s' "$pair" | sed 's/^"\([^"]*\)".*/\1/')
    v=$(printf '%s' "$pair" | sed 's/^"[^"]*" *: *"\(.*\)"$/\1/')
    form_args+=(-F "$k=$v")
  done < <(printf '%s' "$fields" | grep -oE '"[^"]+" *: *"[^"]*"')

  http_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$upload_url" \
    "${form_args[@]}" \
    -F "file=@$file;type=$media_type")

  if [ "$http_code" != "204" ] && [ "$http_code" != "200" ]; then
    echo "ERROR $http_code: Video upload failed." >&2; return 1
  fi

  echo "$file_url"
}

# Remove the background from a video (local file path or public URL).
# Extra JSON fields can be appended as a second argument, e.g.:
#   bria_video_call clip.mp4 '"background_color":"Green","preserve_audio":true'
# Echoes the result video URL on success.
bria_video_call() {
  local video extra payload body http_code url status_url poll i
  video="$1"; shift
  extra="$*"

  _bria_load_key || return 1

  # --- Resolve local files via the upload service ---
  if ! printf '%s' "$video" | grep -qE '^https?://'; then
    video=$(bria_video_upload "$video") || return 1
  fi

  payload="{\"video\": \"$video\"${extra:+, $extra}}"

  # --- API call ---
  local result="/tmp/bria_video_result_$$.json"
  http_code=$(curl -s -o "$result" -w '%{http_code}' -X POST \
    "${BRIA_API_BASE}/v2/video/edit/remove_background" \
    -H "api_token: $BRIA_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: $BRIA_USER_AGENT" \
    -d "$payload")

  body=$(cat "$result")
  rm -f "$result"

  # --- Error handling ---
  case "$http_code" in
    401) echo "ERROR 401: API key invalid. Delete ~/.bria/credentials and re-authenticate." >&2; return 1 ;;
    403) echo "ERROR 403: Billing/quota issue. Visit https://platform.bria.ai/pricing" >&2; echo "$body" >&2; return 1 ;;
    413) echo "ERROR 413: Video too large (max resolution 16000x16000)." >&2; return 1 ;;
    422) echo "ERROR 422: Invalid combination — Transparent background requires an alpha-capable preset (webm_vp9, mkv_vp9, mov_proresks). Use a solid background_color for other presets. Response: $body" >&2; return 1 ;;
    5*) echo "ERROR $http_code: Server error. Try again shortly." >&2; return 1 ;;
  esac

  if [ "${http_code:-0}" -ge 400 ] 2>/dev/null; then
    echo "ERROR $http_code: $body" >&2; return 1
  fi

  # --- Async: poll status_url (video jobs take longer than image jobs) ---
  status_url=$(printf '%s' "$body" | sed -n 's/.*"status_url" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$status_url" ]; then
    i=0
    while [ "$i" -lt "$BRIA_POLL_ATTEMPTS" ]; do
      sleep "$BRIA_POLL_INTERVAL"
      poll=$(curl -s "$status_url" \
        -H "api_token: $BRIA_API_KEY" \
        -H "User-Agent: $BRIA_USER_AGENT")
      if printf '%s' "$poll" | grep -qE '"status" *: *"(ERROR|FAILED)"'; then
        echo "ERROR: Job failed. Response: $poll" >&2; return 1
      fi
      url=$(printf '%s' "$poll" | sed -n 's/.*"video_url" *: *"\([^"]*\)".*/\1/p')
      [ -z "$url" ] && url=$(printf '%s' "$poll" | sed -n 's/.*"result_url" *: *"\([^"]*\)".*/\1/p')
      [ -n "$url" ] && { echo "$url"; return 0; }
      i=$((i + 1))
    done
    echo "ERROR: Polling timed out after $((BRIA_POLL_ATTEMPTS * BRIA_POLL_INTERVAL)) seconds." >&2
    echo "The job may still complete — resume polling manually: curl -s \"$status_url\" -H \"api_token: \$BRIA_API_KEY\"" >&2
    return 1
  fi

  echo "$body"
}

#!/bin/bash
# bria_resize_client.sh — Self-contained helper for Bria Ad Resize (one flat ad → many sizes).
# Zero dependencies beyond curl, grep, sed, base64 (standard on macOS/Linux).
#
# Usage:
#   source bria_resize_client.sh
#   bria_resize "/path/to/ad.jpg" --size feed=1080x1080 --size story=1080x1920
#   bria_resize "https://example.com/ad.jpg" --size leaderboard=970x90 --prompt "keep the logo top-left"
#   bria_resize "/path/to/ad.jpg" --size feed=1080x1080 --out-dir ./my-sizes
#
#   # or the three steps on their own:
#   STATUS_URL=$(bria_resize_submit "/path/to/ad.jpg" --size feed=1080x1080)
#   RESULT_JSON=$(bria_resize_wait "$STATUS_URL")
#   bria_resize_download "$RESULT_JSON" "/path/to/ad.jpg"
#
# BRIA_API_KEY is auto-loaded from ~/.bria/credentials if not already set.

BRIA_API_BASE="${BRIA_API_BASE:-https://engine.prod.bria-api.com}"
BRIA_USER_AGENT="BriaSkills/1.4.0"
BRIA_POLL_INTERVAL="${BRIA_POLL_INTERVAL:-10}"     # seconds between status polls
BRIA_POLL_ATTEMPTS="${BRIA_POLL_ATTEMPTS:-90}"     # max polls (default 90 x 10s = 15 min; a layered size can take 7)
BRIA_RETRY_BACKOFF="${BRIA_RETRY_BACKOFF:-20 40 60}"  # rate-limit backoff schedule, in seconds

_bria_load_key() {
  if [ -z "$BRIA_API_KEY" ] && [ -f "$HOME/.bria/credentials" ]; then
    BRIA_API_KEY=$(grep '^api_token=' "$HOME/.bria/credentials" | cut -d= -f2-)
  fi
  [ -z "$BRIA_API_KEY" ] && { echo "Bria sign-in is missing. Run the skill's authentication step first." >&2; return 1; }
  return 0
}

_bria_json_str() {
  # First string value for a key, tolerating pretty or compact JSON.
  printf '%s' "$2" | grep -oE "\"$1\" *: *\"[^\"]*\"" | head -1 | sed 's/^[^:]*: *"//; s/"$//'
}

# Map an API failure onto one cause+action sentence. Raw payloads are never printed.
# Sets BRIA_RESIZE_RETRYABLE=1 when the retry-once rule applies.
_bria_report_error() {
  local code="$1" message="$2"
  BRIA_RESIZE_RETRYABLE=0
  case "$message" in
    *"Invalid URL or base64"*)
      echo "The ad reference is neither a public image URL nor an image file Bria could read. Attach the file itself, or a direct link to it." >&2; return ;;
    *"returned HTTP"*|*"could not be fetched"*)
      echo "That image URL could not be fetched — it needs to be a public, direct link to the image file. Attach the file instead." >&2; return ;;
    *"at most 10 items"*)
      echo "Ad Resize takes at most 10 sizes per call. Split the sizes across calls." >&2; return ;;
    *"at least 1 item"*)
      echo "No target sizes were given. Pass at least one --size name=WIDTHxHEIGHT." >&2; return ;;
    *"greater than 0"*)
      echo "Every target size needs a width and a height above zero." >&2; return ;;
    *"synchronously"*)
      echo "Ad Resize runs asynchronously only. This is an ad-resize skill issue; report it." >&2; return ;;
  esac
  case "$code" in
    400|422)
      echo "Bria rejected the request as invalid. Try once more; if it repeats, report it as an ad-resize skill issue." >&2 ;;
    401)
      echo "Bria sign-in is missing or invalid. Delete ~/.bria/credentials and run the authentication step again." >&2 ;;
    403)
      echo "This Bria account is not permitted to run this request — check the plan and billing status at https://platform.bria.ai/pricing" >&2 ;;
    404)
      echo "Ad Resize is not enabled for this Bria account yet. Ask Bria to enable it." >&2 ;;
    413)
      echo "The request is too large. Send the ad as a public URL instead of an attached file." >&2 ;;
    429)
      echo "Bria is rate-limiting this account. Wait a minute and try again." >&2 ;;
    5*)
      echo "Resizing failed inside Bria's pipeline." >&2; BRIA_RESIZE_RETRYABLE=1 ;;
    *)
      echo "Resizing failed (Bria returned status $code)." >&2; BRIA_RESIZE_RETRYABLE=1 ;;
  esac
}

# Turn "--size name=WxH" arguments into the JSON formats array. Echoes the array or returns 1.
_bria_formats_json() {
  local spec name dims w h out=""
  for spec in "$@"; do
    name="${spec%%=*}"; dims="${spec#*=}"
    w="${dims%%x*}"; h="${dims#*x}"
    if [ -z "$name" ] || [ "$name" = "$spec" ] || ! printf '%s' "$w" | grep -qE '^[0-9]+$' || ! printf '%s' "$h" | grep -qE '^[0-9]+$'; then
      echo "Bad size '$spec'. Use name=WIDTHxHEIGHT, for example feed=1080x1080." >&2; return 1
    fi
    name=$(printf '%s' "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    [ -n "$out" ] && out="$out, "
    out="$out{\"name\": \"$name\", \"width\": $w, \"height\": $h}"
  done
  [ -z "$out" ] && { echo "Pass at least one --size name=WIDTHxHEIGHT." >&2; return 1; }
  printf '[%s]' "$out"
}

# Submit one ad for resizing. Echoes the status_url to poll.
#   bria_resize_submit <image-path-or-url> --size name=WxH [--size ...] [--prompt "..."]
bria_resize_submit() {
  local image prompt payload_file body http_code status_url backoff formats
  local sizes=()
  image="$1"; shift
  prompt=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --size) sizes+=("$2"); shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done
  _bria_load_key || return 1
  formats=$(_bria_formats_json "${sizes[@]}") || return 1
  if ! printf '%s' "$image" | grep -qE '^https?://'; then
    [ ! -f "$image" ] && { echo "File not found: $image" >&2; return 1; }
  fi

  payload_file="/tmp/bria_resize_payload_$$.json"
  {
    printf '{"attachments": ["'
    if printf '%s' "$image" | grep -qE '^https?://'; then
      printf '%s' "$image"
    else
      base64 < "$image" | tr -d '\n\r'
    fi
    printf '"], "sync": false, "formats": %s' "$formats"
    # Escape backslashes and quotes, and flatten newlines — the prompt is free text.
    [ -n "$prompt" ] && printf ', "prompt": "%s"' "$(printf '%s' "$prompt" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '}'
  } > "$payload_file" || { rm -f "$payload_file"; return 1; }

  local response_file="/tmp/bria_resize_submit_$$.json"
  # Walked with string ops rather than `for x in $SCHEDULE`: zsh does not word-split an unquoted parameter.
  local remaining="$BRIA_RETRY_BACKOFF"
  while : ; do
    http_code=$(curl -s -o "$response_file" -w '%{http_code}' -X POST \
      "${BRIA_API_BASE}/v2/ads/resize" \
      -H "api_token: $BRIA_API_KEY" \
      -H "Content-Type: application/json" \
      -H "User-Agent: $BRIA_USER_AGENT" \
      --data-binary "@$payload_file")
    [ "$http_code" != "429" ] && break
    [ -z "$remaining" ] && break
    backoff="${remaining%% *}"
    case "$remaining" in *" "*) remaining="${remaining#* }" ;; *) remaining="" ;; esac
    echo "Bria is rate-limiting this account — waiting ${backoff}s before retrying." >&2
    sleep "$backoff"
  done
  body=$(cat "$response_file" 2>/dev/null)
  rm -f "$payload_file" "$response_file"

  if [ "${http_code:-0}" -ge 400 ] 2>/dev/null; then
    _bria_report_error "$http_code" "$(_bria_json_str details "$body")$(_bria_json_str message "$body")"
    return 1
  fi

  status_url=$(_bria_json_str status_url "$body")
  [ -n "$status_url" ] && { echo "$status_url"; return 0; }
  echo "Bria accepted the ad but returned no job to track. Try again." >&2
  return 1
}

# Poll a status_url until the run finishes. Echoes the completed status body (JSON).
# Returns 1 for a terminal failure, 2 when the caller should retry the whole job once.
bria_resize_wait() {
  local status_url poll i code message
  status_url="$1"
  _bria_load_key || return 1

  i=0
  while [ "$i" -lt "$BRIA_POLL_ATTEMPTS" ]; do
    sleep "$BRIA_POLL_INTERVAL"
    poll=$(curl -s "$status_url" -H "api_token: $BRIA_API_KEY" -H "User-Agent: $BRIA_USER_AGENT")

    if printf '%s' "$poll" | grep -qE '"status" *: *"(ERROR|FAILED)"'; then
      code=$(printf '%s' "$poll" | grep -oE '"code" *: *[0-9]+' | head -1 | sed 's/[^0-9]//g')
      message="$(_bria_json_str details "$poll")$(_bria_json_str message "$poll")"
      _bria_report_error "${code:-500}" "$message"
      [ "$BRIA_RESIZE_RETRYABLE" = "1" ] && return 2
      return 1
    fi
    if printf '%s' "$poll" | grep -qE '"status" *: *"UNKNOWN"'; then
      echo "That resize run is no longer on file — Bria keeps job status for about a day. Run it again." >&2
      return 1
    fi
    if printf '%s' "$poll" | grep -qE '"status" *: *"COMPLETED"'; then
      if printf '%s' "$poll" | grep -q '"results"'; then
        printf '%s' "$poll"; return 0
      fi
      echo "Bria reported the run complete but returned no sizes. Run it again." >&2
      return 1
    fi
    i=$((i + 1))
  done

  echo "Resizing is still running after $((BRIA_POLL_ATTEMPTS * BRIA_POLL_INTERVAL)) seconds; it may still finish." >&2
  echo "Resume checking it with: curl -s \"$status_url\" -H \"api_token: \$BRIA_API_KEY\"" >&2
  return 1
}

# Save every finished size into <input-stem>-sizes/ as <name>-<width>x<height>.png, plus result.json.
#   bria_resize_download <completed-status-json> <original-input> [output-dir]
bria_resize_download() {
  # `status` is read-only in zsh, and this file is sourced into whichever shell the agent runs.
  local result input out_dir stem fields name width height target_status url saved failed note line value
  result="$1"; input="$2"; out_dir="$3"

  stem="${input##*/}"; stem="${stem%%\?*}"; stem="${stem%.*}"
  stem=$(printf '%s' "$stem" | tr -cd 'A-Za-z0-9._-')
  [ -z "$stem" ] && stem="ad"
  [ -z "$out_dir" ] && out_dir="${stem}-sizes"
  mkdir -p "$out_dir" || return 1

  printf '%s' "$result" > "$out_dir/result.json"
  echo "saved $out_dir/result.json"

  # Each target is emitted as name, width, height, status, strategy, url, error in that order,
  # so walking the keys in document order rebuilds one target at a time.
  fields=$(printf '%s' "$result" | grep -oE '"(name|width|height|status|url|error)" *: *("[^"]*"|[0-9]+|null)')
  name=""; width=""; height=""; target_status=""; saved=0; failed=0
  while IFS= read -r line; do
    value=$(printf '%s' "$line" | sed 's/^[^:]*: *//; s/^"//; s/"$//')
    case "$line" in
      '"name"'*) name="$value" ;;
      '"width"'*) width="$value" ;;
      '"height"'*) height="$value" ;;
      '"status"'*) target_status="$value" ;;
      '"url"'*)
        [ -z "$name" ] && continue
        if [ "$target_status" = "ok" ] && [ "$value" != "null" ]; then
          if curl -sfL "$value" -H "User-Agent: $BRIA_USER_AGENT" -o "$out_dir/${name}-${width}x${height}.png"; then
            echo "saved $out_dir/${name}-${width}x${height}.png"; saved=$((saved + 1))
          else
            echo "Size '$name' could not be downloaded." >&2; failed=$((failed + 1))
          fi
        fi ;;
      '"error"'*)
        if [ "$target_status" = "failed" ]; then
          echo "Size '$name' (${width}x${height}) failed: $value" >&2; failed=$((failed + 1))
        fi
        name=""; width=""; height=""; target_status="" ;;
    esac
  done <<< "$fields"

  note=$(_bria_json_str text "$result")
  [ -n "$note" ] && echo "Note from Bria: $note"
  echo "$saved size(s) saved in $out_dir${failed:+, $failed failed}"
  [ "$saved" -gt 0 ] && return 0
  return 1
}

# Resize one ad end to end: submit, wait, download.
#   bria_resize <image-path-or-url> --size name=WxH [--size ...] [--prompt "..."] [--out-dir DIR]
bria_resize() {
  local image out_dir args status_url result rc attempt request_id
  image="$1"; shift
  out_dir=""; args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --out-dir) out_dir="$2"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done

  attempt=1
  while : ; do
    status_url=$(bria_resize_submit "$image" "${args[@]}") || return 1
    request_id="${status_url##*/}"
    result=$(bria_resize_wait "$status_url")
    rc=$?
    [ "$rc" -eq 0 ] && break
    if [ "$rc" -eq 2 ] && [ "$attempt" -eq 1 ]; then
      attempt=2
      echo "Retrying the ad once." >&2
      continue
    fi
    [ "$rc" -eq 2 ] && echo "Resizing failed twice. Contact Bria support with request_id $request_id" >&2
    return 1
  done

  bria_resize_download "$result" "$image" "$out_dir"
}

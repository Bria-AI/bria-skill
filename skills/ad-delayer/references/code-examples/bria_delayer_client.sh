#!/bin/bash
# bria_delayer_client.sh — Self-contained helper for Bria Ad Delayer (flat ad → editable layers).
# Zero dependencies beyond curl, grep, sed, base64 (standard on macOS/Linux).
#
# Usage:
#   source bria_delayer_client.sh
#   bria_delayer "/path/to/ad.png"
#   bria_delayer "https://example.com/ad.jpg" --prompt "the headline is two separate lines"
#   bria_delayer "/path/to/ad.png" --effort high --out-dir ./my-layers
#
#   # or the three steps on their own:
#   STATUS_URL=$(bria_delayer_submit "/path/to/ad.png")
#   RESULT_URL=$(bria_delayer_wait "$STATUS_URL")
#   bria_delayer_download "$RESULT_URL" "/path/to/ad.png"
#
# BRIA_API_KEY is auto-loaded from ~/.bria/credentials if not already set.

BRIA_API_BASE="${BRIA_API_BASE:-https://engine.prod.bria-api.com}"
BRIA_USER_AGENT="BriaSkills/1.3.7"
BRIA_POLL_INTERVAL="${BRIA_POLL_INTERVAL:-10}"     # seconds between status polls
BRIA_POLL_ATTEMPTS="${BRIA_POLL_ATTEMPTS:-36}"     # max polls (default 36 x 10s = 6 min)
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
# Sets BRIA_DELAYER_RETRYABLE=1 when the retry-once rule applies.
_bria_report_error() {
  local code="$1" message="$2"
  BRIA_DELAYER_RETRYABLE=0
  case "$message" in
    *"corrupt or empty"*)
      echo "The image could not be read — the file may be corrupt or empty. Re-export it and try again." >&2; return ;;
    *"Unsupported image format"*)
      echo "That image format is not supported. Save the ad as PNG, JPEG or WEBP and try again." >&2; return ;;
    *"could not be fetched"*)
      echo "That image URL could not be fetched — it needs to be a public, direct link to the image file. Attach the file instead." >&2; return ;;
  esac
  case "$code" in
    400|422)
      echo "Bria rejected the request as invalid. Try once more; if it repeats, report it as an ad-delayer skill issue." >&2 ;;
    401)
      echo "Bria sign-in is missing or invalid. Delete ~/.bria/credentials and run the authentication step again." >&2 ;;
    403)
      echo "This Bria account is not permitted to run this request — check the plan and billing status at https://platform.bria.ai/pricing" >&2 ;;
    429)
      echo "Bria is rate-limiting this account (9 delayering submits a minute by default). Wait a minute and try again." >&2 ;;
    5*)
      echo "Delayering failed inside Bria's pipeline." >&2; BRIA_DELAYER_RETRYABLE=1 ;;
    *)
      echo "Delayering failed (Bria returned status $code)." >&2; BRIA_DELAYER_RETRYABLE=1 ;;
  esac
}

# Submit one ad for delayering. Echoes the status_url to poll.
#   bria_delayer_submit <image-path-or-url> [--prompt "..."] [--effort minimal|low|medium|high]
bria_delayer_submit() {
  local image prompt effort payload_file body http_code status_url result_url backoff
  image="$1"; shift
  prompt=""; effort=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --prompt) prompt="$2"; shift 2 ;;
      --effort) effort="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done
  _bria_load_key || return 1
  if ! printf '%s' "$image" | grep -qE '^https?://'; then
    [ ! -f "$image" ] && { echo "File not found: $image" >&2; return 1; }
  fi

  payload_file="/tmp/bria_payload_$$.json"
  {
    printf '{"attachments": ["'
    if printf '%s' "$image" | grep -qE '^https?://'; then
      printf '%s' "$image"
    else
      base64 < "$image" | tr -d '\n\r'
    fi
    printf '"], "sync": false, "output_format": "json"'
    # Escape backslashes and quotes, and flatten newlines — the prompt is free text.
    [ -n "$prompt" ] && printf ', "prompt": "%s"' "$(printf '%s' "$prompt" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    [ -n "$effort" ] && printf ', "thinking_effort": "%s"' "$effort"
    printf '}'
  } > "$payload_file" || { rm -f "$payload_file"; return 1; }

  local response_file="/tmp/bria_submit_$$.json"
  # This file gets sourced into whatever shell the caller is using, and zsh does not word-split
  # an unquoted parameter, so the backoff schedule is walked with string ops rather than by
  # relying on `for x in $SCHEDULE` splitting it.
  local remaining="$BRIA_RETRY_BACKOFF"
  while : ; do
    http_code=$(curl -s -o "$response_file" -w '%{http_code}' -X POST \
      "${BRIA_API_BASE}/v2/ads/image_to_layers" \
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
    _bria_report_error "$http_code" "$(_bria_json_str message "$body")"
    return 1
  fi

  status_url=$(_bria_json_str status_url "$body")
  if [ -n "$status_url" ]; then
    echo "$status_url"
    return 0
  fi
  # Defensive: a synchronous 200 carries the result pointer directly, with no polling step.
  result_url=$(printf '%s' "$body" | grep -oE '[^_]"url" *: *"[^"]*"' | head -1 | sed 's/^[^:]*: *"//; s/"$//')
  [ -n "$result_url" ] && { echo "$result_url"; return 0; }
  echo "Bria accepted the ad but returned no job to track. Try again." >&2
  return 1
}

# Poll a status_url until the run finishes. Echoes the result URL (the layers manifest).
# Returns 1 for a terminal failure, 2 when the caller should retry the whole job once.
bria_delayer_wait() {
  local status_url poll url i code message
  status_url="$1"
  # A result pointer instead of a status URL (synchronous submit) needs no polling.
  case "$status_url" in
    */v2/status/*) : ;;
    *) echo "$status_url"; return 0 ;;
  esac
  _bria_load_key || return 1

  i=0
  while [ "$i" -lt "$BRIA_POLL_ATTEMPTS" ]; do
    sleep "$BRIA_POLL_INTERVAL"
    poll=$(curl -s "$status_url" -H "api_token: $BRIA_API_KEY" -H "User-Agent: $BRIA_USER_AGENT")

    if printf '%s' "$poll" | grep -qE '"status" *: *"(ERROR|FAILED)"'; then
      code=$(printf '%s' "$poll" | grep -oE '"code" *: *[0-9]+' | head -1 | sed 's/[^0-9]//g')
      message=$(_bria_json_str message "$poll")
      _bria_report_error "${code:-500}" "$message"
      [ "$BRIA_DELAYER_RETRYABLE" = "1" ] && return 2
      return 1
    fi
    if printf '%s' "$poll" | grep -qE '"status" *: *"UNKNOWN"'; then
      echo "That delayering run is no longer on file — Bria keeps job status for about a day. Run it again." >&2
      return 1
    fi

    url=$(printf '%s' "$poll" | grep -oE '[^_]"url" *: *"[^"]*"' | head -1 | sed 's/^[^:]*: *"//; s/"$//')
    [ -n "$url" ] && { echo "$url"; return 0; }

    if printf '%s' "$poll" | grep -qE '"status" *: *"COMPLETED"'; then
      echo "Bria reported the run complete but returned no layers. Run it again." >&2
      return 1
    fi
    i=$((i + 1))
  done

  echo "Delayering is still running after $((BRIA_POLL_ATTEMPTS * BRIA_POLL_INTERVAL)) seconds; it may still finish." >&2
  echo "Resume checking it with: curl -s \"$status_url\" -H \"api_token: \$BRIA_API_KEY\"" >&2
  return 1
}

# Fetch the layers manifest and every layer asset into <input-stem>-layers/.
#   bria_delayer_download <result_url> <original-input> [output-dir]
bria_delayer_download() {
  local result_url input out_dir stem manifest pairs id url name ext saved
  result_url="$1"; input="$2"; out_dir="$3"

  stem="${input##*/}"; stem="${stem%%\?*}"; stem="${stem%.*}"
  stem=$(printf '%s' "$stem" | tr -cd 'A-Za-z0-9._-')
  [ -z "$stem" ] && stem="ad"
  [ -z "$out_dir" ] && out_dir="${stem}-layers"
  mkdir -p "$out_dir" || return 1

  manifest="$out_dir/result.json"
  if ! curl -sfL "$result_url" -H "User-Agent: $BRIA_USER_AGENT" -o "$manifest"; then
    echo "The layers manifest could not be downloaded. Run the ad again." >&2
    return 1
  fi
  echo "saved $manifest"

  # The manifest lists each layer's "id" before its "asset_path", so walking the two keys
  # in document order pairs every asset with the layer id it belongs to.
  pairs=$(grep -oE '"(id|asset_path)" *: *"[^"]*"' "$manifest")
  id=""; saved=0
  while IFS= read -r line; do
    case "$line" in
      '"id"'*)
        id=$(printf '%s' "$line" | sed 's/^[^:]*: *"//; s/"$//') ;;
      '"asset_path"'*)
        url=$(printf '%s' "$line" | sed 's/^[^:]*: *"//; s/"$//')
        [ -z "$id" ] && continue
        ext=$(printf '%s' "$url" | sed 's/[?#].*$//' | sed -n 's/.*\.\([A-Za-z0-9]\{1,5\}\)$/\1/p')
        [ -z "$ext" ] && ext="png"
        name=$(printf '%s' "$id" | tr -cd 'A-Za-z0-9._-')
        if curl -sfL "$url" -H "User-Agent: $BRIA_USER_AGENT" -o "$out_dir/${name}.${ext}"; then
          echo "saved $out_dir/${name}.${ext}"
          saved=$((saved + 1))
        else
          echo "Layer '$id' could not be downloaded." >&2
        fi ;;
    esac
  done <<< "$pairs"

  echo "$saved layer image(s) plus result.json in $out_dir"
  return 0
}

# Delayer one ad end to end: submit, wait, download.
#   bria_delayer <image-path-or-url> [--prompt "..."] [--effort ...] [--out-dir DIR]
bria_delayer() {
  local image out_dir args status_url result_url rc attempt request_id
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
    status_url=$(bria_delayer_submit "$image" "${args[@]}") || return 1
    case "$status_url" in */v2/status/*) request_id="${status_url##*/}" ;; esac
    result_url=$(bria_delayer_wait "$status_url")
    rc=$?
    [ "$rc" -eq 0 ] && break
    if [ "$rc" -eq 2 ] && [ "$attempt" -eq 1 ]; then
      attempt=2
      echo "Retrying the ad once." >&2
      continue
    fi
    [ "$rc" -eq 2 ] && echo "Delayering failed twice. Contact Bria support with request_id $request_id" >&2
    return 1
  done

  bria_delayer_download "$result_url" "$image" "$out_dir"
}

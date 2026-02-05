#!/bin/bash
#
# Bria Visual Asset Generator - curl Reference
#
# Generate production-ready visual assets for websites, presentations,
# documents, and applications using Bria's AI models.
#
# Usage:
#   export BRIA_API_KEY="your-api-key"
#   ./bria_client.sh
#
# Or source individual functions:
#   source bria_client.sh
#   bria_generate "A modern office workspace"
#

set -euo pipefail

# ==================== Configuration ====================

BRIA_BASE_URL="${BRIA_BASE_URL:-https://engine.prod.bria-api.com}"
BRIA_API_KEY="${BRIA_API_KEY:-}"
BRIA_POLL_INTERVAL="${BRIA_POLL_INTERVAL:-2}"
BRIA_TIMEOUT="${BRIA_TIMEOUT:-120}"

# ==================== Helper Functions ====================

bria_check_api_key() {
  if [[ -z "$BRIA_API_KEY" ]]; then
    echo "Error: BRIA_API_KEY environment variable is not set" >&2
    echo "Set it with: export BRIA_API_KEY='your-api-key'" >&2
    return 1
  fi
}

bria_request() {
  local endpoint="$1"
  local data="$2"
  local wait="${3:-true}"

  bria_check_api_key || return 1

  local response
  response=$(curl -s -X POST "${BRIA_BASE_URL}${endpoint}" \
    -H "api_token: ${BRIA_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$data")

  if [[ "$wait" == "true" ]]; then
    local status_url
    status_url=$(echo "$response" | jq -r '.status_url // empty')
    if [[ -n "$status_url" ]]; then
      bria_poll "$status_url"
      return
    fi
  fi

  echo "$response"
}

bria_poll() {
  local status_url="$1"
  local timeout="${BRIA_TIMEOUT}"
  local interval="${BRIA_POLL_INTERVAL}"
  local elapsed=0

  while [[ $elapsed -lt $timeout ]]; do
    local response
    response=$(curl -s -X GET "$status_url" \
      -H "api_token: ${BRIA_API_KEY}")

    local status
    status=$(echo "$response" | jq -r '.status')

    case "$status" in
      "COMPLETED")
        echo "$response"
        return 0
        ;;
      "FAILED")
        local error
        error=$(echo "$response" | jq -r '.error // "Unknown error"')
        echo "Error: Request failed - $error" >&2
        return 1
        ;;
      *)
        sleep "$interval"
        elapsed=$((elapsed + interval))
        ;;
    esac
  done

  echo "Error: Request timed out after ${timeout}s" >&2
  return 1
}

# ==================== FIBO - Image Generation ====================

bria_generate() {
  local prompt="$1"
  local aspect_ratio="${2:-1:1}"
  local num_results="${3:-1}"
  local negative_prompt="${4:-}"
  local seed="${5:-}"

  local data
  data=$(jq -n \
    --arg prompt "$prompt" \
    --arg aspect_ratio "$aspect_ratio" \
    --argjson num_results "$num_results" \
    '{prompt: $prompt, aspect_ratio: $aspect_ratio, num_results: $num_results}')

  if [[ -n "$negative_prompt" ]]; then
    data=$(echo "$data" | jq --arg np "$negative_prompt" '. + {negative_prompt: $np}')
  fi
  if [[ -n "$seed" ]]; then
    data=$(echo "$data" | jq --argjson seed "$seed" '. + {seed: $seed}')
  fi

  bria_request "/v2/image/generate" "$data"
}

bria_refine() {
  local structured_prompt="$1"
  local instruction="$2"
  local aspect_ratio="${3:-1:1}"

  local data
  data=$(jq -n \
    --arg sp "$structured_prompt" \
    --arg prompt "$instruction" \
    --arg ar "$aspect_ratio" \
    '{structured_prompt: $sp, prompt: $prompt, aspect_ratio: $ar}')

  bria_request "/v2/image/generate" "$data"
}

bria_inspire() {
  local image_url="$1"
  local prompt="$2"
  local aspect_ratio="${3:-1:1}"

  local data
  data=$(jq -n \
    --arg url "$image_url" \
    --arg prompt "$prompt" \
    --arg ar "$aspect_ratio" \
    '{image_url: $url, prompt: $prompt, aspect_ratio: $ar}')

  bria_request "/v2/image/generate" "$data"
}

# ==================== RMBG-2.0 - Background Removal ====================

bria_remove_background() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/remove_background" "$data"
}

# ==================== FIBO-Edit - Image Editing ====================

bria_gen_fill() {
  local image_url="$1"
  local mask_url="$2"
  local prompt="$3"
  local mask_type="${4:-manual}"
  local negative_prompt="${5:-}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg mask "$mask_url" \
    --arg prompt "$prompt" \
    --arg mask_type "$mask_type" \
    '{image: $image, mask: $mask, prompt: $prompt, mask_type: $mask_type}')

  if [[ -n "$negative_prompt" ]]; then
    data=$(echo "$data" | jq --arg np "$negative_prompt" '. + {negative_prompt: $np}')
  fi

  bria_request "/v2/image/edit/gen_fill" "$data"
}

bria_erase() {
  local image_url="$1"
  local mask_url="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg mask "$mask_url" \
    '{image: $image, mask: $mask}')

  bria_request "/v2/image/edit/erase" "$data"
}

bria_erase_foreground() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/erase_foreground" "$data"
}

bria_replace_background() {
  local image_url="$1"
  local prompt="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg prompt "$prompt" \
    '{image: $image, prompt: $prompt}')

  bria_request "/v2/image/edit/replace_background" "$data"
}

bria_expand_image() {
  local image_url="$1"
  local aspect_ratio="${2:-16:9}"
  local prompt="${3:-}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg ar "$aspect_ratio" \
    '{image: $image, aspect_ratio: $ar}')

  if [[ -n "$prompt" ]]; then
    data=$(echo "$data" | jq --arg p "$prompt" '. + {prompt: $p}')
  fi

  bria_request "/v2/image/edit/expand" "$data"
}

bria_enhance_image() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/enhance" "$data"
}

bria_increase_resolution() {
  local image_url="$1"
  local scale="${2:-2}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --argjson scale "$scale" \
    '{image: $image, scale: $scale}')

  bria_request "/v2/image/edit/increase_resolution" "$data"
}

bria_lifestyle_shot() {
  local image_url="$1"
  local prompt="$2"
  local placement_type="${3:-automatic}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg prompt "$prompt" \
    --arg pt "$placement_type" \
    '{image: $image, prompt: $prompt, placement_type: $pt}')

  bria_request "/v2/image/edit/lifestyle_shot_by_text" "$data"
}

bria_shot_by_image() {
  local image_url="$1"
  local background_url="$2"
  local placement_type="${3:-automatic}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg bg "$background_url" \
    --arg pt "$placement_type" \
    '{image: $image, background: $bg, placement_type: $pt}')

  bria_request "/v2/image/edit/shot_by_image" "$data"
}

bria_blur_background() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/blur_background" "$data"
}

bria_edit_image() {
  local image_url="$1"
  local instruction="$2"
  local mask_url="${3:-}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg inst "$instruction" \
    '{images: [$image], instruction: $inst}')

  if [[ -n "$mask_url" ]]; then
    data=$(echo "$data" | jq --arg mask "$mask_url" '. + {mask: $mask}')
  fi

  bria_request "/v2/image/edit" "$data"
}

# ==================== Text-Based Object Editing ====================

bria_add_object() {
  local image_url="$1"
  local instruction="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg inst "$instruction" \
    '{image: $image, instruction: $inst}')

  bria_request "/v2/image/edit/add_object_by_text" "$data"
}

bria_replace_object() {
  local image_url="$1"
  local instruction="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg inst "$instruction" \
    '{image: $image, instruction: $inst}')

  bria_request "/v2/image/edit/replace_object_by_text" "$data"
}

bria_erase_object() {
  local image_url="$1"
  local object_name="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg obj "$object_name" \
    '{image: $image, object_name: $obj}')

  bria_request "/v2/image/edit/erase_by_text" "$data"
}

# ==================== Image Transformation ====================

bria_blend_images() {
  local image_url="$1"
  local overlay_url="$2"
  local instruction="$3"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg overlay "$overlay_url" \
    --arg inst "$instruction" \
    '{image: $image, overlay: $overlay, instruction: $inst}')

  bria_request "/v2/image/edit/blend" "$data"
}

bria_reseason() {
  local image_url="$1"
  local season="$2"  # spring, summer, autumn, winter

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg season "$season" \
    '{image: $image, season: $season}')

  bria_request "/v2/image/edit/reseason" "$data"
}

bria_restyle() {
  local image_url="$1"
  local style="$2"  # render_3d, cubism, oil_painting, anime, cartoon, etc.

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg style "$style" \
    '{image: $image, style: $style}')

  bria_request "/v2/image/edit/restyle" "$data"
}

bria_relight() {
  local image_url="$1"
  local light_type="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg lt "$light_type" \
    '{image: $image, light_type: $lt}')

  bria_request "/v2/image/edit/relight" "$data"
}

# ==================== Text in Images ====================

bria_replace_text() {
  local image_url="$1"
  local new_text="$2"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg text "$new_text" \
    '{image: $image, new_text: $text}')

  bria_request "/v2/image/edit/replace_text" "$data"
}

# ==================== Image Restoration & Conversion ====================

bria_sketch_to_image() {
  local image_url="$1"
  local prompt="${2:-}"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  if [[ -n "$prompt" ]]; then
    data=$(echo "$data" | jq --arg p "$prompt" '. + {prompt: $p}')
  fi

  bria_request "/v2/image/edit/sketch_to_image" "$data"
}

bria_restore_image() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/restore" "$data"
}

bria_colorize() {
  local image_url="$1"
  local style="${2:-color_contemporary}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg style "$style" \
    '{image: $image, style: $style}')

  bria_request "/v2/image/edit/colorize" "$data"
}

bria_crop_foreground() {
  local image_url="$1"

  local data
  data=$(jq -n --arg image "$image_url" '{image: $image}')

  bria_request "/v2/image/edit/crop_foreground" "$data"
}

# ==================== Structured Instructions ====================

bria_generate_structured_instruction() {
  local image_url="$1"
  local instruction="$2"
  local mask_url="${3:-}"

  local data
  data=$(jq -n \
    --arg image "$image_url" \
    --arg inst "$instruction" \
    '{images: [$image], instruction: $inst}')

  if [[ -n "$mask_url" ]]; then
    data=$(echo "$data" | jq --arg mask "$mask_url" '. + {mask: $mask}')
  fi

  bria_request "/v2/structured_instruction/generate" "$data"
}

# ==================== Raw curl Examples ====================

# The following are standalone curl commands that can be copied directly.
# They don't use the helper functions above.

print_curl_examples() {
  cat << 'EOF'
# ==================== Raw curl Examples ====================
# Copy and paste these commands directly. Replace placeholders with your values.

# --- Generate Image ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/generate" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Modern tech startup office, developers collaborating",
    "aspect_ratio": "16:9",
    "num_results": 1,
    "negative_prompt": "cluttered, dark"
  }'

# --- Poll Status (replace STATUS_URL) ---
curl -X GET "STATUS_URL" \
  -H "api_token: $BRIA_API_KEY"

# --- Remove Background ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/remove_background" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg"
  }'

# --- Gen Fill (Inpainting) ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/gen_fill" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "mask": "https://example.com/mask.png",
    "prompt": "red leather chair",
    "mask_type": "manual"
  }'

# --- Erase with Mask ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/erase" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "mask": "https://example.com/mask.png"
  }'

# --- Replace Background ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/replace_background" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "prompt": "tropical beach at sunset"
  }'

# --- Expand Image (Outpaint) ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/expand" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "aspect_ratio": "16:9",
    "prompt": "continue the scene naturally"
  }'

# --- Enhance Image ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/enhance" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg"
  }'

# --- Increase Resolution ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/increase_resolution" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "scale": 2
  }'

# --- Lifestyle Shot (Product Photography) ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/lifestyle_shot_by_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/product.png",
    "prompt": "modern kitchen countertop, morning light",
    "placement_type": "automatic"
  }'

# --- Shot by Image (Product on Reference BG) ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/shot_by_image" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/product.png",
    "background": "https://example.com/background.jpg",
    "placement_type": "automatic"
  }'

# --- Edit Image (Natural Language) ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "images": ["https://example.com/image.jpg"],
    "instruction": "change the mug to red"
  }'

# --- Add Object ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/add_object_by_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "instruction": "Place a red vase on the table"
  }'

# --- Replace Object ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/replace_object_by_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "instruction": "Replace the red apple with a green pear"
  }'

# --- Erase Object by Name ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/erase_by_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "object_name": "table"
  }'

# --- Blend Images ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/blend" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/base.jpg",
    "overlay": "https://example.com/texture.png",
    "instruction": "Apply the texture to the shirt"
  }'

# --- Reseason ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/reseason" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "season": "winter"
  }'

# --- Restyle ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/restyle" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "style": "oil_painting"
  }'

# --- Relight ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/relight" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "light_type": "golden hour"
  }'

# --- Replace Text ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/replace_text" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg",
    "new_text": "SALE 50% OFF"
  }'

# --- Sketch to Image ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/sketch_to_image" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/sketch.png",
    "prompt": "modern sports car"
  }'

# --- Restore Image ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/restore" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/old-photo.jpg"
  }'

# --- Colorize ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/colorize" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/bw-photo.jpg",
    "style": "color_contemporary"
  }'

# --- Crop Foreground ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/crop_foreground" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg"
  }'

# --- Blur Background ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/blur_background" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg"
  }'

# --- Erase Foreground ---
curl -X POST "https://engine.prod.bria-api.com/v2/image/edit/erase_foreground" \
  -H "api_token: $BRIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://example.com/image.jpg"
  }'

EOF
}

# ==================== CLI Examples ====================

main() {
  echo "=== Generate Website Hero Image ==="
  result=$(bria_generate \
    "Modern tech startup office, developers collaborating, bright natural light, minimal clean aesthetic" \
    "16:9" \
    1 \
    "cluttered, dark, low quality")
  echo "Hero image: $(echo "$result" | jq -r '.result.image_url')"

  echo ""
  echo "=== Generate Product Photo ==="
  result=$(bria_generate \
    "Professional product photo of wireless headphones on white studio background, soft shadows" \
    "1:1")
  product_url=$(echo "$result" | jq -r '.result.image_url')
  echo "Product photo: $product_url"

  echo ""
  echo "=== Remove Background ==="
  result=$(bria_remove_background "$product_url")
  echo "Transparent PNG: $(echo "$result" | jq -r '.result.image_url')"
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

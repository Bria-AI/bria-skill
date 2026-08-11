# Bria.ai Automotive API Reference

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** Include these headers in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
User-Agent: BriaSkills/<version>
```

> All automotive endpoints live under the `/v1/product/vehicle/*` namespace. Each endpoint accepts either an `image_url` OR a base64-encoded `file`. When both are provided, `image_url` takes precedence.

---

## POST /v1/product/vehicle/shot_by_text

Place a vehicle into a realistic, text-described environment. Produces enriched automotive shots by embedding the vehicle into the scene for a natural, grounded appearance.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | one of image_url/file | — | Vehicle image URL (jpeg, jpg, png, webp; max 12MB) |
| `file` | string | one of image_url/file | — | Base64-encoded vehicle image |
| `scene_description` | string | yes | — | Text description of the desired environment |
| `placement_type` | string | yes | — | See "Placement Types" below |
| `shot_size` | object | conditional | — | Output image dimensions (depends on placement_type) |
| `manual_placement_selection` | string | when `manual_placement` | — | Predefined position name |
| `foreground_image_size` | object | when `custom_coordinates` | — | Vehicle size inside the frame |
| `foreground_image_location` | object | when `custom_coordinates` | — | Vehicle x/y origin |
| `manual_padding` | number | when `manual_padding` | — | Padding in pixels around the vehicle |
| `aspect_ratio` | string | when `automatic_aspect_ratio` | — | Target canvas aspect ratio |
| `num_results` | number | no | 1 | Number of variations (up to 7 in `automatic` mode) |

### Placement Types

| Placement | Behavior |
|-----------|----------|
| `original` | Preserves original vehicle position and size |
| `automatic` | Returns up to 7 recommended placements |
| `manual_placement` | Uses a predefined position |
| `custom_coordinates` | Full control via `foreground_image_size` + `foreground_image_location` |
| `manual_padding` | Adds pixel padding around the vehicle |
| `automatic_aspect_ratio` | Centers the vehicle and resizes the canvas to `aspect_ratio` |

**Request example:**
```json
{
  "image_url": "https://example.com/car.png",
  "scene_description": "winding alpine road, golden hour lighting",
  "placement_type": "automatic",
  "num_results": 3
}
```

**Response:** Returns URLs of the enriched automotive shots with the vehicle embedded in the generated scene.

---

## POST /v1/product/vehicle/segment

Generate binary segmentation masks for specific vehicle parts. Each returned field is either a PNG mask URL or an empty string when the part is not visible. Masks power downstream edits such as reflection generation or tire refinement.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image_url` | string | one of image_url/file | Vehicle image URL (jpeg, jpg, png, webp; max 12MB) |
| `file` | string | one of image_url/file | Base64-encoded image |

**Response schema:**

| Field | Type | Description |
|-------|------|-------------|
| `windshield` | string | Front windshield mask URL |
| `rear_window` | string | Rear window mask URL |
| `side_windows` | string | All visible side windows combined |
| `body` | string | Vehicle body (painted surfaces) |
| `wheels` | string | All visible wheels |
| `hubcap` | string | All visible hubcaps |
| `tires` | string | All visible tires (use as input to `refine_tires`) |

---

## POST /v1/product/vehicle/generate_reflections

Paint realistic reflections onto glossy surfaces such as windshields, side windows, and painted bodywork. Reflection masks may be supplied manually or generated automatically with the segmentation endpoint.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image_url` | string | one of image_url/file | Vehicle image URL |
| `file` | string | one of image_url/file | Base64-encoded image |
| `masks` | object | no | Optional per-region reflection masks |
| `layers` | boolean | no | When true, also returns per-region reflection layers |

**Response:** Updated vehicle image with applied reflections, plus optional reflection layers per region.

---

## POST /v1/product/vehicle/refine_tires

Replace tire textures with a realistic terrain surface. Requires a tire mask (use `/v1/product/vehicle/segment` first to obtain one automatically).

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image` | string | yes | — | Vehicle image (URL or base64) |
| `tire_mask` | string | yes | — | Binary mask of all tires (URL or base64) |
| `surface` | string | yes | — | One of `snow`, `mud`, `grass` |
| `output_tire_layer` | boolean | no | `false` | When true, also returns just the refined tires layer |

**Response schema:**
```json
{
  "image": "https://…/vehicle_with_refined_tires.jpg",
  "tire_layer": "https://…/tire_layer.png"
}
```

---

## POST /v1/product/vehicle/apply_effect

Apply atmospheric overlays to a vehicle image for added realism or dramatic mood.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | one of image_url/file | — | Vehicle image URL |
| `file` | string | one of image_url/file | — | Base64-encoded vehicle image |
| `effect` | string | yes | — | One of `dust`, `snow`, `fog`, `light leaks`, `lens flare` |
| `layers` | boolean | no | `false` | When true, returns only the effect layer; when false, returns the composited image |
| `seed` | integer | no | random | Seed for reproducible effect variations |

**Request example:**
```json
{
  "image_url": "https://example.com/car.jpg",
  "effect": "fog",
  "layers": false,
  "seed": 12345
}
```

**Response schema:**
```json
{
  "url": "https://.../car_fog.jpg",
  "layer_url": "https://.../fog_layer.png",
  "seed": 12345
}
```

`layer_url` is returned only when `layers=true`.

---

## POST /v1/product/vehicle/harmonize

Apply a predefined lighting and tone preset so the vehicle visually matches a desired environmental context (useful after `shot_by_text`).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image_url` | string | one of image_url/file | Vehicle image URL |
| `file` | string | one of image_url/file | Base64-encoded vehicle image |
| `preset` | string | yes | One of `hot-day`, `cold-day`, `hot-night`, `cold-night` |

**Response:** Updated image with harmonized lighting/tone; the vehicle subject is unified with its background for visual consistency.

---

## Error Handling

All automotive endpoints may return the following HTTP status codes:

| Code | Meaning |
|------|---------|
| 400 | Bad request — malformed parameters |
| 401 | Unauthorized — invalid or missing `api_token` |
| 404 | Resource not found |
| 413 | Payload too large (>12MB) |
| 415 | Unsupported image format |
| 422 | Semantic validation failed (e.g. missing required mask) |
| 429 | Rate limit exceeded |
| 460 | Content moderation blocked the input or output |
| 500 | Server error |

### Supported Image Formats
JPEG, PNG, WEBP — up to 12MB per image.

### Content Moderation
All automotive endpoints support an optional content moderation flag that filters unsafe inputs and outputs. Refer to the upstream docs for the parameter name per endpoint.

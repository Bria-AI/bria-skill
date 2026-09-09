# Ad Delayer API Reference

> This file documents the delayering API **as implemented**, verified 2026-08-24 against the
> service source. When it drifts, the source of truth is the ads service's own request model
> (`services/ads/app/parse_api_input.py`), its error mapping (`services/ads/app/errors.py`), and
> the layer-manifest exporter in Bria's deflatter library — not the product spec. Fields the
> product spec describes but the API does not emit yet (a symbolic error-code registry, a
> dimension cap, `schema_version`, per-layer confidence) are deliberately absent below.

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** include these headers in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
User-Agent: BriaSkills/1.3.5
```

> **Required:** always include the `User-Agent: BriaSkills/1.3.5` header on every call, including
> status polls. It is how delayering traffic from this skill is identified server-side.

---

## Delayering

### POST /v2/ads/image_to_layers

Takes one flat ad image apart into layers. Asynchronous: returns HTTP 202 with a `request_id` and
a `status_url` to poll. A typical ad takes **2–3 minutes**.

Use this path, not `/v2/ads/delayer`. The alias exists in the service code but is not routed by
the load balancer in either environment, so it is unreachable from the public API.

**Request:**
```json
{
  "attachments": ["https://example.com/ads/summer-sale.jpg"],
  "prompt": "the badge top-left is the brand logo",
  "thinking_effort": "medium",
  "output_format": "json",
  "sync": false
}
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `attachments` | array of string | Yes | — | The source ad. **Exactly one** entry: a public direct image URL, raw base64, or a `data:` URI. Two or more entries is a 422 |
| `prompt` | string | No | — | Natural-language guidance for the extraction |
| `thinking_effort` | string | No | `medium` | `minimal`, `low`, `medium`, or `high` |
| `output_format` | string | No | `json` | `json` for the layer manifest, `html` for the reconstructed HTML render of the same run |
| `sync` | boolean | No | `false` | Send `false` explicitly. `true` holds the connection open for the entire 2–3 minute run — far longer than an HTTP response can wait |
| `webhook_url` | string | No | — | Delivers the result instead of requiring polling. Ignored when `sync` is `true` |

Unknown fields are rejected (`extra="forbid"`).
Supported input formats: PNG, JPEG, WEBP, AVIF, GIF, TIFF, BMP, SVG, PDF. There is no file-size
limit. Dimensions are capped at **800 px per side** unless the requesting organisation has
enterprise-tier entitlement; the check runs before any billable work, so a rejection costs nothing
but is also unrecoverable without resizing the ad.

**Response (HTTP 202):**
```json
{
  "request_id": "3f0b7c2e-...",
  "status_url": "https://engine.prod.bria-api.com/v2/status/3f0b7c2e-..."
}
```

---

## Status Polling

### GET /v2/status/{request_id}

Always HTTP 200; the job's own outcome is in the body. `/v2/status/*` is exempt from rate
limiting, so polling costs nothing against the submit limit.

**While running:**
```json
{ "status": "IN_PROGRESS", "request_id": "3f0b7c2e-..." }
```

**On success:**
```json
{
  "status": "COMPLETED",
  "result": {
    "agent_type": "deflat",
    "status": "completed",
    "text": "Constructed a layered ad.",
    "url": "https://.../deflatter/<run-id>/public/creation/creation.json"
  },
  "request_id": "3f0b7c2e-..."
}
```

**On failure:**
```json
{
  "status": "ERROR",
  "error": { "code": 422, "message": "The image URL could not be fetched", "details": "..." },
  "request_id": "3f0b7c2e-..."
}
```

**Status values** (the wire values, which differ from the internal enum names):

| Value | Meaning |
|-------|---------|
| `IN_PROGRESS` | Still running — poll again |
| `COMPLETED` | Done; `result.url` points at the layer manifest |
| `ERROR` | The run failed; `error` carries the reason |
| `UNKNOWN` | No record of this request id — either it never existed or its status has aged out (status is retained for about a day) |

`result` also carries two legacy fields that are not worth reading: `agent_type` is always
`"deflat"`, and `text` is a fixed sentence, not a generated description.

**Polling strategy:** 10-second intervals, up to 36 attempts (a 6-minute ceiling; typical runs
finish in 2–3 minutes). `bria_delayer_wait` implements this — override with `BRIA_POLL_INTERVAL`
and `BRIA_POLL_ATTEMPTS`.

---

## The result is a pointer, not the layers

`result.url` is a **link to the layer manifest**, not the manifest itself — delayering is a
three-hop flow:

1. `POST /v2/ads/image_to_layers` → 202 + `status_url`
2. `GET {status_url}` until `COMPLETED` → `result.url`
3. `GET {result.url}` → `creation.json`, the manifest below; then GET each layer's `asset_path`

Manifest and assets are stored without an expiry, and every `asset_path` in the published
manifest has already been rewritten to a public URL, so a plain GET is enough.

### Layer manifest (`creation.json`)

```json
{
  "canvas": { "width": 1080, "height": 1350 },
  "layers": [ { "id": "...", "type": "...", "subtype": "...", "bbox": {}, "z_order": 0 } ],
  "font_stylesheets": ["https://fonts.googleapis.com/css2?family=Poppins:wght@400;700"]
}
```

Null-valued keys are omitted entirely, so a layer only carries the fields that apply to it.

| Layer field | Type | Present on | Description |
|-------------|------|-----------|-------------|
| `id` | string | always | Role slot — `canvas_background`, `background_1`, `logo_1`, `image_1`, `product_1`, `primary_copy_1`, `secondary_copy_1`, `cta_1`, … Falls back to `{subtype}_{index}` when no slot was assigned |
| `type` | string | always | `image`, `text`, or `vector` |
| `subtype` | string | always | The semantic role behind the slot (`background`, `logo`, `headline`, `cta`, …) |
| `bbox` | object | always | `{x, y, width, height}` in canvas pixels, 2 decimal places |
| `z_order` | int | always | Paint order, back to front. `0` is the synthetic `canvas_background` base fill |
| `text` | string | text layers, and labelled placeholders | The copy, newlines preserved |
| `asset_path` | string | image layers only | Public URL of that layer's extracted image |
| `style` | object | when it has any | Box paint: `background_color`, `background_gradient`, `border_*`, `border_radius_*`, `box_shadow`, `opacity`, `rotation_deg`, `skew_x_deg`, `blend_mode`, `vector_shape` |
| `text_style` | object | text layers | `color`, `font_family`, `font_weight`, `font_size_px`, `letter_spacing_px`, `line_height`, `text_align`, `align_x`, `align_y`, `uppercase`, `underline`, `italic`, `no_wrap`, `direction`, `text_shadows`, `rotation_deg`, `translate_*_px` |
| `text_runs` | array | text with mixed styling | Per-run `{text, style}`, where `style` holds only what differs from `text_style` |
| `image_fit` | object | image layers | `object_fit`, `object_position_x`, `object_position_y` |

Only image layers have an `asset_path`, so a text-heavy ad produces fewer files than layers —
its copy lives in the manifest as editable text, which is the point of delayering.

---

## Errors

There is no symbolic error-code registry. Every failure is the same shape, with `code` set to the
HTTP status:

```json
{ "code": 422, "message": "The image URL could not be fetched", "details": "..." }
```

**Where it arrives depends on when it happens.** Because the run is asynchronous, only failures
raised before the job starts come back on the submit; the rest arrive on the status poll inside
`error`.

| Signal | Where | Message | Retry |
|--------|-------|---------|-------|
| `401` | submit | Auth failure | No |
| `403` | submit | Account not permitted / billing | No |
| `422` | submit | Request-shape rejection — two or more `attachments`, an unknown field, an invalid `thinking_effort` or `output_format` | No |
| `429` | submit | Rate limit — 9 submits per minute per account on this endpoint by default (configurable per route and plan; some orgs are exempt) | Backoff |
| `400` | status poll | "An attachment (reference image URL) is required." | No |
| `422` | status poll | "The uploaded file appears corrupt or empty" | No |
| `422` | status poll | "Unsupported image format. Supported formats include: PNG, JPEG, WEBP, AVIF, GIF, TIFF, BMP, SVG, PDF" | No |
| `422` | status poll | "The image URL could not be fetched" — not a public direct link, or resolves to a non-global address | No |
| `413` | status poll | Over 800 px per side on a plan that is capped there. Two wordings — a plan-upgrade message, or a lite-version message for limited-distribution partner organisations | No |
| `500` | status poll | Pipeline failure; `details` names the stage that failed | Once |

The 4xx messages above are Bria's validator messages, passed through unchanged.

---

## Related endpoints on the same service

Same request model, same async flow, different output — documented here only so the delayering
path is not confused with them:

- `POST /v2/ads/extract_objects` — returns just the cut-out foreground objects, with dimensions
  and file sizes, and no layout or text
- `POST /v2/ads/image_to_template` — returns a reusable template rather than a faithful
  reconstruction of this specific ad

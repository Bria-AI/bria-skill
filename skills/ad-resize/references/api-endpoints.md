# Ad Resize API Reference

> This file documents the resize API **as implemented**, verified 2026-09-29 against the service
> source and a production run. When it drifts, the source of truth is the ads service's own
> request model (`services/ads/app/parse_api_input.py`, `AdsResizeRequest`) and its response model
> (`services/ads/app/parse_api_outputs.py`, `AdsResizeResponse`) in Bria-AI/spring.

## Contents

- Base URL & Authentication
- Resizing: `POST /v2/ads/resize` (request, parameters, 202 response)
- Status: `GET /v2/status/{request_id}` (completed body, per-size fields, failed job)
- Errors

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** include these headers in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
User-Agent: BriaSkills/1.4.0
```

> **Required:** always include the `User-Agent: BriaSkills/1.4.0` header on every call, including
> status polls. It is how resize traffic from this skill is identified server-side.

---

## Resizing

### POST /v2/ads/resize

Resizes one flat ad into up to ten target sizes. Asynchronous: returns HTTP 202 with a
`request_id` and a `status_url` to poll. A direct size takes **about a minute**; a size that
needs the layered route takes **five to seven minutes**, and the job finishes when its slowest
size does.

**Request:**
```json
{
  "attachments": ["https://example.com/ads/summer-sale.jpg"],
  "formats": [
    {"name": "feed", "width": 1080, "height": 1080},
    {"name": "story", "width": 1080, "height": 1920},
    {"name": "leaderboard", "width": 970, "height": 90}
  ],
  "prompt": "keep the logo in the top-left corner",
  "sync": false
}
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `attachments` | array of string | Yes | — | The source ad. **Exactly one** entry: a public direct image URL, raw base64, or a `data:` URI. Two or more entries, or a value that is neither a URL nor base64, is a 422 on the POST |
| `formats` | array of object | Yes | — | **One to ten** target sizes. Each has `name` (string, non-empty, echoed back), `width` and `height` (integers above zero, pixels). Eleven entries or a zero dimension is a 422 on the POST |
| `prompt` | string | No | — | Natural-language guidance for how the ad adapts to each size |
| `sync` | boolean | No | `false` | Send `false` explicitly. `true` is rejected with 400; the layered route runs for minutes |
| `webhook_url` | string | No | — | Delivers the completion body instead of requiring polling |

Unknown fields are rejected (`extra="forbid"`). Supported input formats: PNG and JPEG. Ads over
**2048 px per side** are downscaled to fit before resizing on plans that are not Enterprise; the
outputs still come back at the requested sizes and the completed body says so in `result.text`.

**Response (202):**
```json
{"request_id": "340780795e1b4530a5c7ee4563989f6f", "status_url": "https://engine.prod.bria-api.com/v2/status/340780795e1b4530a5c7ee4563989f6f"}
```

---

## Status

### GET /v2/status/{request_id}

Poll until `status` is terminal. `IN_PROGRESS` → `COMPLETED` or `ERROR`; `UNKNOWN` (HTTP 200)
means the id is not on file any more, about a day after the run.

**Completed:**
```json
{
  "request_id": "340780795e1b4530a5c7ee4563989f6f",
  "status": "COMPLETED",
  "result": {
    "status": "completed",
    "results": [
      {"name": "feed", "width": 1080, "height": 1080, "status": "ok", "strategy": "ai_image_models", "url": "https://editor-media.bria.ai/inventory/.../assets/7b4549c2.png", "error": null},
      {"name": "story", "width": 1080, "height": 1920, "status": "ok", "strategy": "ai_image_models", "url": "https://editor-media.bria.ai/inventory/.../assets/ee056ad7.png", "error": null},
      {"name": "leaderboard", "width": 970, "height": 90, "status": "ok", "strategy": "delayer_dispatch", "url": "https://editor-media.bria.ai/inventory/.../assets/86086542.png", "error": null}
    ],
    "text": "Your source image was downscaled to fit within 2048 px per dimension before resizing, because your plan caps resolution at that size. Full-resolution resizing requires a Bria enterprise plan."
  }
}
```

| Field | Description |
|-------|-------------|
| `result.results[]` | One entry per requested size, in request order, carrying the request's `name` |
| `results[].status` | `ok` or `failed`. Sizes are independent: one can fail while the rest succeed |
| `results[].strategy` | `ai_image_models` (direct image-model pass, ratios between 1:3 and 3:1) or `delayer_dispatch` (layered route through the Ad Delayer, every other ratio). Chosen by Bria per size |
| `results[].url` | The hosted image at exactly the requested pixels. Present when `status` is `ok` |
| `results[].error` | Why the size failed. Present when `status` is `failed` |
| `result.text` | Present only when the source was downscaled on a capped plan, or a font the ad uses was unavailable and a default was rendered |

**Failed job:**
```json
{"request_id": "...", "status": "ERROR", "error": {"code": 422, "message": "The image URL returned HTTP 403.", "details": "422 Unprocessable Entity: The image URL returned HTTP 403."}}
```

---

## Errors

| HTTP / status | Where | Meaning | Retry? |
|---------------|-------|---------|--------|
| `400` | POST | `sync` was `true` | No |
| `401` / `403` | POST or poll | Missing, invalid, or unauthorised API key | No, re-authenticate |
| `404` | POST | Ad Resize is not enabled for this organisation | No, ask Bria |
| `413` | POST | Request body over the platform cap; send a URL instead of base64 | No |
| `422` | POST | Two attachments, an attachment that is neither a URL nor base64, no sizes, more than ten sizes, or a zero dimension. `details` names the field | No |
| `422` | status poll | The image URL could not be fetched (`The image URL returned HTTP 403.`) | No |
| `429` | POST | Rate limit for the account | Yes, after backoff |
| `500` | status poll | The pipeline failed | Once |
| `UNKNOWN` | status poll | The id has aged out | Submit again |

Every error body carries `request_id`; the one in a POST error identifies that response, the
durable handle for a job is the id in its `status_url`.

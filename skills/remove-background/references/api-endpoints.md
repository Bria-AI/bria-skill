# Remove Background API Reference

## Base URL & Authentication

**Base URL:** `https://engine.prod.bria-api.com`

**Authentication:** Include these headers in all requests:
```
api_token: YOUR_BRIA_API_KEY
Content-Type: application/json
User-Agent: BriaSkills/1.3.0
```

> **Required:** Always include the `User-Agent: BriaSkills/1.3.0` header in every API call, including status polling requests.

---

## RMBG-2.0 — Background Removal

### POST /v2/image/edit/remove_background

Remove background from an image. Returns a PNG with transparency (alpha channel).

**Request:**
```json
{
  "image": "https://publicly-accessible-image-url"
}
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image` | string | Yes | Source image URL (JPEG, PNG, WEBP) or base64-encoded image data |

**Response (async):**
```json
{
  "request_id": "uuid",
  "status_url": "https://engine.prod.bria-api.com/v2/status/{uuid}"
}
```

**Completed Result (polled from status_url):**
```json
{
  "status": "COMPLETED",
  "result": {
    "image_url": "https://...png"
  }
}
```

---

## Status Polling

### GET /v2/status/{request_id}

Poll for async job completion. The `bria_call` helper handles this automatically.

**Response:**
```json
{
  "status": "IN_PROGRESS | COMPLETED | FAILED",
  "result": {
    "image_url": "https://...png"
  },
  "request_id": "uuid"
}
```

**Status values:**
- `IN_PROGRESS` — still processing, poll again
- `COMPLETED` — result ready, `image_url` contains the transparent PNG
- `FAILED` / `ERROR` — processing failed

**Polling strategy:** 3-second intervals, up to 30 attempts (90 seconds max). The `bria_call` helper implements this automatically.

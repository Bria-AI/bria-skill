# Video Remove Background API Reference

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

## Video Background Removal

### POST /v2/video/edit/remove_background

Initiates an asynchronous background removal job for a video. Returns HTTP 202 with a `request_id` and `status_url` to poll until a terminal status is returned.

**Request:**
```json
{
  "video": "https://publicly-accessible-video-url.mp4",
  "background_color": "Transparent",
  "output_container_and_codec": "webm_vp9",
  "preserve_audio": true
}
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `video` | string | Yes | — | Publicly accessible URL of the input video. Input resolution supported up to 16000x16000 (16K) |
| `background_color` | string | No | `Transparent` | Predefined string only — one of: `Transparent`, `Black`, `White`, `Gray`, `Red`, `Green`, `Blue`, `Yellow`, `Cyan`, `Magenta`, `Orange`. Hex values are not supported |
| `output_container_and_codec` | string | No | — | Output preset — one of: `mp4_h264`, `mp4_h265`, `webm_vp9`, `mov_h265`, `mov_proresks`, `mkv_h264`, `mkv_h265`, `mkv_vp9`, `gif` |
| `preserve_audio` | boolean | No | — | Retain the audio track in the output if present in the input |
| `webhook_url` | string | No | — | Optional URL for receiving the result via webhook when the async job completes |

**Response (HTTP 202):**
```json
{
  "request_id": "uuid",
  "status_url": "https://engine.prod.bria-api.com/v2/status/{uuid}"
}
```

**Error response (HTTP 400 / 422):**
```json
{
  "error": {
    "code": 123,
    "message": "...",
    "details": "..."
  },
  "request_id": "uuid"
}
```

### Input constraints

- **Max input duration:** 60 seconds
- **Input containers:** `.mp4`, `.mov`, `.webm`, `.avi`, `.gif`
- **Input codecs:** H.264, H.265 (HEVC), VP9, AV1, PhotoJPEG
- **Resolution:** up to 16000x16000 (16K). Larger inputs return `413 Payload Too Large`

### Attributes preserved in output

- Aspect ratio and resolution (output matches input)
- Frame rate
- Audio, if present (with `preserve_audio`)

### Transparency / alpha support

If `background_color` is `Transparent` (the default), the selected output preset **must support alpha**, otherwise the server responds with `422 Unprocessable Entity`.

| Alpha supported | Alpha NOT supported |
|-----------------|---------------------|
| `webm_vp9`, `mov_proresks`, `mkv_vp9`, `mkv_raw`, `gif`, `mov_h265` (HEVC with Alpha) | `mp4_h264`, `mp4_h265`, `mkv_h264`, `mkv_h265`, `avi_h264` |

---

## Local Video Upload Service

The `video` parameter requires a publicly accessible URL. To process a local file, upload it first to get a temporary URL.

### POST /v2/video/upload

Request a presigned upload URL.

**Request:**
```json
{ "media_type": "video/mp4" }
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `media_type` | string | No | MIME type (e.g. `video/mp4`). Defaults to `video/` if omitted |

**Response:**
```json
{
  "result": {
    "upload_url": "https://...",
    "upload_fields": { "key": "...", "policy": "...", "signature": "..." },
    "file_url": "https://..."
  }
}
```

| Field | Validity | Purpose |
|-------|----------|---------|
| `upload_url` | 1 hour | Presigned POST endpoint for the file upload |
| `upload_fields` | 1 hour | Form fields that must be sent with the upload |
| `file_url` | 1 day | URL to pass as `video` to editing endpoints |

### Upload the file

POST to `upload_url` as `multipart/form-data`. **All `upload_fields` must precede the file field** — validation is sequential, the file must come last. Success returns HTTP 204 No Content.

**Limits:** video files only, max size 1 GB. Treat `upload_url` and `file_url` as secrets — they are unauthenticated.

---

## Status Polling

### GET /v2/status/{request_id}

Poll for async job completion. The `bria_video_call` helper handles this automatically.

**Response:**
```json
{
  "status": "IN_PROGRESS | COMPLETED | ERROR",
  "result": {
    "video_url": "https://...webm"
  },
  "request_id": "uuid"
}
```

**Status values:**
- `IN_PROGRESS` — still processing, poll again
- `COMPLETED` — result ready, `video_url` contains the processed video
- `ERROR` / `FAILED` — processing failed, an error object is provided
- `UNKNOWN` — unexpected internal error (equivalent to HTTP 500)

**HTTP codes:** `200` standard response (regardless of job success), `404` request ID doesn't exist or expired, `5XX` Status Service internal error.

**Polling strategy:** 5-second intervals, up to 120 attempts (10 minutes max — video jobs take longer than image jobs). The `bria_video_call` helper implements this automatically.

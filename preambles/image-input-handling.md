# Image Input Handling

Shared pattern for Bria skills that accept image parameters.

## Tool Section Pattern

Replace `IMAGE_PATH_OR_URL` with the image URL or local file path.

Source the helper script at `references/code-examples/bria_client.sh` (resolve relative to this skill's directory).

```bash
source <SKILL_DIR>/references/code-examples/bria_client.sh
RESULT_URL=$(bria_call <ENDPOINT> "IMAGE_PATH_OR_URL" [extra JSON fields...])
echo "$RESULT_URL"
```

The helper auto-loads the API key from `~/.bria/credentials` and handles URL passthrough, local file base64 encoding, JSON construction, API call, and async polling.

## Examples

```bash
source <SKILL_DIR>/references/code-examples/bria_client.sh

# Remove background
RESULT_URL=$(bria_call /v2/image/edit/remove_background "/path/to/image.png")

# Replace background
RESULT_URL=$(bria_call /v2/image/edit/replace_background "https://example.com/img.jpg" '"prompt": "sunset beach"')

# Edit image (uses images array)
RESULT_URL=$(bria_call /v2/image/edit "/path/to/image.png" --key images '"instruction": "make it warmer"')
```

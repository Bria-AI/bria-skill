# Bria AI Workflows & Advanced Patterns

## Batch & Parallel Image Generation

### Python Async Batch Generation

For generating many images efficiently, launch requests in parallel and poll concurrently:

```python
import asyncio
import aiohttp

async def generate_image(session, api_key, prompt, aspect_ratio="1:1"):
    """Launch a single generation request."""
    async with session.post(
        "https://engine.prod.bria-api.com/v2/image/generate",
        headers={"api_token": api_key, "Content-Type": "application/json"},
        json={"prompt": prompt, "aspect_ratio": aspect_ratio}
    ) as resp:
        return await resp.json()

async def poll_status(session, api_key, status_url, timeout=120):
    """Poll until complete or failed."""
    for _ in range(timeout // 2):
        async with session.get(status_url, headers={"api_token": api_key}) as resp:
            data = await resp.json()
            if data["status"] == "COMPLETED":
                return data["result"]["image_url"]
            if data["status"] == "FAILED":
                raise Exception(data.get("error", "Generation failed"))
        await asyncio.sleep(2)
    raise TimeoutError(f"Timeout polling {status_url}")

async def generate_batch(api_key, prompts, aspect_ratio="1:1", max_concurrent=5):
    """Generate multiple images with different prompts concurrently."""
    semaphore = asyncio.Semaphore(max_concurrent)  # Rate limiting

    async def generate_one(prompt):
        async with semaphore:
            async with aiohttp.ClientSession() as session:
                # Launch request
                result = await generate_image(session, api_key, prompt, aspect_ratio)
                # Poll for completion
                return await poll_status(session, api_key, result["status_url"])

    # Run all concurrently
    results = await asyncio.gather(*[generate_one(p) for p in prompts], return_exceptions=True)
    return results

# Usage
prompts = [
    "Professional photo of running shoes on white background",
    "Professional photo of leather handbag on white background",
    "Professional photo of smartwatch on white background",
    "Professional photo of sunglasses on white background",
]
image_urls = asyncio.run(generate_batch("YOUR_API_KEY", prompts, max_concurrent=3))
```

**Key points:**
- Use `asyncio.Semaphore` to limit concurrent requests (recommended: 3-5)
- `return_exceptions=True` prevents one failure from canceling all requests
- Each result is either a URL string or an Exception object

### TypeScript/Node.js Parallel Generation

```typescript
type AspectRatio = "1:1" | "4:3" | "16:9" | "3:4" | "9:16";

interface BriaResponse {
  request_id: string;
  status_url: string;
}

interface BriaStatusResponse {
  status: "IN_PROGRESS" | "COMPLETED" | "FAILED";
  result?: { image_url: string };
  error?: string;
}

interface GenerateBatchResult {
  prompt: string;
  imageUrl: string | null;
  error: string | null;
}

async function generateBatch(
  apiKey: string,
  prompts: string[],
  aspectRatio: AspectRatio = "1:1",
  maxConcurrent = 5
): Promise<GenerateBatchResult[]> {
  const semaphore = { count: 0, max: maxConcurrent };

  async function withLimit<T>(fn: () => Promise<T>): Promise<T> {
    while (semaphore.count >= semaphore.max) {
      await new Promise(r => setTimeout(r, 100));
    }
    semaphore.count++;
    try {
      return await fn();
    } finally {
      semaphore.count--;
    }
  }

  async function generateOne(prompt: string): Promise<string> {
    return withLimit(async () => {
      // Launch request
      const res = await fetch("https://engine.prod.bria-api.com/v2/image/generate", {
        method: "POST",
        headers: { "api_token": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({ prompt, aspect_ratio: aspectRatio })
      });
      const { status_url } = (await res.json()) as BriaResponse;

      // Poll for result
      for (let i = 0; i < 60; i++) {
        const statusRes = await fetch(status_url, { headers: { "api_token": apiKey } });
        const data = (await statusRes.json()) as BriaStatusResponse;
        if (data.status === "COMPLETED") return data.result!.image_url;
        if (data.status === "FAILED") throw new Error(data.error || "Generation failed");
        await new Promise(r => setTimeout(r, 2000));
      }
      throw new Error("Timeout waiting for generation");
    });
  }

  const results = await Promise.allSettled(prompts.map(generateOne));

  return results.map((result, i) => ({
    prompt: prompts[i],
    imageUrl: result.status === "fulfilled" ? result.value : null,
    error: result.status === "rejected" ? result.reason.message : null
  }));
}

// Usage
const results = await generateBatch(process.env.BRIA_API_KEY!, [
  "Modern office workspace with natural lighting",
  "Abstract tech background with blue gradient",
  "Professional headshot studio setup"
], "16:9", 3);

results.forEach(r => {
  if (r.imageUrl) console.log(`Done ${r.prompt}: ${r.imageUrl}`);
  else console.log(`Failed ${r.prompt}: ${r.error}`);
});
```

---

## Pipeline Workflows

Chain multiple operations on images (generate -> edit -> remove background).

### Complete Pipeline Example

```python
async def product_pipeline(api_key, product_descriptions, scene_prompt):
    """
    Pipeline: Generate product -> Remove background -> Place in lifestyle scene
    """
    async with aiohttp.ClientSession() as session:
        results = []

        for desc in product_descriptions:
            # Step 1: Generate product image
            gen_result = await generate_image(session, api_key,
                f"Professional product photo of {desc} on white background, studio lighting",
                aspect_ratio="1:1")
            product_url = await poll_status(session, api_key, gen_result["status_url"])

            # Step 2: Remove background
            async with session.post(
                "https://engine.prod.bria-api.com/v2/image/edit/remove_background",
                headers={"api_token": api_key, "Content-Type": "application/json"},
                json={"image": product_url}
            ) as resp:
                rmbg_result = await resp.json()
            transparent_url = await poll_status(session, api_key, rmbg_result["status_url"])

            # Step 3: Place in lifestyle scene
            async with session.post(
                "https://engine.prod.bria-api.com/v2/image/edit/lifestyle_shot_by_text",
                headers={"api_token": api_key, "Content-Type": "application/json"},
                json={"image": transparent_url, "prompt": scene_prompt}
            ) as resp:
                lifestyle_result = await resp.json()
            final_url = await poll_status(session, api_key, lifestyle_result["status_url"])

            results.append({
                "product": desc,
                "original": product_url,
                "transparent": transparent_url,
                "lifestyle": final_url
            })

        return results

# Usage
products = ["coffee mug", "water bottle", "notebook"]
scene = "modern minimalist desk, natural morning light, plants in background"
results = asyncio.run(product_pipeline("YOUR_API_KEY", products, scene))
```

### Parallel Pipeline (Advanced)

Process multiple products through the pipeline concurrently:

```python
async def parallel_pipeline(api_key, products, scene_prompt, max_concurrent=3):
    """Run full pipeline for multiple products in parallel."""
    semaphore = asyncio.Semaphore(max_concurrent)

    async def process_one(product):
        async with semaphore:
            return await single_product_pipeline(api_key, product, scene_prompt)

    return await asyncio.gather(*[process_one(p) for p in products], return_exceptions=True)
```

### Common Pipeline Patterns

| Pipeline | Steps | Use Case |
|----------|-------|----------|
| Product -> Transparent | generate -> remove_background | E-commerce cutouts |
| Product -> Lifestyle | generate -> remove_background -> lifestyle_shot | Marketing photos |
| Edit -> Upscale | edit -> increase_resolution | High-res edited images |
| Generate -> Restyle | generate -> restyle | Artistic variations |
| Generate -> Variations | generate (num_results=4) | A/B testing options |

---

## Integration Examples

### React/Next.js Component

```jsx
// Generate and display a hero image
const [imageUrl, setImageUrl] = useState(null);

async function generateHero(prompt) {
  const res = await fetch('/api/bria/generate', {
    method: 'POST',
    body: JSON.stringify({ prompt, aspect_ratio: '16:9' })
  });
  const { image_url } = await res.json();
  setImageUrl(image_url);
}
```

### Python Script for Batch Generation

```python
import asyncio

# See "Batch & Parallel Image Generation" section for generate_batch function

async def main():
    api_key = "YOUR_API_KEY"
    products = ["running shoes", "leather bag", "smart watch"]
    prompts = [f"Professional product photo of {p} on white background" for p in products]

    results = await generate_batch(api_key, prompts, aspect_ratio="1:1", max_concurrent=3)

    for product, result in zip(products, results):
        if isinstance(result, Exception):
            print(f"{product}: FAILED - {result}")
        else:
            print(f"{product}: {result}")

asyncio.run(main())
```

---

## Asset Generation Recipes

### Website Hero Images

```json
{
  "prompt": "Modern tech startup workspace with developers collaborating, bright natural lighting, clean minimal aesthetic",
  "aspect_ratio": "16:9",
  "negative_prompt": "cluttered, dark, low quality"
}
```

**Tips:**
- Use `16:9` for full-width banners
- Describe lighting and mood explicitly
- Include "professional", "high quality", "commercial" for polished results
- Specify "clean background" or "minimal" for text overlay space

### Product Photography

```json
{
  "prompt": "Professional product photo of [item] on white studio background, soft shadows, commercial photography lighting",
  "aspect_ratio": "1:1"
}
```

Then remove background for transparent PNG to composite anywhere.

### Presentation Visuals

```json
{
  "prompt": "Abstract visualization of data analytics, blue and purple gradient, modern corporate style, clean composition with space for text",
  "aspect_ratio": "16:9"
}
```

**Common themes:** "Abstract technology background", "Business team collaboration", "Growth chart visualization", "Minimalist geometric patterns"

### Social Media Assets

**Instagram post (1:1):**
```json
{
  "prompt": "Lifestyle photo of coffee and laptop on wooden desk, morning light, cozy atmosphere",
  "aspect_ratio": "1:1"
}
```

**Story/Reel (9:16):**
```json
{
  "prompt": "Vertical product showcase of smartphone, floating in gradient background, tech aesthetic",
  "aspect_ratio": "9:16"
}
```

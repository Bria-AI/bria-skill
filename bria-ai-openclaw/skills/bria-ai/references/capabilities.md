# Bria Capabilities Reference

## What You Can Build

- **E-commerce product catalog** — Generate product photos, remove backgrounds for transparent PNGs, place products in lifestyle scenes (kitchen, office, outdoor), create packshots with consistent style
- **Landing page visuals** — Generate hero images, abstract tech backgrounds, team photos, and section illustrations — all matching your brand aesthetic
- **Social media content** — Instagram posts (1:1), Stories/Reels (9:16), LinkedIn banners (16:9), ad creatives — batch-generate variants for A/B testing
- **Marketing campaign assets** — Seasonal transformations (summer→winter), restyle product shots for different markets, create localized visuals at scale
- **Photo restoration pipeline** — Restore old damaged photos, colorize black & white images, upscale low-res photos to 4x, enhance quality automatically
- **Brand asset toolkit** — Remove backgrounds from logos, blend artwork onto products (t-shirts, mugs), create consistent product photography across your entire catalog
- **AI-powered design workflows** — Chain operations: generate→edit→remove background→place in scene→upscale — all automated through API pipelines

---

## Full Capabilities Table

| Need | Capability | Endpoint |
|------|------------|----------|
| Generate images from text | FIBO Generate | `/v2/image/generate` |
| Edit images by text instruction | FIBO-Edit | `/v2/image/edit` |
| Edit image region with mask | GenFill/Erase | `/v2/image/edit/genfill` |
| Add/Replace/Remove objects | Text-based editing | `/v2/image/edit` |
| Remove background (transparent PNG) | RMBG-2.0 | `/v2/image/edit/remove_background` |
| Replace/blur/erase background | Background ops | `/v2/image/edit/replace_background` |
| Expand/outpaint images | Outpainting | `/v2/image/edit/increase_outpaint` |
| Upscale image resolution | Super Resolution | `/v2/image/edit/increase_resolution` |
| Enhance image quality | Enhancement | `/v2/image/edit/enhance` |
| Restyle images | Restyle | `/v2/image/edit/restyle` |
| Change lighting | Relight | `/v2/image/edit/relight` |
| Change season | Reseason | `/v2/image/edit/reseason` |
| Composite/blend images | Image Blending | `/v2/image/edit/blend` |
| Restore old photos | Restoration | `/v2/image/edit/restore` |
| Colorize images | Colorization | `/v2/image/edit/colorize` |
| Sketch to photo | Sketch2Image | `/v2/image/edit/sketch2image` |
| Create product lifestyle shots | Lifestyle Shot | `/v1/product/lifestyle_shot_by_text` |
| Integrate products into scenes | Product Integrate | `/v1/product/product_integrate` |

---

## Prompt Engineering Tips

- **Style**: "professional product photography" vs "casual snapshot", "flat design illustration" vs "3D rendered"
- **Lighting**: "soft natural light", "studio lighting", "dramatic shadows"
- **Background**: "white studio", "gradient", "blurred office", "transparent"
- **Composition**: "centered", "rule of thirds", "negative space on left for text"
- **Quality keywords**: "high quality", "professional", "commercial grade", "4K", "sharp focus"
- **Negative prompts**: "blurry, low quality, pixelated", "text, watermark, logo"

### Recipes by Use Case

**Hero banner (16:9):** `"Modern tech startup workspace with developers collaborating, bright natural lighting, clean minimal aesthetic"` — include "clean background" or "minimal" for text overlay space

**Product photo (1:1):** `"Professional product photo of [item] on white studio background, soft shadows, commercial photography lighting"` — then remove background for transparent PNG

**Presentation visual (16:9):** `"Abstract visualization of data analytics, blue and purple gradient, modern corporate style, clean composition with space for text"` — common themes: "abstract technology", "business collaboration", "minimalist geometric patterns"

**Instagram post (1:1):** `"Lifestyle photo of coffee and laptop on wooden desk, morning light, cozy atmosphere"`

**Story/Reel (9:16):** `"Vertical product showcase of smartphone, floating in gradient background, tech aesthetic"`

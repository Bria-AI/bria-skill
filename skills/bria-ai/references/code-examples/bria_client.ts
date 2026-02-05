/**
 * Bria Visual Asset Generator
 *
 * Generate production-ready visual assets for websites, presentations,
 * documents, and applications using Bria's AI models.
 *
 * Usage:
 *    import { BriaClient } from './bria_client';
 *
 *    const client = new BriaClient();
 *
 *    // Generate hero image for website
 *    const result = await client.generate("Modern office workspace, natural lighting", { aspectRatio: "16:9" });
 *
 *    // Remove background for transparent PNG
 *    const result = await client.removeBackground(imageUrl);
 *
 *    // Edit specific region
 *    const result = await client.genFill(imageUrl, maskUrl, "red leather chair");
 */

// ==================== Types ====================

export interface BriaResponse {
  status: "IN_PROGRESS" | "COMPLETED" | "FAILED";
  status_url?: string;
  result?: {
    image_url?: string;
    image_urls?: string[];
    structured_prompt?: string;
    structured_instruction?: string;
  };
  error?: string;
}

export interface GenerateOptions {
  aspectRatio?: "1:1" | "4:3" | "16:9" | "3:4" | "9:16";
  negativePrompt?: string;
  numResults?: number;
  seed?: number;
  wait?: boolean;
}

export interface GenFillOptions {
  maskType?: "manual" | "automatic";
  negativePrompt?: string;
  wait?: boolean;
}

export interface ExpandOptions {
  aspectRatio?: "1:1" | "4:3" | "16:9" | "3:4" | "9:16";
  prompt?: string;
  wait?: boolean;
}

export interface LifeshotOptions {
  placementType?: "automatic" | "manual";
  wait?: boolean;
}

export interface RestyleOptions {
  style:
    | "render_3d"
    | "cubism"
    | "oil_painting"
    | "anime"
    | "cartoon"
    | "coloring_book"
    | "retro_ad"
    | "pop_art_halftone"
    | "vector_art"
    | "story_board"
    | "art_nouveau"
    | "cross_etching"
    | "wood_cut"
    | string;
  wait?: boolean;
}

export interface ColorizeOptions {
  style?: "color_contemporary" | "bw" | string;
  wait?: boolean;
}

// ==================== Client ====================

export class BriaClient {
  private readonly baseUrl = "https://engine.prod.bria-api.com";
  private readonly apiKey: string;

  /**
   * Initialize the Bria client.
   * @param apiKey - Bria API key. Reads from BRIA_API_KEY env var if not provided.
   */
  constructor(apiKey?: string) {
    this.apiKey = apiKey || process.env.BRIA_API_KEY || "";
    if (!this.apiKey) {
      throw new Error("API key required. Set BRIA_API_KEY or pass apiKey.");
    }
  }

  private headers(): Record<string, string> {
    return {
      api_token: this.apiKey,
      "Content-Type": "application/json",
    };
  }

  private async request(
    endpoint: string,
    data: Record<string, unknown>,
    wait = true
  ): Promise<BriaResponse> {
    const url = `${this.baseUrl}${endpoint}`;
    const response = await fetch(url, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result: BriaResponse = await response.json();

    if (wait && result.status_url) {
      return this.poll(result.status_url);
    }
    return result;
  }

  private async poll(statusUrl: string, timeout = 120): Promise<BriaResponse> {
    const maxAttempts = Math.floor(timeout / 2);

    for (let i = 0; i < maxAttempts; i++) {
      const response = await fetch(statusUrl, {
        method: "GET",
        headers: this.headers(),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data: BriaResponse = await response.json();

      if (data.status === "COMPLETED") {
        return data;
      } else if (data.status === "FAILED") {
        throw new Error(`Request failed: ${data.error || "Unknown"}`);
      }

      await new Promise((resolve) => setTimeout(resolve, 2000));
    }

    throw new Error("Request timed out");
  }

  // ==================== FIBO - Image Generation ====================

  /**
   * Generate images from text prompt.
   * @param prompt - Description of desired image
   * @param options - Generation options
   * @returns Response with image_url and structured_prompt
   */
  async generate(
    prompt: string,
    options: GenerateOptions = {}
  ): Promise<BriaResponse> {
    const {
      aspectRatio = "1:1",
      negativePrompt,
      numResults = 1,
      seed,
      wait = true,
    } = options;

    const data: Record<string, unknown> = {
      prompt,
      aspect_ratio: aspectRatio,
      num_results: numResults,
    };
    if (negativePrompt) data.negative_prompt = negativePrompt;
    if (seed !== undefined) data.seed = seed;

    return this.request("/v2/image/generate", data, wait);
  }

  /**
   * Refine a previous generation with modifications.
   * @param structuredPrompt - JSON from previous generation
   * @param instruction - What to change (e.g., "warmer lighting")
   * @param aspectRatio - Output aspect ratio
   * @param wait - Wait for completion
   * @returns Response with refined image_url
   */
  async refine(
    structuredPrompt: string,
    instruction: string,
    aspectRatio = "1:1",
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/generate",
      {
        structured_prompt: structuredPrompt,
        prompt: instruction,
        aspect_ratio: aspectRatio,
      },
      wait
    );
  }

  /**
   * Generate variations inspired by a reference image.
   * @param imageUrl - Reference image URL
   * @param prompt - Creative direction
   * @param aspectRatio - Output aspect ratio
   * @param wait - Wait for completion
   * @returns Response with image_url
   */
  async inspire(
    imageUrl: string,
    prompt: string,
    aspectRatio = "1:1",
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/generate",
      {
        image_url: imageUrl,
        prompt,
        aspect_ratio: aspectRatio,
      },
      wait
    );
  }

  // ==================== RMBG-2.0 - Background Removal ====================

  /**
   * Remove background from image.
   * @param imageUrl - Source image URL
   * @param wait - Wait for completion
   * @returns Response with transparent PNG image_url
   */
  async removeBackground(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/remove_background", { image: imageUrl }, wait);
  }

  // ==================== FIBO-Edit - Image Editing ====================

  /**
   * Generate content in masked region (inpainting).
   * @param imageUrl - Source image URL
   * @param maskUrl - Mask URL (white=edit, black=keep)
   * @param prompt - What to generate
   * @param options - Gen fill options
   * @returns Response with edited image_url
   */
  async genFill(
    imageUrl: string,
    maskUrl: string,
    prompt: string,
    options: GenFillOptions = {}
  ): Promise<BriaResponse> {
    const { maskType = "manual", negativePrompt, wait = true } = options;

    const data: Record<string, unknown> = {
      image: imageUrl,
      mask: maskUrl,
      prompt,
      mask_type: maskType,
    };
    if (negativePrompt) data.negative_prompt = negativePrompt;

    return this.request("/v2/image/edit/gen_fill", data, wait);
  }

  /**
   * Erase objects defined by mask.
   * @param imageUrl - Source image URL
   * @param maskUrl - Mask URL (white=erase)
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async erase(
    imageUrl: string,
    maskUrl: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/erase",
      { image: imageUrl, mask: maskUrl },
      wait
    );
  }

  /**
   * Remove primary subject and fill background.
   * @param imageUrl - Source image URL
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async eraseForeground(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/erase_foreground", { image: imageUrl }, wait);
  }

  /**
   * Replace background with AI-generated content.
   * @param imageUrl - Source image URL
   * @param prompt - New background description
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async replaceBackground(
    imageUrl: string,
    prompt: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/replace_background",
      { image: imageUrl, prompt },
      wait
    );
  }

  /**
   * Expand/outpaint an image to extend its boundaries.
   * @param imageUrl - Source image URL or base64 string
   * @param options - Expand options
   * @returns Response with expanded image_url
   */
  async expandImage(
    imageUrl: string,
    options: ExpandOptions = {}
  ): Promise<BriaResponse> {
    const { aspectRatio = "16:9", prompt, wait = true } = options;

    const data: Record<string, unknown> = {
      image: imageUrl,
      aspect_ratio: aspectRatio,
    };
    if (prompt) data.prompt = prompt;

    return this.request("/v2/image/edit/expand", data, wait);
  }

  /**
   * Enhance image quality (lighting, colors, details).
   * @param imageUrl - Source image URL
   * @param wait - Wait for completion
   * @returns Response with enhanced image_url
   */
  async enhanceImage(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/enhance", { image: imageUrl }, wait);
  }

  /**
   * Upscale image resolution.
   * @param imageUrl - Source image URL
   * @param scale - Upscale factor (2 or 4)
   * @param wait - Wait for completion
   * @returns Response with upscaled image_url
   */
  async increaseResolution(
    imageUrl: string,
    scale: 2 | 4 = 2,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/increase_resolution",
      { image: imageUrl, scale },
      wait
    );
  }

  /**
   * Place a product in a lifestyle scene using text description.
   * @param imageUrl - Product image URL (ideally with transparent background)
   * @param prompt - Scene description (e.g., "modern kitchen countertop")
   * @param options - Lifestyle shot options
   * @returns Response with lifestyle shot image_url
   */
  async lifestyleShot(
    imageUrl: string,
    prompt: string,
    options: LifeshotOptions = {}
  ): Promise<BriaResponse> {
    const { placementType = "automatic", wait = true } = options;

    return this.request(
      "/v2/image/edit/lifestyle_shot_by_text",
      {
        image: imageUrl,
        prompt,
        placement_type: placementType,
      },
      wait
    );
  }

  /**
   * Place a product on a reference background image.
   * @param imageUrl - Product image URL
   * @param backgroundUrl - Background reference image URL
   * @param options - Shot by image options
   * @returns Response with composited image_url
   */
  async shotByImage(
    imageUrl: string,
    backgroundUrl: string,
    options: LifeshotOptions = {}
  ): Promise<BriaResponse> {
    const { placementType = "automatic", wait = true } = options;

    return this.request(
      "/v2/image/edit/shot_by_image",
      {
        image: imageUrl,
        background: backgroundUrl,
        placement_type: placementType,
      },
      wait
    );
  }

  /**
   * Apply blur effect to image background.
   * @param imageUrl - Source image URL
   * @param wait - Wait for completion
   * @returns Response with blurred background image_url
   */
  async blurBackground(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/blur_background", { image: imageUrl }, wait);
  }

  /**
   * Edit an image using natural language instructions.
   * @param imageUrl - Source image URL or base64 data URL
   * @param instruction - Edit instruction (e.g., "change the mug to red")
   * @param maskUrl - Optional mask for localized editing (white=edit, black=keep)
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async editImage(
    imageUrl: string,
    instruction: string,
    maskUrl?: string,
    wait = true
  ): Promise<BriaResponse> {
    const data: Record<string, unknown> = {
      images: [imageUrl],
      instruction,
    };
    if (maskUrl) data.mask = maskUrl;

    return this.request("/v2/image/edit", data, wait);
  }

  // ==================== Text-Based Object Editing ====================

  /**
   * Add a new object to an image using natural language.
   * @param imageUrl - Source image URL or base64
   * @param instruction - What and where to add (e.g., "Place a red vase on the table")
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async addObject(
    imageUrl: string,
    instruction: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/add_object_by_text",
      { image: imageUrl, instruction },
      wait
    );
  }

  /**
   * Replace an existing object with a new one using natural language.
   * @param imageUrl - Source image URL or base64
   * @param instruction - What to replace (e.g., "Replace the red apple with a green pear")
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async replaceObject(
    imageUrl: string,
    instruction: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/replace_object_by_text",
      { image: imageUrl, instruction },
      wait
    );
  }

  /**
   * Remove a specific object from an image using its name.
   * @param imageUrl - Source image URL or base64
   * @param objectName - Name of object to remove (e.g., "table", "person")
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async eraseObject(
    imageUrl: string,
    objectName: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/erase_by_text",
      { image: imageUrl, object_name: objectName },
      wait
    );
  }

  // ==================== Image Transformation ====================

  /**
   * Blend/merge objects or apply textures using natural language.
   * @param imageUrl - Base image URL or base64
   * @param overlayUrl - Overlay image (e.g., texture, logo, art)
   * @param instruction - How to blend (e.g., "Place the art on the shirt")
   * @param wait - Wait for completion
   * @returns Response with blended image_url
   */
  async blendImages(
    imageUrl: string,
    overlayUrl: string,
    instruction: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/blend",
      { image: imageUrl, overlay: overlayUrl, instruction },
      wait
    );
  }

  /**
   * Change the season or weather atmosphere of an image.
   * @param imageUrl - Source image URL or base64
   * @param season - Target season ("spring", "summer", "autumn", "winter")
   * @param wait - Wait for completion
   * @returns Response with reseasoned image_url
   */
  async reseason(
    imageUrl: string,
    season: "spring" | "summer" | "autumn" | "winter",
    wait = true
  ): Promise<BriaResponse> {
    return this.request("/v2/image/edit/reseason", { image: imageUrl, season }, wait);
  }

  /**
   * Transform the artistic style of an image.
   * @param imageUrl - Source image URL or base64
   * @param options - Restyle options with style ID
   * @returns Response with restyled image_url
   */
  async restyle(
    imageUrl: string,
    options: RestyleOptions
  ): Promise<BriaResponse> {
    const { style, wait = true } = options;
    return this.request("/v2/image/edit/restyle", { image: imageUrl, style }, wait);
  }

  /**
   * Modify the lighting setup of an image.
   * @param imageUrl - Source image URL or base64
   * @param lightType - Lighting description (e.g., "spotlight on subject", "golden hour")
   * @param wait - Wait for completion
   * @returns Response with relit image_url
   */
  async relight(
    imageUrl: string,
    lightType: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/relight",
      { image: imageUrl, light_type: lightType },
      wait
    );
  }

  // ==================== Text in Images ====================

  /**
   * Replace existing text in an image with new text.
   * @param imageUrl - Source image URL or base64
   * @param newText - The new text to display
   * @param wait - Wait for completion
   * @returns Response with edited image_url
   */
  async replaceText(
    imageUrl: string,
    newText: string,
    wait = true
  ): Promise<BriaResponse> {
    return this.request(
      "/v2/image/edit/replace_text",
      { image: imageUrl, new_text: newText },
      wait
    );
  }

  // ==================== Image Restoration & Conversion ====================

  /**
   * Convert a sketch or line drawing to a photorealistic image.
   * @param imageUrl - Sketch image URL or base64
   * @param prompt - Optional description to guide the conversion
   * @param wait - Wait for completion
   * @returns Response with realistic image_url
   */
  async sketchToImage(
    imageUrl: string,
    prompt?: string,
    wait = true
  ): Promise<BriaResponse> {
    const data: Record<string, unknown> = { image: imageUrl };
    if (prompt) data.prompt = prompt;

    return this.request("/v2/image/edit/sketch_to_image", data, wait);
  }

  /**
   * Restore old/damaged photos by removing noise, scratches, and blur.
   * @param imageUrl - Old photo URL or base64
   * @param wait - Wait for completion
   * @returns Response with restored image_url
   */
  async restoreImage(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/restore", { image: imageUrl }, wait);
  }

  /**
   * Add color to B&W photos or convert to B&W.
   * @param imageUrl - Source image URL or base64
   * @param options - Colorize options
   * @returns Response with colorized image_url
   */
  async colorize(
    imageUrl: string,
    options: ColorizeOptions = {}
  ): Promise<BriaResponse> {
    const { style = "color_contemporary", wait = true } = options;
    return this.request("/v2/image/edit/colorize", { image: imageUrl, style }, wait);
  }

  /**
   * Remove background and crop tightly around the foreground subject.
   * @param imageUrl - Source image URL or base64
   * @param wait - Wait for completion
   * @returns Response with cropped image_url
   */
  async cropForeground(imageUrl: string, wait = true): Promise<BriaResponse> {
    return this.request("/v2/image/edit/crop_foreground", { image: imageUrl }, wait);
  }

  // ==================== Structured Instructions ====================

  /**
   * Generate a structured JSON instruction from natural language.
   * Useful for inspection, editing, or reuse before actual image generation.
   * @param imageUrl - Source image URL or base64
   * @param instruction - Edit instruction in natural language
   * @param maskUrl - Optional mask for masked instruction
   * @param wait - Wait for completion
   * @returns Response with structured_instruction JSON
   */
  async generateStructuredInstruction(
    imageUrl: string,
    instruction: string,
    maskUrl?: string,
    wait = true
  ): Promise<BriaResponse> {
    const data: Record<string, unknown> = {
      images: [imageUrl],
      instruction,
    };
    if (maskUrl) data.mask = maskUrl;

    return this.request("/v2/structured_instruction/generate", data, wait);
  }
}

// ==================== CLI Examples ====================

async function main() {
  const client = new BriaClient();

  console.log("=== Generate Website Hero Image ===");
  const heroResult = await client.generate(
    "Modern tech startup office, developers collaborating, bright natural light, minimal clean aesthetic",
    {
      aspectRatio: "16:9",
      negativePrompt: "cluttered, dark, low quality",
    }
  );
  console.log(`Hero image: ${heroResult.result?.image_url}`);

  console.log("\n=== Generate Product Photo ===");
  const productResult = await client.generate(
    "Professional product photo of wireless headphones on white studio background, soft shadows",
    { aspectRatio: "1:1" }
  );
  const productUrl = productResult.result?.image_url || "";
  console.log(`Product photo: ${productUrl}`);

  console.log("\n=== Remove Background ===");
  const bgResult = await client.removeBackground(productUrl);
  console.log(`Transparent PNG: ${bgResult.result?.image_url}`);
}

// Run if executed directly
if (require.main === module) {
  main().catch(console.error);
}

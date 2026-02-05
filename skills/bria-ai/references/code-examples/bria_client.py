#!/usr/bin/env python3
"""
Bria Visual Asset Generator

Generate production-ready visual assets for websites, presentations,
documents, and applications using Bria's AI models.

Usage:
    from bria_client import BriaClient

    client = BriaClient()

    # Generate hero image for website
    result = client.generate("Modern office workspace, natural lighting", aspect_ratio="16:9")

    # Remove background for transparent PNG
    result = client.remove_background(image_url)

    # Edit specific region
    result = client.gen_fill(image_url, mask_url, "red leather chair")
"""

import os
import time
import requests
from typing import Optional, Dict, Any


class BriaClient:
    """Client for Bria.ai Visual Asset Generation APIs."""

    BASE_URL = "https://engine.prod.bria-api.com"

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize the Bria client.

        Args:
            api_key: Bria API key. Reads from BRIA_API_KEY env var if not provided.
        """
        self.api_key = api_key or os.environ.get("BRIA_API_KEY")
        if not self.api_key:
            raise ValueError("API key required. Set BRIA_API_KEY or pass api_key.")

    def _headers(self) -> Dict[str, str]:
        return {
            "api_token": self.api_key,
            "Content-Type": "application/json"
        }

    def _request(self, endpoint: str, data: Dict, wait: bool = True) -> Dict[str, Any]:
        """Make API request with optional polling."""
        url = f"{self.BASE_URL}{endpoint}"
        response = requests.post(url, json=data, headers=self._headers())
        response.raise_for_status()
        result = response.json()

        if wait and "status_url" in result:
            return self._poll(result["status_url"])
        return result

    def _poll(self, status_url: str, timeout: int = 120) -> Dict[str, Any]:
        """Poll status URL until completion."""
        for _ in range(timeout // 2):
            response = requests.get(status_url, headers=self._headers())
            response.raise_for_status()
            data = response.json()

            if data["status"] == "COMPLETED":
                return data
            elif data["status"] == "FAILED":
                raise Exception(f"Request failed: {data.get('error', 'Unknown')}")

            time.sleep(2)

        raise TimeoutError("Request timed out")

    # ==================== FIBO - Image Generation ====================

    def generate(
        self,
        prompt: str,
        aspect_ratio: str = "1:1",
        negative_prompt: Optional[str] = None,
        num_results: int = 1,
        seed: Optional[int] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Generate images from text prompt.

        Args:
            prompt: Description of desired image
            aspect_ratio: "1:1", "4:3", "16:9", "3:4", "9:16"
            negative_prompt: What to exclude
            num_results: Number of images (1-4)
            seed: For reproducibility
            wait: Wait for completion

        Returns:
            Dict with image_url and structured_prompt
        """
        data = {"prompt": prompt, "aspect_ratio": aspect_ratio, "num_results": num_results}
        if negative_prompt:
            data["negative_prompt"] = negative_prompt
        if seed is not None:
            data["seed"] = seed

        return self._request("/v2/image/generate", data, wait)

    def refine(
        self,
        structured_prompt: str,
        instruction: str,
        aspect_ratio: str = "1:1",
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Refine a previous generation with modifications.

        Args:
            structured_prompt: JSON from previous generation
            instruction: What to change (e.g., "warmer lighting")
            aspect_ratio: Output aspect ratio
            wait: Wait for completion

        Returns:
            Dict with refined image_url
        """
        data = {
            "structured_prompt": structured_prompt,
            "prompt": instruction,
            "aspect_ratio": aspect_ratio
        }
        return self._request("/v2/image/generate", data, wait)

    def inspire(
        self,
        image_url: str,
        prompt: str,
        aspect_ratio: str = "1:1",
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Generate variations inspired by a reference image.

        Args:
            image_url: Reference image URL
            prompt: Creative direction
            aspect_ratio: Output aspect ratio
            wait: Wait for completion

        Returns:
            Dict with image_url
        """
        data = {"image_url": image_url, "prompt": prompt, "aspect_ratio": aspect_ratio}
        return self._request("/v2/image/generate", data, wait)

    # ==================== RMBG-2.0 - Background Removal ====================

    def remove_background(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Remove background from image.

        Args:
            image_url: Source image URL
            wait: Wait for completion

        Returns:
            Dict with transparent PNG image_url
        """
        return self._request("/v2/image/edit/remove_background", {"image": image_url}, wait)

    # ==================== FIBO-Edit - Image Editing ====================

    def gen_fill(
        self,
        image_url: str,
        mask_url: str,
        prompt: str,
        mask_type: str = "manual",
        negative_prompt: Optional[str] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Generate content in masked region (inpainting).

        Args:
            image_url: Source image URL
            mask_url: Mask URL (white=edit, black=keep)
            prompt: What to generate
            mask_type: "manual" or "automatic"
            negative_prompt: What to avoid
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        data = {
            "image": image_url,
            "mask": mask_url,
            "prompt": prompt,
            "mask_type": mask_type
        }
        if negative_prompt:
            data["negative_prompt"] = negative_prompt

        return self._request("/v2/image/edit/gen_fill", data, wait)

    def erase(self, image_url: str, mask_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Erase objects defined by mask.

        Args:
            image_url: Source image URL
            mask_url: Mask URL (white=erase)
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/erase", {"image": image_url, "mask": mask_url}, wait)

    def erase_foreground(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Remove primary subject and fill background.

        Args:
            image_url: Source image URL
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/erase_foreground", {"image": image_url}, wait)

    def replace_background(
        self,
        image_url: str,
        prompt: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Replace background with AI-generated content.

        Args:
            image_url: Source image URL
            prompt: New background description
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/replace_background", {"image": image_url, "prompt": prompt}, wait)

    def expand_image(
        self,
        image_url: str,
        aspect_ratio: str = "16:9",
        prompt: Optional[str] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Expand/outpaint an image to extend its boundaries.

        Args:
            image_url: Source image URL or base64 string
            aspect_ratio: Target aspect ratio ("1:1", "4:3", "16:9", "3:4", "9:16")
            prompt: Optional description for generated content
            wait: Wait for completion

        Returns:
            Dict with expanded image_url
        """
        data = {"image": image_url, "aspect_ratio": aspect_ratio}
        if prompt:
            data["prompt"] = prompt
        return self._request("/v2/image/edit/expand", data, wait)

    def enhance_image(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Enhance image quality (lighting, colors, details).

        Args:
            image_url: Source image URL
            wait: Wait for completion

        Returns:
            Dict with enhanced image_url
        """
        return self._request("/v2/image/edit/enhance", {"image": image_url}, wait)

    def increase_resolution(
        self,
        image_url: str,
        scale: int = 2,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Upscale image resolution.

        Args:
            image_url: Source image URL
            scale: Upscale factor (2 or 4)
            wait: Wait for completion

        Returns:
            Dict with upscaled image_url
        """
        return self._request("/v2/image/edit/increase_resolution", {"image": image_url, "scale": scale}, wait)

    def lifestyle_shot(
        self,
        image_url: str,
        prompt: str,
        placement_type: str = "automatic",
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Place a product in a lifestyle scene using text description.

        Args:
            image_url: Product image URL (ideally with transparent background)
            prompt: Scene description (e.g., "modern kitchen countertop")
            placement_type: "automatic" or "manual"
            wait: Wait for completion

        Returns:
            Dict with lifestyle shot image_url
        """
        return self._request("/v2/image/edit/lifestyle_shot_by_text", {
            "image": image_url,
            "prompt": prompt,
            "placement_type": placement_type
        }, wait)

    def shot_by_image(
        self,
        image_url: str,
        background_url: str,
        placement_type: str = "automatic",
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Place a product on a reference background image.

        Args:
            image_url: Product image URL
            background_url: Background reference image URL
            placement_type: "automatic" or "manual"
            wait: Wait for completion

        Returns:
            Dict with composited image_url
        """
        return self._request("/v2/image/edit/shot_by_image", {
            "image": image_url,
            "background": background_url,
            "placement_type": placement_type
        }, wait)

    def blur_background(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Apply blur effect to image background.

        Args:
            image_url: Source image URL
            wait: Wait for completion

        Returns:
            Dict with blurred background image_url
        """
        return self._request("/v2/image/edit/blur_background", {"image": image_url}, wait)

    def edit_image(
        self,
        image_url: str,
        instruction: str,
        mask_url: Optional[str] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Edit an image using natural language instructions.

        Args:
            image_url: Source image URL or base64 data URL
            instruction: Edit instruction (e.g., "change the mug to red")
            mask_url: Optional mask for localized editing (white=edit, black=keep)
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        data = {"images": [image_url], "instruction": instruction}
        if mask_url:
            data["mask"] = mask_url
        return self._request("/v2/image/edit", data, wait)

    # ==================== Text-Based Object Editing ====================

    def add_object(
        self,
        image_url: str,
        instruction: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Add a new object to an image using natural language.

        Args:
            image_url: Source image URL or base64
            instruction: What and where to add (e.g., "Place a red vase on the table")
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/add_object_by_text", {
            "image": image_url,
            "instruction": instruction
        }, wait)

    def replace_object(
        self,
        image_url: str,
        instruction: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Replace an existing object with a new one using natural language.

        Args:
            image_url: Source image URL or base64
            instruction: What to replace (e.g., "Replace the red apple with a green pear")
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/replace_object_by_text", {
            "image": image_url,
            "instruction": instruction
        }, wait)

    def erase_object(
        self,
        image_url: str,
        object_name: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Remove a specific object from an image using its name.

        Args:
            image_url: Source image URL or base64
            object_name: Name of object to remove (e.g., "table", "person")
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/erase_by_text", {
            "image": image_url,
            "object_name": object_name
        }, wait)

    # ==================== Image Transformation ====================

    def blend_images(
        self,
        image_url: str,
        overlay_url: str,
        instruction: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Blend/merge objects or apply textures using natural language.

        Args:
            image_url: Base image URL or base64
            overlay_url: Overlay image (e.g., texture, logo, art)
            instruction: How to blend (e.g., "Place the art on the shirt")
            wait: Wait for completion

        Returns:
            Dict with blended image_url
        """
        return self._request("/v2/image/edit/blend", {
            "image": image_url,
            "overlay": overlay_url,
            "instruction": instruction
        }, wait)

    def reseason(
        self,
        image_url: str,
        season: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Change the season or weather atmosphere of an image.

        Args:
            image_url: Source image URL or base64
            season: Target season ("spring", "summer", "autumn", "winter")
            wait: Wait for completion

        Returns:
            Dict with reseasoned image_url
        """
        return self._request("/v2/image/edit/reseason", {
            "image": image_url,
            "season": season
        }, wait)

    def restyle(
        self,
        image_url: str,
        style: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Transform the artistic style of an image.

        Args:
            image_url: Source image URL or base64
            style: Style ID or description. Supported IDs:
                   "render_3d", "cubism", "oil_painting", "anime", "cartoon",
                   "coloring_book", "retro_ad", "pop_art_halftone", "vector_art",
                   "story_board", "art_nouveau", "cross_etching", "wood_cut"
            wait: Wait for completion

        Returns:
            Dict with restyled image_url
        """
        return self._request("/v2/image/edit/restyle", {
            "image": image_url,
            "style": style
        }, wait)

    def relight(
        self,
        image_url: str,
        light_type: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Modify the lighting setup of an image.

        Args:
            image_url: Source image URL or base64
            light_type: Lighting description (e.g., "spotlight on subject",
                        "golden hour", "dramatic side lighting")
            wait: Wait for completion

        Returns:
            Dict with relit image_url
        """
        return self._request("/v2/image/edit/relight", {
            "image": image_url,
            "light_type": light_type
        }, wait)

    # ==================== Text in Images ====================

    def replace_text(
        self,
        image_url: str,
        new_text: str,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Replace existing text in an image with new text.

        Args:
            image_url: Source image URL or base64
            new_text: The new text to display
            wait: Wait for completion

        Returns:
            Dict with edited image_url
        """
        return self._request("/v2/image/edit/replace_text", {
            "image": image_url,
            "new_text": new_text
        }, wait)

    # ==================== Image Restoration & Conversion ====================

    def sketch_to_image(
        self,
        image_url: str,
        prompt: Optional[str] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Convert a sketch or line drawing to a photorealistic image.

        Args:
            image_url: Sketch image URL or base64
            prompt: Optional description to guide the conversion
            wait: Wait for completion

        Returns:
            Dict with realistic image_url
        """
        data = {"image": image_url}
        if prompt:
            data["prompt"] = prompt
        return self._request("/v2/image/edit/sketch_to_image", data, wait)

    def restore_image(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Restore old/damaged photos by removing noise, scratches, and blur.

        Args:
            image_url: Old photo URL or base64
            wait: Wait for completion

        Returns:
            Dict with restored image_url
        """
        return self._request("/v2/image/edit/restore", {"image": image_url}, wait)

    def colorize(
        self,
        image_url: str,
        style: str = "color_contemporary",
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Add color to B&W photos or convert to B&W.

        Args:
            image_url: Source image URL or base64
            style: Colorization style (e.g., "color_contemporary", "bw")
            wait: Wait for completion

        Returns:
            Dict with colorized image_url
        """
        return self._request("/v2/image/edit/colorize", {
            "image": image_url,
            "style": style
        }, wait)

    def crop_foreground(self, image_url: str, wait: bool = True) -> Dict[str, Any]:
        """
        Remove background and crop tightly around the foreground subject.

        Args:
            image_url: Source image URL or base64
            wait: Wait for completion

        Returns:
            Dict with cropped image_url
        """
        return self._request("/v2/image/edit/crop_foreground", {"image": image_url}, wait)

    # ==================== Structured Instructions ====================

    def generate_structured_instruction(
        self,
        image_url: str,
        instruction: str,
        mask_url: Optional[str] = None,
        wait: bool = True
    ) -> Dict[str, Any]:
        """
        Generate a structured JSON instruction from natural language.
        Useful for inspection, editing, or reuse before actual image generation.

        Args:
            image_url: Source image URL or base64
            instruction: Edit instruction in natural language
            mask_url: Optional mask for masked instruction
            wait: Wait for completion

        Returns:
            Dict with structured_instruction JSON
        """
        data = {"images": [image_url], "instruction": instruction}
        if mask_url:
            data["mask"] = mask_url
        return self._request("/v2/structured_instruction/generate", data, wait)


# ==================== CLI Examples ====================

if __name__ == "__main__":
    client = BriaClient()

    print("=== Generate Website Hero Image ===")
    result = client.generate(
        prompt="Modern tech startup office, developers collaborating, bright natural light, minimal clean aesthetic",
        aspect_ratio="16:9",
        negative_prompt="cluttered, dark, low quality"
    )
    print(f"Hero image: {result['result']['image_url']}")

    print("\n=== Generate Product Photo ===")
    result = client.generate(
        prompt="Professional product photo of wireless headphones on white studio background, soft shadows",
        aspect_ratio="1:1"
    )
    product_url = result['result']['image_url']
    print(f"Product photo: {product_url}")

    print("\n=== Remove Background ===")
    result = client.remove_background(product_url)
    print(f"Transparent PNG: {result['result']['image_url']}")

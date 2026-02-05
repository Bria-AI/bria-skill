#!/usr/bin/env python3
"""
Classic Image Manipulation Utilities

Pillow-based utilities for deterministic pixel-level operations that complement
Bria's AI-powered transformations. Use for resize, crop, composite, format
conversion, and other standard image processing tasks.

Usage:
    from image_utils import ImageUtils

    # Load from URL and resize
    image = ImageUtils.load_from_url("https://example.com/image.jpg")
    resized = ImageUtils.resize(image, width=800, height=600)
    ImageUtils.save(resized, "output.webp", quality=90)

    # Pipeline with Bria
    result = bria_client.generate("product photo", aspect_ratio="1:1")
    image = ImageUtils.load_from_url(result['result']['image_url'])
    final = ImageUtils.resize(image, width=800, height=800)
    ImageUtils.save(final, "product.webp")
"""

import io
import base64
import requests
from pathlib import Path
from typing import Union, Optional, Tuple, Dict, Any

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance


class ImageUtils:
    """Classic image manipulation utilities using Pillow/PIL."""

    # ==================== Loading & Saving ====================

    @staticmethod
    def load(source: Union[str, bytes, Path]) -> Image.Image:
        """
        Load image from URL, file path, bytes, or base64 string.

        Args:
            source: URL string, file path, Path object, bytes, or base64 string

        Returns:
            PIL Image object

        Examples:
            image = ImageUtils.load("https://example.com/image.jpg")
            image = ImageUtils.load("/path/to/image.png")
            image = ImageUtils.load(image_bytes)
            image = ImageUtils.load("data:image/png;base64,...")
        """
        # Handle bytes directly
        if isinstance(source, bytes):
            return Image.open(io.BytesIO(source))

        # Handle Path objects
        if isinstance(source, Path):
            return Image.open(source)

        # Handle strings
        if isinstance(source, str):
            # Base64 data URL
            if source.startswith("data:image"):
                # Extract base64 portion after comma
                base64_data = source.split(",", 1)[1]
                image_bytes = base64.b64decode(base64_data)
                return Image.open(io.BytesIO(image_bytes))

            # Plain base64 string (no data URL prefix)
            if len(source) > 200 and not source.startswith(("http://", "https://", "/")):
                try:
                    image_bytes = base64.b64decode(source)
                    return Image.open(io.BytesIO(image_bytes))
                except Exception:
                    pass  # Not valid base64, try as path

            # URL
            if source.startswith(("http://", "https://")):
                return ImageUtils.load_from_url(source)

            # File path
            return Image.open(source)

        raise ValueError(f"Unsupported source type: {type(source)}")

    @staticmethod
    def load_from_url(url: str, timeout: int = 30) -> Image.Image:
        """
        Download and load image from URL.

        Args:
            url: Image URL
            timeout: Request timeout in seconds

        Returns:
            PIL Image object
        """
        response = requests.get(url, timeout=timeout)
        response.raise_for_status()
        return Image.open(io.BytesIO(response.content))

    @staticmethod
    def save(
        image: Image.Image,
        path: Union[str, Path],
        quality: int = 95,
        optimize: bool = True
    ) -> None:
        """
        Save image to file with format auto-detection from extension.

        Args:
            image: PIL Image to save
            path: Output file path (format detected from extension)
            quality: Quality for lossy formats (1-100)
            optimize: Enable optimization for smaller file size

        Examples:
            ImageUtils.save(image, "output.png")
            ImageUtils.save(image, "output.jpg", quality=85)
            ImageUtils.save(image, "output.webp", quality=90)
        """
        path = Path(path)
        ext = path.suffix.lower()

        # Ensure directory exists
        path.parent.mkdir(parents=True, exist_ok=True)

        # Convert to appropriate mode for format
        save_image = image
        if ext in (".jpg", ".jpeg"):
            if image.mode in ("RGBA", "LA", "P"):
                save_image = image.convert("RGB")

        # Save with format-specific options
        save_kwargs = {"optimize": optimize}
        if ext in (".jpg", ".jpeg", ".webp"):
            save_kwargs["quality"] = quality

        save_image.save(path, **save_kwargs)

    @staticmethod
    def to_bytes(
        image: Image.Image,
        format: str = "PNG",
        quality: int = 95
    ) -> bytes:
        """
        Convert image to bytes.

        Args:
            image: PIL Image
            format: Output format (PNG, JPEG, WEBP)
            quality: Quality for lossy formats

        Returns:
            Image as bytes
        """
        buffer = io.BytesIO()

        save_image = image
        if format.upper() == "JPEG" and image.mode in ("RGBA", "LA", "P"):
            save_image = image.convert("RGB")

        save_kwargs = {}
        if format.upper() in ("JPEG", "WEBP"):
            save_kwargs["quality"] = quality

        save_image.save(buffer, format=format, **save_kwargs)
        return buffer.getvalue()

    @staticmethod
    def to_base64(
        image: Image.Image,
        format: str = "PNG",
        quality: int = 95,
        include_data_url: bool = False
    ) -> str:
        """
        Convert image to base64 string.

        Args:
            image: PIL Image
            format: Output format (PNG, JPEG, WEBP)
            quality: Quality for lossy formats
            include_data_url: Include data URL prefix

        Returns:
            Base64 encoded string
        """
        image_bytes = ImageUtils.to_bytes(image, format, quality)
        b64_string = base64.b64encode(image_bytes).decode("utf-8")

        if include_data_url:
            mime_types = {"PNG": "image/png", "JPEG": "image/jpeg", "WEBP": "image/webp"}
            mime = mime_types.get(format.upper(), "image/png")
            return f"data:{mime};base64,{b64_string}"

        return b64_string

    # ==================== Resizing & Scaling ====================

    @staticmethod
    def resize(
        image: Image.Image,
        width: Optional[int] = None,
        height: Optional[int] = None,
        maintain_aspect: bool = False,
        resample: int = Image.Resampling.LANCZOS
    ) -> Image.Image:
        """
        Resize image to exact dimensions.

        Args:
            image: PIL Image
            width: Target width (if None, calculated from height)
            height: Target height (if None, calculated from width)
            maintain_aspect: If True, fit within dimensions keeping aspect ratio
            resample: Resampling filter

        Returns:
            New resized Image
        """
        if width is None and height is None:
            raise ValueError("Must specify width, height, or both")

        orig_width, orig_height = image.size

        if width is None:
            width = int(orig_width * height / orig_height)
        elif height is None:
            height = int(orig_height * width / orig_width)

        if maintain_aspect:
            # Calculate size that fits within bounds
            ratio = min(width / orig_width, height / orig_height)
            width = int(orig_width * ratio)
            height = int(orig_height * ratio)

        return image.resize((width, height), resample=resample)

    @staticmethod
    def scale(
        image: Image.Image,
        factor: float,
        resample: int = Image.Resampling.LANCZOS
    ) -> Image.Image:
        """
        Scale image by factor.

        Args:
            image: PIL Image
            factor: Scale factor (0.5 = half, 2.0 = double)
            resample: Resampling filter

        Returns:
            New scaled Image
        """
        width, height = image.size
        new_width = int(width * factor)
        new_height = int(height * factor)
        return image.resize((new_width, new_height), resample=resample)

    @staticmethod
    def thumbnail(
        image: Image.Image,
        size: Tuple[int, int],
        resample: int = Image.Resampling.LANCZOS
    ) -> Image.Image:
        """
        Create thumbnail that fits within size, maintaining aspect ratio.

        Args:
            image: PIL Image
            size: Maximum (width, height)
            resample: Resampling filter

        Returns:
            New thumbnail Image
        """
        result = image.copy()
        result.thumbnail(size, resample=resample)
        return result

    # ==================== Cropping ====================

    @staticmethod
    def crop(
        image: Image.Image,
        left: int,
        top: int,
        right: int,
        bottom: int
    ) -> Image.Image:
        """
        Crop image to region.

        Args:
            image: PIL Image
            left: Left edge X coordinate
            top: Top edge Y coordinate
            right: Right edge X coordinate
            bottom: Bottom edge Y coordinate

        Returns:
            New cropped Image
        """
        return image.crop((left, top, right, bottom))

    @staticmethod
    def crop_center(
        image: Image.Image,
        width: int,
        height: int
    ) -> Image.Image:
        """
        Crop from center of image.

        Args:
            image: PIL Image
            width: Crop width
            height: Crop height

        Returns:
            New cropped Image
        """
        img_width, img_height = image.size
        left = (img_width - width) // 2
        top = (img_height - height) // 2
        return image.crop((left, top, left + width, top + height))

    @staticmethod
    def crop_to_aspect(
        image: Image.Image,
        ratio: Union[str, float],
        anchor: str = "center"
    ) -> Image.Image:
        """
        Crop image to target aspect ratio.

        Args:
            image: PIL Image
            ratio: Aspect ratio as "16:9" string or float (width/height)
            anchor: Crop anchor - "center", "top", "bottom", "left", "right"

        Returns:
            New cropped Image
        """
        # Parse ratio
        if isinstance(ratio, str):
            w, h = map(int, ratio.split(":"))
            target_ratio = w / h
        else:
            target_ratio = ratio

        img_width, img_height = image.size
        current_ratio = img_width / img_height

        if current_ratio > target_ratio:
            # Image is wider, crop width
            new_width = int(img_height * target_ratio)
            new_height = img_height
        else:
            # Image is taller, crop height
            new_width = img_width
            new_height = int(img_width / target_ratio)

        # Calculate position based on anchor
        if anchor == "center":
            left = (img_width - new_width) // 2
            top = (img_height - new_height) // 2
        elif anchor == "top":
            left = (img_width - new_width) // 2
            top = 0
        elif anchor == "bottom":
            left = (img_width - new_width) // 2
            top = img_height - new_height
        elif anchor == "left":
            left = 0
            top = (img_height - new_height) // 2
        elif anchor == "right":
            left = img_width - new_width
            top = (img_height - new_height) // 2
        else:
            raise ValueError(f"Unknown anchor: {anchor}")

        return image.crop((left, top, left + new_width, top + new_height))

    # ==================== Compositing ====================

    @staticmethod
    def paste(
        background: Image.Image,
        foreground: Image.Image,
        position: Tuple[int, int] = (0, 0),
        use_alpha: bool = True
    ) -> Image.Image:
        """
        Paste foreground onto background at position.

        Args:
            background: Background image
            foreground: Image to paste
            position: (x, y) position for top-left of foreground
            use_alpha: Use foreground alpha channel as mask

        Returns:
            New composited Image
        """
        result = background.copy()
        if result.mode != "RGBA":
            result = result.convert("RGBA")

        if use_alpha and foreground.mode == "RGBA":
            result.paste(foreground, position, foreground)
        else:
            result.paste(foreground, position)

        return result

    @staticmethod
    def composite(
        background: Image.Image,
        foreground: Image.Image,
        mask: Optional[Image.Image] = None
    ) -> Image.Image:
        """
        Alpha composite foreground over background.

        Args:
            background: Background image
            foreground: Foreground image (must match background size)
            mask: Optional mask image

        Returns:
            New composited Image
        """
        bg = background.convert("RGBA") if background.mode != "RGBA" else background
        fg = foreground.convert("RGBA") if foreground.mode != "RGBA" else foreground

        if mask:
            mask = mask.convert("L")
            return Image.composite(fg, bg, mask)

        return Image.alpha_composite(bg, fg)

    @staticmethod
    def fit_to_canvas(
        image: Image.Image,
        width: int,
        height: int,
        background_color: Tuple[int, int, int, int] = (255, 255, 255, 0),
        position: str = "center"
    ) -> Image.Image:
        """
        Fit image onto canvas, letterboxing if needed.

        Args:
            image: PIL Image
            width: Canvas width
            height: Canvas height
            background_color: RGBA tuple for background
            position: Image position - "center", "top", "bottom"

        Returns:
            New Image on canvas
        """
        # Resize to fit
        resized = ImageUtils.resize(image, width, height, maintain_aspect=True)

        # Create canvas
        canvas = Image.new("RGBA", (width, height), background_color)

        # Calculate position
        res_width, res_height = resized.size
        if position == "center":
            x = (width - res_width) // 2
            y = (height - res_height) // 2
        elif position == "top":
            x = (width - res_width) // 2
            y = 0
        elif position == "bottom":
            x = (width - res_width) // 2
            y = height - res_height
        else:
            x = (width - res_width) // 2
            y = (height - res_height) // 2

        canvas.paste(resized, (x, y), resized if resized.mode == "RGBA" else None)
        return canvas

    # ==================== Format Conversion ====================

    @staticmethod
    def convert_format(
        image: Image.Image,
        format: str,
        quality: int = 95
    ) -> bytes:
        """
        Convert image to different format.

        Args:
            image: PIL Image
            format: Target format (PNG, JPEG, WEBP)
            quality: Quality for lossy formats

        Returns:
            Image bytes in new format
        """
        return ImageUtils.to_bytes(image, format, quality)

    @staticmethod
    def get_info(image: Image.Image) -> Dict[str, Any]:
        """
        Get image metadata.

        Args:
            image: PIL Image

        Returns:
            Dict with width, height, mode, format info
        """
        return {
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "format": image.format,
            "has_alpha": image.mode in ("RGBA", "LA", "PA"),
            "aspect_ratio": round(image.width / image.height, 3)
        }

    # ==================== Borders & Padding ====================

    @staticmethod
    def add_border(
        image: Image.Image,
        width: int,
        color: Tuple[int, int, int] = (0, 0, 0)
    ) -> Image.Image:
        """
        Add solid border around image.

        Args:
            image: PIL Image
            width: Border width in pixels
            color: RGB color tuple

        Returns:
            New Image with border
        """
        img_width, img_height = image.size
        new_width = img_width + 2 * width
        new_height = img_height + 2 * width

        # Create new image with border color
        result = Image.new(image.mode, (new_width, new_height), color)
        result.paste(image, (width, width))
        return result

    @staticmethod
    def add_padding(
        image: Image.Image,
        padding: Union[int, Tuple[int, int, int, int]],
        color: Tuple[int, int, int, int] = (255, 255, 255, 255)
    ) -> Image.Image:
        """
        Add whitespace padding around image.

        Args:
            image: PIL Image
            padding: Uniform padding or (left, top, right, bottom)
            color: RGBA color for padding

        Returns:
            New padded Image
        """
        if isinstance(padding, int):
            left = top = right = bottom = padding
        else:
            left, top, right, bottom = padding

        img_width, img_height = image.size
        new_width = img_width + left + right
        new_height = img_height + top + bottom

        result = Image.new("RGBA", (new_width, new_height), color)

        if image.mode == "RGBA":
            result.paste(image, (left, top), image)
        else:
            result.paste(image, (left, top))

        return result

    # ==================== Transforms ====================

    @staticmethod
    def rotate(
        image: Image.Image,
        angle: float,
        expand: bool = True,
        fill_color: Tuple[int, int, int, int] = (255, 255, 255, 0)
    ) -> Image.Image:
        """
        Rotate image by degrees (counter-clockwise).

        Args:
            image: PIL Image
            angle: Rotation angle in degrees
            expand: Expand canvas to fit rotated image
            fill_color: Color for new corners

        Returns:
            New rotated Image
        """
        return image.rotate(angle, expand=expand, fillcolor=fill_color, resample=Image.Resampling.BICUBIC)

    @staticmethod
    def flip_horizontal(image: Image.Image) -> Image.Image:
        """
        Mirror image horizontally.

        Args:
            image: PIL Image

        Returns:
            New flipped Image
        """
        return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    @staticmethod
    def flip_vertical(image: Image.Image) -> Image.Image:
        """
        Flip image vertically.

        Args:
            image: PIL Image

        Returns:
            New flipped Image
        """
        return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

    # ==================== Watermarks ====================

    @staticmethod
    def add_text_watermark(
        image: Image.Image,
        text: str,
        position: str = "bottom-right",
        font_size: int = 24,
        color: Tuple[int, int, int, int] = (255, 255, 255, 128),
        margin: int = 10
    ) -> Image.Image:
        """
        Add text watermark to image.

        Args:
            image: PIL Image
            text: Watermark text
            position: "bottom-right", "bottom-left", "top-right", "top-left", "center"
            font_size: Font size
            color: RGBA color (with alpha for transparency)
            margin: Margin from edges

        Returns:
            New watermarked Image
        """
        result = image.convert("RGBA")
        overlay = Image.new("RGBA", result.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)

        # Try to load a font, fall back to default
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", font_size)
        except (IOError, OSError):
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
            except (IOError, OSError):
                font = ImageFont.load_default()

        # Get text size
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        # Calculate position
        img_width, img_height = result.size
        positions = {
            "bottom-right": (img_width - text_width - margin, img_height - text_height - margin),
            "bottom-left": (margin, img_height - text_height - margin),
            "top-right": (img_width - text_width - margin, margin),
            "top-left": (margin, margin),
            "center": ((img_width - text_width) // 2, (img_height - text_height) // 2)
        }
        x, y = positions.get(position, positions["bottom-right"])

        draw.text((x, y), text, font=font, fill=color)
        return Image.alpha_composite(result, overlay)

    @staticmethod
    def add_image_watermark(
        image: Image.Image,
        watermark: Image.Image,
        position: str = "bottom-right",
        opacity: float = 0.5,
        scale: float = 0.2,
        margin: int = 10
    ) -> Image.Image:
        """
        Add image/logo watermark.

        Args:
            image: PIL Image
            watermark: Watermark image
            position: "bottom-right", "bottom-left", "top-right", "top-left", "center"
            opacity: Watermark opacity (0-1)
            scale: Scale watermark relative to image width
            margin: Margin from edges

        Returns:
            New watermarked Image
        """
        result = image.convert("RGBA")

        # Scale watermark
        wm_width = int(result.width * scale)
        wm = ImageUtils.resize(watermark, width=wm_width)

        # Apply opacity
        if wm.mode == "RGBA":
            r, g, b, a = wm.split()
            a = a.point(lambda x: int(x * opacity))
            wm = Image.merge("RGBA", (r, g, b, a))
        else:
            wm = wm.convert("RGBA")

        # Calculate position
        img_width, img_height = result.size
        wm_w, wm_h = wm.size
        positions = {
            "bottom-right": (img_width - wm_w - margin, img_height - wm_h - margin),
            "bottom-left": (margin, img_height - wm_h - margin),
            "top-right": (img_width - wm_w - margin, margin),
            "top-left": (margin, margin),
            "center": ((img_width - wm_w) // 2, (img_height - wm_h) // 2)
        }
        x, y = positions.get(position, positions["bottom-right"])

        result.paste(wm, (x, y), wm)
        return result

    # ==================== Adjustments ====================

    @staticmethod
    def adjust_brightness(image: Image.Image, factor: float) -> Image.Image:
        """
        Adjust image brightness.

        Args:
            image: PIL Image
            factor: Brightness factor (1.0 = original, < 1 darker, > 1 lighter)

        Returns:
            New adjusted Image
        """
        enhancer = ImageEnhance.Brightness(image)
        return enhancer.enhance(factor)

    @staticmethod
    def adjust_contrast(image: Image.Image, factor: float) -> Image.Image:
        """
        Adjust image contrast.

        Args:
            image: PIL Image
            factor: Contrast factor (1.0 = original, < 1 less contrast, > 1 more)

        Returns:
            New adjusted Image
        """
        enhancer = ImageEnhance.Contrast(image)
        return enhancer.enhance(factor)

    @staticmethod
    def adjust_saturation(image: Image.Image, factor: float) -> Image.Image:
        """
        Adjust color saturation.

        Args:
            image: PIL Image
            factor: Saturation factor (1.0 = original, 0 = grayscale, > 1 more vivid)

        Returns:
            New adjusted Image
        """
        enhancer = ImageEnhance.Color(image)
        return enhancer.enhance(factor)

    @staticmethod
    def adjust_sharpness(image: Image.Image, factor: float) -> Image.Image:
        """
        Adjust image sharpness.

        Args:
            image: PIL Image
            factor: Sharpness factor (1.0 = original, < 1 blur, > 1 sharper)

        Returns:
            New adjusted Image
        """
        enhancer = ImageEnhance.Sharpness(image)
        return enhancer.enhance(factor)

    @staticmethod
    def blur(image: Image.Image, radius: float = 2.0) -> Image.Image:
        """
        Apply Gaussian blur to image.

        Args:
            image: PIL Image
            radius: Blur radius

        Returns:
            New blurred Image
        """
        return image.filter(ImageFilter.GaussianBlur(radius=radius))

    # ==================== Web Optimization ====================

    @staticmethod
    def optimize_for_web(
        image: Image.Image,
        max_dimension: int = 1920,
        format: str = "WEBP",
        quality: int = 85
    ) -> bytes:
        """
        Optimize image for web delivery.

        Args:
            image: PIL Image
            max_dimension: Maximum width or height
            format: Output format (WEBP recommended)
            quality: Output quality

        Returns:
            Optimized image bytes
        """
        # Resize if needed
        width, height = image.size
        if width > max_dimension or height > max_dimension:
            image = ImageUtils.resize(image, max_dimension, max_dimension, maintain_aspect=True)

        return ImageUtils.to_bytes(image, format, quality)


# ==================== CLI Examples ====================

if __name__ == "__main__":
    # Example: Load, resize, save
    print("=== ImageUtils Examples ===\n")

    # Create a test image
    test_image = Image.new("RGB", (800, 600), color=(100, 150, 200))

    print("1. Basic operations:")
    info = ImageUtils.get_info(test_image)
    print(f"   Original: {info['width']}x{info['height']}")

    resized = ImageUtils.resize(test_image, width=400)
    print(f"   Resized (width=400): {resized.width}x{resized.height}")

    scaled = ImageUtils.scale(test_image, 0.5)
    print(f"   Scaled (0.5x): {scaled.width}x{scaled.height}")

    print("\n2. Cropping:")
    cropped = ImageUtils.crop_to_aspect(test_image, "16:9")
    print(f"   Crop to 16:9: {cropped.width}x{cropped.height}")

    center_crop = ImageUtils.crop_center(test_image, 200, 200)
    print(f"   Center crop 200x200: {center_crop.width}x{center_crop.height}")

    print("\n3. Format conversion:")
    png_bytes = ImageUtils.to_bytes(test_image, "PNG")
    print(f"   PNG: {len(png_bytes):,} bytes")

    jpeg_bytes = ImageUtils.to_bytes(test_image, "JPEG", quality=85)
    print(f"   JPEG (q=85): {len(jpeg_bytes):,} bytes")

    webp_bytes = ImageUtils.to_bytes(test_image, "WEBP", quality=85)
    print(f"   WEBP (q=85): {len(webp_bytes):,} bytes")

    print("\n4. Adjustments:")
    bright = ImageUtils.adjust_brightness(test_image, 1.5)
    contrast = ImageUtils.adjust_contrast(test_image, 1.2)
    blurred = ImageUtils.blur(test_image, radius=5)
    print("   Brightness, contrast, blur applied")

    print("\n5. Transforms:")
    rotated = ImageUtils.rotate(test_image, 45)
    print(f"   Rotated 45deg: {rotated.width}x{rotated.height}")

    flipped = ImageUtils.flip_horizontal(test_image)
    print(f"   Flipped horizontal: {flipped.width}x{flipped.height}")

    print("\n=== Complete ===")

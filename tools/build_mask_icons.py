#!/usr/bin/env python3
"""Crop the four-symbol reference sheet into reusable mask icon assets."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/game-design/assets/four-symbols-reference.jpg"
OUTPUT = ROOT / "assets/ui/masks"


def transparent_quadrant(image: Image.Image, bounds: tuple[int, int, int, int]) -> Image.Image:
    crop = image.crop(bounds).convert("RGB")
    rgba = crop.convert("RGBA")
    background_luma = sum(crop.getpixel((0, 0))) / 3
    pixels = []
    for red, green, blue, _alpha in rgba.getdata():
        low_saturation = max(red, green, blue) - min(red, green, blue) < 18
        near_background = abs((red + green + blue) / 3 - background_luma) < 28
        is_key = low_saturation and near_background
        pixels.append((red, green, blue, 0 if is_key else 255))
    rgba.putdata(pixels)
    bbox = rgba.getbbox()
    if bbox is not None:
        rgba = rgba.crop(bbox)

    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    rgba.thumbnail((208, 208), Image.Resampling.NEAREST)
    position = ((256 - rgba.width) // 2, (256 - rgba.height) // 2)
    canvas.alpha_composite(rgba, position)
    return canvas


def main() -> None:
    image = Image.open(SOURCE)
    width, height = image.size
    middle_x = width // 2
    middle_y = height // 2
    margin = 6
    quadrants = {
        "azure_dragon.png": (margin, margin, middle_x - margin, middle_y - margin),
        "white_tiger.png": (middle_x + margin, margin, width - margin, middle_y - margin),
        "vermilion_bird.png": (margin, middle_y + margin, middle_x - margin, height - margin),
        "black_tortoise.png": (
            middle_x + margin,
            middle_y + margin,
            width - margin,
            height - margin,
        ),
    }

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, bounds in quadrants.items():
        transparent_quadrant(image, bounds).save(OUTPUT / filename)


if __name__ == "__main__":
    main()

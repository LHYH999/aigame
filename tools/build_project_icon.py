#!/usr/bin/env python3
"""Build the square project icon from the supplied four-symbol reference."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/game-design/assets/four-symbols-reference.jpg"
OUTPUT = ROOT / "icon.png"
FONT = ROOT / "assets/ui/fonts/fusion-pixel-12px-proportional-zh_hans.ttf"


def main() -> None:
    canvas = Image.new("RGB", (1024, 1024), "#1b2928")
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (36, 36, 988, 988),
        radius=64,
        outline="#b99b5d",
        width=8,
    )

    reference = Image.open(SOURCE).convert("RGB")
    reference.thumbnail((920, 640), Image.Resampling.LANCZOS)
    position = ((1024 - reference.width) // 2, 190)
    canvas.paste(reference, position)

    font = ImageFont.truetype(str(FONT), 72)
    draw.text(
        (512, 100),
        "逆岁：四契",
        font=font,
        fill="#f0dfb7",
        anchor="mm",
        stroke_width=5,
        stroke_fill="#0b1212",
    )
    canvas.save(OUTPUT)


if __name__ == "__main__":
    main()

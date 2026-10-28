from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


OUTPUT_SIZE = 256
CHARACTER_SIZE = (164, 218)
CHARACTER_OFFSET = (46, 32)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    bounds = source.getbbox()
    if bounds is None:
        raise ValueError("Generated player image has no visible pixels")
    character = source.crop(bounds).resize(
        CHARACTER_SIZE,
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(character, CHARACTER_OFFSET)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)


if __name__ == "__main__":
    main()

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--canvas", default=256, type=int)
    parser.add_argument("--content", default=220, type=int)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    bounds = source.getbbox()
    if bounds is None:
        raise ValueError("Input image has no visible pixels")
    content = source.crop(bounds)
    scale = min(args.content / content.width, args.content / content.height)
    size = (
        max(1, round(content.width * scale)),
        max(1, round(content.height * scale)),
    )
    content = content.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (args.canvas, args.canvas), (0, 0, 0, 0))
    canvas.alpha_composite(
        content,
        ((args.canvas - size[0]) // 2, (args.canvas - size[1]) // 2),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)


if __name__ == "__main__":
    main()

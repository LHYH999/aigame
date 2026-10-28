#!/usr/bin/env python3
"""Extract a Meowa attack WebP into square PNG frames and a review sheet."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageSequence


def checkerboard(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (35, 43, 43, 255))
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if ((x // 16) + (y // 16)) % 2:
                pixels[x, y] = (48, 58, 58, 255)
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir")
    parser.add_argument("output_dir")
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--size", type=int, default=256)
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    source = next(
        path
        for path in input_dir.rglob("*.webp")
        if "background" not in path.name
    )
    image = Image.open(source)
    frames = [
        frame.convert("RGBA").resize((args.size, args.size), Image.Resampling.NEAREST)
        for frame in ImageSequence.Iterator(image)
    ]
    if len(frames) != args.frames:
        raise ValueError(f"Expected {args.frames} frames, found {len(frames)}")

    output_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(output_dir / f"frame_{index:03d}.png")

    preview = checkerboard((args.size * 4, args.size * 2))
    for index, frame in enumerate(frames):
        x = (index % 4) * args.size
        y = (index // 4) * args.size
        preview.alpha_composite(frame, (x, y))
    preview.save(output_dir / "preview.png")


if __name__ == "__main__":
    main()

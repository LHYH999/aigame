from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


OUTPUT_SIZE = 228
PREVIEW_SCALE = 2


def build_preview(frames: list[Image.Image]) -> Image.Image:
    gap = 12
    cell = OUTPUT_SIZE * PREVIEW_SCALE
    preview = Image.new(
        "RGBA",
        (cell * 4 + gap * 5, cell * 2 + gap * 3),
        (34, 35, 39, 255),
    )
    draw = ImageDraw.Draw(preview)
    for y in range(0, preview.height, 16):
        for x in range(0, preview.width, 16):
            if (x // 16 + y // 16) % 2 == 0:
                draw.rectangle((x, y, x + 15, y + 15), fill=(54, 55, 60, 255))
    for index, frame in enumerate(frames):
        enlarged = frame.resize((cell, cell), Image.Resampling.NEAREST)
        preview.alpha_composite(
            enlarged,
            (gap + (index % 4) * (cell + gap), gap + (index // 4) * (cell + gap)),
        )
    return preview


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    args = parser.parse_args()

    animation = Image.open(args.input)
    if getattr(animation, "n_frames", 1) != 8:
        raise ValueError("Expected an eight-frame animation")
    if animation.size[0] < OUTPUT_SIZE or animation.size[1] < OUTPUT_SIZE:
        raise ValueError(f"Animation is too small: {animation.size}")

    left = (animation.width - OUTPUT_SIZE) // 2
    top = (animation.height - OUTPUT_SIZE) // 2
    frames = []
    args.output.mkdir(parents=True, exist_ok=True)
    for index in range(8):
        animation.seek(index)
        frame = animation.convert("RGBA").crop(
            (left, top, left + OUTPUT_SIZE, top + OUTPUT_SIZE)
        )
        frame.save(args.output / f"frame_{index:03d}.png")
        frames.append(frame)

    args.preview.parent.mkdir(parents=True, exist_ok=True)
    build_preview(frames).save(args.preview)


if __name__ == "__main__":
    main()

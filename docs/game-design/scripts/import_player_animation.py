from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


FRAME_COUNT = 8
PREVIEW_SCALE = 3


def build_preview(frames: list[Image.Image]) -> Image.Image:
    gap = 12
    cell = frames[0].width * PREVIEW_SCALE
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
    if getattr(animation, "n_frames", 1) != FRAME_COUNT:
        raise ValueError("Expected an eight-frame player animation")

    args.output.mkdir(parents=True, exist_ok=True)
    frames = []
    for index in range(FRAME_COUNT):
        animation.seek(index)
        frame = animation.convert("RGBA")
        frame.save(args.output / f"frame_{index:03d}.png")
        frames.append(frame)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    build_preview(frames).save(args.preview)


if __name__ == "__main__":
    main()

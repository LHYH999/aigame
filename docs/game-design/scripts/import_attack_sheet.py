from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


CELL_SIZE = 256
FRAME_CELLS = (
    (0, 0),
    (1, 0),
    (2, 0),
    (0, 1),
    (1, 1),
    (2, 1),
    (0, 2),
    (1, 2),
)


def clear_gray_background(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    width, height = result.size
    pending = deque()
    visited = set()

    def is_background(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        neutral = max(red, green, blue) - min(red, green, blue) <= 16
        return alpha == 0 or (neutral and 100 <= (red + green + blue) / 3 <= 207)

    for x in range(width):
        pending.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        pending.extend(((0, y), (width - 1, y)))

    while pending:
        point = pending.popleft()
        if point in visited:
            continue
        visited.add(point)
        x, y = point
        if not is_background(x, y):
            continue
        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
        if x > 0:
            pending.append((x - 1, y))
        if x + 1 < width:
            pending.append((x + 1, y))
        if y > 0:
            pending.append((x, y - 1))
        if y + 1 < height:
            pending.append((x, y + 1))
    return result


def build_preview(frames: list[Image.Image]) -> Image.Image:
    gap = 16
    preview = Image.new(
        "RGBA",
        (CELL_SIZE * 4 + gap * 5, CELL_SIZE * 2 + gap * 3),
        (34, 35, 39, 255),
    )
    draw = ImageDraw.Draw(preview)
    for y in range(0, preview.height, 16):
        for x in range(0, preview.width, 16):
            if (x // 16 + y // 16) % 2 == 0:
                draw.rectangle((x, y, x + 15, y + 15), fill=(54, 55, 60, 255))
    for index, frame in enumerate(frames):
        column = index % 4
        row = index // 4
        x = gap + column * (CELL_SIZE + gap)
        y = gap + row * (CELL_SIZE + gap)
        preview.alpha_composite(frame, (x, y))
    return preview


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    if source.size != (CELL_SIZE * 3, CELL_SIZE * 3):
        raise ValueError(f"Expected a 768x768 sheet, got {source.size}")

    args.output.mkdir(parents=True, exist_ok=True)
    frames = []
    for column, row in FRAME_CELLS:
        frame = source.crop(
            (
                column * CELL_SIZE,
                row * CELL_SIZE,
                (column + 1) * CELL_SIZE,
                (row + 1) * CELL_SIZE,
            )
        )
        frame = clear_gray_background(frame)
        frame.save(args.output / f"frame_{len(frames):03d}.png")
        frames.append(frame)
    build_preview(frames).save(args.output / "preview.png")


if __name__ == "__main__":
    main()

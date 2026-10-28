from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


CELL_SIZE = 32
COLUMNS = 4
ROWS = 4
FRAME_SCALE = 3
GAME_CANVAS = 228
FRAME_OFFSET = (66, 78)


def clear_gray_background(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            neutral = max(red, green, blue) - min(red, green, blue) <= 16
            if alpha > 0 and neutral and 100 <= (red + green + blue) / 3 <= 207:
                pixels[x, y] = (red, green, blue, 0)
    return result


def build_preview(frames: list[Image.Image]) -> Image.Image:
    preview_scale = 6
    gap = 12
    cell = CELL_SIZE * preview_scale
    preview = Image.new(
        "RGBA",
        (cell * COLUMNS + gap * (COLUMNS + 1), cell * ROWS + gap * (ROWS + 1)),
        (34, 35, 39, 255),
    )
    draw = ImageDraw.Draw(preview)
    for y in range(0, preview.height, 16):
        for x in range(0, preview.width, 16):
            if (x // 16 + y // 16) % 2 == 0:
                draw.rectangle((x, y, x + 15, y + 15), fill=(54, 55, 60, 255))
    for index, frame in enumerate(frames):
        column = index % COLUMNS
        row = index // COLUMNS
        enlarged = frame.resize((cell, cell), Image.Resampling.NEAREST)
        preview.alpha_composite(
            enlarged,
            (gap + column * (cell + gap), gap + row * (cell + gap)),
        )
    return preview


def place_on_game_canvas(frame: Image.Image) -> Image.Image:
    enlarged = frame.resize(
        (CELL_SIZE * FRAME_SCALE, CELL_SIZE * FRAME_SCALE),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", (GAME_CANVAS, GAME_CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(enlarged, FRAME_OFFSET)
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    expected_size = (CELL_SIZE * COLUMNS, CELL_SIZE * ROWS)
    if source.size != expected_size:
        raise ValueError(f"Expected a {expected_size} sheet, got {source.size}")

    cells = []
    for row in range(ROWS):
        for column in range(COLUMNS):
            frame = source.crop(
                (
                    column * CELL_SIZE,
                    row * CELL_SIZE,
                    (column + 1) * CELL_SIZE,
                    (row + 1) * CELL_SIZE,
                )
            )
            cells.append(ImageOps.mirror(clear_gray_background(frame)))

    idle_dir = args.output / "idle" / "west"
    run_dir = args.output / "run" / "west"
    idle_dir.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)

    for index, frame in enumerate(cells):
        place_on_game_canvas(frame).save(run_dir / f"frame_{index:03d}.png")
    for index, frame in enumerate(cells[:COLUMNS]):
        place_on_game_canvas(frame).save(idle_dir / f"frame_{index:03d}.png")
    place_on_game_canvas(cells[0]).save(args.output / "west.png")

    args.preview.parent.mkdir(parents=True, exist_ok=True)
    build_preview(cells).save(args.preview)


if __name__ == "__main__":
    main()

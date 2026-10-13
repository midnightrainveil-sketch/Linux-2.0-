# Artwork

The shell's artwork lives in four source images in `art/`. Two scripts turn
them into the files the shell reads. Re-run them whenever you replace a
source image:

```sh
python3 tools/import_art.py         # sprig, icons, weather sketches
python3 tools/import_wallpaper.py   # the starter plate (wallpaper)
```

| Source | Becomes | What it is |
| --- | --- | --- |
| `art/sprig.webp` | `assets/sprig-wash.png` | The Time Record's twig, a blue-grey watercolour sprig. |
| `art/icons.webp` | `assets/icons/<name>.png` | One row of ten ink icons, left to right: seedling, screen, screen-night, speaker, speaker-loud, speaker-muted, wifi, wifi-none, wifi-off, record. |
| `art/weather.webp` | `assets/weather/<name>.png` | A 3 × 3 grid of pencil weather sketches, row by row: overcast, clear, clear-night / partly, partly-night, fog / rain, snow, storm. |
| `art/wallpaper.webp` | `~/.local/share/archive/plates/0001-geranium-pratense/` | The whole 16:9 sheet, used as the wallpaper with its own text: `sheet-day.jpg` (toned to the desk grey) and `sheet-night.jpg` (a cyanotype print of it). |

The sources can be ink on white: the scripts key out the paper and write
black ink with alpha, which the shell tints graphite by day and pale blue at
night. Colour in the art is not kept.

## Replacing a source

- Keep the layout: ten icons in one row with clear gaps between them, and
  nine weather sketches in a 3 × 3 grid with clear gaps. The scripts find
  the pieces by those gaps and stop with a message if the count is wrong.
- For the wallpaper, any finished 16:9 sheet works: replace
  `art/wallpaper.webp` and run `tools/import_wallpaper.py`. The screen fills
  with it, cropping a little off the sides on a 16:10 panel, so keep the
  sides of the picture quiet. A text-free plant on plain paper can instead go
  through `archive-plate import`, and the shell types its labels.
- A larger source gives finer lines on the G14's 2880 × 1800 panel. The
  current wallpaper is 1672 × 941 and is upscaled 2×.

Any file you place directly at `assets/<group>/<name>.png` is used as is;
the generated `.svg` files are only fallbacks.

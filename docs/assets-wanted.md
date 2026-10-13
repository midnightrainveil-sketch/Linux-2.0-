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
| `art/wallpaper.webp` | `~/.local/share/archive/plates/0001-geranium-pratense/` | A whole 16:9 plate. Only the plant column is kept. Its typed text is painted out, because the shell types its own live labels. |

The sources can be ink on white: the scripts key out the paper and write
black ink with alpha, which the shell tints graphite by day and pale blue at
night. Colour in the art is not kept.

## Replacing a source

- Keep the layout: ten icons in one row with clear gaps between them, and
  nine weather sketches in a 3 × 3 grid with clear gaps. The scripts find
  the pieces by those gaps and stop with a message if the count is wrong.
- For the wallpaper, any plant works, but `tools/import_wallpaper.py` has the
  crop box and the text boxes for this particular image at the top (`CROP`,
  `TEXT`). A new image needs those numbers changed. A text-free plant on a
  plain ground is easier: use `archive-plate import` instead.
- A larger source gives finer lines on the G14's 2880 × 1800 panel. The
  current wallpaper is 1672 × 941 and is upscaled 2×.

Any file you place directly at `assets/<group>/<name>.png` is used as is;
the generated `.svg` files are only fallbacks.

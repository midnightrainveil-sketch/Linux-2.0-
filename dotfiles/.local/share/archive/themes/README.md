# Themes

Each folder here is a desktop theme you can log in to; the Themes app
(launcher: "Themes", or Instruments → Themes) shows them and chooses one,
and `archive-theme` does the same from a terminal. A new choice takes effect
at the next log-in.

A theme folder holds:

- `theme.json`: `id` (the folder's name), `name`, `by`, `summary`,
  `previews` (picture files in the folder, 16:10, about 1280 × 800) and
  optionally `captions` (one per preview).
- the preview pictures.
- `hypr/hyprland.lua`: the theme's whole Hyprland configuration, loaded
  instead of the Archive's own (`~/.config/hypr/hyprland.lua` hands over to
  it as the session starts). It starts the theme's own shell, for example
  `hl.exec_once("qs -p " .. dir .. "/quickshell")`, and its own Themes app,
  styled like the rest of it, reading this same folder.

The Archive itself is built in: its `theme.json` has no `hypr/`.

Shared by every theme (they live outside the themes): your files and apps,
and the archive-* commands behind the scenes: restore points
(`archive-snapshot`), refresh rate (`archive-refresh`), GPU and power
(`archive-rog`, `archive-profile`), brightness, clipboard history
(`archive-clips`), screenshots.

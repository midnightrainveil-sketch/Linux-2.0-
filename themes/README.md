# Themes

Each folder here is one desktop theme, complete in itself: a **box**. The
Themes app (launcher: "Themes") lists them and chooses one; `ultra-theme`
does the same from a terminal. A new choice takes effect at the next log-in.

```
ultra-theme list            the themes kept
ultra-theme set <id>        choose one (from the next log-in)
ultra-theme current         the one in place
```

## How it stays separate

Only the chosen theme is ever in your home folder. As a session starts,
`~/.config/hypr/hyprland.lua` (the selector, in `core/`) runs
`ultra-theme apply`: the chosen box's `home/` is linked file by file into
your home, and every link of the previous theme is taken out, its timers
stopped. So nothing of another theme is read, loaded or running: not its
shell, its widgets, its fonts, its keybinds or its scripts. The others are
folders on disk, nothing more.

Shared by all (in `core/`, not in any box): the machine. Screens, GPUs and
input (`hypr/ultra/machine.lua`), and the commands that are not about looks:
`ultra-update`, `ultra-rog`, `ultra-lan`, `ultra-ros`, `ultra-refresh`,
`ultra-snapshot`, `ultra-brightness`, `ultra-mic`, `ultra-icc`, `ultra-boot`,
`ultra-memory`, `ultra-theme`. (`ultra-boot` only installs the start-up page;
the page itself is the theme's.)

## What a box holds

```
themes/<id>/
  theme.json            id, name, by, summary, previews, captions
  preview-*.jpg         pictures for the Themes app (16:10, about 1280 x 800)
  home/                 mirrors your home folder; linked while the theme is on
    .config/hypr/theme.lua      its Hyprland side: look, keybinds, rules, and
                                what it starts (its shell, its idle, its sounds)
    .config/quickshell/...      its shell (or whatever bar and widgets it uses)
    .config/foot, gtk-3.0 ...   its terminal, GTK and Qt look
    .local/bin/...              its own commands
    .local/share/...            its fonts, cursors, sounds, wallpapers
  system/plymouth/      its start-up and shut-down page (optional): page.script and
                        its pictures. A root helper (ultra-page, set up by
                        ultra-boot quiet) installs the page of the theme in
                        place whenever the theme changes.
  tools/, art/          what its pictures are made from (optional)
```

Each theme keeps its own settings and state apart from the others':
`~/.config/ultra/<id>/`, `~/.local/state/ultra/<id>/`,
`~/.local/share/ultra/<id>/`, `~/.cache/ultra/<id>/`.

`theme.json` may also say:

- `"leaves": [".config/gtk-3.0/gtk.css"]`: files the theme writes outside
  its links while it runs; they are removed when another theme takes over.
- `"own": {"when": ".config/ultra/<id>/wallpaper.*", "skip": [...]}`: files
  not linked while you have your own in their place (a wallpaper of yours).

## Adding a theme

1. Make a folder: `~/.local/share/ultra/themes/<id>/` (updates never touch
   it; `~/ultra/themes/` is for the ones that ship).
2. Put in `theme.json`, a preview picture or two, and `home/`.
3. `home/.config/hypr/theme.lua` is the one file it must have. The selector
   has already set up the screens, GPUs, input and `PATH` when it runs; the
   theme adds its look, its keybinds and starts its own programs
   (`hl.on("hyprland.start", ...)`). Give it a way to open a Themes list of
   its own (`ultra-theme list` prints them as JSON), or use
   `ultra-theme set <id>` in a terminal.
4. `ultra-theme set <id>`, then log out and in. To go back from a theme that
   does not start: `Ctrl + Alt + F3`, log in, `ultra-theme set archive`,
   `Ctrl + Alt + F1` (or reboot).

Copying an existing box is a fine start (`cp -r ~/ultra/themes/archive
~/.local/share/ultra/themes/mine`), but then replace `archive` in its paths
(`.config/ultra/archive`, `.local/share/ultra/archive` and the same names
inside its scripts) with the new id, so the two keep their settings apart.

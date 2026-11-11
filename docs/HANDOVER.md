# Handover: start here

For a new chat picking this project up. Read this first, then
`docs/next-ideas.md` (the plan), then whatever the task touches.

## The person and how to work with them

- New to Linux: give short, exact commands to paste, one block at a time,
  and say what each does. They install with `ultra-update` (fetches this
  branch and runs `setup.sh`); single files are installed with `curl` from
  `raw.githubusercontent.com/midnightrainveil-sketch/Linux-2.0-/claude/hyprland-ui-setup-l5njnw/...`.
- Design: **mock up first and wait for a choice** before building anything
  visual (several options, rendered on their real bar or desk). They care
  about quality and cohesion; they dislike cartoony, toy-like or too
  saturated looks; they like paper, tickets, the typewriter, the night train.
- They often generate art with an image generator; write them complete,
  self-contained prompts (style block included in each), then cut the
  results out cleanly (`tools/import_*.py`).
- Work on branch `claude/hyprland-ui-setup-l5njnw`; commit and push each
  finished change; never open a PR unless asked. Test QML in the real
  Quickshell harness before pushing (a QML syntax slip blanks the desktop).
- Say plainly what was tested here and what only their laptop can show
  (Hyprland itself, the plugin build, anything needing sudo). After they
  install, they report back; fix from that.
- Keep replies short: what changed, the command to run, what to look for.
- Never store passwords. (They once shared a robot password: never put it
  anywhere.) Their email and personal details stay out of the repo and out
  of requests to outside services. Their ROS notes stay out of the repo.

## The machine

ASUS ROG Zephyrus G14 GA403UV (Ryzen 9 8945HS, Radeon 780M + RTX 4060),
2880x1800 OLED at 1.5 scale, 60/120 Hz (auto by charger). Arch Linux with
two kernels: `linux-lts` (iGPU use) and `linux` (dGPU use). Hyprland 0.57
(Lua config) + Quickshell 0.3.2. Work: SSH to robots and an FMS server on a
mesh Wi-Fi (Botsync_PilotB_Mesh), see `ultra-lan`.

## What exists

- **Layout** (installed at `~/ultra`; see `themes/README.md`):
  - `core/`: the machine, shared by all themes. The selector
    (`core/home/.config/hypr/hyprland.lua`), `ultra/machine.lua`, and the
    commands that are not about looks: `ultra-theme` (links the chosen box),
    `ultra-update`, `ultra-lan` (mesh Wi-Fi detour, calm switching),
    `ultra-rog` (GPU/power), `ultra-refresh`, `ultra-snapshot` (Timeshift),
    `ultra-ros` (rviz), `ultra-brightness`, `ultra-mic`, `ultra-icc`,
    `ultra-boot`, `ultra-memory`. `setup.sh` also bakes in: ssh keepalive,
    Wi-Fi power saving off. Nothing depends on the kernel (linux, linux-lts).
  - `themes/<id>/`: one self-contained box per theme; `home/` is linked
    into the home folder only while that theme is on. No box refers to
    another; each has its own copy of the shell, scripts, tools and art.
- **Themes** (chosen in the Themes app or `ultra-theme set <id>`, from the
  next log-in):
  - **Archive** (`themes/archive`): a botanical herbarium desk.
  - **Compartment 19** (`themes/night-service`): a 1930s Vienna to Venice
    night train; a full copy with its own parts (keepsakes, music box).
- **In both** (each box has its own copy): ticket-stub workspaces, title-bar
  tickets (archivebars plugin, `home/.local/share/ultra/<id>/plugins/`),
  the train along the bar, inked file icons (`tools/inked_icons.py`), the
  lock screen seal.
- **Start-up / shut-down page** (Plymouth): each box's `system/plymouth/`;
  `ultra-boot quiet` installs root's `ultra-page` and a path unit that
  swaps the page (and rebuilds the initramfs) when the theme changes.
## Testing here (the harness)

A cloud container has no Hyprland, but the real Quickshell can be built and
run under a headless sway, which catches QML errors and shows the desk:

- `docs/harness/build.sh`: builds Quickshell 0.3.2 with Qt 6.12 from
  conda-forge (about 15 minutes, once per container). It is written down
  from the build that worked, not re-run since: expect to adjust it.
- `STEPS=steps.sh docs/harness/run.sh <theme-id>`: puts the theme in place
  in a scratch home with `ultra-theme` and takes screenshots (`shot`, `ipc`
  lines in the steps file). Look at the screenshots and read `out/qs.log`.
- Also: `bash -n` every script, `python3 -m py_compile`, and the Hyprland
  config run in plain `lua` with `hl` stubbed out (a table that accepts any
  call), which catches Lua errors and shows what would be started.
- After a theme change, check nothing of another box is left:
  `find ~ -lname '*themes/<other>/*'` in the scratch home prints nothing.
- `setup.sh` can be dry-run in a scratch home with `sudo`, `pacman`,
  `systemctl` and the like replaced by do-nothing scripts on `PATH`.

Not testable here: Hyprland (windows, workspaces, keybinds), the archivebars
plugin against the user's Hyprland, Plymouth, anything with sudo.

## State (November 2026)

The restructure is done, installed and confirmed working on the laptop:
`core/` + one box per theme, commands renamed `archive-*` to `ultra-*`, the
old `~/archive` install migrated. The start-up / shut-down page follows the
theme (also confirmed).

## Next

Build the **new, third theme** as its own box (`themes/<id>/`). Nothing
about it is decided: ask what they want it to be, offer directions, mock up
(several options) and wait for their pick before building. It is to be a
completely different setup, not a re-skin, and must not touch or depend on
the other two boxes (`themes/README.md` says what a box needs; copying a
box is fine as scaffolding, with its id replaced throughout). Keep it
light: only what it shows is loaded. Older ideas for the existing themes
are in `docs/next-ideas.md` (not asked for now).

Leftovers they may mention: the train button and train are in both themes
(offer to take it out of the Archive if they want); the boot wording for
Compartment 19 ("Now boarding, Vienna – Venice." etc.) was my choice.

Still open from before: the GPU switching check on the user's laptop
(`ultra-rog status`, the "dGPU open by" line, after a reboot).

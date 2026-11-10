# Handover: start here

For a new chat picking this project up. Read this first, then
`docs/next-ideas.md` (the plan), then whatever the task touches.

## The person and how to work with them

- New to Linux: give short, exact commands to paste, one block at a time,
  and say what each does. They install with `archive-update` (fetches this
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
- Never store passwords. (They once shared a robot password: never put it
  anywhere.)

## The machine

ASUS ROG Zephyrus G14 GA403UV (Ryzen 9 8945HS, Radeon 780M + RTX 4060),
2880x1800 OLED at 1.5 scale, 60/120 Hz (auto by charger). Arch Linux with
two kernels: `linux-lts` (iGPU use) and `linux` (dGPU use). Hyprland 0.57
(Lua config) + Quickshell 0.3.2. Work: SSH to robots and an FMS server on a
mesh Wi-Fi (Botsync_PilotB_Mesh), see `archive-lan`.

## What exists

- **Themes** (`~/.local/share/archive/themes`, chosen in the Themes app or
  `archive-theme`, from the next log-in):
  - **Archive**: a botanical herbarium desk (the original).
  - **Compartment 19** (folder `night-service`): a 1930s Vienna to Venice
    night train. Today it is a *variant* of the Archive (theme.json
    `"base": "archive"`, `services/Flavour.qml`), sharing its shell.
- **Shared look pieces**: ticket-stub workspaces, title-bar tickets
  (archivebars plugin, `dotfiles/.local/share/archive/plugins/archivebars`),
  the train along the bar (drag it; drop mid-screen for the night-train
  screensaver), keepsakes on the desk, the music box / cassette audio card,
  inked file icons (`tools/inked_icons.py`), lock screen seal.
- **Machine tools** (`dotfiles/.local/bin/archive-*`): `archive-lan` (mesh
  Wi-Fi detour, calm switching), `archive-rog` (GPU/power), `archive-refresh`,
  `archive-snapshot` (Timeshift), `archive-update`, `archive-ros` (rviz).
  `setup.sh` also bakes in: ssh keepalive, Wi-Fi power saving off.

## Next

The first job is in `docs/next-ideas.md` under **"Three separate boxes"**:
restructure so each theme is a self-contained box (Archive, Compartment 19
as a full copy, and the new theme), with only a tiny selector and a separate
machine-tools folder shared, then build the **new theme** in its own box.
Verify afterwards that, with one theme chosen, nothing from the others is
loaded or running.

Still open from before: the GPU switching check on the user's laptop
(`archive-rog status`, the "dGPU open by" line, after a reboot).

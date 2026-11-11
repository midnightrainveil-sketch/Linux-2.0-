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
- Never store passwords. (They once shared a robot password: never put it
  anywhere.)

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
- **Testing**: QML in the real Quickshell harness per box, after
  `ultra-theme apply <id>` into a scratch home; check no link of the other
  box is left (`find ~ -lname '*themes/<other>/*'`).

## Next

Build the **new, third theme** as its own box (`themes/<id>/`), mock-ups
first. Ideas kept in `docs/next-ideas.md`.

Still open from before: the GPU switching check on the user's laptop
(`ultra-rog status`, the "dGPU open by" line, after a reboot).

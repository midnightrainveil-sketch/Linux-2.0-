# Next ideas (notes, not started)

Kept from a braindump, to pick up in a later session.

- **The desk still feels empty.** Fill the open paper on the home screen
  (Compartment 19 especially) without crowding the terminal and cards.
- **A slight revamp of the whole UI** so everything fits the theme and looks
  better. Possibly have an image generator draw visual improvement ideas
  first, and build from those.
- **The key should do something.** The brass key on the clock card is only
  decorative (it swings); give it a real function.
- **The train ticket should stand out.** Keep its size and shape (the same
  as the workspace tickets) but change what is drawn on it, and maybe its
  colour.
- **The home button can be the train** (the little engine), now that the
  train ticket gets a different drawing.
- **A draggable train / screensaver.** Press and drag the bar's train: it
  follows like a snake. Let go near the middle of the screen and every
  window hides, the background dims, the train grows large and drives
  across, as a screensaver.
- **Files icons still look a little toy-like**, both folders and files.
  Redesign them, or have an image generator draw them.

## First job next session: three separate boxes

Before the new theme: make every theme a self-contained box, so that with
one chosen the machine behaves as if only it exists.

- **The drawer**: one small selector (the only shared part) reads the
  chosen theme at log-in and opens that box, and nothing else.
- **Each box** holds everything of its theme: Hyprland config, shell,
  wallpapers, icons, cursors, terminal look and startup card, lock screen,
  fonts, scripts, settings. No box refers to another.
  - the Archive moves into its own box;
  - Compartment 19 becomes a complete box of its own (a full copy, no
    longer a variant leaning on the Archive's shell);
  - the new theme is built as its own box from the start.
- **No global leftovers**: icon theme, cursors, GTK look, terminal config
  are applied by the chosen box for its session only.
- **Zero performance impact**: unchosen boxes are folders on disk, nothing
  loaded, started or scheduled from them.
- **Outside every box**: what is before log-in (boot splash, login screen,
  kernel: one per machine, set by the chosen box when chosen) and the
  machine's own tools (Wi-Fi fix, restore points, refresh rate, GPU,
  driver setup, archive-update), kept in a separate "machine" folder.
- **Verify**: with the new theme chosen, check no file, process or setting
  from the other two is loaded or running.

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

## Done: three separate boxes

Every theme is a self-contained box now (`themes/<id>/`), the machine's own
tools are in `core/`, and `ultra-theme` links only the chosen box into the
home folder (see `themes/README.md`). Compartment 19 is a full copy, no
longer a variant. Next: the new, third theme, built as its own box.

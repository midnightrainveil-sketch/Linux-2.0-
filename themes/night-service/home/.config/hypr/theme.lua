-- This theme's Hyprland side. ~/.config/hypr/hyprland.lua (the selector,
-- the same for every theme) has set up the machine: screens, GPUs, input,
-- PATH. Everything here, and everything it starts, belongs to this theme
-- alone; no other theme's files are linked into your home while it is on.
--
--   theme/look.lua      borders, shadows, motion, title bars
--   theme/binds.lua     keybinds
--   theme/rules.lua     window and layer rules
--   theme/state.lua     day / night, grain, settings.json
require("theme.look")
require("theme.binds")
require("theme.rules")

-- the cursors: the pencil, the gloves, the instruments
hl.env("XCURSOR_THEME", "Archive-Cursors")
hl.env("XCURSOR_SIZE", "40")
hl.env("HYPRCURSOR_SIZE", "40")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function()
    hl.exec_cmd("ultra-mode start")                 -- fonts, icons, cursors; day or night, by the clock
    hl.exec_cmd("ultra-bars ensure")                -- title bars: rebuild if Hyprland was updated
    hl.exec_cmd("ultra-icons ensure")               -- icons: remake if Papirus was updated
    hl.exec_cmd("hyprctl setcursor Archive-Cursors 40")
    hl.exec_cmd("ultra-shell")                      -- the shell (started again if it crashes)
    hl.exec_cmd("ultra-idle start")                 -- dim, lock, screen off (ultra-idle <minutes>)
    hl.exec_cmd("sh -c 'sleep 2; qs ipc call sound play login'")   -- the drawer slides open
    -- the desk terminal, as on the mockup (set "deskTerminal": false to skip)
    if require("theme.state").setting_bool("deskTerminal", true) then
        hl.exec_cmd("sh -c 'sleep 1; ultra-desk terminal'")
    end
end)

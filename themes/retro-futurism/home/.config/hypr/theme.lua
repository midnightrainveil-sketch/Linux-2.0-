-- Magnetic 88: this theme's Hyprland side. ~/.config/hypr/hyprland.lua (the
-- selector, the same for every theme) has set up the machine: screens,
-- GPUs, input, PATH. Everything here, and everything it starts, belongs to
-- this theme alone.
--
--   theme/look.lua      borders, gaps, motion
--   theme/binds.lua     keybinds
--   theme/rules.lua     window and layer rules, the terminal widget on the picture
require("theme.look")
require("theme.binds")
require("theme.rules")

-- the pointer: Magnetic 88's chrome and sage cursors (home/.local/share/icons/
-- Magnetic88, tools/make_cursors.py), 28 px ("cursorSize" in this theme's
-- settings.json for another size: 24, 32 ...)
local mine = require("ultra.state").settings((os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config"))
    .. "/ultra/retro-futurism/settings.json")
local cursor_size = tostring(math.floor(mine.number("cursorSize", 28)))
hl.env("XCURSOR_THEME", "Magnetic88")
hl.env("XCURSOR_SIZE", cursor_size)
hl.env("HYPRCURSOR_SIZE", cursor_size)

hl.on("hyprland.start", function()
    hl.exec_cmd("ultra-look")                       -- dark, monochrome, one typeface
    hl.exec_cmd("hyprctl setcursor Magnetic88 " .. cursor_size)
    hl.exec_cmd("ultra-rim ensure")                 -- the window rims: rebuilt if Hyprland was updated
    hl.exec_cmd("ultra-shell")                      -- the shell (started again if it crashes)
    hl.exec_cmd("ultra-idle start")                 -- dim, lock, screen off (ultra-idle <minutes>)
    -- the terminal widget on the picture (settings.json "deskTerminal": false for none)
    if require("ultra.state").settings((os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config"))
            .. "/ultra/retro-futurism/settings.json").bool("deskTerminal", true) then
        hl.exec_cmd("sh -c 'sleep 1; ultra-desk'")
    end
end)

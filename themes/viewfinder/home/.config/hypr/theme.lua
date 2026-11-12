-- Viewfinder: this theme's Hyprland side. ~/.config/hypr/hyprland.lua (the
-- selector, the same for every theme) has set up the machine: screens,
-- GPUs, input, PATH. Everything here, and everything it starts, belongs to
-- this theme alone.
--
--   theme/look.lua      borders, gaps, motion
--   theme/binds.lua     keybinds
--   theme/rules.lua     window and layer rules, the small terminal on the picture
require("theme.look")
require("theme.binds")
require("theme.rules")

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    hl.exec_cmd("ultra-look")                       -- dark, monochrome, one typeface
    hl.exec_cmd("hyprctl setcursor Adwaita 24")
    hl.exec_cmd("ultra-shell")                      -- the shell (started again if it crashes)
    hl.exec_cmd("ultra-idle start")                 -- dim, lock, screen off (ultra-idle <minutes>)
    -- the small terminal on the picture (settings.json "deskTerminal": false to skip)
    if require("ultra.state").settings((os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config"))
            .. "/ultra/viewfinder/settings.json").bool("deskTerminal", true) then
        hl.exec_cmd("sh -c 'sleep 1; ultra-desk'")
    end
end)

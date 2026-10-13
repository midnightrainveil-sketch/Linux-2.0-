-- Hyprland (0.55+, Lua config) for the Archive desktop.
--
-- The desktop is a botanical archive sheet: windows are typed index cards,
-- the wallpaper is the pressed specimen, the bar is the printed footer.
-- Hyprland handles the windows; Quickshell (~/.config/quickshell) draws the
-- rest. Colours follow ~/.local/state/archive/mode (day / night), which
-- `archive-mode` writes before asking Hyprland to reload this file.
--
--   archive/machine.lua   monitor, GPUs and input for the Zephyrus G14
--   archive/look.lua      borders, shadows, motion, title bars
--   archive/binds.lua     keybinds
--   archive/rules.lua     window and layer rules
--   user.lua              your own additions (optional, not tracked)

require("archive.machine")
require("archive.look")
require("archive.binds")
require("archive.rules")

------------------------------------------------------------------ environment
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

------------------------------------------------------------------ permissions
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")

------------------------------------------------------------------ autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("archive-mode auto")                  -- day or night, by the clock
    hl.exec_cmd("hyprpm reload -n")                   -- hyprbars title bars
    hl.exec_cmd("qs")                                 -- the shell
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("sh -c 'sleep 2; qs ipc call sound play login'")   -- the drawer slides open
    -- the desk terminal, as on the mockup (set "deskTerminal": false to skip)
    if require("archive.state").setting_bool("deskTerminal", true) then
        hl.exec_cmd("sh -c 'sleep 1; foot --app-id=archive.desk env ARCHIVE_DESK=1 zsh'")
    end
end)

------------------------------------------------------------------ your additions
pcall(require, "user")

-- Hyprland (0.55+, Lua config): the selector. The same file whatever the
-- theme; it holds nothing of any theme's look.
--
--   1. which theme this session is (chosen in the Themes app or with
--      ultra-theme; read once as the session starts and kept for it)
--   2. that theme's files linked into your home, the previous theme's taken
--      out (ultra-theme apply): only one theme is ever present
--   3. the machine: screens, GPUs, input (ultra/machine.lua)
--   4. the theme's own config, ~/.config/hypr/theme.lua
--   5. your own additions, ~/.config/hypr/user.lua (optional, not tracked)
local home = os.getenv("HOME") or ""

------------------------------------------------------------------ which theme
do
    local function first_line(path)
        local f = io.open(path, "r")
        if f == nil then return nil end
        local s = f:read("*l")
        f:close()
        return s and s:match("^%s*([%w_%-]+)") or nil
    end
    local mark = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/ultra-theme-" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "")
    if first_line(mark) == nil then
        -- a new session: put the chosen theme in place (a moment's work
        -- when it already is), before anything of it is read
        os.execute('"' .. home .. '/.local/bin/ultra-theme" apply --session >/dev/null 2>&1')
        local theme = first_line((os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/ultra/applied") or "none"
        local f = io.open(mark, "w")
        if f ~= nil then f:write(theme, "\n"); f:close() end
    end
end

------------------------------------------------------------------ environment
-- the ultra-* commands live in ~/.local/bin; every login path must see them
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))
-- Flatpak apps (GeForce NOW ...) keep their launcher entries in their own
-- folders: launchers look there too
do
    local dirs = os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    for _, d in ipairs({ "/var/lib/flatpak/exports/share", home .. "/.local/share/flatpak/exports/share" }) do
        if not dirs:find(d, 1, true) then dirs = d .. ":" .. dirs end
    end
    hl.env("XDG_DATA_DIRS", dirs)
end
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- GTK 4 programs (Nautilus...) draw with OpenGL, not Vulkan: Vulkan opens
-- every graphics driver, the NVIDIA one too, which wakes that chip (a
-- second's wait, and its power) at every launch. Games are not GTK.
hl.env("GSK_RENDERER", "ngl")
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

------------------------------------------------------------------ the machine
require("ultra.machine")

hl.on("hyprland.start", function()
    hl.exec_cmd("ultra-brightness init")            -- a software dim, if the panel needs one
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("sh -c 'sleep 4; ultra-mic tone'")   -- the microphone's tone, as last chosen
end)

------------------------------------------------------------------ the theme
local conf = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr/"
if require("ultra.state").exists(conf .. "theme.lua") then
    dofile(conf .. "theme.lua")
else
    -- no theme in place (ultra-theme apply could not run): a bare desk you
    -- can still work from. Super + Return a terminal, there: ultra-theme apply
    hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
    hl.bind("SUPER + Q", hl.dsp.window.close())
    hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
end

------------------------------------------------------------------ your additions
pcall(require, "user")

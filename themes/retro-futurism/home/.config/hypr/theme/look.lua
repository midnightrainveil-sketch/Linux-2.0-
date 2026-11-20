-- Windows in chrome: the taskbar's rim round each one, drawn by Hyprland
-- itself with the theme's chromerim plugin (built for your Hyprland by
-- ultra-rim, from ~/.local/share/ultra/retro-futurism/plugins/chromerim), so
-- it moves, slides and resizes with the window in the same frame, at any
-- size. Until it is built (and round X11 windows) the shell draws the same
-- rim instead (modules/Backdrop.qml). Hyprland's own border stays off. The
-- gaps leave room for the rim and go with Theme.qml's frame values:
--   gaps_out 38 = 22 (screen edge to rim) + 17 (the rim: the taskbar's) - 1
--                 (the window over its inner edge: they touch)
--   gaps_in  19 = 17 - 1 + 3, so 6 px lie between two rims
local ink, grey = "f2efed", "6b6766"

hl.config({
    general = {
        border_size = 0,
        gaps_in = 19,
        gaps_out = 38,              -- nearly fullscreen, the rim in the margin
        float_gaps = 38,
        layout = "dwindle",
        resize_on_border = true,
        col = {
            active_border = "rgb(" .. ink .. ")",
            inactive_border = "rgb(" .. grey .. ")",
        },
    },

    decoration = {
        rounding = 9,               -- Theme.windowRounding: the chrome's inner corner
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = false,
        -- blur only where the shell asks for it (the widget stage)
        blur = { enabled = true, size = 7, passes = 3, noise = 0.02, vibrancy = 0.12 },
        shadow = { enabled = false },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(0b0a0b)",       -- seen only before the shell draws the picture
        font_family = "JetBrains Mono",
        focus_on_activate = false,
        allow_session_lock_restore = true,      -- if the shell restarts while locked
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
        -- variable refresh only for a fullscreen game or video; never on the
        -- desk, where an OLED can flicker with it
        vrr = 3,
    },

    -- a fullscreen video or game goes straight to the panel
    render = {
        direct_scanout = 2,
    },

    cursor = {
        inactive_timeout = 8,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

------------------------------------------------------------------ motion
-- quick and plain: windows slide in from their nearest edge and out the
-- same way (no fading); workspaces slide left and right
hl.curve("settle", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("leave", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "settle" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.6, bezier = "settle", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "leave", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "settle" })
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeOut", enabled = false })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, bezier = "settle" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.4, bezier = "settle", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "settle", style = "slidefade 8%" })
-- the shell draws its own surfaces; Hyprland just shows them
hl.animation({ leaf = "layers", enabled = false })

------------------------------------------------------------------ the rim
-- chromerim, if built (ultra-rim). If Hyprland ever crashed inside this
-- build, it is left out (the shell draws the rim) rather than crash at every
-- login; `ultra-rim retry` or a rebuild brings it back.
local data = os.getenv("XDG_DATA_HOME") or ((os.getenv("HOME") or "") .. "/.local/share")
local rim_so = data .. "/ultra/retro-futurism/plugins/chromerim.so"
if require("ultra.state").exists(rim_so) then
    if os.execute((os.getenv("HOME") or "") .. "/.local/bin/ultra-rim crashed") == true then
        hl.on("hyprland.start", function()
            hl.exec_cmd([[notify-send --app-name "Cassette OS" "Window rims drawn by the shell." "Hyprland crashed in the rim plugin last time. Run: ultra-rim retry"]])
        end)
    else
        hl.plugin.load(rim_so)
    end
end
if hl.plugin ~= nil and hl.plugin.chromerim ~= nil then
    hl.config({ plugin = { chromerim = {
        enabled = true,
        width = 17,                 -- Theme.frameRim: the taskbar's rim at its size
        overlap = 1,                -- the inner edge a pixel under the window
        dim = "rgba(1f1a1452)",     -- a window not in use: a shade darker, still solid
    } } })
    -- your own window without it: hl.window_rule({ match = { class = "..." }, ["chromerim:no_rim"] = true }) in user.lua
end

-- Windows in frames: the shell draws the mock-up's sage-and-chrome frame
-- round each one (modules/Backdrop.qml), so Hyprland draws no border and
-- leaves room for the frame. These gaps go with Theme.qml's frame values:
--   gaps_out 30 = 22 (screen edge to frame) + 9 (the chrome) - 1 (the window
--                 over its inner edge: they touch)
--   gaps_in  11 = 9 - 1 + 3, so 6 px lie between two frames
local ink, grey = "f2efed", "6b6766"

hl.config({
    general = {
        border_size = 0,
        gaps_in = 11,
        gaps_out = 30,              -- nearly fullscreen, the frame in the margin
        float_gaps = 30,
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

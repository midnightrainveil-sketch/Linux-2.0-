-- Windows in frames: the shell draws the mock-up's sage-and-chrome frame
-- round each one (modules/Backdrop.qml), so Hyprland draws no border and
-- leaves room for the frame. These gaps go with Theme.qml's frame values:
--   gaps_out 45 = 22 (screen edge to frame) + 17 (the rim) + 6 (inside it)
--   gaps_in  29 = 17 + 6 + 6, so 12 px lie between two frames
local ink, grey = "f2efed", "6b6766"

hl.config({
    general = {
        border_size = 0,
        gaps_in = 29,
        gaps_out = 45,              -- nearly fullscreen, the frame in the margin
        float_gaps = 45,
        layout = "dwindle",
        resize_on_border = true,
        col = {
            active_border = "rgb(" .. ink .. ")",
            inactive_border = "rgb(" .. grey .. ")",
        },
    },

    decoration = {
        rounding = 6,               -- inside the frame's rounded rim
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = false,
        blur = { enabled = false },
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
-- quick and plain: a window comes into focus, it does not bounce
hl.curve("settle", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("leave", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "settle" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "settle", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "leave", style = "popin 97%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "settle" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "settle" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "leave" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, bezier = "settle" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.4, bezier = "settle", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "settle", style = "slidefadevert 8%" })
-- the shell draws its own surfaces; Hyprland just shows them
hl.animation({ leaf = "layers", enabled = false })

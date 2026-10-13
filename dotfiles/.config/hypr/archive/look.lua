-- Windows as cards of thicker stock lying on the sheet (spec section 6).
-- Focus is shown physically: the focused card is lifted (2 px graphite
-- border, 14 px shadow), the others lie flat. No rounding, blur or dimming.
local state = require("archive.state")
local palette = require("archive.palette")

local mode = state.mode()
local c = palette[mode]
local reduced = state.setting_bool("reducedMotion", false)

local function rgb(hex) return "rgb(" .. hex .. ")" end
local function rgba(hex, a) return "rgba(" .. hex .. a .. ")" end

hl.config({
    general = {
        border_size = 2,
        gaps_in = 4,                -- 8 px between tiled windows
        gaps_out = 24,              -- 24 px to the screen edge
        float_gaps = 24,
        layout = "dwindle",
        resize_on_border = true,
        col = {
            active_border = rgb(c.graphite),
            inactive_border = rgb(c.rule_faint),
        },
    },

    decoration = {
        rounding = 0,               -- a cut card, never rounded
        active_opacity = 1.0,
        inactive_opacity = 1.0,     -- dimming looks digital
        dim_inactive = false,
        blur = { enabled = false },
        shadow = {
            enabled = true,
            range = 14,
            render_power = 3,
            offset = { 0, 4 },
            color = rgba(c.shadow, c.shadow_active),
            color_inactive = rgba(c.shadow, c.shadow_inactive),
        },
        -- optional film grain over everything (archive-grain / Super+Shift+G)
        screen_shader = state.grain() and (state.config_dir .. "/hypr/shaders/grain.frag") or "",
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = rgb(c.paper_base),   -- seen only before the shell draws the plate
        font_family = "Courier Prime",
        focus_on_activate = false,
        allow_session_lock_restore = true,      -- if the shell restarts while locked
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
        vfr = true,
    },

    cursor = {
        inactive_timeout = 8,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

------------------------------------------------------------------ motion (section 11)
-- place = cubic-bezier(0.22, 1, 0.36, 1): a smooth ease-out (the card lands)
-- lift  = cubic-bezier(0.4, 0, 1, 1):     a quick ease-in (the card is lifted off)
-- speed is in deciseconds: 2.2 = 220 ms.
hl.curve("place", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("lift", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

if reduced then
    -- reduced motion: every transition is a 100 ms fade
    hl.animation({ leaf = "global", enabled = true, speed = 1, bezier = "linear" })
    hl.animation({ leaf = "windows", enabled = true, speed = 1, bezier = "linear", style = "popin 100%" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "linear", style = "fade" })
else
    hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "place" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "place", style = "popin 97%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.4, bezier = "lift", style = "popin 97%" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, bezier = "place" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.2, bezier = "place" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.4, bezier = "lift" })
    hl.animation({ leaf = "fade", enabled = true, speed = 1.6, bezier = "place" })
    hl.animation({ leaf = "border", enabled = true, speed = 1.6, bezier = "place" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "place", style = "slidefade 15%" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.2, bezier = "place", style = "slidefadevert 8%" })
end
-- the shell animates its own cards; Hyprland just shows them
hl.animation({ leaf = "layers", enabled = false })

------------------------------------------------------------------ title bars (hyprbars plugin)
-- 28 px, paper.card, title in Courier Prime 12; three small ink dots on the
-- left instead of red / yellow / green: file away (close), full sheet
-- (maximise), drawer (minimise to the scratchpad).
-- The plugin loads after the first config pass (hyprpm reload), and Hyprland
-- re-reads this file once it has, so these lines are simply skipped at first.
if hl.plugin ~= nil and hl.plugin.hyprbars ~= nil then
    hl.config({
        plugin = {
            hyprbars = {
                enabled = true,
                bar_height = 28,
                bar_color = rgb(c.paper_card),
                col = { text = rgb(c.graphite) },
                bar_text_font = "Courier Prime",
                bar_text_size = 12,
                bar_text_weight = "normal",
                bar_text_align = "left",
                bar_buttons_alignment = "left",
                bar_padding = 12,
                bar_button_padding = 6,
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                bar_blur = false,
                inactive_button_color = rgb(c.rule_faint),
                on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
            },
        },
    })

    local dot = { bg_color = rgb(c.faded), fg_color = rgb(c.faded), size = 8, icon = "" }
    -- buttons are listed from the outer edge inwards
    hl.plugin.hyprbars.add_button({ bg_color = dot.bg_color, fg_color = dot.fg_color, size = dot.size, icon = dot.icon,
        action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = dot.bg_color, fg_color = dot.fg_color, size = dot.size, icon = dot.icon,
        action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = dot.bg_color, fg_color = dot.fg_color, size = dot.size, icon = dot.icon,
        action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:drawer", follow = false })']] })

    -- unfocused cards: title in ink.faded
    hl.window_rule({
        name = "archive-bar-unfocused",
        match = { focus = false },
        ["hyprbars:title_color"] = rgb(c.faded),
    })
    -- no title bar on the shell's own surfaces or on fullscreen windows
    hl.window_rule({ name = "archive-bar-fullscreen", match = { fullscreen = true }, ["hyprbars:no_bar"] = true })
end

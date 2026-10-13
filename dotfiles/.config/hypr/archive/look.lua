-- Windows as cards of thicker stock lying on the sheet, drawn to the
-- reference: no hard black frame, but the card's cut edge, a thin rim that is
-- light along the top and darkest along the bottom where the card's thickness
-- meets its shadow; a short soft shadow falling down onto the sheet; a 46 px
-- paper title bar with three ink dots, the typed title, a "-" on the right
-- and a ruled line underneath. Focus lifts the card: darker rim, deeper shadow.
local state = require("archive.state")
local palette = require("archive.palette")

local mode = state.mode()
local c = palette[mode]
local reduced = state.setting_bool("reducedMotion", false)

local function rgb(hex) return "rgb(" .. hex .. ")" end
local function rgba(hex, a) return "rgba(" .. hex .. a .. ")" end

hl.config({
    general = {
        border_size = 1,            -- 1.5 physical px at the G14's 1.5 scale: the cut edge
        gaps_in = 4,                -- 8 px between tiled windows
        gaps_out = 24,              -- 24 px to the screen edge
        float_gaps = 24,
        layout = "dwindle",
        resize_on_border = true,
        col = {
            -- top to bottom: the cut edge catching light, then its shadowed underside
            active_border = { colors = { rgb(c.rim_top), rgb(c.rim_top), rgb(c.rim_bottom) }, angle = 90 },
            inactive_border = { colors = { rgb(c.rim_top_flat), rgb(c.rim_top_flat), rgb(c.rim_bottom_flat) }, angle = 90 },
        },
    },

    decoration = {
        rounding = 2,               -- a cut card: square, just worn at the corners
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,     -- dimming looks digital
        dim_inactive = false,
        blur = { enabled = false },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 2,
            offset = { -1, 4 },
            color = rgba(c.shadow, c.shadow_active),
            color_inactive = rgba(c.shadow, c.shadow_inactive),
        },
        -- paper texture and ink roughness over every window (archive-grain / Super+Shift+G)
        screen_shader = state.grain() and (state.config_dir .. "/hypr/shaders/paper.frag") or "",
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

------------------------------------------------------------------ title bars
-- archivebars is hyprbars plus a ruled line and a right-hand glyph, built
-- for this Hyprland by `archive-bars` (see the guide). Measured off the
-- reference terminal card at 1920 px: 46 px bar, three 11 px ink dots 21 px
-- apart starting 20 px in, the title in Courier Prime 18, a "-" 18 px from the
-- right edge, and a rule 2 px thick, 11 px in from each side.
local bars_so = (os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")) .. "/archive/plugins/archivebars.so"
if state.exists(bars_so) then
    hl.plugin.load(bars_so)
end

local drawer = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:drawer", follow = false })']]

local function bars(name, extras)
    local opts = {
        enabled = true,
        bar_height = 46,
        bar_color = rgb(c.paper_card),
        col = { text = rgb(c.soft) },
        bar_text_font = "Courier Prime",
        bar_text_size = 18,
        bar_text_weight = "normal",
        bar_text_align = "left",
        bar_buttons_alignment = "left",
        bar_padding = 20,
        bar_button_padding = 10,
        bar_part_of_window = true,
        bar_precedence_over_border = false,
        bar_blur = false,
        inactive_button_color = rgb(c.dot_flat),
        on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
    }
    for k, v in pairs(extras or {}) do opts[k] = v end
    hl.config({ plugin = { [name] = opts } })

    -- three ink dots: file away (close), full sheet (maximise), drawer (minimise)
    local api = hl.plugin[name]
    for _, action in ipairs({
        [[hyprctl dispatch 'hl.dsp.window.close()']],
        [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
        drawer,
    }) do
        api.add_button({ bg_color = rgb(c.dot), fg_color = rgb(c.dot), size = 11, icon = "", action = action })
    end

    hl.window_rule({ name = "archive-bar-unfocused", match = { focus = false }, [name .. ":title_color"] = rgb(c.faded) })
    hl.window_rule({ name = "archive-bar-fullscreen", match = { fullscreen = true }, [name .. ":no_bar"] = true })
end

if hl.plugin ~= nil and hl.plugin.archivebars ~= nil then
    bars("archivebars", {
        rule_color = rgba(c.rule_ink, "aa"),
        rule_width = 1,
        rule_inset = 11,
        right_icon = "–",
        right_icon_action = drawer,
        right_icon_color = rgb(c.soft),
        right_icon_size = 20,
    })
elseif hl.plugin ~= nil and hl.plugin.hyprbars ~= nil then
    -- stock hyprbars (from hyprpm) as a fallback: same bar, without the rule and the "-"
    bars("hyprbars")
end

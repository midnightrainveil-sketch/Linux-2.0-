-- Windows as cards of thicker stock lying on the sheet, drawn to the
-- reference: no hard black frame, but the card's cut edge, a thin rim that is
-- light along the top and darkest along the bottom where the card's thickness
-- meets its shadow; a short soft shadow falling down onto the sheet; a 46 px
-- paper title bar with three ink dots, the typed title, a "-" on the right
-- and a ruled line underneath. Focus lifts the card: darker rim, deeper shadow.
--
-- With archivebars built, the edge is torn paper rather than a straight line:
-- the plugin lays a card a few pixels larger than the window, out of short
-- repeating tiles so it fits any window size: a deckled, chipped edge lit
-- from the top left, a shadow falling down and to the right, and over the
-- window's padding an aged edge, small tears, wrinkles and the odd creased
-- corner. The straight border and Hyprland's shadow are then switched off.
-- Without the plugin the plain border below is the fallback.
local state = require("archive.state")
local palette = require("archive.palette")

local mode = state.mode()
local c = palette[mode]
-- Folio (by day, the default look): the windows' torn edge turned up a step,
-- to match the shell's cards. Like them it is depth, not darkness: the cut
-- wanders further and the shadow falls longer (half way from the original
-- to the full design), while the rim's colour and weight move only a sixth
-- as far and the title bars stay plain (the shell's Theme.folioAmount and
-- inkAmount). Original and dark as before.
local folio = state.folio()
local depth = folio and 0.5 or 0
local ink = depth / 6
local function fv(original, full) return original + (full - original) * depth end
local function fvi(original, full) return original + (full - original) * ink end
local function fhex(original, full, k) -- hex colours (or a lone alpha byte), blended k of the way
    return (original:gsub("()(%x%x)", function(i, byte)
        local a = tonumber(byte, 16)
        local v = a + (tonumber(full:sub(i, i + 1), 16) - a) * k
        return string.format("%02x", math.floor(v + 0.5))
    end))
end
if folio then
    local f = {}
    for k, v in pairs(c) do f[k] = v end
    f.edge_top, f.edge_top_flat = fhex(c.edge_top, "8a8580", ink), fhex(c.edge_top_flat, "a29d97", ink)
    f.rim_bottom = fhex(c.rim_bottom, "47433f", ink)
    f.edge_shadow, f.edge_shadow_flat = fhex(c.edge_shadow, "80", depth), fhex(c.edge_shadow_flat, "4d", depth)
    c = f
end
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
        -- no screen shader: the paper grain is drawn per window by the plugin
        -- (a whole-screen shader also grained videos and photos, and left
        -- faint boxes where only part of the screen was redrawn)
        screen_shader = "",
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
-- If Hyprland ever crashed inside this build of the plugin, leave it out (plain
-- edges) rather than crash at every login; `archive-bars retry` or a rebuild
-- brings it back.
local home = os.getenv("HOME") or ""
local bars_crashed = state.exists(bars_so) and os.execute(home .. "/.local/bin/archive-bars crashed") == true
if bars_crashed then
    hl.on("hyprland.start", function()
        hl.exec_cmd([[notify-send --app-name Archive "Title bars are off." "Switched off, or Hyprland crashed in them last time. Run: archive-bars on"]])
    end)
elseif state.exists(bars_so) then
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

    -- three ink dots, in the usual order: file away (close, red), drawer
    -- (minimise, yellow), full sheet (maximise and back, green; on the desk
    -- terminal it lifts it into an ordinary window instead: archive-desk dot)
    local api = hl.plugin[name]
    -- each in its own muted pigment (palette.lua); grey on unfocused windows
    for _, b in ipairs({
        { [[hyprctl dispatch 'hl.dsp.window.close()']], c.dot_close },
        { drawer, c.dot_away },
        { "archive-desk dot", c.dot_full },
    }) do
        api.add_button({ bg_color = rgb(b[2]), fg_color = rgb(b[2]), size = 11, icon = "", action = b[1] })
    end

    hl.window_rule({ name = "archive-bar-unfocused", match = { focus = false }, [name .. ":title_color"] = rgb(c.faded) })
    -- true fullscreen (Super+F) has no bar; a maximised window keeps it, and
    -- its green dot to go back ("fullscreen" alone matches maximised too)
    hl.window_rule({ name = "archive-bar-fullscreen", match = { fullscreen_state_internal = 2 }, [name .. ":no_bar"] = true })
end

if hl.plugin ~= nil and hl.plugin.archivebars ~= nil then
    local extras = {
        rule_color = rgba(c.rule_ink, "aa"),
        rule_width = 1,
        rule_inset = 11,
        right_icon = "–",
        right_icon_action = drawer,
        right_icon_color = rgb(c.soft),
        right_icon_size = 20,
    }

    -- paper grain over terminals and system tools (rules below); the "░"
    -- left of the "–" shows it (ink: on, faded: off) and flips it for one
    -- window, as does Super+Shift+G. archive-grain off turns it off everywhere.
    -- (Only with a plugin built with grain: an older build, still loaded until
    -- the next login after an update, would reject these.)
    local has_grain = hl.plugin.archivebars.toggle_grain ~= nil
    if has_grain then
        extras.grain = state.grain() and 1 or 0
        extras.grain_default = false
        extras.grain_icon = "░"
        extras.grain_icon_color = rgb(c.soft)
        extras.grain_icon_color_off = rgba(c.faded, "66")
    end

    -- which windows are paper: the terminal and the system's own tools.
    -- Browsers, players, editors and anything new keep their true colours.
    local paper_apps = {
        "^(foot|footclient|archive\\.desk|kitty|Alacritty|com\\.mitchellh\\.ghostty|org\\.wezfurlong\\.wezterm)$",
        "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|blueman-manager|\\.blueman-manager-wrapped|nm-connection-editor)$",
        "^(org\\.gnome\\.Calculator|qalculate-gtk|hyprpolkitagent|org\\.hyprland\\.polkitagent|rog-control-center)$",
        "^(nwg-look|qt6ct|qt5ct|thunar|Thunar|org\\.gnome\\.Nautilus|pcmanfm|pcmanfm-qt|btop|htop)$",
        "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\.gtk)$",
    }
    for i, class in ipairs(has_grain and paper_apps or {}) do
        hl.window_rule({ name = "archive-paper-" .. i, match = { class = class }, ["archivebars:grain"] = true })
    end
    -- your own: hl.window_rule({ match = { class = "^obsidian$" }, ["archivebars:grain"] = true }) in user.lua

    -- torn paper edges (settings.json "paperEdges": false turns them off)
    local deckle = hl.plugin.archivebars.has_deckle ~= nil and state.setting_bool("paperEdges", true)
    if deckle then
        extras.deckle = true
        extras.deckle_margin = 6                  -- the card's edge, 6 px outside the window
        extras.deckle_amplitude = fv(1.2, 1.8)   -- how far the cut wanders
        extras.deckle_rim_width = fvi(1.3, 1.8)
        extras.deckle_paper = rgb(c.paper_card)   -- same paper as the title bar and terminal
        extras.deckle_rim_top = rgb(c.edge_top)
        extras.deckle_rim_bottom = rgb(c.rim_bottom)
        extras.deckle_rim_top_inactive = rgb(c.edge_top_flat)
        extras.deckle_rim_bottom_inactive = rgb(c.rim_bottom_flat)
        extras.deckle_bevel = rgba(c.bevel, c.bevel_alpha)
        extras.deckle_shadow = rgba(c.shadow, c.edge_shadow)
        extras.deckle_shadow_inactive = rgba(c.shadow, c.edge_shadow_flat)
        extras.deckle_shadow_blur = fv(4.5, 5.5)   -- falls down and to the right
        extras.deckle_shadow_x = fv(1.5, 2.3)
        extras.deckle_shadow_y = fv(3, 4.6)
        extras.deckle_tone = rgba(c.edge_tone, c.edge_tone_alpha)   -- the aged edge
        extras.deckle_tone_depth = 18
        extras.deckle_chips = 1                   -- chips, tears and wrinkles (0 = a clean cut)
        extras.deckle_creases = 1                 -- creased corners (0 = none)
    end
    bars("archivebars", extras)

    if deckle then
        hl.config({
            general = { border_size = 0, gaps_in = 10 },  -- 20 px between windows: 6 + 6 of card, 8 of desk
            decoration = { rounding = 0, shadow = { enabled = false } },
        })
        -- fullscreen windows have no edge; a window that draws its own frame can opt out:
        --   hl.window_rule({ match = { class = "..." }, ["archivebars:no_deckle"] = true })
    end
elseif hl.plugin ~= nil and hl.plugin.hyprbars ~= nil then
    -- stock hyprbars (from hyprpm) as a fallback: same bar, without the rule and the "-"
    bars("hyprbars")
end

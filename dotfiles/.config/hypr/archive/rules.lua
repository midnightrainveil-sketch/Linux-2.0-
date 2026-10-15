-- Window and layer rules.
local state = require("archive.state")
local palette = require("archive.palette")
local c = palette[state.mode()]

------------------------------------------------------------------ the desk terminal
-- At rest the left desk holds one terminal card (the reference's fastfetch
-- card): floating by the left edge, 31 % of the screen wide, and 4:3 with
-- its 46 px title bar (room for the card's portrait), clear of the plate's
-- big leaf.
-- archive-desk (the bar's desk button, Super+D) puts it back here and opens
-- it at login; keep the two in step.
hl.window_rule({
    name = "archive-desk",
    match = { class = "^archive\\.desk$" },
    float = true,
    size = { "monitor_w*0.3125", "monitor_w*0.3125*3/4-46" },
    move = { "monitor_w*0.019", "monitor_h*0.25" },
})

------------------------------------------------------------------ the desk terminal stays at the back
-- The desk terminal is part of the desk: every other window goes over it.
-- Hyprland always draws floating windows over tiled ones, so a floating card
-- cannot sit under an app. Instead, while its workspace holds a tiled window
-- (which fills the screen and would cover it anyway), the terminal steps off
-- the desk into the hidden special:desk, and it comes back when the last one
-- closes or floats. Among floating windows it is kept lowest, even right
-- after you click into it. The desk button (archive-desk, Super+D) still
-- brings it forward over everything; it steps back once you focus another
-- window. Newly opened terminals are ordinary windows.
local desk_home = nil   -- the workspace it stepped off (forgotten on reload)

local function is_desk(w)
    return w ~= nil and w.class == "archive.desk"
end

local function find_desk()
    for _, w in ipairs(hl.get_windows()) do
        if is_desk(w) and w.mapped then return w end
    end
end

-- does a tiled window (other than `gone`, which is closing) cover `ws`?
local function covered(ws, gone)
    if ws == nil then return false end
    for _, w in ipairs(hl.get_workspace_windows(ws)) do
        if not is_desk(w) and not w.floating and not w.hidden and (gone == nil or w.address ~= gone.address) then
            return true
        end
    end
    return false
end

local function tuck(gone)
    local desk = find_desk()
    if desk == nil or desk.workspace == nil then return end
    if desk.workspace.special then
        -- only bring it back from where we put it (not from the drawer)
        if desk.workspace.name ~= "special:desk" then return end
        local home = desk_home or hl.get_active_workspace().id
        if not covered(hl.get_workspace(tostring(home)), gone) then
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(home), follow = false, window = desk }))
        end
        return
    end
    local active = hl.get_active_window()
    if active ~= nil and active.address == desk.address then return end   -- brought forward on purpose
    if covered(desk.workspace, gone) then
        desk_home = desk.workspace.id
        hl.dispatch(hl.dsp.window.move({ workspace = "special:desk", follow = false, window = desk }))
    end
end

local function keep_back(w)
    if is_desk(w) and w.floating then
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = w }))
    end
end

hl.on("window.open", function(w) if not is_desk(w) then tuck() end end)
hl.on("window.close", function(w) if not is_desk(w) then tuck(w) end end)
hl.on("window.move_to_workspace", function(w) if not is_desk(w) then tuck() end end)
hl.on("window.update_rules", function(w) if not is_desk(w) then tuck() end end)   -- floated / tiled
hl.on("window.active", function(w)
    keep_back(w)
    if not is_desk(w) then tuck() end
end)

-- An empty workspace is a clean desk: going to one lays the desk out there,
-- the terminal at its place (moved over, or opened again if it was closed)
-- and the cards back in theirs, as at login.
hl.on("workspace.active", function(ws)
    if ws == nil or ws.special then return end
    for _, w in ipairs(hl.get_workspace_windows(ws)) do
        if not is_desk(w) then return end
    end
    local desk = find_desk()
    if desk ~= nil and desk.workspace ~= nil and desk.workspace.id == ws.id then return end
    hl.exec_cmd("archive-desk")
end)

------------------------------------------------------------------ small tools float as centred cards
-- (volume mixer, file picker, calculator, Bluetooth, network, authorisation)
local small_tools = {
    { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$", size = { 760, 540 } },
    { class = "^(blueman-manager|\\.blueman-manager-wrapped)$", size = { 640, 480 } },
    { class = "^nm-connection-editor$", size = { 640, 480 } },
    { class = "^(org\\.gnome\\.Calculator|qalculate-gtk)$", size = { 420, 560 } },
    { class = "^(hyprpolkitagent|org\\.hyprland\\.polkitagent)$", size = { 520, 260 } },
    { class = "^rog-control-center$", size = { 960, 680 } },
    { class = "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\.gtk)$", size = { 980, 640 } },
    { class = "^(nwg-look|qt6ct)$", size = { 900, 640 } },
    { class = "^(org\\.gnome\\.gThumb|gthumb|Gthumb)$", size = { 1240, 820 } },
}
for i, t in ipairs(small_tools) do
    hl.window_rule({ name = "archive-tool-" .. i, match = { class = t.class }, float = true, center = true, size = t.size })
end
-- file pickers, by title, from any toolkit
hl.window_rule({
    name = "archive-file-picker",
    match = { title = "^(Open File|Open Folder|Save As|Save File|Select a File|Choose Files|File Upload).*" },
    float = true, center = true, size = { 980, 640 },
})
hl.window_rule({ name = "archive-modal", match = { modal = true }, float = true, center = true })

------------------------------------------------------------------ fullscreen: no border, no shadow
hl.window_rule({ name = "archive-fullscreen", match = { fullscreen = true }, border_size = 0, no_shadow = true })

------------------------------------------------------------------ urgent windows: accent.ink border
hl.window_rule({ name = "archive-urgent", match = { tag = "urgent" }, border_color = "rgb(" .. c.accent .. ")" })
hl.on("window.urgent", function(w)
    if w ~= nil then hl.dispatch(hl.dsp.window.tag({ tag = "+urgent", window = w })) end
end)
hl.on("window.active", function(w)
    if w ~= nil then hl.dispatch(hl.dsp.window.tag({ tag = "-urgent", window = w })) end
end)

------------------------------------------------------------------ misc
hl.window_rule({ name = "archive-no-maximize-requests", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "archive-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
-- picture-in-picture as a small pinned card in the lower right
hl.window_rule({
    name = "archive-pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true, pin = true, size = { 480, 270 }, move = { "monitor_w-512", "monitor_h-342" },
})
-- a video or game in fullscreen keeps the screen awake
hl.window_rule({ name = "archive-idle", match = { fullscreen = true }, idle_inhibit = "fullscreen" })

------------------------------------------------------------------ the shell's own surfaces
-- Quickshell animates its own cards (rise 8 px, fade); no second animation.
hl.layer_rule({ name = "archive-layers", match = { namespace = "^archive-" }, no_anim = true })

-- Window and layer rules.

-- every handler here runs guarded: a window or workspace that is gone by the
-- time it runs (a three-finger swipe makes a workspace and drops it again)
-- must not stop the others or put up Hyprland's error bar; it is logged
local function on(event, fn)
    hl.on(event, function(...)
        local ok, err = pcall(fn, ...)
        if not ok then print("viewfinder rules: " .. event .. ": " .. tostring(err)) end
    end)
end

-- A window handed to a handler can close before the handler acts on it.
-- Hyprland puts up its error bar for a dispatcher given such a window, past
-- any pcall; its fields read as nil, so look before dispatching.
local function alive(w)
    return w ~= nil and w.address ~= nil
end

------------------------------------------------------------------ the small terminal on the picture
-- At rest the picture holds one small terminal, floating where the
-- reference has it. ultra-desk (Super+D) puts it back here and opens it at
-- login; keep the two in step.
hl.window_rule({
    name = "viewfinder-desk",
    match = { class = "^viewfinder\\.desk$" },
    float = true,
    size = { "monitor_w*0.2146", "monitor_h*0.2217" },
    move = { "monitor_w*0.1375", "monitor_h*0.1467" },
})

-- It is part of the picture: every other window goes over it. Hyprland
-- always draws floating windows over tiled ones, so while its workspace
-- holds a tiled window the terminal steps off into the hidden special:desk,
-- and it comes back when the last one closes or floats. Among floating
-- windows it is kept lowest. Newly opened terminals are ordinary windows.
local desk_home = nil   -- the workspace it stepped off (forgotten on reload)

local function is_desk(w)
    return w ~= nil and w.class == "viewfinder.desk"
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
            if alive(desk) then
                hl.dispatch(hl.dsp.window.move({ workspace = tostring(home), follow = false, window = desk }))
            end
        end
        return
    end
    local active = hl.get_active_window()
    if active ~= nil and active.address == desk.address then return end   -- brought forward on purpose
    if covered(desk.workspace, gone) and alive(desk) then
        desk_home = desk.workspace.id
        hl.dispatch(hl.dsp.window.move({ workspace = "special:desk", follow = false, window = desk }))
    end
end

local function keep_back(w)
    if is_desk(w) and w.floating and alive(w) then
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = w }))
    end
end

-- a desk terminal opening where a tiled window already covers the desk goes
-- straight behind it, not on top of that window
local function tuck_new_desk(w)
    if alive(w) and w.workspace ~= nil and not w.workspace.special and covered(w.workspace) then
        desk_home = w.workspace.id
        hl.dispatch(hl.dsp.window.move({ workspace = "special:desk", follow = false, window = w }))
    end
end

on("window.open", function(w)
    if is_desk(w) then tuck_new_desk(w) else tuck() end
end)
on("window.close", function(w) if not is_desk(w) then tuck(w) end end)
on("window.move_to_workspace", function(w) if not is_desk(w) then tuck() end end)
on("window.update_rules", function(w) if not is_desk(w) then tuck() end end)   -- floated / tiled
on("window.active", function(w)
    keep_back(w)
    if not is_desk(w) then tuck() end
end)

-- Going to an empty workspace brings the small terminal there, at its
-- place (moved over, or opened again if it was closed), as at login.
on("workspace.active", function(ws)
    if ws == nil or ws.special then return end
    for _, w in ipairs(hl.get_workspace_windows(ws)) do
        if not is_desk(w) then return end
    end
    local desk = find_desk()
    if desk ~= nil and desk.workspace ~= nil and desk.workspace.id == ws.id then return end
    hl.exec_cmd("ultra-desk")
end)

------------------------------------------------------------------ small tools float in the middle
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
    hl.window_rule({ name = "viewfinder-tool-" .. i, match = { class = t.class }, float = true, center = true, size = t.size })
end
-- file pickers, by title, from any toolkit
hl.window_rule({
    name = "viewfinder-file-picker",
    match = { title = "^(Open File|Open Folder|Save As|Save File|Select a File|Choose Files|File Upload).*" },
    float = true, center = true, size = { 980, 640 },
})
hl.window_rule({ name = "viewfinder-modal", match = { modal = true }, float = true, center = true })

------------------------------------------------------------------ fullscreen: no border, no shadow
hl.window_rule({ name = "viewfinder-fullscreen", match = { fullscreen = true }, border_size = 0, no_shadow = true })

------------------------------------------------------------------ urgent windows: a blossom-pink frame
hl.window_rule({ name = "viewfinder-urgent", match = { tag = "urgent" }, border_color = "rgb(f4abc0)" })
on("window.urgent", function(w)
    if alive(w) then hl.dispatch(hl.dsp.window.tag({ tag = "+urgent", window = w })) end
end)
on("window.active", function(w)
    if alive(w) then hl.dispatch(hl.dsp.window.tag({ tag = "-urgent", window = w })) end
end)

------------------------------------------------------------------ full redraws for older GTK programs
-- GTK3 programs draw at 2x and are shown at the G14's 1.5, and when they
-- redraw a small part (gThumb's crop frame) the edge of it can be left
-- behind as a trail. While one of these is the active window, the whole
-- screen is redrawn on every change (a little more power, only then).
local full_redraw = { ["org.gnome.gThumb"] = true, gthumb = true, Gthumb = true }
local redrawing = false
local function redraw_all(on)
    if on == redrawing then return end
    redrawing = on
    hl.config({ debug = { damage_tracking = on and 1 or 2 } })
end
on("window.active", function(w) redraw_all(w ~= nil and full_redraw[w.class] == true) end)
on("window.close", function(w) if w ~= nil and full_redraw[w.class] then redraw_all(false) end end)

------------------------------------------------------------------ misc
hl.window_rule({ name = "viewfinder-no-maximize-requests", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "viewfinder-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
-- picture-in-picture: small, pinned, in the lower right
hl.window_rule({
    name = "viewfinder-pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true, pin = true, size = { 480, 270 }, move = { "monitor_w-512", "monitor_h-342" },
})
-- a video or game in fullscreen keeps the screen awake
hl.window_rule({ name = "ultra-idle", match = { fullscreen_state_internal = 2 }, idle_inhibit = "fullscreen" })

------------------------------------------------------------------ the shell's own surfaces
-- the shell fades its own surfaces; no second animation
hl.layer_rule({ name = "viewfinder-layers", match = { namespace = "^viewfinder-" }, no_anim = true })

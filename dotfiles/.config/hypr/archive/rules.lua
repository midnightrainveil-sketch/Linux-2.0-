-- Window and layer rules.
local state = require("archive.state")
local palette = require("archive.palette")
local c = palette[state.mode()]

------------------------------------------------------------------ the desk terminal
-- At rest the left desk holds one terminal card (the reference's fastfetch
-- card): floating by the left edge, 31 % of the screen wide, and 16:9 with
-- its 46 px title bar, which keeps it clear of the plate's big leaf.
-- archive-desk (the bar's desk button, Super+D) puts it back here and opens
-- it at login; keep the two in step.
hl.window_rule({
    name = "archive-desk",
    match = { class = "^archive\\.desk$" },
    float = true,
    size = { "monitor_w*0.3125", "monitor_w*0.3125*9/16-46" },
    move = { "monitor_w*0.019", "monitor_h*0.164" },
})

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

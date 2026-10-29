-- Machine specifics: ASUS ROG Zephyrus G14 (2024, GA403).
--   panel:  3K OLED, 2880x1800 @ 120 Hz, 16:10
--   GPUs:   AMD Radeon 780M (iGPU) + NVIDIA RTX 40-series (dGPU)
-- Edit this file for another machine; everything else is portable.
local state = require("archive.state")

------------------------------------------------------------------ monitors
-- Scale 1.5 gives 1920x1200 logical pixels: the mockup's 1920 width, plus
-- the extra 16:10 height that the record column uses as breathing room.
-- The internal panel shows up as eDP-1 or eDP-2 depending on the MUX mode.
--
-- Colour profiles: archive-icc (or the Colour row in quick settings) links
-- a .icc file at ~/.config/archive/icc/<output>.icc; it is passed on here.
local icc_dir = state.config_dir .. "/archive/icc/"
-- The laptop's own panel is eDP-1 or eDP-2 depending on which GPU drives
-- it, so it keeps its profile under either name ("internal.icc").
local function with_icc(rule)
    if rule.output == "" then return rule end
    local candidates = { icc_dir .. rule.output .. ".icc" }
    if rule.output:match("^eDP%-") then
        for _, n in ipairs({ "internal", "eDP-1", "eDP-2" }) do
            table.insert(candidates, icc_dir .. n .. ".icc")
        end
    end
    for _, icc in ipairs(candidates) do
        if state.exists(icc) then
            rule.icc = icc
            break
        end
    end
    return rule
end

-- 120 Hz, or 60 to save battery (archive-refresh, the "Hz" in the bar).
-- A global, so archive-refresh can set the panel again on its own
-- (hyprctl eval 'archive_panel()'), without reading the whole config again.
function archive_panel()
    for _, name in ipairs({ "eDP-1", "eDP-2" }) do
        hl.monitor(with_icc({ output = name, mode = "2880x1800@" .. state.refresh(), position = "0x0", scale = 1.5 }))
    end
end
archive_panel()
-- anything else you plug in: its preferred mode, to the right
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- ...with its profile, if it has one
local ls = io.popen('ls "' .. icc_dir .. '" 2>/dev/null')
if ls ~= nil then
    for file in ls:lines() do
        local name = file:match("^(.+)%.icc$")
        if name ~= nil and name ~= "internal" and not name:match("^eDP%-") then
            hl.monitor(with_icc({ output = name, mode = "preferred", position = "auto", scale = "auto" }))
        end
    end
    ls:close()
end

------------------------------------------------------------------ GPUs
-- Render on the iGPU (battery, heat); keep the dGPU listed so outputs wired
-- to it (the G14's HDMI port) still work. The stable /dev/dri names come
-- from the udev rule installed by the guide (docs/zephyrus-g14.md).
local devices = {}
if state.exists("/dev/dri/amd-igpu") then table.insert(devices, "/dev/dri/amd-igpu") end
if state.exists("/dev/dri/nvidia-dgpu") then table.insert(devices, "/dev/dri/nvidia-dgpu") end
if #devices > 0 then
    hl.env("AQ_DRM_DEVICES", table.concat(devices, ":"))
end

------------------------------------------------------------------ input
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        -- no acceleration: the pointer moves as far as the hand does (sensitivity,
        -- -1 to 1, sets the speed; override both in user.lua)
        accel_profile = "flat",
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.6,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

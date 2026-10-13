-- Machine specifics: ASUS ROG Zephyrus G14 (2024, GA403).
--   panel:  3K OLED, 2880x1800 @ 120 Hz, 16:10
--   GPUs:   AMD Radeon 780M (iGPU) + NVIDIA RTX 40-series (dGPU)
-- Edit this file for another machine; everything else is portable.
local state = require("archive.state")

------------------------------------------------------------------ monitors
-- Scale 1.5 gives 1920x1200 logical pixels: the mockup's 1920 width, plus
-- the extra 16:10 height that the record column uses as breathing room.
-- The internal panel shows up as eDP-1 or eDP-2 depending on the MUX mode.
for _, name in ipairs({ "eDP-1", "eDP-2" }) do
    hl.monitor({ output = name, mode = "2880x1800@120", position = "0x0", scale = 1.5 })
end
-- anything else you plug in: its preferred mode, to the right
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

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
        accel_profile = "adaptive",
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

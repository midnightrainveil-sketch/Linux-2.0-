-- Keybinds.
-- Shell surfaces are reached over Quickshell IPC: `qs ipc call <target> <fn>`.
local terminal = "foot"
local files = "nautilus"
local browser = "ultra-browser"           -- your default browser (xdg-settings)
local mod = "SUPER"

local function exec(cmd) return hl.dsp.exec_cmd(cmd) end
local function shell(target, fn) return exec("qs ipc call " .. target .. " " .. fn) end

------------------------------------------------------------------ the shell
hl.bind(mod .. " + Space", shell("shell", "launcher"), { description = "Launcher" })
hl.bind(mod .. " + D", exec("ultra-desk"), { description = "The small terminal on the picture, back in its place" })
hl.bind(mod .. " + Escape", shell("lock", "lock"), { description = "Lock" })
hl.bind(mod .. " + SHIFT + Escape", shell("shell", "power"), { description = "Power menu" })
hl.bind(mod .. " + T", shell("shell", "themes"), { description = "Themes" })
hl.bind(mod .. " + O", exec("ultra-notes"), { description = "Write the notes" })
hl.bind(mod .. " + SHIFT + N", shell("notifications", "clear"), { description = "Put every notification away" })
hl.bind(mod .. " + ALT + N", shell("notifications", "dnd"), { description = "Do not disturb, on / off" })

------------------------------------------------------------------ programs
hl.bind(mod .. " + Return", exec(terminal), { description = "Terminal" })
hl.bind(mod .. " + E", exec(files), { description = "Files" })
hl.bind(mod .. " + B", exec(browser), { description = "Browser" })

------------------------------------------------------------------ windows
hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Close the window" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Fullscreen" })
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Maximise" })
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }), { description = "Float / tile" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudotile" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })

for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down", h = "left", l = "right", k = "up" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

------------------------------------------------------------------ workspaces (the film strip's frames)
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
-- back and forth between the last two workspaces; and the next / previous workspace
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "The workspace you were on before" })
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })
-- carry the window along: to the next / previous workspace (Super+Shift+1-9 for a numbered one)
hl.bind(mod .. " + SHIFT + CTRL + Right", hl.dsp.window.move({ workspace = "r+1" }), { description = "Take the window to the next workspace" })
hl.bind(mod .. " + SHIFT + CTRL + Left", hl.dsp.window.move({ workspace = "r-1" }), { description = "Take the window to the previous workspace" })
hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Take the window to the next workspace" })
hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Take the window to the previous workspace" })

-- the drawer: minimised windows live in a special workspace
hl.bind(mod .. " + grave", hl.dsp.workspace.toggle_special("drawer"), { description = "Open the drawer" })
hl.bind(mod .. " + minus", hl.dsp.window.move({ workspace = "special:drawer", follow = false }), { description = "Put the window in the drawer" })
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "e+0" }), { description = "Take the window out of the drawer" })

------------------------------------------------------------------ screenshots (~/Pictures/Viewfinder)
hl.bind("Print", exec("ultra-screenshot region"), { description = "An area" })
hl.bind("SHIFT + Print", exec("ultra-screenshot screen"), { description = "The screen" })
-- instant: the whole screen you are looking at, no selection. (Ctrl+Backspace
-- is "delete the previous word" in most apps; this takes it over everywhere.
-- Delete this line to give it back.)
hl.bind("CTRL + BackSpace", exec("ultra-screenshot screen"), { description = "The screen, at once" })
hl.bind(mod .. " + SHIFT + S", exec("ultra-screenshot region"), { description = "An area" })
hl.bind(mod .. " + ALT + S", exec("ultra-screenshot window"), { description = "The window" })

------------------------------------------------------------------ media and brightness
-- Volume goes straight to PipeWire, so it works even if the shell is down;
-- the bottom bar's slider follows.
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", exec("qs ipc call brightness up || ultra-brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec("qs ipc call brightness down || ultra-brightness down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })

------------------------------------------------------------------ Zephyrus G14 keys
-- keyboard backlight (Fn + F2 / F3)
hl.bind("XF86KbdBrightnessUp", exec("brightnessctl -d asus::kbd_backlight set +1"), { locked = true })
hl.bind("XF86KbdBrightnessDown", exec("brightnessctl -d asus::kbd_backlight set 1-"), { locked = true })
-- fan / power profile key (Fn + F5): Quiet -> Balanced -> Performance
hl.bind("XF86Launch4", exec("ultra-profile next"), { locked = true })
-- the ROG / Armoury Crate key
hl.bind("XF86Launch1", exec("rog-control-center"))

------------------------------------------------------------------ the power button
-- (ultra-boot power stops logind acting on a press, so it comes here.)
-- A press opens the power menu; choose there.
hl.bind("XF86PowerOff", shell("shell", "power"), { description = "Power button: the power menu" })

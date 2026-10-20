-- Keybinds. Super is the archivist's key.
-- Shell surfaces are reached over Quickshell IPC: `qs ipc call <target> <fn>`.
local terminal = "foot"
local files = "nautilus"
local browser = "archive-browser"           -- your default browser (xdg-settings)
local mod = "SUPER"

local function exec(cmd) return hl.dsp.exec_cmd(cmd) end
local function shell(target, fn) return exec("qs ipc call " .. target .. " " .. fn) end

------------------------------------------------------------------ the shell
hl.bind(mod .. " + Space", shell("shell", "catalogue"), { description = "Card Catalogue (launcher)" })
hl.bind(mod .. " + D", exec("archive-desk"), { description = "Lay the desk out again (cards and terminal)" })
hl.bind(mod .. " + C", shell("shell", "ledger"), { description = "Ledger (calendar)" })
hl.bind(mod .. " + I", shell("shell", "instruments"), { description = "Instrument card (quick settings)" })
hl.bind(mod .. " + Escape", shell("lock", "lock"), { description = "Reading Room (lock)" })
hl.bind(mod .. " + SHIFT + Escape", shell("shell", "disposition"), { description = "Disposition (power menu)" })
hl.bind(mod .. " + A", shell("shell", "phonograph"), { description = "Phonograph (music from ~/Music)" })
hl.bind(mod .. " + O", shell("shell", "notebook"), { description = "Field notebook" })
hl.bind(mod .. " + R", shell("shell", "typewriter"), { description = "Label typewriter (sums, commands, look-ups)" })
hl.bind(mod .. " + N", exec("archive-mode toggle"), { description = "Turn the sheet: day / night" })
hl.bind(mod .. " + SHIFT + G", exec("archive-grain window"), { description = "Paper grain on / off for this window" })
hl.bind(mod .. " + ALT + L", shell("lamp", "toggle"), { description = "Desk lamp on / off (night)" })
hl.bind(mod .. " + SHIFT + N", shell("notifications", "clear"), { description = "File all correspondence" })

-- the Register: every open window, put-away ones too (also the bar button).
-- Alt+Tab steps through it; letting go of Alt goes to the one marked.
hl.bind(mod .. " + W", shell("shell", "register"), { description = "Register (open windows)" })
hl.bind("ALT + Tab", shell("shell", "registerNext"), { description = "Next window" })
hl.bind("ALT + SHIFT + Tab", shell("shell", "registerPrev"), { description = "Previous window" })
hl.bind("ALT + Alt_L", shell("shell", "registerPick"), { release = true, non_consuming = true })

------------------------------------------------------------------ programs
hl.bind(mod .. " + Return", exec(terminal), { description = "Terminal" })
hl.bind(mod .. " + E", exec(files), { description = "Files" })
hl.bind(mod .. " + B", exec(browser), { description = "Browser" })

------------------------------------------------------------------ windows
hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "File the window away (close)" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Hold the card up (fullscreen)" })
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Maximise" })
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Float / tile" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudotile" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })

for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down", h = "left", l = "right", k = "up" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

------------------------------------------------------------------ workspaces (typed 1-9 in the bar)
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
-- back and forth between the last two desks; and the next / previous desk
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "The desk you were on before" })
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "e+1" }), { description = "Next desk" })
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous desk" })
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next desk" })
hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous desk" })
-- carry the window along: to the next / previous desk (Super+Shift+1-9 for a numbered one)
hl.bind(mod .. " + SHIFT + CTRL + Right", hl.dsp.window.move({ workspace = "r+1" }), { description = "Take the window to the next desk" })
hl.bind(mod .. " + SHIFT + CTRL + Left", hl.dsp.window.move({ workspace = "r-1" }), { description = "Take the window to the previous desk" })
hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Take the window to the next desk" })
hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Take the window to the previous desk" })

-- the drawer: minimised windows live in a special workspace
hl.bind(mod .. " + grave", hl.dsp.workspace.toggle_special("drawer"), { description = "Open the drawer" })
hl.bind(mod .. " + minus", hl.dsp.window.move({ workspace = "special:drawer", follow = false }), { description = "Put the window in the drawer" })
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "e+0" }), { description = "Take the window out of the drawer" })

------------------------------------------------------------------ screenshots (filed with a stamp)
hl.bind("Print", exec("archive-screenshot region"), { description = "File a region" })
hl.bind("SHIFT + Print", exec("archive-screenshot screen"), { description = "File the screen" })
-- instant: the whole screen you are looking at, no selection. (Ctrl+Backspace
-- is "delete the previous word" in most apps; this takes it over everywhere.
-- Delete this line to give it back.)
hl.bind("CTRL + BackSpace", exec("archive-screenshot screen"), { description = "File the screen, instantly" })
hl.bind(mod .. " + SHIFT + S", exec("archive-screenshot region"), { description = "File a region" })
hl.bind(mod .. " + ALT + S", exec("archive-screenshot window"), { description = "File the window" })

------------------------------------------------------------------ media and brightness
-- Volume goes straight to PipeWire, so it works even if the shell is down;
-- the shell notices and shows the Instrument reading with a pencil tick.
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", exec("qs ipc call brightness up || archive-brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec("qs ipc call brightness down || archive-brightness down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })

------------------------------------------------------------------ Zephyrus G14 keys
-- keyboard backlight (Fn + F2 / F3)
hl.bind("XF86KbdBrightnessUp", exec("brightnessctl -d asus::kbd_backlight set +1"), { locked = true })
hl.bind("XF86KbdBrightnessDown", exec("brightnessctl -d asus::kbd_backlight set 1-"), { locked = true })
-- fan / power profile key (Fn + F5): Quiet -> Balanced -> Performance
hl.bind("XF86Launch4", exec("archive-profile next"), { locked = true })
-- the ROG / Armoury Crate key
hl.bind("XF86Launch1", exec("rog-control-center"))

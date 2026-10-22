-- Reads the archive's small state files so every reload of the config picks
-- up the current day / night mode, the grain shader and a few settings.
local M = {}

local home = os.getenv("HOME") or ""
M.state_dir = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/archive"
M.config_dir = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"))

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- (without opening it: opening a graphics device such as
-- /dev/dri/nvidia-dgpu wakes the chip, on every load of the config)
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok == true or code == 13 or code == 16 or code == 1 or code == 30   -- there, but not ours to rename
end
M.exists = exists

-- the look by day: "folio" (the default) or "original" (archive-mode)
function M.style()
    local s = read(M.state_dir .. "/style")
    if s and s:match("original") then return "original" end
    return "folio"
end

-- folio by day: the paper turned up (the windows' torn edge, title bars)
function M.folio()
    return M.mode() == "day" and M.style() == "folio"
end

-- how far Folio goes from the original, 0 to 1 (the Instrument card's slider)
function M.folio_amount()
    local v = tonumber((read(M.state_dir .. "/folio") or ""):match("[%d.]+") or "")
    if not v then return 0.5 end
    return math.max(0, math.min(1, v))
end

function M.mode()
    local s = read(M.state_dir .. "/mode")
    if s and s:match("night") then return "night" end
    return "day"
end

-- the internal panel's refresh rate, 60 or 120 (archive-refresh, the bar's "Hz")
function M.refresh()
    local s = read(M.state_dir .. "/refresh")
    if s and s:match("^%s*60") then return 60 end
    return 120
end

function M.grain()
    local s = read(M.state_dir .. "/grain")
    return s ~= nil and s:match("on") ~= nil
end

-- ~/.config/archive/settings.json, read with patterns (no JSON library needed)
local settings = read(M.config_dir .. "/archive/settings.json") or ""

function M.setting_bool(key, default)
    local v = settings:match('"' .. key .. '"%s*:%s*(%a+)')
    if v == "true" then return true end
    if v == "false" then return false end
    return default
end

function M.setting_string(key, default)
    return settings:match('"' .. key .. '"%s*:%s*"([^"]*)"') or default
end

return M

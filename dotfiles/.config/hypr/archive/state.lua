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

local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end
M.exists = exists

function M.mode()
    local s = read(M.state_dir .. "/mode")
    if s and s:match("night") then return "night" end
    return "day"
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

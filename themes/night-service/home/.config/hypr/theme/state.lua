-- Reads this theme's small state files so every reload of the config picks
-- up the current day / night mode, the grain shader and a few settings.
-- (The machine's own state, the refresh rate and such, is hypr/ultra/state.lua.)
local core = require("ultra.state")
local M = {}

local home = os.getenv("HOME") or ""
M.state_dir = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/ultra/night-service"
M.config_dir = core.config_dir
M.exists = core.exists
local read = core.read

-- the look by day: "folio" (the default) or "original" (ultra-mode)
function M.style()
    local s = read(M.state_dir .. "/style")
    if s and s:match("original") then return "original" end
    return "folio"
end

function M.mode()
    local s = read(M.state_dir .. "/mode")
    if s and s:match("night") then return "night" end
    return "day"
end

-- folio by day: the paper turned up (the windows' torn edge, title bars)
function M.folio()
    return M.mode() == "day" and M.style() == "folio"
end

function M.grain()
    local s = read(M.state_dir .. "/grain")
    return s ~= nil and s:match("on") ~= nil
end

-- ~/.config/ultra/night-service/settings.json
local own = core.settings(M.config_dir .. "/ultra/night-service/settings.json")
M.setting_bool = own.bool
M.setting_string = own.string

return M

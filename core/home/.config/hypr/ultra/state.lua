-- The machine's own small state (not any theme's): the panel's refresh rate,
-- the charger, and ~/.config/ultra/settings.json for the few machine
-- settings ("dgpuOutputs"). Themes keep theirs in hypr/theme/state.lua.
local M = {}

local home = os.getenv("HOME") or ""
M.state_dir = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/ultra"
M.config_dir = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"))

function M.read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local read = M.read

-- (without opening it: opening a graphics device such as
-- /dev/dri/nvidia-dgpu wakes the chip, on every load of the config)
function M.exists(path)
    local ok, _, code = os.rename(path, path)
    return ok == true or code == 13 or code == 16 or code == 1 or code == 30   -- there, but not ours to rename
end

-- plugged in: a charger online, the barrel (Mains) or USB-C (USB, not a
-- device's own battery); none at all, a desktop, counts as plugged in
function M.plugged()
    local ls = io.popen("ls /sys/class/power_supply 2>/dev/null")
    if ls == nil then return true end
    local found, online = false, false
    for name in ls:lines() do
        local dir = "/sys/class/power_supply/" .. name
        local kind = read(dir .. "/type")
        local scope = read(dir .. "/scope") or ""
        if kind and (kind:match("Mains") or (kind:match("USB") and not scope:match("Device"))) then
            found = true
            local o = read(dir .. "/online")
            if o and o:match("1") then online = true end
        end
    end
    ls:close()
    return online or not found
end

-- the internal panel's refresh rate, 60 or 120: as chosen, or "auto", 120
-- plugged in and 60 on battery (ultra-refresh, the bar's "Hz")
function M.refresh()
    local s = read(M.state_dir .. "/refresh")
    if s and s:match("^%s*60") then return 60 end
    if s and s:match("^%s*auto") then return M.plugged() and 120 or 60 end
    return 120
end

-- settings.json files, read with patterns (no JSON library needed)
function M.settings(path)
    local text = read(path) or ""
    local S = {}
    function S.bool(key, default)
        local v = text:match('"' .. key .. '"%s*:%s*(%a+)')
        if v == "true" then return true end
        if v == "false" then return false end
        return default
    end
    function S.string(key, default)
        return text:match('"' .. key .. '"%s*:%s*"([^"]*)"') or default
    end
    return S
end

local own = M.settings(M.config_dir .. "/ultra/settings.json")
M.setting_bool = own.bool
M.setting_string = own.string

return M

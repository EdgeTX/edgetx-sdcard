local libgui_dir = ...

local app_ver = "0.0.0-dev.1"

print(string.format("libgui_dir: %s, app_ver: %s", libgui_dir, app_ver))

local M = { }
M.libgui_dir = libgui_dir
M.newCtl = {}

function M.getVer()
    return app_ver
end

function M.log(fmt, ...)
    print(string.format("libgui4: " .. fmt, ...))
end
function log(fmt, ...)
    M.log(fmt, ...)
end

-- Load all controls
for ctl_name in dir(libgui_dir) do
    local file_name_short = string.match(ctl_name, "^(ctl_.+).lua$")
    if file_name_short ~= nil then
        M.log("loadControl(%s)", ctl_name)
        M.newCtl[file_name_short] = assert(loadScript(M.libgui_dir .. "/" .. ctl_name, "tcd"))()
        M.log("ctl_file: %s, flie_name_short: %s", ctl_name, file_name_short)
    end
end

return M

---- #########################################################################
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html              #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- This script display the flights history as kept using the "Flights" widget
-- Author: Offer Shmuely
-- Date: 2023
local ver = "1.1"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send me the log file that will be created on: /SCRIPTS/TOOLS/FlightsHistory/app.log

local app_name = "FlightsHistory"

local m_log = nil
local m_utils = nil
local m_tables = nil
local m_index_file = nil
local m_libgui = nil
local m_log_viewer3 = nil


local error_desc = nil
local script_folder = "/SCRIPTS/TOOLS/FlightsHistory/"

local function validate_image(file_name)
    local img1 = bitmap.open(script_folder .. file_name)
    local w, h = bitmap.getSize(img1)
    if w == 0 and h == 0  then
        error_desc = "File not found: " .. script_folder .. file_name
    end
    img1 = nil

    collectgarbage("collect")
end

local function validate_script(file_name, expected_ver, ...)
    -- validate module exist
    local my_loading_flag = "tcd"
    local code_chunk = loadScript(script_folder .. file_name, my_loading_flag)
    if code_chunk == nil then
        error_desc = "File not found: " .. script_folder .. file_name
        return
    end

    print(string.format("%s - loading, num args: %d", file_name, #{...}))
    local m = code_chunk(...)
    print(string.format("%s - loaded OK", file_name))
    if expected_ver == nil then
        return m -- file exist, no specific version needed
    end

    local the_ver = m.getVer()
    print("the_ver: " .. the_ver)
    if the_ver ~= expected_ver then
        error_desc = "incorrect version of file:\n " .. script_folder .. file_name .. ".lua \n (" .. the_ver .. " <> " .. expected_ver .. ")"
        return nil
    end
    return m
    --collectgarbage("collect")
end

local function validate_files()
    m_log = validate_script("lib_log", nil, app_name, "/SCRIPTS/TOOLS/" .. app_name)
    if error_desc ~= nil then return end
    m_log.info("loaded")

    m_utils = validate_script("lib_utils", nil, m_log, app_name)
    if error_desc ~= nil then return end

    m_tables = validate_script("lib_tables", nil, m_log, app_name)
    if error_desc ~= nil then return end

    m_index_file = validate_script("lib_history_index", nil, m_log, app_name, m_utils, m_tables)
    if error_desc ~= nil then return end

    m_libgui = validate_script("libgui", "1.0.2")
    if error_desc ~= nil then return end

    m_log_viewer3 = validate_script("FlightsHistory3", ver, m_log, m_utils,m_tables,m_index_file,m_libgui)
    if error_desc ~= nil then return end


    validate_image("bg1.png")
    if error_desc ~= nil then return end

    validate_image("bg2.png")
    if error_desc ~= nil then return end
end

local function init()
    validate_files()
    if error_desc ~= nil then return end

    return m_log_viewer3.init()
end

local function run(event, touchState)
    -- display if in error mode
    if error_desc ~= nil then
        print(error_desc)
        lcd.clear()
        lcd.drawText(5, 30, "Error:", TEXT_COLOR + BOLD)
        lcd.drawText(5, 60, error_desc, TEXT_COLOR + BOLD)
        return 0
    end

    return m_log_viewer3.run(event, touchState)
end

return { init = init, run = run }

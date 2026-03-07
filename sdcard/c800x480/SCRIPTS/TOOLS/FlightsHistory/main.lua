-- TNS|Flights History|TNE
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
-- Date: 2023-2026
local app_ver = "1.9"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send me the log file that will be created on: /SCRIPTS/TOOLS/FlightsHistory/app.log

local app_name = "FlightsHistory"

local script_folder = "/SCRIPTS/TOOLS/FlightsHistory"

local function my_load_script(file_name, ...)
    local code_chunk = assert(loadScript(script_folder .. "/" .. file_name, "tbd"))
    -- print(string.format("%s - loading, num args: %d", file_name, #{...}))
    return code_chunk(...)
end
print("Loading "..app_name.." ver: "..app_ver)
local m_log =       my_load_script("lib_log",               app_name, "/SCRIPTS/TOOLS/"..app_name)
local m_utils =     my_load_script("lib_utils",             m_log, app_name)
local m_tables =    my_load_script("lib_tables",            m_log, app_name)
local m_index_file= my_load_script("lib_history_index",     m_log, app_name, m_utils, m_tables)
local m_libgui =    my_load_script("libgui4/libgui4.lua",   script_folder.."/libgui4")
local app =         my_load_script("app",                   m_log, m_utils,m_tables,m_index_file,m_libgui,app_ver)

return { init=app.init, run=app.run, useLvgl=true }

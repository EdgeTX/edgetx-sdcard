local m_log,m_utils,m_tables,m_index_file,m_libgui  = ...

local M = {}

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

-- This script display a log file as a graph
-- Original Author: Herman Kruisman (RealTadango) (original version: https://raw.githubusercontent.com/RealTadango/FrSky/master/OpenTX/LView/LView.lua)
-- Current Author: Offer Shmuely
-- Date: 2023
local ver = "1.1"

function M.getVer()
    return ver
end

--local m_log2 = require("lib_log")
--local m_log = m_log2
local _, rv = getVersion()
if string.sub(rv, -5) ~= "-simu" then
    --m_log = m_log1
    --m_lib_file_parser = require("FlightsHistory/lib_file_parser")
    --m_utils = require("FlightsHistory/lib_utils")
    --m_tables = require("FlightsHistory/lib_tables")
    --local m_index_file = require("FlightsHistory/lib_history_index")
    --local m_libgui = require("FlightsHistory/libgui")
end


-- read_history_file()
local log_file_list_raw = {}

local log_file_list_filtered = {}
local log_file_list_filtered2 = {}
local model_summary_list = {}
local filter_model_name
local filter_model_name_idx = 1
local model_name_list = { "-- all --" }
local date_list = { "-- all --" }
local ddModel = nil
local ddLogFile = nil -- log-file dropDown object

local selected_flight_date
local filename_idx = 1

-- state machine
local STATE = {
    SPLASH = 0,
    INIT = 1,
    FLIGHTS_COUNT_INIT = 2,
    FLIGHTS_COUNT = 3,

    SHOW_FLIGHTS_INIT = 4,
    SHOW_FLIGHTS = 5,
}
local state = STATE.SPLASH

local img_bg1 = bitmap.open("/SCRIPTS/TOOLS/FlightsHistory/bg1.png")
local img_bg2 = bitmap.open("/SCRIPTS/TOOLS/FlightsHistory/bg2.png")

-- Instantiate a new GUI object
local ctx1 = m_libgui.newGUI()
local ctx2 = m_libgui.newGUI()
local flights_count_gui_init = false
local show_flights_gui_init = false

---- #########################################################################

--------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
--------------------------------------------------------------

local function compare_names(a, b)
    return a < b
end

local function compare_date_first(a1, b1)
    local a = string.sub(a1, 0, 16)
    local b = string.sub(b1, 0, 16)
    return (a > b)
end

-- read log file list
local function read_history_file()
    if (#log_file_list_raw > 0) then
        return
    end

    log("read_history_file: init")
    m_index_file.indexInit()
    m_index_file.historyFileRead()

    for i = 1, #m_index_file.log_files_index_info do
        local flight_info = m_index_file.log_files_index_info[i]
        log("filter_log_file_list: %d. %s", i, flight_info.model_name)
        m_tables.list_ordered_insert(model_name_list, flight_info.model_name, compare_names, 2)
    end

end

local function onLogFileChange(obj)
    --m_tables.table_print("log_file_list_filtered", log_file_list_filtered)

    local i = obj.selected
    selected_flight_date = log_file_list_filtered[i]
    log("Selected file index: %d", i)
    log("Selected file: %s", log_file_list_filtered[i])
    filename_idx = i
    --log("selected_flight_date: " .. selected_flight_date)
end

local function filter_log_file_list(filter_model_name, need_update)
    log("need to filter by: [%s] [%s]", filter_model_name, need_update)

    m_tables.table_clear(log_file_list_filtered)

    for i = 1, #m_index_file.log_files_index_info do
        local log_file_info = m_index_file.log_files_index_info[i]

        log("filter_log_file_list: %d. %s", i, log_file_info.flight_date)

        local model_name = log_file_info.model_name
        local year, month, day, hour, min = string.match(m_utils.trim_safe(log_file_info.flight_date), "^(%d+)-(%d+)-(%d+) (%d%d):(%d%d)$")
        log("%s --> year: %s, month: %s, day: %s, hour: %s, min: %s", log_file_info.flight_date, year, month, day, hour, min)

        local is_model_name_ok
        if filter_model_name == nil or string.sub(filter_model_name, 1, 2) == "--" then
            is_model_name_ok = true
        else
            is_model_name_ok = (model_name == filter_model_name)
        end

        if is_model_name_ok then
            log("filter_log_file_list: [%s] - OK (%s)", log_file_info.file_name, filter_model_name)
            m_tables.list_ordered_insert(log_file_list_filtered, log_file_info.flight_date, compare_date_first, 1)
        else
            log("filter_log_file_list: [%s] - FILTERED-OUT (filters:%s) (model_name_ok:%s)", log_file_info.file_name, filter_model_name, is_model_name_ok)
        end

    end

    m_tables.table_print("log_file_list_filtered after filter:", log_file_list_filtered)

    m_tables.table_clear(log_file_list_filtered2)

    if #log_file_list_filtered == 0 then
        table.insert(log_file_list_filtered, "not found")
        table.insert(log_file_list_filtered2, "not found")
    else
        -- prepare list with friendly names
        for i=1, #log_file_list_filtered do
            -- get duration
            local f_info = m_index_file.getFileDataInfo(log_file_list_filtered[i])
            log_file_list_filtered2[#log_file_list_filtered2 +1] = f_info.desc
            m_tables.list_ordered_insert(log_file_list_filtered2, f_info.desc, compare_date_first, 1)
        end
        --m_tables.table_print("prepare friendly names", log_file_list_filtered2)
    end
    --m_tables.table_print("filter_log_file_list", log_file_list_filtered)

    -- update the log combo to first
    if need_update == true then
        onLogFileChange(ddLogFile)
        ddLogFile.selected = 1
    end
end

local function calculate_model_summary_list()
    log("calculate_model_summary_list()")

    local model_flight_count = {}
    for i = 1, #m_index_file.log_files_index_info do
        local flight_info = m_index_file.log_files_index_info[i]
        log("model_summary_list: %d. %s = %d", i, flight_info.model_name, flight_info.flight_count)

        if model_flight_count[flight_info.model_name] == nil then
            log("model_summary_list: %d. first", i)
            model_flight_count[flight_info.model_name] = 0
        else
            log("model_summary_list: %d. logged", i)
        end

        model_flight_count[flight_info.model_name] = flight_info.flight_count
    end

    m_tables.table_clear(model_summary_list)
    for k, v in pairs(model_flight_count) do
        --local inf = string.format("%-17s - %d flights", k, v)
        local inf = string.format("%03d - %s", v, k)
        log("model_flight_count: %s", inf)
        model_summary_list[#model_summary_list +1] = inf
    end

end

local splash_start_time = 0
local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    log('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 1500) then
        state = STATE.INIT
    end

    return 0
end

local function state_INIT(event, touchState)
    read_history_file()
    state = STATE.FLIGHTS_COUNT_INIT
    return 0
end

local function state_FLIGHTS_COUNT_init(event, touchState)
    calculate_model_summary_list()

    log("++++++++++++++++++++++++++++++++")
    if flights_count_gui_init == false then
        flights_count_gui_init = true
        -- creating new window gui
        log("creating new window gui")
        --ctx1 = libGUI.newGUI()

        ctx1.label(10, 25, 120, 24, "Models Flight Count...", BOLD)

        log("setting file combo...")
        --ddLogFile = ctx1.dropDown(20, 90, 450, 24, log_file_list_filtered2, filename_idx,
        ddLogFile = ctx1.menu(80, 55, 300, 200, model_summary_list)
    end

    state = STATE.FLIGHTS_COUNT
    return 0
end

local function state_FLIGHTS_COUNT_refresh(event, touchState)
    --if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
    --    state = STATE.FLIGHTS_COUNT_INIT
    --    return 0
    --end

    -- ## file selected
    if event == EVT_VIRTUAL_NEXT_PAGE then
        log("state_SHOW_FLIGHTS_refresh --> EVT_VIRTUAL_NEXT_PAGE: filename: %s", selected_flight_date)
        if selected_flight_date == "not found" then
            m_log.warn("state_SHOW_FLIGHTS_refresh: trying to next-page, but no logfile available, ignoring.")
            return 0
        end

        --Reset file load data
        log("Reset file load data")

        local f_info = m_index_file.getFileDataInfo(selected_flight_date)

        state = STATE.SHOW_FLIGHTS_INIT
        return 0
    end

    ctx1.run(event, touchState)

    return 0
end

local function state_SHOW_FLIGHTS_init(event, touchState)
    m_tables.table_clear(log_file_list_filtered)
    filter_log_file_list(nil, false)

    log("++++++++++++++++++++++++++++++++")
    if show_flights_gui_init == false then
        show_flights_gui_init = true
        -- creating new window gui
        log("creating new window gui")
        --ctx2 = libGUI.newGUI()

        ctx2.label(10, 25, 120, 24, "Flights History...", BOLD)

        log("setting model filter...")
        ctx2.label(270, 25, 60, 24, "Model")
        m_tables.table_print("model_name_list", model_name_list)
        ddModel = ctx2.dropDown(325, 25, 150, 24, model_name_list, 1,
            function(obj)
                local i = obj.selected
                filter_model_name = model_name_list[i]
                filter_model_name_idx = i
                log("Selected model-name: " .. filter_model_name)
                filter_log_file_list(filter_model_name, true)
            end
        )

        log("setting file combo...")
        --ddLogFile = ctx2.dropDown(20, 90, 450, 24, log_file_list_filtered2, filename_idx,
        ddLogFile = ctx2.menu(80, 55, 390, 200, log_file_list_filtered2, onLogFileChange)
        onLogFileChange(ddLogFile)
    end

    --filter_model_name_i
    ddModel.selected = filter_model_name_idx
    --ddLogFile.selected = filename_idx
    filter_log_file_list(filter_model_name, true)

    ddLogFile.selected = filename_idx


    state = STATE.SHOW_FLIGHTS
    return 0
end

local function state_SHOW_FLIGHTS_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.FLIGHTS_COUNT_INIT
        return 0
    end

    --if event == EVT_VIRTUAL_NEXT_PAGE then
    --    state = STATE.SELECT_SENSORS_INIT
    --    return 0
    --end

    ctx2.run(event, touchState)

    return 0
end

local function drawMain()
    lcd.clear()

    -- draw background
    if state == STATE.SPLASH then
        lcd.drawBitmap(img_bg1, 0, 0)
    else
        -- draw top-bar
        lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
        lcd.drawBitmap(img_bg2, 0, 0)
    end

    if selected_flight_date ~= nil then
        lcd.drawText(30, 1, "/LOGS/" .. selected_flight_date, WHITE + SMLSIZE)
    end
end


function M.init()
end

function M.run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    --log("run() ---------------------------")
    --log("event: %s", event)


    drawMain()


    if state == STATE.SPLASH then
        log("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.INIT then
        log("STATE.INIT")
        return state_INIT()

    elseif state == STATE.FLIGHTS_COUNT_INIT then
        log("STATE.FLIGHTS_COUNT_INIT")
        return state_FLIGHTS_COUNT_init(event, touchState)

    elseif state == STATE.FLIGHTS_COUNT then
        --log("STATE.state_FLIGHTS_COUNT_refresh")
        return state_FLIGHTS_COUNT_refresh(event, touchState)

    elseif state == STATE.SHOW_FLIGHTS_INIT then
        log("STATE.SHOW_FLIGHTS_INIT")
        return state_SHOW_FLIGHTS_init(event, touchState)

    elseif state == STATE.SHOW_FLIGHTS then
        --log("STATE.state_SHOW_FLIGHTS_refresh")
        return state_SHOW_FLIGHTS_refresh(event, touchState)

    end

    --impossible state
    error("Something went wrong with the script!")
    return 2
end

return M

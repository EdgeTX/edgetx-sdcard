local m_log,m_utils,m_tables,m_index_file,libGUIv4,app_ver  = ...

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

-- This history of flights
-- Author: Offer Shmuely
-- Date: 2023-2026

local script_folder = "/SCRIPTS/TOOLS/FlightsHistory"
local filter_model_name
local filter_model_name_idx = 1
local model_name_list = { "-- all --" }

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

-- state machine
local STATE = {
    SPLASH_INIT = 0,
    SPLASH = 1,
    READ_HIST_INIT = 2,
    READ_HIST = 3,
    SHOW_FLIGHTS_HIST_INIT = 4,
    SHOW_FLIGHTS_HIST = 5,
    FLIGHTS_COUNT_INIT = 6,
    FLIGHTS_COUNT = 7,
    DO_NOTHING=99,--???
}
local state = STATE.SPLASH_INIT

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

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

local function isFileExist(file_name)
    log("is_file_exist()")
    local hFile = io.open(file_name, "r")
    if hFile == nil then
        log("file not exist - %s", file_name)
        return false
    end
    io.close(hFile)
    log("file exist - %s", file_name)
    return true
end

local splash_start_time = 0
local function state_SPLASH_INIT(event, touchState)
    lvgl.clear()
    lvgl.image({x=0,y=0,w=LCD_W,h=LCD_H,file=script_folder.."/bg1.png"})
    state = STATE.SPLASH
    return 0
end

local function state_SPLASH(event, touchState)
    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    log('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    -- if (elapsedMili >= 1500) then
    if (elapsedMili < 500) then
        return 0
    end
    local isHistoryExist = isFileExist( "/flights-history.csv")
    if isHistoryExist then
        log("History file exist")
        state = STATE.READ_HIST_INIT
    else
        log("History file does not exist")
        lvgl.label({x=30, y=180, text="No history file found! \n"
            .. "This app is working with 'Flights' widget.\n"
            .. "Please count your flights with 'Flights' widget \n"
            .. "then use this script.\n"
        , color=WHITE, font=BOLD})
        state = STATE.DO_NOTHING
    end
    return 0
end

local function state_READ_HIST_INIT(event, touchState)
    -- lvgl.clear()
    lvgl.build({
        {type="label", x=20*lvSCALE, y=200*lvSCALE, text="Reading data...", color=ORANGE, font=FS.FONT_12 + BOLD}
    })

    state = STATE.READ_HIST
    return 0
end
local function state_READ_HIST(event, touchState)
    -- read log file list
    log("read_history_file: init")
    m_index_file.indexInit()
    m_index_file.historyFileRead()

    for i = 1, #m_index_file.log_files_index_info do
        local flight_info = m_index_file.log_files_index_info[i]
        -- log("to model name list: %d. %s", i, flight_info.model_name)
        m_tables.list_ordered_insert(model_name_list, flight_info.model_name, compare_names, 2)
    end

    state = STATE.SHOW_FLIGHTS_HIST_INIT
    return 0
end


local function is_visible_line(line)
    if filter_model_name == nil or filter_model_name == "-- all --" then
    -- if filter_model_name == nil or filter_model_name == string.sub(filter_model_name, 1, 2) == "--" then
        return true
    end

    local  lineModelName = line[2]
    -- log("is_visible_line by: [%s] [%s] --> %s    %s %s %s", filter_model_name, lineModelName, filter_model_name == lineModelName)
    return (filter_model_name == lineModelName)
end

local function state_SHOW_FLIGHTS_HIST_INIT(event, touchState)
    -- creating new window gui
    lvgl.clear()
    collectgarbage()

    lvgl.build({
        -- draw top-bar
        {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=BLACK, filled=true},
        {type="rectangle", x=0, y=0, w=LCD_W, h=20*lvSCALE, color=COLOR_THEME_SECONDARY1, filled=true},
        {type="label", x=160*lvSCALE, y=1*lvSCALE, text="Flight History Viewer", color=WHITE, font=FS.FONT_6},
        {type="label", x=LCD_W-40*lvSCALE, y=1*lvSCALE, text="v" .. app_ver, color=WHITE, font=FS.FONT_6},
        -- {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=script_folder.."/bg2.png"},
        {type="label", x=10*lvSCALE, y=25*lvSCALE, text="All Flight...", font=BOLD, color=WHITE},
    })

    filter_model_name_idx = 1
    lvgl.build({
        { type="choice", x=150*lvSCALE, y=25*lvSCALE, w=LCD_W-(10+150)*lvSCALE, h=27*lvSCALE, title = "Craft",
            values = model_name_list,
            -- values = {"aaa", "bbb", "ccc", "ddd", "eee"},
            get = function() return filter_model_name_idx; end,
            set = function(i)
                log("Selected model-summary: %d", i)
                log("Selected model-summary: %s", model_name_list[i])
                filter_model_name = model_name_list[i]
                filter_model_name_idx = i
                log("Selected model-name: " .. filter_model_name)
            end ,
        },
    })

    local lines_csv = {}
    for i = #m_index_file.log_files_index_info, 1, -1 do
        -- log("log_file_list_filtered: %d. [%s]=%s", i, m_index_file.log_files_index_info[i], m_index_file.log_files_index_info[i].flight_date)
        local f_info = m_index_file.getFileDataInfo(m_index_file.log_files_index_info[i].flight_date)
        assert(f_info)
        -- log("log_file_list_filtered: %d. [%s]=%d (%s min)", i, f_info.file_name, f_info.flight_count, f_info.duration)
        -- log("log_file_list_filtered: %d. [%s]=%d (%s min)", i, m_index_file.log_files_index_info[i], f_info.flight_count, f_info.duration)

        local day = string.sub(m_index_file.log_files_index_info[i].flight_date, 1, 10) -- Extracts the 9th and 10th characters (the day)

        lines_csv[#lines_csv + 1] = {
            day,
            f_info.model_name,
            string.format("%s", f_info.flight_count),
            string.format("(%0.1f min)", f_info.duration/100),
        }
    end

    libGUIv4.newCtl.ctl_table(nil, "count-table", {
        x=10*lvSCALE, y=64*lvSCALE, w=LCD_W-10*lvSCALE, h=LCD_H-65*lvSCALE,
        font=FS.FONT_6,
        header={"Date", "Model", "Flights", "Duration"},
        colX={20*lvSCALE, 100*lvSCALE, 340*lvSCALE, 400*lvSCALE},
        lines=lines_csv,
        fIsLineVisible=is_visible_line,
        maxLines=50,
    })

    for i = 1, #model_name_list do
        log("model_name_list: %d. [%s]", i, model_name_list[i])
    end

    state = STATE.SHOW_FLIGHTS_HIST
    return 0
end

local function state_SHOW_FLIGHTS_HIST(event, touchState)
    if event == EVT_VIRTUAL_NEXT_PAGE then
        lvgl.clear()
        lvgl.label({x=0, y=0, text="Loading...", color=WHITE, font=BOLD})
        state = STATE.FLIGHTS_COUNT_INIT
        return 0
    end

    return 0
end

-- ----------------------------------------------------------------------------------------------------------

local function calculate_model_summary_list()

    local model_flight_count = {}
    for i = 1, #m_index_file.log_files_index_info do
        local flight_info = m_index_file.log_files_index_info[i]
        --log("model_summary_list: %d. [%s]=%d (%s min)", i, flight_info.model_name, flight_info.flight_count, flight_info.duration)

        if model_flight_count[flight_info.model_name] == nil then
            -- log("model_summary_list: %d. first", i)
            model_flight_count[flight_info.model_name] = 0
        else
            -- log("model_summary_list: %d. logged", i)
        end

        model_flight_count[flight_info.model_name] = flight_info.flight_count
    end

    -- for k, v in pairs(model_flight_count) do
    --     local inf = string.format("===================== %-17s - %d flights", k, v)
    --     -- local inf = string.format("%03d - %s", v, k)
    --     log("model_flight_count: %s", inf)
    --     model_summary_list[#model_summary_list +1] = {k, v}
    -- end

    local keys = {}
    for k in next, model_flight_count do
        keys[#keys+1] = k
    end

    local model_summary_list = {}
    log("calculate_model_summary_list()")
    m_tables.table_clear(model_summary_list)
    for i = 1, #keys do
        local k = keys[i]
        local v = model_flight_count[k]
        local inf = string.format("===================== %-17s - %d flights", k, v)
        -- local inf = string.format("%03d - %s", v, k)
        log("model_flight_count: %s", inf)
        model_summary_list[#model_summary_list +1] = {k, v}
    end

    return model_summary_list
end


local function state_FLIGHTS_COUNT_INIT(event, touchState)
    local model_summary_list = calculate_model_summary_list()

    log("creating new window gui")
    lvgl.clear()
    lvgl.build({
        -- draw top-bar
        {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=BLACK, filled=true},
        {type="rectangle", x=0, y=0, w=LCD_W, h=20*lvSCALE, color=COLOR_THEME_SECONDARY1, filled=true},
        {type="label", x=160*lvSCALE, y=1, text="Flight History Viewer", color=WHITE, font=FS.FONT_6},
        {type="label", x=LCD_W-40*lvSCALE, y=1, text="v" .. app_ver, color=WHITE, font=FS.FONT_6},
        -- {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=script_folder.."/bg2.png"},
        {type="label", x=10*lvSCALE, y=25*lvSCALE, text="Flight Count...", font=BOLD, color=WHITE},
    })

    libGUIv4.newCtl.ctl_table(nil, "count-table", {
        x=20*lvSCALE, y=50*lvSCALE, w=LCD_W-20*lvSCALE, h=LCD_H-50*lvSCALE,
        font=FS.FONT_8,
        header={"Model", "Flights Count"},
        colX={20*lvSCALE, 250*lvSCALE},
        lines=model_summary_list,
    })

    state = STATE.FLIGHTS_COUNT
    return 0
end

local function state_FLIGHTS_COUNT(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        lvgl.clear()
        lvgl.label({x=0, y=0, text="Loading...", color=WHITE, font=BOLD})
        state = STATE.SHOW_FLIGHTS_HIST_INIT
        return 0
    end

    return 0
end

function M.init()
    log("init()")
end

function M.run(event, touchState)
    -- log("run(%s)", state)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if state == STATE.SPLASH_INIT then
        log("STATE.SPLASH_INIT")
        return state_SPLASH_INIT()

    elseif state == STATE.SPLASH then
        log("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.READ_HIST_INIT then
        log("STATE.READ_HIST_INIT")
        return state_READ_HIST_INIT()

    elseif state == STATE.READ_HIST then
        log("STATE.READ_HIST")
        return state_READ_HIST()

    elseif state == STATE.SHOW_FLIGHTS_HIST_INIT then
        log("STATE.SHOW_FLIGHTS_HIST_INIT")
        return state_SHOW_FLIGHTS_HIST_INIT(event, touchState)

    elseif state == STATE.SHOW_FLIGHTS_HIST then
        --log("STATE.state_SHOW_FLIGHTS")
        return state_SHOW_FLIGHTS_HIST(event, touchState)

    elseif state == STATE.FLIGHTS_COUNT_INIT then
        log("STATE.FLIGHTS_COUNT_INIT")
        return state_FLIGHTS_COUNT_INIT(event, touchState)

    elseif state == STATE.FLIGHTS_COUNT then
        --log("STATE.state_FLIGHTS_COUNT")
        return state_FLIGHTS_COUNT(event, touchState)

    elseif state == STATE.DO_NOTHING then
        log("STATE.DO_NOTHING")
        return 0

    end

    --impossible state
    error(string.format("Something went wrong with the script! (%s)", state))
    return 2
end

return M

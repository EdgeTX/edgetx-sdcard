--[[
#########################################################################
#                                                                       #
# Flight Counter Widget for color lcd 480x272                           #
# Copyright "Offer Shmuely"                                             #
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
#                                                                       #
# This program is free software; you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License version 2 as     #
# published by the Free Software Foundation.                            #
#                                                                       #
# This program is distributed in the hope that it will be useful        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
#########################################################################


-- Widget to count number of flights
-- Offer Shmuely
-- Date: 2022-2024
-- flight considered successful: after 30sec the engine above 25%, and telemetry is active (to indicated that the model connected), and safe switch ON
-- flight considered ended: after 8sec of battery disconnection (detected by no telemetry)
-- warning: do NOT use this widget if model is using GV9!!!
-- history of flights is kept at /flights-history.csv

-- widget assume the following:
--   the model have motor
--   the motor is activated on channel 3 (can be change in settings)
--   there is telemetry with one of the above [RSSI|RxBt|A1|A2|1RSS|2RSS|RQly]
--   there is a safe switch (arm switch)
--   global variable GV9 is free (i.e. not used)

-- state machine:
--   ground --> flight-starting --> flight-on --> flight-ending --> ground
-- i.e.
--   all-flags on for 30s => flight-on
--   no telemetry for 8s  => flight-completed


-- Tips:
-- widget is desined to be in the top bar
-- if widget size 1/2 or 1/1 (instead in the top bar) it will enter a debug mode
-- there are two options of voice indication: (you can also put your own)
--     copy flight_logged2.wav-->flight_logged.wav
--     or
--     flight_ended2.wav-->flight_ended.wav
-- for Heli, the motor-switch=arm-switch (same value for both)
-- if you prefer different logics, do them on logical switches, and put that logical switch in both Arm & motor channel
-- if your recweiver does not have telemetry, use: [Plane no Telemetry]

]]

local args = {...}
local triggerTypeDefs = args[1]

local app_name = "Flights"
local app_ver = "2.1"

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

local build_ui = nil
------------------------------------------------------------------------------------------------------------------
-- configuration
local default_flight_starting_duration = 30  -- 30 sec to detect flight success
local default_flight_ending_duration = 8     --  8 sec to detect flight ended
-- local default_min_motor_value = 200
local enable_count_announcement_on_start = 0 -- 0=no voice, 1=play the count upon increment
local enable_count_announcement_on_end = 1   -- 0=no voice, 1=play the count upon end of flight
local show_dots = true                       -- false=do not show dots, true=show dbg dots
local use_flights_history = 1                -- 0=do not write flights-history, 1=write flights-history
--local use_flights_count_csv = 1              -- 0=do not write flights-count.csv, 1=write flights-count.csv
------------------------------------------------------------------------------------------------------------------


-- imports
local m_log = assert(loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "btd"))(app_name, "/WIDGETS/" .. app_name)

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local function log(fmt, ...)
    m_log.info(fmt, ...)
end

local function update(wgt, options)
    if (wgt == nil) then return end

    wgt.options = options
    wgt.triggerDesc = triggerTypeDefs.info[wgt.options.triggerType].desc
    wgt.triggerFile = triggerTypeDefs.info[wgt.options.triggerType].file
    wgt.enable_sounds = wgt.options.enable_sounds

    -- status
    wgt.status = {}
    wgt.status.switch_name = nil
    wgt.status.motor_channel_name = nil
    wgt.status.flight_state = "GROUND"
    wgt.status.duration_passed = 0
    wgt.status.periodic1 = wgt.tools.periodicInit()
    wgt.status.last_flight_count = 0
    wgt.status.flight_start_time = 0
    wgt.status.flight_start_date_time = 0
    wgt.status.flight_end_time = 0
    wgt.status.flight_duration = 0

    if (wgt.options.min_flight_duration < 0) then
        wgt.options.min_flight_duration = math.abs(wgt.options.min_flight_duration)
        default_flight_ending_duration = 1
    end

    if (wgt.options.arm_switch_id == nil) then
        wgt.options.arm_switch_id = DEFAULT_ARM_SWITCH_ID -- SF up
    end

    wgt.status.switch_name = getSwitchName(wgt.options.arm_switch_id)
    if (wgt.status.switch_name==nil) then
        wgt.status.switch_name = "---"
    end
    log("wgt.options.arm_switch_id: %s, name: %s --- getSwitchIndex() %s ", wgt.options.arm_switch_id, wgt.status.switch_name, getSwitchIndex("SF"..CHAR_DOWN))

    local fi_mot = getFieldInfo(wgt.options.motor_channel)
    if (fi_mot == nil) then
        wgt.status.motor_channel_name = "--"
    else
        wgt.status.motor_channel_name = fi_mot.name
    end

    local t_chunk = assert(loadScript("/WIDGETS/" .. app_name .. "/rules/" .. wgt.triggerFile, "btd"), "Failed to load trigger script: "..wgt.triggerFile)
    wgt.rule = t_chunk(m_log, app_name, wgt.status.switch_name, wgt.status.motor_channel_name)

    log("Using trigger type: %s (%s)", wgt.triggerDesc, wgt.triggerFile)
    log("info: %s", wgt.rule:info())

    local override_min_flight_time = wgt.rule:override_min_flight_time()
    if (override_min_flight_time ~= nil) then
        wgt.options.min_flight_duration = override_min_flight_time
        log("Using override min flight duration: %s", wgt.options.min_flight_duration)
    end


    -- auto debug mode if widget size 1/2 or 1/1
    wgt.options.is_debug = (wgt.options.auto_debug==1 and wgt.zone.h > 140)
    -- log("auto_debug: %s, is_debug: %s, wgt.zone.h: %s", wgt.options.auto_debug, wgt.options.is_debug, wgt.zone.h)

    -- backward compatibility
    if wgt.options.text_color == 32768 or wgt.options.text_color == 65536 or wgt.options.text_color == 98304 then
        log(string.format("wgt.options.text_color: %s", wgt.options.text_color))
        log("flights wgt.options.text_color == <invalid value>, probably upgraded from previous ver, setting to RED")
        wgt.options.text_color = RED
        log(string.format("wgt.options.text_color (fixed): %s", wgt.options.text_color))
    end

    local ver, radio, maj, minor, rev, osname = getVersion()
    local nVer = maj*1000000 + minor*1000 + rev
    wgt.is_valid_ver = (nVer>=2011000)

    build_ui(wgt)
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,

        -- imports
        tools = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "btd")(m_log, app_name),
        flightHistory = loadScript("/WIDGETS/" .. app_name .. "/lib_flights_history.lua", "btd")(m_log, app_name),
        -- flightCountHWriter = loadScript("/WIDGETS/" .. app_name .. "/lib_flights_count.lua", "btd")(m_log, app_name, "/flights-count.csv"),
    }

    update(wgt, options)
    return wgt
end

local function getFontSize(wgt, txt)
    local wide_txt = string.gsub(txt, "[1-9]", "0")
    --log(string.gsub("******* 12:34:56", "[1-9]", "0"))
    --log("wide_txt: " .. wide_txt)

    local w, h = lcd.sizeText(wide_txt, FS.FONT_38)
    --log(string.format("FS.FONT_38 w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_38
    end

    w, h = lcd.sizeText(wide_txt, FS.FONT_16)
    --log(string.format("FS.FONT_16 w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_16
    end

    w, h = lcd.sizeText(wide_txt, FS.FONT_12)
    --log(string.format("FS.FONT_12 w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_12
    end

    --log(string.format("SMLSIZE w: %d, h: %d, %s", w, h, time_str))
    return FS.FONT_6
end

--------------------------------------------------------------------------------------------------------
-- get flight count
local function getFlightCount(wgt)
    -- get GV9 (index = 0) from Flight mode 0 (FM0)
    local num_flights = model.getGlobalVariable(8, 0)

    -- local model_name = model.getInfo().name
    -- local num_flights = wgt.flightCountHWriter.getValue(model_name)
    return num_flights
end

local function setFlightCount(wgt, newCount)
    model.setGlobalVariable(8, 0, newCount)

    -- local model_name = model.getInfo().name
    -- wgt.flightCountHWriter.setValue(model.getInfo().name, newCount)

    log("num_flights updated: " .. newCount)
end

local function doNewFlightTasks(wgt)
    log("doNewFlightTasks()")
    local new_flight_count = wgt.status.last_flight_count + 1
    setFlightCount(wgt, new_flight_count)

    -- beep
    if (wgt.enable_sounds == 1) then
        local is_exist_file_10 = wgt.flightHistory.isFileExist("/WIDGETS/" .. app_name .. "/flight_logged_10.wav")
        log("is_exist_file_10: %s", is_exist_file_10)

        if (is_exist_file_10 == true) and (new_flight_count % 10 == 0) then
            playFile("/WIDGETS/" .. app_name .. "/flight_logged_10.wav")
        else
            playFile("/WIDGETS/" .. app_name .. "/flight_logged.wav")
        end
    end

    if (wgt.enable_sounds == 1 and enable_count_announcement_on_start == 1) then
        playNumber(new_flight_count, 0)
        playFile("/WIDGETS/" .. app_name .. "/flights.wav")
    end
end

local function doEndOfFlightTasks(wgt)
    log("doEndOfFlightTasks()")
    if (wgt.enable_sounds == 1) then
        playFile("/WIDGETS/" .. app_name .. "/flight_ended.wav")
    end

    local num_flights = getFlightCount(wgt)
    if (wgt.enable_sounds == 1 and enable_count_announcement_on_end == 1) then
        playNumber(num_flights, 0)
        playFile("/WIDGETS/" .. app_name .. "/flights.wav")
    end

    --wgt.status.flight_duration = math.floor(wgt.status.flight_duration)
    --if use_flights_history == 1 then
    --    log("flight_start_time: %s", wgt.status.flight_start_time)
    --    log("flight_end_time: %s", wgt.status.flight_end_time)
    --    log("flight_duration: %s", wgt.status.flight_duration)
    --    wgt.flightHistory.addFlightLog(wgt.status.flight_start_date_time, wgt.status.flight_duration, num_flights)
    --end

end

---------------------------------------------------------------
local function stateChange(wgt, newState, timer_sec)
    log("flight_state: %s --> %s", wgt.status.flight_state, newState)
    wgt.status.flight_state = newState

    if (timer_sec > 0) then
        wgt.tools.periodicStart(wgt.status.periodic1, timer_sec * 1000)
    else
        wgt.status.duration_passed = 0
        --periodicReset(wgt.status.periodic1)
    end
end

local function background(wgt)
    wgt.rule:background(wgt)

    -- **** state: GROUND ***
    if wgt.status.flight_state == "GROUND" then
        if (wgt.rule:is_flight_starting() == true) then
            stateChange(wgt, "FLIGHT_STARTING", wgt.options.min_flight_duration)
            wgt.status.last_flight_count = getFlightCount(wgt)
            wgt.status.flight_start_time = getTime() * 10 / 1000
            wgt.status.flight_start_date_time = getDateTime()
            -- log("flight_start_time: %s", wgt.status.flight_start_time)
        end
        return

    -- **** state: FLIGHT_STARTING ***
    elseif wgt.status.flight_state == "FLIGHT_STARTING" then
        if (wgt.rule:is_flight_starting() == false) then
            stateChange(wgt, "GROUND", 0)
            return
        end

        -- record flight duration in case we soon detect end of flight
        wgt.status.flight_end_time = getTime() * 10 / 1000
        wgt.status.flight_duration = wgt.status.flight_end_time - wgt.status.flight_start_time

        wgt.status.duration_passed = wgt.tools.periodicGetElapsedTime(wgt.status.periodic1)
        log("flight_state: FLIGHT_STARTING ..." .. wgt.status.duration_passed)
        if (wgt.tools.periodicHasPassed(wgt.status.periodic1)) then
            stateChange(wgt, "FLIGHT_ON", 0)

            -- **************************************
            -- yep, we have a good flight, count it!
            -- **************************************
            doNewFlightTasks(wgt)

        end
        return

    -- **** state: FLIGHT_ON ***
    elseif wgt.status.flight_state == "FLIGHT_ON" then
        -- record flight duration in case we soon detect end of flight

        if wgt.rule:is_still_on_flight() then
            wgt.status.flight_end_time = getTime() * 10 / 1000
            wgt.status.flight_duration = wgt.status.flight_end_time - wgt.status.flight_start_time
            -- log("flight_start_time: %s", wgt.status.flight_start_time)
            -- log("flight_end_time: %s", wgt.status.flight_end_time)
            -- log("flight_duration: %s", wgt.status.flight_duration)
        end

        if wgt.rule:is_flight_ending() then
            stateChange(wgt, "FLIGHT_ENDING", default_flight_ending_duration)

            local num_flights = getFlightCount(wgt)
            wgt.status.flight_duration = math.floor(wgt.status.flight_duration)
            if use_flights_history == 1 then
                log("flight_start_time: %s", wgt.status.flight_start_time)
                log("flight_end_time: %s", wgt.status.flight_end_time)
                log("flight_duration: %s", wgt.status.flight_duration)
                wgt.flightHistory.addFlightLog(wgt.status.flight_start_date_time, wgt.status.flight_duration, num_flights)
            end

        end
        return

    -- **** state: FLIGHT_ENDING ***
    elseif wgt.status.flight_state == "FLIGHT_ENDING" then
        wgt.status.duration_passed = wgt.tools.periodicGetElapsedTime(wgt.status.periodic1)
        log("flight_state: FLIGHT_ENDING ..." .. wgt.status.duration_passed)

        if (wgt.tools.periodicHasPassed(wgt.status.periodic1)) then
            stateChange(wgt, "GROUND", 0)

            -- ***********************************
            -- yes, we landed after a good flight
            -- ***********************************
            doEndOfFlightTasks(wgt)
        end

        if wgt.rule:is_flight_ending() == false then
            stateChange(wgt, "FLIGHT_ON", 0)
        end

        return
    end

    --log("flight_state: " .. wgt.status.flight_state)
    return
end

local function ternary(cond, T, F)
    if cond then
        return "ON"
    else
        return "OFF"
    end
end

local function getColorByState(wgt, flight_state)
    return (wgt.status.flight_state  == flight_state) and BLUE or 0+GREY
end


build_ui = function(wgt)

    lvgl.clear()

    if (wgt == nil) then log("refresh(nil)") return end
    if (wgt.options == nil) then log("refresh(wgt.options=nil)") return end

    -- get flight count
    local num_flights = getFlightCount(wgt)

    local font_size = getFontSize(wgt, num_flights)
    local zone_w = wgt.zone.w
    local zone_h = wgt.zone.h

    local font_size_header = FS.FONT_6
    -- if (event ~= nil) then
    --     -- app mode (full screen)
    --     font_size = FS.FONT_38
    --     font_size_header = FS.FONT_16
    --     zone_w = LCD_W
    --     zone_h = LCD_H - 20
    -- end

    local ts_w, ts_h = lcd.sizeText(num_flights, font_size)
    local dx = (zone_w - ts_w) / 2
    local dyh = 5*lvSCALE
    local dy --  = header_h - 1
    local is_top_bar = (zone_h < 50*lvSCALE)

    if is_top_bar then
        -- force minimal spaces
        dyh = -3*lvSCALE
    else
        dyh = 5*lvSCALE
    end

    -- global
    -- lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x11, 0x11, 0x11), filled=true})
    local pMain = lvgl.box({x=0, y=0})

    -- draw header
    pMain:label({x=0, y=dyh, font=font_size_header, text="Flights:", color=wgt.options.text_color})

    -- draw count
    if is_top_bar == true then
        -- pMain:label({x=zone_w-ts_w -10, y=dy, font=font_size, text=function() return getFlightCount(wgt) end, color=wgt.options.text_color})
        pMain:label({x=10*lvSCALE, y=13*lvSCALE, font=font_size, text=function() return getFlightCount(wgt) end, color=wgt.options.text_color})
    else
        pMain:label({x=zone_w-ts_w-5*lvSCALE, y=5*lvSCALE, font=font_size, text=function() return getFlightCount(wgt) end, color=wgt.options.text_color})
    end

    -- enable 3 dots
    if (show_dots == true) then
        local dxc = 7*lvSCALE
        pMain:circle({x=5*lvSCALE, y=20*lvSCALE + dxc*0, radius=3, filled=true, color=function() return wgt.rule:is_dot_1()   and GREEN or GREY end})
        pMain:circle({x=5*lvSCALE, y=20*lvSCALE + dxc*1, radius=3, filled=true, color=function() return wgt.rule:is_dot_2()   and GREEN or GREY end})
        pMain:circle({x=5*lvSCALE, y=20*lvSCALE + dxc*2, radius=3, filled=true, color=function() return wgt.rule:is_dot_3()   and GREEN or GREY end})
    end

    -- debug
    local pInfo = lvgl.box({x=0, y=40})
    if wgt.options.is_debug == true then
        local dx = 15*lvSCALE
        pInfo:label({x=dx+190*lvSCALE, y= 5*lvSCALE, font=FS.FONT_8, text=function() return string.format("Rule: %s", wgt.triggerDesc) end})
        pInfo:label({x=dx, y= 0*lvSCALE, font=FS.FONT_6, text=function() return wgt.rule:dot_1_txt() end})
        pInfo:label({x=dx, y=15*lvSCALE, font=FS.FONT_6, text=function() return wgt.rule:dot_2_txt() end})
        pInfo:label({x=dx, y=30*lvSCALE, font=FS.FONT_6, text=function() return wgt.rule:dot_3_txt() end})
        pInfo:label({x=dx, y=45*lvSCALE, font=FS.FONT_6, text=function() return string.format("timer: %.1f/%d",        wgt.status.duration_passed / 1000, wgt.tools.getDurationMili(wgt.status.periodic1) / 1000) end})
        pInfo:label({x=dx, y=60*lvSCALE, font=FS.FONT_6, text=function() return string.format("flight duration: %.1f", wgt.status.flight_duration) end})

        pInfo:label({x=dx, y=80*lvSCALE, font=FS.FONT_6, text="state:"})
        dx = 50*lvSCALE
        pInfo:label({x=dx, y= 80*lvSCALE, font=FS.FONT_6, text="GROUND"         , color=function() return getColorByState(wgt, "GROUND") end})
        pInfo:label({x=dx, y= 95*lvSCALE, font=FS.FONT_6, text="FLIGHT_STARTING", color=function() return getColorByState(wgt, "FLIGHT_STARTING") end})
        pInfo:label({x=dx, y=110*lvSCALE, font=FS.FONT_6, text="FLIGHT_ON"      , color=function() return getColorByState(wgt, "FLIGHT_ON") end})
        pInfo:label({x=dx, y=125*lvSCALE, font=FS.FONT_6, text="FLIGHT_ENDING"  , color=function() return getColorByState(wgt, "FLIGHT_ENDING") end})

        pInfo:label({x=  5*lvSCALE, y=145*lvSCALE, font=FS.FONT_6, text=function() return string.format("starting:\n %s", wgt.rule.is_flight_starting()) end})
        pInfo:label({x= 70*lvSCALE, y=145*lvSCALE, font=FS.FONT_6, text=function() return string.format("on_flight:\n %s", wgt.rule.is_still_on_flight()) end})
        pInfo:label({x=140*lvSCALE, y=145*lvSCALE, font=FS.FONT_6, text=function() return string.format("ending:\n %s", wgt.rule.is_flight_ending()) end})

        pInfo:rectangle({x=dx+160*lvSCALE, y=30*lvSCALE, w=260*lvSCALE, h=140*lvSCALE, color=LIGHTBLUE, filled=true, rounded=5})
        pInfo:label({x=dx+(160+10)*lvSCALE, y=40*lvSCALE, font=FS.FONT_6, text=function() return wgt.rule:info() end, color=WHITE})
    end
end

local function refresh(wgt, event, touchState)
    background(wgt)
end

return {name=app_name, create=create, update=update, refresh=refresh, background=background, useLvgl=true}

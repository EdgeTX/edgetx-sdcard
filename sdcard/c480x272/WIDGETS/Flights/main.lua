--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
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


-- Horus Widget that count number of flights
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
--
-- if widget size 1/2 or 1/1 (instead in the top bar where it design to) it will enter a debug mode
-- there are two options of voice indication (just copy flight_logged2.wav-->flight_logged.wav, flight_ended2.wav-->flight_ended.wav)
-- you can also put your own
-- if you do not like the sound, just delete the files
-- for Heli, the motor-switch=arm-switch (same value for both)
-- if you need a reversed arm switch (e.g. !SF) you need to do change it (for now) in the script: inverted_arm_switch_logic=0
-- if you prefer different logics, do them on logical switches, and put that logical switch in both Arm & motor channel
-- if you do not use telemetry, set the: use_telemetry=0

]]

local app_name = "Flights"
local app_ver = "1.1"


------------------------------------------------------------------------------------------------------------------
-- configuration
local default_flight_starting_duration = 30  -- 20 sec to detect flight success
local default_flight_ending_duration = 8     -- 8 sec to detect flight ended
local default_min_motor_value = 200
local enable_sounds = 1                      -- 0=no sound, 1=play blip sound on increment& on flight end
local enable_count_announcement_on_start = 0 -- 0=no voice, 1=play the count upon increment
local enable_count_announcement_on_end = 1   -- 0=no voice, 1=play the count upon end of flight
local enable_dbg_dots = 1                    -- 0=do not show dots, 1=show dbg dots
local use_telemetry = 1                      -- 0=do not use telemetry, 1=use telemetry in state machine
local use_flights_history = 1                -- 0=do not write flights-history, 1=write flights-history
local inverted_arm_switch_logic = 1          -- 0=armed when SF down, 1=armed when SF up
------------------------------------------------------------------------------------------------------------------


-- imports
local img = Bitmap.open("/WIDGETS/" .. app_name .. "/logo.png")

local LibLogClass = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "tcd")
local m_log = LibLogClass(app_name, "/WIDGETS/" .. app_name)

-- for backward compatibility
local function getSwitchIds(key)
    local OS_SWITCH_ID = {
        ["2.7"]  = {SA=112, SB=113, SC=114, SD=115, SE=116, SF=117, CH3 = 204},
        ["2.8"]  = {SA=120, SB=121, SC=122, SD=123, SE=124, SF=125, CH3 = 212},
        ["2.9"]  = {SA=120, SB=121, SC=122, SD=123, SE=124, SF=125, CH3 = 212},
        ["2.10"] = {SA=127, SB=128, SC=129, SD=130, SE=131, SF=132, CH3 = 229},
    }
    local ver, radio, maj, minor, rev, osname = getVersion()
    local os1 = string.format("%d.%d", maj, minor)
    return OS_SWITCH_ID[os1][key]
end

local DEFAULT_ARM_SWITCH_ID = getSwitchIds("SF")      -- arm/safety switch=SF
local DEFAULT_MOTOR_CHANNEL_ID = getSwitchIds("CH3")  -- motor_channel=CH3

local options = {
    { "switch", SOURCE, DEFAULT_ARM_SWITCH_ID },
    { "motor_channel", SOURCE, DEFAULT_MOTOR_CHANNEL_ID },
    { "min_flight_duration", VALUE, default_flight_starting_duration, 2, 120 },
    --{ "enable_sounds"    , BOOL  , 1      },  -- enable sound on adding succ flight, and on end of flight
    { "text_color", COLOR, COLOR_THEME_PRIMARY2 },
    --{ "debug", BOOL, 0 }   -- show status on screen
}

local function log(fmt, ...)
    m_log.info(fmt, ...)
end

local function update(wgt, options)
    if (wgt == nil) then return end

    wgt.options = options

    -- status
    wgt.status = {}
    wgt.status.switch_on = nil
    wgt.status.switch_name = nil
    --wgt.status.tele_src = nil
    --wgt.status.tele_src_name = nil
    wgt.status.tele_is_available = nil
    wgt.status.motor_active = nil
    wgt.status.motor_channel_name = nil
    wgt.status.motor_channel_direction_inv = nil
    wgt.status.flight_state = "GROUND"
    wgt.status.duration_passed = 0
    wgt.status.periodic1 = wgt.tools.periodicInit()
    wgt.status.last_flight_count = 0
    wgt.status.flight_start_time = 0
    wgt.status.flight_start_date_time = 0
    wgt.status.flight_end_time = 0
    wgt.status.flight_duration = 0
    wgt.status.heli_mode = false -- ignore motor direction detection, and throttle position

    --log("TimerNumB:" .. options.Timer)
    if (wgt.options.switch == nil) then
        wgt.options.switch = "sf"
    end

    --log("wgt.options.switch: " .. wgt.options.switch)
    local fi_sw = getFieldInfo(wgt.options.switch)
    if (fi_sw == nil) then
        wgt.status.switch_name = "--"
    else
        wgt.status.switch_name = fi_sw.name
    end

    local fi_mot = getFieldInfo(wgt.options.motor_channel)
    if (fi_mot == nil) then
        wgt.status.motor_channel_name = "--"
    else
        wgt.status.motor_channel_name = fi_mot.name
    end

    -- auto debug mode if widget size 1/2 or 1/1
    wgt.options.is_debug = (wgt.zone.h > 140)
    log("1111 is_debug: %s, wgt.zone.h: %s", wgt.options.is_debug, wgt.zone.h)

    -- for heli, if the motor-sw==switch-sw, then ignore motor direction detection
    if (wgt.options.switch == wgt.options.motor_channel) then
        wgt.status.heli_mode = true
    end

    -- backward compatibility
    if wgt.options.text_color == 32768 or wgt.options.text_color == 65536 or wgt.options.text_color == 98304 then
        log(string.format("wgt.options.text_color: %s", wgt.options.text_color))
        log("flights wgt.options.text_color == <invalid value>, probably upgraded from previous ver, setting to RED")
        wgt.options.text_color = RED
        log(string.format("wgt.options.text_color (fixed): %s", wgt.options.text_color))
    end

end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options
    }
    --wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1

    -- imports
    wgt.ToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
    wgt.tools = wgt.ToolsClass(m_log, app_name)

    wgt.FlightsHistoryClass = loadScript("/WIDGETS/" .. app_name .. "/lib_flights_history.lua", "tcd")
    wgt.flightHistory = wgt.FlightsHistoryClass(m_log, app_name)
    update(wgt, options)
    return wgt
end

local function getFontSize(wgt, txt)
    local wide_txt = string.gsub(txt, "[1-9]", "0")
    --log(string.gsub("******* 12:34:56", "[1-9]", "0"))
    --log("wide_txt: " .. wide_txt)

    local w, h = lcd.sizeText(wide_txt, XXLSIZE)
    --log(string.format("XXLSIZE w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return XXLSIZE
    end

    w, h = lcd.sizeText(wide_txt, DBLSIZE)
    --log(string.format("DBLSIZE w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return DBLSIZE
    end

    w, h = lcd.sizeText(wide_txt, MIDSIZE)
    --log(string.format("MIDSIZE w: %d, h: %d, %s", w, h, time_str))
    if w < wgt.zone.w and h <= wgt.zone.h then
        return MIDSIZE
    end

    --log(string.format("SMLSIZE w: %d, h: %d, %s", w, h, time_str))
    return SMLSIZE
end

---------------------------------------------------------------------------------------------------

local function updateTelemetryStatus(wgt)
    if use_telemetry == 0 then
        wgt.status.tele_is_available = true
    else
        wgt.status.tele_is_available = wgt.tools.isTelemetryAvailable()
    end
end

local function updateMotorStatus(wgt)

    -- for heli, if the motor-sw==switch-sw, then ignore motor direction detection
    if (wgt.status.heli_mode == true) then
        wgt.status.motor_active = wgt.status.switch_on
        return
    end

    local motor_value = getValue(wgt.options.motor_channel)
    --log(string.format("motor_value (%s): %s", wgt.options.motor_channel, motor_value))

    ---- if we do not have telemetry, then the battery is not connected yet, so we can detect yet motor channel direction
    --if (wgt.status.tele_is_available == nil or wgt.status.tele_is_available == false) then
    --  return
    --end

    if (wgt.status.motor_channel_direction_inv == nil) then
        -- detect motor channel direction
        if (motor_value < (-1024 + default_min_motor_value)) then
            wgt.status.motor_channel_direction_inv = false
        elseif (motor_value > (1024 - default_min_motor_value)) then
            wgt.status.motor_channel_direction_inv = true
        else
            -- still nil
            return
        end
    end

    if (wgt.status.motor_channel_direction_inv == false) then
        -- non inverted mixer
        if (motor_value > (-1024 + default_min_motor_value)) then
            wgt.status.motor_active = true
        else
            wgt.status.motor_active = false
        end
    else
        -- inverted mixer
        if (motor_value < (1024 - default_min_motor_value)) then
            wgt.status.motor_active = true
        else
            wgt.status.motor_active = false
        end
    end

end

local function updateSwitchStatus(wgt)
    local sw_val = getValue(wgt.options.switch)
    if inverted_arm_switch_logic == 1 then
        wgt.status.switch_on = (sw_val < 0)
    else
        wgt.status.switch_on = (sw_val > 0)
    end

    --if wgt.status.switch_on then
    --    log(string.format("switch status (%s): =ON", wgt.status.switch_name))
    --else
    --    log(string.format("switch status (%s): =OFF", wgt.status.switch_name))
    --end
end

--------------------------------------------------------------------------------------------------------
-- get flight count
local function getFlightCount()
    -- get GV9 (index = 0) from Flight mode 0 (FM0)
    local num_flights = model.getGlobalVariable(8, 0)
    return num_flights
end

local function doNewFlightTasks(wgt)
    log("doNewFlightTasks()")
    local new_flight_count = wgt.status.last_flight_count + 1
    model.setGlobalVariable(8, 0, new_flight_count)
    log("num_flights updated: " .. new_flight_count)

    -- beep
    if (enable_sounds == 1) then
        local is_exist_file_10 = wgt.flightHistory.isFileExist("/WIDGETS/" .. app_name .. "/flight_logged_10.wav")
        log("is_exist_file_10: %s", is_exist_file_10)

        local num_flights = getFlightCount()
        if (is_exist_file_10 == true) and (num_flights % 10 == 0) then
            playFile("/WIDGETS/" .. app_name .. "/flight_logged_10.wav")
        else
            playFile("/WIDGETS/" .. app_name .. "/flight_logged.wav")
        end
    end

    if (enable_count_announcement_on_start == 1) then
        local num_flights = getFlightCount()
        playNumber(num_flights, 0)
        playFile("/WIDGETS/" .. app_name .. "/flights.wav")
    end
end

local function doEndOfFlightTasks(wgt)
    log("doEndOfFlightTasks()")
    if (enable_sounds == 1) then
        playFile("/WIDGETS/" .. app_name .. "/flight_ended.wav")
    end

    local num_flights = getFlightCount()
    if (enable_count_announcement_on_end == 1) then
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

    updateSwitchStatus(wgt)

    updateMotorStatus(wgt) -- always after updateSwitchStatus

    updateTelemetryStatus(wgt)

    --log(string.format("tele_is_available: %s", wgt.status.tele_is_available))

    -- **** state: GROUND ***
    if wgt.status.flight_state == "GROUND" then
            if (wgt.status.motor_active == true) and (wgt.status.switch_on == true) and (use_telemetry==0 or wgt.status.tele_is_available == true) then
            stateChange(wgt, "FLIGHT_STARTING", wgt.options.min_flight_duration)
            wgt.status.last_flight_count = getFlightCount()

            wgt.status.flight_start_time = getTime() * 10 / 1000
            wgt.status.flight_start_date_time = getDateTime()
            log("flight_start_time: %s", wgt.status.flight_start_time)
        end
        return

        -- **** state: FLIGHT_STARTING ***
    elseif wgt.status.flight_state == "FLIGHT_STARTING" then

        if (wgt.status.motor_active == false) or (wgt.status.switch_on == false) or (use_telemetry==1 and wgt.status.tele_is_available == false) then
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
        if (wgt.status.motor_active == true) and (wgt.status.switch_on == true) then
            wgt.status.flight_end_time = getTime() * 10 / 1000
            wgt.status.flight_duration = wgt.status.flight_end_time - wgt.status.flight_start_time
            log("flight_start_time: %s", wgt.status.flight_start_time)
            log("flight_end_time: %s", wgt.status.flight_end_time)
            log("flight_duration: %s", wgt.status.flight_duration)
        end

        if (use_telemetry==1 and wgt.status.tele_is_available == false) or (use_telemetry==0 and wgt.status.switch_on == false) then
            stateChange(wgt, "FLIGHT_ENDING", default_flight_ending_duration)

            local num_flights = getFlightCount()
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

        --if (wgt.status.tele_is_available == true) then
        if (use_telemetry==1 and wgt.status.tele_is_available == true) or (use_telemetry==0 and wgt.status.switch_on == true) then
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

local function drawTopbarDot(wgt, i, is_on)
    local dxc = 6
    if is_on==true then
        lcd.drawFilledCircle(5, 24 + dxc*i, 2, GREEN)
    else
        lcd.drawFilledCircle(5, 24 + dxc*i, 2, GREY)
    end
end


local function refresh(wgt, event, touchState)
    if (wgt == nil) then log("refresh(nil)") return end
    if (wgt.options == nil) then log("refresh(wgt.options=nil)") return end

    background(wgt)

    -- get flight count
    local num_flights = getFlightCount()

    -- header
    local header = "Flights:"
    local header_w, header_h = lcd.sizeText(header, SMLSIZE)

    local font_size = getFontSize(wgt, num_flights)
    local zone_w = wgt.zone.w
    local zone_h = wgt.zone.h

    local font_size_header = SMLSIZE
    if (event ~= nil) then
        -- app mode (full screen)
        font_size = XXLSIZE
        font_size_header = DBLSIZE
        zone_w = LCD_W
        zone_h = LCD_H - 20
    end

    local ts_w, ts_h = lcd.sizeText(num_flights, font_size)
    local dx = (zone_w - ts_w) / 2
    local dyh = 5
    local dy = header_h - 1
    local icon_y = 22
    local icon_x = 15
    local is_top_bar = false
    if (header_h + ts_h > zone_h) and (zone_h < 50) then
        is_top_bar = true
    end

    if is_top_bar then
        --log(string.format("--- not enough height, force minimal spaces"))
        dyh = -3
        dy = 8
    end

    -- icon
    if wgt.options.is_debug == false then
        if is_top_bar == false then
            lcd.drawBitmap(img, icon_x, icon_y, 45)
        end
    end

    -- draw header
    lcd.drawText(wgt.zone.x, wgt.zone.y + dyh, header, font_size_header + wgt.options.text_color)

    -- enable_dbg_dots
    if (enable_dbg_dots == 1) then
        drawTopbarDot(wgt, 0, wgt.status.tele_is_available==true)
        drawTopbarDot(wgt, 1, wgt.status.switch_on==true)
        drawTopbarDot(wgt, 2, wgt.status.motor_active==true)
    end

    -- draw count
    if is_top_bar == true then
        --lcd.drawText(wgt.zone.x + 4, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color)
        --lcd.drawText(wgt.zone.x + wgt.zone.w -6, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + RIGHT)
        lcd.drawText(wgt.zone.x + (wgt.zone.w / 2), wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + CENTER)
    else
        lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + RIGHT)
    end

    -- debug
    if wgt.options.is_debug == true then
        local dx = 15
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 25, string.format("DEBUG:"), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 20, string.format("%s - switch (%s)", ternary(wgt.status.switch_on), wgt.status.switch_name), SMLSIZE)
        if (wgt.status.heli_mode == false) then
            lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 35, string.format("%s - throttle (%s) (inv: %s)", ternary(wgt.status.motor_active), wgt.status.motor_channel_name, wgt.status.motor_channel_direction_inv), SMLSIZE)
        else
            lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 35, string.format("%s - throttle (%s) (heli mode)", ternary(wgt.status.motor_active), wgt.status.motor_channel_name), SMLSIZE)
        end
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 50, string.format("%s - telemetry(%s)", ternary(wgt.status.tele_is_available), wgt.tools.tele_src_name), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 65, string.format("duration: %.1f/%d", wgt.status.duration_passed / 1000, wgt.tools.getDurationMili(wgt.status.periodic1) / 1000), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 80, string.format("flight duration: %.1f", wgt.status.flight_duration), SMLSIZE)
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 110, string.format("state: %s", wgt.status.flight_state), 0)

        local GROUND_COLOR          = (wgt.status.flight_state == "GROUND")             and BLUE or 0+GREY
        local FLIGHT_STARTING_COLOR = (wgt.status.flight_state == "FLIGHT_STARTING")    and BLUE or 0+GREY
        local FLIGHT_ON_COLOR       = (wgt.status.flight_state == "FLIGHT_ON")          and BLUE or 0+GREY
        local FLIGHT_ENDING_COLOR   = (wgt.status.flight_state == "FLIGHT_ENDING")      and BLUE or 0+GREY
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 105, "state:"                      , SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 105, "             GROUND"         , SMLSIZE + GROUND_COLOR)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 120, "             FLIGHT_STARTING", SMLSIZE + FLIGHT_STARTING_COLOR)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 135, "             FLIGHT_ON"      , SMLSIZE + FLIGHT_ON_COLOR)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 150, "             FLIGHT_ENDING"  , SMLSIZE + FLIGHT_ENDING_COLOR)

        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 110, "state: GROUND"         , 0 + GROUND_COLOR)
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 125, "state: FLIGHT_STARTING", 0 + FLIGHT_STARTING_COLOR)
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 140, "state: FLIGHT_ON"      , 0 + FLIGHT_ON_COLOR)
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 155, "state: FLIGHT_ENDING"  , 0 + FLIGHT_ENDING_COLOR)

    end

end

return { name = app_name, options = options, create = create, update = update, background = background, refresh = refresh }

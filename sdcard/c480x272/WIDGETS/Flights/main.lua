-- Horus Widget that count number of flights
-- Offer Shmuely
-- Date: 2022
-- ver: 0.4
-- flight considered successful: after 30sec the engine above 25%, and telemetry is active (to indicated that the model connected), and safe switch ON
-- flight considered ended: after 8sec of battery disconnection (detected by no telemetry)
-- warning: do NOT use this widget if model is using GV9!!!

-- widget assume the following:
--   the model have motor
--   the motor is activated on channel 3 (can be change in settings)
--   there is telemetry with one of the above [RSSI|RxBt|A1|A2|1RSS|2RSS|RQly]
--   there is a safe switch (arm switch)
--   global variable GV9 is free (i.e. not used)

-- state machine:
--   ground --> flight-starting --> flight-on --> flight-ending --> ground
--   all-flags on for 30s => flight-on
--   no telemetry for 8s  => flight-completed


-- Tips:
--
-- there are two options of voice indication (just copy flight_logged2.wav-->flight_logged.wav, flight_ended2.wav-->flight_ended.wav)
-- you can also put your own
-- if you do not like the sound, just delete the files
-- for Heli, you need to put the arm switch in the motor switch
-- if you need a reversed arm switch (e.g. !SF) you need to do that (for now) in a logical switch
-- if you prefer different logics, do them on logical switches, and put that logical switch in both Arm & motor channel

local app_name = "Flights"

local periodic1 = {
    startTime = getTime(),
    durationMili = 0
}

-- imports
local img = Bitmap.open("/WIDGETS/" .. app_name .. "/logo.png")

-- const
local default_flight_starting_duration = 30 -- 20 sec to detect fight success
local default_flight_ending_duration = 8 -- 8 sec to detect fight ended
local default_min_motor_value = 200
local enable_sounds = 1                      -- 0=no sound, 1=play blip sound on increment& on flight end
local enable_count_announcement_on_start = 1 -- 0=no voice, 1=play the count upon increment
local enable_count_announcement_on_end = 1   -- 0=no voice, 1=play the count upon end of flight

local options = {
    { "switch", SOURCE, 117 }, -- 117== SF (arm/safety switch)
    { "motor_channel", SOURCE, 204 }, -- 204==CH3
    { "min_flight_duration", VALUE, default_flight_starting_duration, 2, 120 },
    --{ "enable_sounds"    , BOOL  , 1      },  -- enable sound on adding succ flight, and on end of flight
    { "text_color", COLOR, YELLOW },
    { "debug", BOOL, 0 }   -- show status on screen
}

local function log(s)
    --  print(app_name .. ": " .. s)
end

local function update(wgt, options)
    if (wgt == nil) then return end

    wgt.options = options

    -- status
    wgt.status = {}
    wgt.status.switch_on = nil
    wgt.status.switch_name = nil
    wgt.status.tele_src = nil
    wgt.status.tele_src_name = nil
    wgt.status.tele_is_available = nil
    wgt.status.motor_active = nil
    wgt.status.motor_channel_name = nil
    wgt.status.motor_channel_direction_inv = nil
    wgt.status.flight_state = "GROUND"
    wgt.status.duration_passed = 0


    --log("TimerNumB:" .. options.Timer)
    if (wgt.options.switch == nil) then
        wgt.options.switch = "sf"
    end

    --log("wgt.options.switch: " .. wgt.options.switch)
    fi_sw = getFieldInfo(wgt.options.switch)
    if (fi_sw == nil) then
        wgt.status.switch_name = "--"
    else
        wgt.status.switch_name = fi_sw.name
    end

    fi_mot = getFieldInfo(wgt.options.motor_channel)
    if (fi_mot == nil) then
        wgt.status.motor_channel_name = "--"
    else
        wgt.status.motor_channel_name = fi_mot.name
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
    local wgt = { zone = zone, options = options }
    --wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1
    update(wgt, options)
    return wgt
end

local function getFontSize(wgt, txt)
    wide_txt = string.gsub(txt, "[1-9]", "0")
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

------------------------------------------------------------

local function periodicStart(t, durationMili)
    t.startTime = getTime();
    t.durationMili = durationMili;
end

local function periodicHasPassed(t)
    local elapsed = getTime() - t.startTime;
    log(string.format('elapsed: %d (t.durationMili: %d)', elapsed, t.durationMili))
    local elapsedMili = elapsed * 10;
    if (elapsedMili < t.durationMili) then
        return false;
    end
    return true;
end

local function periodicGetElapsedTime(t)
    local elapsed = getTime() - t.startTime;
    --log(string.format("elapsed: %d",elapsed));
    local elapsedMili = elapsed * 10;
    --log(string.format("elapsedMili: %d",elapsedMili));
    return elapsedMili;
end

local function periodicReset(t)
    t.startTime = getTime();
    log(string.format("periodicReset()"));
    periodicGetElapsedTime(t)
end

--------------------------------------------------------------------------------------------------------

function updateTelemetryStatus(wgt)
    -- select telemetry source
    if not wgt.status.tele_src then
        --log("select telemetry source")
        wgt.status.tele_src = getFieldInfo("RSSI")
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("RxBt") end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("A1")   end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("A2")   end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("1RSS") end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("2RSS") end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("RQly") end
        if not wgt.status.tele_src then wgt.status.tele_src = getFieldInfo("TRSS") end

        if wgt.status.tele_src ~= nil then
            wgt.status.tele_src_name = wgt.status.tele_src.name
            log("found telemetry source: " .. wgt.status.tele_src_name)
        end
    end

    if wgt.status.tele_src == nil then
        log("no telemetry sensor found")
        wgt.status.tele_src_name = "---"
        wgt.status.tele_is_available = false
        return
    end

    local tele_src_val = getValue(wgt.status.tele_src.id)
    --log("tele_src.id: " .. tele_src.id)
    --log("tele_src_name: " .. wgt.status.tele_src_name)
    --log("tele_src_val: " .. wgt.status.tele_src_val)
    local tele_val = getValue(wgt.status.tele_src.id)
    if tele_val <= 0 then
        --log("tele: tele_val<=0")
        wgt.status.tele_is_available = false
        return
    end

    --log("tele: tele_val>0")
    wgt.status.tele_is_available = true
    return

end

function updateMotorStatus(wgt)
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

function updateSwitchStatus(wgt)
    if getValue(wgt.options.switch) < 0 then
        --log(string.format("switch status (%s): =ON", wgt.options.switch))
        wgt.status.switch_on = true
    else
        --log(string.format("switch status (%s): =OFF", wgt.status.switch_name))
        wgt.status.switch_on = false
    end
end

--------------------------------------------------------------------------------------------------------
local function getFlightCount()
    -- get flight count
    -- get GV9 (index = 0) from Flight mode 0 (FM0)
    local num_flights = model.getGlobalVariable(8, 0)
    return num_flights
end

local function incrementFlightCount(wgt)
    local num_flights = getFlightCount()
    local new_flight_count = num_flights + 1
    model.setGlobalVariable(8, 0, new_flight_count)
    log("num_flights updated: " .. new_flight_count)

    -- beep
    --if (wgt.options.enable_sounds) then
    if (enable_sounds == 1) then
        playFile("/WIDGETS/" .. app_name .. "/flight_logged.wav")
    end

    if (enable_count_announcement_on_start == 1) then
        local num_flights = getFlightCount()
        playNumber(num_flights, 0)
        playFile("/WIDGETS/" .. app_name .. "/flights.wav")
    end

end

---------------------------------------------------------------
local function stateChange(wgt, newState, timer_sec)
    log(string.format("flight_state: %s --> %s", wgt.status.flight_state, newState))
    wgt.status.flight_state = newState

    if (timer_sec > 0) then
        periodicStart(periodic1, timer_sec * 1000)
    else
        wgt.status.duration_passed = 0
        --periodicReset(periodic1)
    end
end

local function background(wgt)

    updateMotorStatus(wgt)

    updateSwitchStatus(wgt)

    updateTelemetryStatus(wgt)

    --log(string.format("tele_is_available: %s", wgt.status.tele_is_available))

    -- **** state: GROUND ***
    if wgt.status.flight_state == "GROUND" then
        if (wgt.status.motor_active == true) and (wgt.status.switch_on == true) and (wgt.status.tele_is_available == true) then
            stateChange(wgt, "FLIGHT_STARTING", wgt.options.min_flight_duration)
        end

        -- **** state: FLIGHT_STARTING ***
    elseif wgt.status.flight_state == "FLIGHT_STARTING" then
        if (wgt.status.motor_active == true) and (wgt.status.switch_on == true) and (wgt.status.tele_is_available == true) then
            wgt.status.duration_passed = periodicGetElapsedTime(periodic1)
            log("flight_state: FLIGHT_STARTING ..." .. wgt.status.duration_passed)
            if (periodicHasPassed(periodic1)) then
                stateChange(wgt, "FLIGHT_ON", 0)

                -- yep, we have a good flight, count it!
                incrementFlightCount(wgt)

            end
        else
            stateChange(wgt, "GROUND", 0)
        end

        -- **** state: FLIGHT_ON ***
    elseif wgt.status.flight_state == "FLIGHT_ON" then
        if (wgt.status.tele_is_available == false) then
            stateChange(wgt, "FLIGHT_ENDING", default_flight_ending_duration)
        end

        -- **** state: FLIGHT_ENDING ***
    elseif wgt.status.flight_state == "FLIGHT_ENDING" then
        wgt.status.duration_passed = periodicGetElapsedTime(periodic1)
        log("flight_state: FLIGHT_ENDING ..." .. wgt.status.duration_passed)

        if (periodicHasPassed(periodic1)) then
            stateChange(wgt, "GROUND", 0)
            --if (wgt.options.enable_sounds) then
            if (enable_sounds == 1) then
                playFile("/WIDGETS/" .. app_name .. "/flight_ended.wav")
            end

            if (enable_count_announcement_on_end == 1) then
                local num_flights = getFlightCount()
                playNumber(num_flights, 0)
                playFile("/WIDGETS/" .. app_name .. "/flights.wav")
            end
        end

        if (wgt.status.tele_is_available == true) then
            stateChange(wgt, "FLIGHT_ON", 0)
        end

    end
    --log("flight_state: " .. wgt.status.flight_state)
end

function ternary(cond, T, F)
    if cond then
        return "ON"
    else
        return "OFF"
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
    if wgt.options.debug == 0 then
        if is_top_bar == false then
            lcd.drawBitmap(img, icon_x, icon_y, 45)
        end
    end

    -- draw header
    lcd.drawText(wgt.zone.x, wgt.zone.y + dyh, header, font_size_header + wgt.options.text_color)

    -- draw count
    if is_top_bar == true then
        --lcd.drawText(wgt.zone.x + 4, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color)
        --lcd.drawText(wgt.zone.x + wgt.zone.w -6, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + RIGHT)
        lcd.drawText(wgt.zone.x + (wgt.zone.w / 2), wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + CENTER)
    else
        lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + dy, num_flights, font_size + wgt.options.text_color + RIGHT)
    end

    -- debug
    if wgt.options.debug == 1 then
        local dx = 5
        --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 25, string.format("DEBUG:"), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 30, string.format("%s - switch(%s)", ternary(wgt.status.switch_on), wgt.status.switch_name), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 45, string.format("%s - motor(%s) (inv: %s)", ternary(wgt.status.motor_active), wgt.status.motor_channel_name, wgt.status.motor_channel_direction_inv), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 60, string.format("%s - telemetry(%s)", ternary(wgt.status.tele_is_available), wgt.status.tele_src_name), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 75, string.format("duration: %.1f/%d", wgt.status.duration_passed / 1000, periodic1.durationMili / 1000), SMLSIZE)
        lcd.drawText(wgt.zone.x + dx, wgt.zone.y + 100, string.format("state: %s", wgt.status.flight_state), 0)
    end

end

return { name = app_name, options = options, create = create, update = update, background = background, refresh = refresh }

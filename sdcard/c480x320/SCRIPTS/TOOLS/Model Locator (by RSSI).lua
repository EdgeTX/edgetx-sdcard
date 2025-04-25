---- TNS|Model Locator by RSSI|TNE
---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for FrSky Horus/Radio Master TX16s            #
---- # Copyright (C) EdgeTX                                                  #
-----#                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
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

-- Model Locator by RSSI
-- Offer Shmuely (based on code from Scott Bauer 6/21/2015)
-- Date: 2022-2024
-- ver: 0.6
local app_ver = "0.6"

-- This widget help to find a lost/crashed model based on the RSSI (if still available)
-- The widget produce audio representation (vario-meter style) of the RSSI from the lost model
-- The widget also  display the RSSI in a visible colorized bar (0-100%)

-- There are two way to use it
-- 1. The simple way:
--    walk toward the quad/plane that crashed,
--    as you get closer to your model the beeps will become more frequent with higher pitch (and a visual bar graph as well)
--    until you get close enough to find it visually

-- 2. the more accurate way:
--    turn the antenna straight away (i.e. to point from you, straight away)
--    try to find the weakest signal! (not the highest), i.e. the lowest RSSI you can find, this is the direction to the model.
--    now walk to the side (not toward the model), find again the weakest signal, this is also the direction to your model
--    triangulate the two lines, and it will be :-)

local delayMillis = 100
local targetTXPower = 25
local nextPlayTime = getTime()
local img = bitmap.open("/SCRIPTS/TOOLS/Model Locator (by RSSI).png")
local useHaptic = false

--------------------------------------------------------------
local function log(s)
  -- print("locator: " .. s)
end
--------------------------------------------------------------


-- init_func is called once when model is loaded
local function init()
    return 0
end

-- This function returns green at gvalue, red at rvalue and graduate in between
local function getRangeColor(value, red_value, green_value)
    local range = math.abs(green_value - red_value)
    if range == 0 then
        return lcd.RGB(0, 0xdf, 0)
    end
    if value == nil then
        return lcd.RGB(0, 0xdf, 0)
    end

    if green_value > red_value then
        if value > green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value < red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        g = math.floor(0xdf * (value - red_value) / range)
        r = 0xdf - g
        return lcd.RGB(r, g, 0)
    else
        if value > green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value < red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        r = math.floor(0xdf * (value - green_value) / range)
        g = 0xdf - r
        return lcd.RGB(r, g, 0)
    end
end

local function getSignalValues()
    -- try to get transmitter power
    local txPowerField = getFieldInfo("TPWR")
    local txPowerValue = nil
    if txPowerField then
        txPowerValue = getValue("TPWR")
    end

    -- try regular Frsky RSSI
    local fieldinfo = getFieldInfo("RSSI")
    if fieldinfo then
        local v = getValue("RSSI")
        log("RSSI: " .. v)
        return v, 0, 100, txPowerValue, "Using signal: Frsky RSSI", nil
    end

    -- try expressLRS antenna 1
    local fieldinfo = getFieldInfo("1RSS")
    if fieldinfo then
        local v = getValue("1RSS")
        if v == 0 then
            v = -115
        end
        return v, -115, 20, txPowerValue, "Using signal: ELRS 1RSS", "Set TX Power to 25mW Non-Dynamic"
    end

    -- try expressLRS antenna 2
    local fieldinfo = getFieldInfo("2RSS")
    if fieldinfo then
        local v = getValue("2RSS")
        if v == 0 then
            v = -115
        end
        return v, -115, 20, txPowerValue, "Using signal: ELRS 2RSS", "Set TX Power to 25mW Non-Dynamic"
    end

    ---- try UNI-ACSST firmware VFR
    --local fieldinfo = getFieldInfo("VFR")
    --if fieldinfo then
    --    local v = getValue("VFR")
    --    log("RSSI: " .. v)
    --    lcd.drawText(3, 30, "Signal: VFR", 0)
    --    return v, 0, 100
    --end
    --
    ---- try elrs RQLY
    --local fieldinfo = getFieldInfo("RQLY")
    --if fieldinfo then
    --    local v = getValue("RQLY")
    --    log("RQLY: " .. v)
    --    lcd.drawText(3, 30, "Signal: RQLY", 0)
    --    return v, 0, 100
    --end

    return nil, 0, 0
end


local function main(event, touchState)
    lcd.clear()
    lcd.drawBitmap(img, LCD_W-120, 30, 20)

    -- Title
    lcd.drawFilledRectangle(0,0, LCD_W, 30, BLACK)
    lcd.drawFilledRectangle(0,LCD_H-25, LCD_W, 25, GREY)
    lcd.drawText(10, 3, "RSSI Model Locator", WHITE)
    lcd.drawText(LCD_W - 50, 3, "ver: " .. app_ver .. "", SMLSIZE + GREEN)

    local signalValue, signalMin, signalMax, txPower, line1, line2 = getSignalValues()
    -- log(signalValue)
    if signalValue == nil then
        lcd.drawText(30, 50, "No signal found (expected: RSSI/1RSS/2RSS)", 0 + BLINK)
        return 0
    end

    if txPower then
        lcd.drawText(3, 60, "Current TX Power: " .. tostring(txPower) .. "mW", (txPower == targetTXPower) and DARKGREEN or RED)

        if txPower ~= targetTXPower then
            lcd.drawText(3, 75, line2 or "", RED + BLINK)
        end
    end

    lcd.drawText(10, LCD_H-22, line1, WHITE)
    lcd.drawText(300, LCD_H-22, "[ENTER] to toggle haptic", WHITE)

    log("signalValue:" .. signalValue .. ", signalMin: " .. signalMin .. ", signalMax: " .. signalMax)

    local signalPercent = 100 * ((signalValue - signalMin) / (signalMax - signalMin))
    lcd.setColor(CUSTOM_COLOR, getRangeColor(signalPercent, 0, 100))

    -- draw current value
    lcd.drawText(3, 90, tostring(signalValue) .. "dB", XXLSIZE + CUSTOM_COLOR)

    -- draw main bar
    local xMin = 10
    local yMin = LCD_H - 30
    local xMax = LCD_W
    local h = 0
    local rssiAsX = (signalPercent * xMax) / 100
    log("signalPercent:" .. signalPercent .. ", signalValue: " .. signalValue .. ", rssiAsX: " .. rssiAsX)
    for xx = xMin, rssiAsX, 20 do
        lcd.setColor(CUSTOM_COLOR, getRangeColor(xx, xMin, xMax - 40))
        h = h + 10
        lcd.drawFilledRectangle(xx, yMin - h, 15, h, CUSTOM_COLOR)
    end

    -- toggle haptic
    if event == EVT_VIRTUAL_ENTER then
        useHaptic = not useHaptic
    end

    -- beep
    if getTime() >= nextPlayTime then
        playFile("/SCRIPTS/TOOLS/Model Locator (by RSSI).wav")
        if useHaptic then
            playHaptic(7, 0, 1)
        end
        nextPlayTime = getTime() + delayMillis - signalPercent
    end

    return 0
end

return { init = init, run = main }


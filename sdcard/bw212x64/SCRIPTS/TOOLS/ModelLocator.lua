---- TNS|Model Locator|TNE
---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for b&w 212x64 radios                         #
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
-- AegisCrusader & Offer Shmuely (based on code from Scott Bauer 6/21/2015)
-- Date: 2022-2024
-- ver: 0.6
local app_ver = "0.6"

-- This widget help to find a lost/crashed model based on the RSSI (if still available)
-- The widget produce audio representation (vario-meter style) of the RSSI from the lost model
-- The widget also displays the RSSI in a visible bar

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
local useHaptic = false

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
        return v, 0, 100, txPowerValue, "Using signal: Frsky RSSI", nil
    end

    -- try expressLRS antenna 1
    local fieldinfo = getFieldInfo("1RSS")
    if fieldinfo then
        local v = getValue("1RSS")
        if v == 0 then
            v = -115
        end
        return v, -115, 20, txPowerValue, "Using signal: ELRS 1RSS", "Set TX PWR 25mW No Dyn"
    end

    -- try expressLRS antenna 2
    local fieldinfo = getFieldInfo("2RSS")
    if fieldinfo then
        local v = getValue("2RSS")
        if v == 0 then
            v = -115
        end
        return v, -115, 20, txPowerValue, "Using signal: ELRS 2RSS", "Set TX PWR 25mW No Dyn"
    end

    return nil, 0, 0
end

local function init()
    lcd.clear()
end

local function run(event)
    -- exit script
    if event == EVT_VIRTUAL_EXIT then
        return 2
    end

    lcd.clear()

    local signalValue, signalMin, signalMax, txPower, line1, line2 = getSignalValues()

    lcd.drawText(0, 0, "Model Locator by RSSI", BOLD)

    if signalValue == nil then
        lcd.drawText(0, 24, "No signal, expected:", 0 + BLINK)
        lcd.drawText(0, 32, "RSSI/1RSS/2RSS", 0 + BLINK)
        return 0
    end

    if txPower then
        lcd.drawText(0, 16, "Current TX PWR: " .. tostring(txPower) .. "mW")

        if txPower ~= targetTXPower then
            lcd.drawText(0, 8, line2 or "", BLINK)
        else
            lcd.drawText(0, 8, "[ENTER] to toggle haptic")
        end
    else
        lcd.drawText(0, 8, "[ENTER] to toggle haptic")
    end

    local signalPercent = 100 * ((signalValue - signalMin) / (signalMax - signalMin))

    lcd.drawText(0, 24, tostring(signalValue) .. "dB", DBLSIZE)

    -- draw main bar
    local xMin = 10
    local yMin = LCD_H - 10
    local xMax = LCD_W
    local h = 0
    local rssiAsX = (signalPercent * xMax) / 100

    for xx = xMin, rssiAsX, 8 do
        h = h + 2
        lcd.drawFilledRectangle(xx, yMin - h, 5, h)
    end

    lcd.drawFilledRectangle(0, LCD_H - 10, LCD_W, 1)

    -- current signal type
    lcd.drawText(0, LCD_H - 8, line1)

    -- toggle haptic
    if event == EVT_VIRTUAL_ENTER then
        useHaptic = not useHaptic
    end

    -- beep
    if getTime() >= nextPlayTime then
        playFile("/SCRIPTS/TOOLS/modloc.wav")
        if useHaptic then
            playHaptic(7, 0, 1)
        end
        nextPlayTime = getTime() + delayMillis - signalPercent
    end

    return 0
end

return {init = init, run = run}

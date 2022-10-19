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
-- Date: 2022
-- ver: 0.3

-- This widget help to find a lost/crashed model based on the RSSI (if still available)
-- The widget produce audio representation (variometer style) of the RSSI from the lost model
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
local nextPlayTime = getTime()
local img = Bitmap.open("/SCRIPTS/TOOLS/Model Locator (by RSSI).png")

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

    -- try regular RSSI
    local fieldinfo = getFieldInfo("RSSI")
    if fieldinfo then
        local v = getValue("RSSI")
        log("RSSI: " .. v)
        lcd.drawText(3, 30, "Signal: RSSI", 0)
        return v, 0, 100
    end

    -- try expressLRS
    local fieldinfo = getFieldInfo("1RSS")
    if fieldinfo then
        local v = getValue("1RSS")
        lcd.drawText(3, 30, "Signal: 1RSS", 0)
        if v == 0 then
            v = -115
        end
        return v, -115, 20
    end

    -- try expressLRS
    local fieldinfo = getFieldInfo("2RSS")
    if fieldinfo then
        local v = getValue("2RSS")
        lcd.drawText(3, 30, "Signal: 2RSS", 0)
        if v == 0 then
            v = -115
        end
        return v, -115, 20
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

    lcd.drawText(30, 3, "Signal: not found in RSSI/1RSS/2RSS", 0)
    return nil, 0, 0
end


local function main(event, touchState)
    lcd.clear()

    local signalValue, signalMin, signalMax = getSignalValues()
    -- log(signalValue)
    if signalValue == nil then
        return
    end
    log("signalValue:" .. signalValue .. ", signalMin: " .. signalMin .. ", signalMax: " .. signalMax)

    -- background
    --lcd.drawBitmap(img, 0, 20, 30)
    lcd.drawBitmap(img, 250, 50, 40)

    -- Title
    lcd.drawText(3, 3, "RSSI Model Locator", 0)

    --if (rssi > 42) then
    --  lcd.setColor(CUSTOM_COLOR, YELLOW) -- RED / YELLOW
    --else
    --  lcd.setColor(CUSTOM_COLOR, RED) -- RED / YELLOW
    --end
    local signalPercent = 100 * ((signalValue - signalMin) / (signalMax - signalMin))
    --myColor = getRangeColor(signalPercent, 0, 100)
    --lcd.setColor(CUSTOM_COLOR, myColor)
    lcd.setColor(CUSTOM_COLOR, getRangeColor(signalPercent, 0, 100))

    -- draw current value
    lcd.drawNumber(180, 30, signalValue, XXLSIZE + CUSTOM_COLOR)
    lcd.drawText(260, 70, "db", 0 + CUSTOM_COLOR)

    -- draw main bar
    --lcd.setColor(CUSTOM_COLOR, YELLOW) -- RED / YELLOW
    local xMin = 0
    local yMin = 270
    local xMax = 480
    local yMax = 200
    local h = 0
    local rssiAsX = (signalPercent * xMax) / 100
    log("signalPercent:" .. signalPercent .. ", signalValue: " .. signalValue .. ", rssiAsX: " .. rssiAsX)
    for xx = xMin, rssiAsX, 20 do
        lcd.setColor(CUSTOM_COLOR, getRangeColor(xx, xMin, xMax - 40))
        h = h + 10
        lcd.drawFilledRectangle(xx, yMin - h, 15, h, CUSTOM_COLOR)
    end

    -- draw rectangle
    --lcd.drawFilledRectangle(0, 250, signalPercent * 4.8, 20, GREY_DEFAULT)

    -- beep
    if getTime() >= nextPlayTime then
        playFile("/SCRIPTS/TOOLS/Model Locator (by RSSI).wav")
        nextPlayTime = getTime() + delayMillis - signalPercent
    end

    return 0
end

return { init = init, run = main }


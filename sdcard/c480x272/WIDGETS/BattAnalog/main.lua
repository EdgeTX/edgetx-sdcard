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


-- This widget display a graphical representation of a Lipo/Li-ion (not other types) battery level,
-- it will automatically detect the cell amount of the battery.
-- it will take a lipo/li-ion voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli

]]

-- Widget to display the levels of Lipo battery from single analog source
-- Author : Offer Shmuely
-- Date: 2021-2023
-- ver: 0.5

local app_name = "BattAnalog"

local CELL_DETECTION_TIME = 8

local _options = {
    { "Sensor"            , SOURCE, 0      }, -- default to 'A1'
    { "Color"             , COLOR , YELLOW },
    { "Show_Total_Voltage", BOOL  , 0      }, -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
    { "Lithium_Ion"       , BOOL  , 0      }, -- 0=LIPO battery, 1=LI-ION (18650/21500)
}

-- Data gathered from commercial lipo sensors
local _lipoPercentListSplit = {
    { { 3.000,  0 }, { 3.093,  1 }, { 3.196,  2 }, { 3.301,  3 }, { 3.401,  4 }, { 3.477,  5 }, { 3.544,  6 }, { 3.601,  7 }, { 3.637,  8 }, { 3.664,  9 }, { 3.679, 10 }, { 3.683, 11 }, { 3.689, 12 }, { 3.692, 13 } },
    { { 3.705, 14 }, { 3.710, 15 }, { 3.713, 16 }, { 3.715, 17 }, { 3.720, 18 }, { 3.731, 19 }, { 3.735, 20 }, { 3.744, 21 }, { 3.753, 22 }, { 3.756, 23 }, { 3.758, 24 }, { 3.762, 25 }, { 3.767, 26 } },
    { { 3.774, 27 }, { 3.780, 28 }, { 3.783, 29 }, { 3.786, 30 }, { 3.789, 31 }, { 3.794, 32 }, { 3.797, 33 }, { 3.800, 34 }, { 3.802, 35 }, { 3.805, 36 }, { 3.808, 37 }, { 3.811, 38 }, { 3.815, 39 } },
    { { 3.818, 40 }, { 3.822, 41 }, { 3.825, 42 }, { 3.829, 43 }, { 3.833, 44 }, { 3.836, 45 }, { 3.840, 46 }, { 3.843, 47 }, { 3.847, 48 }, { 3.850, 49 }, { 3.854, 50 }, { 3.857, 51 }, { 3.860, 52 } },
    { { 3.863, 53 }, { 3.866, 54 }, { 3.870, 55 }, { 3.874, 56 }, { 3.879, 57 }, { 3.888, 58 }, { 3.893, 59 }, { 3.897, 60 }, { 3.902, 61 }, { 3.906, 62 }, { 3.911, 63 }, { 3.918, 64 } },
    { { 3.923, 65 }, { 3.928, 66 }, { 3.939, 67 }, { 3.943, 68 }, { 3.949, 69 }, { 3.955, 70 }, { 3.961, 71 }, { 3.968, 72 }, { 3.974, 73 }, { 3.981, 74 }, { 3.987, 75 }, { 3.994, 76 } },
    { { 4.001, 77 }, { 4.007, 78 }, { 4.014, 79 }, { 4.021, 80 }, { 4.029, 81 }, { 4.036, 82 }, { 4.044, 83 }, { 4.052, 84 }, { 4.062, 85 }, { 4.074, 86 }, { 4.085, 87 }, { 4.095, 88 } },
    { { 4.105, 89 }, { 4.111, 90 }, { 4.116, 91 }, { 4.120, 92 }, { 4.125, 93 }, { 4.129, 94 }, { 4.135, 95 }, { 4.145, 96 }, { 4.176, 97 }, { 4.179, 98 }, { 4.193, 99 }, { 4.200, 100 } },
}

-- from: https://electric-scooter.guide/guides/electric-scooter-battery-voltage-chart/
local _liionPercentListSplit = {
    { { 2.800,  0 }, { 2.840,  1 }, { 2.880,  2 }, { 2.920,  3 }, { 2.960,  4 } },
    { { 3.000,  5 }, { 3.040,  6 }, { 3.080,  7 }, { 3.096,  8 }, { 3.112,  9 } },
    { { 3.128, 10 }, { 3.144, 11 }, { 3.160, 12 }, { 3.176, 13 }, { 3.192, 14 } },
    { { 3.208, 15 }, { 3.224, 16 }, { 3.240, 17 }, { 3.256, 18 }, { 3.272, 19 } },
    { { 3.288, 20 }, { 3.304, 21 }, { 3.320, 22 }, { 3.336, 23 }, { 3.352, 24 } },
    { { 3.368, 25 }, { 3.384, 26 }, { 3.400, 27 }, { 3.416, 28 }, { 3.432, 29 } },
    { { 3.448, 30 }, { 3.464, 31 }, { 3.480, 32 }, { 3.496, 33 }, { 3.504, 34 } },
    { { 3.512, 35 }, { 3.520, 36 }, { 3.528, 37 }, { 3.536, 38 }, { 3.544, 39 } },
    { { 3.552, 40 }, { 3.560, 41 }, { 3.568, 42 }, { 3.576, 43 }, { 3.584, 44 } },
    { { 3.592, 45 }, { 3.600, 46 }, { 3.608, 47 }, { 3.616, 48 }, { 3.624, 49 } },
    { { 3.632, 50 }, { 3.640, 51 }, { 3.648, 52 }, { 3.656, 53 }, { 3.664, 54 } },
    { { 3.672, 55 }, { 3.680, 56 }, { 3.688, 57 }, { 3.696, 58 }, { 3.704, 59 } },
    { { 3.712, 60 }, { 3.720, 61 }, { 3.728, 62 }, { 3.736, 63 }, { 3.744, 64 } },
    { { 3.752, 65 }, { 3.760, 66 }, { 3.768, 67 }, { 3.776, 68 }, { 3.784, 69 } },
    { { 3.792, 70 }, { 3.800, 71 }, { 3.810, 72 }, { 3.820, 73 }, { 3.830, 74 } },
    { { 3.840, 75 }, { 3.850, 76 }, { 3.860, 77 }, { 3.870, 78 }, { 3.880, 79 } },
    { { 3.890, 80 }, { 3.900, 81 }, { 3.910, 82 }, { 3.920, 83 }, { 3.930, 84 } },
    { { 3.940, 85 }, { 3.950, 86 }, { 3.960, 87 }, { 3.970, 88 }, { 3.980, 89 } },
    { { 3.990, 90 }, { 4.000, 91 }, { 4.010, 92 }, { 4.030, 93 }, { 4.050, 94 } },
    { { 4.070, 95 }, { 4.090, 96 } },
    { { 4.10, 100}, { 4.15,100 }, { 4.20, 100} },
}

local defaultSensor = "RxBt" -- RxBt / A1 / A3/ VFAS / Batt

--------------------------------------------------------------
local function log(s)
    print("BattAnalog: " .. s)
end
--------------------------------------------------------------

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options
    wgt.periodic1 = wgt.tools.periodicInit()
    wgt.cell_detected = false

    -- use default if user did not set, So widget is operational on "select widget"
    if wgt.options.Sensor == 0 then
        wgt.options.Sensor = defaultSensor
    end

    wgt.options.source_name = ""
    if (type(wgt.options.Sensor) == "number") then
        local source_name = getSourceName(wgt.options.Sensor)
        if (source_name ~= nil) then
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            log(string.format("source_name: %s", source_name))
            wgt.options.source_name = source_name
        end
    else
        wgt.options.source_name = wgt.options.Sensor
    end

    wgt.options.Show_Total_Voltage = wgt.options.Show_Total_Voltage % 2 -- modulo due to bug that cause the value to be other than 0|1

    log(string.format("wgt.options.Lithium_Ion: %s", wgt.options.Lithium_Ion))
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        counter = 0,
        text_color = 0,

        telemResetCount = 0,
        telemResetLowestMinRSSI = 101,
        no_telem_blink = 0,
        isDataAvailable = 0,
        vMax = 0,
        vMin = 0,
        vTotalLive = 0,
        vPercent = 0,
        cellCount = 1,
        cell_detected = false,
        vCellLive = 0,
        mainValue = 0,
        secondaryValue = 0
    }

    -- imports
    wgt.ToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
    wgt.tools = wgt.ToolsClass(app_name)

    update(wgt, options)
    return wgt
end

-- clear old telemetry data upon reset event
local function onTelemetryResetEvent(wgt)
    log("telemetry reset event detected.")
    wgt.telemResetCount = wgt.telemResetCount + 1

    wgt.vTotalLive = 0
    wgt.vCellLive = 0
    wgt.vMin = 99
    wgt.vMax = 0
    wgt.cellCount = 1
    wgt.cell_detected = false
    --wgt.tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
end

--- This function return the percentage remaining in a single Lipo cel
local function getCellPercent(wgt, cellValue)
    if cellValue == nil then
        return 0
    end

    -- in case somehow voltage is higher, don't return nil
    if (cellValue > 4.2) then
        return 100
    end

    local _percentListSplit = _lipoPercentListSplit
    if wgt.options.Lithium_Ion == 1 then
        _percentListSplit = _liionPercentListSplit
    end

    for i1, v1 in ipairs(_percentListSplit) do
        --log(string.format("sub-list#: %s, head:%f, length: %d, last: %.3f", i1,v1[1][1], #v1, v1[#v1][1]))
        --is the cellVal < last-value-on-sub-list? (first-val:v1[1], last-val:v1[#v1])
        if (cellValue <= v1[#v1][1]) then
            -- cellVal is in this sub-list, find the exact value
            --log("this is the list")
            for i2, v2 in ipairs(v1) do
                --log(string.format("cell#: %s, %.3f--> %d%%", i2,v2[1], v2[2]))
                if v2[1] >= cellValue then
                    result = v2[2]
                    --log(string.format("result: %d%%", result))
                    --cpuProfilerAdd(wgt, 'cell-perc', t4);
                    return result
                end
            end
        end
    end

    --for i, v in ipairs(_percentListSplit) do
    --  if v[1] >= cellValue then
    --    result = v[2]
    --    break
    --  end
    --end
    return result
end

-- Only invoke this function once.
local function calcCellCount(wgt, singleVoltage)
    if singleVoltage     < 4.3  then return 1
    elseif singleVoltage < 8.6  then return 2
    elseif singleVoltage < 12.9 then return 3
    elseif singleVoltage < 17.2 then return 4
    elseif singleVoltage < 21.5 then return 5
    elseif singleVoltage < 25.8 then return 6
    elseif singleVoltage < 30.1 then return 7
    elseif singleVoltage < 34.4 then return 8
    elseif singleVoltage < 38.7 then return 9
    elseif singleVoltage < 43.0 then return 10
    elseif singleVoltage < 47.3 then return 11
    elseif singleVoltage < 51.6 then return 12
    end

    log("no match found" .. singleVoltage)
    return 1
end


--- This function returns a table with cels values
local function calculateBatteryData(wgt)

    local v = getValue(wgt.options.Sensor)
    local fieldinfo = getFieldInfo(wgt.options.Sensor)
    log("wgt.options.Sensor: " .. wgt.options.Sensor)

    if type(v) == "table" then
        -- multi cell values using FLVSS liPo Voltage Sensor
        if (#v > 1) then
            wgt.isDataAvailable = false
            local txt = "FLVSS liPo Voltage Sensor, not supported"
            log(txt)
            return
        end
    elseif v ~= nil and v >= 1 then
        -- single cell or VFAS lipo sensor
        if fieldinfo then
            log(wgt.options.source_name .. ", value: " .. fieldinfo.name .. "=" .. v)
        else
            log("only one cell using Ax lipo sensor")
        end
    else
        -- no telemetry available
        wgt.isDataAvailable = false
        if fieldinfo then
            log("no telemetry data: " .. fieldinfo['name'] .. "=??")
        else
            log("no telemetry data")
        end
        return
    end

    if (wgt.cell_detected == true) then
        log("permanent cellCount: " .. wgt.cellCount)
    else
        local newCellCount = calcCellCount(wgt, v)
        if (wgt.tools.periodicHasPassed(wgt.periodic1)) then
            wgt.cell_detected = true
            wgt.cellCount = newCellCount
        else
            local duration_passed = wgt.tools.periodicGetElapsedTime(wgt.periodic1)
            log(string.format("detecting cells: %ss, %d/%d msec", newCellCount, duration_passed, wgt.tools.getDurationMili(wgt.periodic1)))

            -- this is necessary for simu where cell-count can change
            if newCellCount ~= wgt.cellCount then
                wgt.vMin = 99
                wgt.vMax = 0
            end
            wgt.cellCount = newCellCount
        end
    end

    -- calc highest of all cells
    if v > wgt.vMax then
        wgt.vMax = v
    end

    wgt.vTotalLive = v
    wgt.vCellLive = wgt.vTotalLive / wgt.cellCount
    wgt.vPercent = getCellPercent(wgt, wgt.vCellLive)

    -- log("wgt.vCellLive: ".. wgt.vCellLive)
    -- log("wgt.vPercent: ".. wgt.vPercent)

    -- mainValue
    if wgt.options.Show_Total_Voltage == 0 then
        wgt.mainValue = wgt.vCellLive
        wgt.secondaryValue = wgt.vTotalLive
    elseif wgt.options.Show_Total_Voltage == 1 then
        wgt.mainValue = wgt.vTotalLive
        wgt.secondaryValue = wgt.vCellLive
    else
        wgt.mainValue = "-1"
        wgt.secondaryValue = "-2"
    end

    --- calc lowest main voltage
    if wgt.mainValue < wgt.vMin and wgt.mainValue > 1 then
        -- min 1v to consider a valid reading
        wgt.vMin = wgt.mainValue
    end

    wgt.isDataAvailable = true
    if wgt.cell_detected == true then
        wgt.tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
    end


end


-- color for battery
-- This function returns green at 100%, red bellow 30% and graduate in between
local function getPercentColor(percent)
    if percent < 30 then
        return lcd.RGB(0xff, 0, 0)
    else
        g = math.floor(0xdf * percent / 100)
        r = 0xdf - g
        return lcd.RGB(r, g, 0)
    end
end

-- color for cell
-- This function returns green at gvalue, red at rvalue and graduate in between
local function getRangeColor(value, green_value, red_value)
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

local function drawBattery(wgt, myBatt)
    -- fill batt
    local fill_color = getPercentColor(wgt.vPercent)
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h - math.floor(wgt.vPercent / 100 * (myBatt.h - myBatt.cath_h)), myBatt.w, math.floor(wgt.vPercent / 100 * (myBatt.h - myBatt.cath_h)), fill_color)

    -- draw battery segments
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h - myBatt.cath_h, WHITE, 2)
    for i = 1, myBatt.h - myBatt.cath_h - myBatt.segments_h, myBatt.segments_h do
        lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h + i, myBatt.w, myBatt.segments_h, WHITE, 1)
    end

    -- draw plus terminal
    local tw = 4
    local th = 4
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2 + tw / 2, wgt.zone.y + myBatt.y, myBatt.cath_w - tw, myBatt.cath_h, WHITE)
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2, wgt.zone.y + myBatt.y + th, myBatt.cath_w, myBatt.cath_h - th, WHITE)
    --lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.0f%%", wgt.vPercent), LEFT + MIDSIZE + wgt.text_color)
    --lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.1fV", wgt.mainValue), LEFT + MIDSIZE + wgt.text_color)
end

--- Zone size: 70x39 top bar
local function refreshZoneTiny(wgt)
    local myString = string.format("%2.2fV", wgt.mainValue)

    -- write text
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 5, wgt.vPercent .. "%", RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 20, myString, RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

    -- draw battery
    local batt_color = wgt.options.Color
    lcd.drawRectangle(wgt.zone.x + 50, wgt.zone.y + 9, 16, 25, batt_color, 2)
    lcd.drawFilledRectangle(wgt.zone.x + 50 + 4, wgt.zone.y + 7, 6, 3, batt_color)
    local rect_h = math.floor(25 * wgt.vPercent / 100)
    lcd.drawFilledRectangle(wgt.zone.x + 50, wgt.zone.y + 9 + 25 - rect_h, 16, rect_h, batt_color + wgt.no_telem_blink)
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
    local myBatt = { ["x"] = 5, ["y"] = 5, ["w"] = wgt.zone.w - 10, ["h"] = wgt.zone.h - 9, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

    -- fill battery
    local fill_color = getPercentColor(wgt.vPercent)
    lcd.drawGauge(myBatt.x, myBatt.y, myBatt.w, myBatt.h, wgt.vPercent, 100, fill_color)

    -- draw battery
    lcd.drawRectangle(myBatt.x, myBatt.y, myBatt.w, myBatt.h, WHITE, 2)

    -- write text
    local topLine = string.format(" %2.2f V     %2.0f %%", wgt.mainValue, wgt.vPercent)
    lcd.drawText(myBatt.x + 15, myBatt.y + 1, topLine, MIDSIZE + wgt.text_color + wgt.no_telem_blink)
end

--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
    local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 50, ["h"] = wgt.zone.h, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 26, ["cath_h"] = 10, ["segments_h"] = 16 }

    -- draw values
    lcd.drawText(wgt.zone.x + myBatt.w + 10, wgt.zone.y, string.format("%2.2f V", wgt.mainValue), DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + myBatt.w + 12, wgt.zone.y + 30, string.format("%2.0f %%", wgt.vPercent), MIDSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + wgt.zone.w - 5, wgt.zone.y + wgt.zone.h - 55, wgt.options.source_name, RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    if wgt.options.Show_Total_Voltage == 0 then
        lcd.drawText(wgt.zone.x + wgt.zone.w - 5, wgt.zone.y + wgt.zone.h - 35, string.format("%2.2fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    else
        --lcd.drawText(wgt.zone.x, wgt.zone.y + 40, string.format("%2.2fV", wgt.mainValue), DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    end
    lcd.drawText(wgt.zone.x + wgt.zone.w - 5, wgt.zone.y + wgt.zone.h - 20, string.format("Min %2.2fV", wgt.vMin), RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

    -- more info if 1/4 is high enough (without trim & slider)
    if wgt.zone.h > 80 then
    end

    drawBattery(wgt, myBatt)
end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
    local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 76, ["h"] = wgt.zone.h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 10, string.format("%2.2f V", wgt.mainValue), RIGHT + DBLSIZE + wgt.text_color)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 40, wgt.vPercent .. " %", RIGHT + DBLSIZE + wgt.text_color)

    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 53, wgt.options.source_name, RIGHT + SMLSIZE + wgt.text_color)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 35, string.format("%2.2fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 20, string.format("min %2.2fV", wgt.vMin), RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

    drawBattery(wgt, myBatt)

end

--- Zone size: 390x172 1/1
--- Zone size: 460x252 1/1 (no sliders/trim/topbar)
local function refreshZoneXLarge(wgt)
    local x = wgt.zone.x
    local w = wgt.zone.w
    local y = wgt.zone.y
    local h = wgt.zone.h

    local myBatt = { ["x"] = 10, ["y"] = 0, ["w"] = 80, ["h"] = h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    -- draw right text section
    --lcd.drawText(x + w, y + myBatt.y + 0, string.format("%2.2f V    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    --lcd.drawText(x + w, y + myBatt.y +  0, string.format("%2.2f V", wgt.mainValue), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 150, y + myBatt.y + 0, string.format("%2.2f V", wgt.mainValue), XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 150, y + myBatt.y + 70, wgt.options.source_name, DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + myBatt.y + 80, string.format("%2.0f%%", wgt.vPercent), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + h - 60, string.format("%2.2fV    %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + h - 30, string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    drawBattery(wgt, myBatt)
    return
end

--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(wgt, event, touchState)
    if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
        lcd.exitFullScreen()
    end

    local x = 0
    local y = 0
    local w = LCD_W
    local h = LCD_H - 20

    local myBatt = { ["x"] = 10, ["y"] = 10, ["w"] = 90, ["h"] = h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    if (event ~= nil) then
        log("event: " .. event)
    end

    -- draw right text section
    --lcd.drawText(x + w - 20, y + myBatt.y + 0, string.format("%2.2f V    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 0, wgt.options.source_name, DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 30, string.format("%2.2f V", wgt.mainValue), XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 90, string.format("%2.0f %%", wgt.vPercent), XXLSIZE + wgt.text_color + wgt.no_telem_blink)

    lcd.drawText(x + w - 20, y + h - 90, string.format("%2.2fV", wgt.secondaryValue), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w - 20, y + h - 60, string.format("%dS", wgt.cellCount), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w - 20, y + h - 30, string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)

    drawBattery(wgt, myBatt)
    return
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
    if (wgt == nil) then return end

    wgt.tools.detectResetEvent(wgt, onTelemetryResetEvent)

    calculateBatteryData(wgt)
end

local function refresh(wgt, event, touchState)

    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end
    if (wgt.options.Show_Total_Voltage == nil) then return end

    background(wgt)

    if wgt.isDataAvailable then
        wgt.no_telem_blink = 0
        wgt.text_color = wgt.options.Color
    else
        wgt.no_telem_blink = INVERS + BLINK
        wgt.text_color = GREY
    end

    if (event ~= nil) then
        refreshAppMode(wgt, event, touchState)
        return
    end

    if     wgt.zone.w > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
    elseif wgt.zone.w > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
    elseif wgt.zone.w > 170 and wgt.zone.h >  65 then refreshZoneMedium(wgt)
    elseif wgt.zone.w > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
    elseif wgt.zone.w >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
    end

end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }

---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for RadioMaster TX16S                         #
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

-- Widget to display the levels of lipo/li-ion battery with indication of each cell (FLVSS)
-- 3djc & Offer Shmuely
-- Date: 2022
local app_name = "BattCheck"
local app_ver = "0.9"

local lib_sensors = loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "tcd")(m_log,app_name)
local DEFAULT_SOURCE = lib_sensors.findSourceId( {"Cels"})

local _options = {
    { "Sensor"      , SOURCE, DEFAULT_SOURCE }, -- default to 'Cels'
    { "Color"       , COLOR , YELLOW },
    { "Shadow"      , BOOL  , 0      },
    { "LowestCell"  , BOOL  , 1      }, -- 0=main voltage display shows all-cell-voltage, 1=main voltage display shows lowest-cell
    { "Lithium_Ion" , BOOL  , 0      }, -- 0=LIPO battery, 1=LI-ION (18650/21500)
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

--------------------------------------------------------------
local function log(s)
  --print("BattCheck: " .. s)
end
--------------------------------------------------------------

--periodic1 = {startTime = -1, durationMili = -1},
local function periodicInit(t, durationMili)
    t.startTime = getTime();
    t.durationMili = durationMili;
end
local function periodicReset(t)
    t.startTime = getTime();
end
local function periodicHasPassed(t)
    local elapsed = getTime() - t.startTime;
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
--------------------------------------------------------------
local function cpuProfilerAdd(wgt, name, u1)
    --return;
    local timeSpan = getUsage() - u1
    local oldValues = wgt.profTimes[name];
    if oldValues == nil then
        oldValues = { 0, 0, 0, 0 } -- count, total-time, last-time, max-time
    end

    local max = oldValues[4]
    if (timeSpan > oldValues[4]) then
        max = timeSpan
    end

    wgt.profTimes[name] = { oldValues[1] + 1, oldValues[2] + timeSpan, timeSpan, max }; -- count, total-time, last-time, max-time
end
local function cpuProfilerShow(wgt)
    --return;
    if (periodicHasPassed(wgt.periodicProfiler)) then
        local s = "profiler: \n"
        for name, valArr in pairs(wgt.profTimes) do
            s = s .. string.format("  /%-15s - avg:%02.1f, max:%2d%%, last:%2d%% (count:%5s, tot:%5s)\n", name, valArr[2] / valArr[1], valArr[4], valArr[3], valArr[1], valArr[2])
        end
        log(s);
        periodicReset(wgt.periodicProfiler)
    end
end
-----------------------------------------------------------------

local function update(wgt, options)
    if (wgt == nil) then return end

    wgt.options = options

    -- use default if user did not set, So widget is operational on "select widget"
    if wgt.options.Sensor == 0 then
        wgt.options.Sensor = "Cels"
    end

    wgt.options.LowestCell = wgt.options.LowestCell % 2 -- modulo due to bug that cause the value to be other than 0|1
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        counter = 0,
        text_color = 0,
        shadowed = 0,

        telemResetCount = 0,
        telemResetLowestMinRSSI = 101,
        no_telem_blink = 0,
        isDataAvailable = 0,
        cellDataLive = { 0, 0, 0, 0, 0, 0, 0, 0 },
        cellDataLivePercent = { 0, 0, 0, 0, 0, 0, 0, 0 },
        cellDataHistoryLowest = { 5, 5, 5, 5, 5, 5, 5, 5 },
        cellDataHistoryLowestPercent = { 5, 5, 5, 5, 5, 5, 5, 5 },
        cellDataHistoryCellLowest = 5,
        cellMax = 0,
        cellMin = 0,
        cellAvg = 0,
        cellPercent = 0,
        cellCount = 0,
        cellSum = 0,
        mainValue = 0,
        secondaryValue = 0,
        periodic1 = { startTime = getTime(), durationMili = 1000 },
        periodicProfiler = { startTime = getTime(), durationMili = 5000 },
        profTimes = {},
    }

    update(wgt, options)
    return wgt
end


-- clear old telemetry data upon reset event
local function onTelemetryResetEvent(wgt)
    wgt.telemResetCount = wgt.telemResetCount + 1

    wgt.cellDataLive = { 0, 0, 0, 0, 0, 0, 0, 0 }
    wgt.cellDataLivePercent = { 0, 0, 0, 0, 0, 0, 0, 0 }
    wgt.cellDataHistoryLowest = { 5, 5, 5, 5, 5, 5, 5, 5 }
    wgt.cellDataHistoryLowestPercent = { 5, 5, 5, 5, 5, 5, 5, 5 }
    wgt.cellDataHistoryCellLowest = 5
end


-- workaround to detect telemetry-reset event, until a proper implementation on the lua interface will be created
-- this workaround assume that:
--   RSSI- is always going down
--   RSSI- is reset on the C++ side when a telemetry-reset is pressed by user
--   widget is calling this func on each refresh/background
-- on event detection, the function onTelemetryResetEvent() will be trigger
--
local function detectResetEvent(wgt)

    local currMinRSSI = getValue('RSSI-')
    if (currMinRSSI == nil) then
        return
    end
    if (currMinRSSI == wgt.telemResetLowestMinRSSI) then
        return
    end

    if (currMinRSSI < wgt.telemResetLowestMinRSSI) then
        -- rssi just got lower, record it
        wgt.telemResetLowestMinRSSI = currMinRSSI
        return
    end

    -- reset telemetry detected
    wgt.telemResetLowestMinRSSI = 101

    -- notify event
    onTelemetryResetEvent(wgt)
end

--- This function return the percentage remaining in a single Lipo cel
--- since running on long array found to be very intensive to hrous cpu, we are splitting the list to small lists
local function getCellPercent(wgt, cellValue)
    if cellValue == nil then
        return 0
    end
    local result = 0;
    local t4 = getUsage();

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
    -- in case somehow voltage is too high (>4.2), don't return nil
    return 100
end

--- This function returns a table with cels values
local function calculateBatteryData(wgt)

    local newCellData = getValue(wgt.options.Sensor)

    if type(newCellData) ~= "table" then
        wgt.isDataAvailable = false
        return
    end

    local cellMax = 0
    local cellMin = 5
    local cellSum = 0
    for k, v in pairs(newCellData) do
        -- stores the lowest cell values in historical table
        if v > 1 and v < wgt.cellDataHistoryLowest[k] then
            -- min 1v to consider a valid reading
            wgt.cellDataHistoryLowest[k] = v

            --- calc history lowest of all cells
            if v < wgt.cellDataHistoryCellLowest then
                wgt.cellDataHistoryCellLowest = v
            end
        end

        -- calc highest of all cells
        if v > cellMax then
            cellMax = v
        end

        --- calc lowest of all cells
        if v < cellMin and v > 1 then
            -- min 1v to consider a valid reading
            cellMin = v
        end
        --- sum of all cells
        cellSum = cellSum + v


    end

    wgt.cellMin = cellMin
    wgt.cellMax = cellMax
    wgt.cellCount = #newCellData
    wgt.cellSum = cellSum

    --- average of all cells
    wgt.cellAvg = wgt.cellSum / wgt.cellCount

    wgt.cellDataLive = newCellData

    -- mainValue
    if wgt.options.LowestCell == 1 then
        wgt.mainValue = wgt.cellMin
    elseif wgt.options.LowestCell == 0 then
        wgt.mainValue = wgt.cellSum
    else
        wgt.mainValue = "-1"
    end

    -- secondaryValue
    if wgt.options.LowestCell == 1 then
        wgt.secondaryValue = wgt.cellSum
    elseif wgt.options.LowestCell == 0 then
        wgt.secondaryValue = wgt.cellMin
    else
        wgt.secondaryValue = "-2"
    end

    wgt.isDataAvailable = true

    -- calculate intensive CPU data
    if (periodicHasPassed(wgt.periodic1) or wgt.cellPercent == 0) then
        local t5 = getUsage();

        wgt.cellPercent = getCellPercent(wgt, wgt.cellMin) -- use batt percentage by lowest cell voltage
        --wgt.cellPercent = getCellPercent(wgt, wgt.cellAvg) -- use batt percentage by average cell voltage

        for i = 1, wgt.cellCount, 1 do
            wgt.cellDataLivePercent[i] = getCellPercent(wgt, wgt.cellDataLive[i])
            wgt.cellDataHistoryLowestPercent[i] = getCellPercent(wgt, wgt.cellDataHistoryLowest[i])
            -- wgt.cellDataLivePercent[i] = 100
            -- wgt.cellDataHistoryLowestPercent[i] = 0
        end

        periodicReset(wgt.periodic1)
        --cpuProfilerAdd(wgt, 'calc-batt-perc', t5);
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

--- Zone size: 70x39 top bar
local function refreshZoneTiny(wgt)
    local myString = string.format("%2.2fV", wgt.mainValue)
    -- write text
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 5, wgt.cellPercent .. "%", RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 20, myString, RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

    -- draw battery
    local batt_color = wgt.options.Color
    lcd.drawRectangle(wgt.zone.x + 50, wgt.zone.y + 9, 16, 25, batt_color, 2)
    lcd.drawFilledRectangle(wgt.zone.x + 50 + 4, wgt.zone.y + 7, 6, 3, batt_color)
    local rect_h = math.floor(25 * wgt.cellPercent / 100)
    lcd.drawFilledRectangle(wgt.zone.x + 50, wgt.zone.y + 9 + 25 - rect_h, 16, rect_h, batt_color + wgt.no_telem_blink)
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
    local myBatt = { ["x"] = 5, ["y"] = 5, ["w"] = wgt.zone.w - 10, ["h"] = wgt.zone.h - 9, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

    -- fill battery
    local fill_color = getPercentColor(wgt.cellPercent)
    lcd.drawGauge(myBatt.x, myBatt.y, myBatt.w, myBatt.h, wgt.cellPercent, 100, fill_color)

    -- draw battery
    lcd.drawRectangle(myBatt.x, myBatt.y, myBatt.w, myBatt.h, WHITE, 2)

    -- write text
    local topLine = string.format("%2.2fV   %2.0f%%", wgt.mainValue, wgt.cellPercent)
    lcd.drawText(myBatt.x + 15, myBatt.y + 1, topLine, MIDSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)
end

--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
    local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 85, ["h"] = 35, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

    -- draw values
    lcd.drawText(wgt.zone.x, wgt.zone.y + 35, string.format("%2.2fV", wgt.mainValue), DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

    -- more info if 1/4 is high enough (depend on  trim & slider)
    if wgt.zone.h > 80 then
        lcd.drawText(wgt.zone.x, wgt.zone.y + 65, string.format("Min %2.2fV", wgt.cellDataHistoryCellLowest), SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    end
    if wgt.zone.h > 85 then
        lcd.drawText(wgt.zone.x, wgt.zone.y + 79, string.format("dV %2.2fV", wgt.cellMax - wgt.cellMin), SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    end

    -- fill battery
    local fill_color = getPercentColor(wgt.cellPercent)
    lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, wgt.cellPercent, 100, fill_color)

    -- draw cells
    local cellH = wgt.zone.h / wgt.cellCount
    if cellH > 20 then cellH = 20 end
    local cellX = 118
    local cellW = 58
    for i = 1, wgt.cellCount, 1 do
        local cellY = wgt.zone.y + (i - 1) * (cellH - 1)

        -- fill current cell
        local fill_color = getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
        --print(fill_color)
        --log(string.format("fill_color: %d", fill_color))
        --lcd.drawFilledRectangle(wgt.zone.x + cellX     , cellY, 58, cellH, fill_color)
        lcd.drawFilledRectangle(wgt.zone.x + cellX, cellY, cellW * wgt.cellDataLivePercent[i] / 100, cellH, fill_color)

        -- fill cell history min
        --lcd.setColor(fill_color, getRangeColor(wgt.cellDataHistoryLowest[i], wgt.cellMax, wgt.cellMax - 0.2))
        lcd.drawFilledRectangle(wgt.zone.x + cellX + (cellW * wgt.cellDataHistoryLowestPercent[i]) / 100 - 2, cellY, 2, cellH, BLACK)

        lcd.drawText(wgt.zone.x + cellX + 10, cellY - 1, string.format("%.2f", wgt.cellDataLive[i]), SMLSIZE + WHITE + wgt.shadowed + wgt.no_telem_blink)
        lcd.drawRectangle(wgt.zone.x + cellX, cellY, cellW, cellH, WHITE, 1)
    end

    -- draw battery
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, WHITE, 2)
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w, wgt.zone.y + myBatt.h / 2 - myBatt.cath_h / 2, myBatt.cath_w, myBatt.cath_h, WHITE)
    lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y, string.format("%2.0f%%", wgt.cellPercent), LEFT + MIDSIZE + WHITE + wgt.shadowed)

end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
    local myBatt = { ["x"] = 0, ["y"] = 18, ["w"] = 76, ["h"] = 121, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 0, string.format("%2.2fV", wgt.mainValue), RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 30, wgt.cellPercent .. "%", RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 70, string.format("%2.2fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color + wgt.shadowed)

    -- fill battery
    local fill_color = getPercentColor(wgt.cellPercent)
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h + myBatt.cath_h - math.floor(wgt.cellPercent / 100 * myBatt.h), myBatt.w, math.floor(wgt.cellPercent / 100 * myBatt.h), fill_color)
    -- draw cells
    local pos = { { x = 80, y = 90 }, { x = 138, y = 90 }, { x = 80, y = 109 }, { x = 138, y = 109 }, { x = 80, y = 128 }, { x = 138, y = 128 }, { x = 80, y = 147 }, { x = 138, y = 147 } }
    for i = 1, wgt.cellCount, 1 do
        local fill_color = getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
        print(fill_color)
        log(string.format("fill_color: %d", fill_color))
        lcd.drawFilledRectangle(wgt.zone.x + pos[i].x, wgt.zone.y + pos[i].y, 58, 20, fill_color)

        lcd.drawText(wgt.zone.x + pos[i].x + 10, wgt.zone.y + pos[i].y, string.format("%.2f", wgt.cellDataLive[i]), WHITE + wgt.shadowed)
        lcd.drawRectangle(wgt.zone.x + pos[i].x, wgt.zone.y + pos[i].y, 59, 20, WHITE, 1)
    end

    -- draw battery
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h, WHITE, 2)
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2, wgt.zone.y + myBatt.y, myBatt.cath_w, myBatt.cath_h, WHITE)
    for i = 1, myBatt.h - myBatt.segments_h, myBatt.segments_h do
        lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h + i, myBatt.w, myBatt.segments_h, WHITE, 1)
    end

end

local function refreshImpl(wgt, x, w, y, h)

    local myBatt = { ["x"] = 10, ["y"] = 20, ["w"] = 80, ["h"] = 121, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    -- fill battery
    local fill_color = getPercentColor(wgt.cellPercent)
    lcd.drawFilledRectangle(x + myBatt.x, y + myBatt.y + myBatt.h + myBatt.cath_h - math.floor(wgt.cellPercent / 100 * myBatt.h), myBatt.w, math.floor(wgt.cellPercent / 100 * myBatt.h), fill_color)

    -- draw right text section
    lcd.drawText(x + w, y + myBatt.y + 0, string.format("%2.2fV", wgt.mainValue), RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)
    lcd.drawText(x + w, y + myBatt.y + 30, wgt.cellPercent .. "%", RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)
    lcd.drawText(x + w, y + myBatt.y + 105, string.format("%2.2fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

    -- draw cells
    local pos = { { x = 111, y = 38 }, { x = 164, y = 38 }, { x = 217, y = 38 }, { x = 111, y = 57 }, { x = 164, y = 57 }, { x = 217, y = 57 }, { x = 111, y = 77 }, { x = 164, y = 77 } }
    for i = 1, wgt.cellCount, 1 do
        local cell_color = getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
        lcd.drawFilledRectangle(x + pos[i].x, y + pos[i].y, 53, 20, cell_color)
        lcd.drawText(x + pos[i].x + 10, y + pos[i].y, string.format("%.2f", wgt.cellDataLive[i]), WHITE + wgt.shadowed + wgt.no_telem_blink)
        lcd.drawRectangle(x + pos[i].x, y + pos[i].y, 54, 20, WHITE, 1)
    end
    -- draw cells for lowest cells
    local pos = { { x = 111, y = 120 }, { x = 164, y = 120 }, { x = 217, y = 120 }, { x = 111, y = 139 }, { x = 164, y = 139 }, { x = 217, y = 139 }, { x = 111, y = 159 }, { x = 164, y = 159 } }
    for i = 1, wgt.cellCount, 1 do
        local cell_color = getRangeColor(wgt.cellDataHistoryLowest[i], wgt.cellDataLive[i], wgt.cellDataLive[i] - 0.3)
        lcd.drawFilledRectangle(x + pos[i].x, y + pos[i].y, 53, 20, cell_color)

        lcd.drawRectangle(x + pos[i].x, y + pos[i].y, 54, 20, WHITE, 1)
        lcd.drawText(x + pos[i].x + 10, y + pos[i].y, string.format("%.2f", wgt.cellDataHistoryLowest[i]), WHITE + wgt.shadowed + wgt.no_telem_blink)
    end

    -- draws battery
    lcd.drawRectangle(x + myBatt.x, y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h, WHITE, 2)
    lcd.drawFilledRectangle(x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2, y + myBatt.y, myBatt.cath_w, myBatt.cath_h, WHITE)
    for i = 1, myBatt.h - myBatt.segments_h, myBatt.segments_h do
        lcd.drawRectangle(x + myBatt.x, y + myBatt.y + myBatt.cath_h + i, myBatt.w, myBatt.segments_h, WHITE, 1)
    end
    -- draw middle rectangles
    lcd.drawRectangle(x + 110, y + 38, 161, 40, WHITE, 1)
    lcd.drawText(x + 220, y + 21, "Live data", RIGHT + SMLSIZE + INVERS + WHITE + wgt.shadowed)
    lcd.drawRectangle(x + 110, y + 120, 161, 40, WHITE, 1)
    lcd.drawText(x + 230, y + 103, "Lowest data", RIGHT + SMLSIZE + INVERS + WHITE + wgt.shadowed)
    return
end

--- Zone size: 390x172 1/1
--- Zone size: 460x252 1/1 (no sliders/trim/topbar)
local function refreshZoneXLarge(wgt)
    local x = wgt.zone.x
    local w = wgt.zone.w
    local y = wgt.zone.y
    local h = wgt.zone.h

    refreshImpl(wgt, x, w, y, h)
end

--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(wgt, event, touchState)
    if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
        lcd.exitFullScreen()
    end

    local x = 0
    local w = 460
    local y = 0
    local h = 252
    refreshImpl(wgt, x, w, y, h)
end


-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
    if (wgt == nil) then return end
    local t1 = getUsage();

    detectResetEvent(wgt)

    calculateBatteryData(wgt)

    --cpuProfilerAdd(wgt, 'background-loop', t1);
    --cpuProfilerShow(wgt);
end

local function refresh(wgt, event, touchState)
    local t1 = getUsage();
    if (wgt         == nil) then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone    == nil) then return end
    if (wgt.options.LowestCell == nil) then return end

    if wgt.options.Shadow == 1 then
        wgt.shadowed = SHADOWED
    else
        wgt.shadowed = 0
    end

    detectResetEvent(wgt)

    local t3 = getUsage();
    calculateBatteryData(wgt)
    --cpuProfilerAdd(wgt, 'main-loop-3', t3);

    if wgt.isDataAvailable then
        wgt.no_telem_blink = 0
        wgt.text_color = wgt.options.Color
    else
        wgt.no_telem_blink = INVERS + BLINK
        wgt.text_color = GREY
    end

    local t4 = getUsage();
    if (event ~= nil) then
      refreshAppMode(wgt, event, touchState)
    elseif wgt.zone.w > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
    elseif wgt.zone.w > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
    elseif wgt.zone.w > 170 and wgt.zone.h >  65 then refreshZoneMedium(wgt)
    elseif wgt.zone.w > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
    elseif wgt.zone.w >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
    end
  --cpuProfilerAdd(wgt, 'main-loop-4', t4);

    --cpuProfilerAdd(wgt, 'main-loop', t1);
    --cpuProfilerShow(wgt);
    --lcd.drawText(wgt.zone.x, wgt.zone.y, string.format("r:%d", wgt.telemResetCount), SMLSIZE + wgt.text_color)
    --lcd.drawText(wgt.zone.x+100, wgt.zone.y, string.format("%d%%", getUsage()), SMLSIZE + wgt.text_color)
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }

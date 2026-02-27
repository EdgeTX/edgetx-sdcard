--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for RadioMaster TX16S                         #
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


-- This widget display a graphical representation of a Lipo/Li-ion/LIHV (not other types) battery level,
-- it will automatically detect the cell amount of the battery.
-- it will take a lipo/li-ion voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * expressLRS pwm receivers (ER6/ER8/SuperP14ch)
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli

]]

-- Widget to display the levels of Lipo battery from single analog source
-- Author : Offer Shmuely
-- Date: 2021-2026
local app_name = "BattAnalog"
local app_ver = "1.9"

-- table.insert(package.searchers or package.loaders, function(filepath)
table.insert(package.searchers, function(filepath)
    local f = loadScript(filepath, "btd")
    if f == nil then
        return "\n--not on SD card: [" .. filepath .. "]--"
    end
    return function() return f end
end)

-- local m_log = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "btd")(app_name, "/WIDGETS/" .. app_name)
-- local wgt   = loadScript("/WIDGETS/" .. app_name .. "/logic.lua", "btd")(m_log)
-- local tools = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "btd")(m_log, app_name, true)
local m_log = require("/WIDGETS/" .. app_name .. "/lib_log.lua", "btd")(app_name, "/WIDGETS/" .. app_name)
-- local wgt   = require("/WIDGETS/" .. app_name .. "/logic.lua", "btd")(m_log)
local tools = require("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "btd")(m_log, app_name, true)

local CELL_DETECTION_TIME = 8
local lvSCALE = lvgl.LCD_SCALE or 1

-- data gathered from commercial lipo sensors
local percent_list_lipo = {
    {3.000,  0},
    {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10},
    {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20},
    {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30},
    {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40},
    {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.840, 46}, {3.843, 47}, {3.847, 48}, {3.850, 49}, {3.854, 50},
    {3.857, 51}, {3.860, 52}, {3.863, 53}, {3.866, 54}, {3.870, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60},
    {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70},
    {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80},
    {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90},
    {4.116, 91}, {4.120, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.200,100},
}

local percent_list_hv = {
    {3.000,  0},
    {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10},
    {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20},
    {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30},
    {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.828, 40},
    {3.832, 41}, {3.836, 42}, {3.841, 43}, {3.846, 44}, {3.850, 45}, {3.855, 46}, {3.859, 47}, {3.864, 48}, {3.868, 49}, {3.873, 50},
    {3.877, 51}, {3.881, 52}, {3.885, 53}, {3.890, 54}, {3.895, 55}, {3.900, 56}, {3.907, 57}, {3.917, 58}, {3.924, 59}, {3.929, 60},
    {3.936, 61}, {3.942, 62}, {3.949, 63}, {3.957, 64}, {3.964, 65}, {3.971, 66}, {3.984, 67}, {3.990, 68}, {3.998, 69}, {4.006, 70},
    {4.015, 71}, {4.024, 72}, {4.032, 73}, {4.042, 74}, {4.050, 75}, {4.060, 76}, {4.069, 77}, {4.078, 78}, {4.088, 79}, {4.098, 80},
    {4.109, 81}, {4.119, 82}, {4.130, 83}, {4.141, 84}, {4.154, 85}, {4.169, 86}, {4.184, 87}, {4.197, 88}, {4.211, 89}, {4.220, 90},
    {4.229, 91}, {4.237, 92}, {4.246, 93}, {4.254, 94}, {4.264, 95}, {4.278, 96}, {4.302, 97}, {4.320, 98}, {4.339, 99}, {4.350,100},
}


-- from: https://electric-scooter.guide/guides/electric-scooter-battery-voltage-chart/
local percent_list_lion = {
    { 2.800,  0 }, { 2.840,  1 }, { 2.880,  2 }, { 2.920,  3 }, { 2.960,  4 },
    { 3.000,  5 }, { 3.040,  6 }, { 3.080,  7 }, { 3.096,  8 }, { 3.112,  9 },
    { 3.128, 10 }, { 3.144, 11 }, { 3.160, 12 }, { 3.176, 13 }, { 3.192, 14 },
    { 3.208, 15 }, { 3.224, 16 }, { 3.240, 17 }, { 3.256, 18 }, { 3.272, 19 },
    { 3.288, 20 }, { 3.304, 21 }, { 3.320, 22 }, { 3.336, 23 }, { 3.352, 24 },
    { 3.368, 25 }, { 3.384, 26 }, { 3.400, 27 }, { 3.416, 28 }, { 3.432, 29 },
    { 3.448, 30 }, { 3.464, 31 }, { 3.480, 32 }, { 3.496, 33 }, { 3.504, 34 },
    { 3.512, 35 }, { 3.520, 36 }, { 3.528, 37 }, { 3.536, 38 }, { 3.544, 39 },
    { 3.552, 40 }, { 3.560, 41 }, { 3.568, 42 }, { 3.576, 43 }, { 3.584, 44 },
    { 3.592, 45 }, { 3.600, 46 }, { 3.608, 47 }, { 3.616, 48 }, { 3.624, 49 },
    { 3.632, 50 }, { 3.640, 51 }, { 3.648, 52 }, { 3.656, 53 }, { 3.664, 54 },
    { 3.672, 55 }, { 3.680, 56 }, { 3.688, 57 }, { 3.696, 58 }, { 3.704, 59 },
    { 3.712, 60 }, { 3.720, 61 }, { 3.728, 62 }, { 3.736, 63 }, { 3.744, 64 },
    { 3.752, 65 }, { 3.760, 66 }, { 3.768, 67 }, { 3.776, 68 }, { 3.784, 69 },
    { 3.792, 70 }, { 3.800, 71 }, { 3.810, 72 }, { 3.820, 73 }, { 3.830, 74 },
    { 3.840, 75 }, { 3.850, 76 }, { 3.860, 77 }, { 3.870, 78 }, { 3.880, 79 },
    { 3.890, 80 }, { 3.900, 81 }, { 3.910, 82 }, { 3.920, 83 }, { 3.930, 84 },
    { 3.940, 85 }, { 3.950, 86 }, { 3.960, 87 }, { 3.970, 88 }, { 3.980, 89 },
    { 3.990, 90 }, { 4.000, 91 }, { 4.010, 92 }, { 4.030, 93 }, { 4.050, 94 },
    { 4.070, 95 }, { 4.090, 96 }, { 4.10, 100 }, { 4.15 ,100 }, { 4.20, 100},
}

local percent_list_life_po4 = {
    {2.500,  0},
    {2.509,  1}, {2.518,  2}, {2.527,  3}, {2.536,  4}, {2.545,  5}, {2.554,  6}, {2.563,  7}, {2.572,  8}, {2.581,  9}, {2.590, 10},
    {2.599, 11}, {2.608, 12}, {2.617, 13}, {2.626, 14}, {2.635, 15}, {2.644, 16}, {2.653, 17}, {2.662, 18}, {2.671, 19}, {2.680, 20},
    {2.689, 21}, {2.698, 22}, {2.707, 23}, {2.716, 24}, {2.725, 25}, {2.734, 26}, {2.743, 27}, {2.752, 28}, {2.761, 29}, {2.770, 30},
    {2.779, 31}, {2.788, 32}, {2.797, 33}, {2.806, 34}, {2.815, 35}, {2.824, 36}, {2.833, 37}, {2.842, 38}, {2.851, 39}, {2.860, 40},
    {2.869, 41}, {2.878, 42}, {2.887, 43}, {2.896, 44}, {2.905, 45}, {2.914, 46}, {2.923, 47}, {2.932, 48}, {2.941, 49}, {2.950, 50},
    {2.959, 51}, {2.968, 52}, {2.977, 53}, {2.986, 54}, {2.995, 55}, {3.004, 56}, {3.013, 57}, {3.022, 58}, {3.031, 59}, {3.040, 60},
    {3.049, 61}, {3.058, 62}, {3.067, 63}, {3.076, 64}, {3.085, 65}, {3.094, 66}, {3.103, 67}, {3.112, 68}, {3.121, 69}, {3.130, 70},
    {3.139, 71}, {3.148, 72}, {3.157, 73}, {3.166, 74}, {3.175, 75}, {3.184, 76}, {3.193, 77}, {3.202, 78}, {3.211, 79}, {3.220, 80},
    {3.229, 81}, {3.238, 82}, {3.247, 83}, {3.256, 84}, {3.265, 85}, {3.274, 86}, {3.283, 87}, {3.292, 88}, {3.301, 89}, {3.310, 90},
    {3.319, 91}, {3.328, 92}, {3.337, 93}, {3.346, 94}, {3.355, 95}, {3.364, 96}, {3.373, 97}, {3.382, 98}, {3.391, 99}, {3.400,100},
}

local topCellVoltage_lipo = 4.30
local topCellVoltage_hv   = 4.45
local topCellVoltage_lion = 4.30
local topCellVoltage_life_po4 = 3.50 -- auto calculation will work up to 3 cell only

local function log(fmt, ...)
    m_log.info(fmt, ...)
end
--------------------------------------------------------------

local function update_logic(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.periodic1 = tools.periodicInit()
    wgt.cell_detected = false

    if (wgt.options.cbCellCount == 1) then
        wgt.autoCellDetection = true
    else
        wgt.autoCellDetection = false
        wgt.cellCount = wgt.options.cbCellCount - 1
    end
    log("cbCellCount: %s, autoCellDetection: %s, cellCount: %s", wgt.options.cbCellCount, wgt.autoCellDetection, wgt.cellCount)

    wgt.source_name = ""
    if (type(wgt.options.sensor) == "number") then
        local source_name = getSourceName(wgt.options.sensor)
        if (source_name ~= nil) then
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            -- log(string.format("source_name: %s", source_name))
            wgt.source_name = source_name
        end
    else
        wgt.source_name = wgt.options.sensor
    end

    -- wgt.options.isTotalVoltage = wgt.options.isTotalVoltage % 2 -- modulo due to bug that cause the value to be other than 0|1
    if (wgt.options.cbShowVoltage == 1) then
        wgt.options.isTotalVoltage = false
    else
        wgt.options.isTotalVoltage = true
    end


    -- log("wgt.options.batt_type: %s", wgt.options.batt_type)
end

--------------------------------------------------------------

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
end

--- This function return the percentage remaining in a single Lipo cel
local function getCellPercent(wgt, cellValue)
    if cellValue == nil then
        return 0
    end

    local _percentList = percent_list_lipo
    if wgt.options.batt_type == 1 then
        _percentList = percent_list_lipo
    elseif wgt.options.batt_type == 2 then
        _percentList = percent_list_hv
    elseif wgt.options.batt_type == 3 then
        _percentList = percent_list_lion
    elseif wgt.options.batt_type == 4 then
        _percentList = percent_list_life_po4
    end

    -- if voltage too low, return 0%
    if cellValue <= _percentList[1][1] then
        return 0
    end

    -- if voltage too high, return 100%
    if cellValue >= _percentList[#_percentList][1] then
        return 100
    end

    -- binary search
    local l = 1
    local u = #_percentList
    while true do
        local n = (u + l) // 2
        if cellValue >= _percentList[n][1] and cellValue <= _percentList[n+1][1] then
            -- return closest value
            if cellValue < (_percentList[n][1] + _percentList[n + 1][1]) / 2 then
                return _percentList[n][2]
            else
                return _percentList[n+1][2]
            end
        end
        if cellValue < _percentList[n][1] then
            u = n
        else
            l = n
        end
    end

    return 0
end

local function calcCellCount(wgt, singleVoltage)
    local topCellVoltage = topCellVoltage_lipo

    if wgt.options.batt_type == 1 then
        topCellVoltage = topCellVoltage_lipo
    elseif wgt.options.batt_type == 2 then
        topCellVoltage = topCellVoltage_hv
    elseif wgt.options.batt_type == 3 then
        topCellVoltage = topCellVoltage_lion
    elseif wgt.options.batt_type == 4 then
        topCellVoltage = topCellVoltage_life_po4
    end

    for i = 1, 12 do
        -- log("calcCellCount %s <? %s", singleVoltage, topCellVoltage*i)
        if singleVoltage < topCellVoltage*i then
            -- log("calcCellCount %s --> %s", singleVoltage, i)
            return i
        end
    end

    log("no match found" .. singleVoltage)
    return 1
end

--- This function returns a table with cels values
local function calculateBatteryData(wgt)

    local v = getValue(wgt.options.sensor)
    local fieldinfo = getFieldInfo(wgt.options.sensor)
    -- log("wgt.options.sensor: " .. wgt.options.sensor)

    if type(v) == "table" then
        -- multi cell values using FLVSS liPo Voltage Sensor
        if (#v > 1) then
            wgt.isDataAvailable = false
            -- log("FLVSS liPo Voltage Sensor, not supported")
            return
        end
    elseif v ~= nil and v >= 1 then
        -- single cell or VFAS lipo sensor
        if fieldinfo then
            -- log(wgt.source_name .. ", value: " .. fieldinfo.name .. "=" .. v)
        else
            -- log("only one cell using Ax lipo sensor")
        end
    else
        -- no telemetry available
        wgt.isDataAvailable = false
        if fieldinfo then
            -- log("no telemetry data: " .. fieldinfo['name'] .. "=??")
        else
            -- log("no telemetry data")
        end
        return
    end

    if wgt.autoCellDetection == true then
        if (wgt.cell_detected == true) then
            -- log("permanent cellCount: " .. wgt.cellCount)
        else
            local newCellCount = calcCellCount(wgt, v)
            if (tools.periodicHasPassed(wgt.periodic1, false)) then
                wgt.cell_detected = true
                wgt.cellCount = newCellCount
            else
                local duration_passed = tools.periodicGetElapsedTime(wgt.periodic1, false)
                -- log(string.format("detecting cells: %ss, %d/%d msec", newCellCount, duration_passed, tools.getDurationMili(wgt.periodic1)))

                -- this is necessary for simu where cell-count can change
                if newCellCount ~= wgt.cellCount then
                    wgt.vMin = 99
                    wgt.vMax = 0
                end
                wgt.cellCount = newCellCount
            end
        end
    -- else
    --     log("cellCount:autoCellDetection=%s", wgt.autoCellDetection)
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
    if wgt.options.isTotalVoltage == false then
        wgt.mainValue = wgt.vCellLive
        wgt.secondaryValue = wgt.vTotalLive
    elseif wgt.options.isTotalVoltage == true then
        wgt.mainValue = wgt.vTotalLive
        wgt.secondaryValue = wgt.vCellLive
    else
        wgt.mainValue = "-1"
        wgt.secondaryValue = "-2"
    end

    --- calc lowest main voltage
    if wgt.mainValue > 0 and wgt.mainValue < wgt.vMin and wgt.mainValue > 1 then
        -- min 1v to consider a valid reading
        wgt.vMin = wgt.mainValue
    end

    wgt.isDataAvailable = true
    if wgt.cell_detected == true then
        tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
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
-- local function getRangeColor(value, green_value, red_value)
--     local range = math.abs(green_value - red_value)
--     if range == 0 then
--         return lcd.RGB(0, 0xdf, 0)
--     end
--     if value == nil then
--         return lcd.RGB(0, 0xdf, 0)
--     end

--     if green_value > red_value then
--         if value > green_value then
--             return lcd.RGB(0, 0xdf, 0)
--         end
--         if value < red_value then
--             return lcd.RGB(0xdf, 0, 0)
--         end
--         g = math.floor(0xdf * (value - red_value) / range)
--         r = 0xdf - g
--         return lcd.RGB(r, g, 0)
--     else
--         if value > green_value then
--             return lcd.RGB(0, 0xdf, 0)
--         end
--         if value < red_value then
--             return lcd.RGB(0xdf, 0, 0)
--         end
--         r = math.floor(0xdf * (value - green_value) / range)
--         g = 0xdf - r
--         return lcd.RGB(r, g, 0)
--     end
-- end


---------------------------------------------------------------------------------------------------




-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local space = 10

local function getFillColor(wgt)
    return getPercentColor(wgt.vPercent)
end

local function calcBattSize(wgt)
    local x = wgt.zone.x + space
    local y = wgt.zone.y + space
    local w = 0
    local h = wgt.zone.h - 2*space
    if (h > 110) then
        w = math.floor(h * 0.50)
    elseif (h > 80) then
        w = math.floor(h * 0.60)
    else
        w = math.floor(h * 0.80)
    end
    return x, y, w, h
end

local function layoutBatt(wgt)
    local bx, by , bw, bh = calcBattSize(wgt)

    -- terminal size
    local th1 = math.floor(bh*0.04)
    local th2 = math.floor(bh*0.05)
    local th = th1+th2
    local tw1 = bw / 2 * 0.8
    local tw2 = bw / 2
    local tx1 = bx + (bw - tw1) / 2
    local tx2 = bx + (bw - tw2) / 2

    -- box size
    local bbx = bx
    local bby = by + th
    local bbw = bw
    local bbh = bh - th
    local fill_space = 3

    local shd = (bh>120) and 3 or ((bh>120) and 2 or 1) -- shaddow
    local isNeedShaddow = (bh>80) and true or false

    lvgl.build({
        -- plus terminal
        {type="rectangle", x=tx1, y=bby-th   , w=tw1, h=th1*2, color=WHITE, filled=true, rounded=5},
        {type="rectangle", x=tx2, y=bby-th2  , w=tw2, h=th2  , color=WHITE, filled=true, rounded=5},
        {type="rectangle", x=tx2, y=bby-th2/2, w=tw2, h=th2/2, color=WHITE, filled=true, rounded=0},

        -- battery outline shaddow
        {type="rectangle", x=bx+2, y=bby+3, w=bbw, h=bbh, thickness=3, rounded=bw*0.1,     color=GREY, visible=function() return isNeedShaddow end},

        {type="box", x=bx, y=bby, w=bbw, h=bbh,
            children={

                -- fill batt
                {type="rectangle", filled=true, color=function() return getFillColor(wgt) end, rounded=bw*0.1,
                    pos =(function() return fill_space+1, fill_space +1 + bbh - math.floor(wgt.vPercent / 100 * bbh) end),
                    size=(function() return bbw-2*fill_space, math.floor(wgt.vPercent / 100 * bbh)-2*fill_space end)
                },

                -- battery segments shaddow
                {type="rectangle", x=1+2, y=0 + (1 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (2 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (3 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (4 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},

                -- battery segments
                {type="rectangle", x=1,   y=(1 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(2 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(3 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(4 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},

                -- battery outline
                {type="rectangle", x=0, y=0, w=bbw, h=bbh, thickness=2,color=WHITE, rounded=bw*0.1},

                -- debug area
                -- {type="label", x=tx2-10, y=bby+10, color=BLUE, font=FS.FONT_8, text=function() return string.format("round=%s", bw*0.1) end},
                -- {type="rectangle", x=bx, y=by, w=bw, h=bh,color=BLUE},
            }
        }
    })


    local batSize = {
        x = bx,
        y = by,
        w = bw,
        h = bh,
        xw = bx + bw,
        yh = by + bh,
    }
    return batSize
end

local function layoutBattHorz(parentBox, wgt, myBatt, fPercent, getPercentColor)
    local percent = fPercent(wgt)
    local r = 30
    local fill_color = myBatt.bar_color or GREEN
    local fill_color= (getPercentColor~=nil) and getPercentColor(wgt, percent) or GREEN
    local tw = 4
    local th = 4

    -- local box = lvgl.box({x=myBatt.x, y=myBatt.y})
    -- local box = lvgl.box({x=100, y=100})
    -- box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})
    -- lvgl.rectangle(box, {w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})
    -- box:rectangle({w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})

    -- local box2 = lvgl.box({x=200, y=100})
    -- lvgl.rectangle(box2, {x=0, y=0, w=30, h=30, color=BLUE, filled=false, rounded=8, thickness=2})

    local box = parentBox:box({x=myBatt.x, y=myBatt.y})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=4, thickness=8})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=WHITE, filled=false, thickness=myBatt.fence_thickness or 3, rounded=6})
    box:rectangle({x=5, y=5,
        -- w=0, h=myBatt.h,
        filled=true, rounded=4,
        size =function() return math.floor(fPercent(wgt) / 100 * myBatt.w)-10, myBatt.h-10 end,
        color=function() return getPercentColor(wgt, percent) or GREEN end,
    })
    -- draw battery segments
    -- for i=0, myBatt.w, myBatt.segments_w do
    --     box:rectangle({x=i, y=0, w=1, h=myBatt.h, color=LIGHTGREY, filled=true})
    -- end

    -- -- draw plus terminal
    -- if myBatt.cath==true then
    --     box:rectangle({ x=myBatt.w,
    --         y=myBatt.h /2 - myBatt.cath_h /2 + th /2,
    --         w=myBatt.cath_w,
    --         h=myBatt.cath_h,
    --         color=BLUE, filled=true, rounded=1,
    --         -- visible=myBatt.cath -- bug, should support bool
    --     })
    --     box:rectangle({ x=myBatt.w + tw,
    --             y=myBatt.h /2 - myBatt.cath_h /2 + th,
    --             w=myBatt.cath_w,
    --             h=myBatt.cath_h,
    --             color=RED, filled=true, rounded=1,
    --             -- visible=myBatt.cath
    --     })
    -- end

    return box
end

--- Zone size: 70x39 top bar
local function layoutZoneTopbar(wgt)
    local bx = wgt.zone.w - 20
    local by = 2
    local bw = 18
    local bh = wgt.zone.h - 4

    lvgl.clear()

    local pMain = lvgl.box({x=0, y=0})
    layoutBattHorz(pMain, wgt,
        {x=2, y=2*lvSCALE,w=wgt.zone.w-4,h=wgt.zone.h-4,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=8, segments_h=20, cath=true, fence_thickness=1},
        function(wgt) return wgt.vPercent end,
        function(wgt) return getFillColor(wgt) end
    )


    lvgl.build({
        -- battery values
        {type="label", x=10*lvSCALE, y=12, w=bx-3, font=FS.FONT_8+RIGHT,
            text=function() return string.format("%2.2fV", wgt.mainValue) end,
            -- color=(function() return (wgt.vPercent < 30) and RED or wgt.text_color end)
            color=function() return wgt.text_color end
        },
        -- {type="label", x=0, y=5, w=bx - 3, font=FS.FONT_6+RIGHT, color=function() return wgt.text_color end,
        --     text=function() return string.format("%2.0f%%", wgt.vPercent) end
        -- },

        -- -- plus terminal
        -- {type="rectangle", x=bx+4, y=by-6, w=bw-8, h=6, filled=true, color=function() return (wgt.vPercent < 30) and RED or wgt.text_color end},

        -- -- fill batt
        -- {type="rectangle", x=bx, y=by, w=bw, h=0, filled=true, color=function() return getFillColor(wgt) end,
        --     size=(function() return bw, math.floor(wgt.vPercent / 100 * (bh)) end),
        --     pos=(function() return bx, by + bh - math.floor(wgt.vPercent / 100 * (bh)) end)},

        -- -- battery outline
        -- {type="rectangle", x=bx, y=by, w=bw, h=bh, thickness=2, color=function() return (wgt.vPercent < 30) and RED or wgt.text_color end},
    })
end

local function layoutTextZoneNormal(wgt, batSize)
    local next_y = space
    local left_w = wgt.zone.w-(batSize.w +10)
    local left_h = wgt.zone.h

    local txtSizes = {
        vMain = {x=nil,y=nil, font=nil},
        percent = {},
        source = {},
        vSec = {},
        cellCount = {},
        vMin = {},
    }

    local fSizeMainV, w, h, v_offset = tools.getFontSize(wgt, "99.99V", left_w, left_h, FS.FONT_38)
    txtSizes.vMain = {x=batSize.xw +10, y=next_y +v_offset, font=fSizeMainV}

    next_y = next_y + h + 10
    left_h = wgt.zone.h - next_y

    local fSizePercent, w, h, v_offset = tools.getFontSize(wgt, "100%", left_w, left_h, fSizeMainV)
    txtSizes.percent = {x=batSize.xw +12, y=next_y +v_offset, font=fSizePercent}
    next_y = next_y + h + 10
    left_h = wgt.zone.h - next_y


    local max_w = 0
    local sec_x = LCD_W
    local sec_font = FS.FONT_16
    local sec_dh = 0
    local line_space = 5

    sec_font = tools.getFontSize(wgt, "AAA", left_w - batSize.w, left_h/3, FS.FONT_8)


    -- source
    local ts_w, ts_h, v_offset = tools.lcdSizeTextFixed(wgt.source_name, sec_font)
    sec_dh = ts_h + 5
    line_space = ts_h * 0
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.source = {y=wgt.zone.h +v_offset -space +line_space -sec_dh*3, visible=(function() return wgt.options.isTotalVoltage == false end)}


    -- vSec + cell count
    local ts_w, ts_h, v_offset = tools.lcdSizeTextFixed("99.99V  12s", sec_font)
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.vSec = {y=wgt.zone.h +v_offset  -space +line_space -sec_dh*2, visible=(function() return wgt.options.isTotalVoltage == false end)}

    -- vMin
    local ts_w, ts_h, v_offset = tools.lcdSizeTextFixed(string.format("min %2.2fV", wgt.vMin), sec_font)
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.vMin = {y=wgt.zone.h +v_offset -space +line_space -sec_dh*1, visible = false}


    lvgl.build({
        -- main value
        {type="label", x=txtSizes.vMain.x, y=txtSizes.vMain.y, font=txtSizes.vMain.font, color=function() return wgt.text_color end,
            text=function() return string.format("%2.2fV", wgt.mainValue) end,
        },
        {type="label", x=txtSizes.percent.x, y=txtSizes.percent.y, font=txtSizes.percent.font, color=function() return wgt.text_color end,
            text=function() return string.format("%2.0f%%", wgt.vPercent) end,
        },
        -- -- source name
        -- {type="label", x=sec_x, y=txtSizes.source.y, font=sec_font, text=wgt.source_name, color=getTxtColor, visible=txtSizes.source.visible},
        {type="label", x=sec_x, y=txtSizes.source.y, font=sec_font, text=wgt.source_name, color=function() return wgt.text_color end},

        -- secondary value & cells
        {type="label", x=sec_x, y=txtSizes.vSec.y, font=sec_font, color=function() return wgt.text_color end,
            text=function() return string.format("%2.2fV   %dS", wgt.secondaryValue, wgt.cellCount) end,
        },

        -- min voltage
        {type="label", x=sec_x, y=txtSizes.vMin.y, font=sec_font, color=function() return wgt.text_color end,
            text=function() return string.format("min %2.2fV", wgt.vMin) end,
        },
    })

end

local function layoutZoneNormal(wgt)
    lvgl.clear()
    local batSize = layoutBatt(wgt)
    layoutTextZoneNormal(wgt, batSize)
end

local function update(wgt, options)
    wgt.options = options
    wgt.counter = 0
    wgt.text_color = 0
    wgt.telemResetCount = 0
    wgt.telemResetLowestMinRSSI = 101
    wgt.isDataAvailable = 0
    wgt.vMax = 0
    wgt.vMin = 99
    wgt.vTotalLive = 0
    wgt.vPercent = 0
    wgt.cellCount = 1
    wgt.cell_detected = false
    wgt.autoCellDetection = nil
    wgt.vCellLive = 0
    wgt.mainValue = 0
    wgt.secondaryValue = 0
    wgt.source_name = ""

    --??? log("zone: %dx%d ----------------------------------------------", wgt.zone.w, wgt.zone.h);

    local ver, radio, maj, minor, rev, osname = getVersion()
    local nVer = maj*1000000+minor*1000+rev
    wgt.is_valid_ver = (nVer>=2011003)
    if wgt.is_valid_ver==false then
        lvgl.build({
            {type="label", x=0, y=0, font=0, color=RED, text="!! this widget \nis supported only \non ver 2.11.3 and above"}
        })
        return
    end

    update_logic(wgt, options)

    -- if wgt.zone.w <  75 and wgt.zone.h < 45 then
    if wgt.zone.h < 45*lvSCALE then
        layoutZoneTopbar(wgt)
    else
        layoutZoneNormal(wgt)
    end

end

local function create(zone, options)
    local wgt = {zone = zone, options = options}
    update(wgt, options)
    return wgt
end

local function background(wgt)
    if wgt.is_valid_ver==false then
        return
    end
    tools.detectResetEvent(wgt, onTelemetryResetEvent)
    calculateBatteryData(wgt)

    -- send sensor if needed
    if (wgt.options.isTelemCellV == 1) then
        setTelemetryValue(0x0310, 0, 1, wgt.vCellLive * 100, 1, 2, "cell")
    end

    -- if (wgt.reportSensorCellCount == true) then
    --     setTelemetryValue(0x0310, 1, 1, wgt.cellCount, 0, 0, "cel#")
    -- end

    -- if (wgt.options.isTelemCellPerc == 1) then
    --     setTelemetryValue(0x0310, 1, 1, wgt.vPercent, 13, 0, "cel%")
    -- end
end


local function refresh(wgt, event, touchState)
    background(wgt)
    wgt.text_color = (wgt.isDataAvailable) and wgt.options.color or GREY
end


return { create=create, update=update, background=background, refresh=refresh }

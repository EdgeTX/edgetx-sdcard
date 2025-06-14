
local CELL_DETECTION_TIME = 8


-- The widget table will be returned to the main script.
local wgt = {
    options = nil,
    zone = nil,
    counter = 0,
    text_color = 0,

    telemResetCount = 0,
    telemResetLowestMinRSSI = 101,
    no_telem_blink = 0,
    isDataAvailable = 0,
    vMax = 0,
    vMin = 99,
    vTotalLive = 0,
    vPercent = 0,
    cellCount = 1,
    cell_detected = false,
    autoCellDetection = nil,
    vCellLive = 0,
    mainValue = 0,
    secondaryValue = 0,

    source_name = "",
}

-- Data gathered from commercial lipo sensors
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
    wgt.log(fmt, ...)
end
--------------------------------------------------------------

function wgt.update_logic(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.periodic1 = wgt.tools.periodicInit()
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

    wgt.options.isTotalVoltage = wgt.options.isTotalVoltage % 2 -- modulo due to bug that cause the value to be other than 0|1

    -- log("wgt.options.batt_type: %s", wgt.options.batt_type)
end

--------------------------------------------------------------

-- clear old telemetry data upon reset event
function wgt.onTelemetryResetEvent(wgt)
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
function wgt.getCellPercent(cellValue)
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

local function calcCellCount(singleVoltage)
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
function wgt.calculateBatteryData()

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
            local newCellCount = calcCellCount(v)
            if (wgt.tools.periodicHasPassed(wgt.periodic1, false)) then
                wgt.cell_detected = true
                wgt.cellCount = newCellCount
            else
                local duration_passed = wgt.tools.periodicGetElapsedTime(wgt.periodic1, false)
                -- log(string.format("detecting cells: %ss, %d/%d msec", newCellCount, duration_passed, wgt.tools.getDurationMili(wgt.periodic1)))

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
    wgt.vPercent = wgt.getCellPercent(wgt.vCellLive)

    -- log("wgt.vCellLive: ".. wgt.vCellLive)
    -- log("wgt.vPercent: ".. wgt.vPercent)

    -- mainValue
    if wgt.options.isTotalVoltage == 0 then
        wgt.mainValue = wgt.vCellLive
        wgt.secondaryValue = wgt.vTotalLive
    elseif wgt.options.isTotalVoltage == 1 then
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
        wgt.tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
    end

end

-- color for battery
-- This function returns green at 100%, red bellow 30% and graduate in between
function wgt.getPercentColor(percent)
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
function wgt.getRangeColor(value, green_value, red_value)
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

function wgt.background()
    wgt.tools.detectResetEvent(wgt, wgt.onTelemetryResetEvent)
    wgt.calculateBatteryData()

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

return wgt

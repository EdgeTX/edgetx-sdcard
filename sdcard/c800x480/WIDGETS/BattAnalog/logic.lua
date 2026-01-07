

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
    vMin = 0,
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
    { {3.000,  0}},
    { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
    { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
    { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
    { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40} },
    { {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.840, 46}, {3.843, 47}, {3.847, 48}, {3.850, 49}, {3.854, 50} },
    { {3.857, 51}, {3.860, 52}, {3.863, 53}, {3.866, 54}, {3.870, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60} },
    { {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70} },
    { {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80} },
    { {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90} },
    { {4.116, 91}, {4.120, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.200,100} },
}

-- from: https://electric-scooter.guide/guides/electric-scooter-battery-voltage-chart/
local percent_list_lion = {
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

local percent_list_hv = {
    { {3.000,  0}},
    { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
    { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
    { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
    { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.828, 40} },
    { {3.832, 41}, {3.836, 42}, {3.841, 43}, {3.846, 44}, {3.850, 45}, {3.855, 46}, {3.859, 47}, {3.864, 48}, {3.868, 49}, {3.873, 50} },
    { {3.877, 51}, {3.881, 52}, {3.885, 53}, {3.890, 54}, {3.895, 55}, {3.900, 56}, {3.907, 57}, {3.917, 58}, {3.924, 59}, {3.929, 60} },
    { {3.936, 61}, {3.942, 62}, {3.949, 63}, {3.957, 64}, {3.964, 65}, {3.971, 66}, {3.984, 67}, {3.990, 68}, {3.998, 69}, {4.006, 70} },
    { {4.015, 71}, {4.024, 72}, {4.032, 73}, {4.042, 74}, {4.050, 75}, {4.060, 76}, {4.069, 77}, {4.078, 78}, {4.088, 79}, {4.098, 80} },
    { {4.109, 81}, {4.119, 82}, {4.130, 83}, {4.141, 84}, {4.154, 85}, {4.169, 86}, {4.184, 87}, {4.197, 88}, {4.211, 89}, {4.220, 90} },
    { {4.229, 91}, {4.237, 92}, {4.246, 93}, {4.254, 94}, {4.264, 95}, {4.278, 96}, {4.302, 97}, {4.320, 98}, {4.339, 99}, {4.350,100} },
}

local voltageRanges_lipo = {4.30, 8.60, 12.90, 17.20, 21.50, 25.80, 30.10, 34.40, 38.70, 43.00, 47.30, 51.60}
--local voltageRanges_lion={4.20, 8.40, 12.60, 16.80, 21.00, 25.20, 29.40, 33.60, 37.80, 42.00, 46.20, 50.40}
local voltageRanges_lion = {4.30, 8.60, 12.90, 17.20, 21.50, 25.80, 30.10, 34.40, 38.70, 43.00, 47.30, 51.60}
local voltageRanges_hv   = {4.45, 8.90, 13.35, 17.80, 22.25, 26.70, 31.15, 35.60, 40.05, 44.50, 48.95, 53.40}

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
    wgt.log("cbCellCount: %s, autoCellDetection: %s, cellCount: %s", wgt.options.cbCellCount, wgt.autoCellDetection, wgt.cellCount)

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
            -- wgt.log(string.format("source_name: %s", source_name))
            wgt.source_name = source_name
        end
    else
        wgt.source_name = wgt.options.sensor
    end

    wgt.options.isTotalVoltage = wgt.options.isTotalVoltage % 2 -- modulo due to bug that cause the value to be other than 0|1

    -- wgt.log("wgt.options.batt_type: %s", wgt.options.batt_type)
end

--------------------------------------------------------------

-- clear old telemetry data upon reset event
function wgt.onTelemetryResetEvent(wgt)
    wgt.log("telemetry reset event detected.")
    wgt.telemResetCount = wgt.telemResetCount + 1

    wgt.vTotalLive = 0
    wgt.vCellLive = 0
    wgt.vMin = 99
    wgt.vMax = 0
    wgt.cellCount = 1
    wgt.cell_detected = false
    -- wgt.tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
end

--- This function return the percentage remaining in a single Lipo cel
function wgt.getCellPercent(cellValue)
    if cellValue == nil then
        return 0
    end

    -- in case somehow voltage is higher, don't return nil
    if (cellValue > 4.2) then
        return 100
    end

    local _percentList = percent_list_lipo
    if wgt.options.batt_type == 1 then
        _percentList = percent_list_lipo
    elseif wgt.options.batt_type == 2 then
        _percentList = percent_list_hv
    elseif wgt.options.batt_type == 3 then
        _percentList = percent_list_lion
    end

    local result = 0
    for i1, v1 in ipairs(_percentList) do
        -- log(string.format("sub-list#: %s, head:%f, length: %d, last: %.3f", i1,v1[1][1], #v1, v1[#v1][1]))
        -- is the cellVal < last-value-on-sub-list? (first-val:v1[1], last-val:v1[#v1])
        if (cellValue <= v1[#v1][1]) then
            -- cellVal is in this sub-list, find the exact value
            -- log("this is the list")
            for i2, v2 in ipairs(v1) do
                -- log(string.format("cell#: %s, %.3f--> %d%%", i2,v2[1], v2[2]))
                if v2[1] >= cellValue then
                    result = v2[2]
                    -- log(string.format("result: %d%%", result))
                    -- cpuProfilerAdd(wgt, 'cell-perc', t4);
                    return result
                end
            end
        end
    end

    -- for i, v in ipairs(_percentListSplit) do
    --  if v[1] >= cellValue then
    --    result = v[2]
    --    break
    --  end
    -- end
    return result
end

local function calcCellCount(singleVoltage)
    local voltageRanges = voltageRanges_lipo

    if wgt.options.batt_type == 1 then
        voltageRanges = voltageRanges_lipo
    elseif wgt.options.batt_type == 2 then
        voltageRanges = voltageRanges_hv
    elseif wgt.options.batt_type == 3 then
        voltageRanges = voltageRanges_lion
    end

    for i = 1, #voltageRanges do
        if singleVoltage < voltageRanges[i] then
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
end

return wgt

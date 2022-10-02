---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
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

--  This Rotary Gauge widget display a fancy old style analog gauge with needle
--  Options:
--    HighAsGreen: [checked] for sensor that high values is good (RSSI/Fuel/...)
--      [checked] for sensor that high values is good (RSSI/Fuel/...)
--      [un-checked] for sensor that low values is good (Temp/Battery/...)
--  Note: if the min & max input value are -1, widget will automatically select min/max based on the source name.
--  common sources are:
--    * RSSI
--    * Temp
--    * rpm
--    * fuel
--    * vibration (heli)
--    * Transmitter Battery
--    * batt-capacity
--    * A1/A2 analog voltage

-- Version: 0.5
-- Author : Offer Shmuely


local app_name = "GaugeRotary"

-- imports
local GaugeClass = loadScript("/WIDGETS/" .. app_name .. "/gauge_core.lua")
local ToolsClass = loadScript("/WIDGETS/" .. app_name .. "/tools.lua")

-- consts
local UNIT_ID_TO_STRING = { "V", "A", "mA", "kts", "m/s", "f/s", "km/h", "mph", "m", "f", "°C", "°F", "%", "mAh", "W", "mW", "dB", "rpm", "g", "°", "rad", "ml", "fOz", "ml/m", "Hz", "uS", "km" }
local DEFAULT_MIN_MAX = {
    { "RSSI", 0, 100, 0 },
    { "1RSS", -120, 0, 0 },
    { "2RSS", -120, 0, 0 },
    { "RQly", 0, 100, 0 },
    { "RxBt", 4, 10, 1 },
    { "TxBt", 6, 8.4, 1 },
    { "Batt", 6, 8.4, 1 },
    { "cell", 3.5, 4.2, 1 },
    { "Fuel", 0, 100, 0 },
    { "Vibr", 0, 100, 0 },
    { "Temp", 30, 120, 0 },
    { "Tmp1", 30, 120, 0 },
    { "Tmp2", 30, 120, 0 },
}

local _options = {
    { "Source", SOURCE, 253 }, -- RSSI
    --{ "Source", SOURCE, 243 }, -- TxBt
    --{ "Source", SOURCE, 256 }, -- RxBt
    { "Min", VALUE, -1, -1024, 1024 },
    { "Max", VALUE, -1, -1024, 1024 },
    { "HighAsGreen", BOOL, 1 },
    { "Precision", VALUE, 1, 0, 1 }
}

--------------------------------------------------------------
local function log(s)
    --print("GaugeRotary: " .. s)
end
--------------------------------------------------------------

local function setAutoMinMax(wgt)
    -- log(string.format("setAutoMinMax(wgt.options.Min: %d, wgt.options.Max: %d) ", wgt.options.Min, wgt.options.Max))
    if wgt.options.Min ~= -1 or wgt.options.Max ~= -1 then
        --if wgt.options.Min ~= wgt.options.Max then
        print("GaugeRotary-setting: " .. "no need for AutoMinMax")
        return
    end

    print("GaugeRotary-setting: " .. "AutoMinMax")
    local sourceName = getSourceName(wgt.options.Source)
    if (sourceName == nil) then return end

    -- workaround for bug in getFiledInfo()
    if string.byte(string.sub(sourceName, 1, 1)) > 127 then
        sourceName = string.sub(sourceName, 2, -1) -- ???? why?
    end
    print("GaugeRotary-setting: " .. "AutoMinMax, source:" .. sourceName)

    for i = 1, #DEFAULT_MIN_MAX, 1 do
        local def_key = DEFAULT_MIN_MAX[i][1]
        local def_min = DEFAULT_MIN_MAX[i][2]
        local def_max = DEFAULT_MIN_MAX[i][3]
        local def_precision = DEFAULT_MIN_MAX[i][4]

        if def_key == sourceName then
            log(string.format("setting min-max from default: %s: min:%d, max:%d, precision:%d", def_key, def_min, def_max, def_precision))
            wgt.options.Min = def_min
            wgt.options.Max = def_max
            wgt.options.precision = def_precision
            break
        end
    end

    if wgt.options.Min == wgt.options.Max then
        print("GaugeRotary-setting: " .. "AutoMinMax else")
        wgt.options.Min = 0
        wgt.options.Max = 100
    end

end

local function update(wgt, options)
    wgt.options = options
    setAutoMinMax(wgt)
    wgt.gauge1 = GaugeClass(options.HighAsGreen, 2)
    wgt.tools = ToolsClass()
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        last_value = -1,
        last_value_min = -1,
        last_value_max = -1,
        gauge1 = nil
    }

    update(wgt, options)
    return wgt
end

--------------------------------------------------------------------------------------------------------

local function getPercentageValue(value, options_min, options_max)
    if value == nil then
        return nil
    end

    local percentageValue = value - options_min;
    percentageValue = (percentageValue / (options_max - options_min)) * 100
    percentageValue = tonumber(percentageValue)
    percentageValue = math.floor(percentageValue)

    if percentageValue > 100 then
        percentageValue = 100
    elseif percentageValue < 0 then
        percentageValue = 0
    end

    log("getPercentageValue(" .. value .. ", " .. options_min .. ", " .. options_max .. ")-->" .. percentageValue)
    return percentageValue
end

local function getWidgetValue(wgt)
    local currentValue = getValue(wgt.options.Source)
    local sourceName = getSourceName(wgt.options.Source)
    --log("aaaaaa:  ".. sourceName .. ": " .. string.byte(string.sub(sourceName, 1, 1)))

    --- if table, sum of all cells
    if type(currentValue) == "table" then
        local cellSum = 0
        for k, v in pairs(currentValue) do
            cellSum = cellSum + v
        end
        currentValue = cellSum
    end

    -- workaround for bug in getFiledInfo()
    if string.byte(string.sub(sourceName, 1, 1)) > 127 then
        sourceName = string.sub(sourceName, 2, -1) -- ???? why?
    end
    if string.byte(string.sub(sourceName, 1, 1)) > 127 then
        sourceName = string.sub(sourceName, 2, -1) -- ???? why?
    end
    --log("Source: " .. wgt.options.Source .. ",name: " .. sourceName)

    local fieldinfo = getFieldInfo(wgt.options.Source)
    if (fieldinfo == nil) then
        log(string.format("getFieldInfo(%s)==nil", wgt.options.Source))
        return sourceName, -1, nil, nil, ""
    end

    local txtUnit = "-"
    if (fieldinfo.unit) then
        --log("have unit")
        if (fieldinfo.unit > 0 and fieldinfo.unit < #UNIT_ID_TO_STRING) then
            txtUnit = UNIT_ID_TO_STRING[fieldinfo.unit]
        end
    end

    --log("")
    --log(string.format("id: %s", fieldinfo.id))
    --log(string.format("  sourceName: %s", sourceName))
    --log(string.format("  curr: %2.1f", currentValue))
    --log(string.format("  name: %s", fieldinfo.name))
    --log(string.format("  desc: %s", fieldinfo.desc))
    --log(string.format("  idUnit: %s", fieldinfo.unit))
    --log(string.format("  txtUnit: %s", txtUnit))

    if (wgt.tools.isTelemetryAvailable()) then

        -- try to get min/max value (if exist)
        local minValue, maxValue, source_min_id, source_max_id

        if source_min_id == nil or source_max_id == nil then
            source_min_obj = getFieldInfo(sourceName .. "-")
            if source_min_obj ~= nil then
                source_min_id = source_min_obj.id
            end
            source_max_obj = getFieldInfo(sourceName .. "+")
            if source_min_obj ~= nil then
                source_max_id = source_max_obj.id
            end
        end
        if source_min_id ~= nil and source_max_id ~= nil then
            minValue = getValue(source_min_id)
            maxValue = getValue(source_max_id)
        end

        wgt.last_value = currentValue
        wgt.last_value_min = minValue
        wgt.last_value_max = maxValue

        --log("min/max: ["..sourceName.."]" .. minValue .. " < " .. currentValue .. " < " .. maxValue)
        return sourceName, currentValue, minValue, maxValue, txtUnit
    else
        log("overriding value with last_value: " .. wgt.last_value)
        return sourceName, wgt.last_value, wgt.last_value_min, wgt.last_value_max, txtUnit
    end
end

local function refresh_app_mode(wgt, event, touchState)
    local w_name, value, minValue, maxValue, w_unit = getWidgetValue(wgt)

    local percentageValue = getPercentageValue(value, wgt.options.Min, wgt.options.Max)
    local percentageValueMin = getPercentageValue(minValue, wgt.options.Min, wgt.options.Max)
    local percentageValueMax = getPercentageValue(maxValue, wgt.options.Min, wgt.options.Max)

    local zone_w = 460
    local zone_h = 252

    local centerX = zone_w / 2
    wgt.gauge1.drawGauge(centerX, 120, 110, false, percentageValue, percentageValueMin, percentageValueMax, value .. w_unit, w_name)
    lcd.drawText(10, 10, string.format("%d%s", value, w_unit), XXLSIZE + YELLOW)

    -- min / max
    wgt.gauge1.drawGauge(100, 180, 50, false, percentageValueMin, nil, nil, "", w_name)
    wgt.gauge1.drawGauge(zone_w - 100, 180, 50, false, percentageValueMax, nil, nil, "", w_name)
    lcd.drawText(50, 230, string.format("Min: %d%s", minValue, w_unit), MIDSIZE)
    lcd.drawText(350, 230, string.format("Max: %d%s", maxValue, w_unit), MIDSIZE)

end

local function refresh_widget(wgt)
    local w_name, value, minValue, maxValue, w_unit = getWidgetValue(wgt)
    if (value == nil) then
        return
    end

    local percentageValue = getPercentageValue(value, wgt.options.Min, wgt.options.Max)
    local percentageValueMin = getPercentageValue(minValue, wgt.options.Min, wgt.options.Max)
    local percentageValueMax = getPercentageValue(maxValue, wgt.options.Min, wgt.options.Max)

    local value_fmt_min = ""
    local value_fmt_max = ""
    local value_fmt = ""
    if wgt.options.precision == 0 then
        value_fmt = string.format("%2.0f%s", value, w_unit)
        if minValue ~= nil then
            value_fmt_min = string.format("%2.0f%s", minValue, w_unit)
        end
        if maxValue ~= nil then
            value_fmt_max = string.format("%2.0f%s", maxValue, w_unit)
        end
    else
        value_fmt = string.format("%2.1f%s", value, w_unit)
        if minValue ~= nil then
            value_fmt_min = string.format("%2.1f%s", minValue, w_unit)
        end
        if maxValue ~= nil then
            value_fmt_max = string.format("%2.1f%s", maxValue, w_unit)
        end
    end

    -- calculate low-profile or full-circle
    local isFull = true
    if wgt.zone.h < 60 then
        lcd.drawText(wgt.zone.x + 10, wgt.zone.y, "too small for GaugeRotary", SMLSIZE + RED)
        return
    elseif wgt.zone.h < 90 then
        log("widget too low (" .. wgt.zone.h .. ")")
        if wgt.zone.w * 1.2 > wgt.zone.h then
            log("wgt wider then height, use low profile ")
            isFull = false
        end
    end

    local centerR, centerX, centerY

    if isFull then
        centerR = math.min(wgt.zone.h, wgt.zone.w) / 2
        --local centerX = wgt.zone.x + (wgt.zone.w / 2)
        centerX = wgt.zone.x + wgt.zone.w - centerR
        centerY = wgt.zone.y + (wgt.zone.h / 2)
    else
        centerR = wgt.zone.h - 20
        centerX = wgt.zone.x + wgt.zone.w - centerR
        centerY = wgt.zone.y + wgt.zone.h - 20
    end

    wgt.gauge1.drawGauge(centerX, centerY, centerR, isFull, percentageValue, percentageValueMin, percentageValueMax, value_fmt, value_fmt_min, value_fmt_max, w_name)
    --lcd.drawText(wgt.zone.x, wgt.zone.y, value_fmt, XXLSIZE + YELLOW)


    -- display min max
    if isFull == false then
        lcd.drawText(wgt.zone.x, wgt.zone.y + 20, value_fmt, 0 + YELLOW)
        lcd.drawText(wgt.zone.x + 0, wgt.zone.y + 40, "Min: " .. value_fmt_min, SMLSIZE)
        lcd.drawText(wgt.zone.x + 0, wgt.zone.y + 55, "Max: " .. value_fmt_max, SMLSIZE)
    end

    if wgt.tools.isTelemetryAvailable() == false then
        lcd.drawText(wgt.zone.x, wgt.zone.y + wgt.zone.h / 2, "Disconnected...", MIDSIZE + WHITE + BLINK)
    end

end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil) then return end
    local sourceName = getSourceName(wgt.options.Source)
    if (sourceName == nil) then
        lcd.drawText(wgt.zone.x, wgt.zone.y + wgt.zone.h / 2, "No source selected...", MIDSIZE + WHITE + BLINK)
        return
    end

    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y, wgt.zone.w, wgt.zone.h, BLACK)

    local ver, radio, maj, minor, rev, osname = getVersion()
    --log("version: " .. ver)
    if osname ~= "EdgeTX" then
        local err = string.format("supported only on EdgeTX: ", osname)
        log(err)
        lcd.drawText(0, 0, err, SMLSIZE)
        return
    end
    if maj == 2 and minor < 7 then
        local err = string.format("NOT supported ver: %s", ver)
        log(err)
        lcd.drawText(0, 0, err, SMLSIZE)
        return
    end

    if (event ~= nil) then
        -- full screen (app mode)
        refresh_app_mode(wgt, event, touchState)
    else
        -- regular screen
        refresh_widget(wgt)
    end

    -- widget load (debugging)
    -- lcd.drawText(wgt.zone.x + 10, wgt.zone.y, string.format("load: %d%%", getUsage()), SMLSIZE + GREY) -- ???
end

return { name = app_name, options = _options, create = create, update = update, refresh = refresh }

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

-- Version: 0.1
-- Author : Offer Shmuely

local UNIT_ID_TO_STRING = { "V", "A", "mA", "kts", "m/s", "f/s", "km/h", "mph", "m", "f", "°C", "°F", "%", "mAh", "W", "mW", "dB", "rpm", "g", "°", "rad", "ml", "fOz", "ml/m", "Hz", "uS", "km" }
local DEFAULT_MIN_MAX = {
  {"RSSI" ,  0, 100, 0},
  {"1RSS" ,  -120, 0, 0},
  {"2RSS" ,  -120, 0, 0},
  {"RQly" ,  0, 100, 0},
  {"RxBt" ,  4,  10, 1},
  {"TxBt" ,  6, 8.4, 1},
  {"Batt" ,  6, 8.4, 1},
  {"cell" ,3.5, 4.2, 1},
  {"Fuel" ,  0, 100, 0},
  {"Vibr" ,  0, 100, 0},
  {"Temp" ,  30,120, 0},
  {"Tmp1" ,  30,120, 0},
  {"Tmp2" ,  30,120, 0},
}

local _options = {
  { "Source", SOURCE, 253 }, -- RSSI
  --{ "Source", SOURCE, 243 }, -- TxBt
  --{ "Source", SOURCE, 256 }, -- RxBt
  { "Min", VALUE, -1, -1024, 1024 },
  { "Max", VALUE, -1, -1024, 1024 },
  { "HighAsGreen", BOOL, 1 },
  { "Precision", VALUE, 1 , 0 , 1}
}

--------------------------------------------------------------
local function log(s)
  return;
  --print("GaugeRotary: " .. s)
end
--------------------------------------------------------------

local function setAutoMinMax(wgt)
  if wgt.options.Min ~= -1 and wgt.options.Max ~= -1 then
  --if wgt.options.Min ~= wgt.options.Max then
    print("GaugeRotary-setting: " .. "no need for AutoMinMax")
    return
  end

  print("GaugeRotary-setting: " .. "AutoMinMax")
  local sourceName = getSourceName(wgt.options.Source)
  -- workaround for bug in getFiledInfo()
  if string.byte(string.sub(sourceName,1,1)) > 127 then
    sourceName = string.sub(sourceName,2,-1) -- ???? why?
  end
  print("GaugeRotary-setting: " .. "AutoMinMax, source:" .. sourceName)

  for i=1, #DEFAULT_MIN_MAX, 1 do
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

local function create(zone, options)
  local GaugeClass = loadScript("/WIDGETS/GaugeRotary/gauge_core.lua")

  local wgt = {
    zone = zone,
    options = options,
    gauge1 = GaugeClass(options.HighAsGreen, 2)
  }

  setAutoMinMax(wgt)

  return wgt
end

local function update(wgt, options)
  wgt.options = options
  setAutoMinMax(wgt)
  wgt.gauge1.HighAsGreen = wgt.options.HighAsGreen
end

-- -----------------------------------------------------------------------------------------------------

local function getPercentageValue(value, options_min, options_max)
  if value == nil then
    return nil
  end

  local percentageValue = value - options_min;
  percentageValue = (percentageValue / (options_max - options_min)) * 100
  percentageValue = tonumber(percentageValue)
  percentageValue = math.floor( percentageValue )

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
  log("aaaaaa:  "..  sourceName)
  log("aaaaaa:  ".. sourceName .. ": " .. string.byte(string.sub(sourceName, 1, 1)))

  -- workaround for bug in getFiledInfo()
  if string.byte(string.sub(sourceName,1,1)) > 127 then
    sourceName = string.sub(sourceName,2,-1) -- ???? why?
  end
  --log("Source: " .. wgt.options.Source .. ",name: " .. sourceName)

  --local currentValue = getValue(wgt.options.Source) / 10.24

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

  log("")
  log(string.format("id: %s", fieldinfo.id))
  log(string.format("  sourceName: %s", sourceName))
  log(string.format("  curr: %2.1f", currentValue))
  log(string.format("  name: %s", fieldinfo.name))
  log(string.format("  desc: %s", fieldinfo.desc))
  log(string.format("  idUnit: %s", fieldinfo.unit))
  log(string.format("  txtUnit: %s", txtUnit))

  -- try to get min/max value (if exist)
  local minValue = getValue(sourceName .. "-")
  local maxValue = getValue(sourceName .. "+")
  --log("min/max: " .. minValue .. " < " .. currentValue .. " < " .. maxValue)

  return sourceName, currentValue, minValue, maxValue, txtUnit
end

local function refresh_app_mode(wgt, event, touchState, w_name, value, minValue, maxValue, w_unit, percentageValue, percentageValueMin, percentageValueMax)
  local w_name, value, minValue, maxValue, w_unit = getWidgetValue(wgt)
  if (value == nil) then
    return
  end

  local percentageValue = getPercentageValue(value, wgt.options.Min, wgt.options.Max)
  local percentageValueMin = getPercentageValue(minValue, wgt.options.Min, wgt.options.Max)
  local percentageValueMax = getPercentageValue(maxValue, wgt.options.Min, wgt.options.Max)

  local zone_w = 460
  local zone_h = 252

  local centerX = zone_w / 2
  wgt.gauge1.drawGauge(centerX, 120, 110, false, percentageValue, percentageValueMin, percentageValueMax, percentageValue .. w_unit, w_name)
  lcd.drawText(10, 10, string.format("%d%s", percentageValue, w_unit), XXLSIZE + YELLOW)

  -- min / max
  wgt.gauge1.drawGauge(100, 180, 50, false, percentageValueMin, nil, nil, "", w_name)
  wgt.gauge1.drawGauge(zone_w - 100, 180, 50, false, percentageValueMax, nil, nil, "", w_name)
  lcd.drawText(50, 230, string.format("Min: %d%s", percentageValueMin, w_unit), MIDSIZE)
  lcd.drawText(350, 230, string.format("Max: %d%s", percentageValueMax, w_unit), MIDSIZE)

end


local function refresh_widget(wgt, w_name, value, minValue, maxValue, w_unit, percentageValue, percentageValueMin, percentageValueMax)
  local w_name, value, minValue, maxValue, w_unit = getWidgetValue(wgt)
  if (value == nil) then
    return
  end

  local percentageValue = getPercentageValue(value, wgt.options.Min, wgt.options.Max)
  local percentageValueMin = getPercentageValue(minValue, wgt.options.Min, wgt.options.Max)
  local percentageValueMax = getPercentageValue(maxValue, wgt.options.Min, wgt.options.Max)

  local value_fmt = ""
  if wgt.options.precision == 0 then
    value_fmt = string.format("%2.0f%s", value, w_unit)
  else
    value_fmt = string.format("%2.1f%s", value, w_unit)
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

  wgt.gauge1.drawGauge(centerX, centerY, centerR, isFull, percentageValue, percentageValueMin, percentageValueMax, value_fmt, w_name)
  --lcd.drawText(wgt.zone.x, wgt.zone.y, value_fmt, XXLSIZE + YELLOW)

end


local function refresh(wgt, event, touchState)
  if (wgt == nil) then return end
  if (wgt.options == nil) then return end
  if (wgt.zone == nil) then return end

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
--  lcd.drawText(wgt.zone.x + 10, wgt.zone.y, string.format("load: %d%%", getUsage()), SMLSIZE + GREY) -- ???
end

return { name = "GaugeRotary", options = _options, create = create, update = update, refresh = refresh }

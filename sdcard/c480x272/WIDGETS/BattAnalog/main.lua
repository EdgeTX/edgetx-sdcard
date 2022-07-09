---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for FrSky Horus/Radio Master TX16s            #
---- # Copyright (C) OpenTX                                                  #
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

-- This widget display a graphical representation of a Lipo (not other types) battery level, it will automatically detect the cell amount of the battery.
-- it will take a lipo voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli


-- Widget to display the levels of Lipo battery from single analog source
-- Offer Shmuely
-- Date: 2021
-- ver: 0.2

local _options = {
  { "Sensor", SOURCE, 0 }, -- default to 'A1'
  { "Color", COLOR, YELLOW },
  { "Show_Total_Voltage", BOOL, 0 } -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
}

-- Data gathered from commercial lipo sensors
local myArrayPercentList = { { 3, 0 }, { 3.093, 1 }, { 3.196, 2 }, { 3.301, 3 }, { 3.401, 4 }, { 3.477, 5 }, { 3.544, 6 }, { 3.601, 7 }, { 3.637, 8 }, { 3.664, 9 }, { 3.679, 10 }, { 3.683, 11 }, { 3.689, 12 }, { 3.692, 13 }, { 3.705, 14 }, { 3.71, 15 }, { 3.713, 16 }, { 3.715, 17 }, { 3.72, 18 }, { 3.731, 19 }, { 3.735, 20 }, { 3.744, 21 }, { 3.753, 22 }, { 3.756, 23 }, { 3.758, 24 }, { 3.762, 25 }, { 3.767, 26 }, { 3.774, 27 }, { 3.78, 28 }, { 3.783, 29 }, { 3.786, 30 }, { 3.789, 31 }, { 3.794, 32 }, { 3.797, 33 }, { 3.8, 34 }, { 3.802, 35 }, { 3.805, 36 }, { 3.808, 37 }, { 3.811, 38 }, { 3.815, 39 }, { 3.818, 40 }, { 3.822, 41 }, { 3.825, 42 }, { 3.829, 43 }, { 3.833, 44 }, { 3.836, 45 }, { 3.84, 46 }, { 3.843, 47 }, { 3.847, 48 }, { 3.85, 49 }, { 3.854, 50 }, { 3.857, 51 }, { 3.86, 52 }, { 3.863, 53 }, { 3.866, 54 }, { 3.87, 55 }, { 3.874, 56 }, { 3.879, 57 }, { 3.888, 58 }, { 3.893, 59 }, { 3.897, 60 }, { 3.902, 61 }, { 3.906, 62 }, { 3.911, 63 }, { 3.918, 64 }, { 3.923, 65 }, { 3.928, 66 }, { 3.939, 67 }, { 3.943, 68 }, { 3.949, 69 }, { 3.955, 70 }, { 3.961, 71 }, { 3.968, 72 }, { 3.974, 73 }, { 3.981, 74 }, { 3.987, 75 }, { 3.994, 76 }, { 4.001, 77 }, { 4.007, 78 }, { 4.014, 79 }, { 4.021, 80 }, { 4.029, 81 }, { 4.036, 82 }, { 4.044, 83 }, { 4.052, 84 }, { 4.062, 85 }, { 4.074, 86 }, { 4.085, 87 }, { 4.095, 88 }, { 4.105, 89 }, { 4.111, 90 }, { 4.116, 91 }, { 4.12, 92 }, { 4.125, 93 }, { 4.129, 94 }, { 4.135, 95 }, { 4.145, 96 }, { 4.176, 97 }, { 4.179, 98 }, { 4.193, 99 }, { 4.2, 100 } }
local defaultSensor = "RxBt" -- RxBt / A1 / A3/ VFAS /RxBt

--------------------------------------------------------------
local function log(s)
  return;
  --print("Batt_A1: " .. s)
end
--------------------------------------------------------------

-- This function is run once at the creation of the widget
local function create(zone, options)
  local wgt = {
    zone = zone,
    options = options,
    counter = 0,

    telemResetCount = 0,
    telemResetLowestMinRSSI = 101,
    no_telem_blink = 0,
    isDataAvailable = 0,
    vMax = 0,
    vMin = 0,
    vTotalLive = 0,
    vPercent = 0,

    cellCount = 0,
    vCellLive = 0,

    mainValue = 0,
    secondaryValue = 0
  }

  -- use default if user did not set, So widget is operational on "select widget"
  if wgt.options.Sensor == 0 then
    wgt.options.Sensor = defaultSensor
  end

  wgt.options.Show_Total_Voltage = wgt.options.Show_Total_Voltage % 2 -- modulo due to bug that cause the value to be other than 0|1

  return wgt
end

-- This function allow updates when you change widgets settings
local function update(wgt, options)
  if (wgt == nil) then
    return
  end

  wgt.options = options

  -- use default if user did not set, So widget is operational on "select widget"
  if wgt.options.Sensor == 0 then
    wgt.options.Sensor = defaultSensor
  end

  wgt.options.Show_Total_Voltage = wgt.options.Show_Total_Voltage % 2 -- modulo due to bug that cause the value to be other than 0|1

end


-- clear old telemetry data upon reset event
local function onTelemetryResetEvent(wgt)
  wgt.telemResetCount = wgt.telemResetCount + 1

  wgt.vTotalLive = 0
  wgt.vCellLive = 0
  wgt.vMin = 99
  wgt.vMax = 0
  wgt.cellCount = 0
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
local function getCellPercent(cellValue)
  if cellValue == nil then
    return 0
  end

  -- in case somehow voltage is higher, don't return nil
  if (cellValue > 4.2) then
    return 100
  end

  for i, v in ipairs(myArrayPercentList) do
    if v[1] >= cellValue then
      result = v[2]
      break
    end
  end
  return result
end

local function calcCellCount(wgt, singleVoltage)
  if singleVoltage < 4.3 then
    return 1
  elseif singleVoltage < 8.6 then
    return 2
  elseif singleVoltage < 12.9 then
    return 3
  elseif singleVoltage < 17.2 then
    return 4
  elseif singleVoltage < 21.5 then
    return 5
  elseif singleVoltage < 25.8 then
    return 6
  elseif singleVoltage < 30.1 then
    return 7
  elseif singleVoltage < 34.4 then
    return 8
  elseif singleVoltage < 38.7 then
    return 9
  elseif singleVoltage < 43.0 then
    return 10
  elseif singleVoltage < 47.3 then
    return 11
  elseif singleVoltage < 51.6 then
    return 12
  end

  print("no match found" .. singleVoltage)
  return 1
end

--- This function returns a table with cels values
local function calculateBatteryData(wgt)

  local v = getValue(wgt.options.Sensor)
  local fieldinfo = getFieldInfo(wgt.options.Sensor)
  print("wgt.options.Sensor: " .. wgt.options.Sensor)
  print("v: " .. v)

  if type(v) == "table" then
    -- multi cell values using FLVSS liPo Voltage Sensor
    if (#v > 1) then
      wgt.isDataAvailable = false
      local txt = "FLVSS liPo Voltage Sensor, not supported"
      print(txt)
      return
    end
  elseif v ~= nil and v >= 1 then
    -- single cell or VFAS lipo sensor
    if fieldinfo then
      print("single value: " .. fieldinfo['name'] .. "=" .. v)
    else
      print("only one cell using Ax lipo sensor")
    end
  else
    -- no telemetry available
    wgt.isDataAvailable = false
    if fieldinfo then
      print("no telemetry data: " .. fieldinfo['name'] .. "=??")
    else
      print("no telemetry data")
    end
    return
  end

  local newCellCount = calcCellCount(wgt, v)

  -- this is necessary for simu where cell-count can change
  if newCellCount ~= wgt.cellCount then
    wgt.vMin = 99
    wgt.vMax = 0
  end

  -- calc highest of all cells
  if v > wgt.vMax then
    wgt.vMax = v
  end

  wgt.cellCount = newCellCount
  wgt.vTotalLive = v
  wgt.vCellLive = wgt.vTotalLive / wgt.cellCount
  wgt.vPercent = getCellPercent(wgt.vCellLive)

  -- print("wgt.vCellLive: ".. wgt.vCellLive)
  -- print("wgt.vPercent: ".. wgt.vPercent)

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
  lcd.setColor(CUSTOM_COLOR, getPercentColor(wgt.vPercent))
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h  - math.floor(wgt.vPercent / 100 * (myBatt.h - myBatt.cath_h)), myBatt.w, math.floor(wgt.vPercent / 100 * (myBatt.h - myBatt.cath_h)), CUSTOM_COLOR)

  -- draw bat
  lcd.setColor(CUSTOM_COLOR, WHITE)

  -- draw bat segments
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h - myBatt.cath_h, CUSTOM_COLOR, 2)
  for i = 1, myBatt.h - myBatt.cath_h - myBatt.segments_h, myBatt.segments_h do
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h + i, myBatt.w, myBatt.segments_h, CUSTOM_COLOR, 1)
  end

  -- draw plus terminal
  local tw = 4
  local th = 4
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2 + tw / 2, wgt.zone.y + myBatt.y, myBatt.cath_w - tw, myBatt.cath_h, CUSTOM_COLOR)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2, wgt.zone.y + myBatt.y + th, myBatt.cath_w, myBatt.cath_h - th, CUSTOM_COLOR)
  --lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.0f%%", wgt.vPercent), LEFT + MIDSIZE + CUSTOM_COLOR)
  --lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.1fV", wgt.mainValue), LEFT + MIDSIZE + CUSTOM_COLOR)

  ---- fill batt
  --lcd.setColor(CUSTOM_COLOR, getPercentColor(wgt.vPercent))
  ----lcd.drawGauge    (wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h , wgt.vPercent, 100, CUSTOM_COLOR)
  --
  --lcd.setColor(CUSTOM_COLOR, lcd.RGB(0, 0xdf, 0))
  --for i = 0, 50, 20 do
  --  local ph = myBatt.h - i
  --  local line_h = 14
  --  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + ph -line_h, myBatt.w, line_h, CUSTOM_COLOR, 2)
  --end
  ----local h = myBatt.h - 30
  --  --lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h - 30, myBatt.w, 10, CUSTOM_COLOR, 2)
  --
  --
  ---- draws bat
  --lcd.setColor(CUSTOM_COLOR, WHITE)
  --lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h - myBatt.cath_h, CUSTOM_COLOR, 2)
  --
  ---- draw plus terminal
  --lcd.setColor(CUSTOM_COLOR, BLACK)
  --local tw = 4
  --local th = 2
  --lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w/2 - myBatt.cath_w/2 +tw/2, wgt.zone.y , myBatt.cath_w -tw, myBatt.cath_h, CUSTOM_COLOR)
  --lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w/2 - myBatt.cath_w/2, wgt.zone.y +th, myBatt.cath_w, myBatt.cath_h -th, CUSTOM_COLOR)
  ----lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.0f%%", wgt.vPercent), LEFT + MIDSIZE + CUSTOM_COLOR)
  ----lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%2.1fV", wgt.mainValue), LEFT + MIDSIZE + CUSTOM_COLOR)

end

--- Zone size: 70x39 1/8th top bar
local function refreshZoneTiny(wgt)
  local myString = string.format("%2.1fV", wgt.mainValue)
  lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 5, wgt.vPercent .. "%", RIGHT + SMLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 20, myString, RIGHT + SMLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  -- draw batt
  lcd.drawRectangle(wgt.zone.x + 50, wgt.zone.y + 9, 16, 25, CUSTOM_COLOR, 2)
  lcd.drawFilledRectangle(wgt.zone.x + 50 + 4, wgt.zone.y + 7, 6, 3, CUSTOM_COLOR)
  local rect_h = math.floor(25 * wgt.vPercent / 100)
  lcd.drawFilledRectangle(wgt.zone.x + 50, wgt.zone.y + 9 + 25 - rect_h, 16, rect_h, CUSTOM_COLOR + wgt.no_telem_blink)
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
  local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 155, ["h"] = 35, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

  -- draws bat
  lcd.setColor(CUSTOM_COLOR, WHITE)
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, CUSTOM_COLOR, 2)

  -- fill batt
  lcd.setColor(CUSTOM_COLOR, getPercentColor(wgt.vPercent))
  lcd.drawGauge(wgt.zone.x + 2, wgt.zone.y + 2, myBatt.w - 4, wgt.zone.h, wgt.vPercent, 100, CUSTOM_COLOR)

  -- write text
  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end
  local topLine = string.format("%2.1fV      %2.0f%%", wgt.mainValue, wgt.vPercent)
  lcd.drawText(wgt.zone.x + 20, wgt.zone.y + 2, topLine, MIDSIZE + CUSTOM_COLOR + wgt.no_telem_blink)

end


--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
  local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 50, ["h"] = wgt.zone.h, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 26, ["cath_h"] = 10, ["segments_h"] = 16 }

  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end

  -- draw values
  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end
  lcd.drawText(wgt.zone.x + myBatt.w + 10, wgt.zone.y, string.format("%2.1fV", wgt.mainValue), DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(wgt.zone.x + myBatt.w + 10, wgt.zone.y + 30, string.format("%2.0f%%", wgt.vPercent), MIDSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  if wgt.options.Show_Total_Voltage == 0 then
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h -35, string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  else
    --lcd.drawText(wgt.zone.x, wgt.zone.y + 40, string.format("%2.1fV", wgt.mainValue), DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  end
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 20, string.format("Min %2.2fV", wgt.vMin), RIGHT + SMLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)

  -- more info if 1/4 is high enough (without trim & slider)
  if wgt.zone.h > 80 then
  end

  drawBattery(wgt, myBatt)

end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
  local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 76, ["h"] = wgt.zone.h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end

  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 0, string.format("%2.1fV", wgt.mainValue), RIGHT + DBLSIZE + CUSTOM_COLOR)
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 30, wgt.vPercent .. "%", RIGHT + DBLSIZE + CUSTOM_COLOR)
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 35, string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + CUSTOM_COLOR)
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 20, string.format("min %2.2fV", wgt.vMin), RIGHT + SMLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)

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
  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end

  lcd.drawText(x + w, y + myBatt.y + 0, string.format("%2.1fV    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(x + w, y +h - 60       , string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(x + w, y +h - 30       , string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)


  drawBattery(wgt, myBatt)

  return
end


--- Zone size: 460x252 (full screen app mode)
local function refreshFullScreen(wgt, event, touchState)
  local x = 0
  local w = 460
  local y = 0
  local h = 252
  
  local myBatt = { ["x"] = 10, ["y"] = 0, ["w"] = 80, ["h"] = h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

  if (event ~= nil) then
    print("event: " .. event)
  end
    
  -- draw right text section
  if wgt.isDataAvailable then
    lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  else
    lcd.setColor(CUSTOM_COLOR, GREY)
  end
  lcd.drawText(x + w, y + myBatt.y + 0, string.format("%2.1fV    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(x + w, y +h - 60, string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)
  lcd.drawText(x + w, y +h - 30, string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + CUSTOM_COLOR + wgt.no_telem_blink)

  drawBattery(wgt, myBatt)

  return
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
  if (wgt == nil) then
    return
  end

  detectResetEvent(wgt)

  calculateBatteryData(wgt)

end

local function refresh(wgt, event, touchState)

  if (wgt == nil) then
    return
  end
  if type(wgt) ~= "table" then
    return
  end
  if (wgt.options == nil) then
    return
  end
  if (wgt.zone == nil) then
    return
  end
  if (wgt.options.Show_Total_Voltage == nil) then
    return
  end

  detectResetEvent(wgt)

  calculateBatteryData(wgt)

  if wgt.isDataAvailable then
    wgt.no_telem_blink = 0
  else
    wgt.no_telem_blink = INVERS + BLINK
  end


  -- debug
  --lcd.setColor(CUSTOM_COLOR, lcd.RGB(0, 150, 0))
  --lcd.drawRectangle(wgt.zone.x, wgt.zone.y, wgt.zone.w, wgt.zone.h, BLACK)

  if (event ~= nil) then
    refreshFullScreen(wgt, event, touchState)
  elseif wgt.zone.w > 380 and wgt.zone.h > 165 then
    refreshZoneXLarge(wgt)
  elseif wgt.zone.w > 180 and wgt.zone.h > 145 then
    refreshZoneLarge(wgt)
  elseif wgt.zone.w > 170 and wgt.zone.h > 65 then
    refreshZoneMedium(wgt)
  elseif wgt.zone.w > 150 and wgt.zone.h > 28 then
    refreshZoneSmall(wgt)
  elseif wgt.zone.w > 65 and wgt.zone.h > 35 then
    refreshZoneTiny(wgt)
  end

end

-- return { name = "BattCheck (Analog)", options = _options, create = create, update = update, background = background, refresh = refresh }
return { name = "BattAnalog", options = _options, create = create, update = update, background = background, refresh = refresh }

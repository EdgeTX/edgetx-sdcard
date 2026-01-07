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

-- Horus Widget to display the levels of lipo battery with per cell indication
-- 3djc & Offer Shmuely
-- Date: 2022
-- ver: 0.7
local version = "v0.8"

local _options = {
  { "Sensor", SOURCE, 0   }, -- default to 'Cels'
  { "Color", COLOR, WHITE },
  { "Shadow", BOOL, 0     },
  { "LowestCell", BOOL, 1 },   -- 0=main voltage display shows all-cell-voltage, 1=main voltage display shows lowest-cell
}

-- Data gathered from commercial lipo sensors

local _lipoPercentListSplit = {
  { { 3, 0 }, { 3.093, 1 }, { 3.196, 2 }, { 3.301, 3 }, { 3.401, 4 }, { 3.477, 5 }, { 3.544, 6 }, { 3.601, 7 }, { 3.637, 8 }, { 3.664, 9 }, { 3.679, 10 }, { 3.683, 11 }, { 3.689, 12 }, { 3.692, 13 } },
  { { 3.705, 14 }, { 3.71, 15 }, { 3.713, 16 }, { 3.715, 17 }, { 3.72, 18 }, { 3.731, 19 }, { 3.735, 20 }, { 3.744, 21 }, { 3.753, 22 }, { 3.756, 23 }, { 3.758, 24 }, { 3.762, 25 }, { 3.767, 26 } },
  { { 3.774, 27 }, { 3.78, 28 }, { 3.783, 29 }, { 3.786, 30 }, { 3.789, 31 }, { 3.794, 32 }, { 3.797, 33 }, { 3.8, 34 }, { 3.802, 35 }, { 3.805, 36 }, { 3.808, 37 }, { 3.811, 38 }, { 3.815, 39 } },
  { { 3.818, 40 }, { 3.822, 41 }, { 3.825, 42 }, { 3.829, 43 }, { 3.833, 44 }, { 3.836, 45 }, { 3.84, 46 }, { 3.843, 47 }, { 3.847, 48 }, { 3.85, 49 }, { 3.854, 50 }, { 3.857, 51 }, { 3.86, 52 } },
  { { 3.863, 53 }, { 3.866, 54 }, { 3.87, 55 }, { 3.874, 56 }, { 3.879, 57 }, { 3.888, 58 }, { 3.893, 59 }, { 3.897, 60 }, { 3.902, 61 }, { 3.906, 62 }, { 3.911, 63 }, { 3.918, 64 } },
  { { 3.923, 65 }, { 3.928, 66 }, { 3.939, 67 }, { 3.943, 68 }, { 3.949, 69 }, { 3.955, 70 }, { 3.961, 71 }, { 3.968, 72 }, { 3.974, 73 }, { 3.981, 74 }, { 3.987, 75 }, { 3.994, 76 } },
  { { 4.001, 77 }, { 4.007, 78 }, { 4.014, 79 }, { 4.021, 80 }, { 4.029, 81 }, { 4.036, 82 }, { 4.044, 83 }, { 4.052, 84 }, { 4.062, 85 }, { 4.074, 86 }, { 4.085, 87 }, { 4.095, 88 } },
  { { 4.105, 89 }, { 4.111, 90 }, { 4.116, 91 }, { 4.12, 92 }, { 4.125, 93 }, { 4.129, 94 }, { 4.135, 95 }, { 4.145, 96 }, { 4.176, 97 }, { 4.179, 98 }, { 4.193, 99 }, { 4.2, 100 } },
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
    oldValues = {0,0,0,0} -- count, total-time, last-time, max-time
  end

  local max = oldValues[4]
  if (timeSpan > oldValues[4]) then
    max = timeSpan
  end

  wgt.profTimes[name] = {oldValues[1]+1, oldValues[2] + timeSpan, timeSpan, max}; -- count, total-time, last-time, max-time
end
local function cpuProfilerShow(wgt)
  --return;
  if (periodicHasPassed(wgt.periodicProfiler)) then
    local s = "profiler: \n"
    for name, valArr in pairs(wgt.profTimes) do
      s = s .. string.format("  /%-15s - avg:%02.1f, max:%2d%%, last:%2d%% (count:%5s, tot:%5s)\n", name, valArr[2]/valArr[1], valArr[4], valArr[3], valArr[1], valArr[2])
    end
    log(s);
    periodicReset(wgt.periodicProfiler)
  end
end
-----------------------------------------------------------------

local function update(wgt, options)
  if (wgt == nil) then
    return
  end

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
    cellDataLive = { 0, 0, 0, 0, 0, 0 },
    cellDataLivePercent = {0,0,0,0,0,0},
    cellDataHistoryLowest = { 5, 5, 5, 5, 5, 5 },
    cellDataHistoryLowestPercent = {5,5,5,5,5,5},
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

  wgt.cellDataLive = { 0, 0, 0, 0, 0, 0 }
  wgt.cellDataLivePercent = {0,0,0,0,0,0}
  wgt.cellDataHistoryLowest = { 5, 5, 5, 5, 5, 5 }
  wgt.cellDataHistoryLowestPercent = {5,5,5,5,5,5}
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

  for i1, v1 in ipairs(_lipoPercentListSplit) do
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
    if v > 1 and v < wgt.cellDataHistoryLowest[k] then -- min 1v to consider a valid reading
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
    if v < cellMin and v > 1 then -- min 1v to consider a valid reading
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
--      wgt.cellDataLivePercent[i] = 100
--      wgt.cellDataHistoryLowestPercent[i] = 0
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

--- Zone size: 70x39 1/8th top bar
local function refreshZoneTiny(wgt)
  local myString = string.format("%2.1fV", wgt.mainValue)
  
  -- 动态计算电池尺寸和位置，适应不同屏幕尺寸
  -- 电池宽度：根据zone宽度按比例计算，但限制在合理范围
  local min_batt_width = 14
  local max_batt_width = 20
  local batt_width_ratio = 0.18  -- 占zone宽度的18%
  local batt_w = math.max(min_batt_width, math.min(max_batt_width, math.floor(wgt.zone.w * batt_width_ratio)))
  
  -- 电池位置：从右侧开始，留出安全边距
  local right_margin = math.max(2, math.floor(wgt.zone.w * 0.02))  -- 右侧边距为zone宽度的2%，最小2像素
  local batt_x = wgt.zone.w - batt_w - right_margin
  local batt_y = 9
  local batt_h = 25
  
  -- 文字区域：明确限制在电池左侧，留出安全间距
  local text_safe_margin = 4  -- 文字和电池之间的安全间距
  local text_right_x = batt_x - text_safe_margin  -- 文字右对齐的位置
  
  -- 动态计算上下文字位置，确保有足够间距
  local text_line_height = math.max(12, math.floor(wgt.zone.h * 0.35))  -- 行间距至少12像素，或zone高度的35%
  local text_y1 = math.max(3, math.floor(wgt.zone.h * 0.12))  -- 第一行位置：至少3像素，或zone高度的12%
  local text_y2 = text_y1 + text_line_height  -- 第二行位置
  
  -- 绘制文字（右对齐到text_right_x位置）
  lcd.drawText(wgt.zone.x + text_right_x, wgt.zone.y + text_y1, wgt.cellPercent .. "%", RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
  lcd.drawText(wgt.zone.x + text_right_x, wgt.zone.y + text_y2, myString, RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

  -- 绘制电池
  local batt_color = wgt.options.Color
  local terminal_w = math.max(4, batt_w - 10)  -- 正极宽度，至少4像素
  lcd.drawRectangle(wgt.zone.x + batt_x, wgt.zone.y + batt_y, batt_w, batt_h, batt_color, 2)
  lcd.drawFilledRectangle(wgt.zone.x + batt_x + (batt_w - terminal_w) / 2, wgt.zone.y + batt_y - 3, terminal_w, 3, batt_color)
  local rect_h = math.floor(batt_h * wgt.cellPercent / 100)
  lcd.drawFilledRectangle(wgt.zone.x + batt_x, wgt.zone.y + batt_y + batt_h - rect_h, batt_w, rect_h, batt_color + wgt.no_telem_blink)
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
  -- 动态计算电池尺寸，适应不同屏幕尺寸
  -- 电池宽度：根据zone宽度计算，留出左右边距
  local batt_margin = 5  -- 左右边距
  local myBatt_w = math.max(100, wgt.zone.w - batt_margin * 2)  -- 电池宽度，至少100像素
  local myBatt_h = math.min(35, wgt.zone.h - 2)  -- 电池高度，不超过zone高度-2
  
  local myBatt = { 
    ["x"] = batt_margin, 
    ["y"] = 0, 
    ["w"] = myBatt_w, 
    ["h"] = myBatt_h, 
    ["segments_w"] = 25, 
    ["color"] = WHITE, 
    ["cath_w"] = 6, 
    ["cath_h"] = 20 
  }

  -- fill battery
  local fill_color = getPercentColor(wgt.cellPercent)
  lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, wgt.cellPercent, 100, fill_color)

  -- draw battery
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, WHITE, 2)


  -- write text - 动态调整位置以适应电池框
  local topLine = string.format("%2.1fV      %2.0f%%", wgt.mainValue, wgt.cellPercent)
  local text_x = wgt.zone.x + myBatt.x + math.min(20, myBatt_w * 0.15)  -- 文字左侧边距，至少20像素或电池宽度的15%
  lcd.drawText(text_x, wgt.zone.y + 2, topLine, MIDSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

end


--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
  -- 动态计算电池大小，适应不同屏幕尺寸
  -- 电池宽度：根据zone宽度按比例，但保持合理范围
  local batt_w = math.max(70, math.min(100, math.floor(wgt.zone.w * 0.35)))  -- 电池宽度为zone宽度的35%，限制在70-100像素
  local batt_h = math.min(35, math.floor(wgt.zone.h * 0.45))  -- 电池高度不超过zone高度的45%，最大35像素
  
  local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = batt_w, ["h"] = batt_h, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

  -- 动态计算文字位置，避免上下数据重合
  -- 主电压值位置：基于zone高度动态计算
  local main_v_y = math.max(30, math.floor(wgt.zone.h * 0.35))  -- 至少30像素，或zone高度的35%
  
  -- draw values
  lcd.drawText(wgt.zone.x, wgt.zone.y + main_v_y, string.format("%2.1fV", wgt.mainValue), DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

  -- more info if 1/4 is high enough (without trim & slider)
  -- 动态计算附加信息的位置，确保与主电压有足够间距
  local info_spacing = math.max(25, math.floor(wgt.zone.h * 0.25))  -- 行间距至少25像素，或zone高度的25%
  if wgt.zone.h > 80 then
    local dV_y = main_v_y + info_spacing
    local min_y = dV_y + math.max(12, math.floor(info_spacing * 0.5))  -- 第二行和第三行之间也有间距
    
    --lcd.drawText(wgt.zone.x + 50     , wgt.zone.y + 70, string.format("%2.2fV"   , wgt.secondaryValue), SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x, wgt.zone.y + dV_y, string.format("dV %2.2fV", wgt.cellMax - wgt.cellMin), SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x, wgt.zone.y + min_y, string.format("Min %2.2fV", wgt.cellDataHistoryCellLowest), SMLSIZE + wgt.text_color + wgt.no_telem_blink)
  end

  -- fill battery
  local fill_color = getPercentColor(wgt.cellPercent)
  lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, wgt.cellPercent, 100, fill_color)

  -- draw cells
  local cellH = wgt.zone.h / wgt.cellCount
  if cellH > 20 then cellH =20 end
  local cellX = 118
  local cellW = 58
  for i = 1, wgt.cellCount, 1 do
    local cellY = wgt.zone.y + (i - 1) * (cellH - 1)

    -- fill current cell
    local fill_color = getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
    print(fill_color)
    log(string.format("fill_color: %d", fill_color))
    --lcd.drawFilledRectangle(wgt.zone.x + cellX     , cellY, 58, cellH, fill_color)
    lcd.drawFilledRectangle(wgt.zone.x + cellX     , cellY, cellW * wgt.cellDataLivePercent[i] / 100, cellH, fill_color)

    -- fill cell history min
    --lcd.setColor(fill_color, getRangeColor(wgt.cellDataHistoryLowest[i], wgt.cellMax, wgt.cellMax - 0.2))
    lcd.drawFilledRectangle(wgt.zone.x + cellX + (cellW * wgt.cellDataHistoryLowestPercent[i])/100 -2, cellY, 2 , cellH, BLACK)

    lcd.drawText           (wgt.zone.x + cellX + 10, cellY, string.format("%.2f", wgt.cellDataLive[i]), SMLSIZE + WHITE + wgt.shadowed + wgt.no_telem_blink)
    lcd.drawRectangle      (wgt.zone.x + cellX     , cellY, 59, cellH, WHITE , 1)
  end

  -- draw battery
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, WHITE, 2)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w, wgt.zone.y + myBatt.h / 2 - myBatt.cath_h / 2, myBatt.cath_w, myBatt.cath_h, WHITE)
  
  -- 动态计算数字位置，确保完全在电池框内
  -- 计算文字大小，确定合适的位置
  local percent_text = string.format("%2.0f%%", wgt.cellPercent)
  local text_w, text_h = lcd.sizeText(percent_text, MIDSIZE)
  
  -- 数字居中在电池框内，留出安全边距
  local text_x = wgt.zone.x + myBatt.x + (myBatt.w - text_w) / 2  -- 水平居中
  local text_y = wgt.zone.y + myBatt.y + (myBatt.h - text_h) / 2  -- 垂直居中
  
  -- 确保数字不超出电池框边界（至少留出2像素边距）
  text_x = math.max(wgt.zone.x + myBatt.x + 2, math.min(text_x, wgt.zone.x + myBatt.x + myBatt.w - text_w - 2))
  text_y = math.max(wgt.zone.y + myBatt.y + 2, math.min(text_y, wgt.zone.y + myBatt.y + myBatt.h - text_h - 2))
  
  lcd.drawText(text_x, text_y, percent_text, LEFT + MIDSIZE + WHITE + wgt.shadowed)

end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
  local myBatt = { ["x"] = 0, ["y"] = 18, ["w"] = 76, ["h"] = 121, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y, wgt.cellPercent .. "%", RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed)
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 30, string.format("%2.1fV", wgt.mainValue), RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed)
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 70, string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color + wgt.shadowed)

  -- fill battery
  local fill_color = getPercentColor(wgt.cellPercent)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h + myBatt.cath_h - math.floor(wgt.cellPercent / 100 * myBatt.h), myBatt.w, math.floor(wgt.cellPercent / 100 * myBatt.h), fill_color)
  -- draw cells
  local pos = { { x = 80, y = 90 }, { x = 138, y = 90 }, { x = 80, y = 109 }, { x = 138, y = 109 }, { x = 80, y = 128 }, { x = 138, y = 128 } }
  for i = 1, math.min(wgt.cellCount, #pos), 1 do
    if pos[i] and wgt.cellDataLive[i] then
      local fill_color = getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
      lcd.drawFilledRectangle(wgt.zone.x + pos[i].x, wgt.zone.y + pos[i].y, 58, 20, fill_color)

      lcd.drawText(wgt.zone.x + pos[i].x + 10, wgt.zone.y + pos[i].y, string.format("%.2f", wgt.cellDataLive[i]), WHITE + wgt.shadowed)
      lcd.drawRectangle(wgt.zone.x + pos[i].x, wgt.zone.y + pos[i].y, 59, 20, WHITE, 1)
    end
  end

  -- draw battery
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h, WHITE, 2)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w / 2 - myBatt.cath_w / 2, wgt.zone.y + myBatt.y, myBatt.cath_w, myBatt.cath_h, WHITE)
  for i = 1, myBatt.h - myBatt.segments_h, myBatt.segments_h do
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h + i, myBatt.w, myBatt.segments_h, WHITE, 1)
  end

end

local function refreshAppModeImpl(wgt, x, w, y, h)

  local myBatt = { ["x"] = 10, ["y"] = 20, ["w"] = 80, ["h"] = 121, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }


  -- fill battery
  local fill_color = getPercentColor(wgt.cellPercent)
  lcd.drawFilledRectangle(x + myBatt.x, y + myBatt.y + myBatt.h + myBatt.cath_h - math.floor(wgt.cellPercent / 100 * myBatt.h), myBatt.w, math.floor(wgt.cellPercent / 100 * myBatt.h), fill_color)

  -- draw right text section
  lcd.drawText(x + w, y + myBatt.y, wgt.cellPercent .. "%", RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

  lcd.drawText(x + w, y + myBatt.y + 30, string.format("%2.1fV", wgt.mainValue), RIGHT + DBLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)
  lcd.drawText(x + w, y + myBatt.y + 105, string.format("%2.1fV %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + SMLSIZE + wgt.text_color + wgt.shadowed + wgt.no_telem_blink)

  -- draw cells
  local pos = { { x = 111, y = 38 }, { x = 164, y = 38 }, { x = 217, y = 38 }, { x = 111, y = 57 }, { x = 164, y = 57 }, { x = 217, y = 57 } }
  for i = 1, math.min(wgt.cellCount, #pos), 1 do
    if pos[i] and wgt.cellDataLive[i] then
      local cell_color =  getRangeColor(wgt.cellDataLive[i], wgt.cellMax, wgt.cellMax - 0.2)
      lcd.drawFilledRectangle(x + pos[i].x, y + pos[i].y, 53, 20, cell_color)
      lcd.drawText(x + pos[i].x + 10, y + pos[i].y, string.format("%.2f", wgt.cellDataLive[i]), WHITE + wgt.shadowed + wgt.no_telem_blink)
      lcd.drawRectangle(x + pos[i].x, y + pos[i].y, 54, 20, WHITE, 1)
    end
  end
  -- draw cells for lowest cells
  local pos = { { x = 111, y = 110 }, { x = 164, y = 110 }, { x = 217, y = 110 }, { x = 111, y = 129 }, { x = 164, y = 129 }, { x = 217, y = 129 } }
  for i = 1, math.min(wgt.cellCount, #pos), 1 do
    if pos[i] and wgt.cellDataHistoryLowest[i] and wgt.cellDataLive[i] then
      local cell_color = getRangeColor(wgt.cellDataHistoryLowest[i], wgt.cellDataLive[i], wgt.cellDataLive[i] - 0.3)
      lcd.drawFilledRectangle(x + pos[i].x, y + pos[i].y, 53, 20, cell_color)

      lcd.drawRectangle(x + pos[i].x, y + pos[i].y, 54, 20, WHITE, 1)
      lcd.drawText(x + pos[i].x + 10, y + pos[i].y, string.format("%.2f", wgt.cellDataHistoryLowest[i]), WHITE + wgt.shadowed + wgt.no_telem_blink)
    end
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
  lcd.drawRectangle(x + 110, y + 110, 161, 40, WHITE, 1)
  lcd.drawText(x + 230, y + 93, "Lowest data", RIGHT + SMLSIZE + INVERS + WHITE + wgt.shadowed)
  return
end

--- Zone size: 390x172 1/1
--- Zone size: 460x252 1/1 (no sliders/trim/topbar)
local function refreshZoneXLarge(wgt)
  local x = wgt.zone.x
  local w = wgt.zone.w
  local y = wgt.zone.y
  local h = wgt.zone.h

  refreshAppModeImpl(wgt, x, w, y, h)
end


--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(wgt, event, touchState)
  local x = 0
  local w = 460
  local y = 0
  local h = 252
  refreshAppModeImpl(wgt, x, w, y, h)
end


-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
  if (wgt == nil) then
    return
  end
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
  else
    -- 使用屏幕百分比来判断布局，适应不同屏幕尺寸
    local w_percent = (wgt.zone.w / LCD_W) * 100  -- 宽度占屏幕百分比
    local h_percent = (wgt.zone.h / LCD_H) * 100   -- 高度占屏幕百分比
    
    if w_percent > 70 and h_percent > 50 then
      refreshZoneXLarge(wgt)                      --最大这两没区别
    elseif w_percent > 30 and h_percent > 40 then
      refreshZoneLarge(wgt)                       --最大这两没区别
    elseif w_percent > 30 and h_percent > 25 then
      refreshZoneMedium(wgt)                      --中等大小
    elseif w_percent > 30 and h_percent > 10 then
      refreshZoneSmall(wgt)                     --1/4格
    else  --if w_percent > 15 and h_percent > 15 then
      refreshZoneTiny(wgt)                        --小屏幕  
    end
  end
  --cpuProfilerAdd(wgt, 'main-loop-4', t4);

  --cpuProfilerAdd(wgt, 'main-loop', t1);
  --cpuProfilerShow(wgt);
  --lcd.drawText(wgt.zone.x, wgt.zone.y, string.format("r:%d", wgt.telemResetCount), SMLSIZE + wgt.text_color)
  --lcd.drawText(wgt.zone.x+100, wgt.zone.y, string.format("%d%%", getUsage()), SMLSIZE + wgt.text_color)
end

return { name = "BattCheck", options = _options, create = create, update = update, background = background, refresh = refresh }
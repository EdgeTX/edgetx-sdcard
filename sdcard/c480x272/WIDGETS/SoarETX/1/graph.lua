---------------------------------------------------------------------------
-- SoarETX graph of log data                                             --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-08-28                                                   --
-- Version: 1.0.1                                                        --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widget, soarGlobals =  ...

local libGUI =    soarGlobals.libGUI
libGUI.flags =    0
local colors =    libGUI.colors
local title =     "Graph"

-- Screen drawing constants
local LCD_W2 =    LCD_W / 2
local HEADER =    40
local TOP =       50
local BOTTOM =    LCD_H - 18
local LINE =      40
local HEIGHT =    28
local LFT =       30
local WIDTH =     60
local W1 =        0.4 * (LCD_W - 3 * LFT)
local W2 =        (LCD_W - 3 * LFT) - W1
local COL2 =      W1 + 2 * LFT
local PLOT_W =    LCD_W - 3 * LFT - WIDTH
local PLOT_H =    BOTTOM - TOP
local RGT =       LFT + PLOT_W
local MARGIN =    10
local BUTTON_X =  RGT + MARGIN
local BUTTON_W =  LCD_W - BUTTON_X - MARGIN

-- Other constants
local FMAX = 1E38
local DEFAULT_PLOT =   "Alt"
local FIRST_EXCLUDED = "Rud"
do
	local lang = getGeneralSettings().language
	if lang == "CZ" then
		FIRST_EXCLUDED = "Smer"
	elseif lang == "DE" then
		FIRST_EXCLUDED = "Sei"
	elseif lang == "FR" or lang == "IT" then
		FIRST_EXCLUDED = "Dir"
	elseif lang == "PL" then
		FIRST_EXCLUDED = "SK"
	elseif lang == "PT" then
		FIRST_EXCLUDED = "Lem"
	elseif lang == "SE" then
		FIRST_EXCLUDED = "Rod"
	end
end

-- Variables
local gui
local guiFile
local guiPause
local guiGraph
local menu1
local menu2
local buildingTree
local fileTree
local fileCount
local getNextFileName
local fileName
local data
local refreshDates
local lines
local cursor
local xMin
local xScale
local y0
local yScale

------------------------------- Reading data ------------------------------

local function timeSerial(str)
	local hr = string.sub(str, 1, 2)
	local mn = string.sub(str, 4, 5)
	local sc = string.sub(str, 7, 12)
	return 3600 * hr + 60 * mn + sc
end

local function buildFileTree()
	if not fileTree then
		guiPause.title = "READING..."
    gui = guiPause
  	fileTree = { }
		fileCount = 0
		getNextFileName = dir("/LOGS")
		fileName = getNextFileName()
	end

  while fileName do
		-- If there are many files, then we may run out of CPU instructions
		if getUsage() > 90 then
			return
		end

    if string.len(fileName) > 23 and string.sub(fileName, -4) == ".csv" then
      local dateStr = string.sub(fileName, -21, -12)
      local nameStr = string.sub(fileName, -10, -9) .. ":" .. string.sub(fileName, -8, -7) .. ":" ..
                      string.sub(fileName, -6, -5) .. " " .. string.sub(fileName, 1, -23)

      if not fileTree[dateStr] then
        fileTree[dateStr] = { }
				fileCount = fileCount + 1
      end

      fileTree[dateStr][nameStr] = fileName
    end

		fileName = getNextFileName()
  end

	if getUsage() > 20 then
		return
	end

	getNextFileName = nil
	fileName = nil

  if fileCount == 0 then
		guiPause.title = "NO   LOG   FILES"
    gui = guiPause
    headers = nil
    data = { }
  else
    refreshDates()
    gui = guiFile
  end

	buildingTree = false
end

local function readLines(fileName)
  -- data[2] = min values, data[3] = max values
  data = { { }, { FMAX }, { -FMAX } }

  if not fileName then
    return
  end

  fileName = "/LOGS/" .. fileName
  local fileStat = fstat(fileName)

  if not fileStat then
    return
  end

  local l = string.len(DEFAULT_PLOT)
  local plotIdx = 2
  local logFile = io.open(fileName, "r")
  local logString = io.read(logFile, fileStat.size)
  io.close(logFile)
  lines = { }

  local i = 0
  for line in string.gmatch(logString, "[^\n]+") do
    i = i + 1
    lines[i] = line
  end

  if #lines < 3 then
    return
  end

  local headers = { }
  i = -1
  for field in string.gmatch(lines[1], "[^,]+") do
    i = i + 1
    if i >= 1 then
      headers[i] = field
    end
  end

  for i = 2, #headers do
    if string.sub(headers[i], 1, l) == DEFAULT_PLOT then
      plotIdx = i
    end
    if headers[i] == FIRST_EXCLUDED then
      break
    end
    data[1][i - 1] = headers[i]
    data[2][i] = FMAX
    data[3][i] = -FMAX
  end

  local ddp = guiGraph.ddPlot
  if #data[1] == 0 then
    ddp.disabled = true
  else
    ddp.disabled = false
    ddp.items = data[1]
    if ddp.selected > #data[1] then
      ddp.selected = plotIdx - 1
    end
  end
  gui = guiGraph
end

local function readData()
  local plotIdxLast = #data[1] + 1

  for i = #data - 1, #lines do
    if getUsage() > 90 then
      return
    end
    local j = -1
    local y
    local record = { }
    for field in string.gmatch(lines[i], "[^,]+") do
      j = j + 1
      if j > 0 then
        if j > plotIdxLast then
          break
        elseif j > 1 then
          y = tonumber(field)
        else
          y = timeSerial(field)
        end
        record[j] = y
        data[2][j] = math.min(y, data[2][j])
        data[3][j] = math.max(y, data[3][j])
      end
    end
    data[i + 2] = record
  end
  lines = nil
  cursor = math.ceil((#data + 3) / 2)
end

local function readSelected()
  local date = menu1.items[menu1.selected]
  local name = menu2.items[menu2.selected]
  guiGraph.title = name
  fileName = fileTree[date][name]
  readLines(fileName)
end

-------------------------------- Setup GUI --------------------------------

-- Common GUI setup
local function setupGUI(title)
  local gui = libGUI.newGUI()
  gui.title = title

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, gui.title, bit32.bor(DBLSIZE, colors.primary2))

    -- Extra drawing
    gui.drawMore()
  end

  -- Close button
  local buttonClose = gui.custom({ }, LCD_W - 34, 6, 28, 28)

  function buttonClose.draw(focused)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
    lcd.drawText(LCD_W - 20, 20, "X", CENTER + VCENTER + MIDSIZE + colors.primary2)

    if focused then
      buttonClose.drawFocus()
    end
  end

  function buttonClose.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      lcd.exitFullScreen()
    end
  end

  return gui
end

-- GUI to show if there are no log files
guiPause = setupGUI("Graph")
guiPause.title = ""

function guiPause.drawMore()
  lcd.drawText(LCD_W / 2, LCD_H / 2, guiPause.title, XXLSIZE + CENTER + VCENTER + colors.primary1)
end

-- GUI for selecting log file
do
  guiFile = setupGUI("Select a log file")

  function guiFile.drawMore()
    lcd.drawLine(COL2 - LFT / 2, TOP, COL2 - LFT / 2, BOTTOM, SOLID, colors.primary1)
  end

  local function refreshTimes()
    local date = menu1.items[menu1.selected]
    local times
    if fileTree[date] then
      times = { }
      for t in pairs(fileTree[date]) do
        times[#times + 1] = t
      end
      table.sort(times)
    else
      times = { "No files" }
    end
    menu2.items = times
    menu2.selected = 1
  end

  function refreshDates()
    local dates = { }
    for d in pairs(fileTree) do
      dates[#dates + 1] = d
    end
    table.sort(dates)
    menu1.items = dates
    refreshTimes()
  end

  local function onMenu1()
    refreshTimes()
    guiFile.onEvent(EVT_VIRTUAL_NEXT)
    guiFile.onEvent(EVT_VIRTUAL_ENTER)
  end

  menu1 = guiFile.menu(LFT, TOP, W1, BOTTOM - TOP, nil, onMenu1)

  local function onMenu2()
    readSelected()
    guiFile.onEvent(EVT_VIRTUAL_PREV)
    guiFile.onEvent(EVT_VIRTUAL_ENTER)
  end

  menu2 = guiFile.menu(COL2, TOP, W2, BOTTOM - TOP, nil, onMenu2) -- Add graph function

  guiFile.onEvent(EVT_VIRTUAL_NEXT)
  guiFile.onEvent(EVT_VIRTUAL_ENTER)
end -- Setup guiFile

-- GUI for plotting the graph
do
  guiGraph = setupGUI("")
  local toggleCursor

  local y = TOP
  guiGraph.ddPlot = guiGraph.dropDown(BUTTON_X, y, BUTTON_W, HEIGHT, { "1", "2", "3", "4", "5", "6", "- - -" }, 7, nil, CENTER)

  y = y + LINE
  guiGraph.button(BUTTON_X, y, BUTTON_W, HEIGHT, "New file", function() gui = guiFile end)

  y = y + LINE

  local function moveCursor(d)
    cursor = cursor + d
    if cursor > #data then
      cursor = 4
    elseif cursor < 4 then
      cursor = #data
    end
  end

  -- Trap events with prompt when cursor is active
  local trapCursor = {
    run = function(event, touchState)
      if touchState then
        local tx, ty = touchState.x - LFT, touchState.y
        if 0 <= tx and tx <= PLOT_W and TOP <= ty and ty <= TOP + PLOT_H then
          local x = tx / xScale + xMin
          local y = (y0 - ty) / yScale
          -- Find the nearest x-values
          local i1 = 4
          local i2 = #data
          while i2 - i1 > 1 do
            local i = math.floor((i1 + i2) / 2)
            if data[i][1] <= x then
              i1 = i
            else
              i2 = i
            end
          end
          -- Search for nearest point within x-window
          local ddMin = FMAX
          local plotIdx = guiGraph.ddPlot.selected + 1
          for i = math.max(4, i1 - 4), math.min(#data, i2 + 4) do
            x = LFT + xScale * (data[i][1] - xMin)
            y = y0 - yScale * data[i][plotIdx]
            local dd = (tx - x) ^ 2 + (ty - y) ^ 2
            if dd < ddMin then
              ddMin = dd
              cursor = i
            end
          end
        elseif event == EVT_TOUCH_TAP then
          toggleCursor.onEvent(EVT_VIRTUAL_ENTER)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        toggleCursor.onEvent(event)
      elseif event == EVT_VIRTUAL_PREV then
        moveCursor(-1)
      elseif event == EVT_VIRTUAL_NEXT then
        moveCursor(1)
      end
    end
  }

  local function onToggleCursor()
    if toggleCursor.value then
      guiGraph.showPrompt(trapCursor)
    else
      guiGraph.dismissPrompt()
    end
  end

  toggleCursor = guiGraph.toggleButton(BUTTON_X, y, BUTTON_W, HEIGHT, "Cursor", false, onToggleCursor)

  local function onArrows(d)
    local s = menu2.selected + d
    if s < 1 then
      s = #menu2.items
    elseif s > #menu2.items then
      s = 1
    end
    menu2.selected = s
    readSelected()
  end

  y = BOTTOM - HEIGHT
  local w = (BUTTON_W - MARGIN) / 2
  guiGraph.button(BUTTON_X, y, w, HEIGHT, CHAR_LEFT, function() onArrows(-1) end)
  guiGraph.button(BUTTON_X + MARGIN + w, y, w, HEIGHT, CHAR_RIGHT, function() onArrows(1) end)

  function guiGraph.drawMore()
    local plotIdx = guiGraph.ddPlot.selected + 1

    -- Background
    lcd.drawFilledRectangle(LFT, TOP, PLOT_W, PLOT_H, colors.primary2)
    lcd.drawRectangle(LFT, TOP, PLOT_W, PLOT_H, COLOR_THEME_SECONDARY2)

    if lines then
      local txt = "READING   DATA"
      local flags = DBLSIZE + CENTER + VCENTER + colors.primary1
      lcd.drawText(LFT + PLOT_W / 2, TOP + PLOT_H / 2, txt, DBLSIZE + CENTER + VCENTER + colors.primary1)
      readData()
      return
    elseif #data < 6 or #data[1] == 0 then
      local txt = "NO  DATA  IN  THIS  FILE"
      local flags = DBLSIZE + VCENTER + CENTER + colors.primary1
      lcd.drawText(LFT + PLOT_W / 2, TOP + PLOT_H / 2, txt, flags)
      return
    end

    -- Time scale
    xMin = data[2][1]
    local xRange = math.max(60, data[3][1] - xMin)
    xScale = PLOT_W / xRange
    -- Y-scale
    local yRange = data[3][plotIdx] - data[2][plotIdx]
    local mag = math.max(-2, math.floor(math.log(yRange, 10)))
    local yTick
    local r = yRange / 10^mag
    if r > 6 then
      yTick = 2 * 10^mag
    elseif r > 3 then
      yTick = 1 * 10^mag
    elseif r > 2.4 then
      yTick = 0.5 * 10^mag
    elseif r > 1.2 then
      yTick = 0.4 * 10^mag
    else
      yTick = 0.2 * 10^mag
    end
    yTick = math.max(0.01, yTick)
    local yMin = yTick * math.floor(data[2][plotIdx] / yTick)
    local yMax = yTick * math.ceil(data[3][plotIdx] / yTick)
    if yMin == yMax then
      yMin = yMin - yTick
      yMax = yMax + yTick
    end
    yScale = PLOT_H / (yMax - yMin)
    y0 = BOTTOM + yScale * yMin
    -- Flags for number precision
    local fmt
    if yTick < 0.1 then
      fmt = "%1.2f"
    elseif yTick < 1 then
      fmt = "%2.1f"
    else
      fmt = "%3i"
    end
    -- Lines
    for x = 0, xRange, 60 do
      local xx = LFT + xScale * x
      lcd.drawLine(xx, TOP, xx, BOTTOM, DOTTED, COLOR_THEME_SECONDARY2)
      if x > 0 then
        lcd.drawNumber(xx, BOTTOM, x / 60, CENTER + colors.primary3)
      end
    end
    for y = yMin, yMax, yTick do
      local yy = y0 - yScale * y
      if math.abs(y) < 1E-12 then
        lcd.drawLine(LFT, yy, RGT, yy, SOLID, COLOR_THEME_SECONDARY2)
      else
        lcd.drawLine(LFT, yy, RGT, yy, DOTTED, COLOR_THEME_SECONDARY2)
      end
      lcd.drawText(LFT, yy, string.format(fmt, y), VCENTER + RIGHT + colors.primary3)
    end
    -- Graph curve
    local x1 = LFT + xScale * (data[4][1] - xMin)
    local y1 = y0 - yScale * data[4][plotIdx]
    for i = 5, #data do
      local x2 = LFT + xScale * (data[i][1] - xMin)
      local y2 = y0 - yScale * data[i][plotIdx]
      lcd.drawLine(x1, y1, x2, y2, SOLID, COLOR_THEME_SECONDARY1, 3)
      x1, y1 = x2, y2
    end
    -- Cursor point
    if toggleCursor.value then
      local delta
      local flags = CENTER + COLOR_THEME_SECONDARY1
      x1 = LFT + xScale * (data[cursor][1] - xMin)
      y1 = y0 - yScale * data[cursor][plotIdx]
      lcd.drawFilledCircle(x1, y1, 5, colors.active)
      lcd.drawCircle(x1, y1, 4, COLOR_THEME_SECONDARY1)
      lcd.drawCircle(x1, y1, 5, COLOR_THEME_SECONDARY1)
      -- Slope
      if cursor == 4 then
        delta = (data[cursor + 1][plotIdx] - data[cursor][plotIdx]) / (data[cursor + 1][1] - data[cursor][1])
      elseif cursor == #data then
        delta = (data[cursor][plotIdx] - data[cursor - 1][plotIdx]) / (data[cursor][1] - data[cursor - 1][1])
      else
        delta = (data[cursor + 1][plotIdx] - data[cursor - 1][plotIdx]) / (data[cursor + 1][1] - data[cursor - 1][1])
      end
      -- Plot value and slope
      if y1 - TOP < 24 then
        y1 = y1 + 8
      elseif BOTTOM - y1 < 24 then
        y1 = y1 - 56
      else
        y1 = y1 - 24
      end
      lcd.drawText(x1, y1, string.format("Y=" .. fmt, data[cursor][plotIdx]), flags)
      lcd.drawText(x1, y1 + 24, string.format(CHAR_DELTA .. "=" .. fmt, 60 * delta), flags)
    end
  end

  guiGraph.onEvent(EVT_VIRTUAL_NEXT)
end -- Setup guiGraph

-------------------- Background and Refresh functions ---------------------

function widget.background()
	buildingTree = true
  fileTree = nil
end -- background()

function widget.refresh(event, touchState)
  if not event then
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    widget.background()
    return
  end

  if buildingTree then
    buildFileTree()
  end

  gui.run(event, touchState)
end -- refresh(...)

---------------------------------------------------------------------------
-- The dynamically loadable part of the demonstration Lua widget.        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-12-20                                                   --
-- Version: 1.0.0 RC1                                                    --
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
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- This code chunk is loaded on demand by the LibGUI widget's main script
-- when the create(...) function is run. Hence, the body of this file is
-- executed by the widget's create(...) function.

local zone, options = ... --zone and options were passed as arguments to chunk(...).
local widget = { } -- The widget table will be returned to the main script.

-- Load the GUI library by calling the global function declared in the main script.
-- As long as LibGUI is on the SD card, any widget can call loadGUI() because it is global.
local libGUI = loadGUI()
libGUI.flags = MIDSIZE      -- Default flags that are used unless other flags are passed.
local gui = libGUI.newGUI() -- Instantiate a new GUI object.
local menuLabel
local hsLabel
local vsLabel

-- Local constants and variables:
local LEFT = 20
local TOP = 10
local COL = 160
local ROW = 40
local WIDTH = 120
local HEIGHT = 32
local TMR = 0
local border = false
local labelToggle
local startValue = 0
local menuItems = {
  "First",
  "Second",
  "Third",
  "Fourth",
  "Fifth",
  "Sixth",
  "Seventh",
  "Eighth",
  "Ninth",
  "Tenth"
}

-- Called by gui in full screen mode
local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, COLOR_THEME_EDIT)
    end
  end
end

-- Called by gui in widget zone mode
function libGUI.widgetRefresh()
  lcd.drawRectangle(0, 0, zone.w, zone.h, COLOR_THEME_EDIT)
  lcd.drawText(5, 5, "LibGUI")
end

-- Call back for button "ON"
local function borderON()
  border = true
end

-- Call back for button "OFF"
local function borderOFF()
  border = false
end

-- Call back for toggle button
local function doToggle(toggleButton)
  if toggleButton.value then
    labelToggle.title = "Toggle = ON"
    menuLabel.invers = true
    menuLabel.blink = true
  else
    labelToggle.title = "Toggle = OFF"
    menuLabel.invers = false
    menuLabel.blink = false
  end
end

-- Call back for number
local function numberChange(number, event, touchState)
  if number.value == "--" then
    number.value = 0
  end

  if event == EVT_VIRTUAL_INC then
    number.value = number.value + 1
  elseif event == EVT_VIRTUAL_DEC then
    number.value = number.value - 1
  elseif event == EVT_TOUCH_FIRST then
    startValue = number.value
  elseif event == EVT_TOUCH_SLIDE then
    number.value = math.floor((touchState.startY - touchState.y) / 20 + 0.5) + startValue
  end

  if number.value == 0 then
    number.value = "--"
  end
end

-- Call back for timer
local function timerChange(timer, event, touchState)
  local d = 0

  if timer.value == "- - -" then
    timer.value = 0
  end
  
  if not timer.value then  -- Initialize at first call
    timer.value = model.getTimer(TMR).value
  end
  if libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
    if event == EVT_VIRTUAL_ENTER then
      local tmr = model.getTimer(TMR)
      tmr.value = timer.value
      model.setTimer(TMR, tmr)
    end
    timer.value = nil -- Nil here means that the model timer's value is displayed
    return
  elseif event == EVT_VIRTUAL_INC then
    d = 1
  elseif event == EVT_VIRTUAL_DEC then
    d = -1
  elseif event == EVT_TOUCH_FIRST then
    startValue = timer.value
  end
  if event == EVT_TOUCH_SLIDE then
    timer.value = 60 * math.floor(startValue / 60 + (touchState.startY - touchState.y) / 20 + 0.5)
  else
    timer.value = 60 * math.floor(timer.value / 60 + d + 0.5)
  end
end

-- Call back for menu
local function menuSelect(item, event, touchState)
  playNumber(item.idx, 0)
end

-- Call back for EXIT button
local function exitFS()
  lcd.exitFullScreen()
end

-- Call back for horizontal slider
local function hsCallBack(slider)
  hsLabel.title = slider.value
end

-- Call back for vertical slider
local function vsCallBack(slider)
  vsLabel.title = slider.value
end

do -- Initialization happens here
  local x = LEFT
  local y = TOP
  
  local function nextCol()
    x = x + COL
  end
  
  local function nextRow()
    x = LEFT
    y = y + ROW
  end
  
  gui.fullScreenRefresh = drawFull
  
  gui.button(x, y, WIDTH, HEIGHT, "ON", borderON)
  nextCol()
  gui.button(x, y, WIDTH, HEIGHT, "OFF", borderOFF)

  nextRow()
  gui.toggleButton(x, y, WIDTH, HEIGHT, "Toggle", true, doToggle)
  nextCol()
  labelToggle = gui.label(x, y, WIDTH, HEIGHT, "")

  nextRow()
  gui.label(x, y, WIDTH, HEIGHT, "Number =")
  nextCol()
  gui.number(x, y, WIDTH, HEIGHT, "--", numberChange, bit32.bor(libGUI.flags, RIGHT))

  nextRow()
  gui.label(x, y, WIDTH, HEIGHT, "Timer =")
  nextCol()
  local timer = gui.timer(x, y, WIDTH, HEIGHT, TMR, timerChange, bit32.bor(libGUI.flags, RIGHT))
  timer.value = "- - -"

  nextRow()
  gui.label(x, y, WIDTH, HEIGHT, "Drop down =")
  nextCol()
  local ddItems = { }
  for i, s in ipairs(getPhysicalSwitches()) do
    ddItems[i] = s[1]
  end
  gui.dropDown(x, y, WIDTH, HEIGHT, ddItems, math.floor(#ddItems / 2), nil, 0)

  nextRow()
  gui.button(x, y, WIDTH, HEIGHT, "EXIT", exitFS)

  nextCol()
  nextCol()
  y = TOP
  menuLabel = gui.label(x, y, WIDTH, HEIGHT, "Menu", bit32.bor(BOLD, DBLSIZE))
  y = y + ROW
  gui.menu(x, y, 5, menuItems, menuSelect)
  
  hsLabel = gui.label(LCD_W - 210, LCD_H - 30, 20, 20, 50, CENTER)
  gui.horizontalSlider(LCD_W - 180, LCD_H - 20, 150, 50, 0, 100, 2, hsCallBack)
  vsLabel = gui.label(LCD_W - 30, LCD_H - 210, 20, 20, 50, CENTER)
  gui.verticalSlider(LCD_W - 20, LCD_H - 180, 150, 50, 0, 100, 2, vsCallBack)
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
  gui.run(event, touchState)
end

-- Return to the create(...) function in the main script
return widget

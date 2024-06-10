---------------------------------------------------------------------------
-- SoarETX F3K RE configure mixes and battery warning                    --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-23                                                   --
-- Version: 1.0.0                                                        --
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
local libGUI =  soarGlobals.libGUI
libGUI.flags =  0
local gui = libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Mixes & battery"
local fm = getFlightMode()

-- Screen drawing constants
local LCD_W2 =  LCD_W / 2
local HEADER =  40
local LINE =    32
local HEIGHT =  LINE - 4
local MARGIN =  15
local W1 =      170
local W2 =      LCD_W2 - 2 * MARGIN - W1

-------------------------------- Setup GUI --------------------------------

do
  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Fligh mode
    local fmIdx, fmStr = getFlightMode()
    lcd.drawText(LCD_W - HEADER, HEADER / 2, "FM" .. fmIdx .. ":" .. fmStr, RIGHT + VCENTER + MIDSIZE + colors.primary2)

    -- Line stripes
    for i = 1, 3, 2 do
      lcd.drawFilledRectangle(0, HEADER + LINE * i, LCD_W, LINE, COLOR_THEME_SECONDARY2)
    end

    local bottom = HEADER + 4 * LINE
    lcd.drawLine(LCD_W2, HEADER, LCD_W2, bottom, SOLID, colors.primary1)

    -- Help text
    local txt = "Some variables can be adjusted individually for each flight mode.\n" ..
                "Therefore, select the flight mode for which you want to adjust.\n" ..
                "You can change that behaviour under GLOBAL VARIABLES."
    lcd.drawTextLines(MARGIN, bottom + 25, LCD_W - 2 * MARGIN, LCD_H - bottom, txt, colors.primary1)
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

  -- Grid for items
  local x, y = MARGIN, HEADER + 2

  local function move()
    if x == MARGIN then
      x = x + LCD_W2
    else
      x = MARGIN
      y = y + LINE
    end
  end

  -- Add label and number element for a GV
  local function addGV(label, gv, min, max)
    gui.label(x, y, W1, HEIGHT, label)

    local function changeGV(delta, number)
      local value = number.value + delta
      value = math.max(value, min)
      value = math.min(value, max)
      model.setGlobalVariable(gv, fm, value)
      return value
    end

    local number = gui.number(x + W1, y, W2, HEIGHT, 0, changeGV, RIGHT + libGUI.flags)

    function number.update()
      number.value = model.getGlobalVariable(gv, fm)
    end

    move()
  end

  -- ADD GVs
  addGV("Elevator input", 6, 20, 100)
  addGV("Exponential", 8, 20, 100)

  -- Add battery warning
  gui.label(x, y, W1, HEIGHT, "Battery warning level (V)")

  local function changeBattery(delta, bat)
    local value = bat.value + delta
    value = math.max(0, value)
    value = math.min(200, value)
    soarGlobals.setParameter(soarGlobals.batteryParameter, value - 100)
    return value
  end

  local batP = soarGlobals.getParameter(soarGlobals.batteryParameter)
  gui.number(x + W1, y, W2, HEIGHT, batP + 100, changeBattery, RIGHT + PREC1 + libGUI.flags)
end -- Setup GUI

function widget.background()
end -- background()

function widget.refresh(event, touchState)
  if not event then
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  end

  fm = getFlightMode()

  gui.run(event, touchState)
end -- refresh(...)

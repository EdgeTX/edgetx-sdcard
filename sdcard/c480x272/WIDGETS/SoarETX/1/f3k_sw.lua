---------------------------------------------------------------------------
-- SoarETX F3K switch setup, loadable component                          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-14                                                   --
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
local gui
local colors =  libGUI.colors
local title =   "Switches"

-- Screen drawing constants
local HEADER =  40
local MARGIN =  25
local LINE =    29
local HEIGHT =  25
local WIDTH =   60
local COL2 =    LCD_W - MARGIN - WIDTH

-- List of 1. Text label 2. logical switch
local items = {
  { "Allow vario and voice reporting of altitude", 0 },
  { "Variometer sound", 1 },
  { "Speed flight mode", 2 },
  { "Float flight mode", 3 },
  { "Report remaining window time every 10 sec.", 4 },
  { "Report current altitude every 10 sec.", 5 },
  { "Launch mode and flight timer control", 6 },
  { "Data logging (when flight timer is running)", 7 }
}

-------------------------------- Setup GUI --------------------------------

local function init()
  gui = libGUI.newGUI()

  function gui.fullScreenRefresh()
    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Row background
    for i = 0, 7 do
      local y = HEADER + i * LINE
      if i % 2 == 1 then
        lcd.drawFilledRectangle(0, y, LCD_W, LINE, COLOR_THEME_SECONDARY2)
      else
        lcd.drawFilledRectangle(0, y, LCD_W, LINE, COLOR_THEME_SECONDARY3)
      end
    end
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

  -- Build the list of drop downs
  local y = HEADER + 2
  local w1 = COL2 - MARGIN

  -- Build lists of physical switch position indices and names
  local swIndices = { }
  local swNames = { }

  for swIdx, swName in switches() do
    if string.find(swName,"^!?S[A-H][+-]?") then
      i = #swIndices + 1
      swIndices[i] = swIdx
      swNames[i] = swName
    end
  end

  local function setSwitch(dropDown)
    lsTbl = model.getLogicalSwitch(dropDown.ls)
    swIdx = swIndices[dropDown.selected]
    lsTbl.v1 = swIdx
    model.setLogicalSwitch(dropDown.ls, lsTbl)
  end

  for i, item in ipairs(items) do
    gui.label(MARGIN, y, w1, HEIGHT, item[1])

    local swIdx = model.getLogicalSwitch(item[2]).v1
    local selected = 0

    for i, idx in ipairs(swIndices) do
      if swIdx == idx then
        selected = i
        break
      end
    end

    if selected == 0 then
      -- Oops, no switch matching current value in LS!
      gui.label(COL2, y, WIDTH, HEIGHT, "???", CENTER + BOLD)
    else
      local dropDown = gui.dropDown(COL2, y, WIDTH, HEIGHT, swNames, selected, setSwitch, CENTER)
      dropDown.ls = item[2]
    end

    y = y + LINE
  end
end -- init()

function widget.background()
  gui = nil
end -- background()

function widget.refresh(event, touchState)
  if not event then
    gui = nil
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif gui == nil then
    init()
    return
  end

  gui.run(event, touchState)
end -- refresh(...)

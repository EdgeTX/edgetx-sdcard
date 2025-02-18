---------------------------------------------------------------------------
-- SoarETX F3K switch setup, loadable component                          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Improvements: Frankie Arzu, Jonathan Neuhaus                          --
-- Date:    2024-09-04                                                    --
-- Version: 1.2.2                                                        --
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
local gui
local colors =  libGUI.colors
local title  =   "Switches"
local modelType =   ""

-- Screen drawing constants
local HEADER =  40
local MARGIN =  25
local LINE =    29
local HEIGHT =  25
local WIDTH =   60
local COL2 =    LCD_W - MARGIN - WIDTH

-- List of 1. Text label 2. logical switch
local items_F3K = { -- For R3K
  { "Allow vario and voice reporting of altitude", 0 },
  { "Variometer sound", 1 },
  { "Speed flight mode", 2 },
  { "Float flight mode", 3 },
  { "Report remaining window time every 10 sec.", 4 },
  { "Report current altitude every 10 sec.", 5 },
  { "Launch mode and flight timer control", 6 },
  { "Data logging (when flight timer is running)", 7 }
}

local items_F3K_RE = { -- For R3K_RE
  { "Allow vario and voice reporting of altitude", 0 },
  { "Variometer sound", 1 },
  { "Speed flight mode", 2 },
  { "Report remaining window time every 10 sec.", 4 },
  { "Report current altitude every 10 sec.", 5 },
  { "Launch mode and flight timer control", 6 },
  { "Data logging (when flight timer is running)", 7 }
}

local items_F5K = {
  { "Allow vario and voice reporting of altitude", 0 },
  { "Variometer sound", 1 },
  { "Speed flight mode", 2 },
  { "Float flight mode", 3 },
  { "Motor ARM ON/OFF", 4},
  { "Report remaining window time every 10 sec.", 5 },
  { "Report current altitude every 10 sec.", 6 },
  { "Launch mode and flight timer control", 7 },
  { "Data logging (when flight timer is running)", 8 }
}

local items_FxJ = {
    { "Allow vario and voice reporting of altitude", 0 },
    { "Variometer sound", 1 },
    { "Speed flight mode", 2 },
    { "Float flight mode", 3 },
    { "Report remaining window time every 10 sec.", 6 },
    { "Report current altitude every 10 sec.", 7 },
    { "Launch mode (Motor Arm) and flight timer control", 4 },
    { "Start/Stop timer and Motor", 8 },
    { "Data logging (when flight timer is running)", 9 }
}

local items_FXY = {
    { "Allow vario and voice reporting of altitude", 0 }
}

local items = items_FXY

-------------------------------- Setup GUI --------------------------------

local function init()
  gui = libGUI.newGUI()

  function gui.fullScreenRefresh()
    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title.."  "..modelType, bit32.bor(DBLSIZE, colors.primary2))

    -- Row background
    for i = 0, 8 do
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

  -- Extract Model Type from parametes
  modelType = widget.options.Type

  if modelType == "F3K" or modelType == "F3K_FH" or modelType == "F3K_TRAD" then
    items = items_F3K
  elseif modelType == "F3K_RE" then
    items = items_F3K_RE
  elseif modelType == "F5K" then
    items = items_F5K -- Make it smaller to fit extra line
    HEIGHT =  20
    LINE   = 25
  elseif modelType == "F3J" or modelType == "F5J" then
    items = items_FxJ
    HEIGHT =  20  -- Make it smaller to fit extra line
    LINE   = 25
  else
    items = items_FXY
    modelType = "F??"
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
      local dropDown = gui.dropDown(COL2, y, WIDTH, HEIGHT, swNames, selected, setSwitch, LEFT)
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

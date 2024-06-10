---------------------------------------------------------------------------
-- SoarETX Center ailerons, loadable component                           --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-19                                                   --
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
local libGUI = soarGlobals.libGUI
libGUI.flags =  0
local gui =     libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Center ailerons"
local slider

-- Screen drawing constants
local HEADER =    40
local MARGIN =    20
local TOP =       HEADER + MARGIN
local SLIDER_X =  LCD_W - 30
local SLIDER_W =  50
local SLIDER_H =  200
local R2 =        (LCD_H - TOP - MARGIN) / 1.707
local R1 =        R2 - 35
local CTR_X =     LCD_W / 2
local CTR_Y =     TOP + 0.707 * R2
local SML_H =     select(2, lcd.sizeText("", SMLSIZE))

-- Global variables
local GV_AIL = 0 -- Aileron travel
local GV_BRK = 1 -- Air brake travel
local GV_DIF = 3 -- Aileron differential

-- Logical switch to disable camber etc. to center
local LS_CTR = 11

-- Special: blend two theme colors
local COLOR_BLEND
do
  local c1 = lcd.getColor(COLOR_THEME_SECONDARY1)
  local b1 = 8 * bit32.band(bit32.rshift(c1, 16), 0x1F)
  local g1 = 4 * bit32.band(bit32.rshift(c1, 21), 0x3F)
  local r1 = 8 * bit32.band(bit32.rshift(c1, 27), 0x1F)

  local c2 = lcd.getColor(COLOR_THEME_SECONDARY2)
  local b2 = 8 * bit32.band(bit32.rshift(c2, 16), 0x1F)
  local g2 = 4 * bit32.band(bit32.rshift(c2, 21), 0x3F)
  local r2 = 8 * bit32.band(bit32.rshift(c2, 27), 0x1F)

  COLOR_BLEND = lcd.RGB((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2)
end

-- Draw radial line
local function drawRadian(deg)
  deg = deg * math.pi / 180
  local x = CTR_X + R2 * math.sin(deg)
  local y = CTR_Y - R2 * math.cos(deg)
  lcd.drawLine(CTR_X, CTR_Y, x, y, SOLID, colors.primary3)
end

-- Draw label on annulus
local function drawLabel(deg, r, txt, color)
  deg = deg * math.pi / 180
  local x = CTR_X + r * math.sin(deg)
  local y = CTR_Y - r * math.cos(deg)
  lcd.drawText(x, y, txt, CENTER + VCENTER + SMLSIZE + color)
end

-- Adjust global variables
local function adjust(slider)
	-- Compensate for possible negative differential
	local dif = model.getGlobalVariable(GV_DIF, 0)
	local difComp = 100.0 / math.max(10.0, math.min(100.0, 100.0 + dif))
	-- Calculate aileron travel from current airbrake travel
	local ail = math.min(2 * slider.value, 2 * (100 - slider.value) * difComp)
	model.setGlobalVariable(GV_AIL, 0, ail)
	model.setGlobalVariable(GV_BRK, 0, slider.value)
end

-------------------------------- Setup GUI --------------------------------

do
  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Illustration of flap and aileron travel
    local ail = model.getGlobalVariable(GV_AIL, 0)
    local ailDeg = 0.45 * ail
    local brk = 2 * model.getGlobalVariable(GV_BRK, 0)
    local brkDeg = 0.45 * brk
    local dif = 0.01 * model.getGlobalVariable(GV_DIF, 0)

    lcd.drawPie(CTR_X, CTR_Y, R2, 90 - ailDeg * math.min(1, 1 + dif), 91 + brkDeg, colors.primary2)
    lcd.drawAnnulus(CTR_X, CTR_Y, R1, R2, 90 + ailDeg * math.min(1, 1 - dif), 90 + brkDeg, COLOR_THEME_SECONDARY2)
    lcd.drawAnnulus(CTR_X, CTR_Y, R1, R2, 90, 90 + ailDeg * math.min(1, 1 - dif), COLOR_BLEND)
    lcd.drawAnnulus(CTR_X, CTR_Y, R1, R2, 90 - ailDeg * math.min(1, 1 + dif), 90, COLOR_THEME_SECONDARY1)

    lcd.drawArc(CTR_X, CTR_Y, R2, 90 - ailDeg * math.min(1, 1 + dif), 90 + brkDeg, colors.primary3)
    drawRadian(90 - ailDeg * math.min(1, 1 + dif))
    drawRadian(90)
    drawRadian(90 + brkDeg)

    lcd.drawFilledCircle(CTR_X, CTR_Y, 2, colors.primary2)
    lcd.drawCircle(CTR_X, CTR_Y, 3, colors.primary3)
    lcd.drawCircle(CTR_X, CTR_Y, 2, colors.primary3)

    lcd.drawFilledCircle(CTR_X + R2, CTR_Y, 4, colors.edit)
    lcd.drawCircle(CTR_X + R2, CTR_Y, 5, colors.primary3)
    lcd.drawCircle(CTR_X + R2, CTR_Y, 4, colors.primary3)

    drawLabel(90 - ailDeg / 2 * math.min(1, 1 + dif), (R1 + R2) / 2, math.floor(ail * math.min(1, 1 + dif) + 0.5) .. "%", colors.primary2)
    drawLabel(90 + math.min(brkDeg - 10, (ailDeg + brkDeg) / 2), (R1 + R2) / 2, math.floor(brk + 0.5) .. "%", colors.primary1)
    lcd.drawText(CTR_X + R1, CTR_Y - SML_H, "aileron ", RIGHT + SMLSIZE + colors.primary1)
    lcd.drawText(CTR_X + R1, CTR_Y, "brake ", RIGHT + SMLSIZE + colors.primary1)
    lcd.drawText(CTR_X + R2, CTR_Y - SML_H, "  max.", SMLSIZE + colors.primary1)
    lcd.drawText(CTR_X + R2, CTR_Y, "  reflex", SMLSIZE + colors.primary1)

    local txt = "Use the slider to adjust the flaperons to the position of maximum reflex.\n\n" ..
                "Notice that camber can only move the flaperons down from this position."
    lcd.drawTextLines(MARGIN, TOP, CTR_X - 2 * MARGIN, LCD_H - TOP - MARGIN, txt, colors.primary1)
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

  slider = gui.verticalSlider(SLIDER_X, TOP, SLIDER_H, 70, 50, 90, 1, adjust)
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  if getLogicalSwitchValue(LS_CTR) then
    setStickySwitch(LS_CTR, false)
  end
end -- background()

function widget.refresh(event, touchState)
  if not event then
    widget.background()
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif not getLogicalSwitchValue(LS_CTR) then
    setStickySwitch(LS_CTR, true)
    slider.value = model.getGlobalVariable(GV_BRK, 0)
  end

  gui.run(event, touchState)
end -- refresh(...)

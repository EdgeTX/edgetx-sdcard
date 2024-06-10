---------------------------------------------------------------------------
-- SoarETX Adjust airbrake curves for flaps and ailerons                 --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-08-20                                                   --
-- Version: 1.0.2                                                        --
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
local gui =     libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Airbrake curves"

-- Screen drawing constants
local HEADER =    40
local TOP =       50
local MARGIN =    20
local DIST_X =    40
local HEIGHT =    150
local WIDTH =     (LCD_W - 3 * DIST_X) / 2
local BUTTON_W =  80
local BUTTON_X =  LCD_W - BUTTON_W - MARGIN
local BUTTON_H =  36
local BUTTON_Y =  (LCD_H + TOP + HEIGHT - BUTTON_H) / 2
local TEXT_Y =    BUTTON_Y

-- Global variables
local INP_STEP = getFieldInfo("input8").id 	-- Step input for selecting curve point
local LS_STEP = 11                          -- Set this LS to apply step input
local N = 5 																-- Number of points on the curves
local MAX_Y = 100   												-- Max plot value
local CRV_FLP = 4 													-- Index of the  flap curve
local CRV_AIL = 5 													-- Index of the  aileron curve
local tblFlp 																-- Table with data for the flap curve
local tblAil 																-- Table with data for the aileron curve
local activeP   														-- The point currently being edited
local stepOn = false												-- Step input has be turned on by this widget

-- Turn off step input (if it was turned on by this widget)
local function stepOff()
	if stepOn then
		stepOn = false
		setStickySwitch(LS_STEP, false)
	end
end

-- Make sure that we have the right number of points on the curve
local function GetCurve(crvIndex)
	local tbl = soarGlobals.getCurve(crvIndex)

  if #tbl.y ~= N then
    stepOff()
    error("Wrong number of points on curve CV" .. crvIndex + 1)
  end

	return tbl
end -- GetCurve()

local function init()
	tblFlp = GetCurve(CRV_FLP)
	tblAil = GetCurve(CRV_AIL)
	setStickySwitch(LS_STEP, true)
	stepOn = true
end -- init()

local function drawCurve(x, y, w, h, yValues)
  -- Background and lines
  gui.drawFilledRectangle(x, y, w + 1, h, colors.primary2)
  gui.drawRectangle(x, y, w + 1, h, COLOR_THEME_SECONDARY2)

  gui.drawLine(x + 0.25 * w, y, x + 0.25 * w, y + h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x + 0.50 * w, y, x + 0.50 * w, y + h, SOLID, COLOR_THEME_SECONDARY2)
  gui.drawLine(x + 0.75 * w, y, x + 0.75 * w, y + h, DOTTED, COLOR_THEME_SECONDARY2)

  gui.drawLine(x, y + 0.1667 * h, x + w, y + 0.1667 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.3333 * h, x + w, y + 0.3333 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.5000 * h, x + w, y + 0.5000 * h, SOLID, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.6667 * h, x + w, y + 0.6667 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.8333 * h, x + w, y + 0.8333 * h, DOTTED, COLOR_THEME_SECONDARY2)

  -- And now to the curve
  local xs = { }
  local ys = { }

  for i = 1, N do
    xs[i] = x + math.floor(w * (i - 1) / (N - 1) + 0.5)
    ys[i] = y + math.floor(h * 0.5 * (1 - yValues[i] / MAX_Y) + 0.5)
  end

  for i = 2, N do
    gui.drawLine(xs[i - 1], ys[i - 1], xs[i], ys[i], SOLID, COLOR_THEME_SECONDARY1, 3)
  end

  for i = 1, N do
    if i == activeP then
      gui.drawFilledCircle(xs[i], ys[i], 4, colors.edit)
      gui.drawCircle(xs[i], ys[i], 5, COLOR_THEME_SECONDARY1)
      gui.drawCircle(xs[i], ys[i], 4, COLOR_THEME_SECONDARY1)
    else
      gui.drawFilledCircle(xs[i], ys[i], 2, colors.primary2)
      gui.drawCircle(xs[i], ys[i], 3, COLOR_THEME_SECONDARY1)
      gui.drawCircle(xs[i], ys[i], 2, COLOR_THEME_SECONDARY1)
    end
  end
end -- drawCurve()

-- Adjust a point, either on a curve or output
local function adjustPoint(crvIdx, crvTbl, slider)
  crvTbl.y[activeP] = slider.value
  model.setCurve(crvIdx, crvTbl)
end

-- Reset curves to defaults
local function reset()
	local ys = { -100, -50, 0, 25, 50 }
	for i, y in ipairs(ys) do
		tblFlp.y[i] = y
	end
	model.setCurve(CRV_FLP, tblFlp)

	ys = { -50, -50, -50, -25, 0 }
	for i, y in ipairs(ys) do
		tblAil.y[i] = y
	end
	model.setCurve(CRV_AIL, tblAil)
end
-------------------------------- Setup GUI --------------------------------

do
  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

		-- Curves
    drawCurve(DIST_X, TOP, WIDTH, HEIGHT, tblFlp.y)
		lcd.drawText(DIST_X + 2, TOP, "Flaps", SMLSIZE + colors.primary1)

    drawCurve(WIDTH + 2 * DIST_X, TOP, WIDTH, HEIGHT, tblAil.y)
		lcd.drawText(WIDTH + 2 * DIST_X + 2, TOP, "Aileron", SMLSIZE + colors.primary1)

    -- Help text
    local txt = "Use the throttle stick to select a point on the\n" ..
                "curve, and adjust with the sliders on the screen."
    lcd.drawTextLines(MARGIN, TEXT_Y, BUTTON_X - MARGIN, LCD_H - TEXT_Y, txt, colors.primary1)
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

	-- Sliders
	local flpSlider = gui.verticalSlider(MARGIN, TOP, HEIGHT, 0, -100, 100, 1, function(slider) adjustPoint(CRV_FLP, tblFlp, slider) end)

  function flpSlider.update()
    flpSlider.value = tblFlp.y[activeP]
  end

  local ailSlider = gui.verticalSlider(LCD_W - MARGIN, TOP, HEIGHT, 0, -100, 100, 1, function(slider) adjustPoint(CRV_AIL, tblAil, slider) end)

  function ailSlider.update()
    ailSlider.value = tblAil.y[activeP]
  end

  gui.button(BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, "Reset", reset)
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  stepOff()
end -- background()

function widget.refresh(event, touchState)
  if not event then
    widget.background()
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif not getLogicalSwitchValue(LS_STEP) then
    init()
    return
  end

  activeP = math.floor((N - 1) / 2048 * (getValue(INP_STEP) + 1024) + 1.5)
  gui.run(event, touchState)
end -- refresh(...)

---------------------------------------------------------------------------
-- SoarETX flaperon alignment, loadable component                        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-06-26                                                   --
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
libGUI.flags =  MIDSIZE
local gui = libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Wing alignment"

-- Screen drawing constants
local HEADER =    40
local TOP =       50
local MARGIN =    20
local DIST_X =    40
local HEIGHT =    150
local WIDTH =     (LCD_W - 3 * DIST_X) / 2
local TEXT_Y =    210
local BUTTON_W =  80
local BUTTON_X =  LCD_W - BUTTON_W - MARGIN
local BUTTON_H =  36
local BUTTON_Y =  (LCD_H + TOP + HEIGHT - BUTTON_H) / 2

-- Other constants
local INP_STEP = getFieldInfo("input7").id  -- Step input
local LS_STEP = 10                          -- Set this LS to apply step input and adjust
local N = 5                                 -- Number of curve points
local MAX_Y = 1500                          -- Max output value
local MINDIF = 100                          -- Minimum difference between lower, center and upper values
local NC = 32																-- Number of channels

-- Flaperon curve indices
local CRV_LFT = 0
local CRV_RGT = 1
-- Tables with data for flaperon curves
local lftCrv
local rgtCrv
-- Indices of output channels
local lftOutIdx
local rgtOutIdx
-- Tables with data for flaperon output channels
local lftOut
local rgtOut
-- Tables with y-values after both curve and output settings have been applied
local lftYs = { }
local rgtYs = { }
local activeP   -- The point currently being edited

-- Make sure that we have the right number of points on the curve
local function GetCurve(crvIndex)
	local tbl = soarGlobals.getCurve(crvIndex)

  if #tbl.y ~= N then
    setStickySwitch(LS_STEP, false)
    gui= nil
    error("Wrong number of points on curve CV" .. crvIndex + 1)
  end

	return tbl
end -- GetCurve()

-- Find the output where the specified curve index is being used
local function GetOutput(crvIndex)
	for i = 0, NC - 1 do
		local out = model.getOutput(i)

		if out and out.curve == crvIndex then
			return i, out
		end
	end

  setStickySwitch(LS_STEP, false)
  error("No output channel with curve CV" .. crvIndex + 1)
end -- GetOutput()

local function init()
	lftCrv = GetCurve(CRV_LFT)
	lftOutIdx, lftOut = GetOutput(CRV_LFT)
	rgtCrv = GetCurve(CRV_RGT)
	rgtOutIdx, rgtOut = GetOutput(CRV_RGT)
  setStickySwitch(LS_STEP, true)
end -- init()

-- Find index of the curve point that corresponds to the value of the step input
local function FindPoint()
	local x = getValue(INP_STEP)
	return math.floor((N - 1) / 2048 * (x + 1024) + 1.5)
end -- FindPoint()

-- Compute output after applying curve and center/endpoints
local function ComputeYs(crv, out, y)
	for p = 1, N do
		if crv.y[p] < 0 then
			y[p] = out.offset + 0.01 * crv.y[p] * (out.offset - out.min)
		else
			y[p] = out.offset + 0.01 * crv.y[p] * (out.max - out.offset)
		end
	end
end -- ComputeYs()

-- Reverse curve points on the left side
local function reverse(ys)
  for i = 1, math.floor((N + 1) / 2) do
    ys[i], ys[N + 1 - i] = -ys[N + 1 - i], -ys[i]
  end
end

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

-- Adjustment is +/-750 around this offset
local function offset()
  local ctr = (N + 1) / 2
  return (activeP - ctr) * 750 / (ctr - 1)
end

-- Adjust a point, either on a curve or output
local function adjustPoint(crvIdx, crvTbl, outIdx, outTbl, activeP, y)
  if activeP == 1 then
    outTbl.min = math.min(y, outTbl.offset - MINDIF)
    model.setOutput(outIdx, outTbl)
  elseif activeP == (N + 1) / 2 then
    outTbl.offset = math.min(math.max(y, outTbl.min + MINDIF), outTbl.max - MINDIF)
    model.setOutput(outIdx, outTbl)
  elseif activeP == N then
    outTbl.max = math.max(y, outTbl.offset + MINDIF)
    model.setOutput(outIdx, outTbl)
  else
    crvTbl.y[activeP] = 0.1 * y
    model.setCurve(crvIdx, crvTbl)
  end
end

-- Adjust the reversed left curve
local function adjLft(slider)
  adjustPoint(CRV_LFT, lftCrv, lftOutIdx, lftOut, N + 1 - activeP, -slider.value - offset())
end

-- Adjust the right curve
local function adjRgt(slider)
  adjustPoint(CRV_RGT, rgtCrv, rgtOutIdx, rgtOut, activeP, slider.value + offset())
end

-- The inverse function of adjust to set slider value from current settings
local function sliderPoint(crvTbl, outTbl, reverse)
  local value
  local activeP = activeP

  if reverse then
    activeP = N + 1 - activeP
  end

  if activeP == 1 then
    value = outTbl.min
  elseif activeP == (N + 1) / 2 then
    value = outTbl.offset
  elseif activeP == N then
    value = outTbl.max
  else
    value = 10 * crvTbl.y[activeP]
  end

  if reverse then
    value = -value
  end

  return 10 * math.floor(0.1 * (value - offset()) + 0.5)
end

-- Reset outputs
local function reset()
  local midpt = (N + 1) / 2

	for p = 1, N do
    local y = 200.0 / (N - 1) * (p - midpt)
		lftCrv.y[p] = y
		rgtCrv.y[p] = y
	end
	model.setCurve(CRV_RGT, rgtCrv)
	model.setCurve(CRV_LFT, lftCrv)

	lftOut.min = -1000
	lftOut.offset = 0
	lftOut.max = 1000
	model.setOutput(lftOutIdx, lftOut)

	rgtOut.min = -1000
	rgtOut.offset = 0
	rgtOut.max = 1000
	model.setOutput(rgtOutIdx, rgtOut)

	init()
end -- Reset()

-------------------------------- Setup GUI --------------------------------

do
  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Curves
    drawCurve(DIST_X, TOP, WIDTH, HEIGHT, lftYs)
    drawCurve(WIDTH + 2 * DIST_X, TOP, WIDTH, HEIGHT, rgtYs)

    -- Help text
    local txt = "Use the throttle stick to select a point on the\n" ..
                "curve, and adjust with the sliders on the screen.\n" ..
                "First end points, then center, and finally +/-50%."
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

  local lftSlider = gui.verticalSlider(MARGIN, TOP, HEIGHT, 0, -750, 750, 10, adjLft)

  function lftSlider.update()
    lftSlider.value = sliderPoint(lftCrv, lftOut, true)
  end

  local rgtSlider = gui.verticalSlider(LCD_W - MARGIN, TOP, HEIGHT, 0, -750, 750, 10, adjRgt)

  function rgtSlider.update()
    rgtSlider.value = sliderPoint(rgtCrv, rgtOut, false)
  end

  gui.button(BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, "Reset", reset)
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  if getLogicalSwitchValue(LS_STEP) then
    setStickySwitch(LS_STEP, false)
  end
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

  activeP = FindPoint()
  ComputeYs(lftCrv, lftOut, lftYs)
  reverse(lftYs)
  ComputeYs(rgtCrv, rgtOut, rgtYs)

  gui.run(event, touchState)
end -- refresh(...)

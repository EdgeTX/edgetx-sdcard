---------------------------------------------------------------------------
-- SoarETX flaps and aileron alignment, loadable component               --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2024-01-20                                                   --
-- Version: 1.2.4                                                        --
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
local gui = nil
local colors =  libGUI.colors
local title =   "Wing alignment"
local modelType = ""

-- Screen drawing constants
local HEADER =    40
local TOP =       50
local MARGIN =    20
local DIST_X =    25
local HEIGHT =    150
local WIDTH =     (LCD_W - 4.5 * DIST_X) / 4
local TEXT_Y =    210
local BUTTON_W =  80
local BUTTON_X =  LCD_W - BUTTON_W - MARGIN
local BUTTON_H =  36
local BUTTON_Y =  (LCD_H + TOP + HEIGHT - BUTTON_H) / 2

-- Other constants
local INP_STEP = getFieldInfo("input8").id  -- Step input
local LS_STEP = nil                         -- Set this LS to apply step input and adjust
local GV_ADJUST = nil
local N = 5                                 -- Number of curve points
local MAX_Y = 1500                          -- Max output value
local MINDIF = 100                          -- Minimum difference between lower, center and upper values
local NC = 32																-- Number of channels

-- Flaperon curve indices (LA, LF, RF, RA)
local CRV_IDX = { 0, 2, 3, 1 }
-- Tables with data for flaperon curves
local crvTbls = { {}, {}, {}, {} }
-- Indices of output channels
local outIds = { {}, {}, {}, {} }
-- Tables with data for flaperon output channels
local outTbls = { {}, {}, {}, {} }
-- Tables with y-values after both curve and output settings have been applied
local yVals = { {}, {}, {}, {} }
-- The point currently being edited
local activeP
-- Labels for curve plots
local labels = {
	"Lft ail",
	"Lft flp",
	"Rgt flp",
	"Rgt ail"
}

-- Step Adjusting input has be turned on by this widget
local function isAdjustin()
  local r = false
  if (LS_STEP ~= nil) then r = getStickySwitch(LS_STEP)
  elseif (GV_ADJUST ~= nil) then r = model.getGlobalVariable(GV_ADJUST, 0)==1 end
  return r
end

-- Turn off step input (if it was turned on by this widget)
local function stepOff()
  if (LS_STEP ~= nil) then setStickySwitch(LS_STEP, false) end
  if (GV_ADJUST ~= nil) then model.setGlobalVariable(GV_ADJUST, 0, 0) end
end

local function stepOn()
  if (LS_STEP ~= nil) then setStickySwitch(LS_STEP, true) end
  if (GV_ADJUST ~= nil) then model.setGlobalVariable(GV_ADJUST, 0, 1) end
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

-- Find the output where the specified curve index is being used
local function GetOutput(crvIndex)
	for i = 0, NC - 1 do
		local out = model.getOutput(i)

		if out and out.curve == crvIndex then
			return i, out
		end
	end

  stepOff()
  error("No output channel with curve CV" .. crvIndex + 1)
end -- GetOutput()

local function init()
	for i, j in ipairs(CRV_IDX) do
		crvTbls[i] = GetCurve(j)
		outIds[i], outTbls[i] = GetOutput(j)
	end

  stepOn()
end -- init()

-- Find index of the curve point that corresponds to the value of the step input
local function FindPoint()
	local x = getValue(INP_STEP)
	return math.floor((N - 1) / 2048 * (x + 1024) + 1.5)
end -- FindPoint()

-- Compute output after applying curve and center/endpoints
local function ComputeYs()
	for i, j in ipairs(CRV_IDX) do
		local crv = crvTbls[i]
		local out = outTbls[i]
		local y = yVals[i]

		for p = 1, N do
			if crv.y[p] < 0 then
				y[p] = out.offset + 0.01 * crv.y[p] * (out.offset - out.min)
			else
				y[p] = out.offset + 0.01 * crv.y[p] * (out.max - out.offset)
			end
		end

		if i <= 2 then
			-- Reverse curve points on the left side
			for k = 1, math.floor((N + 1) / 2) do
		    y[k], y[N + 1 - k] = -y[N + 1 - k], -y[k]
		  end
		end
	end
end -- ComputeYs()

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
local function adjustPoint(i, slider)
	local crvIdx = CRV_IDX[i]
	local crvTbl = crvTbls[i]
	local outIdx = outIds[i]
	local outTbl = outTbls[i]
	local activeP = activeP
	local y = slider.value + offset()

	if i <= 2 then
		-- Left side; reverse
		activeP = N + 1 - activeP
		y = -y
	end

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

-- The inverse function of adjust to set slider value from current settings
local function sliderPoint(i)
	local crvTbl = crvTbls[i]
	local outTbl = outTbls[i]
	local activeP = activeP
  local value

  if i <= 2 then
		-- Left side; reverse
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

  if i <= 2 then
    value = -value
  end

  return 10 * math.floor(0.1 * (value - offset()) + 0.5)
end

-- Reset outputs
local function reset()
  local midpt = (N + 1) / 2

	for i, j in ipairs(CRV_IDX) do
		local crvTbl = crvTbls[i]
		for p = 1, N do
	    local y = 200.0 / (N - 1) * (p - midpt)
			crvTbl.y[p] = y
		end
		model.setCurve(j, crvTbl)

		local outTbl = outTbls[i]
		outTbl.min = -1000
		outTbl.offset = 0
		outTbl.max = 1000
		model.setOutput(outIds[i], outTbl)
	end

	init()
end -- Reset()

-------------------------------- Setup GUI --------------------------------

local function setup_gui()
  gui = libGUI.newGUI()

  -- Extract Model Type from parametes
  modelType = widget.options.Type
  if modelType == "F3K_FH" then
    LS_STEP = 10 -- L11
  elseif modelType == "F3J" or modelType == "F5J" then
    GV_ADJUST = 7 -- GV8:Adj
  else
    LS_STEP = nil
    modelType = "F??"
  end

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title.." "..modelType, bit32.bor(DBLSIZE, colors.primary2))

    -- Curves
		for i, j in ipairs(CRV_IDX) do
			local x = (i - 1) * (DIST_X + WIDTH) + DIST_X
			if i > 2 then
				x = x - DIST_X / 2
			end
			drawCurve(x, TOP, WIDTH, HEIGHT, yVals[i])
			lcd.drawText(x + 2, TOP, labels[i], SMLSIZE + colors.primary1)
		end

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

	-- Sliders
	for i, j in ipairs(CRV_IDX) do
		local x = DIST_X / 2 + (i - 1) * (DIST_X + WIDTH)
		if i > 2 then
			x = x + WIDTH + DIST_X / 2
		end
	  local slider = gui.verticalSlider(x, TOP, HEIGHT, 0, -750, 750, 10, function(slider) adjustPoint(i, slider) end)

	  function slider.update()
	    slider.value = sliderPoint(i)
	  end
	end

  gui.button(BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, "Reset", reset)
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  gui=nil
	stepOff()
end -- background()

function widget.refresh(event, touchState)
  if not event then
    widget.background()
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif gui == nil then
    setup_gui()
    init()
    return
  end

  activeP = FindPoint()
  ComputeYs()

  gui.run(event, touchState)
end -- refresh(...)

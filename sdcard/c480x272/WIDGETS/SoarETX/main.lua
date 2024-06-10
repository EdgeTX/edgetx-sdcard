---------------------------------------------------------------------------
-- SoarETX widget                                                        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Improvements: Frankie Arzu                                            --
-- Date:    2024-01-15                                                   --
-- Version: 1.2.0                                                        --
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

local options = {
  { "Version", VALUE, 1, 1, 2 },
  { "FileName", STRING, "" },
  { "Type", STRING, "" }          --  F3K|F3K_TRAD|F3K_FH|F3K_RE|F3J|F5J
}

local soarGlobals

-- Battery - moved here from battery.lua because of bugs in ETX not calling background() on topbar widgets
local rxBatNxtWarn = 0
local rxBatNxtCheck = 0

function rxBatCheck()
  local now = getTime()

	if now < rxBatNxtCheck then
		return
	end

	rxBatNxtCheck = now + 100

	local rxBatSrc = getFieldInfo("Cels")
	if not rxBatSrc then rxBatSrc = getFieldInfo("RxBt") end
	if not rxBatSrc then rxBatSrc = getFieldInfo("A1") end
	if not rxBatSrc then rxBatSrc = getFieldInfo("A2") end

  if rxBatSrc then
    soarGlobals.battery = getValue(rxBatSrc.id)

    if type(soarGlobals.battery) == "table" then
      for i = 2, #soarGlobals.battery do
        soarGlobals.battery[1] = math.min(soarGlobals.battery[1], soarGlobals.battery[i])
      end
      soarGlobals.battery = soarGlobals.battery[1]
    end
  end

  -- Warn about low receiver battery
	local rxBatMin = 0.1 * (soarGlobals.getParameter(soarGlobals.batteryParameter) + 100)
  if now > rxBatNxtWarn and soarGlobals.battery > 0 and soarGlobals.battery < rxBatMin then
    playHaptic(200, 0, 1)
    playFile("lowbat.wav")
    playNumber(10 * soarGlobals.battery + 0.5, 1, PREC1)
    rxBatNxtWarn = now + 2000
  end
end -- rxBatCheck()

-- Load a Lua component dynamically based on option values
local function Load(widget)
  local chunk, errMsg = loadScript(soarGlobals.path .. widget.options.Version .. "/" .. widget.options.FileName .. ".lua")
  if errMsg then
    widget.errMsg = errMsg
  else
    chunk(widget, soarGlobals)
  end
end

local function GetCurve(crvIndex)
  local N = 5

  local oldTbl = model.getCurve(crvIndex)

  if #oldTbl.y == N then -- Normal Behaviour
    return oldTbl
  end

  -- Work arround the bug of GetCurve in some versions (2.8.3) of ETX
  if #oldTbl.y == N - 1 then
    local newTbl = { }
    newTbl.y = { }
    for p = 1, N do
      newTbl.y[p] = oldTbl.y[p - 1]
    end
    newTbl.smooth = 1
    newTbl.name = oldTbl.name
    return newTbl
  end

  return oldTbl
end -- GetCurve()


-- Initialize the first time this widget is instantiated
local function init()
  soarGlobals = {
    path = "/WIDGETS/SoarETX/",
    battery = 0,
    batteryParameter = 1,
    getCurve = GetCurve
  }
  soarGlobals.libGUI = loadScript("/WIDGETS/SoarETX/libgui.lua")()
  local gui = soarGlobals.libGUI.newGUI()


  -- Functions to handle persistent model parameters stored in curve 32
  local parameterCurve = GetCurve(31)

  if not parameterCurve then
    error("Curve #32 is missing! It is used to store persistent model parameters for Lua.")
  end

  function soarGlobals.getParameter(idx)
    return parameterCurve.y[idx]
  end

  function soarGlobals.setParameter(idx, value)
    parameterCurve.y[idx] = value
    model.setCurve(31, parameterCurve)
  end
end


local function create(zone, options)
  if not soarGlobals then
    init()
  end

  local widget = {
    zone = zone,
    options = options
  }
  Load(widget)
  return widget
end

local function update(widget, options)
  if options.Version ~= widget.options.Version or options.FileName ~= widget.options.FileName then
    local zone = widget.zone

    -- Erase all fields in widget
    local keys = { }
    for key in pairs(widget) do
      keys[#keys + 1] = key
    end
    for i, key in ipairs(keys) do
      widget[key] = nil
    end

    widget.zone = zone
    widget.options = options
    Load(widget)
  end
end

local function refresh(widget, event, touchState)
  if widget.errMsg then
    lcd.drawTextLines(0, 0, widget.zone.w, widget.zone.h, widget.errMsg .. "\nPlease check widget settings!", COLOR_THEME_WARNING)
  else
    widget.refresh(event, touchState)
  end
end

local function background(widget)
	rxBatCheck()

  if widget.background then
    widget.background()
  end
end

return {
  name = "SoarETX",
  create = create,
  refresh = refresh,
  options = options,
  update = update,
  background = background
}

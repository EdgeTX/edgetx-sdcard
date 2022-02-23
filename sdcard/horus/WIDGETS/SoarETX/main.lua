---------------------------------------------------------------------------
-- SoarETX widget                                                        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-08                                                   --
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

local options = {
  { "Version", VALUE, 1, 1, 99 },
  { "FileName", STRING, "" }
}
local soarGlobals

-- Load a Lua component dynamically based on option values
local function Load(widget)
  local chunk, errMsg = loadScript(soarGlobals.path .. widget.options.Version .. "/" .. widget.options.FileName .. ".lua")
  if errMsg then
    widget.errMsg = errMsg
  else
    chunk(widget, soarGlobals)
  end
end

-- Initialize the first time this widget is instantiated
local function init()
  soarGlobals = {
    path = "/WIDGETS/SoarETX/",
    battery = 0,
    batteryParameter = 1
  }

  -- Functions to handle persistent model parameters stored in curve 32
  local parameterCurve = model.getCurve(31)
  
  if not parameterCurve then
    error("Curve #32 is missing! It is used to store persistent model parameters for Lua.")
  end
  
  -- Work around the stupid fact that getCurve and setCurve tables are incompatible...
  local y = parameterCurve.y
  parameterCurve.y = { }
  for i = 1, parameterCurve.points do
    parameterCurve.y[i] = y[i - 1]
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
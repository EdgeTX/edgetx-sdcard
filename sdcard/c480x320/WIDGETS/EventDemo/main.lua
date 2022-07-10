---------------------------------------------------------------------------
-- Lua widget to demonstrate handling of key and touch events in full    --
-- screen mode.                                                          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-XX-XX                                                   --
-- Version: 0.9                                                          --
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

local name = "EventDemo"

local function create(zone, options)
  -- Loadable code chunk is called immediately and returns a widget table
  return loadScript("/WIDGETS/" .. name .. "/loadable.lua")(zone, options)
end

local function refresh(widget, event, touchState)
  widget.refresh(event, touchState)
end

local options = {
  { "size", VALUE, 30, 5, 100 }
}

local function update(widget, options)
  widget.update(options)
end

local function background(widget)
end

return {
  name = name, 
  create = create, 
  refresh = refresh, 
  options = options, 
  update = update, 
  background = background
}
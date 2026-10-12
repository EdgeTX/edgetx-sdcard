---------------------------------------------------------------------------
-- Control serial port power via touch or keys.                          --
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

-- Every widget's main.lua is loaded at boot, so this only holds the name and
-- options. The widget code lives in app.lua and is loaded on create().

local name = "SerialPower"

local options = {
  { "Color", COLOR, COLOR_THEME_PRIMARY1 },
}

local function create(zone, options)
  local tool = assert(loadScript("/WIDGETS/" .. name .. "/app.lua", "btd"))()
  local wgt = tool.create(zone, options)
  wgt._tool = tool
  return wgt
end
local function update(wgt, options) return wgt._tool.update(wgt, options) end
local function refresh(wgt, event, touchState) return wgt._tool.refresh(wgt, event, touchState) end

return { name = name, options = options, create = create, update = update, refresh = refresh, useLvgl = true }

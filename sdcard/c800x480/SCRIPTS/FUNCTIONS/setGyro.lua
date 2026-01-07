--
-- Copyright (C) EdgeTX
--
-- Based on code named
--   opentx - https://github.com/opentx/opentx
--   th9x - http://code.google.com/p/th9x
--   er9x - http://code.google.com/p/er9x
--   gruvin9x - http://code.google.com/p/gruvin9x
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 2 as
-- published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--

local function my_init()
  -- Called once when the script is loaded
end

-- set X range to 120° (60° both sides), centered on default position
-- set Y range to 90° (45° both sides), centered on current position
local function my_run()
  setIMU_X(0, 180)
  setIMU_Y(-1, 90)
end

local function my_background()
  -- Called periodically while the Special Function switch is off
end

return { run = my_run, background = my_background, init = my_init }
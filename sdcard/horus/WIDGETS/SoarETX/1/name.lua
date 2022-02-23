---------------------------------------------------------------------------
-- SoarETX model name, loadable component                                --
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

local widget =  ...
local name = model.getInfo().name
local att = SMLSIZE

for i, a in ipairs({ DBLSIZE, MIDSIZE, BOLD, 0 }) do
  local w = lcd.sizeText(name, a)
  if w <= widget.zone.w then
    att = a
    break
  end
end

att = att + VCENTER + COLOR_THEME_PRIMARY2

function widget.refresh(event, touchState)
  lcd.drawText(0, widget.zone.h / 2, name, att)
end -- refresh(...)

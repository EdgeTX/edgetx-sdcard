---------------------------------------------------------------------------
-- SoarETX, loadable component                                           --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-11-21                                                   --
-- Version: 1.0.1                                                         --
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

function widget.refresh(event, touchState)
  if event then
    lcd.exitFullScreen()
  end
  local flags = CENTER + VCENTER + MIDSIZE
  if soarGlobals.battery and soarGlobals.battery > 0 then
    flags = flags + COLOR_THEME_PRIMARY2
  else
    flags = flags + COLOR_THEME_DISABLED
  end  
  lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, string.format("%1.1f V", soarGlobals.battery), flags)
end -- refresh(...)

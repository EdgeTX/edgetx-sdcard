---------------------------------------------------------------------------
-- SoarETX, loadable component                                           --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-17                                                   --
-- Version: 1.0.0                                                         --
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

-- Battery variables
local rxBatSrc
local rxBatNxtWarn = 0

local function getWarningLevel()
  return 0.1 * (soarGlobals.getParameter(soarGlobals.batteryParameter) + 100)
end

function widget.background()
  local now = getTime()
  
  -- Receiver battery
  if not rxBatSrc then 
    rxBatSrc = getFieldInfo("Cels")
    if not rxBatSrc then rxBatSrc = getFieldInfo("RxBt") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A1") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A2") end
  end
  
  if rxBatSrc then
    soarGlobals.battery = getValue(rxBatSrc.id)
    
    if type(soarGlobals.battery) == "table" then
      for i = 2, #soarGlobals.battery do
        soarGlobals.battery[1] = math.min(soarGlobals.battery[1], soarGlobals.battery[i])
      end
      soarGlobals.battery = soarGlobals.battery[1]
    end
  end

  -- Warn about low receiver battery or Rx off
  if now > rxBatNxtWarn and soarGlobals.battery > 0 and soarGlobals.battery < getWarningLevel() then
    playHaptic(200, 0, 1)
    playFile("lowbat.wav")
    playNumber(10 * soarGlobals.battery + 0.5, 1, PREC1)
    rxBatNxtWarn = now + 2000
  end
end -- background()

function widget.refresh(event, touchState)
  widget.background()
  
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

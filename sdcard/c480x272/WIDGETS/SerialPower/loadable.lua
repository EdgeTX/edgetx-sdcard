---------------------------------------------------------------------------
-- Control serial port power via touch.                                  --
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
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- zone and options were passed as arguments to chunk(...)
local zone, options = ...

-- Miscellaneous constants
local HEADER = 40
local WIDTH  = 200
local HEIGHT = 50
local AUX1   = 0
local AUX2   = 1
local HIGH   = 1
local LOW    = 0
local ON     = "On"
local OFF    = "Off"
local NA     = "N/A"

-- The widget table will be returned to the main script
local widget = { }

-- Load the GUI library by calling the global function declared in the main script.
-- As long as LibGUI is on the SD card, any widget can call loadGUI() because it is global.
local libGUI = loadGUI()

-- Instantiate a new GUI object
local gui = libGUI.newGUI()

-- Make a minimize button from a custom element
local custom = gui.custom({ }, LCD_W - 34, 6, 28, 28)

function custom.draw(focused)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, libGUI.colors.primary2)
  lcd.drawFilledRectangle(LCD_W - 30, 19, 20, 3, libGUI.colors.primary2)
  if focused then
    custom.drawFocus()
  end
end

function custom.onEvent(event, touchState)
  if event == EVT_VIRTUAL_ENTER then
    lcd.exitFullScreen()
  end
end

local aux1pwrstate = 0;
local aux2pwrstate = 0;

-- AUX power state
function readSerPwrState()
  if serialGetPower ~= nil then
    if serialGetPower(AUX1) ~= nil then
	  if serialGetPower(AUX1) then
	    aux1pwrstate = 1
	  else
	    aux1pwrstate = 0
	  end
    else
      aux1pwrstate = -1
    end
    if serialGetPower(AUX2) ~= nil then
	  if serialGetPower(AUX2) then
	    aux2pwrstate = 1
	  else
	    aux2pwrstate = 0
	  end
    else
      aux2pwrstate = -1
	end
  else
    aux1pwrstate = -1
    aux2pwrstate = -1
  end
end

function aux1cb()
  if (serialGetPower ~= nil and serialSetPower ~= nil) then
    if serialGetPower(AUX1) then
	  serialSetPower(AUX1, LOW)
    else
      serialSetPower(AUX1, HIGH)
    end
  end
end

function aux2cb()
  if (serialGetPower ~= nil and serialSetPower ~= nil) then
    if serialGetPower(AUX2) then
      serialSetPower(AUX2, LOW)
    else
      serialSetPower(AUX2, HIGH)
    end
  end
end

local aux1powerButton = gui.button(5, 50, WIDTH, HEIGHT, "AUX1 power", aux1cb, VCENTER + DBLSIZE + libGUI.colors.primary2)
local aux2powerButton = gui.button(5, 120, WIDTH, HEIGHT, "AUX2 Power", aux2cb, VCENTER + DBLSIZE + libGUI.colors.primary2)

function gui.fullScreenRefresh()
  -- Draw header
  lcd.drawFilledRectangle(0, 0, LCD_W, 40, COLOR_THEME_SECONDARY1)
  lcd.drawText(5, 20, "Serial port power demo", VCENTER + DBLSIZE + libGUI.colors.primary2)
  readSerPwrState()
  
  local text
  if aux1pwrstate == 0 then text = OFF end
  if aux1pwrstate == 1 then text = ON end
  if aux1pwrstate == -1 then text = NA end
  lcd.drawText(10+WIDTH, 50 + HEIGHT/2, text, DBLSIZE + VCENTER + libGUI.colors.primary1)
  
  if aux2pwrstate == 0 then text = OFF end
  if aux2pwrstate == 1 then text = ON end
  if aux2pwrstate == -1 then text = NA end
  lcd.drawText(10+WIDTH, 120 + HEIGHT/2, text, DBLSIZE + VCENTER + libGUI.colors.primary1)
end

-- Draw in widget mode
function libGUI.widgetRefresh()
  lcd.drawRectangle(0, 0, zone.w, zone.h, libGUI.colors.primary3)
  lcd.drawText(zone.w / 2, zone.h / 2, "Put me to fullscreen", DBLSIZE + CENTER + VCENTER + libGUI.colors.primary3)
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
  gui.run(event, touchState)
end

-- Return to the create(...) function in the main script
return widget

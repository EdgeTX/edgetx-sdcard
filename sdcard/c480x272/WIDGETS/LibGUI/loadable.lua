---------------------------------------------------------------------------
-- The dynamically loadable part of the demonstration Lua widget.        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-27                                                   --
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
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- This code chunk is loaded on demand by the LibGUI widget's main script
-- when the create(...) function is run. Hence, the body of this file is
-- executed by the widget's create(...) function.

-- zone and options were passed as arguments to chunk(...)
local zone, options = ...

-- Miscellaneous constants
local HEADER = 40
local WIDTH  = 100
local COL1   = 10
local COL2   = 130
local COL3   = 250
local COL4   = 370
local COL2s  = 120
local TOP    = 44
local ROW    = 28
local HEIGHT = 24

-- The widget table will be returned to the main script
local widget = { }

-- Load the GUI library.
-- Note: for backward & forward compatibility, each script should come with it's own version of libgui.
local libGUI = loadScript("/WIDGETS/LibGUI/libgui.lua")()


-- Instantiate a new GUI object
local gui = libGUI.newGUI()

-- Make a minimize button from a custom element
local custom = gui.custom({ }, LCD_W - 34, 6, 28, 28)

local function getLastSwitchIndex()
    local lastSwitch
    for switchIndex, switchName in switches(1, SWSRC_LAST) do
        if string.find(switchName, "^!?S[A-R][+-]?") then
            lastSwitch = switchIndex
        end
    end
    return lastSwitch
end

function custom.draw(focused)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, libGUI.colors.primary2)
  lcd.drawFilledRectangle(LCD_W - 30, 19, 20, 3, libGUI.colors.primary2)
  if focused then
    custom.drawFocus()
  end
end

function custom.onEvent(event, touchState)
  if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
    lcd.exitFullScreen()
  end
end

-- A timer
gui.label(COL1, TOP, WIDTH, HEIGHT, "Timer", BOLD)

local function timerChange(steps, timer)
  if steps < 0 then
    return (math.ceil(timer.value / 60) + steps) * 60
  else
    return (math.floor(timer.value / 60) + steps) * 60
  end
end

gui.timer(COL1, TOP + ROW, WIDTH, 1.4 * HEIGHT, 0, timerChange, DBLSIZE + RIGHT)

-- A sub-gui
gui.label(COL2, TOP, WIDTH, HEIGHT, "Group of elements", BOLD)
local subGUI = gui.gui(COL2, TOP + ROW, COL4 + WIDTH - COL3, 2 * ROW + HEIGHT)

-- A number that can be edited
subGUI.label(0, 0, WIDTH, HEIGHT, "Number:")
subGUI.number(COL2s, 0, WIDTH, HEIGHT, 0, nil, nil, -10, 10)

-- A drop-down with physical switches
subGUI.label(0, ROW, WIDTH, HEIGHT, "Drop-down:")
local labelDropDown = subGUI.label(0, 2 * ROW, 2 * WIDTH, HEIGHT, "")

local dropDownIndices = { }
local dropDownItems = { }
local lastSwitch = getLastSwitchIndex()

for i, s in switches(-lastSwitch, lastSwitch) do
  if i ~= 0 then
    local j = #dropDownIndices + 1
    dropDownIndices[j] = i
    dropDownItems[j] = s
  end
end

local function dropDownChange(dropDown)
  local i = dropDown.selected
  labelDropDown.title = "Selected switch: " .. dropDownItems[i] .. " [" .. dropDownIndices[i] .. "]"
end

local dropDown = subGUI.dropDown(COL2s, ROW, WIDTH, HEIGHT, dropDownItems, #dropDownItems / 2 + 1, dropDownChange)
dropDownChange(dropDown)

-- Menu that does nothing
gui.label(COL4, TOP, WIDTH, HEIGHT, "Menu", BOLD)

local menuItems = {
  "First",
  "Second",
  "Third",
  "Fourth",
  "Fifth",
  "Sixth",
  "Seventh",
  "Eighth",
  "Ninth",
  "Tenth"
}

gui.menu(COL4, TOP + ROW, WIDTH, 5 * ROW, menuItems, function(menu) playNumber(menu.selected, 0) end)

-- momentary button
gui.momentaryButton(COL1, TOP + 5 * ROW, WIDTH, HEIGHT, "Momentary");

-- Horizontal slider
gui.label(COL1, TOP + 6 * ROW, WIDTH, HEIGHT, "Horizontal slider:", BOLD)
local horizontalSliderLabel = gui.label(COL1 + 2 * WIDTH, TOP + 7 * ROW, 30, HEIGHT, "", RIGHT)

local function horizontalSliderCallBack(slider)
  horizontalSliderLabel.title = slider.value
end

local horizontalSlider = gui.horizontalSlider(COL1, TOP + 7 * ROW + HEIGHT / 2, 2 * WIDTH, 0, -20, 20, 1, horizontalSliderCallBack)
horizontalSliderCallBack(horizontalSlider)

-- Toggle button
local toggleButton = gui.toggleButton(COL3, TOP + 7 * ROW, WIDTH, HEIGHT, "Border", false, nil)

-- Prompt showing About text
local aboutPage = 1
local aboutText = {
  "LibGUI is a Lua library for creating graphical user interfaces for Lua widgets on EdgeTX transmitters with color screens. " ..
  "It is a code library embedded in a widget. Since all Lua widgets are always loaded into memory, whether they are used or not, " ..
  "the global function named 'loadGUI()', defined in the 'main.lua' file of this widget, is always available to be used by other widgets.",
  "The library code is implemented in the 'libgui.lua' file of this widget. This code is loaded on demand, i.e. it is only loaded if " ..
  "loadGUI() is called by a client widget to create a new libGUI Lua table object. That way, the library is not using much of " ..
  "the radio's memory unless it is being used. And since it is all Lua code, you can inspect the file yourself, if you are curious " ..
  "or you have found a problem.",
  "When you add the widget to your radio's screen, then this demo is loaded. It is implemented in the 'loadable.lua' file of this " ..
  "widget. Hence, like the LibGUI library itself, it does not waste your radio's memory, unless it is being used. And you can view " ..
  "the 'loadable.lua' file in the widget folder to see for yourself how this demo is loading LibGUI and using it, so you can start " ..
  "creating your own awesome widgets!",
   "Copyright (C) EdgeTX\n\nLicensed under GNU Public License V2:\nwww.gnu.org/licenses/gpl-2.0.html\n\nAuthored by Jesper Frickmann."
}

local aboutPrompt = libGUI.newGUI()

function aboutPrompt.fullScreenRefresh()
  lcd.drawFilledRectangle(40, 30, LCD_W - 80, 30, COLOR_THEME_SECONDARY1)
  lcd.drawText(50, 45, "About LibGUI  " .. aboutPage .. "/" .. #aboutText, VCENTER + MIDSIZE + libGUI.colors.primary2)
  lcd.drawFilledRectangle(40, 60, LCD_W - 80, LCD_H - 90, libGUI.colors.primary2)
  lcd.drawRectangle(40, 30, LCD_W - 80, LCD_H - 60, libGUI.colors.primary1, 2)
  lcd.drawTextLines(50, 70, LCD_W - 120, LCD_H - 110, aboutText[aboutPage])
end

-- Button showing About prompt
gui.button(COL4, TOP + 7 * ROW, WIDTH, HEIGHT, "About", function() gui.showPrompt(aboutPrompt) end)

-- Make a dismiss button from a custom element
local custom2 = aboutPrompt.custom({ }, LCD_W - 65, 36, 20, 20)

function custom2.draw(focused)
  lcd.drawRectangle(LCD_W - 65, 36, 20, 20, libGUI.colors.primary2)
  lcd.drawText(LCD_W - 55, 45, "X", MIDSIZE + CENTER + VCENTER + libGUI.colors.primary2)
  if focused then
    custom2.drawFocus()
  end
end

function custom2.onEvent(event, touchState)
  if event == EVT_VIRTUAL_ENTER then
    gui.dismissPrompt()
  end
end

-- Add a vertical slider to scroll pages
local function verticalSliderCallBack(slider)
  aboutPage = #aboutText + 1 - slider.value
end

local verticalSlider = aboutPrompt.verticalSlider(LCD_W - 60, 80, LCD_H - 130, #aboutText, 1, #aboutText, 1, verticalSliderCallBack)

-- Draw on the screen before adding gui elements
function gui.fullScreenRefresh()
  -- Draw header
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
  lcd.drawText(COL1, HEADER / 2, "LibGUI   Demo", VCENTER + DBLSIZE + libGUI.colors.primary2)

  -- Border
  if toggleButton.value then
    lcd.drawRectangle(0, HEADER, LCD_W, LCD_H - HEADER, libGUI.colors.edit, 5)
  end
end

-- Draw in widget mode
function libGUI.widgetRefresh()
  lcd.drawRectangle(0, 0, zone.w, zone.h, libGUI.colors.primary3)
  lcd.drawText(zone.w / 2, zone.h / 2, "LibGUI", DBLSIZE + CENTER + VCENTER + libGUI.colors.primary3)
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
    if event == nil then
        lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
        lcd.drawText(10, 40 / 2, "LibGUI  Demo", VCENTER + MIDSIZE + libGUI.colors.primary2)

        lcd.drawFilledRectangle(0, 50-5, 480, 60, RED, 90)
        lcd.drawText(10, 50, "change to full-screen")
        lcd.drawText(10, 70, "to see the widget")
        return
    end
    gui.run(event, touchState)
end

-- Return to the create(...) function in the main script
return widget

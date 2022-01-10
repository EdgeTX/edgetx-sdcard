---------------------------------------------------------------------------
-- Lua widget to demonstrate handling of key and touch events in full    --
-- screen mode.                                                          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-01-03                                                   --
-- Version: 1.0                                                          --
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

-- This code chunk is loaded on demand by the widget's main script when 
-- the create(...) function is run. Hence, the body of this file is
-- executed by the widget's create(...) function.

local zone, options = ... -- zone and options were passed as arguments to chunk(...).
local widget = { } -- The widget table will be returned to the main script.

local lastEvent = 0
local eventTime = 0
local x = LCD_W / 2
local y = LCD_H / 2
local stick
local animate

-- String identifying events
local function evt2str(event)
  if event == EVT_VIRTUAL_PREV then return "EVT_VIRTUAL_PREV"
  elseif event == EVT_VIRTUAL_NEXT then return "EVT_VIRTUAL_NEXT"
  elseif event == EVT_VIRTUAL_DEC then return "EVT_VIRTUAL_DEC"
  elseif event == EVT_VIRTUAL_INC then return "EVT_VIRTUAL_INC"
  elseif event == EVT_VIRTUAL_PREV_PAGE then return "EVT_VIRTUAL_PREV_PAGE"
  elseif event == EVT_VIRTUAL_NEXT_PAGE then return "EVT_VIRTUAL_NEXT_PAGE"
  elseif event == EVT_VIRTUAL_MENU then return "EVT_VIRTUAL_MENU"
  elseif event == EVT_VIRTUAL_ENTER then return "EVT_VIRTUAL_ENTER"
  elseif event == EVT_VIRTUAL_MENU_LONG then return "EVT_VIRTUAL_MENU_LONG"
  elseif event == EVT_VIRTUAL_ENTER_LONG then return "EVT_VIRTUAL_ENTER_LONG"
  elseif event == EVT_VIRTUAL_EXIT then return "EVT_VIRTUAL_EXIT"
  elseif event == EVT_TOUCH_FIRST then return "EVT_TOUCH_FIRST"
  elseif event == EVT_TOUCH_BREAK then return "EVT_TOUCH_BREAK"
  elseif event == EVT_TOUCH_TAP then return "EVT_TOUCH_TAP" 
  elseif event == EVT_TOUCH_SLIDE then return "EVT_TOUCH_SLIDE"
  else 
    local txt = string.format("Event = %i", event)
    return txt
  end
end

-- Sets a function to animate tap events on the square
local function TapAnimation(tapCount)
  local delta = 20
  local maxS = 250
  local s = options.size
  local txt
  
  if tapCount == 1 then
    txt = "Single tap"
  elseif tapCount == 2 then
    txt = "DOUBLE TAP!!"
  else
    txt = tapCount .. " TAPS!!!"
  end
    
  
  animate = function()
    lcd.drawText(x, y, txt, VCENTER + CENTER + DBLSIZE + ORANGE)
    s = s + delta
    lcd.drawRectangle(x - 0.5 * s, y - 0.5 * s, s, s)
    
    if s > maxS then
      animate = nil
    end
  end
end

-- Sets a function to animate swipe events shooting little bullets
local function SwipeAnimation(deltaX, deltaY)
  local x = x
  local y = y
  
  animate = function()
    local x2 = x + deltaX
    local y2 = y + deltaY
    
    lcd.drawLine(x, y, x2, y2, SOLID, 0)
    x, y = x2, y2
    
    if x < 0 or x > LCD_W or y < 0 or y > LCD_H then
      animate = nil
    end
  end
end

function widget.refresh(event, touchState)
  local s = options.size
  
  if event == nil then -- Widget mode; event == nil
    -- Draw a border using zone.w and zone.h
    lcd.drawRectangle(0, 0, zone.w, zone.h, COLOR_THEME_PRIMARY3)
    lcd.drawText(zone.w / 2, zone.h / 2, "Event Demo", DBLSIZE + CENTER + VCENTER + COLOR_THEME_PRIMARY3)

    lastEvent = 0    
  else -- Full screen mode. If no event happened then event == 0
    -- Draw a border using the full screen with LCD_W and LCD_H instead of zone.w and zone.h
    for i = 0, 2 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i)
    end
    
    if event ~= 0 then -- We got a new event
      -- Save the event for subsequent cycles and mark the time
      lastEvent = event
      eventTime = getTime()
    
      if touchState then -- Only touch events come with a touchState; otherwise touchState == nil
        if event == EVT_TOUCH_FIRST then -- When the finger first hits the screen
          -- If the finger hit the square, then stick to it!
          stick = (math.abs(touchState.x - x) < 0.5 * s and math.abs(touchState.y - y) < 0.5 * s)

        elseif event == EVT_TOUCH_BREAK then -- When the finger leaves the screen (and did not slide on it)
          if stick then
            playTone(100, 200, 100, PLAY_NOW, 10)
          end
          
        elseif event == EVT_TOUCH_TAP then -- A short tap on the screen gives TAP instead of BREAK
          -- If the finger hit the square, then play the animation
          if stick then
            playTone(200, 50, 100, PLAY_NOW)
            TapAnimation(touchState.tapCount)
          end
          
        elseif event == EVT_TOUCH_SLIDE then -- Sliding the finger gives a SLIDE instead of BREAK or TAP
          -- A fast vertical or horizontal slide gives a true swipe* value in touchState (only once per 500ms)
          if touchState.swipeRight then
            SwipeAnimation(20, 0)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeLeft then
            SwipeAnimation(-20, 0)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeUp then
            SwipeAnimation(0, -20)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeDown then
            SwipeAnimation(0, 20)
            playTone(10000, 200, 100, PLAY_NOW, -60)
          
          elseif stick then
            -- If the finger hit the square, then move it around. (x, y) is the current position
            x = touchState.x
            y = touchState.y
            
            -- (slideX, slideY) gives the finger movement since the previous slide event - draw a little tail
            lcd.drawLine(x - 3 * touchState.slideX, y - 3 * touchState.slideY, x, y, SOLID, 0)
            
            -- (startX, startY) is the point where the first slide event started - draw a square outline
            lcd.drawRectangle(touchState.startX - 0.5 * s, touchState.startY - 0.5 * s, s, s)
            
          end
        end
      end      
    end
    
    -- Double the size of the square while the finger is on it
    if lastEvent == EVT_TOUCH_FIRST and stick then
      s = 2 * s
    end

    -- Draw the square
    lcd.drawFilledRectangle(x - 0.5 * s, y - 0.5 * s, s, s)
    
    -- Show the last event for 4 sec. in the upper left corner
    if getTime() - eventTime < 400 then
      lcd.drawText(3, 3, evt2str(lastEvent))
    end
    
    -- If we have an active animation, run it
    if animate then 
      animate()
    end
  end
end

function widget.update(opt)
  options = opt
end

-- Return to the create(...) function in the main script
return widget
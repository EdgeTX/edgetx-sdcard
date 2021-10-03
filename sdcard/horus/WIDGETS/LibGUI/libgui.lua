---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-10-03                                                   --
-- Version: 0.99                                                         --
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

local lib = { }

-- Default flags and colors, can be changed by client
lib.flags = 0
lib.colors = {
  text = COLOR_THEME_PRIMARY3,
  focusText = COLOR_THEME_PRIMARY2,
  buttonBackground = COLOR_THEME_FOCUS,
  editBackground = COLOR_THEME_EDIT,
  active = COLOR_THEME_ACTIVE,
}

-- Return true if the first arg matches any of the following args
local function match(x, ...)
  for i, y in ipairs({...}) do
    if x == y then
      return true
    end
  end
  return false
end

lib.match = match

-- Create a new GUI object with interactive screen elements
-- The following variables can be set by the client:
--> flags = lcd flags; will be used as defaults for drawing text and numbers
--> widgetRefresh = function drawing screen in non-fullscreen mode
--> fullScreenRefresh = function drawing screen in fullscreen mode
--> element.disabled = true prevents element from taking focus
--> element.title can be set for button, toggleButton and label
--> element.value can be set for toggleButton and number

function lib.newGUI()
  local gui = { }
  local handles = { }
  local elements = { }
  local focus = 1
  local editing = false
  local scrolling = false
  
  -- The default callBack
  local function doNothing()
  end
  
  -- Adjust text according to horizontal alignment
  local function align(x, w, flags)
    if bit32.band(flags, RIGHT) == RIGHT then
      return x + w - 2
    elseif bit32.band(flags, CENTER) == CENTER then
      return x + w / 2
    else
      return x + 2
    end
  end -- align(...)
  
  -- Draw border around focused elements
  local function drawFocus(x, y, w, h, color)
    color = color or lib.colors.active
    lcd.drawRectangle(x - 2, y - 2, w + 4, h + 4, color, 2)
  end -- drawFocus(...)
  
  -- Move focus to another element
  local function moveFocus(delta)
    local count = 0 -- Prevent infinite loop
    repeat
      focus = focus + delta
      if focus > #elements then
        focus = 1
      elseif focus < 1 then
        focus = #elements
      end
      count = count + 1
    until not (elements[focus].disabled or elements[focus].hidden) or count > #elements
  end -- moveFocus(...)
  
  -- Add an element and return it to the client
  local function addElement(element, x, y, w, h)
    local idx = #elements + 1

    if not element.covers then
      function element.covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
    end
    
    elements[idx] = element
    return element
  end -- addElement(...)
  
  -- Add temporary BLINK or INVERS flags
  local function getFlags(element)
    local flags = element.flags
    if element.blink then flags = bit32.bor(flags or 0, BLINK) end
    if element.invers then flags = bit32.bor(flags or 0, INVERS) end
    return flags
  end
  
  -- Set an event handler
  function gui.SetEventHandler(event, f)
    handles[event] = f
  end
  
  -- Run an event cycle
  function gui.run(event, touchState)
    if not event then -- widget mode; event == nil
      if gui.widgetRefresh then
        gui.widgetRefresh()
      else
        lcd.drawText(1, 1, "No widget refresh")
        lcd.drawText(1, 25, "function was loaded.")
      end
    else -- full screen mode; event is a value
      if gui.fullScreenRefresh then
        gui.fullScreenRefresh(event, touchState)
      end
      for idx, element in ipairs(elements) do
        if not element.hidden then
          element.draw(idx)
        end
      end
      if (elements[focus].disabled or elements[focus].hidden) then
        moveFocus(1)
        return
      end
      if gui.prompt then
        return gui.prompt.run(event, touchState)
      end
      if event ~= 0 then -- non-zero event; process it
        -- If we put a finger down on a menu item and immediately slide, then we can scroll
        if event ~= EVT_TOUCH_SLIDE then
          scrolling = false
        end
        if event == EVT_TOUCH_FIRST then
          if elements[focus].covers(touchState.x, touchState.y) then
            scrolling = true
          else
            -- Did we touch another element?
            for idx, element in ipairs(elements) do
              if not (element.disabled or element.hidden) and element.covers(touchState.x, touchState.y) then
                if editing then
                  -- A goodbye EXIT before we take away focus
                  elements[focus].run(EVT_VIRTUAL_EXIT, touchState)
                  editing = false
                end
                focus = idx
                scrolling = true
                return -- Do not continue this cycle
              end
            end
          end
        elseif event == EVT_TOUCH_TAP then
          if elements[focus].covers(touchState.x, touchState.y) then
            -- Convert to ENTER
            event = EVT_VIRTUAL_ENTER
          elseif editing then
            -- Convert a tap off the focused element to EXIT
            event = EVT_VIRTUAL_EXIT
          end
        end
        
        if editing then -- Send the event to the element being edited
          elements[focus].run(event, touchState)
          if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
            editing = false
          end
        elseif event == EVT_VIRTUAL_ENTER and elements[focus].editable then -- Start editing
          editing = true
        elseif event == EVT_VIRTUAL_NEXT then -- Move focus
          moveFocus(1)
        elseif event == EVT_VIRTUAL_PREV then
          moveFocus(-1)
        else
          if handles[event] then
            -- Is it being handled? Handler can modify event
            event = handles[event](event, touchState)
            -- If handler returned false or nil, then we are done
            if not event then
             return
            end
          end
          elements[focus].run(event, touchState)
        end
      end
    end
  end -- run(...)

-- Create a button to trigger a function
  function gui.button (x, y, w, h, title, callBack, flags)
    local self = {
      title = title,
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, CENTER, VCENTER)
    }
    
    function self.draw(idx)
      if focus == idx then
        drawFocus(x, y, w, h)
      end
      
      lcd.drawFilledRectangle(x, y, w, h, lib.colors.buttonBackground)
      lcd.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(lib.colors.focusText, self.flags))
      
      if self.disabled then
        lcd.drawFilledRectangle(x, y, w, h, GREY, 7)
      end
    end
    
    function self.run(event, touchState)
      if event == EVT_VIRTUAL_ENTER then
        return self.callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- button(...)
  
-- Create a toggle button that turns on/off. callBack gets true/false
  function gui.toggleButton(x, y, w, h, title, value, callBack, flags)
    local self = {
      title = title, 
      value = value,
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, CENTER, VCENTER)
    }

    function self.draw(idx)
      local fg = lib.colors.focusText
      local bg = lib.colors.buttonBackground
      local border = lib.colors.active

      if self.value then
        fg = lib.colors.text
        bg = lib.colors.active
        border = lib.colors.buttonBackground
      end
      
      if focus == idx then
        drawFocus(x, y, w, h, border)
      end
      
      lcd.drawFilledRectangle(x, y, w, h, bg)
      lcd.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(fg, self.flags))
      
      if self.disabled then
        lcd.drawFilledRectangle(x, y, w, h, GREY, 7)
      end
    end
    
    function self.run(event, touchState)
      if event == EVT_VIRTUAL_ENTER then
        self.value = not self.value
        return self.callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- toggleButton(...)
  
-- Create a number that can be edited
  function gui.number(x, y, w, h, value, callBack, flags)
    local self = {
      value = value,
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, VCENTER),
      editable = true
    }
    
    function self.draw(idx)
      local flags = getFlags(self)
      local fg = lib.colors.text
      
      if focus == idx then
        drawFocus(x, y, w, h)

        if editing then
          fg = lib.colors.focusText
          lcd.drawFilledRectangle(x, y, w, h, lib.colors.editBackground)
        end
      end
      if type(self.value) == "string" then
        lcd.drawText(align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
      else
        lcd.drawNumber(align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
      end
    end
    
    function self.run(event, touchState)
      -- There are so many possibilities that we leave it up to the call back to decide what to do.
      if editing then
        return self.callBack(self, event, touchState)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- number(...)
  
-- Create a text label
  function gui.label(x, y, w, h, title, flags)
    local self = {
      title = title,
      flags = bit32.bor(flags or lib.flags, VCENTER, lib.colors.text),
      disabled = true
    }
    
    function self.draw(idx)
      local flags = getFlags(self)
      lcd.drawText(align(x, w, flags), y + h / 2, self.title, flags)
    end

    -- We should not ever run, but just in case...
    function self.run(event, touchState)
      self.disabled = true
      moveFocus(1)
    end
    
    function self.covers(p, q)
      return false
    end
     
    return addElement(self, x, y, w, h)
  end -- label(...)
  
-- Create a display of current time on timer[tmr]
-- Set timer.value to show a different value
  function gui.timer(x, y, w, h, tmr, callBack, flags)
    local self = {
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, VCENTER),
      editable = true
    }

    function self.draw(idx)
      local flags = getFlags(self)
      local fg = lib.colors.text
      -- self.value overrides the timer value
      local value = self.value or model.getTimer(tmr).value
      
      if focus == idx then
        drawFocus(x, y, w, h)

        if editing then
          fg = lib.colors.focusText
          lcd.drawFilledRectangle(x, y, w, h, lib.colors.editBackground)
        end
      end
      if type(value) == "string" then
        lcd.drawText(align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
      else
        lcd.drawTimer(align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
      end
    end
    
    function self.run(event, touchState)
      -- There are so many possibilities that we leave it up to the call back to decide what to do.
      if editing then
        return self.callBack(self, event, touchState)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- timer(...)
  
  function gui.menu(x, y, visibleCount, items, callBack, flags)
    items = items or { "No items!" }
    callBack = callBack or doNothing
    flags = bit32.bor(flags or lib.flags, lib.colors.text, VCENTER)
    local es = { }
    local firstVisible = 1
    local startFirst = 1
    local idx0 = #elements
    local idxN = idx0 + #items
    local h = select(2, lcd.sizeText("X", flags))
    y = y + h / 2
    
    -- Add line items as GUI elements
    for i, item in ipairs(items) do
      local self = {
        idx = i,
        callBack = callBack,
        flags = flags
      }
      
      local w = lcd.sizeText(item, flags) + 4
      
      function self.draw(idx)
        local flags = getFlags(self)
        local yy = y + h * (self.idx - firstVisible)
        
        -- Do we need to adjust scroll?
        if self.idx == 1 and focus > idx0 and focus <= idxN then
          local selected = focus - idx0
          if selected < firstVisible then
            firstVisible = selected
          elseif selected - firstVisible >= visibleCount then
            firstVisible = selected - visibleCount + 1
          end
        end
        
        -- Is this line item visible?
        if self.idx < firstVisible or self.idx >= firstVisible + visibleCount then
          return
        end
        
        if focus == idx then
          drawFocus(x - 2, yy - h / 2, w, h)
        end
        
        lcd.drawText(x, yy, item, flags)
      end -- draw(...)
      
      function self.run(event, touchState)
        if event == EVT_VIRTUAL_ENTER then
          return self.callBack(self)
        elseif scrolling then
          -- Finger scrolling
          firstVisible = math.floor(self.idx - (touchState.y - y) / h + 0.5)
          firstVisible = math.min(firstVisible, idxN - idx0 - visibleCount + 1, self.idx)
          firstVisible = math.max(firstVisible, 1, self.idx - visibleCount + 1)
        end
      end
      
      function self.covers(p, q)
        if self.idx < firstVisible or self.idx >= firstVisible + visibleCount then
          return false
        else
          local yy = y + h * (self.idx - firstVisible)

          return (x <= p and p <= x + w and yy - h / 2 <= q and q <= yy + h / 2)
        end
      end
      
      es[#es + 1] = addElement(self)
    end -- Loop adding menu items
    return es
  end -- menu(...)
  
  return gui
end -- gui(...)

return lib
---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-01-09                                                   --
-- Version: 1.0.0 RC1                                                    --
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
local x1, y1, x2, y2

-- Radius of slider dot
local SLIDER_DOT_RADIUS = 10

-- Default flags and colors, can be changed by client
lib.flags = 0
lib.colors = {
  primary1 = COLOR_THEME_PRIMARY1,
  primary2 = COLOR_THEME_PRIMARY2,
  primary3 = COLOR_THEME_PRIMARY3,
  focus = COLOR_THEME_FOCUS,
  edit = COLOR_THEME_EDIT,
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
function lib.newGUI()
  local gui = { 
    x = 0,
    y = 0,
    editable = true
  }
  
  local handles = { }
  local elements = { }
  local focus = 1
  
  -- Translate coordinates for sub-GUIs
  function gui.translate(x, y)
    if gui.parent then
      x, y = gui.parent.translate(x, y)
    end
    return gui.x + x, gui.y + y
  end
  
  -- Replace lcd functions to translate by gui offset
  function gui.drawCircle(x, y, r, flags)
    x, y = gui.translate(x, y)
    lcd.drawCircle(x, y, r, flags)
  end

  function gui.drawFilledCircle(x, y, r, flags)
    x, y = gui.translate(x, y)
    lcd.drawFilledCircle(x, y, r, flags)
  end

  function gui.drawLine(x1, y1, x2, y2, pattern, flags)
    x, y = gui.translate(x1, y1)
    x, y = gui.translate(x2, y2)
    lcd.drawLine(x1, y1, x2, y2, pattern, flags)
  end

  function gui.drawRectangle(x, y, w, h, flags, t)
    x, y = gui.translate(x, y)
    lcd.drawRectangle(x, y, w, h, flags, t)
  end

  function gui.drawFilledRectangle(x, y, w, h, flags, opacity)
    x, y = gui.translate(x, y)
    lcd.drawFilledRectangle(x, y, w, h, flags, opacity)
  end

  function gui.drawText(x, y, text, flags, inversColor)
    x, y = gui.translate(x, y)
    lcd.drawText(x, y, text, flags, inversColor)
  end

  function gui.drawTextLines(x, y, w, h, text, flags)
    x, y = gui.translate(x, y)
    lcd.drawTextLines(x, y, w, h, text, flags)
  end

  function gui.drawNumber(x, y, value, flags, inversColor)
    x, y = gui.translate(x, y)
    lcd.drawNumber(x, y, value, flags, inversColor)
  end

  function gui.drawTimer(x, y, value, flags, inversColor)
    x, y = gui.translate(x, y)
    lcd.drawTimer(x, y, value, flags, inversColor)
  end

  -- The default callBack
  local function doNothing()
  end
  
  -- The default changeValue
  local function changeDefault(delta, self)
    return self.value + delta
  end
  
  -- Adjust text according to horizontal alignment
  local function align(x, w, flags)
    if bit32.band(flags, RIGHT) == RIGHT then
      return x + w
    elseif bit32.band(flags, CENTER) == CENTER then
      return x + w / 2
    else
      return x
    end
  end -- align(...)
  
  -- Draw border around focused elements
  local function drawFocus(x, y, w, h, color)
    color = color or lib.colors.active
    gui.drawRectangle(x - 2, y - 2, w + 4, h + 4, color, 2)
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
  
  -- Show prompt
  function gui.showPrompt(prompt)
    lib.prompt = prompt
  end
  
  -- Dismiss prompt
  function gui.dismissPrompt()
    lib.prompt = nil
  end
  
  -- Run an event cycle
  function gui.run(event, touchState)
    if not event then -- widget mode; event == nil
      if lib.widgetRefresh then
        lib.widgetRefresh()
      else
        gui.drawText(1, 1, "No widget refresh")
        gui.drawText(1, 25, "function was loaded.")
      end
    else -- full screen mode; event is a value
      x2, y2 = 0, 0
      gui.draw(false)
      -- Dim non-active region
      if x2 > 0 then
        lcd.drawFilledRectangle(0, 0, LCD_W, y1, BLACK, 8)
        lcd.drawFilledRectangle(0, y2, LCD_W, LCD_H - y2, BLACK, 8)
        lcd.drawFilledRectangle(0, y1, x1, y2 - y1, BLACK, 8)
        lcd.drawFilledRectangle(x2, y1, LCD_W - x2, y2 - y1, BLACK, 8)
      end
      gui.onEvent(event, touchState)
    end
  end -- run(...)

  function gui.draw(focused)
    if gui.fullScreenRefresh then
      gui.fullScreenRefresh()
    end
    local guiFocus = not gui.parent or (focused and gui.parent.editing)
    for idx, element in ipairs(elements) do
      if not element.hidden then
        element.draw(focus == idx and guiFocus)
      end
    end
    if focused then
      if gui.parent.editing then
        x1, y1 = gui.translate(-3, -3)
        x2, y2 = gui.translate(gui.w + 3, gui.h + 3)
      else
        drawFocus(0, 0, gui.w, gui.h)
      end
    end
  end -- draw()
  
  function gui.onEvent(event, touchState)
    -- Make sure that focused element is active
    if (elements[focus].disabled or elements[focus].hidden) then
      moveFocus(1)
      return
    end
    -- Is there an active prompt?
    if lib.prompt and not lib.showingPrompt then
      lib.showingPrompt = true
      lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, BLACK, 8)
      lib.prompt.run(event, touchState)
      lib.showingPrompt = false
      return
    end
    if event ~= 0 then -- non-zero event; process it
      if not gui.parent or gui.parent.editing then
        -- Translate touch coordinates if offset
        if touchState then
          touchState.x = touchState.x - gui.x
          touchState.y = touchState.y - gui.y
          if touchState.startX then
            touchState.startX = touchState.startX - gui.x
            touchState.startY = touchState.startY - gui.y
          end
          -- "Un-convert" ENTER to TAP
          if event == EVT_VIRTUAL_ENTER then
            event = EVT_TOUCH_TAP
          end
        end
        -- If we put a finger down on a menu item and immediately slide, then we can scroll
        if event ~= EVT_TOUCH_SLIDE then
          gui.scrolling = false
        end
        -- "Pre-processing" of touch events to simplify subsequent handling and support scrolling etc.
        if event == EVT_TOUCH_FIRST then
          if elements[focus].covers(touchState.x, touchState.y) then
            gui.scrolling = true
          else
            if gui.editing then
              return
            else
              -- Did we touch another element?
              for idx, element in ipairs(elements) do
                if not (element.disabled or element.hidden) and element.covers(touchState.x, touchState.y) then
                  focus = idx
                  gui.scrolling = true
                end
              end
            end
          end
        elseif event == EVT_TOUCH_TAP then
          if elements[focus].covers(touchState.x, touchState.y) then
            -- Convert TAP on focused element to ENTER
            event = EVT_VIRTUAL_ENTER
          elseif gui.editing then
            -- Convert a TAP off the element being edited to EXIT
            event = EVT_VIRTUAL_EXIT
          end
        end
        
        if gui.editing then -- Send the event directly to the element being edited
          elements[focus].onEvent(event, touchState)
        elseif event == EVT_VIRTUAL_NEXT then -- Move focus
          moveFocus(1)
        elseif event == EVT_VIRTUAL_PREV then
          moveFocus(-1)
        elseif event == EVT_VIRTUAL_EXIT then
          if gui.parent then
            gui.parent.editing = false
          end
        else
          if handles[event] then
            -- Is it being handled? Handler can modify event
            event = handles[event](event, touchState)
            -- If handler returned false or nil, then we are done
            if not event then
             return
            end
          end
          elements[focus].onEvent(event, touchState)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        gui.parent.editing = true
      end
    end
  end -- onEvent(...)

-- Create a text label
  function gui.label(x, y, w, h, title, flags)
    local self = {
      title = title,
      flags = bit32.bor(flags or lib.flags, VCENTER, lib.colors.primary1),
      disabled = true
    }
    
    function self.draw(focused)
     local flags = getFlags(self)
      gui.drawText(align(x, w, flags), y + h / 2, self.title, flags)
    end

    -- We should not ever onEvent, but just in case...
    function self.onEvent(event, touchState)
      self.disabled = true
      moveFocus(1)
    end
    
    function self.covers(p, q)
      return false
    end
     
    return addElement(self, x, y, w, h)
  end -- label(...)
  
  -- Create a button to trigger a function
  function gui.button (x, y, w, h, title, callBack, flags)
    local self = {
      title = title,
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, CENTER, VCENTER)
    }
    
    function self.draw(focused)
      if focused then
        drawFocus(x, y, w, h)
      end
      
      gui.drawFilledRectangle(x, y, w, h, lib.colors.focus)
      gui.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(lib.colors.primary2, self.flags))
      
      if self.disabled then
        gui.drawFilledRectangle(x, y, w, h, GREY, 7)
      end
    end
    
    function self.onEvent(event, touchState)
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

    function self.draw(focused)
      local fg = lib.colors.primary2
      local bg = lib.colors.focus
      local border = lib.colors.active

      if self.value then
        fg = lib.colors.primary3
        bg = lib.colors.active
        border = lib.colors.focus
      end
      
      if focused then
        drawFocus(x, y, w, h, border)
      end
      
      gui.drawFilledRectangle(x, y, w, h, bg)
      gui.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(fg, self.flags))
      
      if self.disabled then
        gui.drawFilledRectangle(x, y, w, h, GREY, 7)
      end
    end
    
    function self.onEvent(event, touchState)
      if event == EVT_VIRTUAL_ENTER then
        self.value = not self.value
        return self.callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- toggleButton(...)
  
-- Create a number that can be edited
  function gui.number(x, y, w, h, value, changeValue, flags)
    local self = {
      value = value,
      changeValue = changeValue or changeDefault,
      flags = bit32.bor(flags or lib.flags, VCENTER),
      editable = true
    }
    local d0
    
    function self.draw(focused)
      local flags = getFlags(self)
      local fg = lib.colors.primary1
      
      if focused then
        drawFocus(x, y, w, h)

        if gui.editing then
          fg = lib.colors.primary2
          gui.drawFilledRectangle(x, y, w, h, lib.colors.edit)
        end
      end
      if type(self.value) == "string" then
        gui.drawText(align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
      else
        gui.drawNumber(align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
      end
    end
    
    function self.onEvent(event, touchState)
      if gui.editing then
        if event == EVT_VIRTUAL_ENTER then
          gui.editing = false
        elseif event == EVT_VIRTUAL_EXIT then
          self.value = value
          gui.editing = false
        elseif event == EVT_VIRTUAL_INC then
          self.value = self.changeValue(1, self)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = self.changeValue(-1, self)
        elseif event == EVT_TOUCH_FIRST then
          d0 = 0
        elseif event == EVT_TOUCH_SLIDE and gui.scrolling then
          local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
          if d ~= d0 then
            self.value = self.changeValue(d - d0, self)
            d0 = d
          end
        end
      elseif event == EVT_VIRTUAL_ENTER then
        value = self.value
        gui.editing = true
      end
    end -- onEvent(...)
    
    return addElement(self, x, y, w, h)
  end -- number(...)

-- Create a display of current time on timer[tmr]
-- Set timer.value to show a different value
  function gui.timer(x, y, w, h, tmr, changeValue, flags)
    local self = {
      changeValue = changeValue or changeDefault,
      flags = bit32.bor(flags or lib.flags, VCENTER),
      editable = true
    }
    local value
    local d0

    function self.draw(focused)
      local flags = getFlags(self)
      local fg = lib.colors.primary1
      -- self.value overrides the timer value
      local value = self.value or model.getTimer(tmr).value
      
      if focused then
        drawFocus(x, y, w, h)

        if gui.editing then
          fg = lib.colors.primary2
          gui.drawFilledRectangle(x, y, w, h, lib.colors.edit)
        end
      end
      if type(value) == "string" then
        gui.drawText(align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
      else
        gui.drawTimer(align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
      end
    end
    
    function self.onEvent(event, touchState)
      if gui.editing then
        if event == EVT_VIRTUAL_ENTER then
          if not value and tmr then
            local tblTmr = model.getTimer(tmr)
            tblTmr.value = self.value
            model.setTimer(tmr, tblTmr)
            self.value = nil
          end
          gui.editing = false
        elseif event == EVT_VIRTUAL_EXIT then
          self.value = value
          gui.editing = false
        elseif event == EVT_VIRTUAL_INC then
          self.value = self.changeValue(1, self)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = self.changeValue(-1, self)
        elseif event == EVT_TOUCH_FIRST then
          d0 = 0
        elseif event == EVT_TOUCH_SLIDE and gui.scrolling then
          local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
          if d ~= d0 then
            self.value = self.changeValue(d - d0, self)
            d0 = d
          end
        end
      elseif event == EVT_VIRTUAL_ENTER then
        if self.value then
          value = self.value
        elseif tmr then
          self.value = model.getTimer(tmr).value
          value = nil
        end
        gui.editing = true
      end
    end -- onEvent(...)
    
    return addElement(self, x, y, w, h)
  end -- timer(...)
  
  function gui.menu(x, y, visibleCount, items, callBack, flags)
    items = items or { "No items!" }
    callBack = callBack or doNothing
    flags = bit32.bor(flags or lib.flags, lib.colors.primary1, VCENTER)
    local es = { }
    local firstVisible = 1
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
      
      function self.draw(focused)
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
        
        if focused then
          drawFocus(x - 2, yy - h / 2, w, h)
        end
        
        gui.drawText(x, yy, item, flags)
      end -- draw(...)
      
      function self.onEvent(event, touchState)
        if event == EVT_VIRTUAL_ENTER then
          return self.callBack(self)
        elseif gui.scrolling then
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
  
  function gui.dropDown(x, y, w, h, items, selected, callBack, flags)
    local self = {
      selected = selected,
      callBack = callBack or doNothing,
      flags = bit32.bor(flags or lib.flags, VCENTER)
    }
    
    local firstVisible
    local firstVisibleScrolling
    local moving = 0
    local visibleCount = math.min(7, #items)
    local height = visibleCount * h
    local left = (LCD_W - w) / 2
    local top = (LCD_H - height) / 2
    local killEvt

    local function setFirstVisible(v)
      firstVisible = v
      firstVisible = math.max(1, firstVisible)
      firstVisible = math.min(#items - visibleCount + 1, firstVisible)
    end

    function self.draw(focused)
      local flags = getFlags(self)
      
      if focused then
        drawFocus(x, y, w, h)
      end
      gui.drawText(align(x, w, flags), y + h / 2, items[self.selected], bit32.bor(lib.colors.primary1, flags))
    end
    
    local dropDown = { }
    
    function dropDown.covers(x, y)
      return left <= x and x <= left + w and top <= y and y <= top + height
    end
    
    function dropDown.run(event, touchState)
      local flags = getFlags(self)
      
      if moving ~= 0 then
        if match(event, EVT_TOUCH_FIRST, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
          moving = 0
          event = 0
        else
          setFirstVisible(firstVisible + moving)
        end
      end
        
      if event ~= 0 then
        -- This hack is needed because killEvents does not seem to work
        if killEvt then
          killEvt = false
          if event == EVT_VIRTUAL_ENTER then
            event = 0
          end
        end

        if event == EVT_TOUCH_SLIDE then
          if gui.scrolling then
            if touchState.swipeUp then
              moving = 1
            elseif touchState.swipeDown then
              moving = -1
            elseif touchState.startX then
              setFirstVisible(firstVisibleScrolling + math.floor((touchState.startY - touchState.y) / h + 0.5))
            end
          end
        else
          gui.scrolling = false

          if event == EVT_TOUCH_FIRST then
            if dropDown.covers(touchState.x, touchState.y) then
              gui.scrolling = true
              firstVisibleScrolling = firstVisible
            end
          elseif event == EVT_TOUCH_TAP then
            if dropDown.covers(touchState.x, touchState.y) then
              selected = firstVisible + math.floor((touchState.y - top) / h)
              event = EVT_VIRTUAL_ENTER
            else
              event = EVT_VIRTUAL_EXIT
            end
          elseif match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV) then
            if event == EVT_VIRTUAL_NEXT then
              selected = math.min(#items, selected + 1)
            elseif event == EVT_VIRTUAL_PREV then
              selected = math.max(1, selected - 1)
            end
            
            if selected >= firstVisible + visibleCount then
              firstVisible = selected - visibleCount + 1
            elseif selected < firstVisible then
              firstVisible = selected
            end
          end
        end

        if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
          gui.dismissPrompt()
          if event == EVT_VIRTUAL_ENTER then
            self.selected = selected
            self.callBack(self)
          end
        end
      end
      
      lcd.drawFilledRectangle(left, top, w, height, lib.colors.primary2)
      lcd.drawRectangle(left - 2, top - 2, w + 4, height + 4, lib.colors.primary1, 2)
      
      for i = 0, visibleCount - 1 do
        local j = firstVisible + i
        local y = top + i * h
        
        if j == selected then
          lcd.drawFilledRectangle(left, y, w, h, lib.colors.focus)
          lcd.drawText(align(left, w, flags), y + h / 2, items[j], bit32.bor(lib.colors.primary2, flags))
        else
          lcd.drawText(align(left, w, flags), y + h / 2, items[j], bit32.bor(lib.colors.primary1, flags))
        end
      end
    end
    
    function self.onEvent(event, touchState)
      -- Show drop down and let it take over while active
      if event == EVT_VIRTUAL_ENTER then
        selected = self.selected
        setFirstVisible(selected - math.floor(visibleCount / 2))
        killEvt = true
        gui.showPrompt(dropDown)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- dropDown(...)
  
  function gui.horizontalSlider(x, y, w, value, min, max, delta, callBack)
    local self = {
      value = value,
      callBack = callBack or doNothing,
      editable = true
    }

    function self.draw(focused)
      local xdot = x + w * (self.value - min) / (max - min)
      
      local colorBar = lib.colors.primary3
      local colorDot = lib.colors.primary2
      local colorDotBorder = lib.colors.primary3
      
      if focused then
        colorDotBorder = lib.colors.active
        if gui.editing or gui.scrolling then
          colorBar = lib.colors.focus
          colorDot = lib.colors.edit
        end
      end

      gui.drawFilledRectangle(x, y - 2, w, 5, colorBar)
      gui.drawFilledCircle(xdot, y, SLIDER_DOT_RADIUS, colorDot)
      for i = -1, 1 do
        gui.drawCircle(xdot, y, SLIDER_DOT_RADIUS + i, colorDotBorder)
      end
    end
    
    function self.onEvent(event, touchState)
      local v0 = self.value
      
      if gui.editing then
        if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
          gui.editing = false
        elseif event == EVT_VIRTUAL_INC then
          self.value = math.min(max, self.value + delta)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = math.max(min, self.value - delta)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        gui.editing = true
      end
      
      if gui.scrolling then
        if touchState.slideX then
          local slideX = touchState.slideX
          slideX = math.min(slideX, touchState.x - x)
          slideX = math.max(slideX, touchState.x - (x + w))
          value = value + (max - min) * slideX / w
          value = math.min(max, value)
          value = math.max(min, value)
          self.value = min + delta * math.floor((value - min) / delta + 0.5)
        end
      else
        value = self.value
      end
      
      if v0 ~= self.value then
        self.callBack(self)
      end
    end
    
    function self.covers(p, q)
      local xdot = x + w * (self.value - min) / (max - min)
      return ((p - xdot)^2 + (q - y)^2 <= SLIDER_DOT_RADIUS^2)
    end
    
    return addElement(self)
  end -- horizontalSlider(...)

  function gui.verticalSlider(x, y, h, value, min, max, delta, callBack)
    local self = {
      value = value,
      callBack = callBack or doNothing,
      editable = true
    }

    function self.draw(focused)
      local ydot = y + h * (1 - (self.value - min) / (max - min))
      
      local colorBar = lib.colors.primary3
      local colorDot = lib.colors.primary2
      local colorDotBorder = lib.colors.primary3
      
      if focused then
        colorDotBorder = lib.colors.active
        if gui.editing or gui.scrolling then
          colorBar = lib.colors.focus
          colorDot = lib.colors.edit
        end
      end

      gui.drawFilledRectangle(x - 2, y, 5, h, colorBar)
      gui.drawFilledCircle(x, ydot, SLIDER_DOT_RADIUS, colorDot)
      for i = -1, 1 do
        gui.drawCircle(x, ydot, SLIDER_DOT_RADIUS + i, colorDotBorder)
      end
    end
    
    function self.onEvent(event, touchState)
      local v0 = self.value
      
      if gui.editing then
        if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
          gui.editing = false
        elseif event == EVT_VIRTUAL_INC then
          self.value = math.min(max, self.value + delta)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = math.max(min, self.value - delta)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        gui.editing = true
      end
      
      if gui.scrolling then
        if touchState.slideY then
          local slideY = touchState.slideY
          slideY = math.min(slideY, touchState.y - y)
          slideY = math.max(slideY, touchState.y - (y + h))
          value = value - (max - min) * slideY / h
          value = math.min(max, value)
          value = math.max(min, value)
          self.value = min + delta * math.floor((value - min) / delta + 0.5)
        end
      else
        value = self.value
      end
      
      self.value = min + delta * math.floor((self.value - min) / delta + 0.5)
      self.value = math.min(max, self.value)
      self.value = math.max(min, self.value)
      
      if v0 ~= self.value then
        self.callBack(self)
      end
    end
    
    function self.covers(p, q)
      local ydot = y + h * (1 - (self.value - min) / (max - min))
      return ((p - x)^2 + (q - ydot)^2 <= SLIDER_DOT_RADIUS^2)
    end
    
    return addElement(self)
  end -- verticalSlider(...)

  -- Create a custom element
  function gui.custom(self, x, y, w, h)
    self.gui = gui
    self.lib = lib
    self.drawFocus = drawFocus
    
    -- Must be implemented by the client
    if not self.draw then
      function self.draw(focused)
        gui.drawText(x, y, "draw(focused) missing")
        if focused then
          drawFocus(x, y, w, h)
        end
      end
    end
    
    -- Must be implemented by the client
    if not self.onEvent then
      function self.onEvent()
        playTone(200, 200, 0, PLAY_NOW)
      end
    end
    
    return addElement(self, x, y, w, h)
  end
  
  -- Create a nested gui
  function gui.gui(x, y, w, h)
    local self = lib.newGUI()
    self.parent = gui
    self.editing = false
    self.x, self.y, self.w, self.h = x, y, w, h
    return addElement(self, x, y, w, h)
  end
  
  return gui
end -- gui(...)

return lib
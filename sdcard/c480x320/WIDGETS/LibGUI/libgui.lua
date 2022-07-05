---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-05-05                                                   --
-- Version: 1.0.1                                                        --
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
  local scrolling = false
  local lastEvent = 0
  
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
    x1, y1 = gui.translate(x1, y1)
    x2, y2 = gui.translate(x2, y2)
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

  function gui.drawTriangle(x1, y1, x2, y2, x3, y3, flags)
    x1, y1 = gui.translate(x1, y1)
    x2, y2 = gui.translate(x2, y2)
    x3, y3 = gui.translate(x3, y3)
    lcd.drawTriangle(x1, y1, x2, y2, x3, y3, flags)
  end
  
  function gui.drawFilledTriangle(x1, y1, x2, y2, x3, y3, flags)
    x1, y1 = gui.translate(x1, y1)
    x2, y2 = gui.translate(x2, y2)
    x3, y3 = gui.translate(x3, y3)
    lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3, flags)
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
    -- Not necessary if there is only one element...
    if #elements == 1 then
      return
    end
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
  
  -- Moved the focused element
  function gui.moveFocused(delta)
    if delta > 0 then
      delta = 1
    elseif delta < 0 then
      delta = -1
    end
    local idx = focus + delta
    if idx >= 1 and idx <= #elements then
      elements[focus], elements[idx] = elements[idx], elements[focus]
      focus = idx
    end
  end
  
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
  function gui.setEventHandler(event, f)
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
      gui.draw(false)
      gui.onEvent(event, touchState)
    end
    lastEvent = event
  end -- run(...)

  function gui.draw(focused)
    if gui.fullScreenRefresh then
      gui.fullScreenRefresh()
    end
    if focused then
      if gui.parent.editing then
        drawFocus(0, 0, gui.w, gui.h, lib.colors.edit)
      else
        drawFocus(0, 0, gui.w, gui.h)
      end
    end
    local guiFocus = not gui.parent or (focused and gui.parent.editing)
    for idx, element in ipairs(elements) do
      -- Clients may provide an update function for elements
      if element.update then
        element.update(element)
      end
      if not element.hidden then
        element.draw(focus == idx and guiFocus)
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
        if event == EVT_TOUCH_SLIDE then
          if not scrolling then
            return
          end
        else
          scrolling = false
        end
        -- "Pre-processing" of touch events to simplify subsequent handling and support scrolling etc.
        if event == EVT_TOUCH_FIRST then
          if elements[focus].covers(touchState.x, touchState.y) then
            scrolling = true
          else
            if gui.editing then
              return
            else
              -- Did we touch another element?
              for idx, element in ipairs(elements) do
                if not (element.disabled or element.hidden) and element.covers(touchState.x, touchState.y) then
                  focus = idx
                  scrolling = true
                end
              end
            end
          end
        elseif event == EVT_TOUCH_TAP or (event == EVT_TOUCH_BREAK and lastEvent == EVT_TOUCH_FIRST) then
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
        elseif event == EVT_VIRTUAL_EXIT and gui.parent then
          gui.parent.editing = false
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
  function gui.button(x, y, w, h, title, callBack, flags)
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
        elseif event == EVT_TOUCH_SLIDE then
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
      tmr = tmr,
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
      local value = self.value or model.getTimer(self.tmr).value
      
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
          if not value and self.tmr then
            local tblTmr = model.getTimer(self.tmr)
            tblTmr.value = self.value
            model.setTimer(self.tmr, tblTmr)
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
        elseif event == EVT_TOUCH_SLIDE then
          local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
          if d ~= d0 then
            self.value = self.changeValue(d - d0, self)
            d0 = d
          end
        end
      elseif event == EVT_VIRTUAL_ENTER then
        if self.value then
          value = self.value
        elseif self.tmr then
          self.value = model.getTimer(self.tmr).value
          value = nil
        end
        gui.editing = true
      end
    end -- onEvent(...)
    
    return addElement(self, x, y, w, h)
  end -- timer(...)
  
  function gui.menu(x, y, w, h, items, callBack, flags)
    local self = {
      items = items or { "No items!" },
      flags = bit32.bor(flags or lib.flags, VCENTER),
      editable = true,
      selected = 1
    }
    local selected = 1
    local firstVisible = 1
    local firstVisibleScrolling
    local moving = 0
    local lh = select(2, lcd.sizeText("", self.flags))
    local visibleCount = math.floor(h / lh)
    local killEvt
    
    callBack = callBack or doNothing

    local function setFirstVisible(v)
      firstVisible = v
      firstVisible = math.max(1, firstVisible)
      firstVisible = math.min(#self.items - visibleCount + 1, firstVisible)
    end
    
    local function adjustScroll()
      if selected >= firstVisible + visibleCount then
        firstVisible = selected - visibleCount + 1
      elseif selected < firstVisible then
        firstVisible = selected
      end
    end

    function self.draw(focused)
      local flags = getFlags(self)
      local visibleCount = math.min(visibleCount, #self.items)
      local sel
      local bgColor
      
      if focused and gui.editing then
        bgColor = lib.colors.edit
      else
        selected = self.selected
        bgColor = lib.colors.focus
      end

      for i = 0, visibleCount - 1 do
        local j = firstVisible + i
        local y = y + i * lh
        
        if j == selected then
          gui.drawFilledRectangle(x, y, w, lh, bgColor)
          gui.drawText(align(x, w, flags), y + lh / 2, self.items[j], bit32.bor(lib.colors.primary2, flags))
        else
          gui.drawText(align(x, w, flags), y + lh / 2, self.items[j], bit32.bor(lib.colors.primary1, flags))
        end
      end

      if focused then
        drawFocus(x, y, w, h)
      end
    end -- draw()
    
    function self.onEvent(event, touchState)
      local visibleCount = math.min(visibleCount, #self.items)

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

        -- If we touch it, then start editing immediately
        if touchState then
          gui.editing = true
        end

        if event == EVT_TOUCH_SLIDE then
          if scrolling then
            if touchState.swipeUp then
              moving = 1
            elseif touchState.swipeDown then
              moving = -1
            elseif touchState.startX then
              setFirstVisible(firstVisibleScrolling + math.floor((touchState.startY - touchState.y) / lh + 0.5))
            end
          end
        else
          scrolling = false

          if event == EVT_TOUCH_FIRST then
            scrolling = true
            firstVisibleScrolling = firstVisible
          elseif match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV) then
            if event == EVT_VIRTUAL_NEXT then
              selected = math.min(#self.items, selected + 1)
            elseif event == EVT_VIRTUAL_PREV then
              selected = math.max(1, selected - 1)
            end
            adjustScroll()
          elseif event == EVT_VIRTUAL_ENTER then
            if gui.editing then
              if touchState then
                selected = firstVisible + math.floor((touchState.y - y) / lh)
              end
              
              gui.editing = false
              self.selected = selected
              callBack(self)
            else
              gui.editing = true
              selected = self.selected
              adjustScroll()
            end
          elseif event == EVT_VIRTUAL_EXIT then
            gui.editing = false
          end
        end
      end
    end -- onEvent(...)

    return addElement(self, x, y, w, h)
  end -- menu(...)
  
  function gui.dropDown(x, y, w, h, items, selected, callBack, flags)
    callBack = callBack or doNothing
    flags = flags or lib.flags

    local self
    local showingMenu
    local drawingMenu
    local dropDown = lib.newGUI()
    local lh = select(2, lcd.sizeText("", flags))
    local height = math.min(0.75 * LCD_H, #items * lh)
    local top = (LCD_H - height) / 2

    dropDown.x = gui.translate(0, 0)
    top = math.min(top, y)
    top = math.max(top, y + h - height)

    local function dismissMenu()
      showingMenu = false
      gui.dismissPrompt()
    end
    
    function dropDown.fullScreenRefresh()
      if not dropDown.editing then
        dismissMenu()
        return
      end
      dropDown.drawFilledRectangle(x, top, w, height, lib.colors.primary2)
      dropDown.drawRectangle(x - 2, top - 2, w + 4, height + 4, lib.colors.primary1, 2)
      drawingMenu = true
    end
    
    local function onMenu(menu)
      dismissMenu()
      callBack(self)
    end
    
    self = dropDown.menu(x, top, w, height, items, onMenu, flags)
    self.selected = selected
    local drawMenu = self.draw
    
    function self.draw(focused)
      if drawingMenu then
        drawingMenu = false
        drawMenu(focused)
      else
        local flags = bit32.bor(VCENTER, lib.colors.primary1, getFlags(self))

        if focused then
          drawFocus(x, y, w, h)
        end
        gui.drawText(align(x, w, flags), y + h / 2, self.items[self.selected], flags)
        local dd = lh / 2
        local yy = y + (h - dd) / 2
        local xx = x + w - 1.15 * dd
        gui.drawTriangle(x + w, yy, (x + w + xx) / 2, yy + dd, xx, yy, lib.colors.primary1)
      end
    end

    local onMenu = self.onEvent
    
    function self.onEvent(event, touchState)
      if showingMenu then
        onMenu(event, touchState)
      elseif event == EVT_VIRTUAL_ENTER then
        -- Show drop down and let it take over while active
        showingMenu = true
        dropDown.onEvent(event)
        gui.showPrompt(dropDown)
      else
      end
    end
    
    local coverMenu = self.covers
    
    function self.covers(p, q)
      if showingMenu then
        return coverMenu(p, q)
      else
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- dropDown(...)
  
  function gui.horizontalSlider(x, y, w, value, min, max, delta, callBack)
    local self = {
      value = value,
      min = min,
      max = max,
      delta = delta,
      callBack = callBack or doNothing,
      editable = true
    }

    function self.draw(focused)
      local xdot = x + w * (self.value - self.min) / (self.max - self.min)
      
      local colorBar = lib.colors.primary3
      local colorDot = lib.colors.primary2
      local colorDotBorder = lib.colors.primary3
      
      if focused then
        colorDotBorder = lib.colors.active
        if gui.editing or scrolling then
          colorBar = lib.colors.primary1
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
          self.value = math.min(self.max, self.value + self.delta)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = math.max(self.min, self.value - self.delta)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        gui.editing = true
      end
      
      if event == EVT_TOUCH_SLIDE then
        local value = self.min + (self.max - self.min) * (touchState.x - x) / w
        value = math.min(self.max, value)
        value = math.max(self.min, value)
        self.value = self.min + self.delta * math.floor((value - self.min) / self.delta + 0.5)
      end
      
      if v0 ~= self.value then
        self.callBack(self)
      end
    end
    
    function self.covers(p, q)
      local xdot = x + w * (self.value - self.min) / (self.max - self.min)
      return ((p - xdot)^2 + (q - y)^2 <= 2 * SLIDER_DOT_RADIUS^2)
    end
    
    return addElement(self)
  end -- horizontalSlider(...)

  function gui.verticalSlider(x, y, h, value, min, max, delta, callBack)
    local self = {
      value = value,
      min = min,
      max = max,
      delta = delta,
      callBack = callBack or doNothing,
      editable = true
    }

    function self.draw(focused)
      local ydot = y + h * (1 - (self.value - self.min) / (self.max - self.min))
      
      local colorBar = lib.colors.primary3
      local colorDot = lib.colors.primary2
      local colorDotBorder = lib.colors.primary3
      
      if focused then
        colorDotBorder = lib.colors.active
        if gui.editing or scrolling then
          colorBar = lib.colors.primary1
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
          self.value = math.min(self.max, self.value + self.delta)
        elseif event == EVT_VIRTUAL_DEC then
          self.value = math.max(self.min, self.value - self.delta)
        end
      elseif event == EVT_VIRTUAL_ENTER then
        gui.editing = true
      end
      
      if event == EVT_TOUCH_SLIDE then
        local value = self.max - (self.max - self.min) * (touchState.y - y) / h
        value = math.min(self.max, value)
        value = math.max(self.min, value)
        self.value = self.min + self.delta * math.floor((value - self.min) / self.delta + 0.5)
      end

      if v0 ~= self.value then
        self.callBack(self)
      end
    end
    
    function self.covers(p, q)
      local ydot = y + h * (1 - (self.value - self.min) / (self.max - self.min))
      return ((p - x)^2 + (q - ydot)^2 <= 2 * SLIDER_DOT_RADIUS^2)
    end
    
    return addElement(self)
  end -- verticalSlider(...)

  -- Create a custom element
  function gui.custom(self, x, y, w, h)
    self.gui = gui
    self.lib = lib
    
    function self.drawFocus(color)
      drawFocus(self.x or x, self.y or y, self.w or w, self.h or h, color)
    end
    
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
    
    function self.covers(p, q)
      return (self.x <= p and p <= self.x + self.w and self.y <= q and q <= self.y + self.h)
    end

    return addElement(self, x, y, w, h)
  end
  
  return gui
end -- gui(...)

return lib
---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Version: 1.0.0   Date: 2021-12-20                                     --
-- Version: 1.0.1   Date: 2022-05-05                                     --
-- Version: 1.0.2   Date: 2022-11-20                                     --
-- Version: 1.0.2   Date: 2023-07                                        --
-- Version: 1.0.3   Date: 2023-12                                        --
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

local app_ver = "1.0.3"

local M = { }

-- Radius of slider dot
M.SLIDER_DOT_RADIUS = 10

-- better font size names
M.FONT_SIZES = {
    FONT_38 = XXLSIZE, -- 38px
    FONT_16 = DBLSIZE, -- 16px
    FONT_12 = MIDSIZE, -- 12px
    FONT_8  = 0,       -- Default 8px
    FONT_6  = SMLSIZE, -- 6px
}

-- Default flags and colors, can be changed by client
M.flags = 0
M.colors = {
    primary1 = COLOR_THEME_PRIMARY1,
    primary2 = COLOR_THEME_PRIMARY2,
    primary3 = COLOR_THEME_PRIMARY3,
    focus = COLOR_THEME_FOCUS,
    edit = COLOR_THEME_EDIT,
    active = COLOR_THEME_ACTIVE,
}

function M.getVer()
    return app_ver
end

-- Return true if the first arg matches any of the following args
function M.match(x, ...)
    for i, y in ipairs({ ... }) do
        if x == y then
            return true
        end
    end
    return false
end


-- Create a new GUI object with interactive screen elements
function M.newGUI()
    local gui = {
        x = 0,
        y = 0,
        editable = true,
    }

    local _ = {} -- internal members
    _.handles = { }
    _.elements = { }
    _.focus = 1
    _.scrolling = false
    _.lastEvent = 0


    function _.lcdSizeTextFixed(txt, font_size)
        local ts_w, ts_h = lcd.sizeText(txt, font_size)

        local v_offset = 0
        if font_size == M.FONT_SIZES.FONT_38 then
            v_offset = -11
        elseif font_size == M.FONT_SIZES.FONT_16 then
            v_offset = -5
        elseif font_size == M.FONT_SIZES.FONT_12 then
            v_offset = -4
        elseif font_size == M.FONT_SIZES.FONT_8 then
            v_offset = -3
        elseif font_size == M.FONT_SIZES.FONT_6 then
            v_offset = 0
        end
        return ts_w, ts_h +2*v_offset, v_offset
    end

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
        local ts_w, ts_h, v_offset = _.lcdSizeTextFixed(text, M.FONT_SIZES.FONT_8)
        lcd.drawText(x, y + v_offset, text, flags, inversColor)
        --lcd.drawText(x, y, text, flags, inversColor)
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
    function _.doNothing()
    end

    -- The default onChangeValue
    function _.onChangeDefault(delta, self)
        return self.value + delta
    end

    -- Adjust text according to horizontal alignment
    function _.align(x, w, flags)
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
        if #_.elements == 1 then
            return
        end
        color = color or M.colors.active
        gui.drawRectangle(x - 4, y - 2, w + 8, h + 2, color, 2)
    end -- drawFocus(...)

    -- Move focus to another element
    local function moveFocus(delta)
        local count = 0 -- Prevent infinite loop
        repeat
            _.focus = _.focus + delta
            if _.focus > #_.elements then
                _.focus = 1
            elseif _.focus < 1 then
                _.focus = #_.elements
            end
            count = count + 1
        until not (_.elements[_.focus].disabled or _.elements[_.focus].hidden) or count > #_.elements
    end -- moveFocus(...)

    -- Moved the focused element
    function gui.moveFocused(delta)
        if delta > 0 then
            delta = 1
        elseif delta < 0 then
            delta = -1
        end
        local idx = _.focus + delta
        if idx >= 1 and idx <= #_.elements then
            _.elements[_.focus], _.elements[idx] = _.elements[idx], _.elements[_.focus]
            _.focus = idx
        end
    end

    -- Add an element and return it to the client
    local function addElement(element, x, y, w, h)
        if not element.covers then
            function element.covers(p, q)
                return (x <= p and p <= x + w and y <= q and q <= y + h)
            end
        end

        _.elements[#_.elements+1] = element
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
        _.handles[event] = f
    end

    -- Show prompt
    function gui.showPrompt(prompt)
        M.prompt = prompt
    end

    -- Dismiss prompt
    function gui.dismissPrompt()
        M.prompt = nil
    end

    -----------------------------------------------------------------------------------------------

    -- Run an event cycle
    function gui.run(event, touchState)
        gui.draw(false)
        if event ~= nil then
            gui.onEvent(event, touchState)
        end
        _.lastEvent = event
    end -- run(...)

    -----------------------------------------------------------------------------------------------

    function gui.draw(focused)
        if gui.fullScreenRefresh then
            gui.fullScreenRefresh()
        end
        if focused then
            if gui.parent.editing then
                drawFocus(0, 0, gui.w, gui.h, M.colors.edit)
            else
                drawFocus(0, 0, gui.w, gui.h)
            end
        end
        local guiFocus = not gui.parent or (focused and gui.parent.editing)
        for idx, element in ipairs(_.elements) do
            -- Clients may provide an update function for elements
            if element.onUpdate then -- New name for method
                element.onUpdate(element)
            elseif element.update then -- For backward compatibility 
                element.update(element)
            end
            if not element.hidden then
                element.draw(_.focus == idx and guiFocus)
            end
        end
    end -- draw()

    -----------------------------------------------------------------------------------------------

    function gui.onEvent(event, touchState)
        -- Make sure that focused element is active
        if (_.elements[_.focus].disabled or _.elements[_.focus].hidden) then
            moveFocus(1)
            return
        end
        -- Is there an active prompt?
        if M.prompt and not M.showingPrompt then
            M.showingPrompt = true
            M.prompt.run(event, touchState)
            M.showingPrompt = false
            return
        end

        if event == 0 then
            return
        end

        if gui.parent and not gui.parent.editing then
            if event == EVT_VIRTUAL_ENTER then
                gui.parent.editing = true
            end
            return
        end

        -- non-zero event; process it
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

        -- ETX 2.8 rc 4 bug fix
        if _.scrolling and event == EVT_VIRTUAL_ENTER_LONG then
            return
        end
        -- If we put a finger down on a menu item and immediately slide, then we can scroll
        if event == EVT_TOUCH_SLIDE then
            if not _.scrolling then
                return
            end
        else
            _.scrolling = false
        end

        -- "Pre-processing" of touch events to simplify subsequent handling and support scrolling etc.
        if event == EVT_TOUCH_FIRST then
            if _.elements[_.focus].covers(touchState.x, touchState.y) then
                _.scrolling = true
            else
                if gui.editing then
                    return
                else
                    -- Did we touch another element?
                    for idx, element in ipairs(_.elements) do
                        if not (element.disabled or element.hidden) and element.covers(touchState.x, touchState.y) then
                            _.focus = idx
                            _.scrolling = true
                        end
                    end
                end
            end
        elseif event == EVT_TOUCH_TAP or (event == EVT_TOUCH_BREAK and _.lastEvent == EVT_TOUCH_FIRST) then
            if _.elements[_.focus].covers(touchState.x, touchState.y) then
                -- Convert TAP on focused element to ENTER
                event = EVT_VIRTUAL_ENTER
            elseif gui.editing then
                -- Convert a TAP off the element being edited to EXIT
                event = EVT_VIRTUAL_EXIT
            end
        end

        if gui.editing then -- Send the event directly to the element being edited
            _.elements[_.focus].onEvent(event, touchState)
        elseif event == EVT_VIRTUAL_NEXT then -- Move focus
            moveFocus(1)
        elseif event == EVT_VIRTUAL_PREV then
            moveFocus(-1)
        elseif event == EVT_VIRTUAL_EXIT and gui.parent then
            gui.parent.editing = false
        else
            if _.handles[event] then
                -- Is it being handled? Handler can modify event
                event = _.handles[event](event, touchState)
                -- If handler returned false or nil, then we are done
                if not event then
                    return
                end
            end
            _.elements[_.focus].onEvent(event, touchState)
        end
    end -- onEvent(...)

    -----------------------------------------------------------------------------------------------

    -- Create a text label
    function gui.label(x, y, w, h, title, flags)
        local self = {
            title = title,
            flags = bit32.bor(flags or M.flags, VCENTER, M.colors.primary1),
            disabled = true,
            hidden= false,
        }

        function self.draw(focused)
            local flags = getFlags(self)
            gui.drawText(_.align(x, w, flags), y + h / 2, self.title, flags)
        end

        -- We should not ever onEvent, but just in case...
        function self.onEvent(event, touchState)
            self.disabled = true
            moveFocus(1)
        end

        function self.covers(p, q)
            return false
        end

        addElement(self, x, y, w, h)
        return self
    end -- label(...)

    -----------------------------------------------------------------------------------------------

    -- Create a text label lines
    function gui.labelLines(x, y, w, h, title, flags)
        local self = {
            title = title,
            flags = bit32.bor(flags or M.flags, VCENTER, M.colors.primary1),
            disabled = true,
            hidden= false,
        }

        function self.draw(focused)
            local flags = getFlags(self)
            gui.drawTextLines(_.align(x, w, flags), y , w, h, self.title, flags)
        end

        -- We should not ever onEvent, but just in case...
        function self.onEvent(event, touchState)
            self.disabled = true
            moveFocus(1)
        end

        function self.covers(p, q)
            return false
        end

        addElement(self, x, y, w, h)
        return self
    end -- label(...)

    -----------------------------------------------------------------------------------------------

    -- Create a button to trigger a function
    function gui.button(x, y, w, h, title, callBack, flags)
        local self = {
            title = title,
            callBack = callBack or _.doNothing,
            flags = bit32.bor(flags or M.flags, CENTER, VCENTER),
            disabled = false,
            hidden= false
        }

        function self.draw(focused)
            if focused then
                drawFocus(x, y, w, h)
            end

            gui.drawFilledRectangle(x, y, w, h, M.colors.focus)
            gui.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(M.colors.primary2, self.flags))

            if self.disabled then
                gui.drawFilledRectangle(x, y, w, h, GREY, 7)
            end
        end

        function self.onEvent(event, touchState)
            if event == EVT_VIRTUAL_ENTER then
                return self.callBack(self)
            end
        end

        addElement(self, x, y, w, h)
        return self
    end -- button(...)

    -----------------------------------------------------------------------------------------------

    -- create a momentary button
    function gui.momentaryButton(x, y, w, h, title, callBack, flags)
        local self = {
          title = title,
          callBack = callBack or _.doNothing,
          flags = bit32.bor(flags or M.flags, CENTER, VCENTER),
          disabled = false,
          hidden = false
        }
    
        function self.draw(focused)
          local fg = M.colors.primary2
          local bg = M.colors.focus
          local border = M.colors.active
    
          if self.value then
            fg = M.colors.primary3
            bg = M.colors.active
            border = M.colors.focus
          end
    
          gui.drawFilledRectangle(x, y, w, h, bg)
          gui.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(fg, self.flags))
    
          if focused then
            gui.drawRectangle(x - 2, y - 2, w + 4, h + 4, border, 2)
          end
    
          if self.disabled then
            gui.drawFilledRectangle(x, y, w, h, GREY, 7)
          end
        end
       
        function self.onEvent(event, touchState)
            if (event == EVT_TOUCH_FIRST) then
              if (self.covers(touchState.x, touchState.y)) then
                gui.editing = true;
                self.value = true;
                return self.callBack(self);
              end
            elseif (event == EVT_VIRTUAL_ENTER_LONG) then
              gui.editing = true;
              self.value = true;
              return self.callBack(self);
            elseif ((event == EVT_TOUCH_BREAK) or (event == EVT_VIRTUAL_EXIT)) then
              gui.editing = false;
              self.value = false;
              return self.callBack(self);
            end
        end

        addElement(self, x, y, w, h)
    
        return self
    end

    -----------------------------------------------------------------------------------------------

    -- Create a toggle button that turns on/off. callBack gets true/false
    function gui.toggleButton(x, y, w, h, title, value, callBack, flags)
        local self = {
            title = title,
            value = value,
            callBack = callBack or _.doNothing,
            flags = bit32.bor(flags or M.flags, CENTER, VCENTER),
            disabled = false,
            hidden= false
        }

        function self.draw(focused)
            local fg = M.colors.primary2
            local bg = M.colors.focus
            local border = M.colors.active

            if self.value then
                fg = M.colors.primary3
                bg = M.colors.active
                border = M.colors.focus
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

        addElement(self, x, y, w, h)
        return self
    end -- toggleButton(...)

    -----------------------------------------------------------------------------------------------

    -- Create a number that can be edited
    function gui.number(x, y, w, h, value, onChangeValue, flags, min, max)
        local self = {
            value = value,
            onChangeValue = onChangeValue or _.onChangeDefault,
            flags = bit32.bor(flags or M.flags, VCENTER),
            editable = true,
            disabled = false,
            hidden= false,
            min_val = min or 0,
            max_val = max or 100,
        }

        local d0

        function self.draw(focused)
            local flags = getFlags(self)
            local fg = M.colors.primary1

            if focused then
                drawFocus(x, y, w, h)

                if gui.editing then
                    fg = M.colors.primary2
                    gui.drawFilledRectangle(x, y, w, h, M.colors.edit)
                end
            end
            if type(self.value) == "string" then
                gui.drawText(_.align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
            else
                gui.drawNumber(_.align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
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
                    if self.value < self.max_val then
                        self.value = self.onChangeValue(1, self)
                    end
                elseif event == EVT_VIRTUAL_DEC then
                    if self.value > self.min_val then
                        self.value = self.onChangeValue(-1, self)
                    end
                elseif event == EVT_TOUCH_FIRST then
                    d0 = 0
                elseif event == EVT_TOUCH_SLIDE then
                    local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
                    if d ~= d0 then
                        self.value = self.onChangeValue(d - d0, self)
                        d0 = d
                    end
                end
            elseif event == EVT_VIRTUAL_ENTER then
                value = self.value
                gui.editing = true
            end
        end -- onEvent(...)

        addElement(self, x, y, w, h)
        return self
    end -- number(...)

    -----------------------------------------------------------------------------------------------

    -- Create a display of current time on timer[tmr]
    -- Set timer.value to show a different value
    function gui.timer(x, y, w, h, tmr, onChangeValue, flags)
        local self = {
            tmr = tmr,
            onChangeValue = onChangeValue or _.onChangeDefault,
            flags = bit32.bor(flags or M.flags, VCENTER),
            disabled = false,
            hidden= false,
            editable = true
        }
        local value
        local d0

        function self.draw(focused)
            local flags = getFlags(self)
            local fg = M.colors.primary1
            -- self.value overrides the timer value
            local value = self.value or model.getTimer(self.tmr).value

            if focused then
                drawFocus(x, y, w, h)

                if gui.editing then
                    fg = M.colors.primary2
                    gui.drawFilledRectangle(x, y, w, h, M.colors.edit)
                end
            end
            if type(value) == "string" then
                gui.drawText(_.align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
            else
                gui.drawTimer(_.align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
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
                    self.value = self.onChangeValue(1, self)
                elseif event == EVT_VIRTUAL_DEC then
                    self.value = self.onChangeValue(-1, self)
                elseif event == EVT_TOUCH_FIRST then
                    d0 = 0
                elseif event == EVT_TOUCH_SLIDE then
                    local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
                    if d ~= d0 then
                        self.value = self.onChangeValue(d - d0, self)
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

        addElement(self, x, y, w, h)
        return self
    end -- timer(...)

    -----------------------------------------------------------------------------------------------

    function gui.menu(x, y, w, h, items, callBack, flags)
        local self = {
            items = items or { "No items!" },
            flags = bit32.bor(flags or M.flags, VCENTER),
            disabled = false,
            hidden= false,
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

        callBack = callBack or _.doNothing

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
                bgColor = M.colors.edit
            else
                selected = self.selected
                bgColor = M.colors.focus
            end

            for i = 0, visibleCount - 1 do
                local j = firstVisible + i
                local y = y + i * lh

                if j == selected then
                    gui.drawFilledRectangle(x, y, w, lh, bgColor)
                    gui.drawText(_.align(x, w, flags), y + lh / 2, self.items[j], bit32.bor(M.colors.primary2, flags))
                else
                    gui.drawText(_.align(x, w, flags), y + lh / 2, self.items[j], bit32.bor(M.colors.primary1, flags))
                end
            end

            if focused then
                drawFocus(x, y, w, h)
            end
        end -- draw()

        function self.onEvent(event, touchState)
            local visibleCount = math.min(visibleCount, #self.items)

            if moving ~= 0 then
                if M.match(event, EVT_TOUCH_FIRST, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
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
                    if _.scrolling then
                        if touchState.swipeUp then
                            moving = 1
                        elseif touchState.swipeDown then
                            moving = -1
                        elseif touchState.startX then
                            setFirstVisible(firstVisibleScrolling + math.floor((touchState.startY - touchState.y) / lh + 0.5))
                        end
                    end
                else
                    _.scrolling = false

                    if event == EVT_TOUCH_FIRST then
                        _.scrolling = true
                        firstVisibleScrolling = firstVisible
                    elseif M.match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV) then
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

        addElement(self, x, y, w, h)
        return self
    end -- menu(...)

    -----------------------------------------------------------------------------------------------

    function gui.dropDown(x, y, w, h, items, selected, callBack, flags)
        callBack = callBack or _.doNothing
        flags = flags or M.flags

        local self
        local showingMenu
        local drawingMenu
        local dropDown = M.newGUI()
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
            dropDown.drawFilledRectangle(x, top, w, height, M.colors.primary2)
            dropDown.drawRectangle(x - 2, top - 2, w + 4, height + 4, M.colors.primary1, 2)
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
                local flags = bit32.bor(VCENTER, M.colors.primary1, getFlags(self))

                if focused then
                    drawFocus(x, y, w, h)
                end
                gui.drawText(_.align(x, w, flags), y + h / 2, self.items[self.selected], flags)
                local dd = lh / 2
                local yy = y + (h - dd) / 2
                local xx = (x-5) + w - 1.15 * dd
                gui.drawTriangle(x-5 + w, yy, (x-5 + w + xx) / 2, yy + dd, xx, yy, M.colors.primary1)
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

        addElement(self, x, y, w, h)
        return self
    end -- dropDown(...)

    -----------------------------------------------------------------------------------------------

    function gui.horizontalSlider(x, y, w, value, min, max, delta, callBack)
        local self = {
            value = value,
            min = min,
            max = max,
            delta = delta,
            callBack = callBack or _.doNothing,
            disabled = false,
            hidden= false,
            editable = true
        }

        function self.draw(focused)
            local xdot = x + w * (self.value - self.min) / (self.max - self.min)

            local colorBar = M.colors.primary3
            local colorDot = M.colors.primary2
            local colorDotBorder = M.colors.primary3

            if focused then
                colorDotBorder = M.colors.active
                if gui.editing or _.scrolling then
                    colorBar = M.colors.primary1
                    colorDot = M.colors.edit
                end
            end

            gui.drawFilledRectangle(x, y - 2, w, 5, colorBar)
            gui.drawFilledCircle(xdot, y, M.SLIDER_DOT_RADIUS, colorDot)
            for i = -1, 1 do
                gui.drawCircle(xdot, y, M.SLIDER_DOT_RADIUS + i, colorDotBorder)
            end
        end

        function self.onEvent(event, touchState)
            local v0 = self.value

            if gui.editing then
                if M.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
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
            return ((p - xdot) ^ 2 + (q - y) ^ 2 <= 2 * M.SLIDER_DOT_RADIUS ^ 2)
        end

        addElement(self)
        return self
    end -- horizontalSlider(...)

    -----------------------------------------------------------------------------------------------

    function gui.verticalSlider(x, y, h, value, min, max, delta, callBack)
        local self = {
            value = value,
            min = min,
            max = max,
            delta = delta,
            callBack = callBack or _.doNothing,
            disabled = false,
            hidden= false,
            editable = true
        }

        function self.draw(focused)
            local ydot = y + h * (1 - (self.value - self.min) / (self.max - self.min))

            local colorBar = M.colors.primary3
            local colorDot = M.colors.primary2
            local colorDotBorder = M.colors.primary3

            if focused then
                colorDotBorder = M.colors.active
                if gui.editing or _.scrolling then
                    colorBar = M.colors.primary1
                    colorDot = M.colors.edit
                end
            end

            gui.drawFilledRectangle(x - 2, y, 5, h, colorBar)
            gui.drawFilledCircle(x, ydot, M.SLIDER_DOT_RADIUS, colorDot)
            for i = -1, 1 do
                gui.drawCircle(x, ydot, M.SLIDER_DOT_RADIUS + i, colorDotBorder)
            end
        end

        function self.onEvent(event, touchState)
            local v0 = self.value

            if gui.editing then
                if M.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
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
            return ((p - x) ^ 2 + (q - ydot) ^ 2 <= 2 * M.SLIDER_DOT_RADIUS ^ 2)
        end

        addElement(self)
        return self
    end -- verticalSlider(...)

    -----------------------------------------------------------------------------------------------

    -- Create a custom element
    function gui.custom(self, x, y, w, h)
        self.gui = gui
        self.lib = M

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

        addElement(self, x, y, w, h)
        return self
    end

    -----------------------------------------------------------------------------------------------

    -- Create a nested gui
    function gui.gui(x, y, w, h)
        local self = M.newGUI()
        self.parent = gui
        self.editing = false
        self.x, self.y, self.w, self.h = x, y, w, h

        function self.covers(p, q)
            return (self.x <= p and p <= self.x + self.w and self.y <= q and q <= self.y + self.h)
        end

        addElement(self, x, y, w, h)
        return self
    end


    -----------------------------------------------------------------------------------------------
    return gui

end -- gui(...)

return M

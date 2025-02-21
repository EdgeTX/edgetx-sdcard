---------------------------------------------------------------------------
-- SoarETX outputs configuration widget, loadable part                   --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2025-01-20                                                   --
-- Version: 1.2.4                                                        --
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
local libGUI =  soarGlobals.libGUI
local gui
local colors =  libGUI.colors
local title =   "Outputs"

local warningPrompt = libGUI.newGUI()         -- Warning prompt shown on opening
local editPrompt = libGUI.newGUI()            -- Prompt asking what to edit
local channels                                -- List sub-GUIs for named channels
local focusNamed = 0                          -- Index of sub-GUI in focus
local firstLine = 1                           -- Index of sub-GUI on the first line
local editPoints = 0                          -- Select what points to edit

local N = 32                                  -- Highest channel number to swap
local MAXOUT = 1500                           -- Maximum output value
local MINDIF = 100                            -- Minimum difference between lower, center and upper values
local CHAN_BASE = getFieldInfo("ch1").id - 1  -- Base of channel sources

-- Screen drawing constants
local HEADER =     40
local MARGIN =     10
local TOP =        50
local ROW =        38
local CTR =        340
local STEP =       10
local SCALE =      12
local MAXOUT =     1500
local MINDIF =     100

-- Function that gives the active points for a given value of editPoints
local function activePoints(ep)
  local p = { 0, 0, 0 }
  if ep == 1 then
    p[1] = 1
    p[2] = 1
    p[3] = 1
  elseif ep == 2 then
    p[1] = -1
    p[3] = 1
  elseif ep == 3 then
    p[1] = 1
  elseif ep == 4 then
    p[2] = 1
  else -- 5
    p[3] = 1
  end
  return p
end -- activePoints(...)

-- Setup warning prompt
do
  local PROMPT_W = 300
  local PROMPT_H = 172
  warningPrompt.x = (LCD_W - PROMPT_W) / 2
  warningPrompt.y = (LCD_H - PROMPT_H) / 2

  function warningPrompt.fullScreenRefresh()
    local txt = "Please disable the motor!\n\n" ..
                "Sudden spikes may occur when channels are moved.\n\n" ..
                "Press ENTER to proceed."

    warningPrompt.drawFilledRectangle(0, 0, PROMPT_W, HEADER, COLOR_THEME_SECONDARY1)
    warningPrompt.drawFilledRectangle(0, HEADER, PROMPT_W, PROMPT_H - HEADER, libGUI.colors.primary2)
    warningPrompt.drawRectangle(0, 0, PROMPT_W, PROMPT_H, libGUI.colors.primary1, 2)
    warningPrompt.drawText(MARGIN, HEADER / 2, "W A R N I N G", DBLSIZE + VCENTER + libGUI.colors.primary2)
    warningPrompt.drawTextLines(MARGIN, HEADER + MARGIN, PROMPT_W - 2 * MARGIN, PROMPT_H - 2 * MARGIN, txt)
  end

  -- Make a dismiss button from a custom element
  local custom = warningPrompt.custom({ }, PROMPT_W - 30, 10, 20, 20)

  function custom.draw(focused)
    warningPrompt.drawRectangle(PROMPT_W - 30, 10, 20, 20, libGUI.colors.primary2)
    warningPrompt.drawText(PROMPT_W - 20, 20, "X", MIDSIZE + CENTER + VCENTER + libGUI.colors.primary2)
    if focused then
      custom.drawFocus()
    end
  end

  function custom.onEvent(event, touchState)
    if event == EVT_VIRTUAL_ENTER then
      gui.dismissPrompt()
    end
  end
end -- Warning prompt

-- Setup prompt for selecting what to edit
do
  local PROMPT_W = 280
  local PROMPT_H = 210
  local MENU_W = 75
  local MENU_H = PROMPT_H - HEADER - 2 * MARGIN
  local X = { 110, 180, 250 }
  local MAX_D = 20
  local t0 = 0
  local h = select(2, lcd.sizeText("", libGUI.flags))
  local menuItems = {
    "Offset",
    "Range",
    "Lower",
    "Center",
    "Upper"
  }
  editPrompt.x = (LCD_W - PROMPT_W) / 2
  editPrompt.y = (LCD_H - PROMPT_H) / 2

  function editPrompt.fullScreenRefresh()
    if not editPrompt.editing then
      editPoints = 0
      gui.dismissPrompt()
      gui.onEvent(EVT_VIRTUAL_EXIT)
      return
    end

    editPrompt.drawFilledRectangle(0, 0, PROMPT_W, HEADER, COLOR_THEME_SECONDARY1)
    editPrompt.drawFilledRectangle(0, HEADER, PROMPT_W, PROMPT_H - HEADER, libGUI.colors.primary2)
    editPrompt.drawRectangle(0, 0, PROMPT_W, PROMPT_H, libGUI.colors.primary1, 2)
    editPrompt.drawText(MARGIN, HEADER / 2, "Select what to edit:", DBLSIZE + VCENTER + libGUI.colors.primary2)

    local y = HEADER + MARGIN + h / 2

    for i = 1, 5 do
      local p = activePoints(i)
      editPrompt.drawFilledRectangle(X[1], y - 2, X[3] - X[1], 5, libGUI.colors.primary1)
      for j = 1, 3 do
        if p[j] == 0 then
          editPrompt.drawFilledRectangle(X[j] - 2, y - 10, 5, 20, libGUI.colors.primary1)
        else
          editPrompt.drawFilledCircle(X[j], y, 10, libGUI.colors.edit)
          for i = -1, 1 do
            editPrompt.drawCircle(X[j], y, 10 + i, libGUI.colors.active)
          end
        end
      end
      y = y + h
    end
  end -- fullScreenRefresh()

  local function onMenu(menu)
    editPoints = menu.selected
    gui.dismissPrompt()
  end -- onMenu(...)

  editPrompt.menu(MARGIN, HEADER + MARGIN, MENU_W, MENU_H, menuItems, onMenu)
end -- Prompt for selecting what to edit

-- Move output channel by swapping with previous or next; direction = -1 or +1
local function MoveOutput(direction, channel)
	local m = { } -- Channel indices
	m[1] = channel.iChannel -- Channel to move
	m[2] = m[1] + direction -- Neighbouring channel to swap

	-- Are we at then end?
	if m[2] < 1 or m[2] > N then
		playTone(3000, 100, 0, PLAY_NOW)
		return
	end

	local outputs = { } -- List of output tables
	local mixes = { }   -- List of lists of mixer tables

	-- Read channel into tables
	for i = 1, 2 do
		outputs[i] = model.getOutput(m[i] - 1)

		-- Read list of mixer lines
		mixes[i] = { }
		for j = 1, model.getMixesCount(m[i] - 1) do
			mixes[i][j] = model.getMix(m[i] - 1, j - 1)
		end
	end

	-- Write back swapped data
	for i = 1, 2 do
		model.setOutput(m[i] - 1, outputs[3 - i])

		-- Delete existing mixer lines
		for j = 1, model.getMixesCount(m[i] - 1) do
			model.deleteMix(m[i] - 1, 0)
		end

		-- Write back mixer lines
		for j, mix in pairs(mixes[3 - i]) do
			model.insertMix(m[i] - 1, j - 1, mix)
		end
	end

	-- Swap sources for the two channels in all mixes
	for i = 1, N do
		local mixes = { }   -- List of mixer tables
		local dirty = false -- If any sources were swapped, then write back data

		-- Read mixer lines and swap sources if they match the two channels being swapped
		for j = 1, model.getMixesCount(i - 1) do
			mixes[j] = model.getMix(i - 1, j - 1)
			if mixes[j].source == m[1] + CHAN_BASE then
				dirty = true
				mixes[j].source = m[2] + CHAN_BASE
			elseif mixes[j].source == m[2] + CHAN_BASE then
				dirty = true
				mixes[j].source = m[1] + CHAN_BASE
			end
		end

		-- Do we have to write back data?
		if dirty then
			-- Delete existing mixer lines
			for j = 1, model.getMixesCount(i - 1) do
				model.deleteMix(i - 1, 0)
			end

			-- Write new mixer lines
			for j, mix in ipairs(mixes) do
				model.insertMix(i - 1, j - 1, mix)
			end
		end
	end

	-- Update channel GUI(s) on the screen
  channel.iChannel = m[2]
  channel.output = outputs[1]
  local iNamed2 = channel.iNamed + direction
  local channel2 = channels[iNamed2]
	if channel2 and channel2.iChannel == m[2] then
		-- Swapping two named channels!
    channel2.iChannel = m[1]
    channel2.output = outputs[2]
    channels[channel.iNamed], channels[iNamed2] = channel2, channel
    channel.iNamed, channel2.iNamed = iNamed2, channel.iNamed
		gui.moveFocused(direction)
	end
end -- MoveOutput()

local function init()
  -- Start building GUI from scratch
  gui = libGUI.newGUI()
  gui.showPrompt(warningPrompt)

  function gui.fullScreenRefresh()
    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(MARGIN, HEADER / 2 - 2, "Configure Outputs", DBLSIZE + VCENTER + colors.primary2)

    -- Row background
    for i = 0, 6 do
      local y = HEADER + i * ROW
      if i % 2 == 1 then
        lcd.drawFilledRectangle(0, y, LCD_W, ROW, COLOR_THEME_SECONDARY2)
      else
        lcd.drawFilledRectangle(0, y, LCD_W, ROW, COLOR_THEME_SECONDARY3)
      end
    end

    -- Adjust scroll for channels
    if focusNamed > 0 then
      if focusNamed < firstLine then
        firstLine = focusNamed
      elseif firstLine + 5 < focusNamed then
        firstLine = focusNamed - 5
      end
    end
    focusNamed = 0

    -- Draw vertical reference lines
    for i = -6, 6 do
      local x = CTR - i * MAXOUT / (SCALE * 6) + 2
      lcd.drawLine(x, HEADER, x, HEADER + 6 * ROW, DOTTED, FORCE, COLOR_THEME_DISABLED)
    end
  end

  -- Close button
  local buttonClose = gui.custom({ }, LCD_W - 34, 6, 28, 28)

  function buttonClose.draw(focused)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
    lcd.drawText(LCD_W - 20, 20, "X", CENTER + VCENTER + MIDSIZE + colors.primary2)

    if focused then
      buttonClose.drawFocus()
    end
  end

  function buttonClose.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      lcd.exitFullScreen()
    end
  end

	-- Build the list of named channels, each in their own movable GUI
  do
    local HEIGHT = ROW - 8
    local iNamed = 0
    channels = { }

    for iChannel = 1, N do
      local output = model.getOutput(iChannel - 1)

      if output and output.name ~= "" then
        local channel = gui.gui(2, LCD_H, LCD_W - 4, ROW - 4)
        local d0

        iNamed = iNamed + 1
        channels[iNamed] = channel
        channel.iNamed = iNamed
        channel.iChannel = iChannel
        channel.output = output

        -- Hack the sub-GUI's draw function to do a few extra things
        local draw = channel.draw
        function channel.draw(focused)
          -- Needed to adjust scroll in fullScreenRefresh()
          if focused then
            focusNamed = channel.iNamed
          end
          -- If channel is not visible, place it outside the screen to avoid receiving touch events
          if channel.iNamed < firstLine or channel.iNamed > firstLine + 5 then
            channel.y = LCD_H
          else
            channel.y = HEADER + (channel.iNamed - firstLine) * ROW + 2
            draw(focused)
          end
        end

        -- Hack the sub-GUI's onEvent function to do finger scrolling
        local onEvent = channel.onEvent
        function channel.onEvent(event, touchState)
          if event == EVT_TOUCH_SLIDE and not channel.editing then
            firstLine = math.floor(channel.iNamed - (touchState.y - HEADER - ROW / 2) / ROW + 0.5)
            firstLine = math.min(firstLine, #channels - 5, channel.iNamed)
            firstLine = math.max(firstLine, 1, channel.iNamed - 5)
          else
            onEvent(event, touchState)
          end
        end -- onEvent(...)

        -- Custom element for changing output channel (and moving all mixer lines etc.)
        local nbrChannel = channel.custom({ }, 2, 2, 30, HEIGHT)

        function nbrChannel.draw(focused)
          local fg = libGUI.colors.primary1
          if focused then
            nbrChannel.drawFocus()
            if channel.editing then
              fg = libGUI.colors.primary2
              channel.drawFilledRectangle(2, 2, 30, HEIGHT, libGUI.colors.edit)
            end
          end
          channel.drawNumber(30, HEIGHT / 2 + 2, channel.iChannel, libGUI.flags + VCENTER + RIGHT + fg)
        end

        function nbrChannel.onEvent(event, touchState)
          if channel.editing then
            if libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
              channel.editing = false
            elseif event == EVT_VIRTUAL_INC then
              MoveOutput(1, channel)
            elseif event == EVT_VIRTUAL_DEC then
              MoveOutput(-1, channel)
            elseif event == EVT_TOUCH_FIRST then
              d0 = 0
            elseif event == EVT_TOUCH_SLIDE then
              local d = math.floor((touchState.y - touchState.startY) / ROW + 0.5)
              if d ~= d0 then
                MoveOutput(d - d0, channel)
                d0 = d
              end
            end
          elseif event == EVT_VIRTUAL_ENTER then
            channel.editing = true
          end
        end -- onEvent(...)

        -- Label for channel name
        local lblName = channel.label(32, 2, 140, HEIGHT, ". " .. channel.output.name)

        -- Custom element to invert output direction
        local revert = channel.custom({ }, 172, 2, 30, HEIGHT)

        function revert.draw(focused)
          local y = HEIGHT / 2 + 3
          if channel.output.revert == 1 then
            channel.drawFilledRectangle(178, y - 1, 19, 3, colors.primary1)
            for x = 177, 180 do
              channel.drawLine(x, y, x + 8, y - 8, SOLID, colors.primary1)
              channel.drawLine(x, y, x + 8, y + 8, SOLID, colors.primary1)
            end
          else
            channel.drawFilledRectangle(177, y - 1, 19, 3, colors.primary1)
            for x = 194, 197 do
              channel.drawLine(x, y, x - 8, y - 8, SOLID, colors.primary1)
              channel.drawLine(x, y, x - 8, y + 8, SOLID, colors.primary1)
            end
          end

          function revert.onEvent(event, touchState)
            if event == EVT_VIRTUAL_ENTER then
              channel.output.revert = 1 - channel.output.revert
              model.setOutput(channel.iChannel - 1, channel.output)
            end
          end

          if focused then
            revert.drawFocus()
          end
        end

        -- Custom element to adjust center and end points
        do
          local interval = channel.custom({ }, 210, 2, 264, HEIGHT)
          interval.editable = true
          local flags = SMLSIZE + CENTER + INVERS + libGUI.colors.primary2
          local x
          local y = HEIGHT / 2 + 2
          local yLbl = y - 12 - select(2, lcd.sizeText("", flags))
          local iScroll = 0

          function interval.draw(focused)
            local output = channel.output
            local p = { 0, 0, 0 }
            local colorBar = libGUI.colors.primary3
            local colorDot = libGUI.colors.primary2
            local colorDotBorder = libGUI.colors.primary3

            x = {
              CTR + output.min / SCALE,
              CTR + output.offset / SCALE,
              CTR + output.max / SCALE
            }
            if focused then
              colorDotBorder = libGUI.colors.active
              if channel.editing then
                -- Draw value labels
                channel.drawNumber(x[1], yLbl, 0.1 * output.min, flags)
                channel.drawNumber(x[2], yLbl, 0.1 * output.offset, flags)
                channel.drawNumber(x[3], yLbl, 0.1 * output.max, flags)
                colorBar = libGUI.colors.primary1
                colorDot = libGUI.colors.edit
                p = activePoints(editPoints)
              else
                interval.drawFocus()
              end
            end
            -- Draw figure
            channel.drawFilledRectangle(x[1], y - 2, x[3] - x[1], 5, colorBar)
            for j = 1, 3 do
              if p[j] == 0 then
                channel.drawFilledRectangle(x[j] - 1, y - 10, 3, 20, colorBar)
              else
                channel.drawFilledCircle(x[j], y, 10, colorDot)
                for i = -1, 1 do
                  channel.drawCircle(x[j], y, 10 + i, colorDotBorder)
                end
              end
            end
            -- Draw position indicators
            local outX = getValue(CHAN_BASE + channel.iChannel)
            if outX >= 0 then
              outX = output.offset + math.min(outX, 1024) * (output.max - output.offset) / 1024
            else
              outX = output.offset + math.max(outX, -1024) * (output.offset - output.min) / 1024
            end
            outX = CTR + outX / SCALE
            channel.drawFilledTriangle(outX, y - 3, outX - 3, y - 9, outX + 3, y - 9, colorBar)
            channel.drawLine(outX, y - 2, outX, y + 2, SOLID, colorBar)
            channel.drawFilledTriangle(outX, y + 3, outX - 3, y + 9, outX + 3, y + 9, colorBar)
          end -- draw(...)

          local RR = 14 ^ 2

          local function ptCovers(p, q)
            local ap = activePoints(editPoints)

            for i = 1, 3 do
              if ap[i] ~= 0 and (x[i] - p) ^ 2 + (y - q) ^ 2 <= RR then
                return i
              end
            end
            return 0
          end -- ptCovers(...)

          local function adjustPoints(d)
            local output = channel.output
            local p = activePoints(editPoints)
            local min = output.min
            local ctr = output.offset
            local max = output.max

            -- Check limits
            if p[1] == -1 then
              d = math.min(d, math.max(0, MAXOUT + min))
            elseif p[1] == 1 then
              d = math.max(d, math.min(0, -(MAXOUT + min)))
            end

            if p[2] - p[1] == 1 then
              d = math.max(d, math.min(0, MINDIF + min - ctr))
            elseif p[2] - p[1] == -1 then
              d = math.min(d, math.max(0, ctr - min - MINDIF))
            end

            if p[3] - p[2] == 1 then
              d = math.max(d, math.min(0, MINDIF + ctr - max))
            elseif p[3] - p[2] == -1 then
              d = math.min(d, math.max(0, max - ctr - MINDIF))
            end

            if p[3] == 1 then
              d = math.min(d, math.max(0, MAXOUT - max))
            end

            -- Update output values
            output.min = min + p[1] * d
            output.offset = ctr + p[2] * d
            output.max = max + p[3] * d

            -- Write back data
            model.setOutput(channel.iChannel - 1, output)
          end

          function interval.onEvent(event, touchState)
            if event == EVT_VIRTUAL_ENTER and not channel.editing then
              channel.editing = true
              editPrompt.onEvent(EVT_VIRTUAL_ENTER)
              channel.showPrompt(editPrompt)
              return
            end

            if event == EVT_TOUCH_SLIDE and iScroll > 0 then
              local p = activePoints(editPoints)[iScroll]
              local d = STEP * math.floor(p * (touchState.x - x[iScroll]) * SCALE / STEP + 0.5)
              adjustPoints(d)
            else
              iScroll = 0
            end

            if event == EVT_TOUCH_FIRST then
              iScroll = ptCovers(touchState.x, touchState.y)
              if iScroll > 0 then
                x0 = x[iScroll]
              end
            elseif libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
              editPoints = 0
              channel.editing = false
            elseif event == EVT_VIRTUAL_INC then
              adjustPoints(STEP)
            elseif event == EVT_VIRTUAL_DEC then
              adjustPoints(-STEP)
            end
          end -- onEvent(...)
        end -- Setup interval
      end
    end
  end
end -- init()

function widget.refresh(event, touchState)
  if not event then
    gui = nil
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif gui == nil then
    init()
    return
  end

  gui.run(event, touchState)
end -- refresh(...)

function widget.background()
  gui = nil
end -- background()

---------------------------------------------------------------------------
-- SoarETX F3K score keeper, loadable component                          --
--                                                                       --
-- Author:  Frankie Arzu/ Jesper Frickmann      			             --
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

local widget, soarGlobals = ...
local libGUI              = soarGlobals.libGUI
local colors              = libGUI.colors

-- GUIs for the different screens and popups
local screenTask          = libGUI.newGUI()

-- Screen drawing constants
local HEADER              = 40
local LEFT                = 40
local RGT                 = LCD_W - 18
local TOP                 = 50
local BOTTOM              = LCD_H - 30
local LINE                = 60
local LINE2               = 28
local HEIGHT              = 42
local HEIGHT2             = 18
local BUTTON_W            = 86
local PROMPT_W            = 260
local PROMPT_H            = 170
local PROMPT_M            = 30
local N_LINES             = 5
local COL2                = (LCD_W - BUTTON_W) / 2
local BOT_ROW             = LCD_H - 60

-- Constants
local LS_ALT              = 0 -- LS1 allowing altitude calls
local LS_ALT10            = 7 -- LS8 for altitude calls every 10 sec.

local LS_TRIGGER          = 8 -- LS9
local LS_ARM              = 22 --LS23

local GV_FLT_TMR          = 8 -- GV8 for the flight timer
local FM_LAUNCH           = 2 -- Launch/motor flight mode

-- Program states
local STATE_INITIAL       = 0  -- Set flight time before the flight
local STATE_MOTOR         = 1  -- Motor running
local STATE_GLIDE         = 2  -- Gliding
local STATE_LANDINGPTS    = 3  -- Landed, input landing points
local STATE_STARTHEIGHT   = 4  -- Input start height
local STATE_TIME          = 5  -- Input flight time
local STATE_SAVE          = 6  -- Ready to save
local state                    -- Current program state

local prevFM              = getFlightMode() -- Used for detecting when FM changes
local prevFt                   -- Previous value of flight timer
local prevArm                  -- Previous value of Arm
local prevTrig            = false -- Previous vakue of Trigger
local prevMt                   -- Previous Motor Time

-- Other common variables
--local counts  = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45 } -- Flight timer countdown
--local countIndex              -- Index of timer count

local flightTimer             -- Flight timer
local motorTimer              -- Motor Timer

local callAlt             = false
local nextCall            = 0

local prevCnt             = 0

local startHeight         = 0
local offTime             = 0 -- Motor Off time after Initial Climb
local landingPts          = 0


-- Browsing scores
local SCORE_FILE = "/LOGS/JF F5J Scores.csv"

-- Handle transitions between program states
local function GotoState(newState)
	print("GotoState:" .. newState)

	state = newState

	-- Stop blinking
	screenTask.timer0.blink = false

	if state == STATE_INITIAL then
		model.setGlobalVariable(GV_FLT_TMR, 0, 0)
		screenTask.labelInfo.title = "INITIAL"
		screenTask.labelTimer0.title = "Target:"
		screenTask.locked = false

	elseif state == STATE_MOTOR then
		model.setGlobalVariable(GV_FLT_TMR, 0, 1)
		screenTask.labelInfo.title = "Motor ON"
		screenTask.labelTimer0.title = "Flight:"
		screenTask.locked = true

	elseif state == STATE_GLIDE then
		model.setGlobalVariable(GV_FLT_TMR, 0, 1)
		screenTask.labelInfo.title = "Soaring .."
		screenTask.labelTimer0.title = "Flight:"
		screenTask.locked = true

	elseif state == STATE_LANDINGPTS then
		screenTask.labelInfo.title = "Landed. Launch Alt =" .. startHeight
	elseif state == STATE_TIME then
		screenTask.labelInfo.title = "TODO:Enter Time/Landing"
	elseif state == STATE_SAVE then
		screenTask.labelInfo.title = "TODO: Save Data"
	end

	-- Configure "button3"
	--screenTask.button3.disabled = false
	--screenTask.button3.title = "Button3"

	-- Configure info text label
	--screenTask.labelInfo.title = " Info Label"
end -- GotoState()

-- Function for setting up a task
local function SetupTask(taskName)
	screenTask.title = taskName
end -- SetupTask(...)

-- Reset altimeter
local function ResetAlt()
	for i = 0, 31 do
		if model.getSensor(i).name == "Alt" then
			model.resetSensor(i)
			break
		end
	end
end

local function TargetTime()
	return model.getTimer(0).start
end -- TargetTime()

-- Initialize variables before flight
local function InitializeFlight()
	local targetTime = TargetTime()

	-- Get ready to count down
	--countIndex = #counts
	--while countIndex > 1 and counts[countIndex] >= targetTime do
	--	countIndex = countIndex - 1
	--end

	-- Set flight timer
	model.setTimer(0, { start = targetTime, value = targetTime })
	flightTimer = targetTime
	prevFt = targetTime

	-- Set Motor Timer
	model.setTimer(1, { start = 0, value = 0 })

	landingPts = 0
	startHeight = 100 -- default if no Alt

	GotoState(STATE_INITIAL)
end --  InitializeFlight()

local function playMotorTime(motorTimer)
	local mt = motorTimer.value -- Current motor timer value
	local sayt               -- Timer value to announce (we don't have time to say "twenty-something")

	local cnt
	if mt <= 20 then
		cnt = 5; sayt = mt
	elseif mt < 30 then
		cnt = 1; sayt = mt - 20
	else
		cnt = 1; sayt = mt
	end

	if math.floor(prevMt / cnt) < math.floor(mt / cnt) then
		playNumber(sayt, 0)
	end

	prevMt = mt
end -- playMotorTime

local function playFlightTimer(flightTimer)
	local ft = flightTimer.value

	-- Count down flight time
	local cnt
	if ft > 120 then
		cnt = 60
	elseif ft > 60 then
		cnt = 15
	elseif ft > 10 then
		cnt = 5
	else
		cnt = 1
	end

	if math.ceil(prevFt / cnt) > math.ceil(ft / cnt) then
		if ft > 10 then
			playDuration(ft, 0)
		elseif ft > 0 then
			playNumber(ft, 0)
		end
	end

	prevFt = ft
end -- Play FlightTimer

local function inAltitudeWindow()
	if offTime == 0 then -- no longer in 10s window
		return false
	end

	-- 10 sec. count after motor off
	local cnt = math.floor((getTime() - offTime) / 100)

	if cnt > prevCnt then
		prevCnt = cnt

		if cnt >= 10 then
			offTime = 0 -- No more counts

			-- Time to record start height
			local alt = getValue("Alt+")
			if alt > 0 then
				startHeight = alt
			end

			-- Call launch height
			if callAlt then
				playNumber(alt, UNIT_METERS)
			else
				playNumber(cnt, 0)
			end
		else
			playNumber(cnt, 0)
		end
	end

	return true
end -- inAltitudeWindow

function widget.background()
	local now            = getTime()
	local flightMode     = getFlightMode()

	local motorOn        = (flightMode == FM_LAUNCH) -- Motor running
	local armedNow       = getLogicalSwitchValue(LS_ARM)
	local triggerNow     = getLogicalSwitchValue(LS_TRIGGER)

	prevArm, armedNow    = armedNow, armedNow and not prevArm
	prevTrig, triggerNow = triggerNow, triggerNow and not prevTrig

	callAlt              = (getLogicalSwitchValue(LS_ALT10)) -- Call alt every 10 sec.

	flightTimer          = model.getTimer(0) -- Current flight timer value
	motorTimer           = model.getTimer(1) -- Current motor timer value

	if armedNow and state ~= STATE_INITIAL then
		InitializeFlight()
	end

	if state == STATE_INITIAL then
		-- Reset altitude if the motor was armed now
		if armedNow then
			ResetAlt()
			screenTask.labelInfo.title = "MOTOR ARMED"
			if soarGlobals.battery == 0 then
				playHaptic(200, 0, 1)
				playFile("lowbat.wav")
			end
		end

		if motorOn then
			GotoState(STATE_MOTOR)
			-- Reset MotorTime Call and Alt Window Time
			prevMt = flightTimer.value
			offTime = 0
		end
	elseif state == STATE_MOTOR then
		playMotorTime(motorTimer)

		if not motorOn then -- Motor stopped
			if offTime == 0 then
				-- start 10 sec. Alt Window to record start height
				offTime = now; prevCnt = 1
			end

			if triggerNow then -- Trigger switch released
				prevFt = flightTimer.value
			end
			GotoState(STATE_GLIDE)
		end
	elseif state == STATE_GLIDE then
		playFlightTimer(flightTimer)

		if (not inAltitudeWindow()) then
			-- Call altitude every 10 sec.
			if callAlt and now > nextCall then
				playNumber(getValue("Alt"), UNIT_METERS)
				nextCall = now + 1000
			end
		end

		if triggerNow then
			-- Stop timer and record scores
			GotoState(STATE_LANDINGPTS)
			playTone(880, 1000, 0)
			model.setGlobalVariable(GV_FLT_TMR, 0, 0)
			model.setTimer(0, { value = flightTimer.start - flightTimer.value })
			playDuration(flightTimer.start - flightTimer.value)
		end
		-- STATE_GLIDE
	elseif state == STATE_LANDINGPTS then
		if triggerNow then
			GotoState(STATE_TIME)
		end
	elseif state == STATE_TIME then
		if triggerNow then
			GotoState(STATE_SAVE)
		end
	elseif state == STATE_SAVE then
		if triggerNow then
			InitializeFlight()
		end
	end

	-- Motor restart; score a zero
	if (state == STATE_GLIDE or state == STATE_LANDINGPTS) and motorOn then
		state = STATE_SAVE
		model.setTimer(0, { value = 0 })
		startHeight = 0
	end
end -- background()

-- Draw zone area when not in fullscreen mode
function libGUI.widgetRefresh()
	local COL1  = (widget.zone.w / 2) - 198
	local COL2  = COL1 + 30
	local COL3  = COL1 + 120
	local RGT   = COL1 + 400

	-- Draw scores
	x           = 5
	local y     = 0
	local dy    = widget.zone.h / N_LINES

	-- Draw timers
	local blink = 0
	local y     = 1

	local tmr   = model.getTimer(0).value -- Flight
	if tmr < 0 and state > STATE_GLIDE then
		blink = BLINK
	end

	lcd.drawText(COL3, y + 10, screenTask.labelTimer0.title, colors.primary1 + DBLSIZE)
	lcd.drawTimer(RGT, y, tmr, colors.primary1 + blink + XXLSIZE + RIGHT)
	y = y + 2 * dy
	tmr = model.getTimer(1).value -- Motor
	lcd.drawText(COL3, y + 10, "Motor:", colors.primary1 + DBLSIZE)
	lcd.drawTimer(RGT, y, tmr, colors.primary1 + XXLSIZE + RIGHT)
	y = y + 2 * dy
	lcd.drawText(COL1, y, screenTask.labelInfo.title, colors.primary1 + DBLSIZE)
end -- widgetRefresh()

-- Refresh function
function widget.refresh(event, touchState)
	widget.background()
	--screenTask.run(event,touchState
	libGUI.widgetRefresh()
end -- refresh(...)

local function SetupScreenTask()
	print("SetupScreenTask:Begin")
	local y
	-- Info text label
	screenTask.labelInfo = screenTask.label(RGT - 250, BOT_ROW, 250, HEIGHT, " Info ", RIGHT)


	-- Add timers
	y = TOP
	screenTask.labelTimer0 = screenTask.label(RGT - 160, y, 50, HEIGHT2, "Target:", MIDSIZE)
	y = y + LINE2
	screenTask.timer0 = screenTask.timer(RGT - 160, y, 160, HEIGHT, 0, nil, XXLSIZE + RIGHT)
	screenTask.timer0.disabled = true

	y = y + LINE
	screenTask.label(RGT - 160, y, 50, HEIGHT2, "Task:", MIDSIZE)
	y = y + LINE2
	local tmr = screenTask.timer(RGT - 160, y, 160, HEIGHT, 1, nil, XXLSIZE + RIGHT)
	tmr.disabled = true
	print("SetupScreenTask:End")
end


-- Initialize stuff
SetupScreenTask()
SetupTask("10 Min Window")
InitializeFlight()

---------------------------------------------------------------------------
-- SoarETX F3J score keeper, loadable component                          --
--                                                                       --
-- Author:  Frankie Arzu / Jesper Frickmann                              --
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

local GV_FLT_TMR          = 8 -- GV8 for the flight timer
local FM_LAUNCH           = 2 -- Launch flight mode

-- Program states
local STATE_INITIAL       = 0  -- Set flight time before the flight
local STATE_WINDOW        = 1  -- Task window is active
local STATE_FLYING        = 2  -- Flight timer is running
local STATE_LANDINGPTS    = 3  -- Landed, input landing points
local STATE_TIME          = 4  -- Input flight time
local STATE_SAVE          = 5  -- Ready to save
local state                    -- Current program state

local prevFM              = getFlightMode() -- Used for detecting when FM changes
local prevTrig            = false -- Previous vakue of Trigger
local prevWt                   -- Previous Window Time

-- Other common variables
--local counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45} -- Flight timer countdown
--local countIndex            -- Index of timer count

--local flightTimer           -- Flight timer
local windowTimer -- Window Timer

local callAlt             = false

local startHeight         = 0
local altTime             = 0
local landingPts          = 0


-- Browsing scores
local SCORE_FILE = "/LOGS/JF F3J Scores.csv"

-- Handle transitions between program states
local function GotoState(newState)
  print("GotoState:" .. newState)

  state = newState

  -- Stop blinking
  screenTask.timer0.blink = false

  if state == STATE_INITIAL then
    model.setGlobalVariable(GV_FLT_TMR, 0, 0)

    screenTask.labelInfo.title = "INITIAL"
    screenTask.locked = false
  elseif state == STATE_WINDOW then
    model.setGlobalVariable(GV_FLT_TMR, 0, 1) -- Window Open
    playTone(1760, 100, PLAY_NOW)

    screenTask.labelInfo.title = "Window Open"
    screenTask.locked = true
  elseif state == STATE_FLYING then
    model.setGlobalVariable(GV_FLT_TMR, 0, 2) -- Flying
    playTone(1760, 100, PLAY_NOW)

    screenTask.labelInfo.title = "Soaring.."
    screenTask.locked = true
  elseif state == STATE_LANDINGPTS then
    screenTask.labelInfo.title = "Landed. Launch Alt =" .. startHeight
  elseif state == STATE_TIME then
    screenTask.labelInfo.title = "TODO:Enter Time/Landing"
  elseif state == STATE_SAVE then
    screenTask.labelInfo.title = "TODO:Save Data"
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

  -- Set Window timer
  model.setTimer(0, { start = targetTime, value = targetTime })
  model.setTimer(1, { start = 0, value = 0 })

  landingPts = 0
  startHeight = 100 -- default if no Alt

  GotoState(STATE_INITIAL)
end --  InitializeFlight()

local function playWindowTime(windowTimer)
  local wt = windowTimer.value -- Current window timer value
  local cnt                    -- Count interval

  if wt > 120 then
    cnt = 60
  elseif wt > 60 then
    cnt = 15
  elseif wt > 10 then
    cnt = 5
  else
    cnt = 1
  end

  if math.ceil(prevWt / cnt) > math.ceil(wt / cnt) then
    if wt > 10 then
      playDuration(wt, 0)
    elseif wt > 0 then
      playNumber(wt, 0)
    end
  end

  -- Stop flight when the window expires
  if wt <= 0 and prevWt > 0 then
    model.setGlobalVariable(GV_FLT_TMR, 0, 1)
  end

  prevWt = wt
end -- PlayWindowTimer

local function inAltitudeWindow()
  -- Record (and announce) start height
  if altTime > 0 and getTime() > altTime then
    startHeight = getValue("Alt+")
    altTime = 0

    -- Call launch height
    if callAlt then
      playNumber(startHeight, UNIT_METERS)
    end

    if startHeight == 0 then startHeight = 100 end -- If no altimeter; default to 100
  end
end -- InAltitudeWindow

function widget.background()
  local now = getTime()
  local flightMode = getFlightMode()

  local launchOn = (flightMode == FM_LAUNCH) and prevFM ~= flightMode -- Launch Activated

  local triggerNow = getLogicalSwitchValue(LS_TRIGGER)
  prevTrig, triggerNow = triggerNow, triggerNow and not prevTrig

  prevFM = flightMode

  callAlt = (getLogicalSwitchValue(LS_ALT10)) -- Call alt every 10 sec.

  windowTimer = model.getTimer(0)            -- Current motor timer value
  flightTimer = model.getTimer(1)            -- Current flight timer value

  if state == STATE_INITIAL then
    landingPts = 0
    startHeight = 0 -- default if no Alt

    -- Move to Window Open
    if triggerNow then
      GotoState(STATE_WINDOW)
      ResetAlt()

      prevWt = model.getTimer(0).value

      if soarGlobals.battery == 0 then
        playHaptic(200, 0, 1)
        playFile("lowbat.wav")
      end
    end
  elseif state == STATE_WINDOW then
    if triggerNow then -- Trigger switch released
      GotoState(STATE_FLYING)

      -- Start 10s Altitude recording window
      altTime = getTime() + 1000
      startHeight = getValue("Alt+")
    end
  elseif state == STATE_FLYING then
    if (launchOn) then                         -- Reflight
      GotoState(STATE_WINDOW)
      model.setTimer(1, { start = 0, value = 0 }) -- Flight Timer
      return
    end

    inAltitudeWindow()
    playWindowTime(windowTimer)

    if triggerNow then
      -- Stop timer and record scores
      playTone(1760, 100, PLAY_NOW)
      model.setGlobalVariable(GV_FLT_TMR, 0, 0)
      GotoState(STATE_LANDINGPTS)
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
      GotoState(STATE_INITIAL)
    end
  end
end -- background()

-- Draw zone area when not in fullscreen mode
function libGUI.widgetRefresh()
  local COL1  = (widget.zone.w / 2) - 198
  local COL2  = COL1 + 30
  local COL3  = COL1 + 125
  local RGT   = COL1 + 400

  -- Draw scores
  x           = 5
  local y     = 0
  local dy    = widget.zone.h / N_LINES

  -- Draw timers
  local blink = 0
  local y     = 1

  local tmr   = model.getTimer(0).value -- Window
  if tmr < 0 and state > STATE_FLYING then
    blink = BLINK
  end

  lcd.drawText(COL3, y + 10, screenTask.labelTimer0.title, colors.primary1 + DBLSIZE)
  lcd.drawTimer(RGT, y, tmr, colors.primary1 + blink + XXLSIZE + RIGHT)
  y = y + 2 * dy

  tmr = model.getTimer(1).value -- Flight Timer
  lcd.drawText(COL3, y + 10, screenTask.labelTimer1.title, colors.primary1 + DBLSIZE)
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
  screenTask.labelTimer0 = screenTask.label(RGT - 160, y, 50, HEIGHT2, "Window:", MIDSIZE)
  y = y + LINE2
  screenTask.timer0 = screenTask.timer(RGT - 160, y, 160, HEIGHT, 0, nil, XXLSIZE + RIGHT)
  screenTask.timer0.disabled = true

  y = y + LINE
  screenTask.labelTimer1 = screenTask.label(RGT - 160, y, 50, HEIGHT2, "Flight:", MIDSIZE)
  y = y + LINE2
  screenTask.timer1 = screenTask.timer(RGT - 160, y, 160, HEIGHT, 0, nil, XXLSIZE + RIGHT)
  screenTask.timer1.disabled = true
  print("SetupScreenTask:End")
end


-- Initialize stuff
SetupScreenTask()
SetupTask("10 Min Window")
InitializeFlight()

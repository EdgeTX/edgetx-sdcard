---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
-----#                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################
chdir("/SCRIPTS/TOOLS/FrSky_Gyro_Suite/SRx_plus")

local app_ver = "v3.0.6"
local app_name = "FrSky_Gyro_Suite"

local IS_SIMULATOR = false -- updated in init()
local CommonFile = assert(loadfile("common.lua"))()
local Telemetry  = CommonFile.Telemetry


local CALI_OPERATION_TIMEOUT = 16 * 100 -- seconds  (100 ticks per second)
local PUSH_FRAME_TIMEOUT = 2 * 100 -- seconds (100 ticks per second)

local CALI_PAGE = { 0xB9, 0xD3 }  -- address for Gyro1, and Gyro2
local CALI_START_COMMAND = 0x01

local EXC_STATE_READY   = 0x00
local EXC_STATE_RUNNING = 0x01
local EXC_STATE_DONE    = 0x02

local CALI_STATE_INIT     = 0x00
local CALI_STATE_READ     = 0x01
local CALI_STATE_RECEIVE  = 0x02
local CALI_STATE_WRITE    = 0x03
local CALI_STATE_FINISHED = 0x04

local COL1_GYRO       = 1
local COL2_STEP       = 2
local COL3_TITLE      = 3
local COL4_HINT       = 4

local spacing         = 20

local caliState = CALI_STATE_INIT
local caliError = false

local pages = {}
local parameters = {}
local page = 1


local finalTick = nil
local lastPushTick = nil

-- common
local function log(fmt, ...)
  print("[" .. app_name .. "]" .. string.format(fmt, ...))
end

-- Select the next or previous page
local function selectPage(step)
  page = 1 + ((page + step - 1 + #pages) % #pages)
  caliState = CALI_STATE_INIT
end

local function refreshNext(param)
  local gyroNo   = param[COL1_GYRO]
  local caliPage  = CALI_PAGE[gyroNo]
  local step = param[COL2_STEP]

  -- Calibration timeout
  if getTime() > finalTick then
    log("TimeOut!!!")
    caliState = CALI_STATE_FINISHED
    caliError = true
  end

  if caliState == CALI_STATE_WRITE then
    log("Write Start Command")
    local val = bit32.bor(step, bit32.lshift(CALI_START_COMMAND,8)) -- CCSS
    if Telemetry.telemetryWrite(caliPage, val) == true then
      caliState = CALI_STATE_READ
      lastPushTick = getTime() + PUSH_FRAME_TIMEOUT
    end
  elseif caliState == CALI_STATE_READ or (getTime() > lastPushTick) then
    log("Send Read Request")
    local page = bit32.bor(caliPage, bit32.lshift(step,8))
    if Telemetry.telemetryRead(page) == true then
      caliState = CALI_STATE_RECEIVE
      lastPushTick = getTime() + PUSH_FRAME_TIMEOUT
    end
  elseif caliState == CALI_STATE_RECEIVE then
    local value = Telemetry.telemetryPop()
    if value == nil then return end -- Return if no value??

    local fieldId,D1,D2 = Telemetry.parseValue(value)
    if fieldId ~= caliPage then return end --?? Return if not the data requested

    log("telementryPop Return valid data")
    local excStep = D1
    local excStepState = D2
    log("exeStep: %d, execStepState: %d", excStep,excStepState)
    -- Wrong step
    if excStep ~= step then return end -- Return on Wrong Step

    --lastPushTick = nil
    if excStepState == EXC_STATE_READY then
      caliState = CALI_STATE_WRITE
    elseif excStepState == EXC_STATE_RUNNING then
      caliState = CALI_STATE_READ
    elseif excStepState == EXC_STATE_DONE then
      caliState = CALI_STATE_FINISHED
      caliError = false
    end
  end
end

local function clibrationInProgress()
    return not ((caliState == CALI_STATE_INIT) or (caliState == CALI_STATE_FINISHED))
end

local function drawScreenTitle(title, page, pages)
  lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
  lcd.drawText(1, 5, title, COLOR_THEME_PRIMARY2)
  --lcd.drawText(LCD_W-40, 5, page.."/"..pages, COLOR_THEME_PRIMARY2)
end


local function runCalibration(param, event)
  lcd.clear()
  drawScreenTitle(param[COL3_TITLE], page, #pages)

  if (clibrationInProgress()) then
    refreshNext(param)
  end

  if (caliState == CALI_STATE_INIT) then
    lcd.drawText(1, spacing * 3, param[COL4_HINT])
  elseif (caliState == CALI_STATE_FINISHED) then
    if (caliError) then
      lcd.drawText(1, spacing * 3, "Calibration failed!\nPlease check the connection state\nand make sure Gyro is Enabled\nPress [ENTER] to exit")
    else
      lcd.drawText(1, spacing * 3, "Calibration finished.\nPress [ENTER] to exit")
    end
  else
    lcd.drawText(1, spacing * 3, "Please wait until calibration is finished ...")
  end

  if (event == EVT_VIRTUAL_EXIT and not clibrationInProgress()) then
    page = 1 -- return to main menu
    caliState = CALI_STATE_INIT
  elseif event == EVT_VIRTUAL_ENTER and caliState == CALI_STATE_FINISHED then
    page = 1 -- return to main menu
    caliState = CALI_STATE_INIT
  elseif event == EVT_VIRTUAL_ENTER and caliState == CALI_STATE_INIT then
    -- start Calibration
    lastPushTick = getTime() + PUSH_FRAME_TIMEOUT
    finalTick    = getTime() + CALI_OPERATION_TIMEOUT
    caliState    = CALI_STATE_WRITE
  end
  return 0
end

local introMenu = {
  pos = 1,
  menu = {
      -- Menu, Page
      {"Level Calibration        (Gyro 1)", 2},
      {"Stick Center Calibration (Gyro 1)", 3},
      {"Stick Range  Calibration (Gyro 1)", 4},
      {"Level Calibration        (Gyro 2)", 5},
      {"Stick Center Calibration (Gyro 2)", 6},
      {"Stick Range  Calibration (Gyro 2)", 7},
  }
}

local function runIntroPage(param, event)
  lcd.clear()
  drawScreenTitle(param[COL3_TITLE], page, #pages)

  for iParam=1, #introMenu.menu do
    -- set y draw coord
    local y = (iParam+1) * spacing
    local x = 1

    -- highlight selected parameter
    local attr = (introMenu.pos==iParam) and INVERS or 0

    local title = introMenu.menu[iParam][1] -- Title
    lcd.drawText (x, y, title, attr)
  end

  if event == EVT_VIRTUAL_PREV then
    if (introMenu.pos>1) then introMenu.pos = introMenu.pos - 1 end
  elseif event == EVT_VIRTUAL_NEXT then
    if (introMenu.pos < #introMenu.menu) then introMenu.pos = introMenu.pos + 1 end
  elseif event == EVT_VIRTUAL_ENTER then
      page = introMenu.menu[introMenu.pos][2]
  elseif (event == EVT_VIRTUAL_EXIT) then
    return 2
  end
  return 0
end

-- Init
local function init()
  page = 1
  pages = {
      runIntroPage,
      runCalibration,
      runCalibration,
      runCalibration,
      runCalibration,
      runCalibration,
      runCalibration
  }

  parameters = {
     { 0, 0, "FrSky SRx PreCalibration ("..app_ver..")",
     },
     { 1, 1, "Level calibration (Group/Gyro 1)",
                "Calibration of the horizontal is about to begin.\n"..
                "Please place the model in a level position,\n" ..
                "then press [ENTER] to continue."
     },
     { 1, 2, "Stick center calibration (Group/Gyro 1)",
                "Stick center calibration is about to begin.\n" ..
                "Please set the stick to the center position,\n" ..
                "then press [ENTER] to continue."
    },
    { 1, 3, "Stick range calibration (Group/Gyro 1)",
                "Stick range calibration is about to begin.\n" ..
                "After pressing [ENTER], please move the stick to\n" ..
                "its full range in all directions to calibrate.",
    },
    { 2, 1, "Level calibration (Group/Gyro 2, ACCESS only)",
              "Calibration of the horizontal is about to begin.\n"..
              "Please place the model in a level position,\n" ..
              "then press [ENTER] to continue."
    },
    { 2, 2, "Stick center calibration (Group/Gyro 2, ACCESS only)",
              "Stick center calibration is about to begin.\n" ..
              "Please set the stick to the center position,\n" ..
              "then press [ENTER] to continue."
    },
    { 2, 3, "Stick range calibration (Group/Gyro 2, ACCESS only)",
              "Stick range calibration is about to begin.\n" ..
              "After pressing [ENTER], please move the stick to\n" ..
              "its full range in all directions to calibrate.",
    }
  }

  local _, rv = getVersion()
  IS_SIMULATOR =  string.sub(rv, -5) == "-simu"
  if IS_SIMULATOR then
    local SimFile = assert(loadfile("simSR10plus.lua"))()
    -- Override telemetry object for a simulated one
    Telemetry = SimFile.Telemetry
  end
end

-- Main
local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  local result = pages[page](parameters[page],event)
  return result
end

return { init=init, run=run }

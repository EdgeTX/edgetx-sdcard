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
local IS_SIMULATOR = false -- updated in init()

local version = "v3.0.6"

local CommonFile = assert(loadfile("common.lua"))()
local Telemetry  = CommonFile.Telemetry

local isHorus = (LCD_W == 480)
local isX9 = (LCD_W == 212)
local VALUE = 0

local CALIBRATION_ADDRESS = 0xB2
local CALIBRATION_INIT = 0
local CALIBRATION_WRITE = 1
local CALIBRATION_READ = 2
local CALIBRATION_WAIT = 3
local CALIBRATION_OK = 4

local rxName = "SRX"
local page = 1
local refreshIndex = 0
local calibrationState = 0
local calibrationStep = 0
local pages = {}
local fields = {}

local calibrationPositions = { "up", "down", "left", "right", "forward", "back" }
-- only for x7
local positionConfirmed = 0
local orientationAutoSense = 0

-- -- only for horus
local calibBitmaps = {}
local calibBitmapsFile = {"img/up.png", "img/down.png", "img/left.png", "img/right.png", "img/forward.png", "img/back.png"}

local calibrationFields = {
  {"X:", VALUE, 0x9E, 0, -100, 100, "%"},
  {"Y:", VALUE, 0x9F, 0, -100, 100, "%"},
  {"Z:", VALUE, 0xA0, 0, -100, 100, "%"}
}

-- common
-- Select the next or previous page
local function selectPage(step)
  page = 1 + ((page + step - 1 + #pages) % #pages)
  refreshIndex = 0
  calibrationStep = 0
  pageOffset = 0
end

local function refreshNext()
  if calibrationState == CALIBRATION_WRITE then
    if Telemetry.telemetryWrite(CALIBRATION_ADDRESS, calibrationStep) == true then
      calibrationState = CALIBRATION_READ
    end
  elseif calibrationState == CALIBRATION_READ then
    if Telemetry.telemetryRead(CALIBRATION_ADDRESS) == true then
      calibrationState = CALIBRATION_WAIT
    end
  elseif calibrationState == CALIBRATION_WAIT then
    local value = Telemetry.telemetryPop()
    if value == nil then return end

    local fieldId = Telemetry.parseValue(value)
    if fieldId == CALIBRATION_ADDRESS then
      if calibrationStep == 5 then
        calibrationState = CALIBRATION_OK
        calibrationStep = 6
      else
        calibrationState = CALIBRATION_INIT
        calibrationStep = (calibrationStep + 1) % 6
      end
    end
  end
end

-- horus
local function drawScreenTitle(title, page, pages)
  lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
  lcd.drawText(1, 5, title, COLOR_THEME_PRIMARY2)
  lcd.drawText(LCD_W-40, 5, page.."/"..pages, COLOR_THEME_PRIMARY2)
end

local function runCalibrationPageForHorus(event)
  fields = calibrationFields
  if refreshIndex == #fields then
    refreshIndex = 0
  end
  lcd.clear()
  drawScreenTitle(rxName.." Calibration ("..version..")", page, #pages)
  if(calibrationStep < 6) then
    local position = calibrationPositions[1 + calibrationStep]
    lcd.drawText(100, 50, "Place the "..rxName.." in the following position", COLOR_THEME_SECONDARY1)
    if calibBitmaps[calibrationStep + 1] == nil then
      calibBitmaps[calibrationStep + 1] = Bitmap.open(calibBitmapsFile[calibrationStep + 1])
    end
    lcd.drawBitmap(calibBitmaps[calibrationStep + 1], 200, 70)
    -- for index = 1, 3, 1 do
    --   local field = fields[index]
    --   lcd.drawText(70, 80+20*index, field[1]..":", COLOR_THEME_SECONDARY1)
    --   lcd.drawNumber(90, 80+20*index, field[4]/10, LEFT+PREC2)
    -- end

    local attr = calibrationState == 0 and INVERS or 0
    lcd.drawText(160, 220, "Press [Enter] when ready", attr)
  else
    lcd.drawText(160, 50, "Calibration completed", 0)
    lcd.drawBitmap(Bitmap.open("bmp/done.bmp"),200, 100)
    lcd.drawText(160, 220, "Press [RTN] when ready", attr)
  end
  if calibrationStep >= 6 and (event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT) then
    return 2
  elseif event == EVT_VIRTUAL_ENTER then
    calibrationState = 1
  elseif event == EVT_VIRTUAL_EXIT then
    if calibrationStep > 0 then
      calibrationStep = 0
    end
  end
  return 0
end

-- only for taranis x9/x7
-- Draw initial warning page
local function runWarningPage(event)
  lcd.clear()
  lcd.drawScreenTitle(rxName.." Calibration ("..version..")", page, #pages)
  lcd.drawText(0, 10, "You only need to calibrate", SMLSIZE)
  lcd.drawText(0, 20, "once. You will need "..rxName, SMLSIZE)
  lcd.drawText(0, 30, "power, and a level surface.", SMLSIZE)
  lcd.drawText(0, 40, "Press [Enter] when ready", SMLSIZE)
  lcd.drawText(0, 50, "Press [Exit] to cancel", SMLSIZE)
  if event == EVT_VIRTUAL_ENTER then
    selectPage(1)
    return 0
  elseif event == EVT_VIRTUAL_EXIT then
    return 2
  end
  return 0
end

-- taranis x9
local calibrationPositionsBitmaps = { "bmp/up.bmp", "bmp/down.bmp", "bmp/left.bmp", "bmp/right.bmp", "bmp/forward.bmp", "bmp/back.bmp"  }
local function runCalibrationPageForX9(event)
  fields = calibrationFields
  if refreshIndex == #fields then
    refreshIndex = 0
  end
  lcd.clear()
  lcd.drawScreenTitle(rxName .." ("..version..")", page, #pages)
  if(calibrationStep < 6) then
    lcd.drawText(0, 9, "Turn the "..rxName.." as shown", 0)
    lcd.drawPixmap(10, 19, calibrationPositionsBitmaps[1 + calibrationStep])
    -- for index = 1, 3, 1 do
    --   local field = fields[index]
    --   lcd.drawText(80, 12+10*index, field[1], 0)
    --   lcd.drawNumber(90, 12+10*index, field[4]/10, LEFT+PREC2)
    -- end

    local attr = calibrationState == 0 and INVERS or 0
    lcd.drawText(0, 56, "Press [Enter] when ready", attr)
  else
    lcd.drawText(0, 9, "Calibration completed", 0)
    lcd.drawPixmap(10, 19, "bmp/done.bmp")
    lcd.drawText(0, 56, "Press [Exit] when ready", attr)
  end
  if calibrationStep >= 6 and (event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT) then
    return 2
  elseif event == EVT_VIRTUAL_ENTER then
    calibrationState = 1
  elseif event == EVT_VIRTUAL_EXIT then
    if calibrationStep > 0 then
      calibrationStep = 0
    end
  end
  return 0
end

-- taranis x7
local function drawCalibrationOrientation(x, y, step)
  local orientation = { {"Front side up.", "", 0, 0, 1000, 0, 0, 1000},
                          {"Front side down.", "", 0, 0, -1000, 0, 0, -1000},
                          {"Top side down.", "", 1000, 0, 0, 1000, 0, 0},
                          {"Top side up.", "", -1000, 0, 0, -1000, 0, 0},
                          {"Right side up.", "", 0, 1000 , 0, 0, -1000, 0},
                          {"Right side down.", "", 0, -1000, 0, 0, 1000, 0}
                        }

  lcd.drawText(0, 9, "Place "..rxName.." as follows:", 0)
  lcd.drawText(x-9, y, orientation[step][1])
  lcd.drawText(x-9, y+10, orientation[step][2])
  local positionStatus = 0
  -- for index = 1, 3, 1 do
  --   local field = fields[index]
  --   lcd.drawText(90, 12+10*index, field[1], 0)
  --   if math.abs(field[4] - orientation[step][2+index+orientationAutoSense]) < 300 then
  --     lcd.drawNumber(100, 12+10*index, field[4]/10, LEFT+PREC2)
  --     positionStatus = positionStatus + 1
  --   else
  --     lcd.drawNumber(100, 12+10*index, field[4]/10, LEFT+PREC2+INVERS)
  --   end
  -- end
  if step == 3 and positionStatus == 2 then -- orientation auto sensing
    orientationAutoSense = 3 - orientationAutoSense
  end
  if positionStatus == 3 then
    lcd.drawText(0, 56, " [Enter] to validate   ", INVERS)
    positionConfirmed = 1
  end
end

local function runCalibrationPageForX7(event)
  fields = calibrationFields
  if refreshIndex == #fields then
    refreshIndex = 0
  end
  lcd.clear()
  lcd.drawScreenTitle(rxName.." Calibration ("..version..")", page, #pages)
  if(calibrationStep < 6) then
    drawCalibrationOrientation(10, 24, 1 + calibrationStep)

    local attr = calibrationState == 0 and INVERS or 0
    --lcd.drawText(0, 56, "[Enter] to validate", attr)
  else
    lcd.drawText(0, 19, "Calibration completed", 0)
--    lcd.drawText(10, 19, "Done",0)
    lcd.drawText(0, 56, "Press [Exit] when ready", attr)
  end
  if calibrationStep >= 6 and (event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT) then
    return 2
  elseif event == EVT_VIRTUAL_ENTER and positionConfirmed  then
    calibrationState = 1
    positionConfirmed = 0
  end
  return 0
end

-- Init
local function init()
  current, edit, refreshIndex = 1, false, 0
  if (isHorus) then
    pages = {
      runCalibrationPageForHorus
    }
  elseif (isX9) then
    pages = {
      runWarningPage,
      runCalibrationPageForX9
    }
  else
    pages = {
      runWarningPage,
      runCalibrationPageForX7
    }
  end

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
  elseif event == EVT_VIRTUAL_NEXT_PAGE then
    selectPage(1)
  elseif event == EVT_VIRTUAL_PREV_PAGE then
    killEvents(event);
    selectPage(-1)
  end

  local result = pages[page](event)
  refreshNext()

  return result
end

return { init=init, run=run }

---- #########################################################################                                                                  #
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
------------------------------------------------------------------------------
-- Developer: Francisco Arzu
-- Developer: Offer Schmuley
-- Change the paths as needed.. the local directory is where the TOOLS are.
-- Example for the new and old FrSky SxR scripts
-- Directory/Folder where the FrSky Confugure script is.. use "./" if in the TOOLS folder
local TOOL_PATH = "/SCRIPTS/TOOLS/FrSky_Gyro_Suite"
local SxR_PATH =     TOOL_PATH.."/FrSky_S8R_S6R/"
local SR_PLUS_PATH = TOOL_PATH.."/SRx_plus/"

local TEXT_SIZE = 0 -- NORMAL
local LCD_COL1 = 6
local LCD_Y_LINE_HEIGHT = 20
local LCD_Y_HEADER = 1
local LCD_Y_DATA = 0 -- First Line of data. Calculated during init

local runningLua = nil
local runningPage = nil

local T_RUN_LUA = 1
local T_RUN_MENU = 2

---------------------------------------------------------------------------------------------

local MainScreen = {
    menuPos = 1, -- Current Menu Pos
    title = "FrSky Stabilization Suite(v1.0)"
    -- menu done later
}

local SxR_Screen = {
    menuPos = 1,
    title = "Frsky Accst Receiver S6R/S8R",

    menu = {
        {"*  Stabilization Setup" , T_RUN_LUA, SxR_PATH .. "setup.lua"},
        {"*  6-Axis Calibration"  , T_RUN_LUA, SxR_PATH .. "calibrate.lua"},
        {"*  <Back>", T_RUN_MENU, MainScreen}
    }
}

local SR_PLUS_V1_Screen = {
    menuPos = 1,
    title = "Frsky Archer Plus SR8+/SR10+/SR12+ (FW V1.x)",

    menu = {
        {"*  Stabilization Setup", T_RUN_LUA, SR_PLUS_PATH .. "setupV1.lua"},
        {"*  6-Axis Calibration" , T_RUN_LUA, SR_PLUS_PATH .. "calibrateV1.lua"},
        {"*  <BACK>", T_RUN_MENU, MainScreen}
    }
}

local SR_PLUS_V3_Screen = {
    menuPos = 1,
    title = "Frsky Archer Plus SR8+/SR10+/SR12+ (FW v3.x)",

    menu = {
        {"*  Stabilization Setup"          , T_RUN_LUA, SR_PLUS_PATH .. "setupV3.lua"},
        {"*  6-Axis Calibration"           , T_RUN_LUA, SR_PLUS_PATH .. "calibrateV3.lua"},
        {"*  Level/Stick Range Calibration", T_RUN_LUA, SR_PLUS_PATH .. "stickCalibrateV3.lua"},
        {"*  <BACK>"                       , T_RUN_MENU, MainScreen},
    }
}

MainScreen.menu = {
    {"*  ACCST S6R/S8R"                               , T_RUN_MENU, SxR_Screen},
    {"*  Archer Plus SR8+/SR10+/SR12+ (Firmware v1.x)", T_RUN_MENU, SR_PLUS_V1_Screen},
    {"*  Archer Plus SR8+/SR10+/SR12+ (Firmware v3.x)", T_RUN_MENU, SR_PLUS_V3_Screen},
}

---------------------------------------------------------------------------------------------
local function gc()
    collectgarbage("collect")
end

local function drawScreenTitle(title, page, pages)
    if (TEXT_SIZE == 0) then -- Big Screen
        lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
        lcd.drawText(10, 5, title, COLOR_THEME_PRIMARY2)
    else
        lcd.drawText(5, 1, title, TEXT_SIZE + BOLD)
    end
end

local function paint(page)
    lcd.clear()
    drawScreenTitle(page.title)

    for iParam = 1, #page.menu do
        -- set y draw coord
        local y = (iParam - 1) * LCD_Y_LINE_HEIGHT + LCD_Y_DATA
        local x = LCD_COL1

        -- highlight selected parameter
        local attr = (page.menuPos == iParam) and INVERS or 0

        local menuLine = page.menu[iParam]
        local title = menuLine[1] -- Title
        lcd.drawText(x, y, title, attr + TEXT_SIZE)
    end
end

local function eventHandler(page, key)
    -- print("MainScreenProcessor.event() called")
    if key == nil then
        return
    elseif key == EVT_VIRTUAL_PREV then
        if (page.menuPos > 1) then
            page.menuPos = page.menuPos - 1
        end
    elseif key == EVT_VIRTUAL_NEXT then
        if (page.menuPos < #page.menu) then
            page.menuPos = page.menuPos + 1
        end
    elseif key == EVT_VIRTUAL_EXIT then
        runningPage = MainScreen
    elseif key == EVT_VIRTUAL_ENTER then
        local menuLine = page.menu[page.menuPos]
        if (menuLine[2] == T_RUN_LUA) then
            chdir(TOOL_PATH)
            -- Execute external LUA
            gc()
            local luaName = menuLine[3]
            local luacFile = assert(loadScript(luaName), "Mising:" .. luaName)
            runningLua = luacFile()
            runningLua.init()
        else -- Execute menu
            runningPage = menuLine[3]
        end
    end
end

local function init()
    runningPage = MainScreen
    local th = 10

    if (LCD_H <= 64) then -- Smaller Screens
        TEXT_SIZE = SMLSIZE -- Small Font
        LCD_COL1 = 0
        LCD_Y_LINE_HEIGHT = 9
    else
        TEXT_SIZE = 0 -- Normal Font
        LCD_COL1 = 15
        LCD_Y_LINE_HEIGHT = 25
    end

    -- Recompute line positions
    LCD_Y_DATA = LCD_Y_HEADER + LCD_Y_LINE_HEIGHT * 2
end

local function run(event)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if (runningLua) then
        local r = runningLua.run(event)
        if (r > 0) then
            -- Exit SubProgram
            runningLua = nil
            gc()
        end
        return 0
    else
        if (runningPage == MainScreen) and (event == EVT_VIRTUAL_EXIT) then
            return 1
        end

        paint(runningPage)
        eventHandler(runningPage, event)
    end

    return 0
end

return {run=run, init=init}

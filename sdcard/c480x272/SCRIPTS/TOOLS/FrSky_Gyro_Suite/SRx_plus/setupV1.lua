---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
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

-- script to setup parameter on SR10+ (plus)
-- this script work only with SR8+ SR10+ SR12+
-- it should NOT be used to confing SR8-pro/SR10-pro/SR-12pro
-- it should NOT be used to confing S6R/S8R
-- based on FrSky version 2.04
-- Updated for FrSky version 3.0.6

-- Updated by: Offer Shmuely from FrSky v2.04
-- Date: Apr 19, 2025

local app_ver = "v2.04.1"
local app_name = "FrSky_Gyro_Suite"

local T_VALUE = 0
local T_COMBO = 1
local T_HEADER = 2

local COL1_TXT = 1
local COL2_TYPE = 2
local COL3_FIELD_ID = 3
local COL4_BYTE_SHIFT  = 4
local COL5_CURR_VAL = 5

local COL6_COMBO_KEYS = 6
local COL7_COMBO_VALUES = 7

local COL6_V_MIN = 6
local COL7_V_MAX = 7
local COL8_V_UNIT = 8
local COL9_V_OFFSET = 9


local COL8_IS_VISIBLE = 8

local edit = false
local page = 1
local current = 1
local refreshState = 0
local refreshIndex = 0
local pageOffset = 0
local pages = {}
local fields = {}
local modifications = {}
local margin = 10
local spacing = 22
local numberPerPage = 11

local FieldsPage1 = {
    { "Group 1", T_HEADER },
    { "    Enable/Disable Gyro 1"   , T_COMBO, 0x40, 1, nil, { "ON", "OFF" }               , { 1, 0 } },
    { "    Stabilization mode:"     , T_COMBO, 0x41, 1, nil, { "Full (with hover & knife)", "Simple (no hover, no knife)" }, { 0, 1 } },
    { "    Wing type (1)"           , T_COMBO, 0x41, 2, nil, { "Normal", "Delta", "VTail" }, { 0, 1, 2 } },
    { "    Mounting type (1)"       , T_COMBO, 0x41, 3, nil, { "Horizontal", "Horizontal Reversed", "Vertical", "Vertical Reversed" }, { 0, 1, 2, 3 } },
    { "    Self Check (1)"          , T_COMBO, 0x4C, 1, nil, { "Disabled", "Enabled" }, { 0, 1 } },

    { "Group 2", T_HEADER },
    { "    Enable/Disable Gyro 2"   , T_COMBO, 0x70, 1, nil, { "ON", "OFF" }               , { 1, 0 } },
    { "    Stabilization mode:"     , T_COMBO, 0x71, 1, nil, { "Full (with hover & knife)", "Simple (no hover, no knife)" }, { 0, 1 } },
    { "    Wing type (2)"           , T_COMBO, 0x71, 2, nil, { "Normal", "Delta", "VTail" }, { 0, 1, 2 } },
    { "    Mounting Type (2)"       , T_COMBO, 0x71, 3, nil, { "Horizontal", "Horizontal Reversed" , "Vertical", "Vertical Reversed" }, { 0, 1, 2, 3 } },
    { "    Self Check (2)"          , T_COMBO, 0x7C, 1, nil, { "Disabled", "Enabled" }, { 0, 1 } },
}

local FieldsPage2 = {
    { "                                        --- Group1 ---", T_HEADER },
    { "Modes"                  , T_HEADER },
    { "    CH5 mode"           , T_COMBO, 0x42, 1, nil, { "Stabilized as AIL2", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH6 mode"           , T_COMBO, 0x42, 2, nil, { "Stabilized as ELE2", "AUX (Not stabilized)" }, { 0, 1 } },

    { "Main stabilization"     , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0x44, 2, nil, 0, 200,   "%", 0 },
    { "    Gain: ELE"          , T_VALUE, 0x44, 3, nil, 0, 200,   "%", 0 },
    { "    Gain: RUD"          , T_VALUE, 0x45, 1, nil, 0, 200,   "%", 0 },
    { "    Roll Degree"        , T_VALUE, 0x4D, 1, nil, 0,  80, " deg", 0 },
    { "    Pitch Degree"       , T_VALUE, 0x4D, 2, nil, 0,  80, " deg", 0 },

    { "Directions"             , T_HEADER },
    { "    Directions: AIL"    , T_COMBO, 0x42, 3, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: ELE"    , T_COMBO, 0x43, 1, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: RUD"    , T_COMBO, 0x43, 2, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: AIL2"   , T_COMBO, 0x43, 3, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: ELE2"   , T_COMBO, 0x44, 1, nil, { "Normal", "Inverted" }, { 0, 255 } },

    { "Auto Level"             , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0x46, 1, nil,   0, 200, " %", 0 },
    { "    Gain: ELE"          , T_VALUE, 0x46, 2, nil,   0, 200, " %", 0 },
    { "    Offset: AIL"        , T_VALUE, 0x49, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: ELE"        , T_VALUE, 0x49, 2, nil, -20,  20, " %", 0x80 },

    { "Hover"                  , T_HEADER },
    { "    Gain: ELE"          , T_VALUE, 0x47, 2, nil, 0, 200, " %", 0 },
    { "    Gain: RUD "         , T_VALUE, 0x47, 3, nil, 0, 200, " %", 0 },
    { "    Offset: ELE"        , T_VALUE, 0x4A, 2, nil, -20, 20, " %", 0x80 },
    { "    Offset: RUD"        , T_VALUE, 0x4A, 3, nil, -20, 20, " %", 0x80 },

    { "Knife Edge"             , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0x48, 1, nil,   0, 200, " %", 0 },
    { "    Gain: RUD"          , T_VALUE, 0x48, 3, nil,   0, 200, " %", 0 },
    { "    Offset: AIL"        , T_VALUE, 0x4B, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD"        , T_VALUE, 0x4B, 3, nil, -20,  20, " %", 0x80 },
}

local FieldsPage3 = {
    { "                                        --- Group2 ---", T_HEADER },
    { "Modes (group 2)"        , T_HEADER },
    { "    CH10 mode"          , T_COMBO, 0x72, 1, nil, { "Stabilized as AIL4", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH11 mode"          , T_COMBO, 0x72, 2, nil, { "Stabilized as ELE4", "AUX (Not stabilized)" }, { 0, 1 } },

    { "Main stabilization (group 2)", T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0x74, 2, nil, 0, 200, "%", 0 },
    { "    Gain: ELE3-4"       , T_VALUE, 0x74, 3, nil, 0, 200, "%", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0x75, 1, nil, 0, 200, "%", 0 },
    { "    Roll Degree"        , T_VALUE, 0x7D, 1, nil, 0, 80, "deg", 0 },
    { "    Pitch Degree"       , T_VALUE, 0x7D, 2, nil, 0, 80, "deg", 0 },

    { "Directions (group 2)"   , T_HEADER },
    { "    Directions: AIL3"   , T_COMBO, 0x72, 3, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: ELE3"   , T_COMBO, 0x73, 1, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: RUD2"   , T_COMBO, 0x73, 2, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: AIL4"   , T_COMBO, 0x73, 3, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: ELE4"   , T_COMBO, 0x74, 1, nil, { "Normal", "Inverted" }, { 0, 0xFF } },

    { "Auto Level (group 2)"   , T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0x76, 1, nil,   0, 200, " %", 0 },
    { "    Gain: ELE3-4"       , T_VALUE, 0x76, 2, nil,   0, 200, " %", 0 },
    { "    Offset: AIL3-4"     , T_VALUE, 0x79, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: ELE3-4"     , T_VALUE, 0x79, 2, nil, -20,  20, " %", 0x80 },

    { "Hover (group 2)"        , T_HEADER },
    { "    Gain: ELE3-4"       , T_VALUE, 0x77, 2, nil,   0, 200, " %", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0x77, 3, nil,   0, 200, " %", 0 },
    { "    Offset: ELE3-4"     , T_VALUE, 0x7A, 2, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD2"       , T_VALUE, 0x7A, 3, nil, -20,  20, " %", 0x80 },

    { "Knife Edge (group 2)"   , T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0x78, 1, nil,   0, 200, " %", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0x78, 3, nil,   0, 200, " %", 0 },
    { "    Offset: AIL3-4"     , T_VALUE, 0x7B, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD2"       , T_VALUE, 0x7B, 3, nil, -20,  20, " %", 0x80 },
}

local function log(fmt, ...)
    print("[" .. app_name .. "]" .. string.format(fmt, ...))
end
local function is_simulator()
    local _, rv = getVersion()
    return string.sub(rv, -5) == "-simu"
end

-- Change display attribute to current field
local function addField(step)
    local field = fields[current]
    local min, max
    if field[COL2_TYPE] == T_VALUE then
        min = field[COL6_V_MIN]
        max = field[COL7_V_MAX]
    elseif field[COL2_TYPE] == T_COMBO then
        min = 1
        max = #(field[COL6_COMBO_KEYS])
    elseif field[COL2_TYPE] == T_HEADER then
        min = 0
        max = 0
    end
    if (step < 0 and field[COL5_CURR_VAL] > min) or (step > 0 and field[COL5_CURR_VAL] < max) then
        field[COL5_CURR_VAL] = field[COL5_CURR_VAL] + step
    end
end

-- Select the next or previous page
local function selectPage(step)
    if page == 1 and step < 0 then
        return
    end
    if page + step > #pages then
        return
    end
    page = page + step
    refreshIndex = 0
    pageOffset = 0
    current = 1
end

-- Select the next or previous editable field
local function selectField(step)
    local new_current = current
    local have_next = 0

    for i = 1, 5 do
        if step < 0 and new_current+step >= 1 then
            new_current = new_current + step

            if new_current == 1 then
                have_next = 1
                break
            end
        end

        if step > 0 and new_current+step <= #fields then
                new_current = new_current + step
        end

        -- skip headers
        local field = fields[new_current]
        if field[COL2_TYPE] ~= T_HEADER then
            have_next = 1
            break
        end
    end

    -- no next, do not move
    if have_next == 0 then
        return
    else
        current = new_current
    end

    local field = fields[current]
    log("333 - %s=%s", field[COL1_TXT], field[COL2_TYPE])

    -- scroll if needed
    if current > numberPerPage + pageOffset then
        pageOffset = current - numberPerPage
    elseif current <= pageOffset then
        pageOffset = current - 1
    end
end

local function getNextNilField(offset)
    for offsetIndex = offset or 1, #fields do
        if fields[offsetIndex][COL5_CURR_VAL] == nil and fields[offsetIndex][COL2_TYPE] ~= T_HEADER then
            return fields[offsetIndex], offsetIndex
        end
    end
    return nil, nil
end

local function drawProgressBar()
    local finishedCount = 0
    for index, thisField in ipairs(fields) do
        if thisField[COL5_CURR_VAL] ~= nil then
            finishedCount = finishedCount + 1
        end
    end
    local width = (80 * finishedCount) / #fields
    lcd.drawRectangle(350, 10, 80, 8)
    lcd.drawFilledRectangle(351, 12, width, 6);
end

local function drawScreenTitle(title, page, pages)
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
    lcd.drawText(10, 5, title.. " (".. app_ver ..")", COLOR_THEME_PRIMARY2)
    lcd.drawText(LCD_W - 40, 5, page .. "/" .. pages, COLOR_THEME_PRIMARY2)
end

-- Redraw the current page
local function redrawFieldsPage()
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("FrSky SR10+/12+ Gyro setup", page, #pages)

    if getNextNilField() ~= nil then
        drawProgressBar()
    end

    for index = 1, numberPerPage, 1 do
        local field = fields[pageOffset + index]
        if field == nil then
            break
        end

        local attr = current == (pageOffset + index) and ((edit == true and BLINK or 0) + INVERS) or 0

        -- debugging in simulator
        if is_simulator() and field[COL5_CURR_VAL] == nil then
            log("simu")
            if field[COL2_TYPE] == T_VALUE then
                log("simu - value")
                field[COL5_CURR_VAL] = field[COL6_V_MIN]
            elseif field[COL2_TYPE] == T_COMBO then
                log("simu - combo")
                field[COL5_CURR_VAL] = 1
            end

            log("simu: %s=%s", field[COL1_TXT], field[COL5_CURR_VAL])
        end

        if field[COL2_TYPE] == T_HEADER then
            attr = attr + BOLD
        end

        lcd.drawText(1, margin + spacing * index, field[COL1_TXT], attr)

        if field[COL5_CURR_VAL] == nil and field[COL2_TYPE] ~= T_HEADER then
            lcd.drawText(280, margin + spacing * index, "---", attr)
        else
            if field[COL2_TYPE] == T_VALUE then
                lcd.drawText(280, margin + spacing * index, tostring(field[COL5_CURR_VAL]) .. field[COL8_V_UNIT], attr)
            elseif field[COL2_TYPE] == T_COMBO then
                if field[COL5_CURR_VAL] > 0 and field[COL5_CURR_VAL] <= #(field[COL6_COMBO_KEYS]) then
                    lcd.drawText(280, margin + spacing * index, field[COL6_COMBO_KEYS][field[COL5_CURR_VAL]], attr)
                end
            end
        end
    end
end

local function telemetryRead(field)
    return sportTelemetryPush(0x17, 0x30, 0x0C30, field)
end

local function telemetryWrite(field, value)
    return sportTelemetryPush(0x17, 0x31, 0x0C30, field + value * 256)
end

local telemetryPopTimeout = 0
local function refreshNext()
    if refreshState == 0 then
        local thisField = getNextNilField()
        if #modifications > 0 then
            telemetryWrite(modifications[1][1], modifications[1][2])
            modifications[1] = nil
        elseif thisField ~= nil then
            if telemetryRead(thisField[3]) == true then
                refreshState = 1
                telemetryPopTimeout = getTime() + 80 -- normal delay is 500ms
            end
        end
    elseif refreshState == 1 then
        local physicalId, primId, dataId, value = sportTelemetryPop()
        if primId == 0x32 and dataId == 0x0C30 then
            local fieldId = bit32.band(value,0xFF) -- % 256
            local refreshCount = 0
            -- Check all the fields
            for fieldIndex, thisField in ipairs(fields) do
                if fieldId == thisField[COL3_FIELD_ID] then
                    refreshCount = refreshCount + 1
                    -- Get local value with sub Id
                    --local fieldValue = math.floor(value / 2 ^ (thisField[COL4_BYTE_SHIFT] * 8)) % 256
                    local fieldValue = bit32.band(bit32.rshift(value,((thisField[COL4_BYTE_SHIFT]) * 8)), 0xFF)
                    -- Set value with checking field type
                    if thisField[COL2_TYPE] == T_COMBO and #thisField == 7 then
                        for index = 1, #(thisField[COL7_COMBO_VALUES]), 1 do
                            if fieldValue == thisField[COL7_COMBO_VALUES][index] then
                                thisField[COL5_CURR_VAL] = index
                                break
                            end
                        end
                    elseif thisField[COL2_TYPE] == T_VALUE and #thisField == 9 then
                        thisField[COL5_CURR_VAL] = fieldValue - thisField[COL9_V_OFFSET]
                    end
                end
                if refreshCount >= 3 then
                    break
                end
            end
            refreshState = 0
        elseif getTime() > telemetryPopTimeout then
            refreshState = 0
        end
    end
end

local function getFieldValue(field)
    local value = field[COL5_CURR_VAL]
    if value == nil then
        return 0
    end
    if field[COL2_TYPE] == T_COMBO and #field == 7 then
        value = field[COL7_COMBO_VALUES][value]
    elseif field[COL2_TYPE] == T_VALUE and #field == 9 then
        value = value + field[COL9_V_OFFSET]
    end
    return value
end

local function updateFieldValue()
    local subIdCount = 0
    local value = 0
    for fieldIndex, thisField in ipairs(fields) do
        if fields[current][COL3_FIELD_ID] == thisField[COL3_FIELD_ID] then
            subIdCount = subIdCount + 1
            local fieldValue = getFieldValue(thisField)
            for subId = 2, thisField[COL4_BYTE_SHIFT] do
                fieldValue = bit32.lshift(fieldValue,8) -- * 256
            end
            value = bit32.bor(value,fieldValue)
        end
        if subIdCount >= 3 then
            break
        end
    end
    modifications[#modifications + 1] = { fields[current][COL3_FIELD_ID], value }
end

-- Main
local function runFieldsPage(event)
    if event == EVT_VIRTUAL_EXIT then -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then -- toggle editing/selecting current field
        if fields[current][COL5_CURR_VAL] ~= nil then
            edit = not edit
            if edit == false then
                updateFieldValue()
            end
        end
    elseif edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            addField(1)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            addField(-1)
        end
    else
        if event == EVT_VIRTUAL_NEXT then
            selectField(1)
        elseif event == EVT_VIRTUAL_PREV then
            selectField(-1)
        end
    end
    redrawFieldsPage()
    return 0
end

local function runPageMainSettings(event)
    fields = FieldsPage1
    return runFieldsPage(event)
end

local function runPageGroup1Tuning(event)
    fields = FieldsPage2
    return runFieldsPage(event)
end

local function runPageGroup2Tuning(event)
    fields = FieldsPage3
    return runFieldsPage(event)
end

local function runInfoPageLine(y1, s1, s2)
    local X1 = 20
    local X2 = 145
    lcd.drawText(X1, y1, s1, BLACK)
    lcd.drawText(X2, y1, s2, BLACK)
end

local function runInfoPage(event, touchState)
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("FrSky S8R/S6R Gyro setup", page, #pages)
    lcd.drawText(80, 30, "Switch Reminder", DBLSIZE)

    runInfoPageLine(  70, "CH13:  Gain", "")
    runInfoPageLine(  90, "CH14 =  +100", "=> stability disabled")
    runInfoPageLine( 110, "CH14 =        0",  "=> wind rejection")
    runInfoPageLine( 130, "CH14 =   -100",  "=> self level")
    runInfoPageLine( 150, "CH16 =  +100", "=> panic mode (self level)")
    return 0
end

-- Init
local function init()
    current, edit, refreshState = 1, false, 0
    modifications = {}

    pages = {
        runPageMainSettings,
        runPageGroup1Tuning,
        runPageGroup2Tuning,
        runInfoPage,
    }
end

-- Main
local function run(event)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    elseif event == EVT_PAGE_BREAK or event == EVT_PAGEDN_FIRST or event == EVT_SHIFT_BREAK then
        selectPage(1)
    elseif event == EVT_PAGE_LONG or event == EVT_PAGEUP_FIRST or event == EVT_SHIFT_LONG then
        killEvents(event);
        selectPage(-1)
    end

    local result = pages[page](event)
    refreshNext()

    return result
end

return { init = init, run = run }

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
-- Updated by: Frankie Arzu  from Frsky v3.0.6
-- Date: Apr 19, 2025

local app_ver = "v3.0.6"
local app_name = "FrSky_Gyro_Suite"

local CommonFile = assert(loadfile("common.lua"))()
local Telemetry  = CommonFile.Telemetry

local IS_SIMULATOR = false -- updated in init()
local simData = {}
local simPop  = nil

local T_VALUE = 0
local T_COMBO = 1
local T_HEADER = 2
local T_BUTTON = 3
local T_TEXT   = 4

local COL1_TXT = 1
local COL2_TYPE = 2
local COL3_FIELD_ID = 3
local COL4_BYTE_SHIFT  = 4
local COL5_CURR_VAL = 5

local COL6_COMBO_KEYS = 6
local COL6_BUTTON_TEXT = 6
local COL7_COMBO_VALUES = 7
local COL7_BUTTON_VALUE = 7

local COL6_V_MIN = 6
local COL7_V_MAX = 7
local COL8_V_SUFFIX = 8
local COL9_V_OFFSET = 9
local COL11_V_PREFIX = 11

local edit = false
local page = 1
local current = 1
local refreshState = 0
local refreshIndex = 1
local refreshTries  = 0
local pageOffset = 0
local pages = {}
local fields = {}
local modifications = {}
local margin = 10
local spacing = 22
local numberPerPage = 11
local lastError = nil

local resetDialogActive = false

local Product = { family = nil, id = nil }
FrSkyProductName = {
     [64]= "Archer+ SR10+",
     [68]= "Archer+ SR8+",
     [76]= "Archer+ SR12+",
}

local ResetDialogText = "        RESET\n Settings are about to be reset.\n Please confirm to continue\n\n [ENTER]=RESET [RTN]=CANCEL"

local FieldsPage1 = {
    { "RX Info", T_HEADER },
    { "    RX Type"                 , T_TEXT, 0xFE, 0, nil  },
    { "    RX Version"              , T_TEXT, 0xFF, 0, nil  },
    { "Group/Gyro 1"  , T_HEADER },
    { "    Reset"                   , T_BUTTON, 0xA5, 3, nil, "Start", 0x81 },
    { "    Stabilizer/Gyro"         , T_COMBO, 0xA5, 1, nil, { "OFF", "ON" }, { 0, 1 } },
    { "    Mode (Quick Mode)"       , T_COMBO, 0xA6, 1, nil, { "Full (with hover & knife)", "Simple (no hover, no knife)" }, { 0, 1 } },
    { "    Wing type"               , T_COMBO, 0xA6, 2, nil, { "Normal", "Delta", "VTail" }, { 0, 1, 2 } },
    { "    Mounting type"           , T_COMBO, 0xA6, 3, nil, { "Horizontal", "Horizontal Reversed", "Vertical", "Vertical Reversed" }, { 0, 1, 2, 3 } },
    --{ "    Self Check (1)"          , T_BUTTON, 0xA5, 2, nil, { "Start", "OFF" }, { 1, 0 } },
    { "Group/Gyro 2 (ACCESS only)", T_HEADER },
    { "    Reset"                   , T_BUTTON, 0xC3, 3, nil, "Start", 0x81 },
    { "    Stabilizer/Gyro"         , T_COMBO, 0xC3, 1, nil, { "OFF", "ON" }, { 0, 1 } },
    { "    Mode (Quick Mode)"       , T_COMBO, 0xC1, 1, nil, { "Full (with hover & knife)", "Simple (no hover, no knife)" }, { 0, 1 } },
    { "    Wing type"               , T_COMBO, 0xC1, 2, nil, { "Normal", "Delta", "VTail" }, { 0, 1, 2 } },
    { "    Mounting type"           , T_COMBO, 0xC1, 3, nil, { "Horizontal", "Horizontal Reversed", "Vertical", "Vertical Reversed" }, { 0, 1, 2, 3 } },
    --{ "    Self Check (2)"          , T_BUTTON, 0xC3, 2, nil, { "Start", "OFF" }, { 1, 0 } },
}

local FieldsPage2 = {
    { "         --- Gyro/Group 1 ---", T_HEADER },
    { "Modes"                  , T_HEADER },
    { "    CH1 mode"           , T_COMBO, 0xA7, 1, nil, { "Stabilized as AIL1", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH2 mode"           , T_COMBO, 0xA7, 2, nil, { "Stabilized as ELE1", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH4 mode"           , T_COMBO, 0xA7, 3, nil, { "Stabilized as RUD",  "AUX (Not stabilized)" },  { 0, 1 } },
    { "    CH5 mode"           , T_COMBO, 0xA8, 1, nil, { "Stabilized as AIL2", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH6 mode"           , T_COMBO, 0xA8, 2, nil, { "Stabilized as ELE2", "AUX (Not stabilized)" }, { 0, 1 } },

    { "Directions"             , T_HEADER },
    { "    Directions: AIL1"   , T_COMBO, 0xA9, 1, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: ELE1"   , T_COMBO, 0xA9, 2, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: RUD"    , T_COMBO, 0xA9, 3, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: AIL2"   , T_COMBO, 0xAA, 1, nil, { "Normal", "Inverted" }, { 0, 255 } },
    { "    Directions: ELE2"   , T_COMBO, 0xAA, 2, nil, { "Normal", "Inverted" }, { 0, 255 } },

    { "Main stabilization"     , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0xAB, 1, nil, 0, 200,   "%", 0 },
    { "    Gain: ELE"          , T_VALUE, 0xAB, 2, nil, 0, 200,   "%", 0 },
    { "    Gain: RUD"          , T_VALUE, 0xAB, 3, nil, 0, 200,   "%", 0 },
    { "    Roll Degree"        , T_VALUE, 0xB3, 1, nil, 0,  80, " deg", 0 },
    { "    Pitch Degree"       , T_VALUE, 0xB3, 2, nil, 0,  80, " deg", 0 },

    { "Auto Level"             , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0xAC, 1, nil,   0, 200, " %", 0 },
    { "    Gain: ELE"          , T_VALUE, 0xAC, 2, nil,   0, 200, " %", 0 },
    { "    Offset: AIL"        , T_VALUE, 0xAF, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: ELE"        , T_VALUE, 0xAF, 2, nil, -20,  20, " %", 0x80 },

    { "Hover"                  , T_HEADER },
    { "    Gain: ELE"          , T_VALUE, 0xAD, 2, nil, 0, 200, " %", 0 },
    { "    Gain: RUD "         , T_VALUE, 0xAD, 3, nil, 0, 200, " %", 0 },
    { "    Offset: ELE"        , T_VALUE, 0xB0, 2, nil, -20, 20, " %", 0x80 },
    { "    Offset: RUD"        , T_VALUE, 0xB0, 3, nil, -20, 20, " %", 0x80 },

    { "Knife Edge"             , T_HEADER },
    { "    Gain: AIL"          , T_VALUE, 0xAE, 1, nil,   0, 200, " %", 0 },
    { "    Gain: RUD"          , T_VALUE, 0xAE, 3, nil,   0, 200, " %", 0 },
    { "    Offset: AIL"        , T_VALUE, 0xB1, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD"        , T_VALUE, 0xB1, 3, nil, -20,  20, " %", 0x80 },

    { "Stick Priority"          , T_HEADER },
    { "    AIL1 Pri"           , T_VALUE, 0xB4, 1, nil,   0, 100, " %", 0 },
    { "    AIL1 Rev Pri"       , T_VALUE, 0xB4, 2, nil,   0, 100, " %", 0, 0, "-"},
    { "    ELE1 Pri"           , T_VALUE, 0xB5, 1, nil,   0, 100, " %", 0 },
    { "    ELE1 Rev Pri"       , T_VALUE, 0xB5, 2, nil,   0, 100, " %", 0, 0, "-" },
    { "    RUD  Pri"           , T_VALUE, 0xB6, 1, nil,   0, 100, " %", 0 },
    { "    RUD  Rev Pri"       , T_VALUE, 0xB6, 2, nil,   0, 100, " %", 0, 0, "-" },
    { "    AIL2 Pri"           , T_VALUE, 0xB7, 1, nil,   0, 100, " %", 0 },
    { "    AIL2 Rev Pri"       , T_VALUE, 0xB7, 2, nil,   0, 100, " %", 0, 0, "-"},
    { "    ELE2 Pri"           , T_VALUE, 0xB8, 1, nil,   0, 100, " %", 0 },
    { "    ELE2 Rev Pri"       , T_VALUE, 0xB8, 2, nil,   0, 100, " %", 0, 0, "-" },
}

local FieldsPage3 = {
    { "         --- Gyro/Group 2 (ACCESS only) ---", T_HEADER },
    { "Modes (Group 2)"        , T_HEADER },
    { "    CH7 mode"           , T_COMBO, 0xC2, 1, nil, { "Stabilized as AIL3", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH8 mode"           , T_COMBO, 0xC2, 2, nil, { "Stabilized as ELE3", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH9 mode"           , T_COMBO, 0xC2, 3, nil, { "Stabilized as RUD2", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH10 mode"          , T_COMBO, 0xC3, 1, nil, { "Stabilized as AIL4", "AUX (Not stabilized)" }, { 0, 1 } },
    { "    CH11 mode"          , T_COMBO, 0xC3, 2, nil, { "Stabilized as ELE4", "AUX (Not stabilized)" }, { 0, 1 } },

    { "Directions (Group 2)"   , T_HEADER },
    { "    Directions: AIL3"   , T_COMBO, 0xC4, 1, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: ELE3"   , T_COMBO, 0xC4, 2, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: RUD2"   , T_COMBO, 0xC4, 3, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: AIL4"   , T_COMBO, 0xC5, 1, nil, { "Normal", "Inverted" }, { 0, 0xFF } },
    { "    Directions: ELE4"   , T_COMBO, 0xC5, 2, nil, { "Normal", "Inverted" }, { 0, 0xFF } },

    { "Main stabilization (Group 2)", T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0xC6, 1, nil, 0, 200, "%", 0 },
    { "    Gain: ELE3-4"       , T_VALUE, 0xC6, 2, nil, 0, 200, "%", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0xC6, 3, nil, 0, 200, "%", 0 },
    { "    Roll Degree"        , T_VALUE, 0xCD, 1, nil, 0, 80, "deg", 0 },
    { "    Pitch Degree"       , T_VALUE, 0xCD, 2, nil, 0, 80, "deg", 0 },

    { "Auto Level (Group 2)"   , T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0xC7, 1, nil,   0, 200, " %", 0 },
    { "    Gain: ELE3-4"       , T_VALUE, 0xC7, 2, nil,   0, 200, " %", 0 },
    { "    Offset: AIL3-4"     , T_VALUE, 0xCA, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: ELE3-4"     , T_VALUE, 0xCA, 2, nil, -20,  20, " %", 0x80 },

    { "Hover (Group 2)"        , T_HEADER },
    { "    Gain: ELE3-4"       , T_VALUE, 0xC8, 2, nil,   0, 200, " %", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0xC8, 3, nil,   0, 200, " %", 0 },
    { "    Offset: ELE3-4"     , T_VALUE, 0xCB, 2, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD2"       , T_VALUE, 0xCB, 3, nil, -20,  20, " %", 0x80 },

    { "Knife Edge (Group 2)"   , T_HEADER },
    { "    Gain: AIL3-4"       , T_VALUE, 0xC9, 1, nil,   0, 200, " %", 0 },
    { "    Gain: RUD2"         , T_VALUE, 0xC9, 3, nil,   0, 200, " %", 0 },
    { "    Offset: AIL3-4"     , T_VALUE, 0xCC, 1, nil, -20,  20, " %", 0x80 },
    { "    Offset: RUD2"       , T_VALUE, 0xCC, 3, nil, -20,  20, " %", 0x80 },

    { "Stick Priority (Group 2)", T_HEADER },
    { "    AIL3 Pri"           , T_VALUE, 0xCE, 1, nil,   0, 100, " %", 0 },
    { "    AIL3 Rev Pri"       , T_VALUE, 0xCE, 2, nil,   0, 100, " %", 0, 0, "-"},
    { "    ELE3 Pri"           , T_VALUE, 0xCF, 1, nil,   0, 100, " %", 0 },
    { "    ELE3 Rev Pri"       , T_VALUE, 0xCF, 2, nil,   0, 100, " %", 0, 0, "-" },
    { "    RUD2 Pri"           , T_VALUE, 0xD0, 1, nil,   0, 100, " %", 0 },
    { "    RUD2 Rev Pri"       , T_VALUE, 0xD0, 2, nil,   0, 100, " %", 0, 0, "-" },
    { "    AIL4 Pri"           , T_VALUE, 0xD1, 1, nil,   0, 100, " %", 0 },
    { "    AIL4 Rev Pri"       , T_VALUE, 0xD1, 2, nil,   0, 100, " %", 0, 0, "-"},
    { "    ELE4 Pri"           , T_VALUE, 0xD2, 1, nil,   0, 100, " %", 0 },
    { "    ELE4 Rev Pri"       , T_VALUE, 0xD2, 2, nil,   0, 100, " %", 0, 0, "-" },
}

local function log(fmt, ...)
    print("[" .. app_name .. "]" .. string.format(fmt, ...))
end

local function addFieldMinMax(field, step, min, max)
    if (step < 0 and field[COL5_CURR_VAL] > min) or (step > 0 and field[COL5_CURR_VAL] < max) then
        field[COL5_CURR_VAL] = field[COL5_CURR_VAL] + step
    end
end

local function extractRawValue(field,value)
    local Data = {}
    local fieldId
    fieldId, Data[1], Data[2], Data[3] = Telemetry.parseValue(value)

    local fieldValue  = 0
    local byteShift = field[COL4_BYTE_SHIFT] or 0
    if (byteShift == 0) then  -- use the entire 32 bits value
        fieldValue = bit32.rshift(value,8) -- remove fieldId
    else  -- Get local value with sub Id  (single byte)
        fieldValue = Data[byteShift]
    end

    return fieldId, fieldValue, Data
end

local function encodeRawValue (field,value)
    for subId = 2, field[COL4_BYTE_SHIFT] do
        value = bit32.lshift(value,8)
    end
    return value
end

local function makeType(type)
    local obj = {}
    local function dummy() return nil end

    obj.type = type
    obj.getType     = function () return obj.type end
    obj.toString    = dummy
    obj.add         = dummy
    obj.getValue    = function() return 0 end
    obj.setValue    = dummy
    return obj
end

------------
local TypeHeader = makeType(T_HEADER)

------------
local TypeText   = makeType(T_TEXT)
function TypeText.setValue(field,rawValue)
    local fieldId, fieldValue, Data  = extractRawValue(field,rawValue)
    -- Special Cases
    if (fieldId==0xFE) then -- Product ID
        local family =  Data[1]
        local id     =  Data[2]
        field[COL8_V_SUFFIX] = FrSkyProductName[id] or "Unknown"
    elseif (fieldId==0xFF) then -- Version
        local major = Data[1]
        local minor = Data[2]
        local revision = Data[3]
        local remoteVersion = string.format("%d.%d.%d", major, minor, revision)
        print("Remote version: " .. remoteVersion)
        field[COL8_V_SUFFIX] = remoteVersion
    end

end

function TypeText.toString(field)
    return field[COL8_V_SUFFIX]
end

------------
local TypeButton = makeType(T_BUTTON)
function TypeButton.setValue(field,rawValue)
    local _, fieldValue  = extractRawValue(field,rawValue)
    field[COL5_CURR_VAL] = fieldValue
end

function TypeButton.toString(field)
    return field[COL6_BUTTON_TEXT]
end

------------
local TypeValue = makeType(T_VALUE)

function TypeValue.setValue(field,rawValue)
    if #field < 9 then
        assert("T_VALUE must have 7 values")
    end

    local _, fieldValue, Data = extractRawValue(field,rawValue)
    field[COL5_CURR_VAL] = fieldValue - field[COL9_V_OFFSET]
end

function TypeValue.getValue(field)
    local value = field[COL5_CURR_VAL]
    if value==nil then return 0 end
    value = value + field[COL9_V_OFFSET]
    return value
end

function TypeValue.add(field,step)
    addFieldMinMax(field,step,field[COL6_V_MIN],field[COL7_V_MAX])
end

function TypeValue.toString(field)
    local ret
    local value = field[COL5_CURR_VAL]

    if (value==nil) then return nil end
    ret = tostring(value) .. field[COL8_V_SUFFIX]
    if #field >= 11 then -- Prefix
        ret = field[COL11_V_PREFIX] .. ret -- Prefix
    end
    return ret
end

------------
local TypeCombo = makeType(T_COMBO)

function TypeCombo.setValue(field,rawValue)
    if #field < 7 then
        assert("Combo must have 7 values")
    end

    local _, fieldValue  = extractRawValue(field,rawValue)

    local valueFound = false
    for index = 1, #(field[COL7_COMBO_VALUES]), 1 do
        if fieldValue == field[COL7_COMBO_VALUES][index] then
            field[COL5_CURR_VAL] = index
            valueFound = true
            break
        end
    end
    if not valueFound then
        lastError = string.format("%s: invalid COMBO value %02X",field[COL1_TXT], fieldValue)
    end
end

function TypeCombo.getValue(field)
    local value = field[COL5_CURR_VAL]
    if value==nil then return 0 end
    value = field[COL7_COMBO_VALUES][value]
    return value
end

function TypeCombo.add(field,step)
    addFieldMinMax(field,step,1,#(field[COL6_COMBO_KEYS]))
end

function TypeCombo.toString(field)
    local value = field[COL5_CURR_VAL]
    if (value==nil) then return nil end

    if value > 0 and value <= #(field[COL6_COMBO_KEYS]) then
        return field[COL6_COMBO_KEYS][value]
    else
        return "[INVALID]"
    end
end
------------

local TypeHandler = {
    [T_HEADER]  = TypeHeader,
    [T_VALUE]   = TypeValue,
    [T_COMBO]   = TypeCombo,
    [T_BUTTON]  = TypeButton,
    [T_TEXT]    = TypeText
}

-- Select the next or previous page
local function selectPage(step)
    if page == 1 and step < 0 then
        return
    end
    if page + step > #pages then
        return
    end
    page = page + step
    refreshIndex = 1
    pageOffset = 0
    current = 1 -- farzu: change of page, reset field
    lastError = nil
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
    log("field : %s Type=%d value=%d", field[COL1_TXT], field[COL2_TYPE], field[COL5_CURR_VAL] or 0)

    -- scroll if needed
    if current > numberPerPage + pageOffset then
        pageOffset = current - numberPerPage
    elseif current <= pageOffset then
        pageOffset = current - 1
    end
end

local function getNextNilField()
    while refreshIndex <= #fields do
        if fields[refreshIndex][COL2_TYPE] ~= T_HEADER then
            return fields[refreshIndex]
        end
        refreshIndex = refreshIndex + 1
    end
    return nil
end

local function drawProgressBar()
    local width = (80 * refreshIndex) / #fields
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
    drawScreenTitle("FrSky SRx setup", page, #pages)

    if refreshIndex <= #fields then
        drawProgressBar()
    end

    for index = 1, numberPerPage, 1 do
        local field = fields[pageOffset + index]
        if field == nil then break end

        local type = field[COL2_TYPE]
        local attr = current == (pageOffset + index) and ((edit == true and BLINK or 0) + INVERS) or 0
        attr = attr + (type == T_HEADER and BOLD or 0) -- BOLD Headers

        lcd.drawText(1, margin + spacing * index, field[COL1_TXT], attr)

        if type ~= T_HEADER then
            local value = TypeHandler[type].toString(field) or "---"
            lcd.drawText(280, margin + spacing * index, value , attr)
        end
    end

    if (lastError) then
        lcd.drawText(1, margin + spacing * numberPerPage, lastError, INVERS)
    end
end

local telemetryPopTimeout = 0
local function refreshNext()
    if refreshState == 0 then -- No request in Progress
        if #modifications > 0 then
            Telemetry.telemetryWrite(modifications[1][1], modifications[1][2])
            modifications[1] = nil
            refreshIndex = 1
        else
            local thisField = getNextNilField()
            if thisField ~= nil then
                if Telemetry.telemetryRead(thisField[COL3_FIELD_ID]) == true then
                    refreshState = 1
                    telemetryPopTimeout = getTime() + 80 -- normal delay is 500ms
                end
            end
        end
    elseif refreshState == 1 then -- Request In Progress
        local value = Telemetry.telemetryPop()

        if (value == nil) then
            -- Check for TimeOut, after 3 times, move index to next field
            if getTime() > telemetryPopTimeout then
                refreshState = 0
                refreshTries = refreshTries + 1
                if (refreshTries > 3) then
                    refreshIndex =  refreshIndex + 1
                    refreshTries = 0
                end
            end
            return
        end

        local fieldId = Telemetry.parseValue(value)

        -- Check all the fields who are consecutive
        -- if not consecutive, a new request will be done later

        while refreshIndex <= #fields do
            local thisField = fields[refreshIndex]
            if fieldId ~= thisField[COL3_FIELD_ID] then -- no longer the same ID
                break
            end
            -- Set value with checking field type
            local type = thisField[COL2_TYPE]
            TypeHandler[type].setValue(thisField,value)
            refreshIndex =  refreshIndex + 1
        end -- while
        refreshState = 0
    end -- refreshState==1
end


local function updateFieldValue(fieldId)
    local subIdCount = 0
    local value = 0
    -- Combine the 3 bytes of the SubId who are on different fields/lines
    for fieldIndex, thisField in ipairs(fields) do
        if fieldId == thisField[COL3_FIELD_ID] then
            local type = thisField[COL2_TYPE]
            subIdCount = subIdCount + 1
            local fieldValue = TypeHandler[type].getValue(thisField)
            fieldValue = encodeRawValue(thisField,fieldValue) -- Sub Shift
            value = bit32.bor(value,fieldValue)
        end
        if subIdCount >= 3 then
            break
        end
    end
    modifications[#modifications + 1] = { fields[current][COL3_FIELD_ID], value }
end

-- Main

local function runDialog(field, event)
    redrawFieldsPage()
    local x = LCD_W/4
    local y = spacing * 1
    lcd.drawFilledRectangle(x, y, LCD_W/2, LCD_H/2, LIGHTWHITE)
    lcd.drawRectangle(x, y, LCD_W/2, LCD_H/2, BLACK)
    lcd.drawText(x+5,y+5,ResetDialogText)

    if event == EVT_VIRTUAL_EXIT then -- CANCEL
        resetDialogActive=false
    elseif event == EVT_VIRTUAL_ENTER then -- OK
        field[COL5_CURR_VAL] = field[COL7_BUTTON_VALUE] -- Button Value
        updateFieldValue(field[COL3_FIELD_ID])
        resetDialogActive=false
    end

end

local function runFieldsPage(event)
    local field = fields[current]

    if resetDialogActive then
        runDialog(field, event)
        return 0
    end

    local type = field[COL2_TYPE]
    if event == EVT_VIRTUAL_EXIT then -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then -- toggle editing/selecting current field
        if type == T_BUTTON then
            resetDialogActive = true -- Activate Dialog to confirm
        elseif type == T_TEXT then
            -- nothing
        elseif field[COL5_CURR_VAL] ~= nil then
            edit = not edit
            if edit == false then
                updateFieldValue(field[COL3_FIELD_ID])
            end
        end
    elseif edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            TypeHandler[type].add(field,1)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            TypeHandler[type].add(field,-1)
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
    drawScreenTitle("FrSky SRx Gyro setup", page, #pages)
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

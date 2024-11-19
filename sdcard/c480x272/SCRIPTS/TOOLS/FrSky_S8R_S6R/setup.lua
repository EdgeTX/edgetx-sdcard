---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
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

chdir("/SCRIPTS/TOOLS/FrSky_S8R_S6R")

-- script to setup parameter on S6R/S8R
-- this script work only with S6R/S8R
-- it should NOT be used to confing SR8-pro/SR10-pro/SR-12pro
-- it should NOT be used to confing SR8+ SR10+ SR 12+
-- based on FrSky version 2.01

-- Updated by: Offer Shmuely
-- Date: 2023

local app_ver = "v2.07-etx-SxR"
local app_name = "FrSky_SR"

local T_VALUE = 0
local T_COMBO = 1
local T_HEADER = 2

local COL1_TXT = 1
local COL2_TYPE = 2
local COL3_FIELD_ID = 3
local COL4_CURR_VAL = 4

local COL5_COMBO_KEYS = 5
local COL6_COMBO_VALUES = 6

local COL5_V_MIN = 5
local COL6_V_MAX = 6
local COL8_V_UNIT = 8
local COL9_V_BASE_VAL = 9

local COL7_IS_VISIBLE = 7

local edit = false
local page = 1
local current = 1
local refreshState = 0
local refreshIndex = 0
local pageOffset = 0
local pages = {}
local fields = {}
local modifications = {}
local wingBitmaps = {}
local mountBitmaps = {}
local margin = 10
local spacing = 22
local numberPerPage = 11
local touch_d0 = 0
local is_gyro_enabled = 1

local FieldsGroup1 = {
    { "Enable/Disable Gyro", T_COMBO, 0x9C, nil, {"OFF", "ON" }                                                         , {0,1}, 1 },
    { "Wing type"          , T_COMBO, 0x80, nil, {"Normal", "Delta", "VTail" }                                          , {0,1}, 1 },
    { "Mounting type"      , T_COMBO, 0x81, nil, {"Horizontal", "Horizontal Reversed", "Vertical", "Vertical Reversed" }, {0,1}, 1 },
}

local wingBitmapsFile = { "bmp/plane.bmp", "bmp/delta.bmp", "bmp/vtail.bmp" }
local mountBitmapsFile = { "bmp/horz.bmp", "bmp/horz-r.bmp", "bmp/vert.bmp", "bmp/vert-r.bmp" }

local FieldsGroup2 = {
    { "Modes", T_HEADER},
    { "    Stabilization mode:" , T_COMBO, 0xAA, nil, {"Full (with hover & knife)", "Simple (no hover, no knife)"}, {0,1}, 1 },
    { "    CH5 mode"            , T_COMBO, 0xA8, nil, {"Stabilized is AIL2", "AUX (Not stabilized)"}                     , {0,1}, 1 },
    { "    CH6 mode"            , T_COMBO, 0xA9, nil, {"Stabilized is ELE2", "AUX (Not stabilized)"}                     , {0,1}, 1 },

    { "Main stabilization"      , T_HEADER},
    { "    Gain: AIL"           , T_VALUE, 0x85, nil, 0, 200, 1, "%"},
    { "    Gain: ELE"           , T_VALUE, 0x86, nil, 0, 200, 1, "%"},
    { "    Gain: RUD"           , T_VALUE, 0x87, nil, 0, 200, 1, "%"},

    { "Directions"              , T_HEADER},
    { "    Directions: AIL"     , T_COMBO, 0x82, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    { "    Directions: ELE"     , T_COMBO, 0x83, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    { "    Directions: RUD"     , T_COMBO, 0x84, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    { "    Directions: AIL2"    , T_COMBO, 0x9A, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    { "    Directions: ELE2"    , T_COMBO, 0x9B, nil, {"Normal", "Inverted"}, {255, 0}, 1 },

    { "Auto Level"              , T_HEADER},
    { "    Gain: AIL"           , T_VALUE, 0x88, nil,   0, 200, 1, "%"},
    { "    Gain: ELE"           , T_VALUE, 0x89, nil,   0, 200, 1, "%"},
    { "    Offset: AIL"         , T_VALUE, 0x91, nil, -20,  20, 1, "%", 0x6C},
    { "    Offset: ELE"         , T_VALUE, 0x92, nil, -20,  20, 1, "%", 0x6C},

    { "Hover"                   , T_HEADER},
    { "    Gain: ELE"           , T_VALUE, 0x8C, nil,   0, 200, 1, "%"},
    { "    Gain: RUD"           , T_VALUE, 0x8D, nil,   0, 200, 1, "%"},
    { "    Offset: ELE"         , T_VALUE, 0x95, nil, -20,  20, 1, "%", 0x6C},
    { "    Offset: RUD"         , T_VALUE, 0x96, nil, -20,  20, 1, "%", 0x6C},

    { "Knife Edge"              , T_HEADER},
    { "    Gain: AIL"           , T_VALUE, 0x8E, nil,   0, 200, 1, "%"},
    { "    Gain: RUD"           , T_VALUE, 0x90, nil,   0, 200, 1, "%"},
    { "    Offset: AIL"         , T_VALUE, 0x97, nil, -20,  20, 1, "%", 0x6C},
    { "    Offset: RUD"         , T_VALUE, 0x99, nil, -20,  20, 1, "%", 0x6C},
}

local function log(fmt, ...)
    print("[" .. app_name .. "]" .. string.format(fmt, ...))
end
local function is_simulator()
    local _, rv = getVersion()
    return string.sub(rv, -5) == "-simu"
end

local function drawScreenTitle(title, page, pages)
    --if math.fmod(math.floor(getTime() / 100), 10) == 0 then
    --    title = version
    --end
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
    lcd.drawText(10, 5, title.. " (".. app_ver ..")", MENU_TITLE_COLOR)
    lcd.drawText(LCD_W - 40, 5, page .. "/" .. pages, MENU_TITLE_COLOR)
end

-- Change display attribute to current field
local function addField(step)
    local field = fields[current]
    local min, max
    if field[2] == T_VALUE then
        min = field[COL5_V_MIN]
        max = field[COL6_V_MAX]
    elseif field[2] == T_COMBO then
        min = 0
        max = #(field[COL5_COMBO_KEYS]) - 1
    elseif field[2] == T_HEADER then
        min = 0
        max = 0
    end
    if (step < 0 and field[COL4_CURR_VAL] > min) or (step > 0 and field[COL4_CURR_VAL] < max) then
        field[COL4_CURR_VAL] = field[COL4_CURR_VAL] + step
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
        if field[COL2_TYPE] ~= T_HEADER and field[COL7_IS_VISIBLE] == 1 then
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
        if fields[offsetIndex][5] == nil then
            return fields[offsetIndex], offsetIndex
        end
    end
    return nil, nil
end

local function drawProgressBar()
    local width = (80 * refreshIndex) / #fields
    lcd.drawRectangle(350, 12, 80, 8, GREY)
    lcd.drawFilledRectangle(351, 12, width, 6, GREY)
end

-- Redraw the current page
local function redrawFieldsPage()
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("FrSky S8R/S6R Gyro setup", page, #pages)

    if refreshIndex < #fields then
        drawProgressBar()
    end

    for index = 1, numberPerPage, 1 do
        local field = fields[pageOffset + index]
        if field == nil then
            break
        end

        local attr = current == (pageOffset + index) and ((edit == true and BLINK or 0) + INVERS) or 0

        -- debugging in simulator
        if is_simulator() and field[COL4_CURR_VAL] == nil then
            log("simu")
            if field[COL2_TYPE] == T_VALUE then
                log("simu - value")
                field[COL4_CURR_VAL] = field[COL5_V_MIN]
            elseif field[COL2_TYPE] == T_COMBO then
                log("simu - combo")
                field[COL4_CURR_VAL] = 0
            end

            log("simu: %s=%s", field[COL1_TXT], field[COL4_CURR_VAL])
        end

        if field[COL2_TYPE] == T_HEADER then
            attr = attr + BOLD
        end

        if field[COL7_IS_VISIBLE] == nil or field[COL7_IS_VISIBLE] == 1 then
            lcd.drawText(10, margin + spacing * index, field[COL1_TXT], attr)

            if field[COL4_CURR_VAL] == nil and field[COL2_TYPE] ~= T_HEADER then
                lcd.drawText(280, margin + spacing * index, "---", attr)
            else
                if field[COL2_TYPE] == T_VALUE then
                    --lcd.drawNumber(280, margin + spacing * index, field[COL4_CURR_VAL], attr)
                    lcd.drawText(280, margin + spacing * index, field[COL4_CURR_VAL] .. field[COL8_V_UNIT], attr)
                elseif field[COL2_TYPE] == T_COMBO then
                    if field[COL4_CURR_VAL] >= 0 and field[COL4_CURR_VAL] < #(field[COL5_COMBO_KEYS]) then
                        lcd.drawText(280, margin + spacing * index, field[COL5_COMBO_KEYS][1 + field[COL4_CURR_VAL]], attr)
                    end
                end
            end
        end

        if index == 1 and is_gyro_enabled == 0 then
            lcd.drawText(120, 120, "Gyro Disabled", DBLSIZE + GREY)
            lcd.drawText(20, 160, "Receiver operate as simple RX", DBLSIZE + GREY)
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
        if #modifications > 0 then
            telemetryWrite(modifications[1][1], modifications[1][2])
            modifications[1] = nil
        elseif refreshIndex < #fields then
            --local field = fields[refreshIndex + 1]
            local field = fields[current]
            log("111a - %s=%s", field[COL1_TXT], field[COL4_CURR_VAL])
            if field[COL4_CURR_VAL] == nil then
                if telemetryRead(field[COL3_FIELD_ID]) == true then
                    refreshState = 1
                    telemetryPopTimeout = getTime() + 500 -- normal delay is 500ms
                end
            else
                refreshIndex = refreshIndex + 1
                refreshState = 0
            end
        else
            refreshIndex = 0
            refreshState = 0
        end
    elseif refreshState == 1 then
        local physicalId, primId, dataId, value = sportTelemetryPop()
        if physicalId == 0x1A and primId == 0x32 and dataId == 0x0C30 then
            local fieldId = value % 256
            local field = fields[refreshIndex + 1]
            if fieldId == field[COL3_FIELD_ID] then
                value = math.floor(value / 256)
                if field[COL3_FIELD_ID] == 0xAA then
                    value = bit32.band(value, 0x0001)
                end
                if field[COL3_FIELD_ID] >= 0x9E and field[COL3_FIELD_ID] <= 0xA0 then
                    local b1 = value % 256
                    local b2 = math.floor(value / 256)
                    value = b1 * 256 + b2
                    value = value - bit32.band(value, 0x8000) * 2
                end
                --if field[COL2_TYPE] == T_COMBO and #field >= 6 and field[COL6_COMBO_VALUES] ~= nil then
                if field[COL2_TYPE] == T_COMBO then
                    for index = 1, #(field[COL6_COMBO_VALUES]), 1 do
                        if value == field[COL6_COMBO_VALUES][index] then
                            value = index - 1
                            break
                        else
                            value = 0
                        end
                    end
                --elseif field[COL2_TYPE] == T_COMBO then
                --    if value >= #field[COL5_COMBO_KEYS] then
                --        value = #field[COL5_COMBO_KEYS] - 1
                --    end
                elseif field[COL2_TYPE] == T_VALUE and #field >= 9 and field[COL9_V_BASE_VAL] then
                    value = value - field[COL9_V_BASE_VAL] + field[COL5_V_MIN]
                end
                fields[refreshIndex + 1][COL4_CURR_VAL] = value
                refreshIndex = refreshIndex + 1
                refreshState = 0
            end
        elseif getTime() > telemetryPopTimeout then
            fields[refreshIndex + 1][COL4_CURR_VAL] = nil
            refreshIndex = refreshIndex + 1
            refreshState = 0
        end
    end
end

local function updateFieldValue(field)
    local value = field[COL4_CURR_VAL]
    --if field[COL2_TYPE] == T_COMBO and #field >= 6 and field[6] ~= nil  then
    --    value = field[6][1 + value]
    if field[COL2_TYPE] == T_COMBO then
        value = field[COL6_COMBO_VALUES][1 + value]
    elseif field[COL2_TYPE] == T_VALUE and #field >= 9 and field[COL9_V_BASE_VAL] then
        value = value + field[COL9_V_BASE_VAL] - field[COL5_V_MIN]
    end
    modifications[#modifications + 1] = { field[COL3_FIELD_ID], value }
end

-- Main
local function runFieldsPage(event, touchState)
    if event == EVT_VIRTUAL_EXIT then -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then -- toggle editing/selecting current field
        if fields[current][COL4_CURR_VAL] ~= nil then
            edit = not edit
            if edit == false then
                updateFieldValue(fields[current])
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
        elseif event == EVT_TOUCH_FIRST then
            touch_d0 = 0
        elseif event == EVT_TOUCH_SLIDE and page==2 then
            local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
            if d < touch_d0 then
                if pageOffset > 0 then
                    pageOffset = pageOffset -1
                end
                touch_d0 = d
            elseif d > touch_d0 then
                if pageOffset < #fields - numberPerPage then
                    pageOffset = pageOffset +1
                end
                touch_d0 = d
            end
        end

    end
    redrawFieldsPage()
    return 0
end

local function runConfigPage(event, touchState)
    fields = FieldsGroup1

    if fields[1][COL4_CURR_VAL] == 1 then
        is_gyro_enabled = 1
        fields[1][COL7_IS_VISIBLE] = 1
        fields[2][COL7_IS_VISIBLE] = 1
        fields[3][COL7_IS_VISIBLE] = 1
    else
        is_gyro_enabled = 0
        fields[1][COL7_IS_VISIBLE] = 1
        fields[2][COL7_IS_VISIBLE] = 0
        fields[3][COL7_IS_VISIBLE] = 0
    end

    local result = runFieldsPage(event, touchState)

    if is_gyro_enabled == 1 then
        if fields[2][COL4_CURR_VAL] ~= nil then
            if wingBitmaps[1 + fields[2][COL4_CURR_VAL]] == nil then
                wingBitmaps[1 + fields[2][COL4_CURR_VAL]] = Bitmap.open(wingBitmapsFile[1 + fields[2][COL4_CURR_VAL]])
            end
            lcd.drawBitmap(wingBitmaps[1 + fields[2][COL4_CURR_VAL]], 10, 90)
        end
        if fields[3][COL4_CURR_VAL] ~= nil then
            if mountBitmaps[1 + fields[3][COL4_CURR_VAL]] == nil then
                mountBitmaps[1 + fields[3][COL4_CURR_VAL]] = Bitmap.open(mountBitmapsFile[1 + fields[3][COL4_CURR_VAL]])
            end
            lcd.drawBitmap(mountBitmaps[1 + fields[3][COL4_CURR_VAL]], 190, 110)
        end
    end

    return result
end

local function runSettingsPage(event, touchState)
    fields = FieldsGroup2
    return runFieldsPage(event, touchState)
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

    runInfoPageLine( 70, "CH9: Gain", "")
    runInfoPageLine( 90, "CH10 = +100", "=> stability disabled")
    runInfoPageLine(110, "CH10 =        0", "=> wind rejection")
    runInfoPageLine(130, "CH10 =  -100", "=> self level")
    runInfoPageLine(150, "CH12: +100", "=> panic mode")
    runInfoPageLine(170, "CH12: x3 times ", "=> activate self-check ")
    return 0
end

-- Init
local function init()
    current, edit, refreshState, refreshIndex = 1, false, 0, 0
    wingBitmapsFile = { "img/plane_b.png", "img/delta_b.png", "img/planev_b.png" }
    mountBitmapsFile = { "img/up.png", "img/down.png", "img/vert.png", "img/vert-r.png" }

    pages = {
        runConfigPage,
        runSettingsPage,
        runInfoPage,
    }
end

-- Main
local function run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    elseif event == EVT_VIRTUAL_NEXT_PAGE and is_gyro_enabled == 1 then
        selectPage(1)
    elseif event == EVT_VIRTUAL_PREV_PAGE then
        killEvents(event)
        selectPage(-1)
    end

    local result = pages[page](event, touchState)
    refreshNext()

    return result
end

return { init = init, run = run }


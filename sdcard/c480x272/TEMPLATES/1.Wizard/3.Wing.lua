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

-- Author: Offer Shmuely
-- Date: 2023-2024
-- version: 1.3

local VALUE = 0
local COMBO = 1
local HEADER = 2

local is_edit = false
local page = 1
local current = 1
local pages = {}

chdir("/TEMPLATES/1.Wizard")

-- load common Bitmaps
local ImgMarkBg = bitmap.open("img/mark_bg.png")
local BackgroundImg = bitmap.open("img/background.png")
local ImgPlane = bitmap.open("img/wing/plane.png")
local ImgPageUp = bitmap.open("img/pageup.png")
local ImgPageDn = bitmap.open("img/pagedn.png")

local STICK_NUMBER_AIL = 3
local STICK_NUMBER_ELE = 1
local STICK_NUMBER_THR = 2
local STICK_NUMBER_RUD = 0

local defaultChannel_AIL = defaultChannel(STICK_NUMBER_AIL) + 1
local defaultChannel_ELE = defaultChannel(STICK_NUMBER_ELE) + 1
local defaultChannel_THR = defaultChannel(STICK_NUMBER_THR) + 1
local defaultChannel_RUD = defaultChannel(STICK_NUMBER_RUD) + 1

local defaultChannel_0_AIL = defaultChannel(STICK_NUMBER_AIL)
local defaultChannel_0_ELE = defaultChannel(STICK_NUMBER_ELE)
local defaultChannel_0_THR = defaultChannel(STICK_NUMBER_THR)
local defaultChannel_0_RUD = defaultChannel(STICK_NUMBER_RUD)


-- Change display attribute to current field
local function addField(fields, step)
    local field = fields[current]
    local min, max
    if field.type == VALUE then
        min = field.min
        max = field.max
    elseif field.type == COMBO then
        min = 0
        max = #(field.avail_values) - 1
    elseif field.type == HEADER then
        min = 0
        max = 0
    end
    if (step < 0 and field.value > min) or (step > 0 and field.value < max) then
        field.value = field.value + step
    end
end

-- Select the next or previous page
local function selectPage(step)
    if page == 1 and step < 0 then
        return
    end
    page = 1 + ((page + step - 1 + #pages) % #pages)
    is_edit = false
    current = 1
    print(string.format("page: (%s)", page))

end

-- Select the next or previous editable field
local function selectField(fields, step)
    print(string.format("selectField-start: current: %s", current))
    repeat
        print(string.format("selectField: current: %s (vis: %s)", current, fields[current].is_visible))
        current = 1 + ((current + step - 1 + #fields) % #fields)
        if fields[current].type == HEADER then
            current = 1 + ((current + step - 1 + #fields) % #fields)
        end
    until fields[current].is_visible == 1
    print(string.format("selectField-end: current: %s", current))
end

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px

local function lcdSizeTextFixed(txt, font_size)
    local ts_w, ts_h = lcd.sizeText(txt, font_size)

    local v_offset = 0
    if font_size == FONT_38 then
        v_offset = -11
    elseif font_size == FONT_16 then
        v_offset = -5
    elseif font_size == FONT_12 then
        v_offset = -4
    elseif font_size == FONT_8 then
        v_offset = -3
    elseif font_size == FONT_6 then
        v_offset = 0
    end
    return ts_w, ts_h +2*v_offset, v_offset
end

local function drawBadgedText(txt, field, font_size, is_selected, is_edit)
    local ts_w, ts_h, v_offset = lcdSizeTextFixed(txt, font_size)
    local bdg_h = 5 + ts_h + 5
    local r = bdg_h / 2

    if (field.w > 0) then
        ts_w = field.w
    else
        if (ts_w < 30) then
            ts_w = 30
        end
    end
    local bg_color = WHITE
    if (is_selected) then
        bg_color = GREEN
    end
    lcd.drawFilledCircle(field.x, field.y + r, r, bg_color)
    lcd.drawFilledCircle(field.x + ts_w, field.y + r, r, bg_color)
    lcd.drawFilledRectangle(field.x, field.y, ts_w, bdg_h, bg_color)
    local attr = 0
    if (is_selected and is_edit) then
        attr = attr + BLINK
    end

    lcd.drawText(field.x, field.y + v_offset + 5, txt, font_size + BLACK + attr)
end


-- Redraw the current page
local function redrawFieldsPage(fields, event)
    for index = 1, 10, 1 do
        local field = fields[index]
        if field == nil then
            break
        end

        -- print(string.format("redrawFieldsPage [%s] field.x=%s, y=%s, is_visible=%s", field.id, field.x, field.y, field.is_visible))
        local attr = current == (index) and ((is_edit == true and BLINK or 0) + INVERS) or 0
        local is_selected = (current == (index))
        attr = attr + COLOR_THEME_PRIMARY1
        if field.is_visible == 1 then
            if field.type == VALUE then
                --lcd.drawNumber(field.x, field.y, field.value, LEFT + attr)
                drawBadgedText(field.value, field, FONT_8, is_selected, is_edit)
            elseif field.type == COMBO then
                if field.value >= 0 and field.value < #(field.avail_values) then
                    --lcd.drawText(field.x, field.y, field.avail_values[1 + field.value], attr)
                    drawBadgedText(field.avail_values[1 + field.value], field, FONT_8, is_selected, is_edit)
                end
            elseif field.type == HEADER then
                lcd.drawText(field.x, field.y, field.value, FONT_8 + BLACK + attr + BOLD)
            end
        end
    end
end

local function updateField(field)
    local value = field.value
end

-- Main
local function runFieldsPage(fields, event)
    if event == EVT_VIRTUAL_EXIT then
        -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then
        -- toggle editing/selecting current field
        if fields[current].value ~= nil then
            is_edit = not is_edit
            if is_edit == false then
                updateField(fields[current])
            end
        end
    elseif is_edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            addField(fields, 1)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            addField(fields, -1)
        end
    else
        if event == EVT_VIRTUAL_NEXT then
            selectField(fields, 1)
        elseif event == EVT_VIRTUAL_PREV then
            selectField(fields, -1)
        end
    end
    redrawFieldsPage(fields, event)
    return 0
end

-- set visibility flags starting with SECOND field of fields
local function setFieldsVisible(fields, ...)
    local arg = { ... }
    local cnt = 2
    for i, v in ipairs(arg) do
        fields[cnt].is_visible = v
        cnt = cnt + 1
    end
end


-- draws one letter mark
local function drawMark(x, y, name)
    lcd.drawBitmap(ImgMarkBg, x, y)
    lcd.drawText(x + 8, y + 3, name, COLOR_THEME_PRIMARY1)
end

local function drawTitle(txt)
    lcd.drawFilledRectangle(1, 1, 480, 35, LIGHTGREY)
    lcd.drawText(150, 8, txt, COLOR_THEME_PRIMARY1)
end

local MotorFields = {
    is_motor   = { id='is_motor'  , x=170, y=50 , w=0, type=COMBO, is_visible=1, value=1                   , avail_values={ "No", "Yes" } },
    motor_ch   = { id='motor_ch'  , x=170, y=90 , w=0, type=COMBO, is_visible=1, value=defaultChannel_0_THR, avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" } },
    is_arm     = { id='is_arm'    , x=170, y=130, w=0, type=COMBO, is_visible=1, value=1                   , avail_values={ "No", "Yes" } },
    arm_switch = { id='arm_switch', x=230, y=130, w=0, type=COMBO, is_visible=1, value=5                   , avail_values={ "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    page = {}
}
MotorFields.page = {
    MotorFields.is_motor,
    MotorFields.motor_ch,
    MotorFields.is_arm,
    MotorFields.arm_switch
}

local ImgEngine

local function runMotorConfig(event)
    lcd.clear()
    if ImgEngine == nil then
        ImgEngine = bitmap.open("img/wing/prop.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgEngine, 310, 50)

    drawTitle("Motor Settings")

    lcd.drawText(40, MotorFields.is_motor.y, "Have a motor?", COLOR_THEME_PRIMARY1)
    print(string.format("111=%s", MotorFields.is_motor.x))

    MotorFields.motor_ch.is_visible = 0
    MotorFields.is_arm.is_visible = 0
    MotorFields.arm_switch.is_visible = 0
    if MotorFields.is_motor.value == 1 then
        lcd.drawText(40, MotorFields.motor_ch.y, "Motor channel", COLOR_THEME_PRIMARY1)
        MotorFields.motor_ch.is_visible = 1

        lcd.drawText(40, MotorFields.is_arm.y, "Safety Switch", COLOR_THEME_PRIMARY1)
        MotorFields.is_arm.is_visible = 1
        if MotorFields.is_arm.value == 1 then
            MotorFields.arm_switch.is_visible = 1
        else
            MotorFields.arm_switch.is_visible = 0
        end
    end

    local result = runFieldsPage(MotorFields.page, event)
    return result
end

-- fields format : {[1]x, [2]y, [3]COMBO, [4]visible, [5]default, [6]{values}}
-- fields format : {[1]x, [2]y, [3]VALUE, [4]visible, [5]default, [6]min, [7]max}
local ElevronFields = {
    ail_ch_r     = {id='ail_ch_r'    , x=180, y=80 , w=0, type=COMBO, is_visible=1, value=defaultChannel_0_AIL  , avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail1 chan
    ail_ch_l     = {id='ail_ch_l'    , x=180, y=110, w=0, type=COMBO, is_visible=1, value=defaultChannel_0_AIL+1, avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail2 chan
    expo         = {id='expo'        , x=180, y=150, w=0, type=VALUE, is_visible=1, value=30, min=0, max=100 }  , -- expo
    is_dual_rate = {id='is_dual_rate', x=180, y=180, w=0, type=COMBO, is_visible=1, value=1                     , avail_values={ "No", "Yes" } },
    dr_switch    = {id='dr_switch'   , x=180, y=210, w=0, type=COMBO, is_visible=1, value=2                     , avail_values={ "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    page={}
}
ElevronFields.page = {
    ElevronFields.ail_ch_r,
    ElevronFields.ail_ch_l,
    ElevronFields.expo,
    ElevronFields.is_dual_rate,
    ElevronFields.dr_switch,
}
local ImgAilR
local ImgAilL

local function runElevronConfig(event)
    lcd.clear()
    if ImgAilR == nil then
        ImgAilR = bitmap.open("img/wing/rail.png")
        ImgAilL = bitmap.open("img/wing/lail.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgPlane, 230, 150)

    drawTitle("Elevron Setup")

    lcd.drawText(40, 50, "Ailerons channels", COLOR_THEME_PRIMARY1)

    lcd.drawText(40, 80, "Right Channel", COLOR_THEME_PRIMARY1)
    lcd.drawText(40, 110, "Left Channel", COLOR_THEME_PRIMARY1)

    lcd.drawText(40, 150, "Expo", COLOR_THEME_PRIMARY1)

    lcd.drawText(40, ElevronFields.is_dual_rate.y, "Dual-Rate?", COLOR_THEME_PRIMARY1)
    if ElevronFields.is_dual_rate.value == 1 then
        lcd.drawText(40, ElevronFields.is_dual_rate.y, "Dual-Rate?", COLOR_THEME_PRIMARY1)
        lcd.drawText(40, ElevronFields.dr_switch.y, "Dual-Rate switch", COLOR_THEME_PRIMARY1)
        ElevronFields.dr_switch.is_visible = 1
    else
        ElevronFields.dr_switch.is_visible = 0
    end

    local result = runFieldsPage(ElevronFields.page, event)
    return result
end

local lineIndex
local function drawNextLine(text, chNum, text2)
    lcd.drawText(40, lineIndex, text, COLOR_THEME_PRIMARY1)
    if chNum ~= nil then
        lcd.drawText(242, lineIndex, ": CH" .. chNum + 1, COLOR_THEME_PRIMARY1)
    else
        lcd.drawText(242, lineIndex, ": " .. text2, COLOR_THEME_PRIMARY1)
    end
    lineIndex = lineIndex + 20
end

local ImgSummary

local function runConfigSummary(event)
    lcd.clear()
    if ImgSummary == nil then
        ImgSummary = bitmap.open("img/summary.png")
    end

    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgSummary, 300, 60)

    drawTitle("Config Summary")

    lineIndex = 40

    -- ail
    drawNextLine("Ail/Ele Right channel", ElevronFields.ail_ch_r.value)
    drawNextLine("Ail/Ele Left channel", ElevronFields.ail_ch_l.value)
    drawNextLine("Expo", nil, ElevronFields.expo.value)

    -- motors
    if (MotorFields.is_motor.value == 1) then
        drawNextLine("Motor channel", MotorFields.motor_ch.value)
    end

    -- arm switch
    if (MotorFields.is_arm.value == 1) then
        local switchName = MotorFields.arm_switch.avail_values[1 + MotorFields.arm_switch.value]
        drawNextLine("Arm switch", nil, switchName)
    end

    drawNextLine("Dual Rate", nil, 
        ElevronFields.is_dual_rate.avail_values[1 + ElevronFields.is_dual_rate.value] ..
          (ElevronFields.is_dual_rate.value == 1 and
            " (" .. ElevronFields.dr_switch.avail_values[1 + ElevronFields.dr_switch.value] .. ")" or 
            "")
    )

    lcd.drawFilledRectangle(60-10, 250-2, 240, 25, YELLOW)
    lcd.drawText(60, 250, "Hold [Enter] to apply changes...", COLOR_THEME_PRIMARY1)

    if event == EVT_VIRTUAL_EXIT then
        -- exit script
        return 2
    end

    -- approve settings
    if (event == EVT_VIRTUAL_ENTER_LONG) then
        selectPage(1)
    end

    return 0
end

local function addMix(channel, input, name, weight, index)
    local mix = {
        source = input,
        name = name,
        --carryTrim= 0 -- 0=on
        --trimSource= 0 -- 0=on
    }
    if weight ~= nil then
        mix.weight = weight
    end
    if index == nil then
        index = 0
    end
    model.insertMix(channel, index, mix)
end

local function updateInputLine(channel, lineNo, expoWeight, weight, switch_name_position)
    local inInfo = model.getInput(channel, 0)

    -- expo
    inInfo.curveType = 1
    inInfo.curveValue = expoWeight
    inInfo.weight = weight
    inInfo.trimSource = 0 -- 0=on
    if (switch_name_position ~= nil) then
        local switchIndex = getSwitchIndex(switch_name_position)
        inInfo.switch = switchIndex
    end

    -- delete the old line
    model.deleteInput(channel, lineNo)
    model.insertInput(channel, lineNo, inInfo)
end

local function createModel(event)
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgSummary, 300, 60)
    model.defaultInputs()
    model.deleteInput(defaultChannel(STICK_NUMBER_RUD), 0) -- delete rudder
    model.deleteMixes()

    -- expo
    local expoVal = ElevronFields.expo.value
    local is_dual_rate = (ElevronFields.is_dual_rate.value == 1)
    local dr_switch = ElevronFields.dr_switch.avail_values[1 + ElevronFields.dr_switch.value]
    if (is_dual_rate) then
        updateInputLine(defaultChannel_0_AIL, 0, expoVal, 100, dr_switch .. CHAR_UP)
        updateInputLine(defaultChannel_0_AIL, 1, expoVal, 75 , dr_switch .. "-")
        updateInputLine(defaultChannel_0_AIL, 2, expoVal, 50 , dr_switch .. CHAR_DOWN)

        updateInputLine(defaultChannel_0_ELE, 0, expoVal, 100, dr_switch .. CHAR_UP)
        updateInputLine(defaultChannel_0_ELE, 1, expoVal, 75 , dr_switch .. "-")
        updateInputLine(defaultChannel_0_ELE, 2, expoVal, 50 , dr_switch .. CHAR_DOWN)
    else
        updateInputLine(defaultChannel_0_AIL, 0, expoVal, 100, nil)
        updateInputLine(defaultChannel_0_ELE, 0, expoVal, 100, nil)
    end

    -- motor
    if (MotorFields.is_motor.value == 1) then
        addMix(MotorFields.motor_ch.value, MIXSRC_FIRST_INPUT + defaultChannel_0_THR, "Motor")
    end

    -- ailerons
    addMix(ElevronFields.ail_ch_r.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-R", 50)
    addMix(ElevronFields.ail_ch_r.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "ail-R", -50)
    addMix(ElevronFields.ail_ch_l.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-L", 50)
    addMix(ElevronFields.ail_ch_l.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "ail-L", 50)

    -- SF arm switch
    if (MotorFields.is_arm.value == 1) then
        local switchName = MotorFields.arm_switch.avail_values[1 + MotorFields.arm_switch.value]
        local switchIndex = getSwitchIndex(switchName .. CHAR_DOWN)
        local channelIndex = MotorFields.motor_ch.value

        model.setCustomFunction(FUNC_OVERRIDE_CHANNEL, {
            switch = switchIndex,
            func = 0,
            value = -100,
            mode = 0,
            param = channelIndex, --"CH3"
            active = 1
        })
    end

    selectPage(1)
    return 0
end

local function onEnd(event)
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgSummary, 300, 60)

    lcd.drawText(70, 90, "Model successfully created !", COLOR_THEME_PRIMARY1)
    lcd.drawText(100, 130, "Hold [RTN] to exit.", COLOR_THEME_PRIMARY1)
    return 0
end

-- Init
local function init()
    current = 1
    is_edit = false
    pages = {
        runMotorConfig,
        runElevronConfig,
        runConfigSummary,
        createModel,
        onEnd
    }
end


-- Main
local function run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    elseif event == EVT_VIRTUAL_PREV_PAGE and page > 1 then
        killEvents(event);
        selectPage(-1)
    elseif event == EVT_VIRTUAL_NEXT_PAGE and page < #pages - 2 then
        selectPage(1)
    elseif event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
        selectPage(-1)
    elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
        if page ~= (#pages - 2) then
            selectPage(1)
        end
    end

    local result = pages[page](event)
    return result
end

return { init = init, run = run }

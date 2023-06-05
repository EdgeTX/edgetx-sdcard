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
-- Date: 2023
-- version: 1.0

local VALUE = 0
local COMBO = 1

local edit = false
local page = 1
local current = 1
local pages = {}

-- load common Bitmaps
local ImgMarkBg = Bitmap.open("img/mark_bg.png")
local BackgroundImg = Bitmap.open("img/background.png")
local ImgPlane = Bitmap.open("img/wing/plane.png")
local ImgPageUp = Bitmap.open("img/pageup.png")
local ImgPageDn = Bitmap.open("img/pagedn.png")

local STICK_NUMBER_AIL = 3
local STICK_NUMBER_ELE = 1
local STICK_NUMBER_THR = 2
local STICK_NUMBER_RUD = 0

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
    edit = false
    current = 1
    print(string.format("page: (%s)", page))

end

-- Select the next or previous editable field
local function selectField(fields, step)
    print(string.format("selectField-start: current: %s", current))
    repeat
        print(string.format("selectField: current: %s (vis: %s)", current, fields[current].is_visible))
        current = 1 + ((current + step - 1 + #fields) % #fields)
    until fields[current].is_visible == 1
    print(string.format("selectField-end: current: %s", current))
end

-- Redraw the current page
local function redrawFieldsPage(fields, event)

    for index = 1, 10, 1 do
        local field = fields[index]
        if field == nil then
            break
        end

        -- print(string.format("redrawFieldsPage [%s] field.x=%s, y=%s, is_visible=%s", field.id, field.x, field.y, field.is_visible))
        local attr = current == (index) and ((edit == true and BLINK or 0) + INVERS) or 0
        attr = attr + COLOR_THEME_PRIMARY1

        if field.is_visible == 1 then
            if field.type == VALUE then
                lcd.drawNumber(field.x, field.y, field.value, LEFT + attr)
            elseif field.type == COMBO then
                if field.value >= 0 and field.value < #(field.avail_values) then
                    lcd.drawText(field.x, field.y, field.avail_values[1 + field.value], attr)
                end
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
            edit = not edit
            if edit == false then
                updateField(fields[current])
            end
        end
    elseif edit then
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
    have_a_motor  = {id='have_a_motor' , x=170, y=50 , type=COMBO, is_visible=1, value=1                                , avail_values={ "No", "Yes" } },
    motor_channel = {id='motor_channel', x=170, y=80 , type=COMBO, is_visible=1, value=defaultChannel(STICK_NUMBER_THR) , avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } },
    is_arm_switch = {id='is_arm_switch', x=170, y=130, type=COMBO, is_visible=1, value=1                                , avail_values={ "No", "Yes" } },
    arm_channel   = {id='arm_channel'  , x=170, y=160, type=COMBO, is_visible=1, value=5                                , avail_values={ "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    page = {}
}
MotorFields.page = {
    MotorFields.have_a_motor,
    MotorFields.motor_channel,
    MotorFields.is_arm_switch,
    MotorFields.arm_channel
}

local ImgEngine

local function runMotorConfig(event)
    lcd.clear()
    if ImgEngine == nil then
        ImgEngine = Bitmap.open("img/wing/prop.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgEngine, 310, 50)

    drawTitle("Motor Settings")

    lcd.drawText(40, 50, "Have a motor?", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(160, 45, 60, 25, TEXT_BGCOLOR)
    print(string.format("111=%s", MotorFields.have_a_motor.x))

    MotorFields.motor_channel.is_visible = 0
    MotorFields.is_arm_switch.is_visible = 0
    MotorFields.arm_channel.is_visible = 0
    if MotorFields.have_a_motor.value == 1 then
        lcd.drawText(40, 80, "Motor channel", COLOR_THEME_PRIMARY1)
        lcd.drawFilledRectangle(160, 80, 60, 25, TEXT_BGCOLOR)
        MotorFields.motor_channel.is_visible = 1

        lcd.drawText(40, 130, "Arm switch?", COLOR_THEME_PRIMARY1)
        lcd.drawFilledRectangle(160, 130, 60, 25, TEXT_BGCOLOR)
        MotorFields.is_arm_switch.is_visible = 1
        MotorFields.arm_channel.is_visible = 0
        if MotorFields.is_arm_switch.value == 1 then
            lcd.drawText(40, 160, "Arm switch", COLOR_THEME_PRIMARY1)
            lcd.drawFilledRectangle(160, 160, 60, 25, TEXT_BGCOLOR)
            MotorFields.arm_channel.is_visible = 1
        end
    end

    local result = runFieldsPage(MotorFields.page, event)
    return result
end

-- fields format : {[1]x, [2]y, [3]COMBO, [4]visible, [5]default, [6]{values}}
-- fields format : {[1]x, [2]y, [3]VALUE, [4]visible, [5]default, [6]min, [7]max}
local ElevronFields = {
    ail_ch_r = {id='ail_ch_r', x=170, y=92 , type=COMBO, is_visible=1, value=defaultChannel(STICK_NUMBER_AIL)  , avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail1 chan
    ail_ch_l = {id='ail_ch_l', x=170, y=122, type=COMBO, is_visible=1, value=defaultChannel(STICK_NUMBER_AIL)+1, avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail2 chan
    expo = {name='expo', x=170,y=152, type=VALUE, is_visible=1, value=30, min=0, max=100 }, -- expo
    page={}
}
ElevronFields.page = {
    ElevronFields.ail_ch_r,
    ElevronFields.ail_ch_l,
    ElevronFields.expo,
}
local ImgAilR
local ImgAilL

local function runAilConfig(event)
    lcd.clear()
    if ImgAilR == nil then
        ImgAilR = Bitmap.open("img/wing/rail.png")
        ImgAilL = Bitmap.open("img/wing/lail.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgPlane, 230, 150)

    drawTitle("Aileron Setup")

    --lcd.drawBitmap(ImgAilR, 324, 123)
    --lcd.drawBitmap(ImgAilL, 275, 210)
    --drawMark(362, 132, "R")
    --drawMark(302, 227, "L")

    lcd.drawText(40, 60, "Ailerons channels", COLOR_THEME_PRIMARY1)

    lcd.drawFilledRectangle(160, 90, 60, 25, TEXT_BGCOLOR)
    lcd.drawText(40, 92, "Right Channel", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(160, 120, 60, 25, TEXT_BGCOLOR)
    lcd.drawText(40, 122, "Left Channel", COLOR_THEME_PRIMARY1)

    lcd.drawText(40, 150, "Expo", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(160, 150, 60, 25, TEXT_BGCOLOR)

    --print(string.format("defaultChannel(STICK_NUMBER_RUD)=%d", defaultChannel(STICK_NUMBER_RUD)))
    --print(string.format("defaultChannel(STICK_NUMBER_ELE)=%d", defaultChannel(STICK_NUMBER_ELE)))
    --print(string.format("defaultChannel(STICK_NUMBER_THR)=%d", defaultChannel(STICK_NUMBER_THR)))
    --print(string.format("defaultChannel(STICK_NUMBER_AIL)=%d", defaultChannel(STICK_NUMBER_AIL)))

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
    lineIndex = lineIndex + 22
end

local ConfigSummaryFields = {
    ack= {name='ack', x=110, y=250, type=COMBO, is_visible=1, value=0, avail_values={ "No, I need to change something", "Yes, all is well, create the plane !" } },
}
ConfigSummaryFields.page = {
    ConfigSummaryFields.ack
}

local ImgSummary

local function runConfigSummary(event)
    lcd.clear()
    if ImgSummary == nil then
        ImgSummary = Bitmap.open("img/summary.png")
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
    if (MotorFields.have_a_motor.value == 1) then
        drawNextLine("Motor channel", MotorFields.motor_channel.value)
    end

    -- arm switch
    if (MotorFields.is_arm_switch.value == 1) then
        local switchName = MotorFields.arm_channel.avail_values[1 + MotorFields.arm_channel.value]
        drawNextLine("Arm switch", nil, switchName)
    end

    local result = runFieldsPage(ConfigSummaryFields.page, event)

    if (ConfigSummaryFields.ack.value == 1 and edit == false) then
        selectPage(1)
    end
    return result
end

local function addMix(channel, input, name, weight, index)
    local mix = {
        source = input,
        name = name
    }
    if weight ~= nil then
        mix.weight = weight
    end
    if index == nil then
        index = 0
    end
    model.insertMix(channel, index, mix)
end

-- add expo
local function addExpo(channel, expoWeight)
    local inInfo = model.getInput(channel, 0)
    --print(string.format("curveType=%s", inInfo.curveType))
    --print(string.format("curveValue=%s", inInfo.curveValue))

    inInfo.curveType = 1
    inInfo.curveValue = expoWeight
    model.insertInput(channel, 0, inInfo)
    --print(string.format("curveType=%s", inInfo.curveType))
    --print(string.format("curveValue=%s", inInfo.curveValue))

    -- delete the old line
    model.deleteInput(channel, 1)
end

local function createModel(event)
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgSummary, 300, 60)
    model.defaultInputs()
    model.deleteInput(3, 0) -- delete rudder
    model.deleteMixes()

    -- expo
    addExpo(0, ElevronFields.expo.value)
    addExpo(1, ElevronFields.expo.value)

    -- motor
    if (MotorFields.have_a_motor.value == 1) then
        addMix(MotorFields.motor_channel.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_THR), "Motor")
    end

    -- Ailerons
    addMix(ElevronFields.ail_ch_r.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-R", 50)
    addMix(ElevronFields.ail_ch_r.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "ail-R", -50)
    addMix(ElevronFields.ail_ch_l.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-L", 50)
    addMix(ElevronFields.ail_ch_l.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "ail-L", 50)

    -- special function for arm switch
    local switchName = MotorFields.arm_channel.avail_values[1 + MotorFields.arm_channel.value]
    local switchIndex = getSwitchIndex(switchName .. CHAR_DOWN)
    local channelIndex = MotorFields.motor_channel.value

    model.setCustomFunction(FUNC_OVERRIDE_CHANNEL, {
        switch = switchIndex,
        func = 0,
        value = -100,
        mode = 0,
        param = channelIndex, --"CH3"
        active = 1
    })

    selectPage(1)
    return 0
end

local function onEnd(event)
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgSummary, 300, 60)

    lcd.drawText(70, 90, "Model successfully created !", COLOR_THEME_PRIMARY1)
    lcd.drawText(100, 130, "Press RTN to exit", COLOR_THEME_PRIMARY1)
    return 0
end

-- Init
local function init()
    current = 1
    edit = false
    pages = {
        runMotorConfig,
        runAilConfig,
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

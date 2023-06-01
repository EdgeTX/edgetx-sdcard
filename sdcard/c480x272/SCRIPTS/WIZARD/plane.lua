---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
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

-- Author: 3djc (2017)
-- Update by: Offer Shmuely (2023)
-- version: 2.0

local VALUE = 0
local COMBO = 1

local edit = false
local page = 1
local current = 1
local pages = {}

-- load common Bitmaps
local ImgMarkBg = Bitmap.open("img/mark_bg.png")
local BackgroundImg = Bitmap.open("img/background.png")
local ImgPlane = Bitmap.open("img/plane/plane.png")
local ImgPageUp = Bitmap.open("img/pageup.png")
local ImgPageDn = Bitmap.open("img/pagedn.png")

local COL_X = 1
local COL_Y = 2
local COL_TYPE = 3
local COL_VISIBLE = 4
local COL_VALUE = 5
local COL_VALUES = 6
local COL_MIN = 6
local COL_MAX = 7

local STICK_NUMBER_AIL = 3
local STICK_NUMBER_ELE = 1
local STICK_NUMBER_THR = 2
local STICK_NUMBER_RUD = 0

-- Change display attribute to current field
local function addField(fields, step)
    local field = fields[current]
    local min, max
    if field[COL_TYPE] == VALUE then
        min = field[COL_MIN]
        max = field[COL_MAX]
    elseif field[COL_TYPE] == COMBO then
        min = 0
        max = #(field[COL_VALUES]) - 1
    end
    if (step < 0 and field[COL_VALUE] > min) or (step > 0 and field[COL_VALUE] < max) then
        field[COL_VALUE] = field[COL_VALUE] + step
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
        print(string.format("selectField: current: %s (vis: %s)", current, fields[current][COL_VISIBLE]))
        current = 1 + ((current + step - 1 + #fields) % #fields)
    until fields[current][COL_VISIBLE] == 1
    print(string.format("selectField-end: current: %s", current))
end

-- Redraw the current page
local function redrawFieldsPage(fields, event)

    for index = 1, 10, 1 do
        local field = fields[index]
        if field == nil then
            break
        end

        local attr = current == (index) and ((edit == true and BLINK or 0) + INVERS) or 0
        attr = attr + COLOR_THEME_PRIMARY1

        if field[COL_VISIBLE] == 1 then
            if field[COL_TYPE] == VALUE then
                lcd.drawNumber(field[COL_X], field[COL_Y], field[COL_VALUE], LEFT + attr)
            elseif field[COL_TYPE] == COMBO then
                if field[COL_VALUE] >= 0 and field[COL_VALUE] < #(field[COL_VALUES]) then
                    lcd.drawText(field[COL_X], field[COL_Y], field[COL_VALUES][1 + field[COL_VALUE]], attr)
                end
            end
        end
    end
end

local function updateField(field)
    local value = field[COL_VALUE]
end

-- Main
local function runFieldsPage(fields, event)
    if event == EVT_VIRTUAL_EXIT then
        -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then
        -- toggle editing/selecting current field
        if fields[current][COL_VALUE] ~= nil then
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
        fields[cnt][COL_VISIBLE] = v
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
    { 170, 50, COMBO, 1, 1, { "No", "Yes" } },
    { 170, 80, COMBO, 1, defaultChannel(STICK_NUMBER_THR), { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } },
    { 170, 130, COMBO, 1, 1, { "No", "Yes" } },
    { 170, 160, COMBO, 1, 5, { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
}

local ImgEngine

local function runMotorConfig(event)
    lcd.clear()
    if ImgEngine == nil then
        ImgEngine = Bitmap.open("img/plane/prop.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgEngine, 310, 50)

    drawTitle("Motor Settings")

    lcd.drawText(40, 50, "Have a motor?", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(160, 45, 60, 25, TEXT_BGCOLOR)
    MotorFields[2][COL_VISIBLE] = 0
    MotorFields[3][COL_VISIBLE] = 0
    MotorFields[4][COL_VISIBLE] = 0
    if MotorFields[1][COL_VALUE] == 1 then
        lcd.drawText(40, 80, "Motor channel", COLOR_THEME_PRIMARY1)
        lcd.drawFilledRectangle(160, 80, 60, 25, TEXT_BGCOLOR)
        MotorFields[2][COL_VISIBLE] = 1

        lcd.drawText(40, 130, "Arm switch?", COLOR_THEME_PRIMARY1)
        lcd.drawFilledRectangle(160, 130, 60, 25, TEXT_BGCOLOR)
        MotorFields[3][COL_VISIBLE] = 1
        MotorFields[4][COL_VISIBLE] = 0
        if MotorFields[3][COL_VALUE] == 1 then
            lcd.drawText(40, 160, "Arm switch", COLOR_THEME_PRIMARY1)
            lcd.drawFilledRectangle(160, 160, 60, 25, TEXT_BGCOLOR)
            MotorFields[4][COL_VISIBLE] = 1
        end
    end

    local result = runFieldsPage(MotorFields, event)
    return result
end

-- fields format : {[1]x, [2]y, [3]COMBO, [4]visible, [5]default, [6]{values}}
-- fields format : {[1]x, [2]y, [3]VALUE, [4]visible, [5]default, [6]min, [7]max}
local AilFields = {
    { 50, 70, COMBO, 1, 2, { "None", "One (or two with Y cable)", "Two" } },
    { 50, 127, COMBO, 1, defaultChannel(3), { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail1 chan
    { 50, 167, COMBO, 1, 4, { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, -- Ail2 chan
}

local ImgAilR
local ImgAilL

local function runAilConfig(event)
    lcd.clear()
    if ImgAilR == nil then
        ImgAilR = Bitmap.open("img/plane/rail.png")
        ImgAilL = Bitmap.open("img/plane/lail.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgPlane, 252, 100)

    drawTitle("Aileron")

    if AilFields[1][COL_VALUE] == 1 then
        lcd.drawBitmap(ImgAilR, 324, 123)
        lcd.drawBitmap(ImgAilL, 275, 210)
        drawMark(362, 132, "A")
        drawMark(302, 227, "A")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        setFieldsVisible(AilFields, 1, 0)
    elseif AilFields[1][COL_VALUE] == 2 then
        lcd.drawBitmap(ImgAilR, 324, 123)
        lcd.drawBitmap(ImgAilL, 275, 210)
        drawMark(362, 132, "A")
        drawMark(302, 227, "B")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        lcd.drawFilledRectangle(40, 162, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 164, "B")
        setFieldsVisible(AilFields, 1, 1)
    else
        setFieldsVisible(AilFields, 0, 0)
    end
    lcd.drawText(40, 40, "Number of ailerons on your model ?", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(40, 65, 400, 30, TEXT_BGCOLOR)
    local result = runFieldsPage(AilFields, event)
    return result
end

local FlapsFields = {
    { 50, 70, COMBO, 1, 0, { "No", "Yes, on one channel", "Yes, on two channels" } },
    { 50, 127, COMBO, 1, 6, { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } },
    { 50, 167, COMBO, 1, 7, { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } },
}

local ImgFlp

local function runFlapsConfig(event)
    lcd.clear()
    if ImgFlp == nil then
        ImgFlp = Bitmap.open("img/plane/flap.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)
    lcd.drawBitmap(ImgPlane, 252, 100)

    drawTitle("Flaps")

    if FlapsFields[1][COL_VALUE] == 1 then
        lcd.drawBitmap(ImgFlp, 315, 143)
        lcd.drawBitmap(ImgFlp, 285, 191)
        drawMark(362, 132, "A")
        drawMark(302, 227, "A")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        setFieldsVisible(FlapsFields, 1, 0)
    elseif FlapsFields[1][COL_VALUE] == 2 then
        lcd.drawBitmap(ImgFlp, 315, 143)
        lcd.drawBitmap(ImgFlp, 285, 191)
        drawMark(362, 132, "A")
        drawMark(302, 227, "B")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        lcd.drawFilledRectangle(40, 162, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 164, "B")
        setFieldsVisible(FlapsFields, 1, 1)
    else
        setFieldsVisible(FlapsFields, 0, 0)
    end
    lcd.drawText(40, 40, "Does your model have flaps ?", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(40, 65, 400, 30, TEXT_BGCOLOR)
    local result = runFieldsPage(FlapsFields, event)
    return result
end

local TailFields = {
    { 50, 70, COMBO, 1, 1, { "1 channel for Elevator, no Rudder", "One channel for Elevator, one for Rudder", "Two channels for Elevator, one for Rudder", "V Tail" } },
    { 50, 127, COMBO, 1, defaultChannel(1), { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, --ele
    { 50, 167, COMBO, 1, defaultChannel(0), { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, --rud
    { 50, 207, COMBO, 0, 5, { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" } }, --ele2
}

local ImgTail
local ImgVTail
local ImgTailRud

local function runTailConfig(event)
    lcd.clear()
    if ImgTail == nil then
        ImgTail = Bitmap.open("img/plane/tail.png")
        ImgVTail = Bitmap.open("img/plane/vtail.png")
        ImgTailRud = Bitmap.open("img/plane/tail_rud.png")
    end
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)

    drawTitle("Tail Configuration")

    if TailFields[1][COL_VALUE] == 0 then
        lcd.drawBitmap(ImgTail, 252, 100)
        drawMark(275, 120, "A")
        drawMark(390, 155, "A")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        setFieldsVisible(TailFields, 1, 0, 0)
    end
    if TailFields[1][COL_VALUE] == 1 then
        lcd.drawBitmap(ImgTail, 252, 100)
        lcd.drawBitmap(ImgTailRud, 340, 100)
        drawMark(275, 120, "A")
        drawMark(390, 155, "A")
        drawMark(370, 112, "B")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        lcd.drawFilledRectangle(40, 162, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 164, "B")
        setFieldsVisible(TailFields, 1, 1, 0)
    end
    if TailFields[1][COL_VALUE] == 2 then
        lcd.drawBitmap(ImgTail, 252, 100)
        lcd.drawBitmap(ImgTailRud, 340, 100)
        drawMark(275, 120, "A")
        drawMark(390, 155, "C")
        drawMark(370, 112, "B")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        lcd.drawFilledRectangle(40, 162, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 164, "B")
        lcd.drawFilledRectangle(40, 202, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 204, "C")
        setFieldsVisible(TailFields, 1, 1, 1)
    end
    if TailFields[1][COL_VALUE] == 3 then
        lcd.drawBitmap(ImgVTail, 252, 100)
        drawMark(315, 110, "A")
        drawMark(382, 120, "B")
        lcd.drawFilledRectangle(40, 122, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 124, "A")
        lcd.drawFilledRectangle(40, 162, 100, 30, TEXT_BGCOLOR)
        drawMark(152, 164, "B")
        setFieldsVisible(TailFields, 1, 1, 0)
    end
    lcd.drawText(40, 40, "Pick the tail configuration", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(40, 65, 400, 30, TEXT_BGCOLOR)

    local result = runFieldsPage(TailFields, event)
    return result
end

local AdditionalSettingsFields = {
    --{ 170, 52, VALUE, 1, 30, 0, 100 }, -- model name
    { 170, 42, VALUE, 1, 30, 0, 100 }, -- expo
}

local function runAdditionalSettings(event)
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)
    lcd.drawBitmap(ImgPageUp, 0, 95)
    lcd.drawBitmap(ImgPageDn, 455, 95)

    drawTitle("Additional Settings")

    --lcd.drawText(40, 50, "Model Name", COLOR_THEME_PRIMARY1)
    --lcd.drawFilledRectangle(160, 50, 150, 25, TEXT_BGCOLOR)
    lcd.drawText(40, 40, "Expo", COLOR_THEME_PRIMARY1)
    lcd.drawFilledRectangle(160, 440, 60, 25, TEXT_BGCOLOR)

    local result = runFieldsPage(AdditionalSettingsFields, event)
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

local ConfigSummaryFields = {
    { 110, 250, COMBO, 1, 0, { "No, I need to change something", "Yes, all is well, create the plane !" } },
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

    -- motors
    if (MotorFields[1][COL_VALUE] == 1) then
        drawNextLine("Motor channel", MotorFields[2][COL_VALUE])
    end
    -- ail
    if (AilFields[1][COL_VALUE] == 1) then
        drawNextLine("Aileron channel", AilFields[2][COL_VALUE])
    elseif (AilFields[1][COL_VALUE] == 2) then
        drawNextLine("Aileron Right channel", AilFields[2][COL_VALUE])
        drawNextLine("Aileron Left channel", AilFields[3][COL_VALUE])
    end
    -- flaps
    if (FlapsFields[1][COL_VALUE] == 1) then
        drawNextLine("Flaps channel", FlapsFields[2][COL_VALUE])
    elseif (FlapsFields[1][COL_VALUE] == 2) then
        drawNextLine("Flaps Right channel", FlapsFields[2][COL_VALUE])
        drawNextLine("Flaps Left channel", FlapsFields[3][COL_VALUE])
    end
    -- tail
    if (TailFields[1][COL_VALUE] == 0) then
        drawNextLine("Elevator channel", TailFields[2][COL_VALUE])
    elseif (TailFields[1][COL_VALUE] == 1) then
        drawNextLine("Elevator channel", TailFields[2][COL_VALUE])
        drawNextLine("Rudder channel", TailFields[3][COL_VALUE])
    elseif (TailFields[1][COL_VALUE] == 2) then
        drawNextLine("Elevator Right channel", TailFields[2][COL_VALUE])
        drawNextLine("Rudder channel", TailFields[3][COL_VALUE])
        drawNextLine("Elevator Left channel", TailFields[4][COL_VALUE])
    elseif (TailFields[1][COL_VALUE] == 3) then
        drawNextLine("V-Tail Right", TailFields[2][COL_VALUE])
        drawNextLine("V-Tail Left", TailFields[3][COL_VALUE])
    end

    -- expo
    drawNextLine("Expo", nil, AdditionalSettingsFields[1][COL_VALUE])

    -- arm switch
    if (MotorFields[3][COL_VALUE] == 1) then
        local switchName = MotorFields[4][COL_VALUES][1 + MotorFields[4][COL_VALUE]]
        drawNextLine("Arm switch", nil, switchName)
    end

    local result = runFieldsPage(ConfigSummaryFields, event)
    if (ConfigSummaryFields[1][COL_VALUE] == 1 and edit == false) then
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
local function addExpo(channel, weight)
    local inInfo = model.getInput(channel, 0)
    --print(string.format("curveType=%s", inInfo.curveType))
    --print(string.format("curveValue=%s", inInfo.curveValue))

    inInfo.curveType = 1
    inInfo.curveValue = weight
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
    model.deleteMixes()

    -- expo
    addExpo(0, AdditionalSettingsFields[1][COL_VALUE])
    addExpo(1, AdditionalSettingsFields[1][COL_VALUE])
    addExpo(3, AdditionalSettingsFields[1][COL_VALUE])

    -- motor
    if (MotorFields[1][COL_VALUE] == 1) then
        addMix(MotorFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_THR), "Motor")
    end

    -- Ailerons
    if (AilFields[1][COL_VALUE] == 1) then
        addMix(AilFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(3), "Ail")
    elseif (AilFields[1][COL_VALUE] == 2) then
        addMix(AilFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(3), "AilR")
        addMix(AilFields[3][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(3), "AilL", -100)
    end
    -- Flaps
    if (FlapsFields[1][COL_VALUE] == 1) then
        addMix(FlapsFields[2][COL_VALUE], MIXSRC_SA, "Flaps")
    elseif (FlapsFields[1][COL_VALUE] == 2) then
        addMix(FlapsFields[2][COL_VALUE], MIXSRC_SA, "FlapsR")
        addMix(FlapsFields[3][COL_VALUE], MIXSRC_SA, "FlapsL")
    end
    -- Tail
    if (TailFields[1][COL_VALUE] == 0) then
        addMix(TailFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev")
    elseif (TailFields[1][COL_VALUE] == 1) then
        addMix(TailFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev")
        addMix(TailFields[3][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(0), "Rudder")
    elseif (TailFields[1][COL_VALUE] == 2) then
        addMix(TailFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "ElevR")
        addMix(TailFields[3][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(0), "Rudder")
        addMix(TailFields[4][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "ElevL")
    elseif (TailFields[1][COL_VALUE] == 3) then
        addMix(TailFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "V-EleR", 50)
        addMix(TailFields[2][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(0), "V-RudR", 50, 1)
        addMix(TailFields[3][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(1), "V-EleL", 50)
        addMix(TailFields[3][COL_VALUE], MIXSRC_FIRST_INPUT + defaultChannel(0), "V-RudL", -50, 1)
    end

    -- special function for arm switch
    local switchName = MotorFields[4][COL_VALUES][1 + MotorFields[4][COL_VALUE]]
    local switchIndex = getSwitchIndex(switchName .. CHAR_DOWN)
    local channelIndex = MotorFields[2][COL_VALUE]

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
        runFlapsConfig,
        runTailConfig,
        runAdditionalSettings,
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

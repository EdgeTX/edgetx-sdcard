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

chdir("/SCRIPTS/TOOLS/FrSky_S8R_S6R")

local VALUE = 0
local refreshState = 0
local refreshIndex = 0
local calibrationState = 0
local calibrationStep = 0
local modifications = {}
local calibrationPositions = { "up", "down", "left", "right", "forward", "back" }
local calibBitmaps = {}
local calibBitmapsFile = { "img/rx_up.png", "img/rx_down.png", "img/rx_left.png", "img/rx_right.png", "img/rx_forward.png", "img/rx_back.png" }
local telemetryPopTimeout = 0

local fields = {
    { "X", VALUE, 0x9E, 0, -100, 100, "%" },
    { "Y", VALUE, 0x9F, 0, -100, 100, "%" },
    { "Z", VALUE, 0xA0, 0, -100, 100, "%" }
}
local fields_needed_state = {
    --XXX   YYY   ZZZ
    {   0,    0,  100}, -- 1
    {   0,    0, -100}, -- 2
    { 100,    0,    0}, -- 3
    {-100,    0,    0}, -- 4
    {   0, -100,    0}, -- 5
    {   0,  100,    0}, -- 6
}

local function telemetryRead(field)
    return sportTelemetryPush(0x17, 0x30, 0x0C30, field)
end

local function telemetryWrite(field, value)
    return sportTelemetryPush(0x17, 0x31, 0x0C30, field + value * 256)
end

local function refreshNext()
    if refreshState == 0 then
        if calibrationState == 1 then
            if telemetryWrite(0x9D, calibrationStep) == true then
                refreshState = 1
                calibrationState = 2
                telemetryPopTimeout = getTime() + 80 -- normal delay is 500ms
            end
        elseif #modifications > 0 then
            -- telemetryWrite(modifications[1][1], modifications[1][2])
            -- modifications[1] = nil
        elseif refreshIndex < #fields then
            local field = fields[refreshIndex + 1]
            if telemetryRead(field[3]) == true then
                refreshState = 1
                telemetryPopTimeout = getTime() + 80 -- normal delay is 500ms
            end
        end
    elseif refreshState == 1 then
        local physicalId, primId, dataId, value = sportTelemetryPop()
        if physicalId == 0x1A and primId == 0x32 and dataId == 0x0C30 then
            local fieldId = value % 256
            if calibrationState == 2 then
                if fieldId == 0x9D then
                    refreshState = 0
                    calibrationState = 0
                    calibrationStep = (calibrationStep + 1) % 7
                end
            else
                local field = fields[refreshIndex + 1]
                if fieldId == field[3] then
                    local value = math.floor(value / 256)
                    value = bit32.band(value, 0xffff)
                    if field[3] >= 0x9E and field[3] <= 0xA0 then
                        local b1 = value % 256
                        local b2 = math.floor(value / 256)
                        value = b1 * 256 + b2
                        value = value - bit32.band(value, 0x8000) * 2
                    end
                    if field[2] == VALUE and #field == 8 then
                        value = value - field[8] + field[5]
                    end
                    fields[refreshIndex + 1][4] = value
                    refreshIndex = refreshIndex + 1
                    refreshState = 0
                end
            end
        elseif getTime() > telemetryPopTimeout then
            refreshState = 0
            calibrationState = 0
        end
    end
end

local function drawScreenTitle(title, page, pages)
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
    lcd.drawText(130, 5, title, MENU_TITLE_COLOR)
    lcd.drawText(LCD_W - 40, 5, page .. "/" .. pages, MENU_TITLE_COLOR)
end

local function refreshPage(event)
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("Frsky S8R/S6R RX Calibration", calibrationStep + 1, 7)

    if refreshIndex == #fields then
        refreshIndex = 0
    end

    if (calibrationStep < 6) then
        local position = calibrationPositions[1 + calibrationStep]
        lcd.drawText(50, 50, "Place the receiver in the following position", TEXT_COLOR)
        if calibBitmaps[calibrationStep + 1] == nil then
            calibBitmaps[calibrationStep + 1] = bitmap.open(calibBitmapsFile[calibrationStep + 1])
        end

        lcd.drawBitmap(calibBitmaps[calibrationStep + 1], 40, 70, 150)
        local is_all_v_align = true
        for index = 1, 3, 1 do
            local field = fields[index]
            local v_current = field[4] / 10
            local v_expected = fields_needed_state[calibrationStep+1][index]
            local v_diff = math.abs(v_current - v_expected)

            local bg_color
            if (v_diff < 10) then
                bg_color = GREEN
            else
                bg_color = RED
                is_all_v_align = false
            end

            local mark_w_half = 10
            local mark_w = mark_w_half * 2
            local prog_w = 80
            local prog_m = 380

            if v_current > 0 then
                v_current = math.ceil(v_current)
                v_current = math.min(v_current,100)
            else
                v_current = math.floor(v_current)
                v_current = math.max(v_current,-100)
            end
            local x_pos = (v_current/100) * prog_w
            local x_pos_expected = (v_expected/100) * prog_w

            -- values
            lcd.drawText(240, 80 + 25 * index, field[1] .. ":" .. v_current, TEXT_COLOR)
            -- background rect
            lcd.drawRectangle(prog_m - prog_w - mark_w_half, 80 + 25 * index - 0, prog_w*2+ mark_w_half *2, 18, BLACK);
            -- expected pos
            lcd.drawFilledRectangle(prog_m + x_pos_expected - mark_w_half +1, 80 + 25 * index - 0 +1, mark_w -2, 18 -2, LIGHTGREY);
            -- current pos (+ shade)
            lcd.drawFilledRectangle(prog_m + x_pos - mark_w_half +1 +2, 80 + 25 * index - 0 +1 +2, mark_w -4, 18 -4, GREY);
            lcd.drawFilledRectangle(prog_m + x_pos - mark_w_half    +2, 80 + 25 * index - 0    +2, mark_w -4, 18 -4, bg_color);
            -- middle mark
            lcd.drawFilledRectangle(prog_m -1, 80 + 25 * index - 0, 2, 18, BLACK);
        end

        if (is_all_v_align) then
            if calibrationState == 0 then
                lcd.drawFilledRectangle(150, 225, 200, 30, GREEN);
            else
                lcd.drawFilledRectangle(150, 225, 200, 30, ORANGE);
            end
            lcd.drawText(160, 230, "Ready! press [Enter]")
        else
            lcd.drawFilledRectangle(150, 225, 215, 30, BLACK);
            lcd.drawText(160, 230, "Press [Enter] when 3 greens", WHITE)
        end
    else
        lcd.drawText(160, 50, "Calibration completed", 0)
        lcd.drawBitmap(bitmap.open("img/done.bmp"), 200, 100)
        lcd.drawBitmap(bitmap.open("img/done.png"), 310, 60)
        lcd.drawText(160, 220, "Hold [RTN] to exit", attr)
    end
    if calibrationStep > 6 and (event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT) then
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

local function init()
    refreshState = 0
    refreshIndex = 0
end

-- Main
local function run(event)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    elseif event == EVT_VIRTUAL_NEXT_PAGE then
        --selectPage(1)
        refreshIndex = 0
        calibrationStep = 0
    elseif event == EVT_VIRTUAL_PREV_PAGE then
        killEvents(event);
        --selectPage(-1)
        refreshIndex = 0
        calibrationStep = 0
    end

    local result = refreshPage(event)
    refreshNext()
    --lcd.drawText(10, 220, "refreshState: " .. refreshState, GREY + SMLSIZE)
    --lcd.drawText(10, 240, "calibrationState: " .. calibrationState, GREY + SMLSIZE)

    return result
end

return { init = init, run = run }

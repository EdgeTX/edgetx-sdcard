---- TNS|Model Locator by RSSI|TNE
---- #########################################################################
---- #                                                                       #
---- # Telemetry Widget script for FrSky Horus/Radio Master TX16s            #
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

-- Model Locator by RSSI
-- Offer Shmuely (based on code from Scott Bauer 6/21/2015)
-- Date: 2022-2025
local app_ver = "1.10"

-- This widget help to find a lost/crashed model based on the RSSI (if still available)
-- The widget produce audio representation (vario-meter style) of the RSSI from the lost model
-- The widget also  display the RSSI in a visible colorized bar (0-100%)

-- There are two way to use it
-- 1. The simple way:
--    walk toward the quad/plane that crashed,
--    as you get closer to your model the beeps will become more frequent with higher pitch (and a visual bar graph as well)
--    until you get close enough to find it visually

-- 2. the more accurate way:
--    turn the antenna straight away (i.e. to point from you, straight away)
--    try to find the weakest signal! (not the highest), i.e. the lowest RSSI you can find, this is the direction to the model.
--    now walk to the side (not toward the model), find again the weakest signal, this is also the direction to your model
--    triangulate the two lines, and it will be :-)

local delayMillis = 100
local targetTXPower1 = 10
local targetTXPower2 = 25
local nextPlayTime = getTime()

local script_folder = "/SCRIPTS/TOOLS/locator_by_rssi"

local signalValue, signalMin, signalMax, txPower
local signalPercent = 0
local signalPercentColor = GREY
local is_elrs = false
local is_beep = true
local useHaptic = false
local signalType = 1 -- 1=no-signal, 2=RSSI, 3=1RSS, 4=2RSS

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

--------------------------------------------------------------
local function log(fmt, ...)
    print("[locator] ".. string.format(fmt, ...))
end
--------------------------------------------------------------

-- This function returns green at gvalue, red at rvalue and graduate in between
local function getRangeColor(value, red_value, green_value)
    local range = math.abs(green_value - red_value)
    if range == 0 then
        return lcd.RGB(0, 0xdf, 0)
    end
    if value == nil then
        return lcd.RGB(0, 0xdf, 0)
    end

    if green_value > red_value then
        if value > green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value < red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        g = math.floor(0xdf * (value - red_value) / range)
        r = 0xdf - g
        return lcd.RGB(r, g, 0)
    else
        if value > green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value < red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        r = math.floor(0xdf * (value - green_value) / range)
        g = 0xdf - r
        return lcd.RGB(r, g, 0)
    end
end

local function detectSignalType()
    -- try regular Frsky RSSI
    local fieldinfoRssi = getFieldInfo("RSSI")
    if fieldinfoRssi ~= nil then
        is_elrs = false
        signalType = 2 -- RSSI
        return
    end

    -- try expressLRS
    -- try to get transmitter power
    local txPowerFieldTpwr = getFieldInfo("TPWR")
    if txPowerFieldTpwr == nil  then
        is_elrs = false
        signalType = 1
        return
    end

    local fieldinfo1 = getFieldInfo("1RSS")
    if fieldinfo1 ~= nil then
        is_elrs = true
        signalType = 3 -- 1RSS
        return
    end

    local fieldinfo2 = getFieldInfo("2RSS")
    if fieldinfo2 ~= nil then
        is_elrs = true
        signalType = 4 -- 2RSS
        return
    end

    is_elrs = false
    signalType = 1 -- no signal
    return
end


local function updateSignalValues()
    if signalType == 1 then
        detectSignalType()
    end

    if signalType == 1 then
        is_elrs = false
        signalValue = nil
        signalMin = 0
        signalMax = 0
        txPower = nil
        return
    end

    -- Frsky RSSI
    if signalType == 2 then
        local fieldinfo = getFieldInfo("RSSI")
        if fieldinfo then
            local v = getValue("RSSI")
            log("RSSI: " .. v)
            signalType = 2 -- RSSI
            signalValue = v
            signalMin = 0
            signalMax = 100
            txPower = nil
            return
        end
    end

    -- expressLRS
    if is_elrs == true then
        -- try to get transmitter power
        local txPowerField = getFieldInfo("TPWR")
        if txPowerField then
            txPower = getValue("TPWR")
        end

    end

    local fieldinfo = nil
    local v = nil
    if signalType == 3 then
        v = getValue("1RSS")
    end

    if signalType == 4 then
        v = getValue("2RSS")
    end

    if v == 0 then
        v = -115
    end

    signalValue = v
    signalMin = -115
    signalMax = -20
    signalValue = math.max(signalValue, signalMin)
    signalValue = math.min(signalValue, signalMax)
    return

end

-- init_func is called once when model is loaded
local function build_ui()
    log("build_ui()")

    lvgl.clear()

    lvgl.build({

        -- background
        {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x1F1F1F), filled=true},

        -- draw top-bar
        {type="rectangle", x=0, y=0, w=LCD_W, h=30, color=DARKBLUE, filled=true},
        {type="label", x=40, y=3, text="Model Locator by RSSI/1RSS", color=WHITE, font=FS.FONT_8},
        {type="label", x=LCD_W - 50, y=3, text="ver: " .. app_ver, color=LIGHTGREY, font=FS.FONT_6},
        {type="hline", x=0, y=30, w=LCD_W-1, h=1, color=WHITE, opacity=50, filled=true},

        -- signal exist
        {type="box", x=0, y=30,
            children={
                -- {type="image", x=0,y=0,w=LCD_W,h=LCD_H-30, fill=true, file=script_folder.."/locator2.png"},

                -- draw gauge bar
                {type="arc", x=350, y=120,
                    radius=110, thickness=28,
                    startAngle=120, endAngle=function() return 120+(300*signalPercent/100) end, opacity=255,
                    bgStartAngle=120, bgEndAngle=60, bgColor=GREY, bgOpacity=155,
                    color=function() return signalPercentColor end,
                    rounded=false
                },

                -- draw current value
                {type="label", x=310, y=80,
                    text=function() return signalPercent end,
                    -- color=function() return signalPercentColor or GREY end,
                    color=WHITE,
                    font=FS.FONT_38
                },
                {type="label", x=340, y=140,
                    text="%",
                    color=WHITE,
                    font=FS.FONT_16
                },

                -- {type="label", x=10 , y=LCD_H-22, text=function() return line1 or "" end, color=WHITE, font=FS.FONT_8},
                {type="label", x=10 , y=20, text="Signal Type:", color=WHITE, font=FS.FONT_8},

                { type = "choice", x=120, y=15, w=130, title = "Telemetry",
                    values = {"---", "Frsky RSSI", "elrs Anntena 1", "elrs Anntena 2"},
                    get = function() return signalType end,
                    set = function(i)
                        signalType = i
                    end ,
                },

                -- beep button
                {type="label", x=20, y=65, text="Beep:", color=WHITE, font=FS.FONT_8},
                {type="toggle", x=80, y=60,
                    get=(function() return is_beep end),
                    set=(function(val) is_beep = (val==1) end)
                },
                -- haptic
                {type="label", x=20, y=105, text="Haptic:", color=WHITE, font=FS.FONT_8},
                {type="toggle", x=80, y=100,
                    get=(function() return useHaptic end),
                    set=(function(val) useHaptic = (val==1) end)
                },

                -- draw raw  value
                {type="label", x=10, y=140,
                    text=function() return "Raw value: " .. tostring(signalValue) .. "db" end,
                    -- color=function() return signalPercentColor or GREY end,
                    color=LIGHTGREY,
                    font=FS.FONT_8
                },

                -- tx power
                {type="label", x=10, y=160,
                    text=function() return "TX Power: " .. tostring(txPower) .. "mW" end,
                    -- color=function() return ((txPower == targetTXPower1)or(txPower == targetTXPower2)) and DARKGREEN or RED end,
                    color=LIGHTGREY,
                    font=FS.FONT_8
                },

                {type="box", x=50, y=180,
                    children={
                        {type="label", x=0, y=0, text="!! Set TX Power to 25mW", color=RED, font=FS.FONT_8},
                        {type="label", x=0, y=20,text="!! Set TX Dynamic=OFF",color=RED,font=FS.FONT_8},
                    },
                    visible=function()
                        return is_elrs==true and txPower ~= targetTXPower1 and txPower ~= targetTXPower2
                    end,
                },
            },
            visible=function()
                return getRSSI() ~= 0
            end
        },

        -- no signal
        {type="box", x=0, y=30,
            children={
                {type="image", x=0,y=0,w=LCD_W,h=LCD_H-30, fill=true, file=script_folder.."/locator1.png"},
                -- {type="rectangle", x=20, y=30+20, w=LCD_W-20*2, h=LCD_H-30-20*2, color=GREY, filled=true, opacity=230},
                {type="label", x=50, y=170, text="No signal found \nwaiting for: RSSI/1RSS/2RSS", color=RED, font=FS.FONT_12},
            },
            visible=function()
                return getRSSI() == 0
            end
        },
    })

    return 0
end

-- init_func is called once when model is loaded
local function init()
    log("init()")
    build_ui()
    return 0
end


local function main(event, touchState)

    updateSignalValues()

    -- log("signalValue: %s, signalMin: %s, signalMax: %s, txPower: %s", signalValue, signalMin, signalMax, txPower)
    -- log("getRSSI(): %s", getRSSI())

    signalPercent = math.floor(100 * ((signalValue - signalMin) / (signalMax - signalMin)))
    signalPercentColor = getRangeColor(signalPercent, 0, 100)
    -- log("signalPercent: %s, signalPercentColor: %s", signalPercent, signalPercentColor)
    -- log("signalValue: %s, signalMin: %s, signalMax: %s, txPower: %s, line1: %s", signalValue, signalMin, signalMax, txPower, line1)
    -- -- log(signalValue)

    -- beep
    if getRSSI() ~= 0 and getTime() >= nextPlayTime then
        log("is_beep: %s, useHaptic: %s", is_beep, useHaptic)
        if is_beep == true then
            playFile(script_folder .. "/locator.wav")
        end
        if useHaptic == true then
            playHaptic(7, 0, 1)
        end
        nextPlayTime = getTime() + delayMillis - signalPercent
    end

    return 0
end

return { init=init, run=main }


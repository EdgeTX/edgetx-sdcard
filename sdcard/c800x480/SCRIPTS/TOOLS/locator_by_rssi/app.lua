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
-- Date: 2022-2026
local app_ver = "1.11"

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

local SIGNAL_NONE = 1
local SIGNAL_RSSI = 2
local SIGNAL_1RSS = 3
local SIGNAL_2RSS = 4
local signalType = SIGNAL_NONE


-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}
local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

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
        signalType = SIGNAL_RSSI
        return
    end

    -- try expressLRS

    -- try to get transmitter power
    local txPowerFieldTpwr = getFieldInfo("TPWR")
    if txPowerFieldTpwr == nil  then
        signalType = SIGNAL_NONE
        return
    end

    local fieldinfo1 = getFieldInfo("1RSS")
    if fieldinfo1 ~= nil then
        signalType = SIGNAL_1RSS
        return
    end

    local fieldinfo2 = getFieldInfo("2RSS")
    if fieldinfo2 ~= nil then
        signalType = SIGNAL_2RSS
        return
    end

    signalType = SIGNAL_NONE -- no signal
    return
end


local function updateSignalValues()
    if signalType == SIGNAL_NONE then
        signalValue = 1
        detectSignalType()
    end

    if signalType == SIGNAL_NONE then
        is_elrs = false
        signalValue = nil
        signalMin = 0
        signalMax = 0
        txPower = nil
        return
    end

    -- Frsky RSSI
    if signalType == SIGNAL_RSSI then
        local fieldinfo = getFieldInfo("RSSI")
        is_elrs = false
        signalMin = 0
        signalMax = 100
        txPower = nil
        if fieldinfo then
            local v = getValue("RSSI")
            log("RSSI: " .. v)
            signalValue = v
        else
            signalValue = 0
        end
        return
    end

    -- expressLRS
    is_elrs = true
    signalMin = -115
    signalMax = -20

    -- try to get transmitter power
    local txPowerField = getFieldInfo("TPWR")
    if txPowerField then
        txPower = getValue("TPWR")
    else
        txPower = nil
    end

    local fieldinfo = nil
    local v = nil
    if signalType == SIGNAL_1RSS then
        v = getValue("1RSS")
        log("1RSS: " .. v)
    end

    if signalType == SIGNAL_2RSS then
        v = getValue("2RSS")
        log("2RSS: " .. v)
    end

    if v == 0 then
        v = signalMin
    end

    signalValue = v
    signalValue = math.max(signalValue, signalMin)
    signalValue = math.min(signalValue, signalMax)
    return

end

-- init_func is called once when model is loaded
local function build_ui()
    -- log("build_ui()")

    lvgl.clear()
    lvgl.build({

        -- background
        {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x1F1F1F), filled=true},

        -- draw top-bar
        {type="rectangle", x=0, y=0, w=LCD_W, h=30*lvSCALE, color=DARKBLUE, filled=true},
        {type="label", x=40*lvSCALE, y=3*lvSCALE, text="Model Locator by RSSI/1RSS", color=WHITE, font=FS.FONT_8},
        {type="label", x=LCD_W - 50*lvSCALE, y=3*lvSCALE, text="ver: " .. app_ver, color=LIGHTGREY, font=FS.FONT_6},
        -- {type="hline", x=0, y=30, w=LCD_W-1, h=1, color=WHITE, opacity=50, filled=true},

        -- signal exist
        {type="box", x=0, y=30*lvSCALE,
            children={
                -- {type="image", x=0,y=0,w=LCD_W,h=LCD_H-30, fill=true, file=script_folder.."/locator2.png"},

                -- draw gauge bar
                {type="arc", x=350*lvSCALE, y=120*lvSCALE,
                    radius=110*lvSCALE, thickness=28*lvSCALE,
                    startAngle=120, endAngle=function() return 120+(300*signalPercent/100) end, opacity=255,
                    bgStartAngle=120, bgEndAngle=60, bgColor=GREY, bgOpacity=155,
                    color=function() return signalPercentColor end,
                    rounded=false
                },
                -- draw current value
                {type="label", x=310*lvSCALE, y=80*lvSCALE, color=WHITE, font=FS.FONT_38,
                    text=function() return signalPercent end,
                },
                {type="label", x=340*lvSCALE, y=140*lvSCALE, color=WHITE, font=FS.FONT_16,
                    text="%",
                },


                -- draw settings
                {type="label", x=10*lvSCALE , y=20*lvSCALE, color=WHITE, font=FS.FONT_8,
                    text="Signal Type:",
                },
                { type="choice", x=120*lvSCALE, y=15*lvSCALE, w=130*lvSCALE, title = "Telemetry",
                    values = {"-- Auto Detect --", "Frsky RSSI", "elrs Antenna 1", "elrs Antenna 2"},
                    get = function() return signalType end,
                    set = function(i)
                        signalType = i
                        is_elrs = (signalType == 3 or signalType == 4) and true or false
                    end,
                },

                -- beep button
                {type="label", x=20*lvSCALE, y=65*lvSCALE, text="Beep:", color=WHITE, font=FS.FONT_8},
                {type="toggle", x=80*lvSCALE, y=60*lvSCALE,
                    get=(function() return is_beep end),
                    set=(function(val) is_beep = (val==1) end)
                },
                -- haptic
                {type="label", x=20*lvSCALE, y=105*lvSCALE, text="Haptic:", color=WHITE, font=FS.FONT_8},
                {type="toggle", x=80*lvSCALE, y=100*lvSCALE,
                    get=(function() return useHaptic end),
                    set=(function(val) useHaptic = (val==1) end)
                },

                -- draw raw  value
                {type="label", x=10*lvSCALE, y=140*lvSCALE,
                    text=function() return "Raw value: " .. tostring(signalValue) .. "db" end,
                    color=LIGHTGREY,
                    font=FS.FONT_8
                },

                -- tx power
                {type="label", x=10*lvSCALE, y=160*lvSCALE,
                    text=function()
                        if txPower == nil then
                            txPower = "N/A "
                        end
                        return "TX Power: " .. tostring(txPower) .. "mW"
                    end,
                    -- color=function() return ((txPower == targetTXPower1)or(txPower == targetTXPower2)) and DARKGREEN or RED end,
                    color=LIGHTGREY,
                    font=FS.FONT_8,
                    visible=function()
                        return is_elrs==true
                    end,

                },

                {type="box", x=50*lvSCALE, y=180*lvSCALE,
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
        {type="box", x=0, y=30*lvSCALE,
            children={
                {type="image", x=0,y=0,w=LCD_W,h=LCD_H-30*lvSCALE, fill=true, file=script_folder.."/locator1.png"},
                -- {type="rectangle", x=20*lvSCALE, y=30*lvSCALE+20*lvSCALE, w=LCD_W-20*2*lvSCALE, h=LCD_H-30*lvSCALE-20*2*lvSCALE, color=GREY, filled=true, opacity=230},
                {type="label", x=50*lvSCALE, y=170*lvSCALE, text="No signal found \nwaiting for: RSSI/1RSS/2RSS", color=RED, font=FS.FONT_12},
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

    log("signalValue: %s, signalMin: %s, signalMax: %s, txPower: %s", signalValue, signalMin, signalMax, txPower)
    -- log("getRSSI(): %s", getRSSI())

    signalPercent = math.floor(100 * ((signalValue - signalMin) / (signalMax - signalMin)))
    signalPercentColor = getRangeColor(signalPercent, 0, 100)
    log("signalPercent: %s, signalPercentColor: %s", signalPercent, signalPercentColor)
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


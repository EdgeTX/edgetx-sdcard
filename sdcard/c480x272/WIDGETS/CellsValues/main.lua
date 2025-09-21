--
-- Copyright (C) EdgeTX
--
-- Based on code named
--   opentx - https://github.com/opentx/opentx
--   th9x - http://code.google.com/p/th9x
--   er9x - http://code.google.com/p/er9x
--   gruvin9x - http://code.google.com/p/gruvin9x
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 2 as
-- published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--

local name = "Cells Values"
local cellsT = {}
local T
-- When the difference between the lowest and highest cell exceeds 0.1,
-- the delta value is then displayed in red
local deltawarning = 0

-- Create a table with default options
-- Options can be changed by the user from the Widget Settings menu
-- Notice that each line is a table inside { }
local options = {
    { "sensor", SOURCE, getSourceIndex(CHAR_TELEMETRY.."Cels") },
    { "battchemistry", CHOICE, 1 , {"LiPo", "LiPo-HV (high voltage)"} },
    { "circlecolor", COLOR, COLOR_THEME_PRIMARY2},
    { "circletext", COLOR, COLOR_THEME_PRIMARY1},
    { "textcolor", COLOR, COLOR_THEME_PRIMARY1},
    { "textalarmcolor", COLOR, COLOR_THEME_WARNING},

}

local function translate(nam)
    local translations = {
        sensor = "Cells sensor",
        circlecolor = "Circle color",
        circletext = "Circle text color",
        textcolor = "Text color",
        textalarmcolor = "Cell alarm color",
        battchemistry="Battery Type",
    }
    return translations[nam]
end


function getColorGradient(value)
    -- Clamp input to 0-100 range
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end

    local r, g, b

    if value <= 50 then
        -- Transition from red (255,0,0) to yellow (255,255,0)
        -- Red stays at 255, green increases from 0 to 255
        r = 255
        g = math.floor((value / 50) * 255)
        b = 0
    else
        -- Transition from yellow (255,255,0) to green (0,255,0)
        -- Red decreases from 255 to 0, green stays at 255
        r = math.floor(((100 - value) / 50) * 255)
        g = 255
        b = 0
    end

    return lcd.RGB(r,g,b)
end

local function getfontHeight(flags)
    local w,h = lcd.sizeText("1", flags)
    return h
end

local function getBoxOffset(flags)
    local w,h = lcd.sizeText("3.99", flags)
    return w
end

local function getCellCount(T)
    if type(T) == "table" then
        return math.max(#T, 0)
    else
        return 0
    end
end

local function getCellMinMax(T)
    if type(T) == "table" and #T > 0 then
        local min, max = T[1], T[1]
        for i=1, #T, 1 do
            local v = T[i]
            if v and v < min then min = v end
            if v and v > max then max = v end
        end
        return min, max
    else
        return 0, 0
    end
end

local function getCellTotal(T)
    if type(T) == "table" then
        local cellsum = 0
        for i=1, #T, 1 do
            if T[i] then
                cellsum = cellsum + T[i]
            end
        end
        return cellsum
    else
        return 0
    end
end

local function getCellPercent(cellvalue)
    if not cellvalue or cellvalue <= 0 then
        return 0
    end

    local lastpercentage = 0

    for i=1, #cellsT do
        for j=1, #cellsT[i] do
            if cellvalue >= cellsT[i][j][1] then
                lastpercentage = cellsT[i][j][2]
            else
                return lastpercentage
            end
        end
    end
    return 100
end

local function getCellTotalPercent(T)
    local count = getCellCount(T)
    if count == 0 then return 0 end

    local cellaverage = getCellTotal(T) / count
    local lastpercentage = 0

    for i=1, #cellsT do
        for j=1, #cellsT[i] do
            if cellaverage >= cellsT[i][j][1] then
                lastpercentage = cellsT[i][j][2]
            else
                return lastpercentage
            end
        end
    end
    return 100
end

local function getCellText(T, index)
    if type(T) == "table" and T[index] and index <= #T then
        return string.format("%1.2f", T[index])
    else
        return "??"
    end
end

local function getTotalText(T)
    return string.format("T:%2.2f V",  getCellTotal(T))
end

local function getDeltaText(T)
    local min, max = getCellMinMax(T)
    if max - min > 0.1 then
        deltawarning = 1
    else
        deltawarning = 0
    end
    return string.format("D:%0.2f V", max - min)
end

local function getSingleCellPercentage(T, index)
    if type(T) == "table" and T[index] then
        local value = T[index]
        return getCellPercent(value)
    else
        return 0
    end
end

local function doLayout(widget)
    T = getValue(widget.options.sensor)

    -- Safety check: ensure T is a valid table
    if T == nil or type(T) ~= "table" then
        T = {}
    end

    if lvgl == nil then return end

    lvgl.clear()

    local zw = widget.zone.w
    local th = getfontHeight()
    local rd = th/2
    local bh = 10
    local bx = getBoxOffset()+3

    local lyt = {
        {type="label", text="No Cells sensor", color=COLOR_THEME_WARNING, visible=function() return getCellCount(T) == 0 end, w=zw, align=CENTER|VCENTER},
        {type="box", w=zw, h=widget.zone.h, visible=function() return getCellCount(T) > 0 end,
         children={
             {type="circle", x=rd, y=rd, radius=rd, filled=true, color=widget.options.circlecolor, children={{type="label", text="1", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 1) end, x=2*rd+3, y=0, font=SMALLSIZE, color=widget.options.textcolor},
             {type ="rectangle", x=2*rd+3+bx, y=(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 1)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 1)) end },
             {type ="rectangle", x=2*rd+3+bx, y=(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY },

             {type="circle", x=zw/2+rd, y=rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 1 end, children={{type="label", text="2", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 2) end, x=zw/2+2*rd+3, y=0, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 1 end},
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 2)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 2)) end, visible=function() return getCellCount(T) > 1 end },
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 1 end },

             {type="circle", x=rd, y=th+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 2 end, children={{type="label", text="3", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 3) end, x=2*rd+3, y=th, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 2 end},
             {type ="rectangle", x=2*rd+3+bx, y=th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 3)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 3)) end, visible=function() return getCellCount(T) > 2 end },
             {type ="rectangle", x=2*rd+3+bx, y=th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 2 end },

             {type="circle", x=zw/2+rd, y=th+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 3 end, children={{type="label", text="4", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 4) end, x=zw/2+2*rd+3, y=th, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 3 end},
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 4)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 4)) end, visible=function() return getCellCount(T) > 3 end },
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 3 end },

             {type="circle", x=rd, y=th*2+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 4 end, children={{type="label", text="5", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 5) end, x=2*rd+3, y=th*2, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 4 end},
             {type ="rectangle", x=2*rd+3+bx, y=2*th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 5)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 5)) end, visible=function() return getCellCount(T) > 4 end },
             {type ="rectangle", x=2*rd+3+bx, y=2*th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 4 end },

             {type="circle", x=zw/2+rd, y=th*2+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 5 end, children={{type="label", text="6", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 6) end, x=zw/2+2*rd+3, y=th*2, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 5 end},
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=2*th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 6)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 6)) end, visible=function() return getCellCount(T) > 5 end },
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=2*th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 5 end },

             {type="circle", x=rd, y=th*3+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 6 end, children={{type="label", text="7", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 7) end, x=2*rd+3, y=th*3, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 6 end},
             {type ="rectangle", x=2*rd+3+bx, y=3*th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 7)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 7)) end, visible=function() return getCellCount(T) > 6 end },
             {type ="rectangle", x=2*rd+3+bx, y=3*th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 6 end },

             {type="circle", x=zw/2+rd, y=th*3+rd, radius=rd, filled=true, color=widget.options.circlecolor, visible=function() return getCellCount(T) > 7 end, children={{type="label", text="8", x=rd/2, y=0, color=widget.options.circletext}}},
             {type="label", text=function() return getCellText(T, 8) end, x=zw/2+2*rd+3, y=th*3, font=SMALLSIZE, color=widget.options.textcolor, visible=function() return getCellCount(T) > 7 end},
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=3*th+(th-bh)/2, size = function() return zw/5*getSingleCellPercentage(T, 8)/100, bh end, filled=true, color=function() return getColorGradient(getSingleCellPercentage(T, 8)) end, visible=function() return getCellCount(T) > 7 end },
             {type ="rectangle", x=zw/2+2*rd+3+bx, y=3*th+(th-bh)/2, h=bh, w=zw/5, filled=false, color=GREY, visible=function() return getCellCount(T) > 7 end },

             {type="label", text=function() return string.format("%d %%", getCellTotalPercent(T)) end, pos=function() return 0, math.ceil(getCellCount(T) / 2) * th end, font=SMALLSIZE, color=widget.options.textcolor},
             {type="label", text=function() return getTotalText(T) end, pos=function() return zw/4, math.ceil(getCellCount(T) / 2) * th end, font=SMALLSIZE, color=widget.options.textcolor},
             {type="label", text=function() return getDeltaText(T) end, pos=function() return 2*zw/3, math.ceil(getCellCount(T) / 2) * th end, font=SMALLSIZE, color= function() return (deltawarning == 0) and widget.options.textcolor or widget.options.textalarmcolor end},
         }
        }
    }

    lvgl.build(lyt)
end

local function create(zone, options)
    -- Runs one time when the widget instance is registered
    -- Store zone and options in the widget table for later use
    local widget = {
        zone = zone,
        options = options
    }

    -- Return widget table to EdgeTX
    return widget
end

local function update(widget, options)
    -- Runs if options are changed from the Widget Settings menu
    widget.options = options

    if options.battchemistry == 2 then
        -- Lipo HV
        cellsT =  {
            { {3.000,  0}},
            { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
            { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
            { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
            { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.828, 40} },
            { {3.832, 41}, {3.836, 42}, {3.841, 43}, {3.846, 44}, {3.850, 45}, {3.855, 46}, {3.859, 47}, {3.864, 48}, {3.868, 49}, {3.873, 50} },
            { {3.877, 51}, {3.881, 52}, {3.885, 53}, {3.890, 54}, {3.895, 55}, {3.900, 56}, {3.907, 57}, {3.917, 58}, {3.924, 59}, {3.929, 60} },
            { {3.936, 61}, {3.942, 62}, {3.949, 63}, {3.957, 64}, {3.964, 65}, {3.971, 66}, {3.984, 67}, {3.990, 68}, {3.998, 69}, {4.006, 70} },
            { {4.015, 71}, {4.024, 72}, {4.032, 73}, {4.042, 74}, {4.050, 75}, {4.060, 76}, {4.069, 77}, {4.078, 78}, {4.088, 79}, {4.098, 80} },
            { {4.109, 81}, {4.119, 82}, {4.130, 83}, {4.141, 84}, {4.154, 85}, {4.169, 86}, {4.184, 87}, {4.197, 88}, {4.211, 89}, {4.220, 90} },
            { {4.229, 91}, {4.237, 92}, {4.246, 93}, {4.254, 94}, {4.264, 95}, {4.278, 96}, {4.302, 97}, {4.320, 98}, {4.339, 99}, {4.350,100} },
        }
    else
        -- Lipo
        cellsT = {
            { {3.000,  0}},
            { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
            { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
            { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
            { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40} },
            { {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.840, 46}, {3.843, 47}, {3.847, 48}, {3.850, 49}, {3.854, 50} },
            { {3.857, 51}, {3.860, 52}, {3.863, 53}, {3.866, 54}, {3.870, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60} },
            { {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70} },
            { {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80} },
            { {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90} },
            { {4.116, 91}, {4.120, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.200,100} },
        }
    end
    doLayout(widget)

end

local function background(widget)
    -- Runs periodically only when widget instance is not visible

    -- Safety check in refresh too
    if T == nil or type(T) ~= "table" then
        T = {}
    end

    -- Update the % telemetry sensor even if not displayed
    setTelemetryValue(0x0310, 0, 1, getCellTotalPercent(T), 13, 0, "%bat")
end

local function refresh(widget, event, touchState)
    -- Runs periodically only when widget instance is visible
    -- If full screen, then event is 0 or event value, otherwise nil
    T = getValue(widget.options.sensor)

    -- Safety check in refresh too
    if T == nil or type(T) ~= "table" then
        T = {}
    end

    if lvgl == nil then
        lcd.drawText(0, 0, "No LVGL detected", COLOR_THEME_WARNING)
    end

    -- Create a % telemetry sensor
    setTelemetryValue(0x0310, 0, 1, getCellTotalPercent(T), 13, 0, "%bat")
end

return {
    name = name,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    translate = translate,
    useLvgl = true
}
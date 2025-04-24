--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for radiomaster TX16s                         #
# Copyright "Offer Shmuely"                                             #
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
#                                                                       #
# This program is free software; you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License version 2 as     #
# published by the Free Software Foundation.                            #
#                                                                       #
# This program is distributed in the hope that it will be useful        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
#########################################################################


-- Widget to show two telemetry Values one above the other.
--   intended mainly for the top bar

]]


-- Author : Offer Shmuely
-- Date: 2025
local app_name = "MicroValues"
local app_ver = "1.1"


-- imports
local LibLogClass = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "tcd")
local LibWidgetToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")

local m_log = LibLogClass(app_name, "/WIDGETS/" .. app_name)

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px
local FONT_LIST = {FONT_6,FONT_8,FONT_12,FONT_16,FONT_38,}

--------------------------------------------------------------
local function log(...)
    m_log.info(...)
end

--------------------------------------------------------------
local function prettyPrintNone(val, precession)
    -- log("prettyPrintNone - val:%s", val)
    -- log("prettyPrintNone - precession:%s", precession)
    if val == nil then
        return "N/A (nil)"
    end
    if type(val) == "table" then
        return "N/A (table)"
    end

    if val == -1 then
        --return "---"
        val = 0
    end

    if precession == 0 then
        return string.format("%2.0f", val)
    elseif precession == 1 then
        return string.format("%2.1f", val)
    elseif precession == 2 then
        return string.format("%2.2f", val)
    elseif precession == 3 then
        return string.format("%2.3f", val)
    --elseif precession == -1 then
    --    return string.format("%2.5f", val)
    end

    --return string.format("%2.3f ?prec?", val)
    return string.format("%2.0f", val)
end

local function calcColor()
    local wgt = lvgl.getContext()
    -- log("calcColor wgt: %s", wgt)

    if wgt.tools == nil then return wgt.options.inactiveColor end
    -- log("calcColor wgt.tools: %s", wgt.tools)
    -- log("calcColor isTelemetryAvailable: %s", wgt.tools.isTelemetryAvailable())
    if wgt.tools.isTelemetryAvailable() == false then return wgt.options.inactiveColor end
    return wgt.options.textColor or wgt.options.inactiveColor
end

-------------------------------------------------------------------------------
local function build_ui(wgt)
    local ts_w, ts_h, ts_voffset = wgt.tools.lcdSizeTextFixed("xxxx", wgt.fontSizeVal)
    local y1 = 4
    local y2 = y1 + ts_h + 5 + 0.2*ts_h
    local dx = 5

    log("build_ui wgt.options.fontSizeKeyIdx: %s", wgt.options.fontSizeKeyIdx)
    log("build_ui wgt.fontSizeVal: %s", wgt.fontSizeVal)

    lvgl.clear()
    lvgl.build({
        { type="label", x=dx, y=y1+ts_voffset,                    font=wgt.fontSizeKey, color=calcColor, text=function() return wgt.source_name1 or "--" end },
        { type="label", x=dx+wgt.source_name1_w, y=y1+ts_voffset, font=wgt.fontSizeVal, color=calcColor, text=function() return wgt.val_1_txt or "--" end },
        -- { type="rectangle", x=dx, y=0, w=220, h=ts_h, color=RED},
        { type="label", x=dx, y=y2+ts_voffset,                    font=wgt.fontSizeKey, color=calcColor, text=function() return wgt.source_name2 or "--" end },
        { type="label", x=dx+wgt.source_name2_w, y=y2+ts_voffset, font=wgt.fontSizeVal, color=calcColor, text=function() return wgt.val_2_txt or "--" end },
        -- { type="rectangle", x=dx, y=y2, w=220, h=ts_h, color=RED},
    })
end

local function update(wgt, options)
    if (wgt == nil) then return end
    wgt.options = options
    wgt.fontSizeVal = FONT_LIST[wgt.options.fontSizeValIdx] or FONT_16
    wgt.fontSizeKey = FONT_LIST[wgt.options.fontSizeKeyIdx] or FONT_8

    wgt.fieldinfo1 = nil
    wgt.fieldinfo2 = nil
    wgt.source_name1 = nil
    wgt.source_name2 = nil
    wgt.unit1 = ""
    wgt.unit2 = ""
    wgt.precession1 = -1
    wgt.precession2 = -1

    wgt.last_value_1 = -1
    wgt.last_value_2 = -1
    wgt.tools = LibWidgetToolsClass(m_log, app_name)

    wgt.source_name1 = wgt.tools.getSourceNameCleaned(wgt.options.source_1)
    if (wgt.source_name1 == nil) then
        wgt.source_name1 = "N/A"
    end
    wgt.source_name2 = wgt.tools.getSourceNameCleaned(wgt.options.source_2)
    if (wgt.source_name2 == nil) then
        wgt.source_name2 = "N/A"
    end
    wgt.source_name1_w = wgt.tools.lcdSizeTextFixed(wgt.source_name1, wgt.fontSizeKey)
    wgt.source_name2_w = wgt.tools.lcdSizeTextFixed(wgt.source_name2, wgt.fontSizeKey)


    wgt.isTypeSensor = false

    wgt.fieldinfo1 = wgt.tools.getSensorInfoByName(wgt.source_name1)
    -- wgt.fieldinfo1 = getFieldInfo(wgt.options.source_1)
    if (wgt.fieldinfo1 == nil) then
        log("getFieldInfo(%s)==nil", wgt.options.source_1)
    else
        local base_source_name = wgt.source_name1
        log("getFieldInfo    base_source_id: %s", wgt.options.source_1)
        log("getFieldInfo    base_source_name: %s", base_source_name)
        log("getFieldInfo    #base_source_name: %d", #base_source_name)
        local last_char = string.sub(base_source_name, #base_source_name,#base_source_name)
        log("getFieldInfo    last_char: %s", last_char)
        if last_char=="-" or last_char=="+" then
            base_source_name = string.sub(base_source_name, 1, #base_source_name - 1)
            log("getFieldInfo  fixed  base_source_name: %s", base_source_name)
        end

        -- wgt.unit = wgt.tools.unitIdToString(wgt.fieldinfo.unit)
        -- wgt.precession = wgt.tools.getSensorPrecession(base_source_name)
        wgt.unit1 = wgt.fieldinfo1.unit
        wgt.precession1 = wgt.fieldinfo1.precession

    end

    wgt.fieldinfo2 = wgt.tools.getSensorInfoByName(wgt.source_name2)
    -- wgt.fieldinfo2 = getFieldInfo(wgt.options.source_1)
    if (wgt.fieldinfo2 == nil) then
        log("getFieldInfo(%s)==nil", wgt.options.source_2)
    else
        local base_source_name = wgt.source_name2
        log("getFieldInfo    base_source_id: %s", wgt.options.source_2)
        log("getFieldInfo    base_source_name: %s", base_source_name)
        log("getFieldInfo    #base_source_name: %d", #base_source_name)
        local last_char = string.sub(base_source_name, #base_source_name,#base_source_name)
        log("getFieldInfo    last_char: %s", last_char)
        if last_char=="-" or last_char=="+" then
            base_source_name = string.sub(base_source_name, 1, #base_source_name - 1)
            log("getFieldInfo  fixed  base_source_name: %s", base_source_name)
        end

        -- wgt.unit = wgt.tools.unitIdToString(wgt.fieldinfo2.unit)
        -- wgt.precession = wgt.tools.getSensorPrecession(base_source_name)
        wgt.unit2 = wgt.fieldinfo2.unit
        wgt.precession2 = wgt.fieldinfo2.precession

    end

    wgt.isTypeSensor = wgt.tools.isSensorExist(wgt.source_name1)
    build_ui(wgt)
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
    }
    update(wgt, options)
    return wgt
end


local function calcWidgetValues(wgt)
    if (wgt.isTypeSensor and wgt.tools.isTelemetryAvailable() == false and wgt.last_value_1 ~= nil) then
        return
    end

    wgt.last_value_1 = getValue(wgt.options.source_1)
    wgt.last_value_2 = getValue(wgt.options.source_2)
end

local function background(wgt)
    if (wgt == nil) then return end

    calcWidgetValues(wgt)
end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end
    if (wgt.options == nil) then return end

    calcWidgetValues(wgt)

    local str_v1 = prettyPrintNone(wgt.last_value_1, wgt.precession)
    local str_v2 = prettyPrintNone(wgt.last_value_2, wgt.precession)

    -- wgt.val_1_txt = string.format("%s: %s%s", wgt.source_name1, str_v1, wgt.unit1)
    -- wgt.val_2_txt = string.format("%s: %s%s", wgt.source_name2, str_v2, wgt.unit2)
    wgt.val_1_txt = string.format("%s%s", str_v1, wgt.unit1)
    wgt.val_2_txt = string.format("%s%s", str_v2, wgt.unit2)
end

return { create=create, update=update, background=background, refresh=refresh }

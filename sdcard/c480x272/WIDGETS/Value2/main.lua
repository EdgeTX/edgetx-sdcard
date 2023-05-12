--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
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


-- Widget to show a telemetry Value in smart way
--   it fill better the widget area
--   it show the min/max values of the field
--   it detect end of flight (by telemetry) and favor the min/max of the unused current value

]]


-- Author : Offer Shmuely
-- Date: 2021-2023
-- ver: 0.7

local app_name = "Value2"

-- imports
local LibLogClass = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "tcd")
local LibWidgetToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
--local WidgetTransitionClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_transition.lua", "tcd")
local UtilsSensorsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "tcd")

local m_log = LibLogClass(app_name, "/WIDGETS/" .. app_name)

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px

-- backward compatibility
local ver, radio, maj, minor, rev, osname = getVersion()
local DEFAULT_SOURCE = 1
if maj == 2 and minor == 7 then
    -- for 2.7.x
    DEFAULT_SOURCE = 253     -- RSSI=253, TxBt=243, RxBt=256
elseif maj == 2 and minor >= 8 then
    -- for 2.8.x
    DEFAULT_SOURCE = 306     -- RSSI
end

local options = {
    { "Source", SOURCE, DEFAULT_SOURCE },
    { "TextColor", COLOR, COLOR_THEME_PRIMARY1 },
    { "Suffix", STRING, "" }
}

--------------------------------------------------------------
local function log(...)
    m_log.info(...)
end
--------------------------------------------------------------

local function update(wgt, options)
  if (wgt == nil) then return end
    wgt.options = options

    wgt.fieldinfo = nil
    wgt.source_name = nil
    wgt.unit = ""
    wgt.precession = -1

    wgt.source_min_id = nil
    wgt.source_max_id = nil
    wgt.last_value = -1
    wgt.last_value_min = -1
    wgt.last_value_max = -1
    wgt.tools = LibWidgetToolsClass(m_log, app_name)
    --wgt.transitions = WidgetTransitionClass(m_log,app_name)
    wgt.utils_sensors = UtilsSensorsClass(m_log,app_name)

    -- ***
    wgt.fieldinfo = getFieldInfo(wgt.options.Source)
    wgt.source_name = getSourceName(wgt.options.Source)
    -- workaround for bug in getFiledInfo()
    if (wgt.source_name == nil) then
        wgt.source_name = "N/A"
    end
    wgt.source_name = wgt.tools.cleanInvalidCharFromGetFiledInfo(wgt.source_name)

    if (wgt.fieldinfo == nil) then
        log("getFieldInfo(%s)==nil", wgt.options.Source)
    else
        wgt.unit = wgt.tools.unitIdToString(wgt.fieldinfo.unit)

        local base_source_name = wgt.source_name
        log("getFieldInfo    base_source_name: %s", base_source_name)
        log("getFieldInfo    #base_source_name: %d", #base_source_name)
        local last_char = string.sub(base_source_name, #base_source_name,#base_source_name)
        log("getFieldInfo    last_char: %s", last_char)
        if last_char=="-" or last_char=="+" then
            base_source_name = string.sub(base_source_name, 1, #base_source_name - 1)
            log("getFieldInfo  fixed  base_source_name: %s", base_source_name)
        end

        wgt.precession = wgt.tools.getSensorPrecession(base_source_name)

        -- update min id
        local source_min_obj = getFieldInfo(base_source_name .. "-")
        if source_min_obj ~= nil then
            wgt.source_min_id = source_min_obj.id
            --log("source_min_id: %d", wgt.source_min_id)
        end

        -- update max id
        local source_max_obj = getFieldInfo(base_source_name .. "+")
        if source_min_obj ~= nil then
            wgt.source_max_id = source_max_obj.id
            --log("source_max_id: %d", wgt.source_max_id)
        end
        --log("source_min_id: %d, source_max_id: %d", wgt.source_min_id, wgt.source_max_id)
    end

end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
    }
    update(wgt, options)
    return wgt
end

local function prettyPrintNone(val, precession)
    log("prettyPrintNone - val:%s", val)
    log("prettyPrintNone - precession:%s", precession)
    if val == nil then
        return "N/A (nil)"
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

    return string.format("%2.3f ?prec?", val)
end

local function getFontSize(wgt, txt, max_w, max_h)
    local w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_38)
    if w <= max_w and h <= max_h then
        log("[%s] FONT_38 %dx%d", txt, w, h, txt)
        return FONT_38, w, h + 2* v_offset, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_16)
    if w <= max_w and h <= max_h then
        log("[%s] FONT_16 %dx%d", txt, w, h, txt)
        return FONT_16, w, h + 2* v_offset, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_12)
    if w <= max_w and h <= max_h then
        log("[%s] FONT_12 %dx%d", txt, w, h, txt)
        return FONT_12, w, h + 2* v_offset, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_8)
    if w <= max_w and h <= max_h then
        log("[%s] FONT_8 %dx%d", txt, w, h, txt)
        return FONT_8, w, h + 2* v_offset, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_6)
    log("[%s] FONT_6 %dx%d", txt, w, h, txt)
    return FONT_6, w, h + 2* v_offset, v_offset
end

local function getFontSizePrint(wgt, txt, max_w, max_h)
    local fs, w, h, v_correction = getFontSize(wgt, txt, max_w, max_h)
    log("getFontSize: [%s] - fs: %d, w: %d, h: %d", txt, fs, w, h)
    return fs, w, h, v_correction
end

local function calcWidgetValues(wgt)
    if (wgt.tools.isTelemetryAvailable() == false) then
        log("overriding value with last_value: %s", wgt.last_value)
        return
    end

    wgt.last_value = getValue(wgt.options.Source)

    -- try to get min/max value (if exist)
    if wgt.source_min_id ~= nil and wgt.source_max_id ~= nil then
        wgt.last_value_min = getValue(wgt.source_min_id)
        wgt.last_value_max = getValue(wgt.source_max_id)
    end
end

local function background(wgt)
    if (wgt == nil) then return end

    calcWidgetValues(wgt)
end

------------------------------------------------------------
-- app mode (full screen)
local function refresh_app_mode(wgt, event, touchState)
    if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
        lcd.exitFullScreen()
    end

    local val_str = string.format("%s %s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)

    local zone_w = LCD_W
    local zone_h = LCD_H
    local ts_w, ts_h = lcd.sizeText(val_str, FONT_38)
    local dx = (zone_w - ts_w) / 2
    local dy = (zone_h - ts_h) / 3

    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    lcd.drawText(10, 0, header_txt, FONT_16 + wgt.options.TextColor)

    -- draw value
    if (wgt.tools.isTelemetryAvailable() == true) then
        lcd.drawText(0 + dx, 0 + dy, val_str, FONT_38 + wgt.options.TextColor)
    else
        lcd.drawText(0 + dx, 0 + dy, val_str, FONT_38 + lcd.RGB(0xA4A5A4) + BLINK)
    end

    -- draw min value
    if (wgt.last_value_min ~= -1) then
        val_str = string.format("min: %s %s", prettyPrintNone(wgt.last_value_min, wgt.precession), wgt.unit)
        lcd.drawText(0 + 10, 0 + LCD_H - 80, val_str, FONT_16 + wgt.options.TextColor)
    end

    -- draw max value
    if (wgt.last_value_max ~= -1) then
        val_str = string.format("max: %s %s", prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
        lcd.drawText(0 + 10, 0 + LCD_H - 40, val_str, FONT_16 + wgt.options.TextColor)
    end
end

local function refresh_widget_with_telem(wgt)
    local last_y = 0

    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    local font_size_header, ts_h_w, ts_h_h, v_offset = getFontSize(wgt, header_txt, wgt.zone.w, wgt.zone.h / 4)
    log("val: font_size_header: %d, ts_h_h: %d, lastY: %d", wgt.zone.y, ts_h_h, last_y)
    lcd.drawText(wgt.zone.x, wgt.zone.y + last_y + v_offset, header_txt, font_size_header + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_h_w, ts_h_h, BLUE)
    last_y = last_y + ts_h_h

    -- draw value
    local str_v = string.format("%s %s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)
    local font_size_v, ts_v_w, ts_v_h, v_offset = getFontSize(wgt, str_v, wgt.zone.w, wgt.zone.h)
    local dx = (wgt.zone.w - ts_v_w) / 2
    lcd.drawText(wgt.zone.x + dx, wgt.zone.y + last_y + v_offset, str_v, font_size_v + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x + dx, wgt.zone.y + last_y, ts_v_w, ts_v_h, BLUE)
    last_y = last_y + ts_v_h
    log("val: wgt.zone.y: %d, ts_v_h: %d, lastY: %d", wgt.zone.y, ts_v_h, last_y)

    -- draw min max
    if (wgt.last_value_min == -1 or wgt.last_value_max == -1) then
        return
    end

    local str_minmax = string.format("%s..%s %s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
    local font_size_minmax, ts_mm_w, ts_mm_h = getFontSize(wgt, str_minmax, wgt.zone.w -40, wgt.zone.h - last_y)

    if ts_mm_h >= wgt.zone.h - last_y then
        return
    end
    if ts_mm_w > wgt.zone.w then
        return
    end

    local dx = (wgt.zone.w - ts_mm_w) / 2
    lcd.setColor(CUSTOM_COLOR, lcd.RGB(0x8B8D8B))
    --lcd.drawFilledRectangle(wgt.zone.x + dx, wgt.zone.y + wgt.zone.h - ts_h3, ts_w3, ts_h3, LIGHTGREY)
    --wgt.tools.drawBadgedText(val_str_minmax, wgt.zone.x + dx, wgt.zone.y + wgt.zone.h - ts_h3, font_size_minmax, wgt.options.TextColor, CUSTOM_COLOR)
    wgt.tools.drawBadgedText(str_minmax, wgt.zone.x + dx, last_y, font_size_minmax, wgt.options.TextColor, CUSTOM_COLOR)
    --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + wgt.zone.h - ts_h3, val_str_minmax, font_size_minmax + wgt.options.TextColor)
end

local function refresh_widget_no_telem(wgt)
    -- end of flight

    local last_y = 0
    lcd.setColor(CUSTOM_COLOR, lcd.RGB(0xA4A5A4))

    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    local font_size_header, ts_h_w, ts_h_h, v_offset = getFontSize(wgt, header_txt, wgt.zone.w, wgt.zone.h / 4)
    log("val: font_size_header: %d, ts_h_h: %d, lastY: %d", wgt.zone.y, ts_h_h, last_y)
    lcd.drawText(wgt.zone.x, wgt.zone.y + last_y + v_offset, header_txt, font_size_header + CUSTOM_COLOR)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_h_w, ts_h_h, BLUE)
    last_y = last_y + ts_h_h

    -- draw min max calc
    local ts_mm_w =0
    local ts_mm_h = 0
    local font_size_mm = 0
    local v_offset = 0
    local val_str_mm = ""
    if (wgt.last_value_min ~= -1 and wgt.last_value_max ~= -1) and (wgt.zone.h > 50) then
        val_str_mm = string.format("%s..%s %s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
        font_size_mm, ts_mm_w, ts_mm_h, v_offset = getFontSize(wgt, val_str_mm, wgt.zone.w, wgt.zone.h - last_y)
        --local dx = (wgt.zone.w - ts_mm_w) / 2
        --if (ts_mm_h <= wgt.zone.h - last_y) and (ts_mm_w <= wgt.zone.w) then
        --    wgt.tools.drawBadgedText(val_str_mm, wgt.zone.x + dx - 5, wgt.zone.h - ts_mm_h, font_size_mm, wgt.options.TextColor, CUSTOM_COLOR)
        --    --log("wgt.zone.y: %d, wgt.zone.h: %d, ts_mm_h: %d", wgt.zone.y,wgt.zone.h,ts_mm_h)
        --end
    end

    -- draw value
    local str_v = string.format("%s %s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)
    local font_size_v, ts_v_w, ts_v_h, v_offset = getFontSize(wgt, str_v, wgt.zone.w, wgt.zone.h - ts_h_h - ts_mm_h)
    lcd.drawText(wgt.zone.x, wgt.zone.y + last_y + v_offset, str_v, font_size_v + CUSTOM_COLOR)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_v_w, ts_v_h, BLUE)
    last_y = last_y + ts_v_h

    -- draw min max
    local dx = (wgt.zone.w - ts_mm_w) / 2
    if (wgt.last_value_min ~= -1 and wgt.last_value_max ~= -1) and (wgt.zone.h > 50) then
        if (ts_mm_h <= wgt.zone.h - last_y) and (ts_mm_w <= wgt.zone.w) then
            wgt.tools.drawBadgedText(val_str_mm, wgt.zone.x + dx - 5, wgt.zone.y + last_y, font_size_mm, wgt.options.TextColor, CUSTOM_COLOR)
            --log("wgt.zone.y: %d, wgt.zone.h: %d, ts_mm_h: %d", wgt.zone.y,wgt.zone.h,ts_mm_h)
        end
    end

end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end
    if (wgt.options == nil) then return end

    calcWidgetValues(wgt)

    if (event ~= nil) then
        refresh_app_mode(wgt, event, touchState)
    else
        if (wgt.tools.isTelemetryAvailable()) then
            refresh_widget_with_telem(wgt)
        else
            refresh_widget_no_telem(wgt)
        end
    end

    -- widget load (debugging)
    -- lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y, string.format("load: %d%%", getUsage()), FONT_6 + GREY + RIGHT) -- ???
end

return { name = app_name, options = options, create = create, update = update, background = background, refresh = refresh }

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


-- Widget to show a telemetry Value in smart way
--   it fill better the widget area
--   it show the min/max values of the field
--   it detect end of flight (by telemetry) and favor the min/max of the unused current value

]]


-- Author : Offer Shmuely
-- Date: 2021-2024
local app_name = "Value2"
local app_ver = "0.9"


-- imports
local LibLogClass = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "tcd")
local LibWidgetToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
local UtilsSensorsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "tcd")

local m_log = LibLogClass(app_name, "/WIDGETS/" .. app_name)

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px

local lib_sensors = loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "tcd")(m_log,app_name)
local DEFAULT_SOURCE = lib_sensors.findSourceId( {"RQLY", "VFR", "cell","cels","RSSI","RxBt"})

local options = {
    { "Source", SOURCE, DEFAULT_SOURCE },
    { "TextColor", COLOR, COLOR_THEME_PRIMARY1 },
    { "Suffix", STRING, "" },
    { "Show_MinMax", BOOL, 1 }
}

--------------------------------------------------------------
local function log(...)
    m_log.info(...)
end
--------------------------------------------------------------

local function update(wgt, options)
  if (wgt == nil) then return end
    wgt.options = options
    if wgt.options.Show_MinMax == nil then
        wgt.options.Show_MinMax = 1
    end

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

    wgt.fieldinfo = getFieldInfo(wgt.options.Source)
    wgt.source_name = wgt.tools.getSourceNameCleaned(wgt.options.Source)
    if (wgt.source_name == nil) then
        wgt.source_name = "N/A"
    end

    wgt.isTypeSensor = false

    if (wgt.fieldinfo == nil) then
        log("getFieldInfo(%s)==nil", wgt.options.Source)
    else
        wgt.unit = wgt.tools.unitIdToString(wgt.fieldinfo.unit)

        local base_source_name = wgt.source_name
        log("getFieldInfo    base_source_id: %s", wgt.options.Source)
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


    wgt.isTypeSensor = wgt.tools.isSensorExist(wgt.source_name)

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
    -- log("prettyPrintNone - val:%s", val)
    -- log("prettyPrintNone - precession:%s", precession)
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

    --return string.format("%2.3f ?prec?", val)
    return string.format("%2.0f", val)
end

local function getFontSizeHeader(wgt, txt, max_h)
    local font_size
    if max_h > 115 then
        font_size = FONT_16
        -- log("getFontSizeHeader: [%s] FONT_16 h: %d", txt, max_h)
    elseif max_h > 80 then
        font_size = FONT_12
        -- log("getFontSizeHeader: [%s] FONT_12 h: %d", txt, max_h)
    elseif max_h > 50 then
        font_size = FONT_8
        -- log("getFontSizeHeader: [%s] FONT_8 h: %d", txt, max_h)
    else
        font_size = FONT_6
        -- log("getFontSizeHeader: [%s] FONT_6 h: %d", txt, max_h)
    end

    local w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, font_size)
    return font_size, w, h, v_offset
end

local function getFontSizeMinMax(wgt, txt, max_w, max_h, max_font_size)
    local w, h, v_offset
    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_8)
    if w <= max_w and h <= max_h then
        log("[%s] FONT_8 %dx%d", txt, w, h, txt)
        return FONT_8, w, h, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FONT_6)
    log("[%s] FONT_6 %dx%d", txt, w, h, txt)
    return FONT_6, w, h, v_offset
end

local function getFontSizePrint(wgt, txt, max_w, max_h)
    local fs, w, h, v_correction = wgt.tools.getFontSize(wgt, txt, max_w, max_h)
    log("getFontSize: [%s] - fs: %d, w: %d, h: %d", txt, fs, w, h)
    return fs, w, h, v_correction
end

local function calcWidgetValues(wgt)
    if (wgt.isTypeSensor and wgt.last_value ~= nil and wgt.tools.isTelemetryAvailable() == false) then
    -- if (wgt.last_value ~= nil and wgt.tools.isTelemetryAvailable() == false) then
            -- log("overriding value with last_value: %s", wgt.last_value)
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

    local val_str = string.format("%s%s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)

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
        val_str = string.format("min: %s%s", prettyPrintNone(wgt.last_value_min, wgt.precession), wgt.unit)
        lcd.drawText(0 + 10, 0 + LCD_H - 80, val_str, FONT_16 + wgt.options.TextColor)
    end

    -- draw max value
    if (wgt.last_value_max ~= -1) then
        val_str = string.format("max: %s%s", prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
        lcd.drawText(0 + 10, 0 + LCD_H - 40, val_str, FONT_16 + wgt.options.TextColor)
    end
end

local function refresh_widget_with_telem(wgt)
    local last_y = 1

    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    local font_size_header, ts_h_w, ts_h_h, ts_h_v_offset = getFontSizeHeader(wgt, header_txt, wgt.zone.h)
    lcd.drawText(wgt.zone.x + 5, wgt.zone.y + last_y + ts_h_v_offset, header_txt, font_size_header + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_h_w, ts_h_h, BLUE)
    last_y = last_y + ts_h_h + 3

    -- draw value
    --local str_v = string.format("%s%s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)
    local str_v = prettyPrintNone(wgt.last_value, wgt.precession)
    local font_size_v, ts_v_w, ts_v_h, ts_v_v_offset = wgt.tools.getFontSize(wgt, str_v, wgt.zone.w, wgt.zone.h - ts_h_h - 0)

    local dx = (wgt.zone.w - ts_v_w) / 2
    lcd.drawText     (wgt.zone.x + dx, wgt.zone.y + last_y + ts_v_v_offset, str_v, font_size_v + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x + dx, wgt.zone.y + last_y, ts_v_w, ts_v_h, BLUE)

    -- draw unit
    local font_size_u = wgt.tools.getFontSizeRelative(font_size_v, -2)
    local ts_u_w, ts_u_h, ts_u_v_offset = wgt.tools.lcdSizeTextFixed(wgt.unit, font_size_u)
    lcd.drawText     (wgt.zone.x + dx + ts_v_w, wgt.zone.y + last_y + (ts_v_h - ts_u_h) + ts_u_v_offset, wgt.unit, font_size_u + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x + dx + ts_v_w, wgt.zone.y + last_y + (ts_v_h - ts_u_h)                , ts_u_w, ts_u_h, BLUE)

    last_y = last_y + ts_v_h + 5

    -- draw min max

    --local str_minmax = string.format("%s..%s %s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
    local str_minmax = string.format("%s..%s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession))
    local font_size_minmax, ts_mm_w, ts_mm_h = getFontSizeMinMax(wgt, str_minmax, wgt.zone.w -40, wgt.zone.h - last_y)
    --local font_size_minmax, ts_mm_w, ts_mm_h = FONT_6, wgt.tools.lcdSizeTextFixed(str_minmax, FONT_6)


    if (wgt.options.Show_MinMax == 0) then
        return
    end
    if (wgt.last_value_min == -1 or wgt.last_value_max == -1) then
        return
    end
    if ts_mm_h >= wgt.zone.h - last_y then
        return
    end
    if ts_mm_w > wgt.zone.w then
        return
    end

    local dx = (wgt.zone.w - ts_mm_w) / 2
    wgt.tools.drawBadgedText(str_minmax, wgt.zone.x + dx, last_y, font_size_minmax, wgt.options.TextColor, lcd.RGB(0x8B8D8B))
    --lcd.drawText(wgt.zone.x + dx, wgt.zone.y + wgt.zone.h - ts_h3, val_str_minmax, font_size_minmax + wgt.options.TextColor)
end

local function refresh_widget_no_telem(wgt)
    -- end of flight

    local last_y = 1
    local valueColor = (wgt.isTypeSensor) and lcd.RGB(0xA4A5A4) or wgt.options.TextColor
    local bkgColor = (wgt.isTypeSensor) and lcd.RGB(0xA4A5A4) or wgt.options.TextColor

    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    local font_size_header, ts_h_w, ts_h_h, v_offset = getFontSizeHeader(wgt, header_txt, wgt.zone.h)
    log("val: font_size_header: %d, ts_h_h: %d, lastY: %d", wgt.zone.y, ts_h_h, last_y)
    lcd.drawText(wgt.zone.x + 5, wgt.zone.y + last_y + v_offset, header_txt, font_size_header + wgt.options.TextColor)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_h_w, ts_h_h, BLUE)
    last_y = last_y + ts_h_h + 3

    -- draw min max calc
    local ts_mm_w =0
    local ts_mm_h = 0
    local font_size_mm = 0
    local v_offset = 0
    local val_str_mm = ""
    if (wgt.options.Show_MinMax == 1) then
        if (wgt.last_value_min ~= -1 and wgt.last_value_max ~= -1) and (wgt.zone.h > 50) then
            val_str_mm = string.format("%s..%s %s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession), wgt.unit)
            font_size_mm, ts_mm_w, ts_mm_h, v_offset = wgt.tools.getFontSize(wgt, val_str_mm, wgt.zone.w, wgt.zone.h - last_y)
            local dx = (wgt.zone.w - ts_mm_w) / 2
            if (ts_mm_h <= wgt.zone.h - last_y) and (ts_mm_w <= wgt.zone.w) then
               wgt.tools.drawBadgedText(val_str_mm, wgt.zone.x + dx - 5, wgt.zone.h - ts_mm_h +v_offset, font_size_mm, wgt.options.TextColor, bkgColor)
               --log("wgt.zone.y: %d, wgt.zone.h: %d, ts_mm_h: %d", wgt.zone.y,wgt.zone.h,ts_mm_h)
            end
        end
    end

    -- draw value
    --local str_v = string.format("%s %s", prettyPrintNone(wgt.last_value, wgt.precession), wgt.unit)
    local str_v = prettyPrintNone(wgt.last_value, wgt.precession)
    local font_size_v, ts_v_w, ts_v_h, v_offset = wgt.tools.getFontSize(wgt, str_v, wgt.zone.w, wgt.zone.h - ts_h_h -(ts_mm_h-v_offset))
    -- log("val: wgt.zone.h:%d, ts_h_h:%d, (ts_mm_h:%d, v_offset: %d)", wgt.zone.h, ts_h_h,ts_mm_h,v_offset)
    local dx = (wgt.zone.w - ts_v_w) / 2
    lcd.drawText(wgt.zone.x + dx, wgt.zone.y + last_y + v_offset, str_v, font_size_v + valueColor)
    --lcd.drawRectangle(wgt.zone.x, wgt.zone.y + last_y, ts_v_w, ts_v_h, BLUE)

    -- draw unit
    local font_size_u = wgt.tools.getFontSizeRelative(font_size_v, -2)
    local ts_u_w, ts_u_h, ts_u_v_offset = wgt.tools.lcdSizeTextFixed(wgt.unit, font_size_u)
    lcd.drawText     (wgt.zone.x + dx + ts_v_w, wgt.zone.y + last_y + (ts_v_h - ts_u_h) + ts_u_v_offset, wgt.unit, font_size_u + valueColor)
    --lcd.drawRectangle(wgt.zone.x + dx + ts_v_w, wgt.zone.y + last_y + (ts_v_h - ts_u_h)                , ts_u_w, ts_u_h, BLUE)

    -- last_y = last_y + ts_v_h + 5

    -- -- draw min max
    -- if (wgt.options.Show_MinMax == 1) then
    --     local dx = (wgt.zone.w - ts_mm_w) / 2
    --     log("last_value_min: %d, last_value_max: %d, wgt.zone.h: %d", wgt.last_value_min,wgt.last_value_max,wgt.zone.h)
    --     if (wgt.last_value_min ~= -1 and wgt.last_value_max ~= -1) and (wgt.zone.h > 50) then
    --         log("aaa222 if (ts_mm_h:%d <= wgt.zone.h:%d - last_y:%d)", ts_mm_h, wgt.zone.h, last_y)
    --         if (ts_mm_h <= wgt.zone.h - last_y) and (ts_mm_w <= wgt.zone.w) then
    --             wgt.tools.drawBadgedText(val_str_mm, wgt.zone.x + dx - 5, wgt.zone.y + last_y, font_size_mm, wgt.options.TextColor, bkgColor)
    --             --log("wgt.zone.y: %d, wgt.zone.h: %d, ts_mm_h: %d", wgt.zone.y,wgt.zone.h,ts_mm_h)
    --         end
    --     end
    -- end

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
    -- lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y+20, string.format("isTypeSensor: %s", wgt.isTypeSensor), FONT_6 + GREY + RIGHT) -- ???
end

return { name = app_name, options = options, create = create, update = update, background = background, refresh = refresh }

--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for RadioMaster TX16S                         #
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
-- Date: 2021-2026
local app_name = "Value2"
local app_ver = "1.0"

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

-- imports
local LibLogClass           = assert(loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "btd"))
local m_log = LibLogClass(app_name, "/WIDGETS/" .. app_name)
local LibWidgetToolsClass   = assert(loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "btd"))
local UtilsSensorsClass     = assert(loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "btd"))
local lib_sensors           = assert(loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "btd"))(m_log,app_name)

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_24=XLSIZE or DBLSIZE, FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

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
        local sum_val = 0
        for k, v in pairs(val) do
            -- log("table %s = %s", tostring(k), tostring(v))
            if type(v) == "number" then
                sum_val = sum_val + v
            end
        end
        -- return "N/A (table)"
        return tostring(sum_val)
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

local function getFontSizeMinMax(wgt, txt, max_w, max_h, max_font_size)
    local w, h, v_offset
    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FS.FONT_8)
    if w <= max_w and h <= max_h then
        -- log("[%s] FONT_8 %dx%d", txt, w, h, txt)
        return FS.FONT_8, w, h, v_offset
    end

    w, h, v_offset = wgt.tools.lcdSizeTextFixed(txt, FS.FONT_6)
    -- log("[%s] FONT_6 %dx%d", txt, w, h, txt)
    return FS.FONT_6, w, h, v_offset
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
        local last_value_min_valid = true
        wgt.last_value_max = getValue(wgt.source_max_id)
        local last_value_max_valid = true
        wgt.last_value_valid = last_value_min_valid and last_value_max_valid
    end
    wgt.ts_value.txt = prettyPrintNone(wgt.last_value, wgt.precession)
    wgt.ts_mm.txt = string.format("%s..%s", prettyPrintNone(wgt.last_value_min, wgt.precession), prettyPrintNone(wgt.last_value_max, wgt.precession))
end

local function background(wgt)
    calcWidgetValues(wgt)
end

------------------------------------------------------------

local function build_ui(wgt)

    lvgl.clear()

    lvgl.build({{type="box", x=0, y=0, w=wgt.zone.w, h=wgt.zone.h,
        children={
            -- background
            {type="rectangle", x=0, y=0, w=wgt.zone.w, h=wgt.zone.h,
                    filled=true,
                    color=wgt.options.background_color,
                    visible=function() return wgt.options.background_enabled end
                },

            -- draw header
            -- {type="rectangle", color=BLACK, filled=false,
            --         pos = function() return wgt.ts_header.x, wgt.ts_header.y end,
            --         size=function () return wgt.ts_header.w, wgt.ts_header.h end,
            --     },
            {type="label",
                    pos = function() return wgt.ts_header.x, wgt.ts_header.y+wgt.ts_header.y_offset end,
                    text=function() return wgt.ts_header.txt end,
                    font=function() return wgt.ts_header.font end,
                    color=wgt.ts_header.color,
                    align=RIGHT
                },

            -- draw value
            -- {type="rectangle", color=BLACK, filled=false,
            --         pos = function() return wgt.ts_value.x, wgt.ts_value.y end,
            --         size=function () return wgt.ts_value.w, wgt.ts_value.h end,
            -- },
            {type="label",
                    pos = function() return wgt.ts_value.x, wgt.ts_value.y + wgt.ts_value.y_offset end,
                    font=function() return wgt.ts_value.font end,
                    color=function() return wgt.ts_value.color end,
                    text=function() return wgt.ts_value.txt end
            },

            -- draw unit
            -- {type="rectangle", x=ts_unit.x, y=ts_unit.y, w=ts_unit.w, h=ts_unit.h },
            {type="label",
                    pos = function() return wgt.ts_unit.x, wgt.ts_unit.y + wgt.ts_unit.y_offset end,
                    text=wgt.unit,
                    font=function() return wgt.ts_unit.font end,
                    color=function() return wgt.ts_unit.color end
               },

            -- draw min max
            {type="rectangle",
                    pos=function() return wgt.ts_mm.x, wgt.ts_mm.y end,
                    size=function() return wgt.ts_mm.w, wgt.ts_mm.h end,
                    filled=true, rounded=5,
                    color=lcd.RGB(0x8B8D8B),
                    visible=function() return wgt.options.Show_MinMax == 1 and wgt.last_value_valid end
                },
            {type="label",
                    pos=function() return wgt.ts_mm.x + 10*lvSCALE, wgt.ts_mm.y + wgt.ts_mm.y_offset end,
                    font=function() return wgt.ts_mm.font end,
                    color=function() return wgt.ts_mm.color end,
                    text=function() return wgt.ts_mm.txt end,
                    visible=function() return wgt.options.Show_MinMax == 1 and wgt.last_value_valid end
                },
        }},
    })

end

local function calc_pos_common(wgt)
    -- draw header
    local header_txt = wgt.source_name .. " " .. wgt.options.Suffix
    local font_size_header, ts_h_w, ts_h_h, ts_h_v_offset = wgt.tools.getFontSize(wgt, header_txt, 1000*lvSCALE, wgt.zone.h/4*lvSCALE, FS.FONT_8)
    log("[%s] header size: font_size_header:%d, ts_h_w:%d, ts_h_h:%d, ts_h_v_offset: %d", header_txt, font_size_header, ts_h_w, ts_h_h, ts_h_v_offset)

    wgt.ts_header.x = 2*lvSCALE
    wgt.ts_header.y = 2*lvSCALE
    wgt.ts_header.y_offset = ts_h_v_offset
    wgt.ts_header.w = ts_h_w
    wgt.ts_header.h = ts_h_h
    wgt.ts_header.txt = header_txt
    wgt.ts_header.font = font_size_header
    wgt.ts_header.color = wgt.options.TextColor
end

local function calc_pos_with_telem(wgt)
    calc_pos_common(wgt)

    local txtColor = wgt.options.TextColor
    local valueColor = wgt.options.TextColor
    local last_y = 1*lvSCALE

    last_y = wgt.ts_header.y + wgt.ts_header.h + 3*lvSCALE

    -- draw value
    local font_size_v, ts_v_w, ts_v_h, ts_v_v_offset = wgt.tools.getFontSize(wgt, wgt.ts_value.txt, wgt.zone.w, wgt.zone.h - wgt.ts_header.y - wgt.ts_header.h, FS.FONT_38)

    -- if value is not covering header
    local header_covers_value = (wgt.ts_header.x + wgt.ts_header.w >= (wgt.zone.w - ts_v_w) / 2)
    -- log("[%s] header covers value: %s, %s", wgt.dbgContext, wgt.ts_value.txt, tostring(header_covers_value))
    -- log("[%s] header.x: %d, header.w: %d, zone.w: %d, ts_v_w: %d, %d =? %d", wgt.dbgContext, wgt.ts_header.x, wgt.ts_header.w, wgt.zone.w, ts_v_w, wgt.ts_header.x + wgt.ts_header.w, (wgt.zone.w - ts_v_w) / 2)
    -- can we push value up if needed
   if header_covers_value == false then
        -- is it too crowded on the bottom? if yes, consider to push the value up
        if (wgt.zone.h - last_y - ts_v_h <  20*lvSCALE) then -- why 20?
            -- log("[%s] value pushed up by: %s", wgt.dbgContext, wgt.ts_header.h)
            last_y = last_y - wgt.ts_header.h
        end
   end

    wgt.ts_value.x = (wgt.zone.w - ts_v_w) / 2
    wgt.ts_value.y = last_y
    wgt.ts_value.y_offset = ts_v_v_offset
    wgt.ts_value.w = ts_v_w
    wgt.ts_value.h = ts_v_h
    wgt.ts_value.font = font_size_v
    wgt.ts_value.color=valueColor

    -- draw unit
    local font_size_u = wgt.tools.getFontSizeRelative(font_size_v, -2)
    local ts_u_w, ts_u_h, ts_u_v_offset = wgt.tools.lcdSizeTextFixed(wgt.unit, font_size_u)

    wgt.ts_unit.x = wgt.ts_value.x + wgt.ts_value.w
    wgt.ts_unit.y = last_y + (wgt.ts_value.h - ts_u_h)
    wgt.ts_unit.y_offset = ts_u_v_offset
    wgt.ts_unit.w = ts_u_w
    wgt.ts_unit.h = ts_u_h + ts_u_v_offset
    wgt.ts_unit.font = font_size_u
    wgt.ts_unit.color=valueColor

    last_y = wgt.ts_value.y + wgt.ts_value.h + 5*lvSCALE

    -- draw min max
    local font_size_mm, ts_mm_w, ts_mm_h, ts_mm_v_offset = getFontSizeMinMax(wgt, wgt.ts_mm.txt, wgt.zone.w -40*lvSCALE, wgt.zone.h - last_y)

    wgt.ts_mm.x = (wgt.zone.w - ts_mm_w) / 2
    wgt.ts_mm.y = wgt.ts_value.y + wgt.ts_value.h + 5*lvSCALE
    wgt.ts_mm.y_offset = ts_mm_v_offset + 2*lvSCALE
    wgt.ts_mm.w = ts_mm_w + 20*lvSCALE
    wgt.ts_mm.h = ts_mm_h + 3*lvSCALE
    wgt.ts_mm.font = font_size_mm
    wgt.ts_mm.color=txtColor
end

local function calc_pos_no_telem(wgt)
    -- end of flight

    calc_pos_common(wgt)

    local txtColor = wgt.options.TextColor
    local valueColor = (wgt.isTypeSensor) and lcd.RGB(0xA4A5A4) or wgt.options.TextColor
    local last_y = 1*lvSCALE

    last_y = wgt.ts_header.y + wgt.ts_header.h + 3*lvSCALE

    -- calc min max
    local ts_mm_w =0
    local ts_mm_h = 0
    local ts_mm_font_size = 0
    local ts_mm_v_offset = 0

    if (wgt.options.Show_MinMax == 1) then
        if (wgt.last_value_valid) and (wgt.zone.h > 50) then
            ts_mm_font_size, ts_mm_w, ts_mm_h, ts_mm_v_offset = wgt.tools.getFontSize(wgt, wgt.ts_mm.txt, wgt.zone.w -40*lvSCALE, wgt.zone.h - last_y, FS.FONT_38)
            log("getFontSize: wgt.ts_mm.font=%s", wgt.ts_mm.font)
        end
    end

    -- calc value
    local font_size_v, ts_v_w, ts_v_h, ts_v_v_offset = wgt.tools.getFontSize(wgt, wgt.ts_value.txt, wgt.zone.w, wgt.zone.h - wgt.ts_header.h -(ts_mm_h-ts_mm_v_offset))

    -- if value is not covering header
    local header_covers_value = (wgt.ts_header.x + wgt.ts_header.w >= (wgt.zone.w - ts_v_w) / 2)
    -- can we push value up if needed
   if header_covers_value == false then
        -- is it too crowded on the bottom? if yes, consider to push the value up
        if (wgt.zone.h - last_y - ts_v_h <  10*lvSCALE) then -- why 20?
            last_y = last_y - wgt.ts_header.h
        end
    end

    wgt.ts_value.x = (wgt.zone.w - ts_v_w) / 2
    wgt.ts_value.y = last_y
    wgt.ts_value.y_offset = ts_v_v_offset
    wgt.ts_value.w = ts_v_w
    wgt.ts_value.h = ts_v_h
    wgt.ts_value.font = font_size_v
    wgt.ts_value.color=valueColor

    -- draw unit
    local font_size_u = wgt.tools.getFontSizeRelative(font_size_v, -2)
    local ts_u_w, ts_u_h, ts_u_v_offset = wgt.tools.lcdSizeTextFixed(wgt.unit, font_size_u)

    wgt.ts_unit.x = wgt.ts_value.x + wgt.ts_value.w
    wgt.ts_unit.y = last_y + (wgt.ts_value.h - ts_u_h)
    wgt.ts_unit.y_offset = ts_u_v_offset
    wgt.ts_unit.w = ts_u_w
    wgt.ts_unit.h = ts_u_h + ts_u_v_offset
    wgt.ts_unit.font = font_size_u
    wgt.ts_unit.color=valueColor

    -- draw min max
    wgt.ts_mm.x = (wgt.zone.w - ts_mm_w) / 2
    wgt.ts_mm.y = wgt.ts_value.y + wgt.ts_value.h + -2*lvSCALE
    wgt.ts_mm.y_offset = ts_mm_v_offset + 2*lvSCALE
    wgt.ts_mm.w = ts_mm_w + 20*lvSCALE
    wgt.ts_mm.h = ts_mm_h + 3*lvSCALE
    wgt.ts_mm.font = ts_mm_font_size
    wgt.ts_mm.color = txtColor

end


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
    wgt.last_value = 0
    wgt.last_value_min = 0
    wgt.last_value_max = 0
    wgt.last_value_valid = false
    wgt.tools = LibWidgetToolsClass(m_log, app_name)
    --wgt.transitions = WidgetTransitionClass(m_log,app_name)
    wgt.utils_sensors = UtilsSensorsClass(m_log,app_name)

    wgt.ts_header  = {x=0,y=0,w=0,h=0, y_offset=0, font=FS.FONT_8, color=wgt.options.TextColor, txt="---"}
    wgt.ts_value   = {x=0,y=0,w=0,h=0, y_offset=0, font=FS.FONT_8, color=wgt.options.TextColor, txt="---"}
    wgt.ts_unit    = {x=0,y=0,w=0,h=0, y_offset=0, font=FS.FONT_8, color=wgt.options.TextColor, txt="---"}
    wgt.ts_mm      = {x=0,y=0,w=0,h=0, y_offset=0, font=FS.FONT_8, color=wgt.options.TextColor, txt="---"}


    wgt.fieldinfo = getFieldInfo(wgt.options.Source)
    wgt.source_name = wgt.tools.getSourceNameCleaned(wgt.options.Source)
    if (wgt.source_name == nil) then
        wgt.source_name = "N/A"
    end
    wgt.dbgContext = wgt.source_name .. " " .. wgt.options.Suffix

    wgt.isTypeSensor = false

    if (wgt.fieldinfo == nil) then
        log("getFieldInfo(%s)==nil", wgt.options.Source)
    else
        wgt.unit = wgt.tools.unitIdToString(wgt.fieldinfo.unit)

        local base_source_name = wgt.source_name
        -- log("getFieldInfo    base_source_id: %s", wgt.options.Source)
        -- log("getFieldInfo    base_source_name: %s", base_source_name)
        -- log("getFieldInfo    #base_source_name: %d", #base_source_name)
        local last_char = string.sub(base_source_name, #base_source_name,#base_source_name)
        -- log("getFieldInfo    last_char: %s", last_char)
        if last_char=="-" or last_char=="+" then
            base_source_name = string.sub(base_source_name, 1, #base_source_name - 1)
            -- log("getFieldInfo  fixed  base_source_name: %s", base_source_name)
        end

        wgt.precession = wgt.tools.getSensorPrecession(base_source_name)

        -- update min id
        local source_min_obj = getFieldInfo(base_source_name .. "-")
        if source_min_obj ~= nil then
            wgt.source_min_id = source_min_obj.id
            -- log("source_min_id: %d", wgt.source_min_id)
        end

        -- update max id
        local source_max_obj = getFieldInfo(base_source_name .. "+")
        if source_max_obj ~= nil then
            wgt.source_max_id = source_max_obj.id
            -- log("source_max_id: %d", wgt.source_max_id)
        end
        -- log("source_min_id: %d, source_max_id: %d", wgt.source_min_id, wgt.source_max_id)
    end


    wgt.isTypeSensor = wgt.tools.isSensorExist(wgt.source_name)

    build_ui(wgt)


    wgt.layout_calc_periodic = wgt.tools.periodicInit()
    wgt.tools.periodicStart(wgt.layout_calc_periodic, 400)
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
    }
    update(wgt, options)
    return wgt
end

local function refresh(wgt, event, touchState)
    background(wgt)

    local is_pass = wgt.tools.periodicHasPassed(wgt.layout_calc_periodic)
    if is_pass then
        if wgt.tools.isTelemetryAvailable() then
            calc_pos_with_telem(wgt)
        else
            calc_pos_no_telem(wgt)
        end

        wgt.tools.periodicReset(wgt.layout_calc_periodic)
    end

end

return { name=app_name, create=create, update=update, background=background, refresh=refresh }

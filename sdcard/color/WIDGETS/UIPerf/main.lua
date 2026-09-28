--
-- Copyright (C) EdgeTX
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

-- Displays UI rendering performance from lvgl.getPerf() and the MCU load
-- from getCpuLoad() and, optionally, publishes them as Lua telemetry
-- sensors (FPS, CPU, MCU) that can be logged, used in logical switches or
-- shown in other widgets.

local name = "UI Perf"

-- Sensors are created with this ID/instance on first run
local SENSOR_ID = 0x5F00
local SENSOR_INSTANCE = 0xE0

-- lvgl.getPerf() refreshes its figures every 300ms, no need to poll faster
local UPDATE_PERIOD = 30 -- 10ms ticks

local options = {
    { "sensors", BOOL, 1 },
    { "textcolor", COLOR, COLOR_THEME_PRIMARY1 },
}

local function translate(nam)
    local translations = {
        sensors = "Create sensors",
        textcolor = "Text color",
    }
    return translations[nam]
end

local function format_texts(widget)
    local keys = widget.keys
    if not keys then return end
    local parts = {}
    for i, k in ipairs(keys) do
        local v = widget.text[k] or "--"
        widget.label[k] = k .. ": " .. v
        parts[i] = k == "FPS" and (v .. " FPS") or (v .. " " .. k)
    end
    widget.line = table.concat(parts, "  ")
end

local function sample(widget)
    local now = getTime()
    if now - widget.lastUpdate < UPDATE_PERIOD then
        return
    end
    widget.lastUpdate = now

    if widget.hasPerf then
        widget.fps, widget.cpu = lvgl.getPerf()
        widget.text.FPS = string.format("%d", widget.fps)
        widget.text.CPU = string.format("%d%%", widget.cpu)
    end
    if widget.hasMcu then
        widget.mcu = getCpuLoad()
        widget.text.MCU = widget.mcu and string.format("%d%%", widget.mcu) or nil
    end
    format_texts(widget)

    if widget.options.sensors == 1 then
        if widget.hasPerf then
            setTelemetryValue(SENSOR_ID, 0, SENSOR_INSTANCE, widget.fps, UNIT_RAW, 0, "FPS")
            setTelemetryValue(SENSOR_ID + 1, 0, SENSOR_INSTANCE, widget.cpu, UNIT_PERCENT, 0, "CPU")
        end
        if widget.mcu then
            setTelemetryValue(SENSOR_ID + 2, 0, SENSOR_INSTANCE, widget.mcu, UNIT_PERCENT, 0, "MCU")
        end
    end
end

-- Retained LVGL labels: the zone only redraws when a value changes
local function build(widget)
    if lvgl == nil then return end
    lvgl.clear()

    local z = widget.zone
    local color = widget.options.textcolor

    if not (widget.hasPerf or widget.hasMcu) then
        lvgl.label({ x = 2, y = 2, text = "lvgl.getPerf() / getCpuLoad() not available",
                     font = SMLSIZE, color = COLOR_THEME_WARNING })
        return
    end

    local keys = {}
    if widget.hasPerf then
        keys[#keys + 1] = "FPS"
        keys[#keys + 1] = "CPU"
    end
    -- getCpuLoad() returns nil in the simulator
    if widget.hasMcu and getCpuLoad() ~= nil then
        keys[#keys + 1] = "MCU"
    end

    widget.keys = keys
    format_texts(widget)

    local font = z.h >= 120 and MIDSIZE or 0
    local lineH = z.h >= 120 and 30 or 18

    if z.h < 4 + #keys * lineH then
        lvgl.label({
            x = 2, y = 2, font = SMLSIZE, color = color,
            text = function() return widget.line end,
        })
        return
    end

    for i, k in ipairs(keys) do
        lvgl.label({
            x = 4, y = 4 + (i - 1) * lineH, font = font, color = color,
            text = function() return widget.label[k] end,
        })
    end
end

local function create(zone, options)
    return {
        zone = zone,
        options = options,
        hasPerf = lvgl ~= nil and lvgl.getPerf ~= nil,
        hasMcu = getCpuLoad ~= nil,
        lastUpdate = -UPDATE_PERIOD,
        fps = 0,
        cpu = 0,
        mcu = nil,
        text = {},
        label = {},
        line = "",
    }
end

local function update(widget, options)
    widget.options = options
    build(widget)
end

local function background(widget)
    if widget.hasPerf or widget.hasMcu then
        sample(widget)
    end
end

local function refresh(widget, event, touchState)
    if lvgl == nil then
        lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "LVGL not available", SMLSIZE + COLOR_THEME_WARNING)
        return
    end
    background(widget)
end

return {
    name = name,
    options = options,
    translate = translate,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    useLvgl = true,
}

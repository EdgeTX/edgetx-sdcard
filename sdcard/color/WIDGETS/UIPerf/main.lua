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

-- Displays UI rendering performance from getUIPerf() and, optionally,
-- publishes it as Lua telemetry sensors (FPS, CPU) that can be
-- logged, used in logical switches or shown in other widgets.

local name = "UI Perf"

-- Sensors are created with this ID/instance on first run
local SENSOR_ID = 0x5F00
local SENSOR_INSTANCE = 0xE0

-- getUIPerf() refreshes its figures every 300ms, no need to poll faster
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

local function sample(widget)
    local now = getTime()
    if now - widget.lastUpdate < UPDATE_PERIOD then
        return
    end
    widget.lastUpdate = now

    widget.fps, widget.cpu = getUIPerf()

    if widget.options.sensors == 1 then
        setTelemetryValue(SENSOR_ID, 0, SENSOR_INSTANCE, widget.fps, UNIT_RAW, 0, "FPS")
        setTelemetryValue(SENSOR_ID + 1, 0, SENSOR_INSTANCE, widget.cpu, UNIT_PERCENT, 0, "CPU")
    end
end

local function create(zone, options)
    return {
        zone = zone,
        options = options,
        supported = getUIPerf ~= nil,
        lastUpdate = -UPDATE_PERIOD,
        fps = 0,
        cpu = 0,
    }
end

local function update(widget, options)
    widget.options = options
end

local function background(widget)
    if widget.supported then
        sample(widget)
    end
end

local function refresh(widget, event, touchState)
    local z = widget.zone
    local color = widget.options.textcolor

    if not widget.supported then
        lcd.drawText(z.x + 2, z.y + 2, "getUIPerf() not available", SMLSIZE + COLOR_THEME_WARNING)
        return
    end

    sample(widget)

    if z.h < 50 then
        lcd.drawText(z.x + 2, z.y + 2,
            string.format("%d FPS  %d%% CPU", widget.fps, widget.cpu),
            SMLSIZE + color)
        return
    end

    local font = z.h >= 120 and MIDSIZE or 0
    local lineH = z.h >= 120 and 30 or 18
    local y = z.y + 4

    lcd.drawText(z.x + 4, y, string.format("FPS: %d", widget.fps), font + color)
    y = y + lineH
    lcd.drawText(z.x + 4, y, string.format("CPU: %d%%", widget.cpu), font + color)
end

return {
    name = name,
    options = options,
    translate = translate,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
}

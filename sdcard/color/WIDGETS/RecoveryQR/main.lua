--
-- Copyright (C) EdgeTX
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--

local appName = "Recovery QR"
local scriptDirectory = "/WIDGETS/RecoveryQR"
local logic = assert(loadScript(scriptDirectory .. "/logic.lua", "btd"))()
local storage = assert(loadScript(scriptDirectory .. "/storage.lua", "btd"))()

local SAVE_INTERVAL = 1500 -- 15 seconds, in 10 ms ticks
local SAVE_RETRY_INTERVAL = 100 -- 1 second
local QR_REFRESH_INTERVAL = 100 -- 1 second

local options = {
    { "GPS", SOURCE, { "GPS", "GPos" } },
    { "Live", COLOR, COLOR_THEME_ACTIVE },
    { "Stored", COLOR, COLOR_THEME_WARNING },
    { "Text", COLOR, COLOR_THEME_PRIMARY1 },
    { "Muted", COLOR, COLOR_THEME_DISABLED },
}

local function translate(name)
    local translations = {
        GPS = "GPS telemetry source",
        Live = "Live position color",
        Stored = "Stored position color",
        Text = "Text color",
        Muted = "Secondary text color",
    }
    return translations[name]
end

local function modelIdentity()
    local info = model.getInfo() or {}
    local filename = info.filename or info.name or "default"
    return logic.sanitizeModelKey(filename), info.name or filename
end

local function statusLabel(widget)
    if widget.state == "live" then
        return "LIVE GPS"
    elseif widget.state == "stored" then
        return "LAST KNOWN"
    end
    return "WAITING FOR GPS"
end

local function statusDetail(widget)
    if widget.state == "live" then
        return "Position updates while telemetry is available"
    elseif widget.state == "stored" then
        return "Telemetry lost - showing the saved position"
    end
    return "Select a GPS telemetry source"
end

local function statusColor(widget)
    if widget.state == "live" then
        return widget.options.Live
    elseif widget.state == "stored" then
        return widget.options.Stored
    end
    return widget.options.Muted
end

local function coordinateText(widget)
    return logic.coordinateText(widget.record)
end

local function capturedText(widget)
    if widget.record == nil then
        return "No position recorded"
    end
    return "Captured " .. widget.record.captured
end

local function qrData(widget)
    return logic.mapsUrl(widget.record) or "https://www.edgetx.org"
end

local function loadStoredRecord(widget)
    widget.record = storage.load(widget.paths, logic.parseRecord)
    if widget.record ~= nil then
        widget.lastSavedSignature = logic.serializeRecord(widget.record)
        widget.lastSavedAt = nil
    end
end

local function persistIfNeeded(widget, wasLive, now)
    if widget.record == nil or not widget.recordDirty then
        return
    end

    local telemetryLost = wasLive and not widget.live
    if widget.lastSaveAttemptAt ~= nil
        and now >= widget.lastSaveAttemptAt
        and now - widget.lastSaveAttemptAt < SAVE_RETRY_INTERVAL
        and not telemetryLost
    then
        return
    end

    if widget.lastSavedSignature ~= nil and not telemetryLost then
        if not widget.live then
            return
        end
        if widget.lastSavedAt ~= nil
            and now >= widget.lastSavedAt
            and now - widget.lastSavedAt < SAVE_INTERVAL
        then
            return
        end
    end

    local signature = logic.serializeRecord(widget.record)
    local shouldPersist = logic.shouldPersist(
        widget.lastSavedSignature,
        signature,
        widget.lastSavedAt,
        now,
        wasLive,
        widget.live,
        SAVE_INTERVAL
    )
    if not shouldPersist then
        if signature == widget.lastSavedSignature then
            widget.recordDirty = false
        end
        return
    end

    widget.lastSaveAttemptAt = now
    if storage.save(widget.paths, signature) then
        widget.lastSavedSignature = signature
        widget.lastSavedAt = now
        widget.recordDirty = false
    end
end

local function poll(widget)
    local now = getTime()
    local wasLive = widget.live
    local previousPayload = logic.mapsUrl(widget.record)
    local position = logic.normalizeGps(getValue(widget.options.GPS))

    widget.live = position ~= nil
    if position ~= nil then
        local payload = logic.mapsUrl(position)
        local refreshCaptureTime = widget.lastCaptureAt == nil
            or now < widget.lastCaptureAt
            or now - widget.lastCaptureAt >= 100
        if payload ~= previousPayload or refreshCaptureTime then
            widget.record = logic.newRecord(
                position,
                logic.captureStamp(getDateTime())
            )
            widget.lastCaptureAt = now
            widget.recordDirty = true
        end
    end

    widget.state = logic.state(widget.live, widget.record)
    persistIfNeeded(widget, wasLive, now)

    local currentPayload = logic.mapsUrl(widget.record)
    local qrRefreshDue = widget.lastQrBuildAt == nil
        or now < widget.lastQrBuildAt
        or now - widget.lastQrBuildAt >= QR_REFRESH_INTERVAL
    if currentPayload ~= widget.renderedPayload
        and (
            widget.renderedPayload == nil
            or qrRefreshDue
            or (wasLive and not widget.live)
        )
    then
        widget.layoutDirty = true
    end
end

local function clearStoredPosition(widget)
    if widget.live then
        return
    end

    storage.clear(widget.paths)
    widget.record = nil
    widget.state = logic.state(false, nil)
    widget.lastSavedSignature = nil
    widget.lastSavedAt = nil
    widget.lastSaveAttemptAt = nil
    widget.recordDirty = false
    widget.layoutDirty = true
end

local function confirmClear(widget)
    lvgl.confirm({
        title = "Clear saved position",
        message = "Remove the last known GPS position for this model?",
        confirm = function()
            clearStoredPosition(widget)
        end,
    })
end

local function statusLayout(widget, width, height, compact)
    local statusFont = compact and MIDSIZE or DBLSIZE
    local coordinateFont = compact and SMLSIZE or MIDSIZE
    local centerY = height // 2

    return {
        {
            type = "label",
            x = 6,
            y = compact and 3 or centerY - 35,
            w = width - 12,
            text = function() return statusLabel(widget) end,
            color = function() return statusColor(widget) end,
            font = statusFont,
            align = CENTER,
        },
        {
            type = "label",
            x = 6,
            y = compact and centerY - 2 or centerY + 2,
            w = width - 12,
            text = function() return coordinateText(widget) end,
            color = widget.options.Text,
            font = coordinateFont,
            align = CENTER,
        },
        {
            type = "label",
            x = 6,
            y = height - 23,
            w = width - 12,
            text = function() return capturedText(widget) end,
            color = widget.options.Muted,
            font = TINSIZE,
            align = CENTER,
        },
    }
end

local function tinyLayout(widget, width, height)
    return {
        {
            type = "label",
            x = 2,
            y = 1,
            w = width - 4,
            h = height - 2,
            text = function()
                if widget.state == "live" then
                    return "GPS LIVE"
                elseif widget.state == "stored" then
                    return "GPS SAVED"
                end
                return "NO GPS"
            end,
            color = function() return statusColor(widget) end,
            font = SMLSIZE,
            align = CENTER + VCENTER,
        },
    }
end

local function qrLayout(widget, width, height, fullscreen)
    local margin = fullscreen and 10 or 6
    local headerHeight = fullscreen and 38 or 0
    local footerHeight = fullscreen and 42 or 0
    local portrait = fullscreen and height > width
    local availableHeight = height - headerHeight - footerHeight - margin * 2
    local outerSize
    if portrait then
        outerSize = math.min(
            width - margin * 2,
            availableHeight * 65 // 100
        )
    else
        outerSize = math.min(availableHeight, width * 52 // 100 - margin)
    end
    local quietZone = math.max(8, outerSize // 10)
    local qrSize = outerSize - quietZone * 2
    local outerX = portrait and (width - outerSize) // 2 or margin
    local outerY = headerHeight + margin
    local qrX = outerX + quietZone
    local qrY = outerY + quietZone
    local textX = portrait and margin or outerX + outerSize + margin * 2
    local textWidth = portrait and width - margin * 2
        or width - textX - margin
    local statusY = portrait and outerY + outerSize + margin
        or qrY + math.max(2, qrSize // 8)
    local statusFont = fullscreen and (
        width < 400 or portrait
    ) and MIDSIZE or (fullscreen and DBLSIZE or MIDSIZE)
    local coordinateFont = fullscreen and (
        width < 400 or portrait
    ) and SMLSIZE or (fullscreen and MIDSIZE or SMLSIZE)
    local coordinateOffset = portrait and 28 or (fullscreen and 45 or 32)
    local capturedOffset = portrait and 52 or (fullscreen and 80 or 57)
    local detailOffset = portrait and 75 or (fullscreen and 112 or 80)
    local modelOffset = portrait and 98 or (fullscreen and 155 or 105)
    local textAlign = portrait and CENTER or nil

    local layout = {
        {
            type = "rectangle",
            x = outerX,
            y = outerY,
            w = outerSize,
            h = outerSize,
            color = WHITE,
            filled = true,
            visible = function() return widget.record ~= nil end,
        },
        {
            type = "qrcode",
            x = qrX,
            y = qrY,
            w = qrSize,
            data = qrData(widget),
            color = BLACK,
            bgColor = WHITE,
            visible = function() return widget.record ~= nil end,
        },
        {
            type = "label",
            x = textX,
            y = statusY,
            w = textWidth,
            text = function() return statusLabel(widget) end,
            color = function() return statusColor(widget) end,
            font = statusFont,
            align = textAlign,
        },
        {
            type = "label",
            x = textX,
            y = statusY + coordinateOffset,
            w = textWidth,
            text = function() return coordinateText(widget) end,
            color = widget.options.Text,
            font = coordinateFont,
            align = textAlign,
        },
        {
            type = "label",
            x = textX,
            y = statusY + capturedOffset,
            w = textWidth,
            text = function() return capturedText(widget) end,
            color = widget.options.Muted,
            font = SMLSIZE,
            align = textAlign,
        },
        {
            type = "label",
            x = textX,
            y = statusY + detailOffset,
            w = textWidth,
            text = function() return statusDetail(widget) end,
            color = widget.options.Muted,
            font = SMLSIZE,
            align = textAlign,
        },
        {
            type = "label",
            x = textX,
            y = statusY + modelOffset,
            w = textWidth,
            text = function() return widget.modelName end,
            color = widget.options.Text,
            font = SMLSIZE,
            visible = function()
                return not portrait and (not fullscreen or height >= 300)
            end,
            align = textAlign,
        },
    }

    if fullscreen then
        table.insert(layout, {
            type = "label",
            x = 10,
            y = 5,
            w = width - 20,
            text = width < 400 and "RECOVERY QR" or "RECOVERY QR - Scan to navigate",
            color = widget.options.Text,
            font = MIDSIZE,
            align = CENTER,
        })
        table.insert(layout, {
            type = "button",
            x = width - 155,
            y = height - 38,
            w = 145,
            h = 32,
            text = "Clear position",
            visible = function()
                return not widget.live and widget.record ~= nil
            end,
            press = function()
                confirmClear(widget)
            end,
        })
    end

    return layout
end

local function buildLayout(widget)
    if lvgl == nil or widget.zone == nil then
        return
    end

    local width = widget.fullscreen and LCD_W or (widget.zone.w or 0)
    local height = widget.fullscreen and LCD_H or (widget.zone.h or 0)
    if width <= 0 or height <= 0 then
        return
    end

    local layoutName = logic.layoutForZone(width, height, widget.fullscreen)
    local layout
    if layoutName == "tiny" then
        layout = tinyLayout(widget, width, height)
    elseif layoutName == "compact" or widget.record == nil then
        layout = statusLayout(widget, width, height, true)
    elseif layoutName == "fullscreen" then
        layout = qrLayout(widget, width, height, true)
    else
        layout = qrLayout(widget, width, height, false)
    end

    lvgl.clear()
    lvgl.build(layout)
    widget.renderedPayload = logic.mapsUrl(widget.record)
    widget.lastQrBuildAt = getTime()
    widget.layoutDirty = false
end

local function create(zone, widgetOptions)
    local modelKey, modelName = modelIdentity()
    local widget = {
        zone = zone,
        options = widgetOptions,
        modelName = modelName,
        paths = storage.paths(scriptDirectory, modelKey),
        live = false,
        fullscreen = false,
        layoutDirty = true,
        recordDirty = false,
    }

    loadStoredRecord(widget)
    poll(widget)
    return widget
end

local function update(widget, widgetOptions)
    widget.options = widgetOptions
    widget.layoutDirty = true
    poll(widget)
    buildLayout(widget)
end

local function background(widget)
    poll(widget)
end

local function refresh(widget, event, touchState)
    local fullscreen = event ~= nil
    if fullscreen and (
        event == EVT_VIRTUAL_EXIT
        or (touchState ~= nil and touchState.tapCount == 2)
    ) then
        lvgl.exitFullScreen()
        return
    end

    if fullscreen ~= widget.fullscreen then
        widget.fullscreen = fullscreen
        widget.layoutDirty = true
    end

    poll(widget)
    if widget.layoutDirty then
        buildLayout(widget)
    end
end

return {
    name = appName,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    translate = translate,
    useLvgl = true,
}

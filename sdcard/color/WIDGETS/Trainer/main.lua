--
-- Copyright (C) EdgeTX
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--

local appName = "Trainer"
local logic = assert(loadScript("/WIDGETS/" .. appName .. "/logic.lua", "btd"))()

local RESCAN_INTERVAL = 100
local RECONNECTED_DURATION = 200

local options = {
    { "Connected", COLOR, COLOR_THEME_PRIMARY2 },
    { "Active", COLOR, COLOR_THEME_ACTIVE },
    { "Warning", COLOR, COLOR_THEME_WARNING },
    { "Neutral", COLOR, COLOR_THEME_DISABLED },
    { "Text", COLOR, COLOR_THEME_PRIMARY1 },
}

local function translate(name)
    local translations = {
        Connected = "Connected color",
        Active = "Student control color",
        Warning = "Link warning color",
        Neutral = "Waiting color",
        Text = "Secondary text color",
    }
    return translations[name]
end

local function scanTrainerSwitches(widget, now)
    widget.trainerSwitches = logic.findTrainerSwitches(model.getCustomFunction, FUNC_TRAINER)
    widget.lastScan = now
end

local function poll(widget)
    local now = getTime()
    if widget.lastScan == nil or now - widget.lastScan >= RESCAN_INTERVAL then
        scanTrainerSwitches(widget, now)
    end

    local status = getTrainerStatus()
    if status ~= widget.rawStatus then
        widget.rawStatus = status
        widget.statusChangedAt = now
    end

    local showReconnected =
        status == 3 and widget.statusChangedAt ~= nil and now - widget.statusChangedAt < RECONNECTED_DURATION
    local controlRequested = logic.isControlRequested(widget.trainerSwitches, getSwitchValue)

    widget.stateKey, widget.state =
        logic.classify(status, controlRequested, showReconnected)
    widget.configured = #widget.trainerSwitches > 0
end

local function stateColor(widget)
    local colors = {
        connected = widget.options.Connected,
        active = widget.options.Active,
        warning = widget.options.Warning,
        neutral = widget.options.Neutral,
    }
    return colors[widget.state.color] or widget.options.Neutral
end

local function drawStatusDot(x, y, radius, color)
    lcd.drawFilledCircle(x, y, radius, color)
    lcd.drawCircle(x, y, radius, COLOR_THEME_PRIMARY1)
end

local function textWidth(text, flags)
    local width = lcd.sizeText(text, flags)
    return width
end

local function chooseText(full, short, maxWidth, fonts)
    for _, font in ipairs(fonts) do
        if textWidth(full, font) <= maxWidth then
            return full, font
        end
    end

    for _, font in ipairs(fonts) do
        if textWidth(short, font) <= maxWidth then
            return short, font
        end
    end

    return short, fonts[#fonts]
end

local function drawCenteredPair(zone, y, leftText, leftFlags, rightText, rightFlags, gap, color)
    local leftWidth = textWidth(leftText, leftFlags)
    local rightWidth = textWidth(rightText, rightFlags)
    local startX = zone.x + (zone.w - leftWidth - gap - rightWidth) // 2

    lcd.drawText(startX, y, leftText, LEFT + VCENTER + leftFlags + color)
    lcd.drawText(startX + leftWidth + gap, y, rightText,
                 LEFT + VCENTER + rightFlags + color)
end

local function drawTiny(widget, color)
    local zone = widget.zone
    local centerY = zone.y + zone.h // 2
    local iconFlags = MIDSIZE
    local labelFlags = SMLSIZE + BOLD
    local gap = 4
    local contentWidth = textWidth(CHAR_TRAINER, iconFlags) + gap +
                         textWidth(widget.state.short, labelFlags)

    if contentWidth > zone.w - 6 then
        lcd.drawText(zone.x + zone.w // 2, centerY, CHAR_TRAINER,
                     CENTER + VCENTER + iconFlags + color)
        drawStatusDot(zone.x + zone.w - 6, zone.y + 6, 3, color)
        return
    end

    drawCenteredPair(zone, centerY, CHAR_TRAINER, iconFlags,
                     widget.state.short, labelFlags, gap, color)
end

local function drawCompact(widget, color)
    local zone = widget.zone
    local centerY = zone.y + zone.h // 2
    local iconFlags = MIDSIZE
    local gap = 6
    local labelWidth = zone.w - textWidth(CHAR_TRAINER, iconFlags) - gap - 8
    local label, labelFlags = chooseText(widget.state.label, widget.state.short,
                                         labelWidth, { MIDSIZE + BOLD, SMLSIZE + BOLD })

    drawCenteredPair(zone, centerY, CHAR_TRAINER, iconFlags,
                     label, labelFlags, gap, color)
end

local function drawMedium(widget, color)
    local zone = widget.zone
    local centerY = zone.y + zone.h // 2
    local iconFlags = MIDSIZE
    local gap = 7
    local labelWidth = zone.w - textWidth(CHAR_TRAINER, iconFlags) - gap - 12
    local label, labelFlags = chooseText(widget.state.label, widget.state.short,
                                         labelWidth, { MIDSIZE + BOLD, SMLSIZE + BOLD })
    local detail, detailFlags = chooseText(widget.state.detail, widget.state.short,
                                           zone.w - 12, { SMLSIZE, TINSIZE })

    drawCenteredPair(zone, centerY - 12, CHAR_TRAINER, iconFlags,
                     label, labelFlags, gap, color)
    lcd.drawText(zone.x + zone.w // 2, centerY + 14, detail,
                 CENTER + VCENTER + detailFlags + widget.options.Text)

    if not widget.configured then
        lcd.drawText(zone.x + zone.w // 2, zone.y + zone.h - 3,
                     "No Trainer function", CENTER + VBOTTOM + TINSIZE + widget.options.Neutral)
    end
end

local function drawLarge(widget, color)
    local zone = widget.zone
    local centerX = zone.x + zone.w // 2
    local stateY = zone.y + math.max(44, zone.h * 2 // 5)
    local rowY = zone.y + zone.h - 34
    local headerIconFlags = MIDSIZE
    local headerLabelFlags = MIDSIZE + BOLD
    local stateFontChoices = zone.h >= 190 and
                                 { DBLSIZE + BOLD, MIDSIZE + BOLD, SMLSIZE + BOLD } or
                                 { MIDSIZE + BOLD, SMLSIZE + BOLD }
    local stateLabel, stateFlags = chooseText(widget.state.label, widget.state.short,
                                               zone.w - 16, stateFontChoices)
    local detail, detailFlags = chooseText(widget.state.detail, widget.state.short,
                                           zone.w - 16, { SMLSIZE, TINSIZE })

    drawCenteredPair(zone, zone.y + 20, CHAR_TRAINER, headerIconFlags,
                     "TRAINER", headerLabelFlags, 8, widget.options.Text)
    lcd.drawText(centerX, stateY, stateLabel,
                 CENTER + VCENTER + stateFlags + color)
    lcd.drawText(centerX, stateY + 32, detail,
                 CENTER + VCENTER + detailFlags + widget.options.Text)

    local control = widget.configured and widget.state.control or "Not configured"
    local rowTextWidth = (zone.w - 48) // 2
    local linkText, linkFlags = chooseText("Link: " .. widget.state.link,
                                           widget.state.link, rowTextWidth,
                                           { SMLSIZE, TINSIZE })
    local controlText, controlFlags = chooseText("Control: " .. control,
                                                 control, rowTextWidth,
                                                 { SMLSIZE, TINSIZE })

    drawStatusDot(zone.x + 16, rowY, 5, color)
    lcd.drawText(zone.x + 28, rowY, linkText,
                 LEFT + VCENTER + linkFlags + widget.options.Text)
    lcd.drawText(zone.x + zone.w - 8, rowY, controlText,
                 RIGHT + VCENTER + controlFlags + widget.options.Text)
end

local function draw(widget)
    local color = stateColor(widget)
    local layout = logic.layoutForZone(widget.zone)

    if layout == "tiny" then
        drawTiny(widget, color)
    elseif layout == "compact" then
        drawCompact(widget, color)
    elseif layout == "medium" then
        drawMedium(widget, color)
    else
        drawLarge(widget, color)
    end
end

local function create(zone, widgetOptions)
    local widget = {
        zone = zone,
        options = widgetOptions,
        trainerSwitches = {},
    }
    poll(widget)
    return widget
end

local function update(widget, widgetOptions)
    widget.options = widgetOptions
    widget.lastScan = nil
    poll(widget)
end

local function background(widget)
    poll(widget)
end

local function refresh(widget)
    poll(widget)
    draw(widget)
end

return {
    name = appName,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    translate = translate,
}

-- A Timer version that fill better the widget area
-- Offer Shmuely
-- Date: 2021-2026
local app_name = "Timer2"
local app_ver = "1.1"

local function log(fmt, ...)
    print(string.format("[%s] " .. fmt, app_name, ...))
end

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

------------------------------------------------------------

local function formatTime(wgt, t1)
    local dd_raw = t1.value
    local isNegative = false
    if dd_raw < 0 then
        isNegative = true
        dd_raw = math.abs(dd_raw)
    end
    -- log("dd_raw: " .. dd_raw)

    local dd = math.floor(dd_raw / 86400)
    dd_raw = dd_raw - dd * 86400
    local hh = math.floor(dd_raw / 3600)
    dd_raw = dd_raw - hh * 3600
    local mm = math.floor(dd_raw / 60)
    dd_raw = dd_raw - mm * 60
    local ss = math.floor(dd_raw)

    local time_str
    if dd == 0 and hh == 0 then
        -- less than 1 hour, 59:59
        time_str = string.format("%02d:%02d", mm, ss)

    elseif dd == 0 then
        -- less than 24 hours, 23:59:59
        time_str = string.format("%02d:%02d:%02d", hh, mm, ss)

    else
        -- more than 24 hours
        if wgt.options.use_days == 0 then
            -- 25:59:59
            time_str = string.format("%02d:%02d:%02d", dd * 24 + hh, mm, ss)
        else
            -- 5d 23:59:59
            time_str = string.format("%dd %02d:%02d:%02d", dd, hh, mm, ss)
        end

    end
    if isNegative then
        time_str = '-' .. time_str
    end
    return time_str, isNegative
end

local function getTimerHeader(wgt, t1, forceMinimalWidth)
    local timerInfo = ""
    local timer_have_name = string.len(t1.name) > 0
    if timer_have_name then
        if forceMinimalWidth then
            timerInfo = string.format("T%s:%s", wgt.options.Timer, t1.name)
        else
            timerInfo = string.format("%s: (Timer %s)", t1.name, wgt.options.Timer)
        end
    else
        if forceMinimalWidth then
            timerInfo = string.format("T %s: ", wgt.options.Timer)
        else
            timerInfo = string.format("Timer %s: ", wgt.options.Timer)
        end
    end
    return timerInfo
end

local function getFontSize(wgt, txt)
    local wide_txt = string.gsub(txt, "[1-9]", "0")
    -- log(string.gsub("******* 12:34:56", "[1-9]", "0"))
    -- log("wide_txt: " .. wide_txt)

    local w, h = lcd.sizeText(wide_txt, FS.FONT_38)
    -- log("FONT_38 w: %d, h: %d, %s", w, h, txt)
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_38
    end

    w, h = lcd.sizeText(wide_txt, FS.FONT_16)
    -- log("FONT_16 w: %d, h: %d, %s", w, h, txt)
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_16
    end

    w, h = lcd.sizeText(wide_txt, FS.FONT_12)
    -- log("FONT_12 w: %d, h: %d, %s", w, h, txt)
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_12
    end

    w, h = lcd.sizeText(wide_txt, FS.FONT_8)
    -- log("FONT_8 w: %d, h: %d, %s", w, h, txt)
    if w < wgt.zone.w and h <= wgt.zone.h then
        return FS.FONT_8
    end

    -- log("FONT_6 w: %d, h: %d, %s", w, h, txt)
    return FS.FONT_6
end


local function calculate_info(wgt)
    local t1 = model.getTimer(wgt.options.Timer - 1)

    -- calculate timer info
    wgt.timerInfo = getTimerHeader(wgt, t1, false)
    wgt.font_size_header = FS.FONT_6
    local timer_info_w, timer_info_h = lcd.sizeText(wgt.timerInfo, wgt.font_size_header)
    if timer_info_w > wgt.zone.w then
        wgt.timerInfo = getTimerHeader(wgt, t1, true)
    end

    -- calculate timer time
    wgt.time_str, wgt.isNegative = formatTime(wgt, t1)
    wgt.font_size = getFontSize(wgt, wgt.time_str)
    local zone_w = wgt.zone.w
    local zone_h = wgt.zone.h

    if wgt.isNegative == true then
        wgt.textColor = RED
    else
        wgt.textColor = wgt.options.TextColor
    end


    local wide_time_str = string.gsub(wgt.time_str, "[1-9]", "0")
    local ts_w, ts_h = lcd.sizeText(wide_time_str, wgt.font_size)
    wgt.dx = (zone_w - ts_w) / 2
    wgt.dy = timer_info_h - 1
    if (timer_info_h + ts_h > zone_h) and (zone_h < 50) then
        log("--- not enough height, force minimal spaces")
        wgt.dy = 0
    end

    return
end

local function build_ui(wgt)

    calculate_info(wgt)

    lvgl.clear()
    lvgl.build({
        -- draw timer info
        {type="label", x=0, y=0, text=function() return wgt.timerInfo end,
            font  = function() return wgt.font_size_header end,
            color = function() return wgt.textColor end,
        },

        -- draw timer time
        {type="label", text=function() return wgt.time_str end,
            font=function() return wgt.font_size end,
            color=function() return wgt.textColor end,
            pos=function() return wgt.dx, wgt.dy end
        },

        -- {type="label", x=100, y=0, font=FS.FONT_6, color=LIGHTGREY, text=function() return string.format("%d%%", getUsage()) end },
        -- {type="rectangle", x=0, y=0, w=wgt.zone.w, h=wgt.zone.h, color=BLACK, filled=false, zIndex=-1}
    })
end

local function update(wgt, options)
    if (wgt == nil) then return end
    wgt.options = options
    wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1
    build_ui(wgt)
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options
    }
    update(wgt, options)
    return wgt
end

local function background(wgt)
end

local function refresh(wgt, event, touchState)
    calculate_info(wgt)
end

return {create=create, update=update, background=background, refresh=refresh}

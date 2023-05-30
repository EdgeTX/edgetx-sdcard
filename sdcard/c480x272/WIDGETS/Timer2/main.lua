-- A Timer version that fill better the widget area
-- Offer Shmuely
-- Date: 2021-2023
-- ver: 0.8

local options = {
  { "TextColor", COLOR, YELLOW },
  { "Timer", VALUE, 1, 1, 3},
  { "use_days", BOOL, 0 }   -- if greater than 24 hours: 0=still show as hours, 1=use days

}

local function log(s)
  return;
  --print("timer2: " .. s)
end

local function create(zone, options)
  local wgt = { zone = zone, options = options }
  wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1
  return wgt
end

local function update(wgt, options)
  if (wgt == nil) then return end
  wgt.options = options
  --log("TimerNumB:" .. options.Timer)
end

local function background(wgt)
  return
end

------------------------------------------------------------

local function formatTime(wgt, t1)
  local dd_raw = t1.value
  local isNegative = false
  if dd_raw < 0 then
    isNegative = true
    dd_raw = math.abs(dd_raw)
  end
  log("dd_raw: " .. dd_raw)

  local dd = math.floor(dd_raw / 86400)
  dd_raw = dd_raw - dd * 86400
  local hh = math.floor(dd_raw / 3600)
  dd_raw = dd_raw - hh * 3600
  local mm = math.floor(dd_raw / 60)
  dd_raw = dd_raw - mm * 60
  local ss = math.floor(dd_raw)

  if dd == 0 and hh == 0 then
    -- less then 1 hour, 59:59
    time_str = string.format("%02d:%02d", mm, ss)

  elseif dd == 0 then
    -- lass then 24 hours, 23:59:59
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

local function getTimerHeader(wgt, t1)
  local timerInfo = ""
  if (string.len(t1.name) == 0) then
    timerInfo = string.format("T%s: ", wgt.options.Timer)
  else
    timerInfo = string.format("T%s: (%s)", wgt.options.Timer, t1.name)
  end
  return timerInfo
end

local function getFontSize(wgt, txt)
  wide_txt = string.gsub(txt, "[1-9]", "0")
  --log(string.gsub("******* 12:34:56", "[1-9]", "0"))
  log("wide_txt: " .. wide_txt)

  local w,h = lcd.sizeText(wide_txt, XXLSIZE)
  log(string.format("XXLSIZE w: %d, h: %d, %s", w, h, time_str))
  if w < wgt.zone.w and h <= wgt.zone.h then
    return XXLSIZE
  end

  w,h = lcd.sizeText(wide_txt, DBLSIZE)
  log(string.format("DBLSIZE w: %d, h: %d, %s", w, h, time_str))
  if w < wgt.zone.w and h <= wgt.zone.h then
    return DBLSIZE
  end

  w,h = lcd.sizeText(wide_txt, MIDSIZE)
  log(string.format("MIDSIZE w: %d, h: %d, %s", w, h, time_str))
  if w < wgt.zone.w and h <= wgt.zone.h then
    return MIDSIZE
  end

  log(string.format("SMLSIZE w: %d, h: %d, %s", w, h, time_str))
  return SMLSIZE
end

local function refresh(wgt, event, touchState)
  if (wgt == nil)               then log("refresh(nil)")                   return end
  if (wgt.options == nil)       then log("refresh(wgt.options=nil)")       return end
  if (wgt.options.Timer == nil) then log("refresh(wgt.options.Timer=nil)") return end

  local t1 = model.getTimer(wgt.options.Timer - 1)

  -- calculate timer info
  local timerInfo = getTimerHeader(wgt, t1)
  local timer_info_w, timer_info_h = lcd.sizeText(timerInfo, SMLSIZE)

  -- calculate timer time
  local time_str, isNegative = formatTime(wgt, t1)
  local font_size = getFontSize(wgt, time_str)
  local zone_w = wgt.zone.w
  local zone_h = wgt.zone.h

  local textColor
  if isNegative == true then
    textColor = RED
  else
    textColor = wgt.options.TextColor
  end

  local font_size_header = SMLSIZE
  if (event ~= nil) then
    -- app mode (full screen)
    font_size = XXLSIZE
    font_size_header = DBLSIZE
    zone_w = 460
    zone_h = 252
  end

  wide_time_str = string.gsub(time_str, "[1-9]", "0")
  local ts_w,ts_h = lcd.sizeText(wide_time_str, font_size)
  local dx = (zone_w - ts_w) /2
  local dy = timer_info_h -1
  if (timer_info_h + ts_h > zone_h) and (zone_h < 50) then
    log(string.format("--- not enough height, force minimal spaces"))
    dy = 10
  end

  --log(string.format("timer_info: timer_info_x:%d, timer_info_h: %d", timer_info_w, timer_info_h))
  --log(string.format("x=%d, y=%d, w=%d, h=%d", wgt.zone.x, wgt.zone.y, zone_w, zone_h))
  --log(string.format("dx: %d, dy: %d, zone_w: %d, zone_h: %d, ts_w: %d, ts_h: %d)", dx, dy, zone_w ,zone_h , ts_w, ts_h))

  -- draw timer info
  lcd.drawText(wgt.zone.x, wgt.zone.y, timerInfo, font_size_header + textColor)

  -- draw timer time
  lcd.drawText(wgt.zone.x + dx, wgt.zone.y + dy, time_str, font_size + textColor)

  --lcd.drawText(wgt.zone.x+100, wgt.zone.y, string.format("%d%%", getUsage()), SMLSIZE + CUSTOM_COLOR)
end

return { name="Timer2", options=options, create=create, update=update, background=background, refresh=refresh }

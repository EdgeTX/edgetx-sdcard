-- A Timer version that fill better the widget area
-- Offer Shmuely
-- Date: 2021
-- ver: 0.4

local options = {
  { "TextColor", COLOR, YELLOW },
  { "Timer", VALUE, 1, 1, 3 },
  { "use_days", BOOL, 0 }   -- if greater than 24 hours: 0=still show as hours, 1=use days

}

local function log(s)
  return;
  --print("app: " .. s)
end

local function create(zone, options)
  local wgt = { zone = zone, options = options }
  wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1
  return wgt
end

local function update(wgt, options)
  if (wgt == nil) then
    return
  end
  wgt.options = options
  --print("TimerNumB:" .. options.Timer)
end

local function background(wgt)
  return
end

------------------------------------------------------------

local function formatTime(wgt, t1)
  local dd_raw = t1.value / 86400 -- 24*3600
  local dd = math.floor(dd_raw)
  local hh_raw = (dd_raw - dd) * 24
  local hh = math.floor(hh_raw)
  local mm_raw = (hh_raw - hh) * 60
  local mm = math.floor(mm_raw)
  local ss_raw = (mm_raw - mm) * 60
  local ss = math.floor(ss_raw)
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
  --print("test: " .. time_str)
  return time_str
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
  local w,h = lcd.sizeText(txt, XXLSIZE)
  log(string.format("XXLSIZE w: %d, h: %d, %s", w,h, time_str))
  if w < wgt.zone.w and h < wgt.zone.h then
    return XXLSIZE
  end

  w,h = lcd.sizeText(txt, DBLSIZE)
  log(string.format("DBLSIZE w: %d, h: %d, %s", w,h, time_str))
  if w < wgt.zone.w and h < wgt.zone.h then
    return DBLSIZE
  end

  w,h = lcd.sizeText(txt, MIDSIZE)
  log(string.format("MIDSIZE w: %d, h: %d, %s", w,h, time_str))
  if w < wgt.zone.w and h < wgt.zone.h then
    return MIDSIZE
  end

  log(string.format("SMLSIZE w: %d, h: %d, %s", w,h, time_str))
  return SMLSIZE
end

local function refresh(wgt, event, touchState)
  if (wgt == nil)               then print("refresh(nil)")                   return end
  if (wgt.options == nil)       then print("refresh(wgt.options=nil)")       return end
  if (wgt.options.Timer == nil) then print("refresh(wgt.options.Timer=nil)") return  end

  lcd.setColor(CUSTOM_COLOR, wgt.options.TextColor)

  local t1 = model.getTimer(wgt.options.Timer-1)

  local timerInfo = getTimerHeader(wgt, t1)
  lcd.drawText(wgt.zone.x, wgt.zone.y, timerInfo, SMLSIZE + CUSTOM_COLOR)
  local time_str = formatTime(wgt, t1)
  local font_size = getFontSize(wgt, time_str)
  local zone_w = wgt.zone.w
  local zone_h = wgt.zone.h
  if (event ~= nil) then
    -- full screen
    font_size = XXLSIZE
    zone_w = 320
    zone_h = 480
  end

  log(string.format("x=%d, y=%d, w=%d, h=%d", wgt.zone.x, wgt.zone.y, zone_w, zone_h))

  w,h = lcd.sizeText(time_str, font_size)
  local dx = (zone_w - w) /2
  local dy = (zone_h - h) /2
  log(string.format("dx: %d, dy: %d, zone_w: %d, w: %d)", dx, dy, zone_w , w))
  lcd.drawText(wgt.zone.x + dx, wgt.zone.y + dy, time_str, font_size + CUSTOM_COLOR)

end

return { name = "Timer2", options = options, create = create, update = update, background = background, refresh = refresh }

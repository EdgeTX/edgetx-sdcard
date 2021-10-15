-- A Timer version that fill better the widget area
-- Offer Shmuely
-- Date: 2021
-- ver: 0.4

local options = {
  { "TextColor", COLOR, YELLOW },
  { "Timer", VALUE, 1, 1, 3},
  { "use_days", BOOL, 0 }   -- if greater than 24 hours: 0=still show as hours, 1=use days

}

local function create(zone, options)
  local wgt  = { zone=zone, options=options}
  wgt.options.use_days = wgt.options.use_days % 2 -- modulo due to bug that cause the value to be other than 0|1
  return wgt
end

local function update(wgt, options)
  if (wgt == nil) then return end
  wgt.options = options
  --print("TimerNumB:" .. options.Timer)
end

local function background(wgt)
  return
end

------------------------------------------------------------

local function formatTime(wgt, t1)
  local dd_raw = t1.value/86400 -- 24*3600
  local dd = math.floor(dd_raw)
  local hh_raw = (dd_raw - dd) * 24
  local hh = math.floor(hh_raw)
  local mm_raw = (hh_raw - hh) * 60
  local mm = math.floor(mm_raw)
  local ss_raw = (mm_raw - mm) * 60
  local ss = math.floor(ss_raw)
  if dd ==0 and hh ==0 then
    -- less then 1 hour, 59:59
    time_str = string.format("%02d:%02d",mm, ss)
  elseif dd == 0 then
    -- lass then 24 hours, 23:59:59
    time_str = string.format("%02d:%02d:%02d",hh, mm, ss)
  else
    -- more than 24 hours

    if wgt.options.use_days == 0 then
      -- 25:59:59
      time_str = string.format("%02d:%02d:%02d",dd*24 + hh, mm, ss)
    else
      -- 5d 23:59:59
      time_str = string.format("%dd %02d:%02d:%02d",dd, hh, mm, ss)
    end


  end
  --print("test: " .. time_str)
  return time_str
end

local function getTimerHeader(wgt, t1)
  local timerInfo = ""
  if (string.len(t1.name) ==0) then
    timerInfo = string.format("T%s: ", wgt.options.Timer)
  else
    timerInfo = string.format("T%s: (%s)", wgt.options.Timer, t1.name)
  end
  return timerInfo
end

local function refreshZoneTiny(wgt)
  local t1 = model.getTimer(wgt.options.Timer-1)
  local timerInfo = string.format("-- T%s --", wgt.options.Timer)
  lcd.drawText(wgt.zone.x+16, wgt.zone.y, timerInfo, SMLSIZE + CUSTOM_COLOR)
  lcd.drawTimer(wgt.zone.x+6, wgt.zone.y+12, t1.value, MIDSIZE + CUSTOM_COLOR)
  return
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
  local t1 = model.getTimer(wgt.options.Timer-1)
  local timerInfo = getTimerHeader(wgt, t1)
  lcd.drawText(wgt.zone.x, wgt.zone.y, timerInfo, SMLSIZE + CUSTOM_COLOR)

  local time_str = formatTime(wgt, t1)
  local font_size = DBLSIZE
  if (string.len(time_str) > 9) then
    font_size = MIDSIZE
  end
  lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y, time_str, font_size + CUSTOM_COLOR + RIGHT)
  return
end

--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
  local t1 = model.getTimer(wgt.options.Timer-1)

  local timerInfo = getTimerHeader(wgt, t1)
  lcd.drawText (wgt.zone.x, wgt.zone.y, timerInfo, SMLSIZE + CUSTOM_COLOR)

  local time_str = formatTime(wgt, t1)
  local font_size = XXLSIZE
  if (string.len(time_str) > 9) then
    font_size = MIDSIZE
  elseif string.len(time_str) > 5 then
    font_size = DBLSIZE
  end
  lcd.drawText(wgt.zone.x, wgt.zone.y+15, time_str, font_size + CUSTOM_COLOR)
end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
  refreshZoneMedium(wgt)
end

--- Zone size: 390x172 1/1
--- Zone size: 460x252 1/1 (no sliders/trim/topbar)
local function refreshZoneXLarge(wgt)
  local x = wgt.zone.x
  local w = wgt.zone.w
  local y = wgt.zone.y
  local h = wgt.zone.h

  local t1 = model.getTimer(wgt.options.Timer-1)
  --print(t1.value)
  local timerInfo = getTimerHeader(wgt, t1)
  lcd.drawText(x, y, timerInfo, SMLSIZE + CUSTOM_COLOR)

  local time_str = formatTime(wgt, t1)
  lcd.drawText(x, y+15, time_str, XXLSIZE + CUSTOM_COLOR)
end


--- Zone size: 460x252 (full screen app mode)
local function refreshFullScreen(wgt, event, touchState)
  local x = 0
  local w = 460
  local y = 0
  local h = 252
  
  local t1 = model.getTimer(wgt.options.Timer-1)
  --print(t1.value)
  local timerInfo = getTimerHeader(wgt, t1)
  lcd.drawText(10, 10, timerInfo, XXLSIZE + CUSTOM_COLOR)
  local time_str = formatTime(wgt, t1)
  lcd.drawText(120, 100, time_str, XXLSIZE + CUSTOM_COLOR)
end

local function refresh(wgt, event, touchState)

  if (wgt==nil) then
    print("refresh(nil)")
    return
  end

  if (wgt.options==nil) then
    print("refresh(wgt.options=nil)")
    return
  end

  if (wgt.options.Timer==nil) then
    print("refresh(wgt.options.Timer=nil)")
    return
  end

  lcd.setColor(CUSTOM_COLOR, wgt.options.TextColor)

  if (event ~= nil) then
    refreshFullScreen(wgt, event, touchState)
  elseif wgt.zone.w  > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
  elseif wgt.zone.w  > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
  elseif wgt.zone.w  > 170 and wgt.zone.h >  65 then refreshZoneMedium(wgt)
  elseif wgt.zone.w  > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
  elseif wgt.zone.w  >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
  end
end

return { name="Timer2", options=options, create=create, update=update, background=background, refresh=refresh }

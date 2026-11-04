-- Set to true to also drive the LEDs of custom switches that are set to NONE
local USE_FULL_STRIP = false

local NUM_LEDS = LED_STRIP_LENGTH
if not USE_FULL_STRIP and (BLING_LED_STRIP_LENGTH or 0) > 0 then
  NUM_LEDS = BLING_LED_STRIP_LENGTH
end

local function init()
  scroll_oldtime = getTime()
  scroll_cycle = NUM_LEDS - 1
end

local function run()
  for i=0, NUM_LEDS - 1, 1
  do
    if (i == scroll_cycle) then
      setRGBLedColor(i, 0, 50, 0)
    else
      setRGBLedColor(i, 0, 0, 50)
    end
  end
  if ((getTime() - scroll_oldtime) > 8) then
    scroll_oldtime = getTime()
    scroll_cycle = scroll_cycle - 1
    if (scroll_cycle < 0) then
      scroll_cycle = NUM_LEDS - 1
    end
  end
  applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

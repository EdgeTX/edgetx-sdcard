-- Set to true to also drive the LEDs of custom switches that are set to NONE
local USE_FULL_STRIP = false

local NUM_LEDS = LED_STRIP_LENGTH
if not USE_FULL_STRIP and (BLING_LED_STRIP_LENGTH or 0) > 0 then
  NUM_LEDS = BLING_LED_STRIP_LENGTH
end

local function init()
end

local function run()
    for i=0, NUM_LEDS - 1, 1
    do
        setRGBLedColor(i, 255, 100, 0)  -- Change RGB values to represent orange color
    end
    applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

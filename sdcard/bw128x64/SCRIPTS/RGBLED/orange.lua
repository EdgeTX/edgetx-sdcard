local function init()
end

local function run()
    for i=0, LED_STRIP_LENGTH - 1, 1
    do
        setRGBLedColor(i, 255, 100, 0)  -- Change RGB values to represent orange color
    end
    applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

local function init()
end

local function run()
  for i=0, LED_STRIP_LENGTH - 1, 1
  do
    setRGBLedColor(i, 0, 0, 0)
  end
  applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

local function init()
    police_oldtime = getTime()
    police_cycle = 0
end

local function run()
  for i=0, LED_STRIP_LENGTH - 1, 1
  do
    if (i % 2 == police_cycle) then
        setRGBLedColor(i, 0, 0, 50)
    else
        setRGBLedColor(i, 50, 0, 0)
    end
  end
  if ((getTime() - police_oldtime) > 8) then
    police_oldtime = getTime()
    police_cycle = 1 - police_cycle
  end
  applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

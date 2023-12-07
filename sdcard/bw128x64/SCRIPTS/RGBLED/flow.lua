local function init()
    colorChangeTime = getTime()  -- Initialize time
    phase = 0
end

-- Function to generate smooth cyclic colors
local function getColor(phase, length)
    local position = (phase % length) / length
    local r, g, b = 30, 30, 30
    local maxBrightness = 50  -- Maximum brightness value

    -- RGB color transition: red -> green -> blue -> red
    if position < 1/3 then
        -- From red to green
        r = maxBrightness * (1 - 3 * position)
        g = maxBrightness * (3 * position)
    elseif position < 2/3 then
        -- From green to blue
        position = position - 1/3
        g = maxBrightness * (1 - 3 * position)
        b = maxBrightness * (3 * position)
    else
        -- From blue to red
        position = position - 2/3
        b = maxBrightness * (1 - 3 * position)
        r = maxBrightness * (3 * position)
    end

    return math.max(0, math.min(r, maxBrightness)), math.max(0, math.min(g, maxBrightness)), math.max(0, math.min(b, maxBrightness))
end

local function run()
    if ((getTime() - colorChangeTime) > 16) then  -- Increase the time interval to 16 time units
        colorChangeTime = getTime()
        phase = phase + 1  -- Update color phase
    end

    for i = 0, LED_STRIP_LENGTH - 1, 1 do
        local r, g, b = getColor(phase, 255)
        setRGBLedColor(i, r, g, b)
    end
    applyRGBLedColors()
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

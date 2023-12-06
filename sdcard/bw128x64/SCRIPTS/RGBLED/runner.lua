local function init()
    colorChangeTime = getTime()  -- Initialize time
    phase = 0
    currentLed = 0  -- Current lit LED position
end

-- Function to generate smooth cyclic colors
local function getColor(phase, length)
    local position = (phase % length) / length
    local r, g, b = 5, 5, 5
    local maxBrightness = 50  -- Maximum brightness value
    local minBrightness = 20  -- Minimum brightness value

    -- RGB color transition: red -> green -> blue -> red
    if position < 1/3 then
        -- From red to green
        r = minBrightness + (maxBrightness - minBrightness) * (1 - 3 * position)
        g = minBrightness + (maxBrightness - minBrightness) * (3 * position)
        b = minBrightness
    elseif position < 2/3 then
        -- From green to blue
        position = position - 1/3
        g = minBrightness + (maxBrightness - minBrightness) * (1 - 3 * position)
        b = minBrightness + (maxBrightness - minBrightness) * (3 * position)
        r = minBrightness
    else
        -- From blue to red
        position = position - 2/3
        b = minBrightness + (maxBrightness - minBrightness) * (1 - 3 * position)
        r = minBrightness + (maxBrightness - minBrightness) * (3 * position)
        g = minBrightness
    end

    return math.max(0, math.min(r, maxBrightness)), math.max(0, math.min(g, maxBrightness)), math.max(0, math.min(b, maxBrightness))
end

local function run()
    if ((getTime() - colorChangeTime) > 4) then  -- Use an interval of 4 time units
        colorChangeTime = getTime()
        phase = phase + 1  -- Update color phase
        currentLed = (currentLed + 1) % LED_STRIP_LENGTH  -- Move to the next LED
    end

    for i = 0, LED_STRIP_LENGTH - 1, 1 do
        if i <= currentLed then
            local r, g, b = getColor(phase, 255)
            setRGBLedColor(i, r, g, b)
        else
            setRGBLedColor(i, 0, 0, 0)  -- Keep unlit LEDs off
        end
    end
    applyRGBLedColors()
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
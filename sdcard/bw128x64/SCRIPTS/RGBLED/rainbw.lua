local function init()
    colorChangeTime = getTime()  -- Initialize time
    phase = 0
end

local minBrightness = 0  -- Minimum brightness value
local maxBrightness = 255  -- Maximum brightness value

local function getColor(phase, length)
    local position = (phase % length) / length
    local r, g, b = minBrightness, minBrightness, minBrightness

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

    return r, g, b
end

local colorChangeTime = 0  -- The time of the last color change

local function run()
    if ((getTime() - colorChangeTime) > 2) then  -- Use an interval of 4 time units
        colorChangeTime = getTime()
        phase = (phase + 1) % 255  -- Update color phase

        for i = 0, LED_STRIP_LENGTH - 1, 1 do
            local r, g, b = getColor(phase + i * 64, 255)  -- Increase phase offset for each LED
            setRGBLedColor(i, r, g, b)
        end
        applyRGBLedColors()
    end
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
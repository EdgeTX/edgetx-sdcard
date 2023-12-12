local function init()
    colorChangeTime = getTime()  -- Initialize time
    phase = 0
    currentLed = 0  -- Current lit LED position
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

local maxBackgroundBrightness = 255  -- Maximum brightness value for the background

local function run()
    if ((getTime() - colorChangeTime) > 2) then  -- Use an interval of 4 time units
        colorChangeTime = getTime()
        phase = phase + 1  -- Update color phase
        currentLed = (currentLed + 1) % LED_STRIP_LENGTH  -- Move to the next LED
    end

    for i = 0, LED_STRIP_LENGTH - 1, 1 do
        local r, g, b = getColor(phase, 255)
        if i <= currentLed then
            setRGBLedColor(i, r, g, b)
        else
            -- Set the background color to the opposite of the main color in the RGB color space
            local bg_r = (r + 128) % 256
            local bg_g = (g + 128) % 256
            local bg_b = (b + 128) % 256

            -- Ensure the brightness of the background color does not exceed 72
            bg_r = math.min(bg_r, maxBackgroundBrightness)
            bg_g = math.min(bg_g, maxBackgroundBrightness)
            bg_b = math.min(bg_b, maxBackgroundBrightness)

            -- Ensure at least one color channel is always off
            if bg_r > bg_g and bg_r > bg_b then
                bg_r = 0
            elseif bg_g > bg_r and bg_g > bg_b then
                bg_g = 0
            else
                bg_b = 0
            end

            setRGBLedColor(i, bg_r, bg_g, bg_b)
        end
    end
    applyRGBLedColors()
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
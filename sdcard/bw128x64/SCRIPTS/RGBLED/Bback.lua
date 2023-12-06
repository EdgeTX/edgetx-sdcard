local function init()
    colorChangeTime = getTime()  -- Initialize time
    phase = 0
    currentLed = 0  -- Current lit LED position
    scroll_oldtime = getTime()  -- Initialize scroll_oldtime
    scroll_cycle = 0  -- Initialize scroll_cycle
end

-- Function to generate smooth cyclic colors
local function getColor(phase, length)
    local position = (phase % length) / length
    local r, g, b = 0, 0, 0
    local maxBrightness = 255  -- Maximum brightness value

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

local colorPhase = 0  -- Initialize color phase

local function run()
    for i=LED_STRIP_LENGTH - 1, 0, -1 do  -- Reverse iteration
        if (i == scroll_cycle) then
            local r, g, b = getColor(colorPhase, 255)
            setRGBLedColor(i, r, g, b)
        else
            setRGBLedColor(i, 0, 0, 50)
        end
    end
    if ((getTime() - scroll_oldtime) > 8) then
        scroll_oldtime = getTime()
        scroll_cycle = scroll_cycle - 1  -- Decrement scroll_cycle
        if (scroll_cycle < 0) then
            scroll_cycle = LED_STRIP_LENGTH - 1  -- Reset scroll_cycle to the end of the strip
        end
    end
    colorPhase = (colorPhase + 1) % 255  -- Update color phase
    applyRGBLedColors()
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
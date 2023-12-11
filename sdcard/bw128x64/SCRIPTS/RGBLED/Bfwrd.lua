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

    -- Skip colors that are close to the background color
    local bg_r, bg_g, bg_b = 0, 0, 72  -- Background color
    local threshold = 30  -- Color difference threshold
    if math.abs(r - bg_r) < threshold and math.abs(g - bg_g) < threshold and math.abs(b - bg_b) < threshold then
        return getColor((phase + 1) % length, length)  -- Skip this color and get the next one
    end

    return r, g, b
end

local colorPhase = 0  -- Initialize color phase

local function run()
    for i=0, LED_STRIP_LENGTH - 1, 1 do
        if (i == scroll_cycle) then
            local r, g, b = getColor(colorPhase, 255)
            setRGBLedColor(i, r, g, b)
        else
            setRGBLedColor(i, 0, 0, 72)
        end
    end
    if ((getTime() - scroll_oldtime) > 8) then
        scroll_oldtime = getTime()
        scroll_cycle = scroll_cycle + 1
        if (scroll_cycle >= LED_STRIP_LENGTH) then
            scroll_cycle = 0
        end
    end
    colorPhase = (colorPhase + 1) % 255  -- Update color phase
    applyRGBLedColors()
end

local function background()
    -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
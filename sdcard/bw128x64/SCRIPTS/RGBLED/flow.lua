local function init()
    colorChangeTime = getTime()  -- 初始化时间
    phase = 0
end

-- 生成平滑循环颜色的函数
local function getColor(phase, length)
    local position = (phase % length) / length
    local r, g, b = 30, 30, 30
    local maxBrightness = 50  -- 最大亮度值

    -- RGB颜色过渡：红 -> 绿 -> 蓝 -> 红
    if position < 1/3 then
        -- 从红到绿
        r = maxBrightness * (1 - 3 * position)
        g = maxBrightness * (3 * position)
    elseif position < 2/3 then
        -- 从绿到蓝
        position = position - 1/3
        g = maxBrightness * (1 - 3 * position)
        b = maxBrightness * (3 * position)
    else
        -- 从蓝到红
        position = position - 2/3
        b = maxBrightness * (1 - 3 * position)
        r = maxBrightness * (3 * position)
    end

    return math.max(0, math.min(r, maxBrightness)), math.max(0, math.min(g, maxBrightness)), math.max(0, math.min(b, maxBrightness))
end

local function run()
    if ((getTime() - colorChangeTime) > 16) then  -- 将时间间隔增加到16个时间单位
        colorChangeTime = getTime()
        phase = phase + 1  -- 更新颜色相位
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

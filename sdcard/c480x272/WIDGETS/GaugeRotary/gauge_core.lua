local HighAsGreen, p2 = ...

local self = {}
self.HighAsGreen = HighAsGreen

--------------------------------------------------------------
local function log(s)
    --return;
    print("Gauge_core: " .. s)
end
--------------------------------------------------------------

function self.drawArm(armX, armY, armR, percentageValue, color, isFull)
    --min = 5.54
    --max = 0.8

    local degrees
    if isFull then
        degrees = 5.51 - (4.74 * percentageValue / 100)
    else
        --degrees = 4.74 - (3.14 * percentageValue / 100)
        degrees = 5.05 - (3.84 * percentageValue / 100)
    end

    --log("percentageValue: " .. percentageValue .. ", degrees: " .. degrees)
    local xh = math.floor(armX + (math.sin(degrees) * armR))
    local yh = math.floor(armY + (math.cos(degrees) * armR))

    --lcd.setColor(CUSTOM_COLOR, lcd.RGB(0, 0, 255))
    --lcd.setColor(CUSTOM_COLOR, lcd.RGB(255, 255, 255))
    lcd.setColor(CUSTOM_COLOR, color)

    local x1 = math.floor(armX - (math.sin(0) * (20 / 2.3)))
    local y1 = math.floor(armY - (math.cos(0) * (20 / 2.3)))
    local x2 = math.floor(armX - (math.sin(3) * (20 / 2.3)))
    local y2 = math.floor(armY - (math.cos(3) * (20 / 2.3)))
    lcd.drawFilledTriangle(x1, y1, x2, y2, xh, yh, CUSTOM_COLOR)
end

-- This function returns green at gvalue, red at rvalue and graduate in between
function self.getRangeColor(value, red_value, green_value)
    local range = math.abs(green_value - red_value)
    if range == 0 then
        return lcd.RGB(0, 0xdf, 0)
    end
    if value == nil then
        return lcd.RGB(0, 0xdf, 0)
    end

    if green_value > red_value then
        if value > green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value < red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        g = math.floor(0xdf * (value - red_value) / range)
        r = 0xdf - g
        return lcd.RGB(r, g, 0)
    else
        if value < green_value then
            return lcd.RGB(0, 0xdf, 0)
        end
        if value > red_value then
            return lcd.RGB(0xdf, 0, 0)
        end
        r = math.floor(0xdf * (value - green_value) / range)
        g = 0xdf - r
        return lcd.RGB(r, g, 0)
    end
end

function self.drawGauge(centerX, centerY, centerR, isFull, percentageValue, percentageValueMin, percentageValueMax, txt1, value_fmt_min, value_fmt_max, txt2)
    if value_fmt_min == nil then
        value_fmt_min = ""
    end
    if value_fmt_max == nil then
        value_fmt_max = ""
    end
    if txt1 == nil then
        txt1 = ""
    end
    if txt2 == nil then
        txt2 = ""
    end

    local fender = 4
    local tickWidth = 9
    local armCenterR = centerR / 2.5
    local armR = centerR - 8
    local txtSize = DBLSIZE
    if centerR < 65 then
        txtSize = MIDSIZE
    end
    if centerR < 30 then
        txtSize = SMLSIZE
    end

    -- main gauge background
    if isFull then
        lcd.drawFilledCircle(centerX, centerY, centerR, lcd.RGB(0x1A1A1A))
    else
        lcd.drawPie(centerX, centerY, centerR, -110, 110, lcd.RGB(0x1A1A1A))
    end

    -- fender
    if isFull then
        lcd.drawAnnulus(centerX, centerY, centerR - fender, centerR, 0, 360, BLACK)
    else
        lcd.drawAnnulus(centerX, centerY, centerR - fender, centerR, -110, 110, BLACK)
    end

    -- ticks
    local to_tick
    local tick_offset
    local tick_step = 10
    if isFull then
        to_tick = 210
        tick_offset = 250
    else
        to_tick = 210
        tick_offset = 250
    end
    if (centerR < 100) then
        tick_step = 10 + 0.15 * (100 - centerR)
    end
    for i = 0, to_tick, tick_step do
        --log("HighAsGreen: " .. self.HighAsGreen)
        if (self.HighAsGreen == 1) then
            local newColor = self.getRangeColor(i, 0, to_tick - 10)
            lcd.setColor(CUSTOM_COLOR, newColor)
            --lcd.setColor(CUSTOM_COLOR, self.getRangeColor(i, 0, to_tick - 10))
        else
            lcd.setColor(CUSTOM_COLOR, self.getRangeColor(i, to_tick - 10, 0))
            --lcd.setColor(CUSTOM_COLOR, self.getRangeColor(i, 120 , 30))
        end
        lcd.drawAnnulus(centerX, centerY, centerR - fender - 3 - tickWidth, centerR - fender - 3, tick_offset + i, tick_offset + i + 7, CUSTOM_COLOR)
        --lcd.drawAnnulus(centerX, centerY, centerR -fender -3 -tickWidth,     centerR -fender -3 , 250 +i, 250 +i +7, YELLOW)
        --lcd.drawAnnulus(centerX, centerY, centerR -fender -3 -tickWidth -15, centerR -fender -3 -tickWidth -4 , 250 +i, 250 +i +7, RED)
    end
    --lcd.drawPie(centerX,centerY,centerR - fender, 0,20)

    local armColor = lcd.RGB(255, 255, 255)
    local armColorMin, armColorMax
    if (self.HighAsGreen == 1) then
        armColorMin = lcd.RGB(200, 0, 0)
        armColorMax = lcd.RGB(0, 200, 0)
    else
        armColorMin = lcd.RGB(0, 200, 0)
        armColorMax = lcd.RGB(200, 0, 0)
    end

    --self.drawArm(centerX, centerY, armR, 0, armColorMin, isFull)
    --self.drawArm(centerX, centerY, armR, 10, armColorMin, isFull)
    --self.drawArm(centerX, centerY, armR, 50, armColorMin, isFull)
    --self.drawArm(centerX, centerY, armR, 90, armColorMin, isFull)
    --self.drawArm(centerX, centerY, armR, 100, armColorMin, isFull)

    if percentageValueMin ~= nil and percentageValueMax ~= nil then
        self.drawArm(centerX, centerY, armR, percentageValueMin, armColorMin, isFull)
        self.drawArm(centerX, centerY, armR, percentageValueMax, armColorMax, isFull)
    end
    self.drawArm(centerX, centerY, armR, percentageValue, armColor, isFull)

    -- hide the base of the arm
    lcd.drawFilledCircle(centerX, centerY, armCenterR, BLACK)
    lcd.drawAnnulus(centerX, centerY, armCenterR - 2, armCenterR, 0, 360,
    --lcd.RGB(255, 255, 0)
        lcd.RGB(192, 192, 192)
    )

    -- text in center
    lcd.drawText(centerX + 0, centerY - 8, txt2, CENTER + SMLSIZE + WHITE) -- XXLSIZE/DBLSIZE/MIDSIZE/SMLSIZE

    lcd.drawText(centerX - armCenterR - 12, centerY + 20, value_fmt_min, CENTER + SMLSIZE + WHITE)
    lcd.drawText(centerX + armCenterR + 12, centerY + 20, value_fmt_max, CENTER + SMLSIZE + WHITE)

    -- text below
    if isFull then
        --lcd.drawText(centerX + 8, centerY + 30, txt1, CENTER + txtSize + WHITE)
        lcd.drawText(centerX + 0, centerY + armCenterR + 2, txt1, CENTER + txtSize + WHITE)
    else
        -- no text below in flat mode
    end

end

return self
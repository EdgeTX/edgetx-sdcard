local wgt = ...

-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local space = 10

local function log(fmt, ...)
    wgt.log(fmt, ...)
end

local function getMainValue()
    return string.format("%2.2fV", wgt.mainValue)
end

local function getVPercent()
    return string.format("%2.0f%%", wgt.vPercent)
end

local function getSecondaryValue()
    -- return string.format("%2.2fV   %dS", wgt.secondaryValue, wgt.cellCount)
    return string.format("%2.2fV", wgt.secondaryValue)
end

local function getCellCount()
    return string.format("%dS", wgt.cellCount)
end

local function getSecondaryValueCell()
    return string.format("%2.2fV   %dS", wgt.secondaryValue, wgt.cellCount)
end

local function getVMin()
    return string.format("min %2.2fV", wgt.vMin)
end

local function getTxtColor()
    return wgt.text_color
end

local function getVPercentColor()
    return (wgt.vPercent < 30) and RED or wgt.text_color
end

local function getFillColor()
    return wgt.getPercentColor(wgt.vPercent)
end

local function calcBattSize()
    local x = wgt.zone.x + space
    local y = wgt.zone.y + space
    local w = 0
    local h = wgt.zone.h - 2*space
    if (h > 110) then
        w = math.floor(h * 0.50)
    elseif (h > 80) then
        w = math.floor(h * 0.60)
    else
        w = math.floor(h * 0.80)
    end
    return x, y, w, h
end

local function layoutBatt()
    local bx, by , bw, bh = calcBattSize()

    -- terminal size
    local th1 = math.floor(bh*0.04)
    local th2 = math.floor(bh*0.05)
    local th = th1+th2
    local tw1 = bw / 2 * 0.8
    local tw2 = bw / 2
    local tx1 = bx + (bw - tw1) / 2
    local tx2 = bx + (bw - tw2) / 2

    -- box size
    local bbx = bx
    local bby = by + th
    local bbw = bw
    local bbh = bh - th
    local fill_space = 3

    local shd = (bh>120) and 3 or ((bh>120) and 2 or 1) -- shaddow
    local isNeedShaddow = (bh>80) and true or false

    lvgl.build({
        -- plus terminal
        {type="rectangle", x=tx1, y=bby-th   , w=tw1, h=th1*2, color=WHITE, filled=true, rounded=5},
        {type="rectangle", x=tx2, y=bby-th2  , w=tw2, h=th2  , color=WHITE, filled=true, rounded=5},
        {type="rectangle", x=tx2, y=bby-th2/2, w=tw2, h=th2/2, color=WHITE, filled=true, rounded=0},

        -- battery outline shaddow
        {type="rectangle", x=bx+2, y=bby+3, w=bbw, h=bbh, thickness=3, rounded=bw*0.1,     color=GREY, visible=function() return isNeedShaddow end},

        {type="box", x=bx, y=bby, w=bbw, h=bbh,
            children={

                -- fill batt
                {type="rectangle", filled=true, color=getFillColor, rounded=bw*0.1,
                    pos =(function() return fill_space+1, fill_space +1 + bbh - math.floor(wgt.vPercent / 100 * bbh) end),
                    size=(function() return bbw-2*fill_space, math.floor(wgt.vPercent / 100 * bbh)-2*fill_space end)
                },

                -- battery segments shaddow
                {type="rectangle", x=1+2, y=0 + (1 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (2 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (3 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},
                {type="rectangle", x=1+2, y=0 + (4 * bbh / 5)+shd, w=bbw-2, h=2, filled=true, color=GREY, visible=function() return isNeedShaddow end},

                -- battery segments
                {type="rectangle", x=1,   y=(1 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(2 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(3 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},
                {type="rectangle", x=1,   y=(4 * bbh / 5)    , w=bbw-2, h=1, thickness=1, color=WHITE},

                -- battery outline
                {type="rectangle", x=0, y=0, w=bbw, h=bbh, thickness=2,color=WHITE, rounded=bw*0.1},

                -- debug area
                -- {type="label", x=tx2-10, y=bby+10, color=BLUE, font=FS.FONT_8, text=function() return string.format("round=%s", bw*0.1) end},
                -- {type="rectangle", x=bx, y=by, w=bw, h=bh,color=BLUE},
            }
        }
    })


    local batSize = {
        x = bx,
        y = by,
        w = bw,
        h = bh,
        xw = bx + bw,
        yh = by + bh,
    }
    return batSize
end

--- Zone size: 70x39 top bar
local function layoutZoneTopbar()
    local bx = wgt.zone.w - 20
    local by = 2
    local bw = 18
    local bh = wgt.zone.h - 4

    local lytTxt = {
        -- battery values
        {type="label", x=0, y=20, w=bx - 3, font=FS.FONT_6+RIGHT, text=getMainValue,
            -- color=(function() return (wgt.vPercent < 30) and RED or wgt.text_color end)
            color=getTxtColor
        },
        {type="label", x=0, y=5, w=bx - 3, font=FS.FONT_6+RIGHT, text=getVPercent, color=getTxtColor},

        -- plus terminal
        {type="rectangle", x=bx+4, y=by-6, w=bw-8, h=6, filled=true, color=function() return (wgt.vPercent < 30) and RED or getTxtColor() end},

        -- fill batt
        {type="rectangle", x=bx, y=by, w=bw, h=0, filled=true, color=getFillColor,
            size=(function() return bw, math.floor(wgt.vPercent / 100 * (bh)) end),
            pos=(function() return bx, by + bh - math.floor(wgt.vPercent / 100 * (bh)) end)},

        -- battery outline
        {type="rectangle", x=bx, y=by, w=bw, h=bh, thickness=2, color=function() return (wgt.vPercent < 30) and RED or getTxtColor() end},
    }

    lvgl.build(lytTxt)
end

local function layoutTextZoneNormal(batSize)
    local next_y = space
    local left_w = wgt.zone.w-(batSize.w +10)
    local left_h = wgt.zone.h

    local txtSizes = {
        vMain = {x=nil,y=nil, font=nil},
        percent = {},
        source = {},
        vSec = {},
        cellCount = {},
        vMin = {},
    }

    local fSizeMainV, w, h, v_offset = wgt.tools.getFontSize(wgt, "99.99 V", left_w, left_h, FS.FONT_38)
    txtSizes.vMain = {x=batSize.xw +10, y=next_y +v_offset, font=fSizeMainV}

    next_y = next_y + h + 10
    left_h = wgt.zone.h - next_y

    local fSizePercent, w, h, v_offset = wgt.tools.getFontSize(wgt, "100 %", left_w, left_h, fSizeMainV)
    txtSizes.percent = {x=batSize.xw +12, y=next_y +v_offset, font=fSizePercent}
    next_y = next_y + h + 10
    left_h = wgt.zone.h - next_y


    local max_w = 0
    local sec_x = LCD_W
    local sec_font = FS.FONT_16
    local sec_dh = 0
    local line_space = 5

    sec_font = wgt.tools.getFontSize(wgt, "AAA", left_w - batSize.w, left_h/3, FS.FONT_16)


    -- source
    local ts_w, ts_h, v_offset = wgt.tools.lcdSizeTextFixed(wgt.source_name, sec_font)
    sec_dh = ts_h + 5
    line_space = ts_h * 0
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.source = {y=wgt.zone.h +v_offset -space +line_space -sec_dh*3, visible=(function() return wgt.options.isTotalVoltage == 0 end)}


    -- vSec + cell count
    local ts_w, ts_h, v_offset = wgt.tools.lcdSizeTextFixed("99.99 V  12s", sec_font)
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.vSec = {y=wgt.zone.h +v_offset  -space +line_space -sec_dh*2, visible=(function() return wgt.options.isTotalVoltage == 0 end)}

    -- vMin
    local ts_w, ts_h, v_offset = wgt.tools.lcdSizeTextFixed(getVMin(), sec_font)
    sec_x = math.min(sec_x, wgt.zone.w -ts_w -space)
    txtSizes.vMin = {y=wgt.zone.h +v_offset -space +line_space -sec_dh*1, visible = false}


    local lytTxt = {
        -- main value
        {type="label", x=txtSizes.vMain.x, y=txtSizes.vMain.y, font=txtSizes.vMain.font, text=getMainValue, color=getTxtColor},
        {type="label", x=txtSizes.percent.x, y=txtSizes.percent.y, font=txtSizes.percent.font, text=getVPercent, color=getTxtColor},
        -- -- source name
        -- {type="label", x=sec_x, y=txtSizes.source.y, font=sec_font, text=wgt.source_name, color=getTxtColor, visible=txtSizes.source.visible},
        {type="label", x=sec_x, y=txtSizes.source.y, font=sec_font, text=wgt.source_name, color=getTxtColor}, -- , visible=txtSizes.vSec.visible
        -- secondary value & cells
        {type="label", x=sec_x, y=txtSizes.vSec.y, font=sec_font, text=getSecondaryValueCell, color=getTxtColor}, -- , visible=txtSizes.vSec.visible
        -- min voltage
        {type="label", x=sec_x, y=txtSizes.vMin.y, font=sec_font, text=getVMin, color=getTxtColor}, -- , visible="false"
    }

    lvgl.build(lytTxt)
end

local function layoutZoneNormal()
    local batSize = layoutBatt()
    layoutTextZoneNormal(batSize)
end

function wgt.refresh(event, touchState)
    wgt.text_color = (wgt.isDataAvailable) and wgt.options.color or GREY
end

function wgt.update_ui()
    lvgl.clear()

    if wgt.zone.w <  75 and wgt.zone.h < 45 then
        layoutZoneTopbar()
    else
        layoutZoneNormal()
    end

end

return wgt

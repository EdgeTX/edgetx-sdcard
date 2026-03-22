local app_name = "Mixers"
local app_ver = "1.0"

local M = {}

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

--------------------------------------------------------------
local function log(fmt, ...)
    print(string.format("[%s] "..fmt, app_name, ...))
end
--------------------------------------------------------------

local function background(wgt)
    for i = 1, 16 do
        wgt.values[i] = getValue("ch" .. i)
        wgt.names[i] = model.getOutput(i-1).name
        wgt.percent[i] = math.floor(100 * (wgt.values[i]+5) / 1024) -- +3 to remove fluctuations
        -- log("%s. name: %s, val: %s%%", i, wgt.names[i], wgt.values[i], wgt.percent[i])
    end
end

local function build_ui_column(wgt, from_ch, to_ch, zx, zy, zw, zh, headr_text)
    local bZone1 = lvgl.box({x=zx, y=zy, w=zw, h=zh})
    local bZone2 = bZone1:box({x=0, y=20*lvSCALE})
    local bBars = bZone2:box({x=40*lvSCALE, y=0})

    -- title
    bZone1:label({x=40*lvSCALE, y=0, text=headr_text, color=wgt.text_color, font=FS.FONT_6})

    local bar_area_w = zw - 40*lvSCALE

    local line_height = 18*lvSCALE
    local bar_height = line_height - 2

    for i = from_ch, to_ch do
        local yy = line_height * (i-from_ch)
        local x_mid = bar_area_w / 2

        -- text channel
        bZone2:label({x=6, y=yy-1, text=string.format("CH%d", i), color=wgt.text_color, font=FS.FONT_6})

        bBars:box({x=0, y=yy, w=zw, h=zh,
            children={
                -- border
                {type="rectangle", x=0, y=0, w=bar_area_w, h=bar_height, color=(wgt.bar_bkg_enabled and wgt.bar_bkg_color or 0), style=SOLID, filled=true, visible=function() return wgt.bar_bkg_enabled end},

                -- bar
                {type="rectangle", color=wgt.bar_color, style=SOLID, filled=true,
                    pos=function()  return x_mid + math.min(0, wgt.percent[i] * bar_area_w /2/100), 0 end,
                    size=function() return         math.abs(   wgt.percent[i] * bar_area_w /2/100), bar_height end,
                },

                -- border
                -- {type="line", x1=0, y1=yy, x2=0 + bar_area_w, y2=yy, color=BLACK, style=SOLID},

                -- middle mark
                {type="rectangle", x=x_mid-1, y=0, w=1, h=bar_height, color=WHITE, style=SOLID, filled=true},

                -- text output name
                {type="label", x=6, y=-1, text=function() return wgt.names[i] end, color=WHITE, font=FS.FONT_6},

                -- text percent
                {type="label", color=WHITE, font=FS.FONT_6,
                    pos=function()
                        local dx = (wgt.percent[i] > 0) and -37*lvSCALE or 15*lvSCALE
                        return x_mid + dx, -1
                    end,
                    text=function() return string.format("%d%%", wgt.percent[i]) end,
                }

            }
        })
    end
end

local function build_ui(wgt)
    lvgl.rectangle({x=wgt.zone.x, y=wgt.zone.y, w=wgt.zone.w, h=wgt.zone.h, color=wgt.background_color, style=SOLID, filled=true, visible=function() return wgt.background_enabled end})

    if (wgt.zone.w < 320) then
        -- single column
        build_ui_column(wgt, 1, 16, 0,            wgt.zone.y, wgt.zone.w -5,   wgt.zone.h, "Mixers")
    else
        -- two columns
        build_ui_column(wgt, 1, 8,  0,            wgt.zone.y, wgt.zone.w /2 -5, wgt.zone.h, "Mixers 1-8")
        build_ui_column(wgt, 9, 16, wgt.zone.w/2, wgt.zone.y, wgt.zone.w /2 -5, wgt.zone.h, "Mixers 9-16")
    end
end

local function update(wgt, options)
    if (wgt == nil) then return end
    wgt.options = options
    wgt.text_color = options.text_color
    wgt.bar_color = options.bar_color
    wgt.bar_bkg_enabled = (options.bar_bkg_enabled==1)
    wgt.bar_bkg_color = options.bar_bkg_color
    wgt.background_enabled = (options.background_enabled==1)
    wgt.background_color = options.background_color or LIGHTGREY
    background(wgt)
    build_ui(wgt)
    return wgt
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        values = {},
        names = {},
        percent = {},
    }
    return update(wgt, options)
end

local function refresh(wgt)
    background(wgt)
end

return {name=app_name, create=create, update=update, refresh=refresh,  background=background, useLvgl=true}

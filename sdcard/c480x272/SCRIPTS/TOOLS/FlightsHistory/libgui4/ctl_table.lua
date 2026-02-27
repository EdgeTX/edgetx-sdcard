-- Create a text table
-- args:

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)


local function M(panel, id, args, flags)
    assert(args)
    assert(args.header)
    assert(args.lines)
    local self = {
        panel = panel,
        id = id,
        colNum = #args.colX,

        -- args
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        fontSize = args.font or FS.FONT_8,
        fontSizeHeader = args.font_header or FS.FONT_8,
        textColor = args.textColor or WHITE,
        colX = args.colX or args.x,
        header = args.header,
        lines = args.lines,
        maxLinesToShow = (args.maxLines ~= nil) and math.min(args.maxLines, #args.lines) or #args.lines, -- max lines to show
        fIsLineVisible = args.fIsLineVisible or function() return true end,
    }
    -- log("ctl_table [%s] x: %d, y: %d, w: %d, h: %d", id, self.x, self.y, self.w, self.h)

    function self.build_ui()
        local boxCtl = (self.panel~=nil)
            and panel:box({x=self.x, y=self.y, w=self.w, h=self.h})
            or   lvgl.box({x=self.x, y=self.y, w=self.w, h=self.h})

        -- header
        boxCtl:rectangle({x=0, y=0, w=self.w, h=20*lvSCALE, color=DARKGREEN, filled=true})
        for i = 1, self.colNum, 1 do
            boxCtl:label({x=self.colX[i], y=0,   text=self.header[i], color=self.textColor, font=self.fontSizeHeader})
        end

        -- lines
        local bxLines = boxCtl:box({x=0, y=25*lvSCALE, flexFlow=lvgl.FLOW_COLUMN, flexPad=2*lvSCALE})

        for lineIdx = 1, self.maxLinesToShow do
            local obj = self.lines[lineIdx]
            local bxSingleLine = bxLines:box({x=0, y=0, visible=function() return self.fIsLineVisible(obj) end })
            bxSingleLine:button({x=0, y=4*lvSCALE,w=12*lvSCALE,h=12*lvSCALE, cornerRadius=10, color=self.textColor})
            -- bxSingleLine:circle({x=7, y=10, radius=4, filled=true, color=self.textColor})
            for i = 1, self.colNum, 1 do
                -- add single line
                -- log("ctl_table colNum: k: %s, i: %s, = %s", k, i, self.lines[k][i])
                -- log("ctl_table colNum: %sx%s, txt=%s, x=%s, w=%s  %s", k, i, self.lines[k][i], self.colX[i], self.colX[i+1], self.w -self.colX[i])
                bxSingleLine:label({
                    x=self.colX[i],
                    y=0,
                    --w=self.colX[i+1] or (self.w -10 - self.colX[i]),
                    text=obj[i],
                    color=self.textColor,
                    font=self.fontSize
                })
            end
        end


    end

    self.build_ui()
    return self
end

return M

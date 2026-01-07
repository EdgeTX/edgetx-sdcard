-- Create a text table
-- args:

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}


function M(panel, id, args, flags)
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
        w = args.w or 0,
        h = args.h or 0,
        fontSize = args.font or FS.FONT_8,
        colX = args.colX or 0,
        header = args.header,
        lines = args.lines,
        fIsLineVisible = args.fIsLineVisible or function() return true end,
    }
    -- log("ctl_table [%s] x: %d, y: %d, w: %d, h: %d", id, self.x, self.y, self.w, self.h)

    function self.build_ui()
        -- header
        local bxHdr = lvgl.box({x=self.x, y=self.y, w=self.w, h=self.h})
        bxHdr:rectangle({x=0, y=0, w=self.w, h=20, color=DARKGREEN, filled=true})
        for i = 1, self.colNum, 1 do
            bxHdr:label({x=self.colX[i], y=0,   text=self.header[i], color=WHITE, font=FS.FONT_8})
        end

        -- lines
        local bxLines = bxHdr:box({x=self.x, y=25, flexFlow=lvgl.FLOW_COLUMN, flexPad=2})

        for k, obj in pairs(self.lines) do

            local bxSingleLine = bxLines:box({x=0, y=0, visible=function() return self.fIsLineVisible(obj) end })

            bxSingleLine:button({x=0, y=4,w=12,h=12, cornerRadius=10, color=WHITE})
            -- bxSingleLine:circle({x=7, y=10, radius=4, filled=true, color=WHITE})
        local last_x = 0
            for i = 1, self.colNum, 1 do
                -- add single line
                bxSingleLine:label({
                    x=self.colX[i], y=0,
                    w=(self.colX[i+1] or 999)-last_x,
                    text=obj[i],
                    color=WHITE,
                    font=self.fontSize
                })
            end
        end

    end

    self.build_ui()
    return self
end

return M

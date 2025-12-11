local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "beeper_config"

local LP1 = m_utils.line_presets.p1
local LP2 = m_utils.line_presets.p2
local LP3 = m_utils.line_presets.p3
local LP4 = m_utils.line_presets.p4
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 3*line_height + 15*lvSCALE

-- State
local is_beeper = 2  -- 1=No, 2=Yes
local switch_idx = getSourceIndex("SD")  -- -- switch SD source
local beeper_channel = 7  -- default CH7 (AUX3)

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({
        {type="image", x=LCD_W-110, y=0, w=80, h=80, file=function() return PRESET_FOLDER .. "/icon.png" end, visible = function() return use_images end},

        { type="setting", x=LP2.x1, y=0*line_height, w=LCD_W, title="Beeper?",
            children={
                -- {type="label", text="Beeper", x=x1, y=5, color=BLACK},
                {type="choice", x=LP2.x2, y=2, w=LP2.w2,
                    values = {
                        "No Beeper", 
                        "Yes, I have beeper",
                    },
                    color = COLOR_THEME_SECONDARY3,
                    label = "Beeper needed?",
                    default = is_beeper,
                    get = function() return is_beeper end,
                    set = function(v) is_beeper = v end,
                    -- labelX = x2
                },
            },
        },

        { type="setting", x=LP3.x1, y=1*line_height, w=LCD_W, title="Beeper Switch", visible = function() return is_beeper==2 end,
            children={
                {type="source", x=LP3.x2, y=0, w=LP3.w2,
                    title = "Switch for beeper",
                    get = function() return switch_idx end,
                    set = function(v) switch_idx = v end,
                },

            },
        },

        { type="setting", x=LP3.x1, y=2*line_height, w=LCD_W, title="Beeper Channel", visible = function() return is_beeper==2 end,
            children={
                -- {type="label", x=x1, y=85, color=BLACK, text="Beeper Channel",
                -- },
                {type="choice", x=LP3.x2, y=0, w=LP3.w2,
                    label = "Channel",
                    default = beeper_channel,
                    values = m_utils.channels_list,
                    color = COLOR_THEME_SECONDARY3,
                    get = function() return beeper_channel end,
                    set = function(v) beeper_channel = v end,
                },
            },
        },

        -- {type="box", x=0, y=M.height, w=LCD_W, h=20, color=RED} -- rectangle/box ???
    })

    return nil
end



function M.do_update_model()
    if is_beeper == 2 then
        local mixInfo = {
            source = switch_idx,
            name = "Beeper",
            weight = 100,
            multiplex = 0
        }
        model.insertMix(beeper_channel - 1, 0, mixInfo)
        m_utils.set_output_name(beeper_channel, "Beeper")

        log("Beeper configured: channel CH%d, switch %s", beeper_channel + 1, switch_idx)
    else
        log("Beeper: Not needed, skipping configuration.")
    end

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "gears_config"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 3*line_height + 15*lvSCALE

-- State
local is_gear = 1  -- 1=No, 2=Yes
local gear_switch_idx = getSourceIndex("SB")  -- -- switch SB source
local gear_channel = 8  -- default CH8

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({
        -- Flaps type selection
        { type="setting", x=x1, y=0*line_height, w=LCD_W, title="Have Gears?",
            children={
                {type="choice", x=x2, y=2, w=safe_width(x2, 160*lvSCALE),
                    values = {
                        "No Gears", 
                        "Yes, I have Gears"
                    },
                    color = COLOR_THEME_SECONDARY3,
                    label = "Gears",
                    default = is_gear,
                    get = function() return is_gear end,
                    set = function(v) is_gear = v end,
                },
            },
        },

        { type="setting", x=x1, y=1*line_height, w=LCD_W, title="Gears Switch", visible = function() return is_gear == 2 end,
            children={
                {type="source", x=x2, y=0, w=80*lvSCALE,
                    title = "Switch for gears",
                    get = function() return gear_switch_idx end,
                    set = function(v) gear_switch_idx = v end,
                },
            },
        },
        { type="setting", x=x1, y=2*line_height, w=LCD_W, title="Gears Channel", visible = function() return is_gear == 2 end,
            children={
                {type="choice", x=x2, y=0, w=80*lvSCALE,
                    label = "Channel",
                    default = gear_channel,
                    values = m_utils.channels_list,
                    color = COLOR_THEME_SECONDARY3,
                    get = function() return gear_channel end,
                    set = function(v) gear_channel = v end,
                },
            },
        },

        -- {type="box", x=0, y=M.height, w=LCD_W, h=20, color=RED} -- rectangle/box ???
    })

    return nil
end

function M.do_update_model()
    if is_gear == 2 then
        local mixInfo = {
            source = gear_switch_idx,
            name = "Gear",
            weight = 100,
            multiplex = 0
        }
        model.insertMix(gear_channel - 1, 0, mixInfo)
        log("Gears configured: channel CH%d, switch %s", gear_channel + 1, gear_switch_idx)
        m_utils.set_output_name(gear_channel, "Gear")
        
    else
        log("Gears: Not needed, skipping configuration.")
    end
    
    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

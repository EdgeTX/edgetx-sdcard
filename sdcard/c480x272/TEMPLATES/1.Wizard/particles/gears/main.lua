local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "gears_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 160
local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)


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
        {type="label", text="Have Gears?", x=x1, y=5, color=BLACK},
        {type="choice", x=x2, y=2, w=safe_width(x2, 160),
            values = {
                "No Gears", 
                "Yes, I have Gears"
            },
            color = COLOR_THEME_SECONDARY3,
            label = "Gears",
            default = is_gear,
            get = function() return is_gear end,
            set = function(v) is_gear = v end,
            -- labelX = x2
        },

        {type="label", x=x1, y=45, color=BLACK, text="Gears Switch",
            visible = function() return is_gear == 2 end
        },
        {type="source", x=x2, y=40, w=80,
            title = "Switch for gears",
            get = function() return gear_switch_idx end,
            set = function(v) gear_switch_idx = v end,
            visible = function() return is_gear == 2 end,
        },

        {type="label", x=x1, y=85, color=BLACK, text="Gears Channel",
            visible = function() return is_gear == 2 end
        },
        {type="choice", x=x2, y=80, w=80,
            label = "Channel",
            default = gear_channel,
            values = m_utils.channels_list,
            color = COLOR_THEME_SECONDARY3,
            get = function() return gear_channel end,
            set = function(v) gear_channel = v end,
            visible = function() return is_gear == 2 end,
        },
        {type="label", x=x1, y=100, text=""}, --???
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

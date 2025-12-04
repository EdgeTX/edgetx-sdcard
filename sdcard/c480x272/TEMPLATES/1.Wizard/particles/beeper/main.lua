local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "beeper_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 160
local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)

-- State
local is_beeper = 1  -- 1=No, 2=Yes
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

        -- Flaps type selection
        {type="label", text="Beeper", x=x1, y=5, color=BLACK},
        {type="choice", x=x2, y=0, w=safe_width(x2, 160),
            values = {
                "Yes, I have beeper",
                "No Beeper", 
            },
            color = COLOR_THEME_SECONDARY3,
            label = "Beeper needed?",
            default = is_beeper,
            get = function() return is_beeper end,
            set = function(v) is_beeper = v end,
            -- labelX = x2
        },

        {type="label", x=x1, y=45, color=BLACK, text="Beeper Switch",
            visible = function() return is_beeper == 1 end
        },
        {type="source", x=x2, y=40, w=80,
            title = "Switch for beeper",
            get = function() return switch_idx end,
            set = function(v) switch_idx = v end,
            visible = function() return is_beeper == 1 end,
        },

        {type="label", x=x1, y=85, color=BLACK, text="Beeper Channel",
            visible = function() return is_beeper == 1 end
        },
        {type="choice", x=x2, y=80, w=80,
            label = "Channel",
            default = beeper_channel,
            values = m_utils.channels_list,
            color = COLOR_THEME_SECONDARY3,
            get = function() return beeper_channel end,
            set = function(v) beeper_channel = v end,
            visible = function() return is_beeper == 1 end,
        },
        {type="label", x=x1, y=100, text=""}, --???
    })

    return nil
end



function M.do_update_model()
    if is_beeper == 1 then
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

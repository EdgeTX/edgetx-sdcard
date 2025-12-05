local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "profile_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 160
local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)


-- State
local is_profile = 1  -- 1=No, 2=Yes
local switch_idx = getSourceIndex("SA")  -- -- switch SD source
local profile_channel = 7  -- default CH7 (AUX3)

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    log("Initializing %s v%s, LCD_W: %s, x2:%s, x2-left: %s, box.w: %s", app_name, ver, LCD_W, x2, LCD_W - x2, box.w)
    box:build({
        {type="label", text="Profiles", x=x1, y=5, color=BLACK},
        {type="choice", x=x2, y=2, w=safe_width(x2, 240),
            values = {
                "Yes, I need profiles",
                "No need, single profile is ok", 
            },
            color = COLOR_THEME_SECONDARY3,
            label = "Profiles needed?",
            default = is_profile,
            get = function() return is_profile end,
            set = function(v) is_profile = v end,
            -- labelX = x2
        },

        {type="label", x=x1, y=45, color=BLACK, text="Profile Switch",
            visible = function() return is_profile == 1 end
        },
        {type="source", x=x2, y=40, w=80,
            title = "Switch for profiles",
            get = function() return switch_idx end,
            set = function(v) switch_idx = v end,
            visible = function() return is_profile == 1 end,
        },

        {type="label", x=x1, y=85, color=BLACK, text="Profiles Channel",
            visible = function() return is_profile == 1 end
        },
        {type="choice", x=x2, y=80, w=80,
            label = "Channel",
            default = profile_channel,
            values = m_utils.channels_list,
            color = COLOR_THEME_SECONDARY3,
            get = function() return profile_channel end,
            set = function(v) profile_channel = v end,
            visible = function() return is_profile == 1 end,
        },
        {type="label", x=x1, y=100, text=""}, --???
    })

    return nil
end



function M.do_update_model()
    if is_profile == 1 then
        local mixInfo = {
            source = switch_idx,
            name = "Prof",
            weight = 100,
            multiplex = 0
        }
        model.insertMix(profile_channel - 1, 0, mixInfo)
        m_utils.set_output_name(profile_channel, "prof")

        log("Profiles configured: channel CH%d, switch %s", profile_channel + 1, switch_idx)
    else
        log("Profiles: Not needed, skipping configuration.")
    end

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

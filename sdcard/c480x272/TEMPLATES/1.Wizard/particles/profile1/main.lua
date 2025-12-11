local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "profile_config"

local LP1 = m_utils.line_presets.p1
local LP2 = m_utils.line_presets.p2
local LP3 = m_utils.line_presets.p3
local LP4 = m_utils.line_presets.p4
local LP5 = m_utils.line_presets.p5
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 3*line_height + 15*lvSCALE

-- State
local is_profile = 2  -- 1=No, 2=Yes
local switch_idx = getSourceIndex("SA")  -- -- switch SD source
local profile_channel = 7  -- default CH7 (AUX3)

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    box:build({
        { type="setting", x=LP2.x1, y=0*line_height, w=LCD_W, title="Profiles",
            children={
                -- {type="label", text="Profiles", x=x1, y=5, color=BLACK},
                {type="choice", x=LP2.x2, y=2, w=LP2.w2,
                    values = {
                        "No need, single profile is ok", 
                        "Yes, I need profiles",
                    },
                    color = COLOR_THEME_SECONDARY3,
                    label = "Profiles needed?",
                    default = is_profile,
                    get = function() return is_profile end,
                    set = function(v) is_profile = v end,
                    -- labelX = x2
                },

            },
        },

        { type="setting", x=LP3.x1, y=1*line_height, w=LCD_W, title="Profiles Switch", visible = function() return is_profile==2 end,
            children={
                -- {type="label", x=x1, y=45, color=BLACK, text="Profile Switch",
                --     visible = function() return is_profile == 1 end
                -- },
                {type="source", x=LP3.x2, y=0, w=LP3.w2,
                    title = "Switch for profiles",
                    get = function() return switch_idx end,
                    set = function(v) switch_idx = v end,
                },
            },
        },

        { type="setting", x=LP3.x1, y=2*line_height, w=LCD_W, title="Profiles Channel", visible = function() return is_profile==2 end,
            children={

                -- {type="label", x=x1, y=85, color=BLACK, text="Profiles Channel",
                --     visible = function() return is_profile == 1 end
                -- },
                {type="choice", x=LP3.x2, y=0, w=LP3.w2,
                    label = "Channel",
                    default = profile_channel,
                    values = m_utils.channels_list,
                    color = COLOR_THEME_SECONDARY3,
                    get = function() return profile_channel end,
                    set = function(v) profile_channel = v end,
                },
            },
        },

        -- {type="box", x=0, y=M.height, w=LCD_W, h=20, color=RED} -- rectangle/box ???
    })

    return nil
end


function M.do_update_model()
    if is_profile == 2 then
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

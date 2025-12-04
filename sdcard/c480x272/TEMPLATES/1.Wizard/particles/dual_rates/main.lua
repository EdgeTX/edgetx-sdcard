local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "dual_rates_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 130
local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)


-- State
local expo = 30         -- 0-100, default 30
local is_dual_rate = 2  -- 1=No, 2=Yes
local dr_switch = 3     -- default SC (3)

-- Constants

-- Switch names
local switch_names = {"SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH"}

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

local function updateInputLine(channel, lineNo, expoWeight, weight, switch_name_position)
    local inInfo = model.getInput(channel -1, 0)

    -- expo
    inInfo.curveType = 1
    inInfo.curveValue = expoWeight
    inInfo.weight = weight
    inInfo.trimSource = 0 -- 0=on
    if (switch_name_position ~= nil) then
        local switchIndex = getSwitchIndex(switch_name_position)
        inInfo.switch = switchIndex
    end

    -- delete the old line
    model.deleteInput(channel-1, lineNo)
    model.insertInput(channel-1, lineNo, inInfo)
end

function M.init(box)
    box:build({
        -- Expo setting
        {type="label", text="Expo", x=x1, y=5, color=BLACK},
        {type="numberEdit", x=x2, y=0, w=60, min=0, max=100,
            default=expo,
            get=function() return expo end,
            set=function(v) expo = v end,
            display=function(v) return string.format("%d%%", v) end,
        },

        -- Dual Rate choice (No/Yes)
        {type="label", text="Dual Rates", x=x1, y=45, color=BLACK},
        {type="choice", x=x2, y=40, w=80,
            label="Dual Rates",
            values={"No", "Yes"},
            default=is_dual_rate,
            get=function() return is_dual_rate end,
            set=function(v) is_dual_rate = v end,
        },

        -- Switch selector (visible when dual rates enabled)
        {type="choice", x=x2+100, y=40, w=safe_width(x2+100, 80), color=COLOR_THEME_SECONDARY3,
            label="Switch",
            default=dr_switch,
            values=switch_names,
            get=function() return dr_switch end,
            set=function(v) dr_switch = v end,
            visible=function() return is_dual_rate == 2 end,
        },
        -- {type="label", text=function() return "is_dual_rate: ".. is_dual_rate end, x=x1, y=105, color=BLACK},

    })

    return nil
end

function M.do_update_model()
    if is_dual_rate == 2 then
        -- Dual rates enabled
        local dr_switch_name = switch_names[dr_switch]

        -- Aileron: High/Med/Low rates
        updateInputLine(m_utils.defaultChannel_AIL, 0, expo, 100, dr_switch_name .. CHAR_UP)
        updateInputLine(m_utils.defaultChannel_AIL, 1, expo, 75, dr_switch_name .. "-")
        updateInputLine(m_utils.defaultChannel_AIL, 2, expo, 50, dr_switch_name .. CHAR_DOWN)

        -- Elevator: High/Med/Low rates
        updateInputLine(m_utils.defaultChannel_ELE, 0, expo, 100, dr_switch_name .. CHAR_UP)
        updateInputLine(m_utils.defaultChannel_ELE, 1, expo, 75, dr_switch_name .. "-")
        updateInputLine(m_utils.defaultChannel_ELE, 2, expo, 50, dr_switch_name .. CHAR_DOWN)

        -- Rudder: Single rate (no dual rate)
        updateInputLine(m_utils.defaultChannel_RUD, 0, expo, 100, nil)

        log("Dual rates configured: expo=%d, switch=%s", expo, dr_switch_name)
    else
        -- Dual rates disabled - single rate for all
        updateInputLine(m_utils.defaultChannel_AIL, 0, expo, 100, nil)
        updateInputLine(m_utils.defaultChannel_ELE, 0, expo, 100, nil)
        updateInputLine(m_utils.defaultChannel_RUD, 0, expo, 100, nil)

        log("Single rates configured: expo=%d", expo)
    end

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

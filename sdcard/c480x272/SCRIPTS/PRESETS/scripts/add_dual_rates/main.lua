local m_log,m_utils,m_box  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "add_dual_rate"

local M = {}
M.height = 270

-- LVGL state variables
local input_idx_ail = -1
local input_idx_ele = -1
local selected_dr_switch = 3
local rate_high = 100
local expo_high = 50
local rate_med = 75
local expo_med = 40
local rate_low = 50
local expo_low = 30

---------------------------------------------------------------------------------------------------
local Fields = {
    dual_rate_switch={ text='Dual Rate switch:', x=180, y=30,  w=80, is_visible=1, default_value=3, avail_values={ "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    rate_high       ={ text='High Rate:'       , x=180, y=90,  w=50, is_visible=1, default_value=100, min=50, max=100 },
    expo_high       ={ text=nil                , x=250, y=90,  w=50, is_visible=1, default_value=50 , min=0 , max=100 }, -- expo
    rate_med        ={ text='Medium Rate:'     , x=180, y=130, w=50, is_visible=1, default_value=75 , min=40, max=90  },
    expo_med        ={ text=nil                , x=250, y=130, w=50, is_visible=1, default_value=40 , min=0 , max=100 }, -- expo
    rate_low        ={ text='Low Rate:'        , x=180, y=170, w=50, is_visible=1, default_value=50 , min=30, max=80  },
    expo_low        ={ text=nil                , x=250, y=170, w=50, is_visible=1, default_value=30 , min=0 , max=100 }, -- expo
}
---------------------------------------------------------------------------------------------------

function M.getVer()
    return ver
end

local function log(fmt, ...)
    m_log.info(fmt, ...)
end

---------------------------------------------------------------------------------------------------
local function updateInputLine(inputIdx, lineNo, expoWeight, weight, switch_name_position)
    local inInfo = model.getInput(inputIdx, 0)

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
    model.deleteInput(inputIdx, lineNo)
    model.insertInput(inputIdx, lineNo, inInfo)
end

------------------------------------------------------------------------------------------------------

function M.init()
    input_idx_ail = m_utils.input_search_by_name("Ail")
    input_idx_ele = m_utils.input_search_by_name("Ele")

    if input_idx_ail == -1 then
        return "can not find Aileron input, will not be able to add dual rates"
    end
    if input_idx_ele == -1 then
        return "can not find Elevator input, will not be able to add dual rates"
    end

    log("Aileron input=%d", input_idx_ail)
    log("Elevator input=%d", input_idx_ele)

    -- Initialize state variables with default values
    selected_dr_switch = Fields.dual_rate_switch.default_value
    rate_high = Fields.rate_high.default_value
    expo_high = Fields.expo_high.default_value
    rate_med = Fields.rate_med.default_value
    expo_med = Fields.expo_med.default_value
    rate_low = Fields.rate_low.default_value
    expo_low = Fields.expo_low.default_value

    m_box:build({
        -- Column headers
        {type="label", text="Rate", x=180, y=70, color=BLACK },
        {type="label", text="Expo", x=250, y=70, color=BLACK},
        -- Dual Rate Switch
        {type="label", text=Fields.dual_rate_switch.text, x=50, y=Fields.dual_rate_switch.y, color=BLACK},
        {type="choice",
            x=Fields.dual_rate_switch.x,
            y=Fields.dual_rate_switch.y -5,
            w=Fields.dual_rate_switch.w,
            title="DR Switch",
            values=Fields.dual_rate_switch.avail_values,
            get=function() return selected_dr_switch end,
            set=function(val) selected_dr_switch=val end
        },
        -- High Rate row
        {type="label", text=Fields.rate_high.text, x=50, y=Fields.rate_high.y, color=BLACK},
        {type="numberEdit",
            x=Fields.rate_high.x,
            y=Fields.rate_high.y,
            w=Fields.rate_high.w,
            min=Fields.rate_high.min,
            max=Fields.rate_high.max,
            get=function() return rate_high end,
            set=function(val) rate_high=val end
        },
        {type="numberEdit",
            x=Fields.expo_high.x,
            y=Fields.expo_high.y,
            w=Fields.expo_high.w,
            min=Fields.expo_high.min,
            max=Fields.expo_high.max,
            get=function() return expo_high end,
            set=function(val) expo_high=val end
        },
        -- Medium Rate row
        {type="label",text=Fields.rate_med.text,x=50,y=Fields.rate_med.y,color=BLACK},
        {type="numberEdit",
            x=Fields.rate_med.x,
            y=Fields.rate_med.y,
            w=Fields.rate_med.w,
            min=Fields.rate_med.min,
            max=Fields.rate_med.max,
            get=function() return rate_med end,
            set=function(val) rate_med=val end
        },
        {type="numberEdit",
            x=Fields.expo_med.x,
            y=Fields.expo_med.y,
            w=Fields.expo_med.w,
            min=Fields.expo_med.min,
            max=Fields.expo_med.max,
            get=function() return expo_med end,
            set=function(val) expo_med=val end
        },
        -- Low Rate row
        {type="label",text=Fields.rate_low.text,x=50,y=Fields.rate_low.y,color=BLACK},
        {type="numberEdit",
            x=Fields.rate_low.x,
            y=Fields.rate_low.y,
            w=Fields.rate_low.w,
            min=Fields.rate_low.min,
            max=Fields.rate_low.max,
            get=function() return rate_low end,
            set=function(val) rate_low=val end
        },
        {type="numberEdit",
            x=Fields.expo_low.x,
            y=Fields.expo_low.y,
            w=Fields.expo_low.w,
            min=Fields.expo_low.min,
            max=Fields.expo_low.max,
            get=function() return expo_low end,
            set=function(val) expo_low=val end
        }
    })

    return nil
end

function M.do_update_model()
    local dr_switch = Fields.dual_rate_switch.avail_values[selected_dr_switch]

    -- input lines for Aileron
    updateInputLine(input_idx_ail, 0, expo_high, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ail, 1, expo_med, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ail, 2, expo_low, rate_low , dr_switch .. CHAR_DOWN)

    -- input lines for Elevator
    updateInputLine(input_idx_ele, 0, expo_high, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ele, 1, expo_med, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ele, 2, expo_low, rate_low , dr_switch .. CHAR_DOWN)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

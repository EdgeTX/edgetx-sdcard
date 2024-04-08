local m_log,m_utils,m_libgui  = ...

-- Author: Offer Shmuely (2023)
local ver = "0.1"
local app_name = "add_dual_rate"

local M = {}

local ctx2
local input_idx_ail = -1
local input_idx_ele = -1

---------------------------------------------------------------------------------------------------
local Fields = {
    dual_rate_switch = { text = 'Dual Rate switch:', x = 200, y = 60 , w = 50, is_visible = 1, default_value = 3, avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    rate_high        = { text = 'High Rate:'       , x = 200, y = 120, w = 50, is_visible = 1, default_value = 100, min = 50, max = 100 },
    expo_high        = { text = nil                , x = 250, y = 120, w = 50, is_visible = 1, default_value = 50 , min = 0 , max = 100 }, -- expo
    rate_med         = { text = 'Medium Rate:'     , x = 200, y = 145, w = 50, is_visible = 1, default_value = 75 , min = 40, max = 90  },
    expo_med         = { text = nil                , x = 250, y = 145, w = 50, is_visible = 1, default_value = 40 , min = 0 , max = 100 }, -- expo
    rate_low         = { text = 'Low Rate:'        , x = 200, y = 170, w = 50, is_visible = 1, default_value = 50 , min = 30, max = 80  },
    expo_low         = { text = nil                , x = 250, y = 170, w = 50, is_visible = 1, default_value = 30 , min = 0 , max = 100 }, -- expo
    page = {}
}
Fields.page = {
    Fields.dual_rate_switch,
    Fields.rate_high,
    Fields.expo_high,
    Fields.rate_med,
    Fields.expo_med,
    Fields.rate_low,
    Fields.expo_low,
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
    local menu_x = 50
    local menu_w = 60
    local menu_h = 26

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

    ctx2 = m_libgui.newGUI()

    ctx2.label(200, 100, menu_w, menu_h, "Rate")
    ctx2.label(250, 100, menu_w, menu_h, "Expo")

    for _, field in pairs(Fields.page) do
        log("111 %s, %s, %s", _, field, field.text)
        local p = field
        if p.text then
            ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
        end
        if p.avail_values then
            p.gui_obj = ctx2.dropDown(p.x, p.y, p.w, menu_h, p.avail_values, p.default_value)
        else
            p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, p.default_value)
        end


        --if field_data.text then
        --    print("Field name: " .. field_name)
        --    print("Field text: " .. field_data.text)
        --     You can access other properties of the field_data table here if needed.
        --end
    end

    return nil
end

function M.draw_page(event, touchState)
    ctx2.run(event, touchState)

    return m_utils.PRESET_RC.OK_CONTINUE
end

function M.do_update_model()
    local rate_high = Fields.rate_high.gui_obj.value
    local rate_med = Fields.rate_med.gui_obj.value
    local rate_low = Fields.rate_low.gui_obj.value
    local expoVal_high = Fields.expo_high.gui_obj.value
    local expoVal_med = Fields.expo_med.gui_obj.value
    local expoVal_low = Fields.expo_low.gui_obj.value
    local dr_switch_idx = Fields.dual_rate_switch.gui_obj.selected
    local dr_switch = Fields.dual_rate_switch.avail_values[dr_switch_idx]

    -- input lines
    updateInputLine(input_idx_ail, 0, expoVal_high, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ail, 1, expoVal_med, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ail, 2, expoVal_low, rate_low , dr_switch .. CHAR_DOWN)

    updateInputLine(input_idx_ele, 0, expoVal_high, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ele, 1, expoVal_med, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ele, 2, expoVal_low, rate_low , dr_switch .. CHAR_DOWN)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

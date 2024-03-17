local m_log,m_utils,m_libgui  = ...

-- Author: Offer Shmuely (2023)
local ver = "0.1"
local app_name = "add_throttle_lock"

local M = {}

local ctx2


---------------------------------------------------------------------------------------------------
local Fields = {
    arm_switch = { text = 'Arm switch:'    , x = 200, y = 155 , w = 50, is_visible = 1, default_value = 6, avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    motor_ch   = { text = 'Motor Channel:' , x = 200, y = 180 , w = 50, is_visible = 1, default_value = 3, avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" } },
}
---------------------------------------------------------------------------------------------------

function M.getVer()
    return ver
end

local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init()
    local menu_x = 50
    local menu_w = 60
    local menu_h = 26

    ctx2 = m_libgui.newGUI()
    ctx2.label(menu_x    ,  50, menu_w, menu_h, "also know as:")
    ctx2.label(menu_x +10,  70, menu_w, menu_h, "* safety switch")
    ctx2.label(menu_x +10,  90, menu_w, menu_h, "* arm switch")
    ctx2.label(menu_x +10, 110, menu_w, menu_h, "* throttle lock switch")

    local p = Fields.arm_switch
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.dropDown(p.x, p.y, p.w, menu_h, p.avail_values, p.default_value)

    local p = Fields.motor_ch
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.dropDown(p.x, p.y, p.w, menu_h, p.avail_values, p.default_value)

    return nil
end

function M.draw_page(event, touchState)
    --local arm_switch_idx = Fields.arm_switch.gui_obj.selected
    --local arm_switch = Fields.arm_switch.avail_values[arm_switch_idx]
    --local mot_ch_idx = Fields.motor_ch.gui_obj.selected
    --local mot_ch = Fields.motor_ch.avail_values[mot_ch_idx]
    --
    --lcd.drawText(300, 240, arm_switch, DBLSIZE + BLACK)
    --lcd.drawText(380, 240, mot_ch, DBLSIZE + BLACK)
    --
    ctx2.run(event, touchState)

    return m_utils.PRESET_RC.OK_CONTINUE
end

function M.do_update_model()
    log("preset::do_update_model()")

    local arm_switch_idx = Fields.arm_switch.gui_obj.selected
    local arm_switch_name = Fields.arm_switch.avail_values[arm_switch_idx]
    local switchIndex = getSwitchIndex(arm_switch_name .. CHAR_DOWN)

    local mot_ch_idx = Fields.motor_ch.gui_obj.selected
    local mot_ch = Fields.motor_ch.avail_values[mot_ch_idx]

    -- set special function for arm switch
    local sp_location = 1
    --???? find a free location

    model.setCustomFunction(FUNC_OVERRIDE_CHANNEL+sp_location-1, {
        switch = switchIndex,
        func = 0,
        value = -100,
        mode = 0,
        param = mot_ch_idx - 1, --"CH3"
        active = 1
    })

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

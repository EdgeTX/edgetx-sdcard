local m_log,m_utils  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "add_throttle_lock"

local M = {}
M.height = 250

-- LVGL state variables
local selected_arm_switch = 6
local selected_motor_ch = 3

---------------------------------------------------------------------------------------------------
local Fields = {
    arm_switch={ text='Arm switch:'    , x=180, y=20 , w=70, is_visible=1, default_value=6, avail_values={ "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    motor_ch  ={ text='Motor Channel:' , x=180, y=60 , w=70, is_visible=1, default_value=3, avail_values={ "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" } },
}
---------------------------------------------------------------------------------------------------

local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    -- Initialize with default values
    selected_arm_switch = Fields.arm_switch.default_value
    selected_motor_ch = Fields.motor_ch.default_value

    local p_arm = Fields.arm_switch
    local p_motor = Fields.motor_ch

    box:build({

        {type="label",text=p_arm.text,x=50,y=p_arm.y,color=BLACK},
        {type="choice",x=p_arm.x,y=p_arm.y,w=p_arm.w,title="Arm Switch",values=p_arm.avail_values,
            get=function() return selected_arm_switch end,
            set=function(val) selected_arm_switch=val end
        },
        {type="label",text=p_motor.text,x=50,y=p_motor.y,color=BLACK},
        {type="choice",
            x=p_motor.x,
            y=p_motor.y,
            w=p_motor.w,
            title="Motor Channel",
            values=p_motor.avail_values,
            get=function() return selected_motor_ch end,
            set=function(val) selected_motor_ch=val end
        },
        {type="label",x=50, y=110,color=GREY, text="Note:\nalso know as:\n  * safety switch\n  * arm switch\n  * throttle lock switch"},
    })

    return nil
end

function M.do_update_model()
    log("preset::do_update_model()")

    local arm_switch_name = Fields.arm_switch.avail_values[selected_arm_switch]
    local switchIndex = getSwitchIndex(arm_switch_name .. CHAR_DOWN)

    -- set special function for arm switch
    local sp_location = 1
    --???? find a free location

    model.setCustomFunction(FUNC_OVERRIDE_CHANNEL + sp_location - 1, {
        switch = switchIndex,
        func = 0,
        value = -100,
        mode = 0,
        param = selected_motor_ch - 1, -- Channel index (0-based)
        active = 1
    })

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

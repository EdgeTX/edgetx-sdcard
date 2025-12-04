local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "mmotor_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 210

local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)


-- state variables
local is_motor = 2                          -- 1=No, 2=Yes (index into avail_values)
local motor_ch = m_utils.defaultChannel_THR -- 1-10 for CH1-CH10
local is_need_arm_switch = 2                -- 1=No, 2=Yes
local arm_switch_idx = 18                   -- 18 SF down
local is_need_elrs_arm_channel = 2          -- 1=Non ELRS, 2=Yes, CH5 as Arm channel
local elrs_arm_channel = 5                  -- default CH5
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    box:build({

        {type="image", x=105, y=100, w=70, h=70, file=function() return PRESET_FOLDER .. "/icon.png" end, visible = function() return use_images end},

        -- Motor question
        -- {type="label", text="Have a motor?", x=x1, y=5, color=BLACK},
        {type="choice",
            x=x2, y=0, w=safe_width(x2, 160),
            title="Have a Motor?",
            values={ "No Motor", "Yes, I have motor" },
            get=function() return is_motor end,
            set=function(val) is_motor = val end
        },
        
        -- Motor channel (conditional visibility)
        {type="label", text="Motor channel:",
            x=x1, y=40, color=BLACK,
            visible=function() return is_motor == 2 end
        },
        {type="choice", x=x2, y=40, w=80,
            title="Motor Channel",
            values=m_utils.channels_list,
            get=function() return motor_ch end,
            set=function(val) motor_ch = val end,
            visible=function() return is_motor == 2 end
        },

        -- Safety Switch question (conditional visibility)
        {type="label", text="Safety Switch:", x=x1, y=80, color=BLACK,
            visible=function() return is_motor == 2 end
        },
        {type="choice",
            x=x2, y=80, w=safe_width(x2, 180),
            title="Safety (ARM) Switch",
            values={ "No arm switch", "Yes, use arm switch" },
            get=function() return is_need_arm_switch end,
            set=function(val) is_need_arm_switch = val end,
            visible=function() return is_motor == 2 end
        },

        -- Arm switch selector (conditional visibility)
        {type="switch",
            x=370, y=80, w=80,
            title="Arm Switch",
            get=function() return arm_switch_idx end,
            set=function(val) arm_switch_idx = val end,
            visible=function() return (is_motor == 2 and is_need_arm_switch == 2) or (is_need_elrs_arm_channel == 2) end
        },

        -- set channel CH5 as arm if elrs communication
        {type="label", text="ELRS Arm:", x=x1, y=120, color=BLACK},
        {type="choice",
            x=x2, y=120, w=safe_width(x2, 180),
            title="ELRS Arm channel CH5",
            values={ "No ELRS", "CH5 as Arm channel" },
            get=function() return is_need_elrs_arm_channel end,
            set=function(val) is_need_elrs_arm_channel = val end,
        },

    })

    return nil
end

function M.do_update_model()
    log("Applying motor configuration...")

    local inputIdx = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_THR -1

    -- Only configure motor if enabled
    if is_motor == 2 then  -- yes
        log("Adding motor on channel CH%d", motor_ch)
        m_utils.addMix(motor_ch - 1, inputIdx, "Motor")
        m_utils.set_output_name(motor_ch, "Motor")
    end

    -- Add safety/arm switch if enabled
    if is_motor == 2 and is_need_arm_switch == 2 then  -- Yes
        log("Adding arm-switch on motor channel (idx: %s)", arm_switch_idx)
        
        -- Add custom function to override channel when switch is down
        model.setCustomFunction(FUNC_OVERRIDE_CHANNEL, {
            switch = arm_switch_idx,
            func = 0,  -- Override
            value = -100,
            mode = 0,
            param = motor_ch - 1, --"CH3"
            active = 1
        })
    end

    if is_need_elrs_arm_channel == 2 then

        local mixInfoElrs = {
            source = elrs_arm_channel - 1,
            name = "Arm",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(elrs_arm_channel - 1, 0, mixInfoElrs)
        m_utils.set_output_name(elrs_arm_channel, "Arm")
    end



    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

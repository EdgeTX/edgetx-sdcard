local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "mmotor_config"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 4*line_height + 15*lvSCALE

-- state variables
local is_motor = 2                          -- 1=No, 2=Yes (index into avail_values)
local motor_ch = m_utils.defaultChannel_THR -- 1-10 for CH1-CH10
local is_need_arm_switch = 2                -- 1=No, 2=Yes
local arm_switch_idx = getSwitchIndex("SF"..CHAR_DOWN) -- SF down
local is_need_elrs_arm_channel = 2          -- 1=Non ELRS, 2=Yes, CH5 as Arm channel
local elrs_arm_channel = 5                  -- default CH5
local elrs_arm_source_idx = getSourceIndex("SF") -- default SF
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    box:build({
        -- Motor question
        -- {type="label", text="Have a motor?", x=x1, y=5, color=BLACK},
        { type="setting", x=x1, y=0*line_height, w=LCD_W, title="Have a Motor?",
            children={
                {type="choice",
                    x=x2, y=2, w=safe_width(x2, 160*lvSCALE),
                    title="Have a Motor?",
                    values={ "No Motor", "Yes, I have motor" },
                    get=function() return is_motor end,
                    set=function(val) is_motor = val end
                },
            },
        },
        -- Motor channel (conditional visibility)
        { type="setting", x=x1, y=1*line_height, w=LCD_W, title="Motor channel:", visible=function() return is_motor == 2 end,
            children={
                -- {type="label", text="Motor channel:",
                --     x=x1, y=5, color=BLACK,
                -- },
                {type="choice", x=x2, y=0, w=80*lvSCALE,
                    title="Motor Channel",
                    values=m_utils.channels_list,
                    get=function() return motor_ch end,
                    set=function(val) motor_ch = val end,
                },
            }
        },

        -- Safety Switch question (conditional visibility)
        { type="setting", x=x1, y=2*line_height, w=LCD_W, title="Safety Switch:", visible=function() return is_motor == 2 end,
            children={
            -- {type="label", text="Safety Switch:", x=x1, y=80, color=BLACK,
            -- visible=function() return is_motor == 2 end
            -- },
                {type="choice",
                    x=x2, y=0, w=safe_width(x2, 180*lvSCALE),
                    title="Safety (ARM) Switch",
                    values={ "No arm switch", "Yes, use arm switch" },
                    get=function() return is_need_arm_switch end,
                    set=function(val) is_need_arm_switch = val end,
                },
                -- Arm switch selector (conditional visibility)
                {type="switch",
                    x=370*lvSCALE, w=80*lvSCALE,
                    title="Arm Switch",
                    get=function() return arm_switch_idx end,
                    set=function(val) arm_switch_idx = val end,                    
                    visible=function() return (is_need_arm_switch == 2) end
                },
            },
        },

        -- set channel CH5 as arm if elrs communication
        { type="setting", x=x1, y=3*line_height, w=LCD_W, title="ELRS Arm:", visible=function() return is_motor == 2 end,
            children={
                {type="image", x=105, y=0, w=line_height, h=line_height, file=function() return PRESET_FOLDER .. "/icon.png" end, visible = function() return use_images end},

                -- {type="label", text="ELRS Arm:", x=x1, y=120, color=BLACK},
                {type="choice",
                    x=x2, y=0, w=safe_width(x2, 180),
                    title="ELRS Arm channel CH5",
                    values={ "No ELRS", "CH5 as Arm channel" },
                    get=function() return is_need_elrs_arm_channel end,
                    set=function(val) is_need_elrs_arm_channel = val end,
                },
                {type="source",
                    x=370*lvSCALE, w=80*lvSCALE,
                    title="Arm Switch",
                    get=function() return elrs_arm_source_idx end,
                    set=function(val) elrs_arm_source_idx = val end,
                    visible=function() return (is_need_elrs_arm_channel == 2) end
                },
            },
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
            source = elrs_arm_source_idx - 1,
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

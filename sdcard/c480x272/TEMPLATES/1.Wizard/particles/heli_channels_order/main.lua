local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "heli_channels_order_config"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 450

local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local x3 = (LCD_W>=470) and 280 or 235
local use_images = (LCD_W>=470)

-- state variables
local channel_type = 2   -- 1=None, 2=ELRS, 3=FrSky, 4=Futaba
local ch_ail = nil
local ch_ele = nil
local ch_col = nil
local ch_rud = nil
local ch_thr = nil
local ch_arm = nil
local ch_tail_gain = nil
local ch_rescue = nil
local ch_bank = nil

local rescue_switch_idx     = getSourceIndex("SH")  -- switch SH
local bank_switch_idx       = getSourceIndex("SA")  -- switch SA
local tail_gain_switch_idx  = getSourceIndex("S1")  -- 
local arm_switch_idx        = getSourceIndex("SF")  -- switch SF down
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

local function apply_preset(preset)
    if preset == 2 then
        -- ELRS:   AECR1T23
        ch_ail  = 1
        ch_ele  = 2
        ch_col  = 3
        ch_rud  = 4
        ch_arm  = 5
        ch_thr  = 6
        ch_tail_gain = 7
        ch_bank   = 8
        ch_rescue = 9

    elseif preset == 3 then
        -- FrSky:  AETRC123
        ch_ail  = 1
        ch_ele  = 2
        ch_thr  = 3
        ch_rud  = 4
        ch_col  = 5
        ch_arm  = 6
        ch_tail_gain = 7
        ch_bank   = 8
        ch_rescue = 9

    elseif preset == 4 then
        -- Futaba: AETR1C23
        ch_ail  = 1
        ch_ele  = 2
        ch_thr  = 3
        ch_rud  = 4
        ch_arm  = 5
        ch_col  = 6
        ch_tail_gain = 7
        ch_bank   = 8
        ch_rescue = 9

    end
end

apply_preset(channel_type)

function M.init(box)

    box:build({
        {type="label", text="Channel Order Preset:", x=x1, y=5, color=BLACK},
        {type="choice", x=x2, y=2, w=safe_width(x2, 180),
            title="Channel Order Preset",
            values={
                "--manual--", 
                "ELRS:   AECR1T23", 
                "FrSky:  AETRC123", 
                "Futaba: AETR1C23",
            },
            get=function() return channel_type end,
            set=function(val) 
                channel_type = val 
                apply_preset(channel_type)
            end
        },
        
        -- aileron
        {type="label", text="Aileron:", x=x1, y=50, color=BLACK },
        {type="choice", x=x2, y=45, w=80,
            title="Ail Channel",
            values=m_utils.channels_list,
            get=function() return ch_ail end,
            set=function(val) 
                ch_ail = val
                channel_type = 1  -- manual
            end,
        },

        {type="label", text="Elevator:", x=x1, y=90, color=BLACK },
        {type="choice", x=x2, y=85, w=80, title="Elevator Channel",
            values=m_utils.channels_list,
            get=function() return ch_ele end,
            set=function(val) 
                ch_ele = val 
                channel_type = 1  -- manual
            end,
        },
        {type="label", text="Collective (pitch):", x=x1, y=130, color=BLACK },
        {type="choice", x=x2, y=125, w=80, title="Collective Channel",
            values=m_utils.channels_list,
            get=function() return ch_col end,
            set=function(val) 
                ch_col = val 
                channel_type = 1  -- manual
            end,
        },
        {type="label", text="Rudder:", x=x1, y=170, color=BLACK },
        {type="choice", x=x2, y=165, w=80, title="Rudder Channel",
            values=m_utils.channels_list,
            get=function() return ch_rud end,
            set=function(val) 
                ch_rud = val 
                channel_type = 1  -- manual
            end,
        },

        {type="label", text="Arm:", x=x1, y=210, color=BLACK },
        {type="choice", x=x2, y=210 -5, w=80, title="Arm Channel",
            values=m_utils.channels_list,
            get=function() return ch_arm end,
            set=function(val) 
                ch_arm = val 
                channel_type = 1  -- manual
            end,
        },
        {type="source", x=x3, y=210-5, w=safe_width(x3, 80),
            -- filter=lvgl.SW_TRIM,
            get=function() return arm_switch_idx end,
            set=function(val) arm_switch_idx = val end,
        },

        {type="label", text="Throttle:", x=x1, y=250, color=BLACK },
        {type="choice", x=x2, y=250-5, w=80, title="Throttle Channel",
            values=m_utils.channels_list,
            get=function() return ch_thr end,
            set=function(val) 
                ch_thr = val 
                channel_type = 1  -- manual
            end,
        },

        {type="label", text="Tail Gain:", x=x1, y=290, color=BLACK },
        {type="choice", x=x2, y=290-5, w=80, title="Tail Gain Channel",
            values=m_utils.channels_list,
            get=function() return ch_tail_gain end,
            set=function(val) 
                ch_tail_gain = val 
                channel_type = 1  -- manual
            end,
        },
        {type="source", x=x3, y=290-5, w=safe_width(x3, 80),
            filter=lvgl.SRC_POT,
            get=function() return tail_gain_switch_idx end,
            set=function(val) tail_gain_switch_idx = val end,
        },


        {type="label", text="Bank (profile):", x=x1, y=330, color=BLACK },
        {type="choice", x=x2, y=330-5, w=80, title="Bank Channel",
            values=m_utils.channels_list,
            get=function() return ch_bank end,
            set=function(val) 
                ch_bank = val 
                -- channel_type = 1  -- manual
            end,
        },
        {type="source", x=x3, y=330-5, w=safe_width(x3, 80),
            filter=lvgl.SRC_SWITCH,
            get=function() return bank_switch_idx end,
            set=function(val) bank_switch_idx = val end,
        },


        {type="label", text="Rescue (Panic):", x=x1, y=370, color=BLACK },
        {type="choice", x=x2, y=370-5, w=80, title="Rescue Channel",
            values=m_utils.channels_list,
            get=function() return ch_rescue end,
            set=function(val) 
                ch_rescue = val 
                -- channel_type = 1  -- manual
            end,
        },
        {type="source", x=x3, y=370-5, w=safe_width(x3, 80),
            filter=lvgl.SRC_SWITCH,
            get=function() return rescue_switch_idx end,
            set=function(val) rescue_switch_idx = val end,
        },

    })

    return nil
end

function M.do_update_model()
    log("Applying channel order configuration...")

    m_utils.set_output_name(ch_ail, "Ail")
    m_utils.set_output_name(ch_ele, "Ele")
    m_utils.set_output_name(ch_col, "Pitch")
    m_utils.set_output_name(ch_rud, "Rud")
    m_utils.set_output_name(ch_arm, "Arm")
    m_utils.set_output_name(ch_thr, "Thr")
    m_utils.set_output_name(ch_tail_gain, "Tail Gain")
    m_utils.set_output_name(ch_rescue, "Rescue")
    m_utils.set_output_name(ch_bank, "Bank")

    m_utils.addMix(ch_ail-1, MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL -1, "Ail", 100, 0)
    m_utils.addMix(ch_ele-1, MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1, "Ele", 100, 0)
    m_utils.addMix(ch_col-1, MIXSRC_FIRST_INPUT + m_utils.defaultChannel_THR -1, "Pitch", 100, 0)
    m_utils.addMix(ch_rud-1, MIXSRC_FIRST_INPUT + m_utils.defaultChannel_RUD -1, "Rud", 100, 0)

    -- throttle with 3 RPM steps
    local mixInfo3 = {source=MIXSRC_MAX, name="RPM3", weight= 40, offset=0, multiplex=2, switch=getSwitchIndex("SC" .. CHAR_UP) }
    local mixInfo2 = {source=MIXSRC_MAX, name="RPM2", weight= 10, offset=0, multiplex=2, switch=getSwitchIndex("SC" .. "-") }
    local mixInfo1 = {source=MIXSRC_MAX, name="RPM1", weight=-30, offset=0, multiplex=2, switch=getSwitchIndex("SC" .. CHAR_DOWN) }
    model.insertMix(ch_thr - 1, 0, mixInfo3)
    model.insertMix(ch_thr - 1, 1, mixInfo2)
    model.insertMix(ch_thr - 1, 2, mixInfo1)
    

    m_utils.addMix(ch_arm-1, arm_switch_idx, "Arm", 100, 0)
    m_utils.addMix(ch_tail_gain-1, tail_gain_switch_idx, "Tail Gain", 100, 0)
    m_utils.addMix(ch_rescue-1, rescue_switch_idx, "Rescue", 100, 0)
    m_utils.addMix(ch_bank-1, bank_switch_idx, "Bank", 100, 0)


    
    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

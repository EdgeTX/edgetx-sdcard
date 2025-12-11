local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "ailerons_config"

local LP1 = m_utils.line_presets.p1
local LP2 = m_utils.line_presets.p2
local LP3 = m_utils.line_presets.p3
local LP4 = m_utils.line_presets.p4
local LP5 = m_utils.line_presets.p5
local LP6 = m_utils.line_presets.p6
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 2*line_height + 15*lvSCALE

-- state variables
local ail_type = 3   -- 1=None, 2=One (or two with Y cable), 3=Two
local ail_ch_a = m_utils.defaultChannel_AIL -- CH1 by default for first aileron
local ail_ch_b = 6   -- CH6 by default for second aileron

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({
        -- Aileron type selection
        { type="setting", x=LP4.x1, y=0*line_height, w=LCD_W, title="Type",
            children={
                {type="choice", x=LP4.x2, y=2, w=LP4.w2,
                    title="Aileron Type",
                    values={ 
                        "No Ailerons", 
                        "Two Ailerons on single channel (with Y cable)", 
                        "Two Ailerons on two channels" 
                    },
                    get=function() return ail_type end,
                    set=function(val) ail_type = val end
                },
            },
        },        
        -- First aileron channel (visible when ail_type >= 2)
        { type="setting", x=LP6.x1, y=1*line_height, w=LCD_W, title="Channels",
            children={
                -- {type="label", text="Aileron channels:", x=x1, y=50, color=BLACK, visible=function() return ail_type==2 or ail_type==3 end },
                {type="choice", x=LP6.x2, y=0, w=LP6.w2,
                    title="Ail Channel",
                    values=m_utils.channels_list,
                    get=function() return ail_ch_a end,
                    set=function(val) ail_ch_a = val end,
                    visible=function() return ail_type==2 or ail_type==3 end
                },

                {type="choice", x=LP6.x3, y=0, w=LP6.w3, title="Ail Left Channel",
                    values=m_utils.channels_list,
                    get=function() return ail_ch_b end,
                    set=function(val) ail_ch_b = val end,
                    visible=function() return ail_type == 3 end
                },
            },
        },
    })
    return nil
end

function M.do_update_model()
    log("Applying aileron configuration...")
    
    if ail_type == 2 then
        -- One aileron (or two with Y cable)
        log("Adding single aileron on channel CH%d", ail_ch_a)
        
        local mixInfo = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL - 1,
            name = "Ail",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ail_ch_a - 1, 0, mixInfo)
        m_utils.set_output_name(ail_ch_a, "Ail")
        
    elseif ail_type == 3 then
        -- Two ailerons
        log("Adding left aileron on channel CH%d", ail_ch_a)
        log("Adding right aileron on channel CH%d", ail_ch_b)
        
        -- Left aileron
        local mixInfoL = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL - 1,
            name = "Ail-L",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ail_ch_a - 1, 0, mixInfoL)
        m_utils.set_output_name(ail_ch_a, "Ail-L")
        
        -- Right aileron (inverted)
        local mixInfoR = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL - 1,
            name = "Ail-R",
            weight = -100,  -- Inverted
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ail_ch_b - 1, 0, mixInfoR)
        m_utils.set_output_name(ail_ch_b, "Ail-R")
    end
    
    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

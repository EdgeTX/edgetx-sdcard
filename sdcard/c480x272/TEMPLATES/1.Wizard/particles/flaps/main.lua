local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "flaps_config"

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

M.height =  3*line_height + 15*lvSCALE

-- state variables
local flap_type = 1   -- 1=No, 2=Yes on one channel, 3=Yes on two channels
local flap_ch_a = 9   -- CH9 by default
local flap_ch_b = 10  -- CH10 by default
local flaps_switch_idx = getSourceIndex("SA")  -- switch SA
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({
        -- Flaps type selection
        -- {type="label", text="Flaps", x=x1, y=5, color=BLACK},
        { type="setting", x=LP4.x1, y=0*line_height, w=LCD_W, title="Have Flaps?",
            children={
                {type="choice", x=LP4.x2, y=2, w=LP4.w2,
                    title="Flaps Type",
                    values={ 
                        "No Flaps", 
                        "Flaps on one channel", 
                        "Flaps on two channels" 
                    },
                    get=function() return flap_type end,
                    set=function(val) flap_type = val 
                        log("Flap type set to: %d", flap_type)
                    end
                },
            },
        },

        { type="setting", x=LP3.x1, y=1*line_height, w=LCD_W, title="Flaps switch", visible=function() return flap_type ~=1 end,
            children={
            -- {type="label", text="Flaps switch:", x=x1, y=45, color=BLACK, visible=function() return flap_type >= 2 end},
                {type="source",
                    x=LP3.x2, y=0, w=LP3.w2,
                    title="Flap Switch",
                    get=function() 
                        return flaps_switch_idx 
                    end,
                    set=function(val) 
                        flaps_switch_idx = val 
                    end,
                },
            },
        },

        { type="setting", x=LP6.x1, y=2*line_height, w=LCD_W, title="Flaps channels", visible=function() return flap_type ~=1 end,
            children={
                -- flap channel left or dual
                {type="choice", x=LP6.x2, y=0, w=LP6.w2,
                    title="Flap Channel",
                    values=m_utils.channels_list,
                    get=function() return flap_ch_a end,
                    set=function(val) flap_ch_a = val end,
                },

                -- flap channel right
                {type="choice", x=LP6.x3, y=0, w=LP6.w3,
                    title="Flap Right Channel",
                    values=m_utils.channels_list,
                    get=function() return flap_ch_b end,
                    set=function(val) flap_ch_b = val end,
                    visible=function() return flap_type == 3 end
                },
            },
        },
        -- {type="box", x=0, y=M.height, w=LCD_W, h=20, color=RED} -- rectangle/box ???
    })

    return nil
end

function M.do_update_model()
    log("Applying flaps configuration...")
    
    if flap_type == 2 then
        -- One flap channel
        log("Adding flaps on channel CH%d controlled by SA", flap_ch_a)
        
        local mixInfo = {
            source = flaps_switch_idx,
            name = "Flaps",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(flap_ch_a - 1, 0, mixInfo)
        m_utils.set_output_name(flap_ch_a, "Flaps")

    elseif flap_type == 3 then
        -- Two flap channels
        log("Adding left flap on channel CH%d controlled by SA", flap_ch_a)
        log("Adding right flap on channel CH%d controlled by SA", flap_ch_b)
        
        -- Left flap
        local mixInfoL = {
            source = flaps_switch_idx,
            name = "FlapL",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(flap_ch_a - 1, 0, mixInfoL)
        m_utils.set_output_name(flap_ch_a, "FlapsL")
        
        -- Right flap
        local mixInfoR = {
            source = flaps_switch_idx,
            name = "FlapR",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(flap_ch_b - 1, 0, mixInfoR)
        m_utils.set_output_name(flap_ch_b, "FlapsR")
        
    end
    
    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

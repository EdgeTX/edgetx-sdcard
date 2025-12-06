local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "elevrons_config"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 1*line_height + 15*lvSCALE

-- Constants

-- state variables
local ch_a = 1
local ch_b = 2

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({       
        { type="setting", x=x1, y=0*line_height, w=LCD_W, title="Elevron Channels", 
            children={
                -- {type="label", text="channels:", x=x1, y=5, color=BLACK},

                {type="choice", x=x2, y=2, w=80,
                    title="Elevron CH Left",
                    values=m_utils.channels_list,
                    get=function() return ch_a end,
                    set=function(val) ch_a = val end
                },
                {type="choice", x=x3, y=2, w=safe_width(x3, 80),
                    title="Elevron CH Right",
                    values=m_utils.channels_list,
                    get=function() return ch_b end,
                    set=function(val) ch_b = val end,
                },
            },
        },

    })
    return nil
end

function M.do_update_model()
    log("Applying tail configuration...")
    
    -- V-Tail
    local ch_a_idx = ch_a - 1
    local ch_b_idx = ch_b - 1
    log("Adding V-tail left on channel CH%d", ch_a)
    log("Adding V-tail right on channel CH%d", ch_b)
    
    -- Right V-tail: 50% Elevator + 50% Rudder
    local mixInfoL1 = {
        source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
        name = "ElevL",
        weight = 50,
        offset = 0,
        switch = 0,
        multiplex = 0  -- Add
    }
    model.insertMix(ch_a_idx, 0, mixInfoL1)
    
    local mixInfoL2 = {
        source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL -1,
        name = "RudL",
        weight = 50,
        offset = 0,
        switch = 0,
        multiplex = 0  -- Add
    }
    model.insertMix(ch_a_idx, 1, mixInfoL2)
    
    -- Left V-tail: 50% Elevator - 50% Rudder
    local mixInfoR1 = {
        source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
        name = "ElevR",
        weight = 50,
        offset = 0,
        switch = 0,
        multiplex = 0  -- Add
    }
    model.insertMix(ch_b_idx, 0, mixInfoR1)
    
    local mixInfoR2 = {
        source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_AIL -1,
        name = "RudR",
        weight = -50,  -- Inverted
        offset = 0,
        switch = 0,
        multiplex = 0  -- Add
    }
    model.insertMix(ch_b_idx, 1, mixInfoR2)

    m_utils.set_output_name(ch_a, "EvonL")
    m_utils.set_output_name(ch_b, "EvonR")

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

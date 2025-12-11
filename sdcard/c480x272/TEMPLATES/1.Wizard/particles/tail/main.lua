local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "tail_config"

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

M.height = 3*line_height + 15*lvSCALE

-- Constants

-- state variables
local tail_type = 2   -- 1=Elevator only, 2=Elevator+Rudder, 3=Two Elevators+Rudder, 4=V-Tail
local ch_a = m_utils.defaultChannel_ELE  -- Elevator channel
local ch_b = m_utils.defaultChannel_RUD  -- Rudder channel
local ch_c = 7   -- Second elevator channel (CH7)

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)

    box:build({
        -- Tail type selection
        -- {type="label", text="Pick the tail configuration:", x=LP1.x1, y=5, color=BLACK},
        { type="setting", x=LP4.x1, y=0*line_height, w=LCD_W, title="Configuration",
            children={
                {type="choice", x=LP4.x2, y=2, w=LP4.w2,
                    title="Tail Type",
                    values={ 
                        "1 Elevator, no Rudder", 
                        "1 Elevator, 1 Rudder", 
                        "2 Elevator, 1 Rudder", 
                        "V-Tail" 
                    },
                    get=function() return tail_type end,
                    set=function(val) tail_type = val end
                },
            },
        },        

        -- Elevators
        { type="setting", x=LP6.x1, y=1*line_height, w=LCD_W, title="Elevator channels", visible=function() return tail_type<4 end,
            children={
                {type="choice", x=LP6.x2, y=0, w=LP6.w2,
                    title="Elevator Ch",
                    values=m_utils.channels_list,
                    get=function() return ch_a end,
                    set=function(val) ch_a = val end
                },
                {type="choice", x=LP6.x3, y=0, w=LP6.w3,
                    title="Elevator Right Ch",
                    values=m_utils.channels_list,
                    get=function() return ch_c end,
                    set=function(val) ch_c = val end,
                    visible=function() return tail_type==3 end
                },
            },
        },

        -- Rudder - visible when tail_type >= 2
        { type="setting", x=LP3.x1, y=2*line_height, w=LCD_W, title="Rudder channel", visible=function() return tail_type==2 or tail_type==3 end,
            children={
                -- {type="label", text="Rudder channel:", x=x1, y=90, color=BLACK,
                --     visible=function() return tail_type==2 or tail_type==3 end
                -- },
                {type="choice", x=LP3.x2, y=0, w=LP3.w2, title="Rudder Ch",
                    values=m_utils.channels_list,
                    get=function() return ch_b end,
                    set=function(val) ch_b = val end,
                },
            },
        },

        -- v-tail
        { type="setting", x=LP3.x1, y=1*line_height, w=LCD_W, title="V-Tail  channels", visible=function() return tail_type==4 end,
            children={
                {type="choice", x=LP3.x2, y=0, w=LP3.w2,
                    title="v-tail-left ch",
                    values=m_utils.channels_list,
                    get=function() return ch_a end,
                    set=function(val) ch_a = val end
                },
                {type="choice", x=LP3.x3, y=0, w=LP3.w3,
                    title="v-tail-right ch",
                    values=m_utils.channels_list,
                    get=function() return ch_c end,
                    set=function(val) ch_c = val end,
                },
            },
        },

    })

    return nil
end

function M.do_update_model()
    log("Applying tail configuration...")
    
    if tail_type==1 then
        -- Elevator only, no rudder
        log("Adding elevator on channel CH%d", ch_a)
        
        local mixInfo = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "Elev",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_a - 1, 0, mixInfo)
        m_utils.set_output_name(ch_a, "Elev")
        
    elseif tail_type==2 then
        -- One elevator + one rudder
        local ch_a_idx = ch_a - 1
        local ch_b_idx = ch_b - 1
        log("Adding elevator on channel CH%d", ch_a)
        log("Adding rudder on channel CH%d", ch_b)
        
        -- Elevator
        local mixInfoElev = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "Elev",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0
        }
        model.insertMix(ch_a - 1, 0, mixInfoElev)
        m_utils.set_output_name(ch_a, "Elev")
        
        -- Rudder
        local mixInfoRud = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_RUD -1,
            name = "Rudder",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0
        }
        model.insertMix(ch_b - 1, 0, mixInfoRud)
        m_utils.set_output_name(ch_b, "Rud")
        
    elseif tail_type==3 then
        -- Two elevators + one rudder
        log("Adding right elevator on channel CH%d", ch_a)
        log("Adding rudder on channel CH%d", ch_b)
        log("Adding left elevator on channel CH%d", ch_c)
        
        -- Elevator Right
        local mixInfoElevL = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "Elev-L",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_a - 1, 0, mixInfoElevL)
        m_utils.set_output_name(ch_a, "Elev-L")
        
        -- Elevator Left
        local mixInfoElevR = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "Elev-R",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_c - 1, 0, mixInfoElevR)

        -- Rudder
        local mixInfoRud = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_RUD -1,
            name = "Rudder",
            weight = 100,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_b - 1, 0, mixInfoRud)
        m_utils.set_output_name(ch_b, "Rud")
        
    elseif tail_type==4 then
        -- V-Tail
        log("Adding V-tail left on channel CH%d", ch_a)
        log("Adding V-tail right on channel CH%d", ch_c)
        
        -- Right V-tail: 50% Elevator + 50% Rudder
        local mixInfoL1 = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "ElevL",
            weight = 50,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_a - 1, 0, mixInfoL1)
        
        local mixInfoL2 = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_RUD -1,
            name = "RudL",
            weight = 50,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_a - 1, 1, mixInfoL2)

        -- Left V-tail: 50% Elevator - 50% Rudder
        local mixInfoR1 = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_ELE -1,
            name = "ElevR",
            weight = 50,
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_c - 1, 0, mixInfoR1)
        
        local mixInfoR2 = {
            source = MIXSRC_FIRST_INPUT + m_utils.defaultChannel_RUD -1,
            name = "RudR",
            weight = -50,  -- Inverted
            offset = 0,
            switch = 0,
            multiplex = 0  -- Add
        }
        model.insertMix(ch_c - 1, 1, mixInfoR2)

        m_utils.set_output_name(ch_a, "Elon-L")
        m_utils.set_output_name(ch_c, "Elon-R")

    end
    
    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "model_name"
local safe_width = m_utils.get_max_width_left

local M = {}
M.height = 80

-- state variables
local model_name = ""
local original_model_name = ""

local x1 = 20
local x2 = (LCD_W>=470) and 180 or 150
local use_images = (LCD_W>=470)


---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.init(box)
    -- Get current model name
    -- local modelInfo = model.getInfo()
    -- original_model_name = modelInfo.name or ""
    -- model_name = original_model_name

    box:build({
        -- {type="label", text="Set the name for this model", x=x1, y=0, color=BLACK},
        {type="label", text="Model Name:", x=x1, y=5, color=BLACK},
        {type="textEdit", x=130, y=0, w=safe_width(130, 200), maxLen=15,
            value=model_name,
            get=function() return model_name end,
            set=function(val) model_name=val end
        },
        -- {type="label", text= string.format("(Original name: %s)", original_model_name) , x=x1, y=70, color=BLACK, font=m_utils.FS.FONT_6},
    })

    return nil
end

function M.do_update_model()
    log("Setting model name to: %s", model_name)
    
    local modelInfo = model.getInfo()
    modelInfo.name = model_name
    model.setInfo(modelInfo)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

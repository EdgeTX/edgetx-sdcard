local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "model_name"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 1*line_height + 15*lvSCALE

-- state variables
local model_name = ""
local original_model_name = ""

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
        { type="setting", x=x1, y=0*line_height, w=LCD_W, title="Model Name",
            children={
                {type="textEdit", x=x2, y=2, w=safe_width(x2, 220), maxLen=15,
                    value=model_name,
                    get=function() return model_name end,
                    set=function(val) model_name=val end
                },
            },
        },
        -- {type="label", text= string.format("(Original name: %s)", original_model_name) , x=x1, y=70, color=BLACK, font=m_utils.FS.FONT_6},
    })

    return nil
end

function M.do_update_model()
    log("Setting model name to: %s", model_name)

    -- strip leading/trailing whitespace before validating
    model_name = string.gsub(model_name, "^%s*(.-)%s*$", "%1")

    if model_name == "" then
        local now = getDateTime()
        model_name = string.format("New %02d-%02d-%02d", now.year, now.mon, now.day)
    end
    
    local modelInfo = model.getInfo()
    modelInfo.name = model_name
    model.setInfo(modelInfo)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

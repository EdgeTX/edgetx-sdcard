local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "model_image"

local LP1 = m_utils.line_presets.p1
local LP2 = m_utils.line_presets.p2
local LP3 = m_utils.line_presets.p3
local LP4 = m_utils.line_presets.p4
local LP5 = m_utils.line_presets.p5
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = LCD_W/2 -- 5*line_height + 15*lvSCALE

-- state variables
local image_name_idx = 1
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------
local image_list = {
    "---",
    -- "fuga.jpg",
    -- "inspir.jpg",
    -- "funjet.png",
}

function M.init(box)

    for img in dir("/IMAGES") do
        m_log.info("image: %s", img)
        image_list[#image_list + 1] = img
    end
    collectgarbage()
    

    local img_size = LP5.w2
    box:build({
        { type="label" , x=LP5.x1, y=0*line_height, text="Model Image:" },
        { type="choice", x=LP5.x1, y=1*line_height, w=LP5.w1,
            title="Model Image",
            values=image_list,
            get=function() return image_name_idx end,
            set=function(val) image_name_idx = val end,
        },
        -- { type="rectangle", x=LP5.x2, y=0, w=img_size, h=img_size, filled=false, color=RED},
        { type="image",     x=LP5.x2, y=0, w=img_size, h=img_size, fill=false, file=function() return "/IMAGES/" .. image_list[image_name_idx] end },
    })

    return nil
end

function M.do_update_model()
    log("Applying image...")
   
    local modelInfo = model.getInfo()
    local image_name = image_list[image_name_idx]
    if image_name ~= "---" then
        modelInfo.bitmap = image_name
        model.setInfo(modelInfo)
    end

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

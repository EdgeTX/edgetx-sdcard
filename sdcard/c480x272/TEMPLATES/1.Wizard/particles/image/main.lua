local m_log, m_utils, PRESET_FOLDER  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "model_image"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 5*line_height + 15*lvSCALE

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
    

    local img_size = safe_width(x2, 180*lvSCALE)
    box:build({
        -- { type="setting", x=x1, y=0*line_height, w=LCD_W, title="Model Image:",
        --     children={
        --         {type="choice", x=x2, y=0, w=safe_width(x2, 300*lvSCALE),
        --             title="Model Image",
        --             values=image_list,
        --             get=function() return image_name_idx end,
        --             set=function(val) image_name_idx = val end,
        --         },
        --     }
        -- },

        { type="label" , x=x1, y=0*line_height, text="Model Image:" },
        { type="choice", x=x1, y=1*line_height, w=safe_width(x1, 180*lvSCALE),
            title="Model Image",
            values=image_list,
            get=function() return image_name_idx end,
            set=function(val) image_name_idx = val end,
        },
        { type="image", x=x2+30, y=0, w=img_size, h=img_size, fill=false, file=function() return "/IMAGES/" .. image_list[image_name_idx] end },
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

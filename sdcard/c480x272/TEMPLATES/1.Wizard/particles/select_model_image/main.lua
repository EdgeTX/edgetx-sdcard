local m_log,m_utils,m_box  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "set_timer1"
local safe_width = m_utils.safe_width
local x1 = m_utils.x1
local x2 = m_utils.x2
local x3 = m_utils.x3
local use_images = m_utils.use_images

local M = {}
local lvSCALE = lvgl.LCD_SCALE or 1
local line_height = 6*lvSCALE + (lvgl.UI_ELEMENT_HEIGHT or 32)

M.height = 3*line_height + 15*lvSCALE

-- state variables
local timer_hh = 0
local timer_mm = 0
local timer_ss = 0
local org_hh = 0
local org_mm = 0
local org_ss = 0

---------------------------------------------------------------------------------------------------
local Fields = {
    timer1_hour = { text = 'Hours', x = 160, y = 130 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 1000 },
    timer1_min  = { text = 'Min'  , x = 220, y = 130 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 60   },
    timer1_sec  = { text = 'Sec'  , x = 280, y = 130 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 60   },
}
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
    print(app_name .. string.format(fmt, ...))
end
---------------------------------------------------------------------------------------------------

local function formatTime(t1)
    local dd_raw = t1.value / 86400 -- 24*3600
    local dd = math.floor(dd_raw)
    local hh_raw = (dd_raw - dd) * 24
    local hh = math.floor(hh_raw)
    local mm_raw = (hh_raw - hh) * 60
    local mm = math.floor(mm_raw)
    local ss_raw = (mm_raw - mm) * 60
    local ss = math.floor(ss_raw)
    local time_str
    if dd == 0 and hh == 0 then
        -- less then 1 hour, 59:59
        time_str = string.format("%02d:%02d", mm, ss)
    elseif dd == 0 then
        -- lass then 24 hours, 23:59:59
        time_str = string.format("%02d:%02d:%02d", hh, mm, ss)
    else
        -- more than 24 hours

        -- use_hours 25:59:59
        time_str = string.format("%02d:%02d:%02d", dd * 24 + hh, mm, ss)
        -- use days: 5d 23:59:59
        --time_str = string.format("%dd %02d:%02d:%02d", dd, hh, mm, ss)
    end
    --log("test: " .. time_str)
    return dd, hh, mm, ss
end
local function formatTime2(hh, mm, ss)
    local time_str
    if 0 and hh == 0 then
        -- less then 1 hour, 59:59
        time_str = string.format("%02d:%02d", mm, ss)
    else
        -- lass then 24 hours, 23:59:59
        time_str = string.format("%02d:%02d:%02d", hh, mm, ss)
    end
    --log("test: " .. time_str)
    return time_str
end

function M.init()
    local t1 = model.getTimer(0)
    local dd, hh, mm, ss = formatTime(t1)

    -- Store original and current values
    org_hh, org_mm, org_ss = hh, mm, ss
    timer_hh, timer_mm, timer_ss = hh, mm, ss

    local p_hour = Fields.timer1_hour
    local p_min = Fields.timer1_min
    local p_sec = Fields.timer1_sec

    m_box:build({
        {type="label",text = "original time:",x = 50,y = 60,color = BLACK},
    })

    return nil
end

function M.do_update_model()
    log("preset::do_update_model()")

    local t1 = model.getTimer(0)
    t1.value = timer_hh * 3600 + timer_mm * 60 + timer_ss
    t1.start = 0
    --t1.persistent = 2
    model.setTimer(0, t1)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

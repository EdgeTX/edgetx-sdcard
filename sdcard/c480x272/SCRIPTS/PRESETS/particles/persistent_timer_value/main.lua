local m_log,m_utils,m_box  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "set_timer1"

local M = {}
M.height = 270

-- LVGL state variables
local timer_hh = 0
local timer_mm = 0
local timer_ss = 0
local org_hh = 0
local org_mm = 0
local org_ss = 0
local selected_timer_id = 3

---------------------------------------------------------------------------------------------------
local Fields = {
    timer1_hour = { text = 'Hours', x = 160, y = 100 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 1000 },
    timer1_min  = { text = 'Min'  , x = 220, y = 100 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 60   },
    timer1_sec  = { text = 'Sec'  , x = 280, y = 100 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 60   },
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

function M.init(box)
    local t1 = model.getTimer(0)
    local dd, hh, mm, ss = formatTime(t1)

    -- Store original and current values
    org_hh, org_mm, org_ss = hh, mm, ss
    timer_hh, timer_mm, timer_ss = hh, mm, ss

    local preset_list = {"Timer1", "Timer2", "Timer3"}

    local p_hour = Fields.timer1_hour
    local p_min = Fields.timer1_min
    local p_sec = Fields.timer1_sec

    box:build({{type="label", text="original time:", x=240, y=10, color=BLACK},
        {type="label", x=340, y=10, color=BLACK, text=function() return formatTime2(org_hh, org_mm, org_ss) end},
        {type="choice",x=50, y=40, w=100, title="Select Timer",
            values=preset_list,
            get=function() return selected_timer_id end,
            set=function(val) selected_timer_id=val end
        },
        {type="label", text="new time:", x=50, y=90, color=BLACK},
        {type="label", text=p_hour.text, x=p_hour.x, y=p_hour.y - 20, color=BLACK},
        {type="numberEdit", x=p_hour.x, y=p_hour.y, w=p_hour.w, min=p_hour.min, max=p_hour.max,
            get=function() return timer_hh end,
            set=function(val) timer_hh=val end
        },
        {type="label", text=p_min.text, x=p_min.x, y=p_min.y - 20, color=BLACK},
        {type="numberEdit",x=p_min.x, y=p_min.y, w=p_min.w, min=p_min.min, max=p_min.max,
            get=function() return timer_mm end,
            set=function(val) timer_mm=val end
        },
        {type="label", text=p_sec.text, x=p_sec.x, y=p_sec.y - 20, color=BLACK},
        {type="numberEdit",x=p_sec.x, y=p_sec.y, w=p_sec.w, min=p_sec.min, max=p_sec.max,
            get=function() return timer_ss end,
            set=function(val) timer_ss=val end
        },
        {type="label", x=180, y=140, color=BLACK, font=m_utils.FS.FONT_16, text=function() return formatTime2(timer_hh, timer_mm, timer_ss) end},
        {type="label",text="Note: Changing the timer to count up\nNote: Changing the timer to be persistent", x=50, y=190, color=GREY}
    })

    return nil
end

function M.do_update_model()
    log("preset::do_update_model()")

    local timeId = selected_timer_id - 1
    local t1 = model.getTimer(timeId)
    t1.value = timer_hh * 3600 + timer_mm * 60 + timer_ss
    t1.start = 0
    t1.persistent = 2
    t1.name = "Air Time"
    model.setTimer(timeId, t1)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

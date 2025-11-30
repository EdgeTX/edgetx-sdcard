local m_log,m_utils  = ...

-- Author: Offer Shmuely (2025)
local ver = "1.0"
local app_name = "flight_widget_adj"

local M = {}
M.height = 270

local num_flights = 0
local flights_count = 0

---------------------------------------------------------------------------------------------------
local Fields = {
    num_flights = { text='Num Flights', x=190, y=90, w=50, is_visible=1, default_value=6, min=0, max=1000 },
}
---------------------------------------------------------------------------------------------------

local function log(fmt, ...)
    m_log.info(fmt, ...)
    print(app_name .. string.format(fmt, ...))
end
---------------------------------------------------------------------------------------------------

-- get flight count
local function getFlightCount()
    -- get GV9 (index = 0) from Flight mode 0 (FM0)
    local num_flights = model.getGlobalVariable(8, 0)
    return num_flights
end

function M.init(box)
    flights_count = getFlightCount()
    num_flights = flights_count

    local p = Fields.num_flights

    box:build({
        {type="label", text="Setting flight count to this model", x=30, y=15, color=BLACK},
        {type="label", text=function() return string.format("original flights count:  %s", flights_count) end, x=50, y=60, color=BLACK},
        -- {type="label", text=function() return tostring(flights_count) end, x=p.x, y=60, color=BLACK},
        {type="label", text="new flights count:", x=50, y=p.y +5, color=BLACK},
        {type="numberEdit", x=p.x, y=p.y, w=p.w, min=p.min, max=p.max,
            get=function() return num_flights end,
            set=function(val) num_flights=val end
        },
    })

    return nil
end

function M.do_update_model()
    log("preset::num_flights()")

    model.setGlobalVariable(8, 0, num_flights)
    log("num_flights updated: " .. num_flights)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

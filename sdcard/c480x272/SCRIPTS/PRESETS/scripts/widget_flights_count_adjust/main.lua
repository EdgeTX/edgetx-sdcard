local m_log,m_utils,m_libgui  = ...

-- Author: Offer Shmuely (2023)
local ver = "0.1"
local app_name = "flight_widget_adj"

local M = {}

local ctx2
local label_new_time
local label_org_time

---------------------------------------------------------------------------------------------------
local Fields = {
    num_flights = { text = 'Num Flights', x = 210, y = 90 , w = 30, is_visible = 1, default_value = 6, min = 0, max = 1000 },
}
---------------------------------------------------------------------------------------------------

function M.getVer()
    return ver
end

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


function M.init()
    local menu_x = 50
    local menu_w = 60
    local menu_h = 26

    ctx2 = m_libgui.newGUI()
    local flights_count = getFlightCount()

    local p = Fields.num_flights

    ctx2.label(menu_x, 60, 0, menu_h, "original flights count:", m_utils.FONT_8)
    label_org_time = ctx2.label(p.x, 60, 0, menu_h, flights_count, m_utils.FONT_8)

    ctx2.label(menu_x,  p.y, 0, menu_h, "new flights count:", m_utils.FONT_8)
    p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, flights_count, nil, m_utils.FONT_8, p.min, p.max)

    ctx2.label(menu_x, 250, 0, menu_h, "Setting flight count to this model", m_utils.FONT_8)
    return nil
end


function M.draw_page(event, touchState)

    local num_flights = Fields.num_flights.gui_obj.value

    ctx2.run(event, touchState)
    return m_utils.PRESET_RC.OK_CONTINUE
end

function M.do_update_model()
    log("preset::num_flights()")

    local new_flight_count = Fields.num_flights.gui_obj.value

    model.setGlobalVariable(8, 0, new_flight_count)
    log("num_flights updated: " .. new_flight_count)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M

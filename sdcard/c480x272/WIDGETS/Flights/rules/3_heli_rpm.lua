local args = {...}
local m_log = args[1]
local app_name = args[2]
local switch_name = args[3]
local motor_channel_name = args[4]

local info = [[
Flight Rules
flight active when:
1. Telemetry available
2. headspeed is above 500 rpm
Notes:
rpm sensor 'Hspd' is required
]]

local FlightLogicRule = assert(loadScript("/WIDGETS/" .. app_name .. "/rules/FlightLogicRule", "btd"), "Failed to load trigger Base Class")(m_log, app_name, switch_name, motor_channel_name)

local M = FlightLogicRule:new()

local status_me = {
    is_rpm_on = false,
}

local function log(fmt, ...)
    FlightLogicRule:log(fmt, ...)
end

function M:info()
    return info
end

function M:is_flight_starting()
    if (M.status.tele_is_available == false) then
        return false
    end
    -- if (M.status.switch_on == false) then
    --     return false
    -- end
    if (status_me.is_rpm_on == false) then
        return false
    end

    return true
end

function M:is_still_on_flight()
    -- if M.status.switch_on == false then
    --     return false
    -- end
    if status_me.is_rpm_on == false then
        return false
    end
    return true
end

function M:is_flight_ending()
    return (status_me.is_rpm_on == false)
end

function M:is_dot_1()
    return M.status.tele_is_available==true
end
-- function M:is_dot_2()
--     return M.status.switch_on==true
-- end
function M:is_dot_3()
    return status_me.is_rpm_on==true
end

function M:dot_1_txt()
    return string.format("%s - telemetry", M:to_on_off(M.status.tele_is_available))
end

-- function M:dot_2_txt()
--     return string.format("%s - arm_switch (%s)",  M:to_on_off(M.status.switch_on), M.status.switch_name)
-- end

function M:dot_3_txt()
    return string.format("%s - rpm_on (%s)" , M:to_on_off(status_me.is_rpm_on), "tlm: Hspd")
end

function M:background(wgt)

    local hspd = getValue("Hspd")
    -- local rpm = getValue("rpm")

    if hspd ~= nil then
        status_me.is_rpm_on = (hspd > 500)
    else
        status_me.is_rpm_on = false
    end

end


return M

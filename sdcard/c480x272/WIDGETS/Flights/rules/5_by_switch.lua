local args = {...}
local m_log = args[1]
local app_name = args[2]
local switch_name = args[3]
local motor_channel_name = args[4]

local info = [[
Flight Rules
flight active when:
1. Arm switch ON
Notes:
only the switch control the flight
the switch can be physical / logical
]]

local FlightLogicRule = assert(loadScript("/WIDGETS/" .. app_name .. "/rules/FlightLogicRule", "btd"), "Failed to load trigger Base Class")(m_log, app_name, switch_name, motor_channel_name)

local M = FlightLogicRule:new()

local function log(fmt, ...)
    FlightLogicRule:log(fmt, ...)
end

function M:info()
    return info
end

function M:is_flight_starting()
    return (M.status.switch_on == true)
end

function M:is_still_on_flight()
    return (M.status.switch_on == true)
end

function M:is_flight_ending()
    return (M.status.switch_on == false)
end

function M:is_dot_2()
    return M.status.switch_on==true
end

function M:dot_2_txt()
    return string.format("%s - arm_switch (%s)",  M:to_on_off(M.status.switch_on), M.status.switch_name)
end


return M

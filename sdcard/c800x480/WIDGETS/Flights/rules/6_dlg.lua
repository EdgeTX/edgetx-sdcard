local args = {...}
local m_log = args[1]
local app_name = args[2]
local switch_name = args[3]
local motor_channel_name = args[4]

local info = [[
Flight Rules - DLG (Discus Launch Glider)
flight active when:
1. Telemetry available
2. Height increase detected (vario/altitude)
3. Vario Telemetry available
Notes:
- Flight starts when vario detect launch
- Flight ends when height below 3m
]]

local FlightLogicRule = assert(loadScript("/WIDGETS/" .. app_name .. "/rules/FlightLogicRule", "btd"), "Failed to load trigger Base Class")(m_log, app_name, wgt_status)

local M = FlightLogicRule:new()

-- DLG specific variables
-- local height_threshold  = 5 -- meters above starting height to consider flight active
-- local landing_threshold = 2 -- meters above starting height to consider landing

local VSPEED_DETECT_THROW = 8
-- local VSPEED_DETECT_THROW_DONE = 1
-- local ALTITUDE_DETECT_ON_AIR = 20 -- meters, threshold to detect if we are on air
local ALTITUDE_DETECT_LANDING = 2 -- meters, threshold to start detect landing

local status_me = {
    is_throwing = false,
    is_still_flying = false,
    is_landing = false
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
    return status_me.is_throwing
end

function M:is_still_on_flight()
    return status_me.is_still_flying
end

function M:is_flight_ending()
    return status_me.is_landing
end

function M:is_dot_1()
    return M.status.tele_is_available==true
end

function M:is_dot_2()
    return self.status.is_throwing or self.status.is_still_flying
end


function M:dot_1_txt()
    return string.format("%s - telemetry", M:to_on_off(M.status.tele_is_available))
end

function M:dot_2_txt()
    return string.format("%s - vario", M:to_on_off(status_me.is_throwing or status_me.is_still_flying))
end

function M:override_min_flight_time()
    return 1.0
end

function M:background(wgt)

    if (self.status.tele_is_available == false) then
        status_me.is_throwing = false
        status_me.is_still_flying = false
        status_me.is_landing = false
        return
    end

    local alt = getValue("Alt") or 0
    local vspd = getValue("VSpd") or 0

    status_me.is_throwing     = (vspd > VSPEED_DETECT_THROW)
    status_me.is_still_flying = (alt >= ALTITUDE_DETECT_LANDING)
    status_me.is_landing      = (alt < ALTITUDE_DETECT_LANDING)
end

return M

local args = {...}
local m_log = args[1]
local app_name = args[2]
local switch_name = args[3]
local motor_channel_name = args[4]

local default_min_motor_value = 200

local FlightLogicRule = {
    m_log = m_log,
    app_name = app_name,

    status = {
        switch_on = nil,
        switch_name = switch_name,
        tele_is_available = nil,
        motor_active = nil,
        motor_channel_name = motor_channel_name,
        motor_channel_direction_inv = nil,
    }


}

function FlightLogicRule:new (o)
    o = o or {}
    setmetatable(o, FlightLogicRule)
    FlightLogicRule.__index = FlightLogicRule
    return o
end

function FlightLogicRule:log(fmt, ...)
    FlightLogicRule.m_log.info(fmt, ...)
end

FlightLogicRule.info = function()
    return "I am trigger class"
end

function FlightLogicRule:is_flight_starting()
    return false
end

function FlightLogicRule:is_still_on_flight()
    return false
end

function FlightLogicRule:is_flight_ending()
    return false
end

function FlightLogicRule:is_dot_1()
    return true
end

function FlightLogicRule:is_dot_2()
    return true
end

function FlightLogicRule:is_dot_3()
    return true
end

function FlightLogicRule:to_on_off(cond)
    if cond then
        return "ON"
    else
        return "OFF"
    end
end

function FlightLogicRule:dot_1_txt()
    return "---"
end

function FlightLogicRule:dot_2_txt()
    return "---"
end

function FlightLogicRule:dot_3_txt()
    return "---"
end

function FlightLogicRule:override_min_flight_time()
    return nil
end

function FlightLogicRule:updateMotorStatus(wgt)
    -- -- for heli, if the motor-sw==switch-sw, then ignore motor direction detection
    -- if (wgt.heli_mode == true) then
    --     status.motor_active = status.switch_on
    --     return
    -- end

    local motor_value = getValue(wgt.options.motor_channel)
    --log(string.format("motor_value (%s): %s", wgt.options.motor_channel, motor_value))

    if (self.status.motor_channel_direction_inv == nil) then
        -- detect motor channel direction
        if (motor_value < (-1024 + default_min_motor_value)) then
            self.status.motor_channel_direction_inv = false
        elseif (motor_value > (1024 - default_min_motor_value)) then
            self.status.motor_channel_direction_inv = true
        else
            -- still nil
            return
        end
    end

    if (FlightLogicRule.status.motor_channel_direction_inv == false) then
        -- non inverted mixer
        if (motor_value > (-1024 + default_min_motor_value)) then
            FlightLogicRule.status.motor_active = true
        else
            FlightLogicRule.status.motor_active = false
        end
    else
        -- inverted mixer
        if (motor_value < (1024 - default_min_motor_value)) then
            FlightLogicRule.status.motor_active = true
        else
            FlightLogicRule.status.motor_active = false
        end
    end

end

function FlightLogicRule:background(wgt)
    -- update switch status
    FlightLogicRule.status.switch_on = getSwitchValue(wgt.options.arm_switch_id)

    self:updateMotorStatus(wgt) -- always after updateSwitchStatus

    -- update telemetry status
    FlightLogicRule.status.tele_is_available = wgt.tools.isTelemetryAvailable()


    -- if status.switch_on==true then
    --    log(string.format("arm_switch(%s)=ON", status.switch_name))
    -- else
    --    log(string.format("arm_switch(%s)=OFF", status.switch_name))
    -- end

end

return FlightLogicRule

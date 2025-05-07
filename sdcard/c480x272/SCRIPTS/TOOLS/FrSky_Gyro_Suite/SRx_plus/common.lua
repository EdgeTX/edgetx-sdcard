local Telemetry = {}

function Telemetry.telemetryRead(field)
    return sportTelemetryPush(0x17, 0x30, 0x0C30, field)
end

function Telemetry.telemetryWrite(field, value)
     -- The Write is a 32bit value with bytes (D3,D2,D1,field)
    local newValue = bit32.bor(bit32.lshift(value,8), field)
    return sportTelemetryPush(0x17, 0x31, 0x0C30, newValue)
end

function Telemetry.telemetryPop()
    local physicalId, primId, dataId, value = sportTelemetryPop()

    if primId == 0x32 and dataId == 0x0C30 then -- Got a valid return
        return value
    end
    return nil
end

function Telemetry.parseValue(value)
    local D3,D2,D1,fieldId
  
    fieldId = bit32.band(value,0xFF) 
    D1      = bit32.band(bit32.rshift(value,8),0xFF)
    D2      = bit32.band(bit32.rshift(value,16),0xFF)
    D3      = bit32.band(bit32.rshift(value,24),0xFF)
  
    return fieldId, D1, D2, D3  
  end


return {Telemetry = Telemetry }
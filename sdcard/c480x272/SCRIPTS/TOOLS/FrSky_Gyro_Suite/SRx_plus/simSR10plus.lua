-- SIMULATION of a Archer+ SR10+
-- Autor: Frankie Arzu 

local SimTelemetry = {
    APPID       = 0x0C30,    
    returnValue = nil,
    lastGetTime = 0,
    getGetDelay = 1
}

local function makeValue(fieldId, D1, D2, D3)
    local value = fieldId
    if (D1) then value = bit32.bor(value,bit32.lshift(D1,8)) end
    if (D2) then value = bit32.bor(value,bit32.lshift(D2,16)) end
    if (D3) then value = bit32.bor(value,bit32.lshift(D3,24)) end
    return value
end

function SimTelemetry.parseValue(value)
  local D3,D2,D1,fieldId

  fieldId = bit32.band(value,0xFF) 
  D1      = bit32.band(bit32.rshift(value,8),0xFF)
  D2      = bit32.band(bit32.rshift(value,16),0xFF)
  D3      = bit32.band(bit32.rshift(value,24),0xFF)

  return fieldId, D1, D2, D3  
end


SimTelemetry.SimTable = {
  -- Group 1
  [0xA5] = makeValue(0xA5,1,0),       -- Stabilizer=ON, Reset
  [0xA6] = makeValue(0xA6,1,0,0),     -- Mounting= (0=Full, 1=QuickMode,), WingType = (0=Normal,1=Delta,2=VTail), Orientation = (Up=0) 
  [0xA7] = makeValue(0xA7,1,0,0),     -- CHMODE: Ch1/Ail,  Ch2/Ele, Ch3/Rud  (Inverted=0, Normal = 1) 
  [0xA8] = makeValue(0xA8,0,0),       -- CHMODE: Ch5/Ail2, Ch6/Elv2 , ?? 
  [0xA9] = makeValue(0xA9,0,0xFF,0),  -- Direction: Ail,  Ele, Rud (Normal=0, Inverted=0xFF)
  [0xAA] = makeValue(0xAA,0,0xFF,0),  -- Direction: Ail2. Ele2, ??
  [0xAB] = makeValue(0xAB,40,60,80), --  Stab Gains: Ail, Ele, Rud 
  [0xAC] = makeValue(0xAC,40,60,0),   -- AutoLevel Gains: Ail, Ele, ?? 
  [0xAD] = makeValue(0xAD,0, 60,80),  -- Hover Gains: ??, Ele, Rud 
  [0xAE] = makeValue(0xAE,40,00,60),  -- Knife Gains: Ail, ??, Rud 
  [0xAF] = makeValue(0xAF,0x80,0x80,0x80), -- Autolevel Offset Ail,Ele,Rud (middle=0x80)
  [0xB0] = makeValue(0xB0,0x80,0x80,0x80), -- Hover Offset: Ail,Ele,Rud
  [0xB1] = makeValue(0xB1,0x80,0x80,0x80), -- Knife Offset: Ail,Ele,Rud

  [0xB2] = makeValue(0xB2),          -- Initial 6-axis Calibration  
  
  [0xB3] = makeValue(0xB3,0,0,0),    -- Deg: Ail,Ele,Rud 
  [0xB4] = makeValue(0xB4,79,79),    -- Stick Pri (AIL1):  -79,+79
  [0xB5] = makeValue(0xB5,79,79),    -- Stick Pri (ELE1):  (79,79) (Rev Pri,Pri)
  [0xB6] = makeValue(0xB6,79,79),    -- Stick Pri (RUD):   (79,79)
  [0xB7] = makeValue(0xB7,79,79),    -- Stick Pri (AIL2):  (79,79)
  [0xB8] = makeValue(0xB8,79,79),    -- Stick Pri (ELE2):  (79,79)
  [0xB9] = makeValue(0xB9),          -- Level + Stick Calibration

  -- Group2
  [0xC0] = makeValue(0xC0,1,0),       -- Stabilizer=ON, Reset = 0
  [0xC1] = makeValue(0xC1,0,0,0),     -- Mounting= (0=Full, 1=QuickMode,), WingType = (0=Normal,1=Delta,2=VTail), Orientation = (Up=0) 
  [0xC2] = makeValue(0xC2,1,0,0),     -- CHMODE: Ch1/Ail,  Ch2/Ele, Ch3/Rud  (Inverted=0, Normal = 1) 
  [0xC3] = makeValue(0xC3,0,0),       -- CHMODE: Ch5/Ail2, Ch6/Elv2 , ?? 
  [0xC4] = makeValue(0xC4,0,0xFF,0),  -- Direction: Ail,  Ele, Rud (Normal=0, Inverted=0xFF)
  [0xC5] = makeValue(0xC5,0,0xFF,0),  -- Direction: Ail2. Ele2, ??
  [0xC6] = makeValue(0xC6,40,60,80), --  Stab Gains: Ail, Ele, Rud 
  [0xC7] = makeValue(0xC7,40,60,0),   -- AutoLevel Gains: Ail, Ele, ?? 
  [0xC8] = makeValue(0xC8,0, 60,80),  -- Hover Gains: ??, Ele, Rud 
  [0xC9] = makeValue(0xC9,40,00,60),  -- Knife Gains: Ail, ??, Rud 
  [0xCA] = makeValue(0xCA,0x80,0x80,0x80), -- Autolevel Offset Ail,Ele,Rud (middle=0x80)
  [0xCB] = makeValue(0xCB,0x80,0x80,0x80), -- Hover Offset: Ail,Ele,Rud
  [0xCC] = makeValue(0xCC,0x80,0x80,0x80), -- Knife Offset: Ail,Ele,Rud

  [0xCD] = makeValue(0xCD,0,0,0),    -- Deg: Ail,Ele,Rud 
  [0xCE] = makeValue(0xCE,79,79),    -- Stick Pri (AIL1):  -79,+79
  [0xCF] = makeValue(0xCF,79,79),    -- Stick Pri (ELE1):  (79,79) (Rev Pri,Pri)
  [0xD0] = makeValue(0xD0,79,79),    -- Stick Pri (RUD):   (79,79)
  [0xD1] = makeValue(0xD1,79,79),    -- Stick Pri (AIL2):  (79,79)
  [0xD2] = makeValue(0xD2,79,79),    -- Stick Pri (ELE2):  (79,79)
  [0xD3] = makeValue(0xD3),          -- Level + Stick Calibration

  -- Info 
  [0xFE] = makeValue(0xFE,2,64),  -- ProductInfo: Family=2, ProductId=64 (Archer+ SR10+)
  [0xFF] = makeValue(0xFF,3,0,1), -- Version: 3.0,1
}

SimTelemetry.telemetryRead = function(page)
  local this = SimTelemetry
  print(string.format("SimTelemetryRead(%02X)",page))
  local val =  this.SimTable[bit32.band(page,0xFF)]
  this.returnValue = val -- Store returnValue for next getParameter() call
  return true
end

SimTelemetry.telemetryWrite = function(page, value)
  local this = SimTelemetry
  print(string.format("SimTelemetryWrite(%02X,%06X)",page, value))

  value = bit32.bor(page,bit32.lshift(value,8))

  local pageId, D1, D2, D3 = SimTelemetry.parseValue(value)
  if ((pageId == 0xA5) or (pageId==0xC0)) and 
      (D3==0x81) then
    print("GYRO RESET !!!!!")  
    value = bit32.band(value,0x00FFFFFF) -- Remove Reset 0x81
  end
  if (pageId >= 0xFE) then
    -- RX Info/Version are read-only
    return true
  end
  this.SimTable[pageId] = value -- Store data in Sim Memory
  return true
end

SimTelemetry.telemetryPop = function()
  local this = SimTelemetry
  
  if (getTime() < this.lastGetTime + this.getGetDelay) then -- Delay of returning next value
    return nil
  end 

  this.getGetDelay = 0
  this.lastGetTime = getTime()

  if (this.returnValue) then -- Do we have a previous requestParameter??
    local val =  this.returnValue
    this.returnValue = nil

    local pageId, D1, D2, D3 = SimTelemetry.parseValue(val)
    if (pageId == 0xB9) or (pageId == 0xD3) then -- Level + Stick Calibration
      print(string.format("SimTelemetryPop(): Calibration: exeStep=%d, exeState=%d", D1, D2))
      
      -- Write Calibration DONE to Sim Memory, With delay of 3 seconds
      D2 = 2 -- Set exeState = Done (2)
      this.SimTable[pageId] = makeValue(pageId,D1,D2,D3)  
      this.getGetDelay = 3
    elseif (pageId == 0xB2) then -- 6-Axis calibration 
        print(string.format("SimTelemeryPop(): 6-Axis: exeStep=%d, exeState=%d", D1, D2))
        this.getGetDelay = 4 * 100 -- 4s (100 ticks per second)
    end

    print(string.format("SimTelemetryPop() = %08X", val))
    return val
  end
  return nil
end


return { Telemetry = SimTelemetry }
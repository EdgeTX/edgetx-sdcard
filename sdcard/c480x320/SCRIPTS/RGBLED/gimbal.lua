--
-- Copyright (C) EdgeTX
--
-- Based on code named
--   opentx - https://github.com/opentx/opentx
--   th9x - http://code.google.com/p/th9x
--   er9x - http://code.google.com/p/er9x
--   gruvin9x - http://code.google.com/p/gruvin9x
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 2 as
-- published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--

local ail, ele, rud, thr
local prev_ail, prev_ele, prev_rud, prev_thr = 0, 0, 0, 0
local delta_ail, delta_ele, delta_rud, delta_thr = 0, 0, 0, 0

-- Configuration constants for delta thresholds
local DELTA_THRESHOLD_HIGH = 50   -- High delta change threshold
local DELTA_THRESHOLD_MED = 25    -- Medium delta change threshold
local DELTA_THRESHOLD_LOW = 10    -- Low delta change threshold
local DELTA_MIN_MOVEMENT = 3      -- Minimum delta to allow LED updates

-- Base LED settings
local BASE_LED_R, BASE_LED_G, BASE_LED_B = 50, 0, 0

local function init()
  -- Initialize all values to current stick positions
  ail = getValue("ail") or 0
  thr = getValue("thr") or 0
  rud = getValue("rud") or 0
  ele = getValue("ele") or 0  
end

local function calculateDeltas()
  -- Calculate delta values for all controls
  delta_ail = math.abs(ail - prev_ail)
  delta_thr = math.abs(thr - prev_thr)
  delta_rud = math.abs(rud - prev_rud)
  delta_ele = math.abs(ele - prev_ele)
end

local function shouldUpdateLeds()
  -- Check if any control has moved enough to warrant LED updates
  local max_delta = math.max(delta_ail, delta_thr, delta_rud, delta_ele)
  return max_delta >= DELTA_MIN_MOVEMENT
end

local function setLed(ring, h, v)
  local magnitude = math.sqrt(h^2 + v^2)
  if magnitude < 0.1 then return end
  
  local angle = math.atan2(v, h)
  angle = (math.deg(angle) + 360) % 360
  local center_index = math.floor(angle / 36 + 0.5) % 10
  center_index = center_index + ring * 10
  
  -- Scale intensity based on delta values for more responsive feedback
  local delta_factor = 1.0
  if ring == 0 then
    delta_factor = 1.0 + (delta_ail + delta_thr) / 200
  else
    delta_factor = 1.0 + (delta_rud + delta_ele) / 200
  end
  
  local base_intensity = 250 * magnitude * math.min(delta_factor, 2.0)
  base_intensity = math.min(255, base_intensity)
  
  local spread = 2
  for offset = -spread, spread do
    local index = (center_index + offset) % 10 + ring * 10
    local distance = math.abs(offset)
    local factor = math.exp(-0.5 * (distance ^ 2))
    local intensity = math.floor(base_intensity * factor)
    setRGBLedColor(index, intensity, intensity, intensity)
  end
end

local function run()
  -- this scripts is hardcoded for tx15 ring lights
  local ver, radio, maj, minor, rev, osname = getVersion()
  if radio ~= "tx15" then
    return
  end

  -- Get current values
  ail = getValue("ail")
  thr = getValue("thr")
  rud = getValue("rud")
  ele = getValue("ele")
  
  -- Calculate deltas
  calculateDeltas()
  
  -- Only update LEDs if there's significant movement
  if not shouldUpdateLeds() then
    -- Skip LED updates for very small movements
    return
  end
  
  -- Set base LED color (will be overridden by delta actions if triggered)
  for i = 0, LED_STRIP_LENGTH - 1 do
    setRGBLedColor(i, BASE_LED_R, BASE_LED_G, BASE_LED_B)
  end

  -- Apply normal LED patterns (enhanced with delta feedback)
  local radioMode = getStickMode()
  if radioMode == 1 then
    setLed(0, -ail/1024, thr/1024)
    setLed(1, rud/1024, -ele/1024)
  elseif radioMode == 2 then
    setLed(0, -ail/1024, ele/1024)
    setLed(1, rud/1024, -thr/1024)
  end
  
  applyRGBLedColors()
  
  -- Store previous values
  prev_ail, prev_ele, prev_rud, prev_thr = ail or 0, ele or 0, rud or 0, thr or 0
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
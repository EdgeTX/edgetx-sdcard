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

local sticks = { ail = 0, ele = 0, rud = 0, thr = 0 }
local prev   = { ail = 0, ele = 0, rud = 0, thr = 0 }
local deltas = { ail = 0, ele = 0, rud = 0, thr = 0 }

-- Which stick drives which ring, per radio mode:
-- { ring 0 horizontal, ring 0 vertical, ring 1 horizontal, ring 1 vertical }
-- ring 0 is the right gimbal, ring 1 the left gimbal
local MODE_AXES = {
  [1] = { "ail", "thr", "rud", "ele" },
  [2] = { "ail", "ele", "rud", "thr" },
  [3] = { "rud", "thr", "ail", "ele" },
  [4] = { "rud", "ele", "ail", "thr" },
}

-- Base LED settings
local BASE_LED_R, BASE_LED_G, BASE_LED_B = 0, 50, 0

-- The strip is the two gimbal rings, ring 0 first then ring 1. Hardcoded
-- rather than read from LED_STRIP_LENGTH, which is unreliable here.
local LED_COUNT = 20
local RING_SIZE = 10

-- Radios with a LED ring around each gimbal, and how each ring is wired:
-- the sign to apply to the horizontal and vertical stick axis so that the lit
-- LED follows the stick. Rings do not all start at the same place nor run in
-- the same direction, so this differs per radio and per ring.
local RING_SIGNS = {
  tx15     = { [0] = { h = -1, v = 1 }, [1] = { h = 1, v = -1 } },
  gx15     = { [0] = { h = -1, v = 1 }, [1] = { h = 1, v =  1 } },
  tx16smk3 = { [0] = { h = -1, v = 1 }, [1] = { h = 1, v = -1 } },
}

local function readSticks()
  for name in pairs(sticks) do
    sticks[name] = getValue(name) or 0
  end
end

local function init()
  -- Initialize all values to current stick positions
  readSticks()
end

local function calculateDeltas()
  -- Calculate delta values for all controls
  for name, value in pairs(sticks) do
    deltas[name] = math.abs(value - prev[name])
  end
end

local function setLed(ring, h, v, delta)
  local magnitude = math.sqrt(h^2 + v^2)
  if magnitude < 0.1 then return end

  local angle = math.atan2(v, h)
  angle = (math.deg(angle) + 360) % 360
  local center_index = math.floor(angle / (360 / RING_SIZE) + 0.5) % RING_SIZE

  -- Scale intensity based on the delta of the two axes driving this ring
  local delta_factor = 1.0 + delta / 200

  local base_intensity = 250 * magnitude * math.min(delta_factor, 2.0)
  base_intensity = math.min(255, base_intensity)

  local spread = 2
  for offset = -spread, spread do
    local index = (center_index + offset) % RING_SIZE + ring * RING_SIZE
    local distance = math.abs(offset)
    local factor = math.exp(-0.5 * (distance ^ 2))
    local intensity = math.floor(base_intensity * factor)
    setRGBLedColor(index, intensity, intensity, intensity)
  end
end

local function setRing(signs, ring, h_axis, v_axis)
  local sign = signs[ring]
  setLed(ring, sign.h * sticks[h_axis] / 1024, sign.v * sticks[v_axis] / 1024,
         deltas[h_axis] + deltas[v_axis])
end

local function run()
  -- this script needs the gimbal ring lights
  local ver, radio, maj, minor, rev, osname = getVersion()
  local signs = RING_SIGNS[radio]
  if not signs then
    return
  end

  local axes = MODE_AXES[getStickMode()]
  if not axes then
    return
  end

  -- Get current values
  readSticks()

  -- Calculate deltas
  calculateDeltas()

  -- Paint the whole strip every cycle, so the part of the ring the stick is
  -- not pointing at always shows the base colour instead of staying dark
  for i = 0, LED_COUNT - 1 do
    setRGBLedColor(i, BASE_LED_R, BASE_LED_G, BASE_LED_B)
  end

  -- Apply normal LED patterns (enhanced with delta feedback)
  setRing(signs, 0, axes[1], axes[2])
  setRing(signs, 1, axes[3], axes[4])

  applyRGBLedColors()

  -- Store previous values
  for name, value in pairs(sticks) do
    prev[name] = value
  end
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }

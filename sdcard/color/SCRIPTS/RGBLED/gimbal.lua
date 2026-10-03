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

-- Base LED color when stick centered (0 - 1.0)
local MIN_R, MIN_G, MIN_B = 0.0, 0.2, 0.0    	-- Green

-- Maximum LED scale when stick at extreme end (0 - 1.0)
local MAX_R, MAX_G, MAX_B = 1.0, 1.0, 1.0    	-- White

-- radio gimbal LED details
-- per radio table with the following properties:
--    per_gimbal      - number of LEDs around each gimbal
--    right           - table of properties for the right gimbal
--        offset      - index of first LED
--        direction   - rotation direction for LEDs 1 = counter clock wise, -1 = clockwise
--        start_angle - angular position of the first LED in degrees (0 = right, 90 = up)
--    left            - table of properties for the left gimbal (as per the right gimbal)
-- assumes each gimbal has the same number of LEDs and the LEDs are equally spaced around the gimbal
local gimbal_leds = {
  tx15     = { per_gimbal = 10, right = { offset =  0, direction = -1, start_angle = 190 }, left = { offset = 10, direction = -1, start_angle =  10 } },
  tx16smk3 = { per_gimbal = 10, right = { offset =  0, direction = -1, start_angle = 190 }, left = { offset = 10, direction =  1, start_angle = 350 } },
  gx15     = { per_gimbal = 10, right = { offset =  0, direction = -1, start_angle = 190 }, left = { offset = 10, direction =  1, start_angle = 350 } },
  st16     = { per_gimbal =  6, right = { offset =  6, direction = -1, start_angle =  30 }, left = { offset =  0, direction = -1, start_angle = 330 } },
-- V16 does not have consistent LED ring orientation
--  v16      = { per_gimbal = 16, right = { offset = 16, direction = -1, start_angle = 270 }, left = { offset =  0, direction = -1, start_angle =  90 } },
}

-- Axis positions in tables
local RH = 1
local RV = 2
local LH = 3
local LV = 4

-- Minimum delta to allow LED updates
local DELTA_MIN_MOVEMENT = 3

local axis = {}
local sticks = {}
local prev = { 0, 0, 0, 0 }
local dif_r, dif_g, dif_b
local min_r, min_g, min_b
local fade

local leds
local angles = {}

local function getLedDetails()
  -- values for setting LED intensity
  dif_r, dif_g, dif_b = MAX_R - MIN_R, MAX_G - MIN_G, MAX_B - MIN_B
  min_r, min_g, min_b = MIN_R * 255, MIN_G * 255, MIN_B * 255

  -- Get gimbal led details for current radio
  local ver, radio, maj, minor, rev, osname = getVersion()
  radio = string.gsub(radio, "-simu", "")
  leds = gimbal_leds[radio]

  if leds then
    local led_angle = 360 / leds.per_gimbal

    fade = 180 / leds.per_gimbal
    if MIN_R + MIN_G + MIN_B > 0.1 then fade = fade * 1.5 end

    for i = leds.right.offset, leds.right.offset + leds.per_gimbal - 1 do
      angles[i+1] = (leds.right.start_angle + i * led_angle * leds.right.direction) % 360
    end

    for i = leds.left.offset, leds.left.offset + leds.per_gimbal - 1 do
      angles[i+1] = (leds.left.start_angle + i * led_angle * leds.left.direction) % 360
    end
  end

  for i = RH, LV do
    prev[i] = 10000
  end
end

local function getAxisNames()
  -- get axis names based on mode
  local radioMode = getStickMode()
  if radioMode < 3 then
    axis[LH] = "rud"
    axis[RH] = "ail"
  else
    axis[LH] = "ail"
    axis[RH] = "rud"
  end
  if radioMode == 1 or radioMode == 3 then
    axis[LV] = "ele"
    axis[RV] = "thr"
  else
    axis[LV] = "thr"
    axis[RV] = "ele"
  end
end

local function getValues()
  -- Get current values
  for i = RH, LV do
    sticks[i] = getValue(axis[i]) or 0
  end
end

local function shouldUpdate(h, v)
  -- Check if any control has moved enough to warrant LED updates
  local dh = math.abs(sticks[h] - prev[h])
  local dv = math.abs(sticks[v] - prev[v])
  return math.max(dh, dv) >= DELTA_MIN_MOVEMENT
end

local function setLeds(first_led, led_count, ih, iv)
  -- save values for next update
  prev[ih], prev[iv] = sticks[ih], sticks[iv]

  -- get position
  local h = sticks[ih] / 1024
  local v = sticks[iv] / 1024

  -- get vector for stick position
  local magnitude = math.min(255, 255 * math.sqrt(h^2 + v^2))
  local angle = (math.deg(math.atan2(v, h)) + 360) % 360

  -- check if centered
  if magnitude < 0.1 then
    for i = first_led, first_led + led_count - 1 do
      setRGBLedColor(i, min_r, min_g, min_b)
    end
    return
  end

  -- Set all LEDs from stick position
  for i = first_led + 1, first_led + led_count do
    local distance = math.abs((angle - angles[i] + 180) % 360 - 180) / fade
    local intensity = math.floor(magnitude * math.exp(-0.5 * (distance ^ 2)))
    setRGBLedColor(i-1,
          dif_r * intensity + min_r,
          dif_g * intensity + min_g,
          dif_b * intensity + min_b)
  end
end

local function run()
  -- this script needs the gimbal ring lights
  if not leds then return end

  -- Get current values
  getValues()

  local update = false

  -- Only update LEDs if there's significant movement
  if shouldUpdate(RH, RV) then
    -- Apply LED patterns
    setLeds(leds.right.offset, leds.per_gimbal, RH, RV)

    update = true
  end

  -- Only update LEDs if there's significant movement
  if shouldUpdate(LH, LV) then
    -- Apply LED patterns
    setLeds(leds.left.offset, leds.per_gimbal, LH, LV)

    update = true
  end

  if update then
    applyRGBLedColors()
  end
end

local function background()
end

local function init()
  getAxisNames()
  getLedDetails()
end

return { run=run, background=background, init=init }

---------------------------------------------------------------------------
-- Control serial port power via touch or keys.                          --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- SerialPower widget body, loaded by main.lua when an instance is created.
--
-- Widget mode: shows the AUX1/AUX2 power state.
-- Full screen: toggle switches to turn AUX1/AUX2 power on and off.
--
-- serialGetPower()/serialSetPower() only exist on radios built with
-- SWSERIALPOWER (e.g. TX16S), and never in the simulator.

local lvSCALE = lvgl.LCD_SCALE or 1
local PAD = lvgl.PAD_OUTLINE or 4

local PORTS = {
  { id = 0, name = "AUX1" },
  { id = 1, name = "AUX2" },
}

-- true/false = power state, nil = port has no power control
local function getPower(port)
  if serialGetPower == nil then return nil end
  return serialGetPower(port)
end

local function stateText(port)
  local on = getPower(port)
  if on == nil then return "N/A" end
  return on and "On" or "Off"
end

local function stateColor(port)
  local on = getPower(port)
  if on == nil then return GREY end
  return on and GREEN or RED
end

local function buildWidget(wgt)
  local z = wgt.zone
  local rowH = z.h // #PORTS

  local font = SMLSIZE
  if rowH >= 40 * lvSCALE then
    font = MIDSIZE
  elseif rowH >= 20 * lvSCALE then
    font = 0
  end

  local dot = math.max(6, math.min(rowH // 2, 16 * lvSCALE))

  for i, p in ipairs(PORTS) do
    lvgl.box({ x = 0, y = (i - 1) * rowH, w = z.w, h = rowH,
      children = {
        { type = "rectangle", x = PAD, y = (rowH - dot) // 2, w = dot, h = dot,
          rounded = dot // 2, filled = true,
          color = function() return stateColor(p.id) end },
        { type = "label", x = PAD * 2 + dot, text = p.name, font = font,
          align = VCENTER, color = wgt.options.Color },
        { type = "label", x = 0, w = z.w - PAD, font = font,
          align = RIGHT + VCENTER, color = wgt.options.Color,
          text = function() return stateText(p.id) end },
      }
    })
  end
end

local function buildFullScreen()
  local pg = lvgl.page({
    title = "Serial Power",
    subtitle = "AUX port power control",
    back = function() lvgl.exitFullScreen() end,
    flexFlow = lvgl.FLOW_COLUMN,
    align = LEFT + VTOP,
  })

  if serialSetPower == nil then
    lvgl.label(pg, { text = "Serial port power control is not available on this radio.",
      color = COLOR_THEME_PRIMARY1 })
    return
  end

  local rowW = LCD_W - PAD * 2
  local toggleX = rowW - PAD * 2 - 52 * lvSCALE

  for _, p in ipairs(PORTS) do
    local row = lvgl.setting(pg, { title = p.name .. " power", w = rowW })
    if getPower(p.id) == nil then
      lvgl.label(row, { x = toggleX, text = "N/A", color = COLOR_THEME_PRIMARY1 })
    else
      lvgl.toggle(row, { x = toggleX,
        get = function() return getPower(p.id) end,
        set = function(val) serialSetPower(p.id, val) end,
      })
    end
  end
end

local function build(wgt)
  lvgl.clear()
  wgt.fullscreen = lvgl.isFullScreen()
  if wgt.fullscreen then
    buildFullScreen()
  else
    buildWidget(wgt)
  end
end

local function create(zone, options)
  -- UI is built by update(), which the firmware calls right after create()
  return { zone = zone, options = options }
end

local function update(wgt, options)
  wgt.options = options
  build(wgt)
end

local function refresh(wgt, event, touchState)
  -- Entering/leaving full screen does not call update(), so rebuild here
  if lvgl.isFullScreen() ~= wgt.fullscreen then
    build(wgt)
  end
end

return { create = create, update = update, refresh = refresh }

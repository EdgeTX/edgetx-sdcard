local toolName = "TNS|ACCESS Module Options|TNE"
---- #########################################################################
---- #                                                                       #
---- # Options of FrSky ACCESS modules (ISRM, R9M ACCESS, XJT Lite)          #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- PXX2 messages used (payload = bytes following TYPE_ID), through
-- accessFramePush / accessFramePop:
--  4 TX settings  request: flag0 (0x40 = write), then on write flag1, power
--                 answer:  flag0, flag1 (0x08 = external antenna), power (dBm)
--  6 HW info      request: 0xFF (the module itself)
--                 answer:  0xFF, model ID, hw version (2), sw version (2), variant

local TX_SETTINGS, HW_INFO = 4, 6
local MODULE_ID = 0xFF
local F_WRITE, F_EXT_ANTENNA = 0x40, 0x08
local VARIANT_EU = 2

-- module types, as in model.getModule()
local PXX2_MODULES = { [3] = true, [8] = true, [10] = true, [12] = true, [14] = true }

local RETRY = 200        -- 2s, in 10ms ticks
local WRITE_WAIT = 250
local TRIES = 5

local OPT_ANTENNA, OPT_POWER = 0x01, 0x02

-- by module model ID: name, options
local modules = {
  [1] = { "XJT", OPT_ANTENNA },
  [2] = { "ISRM", OPT_ANTENNA },
  [3] = { "ISRM-PRO", OPT_ANTENNA },
  [4] = { "ISRM-S", OPT_ANTENNA },
  [5] = { "R9M", OPT_POWER },
  [6] = { "R9MLite", OPT_POWER },
  [7] = { "R9MLite-PRO", OPT_POWER },
  [8] = { "ISRM-N", 0 },
  [9] = { "ISRM-S-X9", 0 },
  [10] = { "ISRM-S-X10E", OPT_ANTENNA },
  [11] = { "XJT Lite", OPT_ANTENNA },
  [12] = { "ISRM-S-X10S", OPT_ANTENNA },
  [13] = { "ISRM-X9LiteS", 0 },
}

-- available power levels (dBm), by model ID and EU variant
local function powerLevels(id, eu)
  if id == 6 then return eu and { 14, 20 } or { 20 } end
  if id == 5 or id == 7 then return eu and { 14, 23, 27 } or { 10, 20, 27, 30 } end
  return {}
end

local powerNames = { [10] = "10mW", [14] = "25mW", [20] = "100mW", [23] = "200mW", [27] = "500mW", [30] = "1W" }

local colorLcd = lcd.RGB ~= nil

-----------------------------------------------------------------------------
-- State
-----------------------------------------------------------------------------

local candidates = {}   -- module indexes
local module            -- the one being edited
local info              -- { id, variant, name, options }
local settings          -- { flag1, power }
local savedPower

local state = "start"   -- pick, info, read, edit, write, confirm, error, exit
local message = ""
local deadline, tries = 0, 0
local pending
local lines, sel, top, edit = {}, 1, 1, false
local dirty, exitAfterWrite = false, false

local function send(t, p, wait)
  pending = { t, p }
  deadline = getTime() + (wait or RETRY)
end

local function pump()
  if pending and accessFramePush(module, 1, pending[1], pending[2]) then
    pending = nil
  end
end

local function receive()
  while true do
    local m, c, t, p = accessFramePop()
    if not m then return end
    if m == module and c == 1 then return t, p end
  end
end

local function eu() return info.variant == VARIANT_EU end
local function telemetryOff() return eu() and settings.power > 14 end

-----------------------------------------------------------------------------
-- Module
-----------------------------------------------------------------------------

local function moduleLabel(idx)
  return idx == 0 and "Internal" or "External"
end

local function readInfo()
  state, message, tries, info = "info", "Waiting for module...", 1, nil
  while accessFramePop() do end
  send(HW_INFO, { MODULE_ID })
end

local function readSettings()
  state, message, tries = "read", "Reading...", 1
  send(TX_SETTINGS, { 0x00 })
end

local function writeSettings()
  state, message, edit = "write", "Writing...", false
  send(TX_SETTINGS, { F_WRITE, settings.flag1, settings.power }, WRITE_WAIT)
end

local function onHwInfo(p)
  if #p < 7 or p[1] ~= MODULE_ID then return end
  local m = modules[p[2]] or { string.format("ID 0x%02X", p[2]), 0 }
  info = { id = p[2], variant = p[7], name = m[1], options = m[2] }
  if info.options == 0 then
    state, message = "error", "No options"
  else
    readSettings()
  end
end

local function onTxSettings(p)
  if #p < 3 then return end
  local rebind = state == "write" and eu() and (savedPower > 14) ~= (p[3] > 14)
  settings = { flag1 = p[2], power = p[3] }
  savedPower = settings.power
  dirty = false
  if state == "write" and exitAfterWrite and not rebind then
    state = "exit"
    return
  end
  message = rebind and "Rebind RX!" or (state == "write" and "Saved" or "")
  state = "edit"
end

-----------------------------------------------------------------------------
-- Edition
-----------------------------------------------------------------------------

local function powerText(dBm)
  return dBm .. "dBm (" .. (powerNames[dBm] or "?") .. ")"
end

local function buildLines()
  lines = {}
  local function add(label, kind) lines[#lines + 1] = { label = label, kind = kind } end
  if info.options & OPT_ANTENNA ~= 0 then add("Ext. antenna", "antenna") end
  if info.options & OPT_POWER ~= 0 then
    add("Power", "power")
    if telemetryOff() then add("Telemetry OFF", "note") end
    if eu() and (savedPower > 14) ~= telemetryOff() then add("Rebind receivers", "note") end
  end
  add("Save", "save")
  sel = math.min(math.max(sel, 1), #lines)
  while lines[sel].kind == "note" do sel = sel + 1 end
end

local function lineValue(l)
  if l.kind == "antenna" then return settings.flag1 & F_EXT_ANTENNA ~= 0 and "ON" or "OFF" end
  if l.kind == "power" then return powerText(settings.power) end
end

local function changePower(dir)
  local list, pos = powerLevels(info.id, eu()), nil
  if #list == 0 then return end
  for i = 1, #list do if list[i] == settings.power then pos = i end end
  pos = pos and pos + dir or (dir > 0 and 1 or #list)
  settings.power = list[math.min(math.max(pos, 1), #list)]
  dirty, message = true, ""
  buildLines()
end

-----------------------------------------------------------------------------
-- Drawing
-----------------------------------------------------------------------------

local LINE_H = colorLcd and 24 or 8
local TOP_Y = colorLcd and 36 or 9
local VALUE_X = colorLcd and LCD_W // 2 or (LCD_W > 128 and 100 or 56)
local FONT = colorLcd and COLOR_THEME_SECONDARY1 or 0

local function visibleLines() return (LCD_H - TOP_Y) // LINE_H end

local function drawTitle(title, right)
  if colorLcd then
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, COLOR_THEME_SECONDARY1)
    lcd.drawText(8, 5, title, COLOR_THEME_PRIMARY2)
    if right then lcd.drawText(LCD_W - 8, 5, right, COLOR_THEME_PRIMARY2 + RIGHT) end
  else
    lcd.drawScreenTitle(title, 0, 0)
    if right then lcd.drawText(LCD_W, 0, right, SMLSIZE + INVERS + RIGHT) end
  end
end

local function drawRow(i, label, value, attr)
  local y = TOP_Y + (i - top) * LINE_H
  local x = colorLcd and 8 or 0
  if value then
    lcd.drawText(x, y, label, FONT)
    lcd.drawText(VALUE_X, y, value, FONT + attr)
  else
    lcd.drawText(x, y, label, FONT + attr)
  end
end

local function drawCentered(text, attr)
  lcd.drawText(LCD_W // 2, LCD_H // 2 - (colorLcd and 10 or 4), text, FONT + CENTER + (attr or 0))
end

local function scrollTo(count)
  local n = visibleLines()
  if sel < top then top = sel end
  if sel >= top + n then top = sel - n + 1 end
  if top > math.max(count - n + 1, 1) then top = math.max(count - n + 1, 1) end
end

local function draw()
  lcd.clear()
  local title = info and info.name or "ACCESS Module Options"
  if state == "pick" then
    drawTitle("Select module")
    for i = 1, #candidates do
      drawRow(i, moduleLabel(candidates[i]), nil, i == sel and INVERS or 0)
    end
  elseif state == "edit" or state == "write" then
    drawTitle(title, message ~= "" and message or nil)
    scrollTo(#lines)
    for i = top, math.min(#lines, top + visibleLines() - 1) do
      local l = lines[i]
      local attr = 0
      if i == sel then attr = (edit and BLINK or 0) + INVERS end
      drawRow(i, l.label, lineValue(l), attr)
    end
  elseif state == "confirm" then
    drawTitle(title)
    drawCentered("Save changes?")
    lcd.drawText(LCD_W // 2, LCD_H // 2 + (colorLcd and 20 or 6), "[ENTER] Yes  [EXIT] No",
                 (colorLcd and COLOR_THEME_SECONDARY1 or SMLSIZE) + CENTER)
  else
    drawTitle(title)
    drawCentered(message, state == "error" and 0 or BLINK)
  end
end

-----------------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------------

local function timeouts()
  if getTime() < deadline then return end
  if state == "write" then
    readSettings()   -- read back what the module kept
  elseif state == "info" or state == "read" then
    if tries < TRIES then
      tries = tries + 1
      if state == "info" then send(HW_INFO, { MODULE_ID }) else send(TX_SETTINGS, { 0x00 }) end
    else
      state, message = "error", "No answer"
    end
  end
end

local function poll()
  if not module then return end
  pump()
  while true do
    local t, p = receive()
    if not t then return end
    if t == HW_INFO and state == "info" then
      onHwInfo(p)
    elseif t == TX_SETTINGS and (state == "read" or state == "write") then
      onTxSettings(p)
      if state == "edit" then buildLines() end
    end
  end
end

local function moveSelection(dir)
  for _ = 1, #lines do
    sel = sel + dir
    if sel < 1 or sel > #lines then sel = sel - dir return end
    if lines[sel].kind ~= "note" then return end
  end
end

local function handleEdit(event)
  local l = lines[sel]
  if edit then
    if event == EVT_VIRTUAL_INC then changePower(1)
    elseif event == EVT_VIRTUAL_DEC then changePower(-1)
    elseif event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then edit = false end
    return
  end
  if event == EVT_VIRTUAL_NEXT then moveSelection(1)
  elseif event == EVT_VIRTUAL_PREV then moveSelection(-1)
  elseif event == EVT_VIRTUAL_ENTER then
    if l.kind == "save" then writeSettings()
    elseif l.kind == "antenna" then
      settings.flag1 = settings.flag1 ~ F_EXT_ANTENNA
      dirty, message = true, ""
    elseif l.kind == "power" then edit = true end
  end
end

local function init()
  candidates = {}
  if not accessFramePush then
    state, message = "error", "Needs newer EdgeTX"
    return
  end
  for idx = 0, 1 do
    local m = model.getModule(idx)
    if m and PXX2_MODULES[m.Type] then candidates[#candidates + 1] = idx end
  end
  if #candidates == 1 then
    module = candidates[1]
    readInfo()
  elseif #candidates > 1 then
    state = "pick"
  else
    state, message = "error", "No ACCESS module"
  end
end

local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  poll()
  timeouts()
  if state == "exit" then return 2 end

  if event == EVT_VIRTUAL_EXIT and not edit then
    if state == "edit" and dirty then
      state = "confirm"
    elseif (state == "edit" or state == "confirm" or state == "error") and #candidates > 1 then
      state, sel, top, module, info = "pick", 1, 1, nil, nil
    elseif state ~= "write" then
      return 2
    end
  elseif state == "pick" then
    if event == EVT_VIRTUAL_NEXT then sel = math.min(sel + 1, #candidates)
    elseif event == EVT_VIRTUAL_PREV then sel = math.max(sel - 1, 1)
    elseif event == EVT_VIRTUAL_ENTER then
      module, sel, top = candidates[sel], 1, 1
      readInfo()
    end
  elseif state == "edit" then
    handleEdit(event)
  elseif state == "confirm" then
    if event == EVT_VIRTUAL_ENTER then
      state, exitAfterWrite = "edit", true
      writeSettings()
    end
  elseif state == "error" and event == EVT_VIRTUAL_ENTER and module then
    readInfo()
  end

  draw()
  return 0
end

return { init = init, run = run }

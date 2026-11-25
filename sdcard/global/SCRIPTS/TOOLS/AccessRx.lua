local toolName = "TNS|ACCESS RX Options|TNE"
---- #########################################################################
---- #                                                                       #
---- # Receiver options of FrSky ACCESS receivers                            #
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

-- Works with:
--  - ACCESS modules (ISRM, R9M ACCESS), through accessFramePush / Pop
--  - the MULTI-Module FrSkyA protocol, through the multiBuffer "Pipe"
--
-- Both carry the PXX2 messages below (payload = bytes following TYPE_ID):
--  4 TX settings  request: flag0 (0x40 = write)
--                 answer:  flag0, flag1, power (ACCESS modules only)
--  5 RX settings  request: flag0 = receiver slot (0x40 = write), then on
--                          write flag1 and one byte per output
--                 answer:  flag0, flag1, one byte per output
--  6 HW info      request: receiver slot
--                 answer:  slot, model ID, hw version (2), sw version (2),
--                          variant, capabilities (little endian)

local TX_SETTINGS, RX_SETTINGS, HW_INFO = 4, 5, 6

local MODULE_ISRM, MODULE_MULTI = 3, 6
local R9M_ACCESS = { [8] = true, [10] = true, [12] = true }
local MULTI_FRSKYA = 112
local VARIANT_EU = 2

-- receiver capabilities
local CAP_FPORT, CAP_TELE25, CAP_PWM56, CAP_FPORT2, CAP_SBUS24 = 0x01, 0x02, 0x04, 0x08, 0x20
local CAP_KNOWN = 0x3F

-- RX settings flag1
local F_TELE_OFF, F_READONLY, F_SBUS24, F_FASTPWM, F_FPORT, F_TELE25, F_FPORT2 = 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x01

-- outputs of receivers with a configurable telemetry port
local MAP_SPORT, MAP_SBUS_OUT, MAP_SBUS_IN, MAP_FBUS = 0x40, 0x80, 0xA0, 0xC0

local RETRY = 200        -- 2s, in 10ms ticks
local SCAN_WAIT = 100
local WRITE_WAIT = 250   -- the receiver may restart after a write
local TRIES = 5

local rxNames = {
  "X8R", "RX8R", "RX8R Pro", "RX6R", "RX4R", "G-RX8", "G-RX6", "X6R", "X4R", "X4R SB",
  "XSR", "XSR M", "RXSR", "S6R", "S8R", "XM", "XM+", "XMR", "R9", "R9 SLIM",
  "R9 SLIM+", "R9 MINI", "R9 MM", "R9 Stab", "R9 Mini OTA", "R9 MM OTA", "R9 SLIM+ OTA", "Archer X", "R9MX", "R9SX",
  "TD MX", "TD R18", "TD R10", "TD R6", "TD R12", "TD SR12", "TD SR18",
  [0x31] = "TW MX", "TW SR12", "TW R12", "TW GR6", "TW GR8", "TW R6", "TW R8", "TW GR6FB", "TW R6FB",
  [0x40] = "SR10 Plus", "R10 Plus", "GR8 Plus", "R8 Plus", "SR8 Plus", "GR6 Plus", "R6 Plus", "R6M (ESC DC)",
  "RS Plus", "RS Mini", "R6FB", "GR6FB", "SR12 Plus", "R12 Plus", "R6 Mini ESC", "SR6 Mini", "SR6 Mini ESC",
}

-- receivers with a configurable telemetry port (dynamic outputs)
local telePort = {
  [0x20] = true, [0x21] = true, [0x23] = true, [0x24] = true, [0x25] = true,
  [0x32] = true, [0x33] = true, [0x40] = true, [0x41] = true, [0x4C] = true, [0x4D] = true,
}

local colorLcd = lcd.RGB ~= nil

-----------------------------------------------------------------------------
-- Links: send(type, payload) queues a message, pump() moves it toward the
-- module, receive() returns the next answer (type, payload) or nil
-----------------------------------------------------------------------------

local function accessLink(module)
  local pending
  while accessFramePop() do end   -- start receiving, drop old frames
  return {
    maxPayload = 58,
    send = function(t, p) pending = { t, p } end,
    pump = function()
      if pending and accessFramePush(module, 1, pending[1], pending[2]) then
        pending = nil
      end
    end,
    receive = function()
      while true do
        local m, c, t, p = accessFramePop()
        if not m then return end
        if m == module and c == 1 then return t, p end
      end
    end,
    close = function() end,
  }
end

-- multiBuffer: [0..3] "Pipe", [4] piece length (0 = sent), [5..11] piece:
-- type, offset << 4 | length, up to 5 bytes; [14] answer length (0 = none),
-- [15..] answer: type, length, data
local function multiLink()
  if type(multiBuffer) ~= "function" then return end
  multiBuffer(0, 80)
  if multiBuffer(0) ~= 80 then return end   -- no buffer
  multiBuffer(1, 105) multiBuffer(2, 112) multiBuffer(3, 101)
  multiBuffer(4, 0) multiBuffer(14, 0)
  local pieces = {}
  return {
    maxPayload = 15,
    send = function(t, p)
      pieces = {}
      for pos = 0, #p - 1, 5 do
        local piece = { t, pos * 16 + #p }
        for i = pos + 1, math.min(pos + 5, #p) do piece[#piece + 1] = p[i] end
        pieces[#pieces + 1] = piece
      end
    end,
    pump = function()
      if #pieces == 0 or multiBuffer(4) ~= 0 then return end
      local piece = pieces[1]
      for i = 1, #pieces do pieces[i] = pieces[i + 1] end
      for i = 1, 7 do multiBuffer(4 + i, piece[i] or 0) end
      multiBuffer(4, #piece)
    end,
    receive = function()
      local len = multiBuffer(14)
      if len < 2 then return end
      local t, total, p = multiBuffer(15), multiBuffer(16), {}
      for i = 1, math.min(total, len - 2) do p[i] = multiBuffer(16 + i) end
      multiBuffer(14, 0)
      if total + 2 <= len then return t, p end
    end,
    close = function() for i = 0, 46 do multiBuffer(i, 0) end end,
  }
end

-----------------------------------------------------------------------------
-- State
-----------------------------------------------------------------------------

local candidates = {}   -- receiver slots to look for: { module, slot, multi }
local receivers = {}    -- answering receivers: candidate + { id, name, variant, caps }
local rx                -- the one being edited
local link, linkKey
local settings          -- { flag1, outputs = { ... } }
local channels, firstChannel = 16, 0
local teleLocked        -- R9M EU module above 25 mW: telemetry can't be enabled

local state = "scan"    -- scan, pick, txread, read, edit, write, confirm, error
local message = ""
local deadline, tries = 0, 0
local lines, sel, top, edit = {}, 1, 1, false
local dirty, exitAfterWrite = false, false

local function openLink(c)
  local key = c.multi and "multi" or c.module
  if key == linkKey then return link end
  if link then link.close() end
  link = c.multi and multiLink() or accessLink(c.module)
  linkKey = link and key
  return link
end

local function request(t, p, wait)
  link.send(t, p)
  deadline = getTime() + (wait or RETRY)
end

local function versionText(major, b)
  if major == 0xFF and b == 0xFF then return "---" end
  return (major + 1) .. "." .. (b >> 4) .. "." .. (b & 0x0F)
end

local function hasCap(cap) return rx.caps & cap ~= 0 end
local function isSet(f) return settings.flag1 & f ~= 0 end
local function setFlag(f, on)
  settings.flag1 = on and (settings.flag1 | f) or (settings.flag1 & ~f)
  dirty, message = true, ""
end

-----------------------------------------------------------------------------
-- Receivers scan
-----------------------------------------------------------------------------

local oldFirmware       -- ACCESS module, but EdgeTX without accessFramePush / Pop

local function findCandidates()
  candidates, oldFirmware = {}, false
  for module = 0, 1 do
    local m = model.getModule(module)
    if m then
      if (m.Type == MODULE_ISRM and m.subType == 0) or R9M_ACCESS[m.Type] then
        if not accessFramePush then
          oldFirmware = true
        else
          for slot = 0, 2 do
            candidates[#candidates + 1] = { module = module, slot = slot, r9m = R9M_ACCESS[m.Type] }
          end
        end
      elseif m.Type == MODULE_MULTI and m.protocol == MULTI_FRSKYA then
        candidates[#candidates + 1] = { module = module, slot = 0, multi = true }
      end
    end
  end
end

local scanIndex

local function scanNext()
  scanIndex = scanIndex + 1
  local c = candidates[scanIndex]
  if c then
    if openLink(c) then
      request(HW_INFO, { c.slot }, SCAN_WAIT)
    else
      scanNext()
    end
  elseif #receivers == 1 then
    rx = receivers[1]
    state = "start"
  elseif #receivers > 1 then
    state, sel, top = "pick", 1, 1
  else
    state = "error"
    message = oldFirmware and "Needs newer EdgeTX"
      or #candidates == 0 and "No ACCESS module" or "No receiver found"
  end
end

local function startScan()
  findCandidates()
  receivers, scanIndex, state = {}, 0, "scan"
  scanNext()
end

local function onHwInfo(p)
  local c = candidates[scanIndex]
  if #p < 7 or p[1] ~= c.slot or p[2] == 0 then return end
  local caps = 0
  for i = #p, 8, -1 do caps = (caps << 8) | p[i] end
  receivers[#receivers + 1] = {
    module = c.module, slot = c.slot, multi = c.multi, r9m = c.r9m,
    id = p[2], variant = p[7], caps = caps,
    name = (rxNames[p[2]] or string.format("ID 0x%02X", p[2])) .. " " .. versionText(p[5], p[6]),
  }
  scanNext()
end

local function rxLabel(r)
  local where = r.module == 0 and "Int" or "Ext"
  if r.multi then where = "MPM" end
  return where .. " RX" .. (r.slot + 1)
end

-----------------------------------------------------------------------------
-- Settings
-----------------------------------------------------------------------------

local function readSettings()
  state, message, tries = "read", "Reading...", 1
  request(RX_SETTINGS, { rx.slot })
end

local function startReceiver()
  openLink(rx)
  local m = model.getModule(rx.module)
  if rx.multi then
    channels, firstChannel = 16, m.firstChannel
  else
    channels, firstChannel = m.channelsCount, m.firstChannel
  end
  settings, dirty, teleLocked = nil, false, false
  if rx.r9m and rx.variant == VARIANT_EU then
    state, message, tries = "txread", "Reading...", 1
    request(TX_SETTINGS, { 0x00 })
  else
    readSettings()
  end
end

local function writeSettings()
  local p = { 0x40 | rx.slot, settings.flag1 & ~F_READONLY }
  for i = 1, #settings.outputs do p[#p + 1] = settings.outputs[i] end
  if #p > link.maxPayload then
    message = "Too many outputs"
    return
  end
  state, message, edit = "write", "Writing...", false
  request(RX_SETTINGS, p, WRITE_WAIT)
end

local function onTxSettings(p)
  if #p < 3 then return end
  teleLocked = p[3] > 14   -- 25 mW
  readSettings()
end

local function onRxSettings(p)
  if #p < 2 then return end
  settings = { flag1 = p[2], outputs = {} }
  for i = 3, math.min(#p, 26) do settings.outputs[#settings.outputs + 1] = p[i] end
  dirty = false
  if state == "write" and exitAfterWrite then
    state = "exit"
    return
  end
  message = isSet(F_READONLY) and "Read only" or (state == "write" and "Saved" or "")
  state = "edit"
end

-----------------------------------------------------------------------------
-- Edition
-----------------------------------------------------------------------------

local function outputChoices(pin)
  local list = {}
  for ch = 0, channels - 1 do list[#list + 1] = ch end
  if telePort[rx.id] then
    list[#list + 1] = MAP_SPORT
    list[#list + 1] = MAP_SBUS_OUT
    list[#list + 1] = MAP_FBUS
    if pin == 1 then list[#list + 1] = MAP_SBUS_IN end
  elseif hasCap(CAP_PWM56) and (pin == 5 or pin == 6) then
    list[#list + 1] = channels
  end
  return list
end

local function outputText(pin, v)
  if telePort[rx.id] then
    if v == MAP_SPORT then return "S.Port" end
    if v == MAP_SBUS_OUT then return "S.Bus out" end
    if v == MAP_FBUS then return "F.Bus" end
    if v == MAP_SBUS_IN and pin == 1 then return "S.Bus in" end
  elseif v == channels and hasCap(CAP_PWM56) then
    if pin == 5 then return "S.Port" end
    if pin == 6 then return "S.Bus out" end
  end
  if v < channels then return "CH" .. (firstChannel + v + 1) end
  return string.format("0x%02X", v)
end

local portNames = { "S.Port", "F.Port", "F.Port2" }

local function portMode()
  if isSet(F_FPORT2) then return 3 end
  if isSet(F_FPORT) then return 2 end
  return 1
end

local function selectable(l)
  return l.kind ~= "note" and not l.ro and (l.kind == "save" or not isSet(F_READONLY))
end

local function buildLines()
  lines = {}
  local function add(label, kind, arg, ro)
    lines[#lines + 1] = { label = label, kind = kind, arg = arg, ro = ro }
  end
  add(rx.r9m and "6.67ms PWM" or "7ms PWM", "flag", F_FASTPWM)
  add("Telemetry", "notflag", F_TELE_OFF, teleLocked)
  if hasCap(CAP_TELE25) then add("25mW telem.", "flag", F_TELE25) end
  if hasCap(CAP_FPORT | CAP_FPORT2) then add("Port", "port") end
  if hasCap(CAP_SBUS24) then add("S.Bus 24", "flag", F_SBUS24) end
  if rx.caps & ~CAP_KNOWN ~= 0 then add("More options: update script", "note") end
  for i = 1, #settings.outputs do add("Pin " .. i, "pin", i) end
  add("Save", "save")
  sel = math.min(math.max(sel, 1), #lines)
  while not selectable(lines[sel]) do sel = sel + 1 end   -- "Save" always is
end

local function lineValue(l)
  if l.kind == "flag" then return isSet(l.arg) and "ON" or "OFF" end
  if l.kind == "notflag" then return isSet(l.arg) and "OFF" or "ON" end
  if l.kind == "port" then return portNames[portMode()] end
  if l.kind == "pin" then return outputText(l.arg, settings.outputs[l.arg]) end
  return ""
end

local function changeValue(dir)
  local l = lines[sel]
  if l.kind == "port" then
    local modes = { 1 }
    if hasCap(CAP_FPORT) then modes[#modes + 1] = 2 end
    if hasCap(CAP_FPORT2) then modes[#modes + 1] = 3 end
    local pos = 1
    for i = 1, #modes do if modes[i] == portMode() then pos = i end end
    local mode = modes[math.min(math.max(pos + dir, 1), #modes)]
    setFlag(F_FPORT, mode == 2)
    setFlag(F_FPORT2, mode == 3)
  elseif l.kind == "pin" then
    local list, pos = outputChoices(l.arg), nil
    for i = 1, #list do if list[i] == settings.outputs[l.arg] then pos = i end end
    pos = pos and pos + dir or (dir > 0 and 1 or #list)   -- unknown value
    settings.outputs[l.arg] = list[math.min(math.max(pos, 1), #list)]
    dirty, message = true, ""
  end
end

-----------------------------------------------------------------------------
-- Drawing
-----------------------------------------------------------------------------

local LINE_H = colorLcd and 24 or 8
local TOP_Y = colorLcd and 36 or 9
local VALUE_X = colorLcd and LCD_W // 2 or (LCD_W > 128 and 110 or 72)

local function visibleLines()
  return (LCD_H - TOP_Y) // LINE_H
end

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
  local font = colorLcd and COLOR_THEME_SECONDARY1 or 0
  if value then
    lcd.drawText(x, y, label, font)
    lcd.drawText(VALUE_X, y, value, font + attr)
  else
    lcd.drawText(x, y, label, font + attr)
  end
end

local function drawCentered(text, attr)
  local font = colorLcd and COLOR_THEME_SECONDARY1 or 0
  lcd.drawText(LCD_W // 2, LCD_H // 2 - (colorLcd and 10 or 4), text, font + CENTER + (attr or 0))
end

local function scrollTo(count)
  local n = visibleLines()
  if sel < top then top = sel end
  if sel >= top + n then top = sel - n + 1 end
  if top > math.max(count - n + 1, 1) then top = math.max(count - n + 1, 1) end
end

local function draw()
  lcd.clear()
  if state == "pick" then
    drawTitle("Select receiver")
    scrollTo(#receivers)
    for i = top, math.min(#receivers, top + visibleLines() - 1) do
      drawRow(i, rxLabel(receivers[i]), receivers[i].name, i == sel and INVERS or 0)
    end
  elseif state == "edit" or state == "write" then
    drawTitle(rx.name, message ~= "" and message or nil)
    scrollTo(#lines)
    for i = top, math.min(#lines, top + visibleLines() - 1) do
      local l = lines[i]
      local attr = 0
      if i == sel then attr = (edit and BLINK or 0) + INVERS end
      if l.kind == "note" or l.kind == "save" then
        drawRow(i, l.label, nil, attr)
      else
        drawRow(i, l.label, lineValue(l), attr)
      end
    end
  elseif state == "confirm" then
    drawTitle(rx.name)
    drawCentered("Save changes?")
    lcd.drawText(LCD_W // 2, LCD_H // 2 + (colorLcd and 20 or 6), "[ENTER] Yes  [EXIT] No",
                 (colorLcd and COLOR_THEME_SECONDARY1 or SMLSIZE) + CENTER)
  else
    drawTitle(rx and rx.name or "ACCESS RX Options")
    if state == "error" then
      drawCentered(message)
    elseif state == "scan" then
      drawCentered("Searching receivers...", BLINK)
    else
      drawCentered(message, BLINK)
    end
  end
end

-----------------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------------

local function timeouts()
  if getTime() < deadline then return end
  if state == "scan" then
    scanNext()
  elseif state == "write" then
    readSettings()   -- read back what the receiver kept
  elseif state == "txread" or state == "read" then
    if tries < TRIES then
      tries = tries + 1
      request(state == "txread" and TX_SETTINGS or RX_SETTINGS,
              state == "txread" and { 0x00 } or { rx.slot })
    else
      state, message = "error", "No answer"
    end
  end
end

local function poll()
  if not link then return end
  link.pump()
  while true do
    local t, p = link.receive()
    if not t then return end
    if t == HW_INFO and state == "scan" then
      onHwInfo(p)
    elseif t == TX_SETTINGS and state == "txread" then
      onTxSettings(p)
    elseif t == RX_SETTINGS and (state == "read" or state == "write") then
      onRxSettings(p)
      if state == "edit" then buildLines() end
    end
  end
end

local function moveSelection(dir)
  local n = #lines
  for _ = 1, n do
    sel = sel + dir
    if sel < 1 or sel > n then sel = sel - dir return end
    if selectable(lines[sel]) then return end
  end
end

local function handleEdit(event)
  local l = lines[sel]
  if edit then
    if event == EVT_VIRTUAL_INC then changeValue(1)
    elseif event == EVT_VIRTUAL_DEC then changeValue(-1)
    elseif event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then edit = false end
    return
  end
  if event == EVT_VIRTUAL_NEXT then moveSelection(1)
  elseif event == EVT_VIRTUAL_PREV then moveSelection(-1)
  elseif event == EVT_VIRTUAL_ENTER and selectable(l) then
    if l.kind == "save" then writeSettings()
    elseif l.kind == "flag" or l.kind == "notflag" then setFlag(l.arg, not isSet(l.arg))
    else edit = true end
  end
end

local function init()
  startScan()
end

local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  poll()
  timeouts()

  if state == "start" then startReceiver() end
  if state == "exit" then
    if link then link.close() end
    return 2
  end

  if event == EVT_VIRTUAL_EXIT and not edit then
    if state == "edit" and dirty then
      state = "confirm"
    elseif (state == "edit" or state == "confirm") and #receivers > 1 then
      state, sel, top = "pick", 1, 1
    elseif state ~= "write" then
      if link then link.close() end
      return 2
    end
  elseif state == "pick" then
    if event == EVT_VIRTUAL_NEXT then sel = math.min(sel + 1, #receivers)
    elseif event == EVT_VIRTUAL_PREV then sel = math.max(sel - 1, 1)
    elseif event == EVT_VIRTUAL_ENTER then
      rx, sel, top = receivers[sel], 1, 1
      startReceiver()
    end
  elseif state == "edit" then
    handleEdit(event)
  elseif state == "confirm" then
    if event == EVT_VIRTUAL_ENTER then
      state, exitAfterWrite = "edit", true
      writeSettings()
    end
  elseif state == "error" and event == EVT_VIRTUAL_ENTER then
    if rx then startReceiver() else startScan() end
  end

  draw()
  return 0
end

return { init = init, run = run }

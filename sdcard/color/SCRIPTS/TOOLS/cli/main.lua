-- TNS|CLI|TNE
-------------------------------------------------------------------------------
-- CLI - universal serial terminal for EdgeTX color radios
--
-- Talks to any device exposing a text CLI over UART (flight controllers,
-- ESCs, GPS modules, ...) through a radio serial port set to "LUA" mode
-- (RADIO SETUP -> Hardware -> Serial ports -> AUX1/AUX2 = LUA).
--
-- The terminal is transport agnostic: everything you type is written to the
-- port as-is (with a trailing newline), everything received is printed.
--
-- Session model:
--   wait   - no session: wiring instructions are shown and the app probes
--            the port with "#\n" until something answers with readable
--            text. In "Auto" (default on every start) the baud rate sweeps
--            through the known values; a manually picked rate probes at
--            that rate only. "#" starts a CLI session on every MSP-family
--            port (Betaflight/INAV/EmuFlight/...) and is a harmless
--            comment for consoles that are already interactive. Commands
--            typed here are sent out too, but the session opens only when
--            the device actually answers - silence is not "disconnected"
--            when nothing was connected in the first place.
--   active - live terminal. Every transmit arms a watchdog: no reply
--            within a second means the device is gone.
--   lost   - "! disconnected" is printed, the log is kept on screen
--            for reading. The header button turns into "Clear": pressing
--            it wipes the log and returns to wait with the same baud mode
--            (Auto stays Auto, a fixed rate stays fixed). Any received
--            byte or a successful reply revives the session in place.
--
--   [CMD]  saved commands library (title = command + free text description,
--          expandable rows, confirm-to-send, [+] to create)
--   [X]    exit (RTN key works too, long press RTN force-quits)
--
-- License: GPLv2 (same as EdgeTX)
-------------------------------------------------------------------------------

local APP_DIR   = "/SCRIPTS/TOOLS/cli"
local CMDS_FILE = APP_DIR .. "/commands.txt"
local FILES_DIR = APP_DIR .. "/files"   -- saved logs and command files

-- pacing when replaying a command file, so the device's own RX buffer and
-- the terminal both keep up
local SEND_INTERVAL_TICKS = 10   -- 100 ms between queued lines

local BAUD_RATES = { 9600, 19200, 38400, 57600, 115200, 230400, 250000, 460800, 921600 }
-- sweep order: most common rates first
local PROBE_ORDER = { 5, 4, 3, 2, 1, 6, 7, 8, 9 }
local BAUD_MENU = { "Auto" }
for i = 1, #BAUD_RATES do BAUD_MENU[i + 1] = tostring(BAUD_RATES[i]) end

-- Measured on a Betaflight F722: a cold "#" is answered in ~160 ms, so 450 ms
-- leaves a comfortable margin without slowing the common case (115200 is
-- probed first and locks immediately).
local PROBE_LISTEN_TICKS  = 45   -- 450 ms listening per probe
local PROBE_PAUSE_TICKS   = 100  -- 1 s pause between sweeps / fixed probes
local REPLY_TIMEOUT_TICKS = 100  -- 1 s without a reply = disconnected

local MAX_LINES = 200  -- terminal scrollback, lines
local HEADER_H  = 34
local INPUT_H   = 38
local LINE_H    = 17   -- estimated SMLSIZE line height, px
local CHAR_W    = 8    -- estimated SMLSIZE char width, px

local SCREEN_TERM  = 1
local SCREEN_SAVED = 2

local PORT_NAMES = { [0] = "AUX1", [1] = "AUX2", [2] = "USB-VCP" }

-- UI state
local screen = SCREEN_TERM
local dirty = true          -- rebuild UI on next run() cycle
local addDialog = nil       -- handle of the "New command" dialog

-- Terminal state
local lines = {}            -- finished lines
local cur = ""              -- line being received
local lastCR = false        -- previous received byte was \r
local ansiSkip = false      -- inside an ANSI escape sequence
local inputText = ""

-- Scrollback. The log lives in one label inside a scrollable box: LVGL does
-- touch swiping natively, and scrollY drives the same box from the PAGE keys.
local scrollY = 0           -- desired scroll position, px
local follow = true         -- stick to the newest output
local logText = ""          -- cached joined log
local logDirty = true       -- rebuild the cache on the next draw

-- Session / baud state. Every app start begins in Auto mode; a manual pick
-- from the menu is not persisted anywhere on purpose.
local session = "wait"      -- wait | active | lost
local autoMode = true       -- Auto selected (vs explicit rate)
local baudIdx = 5           -- rate currently applied to the port

-- probe machine (runs while session == "wait")
local probePos = 0          -- position in PROBE_ORDER (Auto mode only)
local probePhase = "hop"    -- hop | listen | pause
local probeT0 = 0
local probeBuf = ""

-- what a failed probe received, for on-screen diagnostics
local diagBytes = 0
local diagRatio = 0
local diagMsp = false
local diagRate = nil

-- reply watchdog (armed by transmit while session == "active")
local awaitReply = false
local replyT0 = 0

-- AUX 5V power monitoring
local lastPower = nil

-- Saved commands: array of { cmd = string, desc = string }
local cmds = {}
local expanded = {}         -- [index] = true when the row is expanded

-- File transfer
local openFileMenu          -- defined further down, used by the header button
local loadDialog = nil      -- handle of the "load from file" dialog
local loadFile = ""         -- file picked in that dialog
local sendQueue = {}        -- lines waiting to be replayed into the CLI
local sendPos = 0
local sendT0 = 0

-- Deferred actions. Widget callbacks that must destroy/rebuild widgets only
-- set these flags; run() applies them outside of any widget event handler.
local pendingSend = nil     -- string to transmit
local pendingClearInput = false -- wipe the input field after this send
local pendingExitAsk = false
local pendingExit = false
local pendingDelete = nil   -- index to delete (already confirmed)
local newCmd, newDesc = "", ""

-- Layout
local termH = LCD_H - HEADER_H - INPUT_H - 4
local wrapCols = math.floor((LCD_W - 40) / CHAR_W)
-- Saved-commands list width. EdgeTX flex boxes add PAD_OUTLINE (2px) of inner
-- padding per side and a scrollbar, so every nested element is kept a few px
-- narrower than its parent to avoid overflow (which shows up as stray
-- horizontal scrollbars and a shifted layout).
local LIST_W = LCD_W - 20

-------------------------------------------------------------------------------
-- Persistence (saved commands only; baud mode is session-only by design)
-------------------------------------------------------------------------------

local function readAll(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local data = ""
  while true do
    local chunk = io.read(f, 2048)
    if not chunk or #chunk == 0 then break end
    data = data .. chunk
  end
  io.close(f)
  return data
end

local function loadCmds()
  cmds = {}
  local data = readAll(CMDS_FILE)
  if not data then return end
  for line in string.gmatch(data, "[^\r\n]+") do
    local c, d = string.match(line, "^([^\t]+)\t?(.*)$")
    if c and c ~= "" then
      cmds[#cmds + 1] = { cmd = c, desc = d or "" }
    end
  end
end

local function saveCmds()
  local f = io.open(CMDS_FILE, "w")
  if not f then return end
  for i = 1, #cmds do
    io.write(f, cmds[i].cmd .. "\t" .. (cmds[i].desc or "") .. "\n")
  end
  io.close(f)
end

-------------------------------------------------------------------------------
-- Port info helpers
-------------------------------------------------------------------------------

-- returns port_nr (or nil when not configured / unknown) and display name
local function luaPortInfo()
  if not serialGetLuaPort then return nil, "AUX" end
  local p, name = serialGetLuaPort()
  if p then return p, (name or PORT_NAMES[p] or ("port " .. p)) end
  return nil, nil
end

-- returns true/false, or nil when power control is not available
local function portPower()
  if not serialGetPower then return nil end
  local p = luaPortInfo()
  if not p or p > 1 then return nil end
  return serialGetPower(p)
end

-------------------------------------------------------------------------------
-- Terminal buffer
-------------------------------------------------------------------------------

local function pushLine(s)
  lines[#lines + 1] = s
  if #lines > MAX_LINES then
    table.remove(lines, 1)
  end
  logDirty = true
end

local function flushCur()
  pushLine(cur)
  cur = ""
end

local function appendData(data)
  for i = 1, #data do
    local b = string.byte(data, i)
    if ansiSkip then
      -- escape sequences terminate with a letter
      if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then ansiSkip = false end
    elseif b == 27 then
      ansiSkip = true
      lastCR = false
    elseif b == 13 then
      flushCur()
      lastCR = true
    elseif b == 10 then
      if not lastCR then flushCur() end
      lastCR = false
    else
      lastCR = false
      if b == 9 then
        cur = cur .. "  "
      elseif b >= 32 and b <= 126 then
        -- printable ASCII only: an unplugged cable leaves the RX line
        -- floating (no pull-up in the GPIO config), which yields noise bytes
        cur = cur .. string.sub(data, i, i)
      end
      if #cur >= wrapCols then flushCur() end
    end
  end
  logDirty = true
end

-- receive path while a session exists (active or lost); any incoming byte
-- proves the device is alive
local function drainSerial()
  -- drain the whole firmware RX buffer each cycle (2 kB / 255 per call)
  for _ = 1, 10 do
    local data = serialRead(255)
    if not data or #data == 0 then break end
    session = "active"
    awaitReply = false
    appendData(data)
  end
end

local function transmit(cmd)
  serialWrite(cmd .. "\n")
  pushLine("> " .. cmd)
  follow = true   -- sending means you want to watch the answer
  if session == "wait" then
    -- no session yet: the command doubles as a probe; the session opens
    -- only when the device answers, silence is not a disconnect
    return
  end
  session = "active"
  -- arm the disconnect watchdog: a live device answers (echo, prompt or
  -- output) almost immediately
  awaitReply = true
  replyT0 = getTime()
end

-------------------------------------------------------------------------------
-- Probing (session == "wait")
-- Probe is "#\n": starts a CLI session on MSP-family ports, is a comment
-- (no-op) for consoles that are already interactive, and is ignored by
-- binary protocols. Auto sweeps the rates, manual probes the selected one.
-------------------------------------------------------------------------------

local function startWaiting()
  session = "wait"
  probePos = 0
  probePhase = "hop"
  probeBuf = ""
  awaitReply = false
  diagBytes, diagRatio, diagMsp, diagRate = 0, 0, false, nil
end

local function clearTerminal()
  lines = {}
  cur = ""
  lastCR = false
  ansiSkip = false
  logDirty = true
  scrollY = 0
  follow = true
  startWaiting()
end

local function printableRatio(s)
  if #s == 0 then return 0 end
  local good = 0
  for i = 1, #s do
    local b = string.byte(s, i)
    if b == 9 or b == 10 or b == 13 or (b >= 32 and b <= 126) then
      good = good + 1
    end
  end
  return good / #s
end

local function probeLooksGood()
  if #probeBuf < 3 then return false end
  return printableRatio(probeBuf) >= 0.8
end

-- Remember what a failed probe actually received. A port that answers with
-- binary is usually a UART assigned to a telemetry/OSD function rather than
-- a text CLI, and saying so beats waiting silently forever.
local function recordDiag()
  if #probeBuf == 0 then return end
  local msp = string.find(probeBuf, "$M", 1, true) ~= nil
              or string.find(probeBuf, "$X", 1, true) ~= nil
  -- an MSP sighting is definitive: never overwrite it with noise from
  -- another rate of the sweep
  if diagMsp and not msp then return end
  diagBytes = #probeBuf
  diagRatio = printableRatio(probeBuf)
  diagMsp = msp
  diagRate = BAUD_RATES[baudIdx]
end

local function runProbe()
  local now = getTime()

  -- collect replies continuously: a readable answer (to our "#" probe or
  -- to a command typed while waiting) opens the session in any phase
  for _ = 1, 10 do
    local d = serialRead(255)
    if not d or #d == 0 then break end
    if #probeBuf < 1024 then probeBuf = probeBuf .. d end
  end
  if probeLooksGood() then
    -- session starts; in Auto the header flips from "Auto" to the rate
    session = "active"
    appendData(probeBuf)
    probeBuf = ""
    return
  end

  if probePhase == "hop" then
    if autoMode then
      probePos = probePos % #PROBE_ORDER + 1
      baudIdx = PROBE_ORDER[probePos]
    end
    if setSerialBaudrate then setSerialBaudrate(BAUD_RATES[baudIdx]) end
    probeBuf = "" -- bytes collected at the previous rate are meaningless
    serialWrite("#\n")
    probeT0 = now
    probePhase = "listen"
  elseif probePhase == "listen" then
    if now - probeT0 >= PROBE_LISTEN_TICKS then
      recordDiag()
      if autoMode and probePos ~= #PROBE_ORDER then
        probePhase = "hop"
      else
        probePhase = "pause"
        probeT0 = now
      end
    end
  else -- pause between sweeps / fixed-rate probes
    if now - probeT0 >= PROBE_PAUSE_TICKS then probePhase = "hop" end
  end
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function trim(s)
  return string.match(s or "", "^%s*(.-)%s*$")
end

local function truncate(s, n)
  s = s or ""
  if #s > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
  return s
end

-- empty text fields normally render as "---"; the same firmware build that
-- provides serialGetLuaPort() also supports the textEdit "placeholder"
-- param, letting them stay visually empty (older firmware would error on
-- the unknown key, so it is only added when supported)
local function textEditSpec(spec)
  if serialGetLuaPort then spec.placeholder = "" end
  return spec
end

-------------------------------------------------------------------------------
-- Wiring instructions (shown in the terminal area while waiting).
-- Baud rate is deliberately not mentioned: it is always visible in the
-- header. Power state is read live, so the text updates by itself.
-------------------------------------------------------------------------------

local function instructionsText()
  local p, pname = luaPortInfo()
  if serialGetLuaPort and not p then
    return "No serial port is set to LUA mode!\n\n"
        .. "Open RADIO SETUP -> Hardware -> Serial ports\n"
        .. "and set AUX1 (or AUX2) to 'LUA',\n"
        .. "then restart this app."
  end

  -- Data is arriving but it isn't text: the wiring is obviously fine, so
  -- report what the port is actually speaking instead of a cabling guide.
  if diagBytes > 0 then
    local t = {
      "Port is talking, but not in text.",
      "",
      "Last probe at " .. tostring(diagRate) .. " baud:",
      "  " .. diagBytes .. " bytes, "
        .. math.floor(diagRatio * 100) .. "% printable",
    }
    if diagMsp then
      t[#t + 1] = "  MSP frames detected ($M/$X)"
      t[#t + 1] = ""
      t[#t + 1] = "This UART runs an MSP function (telemetry"
      t[#t + 1] = "or DisplayPort OSD), which never enters CLI."
      t[#t + 1] = "Point the cable at a UART whose function is"
      t[#t + 1] = "plain MSP (Configuration), or change it."
    else
      t[#t + 1] = ""
      t[#t + 1] = "Either the baud rate is wrong or this port"
      t[#t + 1] = "speaks a binary protocol. Try picking a"
      t[#t + 1] = "fixed baud rate from the header menu."
    end
    return table.concat(t, "\n")
  end

  pname = pname or "AUX"
  local t = {
    autoMode and "Waiting for device (auto baud scan)"
             or "Waiting for device (probing at fixed rate)",
    "",
    "Wiring " .. pname .. " <-> device UART (crossover!):",
    "  " .. pname .. " TX  ->  device RX",
    "  " .. pname .. " RX  ->  device TX",
    "  GND -> GND",
    "",
  }
  local pwr = portPower()
  if pwr == true then
    t[#t + 1] = "! " .. pname .. " 5V is ON - device is powered by radio."
    t[#t + 1] = "! DISCONNECT the drone battery before"
    t[#t + 1] = "! plugging the cable!"
  elseif pwr == false then
    t[#t + 1] = pname .. " 5V is OFF: power the device from its own"
    t[#t + 1] = "battery and leave the 5V wire unconnected."
  end
  return table.concat(t, "\n")
end

local function termText()
  if session == "wait" then
    return instructionsText()
  end
  -- the whole scrollback goes into the label; joining 200 lines every draw
  -- would be wasteful, so it is cached until something changes
  if logDirty then
    logDirty = false
    local t = {}
    for i = 1, #lines do t[i] = lines[i] end
    if cur ~= "" then t[#t + 1] = cur end
    logText = table.concat(t, "\n")
  end
  return logText
end

-- how far the log can be scrolled, in pixels
local function maxScroll()
  if session == "wait" then return 0 end
  local n = #lines + ((cur ~= "") and 1 or 0)
  return math.max(0, n * LINE_H - (termH - 8))
end

-------------------------------------------------------------------------------
-- Terminal screen
-------------------------------------------------------------------------------

local function buildTerminal()
  lvgl.clear()
  lvgl.build({
    -- header: title merged into the baud button; after a disconnect the
    -- same button becomes "Start new session"
    -- While a session is live there is nothing to choose: changing the baud
    -- rate could only break it, so the control gives way to a plain label.
    { type = "label", x = 8, y = 9, font = BOLD,
      visible = function() return session == "active" end,
      text = "CLI session is running" },
    { type = "button", x = 4, y = 3, w = LCD_W - 168, h = HEADER_H - 6,
      visible = function() return session ~= "active" end,
      text = function()
        if session == "lost" then return "Start new session" end
        local v = (autoMode and session == "wait") and "Auto"
                  or tostring(BAUD_RATES[baudIdx])
        return "CLI baud rate: " .. v
      end,
      press = function()
        if session == "lost" then
          -- wipe the log, wait for a new session with the same baud mode
          clearTerminal()
          return
        end
        lvgl.menu({
          title = "Baud rate",
          values = BAUD_MENU,
          get = function()
            return autoMode and 1 or (baudIdx + 1)
          end,
          set = function(i)
            if i == 1 then
              autoMode = true
              if session == "wait" then startWaiting() end
            else
              autoMode = false
              baudIdx = i - 1
              if setSerialBaudrate then setSerialBaudrate(BAUD_RATES[baudIdx]) end
              if session == "wait" then
                -- drop the previous rate's diagnosis so the wait screen does
                -- not show it against the newly picked rate (the Auto branch
                -- gets this via startWaiting())
                probePhase = "hop"
                diagBytes, diagRatio, diagMsp, diagRate = 0, 0, false, nil
              end
            end
          end,
        })
      end },
    { type = "button", x = LCD_W - 160, y = 3, w = 56, h = HEADER_H - 6,
      text = "FILE", press = openFileMenu },
    { type = "button", x = LCD_W - 100, y = 3, w = 56, h = HEADER_H - 6, text = "CMD",
      press = function() screen = SCREEN_SAVED; dirty = true end },
    { type = "button", x = LCD_W - 40, y = 3, w = 36, h = HEADER_H - 6, text = "X",
      press = function() pendingExitAsk = true end },

    -- terminal area: a scrollable box gives touch swiping for free, and the
    -- PAGE keys drive the very same scroll position through scrollTo
    { type = "rectangle", x = 4, y = HEADER_H, w = LCD_W - 8, h = termH, thickness = 1 },
    { type = "box", x = 6, y = HEADER_H + 2, w = LCD_W - 12, h = termH - 4,
      scrollDir = lvgl.SCROLL_VER, scrollBar = true,
      scrollTo = function() return 0, scrollY end,
      scrolled = function(_, y)
        -- LVGL clamps to the real content height, so this also corrects
        -- scrollY whenever the line-height estimate is off
        scrollY = y
        follow = y >= maxScroll() - LINE_H
      end,
      children = {
        { type = "label", x = 4, y = 2, w = LCD_W - 28,
          font = SMLSIZE, text = termText },
      }},

    -- input row. The keyboard checkmark only closes the keyboard keeping the
    -- draft (set); the keyboard Enter key sends it (enter). The button to the
    -- right is a second send path (and the only one on non-touch radios).
    { type = "label", x = 6, y = LCD_H - INPUT_H + 10, text = ">", font = BOLD },
    textEditSpec({ type = "textEdit", x = 20, y = LCD_H - INPUT_H + 2,
      w = LCD_W - 20 - 92, value = inputText, length = 128,
      set = function(v) inputText = v or "" end,
      enter = function(v)
        local c = trim(v or inputText)
        if c ~= "" then
          pendingSend = c
          pendingClearInput = true
        end
      end }),
    { type = "button", x = LCD_W - 88, y = LCD_H - INPUT_H + 2, w = 84, h = 32,
      text = "Enter",
      press = function()
        local c = trim(inputText)
        if c ~= "" then
          pendingSend = c
          pendingClearInput = true
        end
      end },
  })
end

-------------------------------------------------------------------------------
-- Saved commands screen
-------------------------------------------------------------------------------

local function sendSavedConfirm(i)
  local c = cmds[i].cmd
  lvgl.confirm({
    title = "Send command?",
    message = c,
    confirm = function()
      pendingSend = c
      screen = SCREEN_TERM
      dirty = true
    end,
  })
end

local function deleteSavedConfirm(i)
  lvgl.confirm({
    title = "Delete command?",
    message = cmds[i].cmd,
    confirm = function() pendingDelete = i end,
  })
end

local function openAddDialog()
  newCmd, newDesc = "", ""
  local dw = math.min(LCD_W - 24, 420)
  -- Flex column body, same structure as native EdgeTX dialogs, so the
  -- on-screen keyboard scrolls the content properly.
  addDialog = lvgl.dialog({
    title = "New command",
    w = dw, h = 210,
    flexFlow = lvgl.FLOW_COLUMN, flexPad = 4,
    close = function() addDialog = nil end,
    children = {
      { type = "label", text = "Command", font = SMLSIZE },
      textEditSpec({ type = "textEdit", w = dw - 24, value = "", length = 128,
        set = function(v) newCmd = v or "" end }),
      { type = "label", text = "Description", font = SMLSIZE },
      textEditSpec({ type = "textEdit", w = dw - 24, value = "", length = 128,
        set = function(v) newDesc = v or "" end }),
      { type = "box", w = dw - 24, h = 40, flexFlow = lvgl.FLOW_ROW, flexPad = 10,
        children = {
          { type = "button", w = 110, h = 36, text = "Save",
            press = function()
              -- native dialog pattern: act inline, deleteLater() makes
              -- closing from inside a button callback safe
              local c = trim(newCmd)
              if c ~= "" then
                cmds[#cmds + 1] = { cmd = c, desc = trim(newDesc) }
                saveCmds()
                dirty = true
              end
              if addDialog then addDialog:close() end
            end },
          { type = "button", w = 110, h = 36, text = "Cancel",
            press = function()
              if addDialog then addDialog:close() end
            end },
        }},
    },
  })
end

local function itemSpec(i)
  local e = expanded[i]
  local rowW   = LIST_W - 6                 -- row inside the item column
  local sendW  = 84
  local titleW = rowW - sendW - 16          -- leave slack for flex padding
  local textW  = LIST_W - 12                -- labels inside the item column
  local titleCols = math.floor(titleW / 10) -- STD font, rough estimate
  local descCols  = math.floor(textW / CHAR_W)
  local children = {
    { type = "box", w = rowW, h = 34, flexFlow = lvgl.FLOW_ROW, flexPad = 6,
      children = {
        { type = "button", w = titleW, h = 30,
          text = (e and "- " or "+ ") .. truncate(cmds[i].cmd, titleCols),
          press = function()
            expanded[i] = (not e) or nil
            dirty = true
          end },
        { type = "button", w = sendW, h = 30, text = "Send",
          press = function() sendSavedConfirm(i) end },
    }},
  }
  if e then
    children[#children + 1] =
      { type = "label", w = textW, text = cmds[i].cmd }
    children[#children + 1] =
      { type = "label", w = textW, font = SMLSIZE,
        text = cmds[i].desc ~= "" and cmds[i].desc or "(no description)" }
    children[#children + 1] =
      { type = "button", w = 120, h = 28, text = "Delete",
        press = function() deleteSavedConfirm(i) end }
  elseif (cmds[i].desc or "") ~= "" then
    children[#children + 1] =
      { type = "label", w = textW, font = SMLSIZE,
        text = truncate(cmds[i].desc, descCols) }
  end
  return { type = "box", w = LIST_W, flexFlow = lvgl.FLOW_COLUMN,
           flexPad = 2, children = children }
end

local function buildSaved()
  lvgl.clear()
  local items = {}
  if #cmds == 0 then
    items[1] = { type = "label", text = "No saved commands yet. Press + to add one." }
  else
    for i = 1, #cmds do
      items[#items + 1] = itemSpec(i)
    end
  end
  lvgl.build({
    { type = "button", x = 4, y = 3, w = 64, h = HEADER_H - 6, text = "Back",
      press = function() screen = SCREEN_TERM; dirty = true end },
    { type = "label", x = 76, y = 9, text = "Saved commands", font = BOLD },
    { type = "button", x = LCD_W - 44, y = 3, w = 40, h = HEADER_H - 6, text = "+",
      press = openAddDialog },
    { type = "box", x = 0, y = HEADER_H, w = LCD_W, h = LCD_H - HEADER_H,
      flexFlow = lvgl.FLOW_COLUMN, flexPad = 8, borderPad = 6,
      scrollDir = lvgl.SCROLL_VER, children = items },
  })
end

-------------------------------------------------------------------------------
-- Save / load, mirroring Betaflight's "Save to File" and "Load from File"
-------------------------------------------------------------------------------

local function twoDigits(n)
  return string.format("%02d", n)
end

local function saveLog()
  if #lines == 0 then
    lvgl.message({ title = "Save log", message = "Nothing to save yet." })
    return
  end
  if mkdir then mkdir(FILES_DIR) end  -- harmless if it already exists
  local d = getDateTime()
  local name = "cli-" .. d.year .. twoDigits(d.mon) .. twoDigits(d.day)
               .. "-" .. twoDigits(d.hour) .. twoDigits(d.min) .. twoDigits(d.sec)
               .. ".txt"
  local path = FILES_DIR .. "/" .. name
  local f = io.open(path, "w")
  if not f then
    lvgl.message({ title = "Save log", message = "Cannot write\n" .. path })
    return
  end
  for i = 1, #lines do
    io.write(f, lines[i] .. "\n")
  end
  io.close(f)
  pushLine("--- log saved: " .. name)
  follow = true
  lvgl.message({ title = "Log saved",
                 message = #lines .. " lines ->\n" .. name })
end

local function startSending(path)
  local data = readAll(path)
  if not data then
    lvgl.message({ title = "Load file", message = "Cannot read\n" .. path })
    return
  end
  sendQueue = {}
  for line in string.gmatch(data, "[^\r\n]+") do
    local c = trim(line)
    if c ~= "" then sendQueue[#sendQueue + 1] = c end
  end
  if #sendQueue == 0 then
    sendQueue = {}
    lvgl.message({ title = "Load file", message = "File has no commands." })
    return
  end
  sendPos = 0
  sendT0 = 0
  follow = true
  pushLine("--- sending " .. #sendQueue .. " lines from file")
end

-- one queued line per interval, from run()
local function pumpSendQueue()
  if sendPos >= #sendQueue then
    if #sendQueue > 0 then
      sendQueue = {}
      sendPos = 0
      pushLine("--- file sent")
    end
    return
  end
  local now = getTime()
  if sendT0 ~= 0 and now - sendT0 < SEND_INTERVAL_TICKS then return end
  sendT0 = now
  sendPos = sendPos + 1
  transmit(sendQueue[sendPos])
end

local function openLoadDialog()
  loadFile = ""
  local dw = math.min(LCD_W - 24, 420)
  loadDialog = lvgl.dialog({
    title = "Load from file",
    w = dw, h = 180,
    flexFlow = lvgl.FLOW_COLUMN, flexPad = 6,
    close = function() loadDialog = nil end,
    children = {
      { type = "label", font = SMLSIZE,
        text = "Every non-empty line is sent as a command." },
      { type = "file", w = dw - 24, folder = FILES_DIR, extension = ".txt",
        title = "Select file",
        get = function() return loadFile end,
        set = function(v) loadFile = v or "" end },
      { type = "box", w = dw - 24, h = 40, flexFlow = lvgl.FLOW_ROW, flexPad = 10,
        children = {
          { type = "button", w = 110, h = 36, text = "Send",
            press = function()
              local f = trim(loadFile)
              if loadDialog then loadDialog:close() end
              if f ~= "" then
                -- the picker hands back a bare name
                if not string.find(f, "/", 1, true) then
                  f = FILES_DIR .. "/" .. f
                end
                startSending(f)
              end
            end },
          { type = "button", w = 110, h = 36, text = "Cancel",
            press = function() if loadDialog then loadDialog:close() end end },
        }},
    },
  })
end

function openFileMenu()
  local values, actions = {}, {}
  if #sendQueue > 0 then
    values[#values + 1] = "Stop sending"
    actions[#actions + 1] = function()
      sendQueue = {}
      sendPos = 0
      pushLine("--- sending aborted")
    end
  end
  values[#values + 1] = "Save log to file"
  actions[#actions + 1] = saveLog
  values[#values + 1] = "Load commands from file"
  actions[#actions + 1] = openLoadDialog

  lvgl.menu({
    title = "File",
    values = values,
    get = function() return 0 end,
    set = function(i)
      local fn = actions[i]
      if fn then fn() end
    end,
  })
end

-------------------------------------------------------------------------------
-- Entry points
-------------------------------------------------------------------------------

local function init()
  loadCmds()
  -- make sure the file picker always has a folder to open
  if mkdir then mkdir(FILES_DIR) end
  lastPower = portPower()
  startWaiting()
end

local function run(event, touchState)
  -- serial I/O per session state
  if session == "wait" then
    runProbe()
  else
    drainSerial()
    if session == "active" and awaitReply and
       getTime() - replyT0 >= REPLY_TIMEOUT_TICKS then
      awaitReply = false
      pushLine("! disconnected")
      session = "lost"
    end
  end

  -- watch the AUX 5V output; warn the moment it turns on
  local pwr = portPower()
  if pwr ~= lastPower then
    if session ~= "wait" then
      local _, pname = luaPortInfo()
      pname = pname or "AUX"
      if pwr == true then
        pushLine("! " .. pname .. " 5V turned ON - make sure the")
        pushLine("! drone battery is DISCONNECTED!")
      elseif pwr == false then
        pushLine("(" .. pname .. " 5V turned off)")
      end
    end
    lastPower = pwr
  end

  -- deferred actions that rebuild the UI (never inside widget callbacks)
  if pendingDelete then
    table.remove(cmds, pendingDelete)
    expanded = {}
    saveCmds()
    pendingDelete = nil
    dirty = true
  end

  if pendingSend then
    transmit(pendingSend)
    pendingSend = nil
    -- only sends from the input field clear it; saved commands leave a
    -- typed draft alone
    if pendingClearInput then
      pendingClearInput = false
      inputText = ""
      if screen == SCREEN_TERM then dirty = true end -- rebuild clears the field
    end
  end

  pumpSendQueue()

  -- PAGE keys scroll the log. The rotary is deliberately left alone: LVGL
  -- uses it to move focus between the header buttons and the input field.
  if screen == SCREEN_TERM and not addDialog and not loadDialog then
    local step = termH - 8 - LINE_H   -- a page, keeping one line of overlap
    if EVT_VIRTUAL_PREV_PAGE and event == EVT_VIRTUAL_PREV_PAGE then
      scrollY = math.max(0, scrollY - step)
      follow = false
    elseif EVT_VIRTUAL_NEXT_PAGE and event == EVT_VIRTUAL_NEXT_PAGE then
      scrollY = math.min(maxScroll(), scrollY + step)
      follow = scrollY >= maxScroll() - LINE_H
    end
  end

  -- keep the newest output in view unless the user scrolled away
  if follow then scrollY = maxScroll() end

  if event == EVT_VIRTUAL_EXIT then
    if addDialog or loadDialog then
      -- modal dialog handles RTN itself
    elseif screen == SCREEN_SAVED then
      screen = SCREEN_TERM
      dirty = true
    else
      pendingExitAsk = true
    end
  end

  if pendingExitAsk then
    pendingExitAsk = false
    lvgl.confirm({
      title = "CLI",
      message = "Exit terminal?",
      confirm = function() pendingExit = true end,
    })
  end

  if pendingExit then
    return 2
  end

  if dirty then
    dirty = false
    if screen == SCREEN_TERM then
      buildTerminal()
    else
      buildSaved()
    end
  end

  return 0
end

return { init = init, run = run, useLvgl = true }

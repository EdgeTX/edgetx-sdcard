local failures = 0
local assertions = 0

local function fail(message)
    failures = failures + 1
    io.stderr:write("FAIL: " .. message .. "\n")
end

local function expectEqual(actual, expected, message)
    assertions = assertions + 1
    if actual ~= expected then
        fail(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
    end
end

local function expectTrue(actual, message)
    expectEqual(actual, true, message)
end

local logic = assert(loadfile("sdcard/color/WIDGETS/Trainer/logic.lua"))()

local cases = {
    { 0, false, false, "waiting" },
    { 0, true, false, "waiting_requested" },
    { 1, false, false, "connected" },
    { 1, true, false, "active" },
    { 2, false, false, "lost" },
    { 2, true, false, "lost_requested" },
    { 3, false, true, "reconnected" },
    { 3, false, false, "connected" },
    { 3, true, true, "active" },
    { 99, false, false, "unknown" },
}

for index, case in ipairs(cases) do
    local key = logic.classify(case[1], case[2], case[3])
    expectEqual(key, case[4], "state matrix case " .. index)
end

local customFunctions = {
    [0] = { func = 1, switch = 10, active = 1 },
    [1] = { func = 2, switch = 20, active = 1 },
    [2] = { func = 1, switch = -11, active = true },
    [3] = { func = 1, switch = 10, active = 1 },
    [4] = { func = 1, switch = 12, active = 0 },
}

local function getCustomFunction(index)
    if index > 5 then return nil end
    return customFunctions[index] or { func = 0, switch = 0, active = 0 }
end

local switches = logic.findTrainerSwitches(getCustomFunction, 1)
expectEqual(#switches, 2, "trainer switch discovery deduplicates switches")
expectEqual(switches[1], 10, "first trainer switch")
expectEqual(switches[2], -11, "inverted trainer switch")
expectTrue(logic.isControlRequested(switches, function(switch) return switch == -11 end),
           "any configured trainer switch can request control")
expectEqual(logic.isControlRequested(switches, function() return false end), false,
            "inactive trainer switches leave instructor in control")

expectEqual(logic.layoutForZone({ w = 70, h = 39 }), "tiny", "top-bar layout")
expectEqual(logic.layoutForZone({ w = 160, h = 60 }), "compact", "compact layout")
expectEqual(logic.layoutForZone({ w = 225, h = 98 }), "medium", "medium layout")
expectEqual(logic.layoutForZone({ w = 460, h = 252 }), "large", "large layout")

local calls = {}
local now = 0
local trainerStatus = 0
local switchValues = {}
local trainerFunctionConfigured = true

COLOR = 1
COLOR_THEME_PRIMARY1 = 0x10000
COLOR_THEME_PRIMARY2 = 0x20000
COLOR_THEME_ACTIVE = 0x30000
COLOR_THEME_WARNING = 0x40000
COLOR_THEME_DISABLED = 0x50000
FUNC_TRAINER = 1
LEFT = 0x01
RIGHT = 0x02
CENTER = 0x04
VCENTER = 0x08
VBOTTOM = 0x10
MIDSIZE = 0x20
DBLSIZE = 0x40
SMLSIZE = 0x80
TINSIZE = 0x100
BOLD = 0x200
CHAR_TRAINER = "T"

local function textSize(text, flags)
    local width
    local height

    if flags & DBLSIZE ~= 0 then
        width = #text * 30
        height = 40
    elseif flags & MIDSIZE ~= 0 then
        width = text == CHAR_TRAINER and 22 or #text * 10
        height = 18
    elseif flags & SMLSIZE ~= 0 then
        width = #text * 6
        height = 12
    else
        width = #text * 5
        height = 8
    end

    return width, height
end

local function record(name, ...)
    calls[#calls + 1] = { name = name, args = { ... } }
end

lcd = {
    drawText = function(...) record("drawText", ...) end,
    drawFilledCircle = function(...) record("drawFilledCircle", ...) end,
    drawCircle = function(...) record("drawCircle", ...) end,
    sizeText = textSize,
}

model = {
    getCustomFunction = function(index)
        if trainerFunctionConfigured and index == 0 then
            return { func = FUNC_TRAINER, switch = 7, active = 1 }
        elseif index < 64 then
            return { func = 0, switch = 0, active = 0 }
        end
        return nil
    end,
}

function getTime() return now end
function getTrainerStatus() return trainerStatus end
function getSwitchValue(switch) return switchValues[switch] == true end
function loadScript(path)
    return assert(loadfile("sdcard/color" .. path))
end

local descriptor = assert(loadfile("sdcard/color/WIDGETS/Trainer/main.lua"))()
local widgetOptions = {
    Connected = COLOR_THEME_PRIMARY2,
    Active = COLOR_THEME_ACTIVE,
    Warning = COLOR_THEME_WARNING,
    Neutral = COLOR_THEME_DISABLED,
    Text = COLOR_THEME_PRIMARY1,
}

local function renderedText(expected)
    for _, call in ipairs(calls) do
        if call.name == "drawText" and call.args[3] == expected then
            return true
        end
    end
    return false
end

local function textBounds(call)
    local x = call.args[1]
    local y = call.args[2]
    local width, height = textSize(call.args[3], call.args[4])
    local flags = call.args[4]

    if flags & CENTER ~= 0 then
        x = x - width // 2
    elseif flags & RIGHT ~= 0 then
        x = x - width
    end

    if flags & VCENTER ~= 0 then
        y = y - height // 2
    elseif flags & VBOTTOM ~= 0 then
        y = y - height
    end

    return x, y, x + width, y + height
end

local function callsStayInside(zone)
    for _, call in ipairs(calls) do
        local x = call.args[1]
        local y = call.args[2]
        if call.name == "drawText" then
            local left, top, right, bottom = textBounds(call)
            if left < zone.x or right > zone.x + zone.w or
               top < zone.y or bottom > zone.y + zone.h then
                return false
            end
        elseif call.name == "drawFilledCircle" or call.name == "drawCircle" then
            local radius = call.args[3]
            if x - radius < zone.x or x + radius > zone.x + zone.w or
               y - radius < zone.y or y + radius > zone.y + zone.h then
                return false
            end
        end
    end
    return true
end

local function textCallsDoNotOverlap()
    local textCalls = {}
    for _, call in ipairs(calls) do
        if call.name == "drawText" then
            textCalls[#textCalls + 1] = call
        end
    end

    for first = 1, #textCalls do
        local leftA, topA, rightA, bottomA = textBounds(textCalls[first])
        for second = first + 1, #textCalls do
            local leftB, topB, rightB, bottomB = textBounds(textCalls[second])
            if leftA < rightB and rightA > leftB and topA < bottomB and bottomA > topB then
                return false
            end
        end
    end

    return true
end

local function renderedTextUses(expected, flag)
    for _, call in ipairs(calls) do
        if call.name == "drawText" and call.args[3] == expected then
            return call.args[4] & flag ~= 0
        end
    end
    return false
end

local function render(zone, status, requested)
    calls = {}
    trainerStatus = status
    switchValues[7] = requested
    local widget = descriptor.create(zone, widgetOptions)
    descriptor.refresh(widget)
    return widget
end

expectEqual(descriptor.name, "Trainer", "widget name")

local topBarZone = { x = 0, y = 0, w = 70, h = 39 }
render(topBarZone, 0, false)
expectTrue(renderedText("WAIT"), "tiny layout renders waiting state")
expectTrue(callsStayInside(topBarZone), "top-bar drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "top-bar icon and text do not overlap")

local narrowTopBarZone = { x = 0, y = 0, w = 45, h = 39 }
render(narrowTopBarZone, 1, true)
expectTrue(renderedText(CHAR_TRAINER), "narrow top bar retains the trainer icon")
expectEqual(renderedText("LIVE"), false, "narrow top bar drops text that cannot fit")
expectTrue(callsStayInside(narrowTopBarZone), "narrow top-bar drawing stays inside its zone")

local compactZone = { x = 3, y = 4, w = 160, h = 60 }
render(compactZone, 1, false)
expectTrue(renderedText("CONNECTED"), "compact layout renders the full connected state when it fits")
expectTrue(callsStayInside(compactZone), "compact drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "compact icon and text do not overlap")

render(compactZone, 1, true)
expectTrue(renderedText("STUDENT CONTROL"), "compact layout retains the full active state at a smaller size")
expectTrue(renderedTextUses("STUDENT CONTROL", SMLSIZE),
           "compact active state selects a font that fits")
expectTrue(callsStayInside(compactZone), "compact active drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "compact active icon and text do not overlap")

local mediumZone = { x = 10, y = 20, w = 225, h = 98 }
render(mediumZone, 1, true)
expectTrue(renderedText("STUDENT CONTROL"), "medium layout renders active student control")
expectTrue(renderedText("Trainer input is active"), "medium layout renders active detail")
expectTrue(callsStayInside(mediumZone), "medium drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "medium icon, state, and detail do not overlap")

local narrowMediumZone = { x = 10, y = 20, w = 150, h = 90 }
render(narrowMediumZone, 1, true)
expectTrue(renderedText("STUDENT CONTROL"), "narrow medium layout preserves the full active state")
expectTrue(callsStayInside(narrowMediumZone), "narrow medium drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "narrow medium content does not overlap")

local largeZone = { x = 5, y = 7, w = 460, h = 252 }
render(largeZone, 2, true)
expectTrue(renderedText("LINK LOST"), "large layout renders link loss")
expectTrue(renderedText("Control: Requested"), "large layout renders requested control")
expectTrue(callsStayInside(largeZone), "large drawing stays inside its zone")

render(largeZone, 1, true)
expectTrue(renderedText("STUDENT CONTROL"), "large layout renders the full active state")
expectTrue(renderedTextUses("STUDENT CONTROL", MIDSIZE),
           "large active state reduces its font when double size would overflow")
expectEqual(renderedTextUses("STUDENT CONTROL", DBLSIZE), false,
            "large active state does not use an overflowing double-size font")
expectTrue(callsStayInside(largeZone), "large active drawing stays inside its zone")

local minimumLargeZone = { x = 5, y = 7, w = 240, h = 130 }
render(minimumLargeZone, 1, true)
expectTrue(renderedText("STUDENT CONTROL"), "minimum large layout preserves the full active state")
expectTrue(renderedTextUses("STUDENT CONTROL", MIDSIZE),
           "minimum large layout avoids a vertically oversized font")
expectTrue(callsStayInside(minimumLargeZone), "minimum large drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "minimum large content does not overlap")

trainerFunctionConfigured = false
render(largeZone, 1, false)
expectTrue(renderedText("Control: Not configured"), "missing Trainer function is reported")

render(minimumLargeZone, 1, false)
expectTrue(renderedText("Not configured"),
           "minimum large layout shortens the unconfigured control label")
expectTrue(callsStayInside(minimumLargeZone),
           "minimum large unconfigured drawing stays inside its zone")
expectTrue(textCallsDoNotOverlap(), "minimum large unconfigured content does not overlap")
trainerFunctionConfigured = true

trainerStatus = 3
switchValues[7] = false
now = 1000
local reconnected = descriptor.create({ x = 0, y = 0, w = 225, h = 98 }, widgetOptions)
calls = {}
descriptor.refresh(reconnected)
expectTrue(renderedText("RECONNECTED"), "reconnected state is announced")
now = now + 201
calls = {}
descriptor.refresh(reconnected)
expectTrue(renderedText("CONNECTED"), "reconnected state settles to connected")

if failures > 0 then
    io.stderr:write(string.format("%d of %d assertions failed\n", failures, assertions))
    os.exit(1)
end

print(string.format("PASS: %d trainer widget assertions", assertions))

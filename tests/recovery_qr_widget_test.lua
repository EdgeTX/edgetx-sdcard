local logic = assert(loadfile("sdcard/color/WIDGETS/RecoveryQR/logic.lua"))()
local storage = assert(loadfile("sdcard/color/WIDGETS/RecoveryQR/storage.lua"))()

local testsRun = 0

local function expect(condition, message)
    testsRun = testsRun + 1
    if not condition then
        error(message or "expectation failed", 2)
    end
end

local function expectEqual(actual, expected, message)
    expect(actual == expected, (message or "values differ")
        .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end

local function expectNear(actual, expected, epsilon, message)
    expect(math.abs(actual - expected) <= epsilon, message or "values are not near")
end

local valid = logic.normalizeGps({ lat = 40.1234567, lon = -74.7654321, delay = 2 })
expect(valid ~= nil, "valid GPS data should be accepted")
expectNear(valid.lat, 40.1234567, 0.00000001)
expectNear(valid.lon, -74.7654321, 0.00000001)
expectEqual(valid.delay, 2)

expectEqual(logic.normalizeGps(nil), nil)
expectEqual(logic.normalizeGps(0), nil)
expectEqual(logic.normalizeGps({ lat = "bad", lon = 1 }), nil)
expectEqual(logic.normalizeGps({ lat = 91, lon = 1 }), nil)
expectEqual(logic.normalizeGps({ lat = 1, lon = -181 }), nil)
expectEqual(logic.normalizeGps({ lat = 0, lon = 0 }), nil)
expect(logic.normalizeGps({ lat = 0, lon = 1 }) ~= nil)
expectEqual(logic.normalizeGps({ lat = 0 / 0, lon = 1 }), nil)
expectEqual(logic.normalizeGps({ lat = math.huge, lon = 1 }), nil)

expectEqual(
    logic.coordinateText(valid),
    "40.123457, -74.765432",
    "coordinates should use six decimal places"
)
expectEqual(
    logic.mapsUrl(valid),
    "https://maps.google.com/?q=40.123457,-74.765432",
    "map URL should contain normalized coordinates"
)
expectEqual(
    logic.coordinateText({ lat = -0.0000001, lon = 0.0000001 }),
    "0.000000, 0.000000",
    "negative zero should not be displayed"
)

local stamp = logic.captureStamp({
    year = 2026, mon = 7, day = 29, hour = 14, min = 5, sec = 9,
})
expectEqual(stamp, "2026-07-29 14:05:09")
expectEqual(logic.captureStamp(nil), "Unknown time")

local record = logic.newRecord(valid, stamp)
local serialized = logic.serializeRecord(record)
local parsed = logic.parseRecord(serialized)
expect(parsed ~= nil, "serialized record should parse")
expectNear(parsed.lat, 40.123457, 0.0000001)
expectNear(parsed.lon, -74.765432, 0.0000001)
expectEqual(parsed.captured, stamp)
expectEqual(logic.parseRecord(""), nil)
expectEqual(logic.parseRecord("RecoveryQR,2\nlat=1\nlon=2\ncaptured=now\n"), nil)
expectEqual(logic.parseRecord("RecoveryQR,1\nlat=bad\nlon=2\ncaptured=now\n"), nil)

expectEqual(logic.sanitizeModelKey("My Plane.yml"), "My_Plane")
expectEqual(logic.sanitizeModelKey("../../bad:model.yml"), "______bad_model")
expectEqual(logic.sanitizeModelKey(nil), "default")
expectEqual(#logic.sanitizeModelKey(string.rep("a", 50) .. ".yml"), 32)

expectEqual(logic.state(true, record), "live")
expectEqual(logic.state(false, record), "stored")
expectEqual(logic.state(false, nil), "waiting")
expectEqual(logic.layoutForZone(60, 40, false), "tiny")
expectEqual(logic.layoutForZone(180, 100, false), "compact")
expectEqual(logic.layoutForZone(220, 125, false), "compact")
expectEqual(logic.layoutForZone(300, 180, false), "qr")
expectEqual(logic.layoutForZone(60, 40, true), "fullscreen")

expect(logic.shouldPersist(nil, "a", nil, 100, false, true, 1500))
expect(not logic.shouldPersist("a", "a", 100, 2000, true, true, 1500))
expect(not logic.shouldPersist("a", "b", 100, 1000, true, true, 1500))
expect(logic.shouldPersist("a", "b", 100, 1600, true, true, 1500))
expect(logic.shouldPersist("a", "b", 100, 101, true, false, 1500))
expect(not logic.shouldPersist("a", "b", 100, 2000, false, false, 1500))
expect(logic.shouldPersist("a", "b", 2000, 10, true, true, 1500))

local files = {}
local function memoryOperations(failTemporaryRename)
    return {
        read = function(path)
            return files[path]
        end,
        write = function(path, data)
            files[path] = data
            return true
        end,
        delete = function(path)
            local existed = files[path] ~= nil
            files[path] = nil
            return existed and 0 or 4
        end,
        rename = function(fromPath, toPath)
            if failTemporaryRename and string.find(fromPath, "%.tmp$") then
                return 1
            end
            if files[fromPath] == nil or files[toPath] ~= nil then
                return 1
            end
            files[toPath] = files[fromPath]
            files[fromPath] = nil
            return 0
        end,
    }
end

local paths = storage.paths("/WIDGETS/RecoveryQR", "My_Plane")
expectEqual(paths.current, "/WIDGETS/RecoveryQR/last_My_Plane.txt")
expect(storage.save(paths, serialized, memoryOperations(false)))
expectEqual(files[paths.current], serialized)
expectEqual(files[paths.temporary], nil)
expectEqual(files[paths.backup], nil)

local loaded = storage.load(paths, logic.parseRecord, memoryOperations(false))
expect(loaded ~= nil, "saved record should load")
expectEqual(loaded.captured, stamp)

local previous = serialized
local replacement = logic.serializeRecord(logic.newRecord(
    { lat = 41.1, lon = -73.2 },
    "2026-07-29 14:06:00"
))
expect(not storage.save(paths, replacement, memoryOperations(true)))
expectEqual(files[paths.current], previous, "failed replacement should restore current file")
expectEqual(files[paths.temporary], nil)

files[paths.current] = "corrupt"
files[paths.backup] = previous
loaded = storage.load(paths, logic.parseRecord, memoryOperations(false))
expect(loaded ~= nil, "valid backup should recover a corrupt current file")
expectEqual(loaded.captured, stamp)

files[paths.current] = previous
expect(storage.clear(paths, memoryOperations(false)))
expectEqual(files[paths.current], nil)
expectEqual(files[paths.temporary], nil)
expectEqual(files[paths.backup], nil)
expect(storage.clear(paths, memoryOperations(false)),
    "clearing an already absent record should succeed")

-- Exercise the widget lifecycle with a small EdgeTX API mock. This catches
-- integration errors in main.lua without requiring a radio.
SOURCE = 1
COLOR = 2
COLOR_THEME_ACTIVE = 10
COLOR_THEME_WARNING = 11
COLOR_THEME_PRIMARY1 = 12
COLOR_THEME_DISABLED = 13
MIDSIZE = 0x0100
DBLSIZE = 0x0200
SMLSIZE = 0x0400
TINSIZE = 0x0800
CENTER = 0x1000
VCENTER = 0x2000
WHITE = 0xFFFF
BLACK = 0
LCD_W = 480
LCD_H = 272
EVT_VIRTUAL_EXIT = 99

local now = 100
local gpsValue = 0
local currentSecond = 5
local builtLayout
local exitedFullscreen = false
local pendingConfirmation
local widgetFiles = {}
local widgetEnvironment
local currentModelFilename = "Rescue Plane.yml"
local currentModelName = "Rescue Plane"

model = {
    getInfo = function()
        return { filename = currentModelFilename, name = currentModelName }
    end,
}

function getTime()
    return now
end

function getValue(source)
    expectEqual(source, 42, "widget should read its configured GPS source")
    return gpsValue
end

function getDateTime()
    return {
        year = 2026,
        mon = 7,
        day = 29,
        hour = 15,
        min = 4,
        sec = currentSecond,
    }
end

function loadScript(path)
    local localPath = string.gsub(
        path,
        "^/WIDGETS/RecoveryQR/",
        "sdcard/color/WIDGETS/RecoveryQR/"
    )
    return assert(loadfile(localPath, "t", widgetEnvironment))
end

local mockIo = {
    open = function(path, mode)
        if mode == "r" and widgetFiles[path] == nil then
            return nil
        end
        return { path = path, mode = mode }
    end,
    read = function(handle)
        return widgetFiles[handle.path]
    end,
    write = function(handle, data)
        widgetFiles[handle.path] = data
        return true
    end,
    close = function()
        return true
    end,
}

function del(path)
    local existed = widgetFiles[path] ~= nil
    widgetFiles[path] = nil
    return existed and 0 or 4
end

function rename(fromPath, toPath)
    if widgetFiles[fromPath] == nil or widgetFiles[toPath] ~= nil then
        return 1
    end
    widgetFiles[toPath] = widgetFiles[fromPath]
    widgetFiles[fromPath] = nil
    return 0
end

lvgl = {
    clear = function()
        builtLayout = nil
    end,
    build = function(layout)
        builtLayout = layout
    end,
    confirm = function(specification)
        pendingConfirmation = specification
    end,
    exitFullScreen = function()
        exitedFullscreen = true
    end,
}

widgetEnvironment = setmetatable({
    io = mockIo,
}, { __index = _G })

local function findLayoutObject(objectType)
    if builtLayout == nil then
        return nil
    end
    for _, object in ipairs(builtLayout) do
        if object.type == objectType then
            return object
        end
    end
    return nil
end

local widgetModule = assert(loadfile(
    "sdcard/color/WIDGETS/RecoveryQR/main.lua",
    "t",
    widgetEnvironment
))()
expectEqual(widgetModule.name, "Recovery QR")
expect(widgetModule.useLvgl, "widget should opt into LVGL")

local widgetOptions = {
    GPS = 42,
    Live = COLOR_THEME_ACTIVE,
    Stored = COLOR_THEME_WARNING,
    Text = COLOR_THEME_PRIMARY1,
    Muted = COLOR_THEME_DISABLED,
}
local widget = widgetModule.create({ x = 0, y = 0, w = 300, h = 180 }, widgetOptions)
widgetModule.update(widget, widgetOptions)
expectEqual(widget.state, "waiting")
expectEqual(findLayoutObject("qrcode"), nil, "waiting layout should not build a QR code")

gpsValue = { lat = 40.1, lon = -74.2, delay = 0 }
now = 200
widgetModule.refresh(widget, nil, nil)
expectEqual(widget.state, "live")
local qrObject = findLayoutObject("qrcode")
expect(qrObject ~= nil, "live layout should contain a QR code")
expectEqual(qrObject.data, "https://maps.google.com/?q=40.100000,-74.200000")
local quietZone = findLayoutObject("rectangle")
expect(quietZone ~= nil, "QR layout should include a white quiet zone")
expect(qrObject.x - quietZone.x >= quietZone.w // 10,
    "quiet zone should be wide enough for reliable scanning")
expect(widgetFiles["/WIDGETS/RecoveryQR/last_Rescue_Plane.txt"] ~= nil,
    "first valid position should be persisted")

gpsValue = { lat = 40.10005, lon = -74.20005, delay = 0 }
now = 250
widgetModule.refresh(widget, nil, nil)
expectEqual(findLayoutObject("qrcode").data, qrObject.data,
    "rapid GPS changes should not rebuild the QR more than once per second")
now = 300
widgetModule.refresh(widget, nil, nil)
qrObject = findLayoutObject("qrcode")
expectEqual(qrObject.data, "https://maps.google.com/?q=40.100050,-74.200050",
    "latest position should reach the QR when the refresh interval expires")

currentSecond = 20
now = 1800
widgetModule.refresh(widget, nil, nil)
expectEqual(widget.record.captured, "2026-07-29 15:04:20",
    "stationary GPS data should still refresh the capture time")
expect(string.find(
    widgetFiles["/WIDGETS/RecoveryQR/last_Rescue_Plane.txt"],
    "captured=2026-07-29 15:04:20",
    1,
    true
) ~= nil, "live checkpoint should persist the refreshed capture time")

gpsValue = 0
now = 1801
widgetModule.refresh(widget, nil, nil)
expectEqual(widget.state, "stored")
expectEqual(logic.mapsUrl(widget.record), qrObject.data,
    "telemetry loss should retain the last position")

local restarted = widgetModule.create(
    { x = 0, y = 0, w = 300, h = 180 },
    widgetOptions
)
widgetModule.update(restarted, widgetOptions)
expectEqual(restarted.state, "stored",
    "a new widget instance should restore the saved position")
expectEqual(logic.mapsUrl(restarted.record), qrObject.data)

gpsValue = { lat = 40.2, lon = -74.3, delay = 0 }
currentSecond = 21
now = 1802
widgetModule.refresh(restarted, nil, nil)
expect(string.find(
    widgetFiles["/WIDGETS/RecoveryQR/last_Rescue_Plane.txt"],
    "lat=40.200000",
    1,
    true
) ~= nil, "the first new fix after loading should persist immediately")
gpsValue = 0

currentModelFilename = "Another Model.yml"
currentModelName = "Another Model"
local otherModel = widgetModule.create(
    { x = 0, y = 0, w = 300, h = 180 },
    widgetOptions
)
widgetModule.update(otherModel, widgetOptions)
expectEqual(otherModel.state, "waiting",
    "saved positions should remain isolated by model")
currentModelFilename = "Rescue Plane.yml"
currentModelName = "Rescue Plane"

widgetModule.refresh(widget, 0, nil)
expectEqual(widget.fullscreen, true)
expect(findLayoutObject("qrcode") ~= nil, "fullscreen layout should contain a QR code")

for _, size in ipairs({
    { 320, 240 },
    { 320, 480 },
    { 480, 272 },
    { 480, 320 },
    { 800, 480 },
}) do
    LCD_W = size[1]
    LCD_H = size[2]
    widget.fullscreen = false
    widgetModule.refresh(widget, 0, nil)
    qrObject = findLayoutObject("qrcode")
    quietZone = findLayoutObject("rectangle")
    expect(qrObject ~= nil and qrObject.w > 0,
        "fullscreen QR should have a positive size")
    expect(quietZone.x >= 0 and quietZone.y >= 0,
        "quiet zone should start inside the display")
    expect(quietZone.x + quietZone.w <= LCD_W,
        "quiet zone should fit the display width")
    expect(quietZone.y + quietZone.h <= LCD_H,
        "quiet zone should fit the display height")
    if LCD_W == 320 and LCD_H == 480 then
        expect(qrObject.w >= 180,
            "portrait fullscreen should use the available vertical space")
    end
end

local clearButton = findLayoutObject("button")
expect(clearButton ~= nil, "fullscreen stored layout should contain the clear button")
clearButton.press()
expect(pendingConfirmation ~= nil, "clear action should require confirmation")
pendingConfirmation.confirm()
expectEqual(widget.state, "waiting")
expectEqual(widgetFiles["/WIDGETS/RecoveryQR/last_Rescue_Plane.txt"], nil)

widgetModule.refresh(widget, 0, { tapCount = 2 })
expect(exitedFullscreen, "double tap should exit fullscreen mode")

print(string.format("Recovery QR tests passed: %d", testsRun))

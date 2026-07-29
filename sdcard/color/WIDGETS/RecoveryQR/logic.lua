--
-- Copyright (C) EdgeTX
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--

local M = {}

local COORDINATE_PRECISION = 6
local GOOGLE_MAPS_PREFIX = "https://maps.google.com/?q="

local function isFinite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function formatCoordinate(value)
    local text = string.format("%." .. COORDINATE_PRECISION .. "f", value)
    if text == "-0.000000" then
        return "0.000000"
    end
    return text
end

function M.normalizeGps(value)
    if type(value) ~= "table" then
        return nil
    end

    local lat = tonumber(value.lat)
    local lon = tonumber(value.lon)
    if not isFinite(lat) or not isFinite(lon) then
        return nil
    end
    if lat < -90 or lat > 90 or lon < -180 or lon > 180 then
        return nil
    end

    -- Telemetry receivers commonly publish 0,0 before acquiring a fix.
    if lat == 0 and lon == 0 then
        return nil
    end

    return {
        lat = lat,
        lon = lon,
        delay = tonumber(value.delay),
    }
end

function M.coordinateText(position)
    if position == nil then
        return "--.------, --.------"
    end
    return formatCoordinate(position.lat) .. ", " .. formatCoordinate(position.lon)
end

function M.mapsUrl(position)
    if position == nil then
        return nil
    end
    return GOOGLE_MAPS_PREFIX
        .. formatCoordinate(position.lat)
        .. ","
        .. formatCoordinate(position.lon)
end

function M.captureStamp(dateTime)
    if type(dateTime) ~= "table" then
        return "Unknown time"
    end

    local year = tonumber(dateTime.year)
    local month = tonumber(dateTime.mon)
    local day = tonumber(dateTime.day)
    local hour = tonumber(dateTime.hour)
    local minute = tonumber(dateTime.min)
    local second = tonumber(dateTime.sec)
    if not year or not month or not day or not hour or not minute or not second then
        return "Unknown time"
    end

    return string.format(
        "%04d-%02d-%02d %02d:%02d:%02d",
        year, month, day, hour, minute, second
    )
end

function M.newRecord(position, captured)
    if position == nil then
        return nil
    end
    return {
        lat = position.lat,
        lon = position.lon,
        captured = captured or "Unknown time",
    }
end

function M.serializeRecord(record)
    if record == nil then
        return nil
    end

    return table.concat({
        "RecoveryQR,1",
        "lat=" .. formatCoordinate(record.lat),
        "lon=" .. formatCoordinate(record.lon),
        "captured=" .. tostring(record.captured or "Unknown time"),
        "",
    }, "\n")
end

function M.parseRecord(data)
    if type(data) ~= "string" or not string.find(data, "^RecoveryQR,1\n") then
        return nil
    end

    local lat = tonumber(string.match(data, "\nlat=([^\n]+)"))
    local lon = tonumber(string.match(data, "\nlon=([^\n]+)"))
    local captured = string.match(data, "\ncaptured=([^\n]+)")
    local position = M.normalizeGps({ lat = lat, lon = lon })
    if position == nil or captured == nil or captured == "" then
        return nil
    end

    return M.newRecord(position, captured)
end

function M.sanitizeModelKey(filename)
    local key = tostring(filename or "")
    key = string.gsub(key, "%.[^%.]+$", "")
    key = string.gsub(key, "[^%w_-]", "_")
    key = string.sub(key, 1, 32)
    if key == "" then
        return "default"
    end
    return key
end

function M.state(live, record)
    if live and record ~= nil then
        return "live"
    elseif record ~= nil then
        return "stored"
    end
    return "waiting"
end

function M.layoutForZone(width, height, fullscreen)
    width = tonumber(width) or 0
    height = tonumber(height) or 0

    if fullscreen then
        return "fullscreen"
    elseif width < 90 or height < 48 then
        return "tiny"
    elseif width < 260 or height < 150 then
        return "compact"
    end
    return "qr"
end

function M.shouldPersist(lastSavedSignature, signature, lastSavedAt, now,
                         wasLive, isLive, interval)
    if signature == nil or signature == lastSavedSignature then
        return false
    end
    if lastSavedSignature == nil then
        return true
    end
    if wasLive and not isLive then
        return true
    end
    if not isLive then
        return false
    end
    if lastSavedAt == nil or now == nil or now < lastSavedAt then
        return true
    end
    return now - lastSavedAt >= (interval or 0)
end

return M

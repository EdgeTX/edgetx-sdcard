--
-- Copyright (C) EdgeTX
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--

local M = {}

local TRAINER_NOT_CONNECTED = 0
local TRAINER_CONNECTED = 1
local TRAINER_DISCONNECTED = 2
local TRAINER_RECONNECTED = 3

local states = {
    waiting = {
        label = "WAITING",
        short = "WAIT",
        detail = "No trainer link",
        link = "Not connected",
        control = "Instructor",
        color = "neutral",
    },
    waiting_requested = {
        label = "NO LINK",
        short = "NO LINK",
        detail = "Student control requested",
        link = "Not connected",
        control = "Requested",
        color = "warning",
    },
    connected = {
        label = "CONNECTED",
        short = "LINK",
        detail = "Trainer link ready",
        link = "Connected",
        control = "Instructor",
        color = "connected",
    },
    reconnected = {
        label = "RECONNECTED",
        short = "BACK",
        detail = "Trainer link restored",
        link = "Connected",
        control = "Instructor",
        color = "connected",
    },
    active = {
        label = "STUDENT CONTROL",
        short = "LIVE",
        detail = "Trainer input is active",
        link = "Connected",
        control = "Student",
        color = "active",
    },
    lost = {
        label = "LINK LOST",
        short = "LOST",
        detail = "Trainer was disconnected",
        link = "Lost",
        control = "Instructor",
        color = "warning",
    },
    lost_requested = {
        label = "LINK LOST",
        short = "LOST",
        detail = "Student control requested",
        link = "Lost",
        control = "Requested",
        color = "warning",
    },
    unknown = {
        label = "UNKNOWN",
        short = "?",
        detail = "Trainer state unavailable",
        link = "Unknown",
        control = "Instructor",
        color = "neutral",
    },
}

function M.findTrainerSwitches(getCustomFunction, trainerFunction)
    local switches = {}
    local seen = {}

    for index = 0, 63 do
        local customFunction = getCustomFunction(index)
        if customFunction == nil then
            break
        end

        local enabled = customFunction.active == true or customFunction.active == 1
        local switch = customFunction.switch or 0
        if enabled and customFunction.func == trainerFunction and switch ~= 0 and not seen[switch] then
            switches[#switches + 1] = switch
            seen[switch] = true
        end
    end

    return switches
end

function M.isControlRequested(switches, getSwitchValue)
    for index = 1, #switches do
        if getSwitchValue(switches[index]) == true then
            return true
        end
    end

    return false
end

function M.classify(status, controlRequested, showReconnected)
    local key

    if status == TRAINER_CONNECTED or status == TRAINER_RECONNECTED then
        if controlRequested then
            key = "active"
        elseif status == TRAINER_RECONNECTED and showReconnected then
            key = "reconnected"
        else
            key = "connected"
        end
    elseif status == TRAINER_DISCONNECTED then
        key = controlRequested and "lost_requested" or "lost"
    elseif status == TRAINER_NOT_CONNECTED then
        key = controlRequested and "waiting_requested" or "waiting"
    else
        key = "unknown"
    end

    return key, states[key]
end

function M.layoutForZone(zone)
    local width = zone and zone.w or 0
    local height = zone and zone.h or 0

    if width < 120 or height <= 45 then
        return "tiny"
    elseif height <= 70 then
        return "compact"
    elseif width < 240 or height < 130 then
        return "medium"
    end

    return "large"
end

return M

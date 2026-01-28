local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

--local m_log = require("./FlightsViewer/lib_log")

function M.split(text)
    local cnt = 0
    local result = {}
    for val in string_gmatch(string_gsub(text, ",,", ", ,"), "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    --M.m_log.info("split: #col: %d (%s)", cnt, text)
    --M.m_log.info("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

function M.split_pipe(text)
    -- M.m_log.info("split_pipe(%s)", text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, "||", "| |"), "([^|]+)|?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    M.m_log.info("split_pipe: #col: %d (%s)", cnt, text)
    M.m_log.info("split_pipe: #col: %d [1-%s, 2-%s, ...]", cnt, result[1], result[2])
    return result, cnt
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function M.trim(s)
    if s == nil then
        return nil
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function M.trim_safe(s)
    if s == nil then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
    --string.gsub(text, ",,", ", ,")
end

return M

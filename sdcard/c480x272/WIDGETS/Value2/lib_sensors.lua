local m_log, app_name = ...

local M =  {}
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


---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

function M.split(text)
    local cnt = 0
    local result = {}
    for val in string_gmatch(string_gsub(text, ",,", ", ,"), "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    --m_log.info("split: #col: %d (%s)", cnt, text)
    --m_log.info("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

function M.split_pipe(text)
    -- m_log.info("split_pipe(%s)", text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, "||", "| |"), "([^|]+)|?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    m_log.info("split_pipe: #col: %d (%s)", cnt, text)
    m_log.info("split_pipe: #col: %d [1-%s, 2-%s, ...]", cnt, result[1], result[2])
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

function M.findSourceId(sourceNameList)
    local interesting_sources = {}
    for i = 200, 400 do
        local name = getSourceName(i)
        if name ~= nil then
            -- workaround for bug in getFiledInfo()  -- ???? why?
            if string.byte(string.sub(name, 1, 1)) > 127 then name = string.sub(name, 2, -1) end
            if string.byte(string.sub(name, 1, 1)) > 127 then name = string.sub(name, 2, -1) end

            for _, sourceName in ipairs(sourceNameList) do
                -- print(string.format("init_compare_source: [%s(%d)][%s] (is =? %s)", name, i, sourceName, (name == sourceName)))
                if (string.lower(name) == string.lower(sourceName)) then
                    print(string.format("init_compare_source (collecting): [%s(%d)] == [%s]", name, i, sourceName))
                    interesting_sources[#interesting_sources + 1] = {i,name}
                end
            end
        end
    end

    -- find the source with highest priority
    for _, sourceName in ipairs(sourceNameList) do
        for _, source in ipairs(interesting_sources) do
            local idx = source[1]
            local name = source[2]
            -- print(string.format("init_compare_source: is_needed? [%s(%d)]", name, idx))
            if (string.lower(name) == string.lower(sourceName)) then
                print(string.format("init_compare_source: we have: %s", sourceName))
                print(string.format("init_compare_source (found): [%s(%d)] == [%s]", name, idx, sourceName))
                return idx
            end
        end
        print(string.format("init_compare_source: we do not have: %s", sourceName))
    end
    return 1
end


return M

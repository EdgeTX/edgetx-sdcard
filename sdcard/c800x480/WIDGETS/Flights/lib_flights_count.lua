local m_log, app_name, count_file_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name

local line_format = "%-18s,%-13s\n"
local countList = {}
function M.init()
end

function M.isFileExist()
    M.m_log.info("is_file_exist()")
    local hFile = io.open(count_file_name, "r")
    if hFile == nil then
        M.m_log.info("file not exist - %s", count_file_name)
        return false
    end
    io.close(hFile)
    M.m_log.info("file exist - %s", count_file_name)
    return true
end

local function trim(s)
    if s == nil then
        return nil
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function split(text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, ",,", ", ,"), "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    -- M.m_log.info("split: #col: %d (%s)", cnt, text)
    -- M.m_log.info("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

-- csv file read
-- format: model_name,flight_count
function M.fileRead()
    local hFile = io.open(count_file_name, "r")
    if not hFile then
        error("Could not open file " .. count_file_name)
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        M.m_log.info("Index header could not be found, file: %s", M.idx_file_name)
        return
    end

    -- check that index file is correct version
    local api_ver = string.match(data1, "# api_ver=(%d*)")
    M.m_log.info("api_ver: %s", api_ver)
    if api_ver ~= "1" then
        M.m_log.info("api_ver of index files is not updated (api_ver=%d)", api_ver)
        return
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    M.m_log.info("indexRead: header: %s", headerLine)

    io.seek(hFile, index)
    local data2 = io.read(hFile, 2048 * 32)
    io.close(hFile)

    M.m_log.info("data2: %s", data2)

    countList = {}
    for line in string.gmatch(data2, "([^\n]+)\n") do
        if string.sub(line, 1, 1) ~= "#" then
            -- M.m_log.info("indexRead: index-line: %s", line)
            local values = split(line)

            local key = trim(values[1])
            local value = trim(values[2])
            -- if not a number, set to -1
            value = tonumber(value)
            if key and value then
                countList[key] = tonumber(value)
            end

            M.m_log.info("indexRead: key: %s, value: %s", key, value)
        else
            M.m_log.info("indexRead: comment: [%s]", line)
        end
    end

end

function M.fileSave()
    -- -- Save the updated content back to the CSV file
    hFile = io.open(count_file_name, "w")
    io.write(hFile, "model_name      ,flight_count\n")
    io.write(hFile, "# api_ver=1\n")
    for k, v in pairs(countList) do
        M.m_log.info("writing: %s", k)
        io.write(hFile, string.format(line_format, k, v))
    end
    io.close(hFile)
end


-- Increase the flight_count in the second line
function M.setValue(key, newVal)
    M.fileRead()

    -- Increase the flight_count in the second line
    local count = 0
    for k, v in pairs(countList) do
        M.m_log.info("--+ key: %s, val: %s", k, v)
        if key == k then
            countList[k] = newVal
        end
        M.m_log.info("--+ key: %s, val: %s", k, countList[k])
    end

    -- -- Save the updated content back to the CSV file
    M.fileSave(countList)
end

function M.getValue(key)
    -- M.m_log.info("------------- getFlightInfoByKey start")

    for model_name, flight_count in pairs(countList) do
        M.m_log.info("getFlightCount: %s", model_name)
        if key == model_name then
            local fileCount = countList[model_name]
            return fileCount
        end
    end

    return 0
end

return M


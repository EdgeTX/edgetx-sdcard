local m_log, app_name, m_utils, m_tables = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_tables = m_tables
M.m_utils = m_utils

--M.idx_file_name = "/app_data/flights/flights-history.csv"
M.idx_file_name = "/flights-history.csv"

M.log_files_index_info = {}

function M.indexInit()
    M.m_tables.table_clear(M.log_files_index_info)
end

local function compare_by_dates(a, b)
    --local a1 = string.sub(a.flight_date, -21, -5)
    --local b1 = string.sub(b.flight_date, -21, -5)
    local a1 = a.flight_date
    local b1 = b.flight_date
    --M.m_log.info("ab, %s ? %s", a, b)
    --M.m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 < b1
end

local function insertFlight(flight_date, model_name, flight_count, duration, model_id)
    M.m_log.info("updateFlight(%s)", flight_date)

    local new_fight = {
        key = string.format("key:%s", m_utils.trim(flight_date)),
        flight_date = m_utils.trim(flight_date),
        model_name = m_utils.trim(model_name),
        flight_count = tonumber(m_utils.trim(flight_count)),
        duration = tonumber(m_utils.trim(duration)),
        model_id = m_utils.trim(model_id),
        desc = string.format("%s - %s #%d (%d min)", flight_date, model_name, flight_count, duration/60)
        --desc = string.format("#%d %s - %s (%d min)", flight_count, flight_date, model_name, duration/60)
        --desc = string.format("%s - #%d %s (%d min)", flight_date, flight_count,model_name, duration/60)
    }
    M.m_tables.list_ordered_insert(M.log_files_index_info, new_fight, compare_by_dates, 1)
end

function M.indexPrint(prefix)
    local tbl = M.log_files_index_info
    M.m_log.info("-------------show start (%s)", prefix)
    for i = 1, #tbl, 1 do
        local f_info = tbl[i]
        local s = string.format("%d. flight_date: %s, model_name: %s, flight_count: %s, duration: %s, model_id: %s",
            i,
            f_info.flight_date, f_info.model_name, f_info.flight_count, f_info.duration, f_info.model_id)

        M.m_log.info(s)
    end
    M.m_log.info("------------- show end")
end

function M.historyFileRead()
    M.m_log.info("historyFileRead()")
    M.m_tables.table_clear(M.log_files_index_info)
    local hFile = io.open(M.idx_file_name, "r")
    if hFile == nil then
        return
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

    --M.indexPrint("indexRead-should-be-empty")
    local is_index_have_deleted_files = false
    for line in string.gmatch(data2, "([^\n]+)\n") do

        if string.sub(line, 1, 1) ~= "#" then
            M.m_log.info("indexRead: index-line: %s", line)
            local values = m_utils.split(line)

            local flight_date = m_utils.trim(values[1])
            local model_name = m_utils.trim(values[2])
            local flight_count = m_utils.trim(values[3])
            local duration = m_utils.trim(values[4])
            local model_id = m_utils.trim(values[5])
            M.m_log.info("indexRead: line: flight_date: %s, model_name: %s, flight_count: %s, duration: %s, model_id: %s",
                flight_date, model_name, flight_count, duration, model_id)

            --m_log.info("files_on_disk exist: %s", file_name)
            insertFlight(flight_date, model_name, flight_count, duration, model_id)
        end
    end

    io.close(hFile)

    M.indexPrint("end of indexRead")
end

function M.getFileDataInfo(flight_date)
    --M.m_log.info("getFileDataInfo(%s)", file_name)
    --M.indexPrint("M.getFileDataInfo-start")

    for i = 1, #M.log_files_index_info do
        local f_info = M.log_files_index_info[i]
        --M.m_log.info("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if flight_date == f_info.flight_date then
            --M.m_log.info("getFileDataInfo: info from cache %s", flight_date)
            return f_info
        end
    end

    M.m_log.info("getFileDataInfo: file not in index... %s", flight_date)
    return false, nil, nil, nil, nil, nil, nil, nil
end


return M


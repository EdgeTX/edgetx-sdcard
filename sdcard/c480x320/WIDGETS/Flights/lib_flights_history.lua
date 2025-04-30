local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name

local hist_file_name = "/app_data/flights/flights-history.csv"
local hist_file_name = "/flights-history.csv"

local line_format = "%-17s,%-16s,%-13s,%-9s,%-12s\n"

function M.init()
end

function M.isFileExist(file_name)
    M.m_log.info("is_file_exist()")
    local hFile = io.open(file_name, "r")
    if hFile == nil then
        M.m_log.info("file not exist - %s", file_name)
        return false
    end
    io.close(hFile)
    M.m_log.info("file exist - %s", file_name)
    return true
end

function M.writeHeaderIfNeeded()
    M.m_log.info("writeHeaderIfNeeded()")

    local is_exist = M.isFileExist(hist_file_name)
    M.m_log.info("is_exist: %s", is_exist)
    if is_exist == true then
        return
    end

    local headline = string.format(line_format,
        "flight_date",
        "model_name",
        "flight_count",
        "duration",
        "model_id"
    )

    -- write csv header
    local hFile = io.open(hist_file_name, "a")
    if hFile == nil then
        M.m_log.info("failed to write file, probably dir is not exist: %s", hist_file_name)
        return
    end
    io.write(hFile, headline)
    local ver_line = "# api_ver=1\n"
    io.write(hFile, ver_line)
    io.close(hFile)
end

function M.addFlightLog(flight_start_date_time, duration, flight_count)
    M.m_log.info("addFlightLog(%s, %s)", duration, flight_count)

    M.writeHeaderIfNeeded()

    -- flight_date =
    local dt = flight_start_date_time
    local flight_date = string.format("%04d-%02d-%02d %02d:%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min)
    M.m_log.info("date_str: %s", flight_date)

    -- model name
    local minfo = model.getInfo()
    local model_name = minfo.name
    local model_id = minfo.filename

    local line = string.format(line_format,
        flight_date,
        model_name,
        flight_count,
        duration,
        model_id
    )
    m_log.info("adding flight history line to csv: [%s]", line)

    local hFile = io.open(hist_file_name, "a")
    if hFile == nil then
        M.m_log.info("failed to write file, probably dir is not exist: %s", hist_file_name)
        return
    end
    io.write(hFile, line)
    io.close(hFile)
end

return M


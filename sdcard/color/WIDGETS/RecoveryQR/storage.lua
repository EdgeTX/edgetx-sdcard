--
-- Copyright (C) EdgeTX
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--

local M = {}

local function defaultRead(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local data = io.read(handle, 512)
    io.close(handle)
    return data
end

local function defaultWrite(path, data)
    local handle = io.open(path, "w")
    if handle == nil then
        return false
    end
    io.write(handle, data)
    io.close(handle)
    return true
end

local function defaultDelete(path)
    return del(path)
end

local function defaultRename(fromPath, toPath)
    return rename(fromPath, toPath)
end

local function operations(custom)
    custom = custom or {}
    return {
        read = custom.read or defaultRead,
        write = custom.write or defaultWrite,
        delete = custom.delete or defaultDelete,
        rename = custom.rename or defaultRename,
    }
end

function M.paths(directory, modelKey)
    local base = directory .. "/last_" .. modelKey .. ".txt"
    return {
        current = base,
        temporary = base .. ".tmp",
        backup = base .. ".bak",
    }
end

function M.load(paths, parser, customOperations)
    local ops = operations(customOperations)
    local record = parser(ops.read(paths.current))
    if record ~= nil then
        return record
    end
    return parser(ops.read(paths.backup))
end

function M.save(paths, data, customOperations)
    if type(data) ~= "string" then
        return false
    end

    local ops = operations(customOperations)
    ops.delete(paths.temporary)
    if not ops.write(paths.temporary, data) then
        return false
    end

    ops.delete(paths.backup)
    local movedCurrent = ops.rename(paths.current, paths.backup) == 0
    if ops.rename(paths.temporary, paths.current) ~= 0 then
        if movedCurrent then
            ops.rename(paths.backup, paths.current)
        end
        ops.delete(paths.temporary)
        return false
    end

    ops.delete(paths.backup)
    return true
end

function M.clear(paths, customOperations)
    local ops = operations(customOperations)
    ops.delete(paths.temporary)
    ops.delete(paths.backup)
    return ops.delete(paths.current) == 0
end

return M

local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name


function M.tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) .. '"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"' .. tostring(v) .. '"'
        if type(v) == 'table' then
            M.tprint(v, (s or '') .. kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            M.m_log.info(type(t) .. (s or '') .. kfmt .. ' = ' .. vfmt)
        end
    end
end

function M.table_clear(tbl)
    -- clean without creating a new list
    for i = 0, #tbl do
        table.remove(tbl, 1)
    end
end

function M.table_print(prefix, tbl)
    M.m_log.info(">>> table_print (%s)", prefix)
    for i = 1, #tbl, 1 do
        local val = tbl[i]
        if type(val) ~= "table" then
            M.m_log.info(string.format("%d. %s: %s", i, prefix, val))
        else
            local t_val = val
            M.m_log.info("-++++------------ %d %s", #val, type(t_val))
            for j = 1, #t_val, 1 do
                local val = t_val[j]
                 M.m_log.info(string.format("%d. %s: %s", i, prefix, val))
            end
        end
    end
    M.m_log.info("<<< table_print end (%s) ", prefix)
end

function M.compare_file_names(a, b)
    local a1 = string.sub(a.file_name, -21, -5)
    local b1 = string.sub(b.file_name, -21, -5)
    --M.m_log.info("ab, %s ? %s", a, b)
    --M.m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 > b1
end


function M.list_ordered_insert(lst, newVal, cmp, firstValAt)
    -- sort
    for i = firstValAt, #lst, 1 do
        -- remove duplication
        --M.m_log.info("list_ordered_insert - %s ? %s",  newVal, lst[i] )
        if newVal == lst[i] then
            --M.table_print("list_ordered_insert - duplicated", lst)
            return
        end

        if cmp(newVal, lst[i]) == true then
            table.insert(lst, i, newVal)
            --M.table_print("list_ordered_insert - inserted", lst)
            return
        end
        --M.table_print("list_ordered_insert-loop", lst)
    end
    table.insert(lst, newVal)
    --M.table_print("list_ordered_insert-inserted-to-end", lst)
end


return M

local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.tele_src_name = nil
M.tele_src_id = nil

local getTime = getTime
local lcd = lcd

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px

local FONT_LIST = {FONT_6, FONT_8, FONT_12, FONT_16, FONT_38}

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

-- const's
local UNIT_ID_TO_STRING = {
    "V", "A", "mA", "kts", "m/s", "f/s", "km/h", "mph", "m", "f",
    "°C", "°F", "%", "mAh", "W", "mW", "dB", "rpm", "g", "°",
    "rad", "ml", "fOz", "ml/m", "Hz", "mS", "uS", "km"
}

function M.unitIdToString(unitId)
    if unitId == nil then
        return ""
    end
    -- UNIT_RAW
    if unitId == "0" then
        return ""
    end

    --log("idUnit: " .. unitId)

    if (unitId > 0 and unitId <= #UNIT_ID_TO_STRING) then
        local txtUnit = UNIT_ID_TO_STRING[unitId]
        --log("txtUnit: " .. txtUnit)
        return txtUnit
    end

    --return "-#-"
    return ""
end

---------------------------------------------------------------------------------------------------

function M.periodicInit()
    local t = {}
    t.startTime = -1;
    t.durationMili = -1;
    return t
end

function M.periodicStart(t, durationMili)
    t.startTime = getTime();
    t.durationMili = durationMili;
end

function M.periodicHasPassed(t, show_log)
    -- not started yet
    if (t.durationMili <= 0) then
        return false;
    end

    local elapsed = getTime() - t.startTime;
    --log('elapsed: %d (t.durationMili: %d)', elapsed, t.durationMili)
    if show_log == true then
        log('elapsed: %0.1f/%0.1f sec', elapsed/100, t.durationMili/1000)
    end
    local elapsedMili = elapsed * 10;
    if (elapsedMili < t.durationMili) then
        return false;
    end
    return true;
end

function M.periodicGetElapsedTime(t, show_log)
    local elapsed = getTime() - t.startTime;
    local elapsedMili = elapsed * 10;
    if show_log == true then
        log('elapsed: %0.1f/%0.1f sec', elapsed/100, t.durationMili/1000)
    end
    return elapsedMili;
end

function M.periodicReset(t)
    t.startTime = getTime();
    --log("periodicReset()");
    M.periodicGetElapsedTime(t)
end

function M.getDurationMili(t)
    return t.durationMili
end

---------------------------------------------------------------------------------------------------

function M.isTelemetryAvailable()
    local is_telem = getRSSI()
    return is_telem > 0
end

---------------------------------------------------------------------------------------------------

-- workaround to detect telemetry-reset event, until a proper implementation on the lua interface will be created
-- this workaround assume that:
--   RSSI- is always going down
--   RSSI- is reset on the C++ side when a telemetry-reset is pressed by user
--   widget is calling this func on each refresh/background
-- on event detection, the function onTelemetryResetEvent() will be trigger
--
function M.detectResetEvent(wgt, callback_onTelemetryResetEvent)

    local currMinRSSI = getValue('RSSI-')
    if (currMinRSSI == nil) then
        log("telemetry reset event: can not be calculated")
        return
    end
    if (currMinRSSI == wgt.telemResetLowestMinRSSI) then
        --log("telemetry reset event: not found")
        return
    end

    if (currMinRSSI < wgt.telemResetLowestMinRSSI) then
        -- rssi just got lower, record it
        wgt.telemResetLowestMinRSSI = currMinRSSI
        --log("telemetry reset event: not found")
        return
    end

    -- reset telemetry detected
    wgt.telemResetLowestMinRSSI = 101
    log("telemetry reset event detected")

    -- notify event
    callback_onTelemetryResetEvent(wgt)
end

---------------------------------------------------------------------------------------------------

function M.getSensorInfoByName(sensorName)
    sensorName = string.gsub(sensorName, "-", "")
    sensorName = string.gsub(sensorName, "+", "")
    local sensors = {}
    for i=0, 30, 1 do
        local s1 = {}
        local s2 = model.getSensor(i)

        --type (number) 0 = custom, 1 = calculated
        s1.type = s2.type
        --name (string) Name
        s1.name = s2.name
        --unit (number) See list of units in the appendix of the OpenTX Lua Reference Guide
        s1.unit = s2.unit
        --prec (number) Number of decimals
        s1.prec = s2.prec
        --id (number) Only custom sensors
        s1.id = s2.id
        --instance (number) Only custom sensors
        s1.instance = s2.instance
        --formula (number) Only calculated sensors. 0 = Add etc. see list of formula choices in Companion popup
        s1.formula = s2.formula

        -- log("getSensorInfo: %d. name: %s, unit: %s , prec: %s , id: %s , instance: %s ", i, s2.name, s2.unit, s2.prec, s2.id, s2.instance)

        if s2.name == sensorName then
            return s1
        end
    end

    return nil
 end

 function M.getSensorPrecession(sensorName)
    local sensorInfo = M.getSensorInfoByName(sensorName)
    if (sensorInfo == nil) then
        log("getSensorPrecession: not found sensor [%s]", sensorName)
        return -1
    end

    log("getSensorPrecession: name: %s, prec: %s , id: %s", sensorInfo.name, sensorInfo.prec, sensorInfo.id)
    return sensorInfo.prec
end


-- function M.getSensorId(sensorName)
--     local sensorInfo = M.getSensorInfoByName(sensorName)
--     if (sensorInfo == nil) then
--         log("getSensorId: not found sensor [%s]", sensorName)
--         return -1
--     end

--     log("getSensorId: name: %s, prec: %s , id: %s", sensorInfo.name, sensorInfo.prec, sensorInfo.id)
--     return sensorInfo.id
-- end


function M.isSensorExist(sensorName)
    local sensorInfo = M.getSensorInfoByName(sensorName)
    local is_exist = (sensorInfo ~= nil)
    log("getSensorInfo: [%s] is_exist: %s", sensorName, is_exist)
    return is_exist
 end

---------------------------------------------------------------------------------------------------
-- workaround for bug in getFiledInfo()  -- ???? why?
function M.cleanInvalidCharFromGetFiledInfo(sourceName)
     if string.byte(string.sub(sourceName, 1, 1)) > 127 then
        sourceName = string.sub(sourceName, 2, -1)
    end
    if string.byte(string.sub(sourceName, 1, 1)) > 127 then
        sourceName = string.sub(sourceName, 2, -1)
    end
    return sourceName
end

-- workaround for bug in getSourceName()
function M.getSourceNameCleaned(source)
    local sourceName = getSourceName(source)
    if (sourceName == nil) then
        return "N/A"
    end
    local sourceName = M.cleanInvalidCharFromGetFiledInfo(sourceName)
    return sourceName
end

------------------------------------------------------------------------------------------------------
function M.getFontSizeRelative(orgFontSize, delta)
    for i = 1, #FONT_LIST do
        if FONT_LIST[i] == orgFontSize then
            local newIndex = i + delta
            newIndex = math.min(newIndex, #FONT_LIST)
            newIndex = math.max(newIndex, 1)
            return FONT_LIST[newIndex]
        end
    end
    return orgFontSize
end

------------------------------------------------------------------------------------------------------
function M.lcdSizeTextFixed(txt, font_size)
    local ts_w, ts_h = lcd.sizeText(txt, font_size)

    local v_offset = 0
    if font_size == FONT_38 then
        v_offset = -15
    elseif font_size == FONT_16 then
        v_offset = -8
    elseif font_size == FONT_12 then
        v_offset = -6
    elseif font_size == FONT_8 then
        v_offset = -4
    elseif font_size == FONT_6 then
        v_offset = -3
    end
    return ts_w, ts_h +2*v_offset, v_offset
end

------------------------------------------------------------------------------------------------------
function M.drawText(x, y, text, font_size, text_color, bg_color)
    local ts_w, ts_h, v_offset = M.lcdSizeTextFixed(text, font_size)
    lcd.drawRectangle(x, y, ts_w, ts_h, BLUE)
    lcd.drawText(x, y + v_offset, text, font_size + text_color)
    return ts_w, ts_h, v_offset
end

function M.drawBadgedText(txt, txtX, txtY, font_size, text_color, bg_color)
    local ts_w, ts_h, v_offset = M.lcdSizeTextFixed(txt, font_size)
    local v_space = 2
    local bdg_h = v_space + ts_h + v_space
    local r = bdg_h / 2
    lcd.drawFilledCircle(txtX , txtY + r, r, bg_color)
    lcd.drawFilledCircle(txtX + ts_w , txtY + r, r, bg_color)
    lcd.drawFilledRectangle(txtX, txtY , ts_w, bdg_h, bg_color)

    lcd.drawText(txtX, txtY + v_offset + v_space, txt, font_size + text_color)

    --lcd.drawRectangle(txtX, txtY , ts_w, bdg_h, RED) -- dbg
end

function M.drawBadgedTextCenter(txt, txtX, txtY, font_size, text_color, bg_color)
    local ts_w, ts_h, v_offset = M.lcdSizeTextFixed(txt, font_size)
    local r = ts_h / 2
    local x = txtX - ts_w/2
    local y = txtY - ts_h/2
    lcd.drawFilledCircle(x + r * 0.3, y + r, r, bg_color)
    lcd.drawFilledCircle(x - r * 0.3 + ts_w , y + r, r, bg_color)
    lcd.drawFilledRectangle(x, y, ts_w, ts_h, bg_color)

    lcd.drawText(x, y + v_offset, txt, font_size + text_color)

    -- dbg
    --lcd.drawRectangle(x, y , ts_w, ts_h, RED) -- dbg
    --lcd.drawLine(txtX-30, txtY, txtX+30, txtY, SOLID, RED) -- dbg
    --lcd.drawLine(txtX, txtY-20, txtX, txtY+20, SOLID, RED) -- dbg
end

------------------------------------------------------------------------------------------------------
-- usage:
--log("bbb----------------------------------------------------------")
--wgt.tools.heap_dump(wgt, 0, 60)
--log("ccc----------------------------------------------------------")
function M.heap_dump(tbl, indent, max_dept)
    local spaces = string.rep("  ", indent)
    if max_dept == 0 then
        log(spaces .. "---- max dept ----")
        return
    end
    max_dept = max_dept -1
    indent = indent or 0

    for key, value in pairs(tbl) do
        if key ~= "_G" then
            if type(value) == "table" then
                --log(spaces .. key .. " (table) = {")
                log(spaces .. key .. " = {")
                M.heap_dump(value, indent + 1, max_dept)
                log(spaces .. "}")
            else
                log(spaces .. key .. " = " .. tostring(value))
            end
        end
    end
end
------------------------------------------------------------------------------------------------------

return M

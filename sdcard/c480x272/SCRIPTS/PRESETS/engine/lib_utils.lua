local m_log, app_name, m_script_folder = ...

local M = {}
M.m_log = m_log
M.app_name = app_name

-- state machine
M.PRESET_RC = {
    OK_CONTINUE = 10,
    PREV_PAGE = 11,
    NEXT_PAGE = 12,
    ERROR_EXIT = 13,
}

M.STICK_NUMBER_AIL = 3
M.STICK_NUMBER_ELE = 1
M.STICK_NUMBER_THR = 2
M.STICK_NUMBER_RUD = 0

M.defaultChannel_AIL = defaultChannel(M.STICK_NUMBER_AIL) + 1
M.defaultChannel_ELE = defaultChannel(M.STICK_NUMBER_ELE) + 1
M.defaultChannel_THR = defaultChannel(M.STICK_NUMBER_THR) + 1
M.defaultChannel_RUD = defaultChannel(M.STICK_NUMBER_RUD) + 1

M.defaultChannel_0_AIL = defaultChannel(M.STICK_NUMBER_AIL)
M.defaultChannel_0_ELE = defaultChannel(M.STICK_NUMBER_ELE)
M.defaultChannel_0_THR = defaultChannel(M.STICK_NUMBER_THR)
M.defaultChannel_0_RUD = defaultChannel(M.STICK_NUMBER_RUD)

local script_folder = m_script_folder
local ImgBackground = bitmap.open(script_folder .. "img/background.png")
local ImgPageUp = bitmap.open(script_folder .. "img/pageup.png")
local ImgPageDn = bitmap.open(script_folder .. "img/pagedn.png")

-----------------------------------------------------------------

-- better font size names
M.FONT_38 = XXLSIZE -- 38px
M.FONT_16 = DBLSIZE -- 16px
M.FONT_12 = MIDSIZE -- 12px
M.FONT_8 = 0 -- Default 8px
M.FONT_6 = SMLSIZE -- 6px


local function lcdSizeTextFixed(txt, font_size)
    local ts_w, ts_h = lcd.sizeText(txt, font_size)

    local v_offset = 0
    if font_size == M.FONT_38 then
        v_offset = -11
    elseif font_size == M.FONT_16 then
        v_offset = -5
    elseif font_size == M.FONT_12 then
        v_offset = -4
    elseif font_size == M.FONT_8 then
        v_offset = -3
    elseif font_size == M.FONT_6 then
        v_offset = 0
    end
    return ts_w, ts_h +2*v_offset, v_offset
end

function M.drawBadgedText(txt, field, font_size, is_selected, is_edit)
    local ts_w, ts_h, v_offset = lcdSizeTextFixed(txt, font_size)
    local bdg_h = 5 + ts_h + 5
    local r = bdg_h / 2

    if (field.w > 0) then
        ts_w = field.w
    else
        if (ts_w < 30) then
            ts_w = 30
        end
    end
    local bg_color = WHITE
    if (is_selected) then
        bg_color = GREEN
    end
    lcd.drawFilledCircle(field.x, field.y + r, r, bg_color)
    lcd.drawFilledCircle(field.x + ts_w, field.y + r, r, bg_color)
    lcd.drawFilledRectangle(field.x, field.y, ts_w, bdg_h, bg_color)
    local attr = 0
    if (is_selected and is_edit) then
        attr = attr + BLINK
    end

    lcd.drawText(field.x, field.y + v_offset + 5, txt, font_size + BLACK + attr)
end

-----------------------------------------------------------------
function M.drawTitle(txt, is_prev, is_next, img)
    lcd.clear()
    lcd.drawBitmap(img, 0, 0)

    lcd.drawText(120, 8, txt, COLOR_THEME_PRIMARY1)

    if is_prev == true then
        lcd.drawBitmap(ImgPageUp, 0, 95)
    end
    if is_next == true then
        lcd.drawBitmap(ImgPageDn, 455, 95)
    end
end

-----------------------------------------------------------------
function M.func1(text)
    local cnt = 0
    local result = {}
    M.m_log.info("func1: ", text)
    return result, cnt
end
-----------------------------------------------------------------

function M.readFileToString(filename)
    m_log.info("readFileToString: %s", filename)
    local file = io.open(filename, "r") -- Open the file in read mode
    if not file then
        return nil -- File does not exist or could not be opened
    end

    --local content = file:read("*a") -- Read the entire file content
    local content = io.read(file, 2000) -- Read the entire file content
    io.close(file) -- Close the file

    m_log.info("readFileToString: - content: %s", content)
    return content
end

function M.readMeta(filename)
    m_log.info("readMeta: %s", filename)

    local content = M.readFileToString(filename)
    m_log.info("readMeta: content: %s", content)

    local properties = {}
    if content == nil then
        return properties
    end

    --for line in string.gmatch(content, "([^,]+),?") do
    for line in string.gmatch(content, "(.-)\r?\n") do
        m_log.info("line: %s", line)

        local key, value = string.match(line, "^(.-)%s*=%s*(.*)$")
        if key and value then
            properties[key] = value
            m_log.info("%s: %s", key, value)
        end
    end

    return properties
end

--------------------------------------------------------------------

function M.input_search_by_name(neededInputName)
    for inputIdx = 0, 3 do
        for lineNo = 0, 2 do
            m_log.info("%d/%d", inputIdx,lineNo)
            local inInfo = model.getInput(inputIdx, lineNo)
            if inInfo ~= nil then
                m_log.info("%d/%d, name:%s, inputName:%s, source: %s", inputIdx,lineNo, inInfo.name, inInfo.inputName, inInfo.source)
                if inInfo.inputName == neededInputName then
                    return inputIdx
                end
            end
        end
    end
    return -1
end

-----------------------------------------------------------------------

return M

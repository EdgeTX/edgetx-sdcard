local m_log, app_name, app_folder = ...

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

local lvSCALE = lvgl.LCD_SCALE or 1
M.x1 = 10*lvSCALE
M.x2 = (LCD_W>=470) and 180*lvSCALE or 150*lvSCALE
M.x3 = (LCD_W>=470) and 280*lvSCALE or 235*lvSCALE
M.use_images = (LCD_W>=470)

---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

-- better font names
-- local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}
M.FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

M.channels_list = {"CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10", "CH11", "CH12", "CH13", "CH14", "CH15", "CH16"}

local function lcdSizeTextFixed(txt, font_size)
    local ts_w, ts_h = lcd.sizeText(txt, font_size)

    local v_offset = 0
    if font_size == M.FS.FONT_38 then
        v_offset = -11
    elseif font_size == M.FS.FONT_16 then
        v_offset = -5
    elseif font_size == M.FS.FONT_12 then
        v_offset = -4
    elseif font_size == M.FS.FONT_8 then
        v_offset = -3
    elseif font_size == M.FS.FONT_6 then
        v_offset = 0
    end
    return ts_w, ts_h +2*v_offset, v_offset
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
    log("readFileToString: %s", filename)
    local file = io.open(filename, "r") -- Open the file in read mode
    if not file then
        return nil -- File does not exist or could not be opened
    end

    --local content = file:read("*a") -- Read the entire file content
    local content = io.read(file, 2000) -- Read the entire file content
    io.close(file) -- Close the file

    log("readFileToString: - content: %s", content)
    return content
end

function M.readMeta(filename)
    log("readMeta: %s", filename)

    local content = M.readFileToString(filename)
    log("readMeta: content: %s", content)

    local properties = {}
    if content == nil then
        return properties
    end

    --for line in string.gmatch(content, "([^,]+),?") do
    for line in string.gmatch(content, "(.-)\r?\n") do
        log("line: %s", line)

        local key, value = string.match(line, "^(.-)%s*=%s*(.*)$")
        if key and value then
            properties[key] = value
            log("%s: %s", key, value)
        end
    end

    return properties
end

--------------------------------------------------------------------

function M.input_search_by_name(neededInputName)
    for inputIdx = 0, 3 do
        for lineNo = 0, 2 do
            log("%d/%d", inputIdx,lineNo)
            local inInfo = model.getInput(inputIdx, lineNo)
            if inInfo ~= nil then
                log("%d/%d, name:%s, inputName:%s, source: %s", inputIdx,lineNo, inInfo.name, inInfo.inputName, inInfo.source)
                if inInfo.inputName == neededInputName then
                    return inputIdx
                end
            end
        end
    end
    return -1
end

-----------------------------------------------------------------------

function M.addMix(channel, input, name, weight, index)
    local mix = {
        source = input,
        name = name,
        --carryTrim= 0 -- 0=on
        --trimSource= 0 -- 0=on
    }
    if weight ~= nil then
        mix.weight = weight
    end
    if index == nil then
        index = 0
    end
    model.insertMix(channel, index, mix)
end
-----------------------------------------------------------------------

function M.set_output_name(channel, txt)
    log("Setting output name for channel CH%s to '%s'", channel, txt)
    local out_info = model.getOutput(channel - 1)
    out_info.name = txt
    model.setOutput(channel - 1, out_info)
end

function M.safe_width(startX, neededWidth)
    local maxWidth = LCD_W - startX - 25
    if neededWidth <= maxWidth then
        return neededWidth
    else
        return maxWidth 
    end    
end

return M

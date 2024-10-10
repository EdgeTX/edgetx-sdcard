---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################


-- Author: Offer Shmuely
-- Date: 2023
local ver = "0.1"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send the log file that will be created on: /SCRIPTS/PRESETS/engine/app.log

local app_name = "PresetsLoader"

local script_folder = "/SCRIPTS/PRESETS/engine/"
--chdir(script_folder)

local m_log =  loadScript(script_folder .. "lib_log", "tcd")(app_name, script_folder)
local m_utils = loadScript(script_folder .. "lib_utils", "tcd")(m_log, app_name, script_folder)
local m_libgui =  loadScript(script_folder .. "libgui", "tcd")()

local preset_list = {
    about="---"
}
local num_of_presets = 0

local preset_script_chunk
local preset_info = {
    category="",
    name="",
    author="",
    ver="",
    help=""
}
local error_desc = nil


local dd_preset_folder_name = "---"
local dd_preset_folder_name_idx

-- Instantiate a new GUI object
local ctx1 = m_libgui.newGUI()
local ddModel

-- state machine
local STATE = {
    SPLASH = 0,
    INIT = 1,
    SELECTION_INIT = 2,
    SELECTION = 3,
    PRESET_OPTIONS_INIT = 4,
    PRESET_OPTIONS = 5,
    CONFIRM_REQUEST_INIT = 6,
    CONFIRM_REQUEST = 7,
    UPDATE_MODEL_INIT = 8,
    UPDATE_MODEL = 9,
    ON_END = 10,
    ERROR_PAGE = 11
}
local state = STATE.SPLASH

local ImgSplash = bitmap.open(script_folder .. "img/splash.png")
local ImgSummary = bitmap.open(script_folder .. "img/summary.png")
local ImgBackground = bitmap.open(script_folder .. "img/background.png")
local ImgBackground2 = bitmap.open(script_folder .. "img/background2.png")

---------------------------------------------------------------------------------------------------
local function getVer()
    return ver
end

local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

local splash_start_time = 0
local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    log('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 50) then
        ImgSplash = nil
        state = STATE.INIT
    end

    return 0
end

---------------------------------------------------------------------------------------------------
local function state_INIT()
    log("PRESETS: init - start")
    preset_list[#preset_list+1] = "---"
    for fn in dir("/SCRIPTS/PRESETS/scripts") do
        preset_list[#preset_list+1] = fn
        log("PRESETS: init - found preset: [%s]", fn)
    end
    log("PRESETS: init - end")
    log("PRESETS: init - count=%d", #preset_list)
    num_of_presets = #preset_list

    state = STATE.SELECTION_INIT
    return 0
end

---------------------------------------------------------------------------------------------------
local function on_change_preset_selection(i)
    dd_preset_folder_name = preset_list[i]
    dd_preset_folder_name_idx = i
    log("Selected model-name: " .. dd_preset_folder_name)

    preset_info = m_utils.readMeta("/SCRIPTS/PRESETS/scripts/" .. dd_preset_folder_name .. "/meta.ini")
    preset_info.icon = bitmap.open("/SCRIPTS/PRESETS/scripts/" .. dd_preset_folder_name .. "/icon.png")

    log("Category: %s", preset_info["category"])
    log("preset_selection: %s", preset_info["name"])
    log("about: %s", preset_info["about"])
end

---------------------------------------------------------------------------------------------------
local function state_SELECTION_INIT()
    ctx1.label(40, 60, 60, 24, "")
    --ctx1.label(40, 60, 60, 24, "Preset:")

    ddModel = ctx1.dropDown(70, 55, 340, 35, preset_list, 1,
        function(obj)
            local i = obj.selected
            on_change_preset_selection(i)
        end
    )

    ---- Button showing About prompt
    --ctx1.button(350, 220, 120, 40, "Run",
    --    function()
    --        if dd_preset_folder_name_idx >1 then
    --            state = STATE.PRESET_OPTIONS_INIT
    --        end
    --        return
    --    end
    --)

    --on_change_preset_selection(0)
    dd_preset_folder_name = "NA"
    dd_preset_folder_name_idx = 1

    state = STATE.SELECTION
    return 0
end

---------------------------------------------------------------------------------------------------
local function state_SELECTION(event, touchState)
    if event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
    elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
        lcd.clear()
        if dd_preset_folder_name_idx >1 then
            state = STATE.PRESET_OPTIONS_INIT
            return 0
        end
    end

    if (event == EVT_VIRTUAL_NEXT_PAGE) then
        lcd.clear()
        if dd_preset_folder_name_idx >1 then
            state = STATE.PRESET_OPTIONS_INIT
            return 0
        end
    end

    m_utils.drawTitle("What Preset do you like Today...", false, true, ImgBackground)

    --lcd.drawFilledRectangle(40, 110, 400, 100, BLACK, 20)
    if preset_info["about"] ~= nil then
        -- set newlines
        local about = string.gsub(preset_info["about"], "/n", "\n")
        log("fix about: [%s] [%s]", preset_info["about"], about)
        ctx1.drawTextLines(60, 120, 300,100, about, WHITE + m_utils.FONT_6)
    end

    ctx1.run(event, touchState)

    --if preset_info.icon then
    --    lcd.drawBitmap(preset_info.icon,0, 120)
    --end

    --local txt1 = string.format("/%s/%s", preset_info["category"], preset_info["name"])
    local txt1 = string.format("Category: %s", preset_info["category"])
    local txt2 = string.format("ver: %s  author: %s", preset_info["ver"], preset_info["author"])
    lcd.drawText(10, 252, txt1, m_utils.FONT_6 + BLACK)
    lcd.drawText(300, 250, txt2, m_utils.FONT_6 + BLACK)

    return 0
end

---------------------------------------------------------------------------------------------------

local function state_PRESET_OPTIONS_INIT()
    log("state_PRESET_OPTIONS_INIT(%s)", dd_preset_folder_name)

    -- validate module exist
    local script_name = "/SCRIPTS/PRESETS/scripts/" .. dd_preset_folder_name .. "/main.lua"
    local code_chunk = loadScript(script_name, "tcd")
    if code_chunk == nil then
        error_desc = "File not found: " .. script_name
        return
    end

    preset_script_chunk = code_chunk(m_log,m_utils,m_libgui)
    if preset_script_chunk == nil then
        error_desc = "failed to load preset file:\n " .. script_name .. " \n"
        return nil
    end
    log("%s - loaded OK", dd_preset_folder_name)

    local the_ver = preset_script_chunk.getVer()
    log("the_ver: " .. the_ver)

    local err = preset_script_chunk.init()
    if err ~= nil then
        log("preset.init() returned error: %s", err)
        error_desc = err
        state = STATE.ERROR_PAGE
        return 0
    end

    log("state_PRESET_OPTIONS_INIT() - end")
    state = STATE.PRESET_OPTIONS
    return 0
end

local function state_PRESET_OPTIONS(event, touchState)
    --log("state_PRESET_OPTIONS()")

    if event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
    elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
        print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
        lcd.clear()
        if dd_preset_folder_name_idx >1 then
            state = STATE.CONFIRM_REQUEST_INIT
            return 0
        end
    end

    if (event == EVT_VIRTUAL_NEXT_PAGE)
        or
        (event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160)) then
        lcd.clear()
        state = STATE.CONFIRM_REQUEST_INIT
        return 0
    end
    --if (event == EVT_VIRTUAL_PREV) or (event == EVT_VIRTUAL_PREV_PAGE) then
    if (event == EVT_VIRTUAL_PREV_PAGE)
        or
        (event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160)) then

        lcd.clear()
        state = STATE.SELECTION
        return 0
    end

    m_utils.drawTitle("Preset: " .. preset_info["name"], true, true, ImgBackground2)

    local rc = preset_script_chunk.draw_page(event, touchState)
    if rc == m_utils.PRESET_RC.NEXT_PAGE then
        lcd.clear()
        state = STATE.CONFIRM_REQUEST_INIT
    end
    return 0
end

---------------------------------------------------------------------------------------------------

local function state_CONFIRM_REQUEST_INIT(event)
    log("state_CONFIRM_REQUEST_INIT()")

    m_utils.drawTitle("Model Updated", true, false, ImgBackground2)

    lcd.drawBitmap(ImgSummary, 300, 60)

    lcd.drawText(60, 80 , "Update the current model?", COLOR_THEME_PRIMARY1)
    lcd.drawText(60, 180, "Note: this will change the current plane settings!!", COLOR_THEME_PRIMARY1)
    lcd.drawText(60, 220, "Hold [Enter] to apply changes...", COLOR_THEME_PRIMARY1)

    if event == EVT_TOUCH_FIRST then
        log("state_ON_END() - exit")
        return 2
    end

    state = STATE.CONFIRM_REQUEST
    return 0
end

local function state_CONFIRM_REQUEST(event, touchState)
    --log("state_CONFIRM_REQUEST()")
    if (event == EVT_VIRTUAL_ENTER_LONG) then
        state = STATE.UPDATE_MODEL_INIT
    end
    if (event == EVT_VIRTUAL_PREV_PAGE)
        or
        (event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160)) then

        lcd.clear()
        state = STATE.PRESET_OPTIONS
        return 0
    end


    --state = STATE.UPDATE_MODEL_INIT
    return 0
end

---------------------------------------------------------------------------------------------------

local function state_UPDATE_MODEL_INIT()
    state = STATE.UPDATE_MODEL
    return 0
end

local function state_UPDATE_MODEL(event, touchState)
    preset_script_chunk.do_update_model()
    state = STATE.ON_END
    return 0
end

---------------------------------------------------------------------------------------------------

local function state_ON_END(event, touchState)
    log("state_ON_END()")

    m_utils.drawTitle("Model Updated", false, false, ImgBackground2)

    lcd.drawBitmap(ImgSummary, 300, 60)

    lcd.drawText(70, 90, "Model successfully updated!", COLOR_THEME_PRIMARY1)
    lcd.drawText(100, 130, "[TAP] or [RTN] to exit.", COLOR_THEME_PRIMARY1)

    if (event == EVT_TOUCH_FIRST) or (event == EVT_VIRTUAL_EXIT) then
        log("state_ON_END() - exit")
        return 2
    end

    return 0
end
---------------------------------------------------------------------------------------------------

local function state_ERROR_PAGE(event, touchState)
    m_utils.drawTitle("Error", false, false, ImgBackground2)

    lcd.drawText(40, 80, error_desc, COLOR_THEME_PRIMARY1)
    lcd.drawText(100, 200, "Hold [RTN] to exit.", COLOR_THEME_PRIMARY1)

    if event == EVT_VIRTUAL_ENTER_LONG or event == EVT_VIRTUAL_PREV_PAGE or event == EVT_VIRTUAL_EXIT then
        log("state_ERROR_PAGE() - exit")
        state = STATE.state_SELECTION
        return 0
    end
    return 0
end

---------------------------------------------------------------------------------------------------

local function init()
    lcd.drawBitmap(ImgSplash, 0, 0)

end

local function run(event, touchState)

    if state == STATE.SPLASH then
        log("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.INIT then
        log("STATE.INIT")
        return state_INIT()

    elseif state == STATE.SELECTION_INIT then
        log("STATE.SELECTION_INIT")
        return state_SELECTION_INIT(event, touchState)
    elseif state == STATE.SELECTION then
        --log("STATE.SELECTION")
        return state_SELECTION(event, touchState)

    elseif state == STATE.PRESET_OPTIONS_INIT then
        log("STATE.PRESET_OPTIONS_INIT")
        return state_PRESET_OPTIONS_INIT(event, touchState)
    elseif state == STATE.PRESET_OPTIONS then
        --log("STATE.PRESET_OPTIONS")
        return state_PRESET_OPTIONS(event, touchState)

    elseif state == STATE.CONFIRM_REQUEST_INIT then
        --log("STATE.CONFIRM_REQUEST_INIT")
        return state_CONFIRM_REQUEST_INIT(event, touchState)
    elseif state == STATE.CONFIRM_REQUEST then
        --log("STATE.CONFIRM_REQUEST")
        return state_CONFIRM_REQUEST(event, touchState)

    elseif state == STATE.UPDATE_MODEL_INIT then
        log("STATE.UPDATE_MODEL_INIT")
        return state_UPDATE_MODEL_INIT(event, touchState)
    elseif state == STATE.UPDATE_MODEL then
        log("STATE.UPDATE_MODEL")
        return state_UPDATE_MODEL(event, touchState)

    elseif state == STATE.ON_END then
        --log("STATE.ON_END")
        return state_ON_END(event, touchState)

    elseif state == STATE.ERROR_PAGE then
        --log("STATE.ERROR_PAGE")
        return state_ERROR_PAGE(event, touchState)
    end

    return 0
end


return { init = init, run = run }

local app_name = "MicroValues"

local options = {
    { "source_1"      , SOURCE  , {"1RSS", "cell","VFAS","RxBt","A1", "A2"} },
    { "source_2"      , SOURCE  , {"RQly", "1RSS"} },
    { "textColor"     , COLOR   , YELLOW },
    { "inactiveColor" , COLOR   , GREY },
    -- { "font_size", TEXT_SIZE},
    { "fontSizeValIdx", CHOICE   , 2 , {"Extra Small (6px)","Normal (8px)","Large (12px)","Extra Large (16px)","Huge (38px)"} },
    { "fontSizeKeyIdx", CHOICE   , 1 , {"Extra Small (6px)","Normal (8px)","Large (12px)","Extra Large (16px)","Huge (38px)"} },
    { "align"        , ALIGNMENT, 0},
}

local function translate(name)
    local translations = {
        source_1 = "Source 1",
        source_2 = "Source 2",
        textColor = "Text Color",
        inactiveColor = "Inactive Color",
        fontSizeValIdx = "Font Size Value",
        fontSizeKeyIdx = "Font Size Key",
        align = "Alignment"
    }
    return translations[name]
end

local function create(zone, options)
    local tool = assert(loadScript("/WIDGETS/" .. app_name .. "/app.lua", "btd"))()
    local wgt = tool.create(zone, options)
    wgt._tool = tool
    return wgt
end
local function update(wgt, options) return wgt._tool.update(wgt, options) end
local function background(wgt)      return wgt._tool.background(wgt)      end
local function refresh(wgt)         return wgt._tool.refresh(wgt)         end

return {name="Micro Values", options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=true}

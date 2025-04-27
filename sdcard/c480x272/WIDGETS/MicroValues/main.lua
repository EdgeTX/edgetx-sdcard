local app_name = "MicroValues"

local options = {
    { "source_1"      , SOURCE  , "Batt" },
    { "source_2"      , SOURCE  , "RQly" },
    { "textColor"     , COLOR   , YELLOW },
    { "inactiveColor" , COLOR   , GREY },
    -- { "font_size", TEXT_SIZE},
    { "fontSizeValIdx", CHOICE   , 2 , {"6px","8px","12px","16px","38px"} },
    { "fontSizeKeyIdx", CHOICE   , 1 , {"6px","8px","12px","16px","38px"} },
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

local tool = nil
local function create(zone, options)
    tool = assert(loadScript("/WIDGETS/" .. app_name .. "/app.lua", "tcd"))()
    return tool.create(zone, options)
end
local function update(wgt, options) return tool.update(wgt, options) end
local function background(wgt)      return tool.background(wgt) end
local function refresh(wgt)         return tool.refresh(wgt)    end

return {name="Micro Values", options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=true}

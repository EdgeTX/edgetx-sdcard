local app_name = "Value2"

local options = {
    { "Source",      SOURCE, "RQly" },
    { "TextColor",   COLOR,  COLOR_THEME_PRIMARY1 },
    { "Suffix",      STRING, "" },
    { "Show_MinMax", BOOL,   1  }
}

local function translate(name)
    local translations = {
        Source = "Source",
        TextColor = "Text Color",
        Show_MinMax="Show Min / Max"
    }
    return translations[name]
end

local tool = nil
local function create(zone, options)
    tool = assert(loadScript("/WIDGETS/" .. app_name .. "/app.lua", "btd"))()
    return tool.create(zone, options)
end
local function update(wgt, options) return tool.update(wgt, options) end
local function background(wgt)      return tool.background(wgt) end
local function refresh(wgt)         return tool.refresh(wgt)    end

return {name=app_name, options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=false}

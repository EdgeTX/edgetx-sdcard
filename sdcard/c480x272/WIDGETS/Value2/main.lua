local app_name = "Value2"

local options = {
    { "Source",      SOURCE, {"RQly", "VFR", "RSSI", "1Rss"} },
    { "TextColor",   COLOR,  YELLOW },
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

local function create(zone, options)
    local tool = assert(loadScript("/WIDGETS/" .. app_name .. "/app.lua", "btd"))()
    local wgt = tool.create(zone, options)
    wgt._tool = tool
    return wgt
end
local function update(wgt, options) return wgt._tool.update(wgt, options) end
local function background(wgt)      return wgt._tool.background(wgt)      end
local function refresh(wgt)         return wgt._tool.refresh(wgt)         end

return {name=app_name, options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=false}

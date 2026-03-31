
local app_name = "Mixers"

local options = {
    { "text_color", COLOR, COLOR_THEME_SECONDARY1 },
    { "bar_color", COLOR, COLOR_THEME_FOCUS },
    { "bar_bkg_enabled", BOOL, 1 },
    { "bar_bkg_color", COLOR, GREY },
    { "background_enabled", BOOL, 0 },
    { "background_color", COLOR, BLACK },
}
local function translate(nam)
    local translations = {
        text_color = "Text Color",
        bar_color = "Bar: Color",
        bar_bkg_enabled = "Bar Background Enabled",
        bar_bkg_color = "Bar Background Color",
        background_enabled="Background Enabled",
        background_color = "Background Color",
    }
    return translations[nam]
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

return {name=app_name, options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=true}

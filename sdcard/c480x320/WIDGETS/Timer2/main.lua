local app_name = "Timer2"

local options = {
  { "TextColor", COLOR, YELLOW },
  { "Timer", VALUE, 1, 1, 3},
  { "use_days", BOOL, 0 }   -- if greater than 24 hours: 0=still show as hours, 1=use days

}

local function translate(nam)
    local translations = {
        TextColor = "Text Color",
        Timer = "Timer",
        use_days = "Use Days",
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

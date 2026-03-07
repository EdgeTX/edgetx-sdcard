
local app_name = "BattAnalog"

local options = {
    {"sensor",          SOURCE,     {"cell","VFAS","RxBt","A1", "A2"} },
    {"batt_type",       CHOICE, 1 , {"LiPo", "LiPo-HV (high voltage)", "Li-Ion", "LifePO4"} },
    {"cbCellCount",     CHOICE, 1 , {"Auto Detection", "1 cells","2 cells","3 cells","4 cells","5 cells","6 cells","7 cells","8 cells","9 cells","10 cells", "11 cells","12 cells","13 cells","14 cells"} },
    {"cbShowVoltage",   CHOICE, 1 , {"Single Cell (average)", "Total Voltage"} },
    {"color",           COLOR , YELLOW },
    {"isTelemCellV",    BOOL  , 0 },
}

local function translate(name)
    local translations = {
        sensor = "Voltage Sensor",
        batt_type="Battery Type",
        cellCount = "Cell Count (0=auto)",
        cbCellCount = "Cell Count",
        cbShowVoltage="Show Voltage as:",
        color = "Text Color",
        isTelemCellV = "Generate Telemetry Cell",
        isTelemCellPerc = "Generate Telemetry Cell%",
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

return {name=app_name, options=options, translate=translate, create=create, update=update, refresh=refresh, background=background, useLvgl=true}

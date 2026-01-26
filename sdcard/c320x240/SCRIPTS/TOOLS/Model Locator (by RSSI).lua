---- TNS|Model Locator by RSSI|TNE

local app = assert(loadScript("/SCRIPTS/TOOLS/locator_by_rssi/app.lua", "btd"))()

return {init=app.init, run=app.run, useLvgl=true}

local toolName = "TNS|Wizard Loader|TNE"

local function init() 
end

local function run(event)    
    chdir("/SCRIPTS/WIZARD")
    return "/SCRIPTS/WIZARD/wizard.lua"
end

return {init = init, run = run}

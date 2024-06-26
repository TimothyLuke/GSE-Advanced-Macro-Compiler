local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    if GSE.isEmpty(GSEOptions.msClickRate) then
        GSEOptions.msClickRate = 250
    end
end

GSE.DebugProfile("OneOffEvents")

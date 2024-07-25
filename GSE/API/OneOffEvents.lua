local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    if GSE.isEmpty(GSEOptions.msClickRate) then
        GSEOptions.msClickRate = 250
    end

    if GSE.isEmpty(GSEOptions.Updates) then
        GSEOptions.Updates = {}
    end
    if GSE.isEmpty(GSE_C.Updates) then
        GSE_C.Updates = {}
    end
    if GSE.isEmpty(GSEOptions.Updates["3200"]) then
        GSE3Storage = nil
        GSEOptions.shownew = true
        GSEOptions.Updates["3200"] = true
    end

    if GSE.isEmpty(GSE_C.Updates["3201"]) then
        local char = UnitFullName("player")
        local realm = GetRealmName()
        if GSE_C and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][char .. "-" .. realm] then
            local tab = GSE_C["KeyBindings"][char .. "-" .. realm]
            GSE_C["KeyBindings"][char .. "-" .. realm] = nil
            GSE_C["KeyBindings"] = tab
        end
        GSE_C.Updates["3201"] = true
    end
end

GSE.DebugProfile("OneOffEvents")

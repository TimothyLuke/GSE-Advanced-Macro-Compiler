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
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE.isEmpty(GSE_C.Updates) then
        GSE_C.Updates = {}
    end
    if GSE.isEmpty(GSEOptions.Updates["3200"]) then
        GSE3Storage = nil
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
    if GSE.isEmpty(GSE_C.Updates["3202"]) then
        if
            GSE_C.KeyBindings and GSE_C.KeyBindings["1"] and GSE_C.KeyBindings["1"].LoadOuts and
                GSE_C.KeyBindings["1"].LoadOuts.All
         then
            GSE_C.KeyBindings["1"].LoadOuts.All = nil
        elseif
            GSE_C.KeyBindings and GSE_C.KeyBindings["2"] and GSE_C.KeyBindings["2"].LoadOuts and
                GSE_C.KeyBindings["2"].LoadOuts.All
         then
            GSE_C.KeyBindings["3"].LoadOuts.All = nil
        elseif
            GSE_C.KeyBindings and GSE_C.KeyBindings["3"] and GSE_C.KeyBindings["3"].LoadOuts and
                GSE_C.KeyBindings["3"].LoadOuts.All
         then
            GSE_C.KeyBindings["3"].LoadOuts.All = nil
        elseif
            GSE_C.KeyBindings and GSE_C.KeyBindings["4"] and GSE_C.KeyBindings["4"].LoadOuts and
                GSE_C.KeyBindings["4"].LoadOuts.All
         then
            GSE_C.KeyBindings["4"].LoadOuts.All = nil
        end
        GSE_C.Updates["3202"] = true
    end
    if GSE.isEmpty(GSE_C.Updates["3212"]) then
        if GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["Loadouts"] then
            GSE_C["ActionBarBinds"]["LoadOuts"] = GSE.CloneSequence(GSE_C["ActionBarBinds"]["Loadouts"])
            GSE_C["ActionBarBinds"]["Loadouts"] = nil
        end
        GSE_C.Updates["3212"] = true
    end
    if GSE.isEmpty(GSEOptions.Updates["3218"]) then
        GSEOptions.shownew = true
        GSEOptions.Updates["3218"] = true
    end
    if GSE.isEmpty(GSE_C.Updates["3218"]) then
        for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
            for i, j in pairs(v) do
                GSE_C["ActionBarBinds"]["Specialisations"][k][i] = {["Sequence"] = j, ["Bind"] = i}
            end
        end
        for k, v in pairs(GSE_C["ActionBarBinds"]["LoadOuts"]) do
            for i, j in pairs(v) do
                for m, l in pairs(j) do
                    GSE_C["ActionBarBinds"]["LoadOuts"][k][i][m] = {["Sequence"] = l, ["Bind"] = m}
                end
            end
        end
        GSE_C.Updates["3218"] = true
    end
end

GSE.DebugProfile("OneOffEvents")

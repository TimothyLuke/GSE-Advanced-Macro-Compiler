local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

if not GSE_C then
    GSE_C = {}
end
if not GSE_C.Updates then
    GSE_C.Updates = {}
end

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
    if GSE.isEmpty(GSEOptions.Updates["3225"]) then
        GSEOptions.shownew = true
        GSEOptions.Updates["3225"] = true
    end
    if GSE.isEmpty(GSEOptions.Updates["3225-d"]) then
        GSEOptions.Multiclick = true
        GSEOptions.Updates["3225-d"] = true
    end
    -- One-off: set the actionBarOverridePopup default based on what the user already has configured.
    -- Keybind-only users default to disabled (they don't use actionbar overrides).
    -- New users (nothing configured) and actionbar override users default to enabled.
    if GSE.isEmpty(GSEOptions.Updates["actionBarOverridePopupDefault"]) then
        local hasOverrides = false
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
            for _, specData in pairs(GSE_C["ActionBarBinds"]["Specialisations"] or {}) do
                if not GSE.isEmpty(specData) then hasOverrides = true; break end
            end
            if not hasOverrides then
                for _, specData in pairs(GSE_C["ActionBarBinds"]["LoadOuts"] or {}) do
                    for _, loadoutData in pairs(specData) do
                        if not GSE.isEmpty(loadoutData) then hasOverrides = true; break end
                    end
                    if hasOverrides then break end
                end
            end
        end
        local hasKeybinds = false
        if not GSE.isEmpty(GSE_C["KeyBindings"]) then
            for specKey, specData in pairs(GSE_C["KeyBindings"]) do
                if specKey ~= "LoadOuts" and not GSE.isEmpty(specData) then
                    hasKeybinds = true; break
                end
            end
        end
        -- Keybind-only existing users get popup disabled; everyone else gets it enabled.
        GSEOptions.actionBarOverridePopup = not (hasKeybinds and not hasOverrides)
        GSEOptions.Updates["actionBarOverridePopupDefault"] = true
    end
    if GSE.isEmpty(GSE_C.Updates["3218"]) then
        if GSE_C["ActionBarBinds"] then
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
        end
        GSE_C.Updates["3218"] = true
    end
end

if GSE.isEmpty(GSE_C.Updates["3300"]) then
    GSEOptions.shownew = true
    GSE_C.Updates["3300"] = true
end
if GSE.isEmpty(GSEOptions.Updates["3301"]) then
    GSEOptions.shownew = true
    GSEOptions.Updates["3301"] = true
end
if GSE.isEmpty(GSEOptions.Updates["3303"]) then
    GSEOptions.shownew = true
    GSEOptions.Updates["3303"] = true
end
GSE.DebugProfile("OneOffEvents")

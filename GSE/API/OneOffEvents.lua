local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    GSE.Update3023()
    if GSE.isEmpty(GSEOptions.msClickRate) then
        GSEOptions.msClickRate = 250
    end
end

function GSE.Update3023()
    if GSE.isEmpty(GSEOptions.Update3023) then
        GSEOptions.UnfoundSpells = nil
        GSEOptions.UnfoundSpellIDS = nil
        GSEOptions.ActiveSequenceVersions = nil
        if GSE.isEmpty(GSESpellCache) then
            GSESpellCache = {}
        end
        if GSE.isEmpty(GSESpellCache["enUS"]) then
            GSESpellCache["enUS"] = {}
        end
        if GSE.isEmpty(GSESpellCache[GetLocale()]) then
            GSESpellCache[GetLocale()] = {}
        end
    end
    GSEOptions.Update3023 = true
end

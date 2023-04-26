local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    GSE.Update3023()
    GSE.Update3111()
    GSE.Update3117()
    GSE.Update3131()
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

function GSE.Update3111()
    if GSE.isEmpty(GSEOptions.Update3111) then
        if GSE.isEmpty(GSE3Storage[13]) then
            GSE3Storage[13] = {}
        end
    end
    GSEOptions.Update3111 = true
end
function GSE.Update3117()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE.isEmpty(GSE_C.Update3117) then
        GSE.Print(
            L[
                "Dragonflight has changed how the /click command operates.  As a result all your macro stubs (found in /macro) have been updated to match the value of the CVar ActionButtonUseKeyDown.  This is a one off configuration change that needs to be done for each character.  You can change this configuration in GSE's Options."
            ],
            "GSE Configuration"
        )
        GSE.setActionButtonUseKeyDown()
    end
    GSE_C.Update3117 = true
end

function GSE.Update3131()
    if GSE.isEmpty(GSE.Update3131) then
        GSEOptions.DebugModules[Statics.DebugModules["Startup"]] = false
    end
    GSEOptions.Update3131 = true
end

GSE.DebugProfile("OneOffEvents")

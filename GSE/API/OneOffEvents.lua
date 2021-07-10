local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    GSE.Update3000()
    GSE.Update3023()
    if GSE.isEmpty(GSEOptions.msClickRate) then
        GSEOptions.msClickRate = 250
    end
end

function GSE.Update3000()
    if GSE.isEmpty(GSEOptions.Update3000) then
        GSE.UpdateGSE2LibrarytoGSE3()
    end
    GSEOptions.Update3000 = true
end

function GSE.UpdateGSE2LibrarytoGSE3()
    if GSE.isEmpty(GSE3Storage) then
        GSE3Storage = {}
        for iind=0, 12 do
            GSE3Storage[iind] = {}
        end
    end
    if not GSE.isEmpty(GSEStorage) then
        for k,v in ipairs(GSEStorage) do
            if v then
                for i,j in pairs(v) do
                    local localsuccess, uncompressedVersion = GSE.DecodeMessage(j)
                    --print(GSE.Dump(uncompressedVersion))
                    local decoded = GSE.ConvertGSE2(uncompressedVersion[2], i)
                    decoded.MetaData.GSEVersion = "3.0.0"
                    decoded.MetaData.EnforceCompatability = true
                    local encoded = GSE.EncodeMessage({i, decoded})
                    GSE3Storage[k][i] = encoded
                    GSE.Print("Storage updated " .. k .. " " .. i)
                end
            end
        end
    end
    GSE.LoadStorage(GSE.Library)
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

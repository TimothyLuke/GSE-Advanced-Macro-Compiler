local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    GSE.Update3000()
end

function GSE.Update3000()
    if GSE.isEmpty(GSEOptions.Update3000) then
        if GSE.isEmpty(GSE3Storage) then
            GSE3Storage = {}
            for iind=0, 12 do
                GSE3Storage[iind] = {}
            end
        end
        for k,v in ipairs(GSEStorage) do
            for i,j in pairs(v) do
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(j)
                print(GSE.Dump(uncompressedVersion))
                local decoded = GSE.ConvertGSE2(uncompressedVersion[2], i)
                local encoded = GSE.EncodeMessage({i, decoded})
                GSE3Storage[k][i] = encoded
                GSE.Print("Storage updated " .. k .. " " .. i)
            end
        end
        GSE.LoadStorage(GSE.Library)
    end
    GSEOptions.Update3000 = true
end
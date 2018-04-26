local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
  GSE.UpdateFrom735to801()
end

function GSE.UpdateFrom735to801()
  if GSE.isEmpty(GSEOptions.Updated801) then

     -- Update Sequence Names to UPPERCASE
       local tempLibary = {}
       for k,v in ipairs(GSELibrary) do
         tempLibary[k] = {}
         for i,j in pairs(v) do
           --i = string.upper(i)
           tempLibary[k][string.upper(i)] = j
         end
       end
       GSELibrary = tempLibrary
     --end
     GSE.CleanOrphanSequences()
     GSE.Print(L["All macros are now stored as upper case names.  You may need to re-add your old macros to your action bars."])
  end
  GSEOptions.Updated801 = true
end

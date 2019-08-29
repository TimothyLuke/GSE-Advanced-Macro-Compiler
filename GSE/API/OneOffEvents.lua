local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
  GSE.UpdateFrom735to801()
  GSE.Update2305()
  GSE.Update2410()
  GSE.Update2411()
  GSE.Update2415()
end

function GSE.UpdateFrom735to801()
  if GSE.isEmpty(GSEOptions.Updated801) then
     GSEOptions.UseVerboseExportFormat = false
     -- Update Sequence Names to UPPERCASE
     --if next(GSELibrary) == nil then
       for k,v in ipairs(GSELibrary) do
         for i,j in pairs(v) do
           --i = string.upper(i)
           GSELibrary[k][string.upper(i)] = j
           if (v == GSE.GetCurrentClassID() or v == 0) then
             GSE.CheckMacroCreated(string.upper(i), true)
           end
           GSELibrary[k][i] = nil
         end
       end
     --end
     GSE.CleanOrphanSequences()
     GSE.Print(L["All macros are now stored as upper case names.  You may need to re-add your old macros to your action bars."])
     GSE.ReloadSequences()
  end
  GSEOptions.Updated801 = true
end

function GSE.Update2305()
  if GSE.isEmpty(GSEOptions.Update2305) then
     GSEOptions.UseWLMExportFormat = true
  end
  GSEOptions.Update2305 = true
end

function GSE.Update2410()
  if GSE.isEmpty(GSEOptions.Update2410) then
    GSEOptions.PromptSample = true
  end
  GSEOptions.Update2410 = true
end

function GSE.Update2411()
  if GSE.isEmpty(GSEOptions.Update2411) then
      GSEOptions.showMiniMap = {
        hide = true
      }
  end
  GSEOptions.Update2411 = true
end


function GSE.Update2415()
  if GSE.isEmpty(GSEOptions.Update2415) then
      GSE_C = {}
  end
  GSEOptions.Update2415 = true
end
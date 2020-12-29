local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

function GSE.PerformOneOffEvents()
    GSE.UpdateFrom735to801()
    GSE.Update2305()
    GSE.Update2410()
    GSE.Update2411()
    GSE.Update2415()
    -- GSE.Update2500()
    GSE.Update2601()
    GSE.Update2633()
    GSE.Update2638()
end

function GSE.UpdateFrom735to801()
    if GSE.isEmpty(GSEOptions.Updated801) then
        GSEOptions.UseVerboseExportFormat = false
        -- Update Sequence Names to UPPERCASE
        -- if next(GSELibrary) == nil then
        for k, v in ipairs(GSE.Library) do
            for i, j in pairs(v) do
                -- i = string.upper(i)
                GSE.Library[k][i] = nil
                GSEStorage[k][i] = nil
                GSEStorage[k][string.upper(i)] = GSE.EncodeMessage({string.upper(i), j})
                GSE.Library[k][string.upper(i)] = j
                if (v == GSE.GetCurrentClassID() or v == 0) then
                    GSE.CheckMacroCreated(string.upper(i), true)
                end
            end
        end
        -- end
        GSE.CleanOrphanSequences()
        GSE.Print(
            L["All macros are now stored as upper case names.  You may need to re-add your old macros to your action bars."])
        GSE.ReloadSequences()
    end
    GSEOptions.Updated801 = true
end

function GSE.Update2305()
    if GSE.isEmpty(GSEOptions.Update2305) then
        GSEOptions.UseWLMExportFormat = true
        if GSE.isEmpty(GSEOptions.useExternalMSTimings) then
            GSEOptions.useExternalMSTimings = true
        end
        if GSE.isEmpty(GSEOptions.msClickRate) then
            GSEOptions.msClickRate = 100
        end
    end
    GSEOptions.Update2305 = true
end

-- function GSE.Update2500()
--   if GSE.isEmpty(GSEOptions.Update2500) then
--      GSELibrary[0]['pause'] = {
--       Author="TimothyLuke",
--       SpecID=0,
--       Talents = "",
--       Help = [[This macro does nothing.  It is used by GSE internally.]],
--       Default=1,
--       MacroVersions = {
--         [1] = {
--           StepFunction = "Sequential",
--           KeyPress={
--           },
--           PreMacro={
--           },
--           PostMacro={
--           },
--           KeyRelease={
--           }
--         }
--       }
--     }
--   end
--   GSEOptions.Update2500 = true
-- end

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

function GSE.Update2601()
    if GSE.isEmpty(GSEOptions.Update2601) then
        GSE.ImportLegacyStorage(GSELibrary)
    end
    GSEOptions.editorHeight = 700
    GSEOptions.editorWidth = 500
    GSEOptions.Update2601 = true
end

function GSE.Update2633()
    if GSE.isEmpty(GSEOptions.Update2633) then
        GSEOptions.showCurrentSpells = true
    end
    GSEOptions.Update2633 = true
end

function GSE.Update2638()
    if GSE.isEmpty(GSEOptions.Update2638) then
        for k,v in ipairs(GSE.Library) do
            for i,j in pairs(v) do
                j.LastUpdated = GSE.GetTimestamp()
                GSE.PerformMergeAction("REPLACE", k, i, j)
            end
        end
    end
    GSEOptions.Update2638 = true
end

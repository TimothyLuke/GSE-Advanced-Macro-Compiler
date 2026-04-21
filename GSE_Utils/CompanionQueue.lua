local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

-- Process GSECompanionQueue after login.
-- Install/reinstall entries are decoded and fed into the import dialog (or auto-imported).
-- Delete entries are shown in a confirmation dialog, then enqueued to the OOC queue.
-- Variable/macro entries are decoded and imported via their respective handlers.

local companionQueueProcessed = false

local function ProcessCompanionQueue()
    if companionQueueProcessed then return end
    if GSE.isEmpty(GSECompanionQueue) then return end
    companionQueueProcessed = true

    local seqInstalls = {}
    local varInstalls = {}
    local macInstalls = {}
    local deletes = {}
    local idUpdates = {}

    for _, entry in ipairs(GSECompanionQueue) do
        local ct = entry.contentType or "sequence"

        if entry.action == "delete" then
            table.insert(deletes, entry)
        elseif entry.action == "setPlatformID" then
            table.insert(idUpdates, entry)
        elseif entry.action == "install" or entry.action == "reinstall" then
            if ct == "variable" and entry.encoded then
                table.insert(varInstalls, entry)
            elseif ct == "macro" and entry.encoded then
                table.insert(macInstalls, entry)
            elseif entry.sequences then
                -- Sequences go into GSE.IncomingQueue for the import dialog
                if not GSE.IncomingQueue then
                    GSE.IncomingQueue = {}
                end
                table.insert(GSE.IncomingQueue, {
                    name      = entry.name or "",
                    author    = entry.author or "",
                    source    = entry.source or "gsecompanion",
                    checksum  = entry.checksum or "",
                    sequences = entry.sequences,
                })
                table.insert(seqInstalls, entry)
            end
        end
    end

    -- Platform ID updates go straight into the OOC queue — no confirmation needed
    if #idUpdates > 0 then
        for _, entry in ipairs(idUpdates) do
            GSE.EnqueueOOC({
                action       = "CompanionSetPlatformID",
                sequencename = entry.name,
                classid      = tonumber(entry.classid) or 0,
                platformid   = entry.platformid,
            })
        end
        GSE.ToggleOOCQueue()
    end

    -- Handle variable installs — decode and import via OOC
    if #varInstalls > 0 then
        for _, entry in ipairs(varInstalls) do
            GSE.EnqueueOOC({
                action  = "CompanionImportEncoded",
                encoded = entry.encoded,
            })
        end
        GSE.ToggleOOCQueue()
        GSE.Print(
            "|cff00ccffGSE Companion:|r " ..
            #varInstalls .. " variable(s) queued for import."
        )
    end

    -- Handle macro installs — decode and import via OOC
    if #macInstalls > 0 then
        for _, entry in ipairs(macInstalls) do
            GSE.EnqueueOOC({
                action  = "CompanionImportEncoded",
                encoded = entry.encoded,
            })
        end
        GSE.ToggleOOCQueue()
        GSE.Print(
            "|cff00ccffGSE Companion:|r " ..
            #macInstalls .. " macro(s) queued for import."
        )
    end

    -- Handle sequence installs/reinstalls
    if #seqInstalls > 0 then
        if GSEOptions.CompanionAutoAccept then
            -- Auto-accept: decode and import each queued sequence directly via OOC
            C_Timer.After(1, function()
                for _, item in ipairs(GSE.IncomingQueue or {}) do
                    for _, encoded in pairs(item.sequences or {}) do
                        local ok, collection = GSE.DecodeMessage(encoded)
                        if ok and collection and collection.payload and collection.payload.Sequences then
                            for name, seq in pairs(collection.payload.Sequences) do
                                GSE.AddSequenceToCollection(name, seq)
                            end
                        end
                    end
                end
                GSE.IncomingQueue = {}
                GSE.Print(
                    "|cff00ccffGSE Companion:|r Auto-imported " ..
                    #seqInstalls .. " sequence update(s)."
                )
            end)
        elseif GSE.ShowIncomingQueue then
            C_Timer.After(1, function()
                GSE.Print(
                    "|cff00ccffGSE Companion:|r " ..
                    #seqInstalls ..
                    " update(s) queued for import. " ..
                    "Open the import dialog with " ..
                    GSEOptions.CommandColour .. "/gse import|r " ..
                    "or click the Import button in the GSE menu."
                )
                GSE.ShowIncomingQueue()
            end)
        end
    end

    -- Handle deletes with a confirmation dialog (always requires confirmation)
    local seqDeletes = {}
    local varDeletes = {}
    local macDeletes = {}
    for _, d in ipairs(deletes) do
        local ct = d.contentType or "sequence"
        if ct == "variable" then
            table.insert(varDeletes, d)
        elseif ct == "macro" then
            table.insert(macDeletes, d)
        else
            table.insert(seqDeletes, d)
        end
    end

    if #deletes > 0 then
        C_Timer.After(#seqInstalls > 0 and 2 or 1, function()
            local lines = {}
            for _, d in ipairs(seqDeletes) do
                table.insert(lines, (d.name or "?") .. " (sequence)")
            end
            for _, d in ipairs(varDeletes) do
                table.insert(lines, (d.name or "?") .. " (variable)")
            end
            for _, d in ipairs(macDeletes) do
                table.insert(lines, (d.name or "?") .. " (macro)")
            end
            StaticPopupDialogs["GSE_COMPANION_DELETE_CONFIRM"] = {
                text = "|cff00ccffGSE Companion|r wants to delete " ..
                       #deletes .. " item(s):\n\n|cFFFFFF00" ..
                       table.concat(lines, ", ") ..
                       "|r\n\nProceed?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    -- Delete sequences
                    for _, d in ipairs(seqDeletes) do
                        local classid = tonumber(d.classid) or 0
                        if classid == 0 then
                            for cid = 0, 13 do
                                if not GSE.isEmpty(GSESequences[cid]) and GSESequences[cid][d.name] then
                                    classid = cid
                                    break
                                end
                            end
                        end
                        if classid > 0 or (GSESequences[0] and GSESequences[0][d.name]) then
                            GSE.EnqueueOOC({
                                action       = "CompanionDelete",
                                sequencename = d.name,
                                classid      = classid,
                            })
                        end
                    end
                    -- Delete variables
                    for _, d in ipairs(varDeletes) do
                        GSE.EnqueueOOC({
                            action       = "CompanionDeleteVariable",
                            variablename = d.name,
                        })
                    end
                    -- Delete macros
                    for _, d in ipairs(macDeletes) do
                        GSE.EnqueueOOC({
                            action    = "CompanionDeleteMacro",
                            macroname = d.name,
                        })
                    end
                    GSE.ToggleOOCQueue()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("GSE_COMPANION_DELETE_CONFIRM")
        end)
    end

    -- Clear the queue after processing
    GSECompanionQueue = {}
end

-- Register Companion actions in the OOC queue processor
local origProcessOOCQueue = GSE.ProcessOOCQueue
if origProcessOOCQueue then
    function GSE:ProcessOOCQueue()
        local queue = GSE.OOCQueue
        local kept = {}
        for _, v in ipairs(queue) do
            if v.action == "CompanionDelete" and not InCombatLockdown() then
                GSE.DeleteSequence(v.classid, v.sequencename)
                GSE.Print("|cff00ccffGSE Companion:|r Deleted sequence |cFFFFFF00" .. v.sequencename .. "|r")

            elseif v.action == "CompanionDeleteVariable" and not InCombatLockdown() then
                if GSEVariables and GSEVariables[v.variablename] then
                    GSEVariables[v.variablename] = nil
                    if GSE.V then GSE.V[v.variablename] = nil end
                    GSE.UnregisterVariableEvents(v.variablename)
                    GSE.Print("|cff00ccffGSE Companion:|r Deleted variable |cFFFFFF00" .. v.variablename .. "|r")
                end

            elseif v.action == "CompanionDeleteMacro" and not InCombatLockdown() then
                -- Remove from GSEMacros and delete the WoW macro stub
                if GSEMacros and GSEMacros[v.macroname] then
                    GSEMacros[v.macroname] = nil
                end
                local slot = GetMacroIndexByName(v.macroname)
                if slot and slot > 0 then
                    DeleteMacro(slot)
                end
                GSE.Print("|cff00ccffGSE Companion:|r Deleted macro |cFFFFFF00" .. v.macroname .. "|r")

            elseif v.action == "CompanionSetPlatformID" and not InCombatLockdown() then
                local classid = v.classid
                local name = v.sequencename
                local platformid = v.platformid
                if classid == 0 then
                    for cid = 0, 13 do
                        if not GSE.isEmpty(GSESequences[cid]) and GSESequences[cid][name] then
                            classid = cid
                            break
                        end
                    end
                end
                local seq = GSESequences[classid] and GSESequences[classid][name]
                if seq then
                    if not seq.MetaData then seq.MetaData = {} end
                    seq.MetaData.PlatformID = platformid
                    if GSE.Library[classid] and GSE.Library[classid][name] then
                        if not GSE.Library[classid][name].MetaData then
                            GSE.Library[classid][name].MetaData = {}
                        end
                        GSE.Library[classid][name].MetaData.PlatformID = platformid
                    end
                    GSE.Print("|cff00ccffGSE Companion:|r Linked |cFFFFFF00" .. name .. "|r to platform ID " .. tostring(platformid))
                end

            elseif v.action == "CompanionImportEncoded" and not InCombatLockdown() then
                -- Decode a !GSE3! blob and import via the standard handler
                -- This handles both variables (objectType=VARIABLE) and macros (objectType=MACRO)
                local ok, decoded = GSE.DecodeMessage(v.encoded)
                if ok and decoded then
                    if decoded.objectType == "VARIABLE" then
                        decoded.objectType = nil
                        local varName = decoded.name
                        decoded.name = nil
                        if varName then
                            GSE.UpdateVariable(decoded, varName)
                            GSE.Print("|cff00ccffGSE Companion:|r Imported variable |cFFFFFF00" .. varName .. "|r")
                        end
                    elseif decoded.objectType == "MACRO" then
                        decoded.objectType = nil
                        GSE.ImportMacro(decoded)
                        GSE.Print("|cff00ccffGSE Companion:|r Imported macro |cFFFFFF00" .. (decoded.name or "?") .. "|r")
                    end
                end
            else
                table.insert(kept, v)
            end
        end
        GSE.OOCQueue = kept
        origProcessOOCQueue(self)
    end
end

-- Trigger after PLAYER_ENTERING_WORLD + out of combat
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            C_Timer.After(3, ProcessCompanionQueue)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        C_Timer.After(1, ProcessCompanionQueue)
    end
end)

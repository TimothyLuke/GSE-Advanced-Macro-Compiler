local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

-- Process GSECompanionQueue after login.
-- Install/reinstall entries (sequence, variable, macro) are all funneled through
-- GSE.IncomingQueue and presented in the import dialog. The ONLY action that
-- auto-applies without confirmation is setPlatformID (a bookkeeping update).
-- Delete entries are shown in a confirmation dialog, then enqueued to the OOC queue.
--
-- Queue dedup: if the Companion queued multiple updates for the same item
-- (action+contentType+name) before the in-game client processed any of them,
-- only the latest entry wins.

local companionQueueProcessed = false

-- Build an identity key for dedup. Entries targeting the same item with the
-- same action collapse down to the most recent one.
local function queueIdentityKey(e)
    if not e then return nil end
    local action = e.action or ""
    local ct = e.contentType or "sequence"
    local name = e.name or ""
    if name == "" then return nil end
    return action .. ":" .. ct .. ":" .. name
end

local function dedupCompanionQueue(queue)
    if not queue or #queue < 2 then return queue end
    local lastIndex = {}
    for i, e in ipairs(queue) do
        local k = queueIdentityKey(e)
        if k then lastIndex[k] = i end
    end
    local deduped = {}
    local dropped = 0
    for i, e in ipairs(queue) do
        local k = queueIdentityKey(e)
        if not k or lastIndex[k] == i then
            table.insert(deduped, e)
        else
            dropped = dropped + 1
        end
    end
    if dropped > 0 then
        GSE.Print(
            "|cff00ccffGSE Companion:|r Collapsed " .. dropped ..
            " superseded queue entr" .. (dropped == 1 and "y" or "ies") .. "."
        )
    end
    return deduped
end

-- Wrap a decoded variable or macro object into a synthetic COLLECTION payload
-- so it flows through the same import-dialog path as sequences. Sets
-- objectType + name so the dialog's re-encode + re-decode cycle routes to
-- the right OOC handler on the inner recursion.
local function wrapStandaloneAsCollection(decoded, contentType, name)
    if type(decoded) ~= "table" then return nil end
    local payload = {
        Sequences    = {},
        Variables    = {},
        Macros       = {},
        ElementCount = 1,
    }
    if contentType == "variable" or contentType == "gseVariable" then
        decoded.objectType = "VARIABLE"
        if not decoded.name then decoded.name = name end
        payload.Variables[name] = decoded
    elseif contentType == "macro" or contentType == "gseMacro" then
        decoded.objectType = "MACRO"
        if not decoded.name then decoded.name = name end
        payload.Macros[name] = decoded
    else
        return nil
    end
    return GSE.EncodeMessage({ type = "COLLECTION", payload = payload })
end

local function ProcessCompanionQueue()
    if companionQueueProcessed then return end
    companionQueueProcessed = true

    -- Purge any deprecated CompanionImportEncoded OOC entries left over from
    -- older addon versions that auto-applied variables/macros. Those now flow
    -- through the import dialog; stale queued entries would otherwise re-run
    -- the old auto-import on every login.
    if type(GSE.OOCQueue) == "table" and #GSE.OOCQueue > 0 then
        local kept, purged = {}, 0
        for _, v in ipairs(GSE.OOCQueue) do
            if type(v) == "table" and v.action == "CompanionImportEncoded" then
                purged = purged + 1
            else
                table.insert(kept, v)
            end
        end
        if purged > 0 then
            GSE.OOCQueue = kept
            GSE.Print(
                "|cff00ccffGSE Companion:|r Cleared " .. purged ..
                " stale auto-import entr" .. (purged == 1 and "y" or "ies") ..
                " (legacy variable/macro path)."
            )
        end
    end

    if GSE.isEmpty(GSECompanionQueue) then return end

    GSECompanionQueue = dedupCompanionQueue(GSECompanionQueue)

    local installs = {}
    local deletes = {}
    local idUpdates = {}

    for _, entry in ipairs(GSECompanionQueue) do
        local ct = entry.contentType or "sequence"

        if entry.action == "delete" then
            table.insert(deletes, entry)
        elseif entry.action == "setPlatformID" then
            -- The only action that auto-applies (no dialog): bookkeeping only.
            table.insert(idUpdates, entry)
        elseif entry.action == "install" or entry.action == "reinstall" then
            -- New Companion builds supply `sequences` (a COLLECTION blob keyed
            -- by title) for ALL content types. Older builds still ship standalone
            -- `encoded` variable/macro blobs — wrap those into a COLLECTION here
            -- so everything flows through the same import-dialog path.
            local sequencesField = nil
            if entry.sequences then
                sequencesField = entry.sequences
            elseif entry.encoded and entry.name then
                local ok, decoded = GSE.DecodeMessage(entry.encoded)
                if ok and decoded then
                    local wrapped = wrapStandaloneAsCollection(decoded, ct, entry.name)
                    if wrapped then sequencesField = { [entry.name] = wrapped } end
                end
            end

            if sequencesField then
                if not GSE.IncomingQueue then GSE.IncomingQueue = {} end
                table.insert(GSE.IncomingQueue, {
                    _id       = entry._id,
                    name      = entry.name or "",
                    author    = entry.author or "",
                    source    = entry.source or "gsecompanion",
                    checksum  = entry.checksum or "",
                    sequences = sequencesField,
                })
                table.insert(installs, entry)
            end
        end
    end

    -- Collapse pre-existing duplicates already sitting in GSE.IncomingQueue
    -- (e.g. from a previous session whose imports didn't complete). Keep the
    -- latest entry per sequences-key identity.
    if GSE.IncomingQueue and #GSE.IncomingQueue > 1 then
        local lastIdx = {}
        for i, item in ipairs(GSE.IncomingQueue) do
            for k, _ in pairs(item.sequences or {}) do
                lastIdx[k] = i
            end
        end
        local kept = {}
        local droppedStale = 0
        for i, item in ipairs(GSE.IncomingQueue) do
            local keep = false
            for k, _ in pairs(item.sequences or {}) do
                if lastIdx[k] == i then keep = true break end
            end
            if keep then
                table.insert(kept, item)
            else
                droppedStale = droppedStale + 1
            end
        end
        if droppedStale > 0 then
            GSE.Print(
                "|cff00ccffGSE Companion:|r Dropped " .. droppedStale ..
                " superseded pending update(s)."
            )
        end
        GSE.IncomingQueue = kept
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

    -- Handle installs (sequences, variables, macros) uniformly via the dialog
    if #installs > 0 then
        if GSEOptions.CompanionAutoAccept then
            -- Auto-accept: decode each queued COLLECTION and import its
            -- Sequences / Variables / Macros directly.
            C_Timer.After(1, function()
                local imported = 0
                for _, item in ipairs(GSE.IncomingQueue or {}) do
                    for _, encoded in pairs(item.sequences or {}) do
                        local ok, collection = GSE.DecodeMessage(encoded)
                        if ok and collection and collection.type == "COLLECTION" and collection.payload then
                            local p = collection.payload
                            for name, seq in pairs(p.Sequences or {}) do
                                GSE.AddSequenceToCollection(name, seq)
                                imported = imported + 1
                            end
                            for name, varData in pairs(p.Variables or {}) do
                                if type(varData) == "table" then
                                    varData.objectType = nil
                                    GSE.UpdateVariable(varData, name)
                                    imported = imported + 1
                                end
                            end
                            for name, macData in pairs(p.Macros or {}) do
                                if type(macData) == "table" then
                                    macData.objectType = nil
                                    if not macData.name then macData.name = name end
                                    GSE.ImportMacro(macData)
                                    imported = imported + 1
                                end
                            end
                        end
                    end
                end
                if GSE.CompanionMarkImported then
                    for _, item in ipairs(GSE.IncomingQueue or {}) do
                        GSE.CompanionMarkImported(item)
                    end
                end
                GSE.IncomingQueue = {}
                GSE.Print(
                    "|cff00ccffGSE Companion:|r Auto-imported " ..
                    imported .. " update(s)."
                )
            end)
        elseif GSE.ShowIncomingQueue then
            C_Timer.After(1, function()
                GSE.Print(
                    "|cff00ccffGSE Companion:|r " ..
                    #installs ..
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

            elseif v.action == "CompanionImportEncoded" then
                -- DEPRECATED: variable/macro installs now flow through the
                -- import dialog like sequences. Silently drop any stale OOC
                -- entries left over from previous versions that auto-applied
                -- these without user confirmation.
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

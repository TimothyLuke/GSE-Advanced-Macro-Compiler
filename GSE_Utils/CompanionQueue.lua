local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

-- Process GSECompanionQueue after login.
-- Install/reinstall entries are decoded and fed into the import dialog.
-- Delete entries are shown in a confirmation dialog, then enqueued to the OOC queue.

local companionQueueProcessed = false

local function ProcessCompanionQueue()
    if companionQueueProcessed then return end
    if GSE.isEmpty(GSECompanionQueue) then return end
    companionQueueProcessed = true

    local installs = {}
    local deletes = {}
    local idUpdates = {}

    for _, entry in ipairs(GSECompanionQueue) do
        if entry.action == "delete" then
            table.insert(deletes, entry)
        elseif entry.action == "setPlatformID" then
            table.insert(idUpdates, entry)
        elseif entry.action == "install" or entry.action == "reinstall" then
            -- These have encoded sequences — feed them into GSEIncomingQueue
            -- so the existing import dialog can handle them
            if entry.sequences then
                if GSE.isEmpty(GSEIncomingQueue) then
                    GSEIncomingQueue = {}
                end
                table.insert(GSEIncomingQueue, {
                    name      = entry.name or "",
                    author    = entry.author or "",
                    source    = entry.source or "gsecompanion",
                    checksum  = entry.checksum or "",
                    sequences = entry.sequences,
                })
                table.insert(installs, entry)
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

    -- Handle installs/reinstalls
    if #installs > 0 then
        if GSEOptions.CompanionAutoAccept then
            -- Auto-accept: decode and import each queued sequence directly via OOC
            C_Timer.After(1, function()
                for _, item in ipairs(GSEIncomingQueue or {}) do
                    for seqName, encoded in pairs(item.sequences or {}) do
                        local ok, collection = GSE.DecodeMessage(encoded)
                        if ok and collection and collection.payload and collection.payload.Sequences then
                            for name, seq in pairs(collection.payload.Sequences) do
                                GSE.AddSequenceToCollection(name, seq)
                            end
                        end
                    end
                end
                GSEIncomingQueue = {}
                GSE.Print(
                    "|cff00ccffGSE Companion:|r Auto-imported " ..
                    #installs .. " update(s)."
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
    if #deletes > 0 then
        C_Timer.After(#installs > 0 and 2 or 1, function()
            local names = {}
            for _, d in ipairs(deletes) do
                table.insert(names, d.name or "?")
            end
            StaticPopupDialogs["GSE_COMPANION_DELETE_CONFIRM"] = {
                text = "|cff00ccffGSE Companion|r wants to delete " ..
                       #deletes .. " sequence(s):\n\n|cFFFFFF00" ..
                       table.concat(names, ", ") ..
                       "|r\n\nProceed?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    for _, d in ipairs(deletes) do
                        local classid = tonumber(d.classid) or 0
                        -- If classid is 0, search all class buckets for the sequence
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
            elseif v.action == "CompanionSetPlatformID" and not InCombatLockdown() then
                local classid = v.classid
                local name = v.sequencename
                local platformid = v.platformid
                -- Find the sequence in GSESequences and set its PlatformID
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
                    -- Also update GSE.Library if it exists there
                    if GSE.Library[classid] and GSE.Library[classid][name] then
                        if not GSE.Library[classid][name].MetaData then
                            GSE.Library[classid][name].MetaData = {}
                        end
                        GSE.Library[classid][name].MetaData.PlatformID = platformid
                    end
                    GSE.Print("|cff00ccffGSE Companion:|r Linked |cFFFFFF00" .. name .. "|r to platform ID " .. tostring(platformid))
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

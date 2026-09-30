local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local L = GSE.L

local GNOME = "Storage"

function GSE.ImportLegacyStorage(Library)
    if not GSE.isEmpty(Library) then
        for k, v in pairs(Library) do
            for i, j in pairs(v) do
                local id = GSE.SequenceIdForIncoming(k, i, j)
                GSE.PutSequenceBody(k, id, i, GSE.EncodeMessage({i, j}))
            end
        end
    end
    GSELegacyLibraryBackup = GSELibrary
    GSELibrary = nil
end

--- Add a sequence to the library
function GSE.OOCAddSequenceToCollection(sequenceName, sequence, classid, id)
    -- Check its not a GSE2 Sequence
    if GSE.isEmpty(sequence.Versions) then
        GSE.Print(string.format("%s " .. L["was unable to be interpreted."], sequenceName), L["Unrecognised Import"])
        return
    end
    -- check for version flags.
    if sequence.MetaData.EnforceCompatability and not string.match(GSE.VersionString, "development") then
        if GSE.ParseVersion(sequence.MetaData.GSEVersion) > (GSE.VersionNumber) then
            GSE.Print(
                string.format(
                    L[
                        "This sequence uses features that are not available in this version. You need to update GSE to %s in order to use this sequence."
                    ],
                    sequence.MetaData.GSEVersion
                )
            )
            --@debug@
            GSE.PrintDebugMessage(
                "Macro Version " .. sequence.MetaData.GSEVersion .. " Required Version: " .. GSE.VersionString,
                "Storage"
            )
            --@end-debug@
            return
        end
    end
    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(sequence)
    end

    --@debug@
    GSE.PrintDebugMessage("Attempting to import " .. sequenceName, "Storage")
    --@end-debug@
    --@debug@
    GSE.PrintDebugMessage("Classid not supplied - " .. tostring(GSE.isEmpty(classid)), "Storage")
    --@end-debug@
    -- Remove Spaces or commas from SequenceNames and replace with _'s
    sequenceName = string.gsub(sequenceName, " ", "_")
    sequenceName = string.gsub(sequenceName, ",", "_")

    -- check the Sequence TOC matches the current TOC at flavour resolution: a
    -- sequence stamped 120001 and a client running 120005 are both Midnight and
    -- shouldn't warn. Only flag when the flavour itself differs (a Midnight
    -- sequence on TWW, or an Era sequence on Forever) or the stored TOC is empty.
    --
    -- This used to compare math.floor(toc / 10000), i.e. the major. Forever
    -- shares Classic Era's major, so an Era sequence (11509) and a Forever one
    -- (16001) both reduced to 1 and crossing between two opposite rulesets
    -- warned about nothing. GSE.TOCFlavour keeps that rule in one place.
    local _, _, _, tocversion = GetBuildInfo()
    local seqExp = GSE.TOCFlavour(sequence.MetaData.TOC)
    local clientExp = GSE.TOCFlavour(tocversion)
    if GSE.isEmpty(sequence.MetaData.TOC) or seqExp ~= clientExp then
        GSE.Print(
            string.format(
                L["WARNING ONLY"] ..
                    ": " ..
                        L[
                            "Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."
                        ],
                sequenceName
            )
        )
    end

    -- Check for collisions
    local found = false
    if (GSE.isEmpty(classid) or classid == 0) and not GSE.isEmpty(sequence.MetaData.SpecID) then
        classid = tonumber(GSE.GetClassIDforSpec(sequence.MetaData.SpecID))
    elseif GSE.isEmpty(sequence.MetaData.SpecID) then
        sequence.MetaData.SpecID = GSE.GetCurrentClassID()
        classid = GSE.GetCurrentClassID()
    end
    --@debug@
    GSE.PrintDebugMessage("Classid now - " .. tostring(classid or 0), "Storage")
    --@end-debug@
    if GSE.isEmpty(GSE.Library[classid]) then
        GSE.Library[classid] = {}
    end
    -- Which stored sequence this is: its PlatformID, else the one filed under
    -- this name in this class, else a new one.
    id = id or GSE.SequenceIdForIncoming(classid, sequenceName, sequence)
    if GSE.SequenceEnvelope(id) or not GSE.isEmpty(GSE.Library[classid][id]) then
        found = true
        --@debug@
        GSE.PrintDebugMessage("Macro Exists", "Storage")
        --@end-debug@
    end
    -- The name it was imported under is its label; a sequence it matched by
    -- PlatformID keeps the label it already has (OOCPerformMergeAction).
    if type(sequence.MetaData) == "table" then sequence.MetaData.Name = sequenceName end
    if found then
        -- Existing sequence imports should let the user choose whether to merge,
        -- replace, rename, or ignore even when the local copy has no manual edits.
        if GSE.GUIShowCompareWindow then
            GSE.GUIShowCompareWindow(id, classid, sequence)
        else
            GSE.PerformMergeAction(GSEOptions.DefaultImportAction, classid, id, sequence)
        end
    else
        --@debug@
        GSE.PrintDebugMessage("Creating New Macro", "Storage")
        --@end-debug@
        -- New Sequence
        GSE.PerformMergeAction("REPLACE", classid, id, sequence)
    end
    if classid == GSE.GetCurrentClassID() or classid == 0 then
        --@debug@
        GSE.PrintDebugMessage("As its the current class updating buttons", "Storage")
        --@end-debug@
        GSE.UpdateSequence(id, sequence.Versions[sequence.MetaData.Default])
    end
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
end

--- Store the result of a merge action, unless that would put protected content
-- on disk in the clear.
--
-- This path only ever holds a DECODED body -- the import dialog hands over the
-- sequence, not the envelope it arrived in -- so there is no sealed blob here
-- to carry across the way a rename or an edit can. When the content is
-- protected the write is declined and a repack request is left instead: the
-- session keeps working from the Library, and the Companion fetches the sealed
-- blob from gse.tools to put the record straight.
local function storeMergedSequence(classid, id, sequenceName, reason, sealed)
    local seq = GSE.Library[classid][id]
    -- A REPLACE from a sealed import stores the blob it arrived in. The body
    -- on disk is exactly what was imported, so the envelope still describes
    -- it, and this is the one merge outcome where that is true -- MERGE and
    -- RENAME produce something the addon cannot seal, and fall through to the
    -- repack request below.
    if sealed then
        GSE.PutSequenceBody(classid, id, sequenceName, sealed)
        return true
    end
    local env = GSE.SequenceEnvelope(id)
    if GSE.IsProtectedAtRest(env and env.Body, seq) then
        -- The sealed body stays; the envelope still files and names it.
        if env then GSE.PutSequenceBody(classid, id, sequenceName, env.Body) end
        GSE.QueueRepack("sequence", classid, sequenceName, seq, reason)
        return false
    end
    GSE.PutSequenceBody(classid, id, sequenceName, GSE.EncodeMessage({sequenceName, seq}))
    return true
end

function GSE.OOCPerformMergeAction(action, classid, id, newSequence, newName)
    -- The label: a RENAME's new name, else what the stored or incoming
    -- sequence is called.
    local sequenceName = (action == "RENAME" and newName)
        or GSE.SequenceName(id)
        or (type(newSequence) == "table" and type(newSequence.MetaData) == "table" and newSequence.MetaData.Name)
        or tostring(id)
    -- Refuse to merge/replace with a Macros-only payload. Auto-rename
    -- has been retired; the user must re-export through gse.tools so
    -- the source is in the current schema before re-import.
    if type(newSequence) == "table" and newSequence.Macros ~= nil and newSequence.Versions == nil then
        GSE.Print(string.format(
            L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
            sequenceName), L["Import"])
        return
    end
    if GSE.isEmpty(newSequence.LastUpdated) then
        newSequence.LastUpdated = GSE.GetTimestamp()
    end
    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(newSequence)
    end
    if sequenceName:len() > 28 then
        local tempseqName = sequenceName:sub(1, 28)
        GSE.Print(
            string.format(
                L[
                    "Your sequence name was longer than 27 characters.  It has been shortened from %s to %s so that the in-game macro GSE creates for it will work."
                ],
                sequenceName,
                tempseqName
            ),
            "GSE Storage"
        )
        sequenceName = tempseqName
    end
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
    if action == "MERGE" then
        -- The stored copy, wherever it is filed; the merge lands in classid.
        local existing, fromClass = GSE.GetSequence(id)
        if existing == nil then existing = {MetaData = {Name = sequenceName}} end
        if fromClass ~= nil and fromClass ~= classid and GSE.Library[fromClass] then
            GSE.Library[fromClass][id] = nil
        end
        GSE.Library[classid][id] = existing
        -- Both sides need a Versions table. Migration above set them up;
        -- belt-and-braces: if either is still nil, init/empty out so the
        -- ipairs/insert doesn't crash and we don't silently no-op.
        if type(GSE.Library[classid][id].Versions) ~= "table" then
            GSE.Library[classid][id].Versions = {}
        end
        if type(newSequence.Versions) ~= "table" then
            newSequence.Versions = {}
        end
        for k, v in ipairs(newSequence.Versions) do
            --@debug@
            GSE.PrintDebugMessage("adding " .. k, "Storage")
            --@end-debug@
            table.insert(GSE.Library[classid][id].Versions, v)
        end
        --@debug@
        GSE.PrintDebugMessage("Finished colliding entry entry", "Storage")
        --@end-debug@
        GSE.Print(string.format(L["Extra Sequence Versions of %s have been added."], sequenceName), GNOME)
        GSE.ComputeSequenceDependencies(GSE.Library[classid][id])
        if GSE.PendingSealedImports then GSE.PendingSealedImports[sequenceName] = nil end
        storeMergedSequence(classid, id, sequenceName, "merge-needs-repack")
    elseif action == "REPLACE" then
        local _, fromClass = GSE.SequenceEnvelope(id)
        if fromClass ~= nil and fromClass ~= classid and GSE.Library[fromClass] then
            GSE.Library[fromClass][id] = nil
        end
        if type(newSequence.MetaData) == "table" then newSequence.MetaData.Name = sequenceName end
        GSE.Library[classid][id] = {}
        GSE.Library[classid][id] = newSequence
        --@debug@
        GSE.PrintDebugMessage("About to encode: Sequence " .. sequenceName)
        --@end-debug@
        --@debug@
        GSE.PrintDebugMessage(" New Entry: " .. GSE.Dump(GSE.Library[classid][id]), "Storage")
        --@end-debug@
        GSE.ComputeSequenceDependencies(GSE.Library[classid][id])
        do
            -- Claim the sealed original this import arrived in, if it had one.
            local sealed = GSE.PendingSealedImports and GSE.PendingSealedImports[sequenceName]
            if sealed and GSE.PendingSealedImports then GSE.PendingSealedImports[sequenceName] = nil end
            storeMergedSequence(classid, id, sequenceName, "replace-needs-repack", sealed)
        end
        GSE.Print(sequenceName .. L[" was updated to new version."], "Storage")
    elseif action == "RENAME" then
        -- Same rule as GSE.DuplicateSequence: a renamed import is a new work
        -- under a new name, so it mints its own record rather than sharing the
        -- original's. Keeping the id meant both sequences resolved to one
        -- server record and the later sync overwrote the other (#2077).
        --
        -- Safe to mint here because the dialog does not offer Rename for
        -- protected content -- that is checked again rather than assumed, so
        -- any other caller cannot use this path to strip an author's identity.
        if not (GSE.IsProtectedContent and GSE.IsProtectedContent(newSequence)) then
            if type(newSequence.MetaData) ~= "table" then newSequence.MetaData = {} end
            newSequence.MetaData.Name = sequenceName
            newSequence.MetaData.PlatformID = nil
            if GSE.MintOriginKey then
                newSequence.MetaData.OriginKey =
                    GSE.MintOriginKey(sequenceName, newSequence.MetaData.Author)
            end
            newSequence.LastUpdated = GSE.GetTimestamp()
        end
        -- A new work gets a new id; the sequence it collided with is untouched.
        id = GSE.NewLocalId()
        GSE.Library[classid][id] = {}
        GSE.Library[classid][id] = newSequence
        GSE.ComputeSequenceDependencies(GSE.Library[classid][id])
        if GSE.PendingSealedImports then GSE.PendingSealedImports[sequenceName] = nil end
        storeMergedSequence(classid, id, sequenceName, "rename-needs-repack")
        GSE.Print(sequenceName .. L[" was imported as a new sequence."], "Storage")
        --@debug@
        GSE.PrintDebugMessage(
            "Sequence " .. sequenceName .. " New Entry: " .. GSE.Dump(GSE.Library[classid][id]),
            "Storage"
        )
        --@end-debug@
    else
        GSE.Print(L["No changes were made to "] .. sequenceName, GNOME)
        -- Nothing was written, but it still came through whatever collection
        -- brought it: settle that here, as a store would.
        if GSE.SettleCollections then GSE.SettleCollections("sequence", sequenceName, id, classid) end
    end
    if type(GSE.Library[classid][id]) == "table" and type(GSE.Library[classid][id].MetaData) == "table" then
        GSE.Library[classid][id].MetaData.ManualIntervention = false
    end
    --@debug@
    GSE.PrintDebugMessage(
        "Sequence " .. sequenceName .. " Finalised Entry: " .. GSE.Dump(GSE.Library[classid][id]),
        "Storage"
    )
    --@end-debug@
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
    return id
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
    for k, v in pairs(Sequences) do
        GSE.AddSequenceToCollection(k, v)
    end
end

--- Add a macro for a sequence and register it in the list of known sequences
local function fixContainer(v)
    local fixedTable = {}
    for k, val in pairs(v) do
        if type(v[k]) == "table" then
            if tonumber(k) then
                fixedTable[tonumber(k)] = {}
                fixedTable[tonumber(k)] = fixContainer(val)
            else
                fixedTable[k] = fixContainer(val)
            end
        else
            fixedTable[k] = val
        end
    end
    for k, val in ipairs(v) do
        if type(v[k]) == "table" then
            fixedTable[k] = fixContainer(val)
        else
            fixedTable[k] = val
        end
    end
    return fixedTable
end

local importMarkupTextKeys = {
    macro = true,
    macrotext = true,
    text = true,
    managedMacro = true,
    manageMacro = true,
    funct = true
}

local importMarkupContainerKeys = {
    Actions = true,
    KeyPress = true,
    KeyRelease = true
}

local importMacroMarkupTextKeys = {
    macro = true,
    macrotext = true,
    text = true,
    managedMacro = true,
    manageMacro = true
}

local importMacroMarkupContainerKeys = {
    KeyPress = true,
    KeyRelease = true
}

local function decodeImportedEditorText(value, macroText)
    if macroText and GSE.DecodeMacroEditorText then
        return GSE.DecodeMacroEditorText(value)
    elseif GSE.DecodeEditorText then
        return GSE.DecodeEditorText(value)
    end
    if type(value) ~= "string" then return value end
    value = value:gsub("||[cC]%x%x%x%x%x%x%x%x", "")
    value = value:gsub("||r", "")
    value = value:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("||", "|")
    if macroText then
        value = value:gsub("(^[ \t]*)|([%a]+)", "%1/%2")
        value = value:gsub("(\n[ \t]*)|([%a]+)", "%1/%2")
    end
    return value
end

local function scrubImportedEditorMarkup(node, decodeAllStrings, macroTextContext)
    if type(node) ~= "table" then return node end
    if GSE.SanitizeSequenceEditorMarkup and GSE.SanitizeSequenceEditorMarkup(node) then
        return node
    end
    local isActionBlock = rawget(node, "Type") ~= nil
    for k, v in pairs(node) do
        if type(v) == "table" then
            scrubImportedEditorMarkup(
                v,
                decodeAllStrings or importMarkupContainerKeys[k] or isActionBlock,
                macroTextContext or importMacroMarkupContainerKeys[k]
            )
        elseif type(v) == "string" then
            if decodeAllStrings or importMarkupTextKeys[k] then
                node[k] = decodeImportedEditorText(v, macroTextContext or importMacroMarkupTextKeys[k])
            end
        end
    end
    return node
end

local function scrubCollectionPayload(payload)
    if type(payload) ~= "table" then return end
    for _, category in ipairs({"Sequences", "Variables", "Macros"}) do
        for _, v in pairs(payload[category] or {}) do
            scrubImportedEditorMarkup(v)
        end
    end
end

function GSE.processWAGOImport(input, dontencode)
    -- Pre-#1853 records stored versions under "Macros" instead of "Versions".
    -- The auto-rename has been retired: refuse to interpret a Macros-only
    -- record so the user can re-export from gse.tools and re-import.
    -- Returns nil; callers must handle that as "abort this import".
    if input and type(input) == "table" and input.Macros ~= nil and input.Versions == nil then
        local name = (input.MetaData and input.MetaData.Name) or input.SequenceName or "<unknown>"
        GSE.Print(string.format(
            L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
            name), L["Import"])
        return nil
    end
    for k, v in ipairs(input) do
        if type(v) == "table" then
            input[k] = fixContainer(v)
        end
    end
    for k, v in pairs(input) do
        if type(v) == "table" then
            input[k] = fixContainer(v)
        end
    end
    scrubImportedEditorMarkup(input)
    if dontencode then
        return input
    else
        return GSE.EncodeMessage(input)
    end
end

--- True when this sequence is already stored, in any class: the same
-- PlatformID, or the same name.
--
-- Answered from the envelopes, so nothing is decoded and no class is forced to
-- load -- the envelope's Name and id are always in the clear, even for sealed
-- content.
local function sealedImportCollides(name, body)
    local meta = type(body) == "table" and body.MetaData
    local pid = type(meta) == "table" and meta.PlatformID
    if type(pid) == "string" and GSE.SequenceEnvelope(pid) then return true end
    return GSE.FindSequenceId(name, nil, true) ~= nil
end

--- Load a serialised Sequence
-- skipDialogs: when true, suppress per-sequence StaticPopup confirmation dialogs
-- (version-mismatch and checksum warnings). Used by collection imports so that
-- the synchronous loop over N sequences does not clobber a single shared popup
-- slot, which would silently drop all but the last sequence.
-- forcemerge: when true, route conflict resolution to PerformMergeAction("MERGE")
-- without showing the compare dialog. Mutually exclusive with forcereplace —
-- if both are true, forcereplace wins (defensive).
function GSE.ImportSerialisedSequence(importstring, forcereplace, skipDialogs, forcemerge)
    if type(importstring) == "string" and importstring:sub(1, 7) == "!GSE3!+" then
        local ok, decoded = GSE.DecodeMessage(importstring)
        if ok and type(decoded) == "table" then
            local name, stored
            if decoded.objectType == "VARIABLE" then
                name = decoded.name
                stored = name and GSE.StoreEncodedVariable(name, importstring)
            elseif decoded.objectType == "MACRO" then
                name = decoded.name
                stored = name and GSE.StoreEncodedMacro and GSE.StoreEncodedMacro(name, importstring)
            else
                name = decoded[1]
                    or (type(decoded[2]) == "table" and decoded[2].MetaData and decoded[2].MetaData.Name)
                local body = type(decoded[2]) == "table" and decoded[2] or nil
                -- Sealed content is not exempt from the import dialog. Stored
                -- straight over the top, an import silently replaced whatever
                -- held that name -- for a pasted website export, and for every
                -- member of a plugin's Collection, which is the same path.
                --
                -- The body is only needed to compare against what is already
                -- installed; the ENVELOPE is what gets stored, so the sealed
                -- original is remembered for the action the user picks.
                if name and body and sealedImportCollides(name, body) and not forcereplace then
                    GSE.PendingSealedImports = GSE.PendingSealedImports or {}
                    GSE.PendingSealedImports[name] = importstring
                    GSE.AddSequenceToCollection(name, body)
                    -- Truthy, so callers testing success still pass, but not
                    -- `true`: nothing has been stored yet and the summary must
                    -- not claim it has. The user has still to choose.
                    return "review"
                end
                stored = name and GSE.StoreEncodedSequence(name, importstring)
            end
            if stored then
                -- Confirm a STANDALONE import. Inside a collection the summary
                -- at the end of that branch lists everything, and printing per
                -- member as well gave four lines plus two summaries for one
                -- four-sequence import. skipDialogs is what the collection
                -- loop passes, so it doubles as "someone else is reporting".
                if not skipDialogs then
                    GSE.Print(string.format(L["Imported: %s"], name), GNOME)
                end
                return true
            end
        end
        GSE.Print(L["Unable to interpret sequence."], GNOME)
        return false
    end
    local decompresssuccess, actiontable
    if type(importstring) == "table" then
        decompresssuccess, actiontable = true, importstring
    else
        decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    end
    --@debug@
    GSE.PrintDebugMessage(string.format("Decomsuccess: %s ", tostring(decompresssuccess)), Statics.SourceTransmission)
    --@end-debug@

    if decompresssuccess and actiontable then
        if actiontable.type == "COLLECTION" then
            actiontable = actiontable.payload or {}
            scrubCollectionPayload(actiontable)
            -- Collection provenance: the collections these elements came
            -- through (payload.Collections, absent for a single element in its
            -- container). Recorded as each member is stored -- see
            -- GSE.ExpectCollection.
            if GSE.ExpectCollection and type(actiontable.Collections) == "table" then
                local kinds = { sequence = "Sequences", variable = "Variables", macro = "Macros" }
                for _, col in ipairs(actiontable.Collections) do
                    if type(col) == "table" then
                        local pid = not GSE.isEmpty(col.PlatformID) and col.PlatformID or nil
                        for kind, field in pairs(kinds) do
                            for _, n in ipairs(type(col[field]) == "table" and col[field] or {}) do
                                GSE.ExpectCollection(kind, n, pid, col.Name)
                            end
                        end
                    end
                end
            end
            -- A collection reported nothing at all: COLLECTION_IMPORTED only
            -- refreshes an open editor tree. Count what actually goes in so
            -- the user is told, the way a single sealed import already is.
            local importedNames, seenCount = {}, 0
            local function noteImport(memberName, wentIn)
                seenCount = seenCount + 1
                -- Only a real store counts. A member routed to the import
                -- dialog returns "review": the user has not answered yet, and
                -- reporting it as imported was a lie -- choosing Ignore on all
                -- four still printed "Imported 4 of 4".
                if wentIn == true and memberName then
                    importedNames[#importedNames + 1] = tostring(memberName)
                end
            end
            -- Sequences/Variables/Macros in a COLLECTION payload are keyed by
            -- name and their values are the raw data tables (no {name, data}
            -- array wrapper). Propagate the key into the object's identity
            -- field so the recursive call can resolve it.
            for name, v in pairs(actiontable["Variables"] or {}) do
                if type(v) == "table" and v.GSEDeltaFork then
                    GSE.StoreDeltaFork(v)
                elseif type(v) == "string" and v:sub(1, 7) == "!GSE3!+" then
                    noteImport(name, GSE.StoreEncodedVariable(name, v))
                else
                    if type(v) == "table" and not v.name then v.name = name end
                    noteImport(name, GSE.ImportSerialisedSequence(v, forcereplace, true, forcemerge))
                end
            end
            for name, v in pairs(actiontable["Sequences"] or {}) do
                if type(v) == "table" and v.GSEDeltaFork then
                    -- Fork shipped as { encrypted base + delta }: persist to
                    -- GSEDeltas (opaque platformId key) + reconstruct in memory.
                    GSE.StoreDeltaFork(v)
                elseif type(v) == "string" and v:sub(1, 7) == "!GSE3!+" then
                    -- Through the importer, not straight to the store: a
                    -- sealed member is still an import, and writing it here
                    -- skipped the collision check, so a plugin's Restore
                    -- overwrote existing sequences with no dialog and nothing
                    -- to say it had happened.
                    noteImport(name, GSE.ImportSerialisedSequence(v, forcereplace, true, forcemerge))
                else
                    if type(v) == "table" then
                        v.MetaData = v.MetaData or {}
                        if not v.MetaData.Name then v.MetaData.Name = name end
                    end
                    GSE.ImportSerialisedSequence(v, forcereplace, true, forcemerge)
                end
            end
            for name, v in pairs(actiontable["Macros"] or {}) do
                if type(v) == "table" and v.GSEDeltaFork then
                    GSE.StoreDeltaFork(v)
                elseif type(v) == "string" and v:sub(1, 7) == "!GSE3!+" then
                    GSE.StoreEncodedMacro(name, v)
                else
                    if type(v) == "table" and not v.name then v.name = name end
                    GSE.ImportSerialisedSequence(v, forcereplace, true, forcemerge)
                end
            end
            if seenCount > 0 then
                -- "Restored" when the plugin panel started this: the content
                -- came back from the plugin that ships it rather than arriving
                -- from outside. The flag is consumed here so the next import
                -- reports itself honestly.
                local restoring = GSE.RestoreInProgress
                GSE.RestoreInProgress = nil
                if #importedNames > 0 then
                    GSE.Print(string.format(
                        restoring and L["Restored %d of %d: %s"] or L["Imported %d of %d: %s"],
                        #importedNames, seenCount, table.concat(importedNames, ", ")), GNOME)
                end
                -- Silent when everything went to a dialog: each one reports its
                -- own outcome ("was updated", "No changes were made", "Extra
                -- Sequence Versions ... added"), which is the truth about what
                -- happened. A summary here could only guess ahead of the user.
            end
            GSE:SendMessage(Statics.Messages.COLLECTION_IMPORTED)
        elseif actiontable.objectType == "MACRO" then
            scrubImportedEditorMarkup(actiontable)
            actiontable.objectType = nil
            local oocaction = {
                ["action"] = "importmacro",
                ["node"] = actiontable
            }
            GSE.EnqueueOOC(oocaction)
        elseif actiontable.objectType == "VARIABLE" then
            scrubImportedEditorMarkup(actiontable)
            actiontable.objectType = nil
            local oocaction = {
                ["action"] = "updatevariable",
                ["variable"] = actiontable,
                ["name"] = actiontable.name
            }
            GSE.EnqueueOOC(oocaction)
        else
            actiontable.objectType = nil
            --@debug@
            GSE.PrintDebugMessage(
                string.format(
                    "tablerows: %s   type cell1 %s cell2 %s",
                    #actiontable,
                    type(actiontable[1]),
                    type(actiontable[2])
                ),
                Statics.SourceTransmission
            )
            --@end-debug@
            local k, v = actiontable[1], actiontable[2]
            if actiontable.MetaData and actiontable.MetaData.Name then
                k = actiontable.MetaData.Name
                v = actiontable
            end
            local seqName = k
            v = GSE.processWAGOImport(v, true)
            -- processWAGOImport returns nil when it refuses an import
            -- (e.g. pre-#1853 records still using `Macros`). It already
            -- printed the user-facing message; we just abort this branch.
            if not v then return false end

            if v.MetaData.GSEVersion and v.MetaData.GSEVersion > 3200 then
                if v.MetaData.GSEVersion < GSE.VersionNumber then
                    if skipDialogs then
                        -- Inside a collection import: log and proceed rather than
                        -- showing a popup that would be clobbered by the next item.
                        GSE.Print(string.format(L["Sequence '%s' was created with an older version of GSE (%s) - importing anyway as part of collection."], seqName, tostring(v.MetaData.GSEVersion)), L["Import"])
                    else
                        -- Older sequence: always show the older-version dialog.
                        -- OnAccept will chain to the checksum dialog for sequences
                        -- >= Statics.ChecksumMinVersion (checksums were introduced then).
                        GSE.GUICall("GUIConfirmSequenceOlderVersion", seqName, v, forcereplace)
                        return decompresssuccess
                    end
                end
            else
                GSE.Print(
                        L["This sequence is not compatible with this version of the game and cannot be imported."],
                        L["Import"]
                    )
                return
            end
            -- Warn if the sequence has been modified after it was exported.
            -- If the checksum is invalid the user must confirm before the import proceeds.
            -- Suppress the dialog inside collection imports to avoid clobbering.
            if GSE.VerifySequenceChecksum then
                local integrity = GSE.VerifySequenceChecksum(v)
                if integrity ~= true and not skipDialogs then
                    GSE.GUICall("GUIConfirmSequenceIntegrity", seqName, v, forcereplace)
                    return decompresssuccess
                end
            end

            if forcereplace then
                local classid = GSE.GetClassIDforSpec(v.MetaData.SpecID)
                v.MetaData.Name = seqName
                GSE.PerformMergeAction("REPLACE", classid, GSE.SequenceIdForIncoming(classid, seqName, v), v)
            elseif forcemerge then
                -- Route to MERGE without compare dialog. Which sequence it
                -- merges into: the same PlatformID, else the same name in the
                -- spec's class, else the same name in any class.
                local classid = GSE.GetClassIDforSpec(v.MetaData and v.MetaData.SpecID)
                local id = GSE.SequenceIdForIncoming(classid, seqName, v)
                local _, foundClass = GSE.SequenceEnvelope(id)
                if foundClass == nil then
                    local other, otherClass = GSE.FindSequenceId(seqName, nil, true)
                    if other then id, foundClass = other, otherClass end
                end
                if (classid == nil or classid == 0) and foundClass then classid = foundClass end
                v.MetaData.Name = seqName
                GSE.PerformMergeAction("MERGE", classid or 0, id, v)
            else
                -- Filed, and announced, once its class and id are known.
                GSE.AddSequenceToCollection(seqName, v)
            end
        end
    else
        GSE.Print(L["Unable to interpret sequence."], GNOME)
        decompresssuccess = false
    end

    return decompresssuccess
end

--- This function dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)
    -- Given a sequence's label, dump its button.
    local id = GSE.FindSequenceId(SequenceName)
    SequenceName = (id and GSE.ButtonForSequence(id)) or SequenceName
    GSE.Print("====================================\nStart GSE Button Dump\n====================================")
    GSE.Print("Button name: " .. SequenceName)
    GSE.Print("Step Id: " .. _G[SequenceName]:GetAttribute("step"))
    GSE.Print("ms: " .. _G[SequenceName]:GetAttribute("ms"))
    GSE.Print("====================================\nStep\n====================================")
    GSE.Print(GSE.SequencesExec[SequenceName][_G[SequenceName]:GetAttribute("step")])
    GSE.Print("====================================\nEnd GSE Button Dump\n====================================")
end

--- Moves sequences filed as global (class 0) whose spec says they belong to a
-- class into that class. The move is stored -- it used to change only the
-- in-memory Library, so it was undone at the next login -- and it keeps the
-- sequence's id, so its keybinds and GSE.Tools record follow it. It also read
-- SpecID off the sequence itself, where it never is, so it moved nothing.
function GSE.MoveMacroToClassFromGlobal()
    GSE.EnsureClassLoaded(0)
    local moves = {}
    for id, seq in pairs(GSE.Library[0] or {}) do
        local specID = type(seq) == "table" and type(seq.MetaData) == "table" and tonumber(seq.MetaData.SpecID)
        if specID and specID > 0 then
            local classid = GSE.GetClassIDforSpec(specID)
            if classid and classid > 0 then moves[#moves + 1] = {id = id, seq = seq, classid = classid} end
        end
    end
    for _, m in ipairs(moves) do
        GSE.ReplaceSequence(m.classid, m.id, m.seq)
        GSE.Library[0][m.id] = nil
        GSE.Print(string.format(L["Moved %s to class %s."], GSE.SequenceName(m.id) or m.id,
            Statics.SpecIDList[m.classid] or tostring(m.classid)))
    end
    GSE.ReloadSequences()
end

-- ============================================================
-- Sequence error checker: module-level helpers
-- ============================================================

--- MetaData keys that store Macros array index references.
--
-- Derived from the runtime's own context list rather than typed out again: the
-- hand-written version had drifted, checking a PVESolo key GSE no longer has a
-- context for and a "Normal" key nothing in the codebase has ever read, while
-- the real list lives in Storage.lua (#2023). Default is not a context, so it
-- is prepended here.
local seqContextKeys = {"Default"}
for _, key in ipairs(GSE.GetContextVersionKeys()) do
    seqContextKeys[#seqContextKeys + 1] = key
end

--- Set of valid WoW macro slash commands (warcraft.wiki.gg/wiki/Macro_commands).
-- Built once at load time from Statics + comprehensive wiki list.
local validMacroSlashCmds = (function()
    local s = {}
    for cmd in pairs(Statics.CastCmds or {}) do s[cmd] = true end
    for _, cmd in ipairs(Statics.MacroCommands or {}) do s[cmd] = true end
    for _, cmd in ipairs({
        -- Combat / casting
        "castrandom", "castsequence", "changeactionbar", "stopcasting",
        "stopspelltarget", "swapactionbar", "userandom", "spell",
        -- Targeting
        "tar", "targetexact", "targetenemyplayer", "targetfriendplayer",
        "targetparty", "targetraid", "targetlastenemy", "targetlastfriend",
        "targetlasttarget",
        -- Pet
        "petassist", "petautocasttoggle", "petdefensive", "petdismiss",
        "petfollow", "petmoveto", "petpassive", "petstay",
        -- System
        "console", "click", "disableaddons", "enableaddons", "help",
        "logout", "macrohelp", "played", "quit", "random", "reload",
        "run", "script", "stopmacro", "time", "timetest", "who",
        -- Character / inventory
        "equip", "equipset", "equipslot", "friend", "follow", "ignore",
        "inspect", "leavevehicle", "randompet", "removefriend", "settitle",
        "trade", "unignore", "summonpet", "dismisspet", "randomfavoritepet",
        -- UI / Blizzard frames
        "achievements", "calendar", "guildfinder", "dungeonfinder", "loot",
        "macro", "raidfinder", "share", "stopwatch",
        -- Chat (full names and abbreviations)
        "afk", "announce", "battleground", "emote", "dnd", "guild",
        "join", "leave", "party", "raid", "rw", "reply", "say",
        "whisper", "yell", "s", "y", "g", "p", "bg", "i", "o", "me",
        -- Party / Raid
        "clearworldmarker", "invite", "readycheck", "requestinvite",
        "targetmarker", "uninvite", "worldmarker", "raidinfo", "promote",
        "ffa", "master", "mainassist", "mainassistoff", "maintank",
        "maintankoff",
        -- Guild
        "guilddemote", "guilddisband", "guildinfo", "guildinvite",
        "guildleader", "guildquit", "guildmotd", "guildpromote",
        "guildroster", "guildremove",
        -- PvP
        "duel", "forfeit", "pvp", "wargame",
        -- Miscellaneous
        "in", "showtooltip", "show",
    }) do
        s[cmd] = true
    end
    return s
end)()

--- Returns (ipairsCount, totalNumericCount, maxNumericIndex) for a table.
-- Reveals array gaps: if totalNumericCount > ipairsCount, there are unreachable entries.
local function arrayStats(t)
    local ipCount = 0
    for _ in ipairs(t) do ipCount = ipCount + 1 end
    local numCount, maxIdx = 0, 0
    for k in pairs(t) do
        if type(k) == "number" and k >= 1 then
            numCount = numCount + 1
            if k > maxIdx then maxIdx = k end
        end
    end
    return ipCount, numCount, maxIdx
end

--- Inspects one sequence for structural and content issues.
-- Returns a list of human-readable issue strings (empty = no problems).
-- ponytail: the "unusable structure" subset of checkSeqStructure's early-return
-- cases below. True = the tree flags it red and routes a click to the
-- corrupt-sequence panel instead of the editor. A missing SpecID counts, tested
-- exactly as checkSeqStructure reports it (isEmpty: nil or "", so a Global
-- sequence's SpecID 0 is not missing). So do versions numbered from 0, tested
-- as the scan tests them (Versions[0] ~= nil): they read as no versions at all,
-- and it is the one case Repair fixes, so the panel offers Repair for it.
-- Other benign notices, such as altered-from-export, stay unflagged.
function GSE.IsSequenceStructurallyBroken(seq)
    if type(seq) ~= "table" then return true end
    if type(seq.MetaData) ~= "table" then return true end
    if GSE.isEmpty(seq.MetaData.SpecID) then return true end
    if seq.Macros ~= nil and seq.Versions == nil then return true end -- pre-#1853 schema
    if type(seq.Versions) ~= "table" then return true end
    if seq.Versions[0] ~= nil then return true end
    return false
end

local function checkSeqStructure(classlibid, seqname, seq) -- luacheck: ignore classlibid seqname
    local issues = {}

    if type(seq) ~= "table" then
        table.insert(issues, L["Sequence is not a table"])
        return issues
    end

    -- Top-level required tables
    if GSE.isEmpty(seq.MetaData) or type(seq.MetaData) ~= "table" then
        table.insert(issues, L["Missing MetaData table"])
        return issues
    end
    -- Pre-#1853 schema detection. Auto-rename has been retired; this
    -- record can't be processed until it goes through gse.tools and
    -- comes back in the current shape. Specific-over-generic so the
    -- user sees the actual remedy rather than "missing Macros table".
    if seq.Macros ~= nil and seq.Versions == nil then
        table.insert(issues, string.format(
            L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
            seqname))
        return issues
    end
    if type(seq.Versions) ~= "table" then
        table.insert(issues, L["Missing or invalid Macros table"])
        return issues
    end

    -- Required MetaData fields
    if GSE.isEmpty(seq.MetaData.SpecID) then
        table.insert(issues, L["MetaData.SpecID is missing"])
    end

    -- Integrity check: if a checksum is present it must still match the Versions content.
    -- "no_checksum" is not an error — locally created sequences have no checksum.
    if GSE.VerifySequenceChecksum then
        if GSE.VerifySequenceChecksum(seq) == false then
            table.insert(issues, L["Sequence has been altered from its exported state"])
        end
    end

    -- Macros array analysis. Special-case the 0-indexed table — it has
    -- versions but ipairs starts at 1, so editor/runtime see nothing.
    -- Detect it BEFORE the generic "empty" message so the error log says
    -- the actual problem (and FixSequenceStructure can recover them by
    -- remapping 0→1 in step 4).
    local macIp, macNum, macMax = arrayStats(seq.Versions)
    local hasZeroKey = seq.Versions[0] ~= nil
    if hasZeroKey then
        local zeroKeyed = 0
        for k in pairs(seq.Versions) do
            if type(k) == "number" and k == 0 then zeroKeyed = zeroKeyed + 1 end
        end
        table.insert(issues, string.format(
            L["Versions starts at index 0 (Lua ipairs starts at 1 → editor and runtime see no versions). %d entr%s at index 0."],
            zeroKeyed, zeroKeyed == 1 and "y" or "ies"))
        -- Don't bail early — keep checking other structural issues so the
        -- repair report covers everything in one pass.
    elseif macNum == 0 then
        table.insert(issues, L["Macros array is empty (no versions defined)"])
        return issues
    end
    if macNum > macIp then
        table.insert(issues, string.format(
            L["Macros array has gaps: %d version(s) reachable of %d total (max index %d)"],
            macIp, macNum, macMax))
    end

    -- MetaData context version references must point to existing Macros entries
    for _, ctxKey in ipairs(seqContextKeys) do
        local val = seq.MetaData[ctxKey]
        if not GSE.isEmpty(val) then
            local idx = tonumber(val)
            if idx and (idx < 1 or idx > macMax or seq.Versions[idx] == nil) then
                table.insert(issues, string.format(
                    L["MetaData.%s = %d references a non-existent Macros version (max valid index: %d)"],
                    ctxKey, idx, macMax))
            end
        end
    end

    -- Valid Action types
    local validTypes = {
        [Statics.Actions.Loop]   = true,
        [Statics.Actions.If]     = true,
        [Statics.Actions.Repeat] = true,
        [Statics.Actions.Action] = true,
        [Statics.Actions.Pause]  = true,
        [Statics.Actions.Embed]  = true,
    }

    -- Inspect every Macro version (including those beyond array gaps)
    for macIdx, macVer in pairs(seq.Versions) do
        if type(macIdx) == "number" then
            if type(macVer) ~= "table" then
                table.insert(issues, string.format(L["Macros[%d] is not a table"], macIdx))
            elseif type(macVer.Actions) ~= "table" then
                table.insert(issues, string.format(
                    L["Macros[%d].Actions is missing or not a table"], macIdx))
            else
                -- Actions array gap detection
                local actIp, actNum, actMax = arrayStats(macVer.Actions)
                if actNum > actIp then
                    table.insert(issues, string.format(
                        L["Macros[%d].Actions has gaps: %d reachable of %d total (max index %d)"],
                        macIdx, actIp, actNum, actMax))
                end

                -- Inspect every Action (including those beyond gaps)
                for actIdx, action in pairs(macVer.Actions) do
                    if type(actIdx) == "number" and type(action) == "table" then
                        if GSE.isEmpty(action.Type) then
                            table.insert(issues, string.format(
                                L["Macros[%d].Actions[%d] is missing Type field"],
                                macIdx, actIdx))
                        elseif not validTypes[action.Type] then
                            table.insert(issues, string.format(
                                L["Macros[%d].Actions[%d] has unrecognized Type: '%s'"],
                                macIdx, actIdx, tostring(action.Type)))
                        else
                            -- Type-specific required fields
                            if action.Type == Statics.Actions.If then
                                if GSE.isEmpty(action.Variable) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (If) is missing the Variable field"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Embed then
                                if GSE.isEmpty(action.Sequence) and GSE.isEmpty(action.SequenceID) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (Embed) is missing the Sequence field"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Pause then
                                if GSE.isEmpty(action.Clicks) and GSE.isEmpty(action.MS) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (Pause) has neither Clicks nor MS"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Action then
                                if not GSE.isEmpty(action.macro) then
                                    local raw = tostring(action.macro)
                                    if raw:sub(1, 1) == "/" then
                                        -- 255-character WoW macro block limit
                                        local unesc = GSE.UnEscapeString(raw)
                                        local macroLength =
                                            GSE.GetMacroEditorTextLength and GSE.GetMacroEditorTextLength(unesc) or #unesc
                                        if macroLength > 255 then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] macro text exceeds 255 characters (%d chars)"],
                                                macIdx, actIdx, macroLength))
                                        end
                                        -- Unbalanced conditional bracket check
                                        local opens, closes = 0, 0
                                        for _ in raw:gmatch("%[") do opens  = opens  + 1 end
                                        for _ in raw:gmatch("%]") do closes = closes + 1 end
                                        if opens ~= closes then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] macro text has unbalanced brackets (%d '[' vs %d ']')"],
                                                macIdx, actIdx, opens, closes))
                                        end
                                        -- Unknown slash command check
                                        local cmd = raw:match("^/(%a+)")
                                        if cmd and not validMacroSlashCmds[cmd:lower()] then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] uses unrecognized slash command: /%s"],
                                                macIdx, actIdx, cmd))
                                        end
                                    end
                                    -- Check for Java-style // comments; GSE only strips lines starting with --
                                    for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
                                        if line:match("^%s*//") then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] uses // comments instead of --; GSE will not strip these on compile"],
                                                macIdx, actIdx))
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return issues
end

-- ---------------------------------------------------------------------------
-- Dependency tracking
-- ---------------------------------------------------------------------------

--- Scan a string for GSE variable references, accumulating names into `found`.
local function scanStringForVarRefs(str, found)
    -- Bracket notation: GSE.V["name"]() or GSE.V['name']()
    for name in str:gmatch('GSE%.V%[["\'](.-)["\']%]') do
        found[name] = true
    end
    -- Dot notation: GSE.V.name() or GSE.V.name(arg)
    for name in str:gmatch('GSE%.V%.([%w_]+)%s*%(') do
        found[name] = true
    end
end

--- Scan a string for WoW macro API references, accumulating macro names into `found`.
-- Matches GetMacroBody("name"), GetMacroIndexByName("name"), GetMacroSpell("name"),
-- GetMacroItem("name"), and any other GetMacro*(name) Lua API call.
local function scanStringForMacroRefs(str, found)
    for name in str:gmatch('GetMacro%a*%s*%(%s*["\']([^"\']+)["\']') do
        found[name] = true
    end
end

--- Names that look like WoW macro references but are actually GSE placeholder
-- text shipped with every new sequence. Excluded from dependency tracking so
-- they do not show as red "missing macro" entries in the editor metadata panel.
GSE.PlaceholderMacroNames = GSE.PlaceholderMacroNames or {
    ["Need Stuff Here"] = true,
}

--- Recursively walk a table collecting variable refs, Embed sequence names, and macro refs.
local function walkTableForDeps(t, vars, seqs, macros)
    for _, v in pairs(t) do
        if type(v) == "string" then
            scanStringForVarRefs(v, vars)
            scanStringForMacroRefs(v, macros)
        elseif type(v) == "table" then
            -- Use rawget to avoid triggering Statics.TableMetadataFunction __index,
            -- which expects array path keys and errors on plain string keys.
            local vType     = rawget(v, "Type")
            local vtype     = rawget(v, "type")
            local vSequence = rawget(v, "Sequence")
            local vmacro    = rawget(v, "macro")
            if vType == "Embed" and type(vSequence) == "string" then
                seqs[vSequence] = true
            end
            -- Action block with type="macro": if the macro field does not start with
            -- "/", "#", or "=" it is a plain WoW macro name reference, not command text.
            -- "=" prefix means it's a GSE variable expression (e.g. =GSE.V.Name()), not a macro name.
            if vType == "Action" and vtype == "macro" and type(vmacro) == "string"
                    and not rawget(v, "Disabled") then
                local text = GSE.UnEscapeString(vmacro)
                local first = string.sub(text, 1, 1)
                if #text > 0 and first ~= "/" and first ~= "#" and first ~= "="
                        and not (GSE.PlaceholderMacroNames and GSE.PlaceholderMacroNames[text]) then
                    macros[text] = true
                end
            end
            if not (vType == "Action" and rawget(v, "Disabled")) then
                walkTableForDeps(v, vars, seqs, macros)
            end
        end
    end
end

--- Compute the direct dependencies of a sequence by scanning its Macros.
-- Mutates sequence.MetaData.Dependencies in place and returns it.
-- {Variables = {"v1",...}, Sequences = {"s1",...}, Macros = {"m1",...}}  (sorted arrays)
function GSE.ComputeSequenceDependencies(sequence)
    if type(sequence) ~= "table" or type(sequence.MetaData) ~= "table" then return end
    local vars, seqs, macros = {}, {}, {}
    if type(sequence.Versions) == "table" then
        walkTableForDeps(sequence.Versions, vars, seqs, macros)
    end
    local varList, seqList, macroList = {}, {}, {}
    for k in pairs(vars) do table.insert(varList, k) end
    for k in pairs(seqs) do table.insert(seqList, k) end
    for k in pairs(macros) do table.insert(macroList, k) end
    table.sort(varList)
    table.sort(seqList)
    table.sort(macroList)
    local deps = {Variables = varList, Sequences = seqList, Macros = macroList}
    sequence.MetaData.Dependencies = deps
    return deps
end

--- Compute the direct variable dependencies of a variable: every variable
-- any of its versions calls. Mutates variable.Dependencies and returns it.
function GSE.ComputeVariableDependencies(variable)
    if type(variable) ~= "table" then return end
    local vars = {}
    if type(variable.funct) == "string" then
        scanStringForVarRefs(variable.funct, vars)
    end
    for _, version in pairs(type(variable.Versions) == "table" and variable.Versions or {}) do
        if type(version) == "table" and type(version.funct) == "string" then
            scanStringForVarRefs(version.funct, vars)
        end
    end
    local varList = {}
    for k in pairs(vars) do table.insert(varList, k) end
    table.sort(varList)
    local deps = {Variables = varList}
    variable.Dependencies = deps
    return deps
end

--- Resolve the full transitive closure of variable names.
-- varNames: array (or set) of starting variable names.
-- Returns a set table {name = true} of all required variable names.
function GSE.GetTransitiveVariableDeps(varNames)
    local result = {}
    local queue = {}
    -- Accept both array and set as input
    if type(varNames) == "table" then
        for k, v in pairs(varNames) do
            local name = (type(k) == "string" and v == true) and k or v
            if type(name) == "string" and not result[name] then
                result[name] = true
                table.insert(queue, name)
            end
        end
    end
    local i = 1
    while i <= #queue do
        local name = queue[i]
        i = i + 1
        if not GSE.isEmpty(GSE.Store("variable")) and not GSE.isEmpty(GSE.Store("variable")[name]) then
            local ok, decoded = GSE.DecodeMessage(GSE.Store("variable")[name])
            if ok and decoded and decoded.Dependencies and decoded.Dependencies.Variables then
                for _, depname in ipairs(decoded.Dependencies.Variables) do
                    if not result[depname] then
                        result[depname] = true
                        table.insert(queue, depname)
                    end
                end
            end
        end
    end
    return result
end

--- Find all loaded sequences and variables that directly depend on a variable.
-- Only searches classes already in GSE.Library (lazy-loaded classes not forced).
-- Returns { sequences = {{classid=n, id=s, name=label}, ...}, variables = {name, ...} }
function GSE.GetVariableDependents(varName)
    local seqs, vars = {}, {}
    for classid = 0, 13 do
        if GSE.Library[classid] then
            for id, seq in pairs(GSE.Library[classid]) do
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Variables) == "table" then
                        for _, vname in ipairs(deps.Variables) do
                            if vname == varName then
                                table.insert(seqs, {classid = classid, id = id,
                                    name = GSE.SequenceName(id, classid) or seq.MetaData.Name or tostring(id)})
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if not GSE.isEmpty(GSE.Store("variable")) then
        for vname, vdata in pairs(GSE.Store("variable")) do
            if vname ~= varName then
                local ok, decoded = GSE.DecodeMessage(vdata)
                if ok and decoded and decoded.Dependencies and type(decoded.Dependencies.Variables) == "table" then
                    for _, depname in ipairs(decoded.Dependencies.Variables) do
                        if depname == varName then
                            table.insert(vars, vname)
                            break
                        end
                    end
                end
            end
        end
    end
    table.sort(vars)
    table.sort(seqs, function(a, b)
        if a.classid ~= b.classid then return a.classid < b.classid end
        return a.name < b.name
    end)
    return {sequences = seqs, variables = vars}
end

--- Find all loaded sequences that embed the given sequence. Takes its id (or,
-- from older callers, its name): an Embed still names what it embeds.
-- Only searches classes already in GSE.Library (lazy-loaded classes not forced).
-- Returns array of {classid=n, id=s, name=label}.
function GSE.GetSequenceDependents(seqRef)
    local seqName = GSE.SequenceName(seqRef) or seqRef
    local result = {}
    for classid = 0, 13 do
        if GSE.Library[classid] then
            for id, seq in pairs(GSE.Library[classid]) do
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Sequences) == "table" then
                        for _, sname in ipairs(deps.Sequences) do
                            if sname == seqName then
                                table.insert(result, {classid = classid, id = id,
                                    name = GSE.SequenceName(id, classid) or seq.MetaData.Name or tostring(id)})
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.classid ~= b.classid then return a.classid < b.classid end
        return a.name < b.name
    end)
    return result
end

--- Find all loaded sequences that embed the given macro name.
-- Searches GSE.Library sequences whose MetaData.Dependencies.Macros lists the macro.
-- Returns array of {classid=n, id=s, name=label}.
function GSE.GetMacroDependents(macroName)
    local result = {}
    for classid = 0, 13 do
        if GSE.Library[classid] then
            for id, seq in pairs(GSE.Library[classid]) do
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Macros) == "table" then
                        for _, mname in ipairs(deps.Macros) do
                            if mname == macroName then
                                table.insert(result, {classid = classid, id = id,
                                    name = GSE.SequenceName(id, classid) or seq.MetaData.Name or tostring(id)})
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.classid ~= b.classid then return a.classid < b.classid end
        return a.name < b.name
    end)
    return result
end

--- A scope to suggest for a variable or macro, from what uses it: the spec
--- every user shares, else the class they share, else nothing (it stays
--- global). A variable's users are the sequences that call it and the managed
--- macros that do; a macro's are the sequences that run it. Only loaded
--- sequences are counted, as the dependents lookups count them. Returns
--- { specID, reason } or nil. Offered to the author, never applied.
function GSE.SuggestElementScope(kind, name)
    local specs = {}
    local users = kind == "variable" and GSE.GetVariableDependents(name).sequences or GSE.GetMacroDependents(name)
    for _, entry in ipairs(users or {}) do
        local seq = GSE.Library[entry.classid] and GSE.Library[entry.classid][entry.id]
        specs[#specs + 1] = tonumber(seq and seq.MetaData and seq.MetaData.SpecID) or entry.classid or 0
    end
    if kind == "variable" then
        -- A managed macro that calls it: it only compiles where the variable is live.
        local calls = {"GSE.V." .. name .. "(", "GSE.V['" .. name .. "']", 'GSE.V["' .. name .. '"]'}
        local function visit(mname, node)
            if not GSE.IsStoredMacroNode(node) or not node.Managed then return end
            local src = GSE.MacroSource(GSE.UpgradeMacro(node, mname))
            for _, c in ipairs(calls) do
                if src:find(c, 1, true) then
                    specs[#specs + 1] = tonumber(node.MetaData and node.MetaData.SpecID) or 0
                    return
                end
            end
        end
        for k, v in pairs(GSE.Store("macro")) do
            if GSE.IsStoredMacroNode(v) then visit(k, v)
            elseif type(v) == "table" then for k2, v2 in pairs(v) do visit(k2, v2) end end
        end
    end
    if #specs == 0 then return nil end
    local classOf = function(spec)
        if spec <= 13 then return spec end
        local ok, c = pcall(GSE.GetClassIDforSpec, spec)
        return ok and tonumber(c) or 0
    end
    local oneSpec, oneClass = specs[1], classOf(specs[1])
    for _, sp in ipairs(specs) do
        if sp ~= oneSpec then oneSpec = nil end
        if classOf(sp) ~= oneClass then oneClass = nil end
    end
    local pick = (oneSpec and oneSpec > 0) and oneSpec or ((oneClass and oneClass > 0) and oneClass or nil)
    if not pick then return nil end
    return {
        specID = pick,
        reason = string.format(L["Everything that uses it is %s."], Statics.SpecIDList[pick] or tostring(pick)),
    }
end

-- Queue of corrupt sequences waiting for the player to act on them.
local corruptQueue = {}

--- Show the next dialog for a corrupt sequence, if any remain in the queue.
-- Called by the StaticPopup OnAccept/OnCancel handlers to chain through all entries.
function GSE.ProcessNextCorruptSequence()
    if #corruptQueue == 0 then return end
    local entry = table.remove(corruptQueue, 1)
    GSE.GUICall("GUIConfirmCorruptSequence", entry.classid, entry.id,
        string.format(L["GSE_CORRUPT_SEQUENCE_TEXT"], entry.name, entry.classid))
end

--- Build the dialog queue from GSE.CorruptSequences and show the first dialog.
-- ponytail: does NOT drain GSE.CorruptSequences anymore — the editor tree reads
-- that list to flag corrupt seqs, so a dismissed/Skipped popup still leaves them
-- findable. Dedup keeps the popup from double-presenting the same entry.
function GSE.ProcessCorruptSequences()
    local queued = {}
    for _, e in ipairs(corruptQueue) do queued[e.classid .. "|" .. tostring(e.id)] = true end
    for _, entry in ipairs(GSE.CorruptSequences or {}) do
        local key = entry.classid .. "|" .. tostring(entry.id)
        if not queued[key] then
            table.insert(corruptQueue, entry)
            queued[key] = true
        end
    end
    if #corruptQueue > 0 then
        GSE.Print(string.format(L["%d corrupt sequence(s) found \226\128\148 showing resolution options."], #corruptQueue))
        GSE.ProcessNextCorruptSequence()
    end
end

-- The editor's corrupt-sequence panel lists the same issues this scan prints,
-- so it asks the same function rather than a second copy of the rules.
GSE.CheckSequenceStructure = checkSeqStructure

-- Whether /gse checksequencesforerrors can fix an issue by itself. One rule,
-- shared: the scan uses it to decide what to repair, and the editor's
-- corrupt-sequence panel uses it to decide whether to offer Repair at all.
function GSE.IsAutoFixableSequenceIssue(issue)
    return type(issue) == "string" and issue:find("Versions starts at index 0", 1, true) ~= nil
end

--- Scans all sequences in GSE.Library for structural and content issues,
-- then checks GSESequences entries for valid encoding.
function GSE.ScanMacrosForErrors()
    GSE.Print(L["Scanning GSE.Library for structural and content issues..."])
    local totalIssues = 0
    local autoFixedCount = 0

    -- Auto-fixable issue detection. For now only the "Versions starts at
    -- index 0" case — FixSequenceStructure remaps 0→1 cleanly and the
    -- result is always equivalent or better. Other issues (missing
    -- MetaData, schema-incompatible, etc.) need user attention so they
    -- continue to surface verbatim. Match by substring on a stable
    -- prefix of the localised string; if a translator drops the prefix
    -- the auto-fix simply doesn't trigger and the user gets the manual
    -- /run hint as before — not a regression.
    local isAutoFixableIssue = GSE.IsAutoFixableSequenceIssue

    -- 1. Structural / content checks on GSE.Library (all class IDs, including 0 = global)
    for classlibid = 0, 13 do
        GSE.EnsureClassLoaded(classlibid)
        local classlib = GSE.Library[classlibid]
        if classlib and type(classlib) == "table" then
            for id, seq in pairs(classlib) do
                local seqname = GSE.SequenceName(id, classlibid) or tostring(id)
                local issues = checkSeqStructure(classlibid, seqname, seq)

                -- Partition issues into auto-fixable vs. the rest. If
                -- any are auto-fixable, run FixSequenceStructure silently
                -- once for the whole sequence (the fix re-keys Versions
                -- end-to-end, which addresses every auto-fixable issue
                -- at once) and re-scan to surface anything that didn't
                -- get cleaned up by the repair.
                local hadAutoFixable = false
                for _, issue in ipairs(issues) do
                    if isAutoFixableIssue(issue) then hadAutoFixable = true; break end
                end
                if hadAutoFixable then
                    if GSE.FixSequenceStructure(classlibid, id, true) then
                        autoFixedCount = autoFixedCount + 1
                        -- Re-fetch the sequence post-repair and re-scan
                        -- so the rest of this iteration sees the repaired
                        -- shape, not the broken one we entered with.
                        seq = GSE.Library[classlibid] and GSE.Library[classlibid][id]
                        issues = seq and checkSeqStructure(classlibid, seqname, seq) or {}
                    end
                end

                if #issues > 0 then
                    totalIssues = totalIssues + #issues
                    GSE.Print(
                        string.format(L["Issues found in '%s' (class library %d):"], seqname, classlibid),
                        "Error"
                    )
                    for _, issue in ipairs(issues) do
                        GSE.Print("  - " .. issue)
                    end
                    GSE.Print(
                        string.format(
                            L["To attempt automatic repair run: %s/gse fixsequence %d %s%s"],
                            GSEOptions.CommandColour,
                            classlibid,
                            seqname,
                            Statics.StringReset
                        )
                    )
                end

                -- Runtime compile check for each reachable Macro version
                if type(seq) == "table" and type(seq.Versions) == "table" then
                    for macvidx, macroversion in ipairs(seq.Versions) do
                        if type(macroversion) == "table" and type(macroversion.Actions) == "table" then
                            local ok, result = pcall(GSE.CompileTemplate, macroversion)
                            if not ok then
                                totalIssues = totalIssues + 1
                                GSE.Print(
                                    string.format(
                                        L["Compile error in Macros[%d] of '%s': %s"],
                                        macvidx, seqname, tostring(result)
                                    ),
                                    "Error"
                                )
                            elseif type(result) == "table" then
                                -- Check for steps that would encode to an empty string.
                                -- This happens when GetSpellId returns nil (e.g. after
                                -- resurrection/phasing), leaving a step with only blockPath.
                                -- Such steps crash inside the secure Execute string with
                                -- "attempt to perform arithmetic on local 'sa' (a nil value)".
                                for stepIdx, step in ipairs(result) do
                                    local hasField = false
                                    for k, _ in pairs(step) do
                                        if k ~= "blockPath" then
                                            hasField = true
                                            break
                                        end
                                    end
                                    if not hasField then
                                        totalIssues = totalIssues + 1
                                        GSE.Print(
                                            string.format(
                                                L["Empty step at index %d in Macros[%d] of '%s': spell ID lookup may have failed"],
                                                stepIdx, macvidx, seqname
                                            ),
                                            "Error"
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Name collision checks (WW / PVP clash with WoW built-ins)
    for classlibid = 0, 13 do
        local classlib = GSE.Library[classlibid]
        if classlib and type(classlib) == "table" then
            for id, seq in pairs(classlib) do
                -- The label, else the name the loaded copy carries (a sealed
                -- sequence with no stored body has no envelope to ask).
                local seqname = GSE.SequenceName(id, classlibid)
                    or (type(seq) == "table" and type(seq.MetaData) == "table" and seq.MetaData.Name)
                if seqname == "WW" then
                    GSE.Print(
                        string.format(
                            L[
                                "Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."
                            ],
                            GSEOptions.CommandColour,
                            Statics.StringReset
                        ),
                        "Error"
                    )
                elseif seqname == "PVP" then
                    GSE.Print(
                        string.format(
                            L[
                                "Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."
                            ],
                            GSEOptions.CommandColour,
                            Statics.StringReset
                        ),
                        "Error"
                    )
                end
            end
        end
    end

    -- 3. Dependency checks: missing variables and sequences
    for classlibid = 0, 13 do
        local classlib = GSE.Library[classlibid]
        if classlib and type(classlib) == "table" then
            for id, seq in pairs(classlib) do
                local seqname = GSE.SequenceName(id, classlibid) or tostring(id)
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps then
                        -- Check variable dependencies
                        if type(deps.Variables) == "table" then
                            for _, vname in ipairs(deps.Variables) do
                                if GSE.isEmpty(GSE.Store("variable")) or GSE.isEmpty(GSE.Store("variable")[vname]) then
                                    totalIssues = totalIssues + 1
                                    GSE.Print(
                                        string.format(
                                            L["Sequence '%s' (class %d) depends on variable '%s' which does not exist."],
                                            seqname, classlibid, vname
                                        ),
                                        "Error"
                                    )
                                end
                            end
                        end
                        -- Check embedded sequence dependencies
                        if type(deps.Sequences) == "table" then
                            for _, depseq in ipairs(deps.Sequences) do
                                -- An Embed names what it embeds; any class will do.
                                local found = GSE.FindSequenceId(depseq, nil, true) ~= nil
                                if not found then
                                    totalIssues = totalIssues + 1
                                    GSE.Print(
                                        string.format(
                                            L["Sequence '%s' (class %d) embeds sequence '%s' which does not exist."],
                                            seqname, classlibid, depseq
                                        ),
                                        "Error"
                                    )
                                end
                            end
                        end
                        -- Check WoW macro dependencies (only if WoW API is available)
                        if type(deps.Macros) == "table" and GetMacroIndexByName then
                            for _, macname in ipairs(deps.Macros) do
                                local slot = GetMacroIndexByName(macname)
                                local inStore = not GSE.isEmpty(GSE.Store("macro")) and not GSE.isEmpty(GSE.Store("macro")[macname])
                                if (not slot or slot == 0) and not inStore then
                                    totalIssues = totalIssues + 1
                                    GSE.Print(
                                        string.format(
                                            L["Sequence '%s' (class %d) depends on macro '%s' which does not exist."],
                                            seqname, classlibid, macname
                                        ),
                                        "Error"
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 4. Variable dependency checks
    if not GSE.isEmpty(GSE.Store("variable")) then
        for vname, vdata in pairs(GSE.Store("variable")) do
            local ok, decoded = GSE.DecodeMessage(vdata)
            if ok and decoded and decoded.Dependencies and type(decoded.Dependencies.Variables) == "table" then
                for _, depname in ipairs(decoded.Dependencies.Variables) do
                    if GSE.isEmpty(GSE.Store("variable")[depname]) then
                        totalIssues = totalIssues + 1
                        GSE.Print(
                            string.format(
                                L["Variable '%s' depends on variable '%s' which does not exist."],
                                vname, depname
                            ),
                            "Error"
                        )
                    end
                end
            end
        end
    end

    -- 5. Icon coverage check: report Action blocks whose icon cannot be determined.
    --    These are cosmetic warnings (not functional errors) but help authors notice
    --    that a block will show '?' in the editor.  Pet-ability blocks are skipped
    --    because no client-side icon lookup is available for pet abilities.
    do
        for classlibid = 0, 13 do
            local classlib = GSE.Library[classlibid]
            if classlib and type(classlib) == "table" then
                for id, seq in pairs(classlib) do
                    local seqname = GSE.SequenceName(id, classlibid) or tostring(id)
                    if type(seq) == "table" and type(seq.Versions) == "table" then
                        for vidx, macroversion in ipairs(seq.Versions) do
                            if type(macroversion) == "table" and type(macroversion.Actions) == "table" then
                                for bidx, action in ipairs(macroversion.Actions) do
                                    if action.Type == "Action" and action.type ~= "pet" and not action.Icon then
                                        local hasIcon = false
                                        if action.type == "spell" then
                                            local si = action.spell and GSE.GetSpellInfo(action.spell)
                                            hasIcon = si and si.iconID ~= nil
                                        elseif action.type == "item" or action.type == "toy" then
                                            local key = action.item or action.toy
                                            hasIcon = key and select(10, C_Item.GetItemInfo(key)) ~= nil
                                        elseif action.type == "macro" or GSE.isEmpty(action.type) then
                                            local macro = action.macro and GSE.UnEscapeString(action.macro) or ""
                                            if string.sub(macro, 1, 1) == "/" then
                                                local ss = GSE.GetSpellsFromString(macro)
                                                hasIcon = ss ~= nil and (ss.iconID ~= nil or #ss > 0)
                                            elseif string.sub(macro, 1, 1) == "=" then
                                                -- Variable reference: check the compiled output
                                                local ok, compiled = pcall(GSE.CompileMacroText, macro, Statics.TranslatorMode.String)
                                                if ok and compiled then
                                                    compiled = GSE.UnEscapeString(compiled)
                                                    if string.sub(compiled, 1, 1) == "/" then
                                                        local ss = GSE.GetSpellsFromString(compiled)
                                                        hasIcon = ss ~= nil and (ss.iconID ~= nil or #ss > 0)
                                                    end
                                                end
                                            elseif macro ~= "" then
                                                -- External WoW macro name
                                                if GetMacroIndexByName then
                                                    local midx = GetMacroIndexByName(macro)
                                                    local _, micon = GetMacroInfo(midx)
                                                    hasIcon = micon ~= nil
                                                end
                                            end
                                        end
                                        if not hasIcon then
                                            totalIssues = totalIssues + 1
                                            GSE.Print(
                                                string.format(
                                                    L["Sequence '%s' (class %d) version %d block %d has no icon set (showing ?).  Open the block in the editor and assign an icon."],
                                                    seqname, classlibid, vidx, bidx
                                                )
                                            )
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 6. Stored-body encoding check (existing behaviour: remove malformed entries)
    for classlibid = 0, 13 do
        local bad = {}
        for id, env in pairs(GSE.SequenceEnvelopes(classlibid)) do
            if type(env.Body) == "string" and string.sub(env.Body, 1, 6) ~= "!GSE3!" then
                bad[#bad + 1] = id
            end
        end
        for _, id in ipairs(bad) do
            local label = GSE.SequenceName(id, classlibid) or tostring(id)
            GSE.RemoveSequence(classlibid, id)
            GSE.Print(L["Removed unreadable sequence "] .. label, Statics.DebugModules["Storage"])
        end
    end

    if autoFixedCount > 0 then
        GSE.Print(string.format(
            L["Auto-repaired %d sequence(s) with structurally invalid Versions (index-0 keys remapped to 1-based)."],
            autoFixedCount))
    end

    -- 7. Final save pass: hydrate action icons across every loaded class and
    --    persist resolved iconIDs to the saved variable. Runs LAST so any
    --    modifications made by sections 1-6 (auto-repairs, encoding cleanup)
    --    are also caught by this commit. Equivalent to /gsesaveallsequences.
    if GSE.SaveAllSequenceActionIcons then
        GSE.SaveAllSequenceActionIcons()
    end

    if totalIssues == 0 then
        GSE.Print(L["Finished scanning for errors.  If no other messages then no errors were found."])
    else
        GSE.Print(string.format(L["%d issue(s) found.  See above for details and fix commands."], totalIssues))
    end

    -- Offer interactive dialogs for any sequences that could not be decoded at all.
    if not GSE.isEmpty(GSE.CorruptSequences) then
        GSE.ProcessCorruptSequences()
    end
end

--- Recursively replaces Java-style // comment lines with -- in all action macro fields.
local function applyJavaCommentFix(actionList)
    for _, action in pairs(actionList) do
        if type(action) == "table" then
            if type(action.macro) == "string" then
                local lines = {}
                for line in (action.macro .. "\n"):gmatch("([^\n]*)\n") do
                    lines[#lines + 1] = line:gsub("^(%s*)//", "%1--")
                end
                if lines[#lines] == "" then table.remove(lines) end
                action.macro = table.concat(lines, "\n")
            end
            -- Recurse into nested numeric sub-tables (Loop children, If branches)
            for k, v in pairs(action) do
                if type(k) == "number" and type(v) == "table" then
                    applyJavaCommentFix(v)
                end
            end
        end
    end
end

--- Repairs structural issues in a sequence in GSE.Library:
-- 1. Clears OOC queue entries for the sequence
-- 2. Migrates pre-#1853 Macros field to Versions
-- 3. Converts Java-style // comment lines to -- in all action macro text
-- 4. Re-indexes the Macros array to remove numeric gaps
-- 5. Re-indexes each Macro version's Actions array to remove gaps
-- 6. Updates MetaData context version references to match the new indices
-- 7. Saves the repaired sequence and queues a recompile
-- Takes the sequence's id, or its name (the slash command passes a name).
-- Usage: /gse fixsequence <classLibraryID> <SequenceName>  (the slash command
-- is the only reachable route: GSE is private and _G.GSE is the plugin proxy)
-- silent: when true, suppress informational/success prints. Errors
-- (invalid class id, missing sequence, schema-incompatible) still print
-- because they signal the caller's request couldn't be honoured. Used
-- by GSE.ScanMacrosForErrors's auto-repair path so the user gets one
-- summary line rather than per-sequence chatter.
function GSE.FixSequenceStructure(classlibid, ref, silent)
    classlibid = tonumber(classlibid)
    if not classlibid or not GSE.Library[classlibid] then
        GSE.Print(string.format(L["Invalid class library ID: %s"], tostring(classlibid)))
        return false
    end
    local id = ref
    if not GSE.SequenceEnvelope(ref, classlibid) then id = GSE.FindSequenceId(ref, classlibid) or ref end
    local seqname = GSE.SequenceName(id, classlibid) or tostring(ref)
    GSE.EnsureSequenceLoaded(classlibid, id)
    local seq = GSE.Library[classlibid][id]
    if GSE.isEmpty(seq) then
        GSE.Print(string.format(L["Sequence '%s' not found in class library %d."], seqname, classlibid))
        return false
    end

    -- 1. Remove any pending OOC queue entries for this sequence
    local kept = {}
    for _, entry in ipairs(GSE.OOCQueue) do
        -- Queued for this sequence: by its id, or -- an import not yet filed --
        -- by its name.
        local forThis = entry.id == id or (entry.id == nil and entry.sequencename == seqname)
        if not forThis then
            table.insert(kept, entry)
        end
    end
    local removed = #GSE.OOCQueue - #kept
    GSE.OOCQueue = kept
    if removed > 0 and not silent then
        GSE.Print(string.format(L["Cleared %d pending queue entries for '%s'."], removed, seqname))
    end

    -- 2. Refuse to repair pre-#1853 records that still carry "Macros".
    -- The auto-rename is retired; user must re-export through gse.tools
    -- to get the current schema, then re-import.
    if seq.Macros ~= nil and seq.Versions == nil then
        GSE.Print(string.format(
            L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
            seqname), L["Import"])
        return false
    end

    -- 3. Replace Java-style // comment lines with -- in all action macro text
    for _, macver in pairs(seq.Versions or {}) do
        if type(macver) == "table" and type(macver.Actions) == "table" then
            applyJavaCommentFix(macver.Actions)
        end
    end

    -- 4. Re-index Macros array (compact gaps into a clean 1..n sequence).
    -- Includes k == 0 deliberately: a Versions table that starts at [0]
    -- (e.g. from a bad in-game merge or a CBOR round-trip that preserved
    -- 0-based keys) is invisible to ipairs and reads as "no versions" in
    -- the editor and runtime. The previous filter `k >= 1` would have
    -- silently DROPPED such entries; mapping 0→1 instead recovers them.
    if type(seq.Versions) == "table" then
        local oldMacroKeys = {}
        for k in pairs(seq.Versions) do
            if type(k) == "number" and k >= 0 then
                table.insert(oldMacroKeys, k)
            end
        end
        table.sort(oldMacroKeys)

        -- Build old→new index mapping and compacted Macros table
        local macroIndexMap = {}
        local newMacros = {}
        for newIdx, oldIdx in ipairs(oldMacroKeys) do
            macroIndexMap[oldIdx] = newIdx
            newMacros[newIdx] = seq.Versions[oldIdx]
        end
        seq.Versions = newMacros

        -- 5. Re-index Actions arrays within each Macro version
        for _, macroversion in ipairs(seq.Versions) do
            if type(macroversion) == "table" and type(macroversion.Actions) == "table" then
                local oldActKeys = {}
                for k in pairs(macroversion.Actions) do
                    if type(k) == "number" and k >= 1 then
                        table.insert(oldActKeys, k)
                    end
                end
                table.sort(oldActKeys)

                local newActions = {}
                for newIdx, oldIdx in ipairs(oldActKeys) do
                    newActions[newIdx] = macroversion.Actions[oldIdx]
                end
                macroversion.Actions = newActions
            end
        end

        -- 6. Update MetaData context version references using the old→new mapping
        local maxNewIdx = #seq.Versions
        for _, ctxKey in ipairs(seqContextKeys) do
            local val = seq.MetaData[ctxKey]
            if not GSE.isEmpty(val) then
                local oldIdx = tonumber(val)
                if oldIdx then
                    if macroIndexMap[oldIdx] then
                        seq.MetaData[ctxKey] = macroIndexMap[oldIdx]
                    else
                        -- Was pointing to a gap or beyond the end; clamp to max valid index
                        local clamped = maxNewIdx > 0 and maxNewIdx or nil
                        if not silent then
                            GSE.Print(string.format(
                                L["MetaData.%s remapped from non-existent version %d to %d."],
                                ctxKey, oldIdx, clamped or 0
                            ))
                        end
                        seq.MetaData[ctxKey] = clamped
                    end
                end
            end
        end
    end

    -- 7. Save repaired sequence and trigger recompile
    GSE.ReplaceSequence(classlibid, id, seq)
    if classlibid == GSE.GetCurrentClassID() or classlibid == 0 then
        GSE.ReloadSequences()
        if not silent then
            GSE.Print(string.format(
                L["'%s' has been repaired and queued for recompile.  Leave combat or /reload to apply."],
                seqname
            ))
        end
    else
        if not silent then
            GSE.Print(string.format(
                L["'%s' repaired. Sequence is for class %d; button will update when that class is played."],
                seqname, classlibid
            ))
        end
    end
    return true
end

--- This creates a pretty export for WLM Forums
function GSE.ExportSequenceHumanReadableFormat(sequence, sequencename)
    local returnstring =
        "# " ..
        sequencename ..
            "\n\n## Talents: " ..
                (GSE.isEmpty(sequence["MetaData"].Talents) and "?,?,?,?,?,?,?" or GSE.Dump(sequence["MetaData"].Talents)) ..
                    "\n\n"
    if not GSE.isEmpty(sequence["MetaData"].Help) then
        returnstring = "\n\n## Usage Information\n" .. sequence["MetaData"].Help .. "\n\n"
    end
    returnstring =
        returnstring ..
        "This macro contains " ..
            (#sequence.Versions > 1 and #sequence.Versions .. " macro templates. " or "1 macro template. ") ..
                string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. "\n\n"
    if (#sequence.Versions > 1) then
        for k, _ in pairs(sequence.Versions) do
            if not GSE.isEmpty(sequence["MetaData"].Default) then
                if sequence["MetaData"].Default == k then
                    returnstring = returnstring .. "- The Default macro template is " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Raid) then
                if sequence["MetaData"].Raid == k then
                    returnstring = returnstring .. "- Raids use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].PVP) then
                if sequence["MetaData"].PVP == k then
                    returnstring = returnstring .. "- PVP uses template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Dungeon) then
                if sequence["MetaData"].Dungeon == k then
                    returnstring = returnstring .. "- Normal Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Heroic) then
                if sequence["MetaData"].Heroic == k then
                    returnstring = returnstring .. "- Heroic Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Mythic) then
                if sequence["MetaData"].Mythic == k then
                    returnstring = returnstring .. "- Mythic Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Arena) then
                if sequence["MetaData"].Arena == k then
                    returnstring = returnstring .. "- Arenas use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Timewalking) then
                if sequence["MetaData"].Timewalking == k then
                    returnstring = returnstring .. "- Timewalking Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].MythicPlus) then
                if sequence["MetaData"].MythicPlus == k then
                    returnstring = returnstring .. "- Mythic+ Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Party) then
                if sequence["MetaData"].Party == k then
                    returnstring = returnstring .. "- Open World Parties use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Scenario) then
                if sequence["MetaData"].Scenario == k then
                    returnstring = returnstring .. "- Delves and Scenarios use template " .. k .. "\n"
                end
            end
        end
    end

    return returnstring
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequence(sequence, sequenceName, verbose)
    local returnVal
    if verbose then
        --@debug@
        GSE.PrintDebugMessage("ExportSequence Sequence Name: " .. sequenceName, "Storage")
        --@end-debug@
        returnVal = GSE.Dump(GSE.UnEscapeTable(GSE.TranslateSequence(sequence, Statics.TranslatorMode.Current))) .. "\n"
    else
        returnVal =
            GSE.EncodeMessage(
            {sequenceName, GSE.UnEscapeTable(GSE.TranslateSequence(sequence, Statics.TranslatorMode.ID))}
        )
    end

    return returnVal
end

function GSE.PrintGnomeHelp()
    GSE.Print(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
    GSE.Print(
        L[
            "GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."
        ],
        GNOME
    )
    GSE.Print(
        L[
            "Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."
        ],
        GNOME
    )
    GSE.Print(
        L[
            "This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."
        ],
        GNOME
    )
    GSE.Print(
        L["To get started "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse|r will list any sequences available to your spec.  This will also add an in-game macro for each sequence available to your current spec to the macro interface."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                "/gse showspec|r will show your current Specialisation and the SPECID needed to tag any existing sequences."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse checksequencesforerrors|r will loop through your sequences and check for corrupt sequence versions.  This will then show how to correct these issues."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse clearincoming|r will abort any pending GSE Companion updates without importing them, and tell the Companion to prune them."
                ],
        GNOME
    )
    GSE.Print(
        GSEOptions.CommandColour ..
            L[
                "GSE registers additional subcommands of /gse: /gse resettracker (restore the tracker to its default layout), /gse savelayoutx and /gse savelayouty (save the current tracker layout to slot X or Y), /gse applylayoutx and /gse applylayouty (apply a saved layout), /gse iconscan and /gse spelliconreset and /gse saveallsequences (action-icon maintenance)."
            ],
        GNOME
    )
end

SLASH_GSE1 = "/gse"
SlashCmdList.GSE = function(input)
    GSE:GSSlash(input)
end

-- Functions

--- Drain the entire incoming queue. Marks every pending item as imported so
--- the Companion prunes them on its side, then empties the local table.
--- Shared by /gse clearincoming and the queue-manager UI.
function GSE.ClearIncomingQueue()
    local pending = GSE.IncomingQueue or {}
    local count = #pending
    if GSE.CompanionMarkImported then
        for _, item in ipairs(pending) do
            GSE.CompanionMarkImported(item)
        end
    end
    GSE.IncomingQueue = {}
    if GSE.GUIImportFrame then GSE.GUIImportFrame:Hide() end
    GSE.Print(
        "|cff00ccffGSE Companion:|r Cleared " .. count ..
        " pending update(s) from the incoming queue."
    )
    return count
end

--- Remove a single incoming-queue entry by index (1-based). Marks it as
--- imported on the Companion side so the same payload doesn't re-sync, then
--- drops it from the local queue. Returns true on success.
function GSE.RemoveIncomingQueueEntry(index)
    if not (GSE.IncomingQueue and GSE.IncomingQueue[index]) then return false end
    local item = GSE.IncomingQueue[index]
    if GSE.CompanionMarkImported then
        GSE.CompanionMarkImported(item)
    end
    table.remove(GSE.IncomingQueue, index)
    return true
end

--- A sequence by its label: the current class first, then global, then any
-- other class. For names a user or an Embed supplies; anything that already
-- holds an id uses GSE.GetSequence. Returns the sequence and its id.
function GSE.FindSequence(sequenceName)
    local id, classid = GSE.FindSequenceId(sequenceName)
    if not id then id, classid = GSE.FindSequenceId(sequenceName, nil, true) end
    if not id then return nil end
    return GSE.GetSequence(id, classid), id
end

--- Handle slash commands
function GSE:GSSlash(input)
    local _, _, currentclassId = UnitClass("player")
    local params = GSE.split(input, " ")
    if #params > 1 then
        input = params[1]
    end
    local command = string.lower(input)
    if command == "showspec" then
        if GSE.GameMode < 7 then
            GSE.Print(L["Your ClassID is "] .. currentclassId .. " " .. Statics.SpecIDList[currentclassId], GNOME)
        else
            local currentSpecID = GSE.GetCurrentSpecID()
            local _, specname, _, _, _, _, _ = GetSpecializationInfoByID(currentSpecID)
            specname = specname or "None"
            GSE.Print(
                L["Your current Specialisation is "] ..
                    currentSpecID .. ":" .. specname .. L["  The Alternative ClassID is "] .. currentclassId,
                GNOME
            )
        end
    elseif command == "help" then
        GSE.PrintGnomeHelp()
    elseif command == "forceclean" then
        GSE.CleanMacroLibrary(true)
        if not InCombatLockdown() then
            if not GSE.isEmpty(GSE_C["KeyBindings"]) then
                for _, specData in pairs(GSE_C["KeyBindings"]) do
                    for key, _ in pairs(specData) do
                        if key ~= "LoadOuts" then SetBinding(key) end
                    end
                    if not GSE.isEmpty(specData["LoadOuts"]) then
                        for _, loadoutData in pairs(specData["LoadOuts"]) do
                            for key, _ in pairs(loadoutData) do SetBinding(key) end
                        end
                    end
                end
            end
            GSE_C["KeyBindings"] = {}
            GSE_C["ActionBarBinds"] = {}
            GSE.ReloadOverrides()
        end
    elseif command == "export" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] and GSE.GUIAdvancedExport then
            GSE.GUIAdvancedExport(GSE.GUIExportframe)
            GSE.GUIExportframe:Show()
        end
    elseif command == "showdebugoutput" then
        GSE.GUICall("GUIShowDebugOutput")
    elseif command == "record" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUIRecordFrame:Show()
        end
    elseif command == "debug" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUIShowDebugWindow()
        end
    elseif command == "variables" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.ShowVariables()
        end
    elseif command == "options" or command == "config" then
        if GSE.OpenOptionsPanel then
            GSE.OpenOptionsPanel()
        else
            GSE.Print(L["Options Not Enabled"])
        end
    elseif command == "resetoptions" then
        GSE.SetDefaultOptions()
        GSE.Print(L["Options have been reset to defaults."])
        GSE.GUICall("GUIConfirmReloadUI")
    elseif command == "movelostmacros" then
        GSE.MoveMacroToClassFromGlobal()
    elseif command == "checksequencesforerrors" then
        GSE.ScanMacrosForErrors()
    elseif command == "fixsequence" then
        -- The repair the error report points at. It has to be reachable from a
        -- slash command: GSE is the addon's private namespace and the only
        -- global is the locked plugin proxy (API/Plugins.lua), which carries
        -- RegisterAddon, GetSequenceNamesFromLibrary and isEmpty and nothing
        -- else. So the old advice -- /run GSE.FixSequenceStructure(...) --
        -- found the proxy, found no such field, and answered "attempt to call
        -- a nil value" for everyone who tried it.
        --
        -- The name is everything after the class id, unsplit: sequence names
        -- contain spaces and params splits on them.
        local classid = tonumber(params[2])
        local seqname = nil
        if #params > 2 then
            seqname = table.concat(params, " ", 3)
        end
        if not classid or GSE.isEmpty(seqname) then
            GSE.Print(L["Usage: /gse fixsequence <classid> <sequence name>"], GNOME)
        elseif not GSE.FindSequenceId(seqname, classid) then
            GSE.Print(string.format(L["No sequence '%s' in class library %d."], seqname, classid), GNOME)
        else
            GSE.FixSequenceStructure(classid, seqname)
        end
    elseif command == "scanicons" then
        if GSE.ScanSequenceActionIcons then
            GSE.ScanSequenceActionIcons()
        else
            GSE.Print("GSE icon scan is unavailable. Make sure GSE_GUI is loaded, then /reload.")
        end
    --@debug@
    elseif command == "compressstring" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUICompressFrame:Show()
        end
    --@end-debug@
    elseif command == "recompilesequences" then
        GSE.ReloadSequences()
    elseif string.lower(command) == "clearoocqueue" then
        GSE.OOCQueue = {}
    elseif string.lower(command) == "clearincoming" then
        GSE.ClearIncomingQueue()
    elseif string.lower(command) == "incoming" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] and GSE.ShowIncomingQueueManager then
            GSE.ShowIncomingQueueManager()
        end
    elseif string.lower(command) == "import" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.ShowImport()
        end
    elseif string.lower(command) == "bind" then
        -- /gse bind spec sequence key
        local spec = tostring(params[2])
        local sequence = tostring(params[3])
        local physicalkey = tostring(params[4])
        if spec and sequence and physicalkey then
            GSE_C["KeyBindings"][tostring(spec)][physicalkey] = sequence
            GSE.ReloadKeyBindings()
        else
           GSE.Print("Invalid Bind - /gse bind spec sequence key")
        end

    -- ----------------------------------------------------------------
    -- Icon-resolver commands. Reach back into Editor.lua-owned routines
    -- via the GSE.* namespace; the `if GSE.X then` guards are defensive
    -- against a layered build that ships without GSE_GUI.
    -- ----------------------------------------------------------------
    elseif command == "spelliconreset" then
        if GSE.ResetAllSequenceActionIcons then GSE.ResetAllSequenceActionIcons() end
    elseif command == "iconscan" then
        if GSE.ScanSequenceActionIcons then GSE.ScanSequenceActionIcons() end
    elseif command == "saveallsequences" then
        if GSE.SaveAllSequenceActionIcons then GSE.SaveAllSequenceActionIcons() end

    -- ----------------------------------------------------------------
    -- Tracker layout slot save / apply. Backed by routines defined in
    -- GSE_Utils/Tracker.lua. Layout slots X and Y are independent.
    -- ----------------------------------------------------------------
    elseif command == "savelayoutx" then
        if GSE.SequenceIconSaveLayout and GSE.SequenceIconSaveLayout("X") then
            GSE.Print("Tracker Layout X saved with the current positions and configuration.")
        end
    elseif command == "savelayouty" then
        if GSE.SequenceIconSaveLayout and GSE.SequenceIconSaveLayout("Y") then
            GSE.Print("Tracker Layout Y saved with the current positions and configuration.")
        end
    elseif command == "applylayoutx" then
        if GSE.SequenceIconApplyLayout and GSE.SequenceIconApplyLayout("X") then
            GSE.Print("Tracker Layout X applied.")
        else
            GSE.Print("Tracker Layout X is not saved. Save it first with /gse savelayoutx.")
        end
    elseif command == "applylayouty" then
        if GSE.SequenceIconApplyLayout and GSE.SequenceIconApplyLayout("Y") then
            GSE.Print("Tracker Layout Y applied.")
        else
            GSE.Print("Tracker Layout Y is not saved. Save it first with /gse savelayouty.")
        end

    -- ----------------------------------------------------------------
    -- Tracker defaults. Chat-side equivalent of the Options panel's
    -- "Restore Defaults" button. Safe to call any time -- does not
    -- touch saved layout slots X or Y.
    -- ----------------------------------------------------------------
    elseif command == "resettracker" then
        if GSE.ResetTrackerToDefaultLayout then
            GSE.ResetTrackerToDefaultLayout()
            GSE.Print("Tracker reset to the default layout.")
        end

    -- ----------------------------------------------------------------
    -- Widget pool kill switch, for reproducing and bisecting recycled-
    -- widget bugs. Replaces `/run GSE_NoWidgetPool = true`: a loose
    -- global that had to be re-set after every /reload and existed
    -- nowhere in the addon's own surface. Stored in GSEOptions so it
    -- survives a reload, which is what a soak test actually needs.
    -- ----------------------------------------------------------------
    elseif command == "widgetpool" then
        local arg = params[2] and string.lower(params[2]) or nil
        if not GSEOptions then
            GSE.Print("Options are not loaded yet. Try again once you are in the world.")
        elseif arg == "on" or arg == "off" then
            GSEOptions.NoWidgetPool = (arg == "off")
            GSE.Print(
                "Widget pool " .. (arg == "off" and "DISABLED" or "enabled") ..
                ". /reload for a clean pool state."
            )
        else
            GSE.Print(
                "Widget pool is " ..
                (GSEOptions.NoWidgetPool and "DISABLED" or "enabled") ..
                ". Use /gse widgetpool on|off."
            )
        end

    -- Sibling switch: the editor draws blocks with layout batched per chunk.
    -- Turning it off is the other half of bisecting a draw-path bug.
    elseif command == "layoutbatch" then
        local arg = params[2] and string.lower(params[2]) or nil
        if not GSEOptions then
            GSE.Print("Options are not loaded yet. Try again once you are in the world.")
        elseif arg == "on" or arg == "off" then
            GSEOptions.NoLayoutBatch = (arg == "off")
            GSE.Print(
                "Editor layout batching " .. (arg == "off" and "DISABLED" or "enabled") ..
                ". Reopen the editor to apply."
            )
        else
            GSE.Print(
                "Editor layout batching is " ..
                (GSEOptions.NoLayoutBatch and "DISABLED" or "enabled") ..
                ". Use /gse layoutbatch on|off."
            )
        end

    else
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            -- Route to Editor when the Toolbar is disabled (see Options.lua's
            -- "GSE Toolbar ON / OFF" checkbox). Default ToolbarEnabled=true.
            if GSEOptions and GSEOptions.ToolbarEnabled == false then
                -- 1) An editor already exists this session. With multi-window
                --    support each /gse opens an ADDITIONAL editor window; without
                --    it, CreateEditor returns the single shared editor, so just
                --    bring the existing one forward.
                if GSE.GUI and GSE.GUI.editors and #GSE.GUI.editors > 0 then
                    local multiWindow = GSE.CanMultiWindow and GSE.CanMultiWindow()
                    if multiWindow and GSE.ShowSequences then
                        -- Open an additional editor window.
                        GSE.ShowSequences()
                    else
                        local existing = GSE.GUI.editors[#GSE.GUI.editors]
                        if existing and existing.Show then existing:Show() end
                    end
                    return
                end

                -- 2) No editor exists yet. On the FIRST /gse this session,
                --    GSE.CheckGUI() above just lazy-loaded GSE_GUI which
                --    queued Editor.lua's RestoreSequenceEditorIfNeeded for
                --    the next tick. If the user had the editor open last
                --    session (seOpts.open=true), that restore WILL create
                --    one — calling ShowSequences here would create a 2nd.
                --    Detect "restore is pending" via the saved open state
                --    AND a flag the restore sets after it runs. If pending,
                --    let the restore handle it.
                local seOpts = GSEOptions and GSEOptions.frameLocations
                    and GSEOptions.frameLocations.sequenceeditor
                local restorePending = seOpts and seOpts.open
                    and not GSE.SequenceEditorRestoreFired
                if restorePending then
                    return
                end

                -- 3) Restore either won't fire (seOpts.open false) or
                --    already fired without producing an editor (e.g. it
                --    ran but the user X-closed it since) — safe to create
                --    one ourselves now, synchronously.
                if GSE.ShowSequences then GSE.ShowSequences() end
            else
                GSE.ShowMenu()
            end
        end
    end
end

local colorTable = {}

local tokens = IndentationLib.tokens

colorTable[tokens.TOKEN_SPECIAL] = GSEOptions.WOWSHORTCUTS
colorTable[tokens.TOKEN_KEYWORD] = GSEOptions.KEYWORD
colorTable[tokens.TOKEN_UNKNOWN] = GSEOptions.UNKNOWN
colorTable[tokens.TOKEN_COMMENT_SHORT] = GSEOptions.COMMENT
colorTable[tokens.TOKEN_COMMENT_LONG] = GSEOptions.COMMENT

local stringColor = GSEOptions.NormalColour
colorTable[tokens.TOKEN_STRING] = stringColor
colorTable[".."] = stringColor

local tableColor = GSEOptions.CONCAT
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = GSEOptions.STRING
colorTable["]"] = GSEOptions.STRING

local arithmeticColor = GSEOptions.NUMBER
colorTable[tokens.TOKEN_NUMBER] = arithmeticColor
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor

local logicColor1 = GSEOptions.EQUALS
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1

local logicColor2 = GSEOptions.EQUALS
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2

local castColor = GSEOptions.UNKNOWN
colorTable["/cast"] = castColor

colorTable[0] = "|r"

Statics.IndentationColorTable = colorTable

do
    -- Shared handler: right-click on a GSE-overridden button shows change/clear options;
    -- right-click on an empty action button shows the sequence picker to assign one.
    local function gseEmptyButtonHandler(self, mousebutton, down)
        if not GSEOptions.actionBarOverridePopup then return end
        if InCombatLockdown() then return end
        if mousebutton ~= "RightButton" then return end
        if down then
            self.gseABMenuDown = true
        elseif self.gseABMenuDown then
            self.gseABMenuDown = nil
            return
        end

        local existingSequence = self:GetAttribute("gse-button")

        if not existingSequence then
            -- Only show the picker on genuinely empty slots.
            -- CPB_ (ConsolePort) buttons are controller-mapped, not slot-based; skip the action check.
            if string.sub(self:GetName() or "", 1, 4) ~= "CPB_" then
                local action = self.action or self:GetAttribute("action")
                if not action or action == 0 then return end
                if HasAction(action) then return end
            end
        end

        local classIconText = ""
        local classInfo = C_CreatureInfo.GetClassInfo(GSE.GetCurrentClassID())
        if classInfo and classInfo.classFile then
            classIconText = "|A:classicon-" .. classInfo.classFile:lower() .. ":16:16|a "
        end

        local names = {}
        local function addSequences(classID)
            for k, seq in pairs(GSE.Library[classID] or {}) do
                local specID = seq and seq.MetaData and seq.MetaData.SpecID
                local disabled = seq and seq.MetaData and seq.MetaData.Disabled
                table.insert(names, { id = k, name = GSE.SequenceName(k, classID) or tostring(k),
                    specID = specID, disabled = disabled })
            end
        end
        addSequences(GSE.GetCurrentClassID())
        addSequences(0)

        table.sort(names, function(a, b) return a.name < b.name end)

        local buttonName = self:GetName()
        MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
            if existingSequence then
                -- gse-button is the sequence's button; show its label.
                local existingId = GSE.SequenceIdForButton(existingSequence)
                rootDescription:CreateTitle(L["GSE"] .. ": "
                    .. (existingId and GSE.SequenceName(existingId) or existingSequence))
                rootDescription:CreateButton(L["Clear Override"], function()
                    GSE.RemoveActionBarOverride(buttonName)
                end)
                if #names > 0 then
                    rootDescription:CreateDivider()
                    rootDescription:CreateTitle(L["Change Sequence"])
                end
            else
                rootDescription:CreateTitle(L["Assign GSE Sequence"])
            end
            for _, entry in ipairs(names) do
                local iconText = classIconText
                local specID = entry.specID
                if specID and specID >= 15 then
                    local _, _, _, specIconID = GetSpecializationInfoByID(specID)
                    if specIconID then
                        iconText = "|T" .. specIconID .. ":16:16|t "
                    end
                end
                local label = iconText .. entry.name
                if entry.disabled then
                    local element = rootDescription:CreateButton("|cFF808080" .. label .. "|r", function() end)
                    element:SetTooltip(function(tooltip, elementDescription)
                        GameTooltip_SetTitle(tooltip, L["Sequence Disabled"])
                    end)
                else
                    rootDescription:CreateButton(label, function()
                        GSE.CreateActionBarOverride(buttonName, entry.id)
                    end)
                end
            end
        end)
    end

    -- Standard Blizzard action bars hook via the global function
    --
    -- Hook the method on the ActionButton metatable instead
    local buttonPrefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }
    for _, prefix in ipairs(buttonPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix..i]
            if button then
                button:HookScript("OnClick", gseEmptyButtonHandler)
            end
        end
    end

    -- Third-party action bar addons use their own OnClick handlers, so we install
    -- HookScript directly on each button after PLAYER_ENTERING_WORLD, by which
    -- point all addon frames are guaranteed to exist.
    if not CreateFrame then return end
    local gseBarHookFrame = CreateFrame("Frame")
    gseBarHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    gseBarHookFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        if Bartender4 then
            for i = 1, 180 do
                local btn = _G["BT4Button" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
        end

        if ElvUI then
            for bar = 1, 15 do
                for slot = 1, 12 do
                    local btn = _G["ElvUI_Bar" .. bar .. "Button" .. slot]
                    if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
                end
            end
        end

        if NDui then
            for bar = 1, 15 do
                for slot = 1, 12 do
                    local btn = _G["NDui_ActionBar" .. bar .. "Button" .. slot]
                    if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
                end
            end
        end

        if _G["EABButton1"] then
            for i = 1, 180 do
                local btn = _G["EABButton" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
        end

        if Dominos then
            -- Dominos frame-name mapping differs between retail and Classic, so
            -- hook every pattern either flavour can use; the `if btn` guard makes
            -- names that don't exist on the current client a harmless no-op.
            --
            --   IDs       Retail name            Classic name
            --   1-24      DominosActionButtonN   DominosActionButtonN (1-12 = ActionButtonN, hooked above)
            --   25-72     MultiBar*ActionButtonN MultiBar*ButtonN (Blizzard, hooked by buttonPrefixes)
            --   73-168    DominosActionButton73-132 + MultiBar5/6/7ActionButtonN   DominosActionButtonN
            --
            -- On retail, Dominos creates its own MultiBar*ActionButtonN frames
            -- (note the "Action" infix) and hides the Blizzard MultiBar*ButtonN
            -- frames — so the buttonPrefixes loop above never reaches the visible
            -- buttons. On Classic, Dominos reuses the Blizzard frames instead.
            for i = 1, 24 do
                local btn = _G["DominosActionButton" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
            -- Retail tops out at DominosActionButton132; Classic goes to 168.
            for i = 73, 168 do
                local btn = _G["DominosActionButton" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
            -- Retail-only Dominos-created frames (absent on Classic → skipped).
            local dominosBlizzPrefixes = {
                "MultiBarRightActionButton",       -- IDs 25-36
                "MultiBarLeftActionButton",        -- IDs 37-48
                "MultiBarBottomRightActionButton", -- IDs 49-60
                "MultiBarBottomLeftActionButton",  -- IDs 61-72
                "MultiBar5ActionButton",           -- IDs 133-144
                "MultiBar6ActionButton",           -- IDs 145-156
                "MultiBar7ActionButton",           -- IDs 157-168
            }
            for _, prefix in ipairs(dominosBlizzPrefixes) do
                for i = 1, 12 do
                    local btn = _G[prefix .. i]
                    if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
                end
            end
        end

        if ConsolePort then
            local cpbButtons = {
                "CPB_PADDUP", "CPB_PADDLEFT", "CPB_PADDDOWN", "CPB_PADDRIGHT",
                "CPB_PADLSHOULDER", "CPB_PADRSHOULDER",
                "CPB_PADRTRIGGER", "CPB_PADLTRIGGER",
                "CPB_PAD1", "CPB_PAD2", "CPB_PAD3", "CPB_PAD4",
            }
            for _, name in ipairs(cpbButtons) do
                local btn = _G[name]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
        end
    end)
end

GSE.Utils = true
end
table.insert(ns.deferred, setup)

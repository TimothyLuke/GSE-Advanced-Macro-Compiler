local _, GSE = ...
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

local function safeGetSpellInfo(spellIdentifier)
    if spellIdentifier == nil or spellIdentifier == "" then return nil end
    local info = GSE.GetSpellInfo(spellIdentifier)
    if info then return info end
    -- Cross-class fallback: if a spell name failed to resolve (e.g. viewing
    -- another class's sequence where C_Spell.GetSpellInfo does not know the
    -- name), look it up in the saved-variable cache populated by prior
    -- imports / translator runs, then resolve by the cached numeric ID.
    if type(spellIdentifier) == "string" and not tonumber(spellIdentifier) and type(GSESpellCache) == "table" then
        local locale = GetLocale and GetLocale() or "enUS"
        local cachedID = GSESpellCache[locale] and GSESpellCache[locale][spellIdentifier]
        if cachedID then return GSE.GetSpellInfo(cachedID) end
    end
    return nil
end

-- Track which class libraries have been decompressed into GSE.Library.
GSE.LoadedClasses = GSE.LoadedClasses or {}

-- Sequences that failed to decode during load are collected here so the UI can
-- offer the player interactive options (delete / skip) rather than silent loss.
GSE.CorruptSequences = GSE.CorruptSequences or {}

-- Walk an action/version tree and rename legacy `macrotext` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ `macro`.
-- Platform storage historically emitted `macrotext` (a WoW SecureActionButton
-- runtime attribute name, never a stored-data field). The editor and runtime
-- read `macro`, so blocks that only have `macrotext` fall through the spell
-- branch and crash C_Spell.GetSpellInfo. Returns true if anything changed.
local function renameMacrotextInTree(node)
    if type(node) ~= "table" then return false end
    local changed = false
    if node.macrotext ~= nil then
        if node.macro == nil then
            node.macro = node.macrotext
        end
        node.macrotext = nil
        changed = true
    end
    if node.Type == Statics.Actions.Action or node.Type == Statics.Actions.Repeat then
        if node.type == "spell" and GSE.isEmpty(node.spell) then
            node.type = "macro"
            if node.macro == nil then node.macro = "" end
            changed = true
        elseif GSE.isEmpty(node.type) then
            if not GSE.isEmpty(node.macro) then
                node.type = "macro"
            elseif not GSE.isEmpty(node.item) then
                node.type = "item"
            elseif not GSE.isEmpty(node.action) then
                node.type = "pet"
            elseif not GSE.isEmpty(node.toy) then
                node.type = "toy"
            elseif not GSE.isEmpty(node.spell) then
                node.type = "spell"
            else
                node.type = "macro"
                node.macro = ""
            end
            changed = true
        end
    end
    for _, v in pairs(node) do
        if type(v) == "table" and renameMacrotextInTree(v) then
            changed = true
        end
    end
    return changed
end

--- Per-load checks applied to every sequence:
---  * recursively rename legacy `macrotext` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ `macro` inside action blocks
---  * clear MetaData.Checksum when anything changed (the stored signature was
---    produced against the pre-rename tree and would no longer verify; the
---    addon's Checksum verifier returns "no_checksum" for an absent sig and
---    suppresses the warning until the sequence is re-exported).
--
-- Returns true when any change was made so the caller can re-save to disk.
-- Returns false, "macros-deprecated" when the sequence still uses the
-- pre-#1853 `Macros` field name. The on-disk MacrosÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢Versions migration
-- has been retired: the addon refuses to interpret a Macros-only record
-- and the caller is expected to surface a "upload to gse.tools to
-- convert" message and skip the sequence.
local function migrateSequenceVersions(sequence)
    if type(sequence) ~= "table" then return false end
    if sequence["Macros"] ~= nil and sequence.Versions == nil then
        return false, "macros-deprecated"
    end
    local changed = false
    if type(sequence.Versions) == "table" then
        for _, version in pairs(sequence.Versions) do
            if renameMacrotextInTree(version) then
                changed = true
            end
        end
    end
    if GSE.SanitizeSequenceEditorMarkup and GSE.SanitizeSequenceEditorMarkup(sequence) then
        changed = true
    end
    if changed and type(sequence.MetaData) == "table" then
        sequence.MetaData.Checksum = nil
    end
    return changed
end

--- Decompress a single class from GSESequences into GSE.Library (internal).
local function loadOneClass(classid)
    if GSE.LoadedClasses[classid] then return end
    GSE.LoadedClasses[classid] = true
    if GSE.isEmpty(GSE.Library[classid]) then
        GSE.Library[classid] = {}
    end
    if GSE.isEmpty(GSESequences) or GSE.isEmpty(GSESequences[classid]) then
        return
    end
    for i, j in pairs(GSESequences[classid]) do
        local status, err =
            pcall(
            function()
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(j)
                GSE.Library[classid][i] = uncompressedVersion[2]
                local changed, reason = migrateSequenceVersions(GSE.Library[classid][i])
                if reason == "macros-deprecated" then
                    -- Refuse to load. The on-disk record uses the old
                    -- 'Macros' field; the addon no longer auto-renames.
                    GSE.Library[classid][i] = nil
                    error(string.format(
                        L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
                        i))
                end
                if changed then
                    GSESequences[classid][i] = GSE.EncodeMessage({i, GSE.Library[classid][i]})
                end
            end
        )
        if err then
            GSE.Print(tostring(err), "Error")
            table.insert(GSE.CorruptSequences, {classid = classid, name = i})
        end
    end
    -- Resolve action icons for this class so foreign-class sequences show
    -- real icons the moment they're browsed. No-op until GSE_GUI defines the
    -- function (i.e. on the very first class loaded during early init).
    if GSE.HydrateClassActionIcons then
        GSE.HydrateClassActionIcons(classid)
    end
end

--- Ensure a full class library is decompressed into GSE.Library (lazy load on first access).
-- Use this only when you need every sequence for a class (e.g. ScanMacrosForErrors).
-- For single-sequence access use GSE.EnsureSequenceLoaded instead.
function GSE.EnsureClassLoaded(classid)
    loadOneClass(classid)
end

--- Decompress a single sequence from GSESequences into GSE.Library on demand.
-- No-op if the sequence is already loaded or does not exist in the compressed store.
function GSE.EnsureSequenceLoaded(classid, sequenceName)
    if GSE.isEmpty(classid) or GSE.isEmpty(sequenceName) then return end
    if not GSE.isEmpty(GSE.Library[classid] and GSE.Library[classid][sequenceName]) then return end
    if GSE.isEmpty(GSESequences) or GSE.isEmpty(GSESequences[classid]) then return end
    if GSE.isEmpty(GSESequences[classid][sequenceName]) then return end
    if GSE.isEmpty(GSE.Library[classid]) then
        GSE.Library[classid] = {}
    end
    local status, err =
        pcall(
        function()
            local localsuccess, uncompressedVersion = GSE.DecodeMessage(GSESequences[classid][sequenceName])
            if localsuccess then
                GSE.Library[classid][sequenceName] = uncompressedVersion[2]
                local changed, reason = migrateSequenceVersions(GSE.Library[classid][sequenceName])
                if reason == "macros-deprecated" then
                    GSE.Library[classid][sequenceName] = nil
                    error(string.format(
                        L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
                        sequenceName))
                end
                if changed then
                    GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
                end
            end
        end
    )
    if not err and not GSE.isEmpty(GSE.Library[classid][sequenceName]) then
        GSE.EnsureSequenceVariablesLoaded(GSE.Library[classid][sequenceName])
    end
    if err then
        GSE.Print(
            "There was an error processing " ..
                sequenceName .. ", You will need to reimport this macro from another source.",
            err
        )
        table.insert(GSE.CorruptSequences, {classid = classid, name = sequenceName})
    end
    -- Resolve action icons for this class so single-sequence loads also
    -- benefit from the load-time icon hydration. Cheap and idempotent.
    if GSE.HydrateClassActionIcons then
        GSE.HydrateClassActionIcons(classid)
    end
end

--- Remove a corrupt sequence from both compressed storage and the live library.
function GSE.DeleteCorruptSequence(classid, name)
    if type(GSESequences) == "table" and type(GSESequences[classid]) == "table" then
        GSESequences[classid][name] = nil
    end
    if type(GSE.Library) == "table" and type(GSE.Library[classid]) == "table" then
        GSE.Library[classid][name] = nil
    end
    GSE.Print(string.format(L["Corrupt sequence '%s' (class %d) deleted."], name, classid))
end

--- Delete a variable from local storage by name. Single canonical
-- helper for both UI and OOC-queue callers ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â each was previously
-- inlining `GSEVariables[k] = nil` etc., which made it easy to forget
-- the sidecar tables (GSE.V cache, Companion PlatformID sidecar) and
-- left orphans behind that the next sync had to clean up.
function GSE.DeleteVariable(name)
    if not name or name == "" then return end
    if GSEVariables then GSEVariables[name] = nil end
    if GSE.V then GSE.V[name] = nil end
    -- Companion sidecar: name ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ server-id map. Clearing it stops the
    -- next sync from re-uploading the deleted variable on the basis of
    -- a stale stamp.
    if GSEVariablePlatformIDs then GSEVariablePlatformIDs[name] = nil end
end

--- Delete a macro from local storage by name. Handles both account-
-- level (GSEMacros[name]) and character-level (GSEMacros["char-realm"]
-- [name]) storage; clears whichever holds the entry.
function GSE.DeleteMacro(name)
    if not name or name == "" then return end
    if GSEMacros then
        GSEMacros[name] = nil
        for _, t in pairs(GSEMacros) do
            if type(t) == "table" and t[name] ~= nil then
                t[name] = nil
            end
        end
    end
    if GSEMacroPlatformIDs then GSEMacroPlatformIDs[name] = nil end
end

--- Delete a sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
    GSE.Library[tonumber(classid)][sequenceName] = nil
    GSESequences[tonumber(classid)][sequenceName] = nil

    -- Remove any actionbar overrides that reference this sequence
    local overrideChanged = false
    if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
            for _, buttons in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
                local toDelete = {}
                for buttonName, bind in pairs(buttons) do
                    if bind.Sequence == sequenceName then
                        table.insert(toDelete, buttonName)
                    end
                end
                for _, buttonName in ipairs(toDelete) do
                    buttons[buttonName] = nil
                    overrideChanged = true
                end
            end
        end
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
            for _, loadouts in pairs(GSE_C["ActionBarBinds"]["LoadOuts"]) do
                for _, buttons in pairs(loadouts) do
                    local toDelete = {}
                    for buttonName, bind in pairs(buttons) do
                        if bind.Sequence == sequenceName then
                            table.insert(toDelete, buttonName)
                        end
                    end
                    for _, buttonName in ipairs(toDelete) do
                        buttons[buttonName] = nil
                        overrideChanged = true
                    end
                end
            end
        end
    end
    if overrideChanged then
        GSE.ReloadOverrides()
    end

    -- Remove any keybindings that reference this sequence
    if not InCombatLockdown() and not GSE.isEmpty(GSE_C["KeyBindings"]) then
        for _, specData in pairs(GSE_C["KeyBindings"]) do
            local toDelete = {}
            for key, seqName in pairs(specData) do
                if key ~= "LoadOuts" and seqName == sequenceName then
                    table.insert(toDelete, key)
                end
            end
            for _, key in ipairs(toDelete) do
                SetBinding(key)
                specData[key] = nil
            end
            if not GSE.isEmpty(specData["LoadOuts"]) then
                for _, loadoutData in pairs(specData["LoadOuts"]) do
                    local toDeleteLO = {}
                    for key, seqName in pairs(loadoutData) do
                        if seqName == sequenceName then
                            table.insert(toDeleteLO, key)
                        end
                    end
                    for _, key in ipairs(toDeleteLO) do
                        SetBinding(key)
                        loadoutData[key] = nil
                    end
                end
            end
        end
    end
end

local missingVariables = {}
local function manageMissingVariable(varname)
    if not missingVariables[varname] then
        GSE.Print(L["Missing Variable "] .. varname, Statics.DebugModules["API"])
        missingVariables[varname] = 0
    end
    missingVariables[varname] = missingVariables[varname] + 1
    if missingVariables[varname] > 100 then
        GSE.Print(L["Missing Variable "] .. varname, Statics.DebugModules["API"])
        missingVariables[varname] = 0
    end
end

function GSE.CloneSequence(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[GSE.CloneSequence(orig_key)] = GSE.CloneSequence(orig_value)
        end
        setmetatable(copy, GSE.CloneSequence(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

--- Smart OOC queue insertion with deduplication and priority hierarchy.
--
-- Sequence priority (highest ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ lowest): MergeSequence > Save/Replace > UpdateSequence
--   MergeSequence: removes all Save/Replace/UpdateSequence/MergeSequence for same name, then enqueues.
--   Save/Replace:  skipped if MergeSequence queued for same name; otherwise replaces existing
--                  Save/Replace and removes any UpdateSequence for same name.
--   UpdateSequence: skipped if any of MergeSequence/Save/Replace/UpdateSequence already queued for same name.
--
-- Macro priority: importmacro > updatemacro
--   importmacro:   removes existing importmacro/updatemacro for same node.name, then enqueues.
--   updatemacro:   skipped if importmacro or updatemacro already queued for same node.name.
--
-- updatevariable: replaces existing entry for same variable name.
-- FinishReload/managemacros/CheckMacroCreated: skipped if already present.
function GSE.EnqueueOOC(vals)
    local action = vals.action
    if GSE.StartOOCTimer then
        GSE.StartOOCTimer()
    end

    if action == "MergeSequence" then
        -- Remove all sequence operations for the same name; we supersede them.
        local k = 1
        while k <= #GSE.OOCQueue do
            local v = GSE.OOCQueue[k]
            if (v.action == "MergeSequence" or v.action == "Save" or v.action == "Replace" or v.action == "UpdateSequence")
                    and v.sequencename == vals.sequencename then
                table.remove(GSE.OOCQueue, k)
            else
                k = k + 1
            end
        end

    elseif action == "Save" or action == "Replace" then
        -- Skip if a MergeSequence for the same name is already queued.
        for _, v in ipairs(GSE.OOCQueue) do
            if v.action == "MergeSequence" and v.sequencename == vals.sequencename then
                return
            end
        end
        -- Replace existing Save/Replace and strip any UpdateSequence for the same name.
        local replaced = false
        local k = 1
        while k <= #GSE.OOCQueue do
            local v = GSE.OOCQueue[k]
            if v.action == "UpdateSequence" and v.name == vals.sequencename then
                table.remove(GSE.OOCQueue, k)
            elseif (v.action == "Save" or v.action == "Replace") and v.sequencename == vals.sequencename then
                GSE.OOCQueue[k] = vals
                replaced = true
                k = k + 1
            else
                k = k + 1
            end
        end
        if replaced then return end

    elseif action == "UpdateSequence" then
        -- Skip if any higher-priority sequence op for the same name is already queued.
        for _, v in ipairs(GSE.OOCQueue) do
            if (v.action == "MergeSequence" or v.action == "Save" or v.action == "Replace" or v.action == "UpdateSequence")
                    and (v.sequencename == vals.name or v.name == vals.name) then
                return
            end
        end

    elseif action == "importmacro" then
        -- importmacro supersedes any existing importmacro/updatemacro for the same macro name.
        local k = 1
        while k <= #GSE.OOCQueue do
            local v = GSE.OOCQueue[k]
            if (v.action == "importmacro" or v.action == "updatemacro")
                    and v.node and vals.node and v.node.name == vals.node.name then
                table.remove(GSE.OOCQueue, k)
            else
                k = k + 1
            end
        end

    elseif action == "updatemacro" then
        -- Skip if importmacro or updatemacro for same macro is already queued.
        for _, v in ipairs(GSE.OOCQueue) do
            if (v.action == "importmacro" or v.action == "updatemacro")
                    and v.node and vals.node and v.node.name == vals.node.name then
                return
            end
        end

    elseif action == "updatevariable" then
        for k, v in ipairs(GSE.OOCQueue) do
            if v.action == "updatevariable" and v.name == vals.name then
                GSE.OOCQueue[k] = vals
                return
            end
        end

    elseif action == "FinishReload" or action == "managemacros" or action == "openoptions" then
        for _, v in ipairs(GSE.OOCQueue) do
            if v.action == action then
                return
            end
        end

    elseif action == "CheckMacroCreated" then
        for _, v in ipairs(GSE.OOCQueue) do
            if v.action == "CheckMacroCreated" and v.sequencename == vals.sequencename then
                return
            end
        end
    end

    table.insert(GSE.OOCQueue, vals)
end

--- Add a sequence to the library
function GSE.AddSequenceToCollection(sequenceName, sequence, classid)
    -- Save-cancels-delete (see UpdateVariable for rationale).
    if GSE.CompanionCancelPendingDelete then
        GSE.CompanionCancelPendingDelete("sequence", sequenceName)
    end
    local vals = {}
    vals.action = "Save"
    vals.sequencename = sequenceName
    vals.sequence = sequence
    vals.classid = classid
    GSE.EnqueueOOC(vals)
end

function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
    local vals = {}
    vals.action = "MergeSequence"
    vals.sequencename = sequenceName
    vals.newSequence = newSequence
    vals.classid = classid
    vals.mergeaction = action
    GSE.EnqueueOOC(vals)
end

--- Snapshot any WoW macros listed in sequence.MetaData.Dependencies.Macros to the
-- account-level GSEMacros store.  Called after saving/replacing a sequence so that
-- character-specific macros are preserved and available to other characters.
function GSE.SnapshotDependentMacros(sequence)
    if not GetMacroIndexByName then return end          -- guard for unit-test context
    if type(sequence) ~= "table" then return end
    local deps = type(sequence.MetaData) == "table" and sequence.MetaData.Dependencies
    if not deps or type(deps.Macros) ~= "table" then return end
    if GSE.isEmpty(GSEMacros) then GSEMacros = {} end
    for _, macname in ipairs(deps.Macros) do
        local slot = GetMacroIndexByName(macname)
        if slot and slot > 0 then
            local mname, micon, mbody = GetMacroInfo(slot)
            if mname then
                -- Always overwrite so the account-level copy stays current.
                GSEMacros[macname] = {
                    name     = mname,
                    value    = slot,
                    icon     = micon,
                    text     = mbody,
                    manageMacro = mbody,
                }
            end
        end
    end
end

--- Replace a current version of a Macro
function GSE.ReplaceSequence(classid, sequenceName, sequence)
    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(sequence)
    end
    GSE.ComputeSequenceDependencies(sequence)
    GSE.SnapshotDependentMacros(sequence)
    -- Checksum is stamped on export only, not on save, so the stored checksum
    -- always reflects the last-exported state rather than the current edit state.
    GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
    GSE.Library[classid][sequenceName] = sequence
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, sequenceName)
end

--- Rename a sequence in-place, preserving its PlatformID and all MetaData.
-- Moves the data from the old key to the new key in both Library and
-- GSESequences, updates MetaData.Name, and removes the old entry.
-- Does NOT wipe PlatformID — this is a rename, not a new-sequence creation.
function GSE.RenameSequence(classid, oldName, newName, sequence)
    classid = tonumber(classid)
    if not classid or GSE.isEmpty(oldName) or GSE.isEmpty(newName) then return false end
    if GSE.isEmpty(GSE.Library[classid]) then return false end

    -- Update the human-readable name stored inside the sequence object.
    sequence.MetaData.Name = newName

    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(sequence)
    end
    GSE.ComputeSequenceDependencies(sequence)
    GSE.SnapshotDependentMacros(sequence)

    -- Write under the new key.
    GSESequences[classid][newName] = GSE.EncodeMessage({newName, sequence})
    GSE.Library[classid][newName] = sequence

    -- Remove the old key so the old name is no longer in use.
    GSESequences[classid][oldName] = nil
    GSE.Library[classid][oldName]  = nil

    -- Migrate any actionbar overrides that referenced the old name so the
    -- bound buttons follow the rename instead of pointing at the stale name.
    local overrideChanged = false
    if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
            for _, buttons in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
                for _, bind in pairs(buttons) do
                    if bind.Sequence == oldName then
                        bind.Sequence = newName
                        overrideChanged = true
                    end
                end
            end
        end
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
            for _, loadouts in pairs(GSE_C["ActionBarBinds"]["LoadOuts"]) do
                for _, buttons in pairs(loadouts) do
                    for _, bind in pairs(buttons) do
                        if bind.Sequence == oldName then
                            bind.Sequence = newName
                            overrideChanged = true
                        end
                    end
                end
            end
        end
    end
    if overrideChanged and GSE.ReloadOverrides then
        GSE.ReloadOverrides()
    end

    -- Migrate any keybindings that referenced the old name. Reassign in the
    -- saved table, then re-apply so the key clicks the renamed button.
    local keybindChanged = false
    if not InCombatLockdown() and not GSE.isEmpty(GSE_C["KeyBindings"]) then
        for _, specData in pairs(GSE_C["KeyBindings"]) do
            for key, seqName in pairs(specData) do
                if key ~= "LoadOuts" and seqName == oldName then
                    specData[key] = newName
                    keybindChanged = true
                end
            end
            if not GSE.isEmpty(specData["LoadOuts"]) then
                for _, loadoutData in pairs(specData["LoadOuts"]) do
                    for key, seqName in pairs(loadoutData) do
                        if seqName == oldName then
                            loadoutData[key] = newName
                            keybindChanged = true
                        end
                    end
                end
            end
        end
    end
    if keybindChanged and GSE.ReloadKeyBindings then
        GSE.ReloadKeyBindings()
    end

    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, newName)
    return true
end

--- Duplicate a sequence under a new name. Unlike a rename, a duplicate is a
-- brand-new sequence: it is given a fresh GSE.Tools identity (PlatformID is
-- cleared) so the copy and the original never resolve to the same server
-- record. If newName is supplied it is used (normalised + collision-checked);
-- otherwise a unique "<source>Copy" name is generated. The sequence is stored
-- synchronously (so open editor trees can show it immediately) and its secure
-- button is built on the next OOC tick. Returns the new name, or nil on failure.
function GSE.DuplicateSequence(classid, sourceName, newName)
    classid = tonumber(classid)
    if GSE.isEmpty(classid) then classid = GSE.GetCurrentClassID() end
    if GSE.isEmpty(sourceName) then return nil end

    local src = GSE.FindSequence(sourceName)
    if GSE.isEmpty(src) then return nil end
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
    if GSE.isEmpty(GSESequences[classid]) then GSESequences[classid] = {} end

    local clone = GSE.CloneSequence(src)
    if GSE.isEmpty(clone.MetaData) then clone.MetaData = {} end

    if not GSE.isEmpty(newName) then
        -- Caller-supplied name (from the rename-style prompt). Normalise like
        -- the import path (spaces/commas -> underscores); bail if it collides.
        newName = newName:gsub(" ", "_"):gsub(",", "_")
        if not GSE.isEmpty(GSE.Library[classid][newName]) then
            return nil
        end
    else
        -- Auto-generate: "<source>Copy", then "Copy2", "Copy3", ...
        local base = sourceName .. "Copy"
        newName = base
        local suffix = 2
        while not GSE.isEmpty(GSE.Library[classid][newName]) do
            newName = base .. suffix
            suffix = suffix + 1
        end
    end

    clone.MetaData.Name = newName
    -- A duplicate must mint its own GSE.Tools record, so clear the inherited
    -- PlatformID; otherwise the copy and the original would share one server
    -- id and bounce against each other on the next Companion sync.
    clone.MetaData.PlatformID = nil
    clone.LastUpdated = GSE.GetTimestamp()

    -- Store synchronously (table writes only — safe in or out of combat).
    GSE.ReplaceSequence(classid, newName, clone)

    -- Build the secure button out of combat via the OOC queue.
    local versionIndex = GSE.GetActiveSequenceVersion(newName)
        or (clone.MetaData and clone.MetaData.Default) or 1
    local version = clone.Versions and clone.Versions[versionIndex]
    if version then
        GSE.UpdateSequence(newName, version)
    end
    return newName
end

--- Load the GSEStorage into a new table.
-- Sequences are loaded first so their dependency data is available when
-- LoadVariables() decides which variables to compile.
function GSE.LoadStorage(destination)
    if GSE.isEmpty(destination) then
        destination = {}
    end
    if GSE.isEmpty(GSESequences) then
        GSESequences = {}
        for iind = 0, 13 do
            GSESequences[iind] = {}
        end
    end
    -- Pre-initialise all class slots so GSE.Library[k] is never nil.
    for k = 0, 13 do
        if GSE.isEmpty(destination[k]) then
            destination[k] = {}
        end
        if GSE.isEmpty(GSESequences[k]) then
            GSESequences[k] = {}
        end
    end
    -- Decompress sequences first so dependency data is readable.
    loadOneClass(0)
    local currentClass = GSE.GetCurrentClassID()
    if currentClass and currentClass ~= 0 then
        loadOneClass(currentClass)
    end
    -- Now load only the variables these sequences depend on.
    GSE.LoadVariables()
end

--- Force-load every class that has not yet been decompressed, triggering the
-- MacrosÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢Versions migration for any sequences still in the old format.
-- Enqueued via the OOC queue from PLAYER_ENTERING_WORLD so it runs in the
-- background (on the next OOC tick) without blocking login.
function GSE.MigrateAllRemainingClasses()
    for classid = 0, 13 do
        if not GSE.LoadedClasses[classid] then
            loadOneClass(classid)
        end
    end
end

--- Compile and register a single variable from its compressed store entry.
-- Shared by LoadVariables and EnsureSequenceVariablesLoaded.
local function loadOneVariable(k, v)
    local status, err =
        pcall(
        function()
            local localsuccess, uncompressedVersion = GSE.DecodeMessage(v)
            if not localsuccess then return end
            GSE.V[k] = loadstring("return " .. uncompressedVersion.funct)()
            if type(GSE.V[k]()) == "boolean" then
                GSE.BooleanVariables["GSE.V['" .. k .. "']()"] = "GSE.V['" .. k .. "']()"
            end
            if uncompressedVersion.eventEnabled and not GSE.isEmpty(uncompressedVersion.eventNames) then
                GSE.RegisterVariableEvents(k, uncompressedVersion.eventNames)
            end
        end
    )
    if err then
        GSE.Print(
            "There was an error processing " ..
                k .. ", You will need to correct errors in this variable from another source.",
            err
        )
    end
end

--- Walk loaded Library entries to collect the set of variable names directly
-- required by current sequences, then resolve the transitive closure by reading
-- each variable's stored Dependencies from GSEVariables.
-- Returns a set {name=true} of all needed variable names, or nil if any loaded
-- sequence lacks dependency data (meaning we must fall back to loading everything).
-- Must be self-contained: called before GSE_Utils is loaded.
local function collectNeededVariables()
    local needed = {}
    local needAll = false

    for classid = 0, 13 do
        local classlib = GSE.Library[classid]
        if classlib then
            for _, seq in pairs(classlib) do
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Variables) == "table" then
                        for _, vname in ipairs(deps.Variables) do
                            needed[vname] = true
                        end
                    else
                        -- Sequence pre-dates dependency tracking; must load all.
                        needAll = true
                    end
                else
                    needAll = true
                end
            end
        end
    end

    if needAll then return nil end

    -- BFS transitive resolution entirely within Storage.lua.
    -- Reads each variable's stored Dependencies directly from GSEVariables.
    local queue = {}
    for vname in pairs(needed) do
        table.insert(queue, vname)
    end
    local i = 1
    while i <= #queue do
        local vname = queue[i]
        i = i + 1
        if not GSE.isEmpty(GSEVariables[vname]) then
            local ok, decoded = GSE.DecodeMessage(GSEVariables[vname])
            if ok and decoded and decoded.Dependencies and type(decoded.Dependencies.Variables) == "table" then
                for _, depname in ipairs(decoded.Dependencies.Variables) do
                    if not needed[depname] then
                        needed[depname] = true
                        table.insert(queue, depname)
                    end
                end
            end
        end
    end

    return needed
end

--- Load the GSEVariables.
-- If all loaded sequences carry dependency data, only the transitively required
-- variables are compiled via loadstring().  Any sequence that pre-dates
-- dependency tracking triggers a full load so nothing is silently missing.
function GSE.LoadVariables()
    if GSE.isEmpty(GSEVariables) then
        GSEVariables = {}
        return
    end

    local needed = collectNeededVariables()

    if needed == nil then
        -- Fallback: at least one sequence has no dep data; load everything.
        for k, v in pairs(GSEVariables) do
            loadOneVariable(k, v)
        end
        return
    end

    -- Selective load: only compile variables the current sequences need.
    local deferred = 0
    for k, v in pairs(GSEVariables) do
        if needed[k] then
            loadOneVariable(k, v)
        else
            deferred = deferred + 1
        end
    end
    if deferred > 0 then
        GSE.PrintDebugMessage(
            string.format("%d variable(s) deferred (not needed by current sequences).", deferred),
            GNOME
        )
    end
end

--- Ensure all variables required by a sequence are compiled into GSE.V.
-- Called when a lazy-loaded foreign-class sequence is accessed, so its
-- variables are ready before it is compiled or executed.
function GSE.EnsureSequenceVariablesLoaded(sequence)
    if type(sequence) ~= "table" or type(sequence.MetaData) ~= "table" then return end
    local deps = sequence.MetaData.Dependencies
    if not deps or type(deps.Variables) ~= "table" or #deps.Variables == 0 then return end

    -- Resolve transitive deps and load any not yet in GSE.V.
    local queue = {}
    local seen = {}
    for _, vname in ipairs(deps.Variables) do
        if not seen[vname] then
            seen[vname] = true
            table.insert(queue, vname)
        end
    end
    local i = 1
    while i <= #queue do
        local vname = queue[i]
        i = i + 1
        if GSE.isEmpty(GSE.V[vname]) and not GSE.isEmpty(GSEVariables[vname]) then
            loadOneVariable(vname, GSEVariables[vname])
        end
        -- Walk transitive deps from the stored variable data.
        if not GSE.isEmpty(GSEVariables[vname]) then
            local ok, decoded = GSE.DecodeMessage(GSEVariables[vname])
            if ok and decoded and decoded.Dependencies and type(decoded.Dependencies.Variables) == "table" then
                for _, depname in ipairs(decoded.Dependencies.Variables) do
                    if not seen[depname] then
                        seen[depname] = true
                        table.insert(queue, depname)
                    end
                end
            end
        end
    end
end

-- Track active variable event registrations, keyed by variable name
GSE.VariableEventHandlers = GSE.VariableEventHandlers or {}

--- Register one or more WoW events or internal messages as callbacks for a variable.
-- Each event/message will call GSE.V[name] with (eventName, ...) when fired.
-- Always unregisters any prior bindings for this variable first.
-- @param name string  The variable name (key in GSEVariables)
-- @param eventNames table  Array of event/message name strings
function GSE.RegisterVariableEvents(name, eventNames)
    GSE.UnregisterVariableEvents(name)
    if GSE.isEmpty(eventNames) then return end

    -- Per-variable AceEvent proxy. AceEvent's :UnregisterEvent / :UnregisterMessage
    -- operate per `self`, so each variable gets its own embedded target table —
    -- that way unregistering this variable's events doesn't trample the bindings
    -- of any other variable subscribed to the same event name.
    local proxy = LibStub("AceEvent-3.0"):Embed({})
    GSE.VariableEventHandlers[name] = {proxy = proxy, events = {}}

    for _, eventName in ipairs(eventNames) do
        -- Routing priority:
        --   1. Known GSE internal message (Statics.InternalMessages) -> RegisterMessage
        --   2. Valid WoW API event (C_EventUtils.IsEventValid)       -> RegisterEvent
        --   3. Anything else (custom addon message)                  -> RegisterMessage
        local isMessage
        if Statics.InternalMessages[eventName] then
            isMessage = true
        elseif C_EventUtils and C_EventUtils.IsEventValid then
            isMessage = not C_EventUtils.IsEventValid(eventName)
        else
            isMessage = false  -- C_EventUtils unavailable: assume WoW event (legacy fallback)
        end
        local handler = function(evt, ...)
            if GSE.V[name] and type(GSE.V[name]) == "function" then
                pcall(GSE.V[name], evt, ...)
            end
        end
        if isMessage then
            proxy:RegisterMessage(eventName, handler)
        else
            proxy:RegisterEvent(eventName, handler)
        end
        table.insert(GSE.VariableEventHandlers[name].events, {name = eventName, isMessage = isMessage})
    end
end

--- Unregister all event/message callbacks previously registered for a variable.
-- @param name string  The variable name
function GSE.UnregisterVariableEvents(name)
    if not GSE.VariableEventHandlers or not GSE.VariableEventHandlers[name] then
        return
    end
    local binding = GSE.VariableEventHandlers[name]
    if binding.proxy then
        binding.proxy:UnregisterAllEvents()
        if binding.proxy.UnregisterAllMessages then binding.proxy:UnregisterAllMessages() end
    end
    GSE.VariableEventHandlers[name] = nil
end
--- Load a collection of Sequences
function GSE.ImportCompressedMacroCollection(Sequences)
    for _, v in ipairs(Sequences) do
        GSE.ImportSerialisedSequence(v)
    end
end
-- Priority-ordered context ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ MetaData version mapping.
-- Evaluated in order by GetActiveSequenceVersion; first matching entry wins.
-- Each entry: { metaKey = field to check not-empty, flag = GSE boolean, valueKey = field to read }
local contextVersionPriority = {
    { metaKey = "Scenario",    flag = "inScenario",   valueKey = "Scenario"    },
    { metaKey = "Arena",       flag = "inArena",       valueKey = "Arena"       },
    { metaKey = "PVP",         flag = "inArena",       valueKey = "Arena"       }, -- PVP set + inArena ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ Arena version (original behaviour)
    { metaKey = "PVP",         flag = "PVPFlag",       valueKey = "PVP"         },
    { metaKey = "Raid",        flag = "inRaid",        valueKey = "Raid"        },
    { metaKey = "Mythic",      flag = "inMythic",      valueKey = "Mythic"      },
    { metaKey = "MythicPlus",  flag = "inMythicPlus",  valueKey = "MythicPlus"  },
    { metaKey = "Heroic",      flag = "inHeroic",      valueKey = "Heroic"      },
    { metaKey = "Dungeon",     flag = "inDungeon",     valueKey = "Dungeon"     },
    { metaKey = "Timewalking", flag = "inTimeWalking", valueKey = "Timewalking" },
    { metaKey = "Party",       flag = "inParty",       valueKey = "Party"       },
}

local function isPVESoloContext()
    return not (
        GSE.inScenario or
        GSE.inArena or
        GSE.PVPFlag or
        GSE.inRaid or
        GSE.inMythic or
        GSE.inMythicPlus or
        GSE.inHeroic or
        GSE.inDungeon or
        GSE.inTimeWalking or
        GSE.inParty
    )
end

--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(sequenceName)
    local classid = GSE.GetCurrentClassID()
    if GSE.isEmpty(GSE.Library[classid][sequenceName]) then
        classid = 0
    end
    if GSE.isEmpty(GSE.Library[classid][sequenceName]) then
        return
    end
    local meta = GSE.Library[classid][sequenceName]["MetaData"]
    local vers = (not GSE.isEmpty(meta.Default)) and meta.Default or 1
    if not GSE.isEmpty(meta.PVESolo) and isPVESoloContext() then
        vers = meta.PVESolo
    end
    for _, ctx in ipairs(contextVersionPriority) do
        if not GSE.isEmpty(meta[ctx.metaKey]) and GSE[ctx.flag] then
            vers = meta[ctx.valueKey]
            break
        end
    end
    return (vers == 0) and 1 or vers
end

function GSE.ReloadSequences()
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) then
        GSE.PerformReloadSequences()
        GSE.UnsavedOptions.ReloadQueued = true
    end
    GSE.EnqueueOOC({action = "managemacros"})
end

function GSE.PerformReloadSequences(force)
    GSE.PrintDebugMessage("Reloading Sequences", Statics.DebugModules["Storage"])
    local func
    if force then
        func = GSE.OOCUpdateSequence
    else
        -- Remove any individual UpdateSequence items already in the queue ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â
        -- the full reload about to be queued will cover all of them.
        local k = 1
        while k <= #GSE.OOCQueue do
            if GSE.OOCQueue[k].action == "UpdateSequence" then
                table.remove(GSE.OOCQueue, k)
            else
                k = k + 1
            end
        end
        func = GSE.UpdateSequence
    end
    for name, sequence in pairs(GSE.Library[GSE.GetCurrentClassID()]) do
        if not sequence.MetaData.Disabled then
            func(name, sequence.Versions[GSE.GetActiveSequenceVersion(name)])
        end
    end
    if not GSE.isEmpty(GSE.Library[0]) then
        for name, sequence in pairs(GSE.Library[0]) do
            if GSE.isEmpty(sequence.MetaData.Disabled) then
                func(name, sequence.Versions[GSE.GetActiveSequenceVersion(name)])
            end
        end
    end
    local vals = {}
    vals.action = "FinishReload"
    GSE.EnqueueOOC(vals)
end

--- This function is used to clean the local sequence library
function GSE.CleanMacroLibrary(forcedelete)
    -- Clean out the sequences database except for the current version
    if forcedelete then
        GSESequences[GSE.GetCurrentClassID()] = nil
        GSESequences[GSE.GetCurrentClassID()] = {}
        GSE.Library[GSE.GetCurrentClassID()] = nil
        GSE.Library[GSE.GetCurrentClassID()] = {}
        if GSE.GUI and GSE.GUI.Editors then
            for k, _ in GSE.GUI.Editors do
                k:Hide()
                k:ReleaseChildren()
                k:Release()
            end
            GSE.GUI.Editors = {}
        end
    end
end

--- This function resets a gsebutton back to its initial setting
function GSE.ResetButtons()
    for k, _ in pairs(GSE.UsedSequences) do
        local gsebutton = _G[k]
        gsebutton:SetAttribute("step", 1)
        GSE.UpdateIcon(gsebutton, true)
        GSE.UsedSequences[k] = nil
    end
end

--- This functions schedules an update to a sequence in the OOCQueue.
function GSE.UpdateSequence(name, sequence)
    local vals = {}
    vals.action = "UpdateSequence"
    vals.name = name
    vals.macroversion = sequence
    GSE.EnqueueOOC(vals)
end

--- This function updates the button for an existing sequence.  It is called from the OOC queue
function GSE.OOCUpdateSequence(name, sequence)
    if GSE.isEmpty(sequence) then
        return
    end
    if GSE.isEmpty(name) then
        return
    end
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][name]) and GSE.isEmpty(GSE.Library[0][name]) then
        return
    end

    -- Avoid rebuilding the secure button while a boss encounter is still active.
    if GSE.IsEncounterInProgress and GSE.IsEncounterInProgress() then
        GSE.UpdateSequence(name, sequence)
        return
    end

    local combatReset = false
    if GSE.isEmpty(sequence.InbuiltVariables) then
        sequence.InbuiltVariables = {["Combat"] = false}
    end
    if sequence.InbuiltVariables.Combat or GSE.GetResetOOC() then
        combatReset = true
    end

    local compiledTemplate = GSE.CompileTemplate(sequence)
    local actionCount = #compiledTemplate
    if actionCount > 64516 then
        GSE.Print(
            string.format(
                L[
                    "%s macro may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this macro."
                ],
                name,
                actionCount
            ),
            "MACRO ERROR"
        )
    end
    GSE.CreateGSE3Button(compiledTemplate, name, combatReset)
    if GSE.RefreshActionBarOverrideIcons then
        GSE.RefreshActionBarOverrideIcons(name, false)
        C_Timer.After(0, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
        C_Timer.After(0.1, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
        C_Timer.After(0.25, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
    end
    if GSE.GUI and not GSE.isEmpty(GSE.GUIEditFrame) then
        if not GSE.isEmpty(GSE.GUIEditFrame.IsVisible) then
            if GSE.GUIEditFrame:IsVisible() then
                GSE.GUIEditFrame:SetStatusText(name .. " " .. L["Saved"])
                C_Timer.After(
                    5,
                    function()
                        GSE.GUIEditFrame:SetStatusText("")
                    end
                )
                GSE.ShowSequences()
            end
        end
    end
end

--- Return whether to store the macro in Personal Character Macros or Account Macros
function GSE.SetMacroLocation()
    local _, numCharacterMacros = GetNumMacros()
    local returnval
    returnval = 1
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSEOptions.overflowPersonalMacros then
        returnval = nil
    end
    return returnval
end

function GSE.CreateMacroString(macroname)
    local returnVal = "#showtooltip\n/click "
    local state = GSE.GetMacroStringFormat()
    local t = state == "DOWN" and "t" or "f"

    if GSE.GetMacroStringFormat() == "DOWN" or GSEOptions.MacroResetModifiers["LeftButton"] then
        returnVal = returnVal .. "[button:1] " .. macroname .. " LeftButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["RightButton"] then
        returnVal = returnVal .. "[button:2] " .. macroname .. " RightButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["MiddleButton"] then
        returnVal = returnVal .. "[button:3] " .. macroname .. " MiddleButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["Button4"] then
        returnVal = returnVal .. "[button:4] " .. macroname .. " Button4 " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["Button5"] then
        returnVal = returnVal .. "[button:5] " .. macroname .. " Button5 " .. t .. "; "
    end
    if GSEOptions.virtualButtonSupport then
        returnVal = returnVal .. "[nobutton:1] " .. macroname .. "; "
    end

    returnVal = returnVal .. macroname
    return returnVal
end

--- Add a Create Macro to the Out of Combat Queue
function GSE.CheckMacroCreated(SequenceName, create)
    local vals = {}
    vals.action = "CheckMacroCreated"
    vals.sequencename = SequenceName
    vals.create = create
    GSE.EnqueueOOC(vals)
end

--- Check if a macro has been created and if the create flag is true and the macro hasn't been created, then create it.
function GSE.OOCCheckMacroCreated(SequenceName, create)
    local found = false

    local macroIndex = GetMacroIndexByName(SequenceName)
    if macroIndex and macroIndex ~= 0 then
        found = true
        if create then
            EditMacro(macroIndex, nil, GSE.GetManagedMacroStubIcon and GSE.GetManagedMacroStubIcon(SequenceName, select(2, GetMacroInfo(macroIndex))) or nil, GSE.CreateMacroString(SequenceName))
        end
    else
        if create then
            GSE.CreateMacroIcon(SequenceName, GSE.GetManagedMacroStubIcon and GSE.GetManagedMacroStubIcon(SequenceName, Statics.QuestionMark) or Statics.QuestionMark)
            found = true
        end
    end
    return found
end

--- This removes a macro Stub.
function GSE.DeleteMacroStub(sequenceName)
    local mname, _, mbody = GetMacroInfo(sequenceName)
    if mname == sequenceName then
        local trimmedmbody = mbody:gsub("[^%w ]", "")
        local compar = GSE.CreateMacroString(mname)
        local trimmedcompar = compar:gsub("[^%w ]", "")
        if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
            GSE.Print(L[" Deleted Orphaned Macro "] .. mname, GNOME)
            DeleteMacro(sequenceName)
        end
    end
end

--- This returns a list of Sequence Names for the current spec
function GSE.GetSequenceNames(Library)
    if not Library then
        Library = GSE.Library
    end
    if GSE.isEmpty(GSEOptions.filterList) then
        GSEOptions.filterList = {}
        GSEOptions.filterList[Statics.Spec] = true
        GSEOptions.filterList[Statics.Class] = true
        GSEOptions.filterList[Statics.All] = false
        GSEOptions.filterList[Statics.Global] = true
    end
    local currentClassID = GSE.GetCurrentClassID()
    local keyset = {}
    for k, _ in pairs(Library) do
        if GSEOptions.filterList[Statics.All] or k == currentClassID then
            if k == currentClassID or k == 0 then
                -- Library already loaded for these classes ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â full metadata available.
                for i, j in pairs(Library[k]) do
                    local disable = 0
                    if j.DisableEditor then
                        disable = 1
                    end
                    local keyLabel = k .. "," .. j.MetaData.SpecID .. "," .. i .. "," .. disable
                    if k == currentClassID and GSEOptions.filterList["Class"] then
                        keyset[keyLabel] = i
                    elseif k == currentClassID and not GSEOptions.filterList["Class"] then
                        if j.MetaData.SpecID == GSE.GetCurrentSpecID() or j.MetaData.SpecID == currentClassID then
                            keyset[keyLabel] = i
                        end
                    else
                        keyset[keyLabel] = i
                    end
                end
            else
                -- Foreign class under All filter: enumerate names from the compressed store
                -- without decompressing. SpecID and disable are unknown until opened.
                if not GSE.isEmpty(GSESequences[k]) then
                    for i, _ in pairs(GSESequences[k]) do
                        keyset[k .. ",0," .. i .. ",0"] = i
                    end
                end
            end
        else
            if k == 0 and GSEOptions.filterList[Statics.Global] then
                for i, j in pairs(Library[k]) do
                    local disable = 0
                    if j.DisableEditor then
                        disable = 1
                    end
                    local keyLabel = k .. "," .. j.MetaData.SpecID .. "," .. i .. "," .. disable
                    keyset[keyLabel] = i
                end
            end
        end
    end

    return keyset
end

--- Return the Macro Icon for the specified Sequence
function GSE.GetMacroIcon(classid, sequenceIndex)
    classid = tonumber(classid)
    GSE.EnsureSequenceLoaded(classid, sequenceIndex)
    GSE.PrintDebugMessage("sequenceIndex: " .. (GSE.isEmpty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
    classid = tonumber(classid)
    local macindex = GetMacroIndexByName(sequenceIndex)
    local a, iconid, c = GetMacroInfo(macindex)
    if not GSE.isEmpty(a) then
        GSE.PrintDebugMessage(
            "Macro Found " ..
                a ..
                    " with iconid " ..
                        (GSE.isEmpty(iconid) and "of no value" or iconid) ..
                            " " .. (GSE.isEmpty(iconid) and L["with no body"] or c),
            GNOME
        )
    else
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        return GSEOptions.DefaultDisabledMacroIcon
    end

    local sequence = GSE.Library[classid][sequenceIndex]
    if GSE.isEmpty(sequence) then
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        return GSEOptions.DefaultDisabledMacroIcon
    end
    if GSE.isEmpty(sequence.Icon) and GSE.isEmpty(iconid) then
        GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.Metadata.SpecID, GNOME)
        if sequence.Metadata.SpecID == 0 then
            return "INV_MISC_QUESTIONMARK"
        else
            local _, _, _, specicon, _, _, _ =
                GetSpecializationInfoByID(
                    (GSE.isEmpty(sequence.Metadata.SpecID) and GSE.GetCurrentSpecID() or sequence.Metadata.SpecID)
                )
            if specicon then
                if type(specicon) == "string" then
                    GSE.PrintDebugMessage("No Sequence Icon setting to " .. strsub(specicon, 17), GNOME)
                    return strsub(specicon, 17)
                end
                return specicon
            end
            return "INV_MISC_QUESTIONMARK"
        end
    elseif GSE.isEmpty(iconid) and not GSE.isEmpty(sequence.Icon) then
        return sequence.Icon
    else
        return iconid
    end
end

local function trimMacroIconCandidate(value)
    local trimmed = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed
end

local function stripLeadingMacroIconConditionals(value)
    value = trimMacroIconCandidate(value)
    while string.sub(value, 1, 1) == "[" do
        local closing = string.find(value, "]", 1, true)
        if not closing then break end
        value = trimMacroIconCandidate(string.sub(value, closing + 1))
    end
    return value
end

local function normaliseMacroIconCandidate(value)
    value = stripLeadingMacroIconConditionals(value)
    value = trimMacroIconCandidate(value:gsub("^reset=%S+%s*", ""))
    while string.sub(value, 1, 1) == "!" do
        value = trimMacroIconCandidate(string.sub(value, 2))
    end
    return value
end

local function getMacroIconItemInfo(candidate)
    local icon = select(10, C_Item.GetItemInfo(candidate))
    if icon then
        return {
            name = candidate,
            iconID = icon,
        }
    end
end

local function getMacroIconSpellOrItemInfo(candidate, preferItem)
    candidate = normaliseMacroIconCandidate(candidate)
    if candidate == "" then return nil end

    if preferItem then
        local itemInfo = getMacroIconItemInfo(candidate)
        if itemInfo then return itemInfo end
    end

    local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(candidate) or candidate
    local spellinfo = safeGetSpellInfo(currentSpell) or safeGetSpellInfo(candidate)
    if spellinfo and spellinfo.iconID then return spellinfo end

    if tonumber(candidate) then
        spellinfo = safeGetSpellInfo(tonumber(candidate))
        if spellinfo and spellinfo.iconID then return spellinfo end
    end

    return getMacroIconItemInfo(candidate)
end

local function getMacroIconFallbackCandidateInfo(candidate, preferItem)
    for _, semicolonCandidate in ipairs(GSE.split(candidate or "", ";")) do
        semicolonCandidate = normaliseMacroIconCandidate(semicolonCandidate)
        for _, commaCandidate in ipairs(GSE.split(semicolonCandidate, ",")) do
            local iconInfo = getMacroIconSpellOrItemInfo(commaCandidate, preferItem)
            if iconInfo then return iconInfo end
        end
    end
end

local function getMacroIconCastSequenceInfo(candidate)
    for _, semicolonCandidate in ipairs(GSE.split(candidate or "", ";")) do
        for _, sequenceCandidate in ipairs(GSE.SplitCastSequence(semicolonCandidate)) do
            local _, _, sequenceEtc = GSE.GetConditionalsFromString(sequenceCandidate)
            local iconInfo = getMacroIconFallbackCandidateInfo(sequenceEtc)
            if iconInfo then return iconInfo end
        end
    end
end

local function getMacroLineResolvedIconInfo(line, suppressUIErrors)
    local cmd, etc = string.match(line or "", "^%s*/(%w+)%s+([^\n]+)")
    if not cmd or not etc then return nil end

    cmd = strlower(cmd)
    if not Statics.CastCmds[cmd] then return nil end
    if cmd == "stopmacro" or cmd == "cancelaura" or cmd == "cancelform" or cmd == "petautocastoff" or cmd == "petautocaston" then return nil end

    local preferItem = cmd == "use" or cmd == "usetoy" or cmd == "toy"
    local resolved = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(etc, suppressUIErrors)
    resolved = trimMacroIconCandidate(resolved)
    if resolved == "" then return nil end

    if cmd == "castsequence" then
        return getMacroIconCastSequenceInfo(resolved)
    end

    return getMacroIconFallbackCandidateInfo(resolved, preferItem)
end

function GSE.GetMacroTextIconInfo(str, suppressUIErrors)
    if string.sub(str or "", 14) == "/click GSE.Pau" then
        return {
            name = "GSE Pause",
            iconID = Statics.ActionsIcons.Pause,
        }
    end

    for line in string.gmatch((str or "") .. "\n", "([^\n]*)\n") do
        local iconInfo = getMacroLineResolvedIconInfo(line, suppressUIErrors)
        if iconInfo and iconInfo.iconID then return iconInfo end
    end
end

function GSE.GetCurrentButtonIconInfo(self, reseticon)
    if not (self and self.GetAttribute and self.GetName) then return nil end

    local step = self:GetAttribute("step") or 1
    local iteration = self:GetAttribute("iteration") or 1
    if iteration > 1 then
        step = step + iteration * 254
    end

    local gsebutton = self:GetName()
    local executionseq = GSE.SequencesExec and GSE.SequencesExec[gsebutton]
    local action = executionseq and executionseq[step]
    if not action then return nil end

    local foundSpell = action.spell and action.spell or ""
    local spellinfo = {}
    spellinfo.iconID = Statics.QuestionMarkIconID

    if reseticon == true then
        spellinfo.name = gsebutton
        spellinfo.iconID = Statics.Icons.GSE_Logo_Dark
        foundSpell = gsebutton
    elseif action.type == "macro" and action.macrotext then
        local macroIconInfo = GSE.GetMacroTextIconInfo(action.macrotext) or GSE.GetSpellsFromString(action.macrotext)
        if macroIconInfo and #macroIconInfo > 1 then
            macroIconInfo = macroIconInfo[1]
        end

        if macroIconInfo then
            spellinfo = macroIconInfo
        else
            -- Slash-command / spell-name parsers didn't find anything to
            -- harvest an icon from. Two more fallbacks before defaulting
            -- to macro.png:
            --
            --   1. "Macro Call" — the block body is just plain text that
            --      matches the name of an in-game WoW macro (e.g. the
            --      block contains "Need Need Stuff Here" verbatim to
            --      invoke a macro by name from inside a sequence). If
            --      that named macro exists AND has been given a real
            --      icon (not the default question mark), inherit that
            --      icon — same way Blizzard's macro UI shows it. The
            --      macro's name also flows into foundSpell so debug /
            --      tooltip strings read sensibly.
            --
            --   2. Otherwise (no matching WoW macro, OR the macro exists
            --      but is still on the default question-mark icon) —
            --      fall back to macro.png (Statics.Icons.Macros) so the
            --      step reads as "macro-typed" instead of just "?".
            --
            -- Display-only: doesn't write to action.Icon, so a real
            -- spell/macro icon will still take over if the block is
            -- later edited to include a /cast line, or if the user gives
            -- the named WoW macro a real icon afterwards.
            local resolved = false
            local trimmed = action.macrotext:match("^%s*(.-)%s*$") or ""
            if trimmed ~= "" and GetMacroIndexByName and GetMacroInfo then
                local idx = GetMacroIndexByName(trimmed)
                if idx and idx ~= 0 then
                    local mname, micon = GetMacroInfo(idx)
                    if mname and micon
                        and micon ~= Statics.QuestionMark
                        and micon ~= Statics.QuestionMarkIconID then
                        spellinfo.name = mname
                        spellinfo.iconID = micon
                        foundSpell = mname
                        resolved = true
                    end
                end
            end
            if not resolved then
                spellinfo.iconID = Statics.Icons.Macros
            end
        end

        if spellinfo and spellinfo.name then
            foundSpell = spellinfo.name
        end
    elseif action.type == "macro" then
        local mname, micon = GetMacroInfo(action.macro)
        if mname then
            spellinfo.name = mname
            spellinfo.iconID = micon
            foundSpell = spellinfo.name
        else
            -- The named WoW macro this action references doesn't exist
            -- (deleted from /macro or never created on this character).
            -- Match the macrotext path's behaviour: show macro.png so the
            -- step still reads as "macro-typed" rather than "unknown".
            spellinfo.iconID = Statics.Icons.Macros
        end
    elseif action.type == "item" then
        local mname, _, _, _, _, _, _, _, _, micon = C_Item.GetItemInfo(GSE.UnEscapeString(action.item))
        if mname then
            spellinfo.name = mname
            spellinfo.iconID = micon
            foundSpell = spellinfo.name
        end
    elseif action.type == "spell" then
        local spell = action.spell and GSE.UnEscapeString(action.spell) or nil
        if not GSE.isEmpty(spell) then
            local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(spell) or spell
            spellinfo = safeGetSpellInfo(currentSpell)
            if spellinfo then
                foundSpell = spellinfo.name
            else
                GSE.Print("Unable to find spell: " .. tostring(spell) .. " from " .. self:GetName() .. " - Compiled Step " .. step)
            end
        end
    end

    local actionIconIsFallback = GSE.IsFallbackIcon(action.Icon)
    if action.Icon and (not actionIconIsFallback or not (spellinfo and spellinfo.iconID)) then
        if not spellinfo then
            spellinfo = {}
        end
        spellinfo.iconID = action.Icon
    end

    return spellinfo, foundSpell, action
end

function GSE.GetSpellsFromString(str, suppressUIErrors)
    local spellinfo = {}
    if string.sub(str, 14) == "/click GSE.Pau" then
        spellinfo.name = "GSE Pause"
        spellinfo.iconID = Statics.ActionsIcons.Pause
    else
        for cmd, oetc in gmatch(str or "", "/(%w+)%s+([^\n]+)") do
            if strlower(cmd) == "castsequence" then
                local returnspells = {}
                local processed = {}
                for _, y in ipairs(GSE.split(oetc, ";")) do
                    for _, v in ipairs(GSE.SplitCastSequence(y)) do
                        local _, _, etc = GSE.GetConditionalsFromString(v)
                        local elements = GSE.split(etc, ",")

                        for _, v1 in ipairs(elements) do
                            local spellstuff = safeGetSpellInfo(string.trim(v1))
                            if spellstuff and spellstuff.name and not processed[v1] then
                                table.insert(returnspells, spellstuff)
                                processed[v1] = true
                            end
                        end
                    end
                end
                return returnspells
            elseif Statics.CastCmds[strlower(cmd)] then
                local _, _, etc = GSE.GetConditionalsFromString("/" .. cmd .. " " .. oetc)
                if string.sub(etc, 1, 1) == "/" then
                    etc = oetc
                end
                if cmd and etc and strlower(cmd) == "use" and tonumber(etc) and tonumber(etc) <= 16 then
                    -- we have a trinket
                else
                    local spell, _ = GSE.SafeSecureCmdOptionParse(etc, suppressUIErrors)
                    if spell then
                        spellinfo = safeGetSpellInfo(spell)
                    end
                end
            end
        end
    end
    if spellinfo and spellinfo.name then
        return spellinfo
    end
end

local function GetDebuggerTraceSpell(action, foundSpell)
    if not GSE.isEmpty(foundSpell) then return foundSpell end
    if not action then return nil end

    if not GSE.isEmpty(action.spell) then
        local spell = GSE.UnEscapeString(action.spell)
        local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(spell) or spell
        local spellInfo = safeGetSpellInfo(currentSpell)
        return (spellInfo and spellInfo.name) or spell
    end

    if action.type == "macro" and action.macrotext then
        local macroIconInfo = GSE.GetMacroTextIconInfo(action.macrotext, true) or GSE.GetSpellsFromString(action.macrotext, true)
        if macroIconInfo and #macroIconInfo > 1 then
            macroIconInfo = macroIconInfo[1]
        end
        if macroIconInfo and macroIconInfo.name then return macroIconInfo.name end
        return "Macro Text"
    end

    if action.type == "macro" and action.macro then
        local macroName = GetMacroInfo(action.macro)
        return macroName or action.macro
    end

    if action.type == "item" and action.item then
        local itemName = C_Item.GetItemInfo(GSE.UnEscapeString(action.item))
        return itemName or action.item
    end

    return nil
end

function GSE.UpdateIcon(self, reseticon)
    local step = self:GetAttribute("step") or 1
    local iteration = self:GetAttribute("iteration") or 1
    if iteration > 1 then
        step = step + iteration * 254
    end
    local gsebutton = self:GetName()
    if not reseticon and self:GetAttribute("combatreset") == true then
        GSE.UsedSequences[gsebutton] = true
    end
    local mods = self:GetAttribute("localmods") or nil
    local clickSerial = tonumber(self:GetAttribute("gseclickserial") or 0) or 0
    GSE.SequenceDebugLastClickSerials = GSE.SequenceDebugLastClickSerials or {}
    local isFreshSequenceClick = clickSerial > 0 and GSE.SequenceDebugLastClickSerials[gsebutton] ~= clickSerial

    local executionseq = GSE.SequencesExec and GSE.SequencesExec[gsebutton]
    local executionAction = executionseq and executionseq[step]

    local reset = self:GetAttribute("combatreset") and self:GetAttribute("combatreset") or false
    -- NOTE: 'X and X(...)' as the RHS of a multiple assignment collapses the call's
    -- return list to a single value, so foundSpell/action were silently always nil.
    -- Capture all three returns inside the existence guard instead.
    local spellinfo, foundSpell, action
    if GSE.GetCurrentButtonIconInfo then
        spellinfo, foundSpell, action = GSE.GetCurrentButtonIconInfo(self, reseticon)
    end
    if not action and executionAction then
        action = executionAction
        foundSpell = foundSpell or executionAction.spell or ""
    elseif action and GSE.isEmpty(foundSpell) and executionAction and executionAction.spell then
        foundSpell = executionAction.spell
    end
    if not action then
        if GSE.SequenceIconFrameUpdateFromButton then
            GSE.SequenceIconFrameUpdateFromButton(self, spellinfo, foundSpell, action)
        end
        return
    end
    if mods and isFreshSequenceClick then
        local modlist = {}
        for _, j in ipairs(strsplittable("|", mods)) do
            local a, b = string.split("=", j)
            if a == "MOUSEBUTTON" then
                modlist[a] = b
            else
                modlist[a] = b == "true" and true or false
            end
        end
        local trackerPayload = {
            SequenceName = gsebutton,
            ButtonName = gsebutton,
            Mods = modlist,
            HardwareEvent = modlist.MOUSEBUTTON,
            ClickSerial = clickSerial
        }
        if GSE.SequenceIconResolveSpamKey then
            trackerPayload.SpamKey = GSE.SequenceIconResolveSpamKey(gsebutton, modlist, gsebutton)
        end
        if WeakAuras and WeakAuras.ScanEvents then
            WeakAuras.ScanEvents(Statics.Messages.GSE_MODS_VISIBLE, gsebutton, modlist)
        end
        GSE:SendMessage(Statics.Messages.GSE_MODS_VISIBLE, trackerPayload)
    end
    if GSE.SequenceIconFrameUpdateFromButton then
        GSE.SequenceIconFrameUpdateFromButton(self, spellinfo, foundSpell, action)
    end
    if spellinfo and spellinfo.iconID then
        if WeakAuras and WeakAuras.ScanEvents then
            WeakAuras.ScanEvents(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, gsebutton, spellinfo)
        end
        GSE:SendMessage(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, {
            SequenceName = gsebutton,
            ButtonName = gsebutton,
            SpellInfo = spellinfo,
            Step = step,
            BlockPath = action and action.blockPath
        })
        -- When resetting (reseticon=true), override buttons keep their spell icon.
        -- The GSE logo reset visual is for the sequence button only, not the bar.
        if GSE.RefreshActionBarOverrideIcons and not reseticon then
            GSE.RefreshActionBarOverrideIcons(gsebutton, false)
        end
        if GSE.ButtonOverrides and not reseticon then
            for k, v in pairs(GSE.ButtonOverrides) do
                if v == gsebutton and _G[k] then
                    if
                        string.sub(k, 1, 5) == "ElvUI" or string.sub(k, 1, 4) == "CPB_" or string.sub(k, 1, 3) == "BT4" or
                            string.sub(k, 1, 4) == "NDui"
                     then
                        -- Yield to a real action the player dropped into this slot (matches the
                        -- Blizzard-bar branch below and getGSEButtonIcon) so the icon stops flickering.
                        if not (GSE.ActionBarSlotHasForeignAction and GSE.ActionBarSlotHasForeignAction(_G[k])) then
                            _G[k].icon:SetTexture(spellinfo.iconID)
                        end
                    else
                        if GSE.GameMode >= 11 then
                            local parent, slot = _G[k] and _G[k]:GetParent():GetParent(), _G[k] and _G[k]:GetID()
                            local page = parent and parent:GetAttribute("actionpage")
                            local actionSlot = page and slot and slot > 0 and (slot + page * 12 - 12)
                            if actionSlot then
                                local at = GetActionInfo(actionSlot)
                                if GSE.isEmpty(at) then
                                    _G[k].icon:SetTexture(spellinfo.iconID)

                                    _G[k].icon:Show()
                                    -- Sequence-name label on the override button.
                                    -- showActionBarLabel (default on) gates it; off
                                    -- writes an empty string so no label shows.
                                    _G[k].TextOverlayContainer.Count:SetText(
                                        GSEOptions.showActionBarLabel ~= false and gsebutton or "")
                                    _G[k].TextOverlayContainer.Count:SetTextScale(0.6)
                                end
                            end
                        else
                            if _G[k] then
                                if not InCombatLockdown() then
                                    _G[k]:Show()
                                end
                                _G[k].icon:SetTexture(spellinfo.iconID)
                                _G[k].icon:Show()
                            -- _G[k].TextOverlayContainer.Count:SetText(gsebutton)
                            -- _G[k].TextOverlayContainer.Count:SetTextScale(0.6)
                            end
                        end
                    end
                end
            end
        end
    end
    if not reset then
        GSE.UsedSequences[gsebutton] = true
    end
    if GSE.Utils and isFreshSequenceClick then
        GSE.TraceSequence(gsebutton, step, GetDebuggerTraceSpell(action, foundSpell), action and action.blockPath)
    end
    if clickSerial > 0 then
        GSE.SequenceDebugLastClickSerials[gsebutton] = clickSerial
    end
    GSE.WagoAnalytics:Switch(gsebutton .. "_" .. GSE.GetCurrentClassID(), true)
end

--- Re-apply the action-bar override label option live (from the options panel,
--- no /reload needed). The label text is written inside GSE.UpdateIcon, so just
--- re-run it for every overridden sequence to pick up showActionBarLabel.
function GSE.SetActionBarLabelEnabled()
    if not GSE.ButtonOverrides then return end
    local seen = {}
    for _, sequence in pairs(GSE.ButtonOverrides) do
        if sequence and _G[sequence] and not seen[sequence] then
            seen[sequence] = true
            GSE.UpdateIcon(_G[sequence], false)
        end
    end
end

--- Takes a collection of Sequences and returns a list of names
function GSE.GetSequenceNamesFromLibrary(library)
    local sequenceNames = {}
    for k, _ in pairs(library) do
        table.insert(sequenceNames, k)
    end
    return sequenceNames
end

--- This function returns in addition to the stepfunction for the KeyBind to Reset a sequence
function GSE.GetMacroResetImplementation()
    local activemods = {}
    local returnstring = ""
    local flagactive = false

    -- Extra null check just in case.
    if GSE.isEmpty(GSEOptions.MacroResetModifiers) then
        GSE.resetMacroResetModifiers()
    end

    for k, v in pairs(GSEOptions.MacroResetModifiers) do
        if v == true then
            flagactive = true
            if string.find(k, "Button") then
                table.insert(activemods, 'GetMouseButtonClicked() == "' .. k .. '"')
            else
                table.insert(activemods, "Is" .. k .. "KeyDown() == true")
            end
        end
    end
    if flagactive then
        returnstring = string.format(Statics.MacroResetSkeleton, table.concat(activemods, " and "))
    end
    return returnstring
end

--- This function takes a text string and compresses it without loading it to the library
function GSE.CompressSequenceFromString(importstring)
    local importStr = GSE.StripControlandExtendedCodes(importstring)
    local returnstr = ""
    local functiondefinition = GSE.FixQuotes(importStr) .. [===[
  return Sequences
  ]===]

    local fake_globals =
        setmetatable(
        {
            Sequences = {}
        },
        {
            __index = _G
        }
    )
    local func, err = loadstring(functiondefinition, "Storage")
    if func then
        -- Make the compiled function see this table as its "globals"
        setfenv(func, fake_globals)

        local TempSequences = assert(func())
        if not GSE.isEmpty(TempSequences) then
            for k, v in pairs(TempSequences) do
                returnstr = GSE.ExportSequence(v, k, false, "ID", false)
            end
        end
    end
    return returnstr
end

--- This function takes a text string and decompresses it without loading it to the library
function GSE.DecompressSequenceFromString(importstring)
    local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    local returnstr = ""
    local seqName = ""
    if
        (decompresssuccess) and (#actiontable == 2) and (type(actiontable[1]) == "string") and
            (type(actiontable[2]) == "table")
     then
        seqName = actiontable[1]
        returnstr = GSE.Dump(actiontable[2])
    end
    return returnstr, seqName, decompresssuccess
end

function GSE.GetSequenceSummary()
    local returntable = {}
    for k, v in ipairs(GSE.Library) do
        returntable[k] = {}
        for i, j in pairs(v) do
            if not (j["MetaData"] and j["MetaData"].noExport) then
                returntable[k][i] = {}
                returntable[k][i].Help = j["MetaData"].Help
                returntable[k][i].LastUpdated = j["MetaData"].LastUpdated
            end
        end
    end
    return returntable
end

local function buildAction(action, metaData, blockPath)
    if action.Type == Statics.Actions.Loop then
        -- we have a loop within a loop
        return GSE.processAction(action, metaData, nil, blockPath)
    else
        if action.type == "spell" and GSE.isEmpty(action.spell) then
            action.type = "macro"
            if action.macro == nil then action.macro = "" end
        end
        if GSE.isEmpty(action.type) then
            if not GSE.isEmpty(action.macro) then
                action.type = "macro"
            elseif not GSE.isEmpty(action.item) then
                action.type = "item"
            elseif not GSE.isEmpty(action.action) then
                action.type = "pet"
            elseif not GSE.isEmpty(action.toy) then
                action.type = "toy"
            elseif not GSE.isEmpty(action.spell) then
                action.type = "spell"
            else
                action.type = "macro"
                action.macro = ""
            end
        elseif action.type == "macro" and action.macro == nil and action.macrotext == nil then
            action.macro = ""
        end
        local spelllist = {}
        for k, v in pairs(action) do
            local value = v
            if k == "Disabled" or type(value) == "boolean" or k == "Type" or k == "Interval" then
                -- we dont want to do anything here
            else
                if string.sub(value, 1, 1) == "=" then
                    xpcall(
                        function()
                            local tempval = loadstring("return " .. string.sub(value, 2, string.len(value)))()
                            if tempval then
                                value = tostring(tempval)
                            else
                                GSE.Print(L["There was an error processing "] .. value, Statics.DebugModules["API"])
                            end
                        end,
                        function(err)
                            manageMissingVariable(string.sub(value, 2, string.len(value)))
                        end
                    )
                end

                if k == "spell" then
                    spelllist[k] =
                        GSE.GetSpellId(value, Statics.TranslatorMode.ID) or
                        GSE.GetSpellId(value, Statics.TranslatorMode.String)
                elseif k == "macro" then
                    if GSE.DecodeMacroEditorText then
                        value = GSE.DecodeMacroEditorText(value)
                    end
                    if string.sub(GSE.UnEscapeString(value), 1, 1) == "/" then
                        -- we have a line of macrotext
                        spelllist["macrotext"] =
                            GSE.UnEscapeString(GSE.CompileMacroText(value, Statics.TranslatorMode.String))
                    else
                        spelllist[k] = value
                    end
                    spelllist["unit"] = nil
                else
                    spelllist[k] = value
                end
            end
        end
        if blockPath then
            spelllist.blockPath = blockPath
        end
        return spelllist
    end
end

local function processRepeats(actionList)
    local inserts = {}
    local removes = {}
    for k, v in ipairs(actionList) do
        if type(v) == "table" and v.Action and v.Interval then
            table.insert(inserts, {Action = v.Action, Interval = v.Interval + 1, Start = k})
            table.insert(removes, k)
        end
    end

    for i = #removes, 1, -1 do
        table.remove(actionList, removes[i])
    end

    for _, v in ipairs(inserts) do
        local startInterval = v["Interval"]
        if startInterval == 1 then
            startInterval = 2
        end
        local insertcount = math.ceil((#actionList - v["Start"]) / startInterval)
        insertcount = math.ceil((#actionList + insertcount - v["Start"]) / startInterval)
        local interval = v["Interval"]
        table.insert(actionList, v["Start"], v["Action"])
        for i = 1, insertcount do
            local insertpos = v["Start"] + i * interval
            table.insert(actionList, insertpos, v["Action"])
        end
    end
    return actionList
end

function GSE.processAction(action, metaData, variables, path)
    if action.Disabled then
        return
    end
    if action.Type == Statics.Actions.Loop then
        local actionList = {}
        -- setup the interation
        for idx, v in ipairs(action) do
            local childPath = path and (path .. "." .. idx) or tostring(idx)
            local builtaction = GSE.processAction(v, metaData, variables, childPath)
            table.insert(actionList, builtaction)
        end
        local returnActions = {}
        local loop = tonumber(action.Repeat)
        if GSE.isEmpty(loop) or loop < 1 then
            loop = 1
        end
        for _ = 1, loop do
            if action.StepFunction == Statics.Priority or action.StepFunction == Statics.ReversePriority then
                local limit = 1
                local step = 1
                local looplimit = 0
                for x = 1, #actionList do
                    looplimit = looplimit + x
                end
                if action.StepFunction == Statics.Priority then
                    for _ = 1, looplimit do
                        table.insert(returnActions, actionList[step])
                        if step == limit then
                            limit = limit % #actionList + 1
                            step = 1
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                        else
                            step = step + 1
                        end
                    end
                else
                    for _ = looplimit, 1, -1 do
                        table.insert(returnActions, actionList[step])
                        if step == 1 then
                            limit = limit % #actionList + 1
                            step = limit
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                        else
                            step = step - 1
                        end
                    end
                end
            elseif action.StepFunction == Statics.Random then
                for _ = 1, #actionList do
                    local randomAction = math.random(1, #actionList)
                    table.insert(returnActions, actionList[randomAction])
                    table.remove(actionList, randomAction)
                end
            else
                for _, v in ipairs(actionList) do
                    table.insert(returnActions, v)
                end
            end
        end
        -- process repeats for the block
        return processRepeats(GSE.FlattenTable(returnActions))
    elseif action.Type == Statics.Actions.Pause then
        local PauseActions = {}
        local clicks = action.Clicks and action.Clicks or 0
        if not GSE.isEmpty(action.MS) then
            if action.MS == "GCD" or action.MS == "~~GCD~~" then
                clicks = GSE.GetGCD() * 1000 / GSE.GetClickRate()
            else
                clicks = action.MS and action.MS and 1000 -- pause for 1 second if no ms specified.
                clicks = math.ceil(clicks / GSE.GetClickRate())
            end
        end
        if clicks > 1 then
            for loop = 1, clicks do
                table.insert(PauseActions, {["type"] = "click", ["blockPath"] = path})
                GSE.PrintDebugMessage(loop, "Storage1")
            end
        end
        -- print(#PauseActions, GSE.Dump(action))
        return PauseActions
    elseif action.Type == Statics.Actions.If then
        -- process repeats for the block
        if GSE.isEmpty(action.Variable) then
            GSE.Print(L["If Blocks Require a variable."], L["Macro Compile Error"])
            return
        end
        local funct = action.Variable
        if string.sub(funct, 1, 1) == "=" then
            funct = string.sub(funct, 2, string.len(funct))
        end

        -- User-defined GSE.V.* variables can throw at runtime (missing locale
        -- keys, stale spell ids, nil C_API responses). A throw here would kill
        -- the whole reload pass for every sequence. Treat any error as a
        -- false branch decision ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â the macro continues to compile.
        local val = false
        local fn, loadErr = loadstring("return " .. funct)
        if fn then
            local ok, result = pcall(fn)
            if ok then val = result
            else GSE.PrintDebugMessage("If-block eval error: " .. tostring(result), "Storage") end
        else
            GSE.PrintDebugMessage("If-block load error: " .. tostring(loadErr), "Storage")
        end

        local actions
        local branchPath
        if val then
            actions = action[1]
            branchPath = path and (path .. ".1") or "1"
        else
            if action[2] then
                actions = action[2]
                branchPath = path and (path .. ".2") or "2"
            else
                return
            end
        end

        local actionList = {}
        for idx, v in ipairs(actions) do
            local childPath = branchPath and (branchPath .. "." .. idx) or tostring(idx)
            local builtaction = GSE.processAction(v, metaData, variables, childPath)
            table.insert(actionList, builtaction)
        end

        return actionList
    elseif action.Type == Statics.Actions.Action then
        local builtstuff = buildAction(action, metaData, path)
        return builtstuff
    elseif action.Type == Statics.Actions.Repeat then
        if GSE.isEmpty(action.Interval) then
            if not GSE.isEmpty(action.Repeat) then
                action.Interval = action.Repeat
                action.Repeat = nil
            else
                action.Interval = 2
            end
        end

        local returnAction = {
            ["Action"] = buildAction(action, metaData, path),
            ["Interval"] = tonumber(action.Interval)
        }

        return returnAction
    elseif action.Type == Statics.Actions.Embed then
        -- Get the sequence and its setup version then compile the actions
        if action.Sequence then
            local sequence = GSE.FindSequence(action.Sequence)
            if sequence then
                return GSE.CompileTemplate(GSE.UnEscapeTable(GSE.TranslateSequence(sequence.Versions[GSE.GetActiveSequenceVersion(action.Sequence)], Statics.TranslatorMode.String)))
            end
        end
        return
    end
end

--- Compiles a macro template into a macro
function GSE.CompileTemplate(macro)
    if #macro.Actions < 1 then
        -- return early nothing to compile
        return {}
    end
    -- print(#macro.Actions)
    local template = GSE.CloneSequence(macro)
    setmetatable(
        template.Actions,
        {
            __index = function(t, k)
                for _, v in ipairs(k) do
                    if not t then
                        error("attempt to index nil")
                    end
                    t = rawget(t, v)
                end
                return t
            end,
            __newindex = function(t, key, v)
                local last_k
                for _, k in ipairs(key) do
                    k, last_k = last_k, k
                    if k ~= nil then
                        local parent_t = t
                        t = rawget(parent_t, k)
                        if t == nil then
                            t = {}
                            rawset(parent_t, k, t)
                        end
                        if type(t) ~= "table" then
                            error("Unexpected subtable", 2)
                        end
                    end
                end
                rawset(t, last_k, v)
            end
        }
    )

    local actions = {
        ["Type"] = "Loop",
        ["Repeat"] = "1"
    }
    for _, action in ipairs(template.Actions) do
        table.insert(actions, action)
    end
    local compiledMacro = GSE.processAction(actions, template.InbuiltVariables, template.Variables)

    return processRepeats(GSE.FlattenTable(compiledMacro)), template
end

local function PCallCreateGSE3Button(spelllist, name, combatReset)
    if GSE.isEmpty(spelllist) then
        GSE.Print("Macro missing for " .. name)
        return
    end

    for k, v in ipairs(spelllist) do
        if v.type == "macro" then
            spelllist[k].unit = nil
        end
    end

    if GSE.isEmpty(combatReset) then
        combatReset = false
    end

    -- name = name .. "T"
    GSE.SequencesExec[name] = spelllist
    local gsebutton = _G[name]
    local buttoncreate = GSE.isEmpty(gsebutton)
    -- if button already exists no need to recreate it.  Maybe able to create this in combat.
    if buttoncreate then
        gsebutton = CreateFrame("Button", name, nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        gsebutton:SetAttribute("type", "spell")
        gsebutton:SetAttribute("step", 1)
        gsebutton:SetAttribute("name", name)
        gsebutton.UpdateIcon = GSE.UpdateIcon
        -- Single registered edge so a keybind advances the step ONCE per press,
        -- not once on down and again on up.
        gsebutton:RegisterForClicks("AnyUp")

        gsebutton:SetAttribute("combatreset", combatReset)
    end
    -- Pin the executor to the key-UP edge irrespective of the
    -- ActionButtonUseKeyDown CVar. The action-bar override delegate
    -- (SecureActionButton type="click") forwards clickbutton:Click(button) with
    -- NO down argument, i.e. down=false, so the executor must cast on down=false
    -- to work under both CVar states. Direct key-DOWN latency is provided by a
    -- separate relay button (see GSE.GetKeybindClickTarget) rather than by
    -- letting this button follow the CVar.
    gsebutton:SetAttribute("useOnKeyDown", false)

    -- Modifier-pause attributes. Read inside the secure OnClick handler
    -- (cannot read GSEOptions directly from secure context) so re-stamp on
    -- every button (re)build to pick up option toggles. The reload prompt
    -- on the option's UI ensures fresh attribute values on next play
    -- session even though a live toggle won't take effect until reload.
    gsebutton:SetAttribute("shiftpause", GSEOptions.ShiftPause and true or false)
    gsebutton:SetAttribute("altpause",   GSEOptions.AltPause   and true or false)
    gsebutton:SetAttribute("ctrlpause",  GSEOptions.CtrlPause  and true or false)

    for k, v in pairs(spelllist[1]) do
        if k == "blockPath" then
            -- not transferred to the secure button
        elseif k == "macrotext" then
            gsebutton:SetAttribute("macro", nil)
            gsebutton:SetAttribute("unit", nil)
            gsebutton:SetAttribute(k, v)
        elseif k == "macro" then
            gsebutton:SetAttribute("macrotext", nil)
            gsebutton:SetAttribute("unit", nil)
            gsebutton:SetAttribute(k, v)
        else
            gsebutton:SetAttribute(k, v)
        end
    end

    local steps = {}

    for k, v in ipairs(spelllist) do
        local line
        steps[k] = {}
        for i, j in pairs(v) do
            if i ~= "blockPath" then
                line = i .. "\002" .. tostring(j)
                tinsert(steps[k], line)
            end
        end
    end

    local compressedsteps = {}
    for _, v in ipairs(steps) do
        if #v > 0 then
            table.insert(compressedsteps, string.join("|", unpack(v)))
        end
    end
    local bigsequence = {}

    local finalsteps = 1
    local temptable = {}
    for k, v in ipairs(compressedsteps) do
        table.insert(temptable, v)
        finalsteps = finalsteps + 1
        if finalsteps == 254 or k == #compressedsteps then
            table.insert(bigsequence, string.join("\001", unpack(temptable)))
            temptable = {}
            finalsteps = 1
        end
    end

    local executestring =
        "compressedspelllist = newtable([=======[" ..
        string.join("]=======],[=======[", unpack(bigsequence)) ..
            "]=======])" ..
                [==[
maxsequences = 1
spelllist = newtable()
for k,v in ipairs(compressedspelllist) do
    tinsert(spelllist, newtable())
    local splitA = newtable()
    local startA = 1
    while true do
        local sa, ea = string.find(v, "\001", startA, true)
        if not sa then
            tinsert(splitA, string.sub(v, startA))
            break
        end
        tinsert(splitA, string.sub(v, startA, sa - 1))
        startA = ea + 1
    end
    for x, y in ipairs(splitA) do
        tinsert(spelllist[k], newtable())
        local splitB = newtable()
        local startB = 1
        while true do
            local sb, eb = string.find(y, "|", startB, true)
            if not sb then
                tinsert(splitB, string.sub(y, startB))
                break
            end
            tinsert(splitB, string.sub(y, startB, sb - 1))
            startB = eb + 1
        end
        for _, j in ipairs(splitB) do
            local sa, ea = string.find(j, "\002", 1, true)
            if sa then
                local a = string.sub(j, 1, sa - 1)
                local b = string.sub(j, ea + 1)
                if a == "spell" then
                    local numericSpell = tonumber(b)
                    if numericSpell then b = numericSpell end
                end
                spelllist[k][x][a] = b
            end
        end
    end
    maxsequences = k
end
]==]

    gsebutton:Execute(executestring)
    if combatReset then
        _G[name]:SetAttribute("step", 1)
        _G[name]:SetAttribute("iteration", 1)
    end

    local clickexecution =
        GSE.GetMacroResetImplementation() ..
        [=[
    if (self:GetAttribute('shiftpause') and IsShiftKeyDown())
        or (self:GetAttribute('altpause') and IsAltKeyDown())
        or (self:GetAttribute('ctrlpause') and IsControlKeyDown()) then
        self:SetAttribute('type', 'macro')
        self:SetAttribute('macro', nil)
        self:SetAttribute('unit', nil)
        self:SetAttribute('macrotext', '')
        return
    end
    local mods = "RALT=" .. tostring(IsRightAltKeyDown()) .. "|" ..
    "LALT=".. tostring(IsLeftAltKeyDown()) .. "|" ..
    "AALT=" .. tostring(IsAltKeyDown()) .. "|" ..
    "RCTRL=" .. tostring(IsRightControlKeyDown()) .. "|" ..
    "LCTRL=" .. tostring(IsLeftControlKeyDown()) .. "|" ..
    "ACTRL=" .. tostring(IsControlKeyDown()) .. "|" ..
    "RSHIFT=" .. tostring(IsRightShiftKeyDown()) .. "|" ..
    "LSHIFT=" .. tostring(IsLeftShiftKeyDown()) .. "|" ..
    "ASHIFT=" .. tostring(IsShiftKeyDown()) .. "|" ..
    "AMOD=" .. tostring(IsModifierKeyDown()) .. "|" ..
    "MOUSEBUTTON=" .. GetMouseButtonClicked()
    self:SetAttribute('localmods', mods)
    local step = self:GetAttribute('step')
    local iteration = self:GetAttribute('iteration') or 1
    step = tonumber(step)
    iteration = tonumber(iteration)
    for k,v in pairs(spelllist[iteration][step]) do
        if k == "macrotext" then
            self:SetAttribute("macro", nil )
            self:SetAttribute("unit", nil )
        elseif k == "macro" then
            self:SetAttribute("macrotext", nil )
            self:SetAttribute("unit", nil )
        elseif k == "Icon" then
            -- skip
        end
        self:SetAttribute(k, v )
    end

    if step < #spelllist[iteration] then
        step = step % #spelllist[iteration] + 1
    else
        iteration = iteration % maxsequences + 1
        step = 1
    end
    self:SetAttribute('step', step)
    self:SetAttribute('iteration', iteration)
    local gseclickserial = tonumber(self:GetAttribute('gseclickserial') or 0) or 0
    self:SetAttribute('gseclickserial', gseclickserial + 1)
    self:CallMethod('UpdateIcon')
    ]=]
    if GSEOptions.DebugPrintModConditionsOnKeyPress then
        clickexecution = Statics.PrintKeyModifiers .. clickexecution
    end
    if buttoncreate then
        gsebutton:WrapScript(gsebutton, "OnClick", clickexecution)
    end
    GSE.UpdateIcon(_G[name], false)
end

--- Build GSE3 Executable Buttons
function GSE.CreateGSE3Button(spelllist, name, combatReset)
    local status, err = pcall(PCallCreateGSE3Button, spelllist, name, combatReset)
    if err or not status then
        GSE.Print(
            string.format(
                "%s " ..
                    L["was unable to be programmed.  This macro will not fire until errors in the macro are corrected."],
                name
            ),
            "BROKEN MACRO"
        )
        if GSE.PrintDebugMessage then GSE.PrintDebugMessage(tostring(err), "Storage") end
    end
end

--- Return the frame name a keybind should click for sequence `name`.
--
-- The executor button casts on the key-UP edge (down=false) so it stays
-- compatible with the action-bar override delegate, which forwards Click(button)
-- with no down flag. That means a direct keybind bound straight to the executor
-- also resolves on key-up -- fine, except a player running
-- ActionButtonUseKeyDown=1 expects key-DOWN latency.
--
-- When the CVar is on we hand the keybind a thin relay button instead: it fires
-- on AnyDown (useOnKeyDown=true) and forwards into the executor via type="click"
-- (Click(button) -> down=false), so the cast lands on the key-down edge without
-- double-stepping. This mirrors how an action-bar override button already relays
-- into the sequence. When the CVar is off (or we are in combat and cannot build
-- the relay) we bind straight to the executor, which resolves on key-up.
function GSE.GetKeybindClickTarget(name)
    if GSE.isEmpty(name) or GSE.isEmpty(_G[name]) then
        return name
    end
    if C_CVar.GetCVar("ActionButtonUseKeyDown") ~= "1" then
        return name
    end
    local relayName = name .. "_KD"
    local relay = _G[relayName]
    if GSE.isEmpty(relay) then
        if InCombatLockdown() then
            -- RegisterForClicks/SetAttribute are restricted on protected frames
            -- in combat; fall back to the executor until the next OOC rebind.
            return name
        end
        relay = CreateFrame("Button", relayName, nil, "SecureActionButtonTemplate")
        relay.gseKeyDownRelay = true
        relay:RegisterForClicks("AnyDown")
    elseif not relay.gseKeyDownRelay then
        -- A frame already owns this name and it is NOT one of our relays (e.g. a
        -- user sequence literally named "<name>_KD"). Don't clobber it -- bind
        -- the keybind straight to the executor (resolves on key-up) instead.
        return name
    end
    if not InCombatLockdown() then
        relay:SetAttribute("type", "click")
        relay:SetAttribute("clickbutton", _G[name])
        relay:SetAttribute("useOnKeyDown", true)
    end
    return relayName
end

function GSE.UpdateVariable(variable, name, status)
    -- A save of variable X cancels any pending Companion-bridge delete for
    -- the same name ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â the user's intent ("X exists") trumps a queued
    -- delete request, and the next sync will push the freshly-saved
    -- variable back to the server. No-op when no Companion is in use.
    if GSE.CompanionCancelPendingDelete then
        GSE.CompanionCancelPendingDelete("variable", name)
    end
    GSE.ComputeVariableDependencies(variable)
    local compressedvariable = GSE.EncodeMessage(variable)
    GSEVariables[name] = compressedvariable
    local actualfunct, error = loadstring("return " .. variable.funct)
    if error then
        if GSE.PrintDebugMessage then GSE.PrintDebugMessage(tostring(error), "Storage") end
    end
    if type(actualfunct) == "function" then
        GSE.V[name] = actualfunct()
    end
    if GSE.V[name] and type(GSE.V[name]()) == "boolean" then
        GSE.BooleanVariables["GSE.V['" .. name .. "']()"] = "GSE.V['" .. name .. "']()"
    end
    -- Re-register or remove event/message callbacks based on updated variable config
    if variable.eventEnabled and not GSE.isEmpty(variable.eventNames) then
        GSE.RegisterVariableEvents(name, variable.eventNames)
    else
        GSE.UnregisterVariableEvents(name)
    end
    GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, name)
end

--- One-off backfill: ensure every sequence/variable/macro carries a
-- top-level LastUpdated. Without it, the Companion uploads with no
-- timestamp and the server's newer-wins gate can't compare. Older mod
-- versions only stamped LastUpdated on edits ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â older never-edited
-- records are missing it, and macros never had a timestamp at all
-- before this release.
--
-- Idempotent: gated by GSEOptions.LastUpdatedBackfill_v1, runs once,
-- writes only to entries where the field is missing. Safe to call from
-- any post-load hook (we use PLAYER_ENTERING_WORLD).
function GSE.BackfillLastUpdated()
    if GSEOptions and GSEOptions.LastUpdatedBackfill_v1 then return end
    local now = GSE.GetTimestamp()
    local touched = 0

    -- Sequences: GSE.Library[classid][name] is the in-memory shape;
    -- GSESequences[classid][name] is the encoded SV blob. Re-encode
    -- on stamp so the SV survives reload.
    if GSE.Library then
        for classid, classLib in pairs(GSE.Library) do
            if type(classLib) == "table" then
                for name, seq in pairs(classLib) do
                    if type(seq) == "table" and not seq.LastUpdated then
                        seq.LastUpdated = now
                        if GSESequences and GSESequences[classid] then
                            GSESequences[classid][name] = GSE.EncodeMessage({name, seq})
                        end
                        touched = touched + 1
                    end
                end
            end
        end
    end

    -- Variables: flat shape, GSEVariables[name] is the variable table.
    if GSEVariables then
        for _, v in pairs(GSEVariables) do
            if type(v) == "table" and not v.LastUpdated then
                v.LastUpdated = now
                touched = touched + 1
            end
        end
    end

    -- Macros: GSEMacros has both global entries (GSEMacros[name]) and
    -- character-scoped subtables (GSEMacros["char-realm"][name]). A
    -- bucket vs node entry is distinguished by the presence of macro
    -- node fields (text/value/managed) on the value itself.
    if GSEMacros then
        for _, scopeOrNode in pairs(GSEMacros) do
            if type(scopeOrNode) == "table" then
                local isNode = scopeOrNode.text ~= nil
                    or scopeOrNode.value ~= nil
                    or scopeOrNode.icon ~= nil
                    or scopeOrNode.Managed ~= nil
                if isNode then
                    if not scopeOrNode.LastUpdated then
                        scopeOrNode.LastUpdated = now
                        touched = touched + 1
                    end
                else
                    for _, node in pairs(scopeOrNode) do
                        if type(node) == "table" and not node.LastUpdated then
                            node.LastUpdated = now
                            touched = touched + 1
                        end
                    end
                end
            end
        end
    end

    if GSEOptions then
        GSEOptions.LastUpdatedBackfill_v1 = true
    end
    if touched > 0 then
        GSE.PrintDebugMessage(
            string.format("LastUpdated backfill: stamped %d records", touched),
            "Storage"
        )
    end
end

local function CleanMacroBookText(text)
    if type(text) ~= "string" then return text end
    if GSE.DecodeMacroEditorText then
        return GSE.DecodeMacroEditorText(text)
    elseif GSE.UnEscapeString then
        return GSE.UnEscapeString(text)
    end
    return text
end

function GSE.UpdateMacro(node, category)
    -- Save-cancels-delete (see UpdateVariable for rationale).
    if node and node.name and GSE.CompanionCancelPendingDelete then
        GSE.CompanionCancelPendingDelete("macro", node.name)
    end
    -- Stamp LastUpdated so server-side newer-wins resolution can pick the
    -- most-recently-edited copy when one Companion is syncing the same
    -- macro across two WoW accounts. UTC-formatted via GetServerTime() so
    -- it's comparable across timezones.
    if node then
        node.LastUpdated = GSE.GetTimestamp()
        node.text = CleanMacroBookText(node.text)
    end
    if not InCombatLockdown() then
        GSE:UnregisterEvent("UPDATE_MACROS")
        local slot = GetMacroIndexByName(node.name)
        if slot > 0 then
            EditMacro(slot, node.name, node.icon, node.text)
        else
            node.value = CreateMacro(node.name, node.icon, node.text, category)
            if category then
                local char, realm = UnitFullName("player")
                GSEMacros[char .. "-" .. realm][node.name] = node
            else
                GSEMacros[node.name] = node
            end
        end
        GSE:RegisterEvent("UPDATE_MACROS")
        GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, node.name)
    end
    return node
end

function GSE.ImportMacro(node)
    local characterMacro = false
    local source = GSEMacros
    if node.category == "p" then
        characterMacro = true
        local char, realm = UnitFullName("player")
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        source = GSEMacros[char .. "-" .. realm]
    end
    node.category = nil

    source[node.name] = GSE.UpdateMacro(node, characterMacro)
    GSE.Print(L["Macro"] .. " " .. node.name .. L[" was imported."], L["Macros"])
    GSE.ManageMacros()
    GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, node.name)
end

-- Should the macro editor translate/colour spell IDs <-> names live as the user
-- types? Driven by GSEOptions.DelayedSpellTranslations:
--   off (default) - yes, translate live as you type while editing.
--   on            - no, always defer translation/colouring to focus-loss, which
--                   reduces editor lag on older machines.
-- When this returns false the editor still stores everything the user types; only
-- the derived translation/colouring is deferred until the box loses focus.
function GSE.ShouldTranslateLive()
    return not (GSEOptions and GSEOptions.DelayedSpellTranslations)
end

function GSE.CompileMacroText(text, mode)
    if GSE.isEmpty(mode) then
        mode = Statics.TranslatorMode.ID
    end
    if GSE.DecodeMacroEditorText then
        text = GSE.DecodeMacroEditorText(text)
    end
    if type(text) ~= "string" then return "" end
    local lines = GSE.SplitMeIntoLines(text)
    for k, v in ipairs(lines) do
        local value = GSE.UnEscapeString(v)
        if mode == Statics.TranslatorMode.String then
            if string.sub(value, 1, 1) == "=" then
                local functionresult, error = loadstring("return " .. string.sub(value, 2, string.len(value)))

                if error then
                    GSE.Print(L["There was an error processing "] .. v, L["Variables"])
                    GSE.Print(error, L["Variables"])
                end
                if functionresult and type(functionresult) == "function" then
                    -- Capture the protected result instead of invoking the
                    -- function twice. The previous form ran the function
                    -- inside pcall AND again outside; functions with side
                    -- effects fired twice, and a function that succeeded
                    -- once but failed on the second call would error
                    -- outside the protected scope.
                    local ok, result = pcall(functionresult)
                    if ok then
                        value = result
                    else
                        value = ""
                    end
                end
            end
            if value ~= nil and type(value) ~= "string" then value = tostring(value) end
            if type(value) == "string" and value:match("^%s*%-%-") then
                lines[k] = "" -- strip the comments
            else
                if value then
                    lines[k] = GSE.TranslateString(value, mode, false)
                else
                    lines[k] = ""
                end
            end
        else
            lines[k] = GSE.TranslateString(value, mode, false)
        end
    end
    local finallines = {}
    for _, v in ipairs(lines) do
        if not GSE.isEmpty(v) then
            table.insert(finallines, v)
        end
    end
    return table.concat(finallines, "\n")
end

local function isManagedMacroFallbackIcon(icon)
    return GSE.IsFallbackIcon(icon)
end

local function getManagedMacroSequenceIcon(sequenceName)
    local button = _G[sequenceName]
    if button and GSE.GetCurrentButtonIconInfo then
        local iconInfo = GSE.GetCurrentButtonIconInfo(button, false)
        if iconInfo and iconInfo.iconID and not isManagedMacroFallbackIcon(iconInfo.iconID) then
            return iconInfo.iconID
        end
    end

    local executionseq = GSE.SequencesExec and GSE.SequencesExec[sequenceName]
    if not executionseq then return nil end

    for step = 1, #executionseq do
        local action = executionseq[step]
        if action then
            local iconInfo
            if action.type == "macro" and action.macrotext then
                iconInfo = GSE.GetMacroTextIconInfo(action.macrotext) or GSE.GetSpellsFromString(action.macrotext)
                if iconInfo and #iconInfo > 1 then
                    iconInfo = iconInfo[1]
                end
            elseif action.type == "macro" and action.macro then
                local _, micon = GetMacroInfo(action.macro)
                if micon then iconInfo = { iconID = micon } end
            elseif action.type == "item" and action.item then
                local mname, _, _, _, _, _, _, _, _, micon = C_Item.GetItemInfo(GSE.UnEscapeString(action.item))
                if mname and micon then iconInfo = { name = mname, iconID = micon } end
            elseif action.type == "spell" and action.spell then
                local spell = GSE.UnEscapeString(action.spell)
                local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(spell) or spell
                iconInfo = safeGetSpellInfo(currentSpell)
            end

            if action.Icon and action.IconUserSelected and not isManagedMacroFallbackIcon(action.Icon) then
                iconInfo = iconInfo or {}
                iconInfo.iconID = action.Icon
            end

            if iconInfo and iconInfo.iconID and not isManagedMacroFallbackIcon(iconInfo.iconID) then
                return iconInfo.iconID
            end
        end
    end
end

function GSE.GetManagedMacroStubIcon(sequenceName, currentIcon)
    if not isManagedMacroFallbackIcon(currentIcon) then return currentIcon end
    return getManagedMacroSequenceIcon(sequenceName) or currentIcon or Statics.QuestionMark
end

function GSE.ManageMacros()
    for k, v in pairs(GSEMacros) do
        if v.Managed then
            local macroIndex = GetMacroIndexByName(k)
            if macroIndex ~= v.value then
                v.value = macroIndex
                GSEMacros[k].value = macroIndex
            end
            local node = {
                ["name"] = k,
                ["value"] = v.value,
                ["icon"] = GSE.GetManagedMacroStubIcon and GSE.GetManagedMacroStubIcon(k, v.icon) or v.icon,
                ["text"] = GSE.CompileMacroText(
                    (v.managedMacro and v.managedMacro or v.text),
                    Statics.TranslatorMode.String
                )
            }
            GSE.UpdateMacro(node)
        else
            local slot = GetMacroIndexByName(k)
            if slot then
                local mname, micon, mbody = GetMacroInfo(slot)
                if mname then
                    GSEMacros[mname] = {
                        ["name"] = mname,
                        ["value"] = slot,
                        ["icon"] = micon,
                        ["text"] = mbody,
                        ["manageMacro"] = mbody
                    }
                else
                    GSEMacros[k] = nil
                end
            else
                if type(GSEMacros[k]) ~= "table" then
                    GSEMacros[k] = nil
                end
            end
        end
    end
    local char, realm = UnitFullName("player")
    if GSE.isEmpty(realm) then
        realm = string.gsub(GetRealmName(), "%s*", "")
    end

    if GSEMacros[char .. "-" .. realm] then
        for k, v in pairs(GSEMacros[char .. "-" .. realm]) do
            if k == "value" then
                GSEMacros[char .. "-" .. realm][k] = nil
            else
                if v.Managed then
                    local macroIndex = GetMacroIndexByName(k)
                    if macroIndex ~= v.value then
                        v.value = macroIndex
                        GSEMacros[char .. "-" .. realm][k].value = macroIndex
                    end
                    local node = {
                        ["name"] = k,
                        ["value"] = v.value,
                        ["icon"] = GSE.GetManagedMacroStubIcon and GSE.GetManagedMacroStubIcon(k, v.icon) or v.icon,
                        ["text"] = GSE.CompileMacroText(
                            (v.managedMacro and v.managedMacro or v.text),
                            Statics.TranslatorMode.String
                        )
                    }
                    GSE.UpdateMacro(node)
                else
                    local slot = GetMacroIndexByName(k)
                    if slot then
                        local mname, micon, mbody = GetMacroInfo(slot)
                        if mname then
                            GSEMacros[char .. "-" .. realm][mname] = {
                                ["name"] = mname,
                                ["value"] = slot,
                                ["icon"] = micon,
                                ["text"] = mbody,
                                ["manageMacro"] = mbody
                            }
                        else
                            GSEMacros[char .. "-" .. realm][k] = nil
                        end
                    else
                        if type(GSEMacros[char .. "-" .. realm][k]) ~= "table" then
                            GSEMacros[char .. "-" .. realm][k] = nil
                        end
                    end
                end
            end
        end
    end

    -- Snapshot and restore WoW macros required by active sequences.
    -- Iterates global (0) and current-class libraries only; other classes are not
    -- loaded at runtime and their sequences are not executing.
    if GSE.isEmpty(GSEMacros) then GSEMacros = {} end
    local currentClass = GSE.GetCurrentClassID()
    for _, classid in ipairs({0, currentClass}) do
        local classlib = GSE.Library[classid]
        if classlib then
            for seqname, seq in pairs(classlib) do
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Macros) == "table" then
                        for _, macname in ipairs(deps.Macros) do
                            local slot = GetMacroIndexByName(macname)
                            if slot and slot > 0 then
                                -- Macro exists on this character: refresh the account-level snapshot.
                                local mname, micon, mbody = GetMacroInfo(slot)
                                if mname then
                                    GSEMacros[macname] = {
                                        name        = mname,
                                        value       = slot,
                                        icon        = micon,
                                        text        = mbody,
                                        manageMacro = mbody,
                                    }
                                end
                            else
                                -- Macro missing on this character: restore from account-level store.
                                local stored = GSEMacros[macname]
                                if stored and not GSE.isEmpty(stored.text) then
                                    CreateMacro(
                                        macname,
                                        stored.icon or Statics.QuestionMark,
                                        CleanMacroBookText(stored.text),
                                        GSE.SetMacroLocation()
                                    )
                                    GSE.Print(
                                        string.format(
                                            L["Restored macro '%s' required by sequence '%s'."],
                                            macname, seqname
                                        ),
                                        L["Macros"]
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

function GSE.CheckVariable(vartext)
    local actualfunct, error = loadstring("return " .. vartext)
    return actualfunct, error
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Storage") end


local _, GSE = ...
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

-- ─────────────────────────────────────────────────────────────────────────────
-- GSEStore: where GSE content lives at rest
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Kept at the top of Storage.lua because this file owns the SavedVariables.
-- Everything else reaches content through GSE.Store(kind) and never names a
-- SavedVariable, so the layout changes here and nowhere else.
--
-- At rest there is one SavedVariable, GSEStore, keyed by identity:
--
--   GSEStore = { v = 1,
--     sequence = { [classid] = { [id] = envelope } },
--     variable = { [classid] = { [id] = envelope } },
--     macro    = { [classid] = { [id] = envelope } } }
--
--   envelope = { Name, Body, PlatformID, Author,       -- every kind
--                Scope }                                -- macros
--
--   GSEStore.character[GUID] = { Label, ClassID, Macros = { [macroId] = slot } }
--     -- which character macros each character holds (see "Characters")
--
--   GSEStore.alias[oldId] = newId      -- where a sequence moved (see "Sequences")
--
-- id is the GSE.Tools PlatformID once an element has synced, and a
-- "local-..." id until then (a PlatformID is 24 hex, so the two cannot
-- collide). Body is the element as it has always been stored -- an encoded
-- string for sequences and variables, a node table for macros -- and may be
-- sealed. The envelope beside it is plain, which is the point: the Mod can
-- always record where an element lives and what it is called, even for a
-- protected element whose Body it cannot re-encode.
--
-- Sequences are worked on in GSEStore itself, by id: GSE.Library[classid][id]
-- holds the decoded sequence and the envelope holds its Name, which is a
-- label and nothing else. See "Sequences" below.
--
-- Variables and macros still go through WORKING VIEWS in the shapes the rest
-- of the Mod has always used: variable[name] = Body, macro[name] = node plus
-- per-character buckets macro[charKey][name], and their PlatformID sidecars.
-- They are rebuilt from GSEStore once per session and never saved. At
-- PLAYER_LOGOUT -- which fires before WoW writes SavedVariables, on /reload
-- and on exit alike -- reconcileStore() folds them back into envelopes.
--
-- Migration: the first load of this build finds the old SavedVariables
-- (GSESequences, GSEVariables, GSEMacros and the *PlatformIDs sidecars) and
-- moves them in. They stay declared in the TOC -- WoW only loads names the TOC
-- declares, so dropping them would leave nothing to migrate from -- and are
-- set to nil afterwards so they drop out of the file. It runs whenever any of
-- them is non-nil, not only once: GSEStore entries always win.
--
-- Where things land: sequences keep their class. EVERY macro and variable
-- goes to class 0 (global); an author moves one to a class or spec by editing
-- it. Class space is separate from macro scope: a character macro keeps
-- Scope = "character", and the characters holding it keep references to it.

local STORE_VERSION = 1
local KINDS = { "sequence", "variable", "macro" }
local LEGACY = {
    sequence = "GSESequences", variable = "GSEVariables", macro = "GSEMacros",
    sequencePid = "GSEPlatformIDs", variablePid = "GSEVariablePlatformIDs",
    macroPid = "GSEMacroPlatformIDs",
}

local VIEWS   -- kind -> working view; nil until the first GSE.Store call
local settleSequenceIds, indexSequenceNames   -- defined under "Sequences"
local INDEX   -- what the views were built from, for reconcileStore

-- Macro fields that are the macro itself. Two per-character copies that agree
-- on these are one macro held by two characters, whatever else differs
-- (LastUpdated, Author).
local MACRO_CONTENT = { "text", "managedMacro", "manageMacro", "Ranks", "icon", "Managed", "GSEProtected",
    "Versions", "MetaData" }

local localIdCounter = 0
--- A fresh id for an element GSE.Tools has not seen yet.
function GSE.NewLocalId()
    localIdCounter = localIdCounter + 1
    return string.format("local-%d-%d-%06x", (time and time()) or 0, localIdCounter,
        math.random(0, 0xFFFFFF))
end

local function isLocalId(id)
    return type(id) == "string" and id:sub(1, 6) == "local-"
end

local function isMacroNode(t)
    return GSE.IsStoredMacroNode and GSE.IsStoredMacroNode(t) or false
end

local function copyShallow(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Deep: a macro's Versions and MetaData are tables, and two copies read from
-- two characters are never the same table.
local function sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not sameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function macroContentEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, k in ipairs(MACRO_CONTENT) do
        if not sameValue(a[k], b[k]) then return false end
    end
    return true
end

-- MetaData out of an encoded sequence Body, or nil. Only asked when a Body is
-- new or has changed, so an unchanged library is never decoded at logout.
local function sequenceMeta(body)
    if type(body) ~= "string" or not GSE.DecodeMessage then return nil end
    local pok, ok, decoded = pcall(GSE.DecodeMessage, body)
    if not (pok and ok) or type(decoded) ~= "table" then return nil end
    local seq
    if decoded.type == "COLLECTION" and type(decoded.payload) == "table"
        and type(decoded.payload.Sequences) == "table" then
        local _, first = next(decoded.payload.Sequences)
        seq = first
    else
        seq = decoded[2] or decoded
    end
    return type(seq) == "table" and type(seq.MetaData) == "table" and seq.MetaData or nil
end

local function bucket(store, kind, classid)
    local k = store[kind]
    if type(k[classid]) ~= "table" then k[classid] = {} end
    return k[classid]
end

-- Find an envelope of a kind by PlatformID in any class.
local function findByPid(store, kind, pid)
    if not pid then return nil end
    for classid, envs in pairs(store[kind]) do
        for id, env in pairs(envs) do
            if env.PlatformID == pid or id == pid then return classid, id, env end
        end
    end
end

-- ── Characters ──────────────────────────────────────────────────────────────
--
-- A character macro lives in GSEStore.macro like any other; which characters
-- hold it lives on the CHARACTER:
--
--   GSEStore.character[GUID] = { Label, ClassID, Macros = { [macroId] = slot } }
--
-- so "what does this character have" is one lookup, and a character that is
-- gone is one record to remove. Label is display only. ClassID is learned the
-- first time the character is seen logged in -- UnitClass answers only for the
-- current character -- so a character known only from old data has none.
--
-- Where a character macro is filed:
--   * every macro migrated from the old tables is global (class 0);
--   * a macro created in game goes in its character's class, or global when
--     that is not known;
--   * a macro held by characters of more than one class -- or by any whose
--     class is not known -- is global.
-- The last rule only ever moves a macro TOWARDS global. Nothing is moved out
-- of global automatically; that is an author's decision, made by editing. So a
-- macro never changes class because of who happened to log in when.

-- The class of the character logged in now, or nil.
local function currentClassId()
    if not UnitClass then return nil end
    local _, _, classId = UnitClass("player")
    return classId
end

local function characters(store)
    if type(store.character) ~= "table" then store.character = {} end
    return store.character
end

local function charRecord(store, charKey)
    local chars = characters(store)
    local rec = chars[charKey]
    if type(rec) ~= "table" then rec = {}; chars[charKey] = rec end
    if type(rec.Macros) ~= "table" then rec.Macros = {} end
    return rec
end

-- A macro envelope by id, in whatever class it is filed.
local function locateMacro(store, id)
    for classid, envs in pairs(store.macro) do
        if envs[id] then return classid, envs[id] end
    end
end

local function referenced(store, id)
    for _, rec in pairs(characters(store)) do
        if rec.Macros and rec.Macros[id] ~= nil then return true end
    end
    return false
end

-- The characters holding a macro, and their shared class if they all have one
-- and it is known (nil otherwise).
local function holders(store, id)
    local list, class, mixed = {}, nil, false
    for charKey, rec in pairs(characters(store)) do
        if rec.Macros and rec.Macros[id] ~= nil then
            list[#list + 1] = charKey
            if not rec.ClassID then mixed = true
            elseif class == nil then class = rec.ClassID
            elseif class ~= rec.ClassID then mixed = true end
        end
    end
    return list, (not mixed) and class or nil
end

-- Move a character macro to global when its holders no longer share the class
-- it is filed in. Only ever towards global; see above.
local function settleMacroClass(store, id)
    local fromClass, env = locateMacro(store, id)
    if not env or env.Scope ~= "character" or fromClass == 0 then return end
    local _, class = holders(store, id)
    if class ~= fromClass then
        store.macro[fromClass][id] = nil
        bucket(store, "macro", 0)[id] = env
    end
end

local function rekeyMacroRefs(store, oldId, newId)
    for _, rec in pairs(characters(store)) do
        if rec.Macros and rec.Macros[oldId] ~= nil then
            rec.Macros[newId], rec.Macros[oldId] = rec.Macros[oldId], nil
        end
    end
end


-- ── Migration ───────────────────────────────────────────────────────────────

local function addCharacterMacro(store, charKey, name, node, pid)
    local body = copyShallow(node)
    local slot = body.value
    body.value = nil
    -- Migrated macros are global, full stop: the characters holding them have
    -- not been seen under this build, so none of their classes is known.
    local envs = bucket(store, "macro", 0)
    local id
    for eid, env in pairs(envs) do
        if env.Scope == "character" and env.Name == name and macroContentEqual(env.Body, body) then
            id = eid
            if (body.LastUpdated or "") > (env.Body.LastUpdated or "") then env.Body = body end
            break
        end
    end
    if not id then
        id = (pid and not findByPid(store, "macro", pid)) and pid or GSE.NewLocalId()
        envs[id] = { Name = name, Scope = "character", Body = body, PlatformID = pid }
    end
    charRecord(store, charKey).Macros[id] = slot or 0
end

-- Move whatever the old SavedVariables hold into the store.
--
-- The old tables WIN over anything already in GSEStore, because of how they
-- can come to exist alongside it. This build clears them at load and again at
-- every logout, so once it has run they are only ever present because
-- something wrote them while WoW was closed -- the Companion's Mode B, or its
-- PlatformID write-back. That is newer intent than the store. On a genuine
-- first run the store is empty, so there is nothing to conflict with. (A
-- downgrade cannot leave both either: an older Mod does not declare GSEStore,
-- so WoW drops it from the file on the next save.)
--
-- A legacy entry matches an envelope by PlatformID, or by name in the same
-- place; a match is updated in place, moving class if the legacy copy is filed
-- in another one. Anything else becomes a new envelope.
local function upsert(store, kind, classid, name, fields, match)
    local pid = fields.PlatformID
    local fromClass, id, env = findByPid(store, kind, pid)
    if not env then
        for eid, e in pairs(store[kind][classid] or {}) do
            if e.Name == name and (not match or match(e)) then fromClass, id, env = classid, eid, e end
        end
    end
    if env and fromClass ~= classid then
        store[kind][fromClass][id] = nil
        bucket(store, kind, classid)[id] = env
    end
    if not env then
        id = pid or GSE.NewLocalId()
        env = {}
        bucket(store, kind, classid)[id] = env
    end
    env.Name = name
    for k, v in pairs(fields) do env[k] = v end
    return id, env
end

local function migrateLegacy(store)
    local seqs  = _G[LEGACY.sequence]
    local vars  = _G[LEGACY.variable]
    local macs  = _G[LEGACY.macro]
    local sPid  = type(_G[LEGACY.sequencePid]) == "table" and _G[LEGACY.sequencePid] or {}
    local vPid  = type(_G[LEGACY.variablePid]) == "table" and _G[LEGACY.variablePid] or {}
    local mPid  = type(_G[LEGACY.macroPid]) == "table" and _G[LEGACY.macroPid] or {}

    if type(seqs) == "table" then
        for classid, names in pairs(seqs) do
            if type(names) == "table" then
                for name, body in pairs(names) do
                    local meta = sequenceMeta(body)
                    local author = meta and meta.Author or ""
                    local pid = sPid[name .. "|" .. author] or (meta and meta.PlatformID)
                    upsert(store, "sequence", classid, name,
                        { Body = body, PlatformID = pid, Author = author })
                end
            end
        end
    end

    if type(vars) == "table" then
        for name, body in pairs(vars) do
            upsert(store, "variable", 0, name, { Body = body, PlatformID = vPid[name] })
        end
    end

    if type(macs) == "table" then
        for key, v in pairs(macs) do
            if isMacroNode(v) then
                upsert(store, "macro", 0, key, { Scope = "account", Body = v, PlatformID = mPid[key] },
                    function(e) return e.Scope ~= "character" end)
            elseif type(v) == "table" then
                -- A per-character bucket: GUID-keyed, or a legacy "Name-Realm"
                -- key for a character not seen since the GUID change. It
                -- becomes that character's record; a legacy key moves to the
                -- GUID the next time that character logs in.
                local rec = charRecord(store, key)
                for name, node in pairs(v) do
                    if isMacroNode(node) then
                        -- This copy replaces whatever this character held
                        -- under the name, then joins an identical macro or
                        -- starts one.
                        for id in pairs(rec.Macros) do
                            local _, env = locateMacro(store, id)
                            if env and env.Name == name then rec.Macros[id] = nil end
                        end
                        addCharacterMacro(store, key, name, node, mPid[name])
                    end
                end
            end
        end
        -- A character macro no character holds any more is gone.
        local drop = {}
        for classid, envs in pairs(store.macro) do
            for id, env in pairs(envs) do
                if env.Scope == "character" and not referenced(store, id) then
                    drop[#drop + 1] = { classid, id }
                end
            end
        end
        for _, d in ipairs(drop) do store.macro[d[1]][d[2]] = nil end
    end

    for _, global in pairs(LEGACY) do _G[global] = nil end
end

-- ── Sequences ───────────────────────────────────────────────────────────────
--
-- A sequence is GSEStore.sequence[classid][id] = { Name, Body, PlatformID,
-- Author }, and GSE.Library[classid][id] is its decoded form. Everything that
-- refers to a sequence holds its id. Name is what the user sees and types; the
-- only way from a name to a sequence is FindSequenceId, which is for input --
-- an import, a command, a name typed into an Embed -- and nothing else.
--
-- An id never changes during a session. A sequence made in game gets a local
-- id at once; when it has a PlatformID the next load moves it there
-- (settleSequenceIds) before anything is built from it, and records the move
-- in GSEStore.alias. Keybinds and overrides live in each character's own
-- GSE_C, which cannot be rewritten while that character is logged out, so they
-- are resolved through the alias when they are next read (ResolveSequenceId).

local NAMES = {}   -- [classid][name] = id: the label index

local function seqEnvs(classid)
    return bucket(GSEStore, "sequence", classid)
end

-- Move each sequence that has a PlatformID off its local id.
settleSequenceIds = function(store)
    -- Every id in use, in any class: two classes must not end up holding one.
    local taken = {}
    for _, envs in pairs(store.sequence) do
        for id in pairs(envs) do taken[id] = true end
    end
    for _, envs in pairs(store.sequence) do
        local moves = {}
        for id, env in pairs(envs) do
            if isLocalId(id) and type(env.PlatformID) == "string" and env.PlatformID ~= id then
                moves[#moves + 1] = id
            end
        end
        for _, id in ipairs(moves) do
            local env = envs[id]
            -- Never onto an id another sequence holds; that one keeps it.
            if not taken[env.PlatformID] then
                envs[id] = nil
                envs[env.PlatformID] = env
                taken[id], taken[env.PlatformID] = nil, true
                store.alias[id] = env.PlatformID
            end
        end
    end
end

indexSequenceNames = function()
    -- A sequence's button is named by its id; the GSES<n> handles an earlier
    -- build kept here are gone.
    GSEStore.button, GSEStore.nextButton = nil, nil
    NAMES = {}
    for classid, envs in pairs(GSEStore.sequence) do
        local names = {}
        NAMES[classid] = names
        for id, env in pairs(envs) do
            -- Two sequences may share a name now; the label then finds the one
            -- whose id sorts first, so which one is stable.
            if type(env.Name) == "string" and (names[env.Name] == nil or id < names[env.Name]) then
                names[env.Name] = id
            end
        end
    end
end

local function ensureStore()
    if type(GSEStore) ~= "table" or GSEStore.v == nil or not VIEWS then GSE.LoadStore() end
end

--- The id a stored id now goes by: itself, or where it moved to.
function GSE.ResolveSequenceId(id)
    ensureStore()
    local seen = 0
    while type(id) == "string" and GSEStore.alias[id] and seen < 8 do
        id, seen = GSEStore.alias[id], seen + 1
    end
    return id
end

--- The envelope for a sequence id, and its class. Searches every class when
-- classid is nil.
function GSE.SequenceEnvelope(id, classid)
    ensureStore()
    id = GSE.ResolveSequenceId(id)
    if id == nil then return nil end
    if classid ~= nil then
        local envs = GSEStore.sequence[classid]
        local env = envs and envs[id]
        if env then return env, classid end
        return nil
    end
    for c, envs in pairs(GSEStore.sequence) do
        if envs[id] then return envs[id], c end
    end
end

--- Every stored sequence of a class: { [id] = envelope }. Read only.
function GSE.SequenceEnvelopes(classid)
    ensureStore()
    return GSEStore.sequence[classid] or {}
end

--- The id and class of the sequence carrying a PlatformID: the one stored
-- under it, or -- until the next load moves it there -- the one whose envelope
-- names it.
function GSE.SequenceIdByPlatformID(pid)
    if type(pid) ~= "string" or pid == "" then return nil end
    local env, c = GSE.SequenceEnvelope(pid)
    if env then return GSE.ResolveSequenceId(pid), c end
    local classid, id = findByPid(GSEStore, "sequence", pid)
    return id, classid
end

--- A stored variable's or macro's id, by name: an account macro before a
-- character one. Nil for one made this session, which is filed -- and given
-- an id -- at logout.
function GSE.StoredElementId(kind, name)
    ensureStore()
    local fallback
    for _, envs in pairs(GSEStore[kind] or {}) do
        for id, env in pairs(envs) do
            if env.Name == name then
                if kind ~= "macro" or env.Scope ~= "character" then return id end
                fallback = fallback or id
            end
        end
    end
    return fallback
end

--- A stored variable's or macro's name, by id.
function GSE.StoredElementName(kind, id)
    ensureStore()
    for _, envs in pairs(GSEStore[kind] or {}) do
        if envs[id] then return envs[id].Name end
    end
end

-- ── Embed blocks ────────────────────────────────────────────────────────────
--
-- An Embed block names the sequence it embeds twice: SequenceID, the id, and
-- Sequence, its label. It runs the sequence with that id when this machine has
-- it, and otherwise the one the label finds -- content travels, and on someone
-- else's machine only a PlatformID means anything. Every save brings both up
-- to date (NormaliseEmbeds); anything leaving the machine carries a PlatformID
-- or no id at all, never a local one.

--- The sequence an Embed block runs, and its id.
function GSE.ResolveEmbed(block)
    if type(block) ~= "table" then return nil end
    local ref = rawget(block, "SequenceID")
    if type(ref) == "string" and ref ~= "" then
        local id = GSE.ResolveSequenceId(ref)
        if GSE.SequenceEnvelope(id) then return GSE.GetSequence(id), id end
    end
    local name = rawget(block, "Sequence")
    if type(name) == "string" and name ~= "" then return GSE.FindSequence(name) end
    return nil
end

-- Every Embed block in a table, however deep (Loop children, If branches).
-- rawget, like walkTableForDeps: block tables may carry an __index that
-- expects array paths.
local function eachEmbed(t, fn, seen)
    seen = seen or {}
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if rawget(t, "Type") == Statics.Actions.Embed then fn(t) end
    for _, v in pairs(t) do
        if type(v) == "table" then eachEmbed(v, fn, seen) end
    end
end

--- Bring a sequence's Embed blocks up to date: the id follows any move to a
--- PlatformID, the label follows the embedded sequence's current name, and a
--- block that has only a label gains the id it resolves to. With forExport,
--- a local id -- meaningless anywhere else -- becomes the embedded sequence's
--- PlatformID, or is dropped so the label decides.
-- Returns true when anything changed.
function GSE.NormaliseEmbeds(sequence, forExport)
    if type(sequence) ~= "table" or type(sequence.Versions) ~= "table" then return false end
    local changed = false
    eachEmbed(sequence.Versions, function(block)
        local beforeId, beforeName = block.SequenceID, block.Sequence
        local _, id = GSE.ResolveEmbed(block)
        if id then
            block.SequenceID = id
            block.Sequence = GSE.SequenceName(id) or block.Sequence
        end
        if forExport and isLocalId(block.SequenceID) then
            local env = GSE.SequenceEnvelope(block.SequenceID)
            block.SequenceID = env and env.PlatformID or nil
        end
        if block.SequenceID ~= beforeId or block.Sequence ~= beforeName then changed = true end
    end)
    return changed
end

-- ── Buttons ─────────────────────────────────────────────────────────────────
--
-- Each sequence runs from a secure button named by the sequence's id. Keybinds
-- and action-bar overrides hold that id, and everything that shows a sequence
-- shows its label, GSE.SequenceName(id).

--- The id of a stored sequence, through any alias it has moved by; nil for
--- anything else. This is also the name of its secure button.
function GSE.StoredSequenceId(id)
    id = GSE.ResolveSequenceId(id)
    if id == nil or not GSE.SequenceEnvelope(id) then return nil end
    return id
end

--- Bring this character's keybinds and action-bar overrides up to date: each
--- names the sequence it runs by id. Older builds stored the sequence's name,
--- and a sequence that has since moved to its PlatformID is still held under
--- its old id (GSE_C is per character, so it cannot be rewritten while the
--- character is logged out). Once per login, before anything is bound. A
--- reference to nothing that exists is left as it is: it binds nothing, as
--- before.
function GSE.UpdateCharacterSequenceRefs()
    if type(GSE_C) ~= "table" then return end
    local function toId(v)
        if type(v) ~= "string" or v == "" then return v end
        local resolved = GSE.ResolveSequenceId(v)
        if GSE.SequenceEnvelope(resolved) then return resolved end
        return GSE.FindSequenceId(v) or v      -- a name, from before ids
    end
    local function fixBinds(t)
        for key, v in pairs(t) do
            if key ~= "LoadOuts" then t[key] = toId(v) end
        end
    end
    local function fixOverrides(buttons)
        for _, bind in pairs(buttons) do
            if type(bind) == "table" then bind.Sequence = toId(bind.Sequence) end
        end
    end
    for _, spec in pairs(type(GSE_C.KeyBindings) == "table" and GSE_C.KeyBindings or {}) do
        if type(spec) == "table" then
            fixBinds(spec)
            for _, loadout in pairs(type(spec.LoadOuts) == "table" and spec.LoadOuts or {}) do
                if type(loadout) == "table" then fixBinds(loadout) end
            end
        end
    end
    local ab = type(GSE_C.ActionBarBinds) == "table" and GSE_C.ActionBarBinds or {}
    for _, buttons in pairs(type(ab.Specialisations) == "table" and ab.Specialisations or {}) do
        if type(buttons) == "table" then fixOverrides(buttons) end
    end
    for _, loadouts in pairs(type(ab.LoadOuts) == "table" and ab.LoadOuts or {}) do
        if type(loadouts) == "table" then
            for _, buttons in pairs(loadouts) do
                if type(buttons) == "table" then fixOverrides(buttons) end
            end
        end
    end
    -- The shared profiles hold ids too (Profiles.lua).
    if GSE.UpdateProfileSequenceRefs then GSE.UpdateProfileSequenceRefs() end
end

--- The class a stored variable or macro is filed in, by name; nil for one
--- made this session and not yet filed.
function GSE.StoredElementClass(kind, name)
    ensureStore()
    local id = kind == "variable" and INDEX.variable[name] or (kind == "macro" and INDEX.macroAccount[name])
    if not id then return nil end
    for classid, envs in pairs(GSEStore[kind] or {}) do
        if envs[id] then return classid end
    end
end

--- Whether a variable or account macro is live for the character playing:
--- global, or the current class's. One not yet filed is live.
function GSE.ElementAvailable(kind, name)
    local classid = GSE.StoredElementClass(kind, name)
    return classid == nil or classid == 0 or classid == currentClassId()
end

--- A sequence's label.
function GSE.SequenceName(id, classid)
    local env = GSE.SequenceEnvelope(id, classid)
    return env and env.Name or nil
end

--- The id of a sequence by its label, and its class. With a classid, that
-- class; otherwise the current class, then global -- the order the runtime
-- has always resolved a name in. With everywhere, every other class after.
function GSE.FindSequenceId(name, classid, everywhere)
    if type(name) ~= "string" or name == "" then return nil end
    ensureStore()
    local order = {}
    if classid ~= nil then order[1] = classid
    else
        local cur = GSE.GetCurrentClassID and GSE.GetCurrentClassID()
        if cur then order[#order + 1] = cur end
        if cur ~= 0 then order[#order + 1] = 0 end
    end
    if everywhere then
        for c = 0, 13 do order[#order + 1] = c end
    end
    for _, c in ipairs(order) do
        local id = NAMES[c] and NAMES[c][name]
        if id and GSEStore.sequence[c] and GSEStore.sequence[c][id] then return id, c end
    end
end

--- Store a sequence's encoded body under its id, creating the envelope if it
-- is new. Moves it from another class if it is filed elsewhere. The name is
-- the label to show; it is not part of the identity.
function GSE.PutSequenceBody(classid, id, name, body)
    ensureStore()
    local env, from = GSE.SequenceEnvelope(id)
    if env and from ~= classid then
        GSEStore.sequence[from][id] = nil
        if NAMES[from] and NAMES[from][env.Name] == id then NAMES[from][env.Name] = nil end
    end
    env = env or {}
    seqEnvs(classid)[id] = env
    if env.Name and env.Name ~= name and NAMES[classid] and NAMES[classid][env.Name] == id then
        NAMES[classid][env.Name] = nil
    end
    env.Name, env.Body = name, body
    NAMES[classid] = NAMES[classid] or {}
    if NAMES[classid][name] == nil or id < NAMES[classid][name] then NAMES[classid][name] = id end
    if GSE.SettleCollections then GSE.SettleCollections("sequence", name, id, classid) end
    return env
end

--- Write a loaded sequence back over its stored body -- unless the stored
-- body is sealed, which is never rewritten in the clear. For derived changes
-- (icons, migrations) to a sequence already stored; returns true if written.
function GSE.StoreSequenceBody(classid, id, sequence)
    local env = GSE.SequenceEnvelopes(classid)[id]
    if not env or GSE.IsProtectedAtRest(env.Body, sequence) then return false end
    env.Body = GSE.EncodeMessage({env.Name, sequence})
    return true
end

--- Forget a stored sequence.
function GSE.RemoveSequence(classid, id)
    ensureStore()
    local envs = GSEStore.sequence[classid]
    local env = envs and envs[id]
    if not env then return end
    envs[id] = nil
    if NAMES[classid] and NAMES[classid][env.Name] == id then
        NAMES[classid][env.Name] = nil
        -- Another sequence of the same name, if any, is found by it now.
        for oid, o in pairs(envs) do
            if o.Name == env.Name and (NAMES[classid][env.Name] == nil or oid < NAMES[classid][env.Name]) then
                NAMES[classid][env.Name] = oid
            end
        end
    end
end

--- The id a sequence arriving from outside should be stored under: its
-- PlatformID when it has one, else the sequence already filed under that name
-- in that class (an import replaces), else a new local id.
function GSE.SequenceIdForIncoming(classid, name, sequence)
    local pid = type(sequence) == "table" and type(sequence.MetaData) == "table" and sequence.MetaData.PlatformID
    if type(pid) == "string" and pid ~= "" then return GSE.ResolveSequenceId(pid) end
    local id = GSE.FindSequenceId(name, classid)
    return id or GSE.NewLocalId()
end

-- ── Scope of variables and macros ───────────────────────────────────────────
--
-- A variable or macro is global, class or spec level exactly as a sequence is:
-- MetaData.SpecID is 0 (or absent) for global, 1-13 for a class, a spec id
-- above that. Its envelope is filed in that class's bucket, at every load
-- (fileElementsByScope) -- so a change of scope takes effect from the next
-- load. Variables and account macros are filed by it whenever it is known; a
-- character macro only when its author set it -- otherwise the holders rule in
-- "Characters" files it.
--
-- At runtime only the current class and global are live: a variable of another
-- class is not compiled into GSE.V and a macro of another class is not written
-- to the player's macros. Where two share a name, the current class's wins over
-- the global one, as a sequence's does.

-- The class a variable's or macro's body asks to be filed in, or nil when it
-- does not say. A variable body is encoded; a macro body is its node.
local function elementClassOf(kind, body)
    local meta
    if kind == "variable" then
        if type(body) ~= "string" or not GSE.DecodeMessage then return nil end
        local pok, ok, decoded = pcall(GSE.DecodeMessage, body)
        meta = pok and ok and type(decoded) == "table" and decoded.MetaData or nil
    elseif type(body) == "table" then
        meta = body.MetaData
    end
    local spec = type(meta) == "table" and tonumber(meta.SpecID) or nil
    if spec == nil then return nil end
    if spec <= 0 then return 0 end
    if spec <= 13 then return spec end
    local ok, classid = pcall(GSE.GetClassIDforSpec, spec)
    return ok and tonumber(classid) or nil
end

-- File each variable and macro envelope in the class its body names.
local function fileElementsByScope(store)
    for _, kind in ipairs({"variable", "macro"}) do
        local moves = {}
        for classid, envs in pairs(store[kind]) do
            for id, env in pairs(envs) do
                if kind == "variable" or env.Scope ~= "character" or elementClassOf(kind, env.Body) ~= nil then
                    local target = elementClassOf(kind, env.Body)
                    if target ~= nil and target ~= classid then moves[#moves + 1] = {classid, id, target} end
                end
            end
        end
        for _, m in ipairs(moves) do
            local env = store[kind][m[1]][m[2]]
            store[kind][m[1]][m[2]] = nil
            bucket(store, kind, m[3])[m[2]] = env
        end
    end
end

-- The classes to read a kind's buckets in: the current class, then global,
-- then the rest -- so a name held twice resolves to the current class's.
local function classOrder(byClass)
    local order, cur = {}, currentClassId()
    if cur and byClass[cur] then order[#order + 1] = cur end
    if byClass[0] and cur ~= 0 then order[#order + 1] = 0 end
    for classid in pairs(byClass) do
        if classid ~= cur and classid ~= 0 then order[#order + 1] = classid end
    end
    return order
end

-- ── Views ───────────────────────────────────────────────────────────────────

local function buildViews(store)
    -- *Collections: collection provenance by name, as the *Pid sidecars carry
    -- ids -- the envelope's Collections, which the views have no other place for.
    local views = { variable = {}, macro = {}, variablePid = {}, macroPid = {},
        variableCollections = {}, macroCollections = {} }
    local index = { variable = {}, macroAccount = {}, macroChar = {}, shadowed = {} }

    for _, classid in ipairs(classOrder(store.variable)) do
        local envs = store.variable[classid]
        for id, env in pairs(envs) do
            if views.variable[env.Name] ~= nil then
                index.shadowed[id] = true
            else
                views.variable[env.Name] = env.Body
                index.variable[env.Name] = id
                if env.PlatformID then views.variablePid[env.Name] = env.PlatformID end
                if type(env.Collections) == "table" and next(env.Collections) then
                    views.variableCollections[env.Name] = copyShallow(env.Collections)
                end
            end
        end
    end

    for _, classid in ipairs(classOrder(store.macro)) do
        local envs = store.macro[classid]
        for id, env in pairs(envs) do
            if env.Scope ~= "character" then
                if views.macro[env.Name] ~= nil then
                    index.shadowed[id] = true
                else
                    -- The same table, not a copy: ManageMacros updates an
                    -- account node in place (its slot), and that is the node
                    -- that persists.
                    views.macro[env.Name] = env.Body
                    index.macroAccount[env.Name] = id
                end
            end
            if env.PlatformID and env.Name then views.macroPid[env.Name] = env.PlatformID end
            if env.Name and type(env.Collections) == "table" and next(env.Collections) then
                local held = views.macroCollections[env.Name] or {}
                for k, v in pairs(env.Collections) do held[k] = v end
                views.macroCollections[env.Name] = held
            end
        end
    end
    -- Each character's bucket, from its record's references.
    for charKey, rec in pairs(characters(store)) do
        for id, slot in pairs(rec.Macros or {}) do
            local _, env = locateMacro(store, id)
            if env then
                local b = views.macro[charKey]
                if type(b) ~= "table" or isMacroNode(b) then b = {}; views.macro[charKey] = b end
                if b[env.Name] ~= nil then
                    index.shadowed[id] = true
                else
                    local node = copyShallow(env.Body)
                    node.value = (slot ~= 0) and slot or nil
                    b[env.Name] = node
                    index.macroChar[charKey] = index.macroChar[charKey] or {}
                    index.macroChar[charKey][env.Name] = id
                end
            end
        end
    end
    return views, index
end

-- ── Reconcile ───────────────────────────────────────────────────────────────

-- A copy of a non-empty table, else nil: an envelope carries no empty fields.
local function nonEmpty(t)
    if type(t) ~= "table" or next(t) == nil then return nil end
    return copyShallow(t)
end

-- Move an envelope to its PlatformID once it has one.
local function rekey(envs, id, env, seen)
    if env.PlatformID and isLocalId(id) and env.PlatformID ~= id then
        envs[id] = nil
        envs[env.PlatformID] = env
        seen[env.PlatformID] = true
        return env.PlatformID
    end
    return id
end

local function dropUnseen(store, kind, seen, shadowed)
    for _, envs in pairs(store[kind]) do
        local gone = {}
        for id in pairs(envs) do
            if not seen[id] and not shadowed[id] then gone[#gone + 1] = id end
        end
        for _, id in ipairs(gone) do envs[id] = nil end
    end
end

local function reconcileVariables(store, views, index, seen)
    for name, body in pairs(views.variable) do
        local id = index.variable[name]
        local classid, env = 0, nil
        if id then
            for c, envs in pairs(store.variable) do
                if envs[id] then classid, env = c, envs[id] end
            end
        end
        local pid = views.variablePid[name]
        if not env and pid then
            local c, fid, found = findByPid(store, "variable", pid)
            if found then classid, id, env = c, fid, found end
        end
        local envs = bucket(store, "variable", classid)
        if not env then
            id = pid or GSE.NewLocalId()
            env = {}
            envs[id] = env
        end
        env.Name, env.Body = name, body
        if pid then env.PlatformID = pid end
        env.Collections = nonEmpty(views.variableCollections and views.variableCollections[name])
        seen[id] = true
        rekey(envs, id, env, seen)
    end
end

local function reconcileMacros(store, views, index, seen)
    local global = bucket(store, "macro", 0)

    -- Account macros.
    for name, node in pairs(views.macro) do
        if isMacroNode(node) then
            local id = index.macroAccount[name]
            local env
            if id then
                local _
                _, env = locateMacro(store, id)
            end
            local pid = views.macroPid[name]
            if not env and pid then
                local _, fid, found = findByPid(store, "macro", pid)
                if found and found.Scope ~= "character" then id, env = fid, found end
            end
            if not env then
                id = pid or GSE.NewLocalId()
                env = { Scope = "account" }
                global[id] = env
            end
            env.Name, env.Body, env.Scope = name, node, "account"
            env.Collections = nonEmpty(views.macroCollections and views.macroCollections[name])
            if pid then env.PlatformID = pid end
            seen[id] = true
        end
    end

    -- Character macros, one bucket per character in the views.
    local me = GSE.CharacterKey and GSE.CharacterKey()
    local held = {}                         -- [charKey][id] = true
    for charKey, b in pairs(views.macro) do
        if type(b) == "table" and not isMacroNode(b) then
            local rec = charRecord(store, charKey)
            if charKey == me then
                rec.ClassID = currentClassId() or rec.ClassID
                rec.Label = (GSE.CharacterLabel and GSE.CharacterLabel()) or rec.Label
            end
            held[charKey] = held[charKey] or {}
            for name, node in pairs(b) do
                if isMacroNode(node) then
                    local body = copyShallow(node)
                    local slot = body.value
                    body.value = nil
                    local id = index.macroChar[charKey] and index.macroChar[charKey][name]
                    local env
                    if id then
                        local _
                        _, env = locateMacro(store, id)
                    end
                    if env and not macroContentEqual(env.Body, body) and #holders(store, id) > 1 then
                        -- This character's copy diverged from a shared macro:
                        -- detach it rather than change it for everyone.
                        rec.Macros[id] = nil
                        env, id = nil, nil
                    end
                    if not env then
                        -- An identical macro some character already holds.
                        for _, envs in pairs(store.macro) do
                            for oid, other in pairs(envs) do
                                if other.Scope == "character" and other.Name == name
                                    and macroContentEqual(other.Body, body) then
                                    id, env = oid, other
                                end
                            end
                        end
                    end
                    if not env then
                        local pid = views.macroPid[name]
                        id = (pid and not findByPid(store, "macro", pid)) and pid or GSE.NewLocalId()
                        env = { Name = name, Scope = "character", PlatformID = pid }
                        -- New: its character's class when known, otherwise global.
                        bucket(store, "macro", rec.ClassID or 0)[id] = env
                    end
                    if not macroContentEqual(env.Body, body)
                        or (body.LastUpdated or "") > ((env.Body or {}).LastUpdated or "") then
                        env.Body = body
                    end
                    env.Name = name
                    env.Collections = nonEmpty(views.macroCollections and views.macroCollections[name])
                    rec.Macros[id] = slot or 0
                    held[charKey][id] = true
                end
            end
        end
    end

    -- References the views no longer hold go, and so do records left with none.
    local empty = {}
    for charKey, rec in pairs(characters(store)) do
        local gone = {}
        for id in pairs(rec.Macros or {}) do
            if not (held[charKey] and held[charKey][id]) and not index.shadowed[id] then
                gone[#gone + 1] = id
            end
        end
        for _, id in ipairs(gone) do rec.Macros[id] = nil end
        if next(rec.Macros) == nil then empty[#empty + 1] = charKey end
    end
    for _, k in ipairs(empty) do store.character[k] = nil end

    -- A PlatformID can arrive by sidecar alone -- the GSE.Tools round trip.
    -- The sidecar is keyed by NAME, and one name can now be several character
    -- macros (identical copies share one; differing copies do not), so it is
    -- applied only where the name picks out exactly one macro and no other
    -- macro already carries that id. Anything else would give two macros one
    -- identity, and the move below would overwrite one with the other.
    for name, pid in pairs(views.macroPid) do
        local match, count = nil, 0
        for _, envs in pairs(store.macro) do
            for _, env in pairs(envs) do
                if env.Scope == "character" and env.Name == name then match, count = env, count + 1 end
            end
        end
        if count == 1 and match.PlatformID ~= pid then
            local _, _, owner = findByPid(store, "macro", pid)
            if not owner then match.PlatformID = pid end
        end
    end

    -- A character macro lives while some character holds it; then it is filed
    -- by its holders (towards global only) and moved to its PlatformID.
    local ids = {}
    for _, envs in pairs(store.macro) do
        for id, env in pairs(envs) do
            if env.Scope == "character" then ids[#ids + 1] = id end
        end
    end
    for _, id in ipairs(ids) do
        if referenced(store, id) then
            seen[id] = true
            settleMacroClass(store, id)
        end
    end
    local pending = {}
    for classid, envs in pairs(store.macro) do
        for id, env in pairs(envs) do
            if env.PlatformID and isLocalId(id) and env.PlatformID ~= id then
                pending[#pending + 1] = { classid, id }
            end
        end
    end
    for _, p in ipairs(pending) do
        local envs = store.macro[p[1]]
        local env = envs[p[2]]
        -- Never move onto a key another macro already holds; that one keeps
        -- its key and this one stays where it is.
        if envs[env.PlatformID] == nil then
            envs[p[2]] = nil
            envs[env.PlatformID] = env
            seen[env.PlatformID] = true
            rekeyMacroRefs(store, p[2], env.PlatformID)
        end
    end
end

--- Fold the working views back into GSEStore. Called at PLAYER_LOGOUT, before
-- WoW writes SavedVariables. Safe to call at any time; does nothing before the
-- views exist.
function GSE.ReconcileStore()
    if not VIEWS then return end
    local store = GSEStore
    -- Sequences are not here: they are edited in the store directly.
    local seenVar, seenMac = {}, {}
    reconcileVariables(store, VIEWS, INDEX, seenVar)
    reconcileMacros(store, VIEWS, INDEX, seenMac)
    dropUnseen(store, "variable", seenVar, INDEX.shadowed)
    dropUnseen(store, "macro", seenMac, INDEX.shadowed)
    -- The legacy globals were cleared at load; make sure nothing recreated one
    -- during the session, or it would be written back beside the store.
    for _, global in pairs(LEGACY) do _G[global] = nil end
end

--- Load (and if needed migrate) the store and build this session's views.
function GSE.LoadStore()
    if type(GSEStore) ~= "table" or GSEStore.v == nil then
        GSEStore = { v = STORE_VERSION, sequence = {}, variable = {}, macro = {} }
    end
    for _, kind in ipairs(KINDS) do
        if type(GSEStore[kind]) ~= "table" then GSEStore[kind] = {} end
    end
    if type(GSEStore.character) ~= "table" then GSEStore.character = {} end
    local legacyPresent = false
    for _, global in pairs(LEGACY) do
        if _G[global] ~= nil then legacyPresent = true end
    end
    if legacyPresent then migrateLegacy(GSEStore) end
    if type(GSEStore.alias) ~= "table" then GSEStore.alias = {} end
    settleSequenceIds(GSEStore)
    fileElementsByScope(GSEStore)
    indexSequenceNames()
    VIEWS, INDEX = buildViews(GSEStore)
end

--- The working view for a kind of content. See the block comment above.
function GSE.Store(kind)
    if not VIEWS then GSE.LoadStore() end
    local t = VIEWS[kind]
    if not t then error("GSE.Store: unknown kind " .. tostring(kind), 2) end
    return t
end

--- Record the GSE.Tools id of a stored element, found by name, without
-- touching its body.
--
-- The body may be sealed (!GSE3!+). The Mod can read a sealed body but must
-- never write one back in the clear, and re-encoding it to change one MetaData
-- field would do exactly that -- which is what the Companion bridge used to do.
-- The id goes into the same sidecar view the GSE.Tools round trip has always
-- used, and ReconcileStore moves the element to it at logout; the body is not
-- read unless nothing else says who the author is, and is never written.
--
-- classid is a hint for sequences: that class is tried first, then every
-- class, global (0) included. Returns true when the element was found.
function GSE.SetStoredPlatformID(kind, name, pid, classid)
    if type(name) ~= "string" or type(pid) ~= "string" or pid == "" then return false end
    if not VIEWS then GSE.LoadStore() end
    if kind == "variable" then
        if VIEWS.variable[name] == nil then return false end
        VIEWS.variablePid[name] = pid
        return true
    elseif kind == "macro" then
        local found = VIEWS.macro[name] ~= nil and isMacroNode(VIEWS.macro[name])
        if not found then
            for _, b in pairs(VIEWS.macro) do
                if type(b) == "table" and not isMacroNode(b) and b[name] ~= nil then found = true; break end
            end
        end
        if not found then return false end
        VIEWS.macroPid[name] = pid
        return true
    end
    -- The hint first, then every class in order. Not "current class first":
    -- the bridge runs this at load, and which character is logged in has no
    -- bearing on which stored sequence the id belongs to.
    local hint = tonumber(classid)
    local id, c
    if hint then id, c = GSE.FindSequenceId(name, hint) end
    for cls = 0, 13 do
        if id then break end
        id, c = GSE.FindSequenceId(name, cls)
    end
    if not id then return false end
    -- An id another sequence already holds is not this one's to take.
    local holder = GSE.SequenceIdByPlatformID(pid)
    if holder ~= nil and holder ~= id then return false end
    -- The envelope carries it from now on; the element moves to it at the
    -- next load (settleSequenceIds), never mid-session.
    GSEStore.sequence[c][id].PlatformID = pid
    local lib = GSE.Library and GSE.Library[c] and GSE.Library[c][id]
    if type(lib) == "table" then
        -- The loaded copy, so the editor shows the id without a /reload.
        -- Memory only: the stored body is not rewritten.
        lib.MetaData = lib.MetaData or {}
        lib.MetaData.PlatformID = pid
    end
    return true
end

-- ── Collection provenance ───────────────────────────────────────────────────
--
-- The collections an element came through, kept on its envelope as
-- Collections = { [key] = name }: key is the collection's PlatformID, or
-- "name:" .. its name for one with no site id (a string another player
-- pasted). Envelope, not body, so it is recorded on sealed content too.
-- A sequence is named by id; a variable or macro by name (see the views'
-- *Collections, written to the envelope at reconcile).

local function collectionsTable(kind, ref, classid, create)
    if not VIEWS then GSE.LoadStore() end
    if kind == "sequence" then
        local env = GSE.SequenceEnvelope(ref, classid)
        if not env then return nil end
        if create and type(env.Collections) ~= "table" then env.Collections = {} end
        return env.Collections
    end
    local map = VIEWS[kind .. "Collections"]
    if not map then return nil end
    if create and type(map[ref]) ~= "table" then map[ref] = {} end
    return map[ref]
end

--- { [key] = name } for the collections an element came through, or nil.
function GSE.ElementCollections(kind, ref, classid)
    local t = collectionsTable(kind, ref, classid, false)
    if type(t) ~= "table" or next(t) == nil then return nil end
    return t
end

--- Record that an element came through a collection. A collection known by
--- name alone is replaced by its site id when that arrives. False when the
--- element is not stored (yet).
function GSE.AddElementCollection(kind, ref, platformID, name, classid)
    if ref == nil or (GSE.isEmpty(platformID) and GSE.isEmpty(name)) then return false end
    if kind ~= "sequence" then
        local view = VIEWS and VIEWS[kind]
        local held = view and view[ref] ~= nil
        if not held and kind == "macro" and view then
            for _, b in pairs(view) do
                if type(b) == "table" and not isMacroNode(b) and b[ref] ~= nil then held = true; break end
            end
        end
        if not held then return false end
    end
    local t = collectionsTable(kind, ref, classid, true)
    if not t then return false end
    if not GSE.isEmpty(platformID) then
        if name then t["name:" .. name] = nil end
        t[platformID] = name or t[platformID] or platformID
    else
        t["name:" .. name] = name
    end
    return true
end

--- Forget a collection on an element (key as in ElementCollections).
function GSE.RemoveElementCollection(kind, ref, key, classid)
    local t = collectionsTable(kind, ref, classid, false)
    if type(t) ~= "table" then return false end
    t[key] = nil
    if next(t) == nil then
        if kind == "sequence" then
            local env = GSE.SequenceEnvelope(ref, classid)
            if env then env.Collections = nil end
        else
            VIEWS[kind .. "Collections"][ref] = nil
        end
    end
    return true
end

-- An import names the elements a collection brings, but most are stored later
-- -- variables and macros out of combat, a clashing sequence after the import
-- dialog -- so it leaves an expectation, and the store functions settle it
-- when the element is written. One the user declined lapses unused.
local PENDING_TTL = 1800
local pendingCollections = { sequence = {}, variable = {}, macro = {} }

local function now()
    if GetServerTime then return GetServerTime() end
    return os and os.time and os.time() or 0
end

--- Expect `name` of `kind` to be stored soon, as having come through a
--- collection (platformID may be nil: a pasted collection has only a name).
function GSE.ExpectCollection(kind, name, platformID, collectionName)
    if not pendingCollections[kind] or type(name) ~= "string" then return end
    if GSE.isEmpty(platformID) and GSE.isEmpty(collectionName) then return end
    local list = pendingCollections[kind][name] or {}
    list[#list + 1] = { pid = platformID, name = collectionName, at = now() }
    pendingCollections[kind][name] = list
end

-- Record what was expected of an element just stored.
local function settleCollections(kind, name, ref, classid)
    local list = pendingCollections[kind] and pendingCollections[kind][name]
    if not list then return end
    pendingCollections[kind][name] = nil
    local t = now()
    for _, e in ipairs(list) do
        if t - (e.at or 0) <= PENDING_TTL then
            GSE.AddElementCollection(kind, ref, e.pid, e.name, classid)
        end
    end
end
GSE.SettleCollections = settleCollections

--- Every collection anything came through: { [key] = { name, sequence =
--- { [id] = classid }, variable = { [name] = true }, macro = { [name] = true } } }.
function GSE.KnownCollections()
    if not VIEWS then GSE.LoadStore() end
    local out = {}
    local function entry(key, name)
        out[key] = out[key] or { name = name, sequence = {}, variable = {}, macro = {} }
        if name then out[key].name = name end
        return out[key]
    end
    for classid = 0, 13 do
        for id, env in pairs(GSE.SequenceEnvelopes(classid)) do
            for key, name in pairs(type(env.Collections) == "table" and env.Collections or {}) do
                entry(key, name).sequence[id] = classid
            end
        end
    end
    for _, kind in ipairs({ "variable", "macro" }) do
        for ref, cols in pairs(VIEWS[kind .. "Collections"] or {}) do
            for key, name in pairs(cols) do entry(key, name)[kind][ref] = true end
        end
    end
    return out
end

--- Take a collection off everything it brought. With deleteElements, also
--- delete what came through it alone -- anything another collection brought
--- too only loses this one. A deleted macro leaves the player's WoW macros as
--- well, out of combat. Returns deleted, released counts.
function GSE.RemoveCollection(key, deleteElements)
    local info = GSE.KnownCollections()[key]
    if not info then return 0, 0 end
    local deleted, released = 0, 0
    local function onlyThis(kind, ref, classid)
        local cols = GSE.ElementCollections(kind, ref, classid)
        if not cols then return true end
        for k in pairs(cols) do if k ~= key then return false end end
        return true
    end
    for id, classid in pairs(info.sequence) do
        if deleteElements and onlyThis("sequence", id, classid) then
            GSE.DeleteSequence(classid, id)
            deleted = deleted + 1
        else
            GSE.RemoveElementCollection("sequence", id, key, classid)
            released = released + 1
        end
    end
    for name in pairs(info.variable) do
        if deleteElements and onlyThis("variable", name) then
            GSE.DeleteVariable(name)
            VIEWS.variableCollections[name] = nil
            deleted = deleted + 1
        else
            GSE.RemoveElementCollection("variable", name, key)
            released = released + 1
        end
    end
    for name in pairs(info.macro) do
        if deleteElements and onlyThis("macro", name) then
            GSE.DeleteMacro(name)
            VIEWS.macroCollections[name] = nil
            if DeleteMacro and not (InCombatLockdown and InCombatLockdown()) then
                local slot = GetMacroIndexByName and GetMacroIndexByName(name)
                if slot and slot > 0 then DeleteMacro(slot) end
            end
            deleted = deleted + 1
        else
            GSE.RemoveElementCollection("macro", name, key)
            released = released + 1
        end
    end
    return deleted, released
end

--- One class's table within a kind's view; created only when asked to.
function GSE.StoreClass(kind, classid, create)
    local root = GSE.Store(kind)
    local t = root[classid]
    if t == nil and create then
        t = {}
        root[classid] = t
    end
    return t
end

-- How many steps ride in one chunk of the secure Execute payload. The step
-- list is split because a single secure string is length-limited; the secure
-- snippet calls each chunk an "iteration" and wraps from the last step of the
-- last iteration back to the first step of the first.
--
-- GSE.SequencesExec keeps the SAME steps as ONE flat list, so anything that
-- wants the flat index from a (iteration, step) pair has to use this number.
-- Both sides are derived from it here so they cannot drift apart.
local SECURE_STEPS_PER_ITERATION = 253

local gseEvalEnv = setmetatable({GSE = GSE}, {__index = _G})
local function gseLoadstring(code, chunkname)
    local chunk, err = loadstring(code, chunkname)
    if chunk then setfenv(chunk, gseEvalEnv) end
    return chunk, err
end

local function safeGetSpellInfo(spellIdentifier)
    if spellIdentifier == nil or spellIdentifier == "" then return nil end
    local info = GSE.GetSpellInfo(spellIdentifier)
    if info then return info end
    if type(spellIdentifier) == "string" and not tonumber(spellIdentifier) and type(GSESpellCache) == "table" then
        local locale = GetLocale and GetLocale() or "enUS"
        local cachedID = GSESpellCache[locale] and GSESpellCache[locale][spellIdentifier]
        if cachedID then return GSE.GetSpellInfo(cachedID) end
    end
    return nil
end

-- Track which class libraries have been decompressed into GSE.Library.
GSE.LoadedClasses = GSE.LoadedClasses or {}

GSE.CorruptSequences = GSE.CorruptSequences or {}

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

--- The origin key a sequence is born with.
--
-- FROZEN at first sight and never recomputed. A key derived from Name|Author
-- at read time does not survive a round trip: a rename changes the name, and
-- gse.tools rewrites Author to the uploader's site nickname on every install,
-- so the same sequence yields a different key depending on where you ask.
-- That is why the platform resolves records by their id and treats this as
-- provenance only -- it is recorded so a record's beginnings stay legible,
-- never so anything can be looked up by it.
function GSE.MintOriginKey(name, author)
    return tostring(name or "") .. "|" .. tostring(author or "")
end

--- Stamp MetaData.OriginKey if the sequence has none. Returns true if it wrote.
-- Idempotent: once set, it is left alone for the life of the sequence.
function GSE.StampOriginKey(sequence, name)
    if type(sequence) ~= "table" or type(sequence.MetaData) ~= "table" then return false end
    if not GSE.isEmpty(sequence.MetaData.OriginKey) then return false end
    local seqName = name or sequence.MetaData.Name
    if GSE.isEmpty(seqName) then return false end
    sequence.MetaData.OriginKey = GSE.MintOriginKey(seqName, sequence.MetaData.Author)
    return true
end

--- GSERepackQueue -- what GSE asks the Companion to re-seal on its behalf.
--
-- The addon does not produce packed envelopes (see GSE.IsPackedBlob), so when
-- protected content genuinely needs one written it says so here and the
-- Companion services it: resolve the record on gse.tools, fetch the sealed
-- blob the server produces, write it back. The key never has to exist on this
-- side of the wire.
--
-- Entries carry IDENTITY ONLY -- never a decoded body. Putting the plaintext
-- in the request would recreate the exact exposure #2054 is about, in a second
-- place.
--
-- Keyed so a request is idempotent: logging in ten times with the same damaged
-- library leaves one entry, not ten.
local function repackKey(contentType, classid, name)
    return tostring(contentType) .. ":" .. tostring(classid or "") .. ":" .. tostring(name)
end

function GSE.QueueRepack(contentType, classid, name, obj, reason)
    if GSE.isEmpty(name) then return false end
    if type(GSERepackQueue) ~= "table" then GSERepackQueue = {} end
    local meta = (type(obj) == "table" and obj.MetaData) or {}
    local key = repackKey(contentType, classid, name)
    -- Keep the first sighting's timestamp; this is a standing request, and a
    -- fresh stamp on every login would make it look perpetually new.
    local existing = GSERepackQueue[key]
    GSERepackQueue[key] = {
        t = contentType,
        classid = classid,
        name = name,
        -- Protected content is content gse.tools sent here, so it arrives with
        -- a PlatformID already on it. That is the record the Companion asks the
        -- server to re-seal, and the only identity this request needs.
        platformId = meta.PlatformID,
        reason = reason,
        stamp = (existing and existing.stamp) or GSE.GetTimestamp(),
    }
    return true
end

function GSE.ClearRepackRequest(contentType, classid, name)
    if type(GSERepackQueue) ~= "table" then return end
    GSERepackQueue[repackKey(contentType, classid, name)] = nil
end

--- Called on every load, whatever else happens to the record.
--
-- Protected content sitting in the clear is the damage a shipped build already
-- did (#2054) and it cannot be repaired here, so it is reported. Anything
-- correctly sealed clears its request, which is what makes the queue
-- self-draining: once the Companion writes the sealed blob back, the next login
-- removes the entry rather than leaving it to be serviced forever.
function GSE.AuditProtectedAtRest(contentType, classid, name, blob, obj)
    if not GSE.IsProtectedContent(obj) then
        GSE.ClearRepackRequest(contentType, classid, name)
        return false
    end
    if GSE.IsPackedBlob(blob) then
        GSE.ClearRepackRequest(contentType, classid, name)
        return false
    end
    GSE.QueueRepack(contentType, classid, name, obj, "plaintext-at-rest")
    return true
end

--- Help links may not point at wowlazymacros.com in any form -- any scheme,
--- subdomain, path or case.  Shared by the editor's Help Link box and the
--- load-time migration, so a sequence already carrying one is healed the
--- first time it is loaded, the way StampOriginKey backfills OriginKey.
GSE.HelplinkDefault = "https://discord.gg/gseunited"
GSE.HelplinkBlockedHost = "wowlazymacros.com"
function GSE.HelplinkAllowed(link)
    if GSE.isEmpty(link) then return true end
    return not string.find(string.lower(tostring(link)), GSE.HelplinkBlockedHost, 1, true)
end
--- Replace a disallowed MetaData.Helplink with the default.  Returns true if
--- it wrote.
function GSE.SanitizeHelplink(sequence)
    if type(sequence) ~= "table" or type(sequence.MetaData) ~= "table" then return false end
    if GSE.HelplinkAllowed(sequence.MetaData.Helplink) then return false end
    sequence.MetaData.Helplink = GSE.HelplinkDefault
    return true
end

local function migrateSequenceVersions(sequence, sequenceName)
    if type(sequence) ~= "table" then return false end
    if sequence["Macros"] ~= nil and sequence.Versions == nil then
        return false, "macros-deprecated"
    end
    local changed = false
    -- Backfills existing sequences on first load; new ones get it here too,
    -- so every creation path is covered without each one remembering to.
    if GSE.StampOriginKey(sequence, sequenceName) then changed = true end
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
    if GSE.SanitizeHelplink(sequence) then changed = true end
    if changed and type(sequence.MetaData) == "table" then
        sequence.MetaData.Checksum = nil
    end
    return changed
end

-- Decode one stored sequence into GSE.Library[classid][id]. Returns the error,
-- if any, having recorded the sequence as corrupt.
local function loadOneSequence(classid, id)
    local env = GSE.SequenceEnvelopes(classid)[id]
    if not env then return end
    local body = env.Body
    local ok, err = pcall(function()
        local _, decoded = GSE.DecodeMessage(body)
        local seq = type(decoded) == "table" and decoded[2] or nil
        -- A locally-edited copy lives in GSEDeltas; the stored blob is only
        -- its base. Prefer the reconstruction or the edit is lost the first
        -- time this class is loaded lazily.
        local forked = GSE.ApplyStoredDeltaFork and GSE.ApplyStoredDeltaFork(seq, body)
        if forked then seq = forked end
        if type(seq) ~= "table" then error("undecodable") end
        -- The envelope's Name is the label. A sealed body renamed here still
        -- says the old name inside, and cannot be rewritten to say otherwise.
        if type(seq.MetaData) == "table" then seq.MetaData.Name = env.Name end
        GSE.Library[classid][id] = seq
        -- The repack queue is read by the Companion, which knows the name.
        GSE.AuditProtectedAtRest("sequence", classid, env.Name, body, seq)
        local changed, reason = migrateSequenceVersions(seq, env.Name)
        -- Embed ids follow a move to a PlatformID here too, not only on the
        -- next edit: the stored body is what the Companion uploads.
        if GSE.NormaliseEmbeds(seq) then changed = true end
        if reason == "macros-deprecated" then
            -- Refuse to load. The on-disk record uses the old 'Macros' field;
            -- the addon no longer auto-renames.
            GSE.Library[classid][id] = nil
            error(string.format(
                L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."],
                env.Name))
        end
        -- Migration results are derived and recomputed on every load, so
        -- declining to persist them costs nothing. Rewriting them over
        -- protected content, on the other hand, is what stripped the packed
        -- envelope in #2054.
        if changed and not GSE.IsProtectedAtRest(body, seq) then
            env.Body = GSE.EncodeMessage({env.Name, seq})
        end
    end)
    if not ok then
        GSE.Print(tostring(err), "Error")
        table.insert(GSE.CorruptSequences, {classid = classid, id = id, name = env.Name})
        return err
    end
end

--- Decompress a single class from GSEStore into GSE.Library (internal).
local function loadOneClass(classid)
    if GSE.LoadedClasses[classid] then return end
    GSE.LoadedClasses[classid] = true
    if GSE.isEmpty(GSE.Library[classid]) then
        GSE.Library[classid] = {}
    end
    for id in pairs(GSE.SequenceEnvelopes(classid)) do
        loadOneSequence(classid, id)
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

--- Decompress a single sequence into GSE.Library on demand. No-op if it is
-- already loaded or is not stored.
function GSE.EnsureSequenceLoaded(classid, id)
    if GSE.isEmpty(classid) or GSE.isEmpty(id) then return end
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
    if not GSE.isEmpty(GSE.Library[classid][id]) then return end
    if not GSE.SequenceEnvelopes(classid)[id] then return end
    local err = loadOneSequence(classid, id)
    if not err and not GSE.isEmpty(GSE.Library[classid][id]) then
        GSE.EnsureSequenceVariablesLoaded(GSE.Library[classid][id])
    end
    -- Resolve action icons for this class so single-sequence loads also
    -- benefit from the load-time icon hydration. Cheap and idempotent.
    if GSE.HydrateClassActionIcons then
        GSE.HydrateClassActionIcons(classid)
    end
end

--- A loaded sequence by id, loading it if it is stored but not yet decoded.
-- Searches every class when classid is nil. Returns the sequence and its class.
function GSE.GetSequence(id, classid)
    local env, c = GSE.SequenceEnvelope(id, classid)
    if not env then return nil end
    id = GSE.ResolveSequenceId(id)
    GSE.EnsureSequenceLoaded(c, id)
    return GSE.Library[c] and GSE.Library[c][id], c
end

-- ponytail: drop a seq from the corrupt list so the editor tree stops flagging
-- it the moment it's deleted. Both delete paths call this.
function GSE.ForgetCorruptSequence(classid, id)
    if type(GSE.CorruptSequences) ~= "table" then return end
    for i = #GSE.CorruptSequences, 1, -1 do
        local c = GSE.CorruptSequences[i]
        if c and tonumber(c.classid) == tonumber(classid) and c.id == id then
            table.remove(GSE.CorruptSequences, i)
        end
    end
end

--- Remove a corrupt sequence from both compressed storage and the live library.
function GSE.DeleteCorruptSequence(classid, id)
    local name = GSE.SequenceName(id, classid) or tostring(id)
    -- The fork goes with the record. The body that failed to decode cannot say
    -- which PlatformID it had; the envelope beside it can.
    if GSE.ForgetDeltaFork then
        local loaded = type(GSE.Library) == "table" and type(GSE.Library[classid]) == "table"
            and GSE.Library[classid][id]
        if not GSE.ForgetDeltaFork(loaded) then GSE.ForgetDeltaFork(GSE.SequenceEnvelope(id, classid)) end
    end
    GSE.RemoveSequence(classid, id)
    if type(GSE.Library) == "table" and type(GSE.Library[classid]) == "table" then
        GSE.Library[classid][id] = nil
    end
    GSE.ForgetCorruptSequence(classid, id)
    GSE.Print(string.format(L["Corrupt sequence '%s' (class %d) deleted."], name, classid))
end

--- Delete a variable from local storage by name. Single canonical
-- helper for both UI and OOC-queue callers ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â each was previously
-- inlining `GSEVariables[k] = nil` etc., which made it easy to forget
-- the sidecar tables (GSE.V cache, Companion PlatformID sidecar) and
-- left orphans behind that the next sync had to clean up.
function GSE.DeleteVariable(name)
    if not name or name == "" then return end
    if GSE.Store("variable") then GSE.Store("variable")[name] = nil end
    if GSE.V then GSE.V[name] = nil end
    -- Companion sidecar: name ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ server-id map. Clearing it stops the
    -- next sync from re-uploading the deleted variable on the basis of
    -- a stale stamp.
    -- A variable can carry a fork for the same reason a sequence can.
    if GSE.ForgetDeltaFork and GSE.Store("variablePid") then
        GSE.ForgetDeltaFork(GSE.Store("variablePid")[name])
    end
    if GSE.Store("variablePid") then GSE.Store("variablePid")[name] = nil end
end

--- Delete a macro from local storage by name. Handles both account-
-- level (GSEMacros[name]) and character-level (GSEMacros["char-realm"]
-- [name]) storage; clears whichever holds the entry.
function GSE.DeleteMacro(name)
    if not name or name == "" then return end
    if GSE.Store("macro") then
        GSE.Store("macro")[name] = nil
        for _, t in pairs(GSE.Store("macro")) do
            if type(t) == "table" and t[name] ~= nil then
                t[name] = nil
            end
        end
    end
    if GSE.Store("macroPid") then GSE.Store("macroPid")[name] = nil end
end

--- Delete a sequence from the library, by id.
function GSE.DeleteSequence(classid, id)
    classid = tonumber(classid)
    -- Read the id before the record goes, or there is nothing left to key by.
    if GSE.ForgetDeltaFork then
        if not GSE.ForgetDeltaFork(GSE.Library[classid] and GSE.Library[classid][id]) then
            GSE.ForgetDeltaFork(GSE.SequenceEnvelope(id, classid))
        end
    end
    if GSE.Library[classid] then GSE.Library[classid][id] = nil end
    GSE.RemoveSequence(classid, id)
    GSE.ForgetCorruptSequence(classid, id)

    -- Remove any actionbar overrides and keybinds that run this sequence (they
    -- hold its id; see GSE.UpdateCharacterSequenceRefs).
    local overrideChanged = false
    if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
            for _, buttons in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
                local toDelete = {}
                for buttonName, bind in pairs(buttons) do
                    if bind.Sequence == id then
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
                        if bind.Sequence == id then
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
    -- And from every shared profile, whichever class or spec it is for.
    local profileBindsChanged = false
    for _, byClass in pairs(type(GSEStore.profile) == "table" and GSEStore.profile or {}) do
        for _, p in pairs(type(byClass) == "table" and byClass or {}) do
            for key, seq in pairs(type(p.KeyBindings) == "table" and p.KeyBindings or {}) do
                if seq == id then p.KeyBindings[key] = nil; profileBindsChanged = true end
            end
            for buttonName, bind in pairs(type(p.ActionBarBinds) == "table" and p.ActionBarBinds or {}) do
                if type(bind) == "table" and bind.Sequence == id then
                    p.ActionBarBinds[buttonName] = nil
                    overrideChanged = true
                end
            end
        end
    end
    if overrideChanged then
        GSE.ReloadOverrides()
    end
    if profileBindsChanged and GSE.ReloadKeyBindings and not InCombatLockdown() then
        GSE.ReloadKeyBindings()
    end

    -- Remove any keybindings that reference this sequence
    if not InCombatLockdown() and not GSE.isEmpty(GSE_C["KeyBindings"]) then
        for _, specData in pairs(GSE_C["KeyBindings"]) do
            local toDelete = {}
            for key, seqName in pairs(specData) do
                if key ~= "LoadOuts" and seqName == id then
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
                        if seqName == id then
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
-- FinishReload/managemacros: skipped if already present.
-- Which sequence a queued operation is about: its id, or -- for an import
-- that has none until it is filed -- its name.
local function seqKey(v)
    if v.id ~= nil then return v.id end
    if v.sequencename ~= nil then return "name:" .. v.sequencename end
end

local function sameSequence(a, b)
    local k = seqKey(a)
    return k ~= nil and k == seqKey(b)
end

function GSE.EnqueueOOC(vals)
    local action = vals.action
    if GSE.StartOOCTimer then
        GSE.StartOOCTimer()
    end

    if action == "MergeSequence" then
        -- Remove all sequence operations for the same sequence; we supersede them.
        local k = 1
        while k <= #GSE.OOCQueue do
            local v = GSE.OOCQueue[k]
            if (v.action == "MergeSequence" or v.action == "Save" or v.action == "Replace" or v.action == "UpdateSequence")
                    and sameSequence(v, vals) then
                table.remove(GSE.OOCQueue, k)
            else
                k = k + 1
            end
        end

    elseif action == "Save" or action == "Replace" then
        -- Skip if a MergeSequence for the same sequence is already queued.
        for _, v in ipairs(GSE.OOCQueue) do
            if v.action == "MergeSequence" and sameSequence(v, vals) then
                return
            end
        end
        -- Replace existing Save/Replace and strip any UpdateSequence for the same name.
        local replaced = false
        local k = 1
        while k <= #GSE.OOCQueue do
            local v = GSE.OOCQueue[k]
            if v.action == "UpdateSequence" and sameSequence(v, vals) then
                table.remove(GSE.OOCQueue, k)
            elseif (v.action == "Save" or v.action == "Replace") and sameSequence(v, vals) then
                GSE.OOCQueue[k] = vals
                replaced = true
                k = k + 1
            else
                k = k + 1
            end
        end
        if replaced then return end

    elseif action == "UpdateSequence" then
        -- Skip if any higher-priority sequence op for the same sequence is already queued.
        for _, v in ipairs(GSE.OOCQueue) do
            if (v.action == "MergeSequence" or v.action == "Save" or v.action == "Replace" or v.action == "UpdateSequence")
                    and sameSequence(v, vals) then
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

    end

    table.insert(GSE.OOCQueue, vals)
end

--- Add a sequence to the library. An import has only a name; which stored
-- sequence it is -- or whether it is new -- is decided when it is filed and its
-- class is known (OOCAddSequenceToCollection). A caller that already knows the
-- id passes it.
function GSE.AddSequenceToCollection(sequenceName, sequence, classid, id)
    -- Save-cancels-delete (see UpdateVariable for rationale). The bridge's
    -- pending deletes are named.
    if GSE.CompanionCancelPendingDelete and type(sequence) == "table" and type(sequence.MetaData) == "table" then
        GSE.CompanionCancelPendingDelete("sequence", sequence.MetaData.Name)
    end
    local vals = {}
    vals.action = "Save"
    vals.sequencename = sequenceName
    vals.id = id
    vals.sequence = sequence
    vals.classid = classid
    GSE.EnqueueOOC(vals)
end

--- Merge, replace or rename an incoming sequence against stored sequence id.
-- For RENAME, newName is the name the copy is stored under (with a new id).
function GSE.PerformMergeAction(action, classid, id, newSequence, newName)
    local vals = {}
    vals.action = "MergeSequence"
    vals.id = id
    vals.newname = newName
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
    for _, macname in ipairs(deps.Macros) do
        local slot = GetMacroIndexByName(macname)
        if slot and slot > 0 then
            local mname, micon, mbody = GetMacroInfo(slot)
            if mname then
                -- Always overwrite so the account-level copy stays current.
                GSE.SnapshotMacro(GSE.Store("macro"), macname, mname, micon, mbody, slot)
            end
        end
    end
end

--- Replace a current version of a Macro
--- Store a sequence into the Library and the saved variables.
--
-- The Library entry is a CLONE, never the caller's own table. The editor keeps
-- its working copy in editframe.Sequence and hands that same table here on
-- Save; storing it directly made the two the same object, and from the first
-- Save of a session onwards every per-version operation ran twice — once as
-- the editor's own edit, then again through the "mirror into the Library so
-- the tree updates before Save" block in each handler, which was by then
-- writing into the same array. Delete removed two versions, New Version
-- inserted two, drag reorder moved twice. The extra version also left the
-- tree pointing at an index the reloaded sequence did not have, which is the
-- nil-index error on the way back into the editor. Cloning restores the
-- invariant those mirror blocks were written against: the Library holds a
-- separate copy that only this function replaces.
function GSE.ReplaceSequence(classid, id, sequence)
    classid = tonumber(classid)
    if type(sequence.MetaData) ~= "table" then sequence.MetaData = {} end
    local prior, fromClass = GSE.SequenceEnvelope(id)
    -- The label: what the sequence says it is called, else what it was.
    local sequenceName = sequence.MetaData.Name or (prior and prior.Name)
    sequence.MetaData.Name = sequenceName
    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(sequence)
    end
    -- Stamp on save, not only on the next load: a sequence created or renamed
    -- within one session must already carry the key it was born with, rather
    -- than acquiring it whenever it is next read back. Idempotent -- an
    -- existing stamp is left alone.
    GSE.StampOriginKey(sequence, sequenceName)
    GSE.SanitizeHelplink(sequence)
    GSE.NormaliseEmbeds(sequence)
    GSE.ComputeSequenceDependencies(sequence)
    GSE.SnapshotDependentMacros(sequence)
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
    -- Filed in another class before: it moves, keeping its id.
    if fromClass ~= nil and fromClass ~= classid and GSE.Library[fromClass] then
        GSE.Library[fromClass][id] = nil
    end
    local storedBody = prior and prior.Body
    -- Asked ONCE, before the fork is consulted. A fork only exists because the
    -- record was protected when the first edit landed, and it used to be read
    -- first -- so a record that has since come back in the clear still had
    -- every later edit swallowed by the fork it had outgrown. The owner then
    -- sees local-changes controls on their own unsealed sequence, and no
    -- amount of editing clears them, because each edit re-enters the fork.
    local protectedAtRest = GSE.IsProtectedAtRest(storedBody, sequence)
    if protectedAtRest then
        -- The sealed body stays exactly as it is; only where it is filed and
        -- what it is called can change, and those live in the envelope.
        if storedBody ~= nil then GSE.PutSequenceBody(classid, id, sequenceName, storedBody) end
        GSE.Library[classid][id] = GSE.CloneSequence(sequence)
        if GSE.UpdateDeltaFork and GSE.UpdateDeltaFork(sequence) then
            GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
            return
        end
        -- Protected content is never rewritten in the clear, so an edit to it
        -- is stored as a delta over the sealed blob instead: the packed base
        -- moves into the fork verbatim and only the divergence is written
        -- beside it.
        if not GSE.SeedDeltaFork(storedBody, sequence, "sequence") then
            -- Nothing to key a fork by, so the edit cannot be persisted here.
            -- Say so rather than writing it out in the clear.
            GSE.QueueRepack("sequence", classid, sequenceName, sequence, "edit-needs-repack")
        end
        GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
        return
    end
    -- Nothing left to protect, so the fork has nothing left to describe: this
    -- write puts the edit -- which IS the reconstructed fork, the editor loads
    -- through GSE.ApplyStoredDeltaFork -- into the record in the clear. The
    -- same end-of-round-trip GSE.StoreEncodedSequence already handles when the
    -- flattened copy arrives from the server; this is the local half of it.
    -- Order matters: forget only once the plain write is about to happen.
    if GSE.ForgetDeltaFork then GSE.ForgetDeltaFork(sequence) end
    -- Checksum is stamped on export only, not on save, so the stored checksum
    -- always reflects the last-exported state rather than the current edit state.
    GSE.PutSequenceBody(classid, id, sequenceName, GSE.EncodeMessage({sequenceName, sequence}))
    GSE.Library[classid][id] = GSE.CloneSequence(sequence)
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
end

function GSE.StoreEncodedSequence(name, encoded)
    if type(name) ~= "string" or type(encoded) ~= "string" then return false end
    local ok, decoded = GSE.DecodeMessage(encoded)
    if not ok or type(decoded) ~= "table" or type(decoded[2]) ~= "table" then
        GSE.Print(L["Unable to interpret sequence."] .. " " .. name, GNOME)
        return false
    end
    local seq = decoded[2]
    local classid = GSE.GetClassIDforSpec(seq.MetaData and seq.MetaData.SpecID) or 0
    local id = GSE.SequenceIdForIncoming(classid, name, seq)
    -- Arriving in the CLEAR for something we hold a fork of means the server
    -- flattened it: this is the owner's own work, their edit was applied to
    -- their record, and what just came back already contains it. The fork
    -- described a divergence from a sealed base that no longer exists, so
    -- keeping it would replay the edit on top of itself.
    --
    -- Only ever on plaintext. A sealed blob is still somebody else's content
    -- and its fork is still the local divergence from it.
    if GSE.ForgetDeltaFork and not (GSE.IsPackedBlob and GSE.IsPackedBlob(encoded)) then
        local meta = seq.MetaData or {}
        local pid = meta.PlatformID or seq.PlatformID
        if type(pid) == "string" and type(GSEDeltas) == "table" and GSEDeltas[pid] then
            GSE.ForgetDeltaFork(pid)
        end
    end
    local _, fromClass = GSE.SequenceEnvelope(id)
    if fromClass ~= nil and type(GSE.Library[fromClass]) == "table" then GSE.Library[fromClass][id] = nil end
    GSE.PutSequenceBody(classid, id, name, encoded)
    -- Drop any stale decoded copy so the lazy loader re-decodes from the
    -- stored string (its canonical migrate + variable-load path).
    if type(GSE.Library[classid]) == "table" then GSE.Library[classid][id] = nil end
    GSE.EnsureSequenceLoaded(classid, id)
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
    return true, id
end

function GSE.StoreEncodedVariable(name, encoded)
    if type(name) ~= "string" or type(encoded) ~= "string" then return false end
    local ok, decoded = GSE.DecodeMessage(encoded)
    if not ok or type(decoded) ~= "table" then
        GSE.Print(L["Unable to interpret sequence."] .. " " .. name, GNOME)
        return false
    end
    GSE.Store("variable")[name] = encoded
    if GSE.V then GSE.V[name] = nil end
    settleCollections("variable", name, name)
    GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, name)
    return true
end

function GSE.StoreEncodedMacro(name, encoded)
    if type(name) ~= "string" or type(encoded) ~= "string" then return false end
    local ok, decoded = GSE.DecodeMessage(encoded)
    if not ok or type(decoded) ~= "table" then
        GSE.Print(L["Unable to interpret sequence."] .. " " .. name, GNOME)
        return false
    end
    GSE.Store("macro")[name] = { GSEProtected = encoded }
    settleCollections("macro", name, name)
    if GSE.ManageMacros then GSE.ManageMacros() end
    GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, name)
    return true
end

--- Rename a sequence in-place, preserving its PlatformID and all MetaData.
-- Moves the data from the old key to the new key in both Library and
-- GSESequences, updates MetaData.Name, and removes the old entry.
-- Does NOT wipe PlatformID — this is a rename, not a new-sequence creation.
function GSE.RenameSequence(classid, id, newName, sequence)
    classid = tonumber(classid)
    if not classid or GSE.isEmpty(id) or GSE.isEmpty(newName) then return false end
    -- Wherever it is filed: a rename can come with a class move.
    local env, fromClass = GSE.SequenceEnvelope(id)
    if not env then
        -- Loaded but never stored: a protected edit that could not be written.
        -- There is no sealed body to carry under the new name, and it must not
        -- be written in the clear, so ask for a repack instead.
        sequence = sequence or (GSE.Library[classid] and GSE.Library[classid][id])
        if type(sequence) == "table" and GSE.IsProtectedAtRest(nil, sequence) then
            if type(sequence.MetaData) ~= "table" then sequence.MetaData = {} end
            sequence.MetaData.Name = newName
            if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
            GSE.Library[classid][id] = sequence
            GSE.QueueRepack("sequence", classid, newName, sequence, "rename-needs-repack")
            return true
        end
        return false
    end
    local oldName = env.Name
    sequence = sequence or (GSE.Library[fromClass] and GSE.Library[fromClass][id])
    if type(sequence) ~= "table" then return false end
    if type(sequence.MetaData) ~= "table" then sequence.MetaData = {} end

    -- Update the human-readable name stored inside the sequence object.
    sequence.MetaData.Name = newName

    if GSE.SanitizeSequenceEditorMarkup then
        GSE.SanitizeSequenceEditorMarkup(sequence)
    end
    GSE.ComputeSequenceDependencies(sequence)
    GSE.SnapshotDependentMacros(sequence)

    -- A rename changes the label, not the identity: the id stays, so nothing
    -- that holds it has to follow. Protected content keeps its sealed body
    -- byte for byte -- only the envelope's Name changes. Anything else is
    -- re-encoded so the name inside the body agrees.
    if GSE.IsProtectedAtRest(env.Body, sequence) then
        GSE.PutSequenceBody(classid, id, newName, env.Body)
    else
        GSE.PutSequenceBody(classid, id, newName, GSE.EncodeMessage({newName, sequence}))
    end
    if fromClass ~= classid and GSE.Library[fromClass] then GSE.Library[fromClass][id] = nil end
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end
    GSE.Library[classid][id] = sequence

    -- Keybinds and action-bar overrides hold the id and click the sequence's
    -- button, whose name is not its label: a rename touches neither.
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, id)
    return true
end

--- Duplicate a sequence under a new name. Unlike a rename, a duplicate is a
-- brand-new sequence: it is given a fresh GSE.Tools identity (PlatformID is
-- cleared) so the copy and the original never resolve to the same server
-- record. If newName is supplied it is used (normalised + collision-checked);
-- otherwise a unique "<source>Copy" name is generated. The sequence is stored
-- synchronously (so open editor trees can show it immediately) and its secure
-- button is built on the next OOC tick. Returns the new id and name, or nil
-- on failure.
function GSE.DuplicateSequence(classid, sourceId, newName)
    classid = tonumber(classid)
    if GSE.isEmpty(classid) then classid = GSE.GetCurrentClassID() end
    if GSE.isEmpty(sourceId) then return nil end

    local src = GSE.GetSequence(sourceId)
    if GSE.isEmpty(src) then return nil end
    local sourceName = GSE.SequenceName(sourceId) or "Sequence"
    if GSE.isEmpty(GSE.Library[classid]) then GSE.Library[classid] = {} end

    local clone = GSE.CloneSequence(src)
    if GSE.isEmpty(clone.MetaData) then clone.MetaData = {} end

    if not GSE.isEmpty(newName) then
        -- Caller-supplied name (from the rename-style prompt). Normalise like
        -- the import path (spaces/commas -> underscores); bail if it collides.
        newName = newName:gsub(" ", "_"):gsub(",", "_")
        if GSE.FindSequenceId(newName, classid) then
            return nil
        end
    else
        -- Auto-generate: "<source>Copy", then "Copy2", "Copy3", ...
        local base = sourceName .. "Copy"
        newName = base
        local suffix = 2
        while GSE.FindSequenceId(newName, classid) do
            newName = base .. suffix
            suffix = suffix + 1
        end
    end

    clone.MetaData.Name = newName
    -- A duplicate must mint its own GSE.Tools record, so clear the inherited
    -- PlatformID; otherwise the copy and the original would share one server
    -- id and bounce against each other on the next Companion sync.
    clone.MetaData.PlatformID = nil
    -- Same reasoning: a duplicate begins its own history, so it mints its own
    -- origin key rather than inheriting the one it was copied from.
    clone.MetaData.OriginKey = GSE.MintOriginKey(newName, clone.MetaData.Author)
    clone.LastUpdated = GSE.GetTimestamp()

    -- Store synchronously (table writes only -- safe in or out of combat).
    local id = GSE.NewLocalId()
    GSE.ReplaceSequence(classid, id, clone)

    -- Build the secure button out of combat via the OOC queue.
    local versionIndex = GSE.GetActiveSequenceVersion(id)
        or (clone.MetaData and clone.MetaData.Default) or 1
    local version = clone.Versions and clone.Versions[versionIndex]
    if version then
        GSE.UpdateSequence(id, version)
    end
    return id, newName
end

--- Load the GSEStorage into a new table.
-- Sequences are loaded first so their dependency data is available when
-- LoadVariables() decides which variables to compile.
function GSE.LoadStorage(destination)
    if GSE.isEmpty(destination) then
        destination = {}
    end
    -- Pre-initialise all class slots so GSE.Library[k] is never nil.
    for k = 0, 13 do
        if GSE.isEmpty(destination[k]) then
            destination[k] = {}
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
-- Put a variable's version for the current context into GSE.V: compile its
-- funct, note a boolean result, and (re)register the events it listens to. The
-- variable is in the current shape (GSE.UpgradeVariable). Used by the load, a
-- save, and a change of context -- one place, so the three agree.
local function compileVariable(name, variable)
    local active = GSE.ActiveElementVersion(variable) or {}
    local funct = active.funct
    if type(funct) ~= "string" or funct == "" then
        GSE.V[name] = nil
        GSE.UnregisterVariableEvents(name)
        return
    end
    local chunk, err = gseLoadstring("return " .. funct)
    if err then
        --@debug@
        if GSE.PrintDebugMessage then GSE.PrintDebugMessage(tostring(err), "Storage") end
        --@end-debug@
    end
    if type(chunk) == "function" then
        GSE.V[name] = chunk()
    end
    if type(GSE.V[name]) == "function" and type(GSE.V[name]()) == "boolean" then
        GSE.BooleanVariables["GSE.V['" .. name .. "']()"] = "GSE.V['" .. name .. "']()"
    end
    if active.eventEnabled and not GSE.isEmpty(active.eventNames) then
        GSE.RegisterVariableEvents(name, active.eventNames)
    else
        GSE.UnregisterVariableEvents(name)
    end
end

local function loadOneVariable(k, v)
    local status, err =
        pcall(
        function()
            local localsuccess, uncompressedVersion = GSE.DecodeMessage(v)
            if not localsuccess then return end
            -- This path never writes back -- which is why variables kept their
            -- envelope where sequences lost it -- so there is nothing to gate,
            -- only damage from an earlier build to report.
            GSE.AuditProtectedAtRest("variable", nil, k, v, uncompressedVersion)
            compileVariable(k, GSE.UpgradeVariable(uncompressedVersion, k))
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

-- Lazy-load variables on first access. The selective load (#1065) only compiles
-- the variables a sequence DECLARES in MetaData.Dependencies.Variables, so a
-- `=GSE.V.X()` expression evaluated during sequence compilation can reference a
-- variable that exists in storage but has not been compiled into GSE.V yet -- a
-- load-order race where the compile reaches the reference before the variable is
-- loaded. This __index resolves any stored-but-unloaded variable on demand:
-- "load the dependency, don't report it missing". A genuinely-absent variable
-- (not in GSEVariables) still returns nil, so the real missing-variable
-- detection in processAction is unchanged. __index fires only on a key miss;
-- once loaded the key is set so there is no repeat cost, pairs() is unaffected,
-- and dependency cycles terminate because loadOneVariable sets the key before
-- it test-calls the variable.
if type(GSE.V) == "table" and not getmetatable(GSE.V) then
    setmetatable(GSE.V, {
        __index = function(t, k)
            -- Another class's variable is not live here (see "Scope of
            -- variables and macros"); it reads as missing, like any other.
            if not GSE.isEmpty(GSE.Store("variable")[k]) and GSE.ElementAvailable("variable", k) then
                loadOneVariable(k, GSE.Store("variable")[k])
                return rawget(t, k)
            end
        end
    })
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
        if not GSE.isEmpty(GSE.Store("variable")[vname]) then
            local ok, decoded = GSE.DecodeMessage(GSE.Store("variable")[vname])
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
    -- Nothing stored: nothing to compile. (The store's root always exists, so
    -- this asks whether it is empty rather than whether it is there.)
    if next(GSE.Store("variable")) == nil then return end

    local needed = collectNeededVariables()

    if needed == nil then
        -- Fallback: at least one sequence has no dep data; load everything
        -- that is live for this class.
        for k, v in pairs(GSE.Store("variable")) do
            if GSE.ElementAvailable("variable", k) then loadOneVariable(k, v) end
        end
        return
    end

    -- Selective load: only compile variables the current sequences need.
    local deferred = 0
    for k, v in pairs(GSE.Store("variable")) do
        if needed[k] and GSE.ElementAvailable("variable", k) then
            loadOneVariable(k, v)
        else
            deferred = deferred + 1
        end
    end
    if deferred > 0 then
        --@debug@
        GSE.PrintDebugMessage(
            string.format("%d variable(s) deferred (not needed by current sequences).", deferred),
            GNOME
        )
        --@end-debug@
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
        if GSE.isEmpty(GSE.V[vname]) and not GSE.isEmpty(GSE.Store("variable")[vname]) then
            loadOneVariable(vname, GSE.Store("variable")[vname])
        end
        -- Walk transitive deps from the stored variable data.
        if not GSE.isEmpty(GSE.Store("variable")[vname]) then
            local ok, decoded = GSE.DecodeMessage(GSE.Store("variable")[vname])
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

--- Every MetaData key that holds a VERSION NUMBER, derived from
-- contextVersionPriority above rather than repeated. PVP appears twice in
-- that table (once routing to Arena), so dedupe on valueKey.
local contextVersionKeys = {}
do
    local seen = {}
    for _, entry in ipairs(contextVersionPriority) do
        if entry.valueKey and not seen[entry.valueKey] then
            seen[entry.valueKey] = true
            contextVersionKeys[#contextVersionKeys + 1] = entry.valueKey
        end
    end
end

--- The context keys, in priority order. Callers must not mutate the result.
function GSE.GetContextVersionKeys()
    return contextVersionKeys
end

--- How each context key is PRESENTED: the Configuration tab section it is
-- drawn under, the row label, and its tooltip. `label` and `tip` are
-- localisation keys (English source strings), translated by whoever displays
-- them, so this table stays free of any locale dependency.
--
-- It lives here, beside the keys themselves, because #2023 was the two lists
-- drifting apart: the editor kept its OWN row table, which had grown a PVESolo
-- row the runtime has no context for and LOST the rows for Mythic, Heroic and
-- Party -- all three of which the runtime still honours. An author who had set
-- one of those (or imported a sequence that had) could not see it, could not
-- change it, and was refused when deleting the version it pointed at, with a
-- message naming a row that was not on screen. Deriving the rows from here
-- means a key cannot exist without somewhere to set it.
--
-- Order is display order, not priority order (priority lives in
-- contextVersionPriority above and is the runtime's business, not the user's).
local contextVersionDisplay = {
    { key = "Scenario",    section = "PVE", label = "Delves/Scenarios", tip = "The version of this sequence to use in Delves and Scenarios." },
    { key = "Party",       section = "PVE", label = "Party",            tip = "The version of this sequence to use when in a party in the world." },
    { key = "Dungeon",     section = "PVE", label = "Dungeon",          tip = "The version of this sequence to use in normal dungeons." },
    { key = "Heroic",      section = "PVE", label = "Heroic",           tip = "The version of this sequence to use in heroic dungeons." },
    { key = "Mythic",      section = "PVE", label = "Mythic",           tip = "The version of this sequence to use in Mythic Dungeons." },
    { key = "MythicPlus",  section = "PVE", label = "Mythic+",          tip = "The version of this sequence to use in Mythic+ Dungeons." },
    { key = "Timewalking", section = "PVE", label = "Timewalking",      tip = "The version of this sequence to use when in time walking dungeons." },
    { key = "Raid",        section = "PVE", label = "Raid",             tip = "The version of this sequence that will be used when you enter raids." },
    { key = "PVP",         section = "PVP", label = "PVP",              tip = "The version of this sequence to use in PVP." },
    { key = "Arena",       section = "PVP", label = "Arena",            tip = "The version of this sequence to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default." },
}

--- Display entries for every context key, in display order.
--
-- Built from contextVersionKeys, NOT from the table above: a key added to
-- contextVersionPriority and forgotten here still gets an entry (labelled with
-- its raw key, in PvE) rather than silently vanishing from the Configuration
-- tab, which is the failure this whole pair exists to prevent. Returns a fresh
-- table each call; callers may keep it but must not expect it to update.
function GSE.GetContextVersionDisplay()
    local known, emitted, display = {}, {}, {}
    for _, key in ipairs(contextVersionKeys) do known[key] = true end
    for _, entry in ipairs(contextVersionDisplay) do
        -- Skip a display entry whose key the runtime no longer knows about --
        -- the reverse drift, a row nothing reads.
        if known[entry.key] then
            emitted[entry.key] = true
            display[#display + 1] = { key = entry.key, section = entry.section, label = entry.label, tip = entry.tip }
        end
    end
    for _, key in ipairs(contextVersionKeys) do
        if not emitted[key] then
            display[#display + 1] = { key = key, section = "PVE", label = key, tip = key }
        end
    end
    return display
end

--- The label a context key is shown under, for messages that have to name one.
-- Falls back to the key so a caller always gets something printable.
function GSE.GetContextVersionLabel(key)
    for _, entry in ipairs(contextVersionDisplay) do
        if entry.key == key then return entry.label end
    end
    return key
end

--- Which MetaData entries point AT `version`.
-- Returns a list of key names, empty when nothing references it. Deleting a
-- version that something points at is refused rather than silently repointed:
-- an author who set Raid to version 4 chose that, and moving it to Default
-- behind their back changes which macro fires in a raid.
function GSE.VersionReferencesInUse(metadata, version)
    local inUse = {}
    if type(metadata) ~= "table" then return inUse end
    version = tonumber(version)
    if not version then return inUse end
    if tonumber(metadata.Default) == version then inUse[#inUse + 1] = "Default" end
    for _, key in ipairs(contextVersionKeys) do
        if tonumber(metadata[key]) == version then inUse[#inUse + 1] = key end
    end
    return inUse
end

--- Move every version reference down one slot after `version` was deleted.
--
-- Only references AFTER the deleted version move — what they point at slid
-- down by one. A reference BEFORE it cannot be affected: deleting a later
-- version does not renumber earlier ones. A reference AT it never reaches
-- here, because VersionReferencesInUse blocks the delete first.
--
-- Default used to be decremented unconditionally, so deleting version 5 while
-- Default was 4 silently moved Default to 3 — the sequence then ran a macro
-- the author never selected.
function GSE.ShiftVersionReferencesAfterDelete(metadata, version)
    if type(metadata) ~= "table" then return end
    version = tonumber(version)
    if not version then return end
    local function shift(value)
        local n = tonumber(value)
        if n and n > version then return n - 1 end
        return value
    end
    metadata.Default = shift(metadata.Default)
    for _, key in ipairs(contextVersionKeys) do
        if not GSE.isEmpty(metadata[key]) then
            metadata[key] = shift(metadata[key])
        end
    end
end


--- The version to run for an element's MetaData in the current context: the
--- first context flag that is set and that the element configures, else
--- Default. One selector for sequences, variables and macros alike, so the
--- three can never disagree about which context they are in.
function GSE.GetActiveVersion(meta)
    if type(meta) ~= "table" then return 1 end
    -- PVESolo is gone: it was never one of GSE's contexts (it is absent from
    -- contextVersionPriority), only an editor row plus this special case, and
    -- "solo" is what Default already means -- no context flag set. A sequence
    -- saved with a PVESolo value now follows Default when solo, like every
    -- sequence that never had one.
    local vers = (not GSE.isEmpty(meta.Default)) and meta.Default or 1
    for _, ctx in ipairs(contextVersionPriority) do
        if meta[ctx.metaKey] and GSE[ctx.flag] then
            vers = meta[ctx.valueKey]
            break
        end
    end
    return (vers == 0) and 1 or vers
end

--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(id)
    local sequence = GSE.GetSequence(id)
    if GSE.isEmpty(sequence) or type(sequence.MetaData) ~= "table" then
        return
    end
    return GSE.GetActiveVersion(sequence.MetaData)
end

-- ── Variables and macros: one shape with sequences ───────────────────────────
--
--   variable = { MetaData = { Name, Author, SpecID, Default, <contexts>,
--                             Notes, Help },
--                Versions = { [n] = { Label, funct, eventEnabled, eventNames } },
--                Dependencies, LastUpdated, GSEVersion }
--   macro    = { MetaData = { ...the same... },
--                Versions = { [n] = { Label, text, managedMacro, Ranks } },
--                name, icon, Managed, value (its WoW slot -- never uploaded),
--                LastUpdated, GSEVersion }
--
-- Older content is flat: a variable's funct and events, a macro's text and
-- managedMacro, and its help as comments/commentsHelp, all at the top. These
-- turn either shape into the new one; one already new comes back as it is.
-- Everything that reads a variable or a macro reads it through them, so older
-- exports, older players' shares and records not yet migrated keep working.

local ELEMENT_META = { Author = true, comments = "Notes", commentsHelp = "Help" }

-- Move the flat fields that belong in MetaData into it.
local function liftMeta(t, name)
    local meta = type(t.MetaData) == "table" and t.MetaData or {}
    for field, into in pairs(ELEMENT_META) do
        local target = (into == true) and field or into
        if t[field] ~= nil then
            if meta[target] == nil then meta[target] = t[field] end
            t[field] = nil
        end
    end
    if name and meta.Name == nil then meta.Name = name end
    if meta.Default == nil then meta.Default = 1 end
    t.MetaData = meta
end

--- A variable in the current shape. Changes and returns the table given.
function GSE.UpgradeVariable(v, name)
    if type(v) ~= "table" then return v end
    if type(v.Versions) ~= "table" then
        v.Versions = { { funct = v.funct, eventEnabled = v.eventEnabled, eventNames = v.eventNames } }
        v.funct, v.eventEnabled, v.eventNames = nil, nil, nil
    end
    liftMeta(v, name)
    return v
end

--- A macro node in the current shape. Changes and returns the table given.
--- The legacy lowercase manageMacro was a copy of the text; it goes.
function GSE.UpgradeMacro(node, name)
    if type(node) ~= "table" or type(node.GSEProtected) == "string" then return node end
    if type(node.Versions) ~= "table" then
        -- Ranks: the casts its text wrote with a rank -- they describe that
        -- text, so they move with it (see "Spell ranks" in translator.lua).
        node.Versions = { { text = node.text, managedMacro = node.managedMacro, Ranks = node.Ranks } }
        node.text, node.managedMacro, node.Ranks = nil, nil, nil
    end
    node.manageMacro = nil
    liftMeta(node, name or node.name)
    return node
end

--- The version of a variable or macro that runs now (see GetActiveVersion).
function GSE.ActiveElementVersion(element)
    if type(element) ~= "table" or type(element.Versions) ~= "table" then return nil end
    local n = GSE.GetActiveVersion(element.MetaData)
    return element.Versions[n] or element.Versions[1]
end

--- What a macro's running version is authored as: managedMacro for a managed
--- macro (it may call variables), text otherwise. Accepts either shape.
function GSE.MacroSource(node)
    if type(node) ~= "table" then return "" end
    if type(node.Versions) ~= "table" then return node.managedMacro or node.text or "" end
    local v = GSE.ActiveElementVersion(node) or {}
    return v.managedMacro or v.text or ""
end

--- The ranked casts of a macro's running version (see "Spell ranks" in
--- translator.lua). Accepts either shape.
function GSE.MacroRanks(node)
    if type(node) ~= "table" then return nil end
    if type(node.Versions) ~= "table" then return node.Ranks end
    local v = GSE.ActiveElementVersion(node)
    return v and v.Ranks
end

-- Compile macro source with its ranked casts in force.
local function compileWithRanks(ranks, text, mode)
    if GSE.WithSpellRanks then return GSE.WithSpellRanks(ranks, GSE.CompileMacroText, text, mode) end
    return GSE.CompileMacroText(text, mode)
end

--- What goes into the player's WoW macro for a macro node: a managed macro's
--- source compiled (variables, ranks and all), anything else its text as
--- written. A flat node -- a WoW macro in the making, not a stored macro -- is
--- its text.
function GSE.MacroText(node)
    if type(node) ~= "table" then return "" end
    if type(node.Versions) ~= "table" then return node.text or "" end
    if node.Managed then
        return compileWithRanks(GSE.MacroRanks(node), GSE.MacroSource(node), Statics.TranslatorMode.String)
    end
    local v = GSE.ActiveElementVersion(node) or {}
    return v.text or ""
end

--- A stored macro node, in the current shape, for a macro read out of WoW.
function GSE.NewMacroNode(name, icon, text, slot)
    return {
        name = name, icon = icon, value = slot,
        MetaData = { Name = name, Default = 1 },
        Versions = { { text = text } },
    }
end

--- Does GSE write this stored macro into WoW, rather than read it from there?
--- A managed macro does: WoW holds what its source compiles to. So does one
--- with more than one version: WoW holds whichever the context selects, and
--- reading that back would copy one version over another when it changes.
function GSE.MacroDrivenByGSE(node)
    if type(node) ~= "table" then return false end
    if node.Managed then return true end
    return type(node.Versions) == "table" and #node.Versions > 1
end

--- Record a macro read out of WoW in a store table (the account level, or a
--- character's bucket). WoW holds only what one version compiles to, so this
--- never writes over a macro GSE drives (MacroDrivenByGSE) or a sealed one --
--- its source lives in GSE, and a snapshot would replace it with what WoW
--- holds -- and for any other macro it updates its text, the icon and the
--- slot, leaving its metadata alone. Returns the node.
function GSE.SnapshotMacro(store, key, name, icon, text, slot)
    local node = store[key]
    if type(node) == "table" and (GSE.MacroDrivenByGSE(node) or type(node.GSEProtected) == "string") then
        node.value = slot
        return node
    end
    if not GSE.IsStoredMacroNode(node) then
        node = GSE.NewMacroNode(name, icon, text, slot)
        store[key] = node
        return node
    end
    GSE.UpgradeMacro(node, name)
    local active = GSE.ActiveElementVersion(node)
    if active then active.text = text else node.Versions[1] = { text = text } end
    node.icon, node.value = icon, slot
    return node
end

--- Recompile every variable already in GSE.V with the version the current
--- context selects. Run when the context changes, beside the sequences.
function GSE.ReloadVariables()
    local names = {}
    for name in pairs(GSE.V) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        local stored = GSE.Store("variable")[name]
        if stored ~= nil and GSE.ElementAvailable("variable", name) then
            local pok, ok, decoded = pcall(GSE.DecodeMessage, stored)
            if pok and ok and type(decoded) == "table" then compileVariable(name, GSE.UpgradeVariable(decoded, name)) end
        end
    end
end

function GSE.ReloadSequences()
    GSE.ReloadVariables()
    if GSE.ClearTranslateStringCache then GSE.ClearTranslateStringCache() end
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) then
        GSE.PerformReloadSequences()
        GSE.UnsavedOptions.ReloadQueued = true
    end
    GSE.EnqueueOOC({action = "managemacros"})
end

function GSE.PerformReloadSequences(force)
    --@debug@
    GSE.PrintDebugMessage("Reloading Sequences", Statics.DebugModules["Storage"])
    --@end-debug@
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
    -- A record with no MetaData or no Versions -- one the editor's tree flags
    -- as corrupt -- has nothing in it to compile, and reading either field off
    -- it stopped the reload for every sequence after it. Anything else is
    -- compiled exactly as before: a missing SpecID, say, still runs.
    local function reloadable(sequence)
        return type(sequence) == "table" and type(sequence.MetaData) == "table"
            and type(sequence.Versions) == "table"
    end
    for id, sequence in pairs(GSE.Library[GSE.GetCurrentClassID()]) do
        if reloadable(sequence) and not sequence.MetaData.Disabled then
            func(id, sequence.Versions[GSE.GetActiveSequenceVersion(id)])
        end
    end
    if not GSE.isEmpty(GSE.Library[0]) then
        for id, sequence in pairs(GSE.Library[0]) do
            if reloadable(sequence) and GSE.isEmpty(sequence.MetaData.Disabled) then
                func(id, sequence.Versions[GSE.GetActiveSequenceVersion(id)])
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
        local classid = GSE.GetCurrentClassID()
        local ids = {}
        for id in pairs(GSE.SequenceEnvelopes(classid)) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do GSE.RemoveSequence(classid, id) end
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
function GSE.UpdateSequence(id, sequence)
    local vals = {}
    vals.action = "UpdateSequence"
    vals.id = id
    vals.macroversion = sequence
    GSE.EnqueueOOC(vals)
end

--- This function updates the button for an existing sequence.  It is called from the OOC queue
function GSE.OOCUpdateSequence(id, sequence)
    if GSE.isEmpty(sequence) then
        return
    end
    if GSE.isEmpty(id) then
        return
    end
    -- Only a sequence the runtime would run: the current class or global.
    local env, classid = GSE.SequenceEnvelope(id)
    if not env or (classid ~= 0 and classid ~= GSE.GetCurrentClassID()) then
        return
    end
    -- The secure button is named by the id (see "Buttons"); messages show the label.
    local name = GSE.ResolveSequenceId(id)
    local label = env.Name

    -- Avoid rebuilding the secure button while a boss encounter is still active.
    if GSE.IsEncounterInProgress and GSE.IsEncounterInProgress() then
        GSE.UpdateSequence(id, sequence)
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
                    "%s sequence may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this sequence."
                ],
                label,
                actionCount
            ),
            "MACRO ERROR"
        )
    end
    GSE.CreateGSE3Button(compiledTemplate, name, combatReset, label)
    if GSE.RefreshActionBarOverrideIcons then
        GSE.RefreshActionBarOverrideIcons(name, false)
        C_Timer.After(0, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
        C_Timer.After(0.1, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
        C_Timer.After(0.25, function() GSE.RefreshActionBarOverrideIcons(name, false) end)
    end
    if GSE.GUI and not GSE.isEmpty(GSE.GUIEditFrame) then
        if not GSE.isEmpty(GSE.GUIEditFrame.IsVisible) then
            if GSE.GUIEditFrame:IsVisible() then
                GSE.GUIEditFrame:SetStatusText(label .. " " .. L["Saved"])
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
    if numCharacterMacros >= GSE.GetMaxCharacterMacros() - 1 and GSEOptions.overflowPersonalMacros then
        returnval = nil
    end
    return returnval
end

--- Order for GetSequenceNames keys ("classid,spec,id,disable"): by class,
-- then spec, then label as a person reads it, then id. Sorting the keys
-- themselves would put sequences in id order, which means nothing to anyone.
function GSE.SequenceKeyOrder(a, b)
    local ea, eb = GSE.split(tostring(a), ","), GSE.split(tostring(b), ",")
    local ca, cb = tonumber(ea[1]) or 0, tonumber(eb[1]) or 0
    if ca ~= cb then return ca < cb end
    local sa, sb = tonumber(ea[2]) or 0, tonumber(eb[2]) or 0
    if sa ~= sb then return sa < sb end
    local na = GSE.SequenceName(ea[3], ca) or tostring(ea[3])
    local nb = GSE.SequenceName(eb[3], cb) or tostring(eb[3])
    if na ~= nb then return GSE.AlphabeticalTableSortAlgorithm(na, nb) end
    return tostring(ea[3]) < tostring(eb[3])
end

--- The sequences to list for the current filters, as { ["classid,spec,id,
-- disable"] = id }. The label is GSE.SequenceName(id).
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
    -- A record with no MetaData or no SpecID still gets a key -- spec 0, the
    -- key a not-yet-decoded foreign-class sequence already gets below --
    -- rather than throwing. This runs before the tree isolates each sequence,
    -- so one such record blanked the whole list, New Sequence and Import
    -- included; the tree now lists it and flags it red for deletion.
    local function specOf(j)
        local meta = type(j) == "table" and j.MetaData
        return (type(meta) == "table" and meta.SpecID) or 0
    end
    local keyset = {}
    for k, _ in pairs(Library) do
        if GSEOptions.filterList[Statics.All] or k == currentClassID then
            if k == currentClassID or k == 0 then
                -- Library already loaded for these classes ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â full metadata available.
                for i, j in pairs(Library[k]) do
                    local disable = 0
                    if type(j) == "table" and j.DisableEditor then
                        disable = 1
                    end
                    local keyLabel = k .. "," .. specOf(j) .. "," .. i .. "," .. disable
                    if k == currentClassID and GSEOptions.filterList["Class"] then
                        keyset[keyLabel] = i
                    elseif k == currentClassID and not GSEOptions.filterList["Class"] then
                        if specOf(j) == GSE.GetCurrentSpecID() or specOf(j) == currentClassID then
                            keyset[keyLabel] = i
                        end
                    else
                        keyset[keyLabel] = i
                    end
                end
            else
                -- Foreign class under All filter: enumerate names from the compressed store
                -- without decompressing. SpecID and disable are unknown until opened.
                for i in pairs(GSE.SequenceEnvelopes(k)) do
                    keyset[k .. ",0," .. i .. ",0"] = i
                end
            end
        else
            if k == 0 and GSEOptions.filterList[Statics.Global] then
                for i, j in pairs(Library[k]) do
                    local disable = 0
                    if type(j) == "table" and j.DisableEditor then
                        disable = 1
                    end
                    local keyLabel = k .. "," .. specOf(j) .. "," .. i .. "," .. disable
                    keyset[keyLabel] = i
                end
            end
        end
    end

    return keyset
end

--- Return the Macro Icon for the specified Sequence
function GSE.GetMacroIcon(classid, id)
    classid = tonumber(classid)
    GSE.EnsureSequenceLoaded(classid, id)
    -- The macro stub is named by the label.
    local sequenceIndex = GSE.SequenceName(id, classid) or tostring(id)
    --@debug@
    GSE.PrintDebugMessage("sequenceIndex: " .. (GSE.isEmpty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
    --@end-debug@
    classid = tonumber(classid)
    local macindex = GetMacroIndexByName(sequenceIndex)
    local a, iconid, c = GetMacroInfo(macindex)
    if not GSE.isEmpty(a) then
        --@debug@
        GSE.PrintDebugMessage(
            "Macro Found " ..
                a ..
                    " with iconid " ..
                        (GSE.isEmpty(iconid) and "of no value" or iconid) ..
                            " " .. (GSE.isEmpty(iconid) and L["with no body"] or c),
            GNOME
        )
        --@end-debug@
    else
        --@debug@
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        --@end-debug@
        return GSEOptions.DefaultDisabledMacroIcon
    end

    local sequence = GSE.Library[classid][id]
    if GSE.isEmpty(sequence) then
        --@debug@
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        --@end-debug@
        return GSEOptions.DefaultDisabledMacroIcon
    end
    if GSE.isEmpty(sequence.Icon) and GSE.isEmpty(iconid) then
        --@debug@
        GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.MetaData.SpecID, GNOME)
        --@end-debug@
        if sequence.MetaData.SpecID == 0 then
            return "INV_MISC_QUESTIONMARK"
        else
            local _, _, _, specicon, _, _, _ =
                GetSpecializationInfoByID(
                    (GSE.isEmpty(sequence.MetaData.SpecID) and GSE.GetCurrentSpecID() or sequence.MetaData.SpecID)
                )
            if specicon then
                if type(specicon) == "string" then
                    --@debug@
                    GSE.PrintDebugMessage("No Sequence Icon setting to " .. strsub(specicon, 17), GNOME)
                    --@end-debug@
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

--- Resolve the icon a `#showtooltip <thing>` directive was asking for.
-- GSE never executes the directive, so once GSE.ApplyShowTooltipToAction
-- strips the line its argument is the only surviving record of the icon the
-- author picked. Same candidate resolution the /cast path uses: conditionals
-- stripped, spell name or id first, item last.
function GSE.GetShowTooltipIconInfo(argument, suppressUIErrors)
    if type(argument) ~= "string" then return nil end
    local resolved = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(argument, suppressUIErrors)
    resolved = trimMacroIconCandidate(resolved)
    -- SecureCmdOptionParse returns nil when every clause is false right now
    -- (e.g. `[combat] Spell` out of combat). The literal text still names the
    -- icon the author wanted, so fall back to it.
    if resolved == "" then resolved = trimMacroIconCandidate(argument) end
    if resolved == "" then return nil end
    return getMacroIconFallbackCandidateInfo(resolved, false)
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
    -- Flat index into SequencesExec. Iteration 2 step 1 is the 254th step of
    -- the rotation, not the 509th: the offset is the number of steps in the
    -- iterations ALREADY consumed, so iteration-1 of them, not iteration.
    if iteration > 1 then
        step = (iteration - 1) * SECURE_STEPS_PER_ITERATION + step
    end

    local gsebutton = self:GetName()
    local executionseq = GSE.SequencesExec and GSE.SequencesExec[gsebutton]
    local action = executionseq and executionseq[step]
    if not action then return nil end

    local foundSpell = action.spell and action.spell or ""
    local spellinfo = {}
    spellinfo.iconID = Statics.QuestionMarkIconID

    if reseticon == true then
        local label = GSE.SequenceName(gsebutton) or gsebutton
        spellinfo.name = label
        spellinfo.iconID = Statics.Icons.GSE_Logo_Dark
        foundSpell = label
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
                GSE.Print("Unable to find spell: " .. tostring(spell) .. " from " .. (GSE.SequenceName(gsebutton) or gsebutton) .. " - Compiled Step " .. step)
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
    -- Same flat index as GSE.GetCurrentButtonIconInfo computes. It is needed
    -- again here: this `step` is the fallback lookup into SequencesExec, and
    -- it is the Step reported outward to WeakAuras and the sequence debugger.
    if iteration > 1 then
        step = (iteration - 1) * SECURE_STEPS_PER_ITERATION + step
    end
    -- The button is named by its sequence's id; what is shown is the label.
    local gsebutton = self:GetName()
    local label = GSE.SequenceName(gsebutton) or gsebutton
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
            SequenceID = gsebutton,
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
            SequenceID = gsebutton,
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
                                        GSEOptions.showActionBarLabel ~= false and label or "")
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
                            -- _G[k].TextOverlayContainer.Count:SetText(label)
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
    GSE.WagoAnalytics:Switch(label .. "_" .. GSE.GetCurrentClassID(), true)
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
        -- Chosen here, not in the snippet: the snippet runs in the secure
        -- environment and cannot see GSEOptions. Changing the option therefore
        -- needs the button rebuilding, which is why the setting prompts for a
        -- reload (same as the modifier-pause toggles).
        local skeleton = GSEOptions.AnnounceMacroReset and Statics.MacroResetSkeletonAnnounced
            or Statics.MacroResetSkeleton
        returnstring = string.format(skeleton, table.concat(activemods, " and "))
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
            if k == "Disabled" or type(value) == "boolean" or k == "Type" or k == "Interval" or k == "Ranks" then
                -- we dont want to do anything here
            else
                if string.sub(value, 1, 1) == "=" then
                    xpcall(
                        function()
                            local tempval = gseLoadstring("return " .. string.sub(value, 2, string.len(value)))()
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
                    -- Resolved per character: a ranked spell casts the highest
                    -- rank known up to the one written (see "Spell ranks" in
                    -- translator.lua).
                    spelllist[k] = GSE.GetCastableSpell(value, action.Ranks)
                elseif k == "macro" then
                    if GSE.DecodeMacroEditorText then
                        value = GSE.DecodeMacroEditorText(value)
                    end
                    if GSE.IsMacroTextBody(GSE.UnEscapeString(value)) then
                        -- we have a line of macrotext
                        spelllist["macrotext"] = GSE.UnEscapeString(
                            GSE.WithSpellRanks(action.Ranks, GSE.CompileMacroText, value, Statics.TranslatorMode.String))
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
                            --@debug@
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                            --@end-debug@
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
                            --@debug@
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                            --@end-debug@
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
                --@debug@
                GSE.PrintDebugMessage(loop, "Storage1")
                --@end-debug@
            end
        end
        -- print(#PauseActions, GSE.Dump(action))
        return PauseActions
    elseif action.Type == Statics.Actions.If then
        -- process repeats for the block
        if GSE.isEmpty(action.Variable) then
            GSE.Print(L["If Blocks Require a variable."], L["Sequence Compile Error"])
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
        local fn, loadErr = gseLoadstring("return " .. funct)
        if fn then
            local ok, result = pcall(fn)
            if ok then
                val = result
            else
                --@debug@
                GSE.PrintDebugMessage("If-block eval error: " .. tostring(result), "Storage")
                --@end-debug@
            end
        else
            --@debug@
            GSE.PrintDebugMessage("If-block load error: " .. tostring(loadErr), "Storage")
            --@end-debug@
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
        if action.SequenceID or action.Sequence then
            local sequence, id = GSE.ResolveEmbed(action)
            if sequence then
                return GSE.CompileTemplate(GSE.UnEscapeTable(GSE.TranslateSequence(sequence.Versions[GSE.GetActiveSequenceVersion(id)], Statics.TranslatorMode.String)))
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
                -- The key is a PATH (a list of indices); this walks it. A plain
                -- index is simply absent, which is what a raw read would have
                -- said. Lua 5.1's ipairs is raw and never reaches here, so the
                -- guard has never been needed in game -- but 5.3+ honours
                -- __index, and a numeric key then arrived at ipairs(k) and
                -- errored. Off-game test runners are 5.4.
                if type(k) ~= "table" then return nil end
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
        if finalsteps == SECURE_STEPS_PER_ITERATION + 1 or k == #compressedsteps then
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
function GSE.CreateGSE3Button(spelllist, name, combatReset, label)
    local status, err = pcall(PCallCreateGSE3Button, spelllist, name, combatReset)
    if err or not status then
        GSE.Print(
            string.format(
                "%s " ..
                    L["was unable to be programmed.  This sequence will not fire until errors in the sequence are corrected."],
                label or name
            ),
            "BROKEN MACRO"
        )
        --@debug@
        if GSE.PrintDebugMessage then GSE.PrintDebugMessage(tostring(err), "Storage") end
        --@end-debug@
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
    GSE.UpgradeVariable(variable, name)
    GSE.ComputeVariableDependencies(variable)
    local storedVariable = GSE.Store("variable") and GSE.Store("variable")[name]
    if GSE.IsProtectedAtRest(storedVariable, variable) then
        -- Same rule as a sequence: the sealed blob stays, the edit becomes a
        -- delta over it, and if there is nothing to key a fork by we ask for a
        -- repack rather than writing the variable out in the clear. A nil
        -- stored value reaches SeedDeltaFork as nil and is refused there,
        -- which lands on the same fallback.
        if not GSE.SeedDeltaFork(storedVariable, variable, "variable") then
            GSE.QueueRepack("variable", nil, name, variable, "edit-needs-repack")
        end
    else
        local compressedvariable = GSE.EncodeMessage(variable)
        if not (GSE.UpdateDeltaFork and GSE.UpdateDeltaFork(variable)) then
            GSE.Store("variable")[name] = compressedvariable
        end
    end
    compileVariable(name, variable)
    settleCollections("variable", name, name)
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

    -- Sequences: GSE.Library[classid][id] is the in-memory shape; the
    -- envelope's Body is the encoded blob. Re-encode on stamp so the store
    -- survives reload.
    if GSE.Library then
        for classid, classLib in pairs(GSE.Library) do
            if type(classLib) == "table" then
                for id, seq in pairs(classLib) do
                    local env = GSE.SequenceEnvelopes(classid)[id]
                    -- Skip protected content outright. There is no way to
                    -- persist the stamp without rewriting the sealed blob, and
                    -- an unwritten LastUpdated would be re-minted to a new
                    -- `now` on every load anyway -- drift, not a backfill.
                    if type(seq) == "table" and not seq.LastUpdated and env
                        and not GSE.IsProtectedAtRest(env.Body, seq) then
                        seq.LastUpdated = now
                        env.Body = GSE.EncodeMessage({env.Name, seq})
                        touched = touched + 1
                    end
                end
            end
        end
    end

    -- Variables: flat shape, GSEVariables[name] is the variable table.
    if GSE.Store("variable") then
        for _, v in pairs(GSE.Store("variable")) do
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
    if GSE.Store("macro") then
        for _, scopeOrNode in pairs(GSE.Store("macro")) do
            if type(scopeOrNode) == "table" then
                local isNode = GSE.IsStoredMacroNode(scopeOrNode)
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
        --@debug@
        GSE.PrintDebugMessage(
            string.format("LastUpdated backfill: stamped %d records", touched),
            "Storage"
        )
        --@end-debug@
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

--- Write a macro into the player's WoW macros, creating it if they do not
--- have it. `node` is either a stored macro (current shape -- MacroText says
--- what the WoW macro holds) or a flat { name, icon, text } built for WoW
--- alone. Only a stored macro is ever stored, and only when it is new here
--- and skipStore is not set. A flat node used to be stored too: that is how a
--- managed macro missing from a character's macro book lost its source --
--- ManageMacros handed over the compiled text, and it replaced the macro.
function GSE.UpdateMacro(node, category, skipStore)
    -- Save-cancels-delete (see UpdateVariable for rationale).
    if node and node.name and GSE.CompanionCancelPendingDelete then
        GSE.CompanionCancelPendingDelete("macro", node.name)
    end
    local stored = node and type(node.Versions) == "table"
    local text
    if node then
        if stored then
            -- Stamp LastUpdated so server-side newer-wins resolution can pick
            -- the most-recently-edited copy when one Companion is syncing the
            -- same macro across two WoW accounts. UTC via GetServerTime().
            node.LastUpdated = GSE.GetTimestamp()
            -- The build that wrote it, as sequences carry in MetaData.GSEVersion.
            node.GSEVersion = GSE.VersionNumber
            if not node.Managed then
                for _, version in pairs(node.Versions) do
                    if type(version) == "table" and type(version.text) == "string" then
                        version.text = CleanMacroBookText(version.text)
                    end
                end
            end
        end
        text = CleanMacroBookText(GSE.MacroText(node))
    end
    if not InCombatLockdown() then
        GSE:UnregisterEvent("UPDATE_MACROS")
        local slot = GetMacroIndexByName(node.name)
        if slot > 0 then
            EditMacro(slot, node.name, node.icon, text)
        else
            node.value = CreateMacro(node.name, node.icon, text, category)
            if stored and not skipStore then
                if not (GSE.UpdateDeltaFork and GSE.UpdateDeltaFork(node)) then
                    if category then
                        local charKey = GSE.CharacterMacroBucketKey()
                        GSE.Store("macro")[charKey][node.name] = node
                    else
                        GSE.Store("macro")[node.name] = node
                    end
                end
            end
        end
        GSE:RegisterEvent("UPDATE_MACROS")
        GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, node.name)
    end
    return node
end

local function resolveMacroNode(entry)
    if type(entry) == "table" and type(entry.GSEProtected) == "string" then
        local ok, decoded = GSE.DecodeMessage(entry.GSEProtected)
        if ok and type(decoded) == "table" then return decoded, true end
        return nil, true
    end
    return entry, false
end

local function materialiseEncodedMacro(name, node, category)
    if not node then return end
    local text = GSE.MacroSource(node)
    GSE.UpdateMacro({
        ["name"] = name,
        ["icon"] = (node.Managed and GSE.GetManagedMacroStubIcon)
            and GSE.GetManagedMacroStubIcon(name, node.icon) or node.icon,
        ["text"] = compileWithRanks(GSE.MacroRanks(node), text, Statics.TranslatorMode.String),
    }, category, true)
end

function GSE.ImportMacro(node)
    local characterMacro = false
    local source = GSE.Store("macro")
    if node.category == "p" then
        characterMacro = true
        local charKey = GSE.CharacterMacroBucketKey()
        if GSE.isEmpty(GSE.Store("macro")[charKey]) then
            GSE.Store("macro")[charKey] = {}
        end
        source = GSE.Store("macro")[charKey]
    end
    node.category = nil
    GSE.UpgradeMacro(node)

    source[node.name] = GSE.UpdateMacro(node, characterMacro)
    settleCollections("macro", node.name, node.name)
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
                local functionresult, error = gseLoadstring("return " .. string.sub(value, 2, string.len(value)))

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
    for k, v in pairs(GSE.Store("macro")) do
        local pnode, encodedEntry = resolveMacroNode(v)
        -- Another class's macro is not written to this character's macros.
        if GSE.IsStoredMacroNode(v) and not GSE.ElementAvailable("macro", k) then
            -- left as stored
        elseif encodedEntry then
            -- Entry held in received encoded form: materialise without writing
            -- a plaintext node back over it (see resolveMacroNode).
            materialiseEncodedMacro(k, pnode, nil)
        elseif GSE.MacroDrivenByGSE(v) then
            local macroIndex = GetMacroIndexByName(k)
            if macroIndex ~= v.value then
                v.value = macroIndex
                GSE.Store("macro")[k].value = macroIndex
            end
            -- Written to WoW only; the stored macro keeps its source. The slot
            -- a created macro lands in is recorded on it.
            local node = {
                ["name"] = k,
                ["value"] = v.value,
                ["icon"] = (v.Managed and GSE.GetManagedMacroStubIcon) and GSE.GetManagedMacroStubIcon(k, v.icon) or v.icon,
                ["text"] = GSE.MacroText(GSE.UpgradeMacro(v, k))
            }
            GSE.UpdateMacro(node, nil, true)
            v.value = node.value
        else
            -- GetMacroIndexByName answers 0, not nil, for a name this character
            -- does not have -- and 0 is truthy. Tested as `if slot`, every miss
            -- went to GetMacroInfo(0), came back nil, and was deleted. That
            -- includes the character buckets themselves: this loop walks every
            -- key in GSEMacros, "Name-Realm" is never a macro name, so each
            -- bucket was dropped the moment it was created. The else branch
            -- below, which keeps tables, was written for exactly this case and
            -- could never be reached.
            local slot = GetMacroIndexByName(k)
            if slot and slot > 0 then
                local mname, micon, mbody = GetMacroInfo(slot)
                if mname then
                    GSE.SnapshotMacro(GSE.Store("macro"), mname, mname, micon, mbody, slot)
                else
                    GSE.Store("macro")[k] = nil
                end
            else
                if type(GSE.Store("macro")[k]) ~= "table" then
                    GSE.Store("macro")[k] = nil
                end
            end
        end
    end
    local charKey = GSE.CharacterMacroBucketKey()

    if GSE.Store("macro")[charKey] then
        for k, v in pairs(GSE.Store("macro")[charKey]) do
            if k == "value" then
                GSE.Store("macro")[charKey][k] = nil
            else
                local cpnode, cEncodedEntry = resolveMacroNode(v)
                if cEncodedEntry then
                    materialiseEncodedMacro(k, cpnode, true)
                elseif GSE.MacroDrivenByGSE(v) then
                    local macroIndex = GetMacroIndexByName(k)
                    if macroIndex ~= v.value then
                        v.value = macroIndex
                        GSE.Store("macro")[charKey][k].value = macroIndex
                    end
                    local node = {
                        ["name"] = k,
                        ["value"] = v.value,
                        ["icon"] = (v.Managed and GSE.GetManagedMacroStubIcon) and GSE.GetManagedMacroStubIcon(k, v.icon) or v.icon,
                        ["text"] = GSE.MacroText(GSE.UpgradeMacro(v, k))
                    }
                    GSE.UpdateMacro(node, true, true)
                    v.value = node.value
                else
                    -- 0 on a miss, as above: a macro this bucket holds that the
                    -- character does not is kept, not deleted.
                    local slot = GetMacroIndexByName(k)
                    if slot and slot > 0 then
                        local mname, micon, mbody = GetMacroInfo(slot)
                        if mname then
                            GSE.SnapshotMacro(GSE.Store("macro")[charKey], mname, mname, micon, mbody, slot)
                        else
                            GSE.Store("macro")[charKey][k] = nil
                        end
                    else
                        if type(GSE.Store("macro")[charKey][k]) ~= "table" then
                            GSE.Store("macro")[charKey][k] = nil
                        end
                    end
                end
            end
        end
    end

    -- Snapshot and restore WoW macros required by active sequences.
    -- Iterates global (0) and current-class libraries only; other classes are not
    -- loaded at runtime and their sequences are not executing.
    local currentClass = GSE.GetCurrentClassID()
    for _, classid in ipairs({0, currentClass}) do
        local classlib = GSE.Library[classid]
        if classlib then
            for id, seq in pairs(classlib) do
                local seqname = GSE.SequenceName(id, classid) or tostring(id)
                if type(seq) == "table" and type(seq.MetaData) == "table" then
                    local deps = seq.MetaData.Dependencies
                    if deps and type(deps.Macros) == "table" then
                        for _, macname in ipairs(deps.Macros) do
                            local slot = GetMacroIndexByName(macname)
                            if slot and slot > 0 then
                                -- Macro exists on this character: refresh the account-level snapshot.
                                local mname, micon, mbody = GetMacroInfo(slot)
                                if mname then
                                    GSE.SnapshotMacro(GSE.Store("macro"), macname, mname, micon, mbody, slot)
                                end
                            else
                                -- Macro missing on this character: restore from account-level store.
                                local stored = GSE.Store("macro")[macname]
                                local restoreText = GSE.IsStoredMacroNode(stored) and GSE.MacroText(GSE.UpgradeMacro(stored, macname)) or ""
                                if not GSE.isEmpty(restoreText) then
                                    CreateMacro(
                                        macname,
                                        stored.icon or Statics.QuestionMark,
                                        CleanMacroBookText(restoreText),
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
    local actualfunct, error = gseLoadstring("return " .. vartext)
    return actualfunct, error
end

--- Evaluate a `=GSE.V.X(...)` preview expression for the variable editor's test
-- field. Strips a leading `=`, compiles against the REAL GSE namespace (via
-- gseLoadstring, so GSE.V resolves past the public proxy) and pcalls it. Lets
-- the editor test a variable that takes arguments, e.g. =GSE.V.Prescience(2),
-- and re-evaluate on demand. Returns (true, value) on success or
-- (false, errorMessage) so the caller can show either.
function GSE.EvaluateVariableExpression(expr)
    if GSE.isEmpty(expr) then return false, "" end
    expr = GSE.TrimWhiteSpace and GSE.TrimWhiteSpace(expr) or expr
    if string.sub(expr, 1, 1) == "=" then expr = string.sub(expr, 2) end
    local chunk, err = gseLoadstring("return " .. expr)
    if not chunk then return false, err end
    local ok, result = pcall(chunk)
    if not ok then return false, result end
    return true, result
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Storage") end


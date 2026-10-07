local _, GSE = ...

-- ── Profiles (#2111 phase 4) ────────────────────────────────────────────────
--
-- What a class's spec is set up with, shared by every character of that class
-- on any realm or faction:
--
--   GSEStore.profile[classID][specID] = {
--       KeyBindings    = { [physicalKey] = sequenceId },
--       ActionBarBinds = { [buttonKey]   = { Bind, State, Sequence } },
--       Settings       = { [name] = value },          -- see SETTINGS
--   }
--
-- specID, not the spec index a character's binds were kept by: it is the same
-- on every character of the class. Before WoD (GameMode < 7) the Mod keeps one
-- set of binds per character, not per spec, so a profile there is per class
-- (specID = classID).
--
-- What stays on the character (GSE_C): anything keyed by a talent loadout --
-- its config id belongs to that character -- and, per spec, whether it has
-- opted out of the shared profile (ProfileOptOut[specKey]) to keep its own
-- binds and overrides. An opted-out character's binds live where they always
-- did (GSE_C.KeyBindings[specKey], GSE_C.ActionBarBinds.Specialisations);
-- settings still come from the profile.

-- The settings a profile carries. Everything else in GSEOptions is account-wide.
local SETTINGS = {
    msClickRate = true, resetOOC = true,
    MacroResetModifiers = true, ShiftPause = true, CtrlPause = true, AltPause = true,
    SkyRidingBinds = true,
    showActionBarWatermark = true, showActionBarLabel = true, actionBarOverridePopup = true,
    CvarActionButtonState = true,
}
GSE.ProfileSettingNames = SETTINGS

--- The current spec's key in a character's binds: the spec index as a string,
--- "1" before WoD. The one definition Events' GetSpec defers to.
function GSE.CurrentSpecKey()
    if GSE.GameMode < 7 then return "1" end
    local getSpec = GSE.GameMode >= 12 and C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
        or GetSpecialization
    return tostring((getSpec and getSpec()) or 1)
end

--- The specID a spec key names for the current character, or nil when WoW has
--- not said yet (early in a login).
function GSE.SpecIDForKey(specKey)
    if GSE.GameMode < 7 then return GSE.GetCurrentClassID() end
    local index = tonumber(specKey)
    local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local specID = index and info and info(index)
    if type(specID) == "number" and specID > 0 then return specID end
    return nil
end

local function profiles()
    if type(GSEStore) ~= "table" or GSEStore.v == nil then GSE.LoadStore() end
    if type(GSEStore.profile) ~= "table" then GSEStore.profile = {} end
    return GSEStore.profile
end

--- The shared profile for one of the current character's specs (nil: the
--- current one). With create, made when missing. Nil while the spec is unknown.
function GSE.Profile(specKey, create)
    local classID = GSE.GetCurrentClassID()
    local specID = GSE.SpecIDForKey(specKey or GSE.CurrentSpecKey())
    if not classID or not specID then return nil end
    local root = profiles()
    local byClass = root[classID]
    if byClass == nil then
        if not create then return nil end
        byClass = {}
        root[classID] = byClass
    end
    local p = byClass[specID]
    if p == nil and create then
        p = {}
        byClass[specID] = p
    end
    return p
end

--- Does this character use the shared profile for a spec (it has not opted out)?
function GSE.UsesSharedProfile(specKey)
    specKey = tostring(specKey or GSE.CurrentSpecKey())
    return not (type(GSE_C) == "table" and type(GSE_C.ProfileOptOut) == "table" and GSE_C.ProfileOptOut[specKey])
end

local function charTable(path, create)
    if type(GSE_C) ~= "table" then
        if not create then return nil end
        GSE_C = {}
    end
    local t = GSE_C
    for _, k in ipairs(path) do
        if type(t[k]) ~= "table" then
            if not create then return nil end
            t[k] = {}
        end
        t = t[k]
    end
    return t
end

--- The spec-level keybinds in force for a spec: { [physicalKey] = sequenceId }
--- -- the shared profile's, or the character's own when it has opted out (that
--- table also holds the LoadOuts layer; loops skip it). With create, made.
function GSE.SpecKeyBinds(specKey, create)
    specKey = tostring(specKey or GSE.CurrentSpecKey())
    if GSE.UsesSharedProfile(specKey) then
        local p = GSE.Profile(specKey, create)
        if not p then return nil end
        if type(p.KeyBindings) ~= "table" then
            if not create then return nil end
            p.KeyBindings = {}
        end
        return p.KeyBindings
    end
    return charTable({ "KeyBindings", specKey }, create)
end

--- The loadout keybinds for a spec, always the character's own:
--- { [loadoutKey] = { [physicalKey] = sequenceId } }.
function GSE.SpecLoadoutKeyBinds(specKey, create)
    return charTable({ "KeyBindings", tostring(specKey or GSE.CurrentSpecKey()), "LoadOuts" }, create)
end

--- The spec-level action-bar overrides in force for a spec:
--- { [buttonKey] = { Bind, State, Sequence } } -- shared or the character's own.
function GSE.SpecOverrides(specKey, create)
    specKey = tostring(specKey or GSE.CurrentSpecKey())
    if GSE.UsesSharedProfile(specKey) then
        local p = GSE.Profile(specKey, create)
        if not p then return nil end
        if type(p.ActionBarBinds) ~= "table" then
            if not create then return nil end
            p.ActionBarBinds = {}
        end
        return p.ActionBarBinds
    end
    return charTable({ "ActionBarBinds", "Specialisations", specKey }, create)
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

local function specLevel(binds)
    local out = {}
    for k, v in pairs(type(binds) == "table" and binds or {}) do
        if k ~= "LoadOuts" then out[k] = v end
    end
    return out
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Drop a character's own spec-level binds and overrides, keeping its loadouts.
local function clearOwn(specKey)
    local own = charTable({ "KeyBindings", specKey }, false)
    if own then
        for k in pairs(specLevel(own)) do own[k] = nil end
    end
    local specs = charTable({ "ActionBarBinds", "Specialisations" }, false)
    if specs then specs[specKey] = nil end
end

--- Use (true) or leave (false) the shared profile for a spec. Leaving starts
--- the character's own binds and overrides as a copy of the profile's;
--- rejoining drops them for the profile's.
function GSE.SetSharedProfile(specKey, shared)
    specKey = tostring(specKey or GSE.CurrentSpecKey())
    if shared then
        if type(GSE_C) == "table" and type(GSE_C.ProfileOptOut) == "table" then
            GSE_C.ProfileOptOut[specKey] = nil
        end
        clearOwn(specKey)
        return
    end
    if not GSE.UsesSharedProfile(specKey) then return end
    local p = GSE.Profile(specKey, false) or {}
    local own = charTable({ "KeyBindings", specKey }, true)
    for k, v in pairs(p.KeyBindings or {}) do own[k] = v end
    local overrides = charTable({ "ActionBarBinds", "Specialisations", specKey }, true)
    for k, v in pairs(p.ActionBarBinds or {}) do overrides[k] = copy(v) end
    charTable({ "ProfileOptOut" }, true)[specKey] = true
end

--- Move this character's spec-level binds and overrides into the shared
--- profiles, once. For each spec: the first character seeds the profile; one
--- whose binds match it just uses it; one whose binds differ keeps them and is
--- opted out -- nothing is lost. Waits (returns false) until WoW can say which
--- spec each key is, and again for any spec it cannot place yet.
function GSE.MigrateToProfiles()
    if type(GSE_C) ~= "table" then return true end
    GSE_C.Updates = GSE_C.Updates or {}
    if GSE_C.Updates.profiles then return true end
    if not GSE.GetCurrentClassID() then return false end
    local keys = {}
    for k in pairs(type(GSE_C.KeyBindings) == "table" and GSE_C.KeyBindings or {}) do keys[tostring(k)] = true end
    local ab = type(GSE_C.ActionBarBinds) == "table" and GSE_C.ActionBarBinds or {}
    for k in pairs(type(ab.Specialisations) == "table" and ab.Specialisations or {}) do keys[tostring(k)] = true end
    for specKey in pairs(keys) do
        if not GSE.SpecIDForKey(specKey) then return false end
    end
    for specKey in pairs(keys) do
        local binds = specLevel(charTable({ "KeyBindings", specKey }, false))
        local overrides = copy(charTable({ "ActionBarBinds", "Specialisations", specKey }, false) or {})
        if next(binds) or next(overrides) then
            local p = GSE.Profile(specKey, true)
            local seeded = type(p.KeyBindings) == "table" or type(p.ActionBarBinds) == "table"
            if not seeded then
                p.KeyBindings, p.ActionBarBinds = binds, overrides
                clearOwn(specKey)
            elseif same(binds, p.KeyBindings or {}) and same(overrides, p.ActionBarBinds or {}) then
                clearOwn(specKey)
            else
                charTable({ "ProfileOptOut" }, true)[specKey] = true
            end
        end
    end
    GSE_C.Updates.profiles = true
    return true
end

--- Follow sequences that moved (GSEStore.alias) in every profile, as
--- UpdateCharacterSequenceRefs does for the character's own binds.
function GSE.UpdateProfileSequenceRefs()
    for _, byClass in pairs(profiles()) do
        for _, p in pairs(type(byClass) == "table" and byClass or {}) do
            for key, id in pairs(type(p.KeyBindings) == "table" and p.KeyBindings or {}) do
                if type(id) == "string" then p.KeyBindings[key] = GSE.ResolveSequenceId(id) or id end
            end
            for _, bind in pairs(type(p.ActionBarBinds) == "table" and p.ActionBarBinds or {}) do
                if type(bind) == "table" and type(bind.Sequence) == "string" then
                    bind.Sequence = GSE.ResolveSequenceId(bind.Sequence) or bind.Sequence
                end
            end
        end
    end
end

-- ── Settings ────────────────────────────────────────────────────────────────
--
-- The SETTINGS keys are not kept in GSEOptions itself: their account-wide
-- values live in GSEOptions.ProfileDefaults, and a metatable answers
-- GSEOptions.<key> with the current profile's value, else the account-wide
-- one, and stores a write in the current profile. So every existing reader and
-- writer of GSEOptions.<key> follows the spec being played without changing.
-- A table value (MacroResetModifiers, SkyRidingBinds) is copied into the
-- profile the first time it is read there, so editing it never edits the
-- account-wide one. Before the spec is known everything is account-wide.

local function deepCopy(v)
    return copy(v)
end

--- Install the profile layer on GSEOptions. Idempotent; run again whenever
--- GSEOptions is replaced.
function GSE.InstallProfileSettings()
    if type(GSEOptions) ~= "table" then return end
    local defaults = rawget(GSEOptions, "ProfileDefaults")
    if type(defaults) ~= "table" then
        defaults = {}
        rawset(GSEOptions, "ProfileDefaults", defaults)
    end
    for k in pairs(SETTINGS) do
        local v = rawget(GSEOptions, k)
        if v ~= nil then
            if defaults[k] == nil then defaults[k] = v end
            rawset(GSEOptions, k, nil)
        end
    end
    setmetatable(GSEOptions, {
        __index = function(t, k)
            if not SETTINGS[k] then return nil end
            local d = rawget(t, "ProfileDefaults") or {}
            local p = GSE.Profile(nil, false)
            local s = p and p.Settings
            if s and s[k] ~= nil then return s[k] end
            if type(d[k]) == "table" then
                p = GSE.Profile(nil, true)
                if p then
                    p.Settings = p.Settings or {}
                    p.Settings[k] = deepCopy(d[k])
                    return p.Settings[k]
                end
            end
            return d[k]
        end,
        __newindex = function(t, k, v)
            if not SETTINGS[k] then rawset(t, k, v); return end
            local p = GSE.Profile(nil, true)
            if p then
                p.Settings = p.Settings or {}
                p.Settings[k] = v
            else
                local d = rawget(t, "ProfileDefaults")
                if type(d) ~= "table" then d = {}; rawset(t, "ProfileDefaults", d) end
                d[k] = v
            end
        end,
    })
end

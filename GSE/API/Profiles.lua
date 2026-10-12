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
-- on every character of the class. Where binds are split by spec group rather
-- than specialisation, Primary's profile is the class's (specID = classID, or
-- the one class-level specialisation) and Secondary's its own (SpecIDForKey).
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

-- What a character's binds are split by -- its "specs". Decided by what the
-- client can do, not its version:
--   * A client with dual spec: the active spec group, Primary or Secondary.
--     TBC Anniversary, Wrath through WoD, Era, MoP Classic and Forever. They
--     are what the player switches between, and the player knows what each
--     one is. Primary from the start, Secondary once the character has it:
--     the key must not change when dual spec is learned, or Primary's binds
--     would be left behind under a specialisation.
--   * Otherwise several specialisations per class (Retail): the
--     specialisation, by index.
--   * Otherwise one, "1".
-- A talent loadout's binds sit on top of its spec's (Retail's loadouts).
--
-- Dual spec is the client being able to switch spec groups:
-- C_SpecializationInfo.SetActiveSpecGroup, or the SetActiveTalentGroup global
-- older clients had (Blizzard's deprecation shims alias one to the other).
-- Retail has GetActiveSpecGroup and GetNumSpecGroups still, but no setter.
local function specInfoApi()
    return C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
end

local function hasSpecGroups()
    return (C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup or SetActiveTalentGroup) ~= nil
end

--- Whether this client has talent loadouts -- Retail. A dual-spec client has
--- none, whatever C_ClassTalents it carries (Forever's lists some).
function GSE.HasTalentLoadouts()
    return not hasSpecGroups() and C_ClassTalents ~= nil and C_ClassTalents.GetLastSelectedSavedConfigID ~= nil
end

local function specGroupCount()
    local api = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups or GetNumSpecGroups or GetNumTalentGroups
    return tonumber(api and api()) or 1
end

local function activeSpecGroup()
    local api = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup or GetActiveSpecGroup
        or GetActiveTalentGroup
    return tonumber(api and api()) or 1
end

local function specialisationCount()
    return tonumber(GetNumSpecializations and GetNumSpecializations()) or 0
end

--- The current spec's key in a character's binds (see above). The one
--- definition Events' GetSpec defers to.
function GSE.CurrentSpecKey()
    if hasSpecGroups() then return tostring(activeSpecGroup()) end
    if specialisationCount() > 1 then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        return tostring((getSpec and getSpec()) or 1)
    end
    return "1"
end

--- The specs a character's binds are kept by, in order, for the Bindings tree:
--- { { key, label, icon }, ... }.
function GSE.BindingSpecs()
    local specs = {}
    local info = specInfoApi()
    local classID = GSE.GetCurrentClassID()
    local classIcon = classID and GSE.GetClassIcon and GSE.GetClassIcon(classID)
    if hasSpecGroups() then
        local groups = math.max(1, specGroupCount())
        local names = { _G.TALENT_SPEC_PRIMARY or "Primary", _G.TALENT_SPEC_SECONDARY or "Secondary" }
        for g = 1, groups do
            -- The group's specialisation's icon where it has one (Cata to WoD).
            local index = GetSpecialization and GetSpecialization(false, false, g)
            local icon = index and info and select(4, info(index))
            specs[#specs + 1] = { key = tostring(g), label = names[g] or tostring(g), icon = icon or classIcon }
        end
        return specs
    end
    if specialisationCount() > 1 and info then
        for i = 1, specialisationCount() do
            local _, name, _, icon = info(i)
            specs[#specs + 1] = { key = tostring(i), label = name, icon = icon }
        end
        return specs
    end
    local className = classID and GetClassInfo and GetClassInfo(classID)
    specs[1] = { key = "1", label = className or "", icon = classIcon }
    return specs
end

--- The specID a spec key names for the current character, or nil when WoW has
--- not said yet (early in a login). A shared profile is kept by it.
---
--- By spec group, Primary keeps the id the class's profile always had, so
--- nothing moves: the class where it has several specialisations or none, the
--- one class-level specialisation where that is all there is (Forever).
--- Another group gets one of its own, and starts empty.
function GSE.SpecIDForKey(specKey)
    local info = specInfoApi()
    if not hasSpecGroups() and specialisationCount() > 1 then
        local index = tonumber(specKey)
        local specID = index and info and info(index)
        if type(specID) == "number" and specID > 0 then return specID end
        return nil
    end
    local base
    if specialisationCount() == 1 then
        local specID = info and info(1)
        base = (type(specID) == "number" and specID > 0) and specID or nil
    else
        base = GSE.GetCurrentClassID()
    end
    if not base then return nil end
    local group = tonumber(specKey) or 1
    return group <= 1 and base or (tostring(base) .. ":" .. group)
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

--- The saved talent loadout whose binds sit on top of the current spec's, as
--- the loadout tables key it, or nil -- no saved loadout, which is every
--- client but Retail.
function GSE.ActiveBindingLoadout()
    if not GSE.HasTalentLoadouts() then return nil end
    local key = GSE.GetBindingLoadoutKey and GSE.GetBindingLoadoutKey()
    if key == nil or key == "nil" then return nil end
    return tostring(key)
end

--- A talent loadout's action-bar overrides for a spec, always the character's
--- own: { [buttonKey] = { Bind, State, Sequence } }.
function GSE.SpecLoadoutOverrides(specKey, loadout, create)
    if not loadout then return nil end
    return charTable({ "ActionBarBinds", "LoadOuts", tostring(specKey or GSE.CurrentSpecKey()), tostring(loadout) },
        create)
end

-- The keys in an override table that put something on buttonName (a key is
-- the button's name, or name-state for a state).
local function overrideKeysFor(t, buttonName)
    local keys = {}
    for k, v in pairs(t or {}) do
        if k == buttonName or (type(v) == "table" and v.Bind == buttonName) then keys[#keys + 1] = k end
    end
    return keys
end

--- Which layer puts an override on buttonName for the current spec:
--- "loadout" (the active talent loadout's, applied last so it wins), "spec",
--- or nil.
function GSE.OverrideLayerFor(buttonName)
    local spec = GSE.CurrentSpecKey()
    if #overrideKeysFor(GSE.SpecLoadoutOverrides(spec, GSE.ActiveBindingLoadout(), false), buttonName) > 0 then
        return "loadout"
    end
    if #overrideKeysFor(GSE.SpecOverrides(spec, false), buttonName) > 0 then return "spec" end
    return nil
end

--- Put a sequence on buttonName for the current spec. layer "loadout" keeps it
--- to the active talent loadout; anything else is the spec's, for every
--- loadout -- and then the active loadout's own entry for the button goes, or
--- it would go on hiding the change.
function GSE.SetOverrideData(buttonName, sequenceId, layer)
    local spec, loadout = GSE.CurrentSpecKey(), GSE.ActiveBindingLoadout()
    local bind = { Bind = buttonName, Sequence = sequenceId }
    if layer == "loadout" and loadout then
        GSE.SpecLoadoutOverrides(spec, loadout, true)[buttonName] = bind
        return "loadout"
    end
    GSE.SpecOverrides(spec, true)[buttonName] = bind
    local own = GSE.SpecLoadoutOverrides(spec, loadout, false)
    for _, k in ipairs(overrideKeysFor(own, buttonName)) do own[k] = nil end
    return "spec"
end

--- Take buttonName's override off the layer that applies it, and only that
--- one: clearing a loadout's lets the spec's show again, and clearing the
--- spec's leaves every loadout's alone. Returns the layer cleared.
function GSE.ClearOverrideData(buttonName)
    local layer = GSE.OverrideLayerFor(buttonName)
    local spec = GSE.CurrentSpecKey()
    local t = layer == "loadout" and GSE.SpecLoadoutOverrides(spec, GSE.ActiveBindingLoadout(), false)
        or layer == "spec" and GSE.SpecOverrides(spec, false)
    for _, k in ipairs(overrideKeysFor(t, buttonName)) do t[k] = nil end
    return layer
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

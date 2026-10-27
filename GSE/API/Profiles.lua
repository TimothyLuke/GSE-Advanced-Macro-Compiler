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

-- Ask each of these in turn; the first the client answers is the answer.
-- Having the function is not enough: Classic Era carries GetNumSpecGroups,
-- and calling it raises "API unsupported in this version of World of
-- Warcraft" -- its own talent frame counts groups with GetNumTalentGroups.
local function firstAnswer(candidates, ...)
    for i = 1, candidates.n do
        local api = candidates[i]
        if type(api) == "function" then
            local ok, value = pcall(api, ...)
            if ok then return value end
        end
    end
    return nil
end

local function specApis(...)
    return { n = select("#", ...), ... }
end

local function specGroupCount()
    local C = C_SpecializationInfo or {}
    return tonumber(firstAnswer(specApis(C.GetNumSpecGroups, GetNumTalentGroups, GetNumSpecGroups))) or 1
end

local function activeSpecGroup()
    local C = C_SpecializationInfo or {}
    return tonumber(firstAnswer(specApis(C.GetActiveSpecGroup, GetActiveSpecGroup, GetActiveTalentGroup))) or 1
end

local function specialisationIndex(...)
    local C = C_SpecializationInfo or {}
    return firstAnswer(specApis(C.GetSpecialization, GetSpecialization), ...)
end

local function specialisationCount()
    return tonumber(GetNumSpecializations and GetNumSpecializations()) or 0
end

--- The current spec's key in a character's binds (see above). The one
--- definition Events' GetSpec defers to.
function GSE.CurrentSpecKey()
    if hasSpecGroups() then return tostring(activeSpecGroup()) end
    if specialisationCount() > 1 then
        return tostring(specialisationIndex() or 1)
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
            local index = specialisationIndex(false, false, g)
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

--- The state a LibActionButton bar's button is in with no stance, form or
--- stealth: the one a Default row (no State) is saved for. Bartender4 counts
--- its states from 0, ConsolePort has none, NDui pages from 2, the rest from 1.
function GSE.LABDefaultState(buttonName)
    if string.sub(buttonName, 1, 3) == "BT4" then return "0" end
    if string.sub(buttonName, 1, 4) == "CPB_" then return "" end
    if string.sub(buttonName, 1, 5) == "NDui_" then return "2" end
    return "1"
end

-- ── What a bar's pages are for ──────────────────────────────────────────────
--
-- A LibActionButton bar pages by a driver of the bar addon's ("[bonusbar:3] 9;
-- [mod:shift] 5; 1"), and Bartender4, ElvUI and EllesmereUI let the player
-- choose the pages: Cat Form can be page 5 on one bar and 7 on another. The
-- Button Bindings name a state by the conditions its bar's driver gives it.
-- Display only: what runs in a state is the state attribute's business.

-- Each driver registered from now on. Bar addons set theirs up at login,
-- after GSE has loaded.
local pageDrivers = setmetatable({}, {__mode = "k"})
if hooksecurefunc and RegisterStateDriver then
    hooksecurefunc("RegisterStateDriver", function(frame, state, values)
        if state == "page" and type(frame) == "table" and type(values) == "string" then
            pageDrivers[frame] = values
        end
    end)
end

local function readPageDriver(frame)
    if pageDrivers[frame] then return pageDrivers[frame] end
    -- One set before GSE loaded: ElvUI keeps its bar's on the bar...
    local page = frame.GetAttribute and frame:GetAttribute("page")
    if type(page) == "string" and string.find(page, "[", 1, true) then return page end
    -- ...and Bartender4 builds its bar's again on request.
    if type(frame.GetStateOption) == "function" and type(frame.UpdateStates) == "function" then
        if not frame:GetStateOption("enabled") then return nil end
        if frame:GetStateOption("customEnabled") then return frame:GetStateOption("custom") end
        local driver = frame:UpdateStates(true)
        if type(driver) == "string" then return driver end
    end
end

--- The page driver of the bar a button is on, or nil.
function GSE.ButtonPageDriver(buttonName)
    local frame = buttonName and _G[buttonName]
    for _ = 1, 3 do
        frame = type(frame) == "table" and frame.GetParent and frame:GetParent()
        if not frame then return nil end
        local ok, driver = pcall(readPageDriver, frame)
        if ok and driver then return driver end
    end
end

-- The form, stance or stealth each bonus bar is for, by class.
local BONUS_BAR_SPELLS = {
    DRUID = { 768, 33891, 5487, 24858 }, -- Cat, Tree of Life, Bear, Moonkin
    ROGUE = { 1784, 51713 }, -- Stealth, Shadow Dance
    WARRIOR = { 2457, 71, 2458 }, -- Battle, Defensive, Berserker
    PRIEST = { 15473 }, -- Shadowform
    MONK = { 103985, 115069, 115070 }, -- Tiger, Ox, Serpent
    EVOKER = { 369536 }, -- Soar
}
local PROWL, STEALTH = 5215, 1784
local NOT_A_FORM = {
    overridebar = true, vehicleui = true, possessbar = true, shapeshift = true, petbattle = true,
}

local function spellName(spellID)
    local info = spellID and GSE.GetSpellInfo(spellID)
    return info and info.name
end

-- One [..] group of a driver as a name: "Bear Form", "Shift + Cat Form".
-- Nil for a vehicle, Skyriding or a page switched by hand.
local function describePageConditions(group, classfile)
    local bonus, form, stealth, modifier, target
    for raw in string.gmatch(group, "[^,]+") do
        local test = string.lower(raw:match("^%s*(.-)%s*$"))
        if NOT_A_FORM[test] or test:match("^bar:") then return nil end
        local n = tonumber(test:match("^bonusbar:(%d+)$"))
        if n then
            if n < 1 or n > 4 then return nil end
            bonus = n
        end
        n = tonumber(test:match("^form:(%d+)$") or test:match("^stance:(%d+)$"))
        if n then form = n end
        if test == "stealth" or test == "stealth:1" then stealth = true end
        local key = test:match("^mod:(%a+)$") or test:match("^modifier:(%a+)$")
        if key then modifier = _G[string.upper(key) .. "_KEY_TEXT"] or key end
        if test == "help" or test == "harm" then target = test end
    end

    local name
    if bonus and stealth and classfile == "DRUID" then
        name = spellName(PROWL)
    elseif bonus then
        name = spellName(BONUS_BAR_SPELLS[classfile] and BONUS_BAR_SPELLS[classfile][bonus])
    elseif form and GetShapeshiftFormInfo then
        name = spellName(select(4, GetShapeshiftFormInfo(form)))
    elseif stealth then
        name = spellName(classfile == "DRUID" and PROWL or STEALTH)
    end
    local parts = {}
    if modifier then parts[#parts + 1] = modifier end
    if name then parts[#parts + 1] = name end
    if target then parts[#parts + 1] = target == "help" and GSE.L["Friendly target"] or GSE.L["Hostile target"] end
    if #parts == 0 then return nil end
    return table.concat(parts, " + ")
end

--- What a driver puts on each page: { [page] = { name, ... } }, in its order,
--- and the page it gives when no condition holds (the bar's own).
function GSE.PageDriverNames(driver, classfile)
    local names, default = {}, nil
    for clause in string.gmatch(tostring(driver or "") .. ";", "([^;]*);") do
        local page = clause:match("(%d+)%s*$")
        if page and not string.find(clause, "[", 1, true) then default = default or page end
        if page then
            for group in string.gmatch(clause, "%[([^%]]*)%]") do
                local name = describePageConditions(group, classfile)
                if name then
                    names[page] = names[page] or {}
                    local seen = false
                    for _, have in ipairs(names[page]) do
                        if have == name then seen = true end
                    end
                    if not seen then table.insert(names[page], name) end
                end
            end
        end
    end
    return names, default
end

--- The page a bar addon's own driver has a button's bar on now, when that is
--- one it sends a form, stance, stealth or modifier to (1-10, not the bar's
--- own): EllesmereUI's, whose pages the player chooses. Nil otherwise.
function GSE.DriverStateForPage(buttonName, page)
    local driver = GSE.ButtonPageDriver(buttonName)
    if not (driver and page and page >= 1 and page <= 10) then return nil end
    local _, classfile = UnitClass("player")
    local names, default = GSE.PageDriverNames(driver, classfile)
    local key = tostring(page)
    if key ~= default and names[key] then return key end
    return nil
end

--- The action-bar overrides to put on for a spec, from its own rows and the
--- active talent loadout's: one per button and state, the loadout's replacing
--- the spec's for the same button and state. Returns them in the order to
--- apply -- every pinned state before any Default row -- and, per button, the
--- states its pinned rows hold: { [button] = { [state] = true } }. A Default
--- row takes every state of its button but those.
function GSE.OverridesToApply(specRows, loadoutRows)
    local byKey = {}
    local function add(t)
        for _, v in pairs(t or {}) do
            if type(v) == "table" and type(v.Bind) == "string" and v.Bind ~= "" then
                byKey[v.Bind .. (v.State ~= nil and ("\001" .. tostring(v.State)) or "")] = v
            end
        end
    end
    add(specRows)
    add(loadoutRows)
    local keys, pinned = {}, {}
    for k, v in pairs(byKey) do
        keys[#keys + 1] = k
        if v.State ~= nil then
            pinned[v.Bind] = pinned[v.Bind] or {}
            pinned[v.Bind][tostring(v.State)] = true
        end
    end
    table.sort(keys, function(a, b)
        local pa, pb = byKey[a].State ~= nil, byKey[b].State ~= nil
        if pa ~= pb then return pa end
        return a < b
    end)
    local rows = {}
    for i, k in ipairs(keys) do rows[i] = byKey[k] end
    return rows, pinned
end

--- The sequence an overridden button runs now: on a LibActionButton bar, the
--- one on the state it is in, as each form, stance or stealth can have its
--- own; else the button's.
function GSE.ButtonOverrideSequence(buttonName)
    local byState = GSE.ButtonOverrideStates and GSE.ButtonOverrideStates[buttonName]
    local button = byState and _G[buttonName]
    if button and button.GetAttribute then
        local st
        if GSE.OverrideStateFor then st = GSE.OverrideStateFor(button) else st = button:GetAttribute("state") end
        if st ~= nil and byState[tostring(st)] then return byState[tostring(st)] end
    end
    -- No row for this state: the Default row, where the button has one.
    if GSE.ButtonOverrideDefaults and not GSE.ButtonOverrideDefaults[buttonName] then return nil end
    return GSE.ButtonOverrides and GSE.ButtonOverrides[buttonName]
end

--- Whether an overridden button runs sequence in any of its states.
function GSE.ButtonRunsSequence(buttonName, sequence)
    if GSE.ButtonOverrides and GSE.ButtonOverrides[buttonName] == sequence then return true end
    for _, seq in pairs(GSE.ButtonOverrideStates and GSE.ButtonOverrideStates[buttonName] or {}) do
        if seq == sequence then return true end
    end
    return false
end

local function sameState(a, b)
    if a == nil or b == nil then return a == b end
    return tostring(a) == tostring(b)
end

-- The keys in an override table that put something on buttonName for state
-- (nil: its Default row). A key is the button's name, or name-state for a
-- state.
local function overrideKeysFor(t, buttonName, state)
    local keys = {}
    for k, v in pairs(t or {}) do
        local row = type(v) == "table" and v or nil
        if ((row and row.Bind) or k) == buttonName and sameState(row and row.State, state) then
            keys[#keys + 1] = k
        end
    end
    return keys
end

--- Which layer puts the override on buttonName that runs in state (nil: no
--- stance, form or stealth) for the current spec: "loadout" (the active
--- talent loadout's, applied last so it wins), "spec", or nil. A row pinned
--- to the state runs there, else the button's Default row, so the second
--- return is the state the row is saved for (nil: the Default row).
function GSE.OverrideLayerFor(buttonName, state)
    local spec = GSE.CurrentSpecKey()
    local layers = {
        { "loadout", GSE.SpecLoadoutOverrides(spec, GSE.ActiveBindingLoadout(), false) },
        { "spec", GSE.SpecOverrides(spec, false) },
    }
    local tries = state ~= nil and { tostring(state), false } or { false }
    for _, try in ipairs(tries) do
        local st = try or nil
        for _, l in ipairs(layers) do
            if #overrideKeysFor(l[2], buttonName, st) > 0 then return l[1], st end
        end
    end
    return nil
end

--- Put a sequence on buttonName for the current spec, in state (a stance,
--- form or stealth; nil: the Default row). layer "loadout" keeps it to the
--- active talent loadout; anything else is the spec's, for every loadout --
--- and then the active loadout's own row for the button and state goes, or it
--- would go on hiding the change.
function GSE.SetOverrideData(buttonName, sequenceId, layer, state)
    local spec, loadout = GSE.CurrentSpecKey(), GSE.ActiveBindingLoadout()
    if state ~= nil then state = tostring(state) end
    local key = state and (buttonName .. "-" .. state) or buttonName
    local bind = { Bind = buttonName, State = state, Sequence = sequenceId }
    local function put(t)
        for _, k in ipairs(overrideKeysFor(t, buttonName, state)) do t[k] = nil end
        t[key] = bind
    end
    if layer == "loadout" and loadout then
        put(GSE.SpecLoadoutOverrides(spec, loadout, true))
        return "loadout"
    end
    put(GSE.SpecOverrides(spec, true))
    local own = GSE.SpecLoadoutOverrides(spec, loadout, false)
    for _, k in ipairs(overrideKeysFor(own, buttonName, state)) do own[k] = nil end
    return "spec"
end

--- Take the override that runs on buttonName in state (nil: no stance, form
--- or stealth) off the layer that applies it, and only that row: clearing a
--- loadout's lets the spec's show again, clearing the spec's leaves every
--- loadout's alone, and other states' rows stay. Returns the layer cleared
--- and the state the cleared row was saved for.
function GSE.ClearOverrideData(buttonName, state)
    local layer, st = GSE.OverrideLayerFor(buttonName, state)
    local spec = GSE.CurrentSpecKey()
    local t = layer == "loadout" and GSE.SpecLoadoutOverrides(spec, GSE.ActiveBindingLoadout(), false)
        or layer == "spec" and GSE.SpecOverrides(spec, false)
    for _, k in ipairs(overrideKeysFor(t, buttonName, st)) do t[k] = nil end
    return layer, st
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

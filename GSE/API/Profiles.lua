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
-- than specialisation (a dual-spec client), it is the group: 1 is Primary's
-- profile and 2 Secondary's (SpecIDForKey) -- profile[9][1] and profile[9][2]
-- for a Warlock.
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
    showActionBarWatermark = true, showActionBarLabel = true,
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
--- By spec group it is the group's number: 1 for Primary, 2 for Secondary.
--- No API is asked, so it is known from the first moment of a login (#2166).
function GSE.SpecIDForKey(specKey)
    local info = specInfoApi()
    if not hasSpecGroups() and specialisationCount() > 1 then
        local index = tonumber(specKey)
        local specID = index and info and info(index)
        if type(specID) == "number" and specID > 0 then return specID end
        return nil
    end
    return math.max(1, math.floor(tonumber(specKey) or 1))
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

-- A bind's key is a string ("5", "F"). One stored as a number ([5] beside
-- ["F"] in a 3.3.36 report; how it got there is not known) broke the editor's
-- key sort and would never bind. Kept under its string, unless that is taken.
local function stringKeys(binds)
    if type(binds) ~= "table" then return end
    local numbers = {}
    for k in pairs(binds) do
        if type(k) == "number" then numbers[#numbers + 1] = k end
    end
    for _, k in ipairs(numbers) do
        local s = tostring(k)
        if binds[s] == nil then binds[s] = binds[k] end
        binds[k] = nil
    end
end

--- Every stored keybind's key as a string: this character's spec and loadout
--- binds, and every shared profile's.
function GSE.RepairBindKeys()
    local own = type(GSE_C) == "table" and type(GSE_C.KeyBindings) == "table" and GSE_C.KeyBindings or {}
    for _, spec in pairs(own) do
        stringKeys(spec)
        local loadouts = type(spec) == "table" and spec.LoadOuts or nil
        for _, binds in pairs(type(loadouts) == "table" and loadouts or {}) do stringKeys(binds) end
    end
    for _, byClass in pairs(profiles()) do
        for _, p in pairs(type(byClass) == "table" and byClass or {}) do
            stringKeys(type(p) == "table" and p.KeyBindings or nil)
        end
    end
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

--- The current spec's saved talent loadouts, in the order WoW lists them:
--- { { id = "123", name = "Raid" }, ... }, id as the loadout tables key it.
--- None on a client without them.
function GSE.BindingLoadouts()
    local out = {}
    if not (GSE.HasTalentLoadouts() and C_ClassTalents.GetConfigIDsBySpecID) then return out end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, GSE.GetCurrentSpecID())
    for _, id in ipairs(ok and ids or {}) do
        local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(id)
        out[#out + 1] = { id = tostring(id), name = (info and info.name) or tostring(id) }
    end
    return out
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
--- An ElvUI bar's is its own page, the bar's number: bar 3 sits in state 3, so
--- with "1" a sequence put on it was saved for a State of its own that no
--- list named, and not as the bar's Default.
function GSE.LABDefaultState(buttonName)
    if string.sub(buttonName, 1, 3) == "BT4" then return "0" end
    if string.sub(buttonName, 1, 4) == "CPB_" then return "" end
    if string.sub(buttonName, 1, 5) == "NDui_" then return "2" end
    return string.match(buttonName, "^ElvUI_Bar(%d+)Button%d+$") or "1"
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
    -- And each one taken off again (DaylightUI, a bar 2-8 whose paging the
    -- player removed): the bar is on one page from then on.
    if UnregisterStateDriver then
        hooksecurefunc("UnregisterStateDriver", function(frame, state)
            if state == "page" and type(frame) == "table" then pageDrivers[frame] = nil end
        end)
    end
end

-- DaylightUI registers its bars' drivers while it loads, before GSE is there
-- to see them, and keeps the rule nowhere on the bar. Its action bar module
-- builds the rule on request, the same function it registers from: bar 1's
-- (forms by [form:N] for a druid and a priest, Moonkin Form and Shadowform
-- among them), and a bar 2-8's where the player set one. A rule registered
-- since GSE loaded was seen above, and is the one in use. Nil for any other
-- button, a bar on one page, and a DaylightUI that cannot be asked.
local function daylightUIPageRule(buttonName)
    local num = GSE.DaylightUIBar and GSE.DaylightUIBar(buttonName)
    local DUI = num and _G.DaylightUI
    local mod = type(DUI) == "table" and type(DUI.GetModule) == "function" and DUI:GetModule("ActionBars")
    local ns = type(mod) == "table" and mod.enabled and mod.ns
    local bars, paging = type(ns) == "table" and ns.Bars, type(ns) == "table" and ns.Paging
    if type(bars) ~= "table" or type(paging) ~= "table" or type(bars.DEFS) ~= "table" then return nil end
    for _, def in ipairs(bars.DEFS) do
        if def.num == num then
            local holder = type(bars.holders) == "table" and bars.holders[def.key]
            if holder and pageDrivers[holder] then return pageDrivers[holder] end
            local rule
            if def.key == "main" then rule = paging.Rule() else rule = paging.BarRule(def) end
            if type(rule) ~= "string" then return nil end
            if holder then pageDrivers[holder] = rule end
            return rule
        end
    end
end

local function readPageDriver(frame)
    if pageDrivers[frame] then return pageDrivers[frame] end
    -- EllesmereUI registers its bars' through a RegisterStateDriver it took
    -- before GSE loaded, which the hook above never sees. It keeps the
    -- conditions on the bar, as they are now (false: a bar on one page).
    if type(frame._eabPagingConds) == "string" then return frame._eabPagingConds end
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
    local asked, rule = pcall(daylightUIPageRule, buttonName)
    if asked and rule then return rule end
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

-- Whether bonus bar n comes up for a class on this client (set below, with
-- the pages they come up on).
local clientBonusBar

-- One [..] group of a driver as a name: "Bear Form", "Shift + Cat Form".
-- Nil for a vehicle, Skyriding or a page switched by hand -- and, with
-- onlyClientBars, for a bonus bar the class has none of on this client.
local function describePageConditions(group, classfile, onlyClientBars)
    local bonus, form, stealth, modifier, target
    for raw in string.gmatch(group, "[^,]+") do
        local test = string.lower(raw:match("^%s*(.-)%s*$"))
        if NOT_A_FORM[test] or test:match("^bar:") then return nil end
        local n = tonumber(test:match("^bonusbar:(%d+)$"))
        if n then
            if n < 1 or n > 4 then return nil end
            if onlyClientBars and not clientBonusBar(classfile, n) then return nil end
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
    if (bonus or form) and stealth and classfile == "DRUID" then
        name = spellName(PROWL)
    elseif bonus then
        name = spellName(BONUS_BAR_SPELLS[classfile] and BONUS_BAR_SPELLS[classfile][bonus])
    elseif form and GetShapeshiftFormInfo then
        name = spellName(select(4, GetShapeshiftFormInfo(form)))
        -- A priest's Shadowform is form 1 to a macro condition and has no
        -- place on the stance bar to be named from (DaylightUI pages by it).
        if not name and form == 1 and classfile == "PRIEST" then name = spellName(BONUS_BAR_SPELLS.PRIEST[1]) end
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
--- onlyClientBars: leave out a page the driver sends a bonus bar to that the
--- class has none of on this client. EllesmereUI on WoW Forever sends all
--- four for every class, and a form that brings up no bar is no State to
--- choose (Moonkin Form and Shadowform there).
function GSE.PageDriverNames(driver, classfile, onlyClientBars)
    local names, default = {}, nil
    for clause in string.gmatch(tostring(driver or "") .. ";", "([^;]*);") do
        -- DaylightUI tags a page with the form or page under it ("13:f1").
        local page = clause:match("(%d+):?%w*%s*$")
        if page and not string.find(clause, "[", 1, true) then default = default or page end
        if page then
            for group in string.gmatch(clause, "%[([^%]]*)%]") do
                local name = describePageConditions(group, classfile, onlyClientBars)
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
    local names, default = GSE.PageDriverNames(driver, classfile, true)
    local key = tostring(page)
    if key ~= default and names[key] then return key end
    return nil
end

-- A LibActionButton button's states; Blizzard's main bar's and Dominos'
-- stance, form and stealth pages (7-10); and the state a row is saved for
-- (saved), so it is never lost from the list.
local BONUS_PAGES = {"7", "8", "9", "10"}
-- The form, stance or stealth that puts a class on each of those pages
-- (6 + its bonus bar, SpellShapeshiftForm.BonusActionBar). Soar brings up the
-- Skyriding bar (11), so it names no page.
-- A spell this client doesn't have names nothing; the page shows its number.
local FORM_PAGES = {
    DRUID = {["7"] = 768, ["9"] = 5487},
    ROGUE = {["7"] = 1784},
}
-- Only a form that brings up a bar on this client is a State to choose
-- (Larry, 2026-11-20). Tree of Life has one in The Burning Crusade and none
-- from Mists of Pandaria on (Wrath and Cataclysm are left as they were, named);
-- Moonkin Form has one from The Burning Crusade on, but not on WoW Forever;
-- Shadow Dance from Wrath of the Lich King to Mists of Pandaria.
if GSE.GameMode < 5 then FORM_PAGES.DRUID["8"] = 33891 end
if GSE.GameMode >= 2 and not GSE.IsForever then FORM_PAGES.DRUID["10"] = 24858 end
if GSE.GameMode >= 3 and GSE.GameMode <= 5 then FORM_PAGES.ROGUE["8"] = 51713 end
-- Warriors' stances page the bar up to Cataclysm, and on WoW Forever; from
-- Mists of Pandaria on they leave it where it is.
if GSE.GameMode < 5 or GSE.IsForever then
    FORM_PAGES.WARRIOR = {["7"] = 2457, ["8"] = 71, ["9"] = 2458}
end
-- Shadowform has a bar of its own from The Burning Crusade to Mists of
-- Pandaria; on Classic Era, WoW Forever and Retail it leaves the bar where it
-- is. A monk's stances have theirs in Mists of Pandaria, the one client with
-- them. Unnamed, those bars were no State to choose, and a Default row stays
-- off them.
if GSE.GameMode >= 2 and GSE.GameMode <= 5 then
    FORM_PAGES.PRIEST = {["7"] = 15473}
end
if GSE.GameMode == 5 then
    FORM_PAGES.MONK = {["7"] = 103985, ["8"] = 115069, ["9"] = 115070}
end
-- A warrior where stances turn the bar, and a monk, is never out of a stance:
-- the bar they play on is always a stance bar. Their stance pages, or nil for
-- every other class and client.
local ALWAYS_IN_STANCE = { WARRIOR = true, MONK = true }
local function alwaysStancePages()
    local classfile = GetClassInfo and select(2, GetClassInfo(GSE.GetCurrentClassID()))
    return classfile and ALWAYS_IN_STANCE[classfile] and FORM_PAGES[classfile] or nil
end
clientBonusBar = function(classfile, n)
    local pages = classfile and FORM_PAGES[classfile]
    return pages ~= nil and pages[tostring(6 + n)] ~= nil
end
-- A button's states by name, "Cat Form / Prowl", the page number left out
-- (Larry, 2026-11-20: "show just Stealth, hide the page number"): from its bar's page
-- driver (GSE.PageDriverNames), where the bar addon lets the player choose
-- the pages; Blizzard's main bar and Dominos by the pages above. A state
-- nothing names shows its number.
local function stateNamer(buttonName)
    local classfile = GetClassInfo and select(2, GetClassInfo(GSE.GetCurrentClassID()))
    -- Not Dominos' driver: it pages by states of its own ("[bonusbar:1]cat;
    -- base"), which name no page, and with it no page had a name. Its pages
    -- are counted as Blizzard's are (GSE.OverrideStatesFor).
    local frame = buttonName and _G[buttonName]
    local dominos = type(frame) == "table" and frame.SetShowGridInsecure ~= nil
    local driver = not dominos and GSE.ButtonPageDriver and GSE.ButtonPageDriver(buttonName)
    -- A LibActionButton bar's states are its own, each named as its driver
    -- has it; any other bar's are the pages a stance brings up here.
    local lab = type(frame) == "table" and frame.state_types ~= nil
    local names = driver and GSE.PageDriverNames(driver, classfile, not lab)
    return function(k)
        local name
        if names then
            name = names[k] and table.concat(names[k], " / ")
        elseif GSE.ButtonPagesWithForms and GSE.ButtonPagesWithForms(buttonName) then
            local spell = classfile and FORM_PAGES[classfile] and FORM_PAGES[classfile][k]
            local info = spell and GSE.GetSpellInfo(spell)
            name = info and info.name
        end
        return name or k
    end
end
-- The pages a stance, form, stealth or modifier turns a button's bar to, as
-- State keys ("7"), or nil for a bar that turns to none: a bar paging by its
-- own driver (EllesmereUI, DaylightUI), the pages it sends a form or modifier
-- to; Blizzard's main bar and Dominos, 7-10. Not a LibActionButton bar,
-- whose states are its own. The State choices and the Default row's stance
-- pages (GSE.ButtonStancePages) are both made from this.
local function statePages(buttonName, frame)
    if not (GSE.ButtonPagesWithForms and GSE.ButtonPagesWithForms(buttonName)) then return nil end
    local driver = frame.SetShowGridInsecure == nil and GSE.ButtonPageDriver(buttonName)
    if not driver then return BONUS_PAGES end
    local _, classfile = UnitClass("player")
    local names, default = GSE.PageDriverNames(driver, classfile, true)
    local pages = {}
    for page = 1, 10 do
        local key = tostring(page)
        if key ~= default and names[key] then pages[#pages + 1] = key end
    end
    return pages
end
--- A button's states to put a sequence on: { [state] = label }, and the
--- states in order, Default first -- or nil when it has only the one. The
--- Button Bindings' State column and the action buttons' right-click menu.
function GSE.OverrideStatesFor(buttonName, saved)
    local frame = buttonName and _G[buttonName]
    local states, order = {["Default"] = "Default"}, {"Default"}
    local stateLabel = stateNamer(buttonName)
    local function add(k)
        if k ~= nil and not states[k] then
            states[k] = stateLabel(k)
            table.insert(order, k)
        end
    end
    if frame and frame.state_types then
        local default = GSE.LABDefaultState(buttonName)
        for k in pairs(frame.state_types) do
            if k ~= default and k ~= buttonName then add(k) end
        end
    else
        for _, k in ipairs(frame and statePages(buttonName, frame) or {}) do add(k) end
    end
    add(saved)
    if #order == 1 then return nil end
    -- Default, then the pages by number, then any state named otherwise.
    table.sort(order, function(a, b)
        if a == "Default" or b == "Default" then return a == "Default" and b ~= "Default" end
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        if na or nb then return na ~= nil end
        return tostring(a) < tostring(b)
    end)
    return states, order
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

--- The pages a stance, form or stealth turns a button's bar to, where its
--- Default row stays off: { [page] = true }. The pages the button's State
--- choices are made from (statePages) -- and the one list for the button's
--- own click (gse-stance-<page>, Events.lua) and for what GSE shows on it, so
--- the two always agree -- but for the page the button is on in no stance: a
--- Dominos bar set on the bonus-bar slots is no stance bar. None on a
--- LibActionButton bar, which keeps the Default row in every state, or on a
--- bar GSE sees no paging of. Read on every sequence press (GSE.UpdateIcon):
--- no names are looked up here.
function GSE.ButtonStancePages(buttonName)
    local pages = {}
    local frame = buttonName and _G[buttonName]
    if type(frame) ~= "table" or frame.state_types or (frame.SetState and frame.SetShowGridInsecure == nil) then
        return pages
    end
    local base = frame.GetAttribute and tonumber(frame:GetAttribute("action-base"))
    local home = base and base > 0 and math.floor((base - 1) / 12) + 1
    for _, k in ipairs(statePages(buttonName, frame) or {}) do
        local page = tonumber(k)
        if page ~= home then pages[page] = true end
    end
    return pages, home
end

--- The sequence an overridden button runs now: the row pinned to the state
--- it is in, as each form, stance or stealth can have its own; else the
--- button's Default row. On a bar that turns to another one for a stance,
--- form or stealth (Blizzard's main bar, Dominos, a bar addon's own pages)
--- that bar is its own: with no row pinned there, nothing runs (Larry,
--- 2026-11-20; GSE.ButtonStancePages). A LibActionButton bar keeps the
--- Default row in every state without one, and the GSE Action Bar has no
--- states.
function GSE.ButtonOverrideSequence(buttonName)
    local byState = GSE.ButtonOverrideStates and GSE.ButtonOverrideStates[buttonName]
    local button = _G[buttonName]
    if type(button) == "table" and button.GetAttribute then
        local st
        if GSE.OverrideStateFor then st = GSE.OverrideStateFor(button) else st = button:GetAttribute("state") end
        if st ~= nil and byState and byState[tostring(st)] then return byState[tostring(st)] end
        if st ~= nil and GSE.OverrideStateFor and GSE.ButtonStancePages(buttonName)[tonumber(st)] then return nil end
    end
    -- No row for this state: the Default row, where the button has one.
    if GSE.ButtonOverrideDefaults and not GSE.ButtonOverrideDefaults[buttonName] then return nil end
    return GSE.ButtonOverrides and GSE.ButtonOverrides[buttonName]
end

-- ── A button by the action slot it is on ────────────────────────────────────
--
-- Each bar addon names its buttons its own way, and a row is saved under the
-- button's name: a sequence put on EllesmereUI's first button was gone from
-- the bars the day the player ran ElvUI, or DaylightUI, or no bar addon at
-- all (Larry, 2026-11-21: "the Sequence and Binds should stay"). What every
-- one of them agrees on is the action slot a button holds on its own page
-- (Blizzard's bars 1-8 are pages 1, 6, 5, 3, 4, 13, 14 and 15), and the
-- game's own key bindings go by the same bars. So a row saved for another bar
-- addon's button is moved to the button on that slot in the one running now.

local BAR_PAGES = { 1, 6, 5, 3, 4, 13, 14, 15 }
local BAR_OF_PAGE = {}
for bar, page in ipairs(BAR_PAGES) do BAR_OF_PAGE[page] = bar end
local BLIZZARD_BARS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

-- A bar addon whose buttons are named by bar and button. byBarOrder: its bars
-- 1-8 are Blizzard's, in Blizzard's order; otherwise bar n is page n.
local function barFamily(name, pattern, format, byBarOrder)
    return {
        name = name,
        slot = function(button)
            local bar, index = string.match(button, pattern)
            bar, index = tonumber(bar), tonumber(index)
            local page = bar
            if byBarOrder then page = bar and BAR_PAGES[bar] end
            if not page or not index or index < 1 or index > 12 then return nil end
            return (page - 1) * 12 + index
        end,
        button = function(slot)
            local page, index = math.floor((slot - 1) / 12) + 1, (slot - 1) % 12 + 1
            local bar = page
            if byBarOrder then bar = BAR_OF_PAGE[page] end
            return bar and string.format(format, bar, index) or nil
        end,
    }
end
-- A bar addon whose buttons are named by the slot itself.
local function slotFamily(name, prefix)
    return {
        name = name,
        slot = function(button) return tonumber(string.match(button, "^" .. prefix .. "(%d+)$")) end,
        button = function(slot) return prefix .. slot end,
    }
end
-- The bar addons that take the bars over, then Blizzard's own (Dominos keeps
-- Blizzard's names for these slots). ConsolePort's buttons go by the pad's
-- keys, Button Forge's and the GSE Action Bar's by nothing shared: their rows
-- stay where they are.
local BAR_FAMILIES = {
    slotFamily("EllesmereUI", "EABButton"),
    barFamily("DaylightUI", "^DaylightUIBar(%d+)Button(%d+)$", "DaylightUIBar%dButton%d", true),
    barFamily("ElvUI", "^ElvUI_Bar(%d+)Button(%d+)$", "ElvUI_Bar%dButton%d"),
    slotFamily("Bartender4", "BT4Button"),
    barFamily("NDui", "^NDui_ActionBar(%d+)Button(%d+)$", "NDui_ActionBar%dButton%d", true),
    {
        name = "Blizzard",
        slot = function(button)
            for bar, prefix in ipairs(BLIZZARD_BARS) do
                local index = tonumber(string.match(button, "^" .. prefix .. "(%d+)$"))
                if index and index >= 1 and index <= 12 then return (BAR_PAGES[bar] - 1) * 12 + index end
            end
        end,
        button = function(slot)
            local bar = BAR_OF_PAGE[math.floor((slot - 1) / 12) + 1]
            return bar and BLIZZARD_BARS[bar] .. ((slot - 1) % 12 + 1) or nil
        end,
    },
}

--- The bar addon a button name is of ("EllesmereUI", "ElvUI", "Blizzard"...)
--- and the action slot it holds on its own page, or nil for any other button.
function GSE.ButtonHomeSlot(buttonName)
    if type(buttonName) ~= "string" then return nil end
    for _, family in ipairs(BAR_FAMILIES) do
        local slot = family.slot(buttonName)
        if slot and slot >= 1 and slot <= 180 then return family.name, slot end
    end
end

-- The bar addon running the bars now: the first that has made a bar's first
-- button, else Blizzard's (and Dominos, on Blizzard's names).
local function activeBarFamily()
    for _, family in ipairs(BAR_FAMILIES) do
        for _, page in ipairs(BAR_PAGES) do
            local name = family.button((page - 1) * 12 + 1)
            if family.name == "Blizzard" or (name and type(_G[name]) == "table") then return family end
        end
    end
end

--- Move the rows saved for another bar addon's buttons to the buttons on the
--- same slots in the one running now: rows, a spec's or a loadout's. A row
--- keeps its State and everything else. One whose slot has no button here, or
--- whose button here already has a row for that State, is left as it is, for
--- the day its own bar addon is back. Returns how many were moved.
function GSE.MoveRowsToActiveBars(rows)
    if type(rows) ~= "table" then return 0 end
    local active = activeBarFamily()
    local moves = {}
    for key, row in pairs(rows) do
        if type(row) == "table" and type(row.Bind) == "string" then
            local family, slot = GSE.ButtonHomeSlot(row.Bind)
            local target = family and family ~= active.name and active.button(slot)
            if target and type(_G[target]) == "table" then
                moves[#moves + 1] = { key = key, row = row, target = target }
            end
        end
    end
    local moved = 0
    for _, move in ipairs(moves) do
        local state = move.row.State
        local key = move.target .. (state ~= nil and ("-" .. tostring(state)) or "")
        if rows[key] == nil then
            rows[move.key] = nil
            move.row.Bind = move.target
            rows[key] = move.row
            moved = moved + 1
        end
    end
    return moved
end

--- Put a spec's Default rows on the stances they ran in before a stance bar
--- became a bar of its own, once. Only for a class that is never out of a
--- stance (alwaysStancePages): its Default rows ran on every stance with no
--- row of its own, and would now never run at all. A row is marked
--- StancesCopied when it has been looked at -- one made after this is marked
--- as it is made (GSE.SetOverrideData) -- so a stance the player then unticks
--- stays unticked. A button that is not there yet waits for a login that has
--- it; a bar set on a stance's own slots (Dominos) never turns, and keeps its
--- Default row as it is. Returns how many rows were added.
function GSE.CopyDefaultRowsToStances(specKey)
    local stances = alwaysStancePages()
    local rows = stances and GSE.SpecOverrides(specKey, false)
    if type(rows) ~= "table" then return 0 end
    local defaults, has = {}, {}
    for _, row in pairs(rows) do
        if type(row) == "table" and type(row.Bind) == "string" then
            if row.State ~= nil then
                has[row.Bind .. "\001" .. tostring(row.State)] = true
            elseif not row.StancesCopied then
                defaults[#defaults + 1] = row
            end
        end
    end
    local added = 0
    for _, row in ipairs(defaults) do
        if type(_G[row.Bind]) == "table" then
            local pages, home = GSE.ButtonStancePages(row.Bind)
            if not (home and home >= 7 and home <= 10) then
                for key in pairs(stances) do
                    if pages[tonumber(key)] and not has[row.Bind .. "\001" .. key] then
                        rows[row.Bind .. "-" .. key] = { Bind = row.Bind, State = key, Sequence = row.Sequence }
                        added = added + 1
                    end
                end
            end
            row.StancesCopied = true
        end
    end
    return added
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
--- form or stealth; nil: the Default row). layer "loadout" keeps it to a
--- talent loadout -- loadout, or the active one when that is nil; anything
--- else is the spec's, for every loadout -- and then the active loadout's own
--- row for the button and state goes, or it would go on hiding the change.
function GSE.SetOverrideData(buttonName, sequenceId, layer, state, loadout)
    local spec, active = GSE.CurrentSpecKey(), GSE.ActiveBindingLoadout()
    loadout = GSE.HasTalentLoadouts() and loadout ~= nil and tostring(loadout) or active
    if state ~= nil then state = tostring(state) end
    local key = state and (buttonName .. "-" .. state) or buttonName
    local bind = { Bind = buttonName, State = state, Sequence = sequenceId }
    -- A Default row made from now on is as the player ticked it: not one for
    -- GSE.CopyDefaultRowsToStances to add stances to.
    if state == nil and alwaysStancePages() then bind.StancesCopied = true end
    local function put(t)
        for _, k in ipairs(overrideKeysFor(t, buttonName, state)) do t[k] = nil end
        t[key] = bind
    end
    if layer == "loadout" and loadout then
        put(GSE.SpecLoadoutOverrides(spec, loadout, true))
        return "loadout"
    end
    put(GSE.SpecOverrides(spec, true))
    local own = GSE.SpecLoadoutOverrides(spec, active, false)
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

-- What a profile holds, by part.
local PROFILE_PARTS = { "KeyBindings", "ActionBarBinds", "Settings" }

-- Two profiles for the same spec group as one: newer as it is, older filling
-- in what it lacks.
local function mergeProfiles(newer, older)
    if type(newer) ~= "table" then return type(older) == "table" and older or nil end
    if type(older) ~= "table" then return newer end
    local defaults = type(GSEOptions) == "table" and rawget(GSEOptions, "ProfileDefaults")
    for _, part in ipairs(PROFILE_PARTS) do
        if type(newer[part]) ~= "table" then
            newer[part] = older[part]
        else
            for k, v in pairs(type(older[part]) == "table" and older[part] or {}) do
                local mine = newer[part][k]
                -- A table setting is copied from the account's the first time
                -- it is read (InstallProfileSettings), so one still matching
                -- it was never chosen in the newer profile: the older's was.
                local unchosen = part == "Settings" and type(mine) == "table"
                    and type(defaults) == "table" and same(mine, defaults[k])
                if mine == nil or unchosen then newer[part][k] = v end
            end
        end
    end
    return newer
end

-- One class's profiles onto their spec groups. They were kept by the class
-- (9, and "9:2" for Secondary) and, on WoW Forever until 3.3.39, by the one
-- class-level specialisation the client reports (1490, "1490:2").
local function moveClassToSpecGroups(classID, byClass)
    -- Forever's old id: the number that is not the class. With more than one,
    -- the one the client names for the class, or none of them.
    local oldID, several
    if GSE.IsForever then
        for key in pairs(byClass) do
            local id = type(key) == "number" and key or tonumber(string.match(tostring(key), "^(%d+):%d+$"))
            if id and id ~= classID then
                if oldID and oldID ~= id then several = true end
                oldID = id
            end
        end
        if several then
            local forClass = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID
                or GetSpecializationInfoForClassID
            local ok, specID = pcall(function() return forClass and forClass(classID, 1) end)
            oldID = ok and type(specID) == "number" and specID ~= classID and byClass[specID] and specID or nil
        end
    end
    -- Every group's profile is worked out before any is put back: a Paladin's
    -- Primary sits at [2], where its Secondary goes.
    local groups, from = {}, {}
    local function take(key, group)
        if byClass[key] == nil then return end
        groups[group] = mergeProfiles(groups[group], byClass[key])
        from[#from + 1] = key
    end
    local function takeFor(id)
        take(id, 1)
        local keys = {}
        for key in pairs(byClass) do
            local group = type(key) == "string" and tonumber(string.match(key, "^" .. id .. ":(%d+)$"))
            if group then keys[key] = group end
        end
        for key, group in pairs(keys) do take(key, group) end
    end
    -- The class's first: what was set up since 3.3.39 stays as it is.
    takeFor(classID)
    if oldID then takeFor(oldID) end
    for _, key in ipairs(from) do byClass[key] = nil end
    for group, profile in pairs(groups) do byClass[group] = profile end
end

--- Once for the account (GSEOptions.Updates.profileSpecGroups, from
--- PerformOneOffEvents), wherever profiles are kept by spec group -- every
--- client but Retail, whose profiles are by specialisation: every class's profiles onto
--- their spec groups, 1 for Primary and 2 for Secondary (#2225). The profiles
--- are shared by every character, so the one pass does every class, whoever
--- logs in first.
---
--- This is also what brings back the keybinds, action bar overrides and
--- settings WoW Forever lost in 3.3.39, which changed the id Primary was kept
--- by (1490 to 9 for a Warlock) and left the saved profiles behind: both are
--- read here, and anything set up again since wins.
---
--- Not to be run twice: after it a Paladin's [2] is its Secondary, not its
--- Primary. Returns whether it ran.
function GSE.MoveProfilesToSpecGroups()
    -- As SpecIDForKey decides it.
    if not hasSpecGroups() and specialisationCount() > 1 then return false end
    for classID, byClass in pairs(profiles()) do
        if type(classID) == "number" and type(byClass) == "table" then
            moveClassToSpecGroups(classID, byClass)
        end
    end
    return true
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
    -- The right-click sequence picker (actionBarOverridePopup) is account-wide
    -- and on unless turned off. It used to be a profile setting: an off kept in
    -- the account defaults or any profile stays off; the profile copies go.
    if rawget(GSEOptions, "actionBarOverridePopup") == nil then
        local on = true
        if defaults.actionBarOverridePopup == false then on = false end
        defaults.actionBarOverridePopup = nil
        for _, byClass in pairs(profiles()) do
            for _, p in pairs(type(byClass) == "table" and byClass or {}) do
                local s = type(p) == "table" and p.Settings
                if type(s) == "table" then
                    if s.actionBarOverridePopup == false then on = false end
                    s.actionBarOverridePopup = nil
                end
            end
        end
        rawset(GSEOptions, "actionBarOverridePopup", on)
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

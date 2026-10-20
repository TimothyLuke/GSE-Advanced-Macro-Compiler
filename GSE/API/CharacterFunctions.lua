local _, GSE = ...
local L = GSE.L

local Statics = GSE.Static

--- Return the characters current spec id
function GSE.GetCurrentSpecID()
    if GSE.GameMode <= 4 then
        return GSE.GetCurrentClassID() and GSE.GetCurrentClassID()
    else
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local currentSpec = getSpec and getSpec()
        if not currentSpec then
            return 0
        end

        local currentSpecID
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            currentSpecID = C_SpecializationInfo.GetSpecializationInfo(currentSpec)
        elseif GetSpecializationInfo then
            currentSpecID = GetSpecializationInfo(currentSpec)
        end
        return currentSpecID or 0
    end
end

-- WoW 12.0.5: UnitSpellHaste("player") returns a "secret number value" once combat
-- starts while execution is tainted by an addon. The call itself succeeds but any
-- arithmetic on the value throws. We cache the last known good haste out of combat
-- and fall back to it when the secret-taint path trips.
local lastKnownHaste = 0

--- Return the current GCD for the current character
function GSE.GetGCD()
    local haste = UnitSpellHaste("player")
    local ok, gcd = pcall(function() return 1.5 / (1 + 0.01 * haste) end)
    if ok then
        lastKnownHaste = haste
        return gcd
    end
    return 1.5 / (1 + 0.01 * lastKnownHaste)
end

--- Return the characters class id
function GSE.GetCurrentClassID()
    local _, _, currentclassId = UnitClass("player")
    return currentclassId
end

--- Return the characters class id
function GSE.GetCurrentClassNormalisedName()
    local _, classnormalisedname, _ = UnitClass("player")
    return classnormalisedname
end

function GSE.GetClassIDforSpec(specid)
    local classid = 0
    if GSE.GameMode < 5 then
        -- Pre-MoP classic: no specialisations exist. GetCurrentSpecID() already
        -- returns the class ID for these versions, so specid IS the class ID.
        return specid or 0
    else
        local _, _, _, _, _, class = GetSpecializationInfoByID(specid)
        if specid <= 13 then
            classid = specid
        elseif class then
            for i = 1, 13, 1 do
                local classInfo = C_CreatureInfo.GetClassInfo(i)
                local st = classInfo and classInfo.classFile
                if class == st then
                    classid = i
                end
            end
        end
        -- WoW Forever knows no retail spec id (66 is Protection Paladin there
        -- only through the talent-tree mapping in Statics.lua), so the client
        -- answers nothing and the sequence would be filed as Global.
        if classid == 0 then classid = GSE.SpecIDClassList[specid] or 0 end
    end
    return classid
end

--- A spec's icon: the client's own, else its talent tree's (WoW Forever has
--- trees but no spec record for a retail id), or nil.
function GSE.GetSpecIcon(specID)
    specID = tonumber(specID)
    if not specID or specID <= 13 then return nil end
    if GetSpecializationInfoByID then
        local id, _, _, icon = GetSpecializationInfoByID(specID)
        if id and icon then return icon end
    end
    local _ = Statics.SpecIDList[0] -- the trees are read when the list is built
    return Statics.SpecIDIconList[specID]
end

function GSE.GetClassIcon(classid)
    local classicon = {}
    classicon[1] = 626008 -- Warrior
    classicon[2] = 626003 -- Paladin
    classicon[3] = 626000 -- Hunter
    classicon[4] = 626005 -- Rogue
    classicon[5] = 626004 -- Priest
    classicon[6] = 135771 -- Death Knight
    classicon[7] = 626006 -- SWhaman
    classicon[8] = 626001 -- Mage
    classicon[9] = 626007 -- Warlock
    classicon[10] = 626002 -- Monk
    classicon[11] = 625999 -- Druid
    classicon[12] = 1260827 -- DEMONHUNTER
    classicon[13] = 4574311 --Evoker
    return classicon[classid]
end

Statics.Icons.Personal = GSE.GetClassIcon(GSE.GetCurrentClassID()) or Statics.Icons.Personal

--- Check if the specID provided matches the players current class
function GSE.isSpecIDForCurrentClass(specID)
    local _, _, _, _, _, _, specclass = GetSpecializationInfoByID(specID)
    local _, currentenglishclass, currentclassId = UnitClass("player")
    specclass = specclass or ""
    if specID > 15 then
        --@debug@
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " " .. specclass .. " equals " .. currentenglishclass)
        --@end-debug@
    else
        --@debug@
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " equals currentclassid " .. currentclassId)
        --@end-debug@
    end
    return (specclass == currentenglishclass or specID == currentclassId)
end

function GSE.GetSpecNames()
    local keyset = {}
    local _ = Statics.SpecIDList[0]  -- trigger lazy build before pairs() iteration
    for _, v in pairs(Statics.SpecIDList) do
        keyset[v] = v
    end
    return keyset
end

--- Returns the Character Name in the form Player@server
function GSE.GetCharacterName()
    return GetUnitName("player", true) .. "@" .. GetRealmName()
end

--- The one identity for "this character": the player GUID.
--
-- Every name-based recipe the Mod used broke somewhere. UnitFullName's second
-- return is the realm on retail but the SURNAME on WoW Forever ("Bob",
-- "Geldoff"), so Forever characters were filed as "Bob-Geldoff". Retail was
-- not consistent either: UnitFullName strips spaces from the realm and
-- GetRealmName does not, and the Mod used both, so a character on Argent Dawn
-- had two buckets. A GUID holds no name or realm, so none of that applies.
-- Nil until the player unit exists (it is not dependable at ADDON_LOADED).
function GSE.CharacterKey()
    local guid = UnitGUID and UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then return guid end
    return nil
end

--- Human-readable name for this character. Display only -- never a lookup
-- key. GetUnitName(..., true) is used because it returns Forever's full
-- two-part name, where UnitFullName splits it.
function GSE.CharacterLabel()
    local name = (GetUnitName and GetUnitName("player", true)) or (UnitName and UnitName("player")) or ""
    local realm = GetRealmName and GetRealmName() or ""
    if realm == "" then return name end
    return name .. "-" .. realm
end

-- A stored macro node, as opposed to a per-character bucket of them. Same
-- rule as Export.lua's isStoredMacroNode: iteration everywhere tells the two
-- apart by shape, never by key.
-- A macro in the current shape has Versions = { [1] = {...} }; a bucket that
-- happens to hold a macro named "Versions" holds a node there, not a list.
local function isMacroNode(t)
    return type(t) == "table" and (
        t.text ~= nil or t.value ~= nil or t.icon ~= nil or t.Managed ~= nil
        or t.managedMacro ~= nil or t.manageMacro ~= nil or t.GSEProtected ~= nil
        or (type(t.Versions) == "table" and type(t.Versions[1]) == "table"))
end
-- Shared with the store (Storage.lua), which has to make the same call when
-- it splits account macros from per-character buckets.
GSE.IsStoredMacroNode = isMacroNode

--- Every key an older build may have filed this character's macro bucket
-- under. Read by the migration below and nothing else; nothing writes these.
local function legacyCharacterKeys()
    local keys, seen = {}, {}
    local function add(k)
        if type(k) == "string" and k ~= "" and not seen[k] then seen[k] = true; keys[#keys + 1] = k end
    end
    local char, ufRealm
    if UnitFullName then char, ufRealm = UnitFullName("player") end
    local realm = GetRealmName and GetRealmName() or ""
    local stripped = string.gsub(realm, "%s*", "")
    if char then
        -- Storage / Export / MacroSync / the editors: UnitFullName's realm,
        -- falling back to the spaceless realm name when it is empty.
        add(char .. "-" .. (GSE.isEmpty(ufRealm) and stripped or ufRealm))
        -- Events.lua startup: first name plus GetRealmName, spaces kept.
        add(char .. "-" .. realm)
        add(char .. "-" .. stripped)
    end
    local full = GetUnitName and GetUnitName("player", true)
    if full then
        -- Earlier WoW Forever builds, where the name came back whole.
        add(full .. "-" .. realm)
        add(full .. "-" .. stripped)
    end
    return keys
end
GSE.LegacyCharacterKeys = legacyCharacterKeys

--- The key of this character's macro bucket in GSEMacros.
--
-- On first use after login, any bucket an older build filed under one of the
-- legacy keys is folded into the GUID-keyed one (entries already under the
-- GUID win) and the legacy key is removed, so the change orphans nothing. A
-- legacy key that holds a MACRO rather than a bucket is left alone: macro
-- names can contain hyphens, so "Bob-Geldoff" could be a user's macro. A GUID
-- cannot collide that way -- it is longer than WoW's 16-character macro name
-- limit.
--
-- Before the player GUID exists this returns the legacy key the storage path
-- has always used, so an early write still lands somewhere the next call
-- will migrate.
function GSE.CharacterMacroBucketKey()
    local key = GSE.CharacterKey()
    if not key then return legacyCharacterKeys()[1] end
    local macros = GSE.Store("macro")
    for _, old in ipairs(legacyCharacterKeys()) do
        local bucket = macros[old]
        if old ~= key and type(bucket) == "table" and not isMacroNode(bucket) then
            local target = macros[key]
            if type(target) ~= "table" then target = {}; macros[key] = target end
            for name, node in pairs(bucket) do
                if target[name] == nil then target[name] = node end
            end
            macros[old] = nil
        end
    end
    return key
end

--- This character's macro bucket, or nil. With create, it is made if absent.
function GSE.CharacterMacroBucket(create)
    local key = GSE.CharacterMacroBucketKey()
    if not key then return nil end
    local macros = GSE.Store("macro")
    if create and type(macros[key]) ~= "table" then macros[key] = {} end
    return macros[key]
end

--- Experimental attempt to load a WeakAuras string.
function GSE.LoadWeakAura(str)
    if C_AddOns.IsAddOnLoaded("WeakAuras") then
        WeakAuras.OpenOptions()
        WeakAuras.OpenOptions()
        WeakAuras.Import(str)
    else
        GSE.Print(L["WeakAuras was not found."])
    end
end

if not SaveBindings then
    function SaveBindings(p)
        AttemptToSaveBindings(p)
    end
end

--- This function clears the Shift+n and CTRL+x keybindings.
function GSE.ClearCommonKeyBinds()
    local combinators = {"SHIFT", "CTRL", "ALT"}
    local defaultbuttons = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="}
    for _, p in ipairs(combinators) do
        for _, v in ipairs(defaultbuttons) do
            SetBinding(p .. "-" .. v)
            --@debug@
            GSE.PrintDebugMessage("Cleared KeyCombination " .. p .. v)
            --@end-debug@
        end
        SetBinding(p)
    end
    -- GSE_C is SavedVariablesPerCharacter, so it needs no character key. This
    -- used to write KeyBindings["Char-Realm"][spec] -- the nesting update
    -- 3201 removed -- while every reader looks at KeyBindings[spec].
    GSE_C["KeyBindings"] = {}
    GSE_C["KeyBindings"][GSE.CurrentSpecKey()] = {}
    -- Save for this character
    SaveBindings(2)
    GSE.Print("Common Keybinding combinations cleared for this character.")
end

--- Obtain the Click Rate from GSE Options or from the characters internal options
function GSE.GetClickRate()
    local clickRate = GSEOptions.msClickRate and GSEOptions.msClickRate or 250
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if not GSE.isEmpty(GSE_C.msClickRate) then
        clickRate = GSE_C.msClickRate
    end
    return clickRate
end

function GSE.GetResetOOC()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE_C.resetOOC ~= nil then
        return GSE_C.resetOOC
    end
    return GSEOptions.resetOOC
end

function GSE.setActionButtonUseKeyDown()
    local state = GSEOptions.CvarActionButtonState and GSEOptions.CvarActionButtonState or "DONTFORCE"

    if state == "UP" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 0)
        GSE.Print(
            L[
                "The UI has been set to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME` You will need to check your macros and adjust your click commands."
            ],
            L["Troubleshooting"]
        )
    elseif state == "DOWN" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 1)
        GSE.Print(
            L[
                "The UI has been set to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)  You will need to check your macros and adjust your click commands."
            ],
            L["Troubleshooting"]
        )
    end
    GSE.ReloadSequences()
end

--- Key identifying the current talent loadout for keybinding and action bar
--- override storage, as a string: the saved loadout's config id (Retail), whose
--- binds sit on top of its spec's.
---
--- A dual-spec client's Primary and Secondary are not loadouts: they are its
--- specs (GSE.CurrentSpecKey), so they never come through here. tostring(nil)
--- with no saved loadout, as it always was, so stored keys are untouched.
function GSE.GetBindingLoadoutKey()
    local currentSpecID = GSE.GetCurrentSpecID()
    local saved =
        currentSpecID and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and
        C_ClassTalents.GetLastSelectedSavedConfigID(currentSpecID)
    return tostring(saved)
end

function GSE.GetSelectedLoadoutConfigID()
    -- Read only. Running the talent frame's UpdateTreeInfo from addon code
    -- leaves its tree data tainted, and Blizzard's own Share > Copy to
    -- Clipboard is then blocked as GSE's (ADDON_ACTION_FORBIDDEN, #2161).
    local currentSpecID = GSE.GetCurrentSpecID()
    local lastSelected =
        currentSpecID and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and
        C_ClassTalents.GetLastSelectedSavedConfigID(currentSpecID)
    local selectionID =
        PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.LoadoutDropDown and
        PlayerSpellsFrame.TalentsFrame.LoadoutDropDown.GetSelectionID and
        PlayerSpellsFrame.TalentsFrame.LoadoutDropDown:GetSelectionID()

    -- the priority in authoritativeness is [default UI's dropdown] > [API] > ['ActiveConfigID'] > nil
    local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    return selectionID or lastSelected or activeConfigID or nil -- nil happens when you don't have any spec selected, e.g. on a freshly created character
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("CharacterFunctions") end


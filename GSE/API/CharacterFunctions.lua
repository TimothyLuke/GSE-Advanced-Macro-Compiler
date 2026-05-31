local GSE = GSE
local L = GSE.L
local _GNOME, _ = ...

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
        local _id, _name, _description, _icon, _role, class = GSE.GetSpecializationInfoByID(specid)
        if specid <= 13 then
            classid = specid
        else
            for i = 1, 13, 1 do
                local classInfo = GSE.GetClassInfo(i)
                local st = classInfo and classInfo.classFile
                if class == st then
                    classid = i
                end
            end
        end
    end
    return classid
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
    local _, _specname, _specdescription, _specicon, _, _specrole, specclass = GSE.GetSpecializationInfoByID(specID)
    local _currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
    specclass = specclass or ""
    if specID > 15 then
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " " .. specclass .. " equals " .. currentenglishclass)
    else
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " equals currentclassid " .. currentclassId)
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

--- Returns the current Talent Selections as a string
function GSE.GetCurrentTalents()
    local talents

    -- force load the addon
    local addonName = "Blizzard_PlayerSpells"

    xpcall(
        function()
            local loaded, reason = GSE.LoadAddOn(addonName)

            if not loaded then
                talents = ""
                GSE.PrintDebugMessage(reason, "TALENTS")
            else
                if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
                    PlayerSpellsFrame.TalentsFrame:UpdateTreeInfo()
                    talents = PlayerSpellsFrame.TalentsFrame:GetLoadoutExportString()
                end
            end
            return talents
        end,
        function()
            return talents
        end
    )
end

--- Experimental attempt to load a WeakAuras string.
function GSE.LoadWeakAura(str)
    if GSE.IsAddOnLoaded("WeakAuras") then
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
            GSE.PrintDebugMessage("Cleared KeyCombination " .. p .. v)
        end
        SetBinding(p)
    end
    local char = UnitFullName("player")
    local realm = GetRealmName()
    GSE_C = {}
    GSE_C["KeyBindings"] = {}
    GSE_C["KeyBindings"][char .. "-" .. realm] = {}
    GSE_C["KeyBindings"][char .. "-" .. realm][tostring(GetSpecialization())] = {}
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
        if GSE.SetCVar then GSE.SetCVar("ActionButtonUseKeyDown", 0) end
        GSE.Print(
            L[
                "The UI has been set to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME` You will need to check your macros and adjust your click commands."
            ],
            L["Troubleshooting"]
        )
    elseif state == "DOWN" then
        if GSE.SetCVar then GSE.SetCVar("ActionButtonUseKeyDown", 1) end
        GSE.Print(
            L[
                "The UI has been set to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)  You will need to check your macros and adjust your click commands."
            ],
            L["Troubleshooting"]
        )
    end
    GSE.ReloadSequences()
end

function GSE.GetSelectedLoadoutConfigID()
    GSE.GetCurrentTalents()
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


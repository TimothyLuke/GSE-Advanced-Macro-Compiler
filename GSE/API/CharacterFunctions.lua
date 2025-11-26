local GSE = GSE
local L = GSE.L
local GNOME, _ = ...

local Statics = GSE.Static

--- Return the characters current spec id
function GSE.GetCurrentSpecID()
    if GSE.GameMode <= 4 then
        return GSE.GetCurrentClassID() and GSE.GetCurrentClassID()
    else
        local currentSpec =
            C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization() or
            GetSpecialization()
        local currentSpecInfo =
            C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo and
            C_SpecializationInfo.GetSpecializationInfo(currentSpec) or
            GetSpecializationInfo(currentSpec)
        return currentSpec and select(1, currentSpecInfo) or 0
    end
end

--- Return the current GCD for the current character
function GSE.GetGCD()
    local gcd
    local haste = UnitSpellHaste("player")
    gcd = 1.5 / (1 + 0.01 * haste)
    return gcd
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
    -- Check for Classic WoW
    local classid = 0
    if GSE.GameMode < 5 then
        -- Classic WoW
        classid = Statics.SpecIDClassList[specid]
    else
        local id, name, description, icon, role, class = GetSpecializationInfoByID(specid)
        if specid <= 13 then
            classid = specid
        else
            for i = 1, 13, 1 do
                local _, st, _ = GetClassInfo(i)
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

--- Check if the specID provided matches the players current class
function GSE.isSpecIDForCurrentClass(specID)
    local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
    local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
    if specID > 15 then
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " " .. specclass .. " equals " .. currentenglishclass)
    else
        GSE.PrintDebugMessage("Checking if specID " .. specID .. " equals currentclassid " .. currentclassId)
    end
    return (specclass == currentenglishclass or specID == currentclassId)
end

function GSE.GetSpecNames()
    local keyset = {}
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
            local loaded, reason = C_AddOns.LoadAddOn(addonName)

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
    return GSE_C.resetOOC and GSE_C.resetOOC or GSEOptions.resetOOC
end

function GSE.setActionButtonUseKeyDown()
    local state = GSEOptions.CvarActionButtonState and GSEOptions.CvarActionButtonState or "DONTFORCE"

    if state == "UP" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 0)
        GSE.Print(
            L[
                "The UI has been set to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME` You will need to check your macros and adjust your click commands."
            ],
            L["GSE"] .. " " .. L["Troubleshooting"]
        )
    elseif state == "DOWN" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 1)
        GSE.Print(
            L[
                "The UI has been set to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)  You will need to check your macros and adjust your click commands."
            ],
            L["GSE"] .. " " .. L["Troubleshooting"]
        )
    end
    GSE.ReloadSequences()
end

function GSE.GetSelectedLoadoutConfigID()
    GSE.GetCurrentTalents()
    local lastSelected =
        PlayerUtil.GetCurrentSpecID() and C_ClassTalents.GetLastSelectedSavedConfigID(PlayerUtil.GetCurrentSpecID())
    local selectionID =
        PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.LoadoutDropDown and
        PlayerSpellsFrame.TalentsFrame.LoadoutDropDown.GetSelectionID and
        PlayerSpellsFrame.TalentsFrame.LoadoutDropDown:GetSelectionID()

    -- the priority in authoritativeness is [default UI's dropdown] > [API] > ['ActiveConfigID'] > nil
    return selectionID or lastSelected or C_ClassTalents.GetActiveConfigID() or nil -- nil happens when you don't have any spec selected, e.g. on a freshly created character
end

GSE.DebugProfile("CharacterFuntions")

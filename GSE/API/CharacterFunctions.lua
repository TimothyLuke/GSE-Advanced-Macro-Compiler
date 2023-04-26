local GSE = GSE
local L = GSE.L
local GNOME, _ = ...

local Statics = GSE.Static

--- Return the characters current spec id
function GSE.GetCurrentSpecID()
    if GSE.GameMode < 4 then
        return GSE.GetCurrentClassID() and GSE.GetCurrentClassID()
    else
        local currentSpec = GetSpecialization()
        return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or 0
    end
end

--- Return the current GCD for the current character
function GSE.GetGCD()
    local gcdSpell

    local gcd = 1.5
    -- Classic doesnt have haste.
    if GSE.GameMode > 3 then
        local haste = UnitSpellHaste("player")
        gcd = 1.5 / (1 + 0.01 * haste)
    --gcd = math.floor(gcd - (750 * haste / 100) + 0.5) / 1000
    end

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
    classicon[1] = "Interface\\Icons\\inv_sword_27" -- Warrior
    classicon[2] = "Interface\\Icons\\ability_thunderbolt" -- Paladin
    classicon[3] = "Interface\\Icons\\inv_weapon_bow_07" -- Hunter
    classicon[4] = "Interface\\Icons\\inv_throwingknife_04" -- Rogue
    classicon[5] = "Interface\\Icons\\inv_staff_30" -- Priest
    classicon[6] = "Interface\\Icons\\inv_sword_27" -- Death Knight
    classicon[7] = "Interface\\Icons\\inv_jewelry_talisman_04" -- SWhaman
    classicon[8] = "Interface\\Icons\\inv_staff_13" -- Mage
    classicon[9] = "Interface\\Icons\\spell_nature_drowsy" -- Warlock
    classicon[10] = "Interface\\Icons\\Spell_Holy_FistOfJustice" -- Monk
    classicon[11] = "Interface\\Icons\\inv_misc_monsterclaw_04" -- Druid
    classicon[12] = "Interface\\Icons\\INV_Weapon_Glave_01" -- DEMONHUNTER
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
    local talents = ""
    -- Need to change this later on to something meaningful
    if GSE.GameMode < 4 then
        local Talented = Talented
        if not GSE.isEmpty(Talented) then
            if GSE.isEmpty(Talented.alternates) then
                Talented:UpdatePlayerSpecs()
            end
            local LT = LibStub("AceLocale-3.0"):GetLocale("Talented")
            local current_spec = Talented.alternates[GetActiveTalentGroup()]
            talents = Talented.exporters[LT["Wowhead Talent Calculator"]](Talented, current_spec)
        else
            if GSE.GameMode == 1 then
                talents = "CLASSIC"
            elseif GSE.GameMode == 2 then
                talents = "BC CLASSIC"
            else --GSE.GameMode == 3 then
                talents = "Wrath CLASSIC"
            end
        end
    elseif GSE.GameMode >= 10 then
        -- force load the addon
        local loaded, _ = LoadAddOn("Blizzard_ClassTalentUI")

        if not loaded then
            talents = ""
        else
            local t = ClassTalentFrame.TalentsTab
            if t.isAnythingPending ~= nil then
                t:UpdateTreeInfo()
                talents = t:GetLoadoutExportString()
            end
        end
    else
        for talentTier = 1, MAX_TALENT_TIERS do
            local available, selected = GetTalentTierInfo(talentTier, 1)
            talents = talents .. (available and selected or "?" .. ",")
        end
    end
    return talents
end

--- Experimental attempt to load a WeakAuras string.
function GSE.LoadWeakAura(str)
    if IsAddOnLoaded("WeakAuras") then
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
    local combinators = {"SHIFT-", "CTRL-", "ALT-"}
    local defaultbuttons = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="}
    for _, p in ipairs(combinators) do
        for _, v in ipairs(defaultbuttons) do
            SetBinding(p .. v)
            GSE.PrintDebugMessage("Cleared KeyCombination " .. p .. v)
        end
    end
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

function GSE.GetRequireTarget()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.requireTarget and GSE_C.requireTarget or GSEOptions.requireTarget
end

function GSE.SetRequireTarget(value)
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE_C.requireTarget then
        GSE_C.requireTarget = value
    else
        GSEOptions.requireTarget = value
    end
end

function GSE.GetUse11()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use11 and GSE_C.use11 or GSEOptions.use11
end

function GSE.GetUse12()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use12 and GSE_C.use12 or GSEOptions.use12
end

function GSE.GetUse13()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use13 and GSE_C.use13 or GSEOptions.use13
end

function GSE.GetUse14()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use14 and GSE_C.use14 or GSEOptions.use14
end

function GSE.GetUse2()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use2 and GSE_C.use2 or GSEOptions.use2
end

function GSE.GetUse6()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use6 and GSE_C.use6 or GSEOptions.use6
end

function GSE.GetUse1()
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    return GSE_C.use1 and GSE_C.use11 or GSEOptions.use1
end

function GSE.setActionButtonUseKeyDown()
    local state = GSEOptions.CvarActionButtonState and GSEOptions.CvarActionButtonState or "DONTFORCE"
    GSE.UpdateMacroString()
    if state == "UP" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 0)
        GSE.Print(
            L[
                "GSE Macro Stubs have been reset to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME`"
            ],
            L["GSE"] .. " " .. L["Troubleshooting"]
        )
    elseif state == "DOWN" then
        C_CVar.SetCVar("ActionButtonUseKeyDown", 1)
        GSE.Print(
            L[
                "GSE Macro Stubs have been reset to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)"
            ],
            L["GSE"] .. " " .. L["Troubleshooting"]
        )
    end
    GSE.ReloadSequences()
end

GSE.DebugProfile("CharacterFuntions")

local GSE = GSE
local L = GSE.L

local Statics = GSE.Static


--- Return the characters current spec id
function GSE.GetCurrentSpecID()
  local currentSpec = GetSpecialization()
  return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or 0
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

--- Check if the specID provided matches the plauers current class.
function GSE.isSpecIDForCurrentClass(specID)
  local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
  local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
  if specID > 15 then
    GSE.PrintDebugMessage(L["Checking if specID "] .. specID .. " " .. specclass .. L[" equals "] .. currentenglishclass)
  else
    GSE.PrintDebugMessage(L["Checking if specID "] .. specID .. L[" equals currentclassid "] .. currentclassId)
  end
  return (specclass==currentenglishclass or specID==currentclassId)
end


function GSE.GetSpecNames()
  local keyset={}
  for k,v in pairs(Statics.SpecIDList) do
    keyset[v] = v
  end
  return keyset
end


function GSE.GetCurrentTalents()
  local talents = ""
  for talentTier = 1, MAX_TALENT_TIERS do
    local available, selected = GetTalentTierInfo(talentTier, 1)
    talents = talents .. (available and selected or "?" .. ",")
  end
  return talents
end

function GSE:UNIT_FACTION()
  --local pvpType, ffa, _ = GetZonePVPInfo()
  if UnitIsPVP("player") then
    GSE.PVPFlag = true
  else
    GSE.PVPFlag = false
  end
  GSE.PrintDebugMessage("PVP Flag toggled to " .. tostring(GSE.PVPFlag), Statics.DebugModules["API"])
end

function GSE:ZONE_CHANGED_NEW_AREA()
  local name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo()
  if type == "arena" or type == "pvp" then
    GSE.PVPFlag = true
  else
    GSE.PVPFlag = false
  end
  if difficulty == 23 then
    GSE.inMythic = true
  else
    GSE.inMythic = false
  end
  if type == "raid" then
    GSE.inRaid = true
  else
    GSE.inRaid = false
  end
  GSE.PrintDebugMessage("PVP: " .. tostring(GSE.PVPFlag) .. " inMythic: " .. tostring(GSE.inMythic) .. " inRaid: " .. tostring(inRaid), Statics.DebugModules["API"])
end

GSE:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GSE:RegisterEvent("UNIT_FACTION")

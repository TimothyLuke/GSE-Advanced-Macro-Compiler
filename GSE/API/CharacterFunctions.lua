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

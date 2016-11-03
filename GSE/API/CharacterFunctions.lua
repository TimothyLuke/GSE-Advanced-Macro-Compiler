--- Return the characters current spec id
function GSGetCurrentSpecID()
  local currentSpec = GetSpecialization()
  return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or 0
end

--- Return the characters class id
function GSGetCurrentClassID()
  local _, _, currentclassId = UnitClass("player")
  return currentclassId
end

--- Check if the specID provided matches the plauers current class.
function GSisSpecIDForCurrentClass(specID)
  local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
  local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
  if specID > 15 then
    GSE.PrintDebugMessage(L["Checking if specID "] .. specID .. " " .. specclass .. L[" equals "] .. currentenglishclass)
  else
    GSE.PrintDebugMessage(L["Checking if specID "] .. specID .. L[" equals currentclassid "] .. currentclassId)
  end
  return (specclass==currentenglishclass or specID==currentclassId)
end

local GNOME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

GSL = L

GSMasterSequences = ns

GSTRUnfoundSpells = {}

GSModifiedSequences = {} -- [sequenceName] = true if we've already modified this sequence


-- Sety defaults.  THese will be overriden once the addon is marked as loaded.
GSAddInPacks = {}
GSUnloadedAddInPacks = {}


GSE.OutputQueue = {}
GSPrintAvailable = false

--- Compares two sequences and return a boolean if the match.  If they do not
--    match then if will print an element by element comparison.  This comparison
--    ignores version, authorversion, source, helpTxt elements as these are not
--    needed for the execution of the macro but are more for help and versioning.
function GSCompareSequence(seq1,seq2)
  local match = false
  local steps1 = table.concat(seq1, "")
  local steps2 = table.concat(seq2, "")

  if seq1.PostMacro == seq2.PostMacro and seq1.PreMacro == seq2.PreMacro and seq1.specID == seq2.specID and seq1.StepFunction == seq2.StepFunction and steps1 == steps2 and seq1.helpTxt == seq2.helpTxt then
    -- we have a match
    match = true
    GSPrintDebugMessage(L["We have a perfect match"], GNOME)
  else
    if seq1.specID == seq2.specID then
      GSPrintDebugMessage(L["Matching specID"], GNOME)
    else
      GSPrintDebugMessage(L["Different specID"], GNOME)
    end
    if seq1.StepFunction == seq2.StepFunction then
      GSPrintDebugMessage(L["Matching StepFunction"], GNOME)
    else
      GSPrintDebugMessage(L["Different StepFunction"], GNOME)
    end
    if seq1.PreMacro == seq2.PreMacro then
      GSPrintDebugMessage(L["Matching PreMacro"], GNOME)
    else
      GSPrintDebugMessage(L["Different PreMacro"], GNOME)
    end
    if steps1 == steps2 then
      GSPrintDebugMessage(L["Same Sequence Steps"], GNOME)
    else
      GSPrintDebugMessage(L["Different Sequence Steps"], GNOME)
    end
    if seq1.PostMacro == seq2.PostMacro then
      GSPrintDebugMessage(L["Matching PostMacro"], GNOME)
    else
      GSPrintDebugMessage(L["Different PostMacro"], GNOME)
    end
    if seq1.helpTxt == seq2.helpTxt then
      GSPrintDebugMessage(L["Matching helpTxt"], GNOME)
    else
      GSPrintDebugMessage(L["Different helpTxt"], GNOME)
    end

  end
  return match
end

GSDebugOutput = ""



--- Experimental attempt to load a WeakAuras string.
function GSLoadWeakauras(str)
  local WeakAuras = WeakAuras

  if WeakAuras then
    WeakAuras.ImportString(str)
  end
end

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

--- Return whether to store the macro in Personal Character Macros or Account Macros
function GSsetMacroLocation()
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  local returnval = 1
  if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSEOptions.overflowPersonalMacros then
   returnval = nil
  end
  return returnval
end


--- Check if the specID provided matches the plauers current class.
function GSisSpecIDForCurrentClass(specID)
  local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
  local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
  if specID > 15 then
    GSPrintDebugMessage(L["Checking if specID "] .. specID .. " " .. specclass .. L[" equals "] .. currentenglishclass)
  else
    GSPrintDebugMessage(L["Checking if specID "] .. specID .. L[" equals currentclassid "] .. currentclassId)
  end
  return (specclass==currentenglishclass or specID==currentclassId)
end

--- Check if a macro has been created and if not create it.
function GSCheckMacroCreated(SequenceName, globalstub)
  local macroIndex = GetMacroIndexByName(SequenceName)
  if macroIndex and macroIndex ~= 0 then
    if not GSModifiedSequences[SequenceName] then
      GSModifiedSequences[SequenceName] = true
      EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. SequenceName)
    end
  else
    icon = GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].icon
    GSregisterSequence(SequenceName, icon, globalstub)
  end

end

--- This removes a macro Stub.
function GSdeleteMacroStub(sequenceName)
  local mname, _, mbody = GetMacroInfo(sequenceName)
  if mname == sequenceName then
    trimmedmbody = mbody:gsub("[^%w ]", "")
    compar = '#showtooltip\n/click ' .. mname
    trimmedcompar = compar:gsub("[^%w ]", "")
    if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
      GSPrint(L[" Deleted Orphaned Macro "] .. mname, GNOME)
      DeleteMacro(sequenceName)
    end
  end
end

-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        local name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" then
          --print (name)
					local loaded = LoadAddOn(i);
          if loaded then
            local authorversion = GetAddOnMetadata(name, "Version")
            GSImportLegacyMacroCollections(name, authorversion)
            GSAddInPacks[name] = true
          else
            GSUnloadedAddInPacks[name] = true
          end
        end

    end

end



function GSListUnloadedAddons()
  local returnVal = "";
  for k,v in pairs(GSUnloadedAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end


function GSListAddons()
  local returnVal = "";
  for k,v in pairs(GSAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end

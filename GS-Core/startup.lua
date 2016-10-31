local GNOME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

GSL = L

GSMasterSequences = ns
GSStaticCastCmds = {}
GSTRUnfoundSpells = {}

GSModifiedSequences = {} -- [sequenceName] = true if we've already modified this sequence

GSStaticCastCmds = { use = true, cast = true, spell = true, cancelaura = true, startattack = true, cancelform = true }

GSStaticCleanStrings = {}
GSStaticCleanStrings = {
  [1] = "/console Sound_EnableSFX 0%;\n",
  [2] = "/console Sound_EnableSFX 1%;\n",
  [3] = "/script UIErrorsFrame:Hide%(%)%;\n",
  [4] = "/run UIErrorsFrame:Clear%(%)%;\n",
  [5] = "/script UIErrorsFrame:Clear%(%)%;\n",
  [6] = "/run UIErrorsFrame:Hide%(%)%;\n",
  [7] = "/console Sound_EnableErrorSpeech 1\n",
  [8] = "/console Sound_EnableErrorSpeech 0\n",

  [11] = "/console Sound_EnableSFX 0\n",
  [12] = "/console Sound_EnableSFX 1\n",
  [13] = "/script UIErrorsFrame:Hide%(%)\n",
  [14] = "/run UIErrorsFrame:Clear%(%)\n",
  [15] = "/script UIErrorsFrame:Clear%(%)\n",
  [16] = "/run UIErrorsFrame:Hide%(%)\n",
  [17] = "/console Sound_EnableErrorSpeech 1%;\n",
  [18] = "/console Sound_EnableErrorSpeech 0%;\n",

  [20] = "/stopmacro [@playertarget, noexists]\n",

  [30] = "/use 2\n",
  [31] = "/use [combat] 11\n",
  [32] = "/use [combat] 12\n",
  [33] = "/use [combat] 13\n",
  [34] = "/use [combat] 14\n",
  [35] = "/use 11\n",
  [36] = "/use 12\n",
  [37] = "/use 13\n",
  [38] = "/use 14\n",
  [39] = "/Use [combat] 11\n",
  [40] = "/Use [combat] 12\n",
  [41] = "/Use [combat] 13\n",
  [42] = "/Use [combat] 14\n",
  [43] = "/use [combat]11\n",
  [44] = "/use [combat]12\n",
  [45] = "/use [combat]13\n",
  [46] = "/use [combat]14\n",
  [47] = "/use [combat]2\n",
  [48] = "/use [combat] 2\n",
  [49] = "/use [combat]5\n",
  [50] = "/use [combat] 5\n",
  [51] = "/use [combat]1\n",
  [52] = "/use [combat] 1\n",
  [53] = "/use 1\n",
  [54] = "/use 5\n",
  [101] = "\n\n",
}

GSStaticStringRESET = "|r"
GSStaticCoreLoadedMessage = "GS-CoreLoaded"

-- Sety defaults.  THese will be overriden once the addon is marked as loaded.
GSAddInPacks = {}
GSUnloadedAddInPacks = {}


GSOutput = {}
GSPrintAvailable = false
GSSpecIDList = {
  [0] = "All",
  [1] = "Warrior",
  [2] = "Paladin",
  [3] = "Hunter",
  [4] = "Rogue",
  [5] = "Priest",
  [6] = "Death Knight",
  [7] = "Shaman",
  [8] = "Mage",
  [9] = "Warlock",
  [10] = "Monk",
  [11] = "Druid",
  [12] = "Demon Hunter",
  [62] = "Arcane",
  [63] = "Fire",
  [64] = "Frost - Mage",
  [65] = "Holy - Paladin",
  [66] = "Protection - Paladin",
  [70] = "Retribution",
  [71] = "Arms",
  [72] = "Fury",
  [73] = "Protection - Warrior",
  [102] = "Balance",
  [103] = "Feral",
  [104] = "Guardian",
  [105] = "Restoration - Druid",
  [250] = "Blood",
  [251] = "Frost - DK",
  [252] = "Unholy",
  [253] = "Beast Mastery",
  [254] = "Marksmanship",
  [255] = "Survival",
  [256] = "Discipline",
  [257] = "Holy - Priest",
  [258] = "Shadow",
  [259] = "Assassination",
  [260] = "Outlaw",
  [261] = "Subtlety",
  [262] = "Elemental",
  [263] = "Enhancement",
  [264] = "Restoration - Shaman",
  [265] = "Affliction",
  [266] = "Demonology",
  [267] = "Destruction",
  [268] = "Brewmaster",
  [269] = "Windwalker",
  [270] = "Mistweaver",
  [577] = "Havoc",
  [581] = "Vengeance",
}

GSSpecIDHashList = {}
for k,v in pairs(GSSpecIDList) do
  GSSpecIDHashList[v] = k
end

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

GSStaticSequenceDebug = "SEQUENCEDEBUG"


--- <code>GSStaticPriority</code> is a static step function that goes 1121231234123451234561234567
--    use this like StepFunction = GSStaticPriority, in a macro
--    This overides the sequential behaviour that is standard in GS
GSStaticPriority = [[
  limit = limit or 1
  if step == limit then
    limit = limit % #macros + 1
    step = 1
  else
    step = step % #macros + 1
  end
]]

--- <code>GSStaticLoopPriority</code> is a static step function that goes 1121231234123451234561234567
--    but it does this within an internal loop.  So more like 123343456
--    If the macro has loopstart or loopstop defined then it will use this instead of GSStaticPriority
GSStaticLoopPriority = [[
  if step < loopstart then
    step = step + 1
  elseif looplimit <= 1 then
    -- when we get to the end reset to loopstart
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if looplimit == loopiter then
        loopiter = 1
        self:SetAttribute('loopiter', loopiter)
      end
    else
      step = step + 1
    end
  elseif step > looplimit then
    step = step + 1
  elseif loopiter == looplimit then
    step = loopstop + 1
  elseif step == #macros then
    step = 1
    self:SetAttribute('loopiter', 1)
  else
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if limit == loopiter then
        loopiter = loopiter + 1
        self:SetAttribute('loopiter', loopiter)
      end
    else
      step = step + 1
    end
  end
]]

--- <code>GSStaticLoopPriority</code> is a static step function that
--    operates in a sequential mode but with an internal loop.
--    eg 12342345
GSStaticLoopSequential = [[
  --print("Step" .. step)
  --print("Num Mcros " .. #macros)
  --print("Start " .. loopstart)
  --print("Stop " .. loopstop)
  --print("Limit " .. looplimit)
  --print("iter " .. loopiter)

  if step < loopstart then
    -- I am before the loop increment to next step.
    --print(step .. " I am before the loop increment to next step.")
    step = step + 1
  elseif looplimit <= 1 then
    -- when we get to the end reset to loopstart
    --print(step .. " When we get to the end reset to loopstart")
    if step == loopstop then
      step = loopstart
      loopiter = loopiter + 1
      self:SetAttribute('loopiter', loopiter)
    else
      step = step + 1
    end
  elseif loopiter == looplimit then
    -- I am at the outside bound of the loop
    --print(step .. " I am at the outside bound of the loop")
    if step == #macros then
      step = 1
    else
      step = step + 1
    end
    self:SetAttribute('loopiter', 1)
  elseif step > loopstop then
    -- I am outside the loop
    --print(step .. " I am outside the loop")
    step = step + 1
  elseif step == loopstop then
    --print("I am at loop stop")
    step = loopstart
    loopiter = loopiter + 1
    self:SetAttribute('loopiter', loopiter)
  elseif step == #macros  then
    -- I am at the very end reset
    step = 1
    self:SetAttribute('loopiter', 1)
    --print(step .. " I am at the very end reset")
  else
    -- I am in the middle
    --print(step .. " I am in the middle")
    step = step + 1
    --print("Incrementing")
  end
]]


--- Experimental attempt to load a WeakAuras string.
function GSLoadWeakauras(str)
  local WeakAuras = WeakAuras

  if WeakAuras then
    WeakAuras.ImportString(str)
  end
end

--- Return the Active Sequence Version for a Sequence.
function GSGetActiveSequenceVersion(SequenceName)
  local vers = 1
  if not GSisEmpty(GSMasterOptions.ActiveSequenceVersions[SequenceName]) then
    vers = GSMasterOptions.ActiveSequenceVersions[SequenceName]
  end
  return vers
end

--- Return the next version value for a sequence.
--    a <code>last</code> value of true means to get the last remaining version
function GSGetNextSequenceVersion(SequenceName, last)
  local nextv = 0
  GSPrintDebugMessage("GSGetNextSequenceVersion " .. SequenceName, "GSGetNextSequenceVersion")
  if not GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName]) then
    for k,_ in ipairs(GSMasterOptions.SequenceLibrary[SequenceName]) do
    nextv = k
    end
  end
  if not last then
    nextv = nextv + 1
  end
  if nextv == 0 then
    -- no entries found setting to a key of 1
    nextv = 1
  end
  return nextv

end

--- Return a table of Known Sequence Versions
function GSGetKnownSequenceVersions(SequenceName)
  if not GSisEmpty(SequenceName) then
    local t = {}
    for k,_ in pairs(GSMasterOptions.SequenceLibrary[SequenceName]) do
      --print (k)
      t[k] = k
    end
    return t, GSMasterOptions.ActiveSequenceVersions[SequenceName]
  end
end

--- Delete a sequence version
function GSDeleteSequenceVersion(sequenceName, version)
  if not GSisEmpty(sequenceName) then
    local _, selectedversion = GSGetKnownSequenceVersions(sequenceName)
    local sequence = GSMasterOptions.SequenceLibrary[sequenceName][version]
    if sequence.source ~= GSStaticSourceLocal then
      GSPrint(L["You cannot delete this version of a sequence.  This version will be reloaded as it is contained in "] .. GSMasterOptions.NUMBER .. sequence.source .. GSStaticStringRESET, GNOME)
    elseif not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      GSMasterOptions.SequenceLibrary[sequenceName][version] = nil
    end
    if version == selectedversion then
      newversion = GSGetNextSequenceVersion(sequenceName, true)
      if newversion >0  then
        GSSetActiveSequenceVersion(sequenceName, newversion)
      else
        GSMasterOptions.ActiveSequenceVersions[sequenceName] = nil
      end
    end
  end
end

--- Set the Active version of a sequence
function GSSetActiveSequenceVersion(sequenceName, version)
  -- This may need more logic but for the moment iuf they are not equal set somethng.
  GSMasterOptions.ActiveSequenceVersions[sequenceName] = version
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
  if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSMasterOptions.overflowPersonalMacros then
   returnval = nil
  end
  return returnval
end

--- Add a macro for a sequence amd register it in the list of known sequences
function GSregisterSequence(sequenceName, icon, forceglobalstub)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  if sequenceIndex > 0 then
    -- Sequence exists do nothing
    GSPrintDebugMessage(L["Moving on - macro for "] .. sequenceName .. L[" already exists."], GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSMasterOptions.overflowPersonalMacros and not forceglobalstub then
      GSPrint(GSMasterOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSMasterOptions.EmphasisColour .. numCharacterMacros .. L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] .. GSMasterOptions.CommandColour .. L["/gs|r again."], GNOME)
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSMasterOptions.overflowPersonalMacros then
      GSPrint(L["Close to Maximum Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSMasterOptions.EmphasisColour .. numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS .. L[" macros per Account.  You currently have "] .. GSMasterOptions.EmphasisColour .. numAccountMacros .. L["|r. As a result this macro was not created.  Please delete some macros and reenter "] .. GSMasterOptions.CommandColour .. L["/gs|r again."], GNOME)
    else
      sequenceid = CreateMacro(sequenceName, (GSMasterOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), '#showtooltip\n/click ' .. sequenceName, (forceglobalstub and false or GSsetMacroLocation()) )
      GSModifiedSequences[sequenceName] = true
    end
  end
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
    icon = GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].icon
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

--- Disable all versions of a sequence and delete any macro stubs.
function GSDisableSequence(SequenceName)
  GSMasterOptions.DisabledSequences[SequenceName] = true
  GSdeleteMacroStub(SequenceName)
end

--- Enable all versions of a sequence and recreate any macro stubs.
function GSEnableSequence(SequenceName)
  GSMasterOptions.DisabledSequences[SequenceName] = nil
  GSCheckMacroCreated(SequenceName)
end

--- Add a sequence to the library
function GSAddSequenceToCollection(sequenceName, sequence, version)
  local confirmationtext = ""
  --Perform some validation checks on the Sequence.
  if GSisEmpty(sequence.specID) then
    -- set to currentSpecID
    sequence.specID = GSGetCurrentSpecID()
    confirmationtext = " " .. L["Sequence specID set to current spec of "] .. sequence.specID .. "."
  end
  sequence.specID = sequence.specID + 0 -- force to a number.
  if GSisEmpty(sequence.author) then
    -- set to unknown author
    sequence.author = "Unknown Author"
    confirmationtext = " " .. L["Sequence Author set to Unknown"] .. "."
  end
  if GSisEmpty(sequence.helpTxt) then
    -- set to currentSpecID
    sequence.helpTxt = "No Help Information"
    confirmationtext = " " .. L["No Help Information Available"] .. "."
  end

  -- CHeck for colissions
  local found = false
  if not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
    if not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      found = true
    end
  end
  if found then
    -- check if source the same.  If so ignore
    if sequence.source ~= GSMasterOptions.SequenceLibrary[sequenceName][version].source then
      -- different source.  if local Ignore
      if sequence.source == GSStaticSourceLocal then
        -- local version - add as new version
        GSPrint (L["A sequence collision has occured.  Your local version of "] .. sequenceName .. L[" has been added as a new version and set to active.  Please review if this is as expected."], GNOME)
        GSAddSequenceToCollection(sequenceName, sequence, GSGetNextSequenceVersion(sequenceName))
      else
        if GSisEmpty(sequence.source) then
          GSPrint(L["A sequence collision has occured. "] .. L["Two sequences with unknown sources found."] .. " " .. sequenceName, GNOME)
        else
          GSPrint (L["A sequence collision has occured. "] .. sequence.source .. L[" tried to overwrite the version already loaded from "] .. GSMasterOptions.SequenceLibrary[sequenceName][version].source .. L[". This version was not loaded."], Gnome)
        end
      end
    end
  else
    -- New Sequence
    if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
      -- Sequence is new
      GSMasterOptions.SequenceLibrary[sequenceName] = {}
    end
    if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      -- This version is new
      -- print(sequenceName .. " " .. version)
      GSMasterOptions.SequenceLibrary[sequenceName][version] = {}
    end
    -- evaluate version
    if version ~= GSMasterOptions.ActiveSequenceVersions[sequenceName] then

      GSSetActiveSequenceVersion(sequenceName, version)
    end

    GSMasterOptions.SequenceLibrary[sequenceName][version] = sequence
    local makemacrostub = false
    local globalstub = false
    if sequence.specID == GSGetCurrentSpecID() or sequence.specID == GSGetCurrentClassID() then
      makemacrostub = true
    elseif GSMasterOptions.autoCreateMacroStubsClass then
      if GSisSpecIDForCurrentClass(sequence.specID) then
        makemacrostub = true
      end
    elseif GSMasterOptions.autoCreateMacroStubsGlobal then
      if sequence.specID == 0 then
        makemacro = true
        globalstub = true
      end
    end
    if makemacrostub then
      if GSMasterOptions.DisabledSequences[sequenceName] == true then
        GSdeleteMacroStub(sequenceName)
      else
        GSCheckMacroCreated(sequenceName, globalstub)
      end
    end
  end
  if not GSisEmpty(confirmationtext) then
    GSPrint(GSMasterOptions.EmphasisColour .. sequenceName .. "|r" .. L[" was imported with the following errors."] .. " " .. confirmationtext, GNOME)
  end
end

--- Load a collection of Sequences
function GSImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    if GSisEmpty(v.version) then
      v.version = 1
    end
    GSAddSequenceToCollection(k, v, v.version)
  end
end

--- Load sequences found in addon Mods.  authorversion is the version of hte mod where the collection was loaded from.
function GSImportLegacyMacroCollections(str, authorversion)
  for k,v in pairs(GSMasterSequences) do
    if GSisEmpty(v.version) then
      v.version = 1
    end
    if GSisEmpty(authorversion) then
      authorversion = 1
    end
    v.source = str
    v.authorversion = authorversion
    GSAddSequenceToCollection(k, v, v.version)
    GSMasterSequences[k] = nil
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


local escapes = {
    ["|c%x%x%x%x%x%x%x%x"] = "", -- color start
    ["|r"] = "", -- color end
    ["|H.-|h(.-)|h"] = "%1", -- links
    ["|T.-|t"] = "", -- textures
    ["{.-}"] = "", -- raid target icons
}

--- remove WoW Text Markup from a sequence
function GSTRUnEscapeSequence(sequence)
  local i = 1
  for _,v in ipairs(sequence) do
    --print (i .. " " .. v)
    sequence[i] = GSTRUnEscapeString(v)
    i = i + 1
  end
  if not GSisEmpty(sequence.PreMacro) then
    sequence.PreMacro = GSTRUnEscapeString(sequence.PreMacro)
  end
  if not GSisEmpty(sequence.PostMacro) then
    sequence.PostMacro = GSTRUnEscapeString(sequence.PostMacro)
  end
  return sequence
end

--- remove WoW Text Markup from a string
function GSTRUnEscapeString(str)
    for k, v in pairs(escapes) do
        str = gsub(str, k, v)
    end
    return str
end


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


--- Return the Active Sequence Version for a Sequence.
function GSGetActiveSequenceVersion(SequenceName)
  local vers = 1
  if not GSisEmpty(GSMasterOptions.ActiveSequenceVersions[SequenceName]) then
    vers = GSMasterOptions.ActiveSequenceVersions[SequenceName]
  end
  return vers
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


function GSSE:importSequence()
  local functiondefinition =  importStr .. [===[

  return Sequences
  ]===]
  GSPrintDebugMessage (functiondefinition, "GS-SequenceEditor")
  local fake_globals = setmetatable({
    Sequences = {},
    }, {__index = _G})
  local func, err = loadstring (functiondefinition, "GS-SequenceEditor")
  if func then
    -- Make the compiled function see this table as its "globals"
    setfenv (func, fake_globals)

    local TempSequences = assert(func())
    if not GSisEmpty(TempSequences) then
      local newkey = ""
      for k,v in pairs(TempSequences) do

        if GSisEmpty(v.version) then
          v.version = GSGetNextSequenceVersion(k)
        end
        v.source = GSStaticSourceLocal
        GSAddSequenceToCollection(k, v, v.version)
        GSUpdateSequence(k, GSMasterOptions.SequenceLibrary[k][v.version])
        if GSisEmpty(v.icon) then
          -- Set a default icon
          v.icon = GSGetDefaultIcon()
        end
        GSCheckMacroCreated(k)
        newkey = k
        GSPrint(L["Imported new sequence "] .. k, GNOME)
      end
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(newkey)

    end
  else
    GSPrintDebugMessage (err, GNOME)
  end

end

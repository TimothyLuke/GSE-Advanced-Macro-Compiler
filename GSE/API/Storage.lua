local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

--- Disable all versions of a sequence and delete any macro stubs.
function GSE.DisableSequence(SequenceName)
  GSEOptions.DisabledSequences[SequenceName] = true
  GSdeleteMacroStub(SequenceName)
end

--- Enable all versions of a sequence and recreate any macro stubs.
function GSE.EnableSequence(SequenceName)
  GSEOptions.DisabledSequences[SequenceName] = nil
  GSCheckMacroCreated(SequenceName)
end

--- Add a sequence to the library
function GSE.AddSequenceToCollection(sequenceName, sequence, version)
  local confirmationtext = ""
  --Perform some validation checks on the Sequence.
  if GSE.isEmpty(sequence.specID) then
    -- set to currentSpecID
    sequence.specID = GSE.GetCurrentSpecID()
    confirmationtext = " " .. L["Sequence specID set to current spec of "] .. sequence.specID .. "."
  end
  sequence.specID = sequence.specID + 0 -- force to a number.
  if GSE.isEmpty(sequence.author) then
    -- set to unknown author
    sequence.author = "Unknown Author"
    confirmationtext = " " .. L["Sequence Author set to Unknown"] .. "."
  end
  if GSE.isEmpty(sequence.helpTxt) then
    -- set to currentSpecID
    sequence.helpTxt = "No Help Information"
    confirmationtext = " " .. L["No Help Information Available"] .. "."
  end

  -- CHeck for colissions
  local found = false
  if not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName]) then
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version]) then
      found = true
    end
  end
  if found then
    -- check if source the same.  If so ignore
    if sequence.source ~= GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version].source then
      -- different source.  if local Ignore
      if sequence.source == GSStaticSourceLocal then
        -- local version - add as new version
        GSE.Print (L["A sequence collision has occured.  Your local version of "] .. sequenceName .. L[" has been added as a new version and set to active.  Please review if this is as expected."], GNOME)
        GSAddSequenceToCollection(sequenceName, sequence, GSGetNextSequenceVersion(sequenceName))
      else
        if GSE.isEmpty(sequence.source) then
          GSE.Print(L["A sequence collision has occured. "] .. L["Two sequences with unknown sources found."] .. " " .. sequenceName, GNOME)
        else
          GSE.Print (L["A sequence collision has occured. "] .. sequence.source .. L[" tried to overwrite the version already loaded from "] .. GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version].source .. L[". This version was not loaded."], Gnome)
        end
      end
    end
  else
    -- New Sequence
    if GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName]) then
      -- Sequence is new
      GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName] = {}
    end
    if GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version]) then
      -- This version is new
      -- print(sequenceName .. " " .. version)
      GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version] = {}
    end
    -- evaluate version
    if version ~= GSEOptions.ActiveSequenceVersions[sequenceName] then

      GSSetActiveSequenceVersion(sequenceName, version)
    end

    GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version] = sequence
    local makemacrostub = false
    local globalstub = false
    if sequence.specID == GSE.GetCurrentSpecID() or sequence.specID == GSGetCurrentClassID() then
      makemacrostub = true
    elseif GSEOptions.autoCreateMacroStubsClass then
      if GSisSpecIDForCurrentClass(sequence.specID) then
        makemacrostub = true
      end
    elseif GSEOptions.autoCreateMacroStubsGlobal then
      if sequence.specID == 0 then
        makemacro = true
        globalstub = true
      end
    end
    if makemacrostub then
      if GSEOptions.DisabledSequences[sequenceName] == true then
        GSdeleteMacroStub(sequenceName)
      else
        GSCheckMacroCreated(sequenceName, globalstub)
      end
    end
  end
  if not GSE.isEmpty(confirmationtext) then
    GSE.Print(GSEOptions.EmphasisColour .. sequenceName .. "|r" .. L[" was imported with the following errors."] .. " " .. confirmationtext, GNOME)
  end
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    if GSE.isEmpty(v.version) then
      v.version = 1
    end
    GSAddSequenceToCollection(k, v, v.version)
  end
end

-- --- Load sequences found in addon Mods.  authorversion is the version of hte mod where the collection was loaded from.
-- function GSImportLegacyMacroCollections(str, authorversion)
--   for k,v in pairs(GSMasterSequences) do
--     if GSE.isEmpty(v.version) then
--       v.version = 1
--     end
--     if GSE.isEmpty(authorversion) then
--       authorversion = 1
--     end
--     v.source = str
--     v.authorversion = authorversion
--     GSAddSequenceToCollection(k, v, v.version)
--     GSMasterSequences[k] = nil
--   end
-- end



--- Delete a sequence version
function GSE.DeleteSequenceVersion(sequenceName, version)
  if not GSE.isEmpty(sequenceName) then
    local _, selectedversion = GSGetKnownSequenceVersions(sequenceName)
    local sequence = GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version]
    if sequence.source ~= GSStaticSourceLocal then
      GSE.Print(L["You cannot delete this version of a sequence.  This version will be reloaded as it is contained in "] .. GSEOptions.NUMBER .. sequence.source .. Statics.StringReset, GNOME)
    elseif not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version]) then
      GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][version] = nil
    end
    if version == selectedversion then
      newversion = GSGetNextSequenceVersion(sequenceName, true)
      if newversion >0  then
        GSSetActiveSequenceVersion(sequenceName, newversion)
      else
        GSEOptions.ActiveSequenceVersions[sequenceName] = nil
      end
    end
  end
end

--- Set the Active version of a sequence
function GSE.SetActiveSequenceVersion(sequenceName, version)
  -- This may need more logic but for the moment iuf they are not equal set somethng.
  GSEOptions.ActiveSequenceVersions[sequenceName] = version
end


--- Return the next version value for a sequence.
--    a <code>last</code> value of true means to get the last remaining version
function GSE.GetNextSequenceVersion(SequenceName, last)
  local nextv = 0
  GSE.PrintDebugMessage("GSGetNextSequenceVersion " .. SequenceName, "GSGetNextSequenceVersion")
  if not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName]) then
    for k,_ in ipairs(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName]) do
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
function GSE.GetKnownSequenceVersions(SequenceName)
  if not GSE.isEmpty(SequenceName) then
    local t = {}
    for k,_ in pairs(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName]) do
      --print (k)
      t[k] = k
    end
    return t, GSEOptions.ActiveSequenceVersions[SequenceName]
  end
end


--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(SequenceName)
  local vers = 1
  if not GSE.isEmpty(GSEOptions.ActiveSequenceVersions[SequenceName]) then
    vers = GSEOptions.ActiveSequenceVersions[SequenceName]
  end
  return vers
end


--- Add a macro for a sequence amd register it in the list of known sequences
function GSE.RegisterSequence(sequenceName, icon, forceglobalstub)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  if sequenceIndex > 0 then
    -- Sequence exists do nothing
    GSE.PrintDebugMessage(L["Moving on - macro for "] .. sequenceName .. L[" already exists."], GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSEOptions.overflowPersonalMacros and not forceglobalstub then
      GSE.Print(GSEOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSEOptions.overflowPersonalMacros then
      GSE.Print(L["Close to Maximum Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS .. L[" macros per Account.  You currently have "] .. GSEOptions.EmphasisColour .. numAccountMacros .. L["|r. As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    else
      sequenceid = CreateMacro(sequenceName, (GSEOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), '#showtooltip\n/click ' .. sequenceName, (forceglobalstub and false or GSsetMacroLocation()) )
      GSE.ModifiedSequences[sequenceName] = true
    end
  end
end

--- Load a GSE Sequence Collection from a String
function GSE.ImportSequence(importStr)
  local functiondefinition =  GSE.FixQuotes(importStr) .. [===[

  return Sequences
  ]===]
  GSE.PrintDebugMessage (functiondefinition, "GS-SequenceEditor")
  local fake_globals = setmetatable({
    Sequences = {},
    }, {__index = _G})
  local func, err = loadstring (functiondefinition, "GS-SequenceEditor")
  if func then
    -- Make the compiled function see this table as its "globals"
    setfenv (func, fake_globals)

    local TempSequences = assert(func())
    if not GSE.isEmpty(TempSequences) then
      local newkey = ""
      for k,v in pairs(TempSequences) do

        if GSE.isEmpty(v.version) then
          v.version = GSGetNextSequenceVersion(k)
        end
        v.source = GSStaticSourceLocal
        GSAddSequenceToCollection(k, v, v.version)
        GSUpdateSequence(k, GSEOptions.SequenceLibrary[k][v.version])
        if GSE.isEmpty(v.icon) then
          -- Set a default icon
          v.icon = GSGetDefaultIcon()
        end
        GSCheckMacroCreated(k)
        newkey = k
        GSE.Print(L["Imported new sequence "] .. k, GNOME)
      end
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(newkey)

    end
  else
    GSE.PrintDebugMessage (err, GNOME)
  end

end

function GSE.ReloadSequences()
  GSE.PrintDebugMessage(L["Reloading Sequences"])
  for name, version in pairs(GSEOptions.ActiveSequenceVersions) do
    GSE.PrintDebugMessage(name .. " " .. version )
    if not GSE.isEmpty(GSELibrary[name]) then
      vers = GSE.GetActiveSequenceVersion(name)
      GSE.PrintDebugMessage(vers)
      if not GSE.isEmpty(GSELibrary[name][vers]) then
        GSE.UpdateSequence(name, GSELibrary[name][vers])
      else
        GSEOptions.ActiveSequenceVersions[name] = nil
        GSE.PrintDebugMessage(L["Removing "] .. name .. L[" From library"])
      end
    end
  end
end

function GSE.ToggleDisabledSequence(SequenceName)
  if GSEOptions.DisabledSequences[SequenceName] then
    -- Sequence has potentially been Disabled
    if GSEOptions.DisabledSequences[SequenceName] == true then
      -- Definately disabled - enabling
      GSEOptions.DisabledSequences[SequenceName] = nil
      GSCheckMacroCreated(SequenceName)
      GSE.Print(GSEOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been enabled.  The Macro stub is now available in your Macro interface."], GNOME)
    else
      -- Disabling
      GSEOptions.DisabledSequences[SequenceName] = true
      GSdeleteMacroStub(SequenceName)
      GSE.Print(GSEOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been disabled.  The Macro stub for this sequence will be deleted and will not be recreated until you re-enable this sequence.  It will also not appear in the /gs list until it is recreated."], GNOME)
    end
  else
    -- disabliong
    GSEOptions.DisabledSequences[SequenceName] = true
    GSdeleteMacroStub(SequenceName)
    GSE.Print(GSEOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been disabled.  The Macro stub for this sequence will be deleted and will not be recreated until you re-enable this sequence.  It will also not appear in the /gs list until it is recreated."], GNOME)
  end
  GSReloadSequences()
end

function GSE.PrepareLogout(deletenonlocalmacros)
  GSE.CleanMacroLibrary(deletenonlocalmacros)
  if GSEOptions.deleteOrphansOnLogout then
    GSE.CleanOrphanSequences()
  end
  GnomeOptions = GSEOptions
end

function GSE.isLoopSequence(sequence)
  local loopcheck = false
  if not GSE.isEmpty(sequence.loopstart) then
    loopcheck = true
  end
  if not GSE.isEmpty(sequence.loopstop) then
    loopcheck = true
  end
  if not GSE.isEmpty(sequence.looplimit) then
    loopcheck = true
  end
  return loopcheck
end

function GSE.ExportSequence(sequenceName)
  --- Creates a string representation of the a Sequence that can be shared as a string.
  --      Accepts <code>SequenceName</code>
  if GSE.isEmpty(GSEOptions.ActiveSequenceVersions[sequenceName]) then
    return GSEOptions.TitleColour .. GNOME .. ':|r ' .. L[" Sequence named "] .. sequenceName .. L[" is unknown."]
  else
    return GSExportSequencebySeq(GSELibrary[sequenceName][GSGetActiveSequenceVersion(sequenceName)], sequenceName)
  end
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequencebySeq(sequence, sequenceName)
  GSE.PrintDebugMessage("GSExportSequencebySeq Sequence Name: " .. sequenceName)
  local disabledseq = ""
  if GSEOptions.DisabledSequences[sequenceName] then
    disabledseq = GSEOptions.UNKNOWN .. "-- " .. L["This Sequence is currently Disabled Locally."] .. Statics.StringReset .. "\n"
  end
  local helptext = "helpTxt = \"" .. GSEOptions.INDENT .. (GSE.isEmpty(sequence.helpTxt) and "No Help Information" or sequence.helpTxt) .. Statics.StringReset .. "\",\n"
  local specversion = "version=" .. GSEOptions.NUMBER  ..(GSE.isEmpty(sequence.version) and "1" or sequence.version ) .. Statics.StringReset ..",\n"
  local source = "source = \"" .. GSEOptions.INDENT .. (GSE.isEmpty(sequence.source) and "Unknown Source" or sequence.source) .. Statics.StringReset .. "\",\n"
  if not GSE.isEmpty(sequence.authorversion) then
    source = source .. "authorversion = \"" .. GSEOptions.INDENT .. sequence.authorversion .. Statics.StringReset .. "\",\n"
  end
  local steps = ""
  if not GSE.isEmpty(sequence.StepFunction) then
    if  sequence.StepFunction == GSStaticPriority then
     steps = "StepFunction = " .. GSEOptions.EQUALS .. "GSStaticPriority" .. Statics.StringReset .. ",\n"
    else
     steps = "StepFunction = [[" .. GSEOptions.EQUALS .. sequence.StepFunction .. Statics.StringReset .. "]],\n"
    end
  end
  local internalloop = ""
  if GSE.isLoopSequence(sequence) then
    if not GSE.isEmpty(sequence.loopstart) then
      internalloop = internalloop .. "loopstart=" .. GSEOptions.EQUALS .. sequence.loopstart .. Statics.StringReset .. ",\n"
    end
    if not GSE.isEmpty(sequence.loopstop) then
      internalloop = internalloop .. "loopstop=" .. GSEOptions.EQUALS .. sequence.loopstop .. Statics.StringReset .. ",\n"
    end
    if not GSE.isEmpty(sequence.looplimit) then
      internalloop = internalloop .. "looplimit=" .. GSEOptions.EQUALS .. sequence.looplimit .. Statics.StringReset .. ",\n"
    end
  end

  --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. helptext .. steps )
  local returnVal = (disabledseq .. "Sequences['" .. GSEOptions.EmphasisColour .. sequenceName .. Statics.StringReset .. "'] = {\nauthor=\"" .. GSEOptions.AuthorColour .. (GSE.isEmpty(sequence.author) and "Unknown Author" or sequence.author) .. Statics.StringReset .. "\",\n" .. (GSE.isEmpty(sequence.specID) and "-- Unknown specID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "specID=" .. GSEOptions.NUMBER  .. sequence.specID .. Statics.StringReset ..",\n") .. specversion .. source .. helptext .. steps .. internalloop)
  if not GSE.isEmpty(sequence.icon) then
     returnVal = returnVal .. "icon=" .. GSEOptions.CONCAT .. (tonumber(sequence.icon) and sequence.icon or "'".. sequence.icon .. "'") .. Statics.StringReset ..",\n"
  end
  if not GSE.isEmpty(sequence.lang) then
    returnVal = returnVal .. "lang=\"" .. GSEOptions.STANDARDFUNCS .. sequence.lang .. Statics.StringReset .. "\",\n"
  end
  returnVal = returnVal .. "KeyPress=[[\n" .. (GSE.isEmpty(sequence.KeyPress) and "" or sequence.KeyPress) .. "]]," .. "\n\"" .. table.concat(sequence,"\",\n\"") .. "\",\n"
  returnVal = returnVal .. "KeyRelease=[[\n" .. (GSE.isEmpty(sequence.KeyRelease) and "" or sequence.KeyRelease) .. "]],\n}"
  return returnVal
end

--- This function performs any actions to clean up common syntax errors in Legacy GSE1 Sequences
function GSE.FixLegacySequence(sequence)
  for k,v in pairs(Statics.CleanStrings) do
    GSE.PrintDebugMessage(L["Testing String: "] .. v, GNOME)
    if not GSE.isEmpty(sequence.PreMacro) then sequence.PreMacro = string.gsub(sequence.PreMacro, v, "") end
    if not GSE.isEmpty(sequence.PostMacro) then sequence.PostMacro = string.gsub(sequence.PostMacro, v, "") end
  end
end

--- This function removes any macro stubs that do not relate to a GSE macro
function GSE.CleanOrphanSequences()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
  local todelete = {}
  for macid = 1, maxmacros do
    local found = false
    local mname, mtexture, mbody = GetMacroInfo(macid)
    if not GSE.isEmpty(mname) then
      for name, _ in pairs(GSEOptions.ActiveSequenceVersions) do
        if name == mname then
          found = true
        end
      end
      if not found then
        -- check if body is a gs one and delete the orphan
        todelete[mname] = true
      end
    end
  end
  for k,_ in pairs(todelete) do
    GSdeleteMacroStub(k)
  end
end

--- This function is used to clean the loacl sequence library
function GSE.CleanMacroLibrary(logout)
  -- clean out the sequences database except for the current version
  local tempTable = {}
  for name, versiontable in pairs(GSELibrary) do
    GSE.PrintDebugMessage(L["Testing "] .. name )

    if not GSE.isEmpty(GSEOptions.ActiveSequenceVersions[name]) then
      GSE.PrintDebugMessage(L["Active Version "] .. GSEOptions.ActiveSequenceVersions[name])
    else
      GSE.PrintDebugMessage(L["No Active Version"] .. " " .. name)
    end
    for version, sequence in pairs(versiontable) do
      GSE.PrintDebugMessage(L["Cycle Version "] .. version )
      GSE.PrintDebugMessage(L["Source "] .. sequence.source)
      if sequence.source == GSStaticSourceLocal then
        -- Save user created entries.  If they are in a mod dont save them as they will be reloaded next load.
        GSE.PrintDebugMessage("sequence.source == GSStaticSourceLocal")
        if GSE.isEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSE.UnEscapeSequence(sequence)
      elseif GSEOptions.ActiveSequenceVersions[name] == version and not logout  then
        GSE.PrintDebugMessage("GSEOptions.ActiveSequenceVersions[name] == version and not logout")
        if GSE.isEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSE.UnEscapeSequence(sequence)
      elseif sequence.source == GSStaticSourceTransmission then
        if GSE.isEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSE.UnEscapeSequence(sequence)
      else
        GSE.PrintDebugMessage(L["Removing "] .. name .. ":" .. version)
      end
    end
  end
  GSELibrary = nil
  GSELibrary = tempTable
end

--- This function resets a button back to its initial setting
function GSE.ResetButtons()
  for k,v in pairs(GSEOptions.ActiveSequenceVersions) do
    if GSE.isSpecIDForCurrentClass(GSELibrary[k][v].specID) then
      button = _G[k]
      button:SetAttribute("step",1)
      UpdateIcon(button)
    end
  end
end

--- This funciton lists all sequences that are cirrently known
function GSE.ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(GSELibrary) do
    if not GSE.isEmpty(sequence[GSGetActiveSequenceVersion(name)].specID) then
      local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence[GSGetActiveSequenceVersion(name)].specID)
      GSE.PrintDebugMessage(L["Sequence Name: "] .. name)
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSE.PrintDebugMessage(L["No Specialisation information for sequence "] .. name .. L[". Overriding with information for current spec "] .. specname)
      if sequence[GSGetActiveSequenceVersion(name)].specID == currentSpecID or string.upper(txt) == specclass then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. GSEOptions.INDENT .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. Statics.StringReset .. ' ' .. GSEOptions.EmphasisColour .. specclass .. '|r ' .. specname .. ' ' .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME)
        GSregisterSequence(name, (GSE.isEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      elseif txt == "all" or sequence[GSGetActiveSequenceVersion(name)].specID == 0  then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt or L["No Help Information "] .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME)
      elseif sequence[GSGetActiveSequenceVersion(name)].specID == currentclassId then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. ' ' .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME )
        GSregisterSequence(name, (GSE.isEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      end
    else
      GSE.Print(GSEOptions.CommandColour .. name .. L["|r Incomplete Sequence Definition - This sequence has no further information "] .. GSEOptions.AuthorColour .. L["Unknown Author|r "], GNOME )
    end
  end
  ShowMacroFrame()
end


--- This function updates the button for an existing sequence3
function GSE.UpdateSequence(name,sequence)
    local button = _G[name]
    -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
    if GSTRanslatorAvailable and GSE.isSpecIDForCurrentClass(sequence.specID) then
      sequence = GSE.TranslateSequence(sequence, name)
    end
    if GSE.isEmpty(_G[name]) then
      createButton(name, sequence)
    else
      button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(sequence))) .. ']=======])')
      button:SetAttribute("step",1)
      button:SetAttribute('KeyPress',prepareKeyPress(sequence.KeyPress or '') .. '\n')
      GSE.PrintDebugMessage(L["GSUpdateSequence KeyPress updated to: "] .. button:GetAttribute('KeyPress'))
      button:SetAttribute('KeyRelease', '\n' .. prepareKeyRelease(sequence.KeyRelease or ''))
      GSE.PrintDebugMessage(L["GSUpdateSequence KeyRelease updated to: "] .. button:GetAttribute('KeyRelease'))
      button:UnwrapScript(button,'OnClick')
      if GSisLoopSequence(sequence) then
        if GSE.isEmpty(sequence.StepFunction) then
          button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopSequential))
        else
          button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopPriority))
        end
      else
        button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
      end
      if not GSE.isEmpty(sequence.loopstart) then
        button:SetAttribute('loopstart', sequence.loopstart)
      end
      if not GSE.isEmpty(sequence.loopstop) then
        button:SetAttribute('loopstop', sequence.loopstop)
      end
      if not GSE.isEmpty(sequence.looplimit) then
        button:SetAttribute('looplimit', sequence.looplimit)
      end
    end
end

--- This funciton dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)
  GSE.Print("Button name: "  .. SequenceName)
  GSE.Print(_G[SequenceName]:GetScript('OnClick'))
  GSE.Print("KeyPress" .. _G[SequenceName]:GetAttribute('KeyPress'))
  GSE.Print("KeyRelease" .. _G[SequenceName]:GetAttribute('KeyRelease'))
  GSE.Print(format(OnClick, GSELibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].StepFunction or 'step = step % #macros + 1'))
end

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
  if usoptions.DebugSequenceExecution then
    -- Note to self do i care if its a loop sequence?
    local isUsable, notEnoughMana = IsUsableSpell(task)
    local usableOutput, manaOutput, GCDOutput, CastingOutput
    if isUsable then
      usableOutput = GSEOptions.CommandColour .. "Able To Cast" .. Statics.StringReset
    else
      usableOutput =  GSEOptions.UNKNOWN .. "Not Able to Cast" .. Statics.StringReset
    end
    if notEnoughMana then
      manaOutput = GSEOptions.UNKNOWN .. "Resources Not Available".. Statics.StringReset
    else
      manaOutput =  GSEOptions.CommandColour .. "Resources Available" .. Statics.StringReset
    end
    local castingspell, _, _, _, _, _, castspellid, _ = UnitCastingInfo("player")
    if not GSE.isEmpty(castingspell) then
      CastingOutput = GSEOptions.UNKNOWN .. "Casting " .. castingspell .. Statics.StringReset
    else
      CastingOutput = GSEOptions.CommandColour .. "Not actively casting anything else." .. Statics.StringReset
    end
    GCDOutput =  GSEOptions.CommandColour .. "GCD Free" .. Statics.StringReset
    if GCD then
      GCDOutput = GSEOptions.UNKNOWN .. "GCD In Cooldown" .. Statics.StringReset
    end
    GSE.PrintDebugMessage(button .. "," .. step .. "," .. (task and task or "nil")  .. "," .. usableOutput .. "," .. manaOutput .. "," .. GCDOutput .. "," .. CastingOutput, Statics.SequenceDebug)
  end
end


--- Compares two sequences and return a boolean if the match.  If they do not
--    match then if will print an element by element comparison.  This comparison
--    ignores version, authorversion, source, helpTxt elements as these are not
--    needed for the execution of the macro but are more for help and versioning.
function GSE.CompareSequence(seq1,seq2)
  local match = false
  local steps1 = table.concat(seq1, "")
  local steps2 = table.concat(seq2, "")

  if seq1.KeyRelease == seq2.KeyRelease and seq1.KeyPress == seq2.KeyPress and seq1.specID == seq2.specID and seq1.StepFunction == seq2.StepFunction and steps1 == steps2 and seq1.helpTxt == seq2.helpTxt then
    -- we have a match
    match = true
    GSE.PrintDebugMessage(L["We have a perfect match"], GNOME)
  else
    if seq1.specID == seq2.specID then
      GSE.PrintDebugMessage(L["Matching specID"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different specID"], GNOME)
    end
    if seq1.StepFunction == seq2.StepFunction then
      GSE.PrintDebugMessage(L["Matching StepFunction"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different StepFunction"], GNOME)
    end
    if seq1.KeyPress == seq2.KeyPress then
      GSE.PrintDebugMessage(L["Matching KeyPress"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different KeyPress"], GNOME)
    end
    if steps1 == steps2 then
      GSE.PrintDebugMessage(L["Same Sequence Steps"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different Sequence Steps"], GNOME)
    end
    if seq1.KeyRelease == seq2.KeyRelease then
      GSE.PrintDebugMessage(L["Matching KeyRelease"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different KeyRelease"], GNOME)
    end
    if seq1.helpTxt == seq2.helpTxt then
      GSE.PrintDebugMessage(L["Matching helpTxt"], GNOME)
    else
      GSE.PrintDebugMessage(L["Different helpTxt"], GNOME)
    end

  end
  return match
end

--- Return whether to store the macro in Personal Character Macros or Account Macros
function GSE.SetMacroLocation()
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  local returnval = 1
  if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSEOptions.overflowPersonalMacros then
   returnval = nil
  end
  return returnval
end



--- Check if a macro has been created and if not create it.
function GSE.CheckMacroCreated(SequenceName, globalstub)
  local macroIndex = GetMacroIndexByName(SequenceName)
  if macroIndex and macroIndex ~= 0 then
    if not GSE.ModifiedSequences[SequenceName] then
      GSE.ModifiedSequences[SequenceName] = true
      EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. SequenceName)
    end
  else
    icon = GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceName][GSGetActiveSequenceVersion(SequenceName)].icon
    GSregisterSequence(SequenceName, icon, globalstub)
  end

end

--- This removes a macro Stub.
function GSE.DeleteMacroStub(sequenceName)
  local mname, _, mbody = GetMacroInfo(sequenceName)
  if mname == sequenceName then
    trimmedmbody = mbody:gsub("[^%w ]", "")
    compar = '#showtooltip\n/click ' .. mname
    trimmedcompar = compar:gsub("[^%w ]", "")
    if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
      GSE.Print(L[" Deleted Orphaned Macro "] .. mname, GNOME)
      DeleteMacro(sequenceName)
    end
  end
end


--- Not Used
function GSE.GetDefaultIcon()
  local currentSpec = GetSpecialization()
  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or ""
  local _, _, _, defaulticon, _, _, _ = GetSpecializationInfoByID(currentSpecID)
  return strsub(defaulticon, 17)
end


--- This returns a list of Sequence Names for the current spec
function GSE.getSequenceNames()
  local keyset={}
  local currentSpec = GetSpecialization()
  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or ""
  if not GSE.isEmpty(currentSpecID) then
    local _, _, _, _, _, _, pspecclass = GetSpecializationInfoByID(currentSpecID)
    for k,v in pairs(GSEOptions.ActiveSequenceVersions) do
      --print (table.getn(GSEOptions.SequenceLibrary[k]))
      if not GSE.isEmpty(GSEOptions.SequenceLibrary[k]) then
        local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(GSEOptions.SequenceLibrary[k][v].specID)
        if GSEOptions.filterList["All"] then
          keyset[k]=k
        elseif GSEOptions.SequenceLibrary[k][v].specID == 0 then
          keyset[k]=k
        elseif GSEOptions.filterList["Class"]  then
          if pspecclass == specclass then
            keyset[k]=k
          end
        elseif GSEOptions.SequenceLibrary[k][v].specID == currentSpecID then
          keyset[k]=k
        else
          -- do nothing
          GSE.PrintDebugMessage (k .. L[" not added to list."], "GS-SequenceEditor")
        end
      else
        GSE.Print(L["No Sequences present so none displayed in the list."] .. ' ' .. k, GNOME)
      end
    end
  end
  -- Filter Keyset
  return keyset
end


--- Return the Macro Icon for the specified Sequence
function GSE:GetMacroIcon(sequenceIndex)
  GSE.PrintDebugMessage(L["sequenceIndex: "] .. (GSE.isEmpty(sequenceIndex) and L["No value"] or sequenceIndex), GNOME)
  if not GSE.isEmpty(GSGetActiveSequenceVersion(currentSequence)) then
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) then
      GSE.PrintDebugMessage(L["Icon: "] .. GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon, GNOME)
    else
      GSE.PrintDebugMessage(L["Icon: "] .. L["none"], GNOME)
    end
  end
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSE.isEmpty(a) then
    GSE.PrintDebugMessage(L["Macro Found "] .. a .. L[" with iconid "] .. (GSE.isEmpty(iconid) and L["of no value"] or iconid) .. " " .. (GSE.isEmpty(iconid) and L["with no body"] or c), GNOME)
  else
    GSE.PrintDebugMessage(L["No Macro Found. Possibly different spec for Sequence "] .. sequenceIndex , GNOME)
  end
  if GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) and GSE.isEmpty(iconid) then
    GSE.PrintDebugMessage("SequenceSpecID: " .. GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID, GNOME)
    if GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID == 0 then
      return "INV_MISC_QUESTIONMARK"
    else
      local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID) and GSE.GetCurrentSpecID() or GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID))
      GSE.PrintDebugMessage(L["No Sequence Icon setting to "] .. strsub(specicon, 17), GNOME)
      return strsub(specicon, 17)
    end
  elseif GSE.isEmpty(iconid) and not GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) then

      return GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon
  else
      return iconid
  end
end


function GSE.ListUnloadedAddons()
  local returnVal = "";
  for k,v in pairs(GSE.UnloadedAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end


function GSE.ListAddons()
  local returnVal = "";
  for k,v in pairs(GSE.AddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end


--- This converts a legacy GS/GSE1 sequence to a new GSE2
function GSE.ConvertLegacySequence(sequence)
  GSE.FixLegacySequence(sequence)
  local GSStaticPriority = Statics.PriorityImplementation
  local returnSequence= {}
  if not GSE.isEmpty(sequence.specID) then
    returnSequence.SpecID = sequence.SpecID
  end
  if not GSE.isEmpty(sequence.author) then
    returnSequence.Author = sequence.author
  end
  if not GSE.isEmpty(sequence.authorversion) then
    returnSequence.AuthorVersion = sequence.authorversion
  end
  if not GSE.isEmpty(sequence.helpTxt) then
    returnSequence.Help = sequence.helpTxt
  end
  if not GSE.isEmpty(sequence.lang) then
    returnSequence.Lang = sequence.lang
  end
  returnSequence.Default = 1
  returnSequence.MacroVersions = {}
  returnSeq.MacroVersions[1] = {}
  if not GSE.isEmpty(sequence.PreMacro) then
    returnSeq.MacroVersions[1].KeyPress = GSE.SplitMeIntolines(sequence.PreMacro)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    returnSeq.MacroVersions[1].KeyRelease = GSE.SplitMeIntolines(sequence.PostMacro)
  end
  if not GSE.isEmpty(sequence.StepFunction) then
    if Sequence.StepFunction == GSStaticPriority then
      returnSeq.MacroVersions[1].StepFunction = Statics.Priority
    elseif GSE.isEmpty(sequence.StepFunction) then
      GSE.Print(L["The Custom StepFunction Specified is not recognised and has been ignored."], GNOME)
      returnSeq.MacroVersions[1].StepFunction = Statics.Sequential
    end
  else
    returnSeq.MacroVersions[1].StepFunction = Statics.Sequential
  end
  if not GSE.isEmpty(sequence.icon) then
    returnSequence.Icon = sequence.icon
  end
  for k,v in ipairs(sequence) do
    local loopstart = sequence.loopstart or 1
    local loopstop = sequence.loopstop or table.getn(sequence)
    if loopstart > 1 then
      returnSeq.MacroVersions[1].PreMacro = {}
    end
    if loopstop < table.getn(sequence) then
      returnSeq.MacroVersions[1].PostMacro = {}
    end
    if k < loopstart then
      table.insert(returnSeq.MacroVersions[1].PreMacro, v)
    elseif k > loopstop then
      table.insert(returnSeq.MacroVersions[1].PostMacro, v)
    else
      table.insert(returnSeq.MacroVersions[1], v)
    end
  end
end

--- Load in the sample macros for the current class.
function GSE.LoadSampleMacros(classID)
  for k,v in pairs(Statics.SampleMacros[classID]) do
    GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()][k] = v
  end
end

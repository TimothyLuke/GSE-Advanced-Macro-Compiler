local GSE = GSE

--- Disable all versions of a sequence and delete any macro stubs.
function GSE.DisableSequence(SequenceName)
  GSMasterOptions.DisabledSequences[SequenceName] = true
  GSdeleteMacroStub(SequenceName)
end

--- Enable all versions of a sequence and recreate any macro stubs.
function GSE.EnableSequence(SequenceName)
  GSMasterOptions.DisabledSequences[SequenceName] = nil
  GSCheckMacroCreated(SequenceName)
end

--- Add a sequence to the library
function GSE.AddSequenceToCollection(sequenceName, sequence, version)
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
function GSE.ImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    if GSisEmpty(v.version) then
      v.version = 1
    end
    GSAddSequenceToCollection(k, v, v.version)
  end
end

-- --- Load sequences found in addon Mods.  authorversion is the version of hte mod where the collection was loaded from.
-- function GSImportLegacyMacroCollections(str, authorversion)
--   for k,v in pairs(GSMasterSequences) do
--     if GSisEmpty(v.version) then
--       v.version = 1
--     end
--     if GSisEmpty(authorversion) then
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
function GSE.SetActiveSequenceVersion(sequenceName, version)
  -- This may need more logic but for the moment iuf they are not equal set somethng.
  GSMasterOptions.ActiveSequenceVersions[sequenceName] = version
end


--- Return the next version value for a sequence.
--    a <code>last</code> value of true means to get the last remaining version
function GSE.GetNextSequenceVersion(SequenceName, last)
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
function GSE.GetKnownSequenceVersions(SequenceName)
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
function GSE.GetActiveSequenceVersion(SequenceName)
  local vers = 1
  if not GSisEmpty(GSMasterOptions.ActiveSequenceVersions[SequenceName]) then
    vers = GSMasterOptions.ActiveSequenceVersions[SequenceName]
  end
  return vers
end


--- Add a macro for a sequence amd register it in the list of known sequences
function GSE.RegisterSequence(sequenceName, icon, forceglobalstub)
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


function GSE.ImportSequence()
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
  CleanMacroLibrary(deletenonlocalmacros)
  if GSEOptions.deleteOrphansOnLogout then
    cleanOrphanSequences()
  end
  GnomeOptions = GSEOptions
end

local function GSE.isLoopSequence(sequence)
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
  returnVal = returnVal .. "PreMacro=[[\n" .. (GSE.isEmpty(sequence.PreMacro) and "" or sequence.PreMacro) .. "]]," .. "\n\"" .. table.concat(sequence,"\",\n\"") .. "\",\n"
  returnVal = returnVal .. "PostMacro=[[\n" .. (GSE.isEmpty(sequence.PostMacro) and "" or sequence.PostMacro) .. "]],\n}"
  return returnVal
end

function GSE.FixSequence(sequence)
  for k,v in pairs(GSStaticCleanStrings) do
    GSE.PrintDebugMessage(L["Testing String: "] .. v, GNOME)
    if not GSE.isEmpty(sequence.PreMacro) then sequence.PreMacro = string.gsub(sequence.PreMacro, v, "") end
    if not GSE.isEmpty(sequence.PostMacro) then sequence.PostMacro = string.gsub(sequence.PostMacro, v, "") end
  end
end

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

function GSE.ResetButtons()
  for k,v in pairs(GSEOptions.ActiveSequenceVersions) do
    if GSE.isSpecIDForCurrentClass(GSELibrary[k][v].specID) then
      button = _G[k]
      button:SetAttribute("step",1)
      UpdateIcon(button)
    end
  end
end

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


function GSE.UpdateSequence(name,sequence)
    local button = _G[name]
    -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
    if GSE.anslatorAvailable and GSisSpecIDForCurrentClass(sequence.specID) then
      sequence = GSE.anslateSequence(sequence, name)
    end
    if GSE.isEmpty(_G[name]) then
      createButton(name, sequence)
    else
      button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(sequence))) .. ']=======])')
      button:SetAttribute("step",1)
      button:SetAttribute('PreMacro',preparePreMacro(sequence.PreMacro or '') .. '\n')
      GSE.PrintDebugMessage(L["GSUpdateSequence PreMacro updated to: "] .. button:GetAttribute('PreMacro'))
      button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
      GSE.PrintDebugMessage(L["GSUpdateSequence PostMacro updated to: "] .. button:GetAttribute('PostMacro'))
      button:UnwrapScript(button,'OnClick')
      if GSisLoopSequence(sequence) then
        if GSE.isEmpty(sequence.StepFunction) then
          button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopSequential))
        else
          button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopPriority))
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

function GSE.DebugDumpButton(SequenceName)
  GSE.Print("Button name: "  .. SequenceName)
  GSE.Print(_G[SequenceName]:GetScript('OnClick'))
  GSE.Print("PreMacro" .. _G[SequenceName]:GetAttribute('PreMacro'))
  GSE.Print("PostMacro" .. _G[SequenceName]:GetAttribute('PostMacro'))
  GSE.Print(format(OnClick, GSELibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].StepFunction or 'step = step % #macros + 1'))
end

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
    GSE.PrintDebugMessage(button .. "," .. step .. "," .. (task and task or "nil")  .. "," .. usableOutput .. "," .. manaOutput .. "," .. GCDOutput .. "," .. CastingOutput, GSStaticSequenceDebug)
  end
end

local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"


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
function GSE.AddSequenceToCollection(sequenceName, sequence)
  local confirmationtext = ""
  -- CHeck for colissions
  local found = false
  if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
      found = true
  end
  if found then
    -- check if source the same.  If so ignore
    GSE.Print (L["A sequence collision has occured.  Extra versions of this macro have been loaded.  Manage the sequence to determine how to use them "], GNOME)
    for k,v in ipairs(sequence.MacroVersions) do
      table.add(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions, v)
    end
  else
    -- New Sequence
    --Perform some validation checks on the Sequence.
    if GSE.isEmpty(sequence.SpecID) then
      -- set to currentSpecID
      sequence.SpecID = GSE.GetCurrentSpecID()
      confirmationtext = confirmationtext .. " " .. L["Sequence specID set to current spec of "] .. sequence.SpecID .. "."
    end
    sequence.SpecID = sequence.SpecID + 0 -- force to a number.
    if GSE.isEmpty(sequence.Author) then
      -- set to unknown author
      sequence.Author = "Unknown Author"
      confirmationtext = confirmationtext .. " " .. L["Sequence Author set to Unknown"] .. "."
    end
    if GSE.isEmpty(sequence.Talents) then
      -- set to currentSpecID
      sequence.Talents = "?,?,?,?,?,?,?"
      confirmationtext = confirmationtext .. " " .. L["No Help Information Available"] .. "."
    end

    if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
      -- Sequence is new
      GSELibrary[GSE.GetCurrentClassID()][sequenceName] = {}
    end
    GSELibrary[GSE.GetCurrentClassID()][sequenceName] = sequence
  end
  if not GSE.isEmpty(confirmationtext) then
    GSE.Print(GSEOptions.EmphasisColour .. sequenceName .. "|r" .. L[" was imported with the following errors."] .. " " .. confirmationtext, GNOME)
  end
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    GSE.AddSequenceToCollection(k, v)
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
    local sequence = GSELibrary[GSE.GetCurrentClassID()][sequenceName][version]
    if sequence.source ~= GSStaticSourceLocal then
      GSE.Print(L["You cannot delete this version of a sequence.  This version will be reloaded as it is contained in "] .. GSEOptions.NUMBER .. sequence.source .. Statics.StringReset, GNOME)
    elseif not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName][version]) then
      GSELibrary[GSE.GetCurrentClassID()][sequenceName][version] = nil
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
  if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
    for k,_ in ipairs(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) do
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
    for k,_ in pairs(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) do
      --print (k)
      t[k] = k
    end
    return t, GSEOptions.ActiveSequenceVersions[SequenceName]
  end
end


--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(sequenceName)
  -- Set to default or 1 if no default
  local vers = GSELibrary[GSE.GetCurrentClassID()][sequenceName].Default or 1
  if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].PVP) and GSE.PVPFlag then
    vers = GSELibrary[GSE.GetCurrentClassID()][sequenceName].PVP
  elseif not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].Raid) and GSE.inRaid then
    vers = GSELibrary[GSE.GetCurrentClassID()][sequenceName].Raid
  elseif not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].Mythic) and GSE.inMythic then
    vers = GSELibrary[GSE.GetCurrentClassID()][sequenceName].Mythic
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
function GSE.ImportSequence(importStr, legacy)
  local success, returnmessage = false, ""

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
        if legacy then
          v = GSE.ConvertLegacySequence(v)
        end
        v.source = Statics.SourceLocal
        GSE.AddSequenceToCollection(k, v)
        if GSE.isEmpty(v.Icon) then
          -- Set a default icon
          v.Icon = GSGetDefaultIcon()
        end
        GSCheckMacroCreated(k)
        newkey = k
      end
      success = true
    end
  else
    GSE.PrintDebugMessage (err, GNOME)
    returnmessage = err

  end
  return success, returnmessage
end

function GSE.ReloadSequences()
  GSE.PrintDebugMessage(L["Reloading Sequences"])
  for name, sequence in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    GSE.UpdateSequence(name, sequence.MacroVersions[GSE.GetActiveSequenceVersion(name)])
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
  GSE.ReloadSequences()
end

function GSE.PrepareLogout(deletenonlocalmacros)
  GSE.CleanMacroLibrary(deletenonlocalmacros)
  if GSEOptions.deleteOrphansOnLogout then
    GSE.CleanOrphanSequences()
  end
  GnomeOptions = GSEOptions
end

function GSE.IsLoopSequence(sequence)
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

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts <code>SequenceName</code>
function GSE.ExportSequence(sequenceName)
  --TODO change current classid to be a lookup of sequenceName
  return GSE.ExportSequencebySeq(GSELibrary[GSE.GetCurrentClassID()][sequenceName], sequenceName)
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequencebySeq(sequence, sequenceName)
  GSE.PrintDebugMessage("GSExportSequencebySeq Sequence Name: " .. sequenceName)
  local disabledseq = ""
  if GSEOptions.DisabledSequences[sequenceName] then
    disabledseq = GSEOptions.UNKNOWN .. "-- " .. L["This Sequence is currently Disabled Locally."] .. Statics.StringReset .. "\n"
  end
  local sequencemeta = "  Talents = \"" .. GSEOptions.INDENT .. (GSE.isEmpty(sequence.Talents) and "?,?,?,?,?,?,?" or sequence.Talents) .. Statics.StringReset .. "\",\n"
  if not GSE.isEmpty(sequence.Helplink) then
    sequencemeta = sequencemeta .. "  Helplink = \"" .. GSEOptions.INDENT .. sequence.Helplink .. Statics.StringReset .. "\",\n"
  end
  if not GSE.isEmpty(sequence.Help) then
    sequencemeta = sequencemeta .. "  Help = \"" .. GSEOptions.INDENT .. sequence.Help .. Statics.StringReset .. "\",\n"
  end
  sequencemeta = sequencemeta .. "  Default=" ..sequence.Default .. ",\n"
  if not GSE.isEmpty(sequence.Raid) then
    sequencemeta = sequencemeta .. "  Raid=" ..sequence.Raid .. ",\n"
  end
  if not GSE.isEmpty(sequence.PVP) then
    sequencemeta = sequencemeta .. "  PVP=" ..sequence.PVP .. ",\n"
  end
  if not GSE.isEmpty(sequence.Mythic) then
    sequencemeta = sequencemeta .. "  Mythic=" ..sequence.Mythic .. ",\n"
  end
  local macroversions = "  MacroVersions = {\n"
  for k,v in pairs(sequence.MacroVersions) do
    macroversions = macroversions .. "    [" .. k .. "] = {\n"

    local steps = "      StepFunction = \"Sequential\"\n" -- Set to this as the default if its blank.
    if not GSE.isEmpty(sequence.StepFunction) then
      if  v.StepFunction == Statics.PriorityImplementation or v.StepFunction == "Priority" then
       steps = "      StepFunction = " .. GSEOptions.EQUALS .. "\"Priority\"" .. Statics.StringReset .. ",\n"
     elseif v.StepFunction == "Sequential" then
       steps = "      StepFunction = " .. GSEOptions.EQUALS .. "\"Sequential\"" .. Statics.StringReset .. ",\n"
     else
       steps = "      StepFunction = [[" .. GSEOptions.EQUALS .. v.StepFunction .. Statics.StringReset .. "]],\n"
      end
    end
    if not GSE.isEmpty(v.Trinket1) then
      macroversions = macroversions .. "      Trinket1=" .. tostring(v.Trinket1) .. ",\n"
    end
    if not GSE.isEmpty(v.Trinket2) then
      macroversions = macroversions .. "      Trinket2=" .. tostring(v.Trinket2) .. ",\n"
    end
    if not GSE.isEmpty(v.Head) then
      macroversions = macroversions .. "      Head=" .. tostring(v.Head) .. ",\n"
    end
    if not GSE.isEmpty(v.Neck) then
      macroversions = macroversions .. "      Neck=" .. tostring(v.Neck) .. ",\n"
    end
    if not GSE.isEmpty(v.Belt) then
      macroversions = macroversions .. "      Belt=" .. tostring(v.Belt) .. ",\n"
    end
    if not GSE.isEmpty(v.Ring1) then
      macroversions = macroversions .. "      Ring1=" .. tostring(v.Ring1) .. ",\n"
    end
    if not GSE.isEmpty(v.Ring2) then
      macroversions = macroversions .. "      Ring2=" .. tostring(v.Ring2) .. ",\n"
    end

    macroversions = macroversions .. steps
    if not GSE.isEmpty(v.looplimit) then
      macroversions = macroversions .. "      looplimit=" .. GSEOptions.EQUALS .. v.looplimit .. Statics.StringReset .. ",\n"
    end
    macroversions = macroversions .. "      KeyPress={\n"
    for _,p in ipairs(v.KeyPress) do
      macroversions = macroversions .. "        \"" .. p .."\",\n"
    end
    macroversions = macroversions .. "      },\n"
    if table.getn(v.PreMacro) > 0 then
      macroversions = macroversions .. "      PreMacro={\n"
      macroversions = macroversions .. "        \"" .. table.concat(v.PreMacro,"\",\n\"")
      macroversions = macroversions .. "      },\n"
    end
    macroversions = macroversions .. "      \"" .. table.concat(v,"\",\n      \"")
    macroversions = macroversions .. "\",\n"
    if table.getn(v.PostMacro) > 0 then
      macroversions = macroversions .. "      PostMacro={\n"
      macroversions = macroversions .. "        \"" .. table.concat(v.PostMacro,"\",\n\"")
      macroversions = macroversions .. "      },\n"
    end
    macroversions = macroversions .. "      KeyRelease={\n"
    for _,p in ipairs(v.KeyRelease) do
      macroversions = macroversions .. "        \"" .. p .."\",\n"
    end
    macroversions = macroversions .. "      },\n"
    macroversions = macroversions .. "    },\n"
  end
  macroversions = macroversions .. "  },\n"
  --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. sequencemeta .. steps )
  local returnVal = (disabledseq .. "Sequences['" .. GSEOptions.EmphasisColour .. sequenceName .. Statics.StringReset .. "'] = {\n  author=\"" .. GSEOptions.AuthorColour .. (GSE.isEmpty(sequence.Author) and "Unknown Author" or sequence.Author) .. Statics.StringReset .. "\",  \n" .. (GSE.isEmpty(sequence.SpecID) and "-- Unknown SpecID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "  SpecID=" .. GSEOptions.NUMBER  .. sequence.SpecID .. Statics.StringReset ..",\n") ..  sequencemeta)
  if not GSE.isEmpty(sequence.Icon) then
     returnVal = returnVal .. "Icon=" .. GSEOptions.CONCAT .. (tonumber(sequence.Icon) and sequence.Icon or "'".. sequence.Icon .. "'") .. Statics.StringReset ..",\n"
  end
  if not GSE.isEmpty(sequence.Lang) then
    returnVal = returnVal .. "Lang=\"" .. GSEOptions.STANDARDFUNCS .. sequence.lang .. Statics.StringReset .. "\",\n"
  end
  returnVal = returnVal .. macroversions
  returnVal = returnVal .. "},\n"

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

function GSE.FixSequence(sequence)
  if GSE.isEmpty(sequence.PreMacro) then
    sequence.PreMacro = {}
    GSE.PrintDebugMessage("Empty PreMacro", GNOME)
  end
  if GSE.isEmpty(sequence.PostMacro) then
    sequence.PostMacro = {}
    GSE.PrintDebugMessage("Empty PostMacro", GNOME)
  end
  if GSE.isEmpty(sequence.KeyPress) then
    sequence.KeyPress = {}
    GSE.PrintDebugMessage("Empty KeyPress", GNOME)
  end
  if GSE.isEmpty(sequence.KeyRelease) then
    sequence.KeyRelease = {}
    GSE.PrintDebugMessage("Empty KeyRelease", GNOME)
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
    GSE.DeleteMacroStub(k)
  end
end

--- This function is used to clean the loacl sequence library
--TODO Fix this
function GSE.CleanMacroLibrary(forcedelete)
  -- clean out the sequences database except for the current version
  if forcedelete then
    GSELibrary[GSE.GetCurrentClassID()] = nil
    GSELibrary[GSE.GetCurrentClassID()] = {}
  else
    local tempTable = {}
    for name, versiontable in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
      GSE.PrintDebugMessage(L["Testing "] .. name )

      for version, sequence in pairs(versiontable) do
        GSE.PrintDebugMessage(L["Cycle Version "] .. version )
        if sequence.source == Statics.SourceLocal then
          -- Save user created entries.  If they are in a mod dont save them as they will be reloaded next load.
          GSE.PrintDebugMessage("sequence.source == Statics.SourceLocal")
          if GSE.isEmpty(tempTable[name]) then
            tempTable[name] = {}
          end
          -- TODO Fix this to unescape the sequence
          --tempTable[name][version] = GSE.UnEscapeSequence(sequence)
        elseif sequence.source == Statics.SourceTransmission then
          if GSE.isEmpty(tempTable[name]) then
            tempTable[name] = {}
          end
          tempTable[name] = GSE.UnEscapeSequence(sequence)
        else
          GSE.PrintDebugMessage(L["Removing "] .. name .. ":" .. version)
        end
      end
    end
    GSELibrary[GSE.GetCurrentClassID()] = nil
    GSELibrary[GSE.GetCurrentClassID()] = tempTable
  end
end

--- This function resets a button back to its initial setting
function GSE.ResetButtons()
  for k,v in pairs(GSE.UsedSequences) do
    button = _G[k]
    button:SetAttribute("step",1)
    GSE.UpdateIcon(button, true)
    GSE.UsedSequences[k] = nil
  end
end

--- This funciton lists all sequences that are cirrently known
function GSE.ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    if not GSE.isEmpty(sequence.SpecID) then
      local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence.SpecID)
      GSE.PrintDebugMessage(L["Sequence Name: "] .. name)
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSE.PrintDebugMessage(L["No Specialisation information for sequence "] .. name .. L[". Overriding with information for current spec "] .. specname)
      if sequence.SpecID == currentSpecID or string.upper(txt) == specclass then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' .. " " .. GSEOptions.INDENT .. sequence.Talents .. Statics.StringReset .. ' ' .. GSEOptions.EmphasisColour .. specclass .. '|r ' .. specname .. ' ' .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence.Author ..'|r ', GNOME)
      elseif txt == "all" or sequence.SpecID == 0  then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' ..  " " .. sequence.Talents or L["No Help Information "] .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence.Author ..'|r ', GNOME)
      elseif GSELibrary[GSE.GetCurrentClassID()][name].SpecID == currentclassId then
        GSE.Print(GSEOptions.CommandColour .. name ..'|r ' ..  " " .. sequence.Talents .. ' ' .. GSEOptions.AuthorColour .. L["Contributed by: "] .. sequence.Author ..'|r ', GNOME )
      end
    else
      GSE.Print(GSEOptionmmms.CommandColour .. name .. L["|r Incomplete Sequence Definition - This sequence has no further information "] .. GSEOptions.AuthorColour .. L["Unknown Author|r "], GNOME )
    end
  end
  ShowMacroFrame()
end


--- This function updates the button for an existing sequence3
function GSE.UpdateSequence(name,sequence)
  -- print(name)
  -- print(sequence)
  -- print(debugstack())
  local existingbutton = true
  if GSE.isEmpty(_G[name]) then
    GSE.CreateButton(name,sequence)
    existingbutton = false
  end
  local button = _G[name]
  -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
  if GSE.isSpecIDForCurrentClass(GSELibrary[GSE.GetCurrentClassID()][name].SpecID) then
    sequence = GSE.TranslateSequence(sequence, name)
  end
  GSE.FixSequence(sequence)
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(sequence))) .. ']=======])')
  button:SetAttribute("step",1)
  button:SetAttribute('KeyPress',table.concat(GSE.PrepareKeyPress(sequence.KeyPress), "\n") or '' .. '\n')
  GSE.PrintDebugMessage(L["GSUpdateSequence KeyPress updated to: "] .. button:GetAttribute('KeyPress'))
  button:SetAttribute('KeyRelease',table.concat(GSE.PrepareKeyRelease(sequence.KeyRelease), "\n") or '' .. '\n')
  GSE.PrintDebugMessage(L["GSUpdateSequence KeyRelease updated to: "] .. button:GetAttribute('KeyRelease'))
  if existingbutton then
    button:UnwrapScript(button,'OnClick')
  end
  if GSE.IsLoopSequence(sequence) then
    if GSE.isEmpty(sequence.StepFunction) then
      button:WrapScript(button, 'OnClick', format(Statics.OnClick, Statics.LoopSequential))
    else
      button:WrapScript(button, 'OnClick', format(Statics.OnClick, Statics.LoopPriority))
    end
  else
    button:WrapScript(button, 'OnClick', format(Statics.OnClick, GSE.PrepareStepFunction(sequence.StepFunction)))
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

function GSE.PrepareStepFunction(stepper)
  if GSE.isEmpty(stepper) then
    stepper = Statics.Sequential
  end
  if stepper == Statics.Priority then
    return Statics.PriorityImplementation
  elseif stepper == Statics.Sequential then
    return 'step = step % #macros + 1'
  else
    return stepper
  end
end

--- This funciton dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)
  GSE.Print("Button name: "  .. SequenceName)
  GSE.Print(_G[SequenceName]:GetScript('OnClick'))
  GSE.Print("KeyPress" .. _G[SequenceName]:GetAttribute('KeyPress'))
  GSE.Print("KeyRelease" .. _G[SequenceName]:GetAttribute('KeyRelease'))
  GSE.Print(format(Statics.OnClick, GSE.PrepareStepFunction(GSELibrary[GSE.GetCurrentClassID()][SequenceName].MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)].StepFunction) or 'step = step % #macros + 1'))
end

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
  local usoptions = GSE.UnsavedOptions
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

  if seq1.KeyRelease == seq2.KeyRelease and seq1.KeyPress == seq2.KeyPress and seq1.SpecID == seq2.SpecID and seq1.StepFunction == seq2.StepFunction and steps1 == steps2 and seq1.helpTxt == seq2.helpTxt then
    -- we have a match
    match = true
    GSE.PrintDebugMessage(L["We have a perfect match"], GNOME)
  else
    if seq1.SpecID == seq2.SpecID then
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
    icon = (GSE.isempty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].Icon) and Statics.QuestionMark or GSELibrary[GSE.GetCurrentClassID()][sequenceName].Icon)
    GSE.RegisterSequence(SequenceName, icon, globalstub)
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
function GSE.GetSequenceNames()
  local keyset={}
  for k,v in pairs(GSELibrary) do
    local name, _, _ = GetClassInfo(k)
    --keyset[name] = name
    for i,j in pairs(GSELibrary[k]) do
      keyset[k .. "," .. i] = i
    end

  end
  return keyset
end


--- Return the Macro Icon for the specified Sequence
function GSE.GetMacroIcon(classid, sequenceIndex)
  GSE.PrintDebugMessage(L["sequenceIndex: "] .. (GSE.isEmpty(sequenceIndex) and L["No value"] or sequenceIndex), GNOME)
  classid = tonumber(classid)
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSE.isEmpty(a) then
    GSE.PrintDebugMessage(L["Macro Found "] .. a .. L[" with iconid "] .. (GSE.isEmpty(iconid) and L["of no value"] or iconid) .. " " .. (GSE.isEmpty(iconid) and L["with no body"] or c), GNOME)
  else
    GSE.PrintDebugMessage(L["No Macro Found. Possibly different spec for Sequence "] .. sequenceIndex , GNOME)
  end
  local sequence = GSELibrary[classid][sequenceIndex]

  if GSE.isEmpty(sequence.Icon) and GSE.isEmpty(iconid) then
    GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.SpecID, GNOME)
    if sequence.SpecID == 0 then
      return "INV_MISC_QUESTIONMARK"
    else
      local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSE.isEmpty(sequence.SpecID) and GSE.GetCurrentSpecID() or sequence.SpecID))
      GSE.PrintDebugMessage(L["No Sequence Icon setting to "] .. strsub(specicon, 17), GNOME)
      return strsub(specicon, 17)
    end
  elseif GSE.isEmpty(iconid) and not GSE.isEmpty(sequence.Icon) then

      return sequence.Icon
  else
      return iconid
  end
end

--- List addons that GSE knows about that have been disabled
function GSE.ListUnloadedAddons()
  local returnVal = "";
  for k,v in pairs(GSE.UnloadedAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end

--- List addons that GSE knows about that have been enabled
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
  GSE.ImportMacroCollection(Statics.SampleMacros[classID])
end


function GSE.CreateButton(name, sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
  -- button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(sequence))) .. ']=======])')
  -- button:SetAttribute('step', 1)
  -- button:SetAttribute('KeyPress','\n' .. prepareKeyPress(sequence.KeyPress or ''))
  -- GSE.PrintDebugMessage(L["createButton KeyPress: "] .. button:GetAttribute('KeyPress'))
  -- button:SetAttribute('KeyRelease', '\n' .. prepareKeyRelease(sequence.KeyRelease or ''))
  -- GSE.PrintDebugMessage(L["createButton KeyRelease: "] .. button:GetAttribute('KeyRelease'))
  -- if GSE.IsLoopSequence(sequence) then
  --   if GSE.isEmpty(sequence.StepFunction) then
  --     button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopSequential))
  --   else
  --     button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopPriority))
  --   end
  --   if not GSE.isEmpty(sequence.loopstart) then
  --     button:SetAttribute('loopstart', sequence.loopstart)
  --   end
  --   if not GSE.isEmpty(sequence.loopstop) then
  --     button:SetAttribute('loopstop', sequence.loopstop)
  --   end
  --   if not GSE.isEmpty(sequence.looplimit) then
  --     button:SetAttribute('looplimit', sequence.looplimit)
  --   end
  -- else
  --   button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
  -- end
  button.UpdateIcon = GSE.UpdateIcon
end


function GSE.UpdateIcon(self, reset)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = GSELibrary[GSE.GetCurrentClassID()][button].MacroVersions[GSE.GetActiveSequenceVersion(button)][step], false, ''
  for cmd, etc in gmatch(sequence or '', '/(%w+)%s+([^\n]+)') do
    if Statics.CastCmds[strlower(cmd)] then
      local spell, target = SecureCmdOptionParse(etc)
      if not reset then
        GSE.TraceSequence(button, step, spell)
      end
      if spell then
        if GetSpellInfo(spell) then
          SetMacroSpell(button, spell, target)
          foundSpell = true
          break
        elseif notSpell == '' then
          notSpell = spell
        end
      end
    end
  end
  if not foundSpell then SetMacroItem(button, notSpell) end
  if not reset then
    GSE.UsedSequences[button] = true
  end
end

function GSE.PrepareKeyPress(KeyPress)

  local tab = {}
  for k,v in pairs(KeyPress) do
    tab[k] = v
  end
  if GSEOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 0)
    table.insert(tab,"/run sfx=GetCVar(\"Sound_EnableSFX\");")
    table.insert(tab, "/run ers=GetCVar(\"Sound_EnableErrorSpeech\");")
    table.insert(tab, "/console Sound_EnableSFX 0")
    table.insert(tab, "/console Sound_EnableErrorSpeech 0")
  end
  return GSE.UnEscapeTable(tab)
end

function GSE.PrepareKeyRelease(KeyRelease)
  local tab = {}
  for k,v in pairs(KeyRelease) do
    table.insert(tab, v)
  end
  if GSEOptions.requireTarget then
    -- see #20 prevent target hopping
    table.insert(tab, "/stopmacro [@playertarget, noexists]")
  end
  if GSEOptions.use11 then
    table.insert(tab, "/use [combat] 11")
  end
  if GSEOptions.use12 then
    table.insert(tab, "/use [combat] 12")
  end
  if GSEOptions.use13 then
    table.insert(tab, "/use [combat] 13")
  end
  if GSEOptions.use14 then
    table.insert(tab, "/use [combat] 14")
  end
  if GSEOptions.use2 then
    table.insert(tab, "/use [combat] 2")
  end
  if GSEOptions.use1 then
    table.insert(tab, "/use [combat] 1")
  end
  if GSEOptions.use6 then
    table.insert(tab, "/use [combat] 6")
  end
  if GSEOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    table.insert(tab, "/run SetCVar(\"Sound_EnableSFX\",sfx);")
    table.insert(tab, "/run SetCVar(\"Sound_EnableErrorSpeech\",ers);")
  end
  if GSEOptions.hideUIErrors then
    table.insert(tab, "/script UIErrorsFrame:Hide();")
    -- potentially change this to UIErrorsFrame:Hide()
  end
  if GSEOptions.clearUIErrors then
    -- potentially change this to UIErrorsFrame:Clear()
    table.insert(tab, "/run UIErrorsFrame:Clear()")
  end
  return GSE.UnEscapeTable(tab)
end

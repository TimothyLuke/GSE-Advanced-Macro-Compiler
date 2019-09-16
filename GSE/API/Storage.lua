local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

--- Delete a sequence starting with the macro and then the sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
  GSE.DeleteMacroStub(sequenceName)
  GSELibrary[tonumber(classid)][sequenceName] = nil
end

function GSE.CloneSequence(sequence, keepcomments)
  local newsequence = {}

  for k,v in pairs(sequence) do
    newsequence[k] = v
  end

  newsequence.MacroVersions = {}
  for k,v in ipairs(sequence.MacroVersions) do
    newsequence.MacroVersions[tonumber(k)] = GSE.CloneMacroVersion(v, keepcomments)
  end

  return newsequence
end

--- This function clones the Macro Version part of a sequence.
function GSE.CloneMacroVersion(macroversion, keepcomments)
  local retseq = {}
  for k,v in ipairs(macroversion) do
    if GSE.isEmpty(string.find(v, '--', 1, true)) then
      table.insert(retseq, v)
    else
      if not GSE.isEmpty(keepcomments) then
        table.insert(retseq, v)
      else
        GSE.PrintDebugMessage(string.format("comment found %s", v), "Storage")
      end
    end
  end

  for k,v in pairs(macroversion) do
    GSE.PrintDebugMessage(string.format("Processing Key: %s KeyType: %s valuetype: %s", k, type(k), type(v)), "Storage")
    if type(k) == "string" and type(v) == "string" then
      if GSE.isEmpty(string.find(v, '--', 1, true)) then
        retseq[k] = v
      else
        if not GSE.isEmpty(keepcomments) then
          table.insert(retseq, v)
        else
          GSE.PrintDebugMessage(string.format("comment found %s", v), "Storage")
        end
      end
    elseif type(k) == "string" and type(v) == "boolean" then
      retseq[k] = v
    elseif type(k) == "string" and type(v) == "number" then
      retseq[k] = v
    elseif type(k) == "string" and type(v) == "table" then
      retseq[k] = {}
      for i,x in ipairs(v) do
        if GSE.isEmpty(string.find(x, '--', 1, true)) then
          table.insert(retseq[k], x)
        else
          if not GSE.isEmpty(keepcomments) then
            table.insert(retseq[k], x)
          else
            GSE.PrintDebugMessage(string.format("comment found %s", x), "Storage")
          end
        end
      end
    end
  end

  return retseq

end

--- Add a sequence to the library
function GSE.AddSequenceToCollection(sequenceName, sequence, classid)
  local vals = {}
  vals.action = "Save"
  vals.sequencename = sequenceName
  vals.sequence = sequence
  vals.classid = classid
  table.insert(GSE.OOCQueue, vals)
end
--- Add a sequence to the library
function GSE.OOCAddSequenceToCollection(sequenceName, sequence, classid)
  -- check for version flags.
  if sequence.EnforceCompatability then
    if GSE.ParseVersion(sequence.GSEVersion) > (GSE.VersionNumber) then
      GSE.Print(string.format(L["This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."], sequence.GSEVersion))
      GSE.PrintDebugMessage("Macro Version " .. sequence.GSEVersion .. " Required Version: " .. GSE.VersionString , "Storage" )
      return
    end
  end

  GSE.PrintDebugMessage("Attempting to import " .. sequenceName, "Storage" )
  GSE.PrintDebugMessage("Classid not supplied - " .. tostring(GSE.isEmpty(classid)), "Storage" )
  -- Remove Spaces or commas from SequenceNames and replace with _'s
  sequenceName = string.gsub(sequenceName, " ", "_")
  sequenceName = string.gsub(sequenceName, ",", "_")
  sequenceName = string.upper(sequenceName)

  -- Check for collisions
  local found = false
  if (GSE.isEmpty(classid) or classid == 0) and not GSE.isEmpty(sequence.SpecID) then
    classid = tonumber(GSE.GetClassIDforSpec(sequence.SpecID))
  elseif GSE.isEmpty(sequence.SpecID) then
    sequence.SpecID = GSE.GetCurrentClassID()
    classid = GSE.GetCurrentClassID()
  end
  GSE.PrintDebugMessage("Classid now - " .. classid, "Storage" )
  if GSE.isEmpty(GSELibrary[classid]) then
    GSELibrary[classid] = {}
  end
  if not GSE.isEmpty(GSELibrary[classid][sequenceName]) then
      found = true
      GSE.PrintDebugMessage("Macro Exists", "Storage" )
  end
  if found then
    -- Check if modified
    if GSE.isEmpty(GSELibrary[classid][sequenceName].ManualIntervention) then
      -- Macro hasnt been touched.
      GSE.PrintDebugMessage(L["No changes were made to "].. sequenceName, "Storage")
    else
      -- Perform choice.
      -- First check if GUI.
      if GSE.GUI then
        -- Show dialog.
        GSE.GUIShowCompareWindow(sequenceName, classid, sequence)
      else
        GSE.PerformMergeAction(GSEOptions.DefaultImportAction, classid, sequenceName, sequence)
      end
    end
  else
    GSE.PrintDebugMessage("Creating New Macro", "Storage" )
    -- New Sequence
    GSE.PerformMergeAction("REPLACE", classid, sequenceName, sequence)
  end
  if classid == GSE.GetCurrentClassID() or classid == 0 then
     GSE.PrintDebugMessage("As its the current class updating buttons", "Storage" )
     GSE.UpdateSequence(sequenceName, sequence.MacroVersions[sequence.Default])
  end
end


function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
  local vals = {}
  vals.action = "MergeSequence"
  vals.sequencename = sequenceName
  vals.newSequence = newSequence
  vals.classid = classid
  vals.mergeaction = action
  table.insert(GSE.OOCQueue, vals)
end

function GSE.OOCPerformMergeAction(action, classid, sequenceName, newSequence)
  if action == "MERGE" then
    for k,v in ipairs(newSequence.MacroVersions) do
      GSE.PrintDebugMessage("adding ".. k, "Storage")
      table.insert(GSELibrary[classid][sequenceName].MacroVersions, v)
    end
    GSE.PrintDebugMessage("Finished colliding entry entry", "Storage")
    GSE.Print (string.format(L["Extra Macro Versions of %s has been added."], sequenceName), GNOME)
  elseif action == "REPLACE" then
    if GSE.isEmpty(newSequence.Author) then
      -- Set to Unknown Author
      newSequence.Author = "Unknown Author"
    end
    if GSE.isEmpty(newSequence.Talents) then
      -- Set to currentSpecID
      newSequence.Talents = "?,?,?,?,?,?,?"
    end

    GSELibrary[classid][sequenceName] = {}
    GSELibrary[classid][sequenceName] = newSequence
    GSE.Print(sequenceName.. L[" was updated to new version."] , "GSE Storage")
    GSE.PrintDebugMessage("Sequence " .. sequenceName .. " New Entry: " .. GSE.Dump(GSELibrary[classid][sequenceName]), "Storage")
  elseif action == "RENAME" then
    if GSE.isEmpty(newSequence.Author) then
      -- Set to Unknown Author
      newSequence.Author = "Unknown Author"
    end
    if GSE.isEmpty(newSequence.Talents) then
      -- Set to currentSpecID
      newSequence.Talents = "?,?,?,?,?,?,?"
    end

    GSELibrary[classid][sequenceName] = {}
    GSELibrary[classid][sequenceName] = newSequence
    GSE.Print(sequenceName.. L[" was imported as a new macro."] , "GSE Storage")
    GSE.PrintDebugMessage("Sequence " .. sequenceName .. " New Entry: " .. GSE.Dump(GSELibrary[classid][sequenceName]), "Storage")
  else
    GSE.Print(L["No changes were made to "].. sequenceName, GNOME)
  end
  GSELibrary[classid][sequenceName].ManualIntervention = false
  GSE.PrintDebugMessage("Sequence " .. sequenceName .. " Finalised Entry: " .. GSE.Dump(GSELibrary[classid][sequenceName]), "Storage")
  if GSE.GUI then
    local event = {}
    event.action = "openviewer"
    table.insert(GSE.OOCQueue, event)
  end
end


--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    GSE.AddSequenceToCollection(k, v)
  end
end

--- Load a collection of Sequences
function GSE.ImportCompressedMacroCollection(Sequences)
  for k,v in ipairs(Sequences) do
    GSE.ImportSerialisedSequence(v)
  end
end
--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(sequenceName)
  local classid = GSE.GetCurrentClassID()
  if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
    classid = 0
  end
  -- Set to default or 1 if no default
  local vers = 1
  if GSE.isEmpty(GSELibrary[classid][sequenceName]) then
    return
  end
  if not GSE.isEmpty(GSELibrary[classid][sequenceName].Default) then
    vers = GSELibrary[classid][sequenceName].Default
  end
  if not GSE.isEmpty(GSELibrary[classid][sequenceName].Arena) and GSE.inArena then
    vers = GSELibrary[classid][sequenceName].Arena
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].PVP) and GSE.inArena then
    vers = GSELibrary[classid][sequenceName].Arena
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].PVP) and GSE.PVPFlag then
    vers = GSELibrary[classid][sequenceName].PVP
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Raid) and GSE.inRaid then
    vers = GSELibrary[classid][sequenceName].Raid
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Mythic) and GSE.inMythic then
    vers = GSELibrary[classid][sequenceName].Mythic
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Dungeon) and GSE.inDungeon then
    vers = GSELibrary[classid][sequenceName].Dungeon
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Heroic) and GSE.inHeroic then
    vers = GSELibrary[classid][sequenceName].Heroic
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Party) and GSE.inParty then
    vers = GSELibrary[classid][sequenceName].Party
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].Timewalking) and GSE.inTimeWalking then
    vers = GSELibrary[classid][sequenceName].Timewalking
  elseif not GSE.isEmpty(GSELibrary[classid][sequenceName].MythicPlus) and GSE.inMythicPlus then
    vers = GSELibrary[classid][sequenceName].MythicPlus
  end
  return vers
end


--- Add a macro for a sequence and register it in the list of known sequences
function GSE.CreateMacroIcon(sequenceName, icon, forceglobalstub)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  if sequenceIndex > 0 then
    -- Sequence exists, do nothing
    GSE.PrintDebugMessage("Moving on - macro for " .. sequenceName .. " already exists.", GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSEOptions.overflowPersonalMacros and not forceglobalstub then
      GSE.Print(GSEOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSEOptions.overflowPersonalMacros then
      GSE.Print(L["Close to Maximum Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS .. L[" macros per Account.  You currently have "] .. GSEOptions.EmphasisColour .. numAccountMacros .. L["|r. As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    else
      sequenceid = CreateMacro(sequenceName, (GSEOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), GSE.CreateMacroString(sequenceName), (forceglobalstub and false or GSE.SetMacroLocation()) )
    end
  end
end

--- Load a serialised Sequence
function GSE.ImportSerialisedSequence(importstring, createicon)
  local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
  GSE.PrintDebugMessage (string.format("Decomsuccess: %s " , tostring(decompresssuccess)), Statics.SourceTransmission)
  if (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and (type(actiontable[2]) == "table") then
    GSE.PrintDebugMessage (string.format("tablerows: %s   type cell1 %s cell2 %s" ,  table.getn(actiontable), type(actiontable[1]), type(actiontable[2])), Statics.SourceTransmission)
    local seqName = string.upper(actiontable[1])
    GSE.AddSequenceToCollection(seqName, actiontable[2])
    if createicon then
      GSE.CheckMacroCreated(seqName, true)
    end
  else
    GSE.Print(L["Unable to interpret sequence."] , GNOME)
    decompresssuccess = false
  end

  return decompresssuccess
end

--- Load a GSE Sequence Collection from a String
function GSE.ImportSequence(importStr, legacy, createicon)
  local success, returnmessage = false, ""
  importStr = GSE.StripControlandExtendedCodes(importStr)
  local functiondefinition =  GSE.FixQuotes(importStr) .. [===[
  return Sequences
  ]===]

  GSE.PrintDebugMessage (functiondefinition, "Storage")
  local fake_globals = setmetatable({
    Sequences = {},
    }, {__index = _G})
  local func, err = loadstring (functiondefinition, "Storage")
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
        GSE.AddSequenceToCollection(string.upper(k), v)
        if GSE.isEmpty(v.Icon) then
          -- Set a default icon
          v.Icon = GSE.GetDefaultIcon()
        end
        newkey = k
      end
      if createicon then
        GSE.CheckMacroCreated(string.upper(newkey), true)
      end
      success = true
    end
  else
    GSE.Print (err, GNOME)
    returnmessage = err

  end
  return success, returnmessage
end

function GSE.ReloadSequences()
  GSE.PrintDebugMessage("Reloading Sequences")
  for name, sequence in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    GSE.UpdateSequence(name, sequence.MacroVersions[GSE.GetActiveSequenceVersion(name)])
  end
  if GSEOptions.CreateGlobalButtons then
    if not GSE.isEmpty(GSELibrary[0]) then
      for name, sequence in pairs(GSELibrary[0]) do
        GSE.UpdateSequence(name, sequence.MacroVersions[GSE.GetActiveSequenceVersion(name)])
      end
    end
  end
end

function GSE.PrepareLogout(deletenonlocalmacros)
  GSE.CleanMacroLibrary(deletenonlocalmacros)
  if GSEOptions.deleteOrphansOnLogout then
    GSE.CleanOrphanSequences()
  end
end

function GSE.IsLoopSequence(sequence)
  local loopcheck = false
  if not GSE.isEmpty(sequence.PreMacro) then
    if type(sequence.PreMacro) == "table" then
      if table.getn(sequence.PreMacro) > 0 then
        loopcheck = true
        GSE.PrintDebugMessage("Setting Loop Check True due to PreMacro", "Storage")
      end
    end
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    if type(sequence.Postmacro) == "table" then
      if table.getn(sequence.PostMacro) > 0 then
        loopcheck = true
        GSE.PrintDebugMessage("Setting Loop Check True due to PreMacro", "Storage")
      end
    end
  end
  if not GSE.isEmpty(sequence.LoopLimit) then
    loopcheck = true
    GSE.PrintDebugMessage("Setting Loop Check True due to LoopLimit", "Storage")
  end
  return loopcheck
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequence(sequence, sequenceName, verbose, mode, hideversion)
  local returnVal = ""
  if verbose then
    GSE.PrintDebugMessage("ExportSequence Sequence Name: " .. sequenceName, "Storage")
    local disabledseq = ""
    local sequencemeta = "  Talents = \"" .. GSEOptions.INDENT .. (GSE.isEmpty(sequence.Talents) and "?,?,?,?,?,?,?" or sequence.Talents) .. Statics.StringReset .. "\",\n"
    if not GSE.isEmpty(sequence.Helplink) then
      sequencemeta = sequencemeta .. "  Helplink = \"" .. GSEOptions.INDENT .. sequence.Helplink .. Statics.StringReset .. "\",\n"
    end
    if not GSE.isEmpty(sequence.Help) then
      sequencemeta = sequencemeta .. "  Help = [[" .. GSEOptions.INDENT .. sequence.Help .. Statics.StringReset .. "]],\n"
    end
    sequencemeta = sequencemeta .. "  Default=" ..sequence.Default .. ",\n"
    if not GSE.isEmpty(sequence.Raid) then
      sequencemeta = sequencemeta .. "  Raid=" ..sequence.Raid .. ",\n"
    end
    if not GSE.isEmpty(sequence.PVP) then
      sequencemeta = sequencemeta .. "  PVP=" ..sequence.PVP .. ",\n"
    end
    if not GSE.isEmpty(sequence.Dungeon) then
      sequencemeta = sequencemeta .. "  Dungeon=" ..sequence.Dungeon .. ",\n"
    end
    if not GSE.isEmpty(sequence.Heroic) then
      sequencemeta = sequencemeta .. "  Heroic=" ..sequence.Heroic .. ",\n"
    end
    if not GSE.isEmpty(sequence.Mythic) then
      sequencemeta = sequencemeta .. "  Mythic=" ..sequence.Mythic .. ",\n"
    end
    if not GSE.isEmpty(sequence.Arena) then
      sequencemeta = sequencemeta .. "  Arena=" ..sequence.Arena .. ",\n"
    end
    if not GSE.isEmpty(sequence.Timewalking) then
      sequencemeta = sequencemeta .. "  Timewalking=" ..sequence.Timewalking .. ",\n"
    end
    if not GSE.isEmpty(sequence.MythicPlus) then
      sequencemeta = sequencemeta .. "  MythicPlus=" ..sequence.MythicPlus .. ",\n"
    end
    if not GSE.isEmpty(sequence.Party) then
      sequencemeta = sequencemeta .. "  Party=" ..sequence.Party .. ",\n"
    end
    local macroversions = "  MacroVersions = {\n"
    for k,v in pairs(sequence.MacroVersions) do
      local outputversion =  GSE.CleanMacroVersion(v)
      macroversions = macroversions .. "    [" .. k .. "] = {\n"

      local steps = "      StepFunction = " .. GSEOptions.INDENT .. "\"Sequential\"" .. Statics.StringReset .. ",\n" -- Set to this as the default if its blank.

      if not GSE.isEmpty(v.StepFunction) then
        if  v.StepFunction == Statics.PriorityImplementation then
          steps = "      StepFunction = " .. GSEOptions.INDENT .. "\"Priority\"" .. Statics.StringReset .. ",\n"
        elseif  v.StepFunction == Statics.Random then
          steps = "      StepFunction = " .. GSEOptions.INDENT .. "\"Random\"" .. Statics.StringReset .. ",\n"
        elseif v.StepFunction == Statics.Priority then
         steps = "      StepFunction = " .. GSEOptions.INDENT .. "\"Priority\"" .. Statics.StringReset .. ",\n"
       else
         steps = "      StepFunction = \"" .. GSEOptions.INDENT .. v.StepFunction .. Statics.StringReset .. "\",\n"
        end
      end
      if not GSE.isEmpty(outputversion.Combat) then
        macroversions = macroversions .. "     Combat=" .. tostring(outputversion.Combat) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Trinket1) then
        macroversions = macroversions .. "      Trinket1=" .. tostring(outputversion.Trinket1) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Trinket2) then
        macroversions = macroversions .. "      Trinket2=" .. tostring(outputversion.Trinket2) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Head) then
        macroversions = macroversions .. "      Head=" .. tostring(outputversion.Head) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Neck) then
        macroversions = macroversions .. "      Neck=" .. tostring(outputversion.Neck) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Belt) then
        macroversions = macroversions .. "      Belt=" .. tostring(outputversion.Belt) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Ring1) then
        macroversions = macroversions .. "      Ring1=" .. tostring(outputversion.Ring1) .. ",\n"
      end
      if not GSE.isEmpty(outputversion.Ring2) then
        macroversions = macroversions .. "      Ring2=" .. tostring(outputversion.Ring2) .. ",\n"
      end

      macroversions = macroversions .. steps
      if not GSE.isEmpty(outputversion.LoopLimit) then
        macroversions = macroversions .. "      LoopLimit=" .. GSEOptions.EQUALS .. outputversion.LoopLimit .. Statics.StringReset .. ",\n"
      end
      if not GSE.isEmpty(outputversion.KeyPress) then
        macroversions = macroversions .. "      KeyPress={\n"
        for _,p in ipairs(outputversion.KeyPress) do
          local results = GSE.TranslateString(p, mode, true)
          if not GSE.isEmpty(results)then
            macroversions = macroversions .. "        \"" .. results .."\",\n"
          end
        end
        macroversions = macroversions .. "      },\n"
      end
      if not GSE.isEmpty(outputversion.PreMacro) then
        macroversions = macroversions .. "      PreMacro={\n"
        for _,p in ipairs(outputversion.PreMacro) do
          local results = GSE.TranslateString(p, mode, true)
          if not GSE.isEmpty(results)then
            macroversions = macroversions .. "        \"" .. results .."\",\n"
          end
        end
        macroversions = macroversions .. "      },\n"
      end
      for _,p in ipairs(v) do
        local results = GSE.TranslateString(p, mode, true)
        if not GSE.isEmpty(results)then
          macroversions = macroversions .. "        \"" .. results .."\",\n"
        end
      end
      if not GSE.isEmpty(outputversion.PostMacro) then
        macroversions = macroversions .. "      PostMacro={\n"
        for _,p in ipairs(outputversion.PostMacro) do
          local results = GSE.TranslateString(p, mode, true)
          if not GSE.isEmpty(results)then
            macroversions = macroversions .. "        \"" .. results .."\",\n"
          end
        end
        macroversions = macroversions .. "      },\n"
      end
      if not GSE.isEmpty(outputversion.KeyRelease) then
        macroversions = macroversions .. "      KeyRelease={\n"
        for _,p in ipairs(outputversion.KeyRelease) do
          local results = GSE.TranslateString(p, mode, true)
          if not GSE.isEmpty(results)then
            macroversions = macroversions .. "        \"" .. results .."\",\n"
          end
        end
        macroversions = macroversions .. "      },\n"
      end
      macroversions = macroversions .. "    },\n"
    end
    macroversions = macroversions .. "  },\n"
    --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. sequencemeta .. steps )
    returnVal = "Sequences['" .. GSEOptions.EmphasisColour .. sequenceName .. Statics.StringReset .. "'] = {\n"
    if not hideversion then
      returnVal = returnVal .. GSEOptions.CONCAT .. "-- " .. string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. Statics.StringReset .. "\n"
    end
    returnVal = returnVal .. "  Author=\"" .. GSEOptions.AuthorColour .. (GSE.isEmpty(sequence.Author) and "Unknown Author" or sequence.Author) .. Statics.StringReset .. "\",\n" .. (GSE.isEmpty(sequence.SpecID) and "-- Unknown SpecID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "  SpecID=" .. GSEOptions.NUMBER  .. sequence.SpecID .. Statics.StringReset ..",\n") ..  sequencemeta
    if not GSE.isEmpty(sequence.Icon) then
       returnVal = returnVal .. "  Icon=" .. GSEOptions.CONCAT .. (tonumber(sequence.Icon) and sequence.Icon or "'".. sequence.Icon .. "'") .. Statics.StringReset ..",\n"
    end
    returnVal = returnVal .. macroversions
    returnVal = returnVal .. "}\n"
  else
    returnVal = returnVal .. GSE.EncodeMessage({sequenceName, sequence})
  end

  return returnVal
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
  if GSE.isEmpty(sequence.StepFunction) then
    sequence.StepFunciton = Statics.Sequential
    GSE.PrintDebugMessage("Empty StepFunction", GNOME)
  end
  if not GSE.isEmpty(sequence.Target) then
    sequence.Target = nil
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
      if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][mname]) then
        found = true
      end
      if not GSE.isEmpty(GSELibrary[0][mname]) then
        found = true
      end

      if not found then
        -- Check if body is a gs one and delete the orphan
        todelete[mname] = true
      end
    end
  end
  for k,_ in pairs(todelete) do
    GSE.DeleteMacroStub(k)
  end
end

--- This function is used to clean the local sequence library
function GSE.CleanMacroLibrary(forcedelete)
  -- Clean out the sequences database except for the current version
  if forcedelete then
    GSELibrary[GSE.GetCurrentClassID()] = nil
    GSELibrary[GSE.GetCurrentClassID()] = {}
  end
end

--- This function resets a gsebutton back to its initial setting
function GSE.ResetButtons()
  for k,v in pairs(GSE.UsedSequences) do
    local gsebutton = _G[k]
    if gsebutton:GetAttribute("combatreset") == true then
      gsebutton:SetAttribute("step",1)
      GSE.UpdateIcon(gsebutton, true)
      GSE.UsedSequences[k] = nil
    end
  end
end

--- This functions schedules an update to a sequence in the OOCQueue.
function GSE.UpdateSequence(name, sequence)
  local vals = {}
  vals.action = "UpdateSequence"
  vals.name = name
  vals.macroversion = sequence
  table.insert(GSE.OOCQueue, vals)
end



--- This function updates the button for an existing sequence.  It is called from the OOC queue
function GSE.OOCUpdateSequence(name,sequence)
  if GSE.isEmpty(sequence) then
    return
  end
  if GSE.isEmpty(name) then
    return
  end
  if pcall(GSE.CheckSequence, sequence) then
    sequence = GSE.CleanMacroVersion(sequence)
    GSE.FixSequence(sequence)
    tempseq = GSE.CloneMacroVersion(sequence)

    local existingbutton = true
    if GSE.isEmpty(_G[name]) then
      GSE.CreateButton(name,tempseq)
      existingbutton = false
    end
    local gsebutton = _G[name]
    -- Only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
    tempseq = GSE.TranslateSequence(tempseq, name, "STRING")
    tempseq = GSE.UnEscapeSequence(tempseq)
    local executionseq = {}
    local pmcount = 0
    if not GSE.isEmpty(tempseq.PreMacro) then
      pmcount = table.getn(tempseq.PreMacro) + 1
      gsebutton:SetAttribute('loopstart', pmcount)
      for k,v in ipairs(tempseq.PreMacro) do
        table.insert(executionseq, v)
      end

    end

    for k,v in ipairs(tempseq) do
      table.insert(executionseq, v)
    end

    gsebutton:SetAttribute('loopstop', table.getn(executionseq))

    if not GSE.isEmpty(tempseq.PostMacro) then
      for k,v in ipairs(tempseq.PostMacro) do
        table.insert(executionseq, v)
      end

    end

    GSE.SequencesExec[name] = executionseq

    gsebutton:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(executionseq)) .. ']=======])')
    gsebutton:SetAttribute("step",1)
    gsebutton:SetAttribute('KeyPress',table.concat(GSE.PrepareKeyPress(tempseq), "\n") or '' .. '\n')
    GSE.PrintDebugMessage("GSUpdateSequence KeyPress updated to: " .. gsebutton:GetAttribute('KeyPress'))
    gsebutton:SetAttribute('KeyRelease',table.concat(GSE.PrepareKeyRelease(tempseq), "\n") or '' .. '\n')
    GSE.PrintDebugMessage("GSUpdateSequence KeyRelease updated to: " .. gsebutton:GetAttribute('KeyRelease'))
    if existingbutton then
      gsebutton:UnwrapScript(gsebutton,'OnClick')
    end

    if (GSE.isEmpty(sequence.Combat) and GSEOptions.resetOOC ) or sequence.Combat then
      gsebutton:SetAttribute("combatreset", true)
    else
      gsebutton:SetAttribute("combatreset", true)
    end
    gsebutton:WrapScript(gsebutton, 'OnClick', GSE.PrepareOnClickImplementation(sequence))
    if not GSE.isEmpty(sequence.LoopLimit) then
      gsebutton:SetAttribute('looplimit', sequence.LoopLimit)
    end
  else
    GSE.Print(string.format(L["There is an issue with sequence %s.  It has not been loaded to prevent the mod from failing."], name))
  end

end

function GSE.PrepareStepFunction(stepper, looper)
  local retvalue = ""
  if looper then
    if GSE.isEmpty(stepper) or stepper == Statics.Sequential then
      retvalue = Statics.LoopSequentialImplementation
    elseif stepper == Statics.Random then
      retvalue = Statics.LoopRandomImplementation
    else
      retvalue = Statics.LoopPriorityImplementation
    end
  else
    if GSE.isEmpty(stepper) or stepper == Statics.Sequential then
      retvalue = 'step = step % #macros + 1'
    elseif stepper == Statics.Priority then
      retvalue = Statics.PriorityImplementation
    elseif stepper == Statics.Random then
      retvalue = Statics.RandomImplementation
    else
      retvalue = stepper
    end
  end
  return retvalue
end

--- This function dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)
  local targetreset = ""
  local looper = GSE.IsLoopSequence(GSELibrary[GSE.GetCurrentClassID()][SequenceName].MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)])
  if GSELibrary[GSE.GetCurrentClassID()][SequenceName].MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)].Target then
    targetreset = Statics.TargetResetImplementation
  end
  GSE.Print("====================================\nStart GSE Button Dump\n====================================")
  GSE.Print("Button name: "  .. SequenceName)
  GSE.Print("KeyPress" .. _G[SequenceName]:GetAttribute('KeyPress'))
  GSE.Print("KeyRelease" .. _G[SequenceName]:GetAttribute('KeyRelease'))
  GSE.Print("LoopMacro?" .. tostring(looper))
  GSE.Print("====================================\nStepFunction\n====================================")
  GSE.Print(GSE.PrepareOnClickImplementation(GSELibrary[GSE.GetCurrentClassID()][SequenceName].MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)]))
  GSE.Print("====================================\nEnd GSE Button Dump\n====================================")
end


--- Compares two sequences and return a boolean if they match.  If they do not
--    match then it will print an element by element comparison.  This comparison
--    ignores version, authorversion, source, helpTxt elements as these are not
--    needed for the execution of the macro but are more for help and versioning.
function GSE.CompareSequence(seq1,seq2)
  GSE.FixSequence(seq1)
  GSE.FixSequence(seq2)
  local match = true
  local steps1 = table.concat(seq1, "")
  local steps2 = table.concat(seq2, "")

  if seq1.SpecID == seq2.SpecID then
    GSE.PrintDebugMessage("Matching specID", GNOME)
  else
    GSE.PrintDebugMessage("Different specID", GNOME)
    match = false
  end
  if seq1.StepFunction == seq2.StepFunction then
    GSE.PrintDebugMessage("Matching StepFunction", GNOME)
  else
    GSE.PrintDebugMessage("Different StepFunction", GNOME)
    match = false
  end
  if table.concat(seq1.KeyPress, "") ==  table.concat(seq2.KeyPress, "") then
    GSE.PrintDebugMessage("Matching KeyPress", GNOME)
  else
    GSE.PrintDebugMessage("Different KeyPress", GNOME)
    match = false
  end
  if steps1 == steps2 then
    GSE.PrintDebugMessage("Same Sequence Steps", GNOME)
  else
    GSE.PrintDebugMessage("Different Sequence Steps", GNOME)
    match = false
  end
  if table.concat(seq1.KeyRelease) == table.concat(seq2.KeyRelease) then
    GSE.PrintDebugMessage("Matching KeyRelease", GNOME)
  else
    GSE.PrintDebugMessage("Different KeyRelease", GNOME)
    match = false
  end
  if table.concat(seq1.PreMacro) == table.concat(seq2.PreMacro) then
    GSE.PrintDebugMessage("Matching PreMacro", GNOME)
  else
    GSE.PrintDebugMessage("Different PreMacro", GNOME)
    match = false
  end
  if table.concat(seq1.PostMacro) == table.concat(seq2.PostMacro) then
    GSE.PrintDebugMessage("Matching PostMacro", GNOME)
  else
    GSE.PrintDebugMessage("Different PostMacro", GNOME)
    match = false
  end

  if not GSE.compareValues(seq1.Head, seq2.Head, "Head") then
    match = false
  end

  if not GSE.compareValues(seq1.Trinket1, seq2.Trinket1, "Trinket1") then
    match = false
  end

  if not GSE.compareValues(seq1.Trinket2, seq2.Trinket2, "Trinket2") then
    match = false
  end
  if not GSE.compareValues(seq1.Ring1, seq2.Ring1, "Ring1") then
    match = false
  end
  if not GSE.compareValues(seq1.Ring2, seq2.Ring2, "Ring2") then
    match = false
  end
  if not GSE.compareValues(seq1.Neck, seq2.Neck, "Neck") then
    match = false
  end
  if not GSE.compareValues(seq1.Belt, seq2.Belt, "Belt") then
    match = false
  end
  if not GSE.compareValues(seq1.LoopLimit, seq2.LoopLimit, "LoopLimit") then
    match = false
  end

  return match
end


--- Compares the values of a sequence used in GSE.CompareSequence
function GSE.compareValues(a, b, description)
  local match = true
  if not GSE.isEmpty(a) then
    if GSE.isEmpty(b) then
      GSE.PrintDebugMessage(description .." in Sequence 1 but not in Sequence 2", GNOME)
      match = false
    else
      if a == b then
        GSE.PrintDebugMessage("Matching " .. description, GNOME)
      else
        GSE.PrintDebugMessage("Different  ".. description .. " Values", GNOME)
        match = false
      end
    end
  else
    if not GSE.isEmpty(a) then
      GSE.PrintDebugMessage(description .. " in Sequence 2 but not in Sequence 1", GNOME)
      match = false
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


function GSE.CreateMacroString(macroname)
  return string.format("#showtooltip\n/click [button:2] %s RightButton; [button:3] %s MiddleButton; [button:4] %s Button4; [button:5] %s Button5; %s", macroname, macroname, macroname, macroname, macroname)
end

function GSE.UpdateMacroString()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
  for macid = 1, maxmacros do
    local mname, mtexture, mbody = GetMacroInfo(macid)
    if not GSE.isEmpty(mname) then
      if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][mname]) then
        EditMacro(macid, nil, nil,  GSE.CreateMacroString(mname))
        GSE.PrintDebugMessage(string.format("Updating macro %s to %s", mname, GSE.CreateMacroString(mname)))
      end
      if not GSE.isEmpty(GSELibrary[0]) then
        if not GSE.isEmpty(GSELibrary[0][mname]) then
          EditMacro(macid, nil, nil,  GSE.CreateMacroString(mname))
          GSE.PrintDebugMessage(string.format("Updating macro %s to %s", mname, GSE.CreateMacroString(mname)))
        end
      end
    end

  end
end

--- Add a Create Macro to the Out of Combat Queue
function GSE.CheckMacroCreated(SequenceName, create)
  local vals = {}
  vals.action = "CheckMacroCreated"
  vals.sequencename = SequenceName
  vals.create = create
  table.insert(GSE.OOCQueue, vals)
end

--- Check if a macro has been created and if the create flag is true and the macro hasn't been created, then create it.
function GSE.OOCCheckMacroCreated(SequenceName, create)
  local found = false
  local classid = GSE.GetCurrentClassID()
  if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][SequenceName]) then
    classid = 0
  end
  local macroIndex = GetMacroIndexByName(SequenceName)
  if macroIndex and macroIndex ~= 0 then
    found = true
    if create then
      EditMacro(macroIndex, nil, nil,  GSE.CreateMacroString(SequenceName))
    end
  else
    if create then
      GSE.CreateMacroIcon(SequenceName, Statics.QuestionMark)
      found = true
    end
  end
  return found
end

--- This removes a macro Stub.
function GSE.DeleteMacroStub(sequenceName)
  local mname, _, mbody = GetMacroInfo(sequenceName)
  if mname == sequenceName then
    trimmedmbody = mbody:gsub("[^%w ]", "")
    compar = GSE.CreateMacroString(mname)
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
    if GSE.isEmpty(GSEOptions.filterList) then
      GSEOptions.filterList = {}
      GSEOptions.filterList[Statics.Spec] = true
      GSEOptions.filterList[Statics.Class] = true
      GSEOptions.filterList[Statics.All] = false
      GSEOptions.filterList[Statics.Global] = true
    end
    if GSEOptions.filterList[Statics.All] or k == GSE.GetCurrentClassID()  then
      for i,j in pairs(GSELibrary[k]) do
        local disable = 0
        if j.DisableEditor then
          disable = 1
        end
        local keyLabel = k .. "," .. i .. "," .. disable
        if k == GSE.GetCurrentClassID() and GSEOptions.filterList["Class"] then
          keyset[keyLabel] = i
        elseif k == GSE.GetCurrentClassID() and not GSEOptions.filterList["Class"] then
          if j.SpecID == GSE.GetCurrentSpecID() or j.SpecID == GSE.GetCurrentClassID() then
            keyset[keyLabel] = i
          end
        else
          keyset[keyLabel] = i
        end
      end
    else
      if k == 0 and GSEOptions.filterList[Statics.Global] then
        for i,j in pairs(GSELibrary[k]) do
          local disable = 0
          if j.DisableEditor then
            disable = 1
          end
          local keyLabel = k .. "," .. i .. "," .. disable
          keyset[keyLabel] = i
        end
      end
    end
  end

  return keyset
end


--- Return the Macro Icon for the specified Sequence
function GSE.GetMacroIcon(classid, sequenceIndex)
  classid = tonumber(classid)
  GSE.PrintDebugMessage("sequenceIndex: " .. (GSE.isEmpty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
  classid = tonumber(classid)
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSE.isEmpty(a) then
    GSE.PrintDebugMessage("Macro Found " .. a .. " with iconid " .. (GSE.isEmpty(iconid) and "of no value" or iconid) .. " " .. (GSE.isEmpty(iconid) and L["with no body"] or c), GNOME)
  else
    GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex , GNOME)
    return GSEOptions.DefaultDisabledMacroIcon
  end

  local sequence = GSELibrary[classid][sequenceIndex]
  if GSE.isEmpty(sequence) then
    GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex , GNOME)
    return GSEOptions.DefaultDisabledMacroIcon
  end
  if GSE.isEmpty(sequence.Icon) and GSE.isEmpty(iconid) then
    GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.SpecID, GNOME)
    if sequence.SpecID == 0 then
      return "INV_MISC_QUESTIONMARK"
    else
      local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSE.isEmpty(sequence.SpecID) and GSE.GetCurrentSpecID() or sequence.SpecID))
      GSE.PrintDebugMessage("No Sequence Icon setting to " .. strsub(specicon, 17), GNOME)
      return strsub(specicon, 17)
    end
  elseif GSE.isEmpty(iconid) and not GSE.isEmpty(sequence.Icon) then

      return sequence.Icon
  else
      return iconid
  end
end



--- This converts a legacy GS/GSE1 sequence to a new GSE2
function GSE.ConvertLegacySequence(sequence)
  local GSStaticPriority = Statics.PriorityImplementation
  local returnSequence = {}
  if not GSE.isEmpty(sequence.specID) then
    returnSequence.SpecID = sequence.specID
  end
  if not GSE.isEmpty(sequence.author) then
    returnSequence.Author = sequence.author
  end
  if not GSE.isEmpty(sequence.helpTxt) then
    returnSequence.Help = sequence.helpTxt
  end
  returnSequence.Default = 1
  returnSequence.MacroVersions = {}
  returnSequence.MacroVersions[1] = {}
  if not GSE.isEmpty(sequence.PreMacro) then
    returnSequence.MacroVersions[1].KeyPress = GSE.SplitMeIntolines(sequence.PreMacro)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    returnSequence.MacroVersions[1].KeyRelease = GSE.SplitMeIntolines(sequence.PostMacro)
  end
  if not GSE.isEmpty(sequence.StepFunction) then
    if sequence.StepFunction == GSStaticPriority then
      returnSequence.MacroVersions[1].StepFunction = Statics.Priority
    else
      GSE.Print(L["The Custom StepFunction Specified is not recognised and has been ignored."], GNOME)
      returnSequence.MacroVersions[1].StepFunction = Statics.Sequential
    end
  else
    returnSequence.MacroVersions[1].StepFunction = Statics.Sequential
  end
  if not GSE.isEmpty(sequence.icon) then
    returnSequence.Icon = sequence.icon
  end
  local macroversion = returnSequence.MacroVersions[1]
  local loopstart = tonumber(sequence.loopstart) or 1
  local loopstop = tonumber(sequence.loopstop) or table.getn(sequence)
  if loopstart > 1 then
    macroversion.PreMacro = {}
  end
  if loopstop < table.getn(sequence) then
    macroversion.PostMacro = {}
  end
  for k,v in ipairs(sequence) do
    if k < loopstart then
      table.insert(macroversion.PreMacro, v)
    elseif k > loopstop then
      table.insert(macroversion.PostMacro, v)
    else
      table.insert(macroversion, v)
    end
  end
  return returnSequence
end

--- Load in the sample macros for the current class.
function GSE.LoadSampleMacros(classID)
  if not GSE.isEmpty() then
    GSE.ImportCompressedMacroCollection(Statics.SampleMacros[classID])
    GSE.Print(L["The Sample Macros have been reloaded."])
  else
    GSE.Print(L["No Sample Macros are available yet for this class."])
  end
end


function GSE.CreateButton(name, sequence)
  local gsebutton = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  gsebutton:SetAttribute('type', 'macro')
  gsebutton.UpdateIcon = GSE.UpdateIcon
end


function GSE.UpdateIcon(self, reset)
  local step = self:GetAttribute('step') or 1
  local gsebutton = self:GetName()
  local executionseq = GSE.SequencesExec[gsebutton]
  local commandline, foundSpell, notSpell = executionseq[step], false, ''
  for cmd, etc in gmatch(commandline or '', '/(%w+)%s+([^\n]+)') do
    if Statics.CastCmds[strlower(cmd)] or strlower(cmd) == "castsequence" then
      local spell, target = SecureCmdOptionParse(etc)
      if not reset then
        GSE.TraceSequence(gsebutton, step, spell)
      end
      if spell then
        if GetSpellInfo(spell) then
          SetMacroSpell(gsebutton, spell, target)
          foundSpell = true
          break
        elseif notSpell == '' then
          notSpell = spell
        end
      end
    end
  end
  if not foundSpell then SetMacroItem(gsebutton, notSpell) end
  if not reset then
    GSE.UsedSequences[gsebutton] = true
  end
end

function GSE.PrepareKeyPress(sequence)

  local tab = {}
  if GSEOptions.requireTarget then

    -- See #20 prevent target hopping
    table.insert(tab, "/stopmacro [@playertarget, noexists]")
  end

  if GSEOptions.hideSoundErrors then
    -- Potentially change this to SetCVar("Sound_EnableSFX", 0)
    table.insert(tab,"/run sfx=GetCVar(\"Sound_EnableSFX\");")
    table.insert(tab, "/run ers=GetCVar(\"Sound_EnableErrorSpeech\");")
    table.insert(tab, "/console Sound_EnableSFX 0")
    table.insert(tab, "/console Sound_EnableErrorSpeech 0")
  end
  if not GSE.isEmpty(sequence.KeyPress) then
    for k,v in pairs(sequence.KeyPress) do
      table.insert(tab, v)
    end
  end

  return tab
end

function GSE.PrepareKeyRelease(sequence)
  local tab = {}
  if GSEOptions.requireTarget then
    -- See #20 prevent target hopping
    table.insert(tab, "/stopmacro [@playertarget, noexists]")
  end
  if not GSE.isEmpty(sequence.KeyRelease) then
    for k,v in pairs(sequence.KeyRelease) do
      table.insert(tab, v)
    end
  end
  if sequence.Ring1 or (sequence.Ring1 == nil and GSEOptions.use11) then
    table.insert(tab, "/use [combat,nochanneling] 11")
  end
  if sequence.Ring2 or (sequence.Ring2 == nil and GSEOptions.use12) then
    table.insert(tab, "/use [combat,nochanneling] 12")
  end
  if sequence.Trinket1 or (sequence.Trinket1 == nil and GSEOptions.use13) then
    table.insert(tab, "/use [combat,nochanneling] 13")
  end
  if sequence.Trinket2 or (sequence.Trinket2 == nil and GSEOptions.use14) then
    table.insert(tab, "/use [combat,nochanneling] 14")
  end
  if sequence.Neck or (sequence.Neck == nil and GSEOptions.use2) then
    table.insert(tab, "/use [combat,nochanneling] 2")
  end
  if sequence.Head or (sequence.Head == nil and GSEOptions.use1) then
    table.insert(tab, "/use [combat,nochanneling] 1")
  end
  if sequence.Belt or (sequence.Belt == nil and GSEOptions.use6) then
    table.insert(tab, "/use [combat,nochanneling] 6")
  end
  if GSEOptions.hideSoundErrors then
    -- Potentially change this to SetCVar("Sound_EnableSFX", 1)
    table.insert(tab, "/run SetCVar(\"Sound_EnableSFX\",sfx);")
    table.insert(tab, "/run SetCVar(\"Sound_EnableErrorSpeech\",ers);")
  end
  if GSEOptions.hideUIErrors then
    table.insert(tab, "/script UIErrorsFrame:Hide();")
    -- Potentially change this to UIErrorsFrame:Hide()
  end
  if GSEOptions.clearUIErrors then
    -- Potentially change this to UIErrorsFrame:Clear()
    table.insert(tab, "/run UIErrorsFrame:Clear()")
  end
  return tab
end

--- Takes a collection of Sequences and returns a list of names
function GSE.GetSequenceNamesFromLibrary(library)
  local sequenceNames = {}
  for k,_ in pairs(library) do
    table.insert(sequenceNames, k)
  end
  return sequenceNames
end

--- Moves Macros hidden in Global Macros to their appropriate class.
function GSE.MoveMacroToClassFromGlobal()
  for k,v in pairs(GSELibrary[0]) do
    if not GSE.isEmpty(v.SpecID) and tonumber(v.SpecID) > 0 then
      if v.SpecID < 12 then
        GSELibrary[v.SpecID][k] = v
        GSE.Print(string.format(L["Moved %s to class %s."], k, Statics.SpecIDList[v.SpecID]))
        GSELibrary[0][k] = nil
      else
        GSELibrary[GSE.GetClassIDforSpec(v.SpecID)][k] = v
        GSE.Print(string.format(L["Moved %s to class %s."], k, Statics.SpecIDList[GSE.GetClassIDforSpec(v.SpecID)]))
        GSELibrary[0][k] = nil
      end
    end
  end
  GSE.ReloadSequences()
end

--- This function returns in addition to the stepfunction for the KeyBind to Reset a sequence
function GSE.GetMacroResetImplementation()
  local activemods = {}
  local returnstring = ""
  local flagactive = false

  -- Extra null check just in case.
  if GSE.isEmpty(GSEOptions.MacroResetModifiers) then
    GSE.resetMacroResetModifiers()
  end

  for k,v in pairs(GSEOptions.MacroResetModifiers) do
    if v == true then
      flagactive = true
      if string.find(k, "Button") then
        table.insert(activemods, "GetMouseButtonClicked() == \"".. k .. "\"")
      else
        table.insert (activemods, "Is" .. k .. "KeyDown() == true" )
      end
    end
  end
  if flagactive then
    returnstring = string.format(Statics.MacroResetSkeleton, table.concat(activemods, " and "))
  end
  return returnstring

end

--- This function finds a macro by name.  It checks current class first then global
function GSE.FindMacro(sequenceName)
  local returnVal = {}
  if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
    returnVal = GSELibrary[GSE.GetCurrentClassID()][sequenceName]
  elseif not GSE.isEmpty(GSELibrary[0][sequenceName]) then
    returnVal = GSELibrary[0][sequenceName]
  end
  return returnVal
end

--- This funcion returns the actual onclick implementation
function GSE.PrepareOnClickImplementation(sequence)
  local returnstring = (GSEOptions.DebugPrintModConditionsOnKeyPress and Statics.PrintKeyModifiers or "" )
  returnstring = returnstring .. GSE.GetMacroResetImplementation()
  returnstring = returnstring  .. format(Statics.OnClick, GSE.PrepareStepFunction(sequence.StepFunction,  GSE.IsLoopSequence(sequence)))
  return returnstring
end

--- This function checks a sequence for mod breaking errors.  Use this with a pcall
function GSE.CheckSequence(sequence)

  for k,v in ipairs(sequence) do
    if type(v) == "table" then
      GSE.PrintDebugMessage("Macro corrupt at ".. k, "Storage")
      error("Corrupt MacroVersion")
    end
  end
end

--- This function scans all macros in the library and reports on corrupt macros.
function GSE.ScanMacrosForErrors()
  for classlibid,classlib in ipairs(GSELibrary) do
    for seqname, seq in pairs(classlib) do
      for macroversionid, macroversion in ipairs(seq) do
        local status, error = pcall(GSE.CheckSequence, macroversion)
        if not status then
          GSE.Print(string.format(L["Error found in version %i of %s."], macroversionid, seqname), "Error")
          GSE.Print(string.format(L["To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"], GSEOptions.CommandColour, classlibid, seqname, Statics.StringReset))
        end
      end
      if seqname == "WW" then
        GSE.Print(string.format(L["Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."], GSEOptions.CommandColour, Statics.StringReset), "Error")
      elseif seqname == "PVP" then
        GSE.Print(string.format(L["Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."], GSEOptions.CommandColour, Statics.StringReset), "Error")
      end
    end
  end
  GSE.Print(L["Finished scanning for errors.  If no other messages then no errors were found."])
end


--- This function takes a text string and compresses it without loading it to the library
function GSE.CompressSequenceFromString(importstring)
  importStr = GSE.StripControlandExtendedCodes(importstring)
  local returnstr = ""
  local functiondefinition =  GSE.FixQuotes(importStr) .. [===[
  return Sequences
  ]===]

  local fake_globals = setmetatable({
    Sequences = {},
    }, {__index = _G})
  local func, err = loadstring (functiondefinition, "Storage")
  if func then
    -- Make the compiled function see this table as its "globals"
    setfenv (func, fake_globals)

    local TempSequences = assert(func())
    if not GSE.isEmpty(TempSequences) then
      for k,v in pairs(TempSequences) do
        returnstr = GSE.ExportSequence(v, k, false, "ID", false)
      end
    end
  end
  return returnstr
end

--- This function takes a text string and decompresses it without loading it to the library
function GSE.DecompressSequenceFromString(importstring)
  local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
  local returnstr = ""
  local seqName = ""
  if (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and (type(actiontable[2]) == "table") then
    seqName = string.upper(actiontable[1])
    returnstr = GSE.Dump(actiontable[2])
  end
  return returnstr, seqName, decompresssuccess
end

--- This function allows the player to toggle Target Protection from the LDB Plugin.
function GSE.ToggleTargetProtection()
  if GSE.isEmpty(GSEOptions.requireTarget) then
    GSEOptions.requireTarget = true
  else
    GSEOptions.requireTarget = false
  end
  GSE.ReloadSequences()
end

--- This creates a pretty export for WLM Forums
function GSE.ExportSequenceWLMFormat(sequence, sequencename)
    local returnstring = "<br/><strong>".. sequencename .."</strong>\n<em>Talents</em> " .. (GSE.isEmpty(sequence.Talents) and "?,?,?,?,?,?,?" or sequence.Talents) .. "<br/><br/>"
    if not GSE.isEmpty(sequence.Help) then
      returnstring = "<em>Usage Information</em>\n" .. sequence.Help .. "<br/><br/>"
    end
    returnstring = returnstring .. "This macro contains " .. (table.getn(sequence.MacroVersions) > 1 and table.getn(sequence.MacroVersions) .. "macro versions. " or "1 macro version. ") .. string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. "\n\n"
    if (table.getn(sequence.MacroVersions) > 1) then
      returnstring = returnstring .. "<ul>"
      for k,v in pairs(sequence.MacroVersions) do
        if not GSE.isEmpty(sequence.Default) then
          if sequence.Default == k then
            returnstring = returnstring .. "<li>The Default macro is " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Raid) then
          if sequence.Raid == k then
            returnstring = returnstring .. "<li>Raids use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.PVP) then
          if sequence.PVP == k then
            returnstring = returnstring .. "<li>PVP uses version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Dungeon) then
          if sequence.Dungeon == k then
            returnstring = returnstring .. "<li>Normal Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Heroic) then
          if sequence.Heroic == k then
            returnstring = returnstring .. "<li>Heroic Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Mythic) then
          if sequence.Mythic == k then
            returnstring = returnstring .. "<li>Mythic Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Arena) then
          if sequence.Arena == k then
            returnstring = returnstring .. "<li>Arenas use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Timewalking) then
          if sequence.Timewalking == k then
            returnstring = returnstring .. "<li>Timewalking Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.MythicPlus) then
          if sequence.MythicPlus == k then
            returnstring = returnstring .. "<li>Mythic+ Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Party) then
          if sequence.Party == k then
            returnstring = returnstring .. "<li>Open World Parties use version " .. k .. "</li>\n"
          end
        end
      end

      returnstring = returnstring .. "</ul>\n"
    end
    for k,v in pairs(sequence.MacroVersions) do
      returnstring = returnstring .. "<strong>Macro Version ".. k .. "</strong>\n"
      returnstring = returnstring .. "<blockquote><strong>Step Function: </strong>" .. v.StepFunction .. "\n\n"
      if not GSE.isEmpty(v.PreMacro) then
        if table.getn(v.PreMacro) > 0 then
          returnstring = returnstring .. "<strong>Pre Macro: </strong>" .. GSE.IdentifySpells(v.PreMacro) .. "\n\n"
        end
      end
      if not GSE.isEmpty(v.KeyPress) then
        if table.getn(v.KeyPress) > 0 then
          spells, _ = GSE.IdentifySpells(v.KeyPress)
          if not GSE.isEmpty(spells) then
            returnstring = returnstring .. "<strong>KeyPress: </strong>" .. GSE.IdentifySpells(v.KeyPress) .. "\n\n"
          else
            returnstring = returnstring .. "<strong>KeyPress: </strong> Contains various utility functions.\n\n"
          end
        end
      end
      returnstring = returnstring .. "<strong>Main Sequence: </strong>" .. GSE.IdentifySpells(v) .. "\n\n"
      if not GSE.isEmpty(v.KeyRelease) then
        if table.getn(v.KeyRelease) > 0 then
          spells, _ = GSE.IdentifySpells(v.KeyRelease)
          if not GSE.isEmpty(spells) then
              returnstring = returnstring .. "<strong>KeyRelease: </strong>" .. GSE.IdentifySpells(v.KeyRelease) .. "\n\n"
          else
            returnstring = returnstring .. "<strong>KeyRelease: </strong> Contains various utility functions.\n\n"
          end
        end
      end
      if not GSE.isEmpty(v.PostMacro) then
        if table.getn(v.PostMacro) > 0 then
          returnstring = returnstring .. "<strong>Post Macro: </strong>" .. GSE.IdentifySpells(v.PostMacro) .. "\n\n"
        end
      end
      returnstring = returnstring .. "</blockquote>"
    end

    return returnstring
end

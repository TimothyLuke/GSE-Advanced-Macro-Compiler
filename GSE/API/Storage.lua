local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

--- Delete a sequence starting with the macro and then the sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
  GSE.DeleteMacroStub(sequenceName)
  GSELibrary[classid][sequenceName] = nil
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
  local confirmationtext = ""
  -- CHeck for colissions
  local found = false
  if GSE.isEmpty(classid) then
    classid = tonumber(GSE.GetClassIDforSpec(sequence.SpecID))
  end
  if GSE.isEmpty(sequence.SpecID) then
    sequence.SpecID = GSE.GetCurrentClassID()
  end

  if GSE.isEmpty(GSELibrary[classid]) then
    GSELibrary[classid] = {}
  end
  if not GSE.isEmpty(GSELibrary[classid][sequenceName]) then
      found = true
  end
  if found then
    -- check if source the same.  If so ignore
    GSE.Print (L["A sequence collision has occured.  Extra versions of this macro have been loaded.  Manage the sequence to determine how to use them "], GNOME)
    for k,v in ipairs(sequence.MacroVersions) do
      GSE.PrintDebugMessage("adding ".. k, "Storage")
      table.insert(GSELibrary[classid][sequenceName].MacroVersions, v)
    end
    GSE.PrintDebugMessage("Finished colliding entry entry", "Storage")
  else
    -- New Sequence
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

    GSELibrary[classid][sequenceName] = {}
    GSELibrary[classid][sequenceName] = sequence
  end
  if not GSE.isEmpty(confirmationtext) then
    GSE.Print(GSEOptions.EmphasisColour .. sequenceName .. "|r" .. L[" was imported with the following errors."] .. " " .. confirmationtext, GNOME)
  end
  -- if classid == GSE.GetCurrentClassID() then
  --   GSE.UpdateSequence(SequenceName, sequence.MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)])
  -- end
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
  for k,v in pairs(Sequences) do
    GSE.AddSequenceToCollection(k, v)
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
function GSE.CreateMacroIcon(sequenceName, icon, forceglobalstub)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  if sequenceIndex > 0 then
    -- Sequence exists do nothing
    GSE.PrintDebugMessage("Moving on - macro for " .. sequenceName .. " already exists.", GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSEOptions.overflowPersonalMacros and not forceglobalstub then
      GSE.Print(GSEOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSEOptions.overflowPersonalMacros then
      GSE.Print(L["Close to Maximum Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour .. numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS .. L[" macros per Account.  You currently have "] .. GSEOptions.EmphasisColour .. numAccountMacros .. L["|r. As a result this macro was not created.  Please delete some macros and reenter "] .. GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
    else
      sequenceid = CreateMacro(sequenceName, (GSEOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), '#showtooltip\n/click ' .. sequenceName, (forceglobalstub and false or GSE.SetMacroLocation()) )
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
        GSE.AddSequenceToCollection(k, v)
        if GSE.isEmpty(v.Icon) then
          -- Set a default icon
          v.Icon = GSE.GetDefaultIcon()
        end
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
  GSE.PrintDebugMessage("Reloading Sequences")
  for name, sequence in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    GSE.UpdateSequence(name, sequence.MacroVersions[GSE.GetActiveSequenceVersion(name)])
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
    loopcheck = true
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    loopcheck = true
  end
  if not GSE.isEmpty(sequence.LoopLimit) then
    loopcheck = true
  end
  return loopcheck
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequence(sequence, sequenceName)
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
    local outputversion =  GSE.CleanMacroVersion(v)
    macroversions = macroversions .. "    [" .. k .. "] = {\n"

    local steps = "      StepFunction = \"Sequential\"\n" -- Set to this as the default if its blank.
    if not GSE.isEmpty(sequence.StepFunction) then
      if  outputversion.StepFunction == Statics.PriorityImplementation or outputversion.StepFunction == "Priority" then
       steps = "      StepFunction = " .. GSEOptions.EQUALS .. "\"Priority\"" .. Statics.StringReset .. ",\n"
     elseif outputversion.StepFunction == "Sequential" then
       steps = "      StepFunction = " .. GSEOptions.EQUALS .. "\"Sequential\"" .. Statics.StringReset .. ",\n"
     else
       steps = "      StepFunction = [[" .. GSEOptions.EQUALS .. outputversion.StepFunction .. Statics.StringReset .. "]],\n"
      end
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
    if not GSE.isEmpty(outputversion.looplimit) then
      macroversions = macroversions .. "      looplimit=" .. GSEOptions.EQUALS .. outputversion.looplimit .. Statics.StringReset .. ",\n"
    end
    if not GSE.isEmpty(outputversion.KeyPress) then
      macroversions = macroversions .. "      KeyPress={\n"
      for _,p in ipairs(outputversion.KeyPress) do
        local results = string.sub(GSE.TranslateString(p, GetLocale(), GetLocale(), true),1,-2)
        if not GSE.isEmpty(results)then
          macroversions = macroversions .. "        \"" .. results .."\",\n"
        end
      end
      macroversions = macroversions .. "      },\n"
    end
    if not GSE.isEmpty(outputversion.PreMacro) then
      macroversions = macroversions .. "      PreMacro={\n"
      for _,p in ipairs(outputversion.PreMacro) do
        local results = string.sub(GSE.TranslateString(p, GetLocale(), GetLocale(), true),1,-2)
        if not GSE.isEmpty(results)then
          macroversions = macroversions .. "        \"" .. results .."\",\n"
        end
      end
      macroversions = macroversions .. "      },\n"
    end
    for _,p in ipairs(v) do
      local results = string.sub(GSE.TranslateString(p, GetLocale(), GetLocale(), true),1,-2)
      if not GSE.isEmpty(results)then
        macroversions = macroversions .. "        \"" .. results .."\",\n"
      end
    end
    if not GSE.isEmpty(outputversion.PostMacro) then
      macroversions = macroversions .. "      PostMacro={\n"
      for _,p in ipairs(outputversion.PostMacro) do
        local results = string.sub(GSE.TranslateString(p, GetLocale(), GetLocale(), true),1,-2)
        if not GSE.isEmpty(results)then
          macroversions = macroversions .. "        \"" .. results .."\",\n"
        end
      end
      macroversions = macroversions .. "      },\n"
    end
    if not GSE.isEmpty(outputversion.KeyRelease) then
      macroversions = macroversions .. "      KeyRelease={\n"
      for _,p in ipairs(outputversion.KeyRelease) do
        local results = string.sub(GSE.TranslateString(p, GetLocale(), GetLocale(), true),1,-2)
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
  local returnVal = (disabledseq .. "Sequences['" .. GSEOptions.EmphasisColour .. sequenceName .. Statics.StringReset .. "'] = {\n  author=\"" .. GSEOptions.AuthorColour .. (GSE.isEmpty(sequence.Author) and "Unknown Author" or sequence.Author) .. Statics.StringReset .. "\",  \n" .. (GSE.isEmpty(sequence.SpecID) and "-- Unknown SpecID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "  SpecID=" .. GSEOptions.NUMBER  .. sequence.SpecID .. Statics.StringReset ..",\n") ..  sequencemeta)
  if not GSE.isEmpty(sequence.Icon) then
     returnVal = returnVal .. "  Icon=" .. GSEOptions.CONCAT .. (tonumber(sequence.Icon) and sequence.Icon or "'".. sequence.Icon .. "'") .. Statics.StringReset ..",\n"
  end
  if not GSE.isEmpty(sequence.Lang) then
    returnVal = returnVal .. "  Lang=\"" .. GSEOptions.STANDARDFUNCS .. sequence.Lang .. Statics.StringReset .. "\",\n"
  end
  returnVal = returnVal .. macroversions
  returnVal = returnVal .. "},\n"

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
function GSE.CleanMacroLibrary(forcedelete)
  -- clean out the sequences database except for the current version
  if forcedelete then
    GSELibrary[GSE.GetCurrentClassID()] = nil
    GSELibrary[GSE.GetCurrentClassID()] = {}
  end
end

--- This function resets a button back to its initial setting
function GSE.ResetButtons()
  for k,v in pairs(GSE.UsedSequences) do
    button = _G[k]
    if button:GetAttribute("combatreset") == true then
      button:SetAttribute("step",1)
      GSE.UpdateIcon(button, true)
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
  -- print(name)
  -- print(sequence)
  -- print(debugstack())
  sequence = GSE.CleanMacroVersion(sequence)

  local existingbutton = true
  if GSE.isEmpty(_G[name]) then
    GSE.CreateButton(name,sequence)
    existingbutton = false
  end
  local button = _G[name]
  -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
  if GSEOptions.useTranslator then
    sequence = GSE.TranslateSequence(sequence, name)
  end
  local tempseq = {}
  if not GSE.isEmpty(sequence.PreMaco) then
    for k,v in ipairs(sequence.PreMacro) do
      table.insert(tempseq, v)
    end
    button:SetAttribute('loopstart', table.getn(tempseq) + 1)
  end
  for k,v in ipairs(sequence) do
    table.insert(tempseq, v)
  end
  if not GSE.isEmpty(sequence.PostMaco) then
    button:SetAttribute('loopstop', table.getn(tempseq) + 1)
    for k,v in ipairs(sequence.PostMacro) do
      table.insert(tempseq, v)
    end
  end


  GSE.FixSequence(sequence)
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(tempseq))) .. ']=======])')
  button:SetAttribute("step",1)
  button:SetAttribute('KeyPress',table.concat(GSE.PrepareKeyPress(sequence), "\n") or '' .. '\n')
  GSE.PrintDebugMessage("GSUpdateSequence KeyPress updated to: " .. button:GetAttribute('KeyPress'))
  button:SetAttribute('KeyRelease',table.concat(GSE.PrepareKeyRelease(sequence), "\n") or '' .. '\n')
  GSE.PrintDebugMessage("GSUpdateSequence KeyRelease updated to: " .. button:GetAttribute('KeyRelease'))
  if existingbutton then
    button:UnwrapScript(button,'OnClick')
  end
  local targetreset = ""
  if sequence.Target then
    targetreset = Statics.TargetResetImplementation
  end
  if (GSE.isEmpty(sequence.Combat) and GSEOptions.resetOOC ) or sequence.Combat then
    button:SetAttribute("combatreset", true)
  else
    button:SetAttribute("combatreset", true)
  end
  button:WrapScript(button, 'OnClick', format(Statics.OnClick, targetreset, GSE.PrepareStepFunction(sequence.StepFunction,  GSE.IsLoopSequence(sequence))))
  if not GSE.isEmpty(sequence.looplimit) then
    button:SetAttribute('looplimit', sequence.looplimit)
  end

end

function GSE.PrepareStepFunction(stepper, looper)
  retvalue = ""
  if looper then
    if GSE.isEmpty(stepper) or stepper == Statics.Sequential then
      retvalue = Statics.LoopSequentialImplementation
    else
      retvalue = Statics.LoopPriorityImplementation
    end
  else
    if GSE.isEmpty(stepper) or stepper == Statics.Sequential then
      retvalue = Statics.Sequential
    end
    if stepper == Statics.Priority then
      retvalue = Statics.PriorityImplementation
    elseif stepper == Statics.Sequential then
      retvalue = 'step = step % #macros + 1'
    else
      retvalue = stepper
    end
  end
  return retvalue
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
    GSE.PrintDebugMessage("We have a perfect match", GNOME)
  else
    if seq1.SpecID == seq2.SpecID then
      GSE.PrintDebugMessage("Matching specID", GNOME)
    else
      GSE.PrintDebugMessage("Different specID", GNOME)
    end
    if seq1.StepFunction == seq2.StepFunction then
      GSE.PrintDebugMessage("Matching StepFunction", GNOME)
    else
      GSE.PrintDebugMessage("Different StepFunction", GNOME)
    end
    if seq1.KeyPress == seq2.KeyPress then
      GSE.PrintDebugMessage("Matching KeyPress", GNOME)
    else
      GSE.PrintDebugMessage("Different KeyPress", GNOME)
    end
    if steps1 == steps2 then
      GSE.PrintDebugMessage("Same Sequence Steps", GNOME)
    else
      GSE.PrintDebugMessage("Different Sequence Steps", GNOME)
    end
    if seq1.KeyRelease == seq2.KeyRelease then
      GSE.PrintDebugMessage("Matching KeyRelease", GNOME)
    else
      GSE.PrintDebugMessage("Different KeyRelease", GNOME)
    end
    if seq1.helpTxt == seq2.helpTxt then
      GSE.PrintDebugMessage("Matching helpTxt", GNOME)
    else
      GSE.PrintDebugMessage("Different helpTxt", GNOME)
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




--- Check if a macro has been created and if the create flag is true and the macro hasnt been created then create it.
function GSE.CheckMacroCreated(SequenceName, create)
  local found = false
  local macroIndex = GetMacroIndexByName(SequenceName)
  if macroIndex and macroIndex ~= 0 then
    found = true
    EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. SequenceName)
  else
    if create then
      local icon = (GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][SequenceName].Icon) and Statics.QuestionMark or GSELibrary[GSE.GetCurrentClassID()][SequenceName].Icon)
      GSE.CreateMacroIcon(SequenceName, icon)
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
    if GSEOptions.filterList[Statics.All] or k == GSE.GetCurrentClassID() then
      for i,j in pairs(GSELibrary[k]) do
        keyset[k .. "," .. i] = i
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
  if not GSE.isEmpty(sequence.lang) then
    returnSequence.Lang = sequence.lang
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
    if Sequence.StepFunction == GSStaticPriority then
      returnSequence.MacroVersions[1].StepFunction = Statics.Priority
    elseif GSE.isEmpty(sequence.StepFunction) then
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
  for k,v in ipairs(sequence) do
    local loopstart = sequence.loopstart or 1
    local loopstop = sequence.loopstop or table.getn(sequence)
    if loopstart > 1 then
      macroversion.PreMacro = {}
    end
    if loopstop < table.getn(sequence) then
      macroversion.PostMacro = {}
    end
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
  GSE.ImportMacroCollection(Statics.SampleMacros[classID])
end


function GSE.CreateButton(name, sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
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

function GSE.PrepareKeyPress(sequence)

  local tab = {}
  for k,v in pairs(sequence.KeyPress) do
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

function GSE.PrepareKeyRelease(sequence)
  local tab = {}
  for k,v in pairs(sequence.KeyRelease) do
    table.insert(tab, v)
  end
  if GSEOptions.requireTarget then
    -- see #20 prevent target hopping
    table.insert(tab, "/stopmacro [@playertarget, noexists]")
  end
  if sequence.Ring1 or (sequence.Ring1 == nil and GSEOptions.use11) then
    table.insert(tab, "/use [combat] 11")
  end
  if sequence.Ring2 or (sequence.Ring2 == nil and GSEOptions.use12) then
    table.insert(tab, "/use [combat] 12")
  end
  if sequence.Trinket1 or (sequence.Trinket1 == nil and GSEOptions.use13) then
    table.insert(tab, "/use [combat] 13")
  end
  if sequence.Trinket2 or (sequence.Trinket2 == nil and GSEOptions.use14) then
    table.insert(tab, "/use [combat] 14")
  end
  if sequence.Neck or (sequence.Neck == nil and GSEOptions.use2) then
    table.insert(tab, "/use [combat] 2")
  end
  if sequence.Head or (sequence.Head == nil and GSEOptions.use1) then
    table.insert(tab, "/use [combat] 1")
  end
  if sequence.Belt or (sequence.Belt == nil and GSEOptions.use6) then
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

--- Takes a collection of Sequences and returns a list of names
function GSE.GetSequenceNamesFromLibrary(library)
  local sequenceNames = {}
  for k,_ in pairs(library) do
    table.insert(sequenceNames, k)
  end
  return sequenceNames
end

local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD, GCD_Update_Timer


--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
  if GSE.UnsavedOptions.DebugSequenceExecution then
    -- Note to self: Do I care if it's a loop sequence?
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
    local castingspell, castspellid

    if GSE.GameMode == 1 then
      print(CastingInfo())
      castingspell, _, _, _, _, _, castspellid, _ = CastingInfo()
    else
      castingspell, _, _, _, _, _, castspellid, _ = UnitCastingInfo("player")
    end
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



function GSE:UNIT_FACTION()
  --local pvpType, ffa, _ = GetZonePVPInfo()
  if UnitIsPVP("player") then
    GSE.PVPFlag = true
  else
    GSE.PVPFlag = false
  end
  GSE.PrintDebugMessage("PVP Flag toggled to " .. tostring(GSE.PVPFlag), Statics.DebugModules["API"])
  GSE.ReloadSequences()
end

function GSE:ZONE_CHANGED_NEW_AREA()
  local name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo()
  if type == "pvp" then
    GSE.PVPFlag = true
  else
    GSE.PVPFlag = false
  end
  if difficulty == 23 then -- Mythic 5 player
    GSE.inMythic = true
  else
    GSE.inMythic = false
  end
  if difficulty == 1 then -- Normal
    GSE.inDungeon = true
  else
    GSE.inDungeon = false
  end
  if difficulty == 2 then -- Heroic
    GSE.inHeroic = true
  else
    GSE.inHeroic = false
  end
  if difficulty == 8 then -- Mythic+
    GSE.inMythicPlus = true
  else
    GSE.inMythicPlus = false
  end

  if difficulty == 24 or difficulty == 33 then -- Timewalking  24 Dungeon, 33 raid
    GSE.inTimeWalking = true
  else
    GSE.inTimeWalking = false
  end
  if type == "raid" then
    GSE.inRaid = true
  else
    GSE.inRaid = false
  end
  if IsInGroup() then
    GSE.inParty = true
  else
    GSE.inParty = false
  end
  if type == "arena" then
    GSE.inArena = true
  else
    GSE.inArena = false
  end
  GSE.PrintDebugMessage("PVP: " .. tostring(GSE.PVPFlag) .. " inMythic: " .. tostring(GSE.inMythic) .. " inRaid: " .. tostring(GSE.inRaid) .. " inDungeon " .. tostring(GSE.inDungeon) .. " inHeroic " .. tostring(GSE.inHeroic) .. " inArena " .. tostring(GSE.inArena) .. " inTimeWalking " .. tostring(GSE.inTimeWalking) .. " inMythicPlus " .. tostring(GSE.inMythicPlus),  Statics.DebugModules["API"])
  GSE.ReloadSequences()
end

function GSE:PLAYER_ENTERING_WORLD()
  GSE.PerformOneOffEvents()
  GSE.PrintAvailable = true
  GSE.PerformPrint()
end

function GSE:ADDON_LOADED(event, addon)

  if GSE.isEmpty(GSELibrary) then
    GSELibrary = {}
  end
  if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()]) then
    GSELibrary[GSE.GetCurrentClassID()] = {}
  end
  if GSE.isEmpty(GSELibrary[0]) then
    GSELibrary[0] = {}
  end

  local counter = 0

  for k,v in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    counter = counter + 1
    for i,j in ipairs(v.MacroVersions) do
      GSELibrary[GSE.GetCurrentClassID()][k].MacroVersions[tonumber(i)] = GSE.UnEscapeSequence(j)
    end
  end
  if not GSE.isEmpty(GSELibrary[0]) then

    for k,v in pairs(GSELibrary[0]) do
      counter = counter + 1
      for i,j in ipairs(v.MacroVersions) do
        GSELibrary[0][k].MacroVersions[tonumber(i)] = GSE.UnEscapeSequence(j)
      end
    end
  end
  if counter <= 0 then
    if GSEOptions.PromptSample then
      if table.getn(Statics.SampleMacros) > 0 then
        StaticPopup_Show ("GSE-SampleMacroDialog")
      end
    end
  end
  GSE.PrintDebugMessage("I am loaded")
  GSEOptions.UnfoundSpells = {}
  GSEOptions.ErroneousSpellID = {}
  GSEOptions.UnfoundSpellIDs = {}
  GSE:ZONE_CHANGED_NEW_AREA()
  GSE:SendMessage(Statics.CoreLoadedMessage)

  -- Register the Sample Macros
  local seqnames = {}
  table.insert(seqnames, "Assorted Sample Macros")
  GSE.RegisterAddon("Samples", GSE.VersionString, seqnames)

  GSE:RegisterMessage(Statics.ReloadMessage, "processReload")

  LibStub("AceConfig-3.0"):RegisterOptionsTable("GSE", GSE.GetOptionsTable(), {"gseo"})
  if addon == GNOME then
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSE", "|cffff0000GSE:|r Gnome Sequencer Enhanced")
    if not GSEOptions.HideLoginMessage then
      GSE.Print(GSEOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSEOptions.CommandColour .. L["/gs help|r to get started."], GNOME)
    end
  end

  -- Added in 2.1.0
  if GSE.isEmpty(GSEOptions.MacroResetModifiers) then
    GSEOptions.MacroResetModifiers = {}
    GSEOptions.MacroResetModifiers["LeftButton"] = false
    GSEOptions.MacroResetModifiers["RighttButton"] = false
    GSEOptions.MacroResetModifiers["MiddleButton"] = false
    GSEOptions.MacroResetModifiers["Button4"] = false
    GSEOptions.MacroResetModifiers["Button5"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["Alt"] = false
    GSEOptions.MacroResetModifiers["LeftControl"] = false
    GSEOptions.MacroResetModifiers["RightControl"] = false
    GSEOptions.MacroResetModifiers["Control"] = false
    GSEOptions.MacroResetModifiers["LeftShift"] = false
    GSEOptions.MacroResetModifiers["RightShift"] = false
    GSEOptions.MacroResetModifiers["Shift"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["AnyMod"] = false
  end

  -- Fix issue where IsAnyShiftKeyDown() was referenced instead of IsShiftKeyDown() #327
  if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyShift"]) then
    GSEOptions.MacroResetModifiers["Shift"] = GSEOptions.MacroResetModifiers["AnyShift"]
    GSEOptions.MacroResetModifiers["AnyShift"] = nil
  end
  if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyControl"]) then
    GSEOptions.MacroResetModifiers["Control"] = GSEOptions.MacroResetModifiers["AnyControl"]
    GSEOptions.MacroResetModifiers["AnyControl"] = nil
  end
  if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyAlt"]) then
    GSEOptions.MacroResetModifiers["Alt"] = GSEOptions.MacroResetModifiers["AnyAlt"]
    GSEOptions.MacroResetModifiers["AnyAlt"] = nil
  end

end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, action)
  if unit == "player" then
    local _, GCD_Timer = GetSpellCooldown(61304)
    GCD = true
    GCD_Update_Timer = C_Timer.After(GCD_Timer, function () GCD = nil; GSE.PrintDebugMessage("GCD OFF") end)
    GSE.PrintDebugMessage("GCD Delay:" .. " " .. GCD_Timer)
    GSE.CurrentGCD = GCD_Timer

    local elements = GSE.split(action, "-")
    local spell,_,_,_,_,_=GetSpellInfo(elements[6])
    local fskilltype, fspellid = GetSpellBookItemInfo(spell)
    if not GSE.isEmpty(fskilltype) then
      if GSE.RecorderActive then
        GSE.GUIRecordFrame.RecordSequenceBox:SetText(GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n")
      end
    end
  end
end

function GSE:PLAYER_REGEN_ENABLED(unit,event,addon)
  GSE:UnregisterEvent('PLAYER_REGEN_ENABLED')
  if GSEOptions.resetOOC then
    GSE.ResetButtons()
  end
  GSE:RegisterEvent('PLAYER_REGEN_ENABLED')
end

local IgnoreMacroUpdates = false

function GSE:PLAYER_LOGOUT()
  GSE.PrepareLogout()
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
  GSE.ReloadSequences()
end

function GSE:PLAYER_LEVEL_UP()
  GSE.ReloadSequences()
end

function GSE:GROUP_ROSTER_UPDATE(...)
  -- Serialisation stuff
  GSE.sendVersionCheck()
  for k,v in pairs(GSE.UnsavedOptions["PartyUsers"]) do
    if not (UnitInParty(k) or UnitInRaid(k)) then
      -- Take them out of the list
      GSE.UnsavedOptions["PartyUsers"][k] = nil
    end

  end
  -- Group Team stuff
  GSE:ZONE_CHANGED_NEW_AREA()
end


GSE:RegisterEvent("GROUP_ROSTER_UPDATE")
GSE:RegisterEvent('PLAYER_LOGOUT')
GSE:RegisterEvent('PLAYER_ENTERING_WORLD')
GSE:RegisterEvent('PLAYER_REGEN_ENABLED')
GSE:RegisterEvent('ADDON_LOADED')
GSE:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
GSE:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GSE:RegisterEvent("UNIT_FACTION")
GSE:RegisterEvent("PLAYER_LEVEL_UP")

local function PrintGnomeHelp()
  GSE.Print(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
  GSE.Print(L["GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."], GNOME)
  GSE.Print(L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."], GNOME)
  GSE.Print(L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."], GNOME)
  GSE.Print(L["To get started "] .. GSEOptions.CommandColour .. L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs checkmacrosforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."], GNOME)
end

GSE:RegisterChatCommand("gsse", "GSSlash")
GSE:RegisterChatCommand("gs", "GSSlash")
GSE:RegisterChatCommand("gse", "GSSlash")



-- Functions
--- Handle slash commands
function GSE:GSSlash(input)
  local params = GSE.split(input, " ")
  if table.getn(params) > 1 then
    input = params[1]
  end
  local command = string.lower(input)
  if command == "showspec" then
    if GSE.GameMode == 1 then
      GSE.Print(L["Your ClassID is "] .. currentclassId .. ' ' .. Statics.SpecIDList[currentclassId], GNOME)
    else
      local currentSpec = GetSpecialization()
      local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
      local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSE.Print(L["Your current Specialisation is "] .. currentSpecID .. ':' .. specname .. L["  The Alternative ClassID is "] .. currentclassId, GNOME)
    end
  elseif command == "help" then
    PrintGnomeHelp()
  elseif command == "cleanorphans" or command == "clean" then
    GSE.CleanOrphanSequences()
  elseif command == "forceclean" then
    GSE.CleanOrphanSequences()
    GSE.CleanMacroLibrary(true)
  elseif command == "showdebugoutput" then
      StaticPopup_Show ("GS-DebugOutput")
  elseif command == "record" then
    if GSE.UnsavedOptions["GUI"] then
      GSE.GUIRecordFrame:Show()
    else
      GSE.printNoGui()
    end
  elseif command == "debug" then
    if GSE.UnsavedOptions["GUI"] then
      GSE.GUIShowDebugWindow()
    else
      GSE.printNoGui()
    end

  elseif command == "compilemissingspells" then
    GSE.Print("Compiling Language Table errors.  If the game hangs please be patient.")
    GSE.ReportUnfoundSpells()
    GSE.Print("Language Spells compiled.  Please exit the game and obtain the values from WTF/AccountName/SavedVariables/GSE.lua")
  elseif command == "resetoptions" then
    GSE.SetDefaultOptions()
    GSE.Print(L["Options have been reset to defaults."])
    StaticPopup_Show ("GSE_ConfirmReloadUIDialog")
  elseif command == "updatemacrostrings" then
    -- Convert macros to new format in a one off run.
    GSE.UpdateMacroString()
  elseif command == "movelostmacros" then
    GSE.MoveMacroToClassFromGlobal()
  elseif command == "checkmacrosforerrors" then
    GSE.ScanMacrosForErrors()
  elseif command == "compressstring" then
    if GSE.UnsavedOptions["GUI"] then
      GSE.GUICompressFrame:Show()
    else
      GSE.printNoGui()
    end
  elseif command == "dumpmacro" then
    GSE_C[params[2]] = {}
    GSE_C[params[2]].name = params[2]
    GSE_C[params[2]].sequence = GSE.FindMacro(params[2])
    GSE_C[params[2]].button = _G[params[2]]
  else
    if GSE.UnsavedOptions["GUI"] then
      GSE.GUIShowViewer()
    else
      GSE.printNoGui()
    end

  end
end

function GSE:processReload(action, arg)
  if arg == "Samples" then
    GSE.LoadSampleMacros(GSE.GetCurrentClassID())
  end
end

function GSE:OnEnable()
  GSE.StartOOCTimer()
end

--- Start the OOC Queue Timer
function GSE.StartOOCTimer()
  GSE.OOCTimer = GSE:ScheduleRepeatingTimer("ProcessOOCQueue", 1)
end

--- Stop the OOC Queue Timer
function GSE.StopOOCTimer()
  GSE:CancelTimer(GSE.OOCTimer)
  GSE.OOCTimer = nil
end


function GSE:ProcessOOCQueue()
  for k,v in ipairs(GSE.OOCQueue) do
    if not InCombatLockdown() then
      if v.action == "UpdateSequence" then
        GSE.OOCUpdateSequence(v.name, v.macroversion)
      elseif v.action == "Save" then
        GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
      elseif v.action == "Replace" then
        if GSE.isEmpty(GSELibrary[v.classid][v.sequencename]) then
          GSE.AddSequenceToCollection(v.sequencename, v.sequence, v.classid)
        else
          GSELibrary[v.classid][v.sequencename] = v.sequence
        end
        if v.checkmacro then
          GSE.CheckMacroCreated(v.sequencename, v.checkmacro)
        end
        GSE.UpdateSequence(v.sequencename, v.sequence.MacroVersions[GSE.GetActiveSequenceVersion(v.sequencename)])
      elseif v.action == "openviewer" then
        GSE.GUIShowViewer()
      elseif v.action == "CheckMacroCreated" then
        GSE.OOCCheckMacroCreated(v.sequencename, v.create)
      elseif v.action == "MergeSequence"then
        GSE.OOCPerformMergeAction(v.mergeaction, v.classid, v.sequencename, v.newSequence)
      end
      GSE.OOCQueue[k] = nil
    end
  end
end

function GSE.prepareTooltipOOCLine(tooltip, OOCEvent, row, oockey)
  tooltip:SetCell(row, 1, L[OOCEvent.action], "LEFT", 1)
  if OOCEvent.action == "UpdateSequence" then
    tooltip:SetCell(row, 3, OOCEvent.name, "RIGHT", 1)
  elseif OOCEvent.action == "Save" then
    tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
  elseif OOCEvent.action == "Replace" then
    tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
  elseif OOCEvent.action == "CheckMacroCreated" then
    tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
  end
  tooltip:SetLineScript(row, "OnMouseUp", function ()
    GSE.OOCQueue[oockey] = nil
  end)
end

function GSE.CheckOOCQueueStatus()
  local output = ""
  if GSE.isEmpty(GSE.OOCTimer) then
    output = GSEOptions.UNKNOWN .. L["Paused"] .. Statics.StringReset
  else
    if InCombatLockdown() then
      output = GSEOptions.TitleColour .. L["Paused - In Combat"] .. Statics.StringReset
    else
      output = GSEOptions.CommandColour .. L["Running"] .. Statics.StringReset
    end
  end
  return output
end

function GSE.ToggleOOCQueue()
  if GSE.isEmpty(GSE.OOCTimer) then
    GSE.StartOOCTimer()
  else
    GSE.StopOOCTimer()
  end
end


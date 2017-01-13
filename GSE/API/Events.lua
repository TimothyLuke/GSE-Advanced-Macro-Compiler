local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD, GCD_Update_Timer


--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
  if GSE.UnsavedOptions.DebugSequenceExecution then
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
  if type == "arena" or type == "pvp" then
    GSE.PVPFlag = true
  else
    GSE.PVPFlag = false
  end
  if difficulty == 23 then
    GSE.inMythic = true
  else
    GSE.inMythic = false
  end
  if type == "raid" then
    GSE.inRaid = true
  else
    GSE.inRaid = false
  end
  GSE.PrintDebugMessage("PVP: " .. tostring(GSE.PVPFlag) .. " inMythic: " .. tostring(GSE.inMythic) .. " inRaid: " .. tostring(inRaid), Statics.DebugModules["API"])
  GSE.ReloadSequences()
end

function GSE:PLAYER_ENTERING_WORLD()
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

  local counter = 0

  for k,v in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    counter = counter + 1
  end
  if counter <= 0 then
    StaticPopup_Show ("GSE-SampleMacroDialog")
  end
  GSE.PrintDebugMessage("I am loaded")
  GSE.ReloadSequences()
  GSE:SendMessage(Statics.CoreLoadedMessage)

  -- Register the Sample Macros
  local seqnames = {}
  for i=1, 12, 1 do
    for k,_ in pairs(Statics.SampleMacros[i]) do
      table.insert(seqnames, k)
    end
  end
  GSE.RegisterAddon("Samples", GSE.VersionString, seqnames)

  GSE:RegisterMessage(Statics.ReloadMessage, "processReload")

  LibStub("AceConfig-3.0"):RegisterOptionsTable("GSE", GSE.GetOptionsTable(), {"gse"})
  if addon == GNOME then
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSE", "|cffff0000GSE:|r Gnome Sequencer Enhanced")
  end

end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
  if unit == "player" then
    local _, GCD_Timer = GetSpellCooldown(61304)
    GCD = true
    GCD_Update_Timer = C_Timer.After(GCD_Timer, function () GCD = nil; GSE.PrintDebugMessage("GCD OFF") end)
    GSE.PrintDebugMessage("GCD Delay:" .. " " .. GCD_Timer)
    GSE.CurrentGCD = GCD_Timer

    if GSE.RecorderActive then
      GSE.GUIRecordFrame.RecordSequenceBox:SetText(GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n")
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

GSE:RegisterEvent('PLAYER_LOGOUT')
GSE:RegisterEvent('PLAYER_ENTERING_WORLD')
GSE:RegisterEvent('PLAYER_REGEN_ENABLED')
GSE:RegisterEvent('ADDON_LOADED')
GSE:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
GSE:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GSE:RegisterEvent("UNIT_FACTION")

local function PrintGnomeHelp()
  GSE.Print(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
  GSE.Print(L["GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."], GNOME)
  GSE.Print(L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."], GNOME)
  GSE.Print(L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."], GNOME)
  GSE.Print(L["To get started "] .. GSEOptions.CommandColour .. L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."], GNOME)
end

GSE:RegisterChatCommand("gsse", "GSSlash")
GSE:RegisterChatCommand("gs", "GSSlash")




-- Functions
--- Handle slash commands
function GSE:GSSlash(input)
  if string.lower(input) == "showspec" then
    local currentSpec = GetSpecialization()
    local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
    local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
    GSE.Print(L["Your current Specialisation is "] .. currentSpecID .. ':' .. specname .. L["  The Alternative ClassID is "] .. currentclassId, GNOME)
  elseif string.lower(input) == "help" then
    PrintGnomeHelp()
  elseif string.lower(input) == "cleanorphans" or string.lower(input) == "clean" then
    GSE.CleanOrphanSequences()
  elseif string.lower(input) == "forceclean" then
    GSE.CleanOrphanSequences()
    GSE.CleanMacroLibrary(true)
  elseif string.lower(string.sub(string.lower(input),1,6)) == "export" then
    GSE.Print(GSE.ExportSequence(string.sub(string.lower(input),8)))
  elseif string.lower(input) == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  elseif string.lower(input) == "record" then
      GSE.GUIRecordFrame:Show()
  elseif string.lower(input) == "debug" then
      GSE.GUIShowDebugWindow()
  elseif string.lower(input) == "compilemissingspells" then
      GSE.Print("Compiling Language Table errors.  If the game hangs please be patient.")
      GSE.ReportUnfoundSpells()
      GSE.Print("Language Spells compiled.  Please exit the game and obtain the values from WTF/AccountName/SavedVariables/GSE.lua")
  elseif string.lower(input) == "movelostmacros" then
      GSE.MoveMacroToClassFromGlobal()
  else
    GSE.GUIShowViewer()
  end
end

function GSE:processReload(action, arg)
  if arg == "Samples" then
    GSE.LoadSampleMacros(GSE.GetCurrentClassID())
    GSE.Print(L["The Sample Macros have been reloaded."])
  end
end

function GSE:OnEnable()
  GSE.OOCTimer = GSE:ScheduleRepeatingTimer("ProcessOOCQueue", 2)
end


function GSE:ProcessOOCQueue()
  if not InCombatLockdown() then
    for k,v in ipairs(GSE.OOCQueue) do
      if v.action == "UpdateSequence" then
        GSE.OOCUpdateSequence(v.name, v.macroversion)
      elseif v.action == "Save" then
        GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
      elseif v.action == "Replace" then
        if GSE.isEmpty(GSELibrary[v.classid][v.sequencename]) then
          GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
        else
          GSELibrary[v.classid][v.sequencename] = v.sequence
        end
        GSE.OOCUpdateSequence(v.sequencename, v.sequence.MacroVersions[GSE.GetActiveSequenceVersion(v.sequencename)])
      end
      GSE.OOCQueue[k] = nil
    end
  end
end

GSE.Print(GSEOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSEOptions.CommandColour .. L["/gs help|r to get started."], GNOME)

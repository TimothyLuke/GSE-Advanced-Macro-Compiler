local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD, GCD_Update_Timer


function GSE:PLAYER_LOGIN()
  GSE:UPDATE_MACROS()
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
  GSE.PrintDebugMessage(L["I am loaded"])
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
    GSE.PrintDebugMessage(L["GCD Delay:"] .. " " .. GCD_Timer)
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

GSE:RegisterEvent('PLAYER_LOGIN')

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
  input = string.lower(input)
  if input == "showspec" then
    local currentSpec = GetSpecialization()
    local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
    local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
    GSE.Print(L["Your current Specialisation is "] .. currentSpecID .. ':' .. specname .. L["  The Alternative ClassID is "] .. currentclassId, GNOME)
  elseif input == "help" then
    PrintGnomeHelp()
  elseif input == "cleanorphans" or input == "clean" then
    GSE.CleanOrphanSequences()
  elseif input == "forceclean" then
    GSE.CleanOrphanSequences()
    GSE.CleanMacroLibrary(true)
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    GSE.Print(GSExportSequence(string.sub(msg,8)))
  elseif input == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  elseif input == "record" then
      GSE.GUIRecordFrame:Show()
  elseif input == "debug" then
      GSE.GUIShowDebugWindow()
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
  GSE.OOCQueue = {}
  GSE.OOCTimer = GSE:ScheduleRepeatingTimer("TimerFeedback", 5)
end


function GSE:OOCQueue()
  if not InCombatLockdown() then
    for k,v in ipairs(GSE.OOCQueue) do
      if v.action == "UpdateSequence" then
        GSE.OOCUpdateSequence(v.name, v.macroversion)
      elseif v.action == "Save" then
        GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
      elseif v.action == "Replace" then
        GSELibrary[v.classid][v.sequencename] = v.sequence
        GSE.OOCUpdateSequence(v.sequencename, v.sequence.MacroVersions[GSE.GetActiveSequenceVersion(v.sequencename)])
      elseif v.action == "OpenGUI" then
        GSE.OOCGuiShowViewer()
      end
      GSE.OOCQueue[k] = nil
    end
  end
end

GSE.Print(GSEOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSEOptions.CommandColour .. L["/gs help|r to get started."], GNOME)

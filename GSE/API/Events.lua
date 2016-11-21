local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD, GCD_Update_Timer

local usoptions = GSE.UnsavedOptions




function GSE:PLAYER_LOGIN()
  GSE:UPDATE_MACROS()
end


function GSE:UPDATE_MACROS()
  if not InCombatLockdown() then
    GSE.PrintDebugMessage("I may not need this", GNOME)
  else
    GSE:RegisterEvent('PLAYER_REGEN_ENABLED')
  end
end

function GSE:PLAYER_ENTERING_WORLD()
  GSE.PrintAvailable = true
  GSE.PerformPrint()
  -- check macro stubs
  for k,v in pairs(GSEOptions.ActiveSequenceVersions) do
    sequence = GSELibrary[k][v]
    if sequence.specID == GSE.GetCurrentSpecID() or sequence.specID == GSE.GetCurrentClassID() then
      if GSEOptions.DisabledSequences[k] == true then
        GSE.DeleteMacroStub(k)
      else
        GSE.CheckMacroCreated(k)
      end
    end
  end
end

function GSE:ADDON_LOADED(addon)
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

end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
  if unit == "player" then
    local _, GCD_Timer = GetSpellCooldown(61304)
    GCD = true
    GCD_Update_Timer = C_Timer.After(GCD_Timer, function () GCD = nil; GSE.PrintDebugMessage("GCD OFF") end)
    GSE.PrintDebugMessage(L["GCD Delay:"] .. " " .. GCD_Timer)
    GSE.CurrentGCD = GCD_Timer

    if GSE.RecorderActive then
      GSE.GUI.RecordFrame.RecordSequenceBox:SetText(GSE.GUI.RecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n")
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
  GSE.PrepareLogout(GSEOptions.saveAllMacrosLocal)
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
  GSE.ReloadSequences()
end

GSE:RegisterEvent('UPDATE_MACROS')
GSE:RegisterEvent('PLAYER_LOGIN')

GSE:RegisterEvent('PLAYER_LOGOUT')
GSE:RegisterEvent('PLAYER_ENTERING_WORLD')
GSE:RegisterEvent('PLAYER_REGEN_ENABLED')
GSE:RegisterEvent('ADDON_LOADED')
GSE:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')

local function PrintGnomeHelp()
  GSE.Print(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
  GSE.Print(L["This is a small addon that allows you create a sequence of macros to be executed at the push of a button."], GNOME)
  GSE.Print(L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."], GNOME)
  GSE.Print(L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."], GNOME)
  GSE.Print(L["To get started "] .. GSEOptions.CommandColour .. L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."], GNOME)
  GSE.Print(GSEOptions.CommandColour .. L["/gs listall|r will produce a list of all available macros with some help information."], GNOME)
  GSE.Print(L["To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."], GNOME)
  GSE.Print(L["The command "] .. GSEOptions.CommandColour .. L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."], GNOME)
end

SLASH_GNOME1, SLASH_GNOME2, SLASH_GNOME3 = "/gnome", "/gs", "/gnomesequencer"
SlashCmdList["GNOME"] = function (msg, editbox)
  if string.lower(msg) == "listall" then
    GSE.ListSequences("all")
  elseif string.lower(msg) == "class" or string.lower(msg) == string.lower(UnitClass("player")) then
    local _, englishclass = UnitClass("player")
    GSE.ListSequences(englishclass)
  elseif string.lower(msg) == "showspec" then
    local currentSpec = GetSpecialization()
    local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
    local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
    GSE.Print(L["Your current Specialisation is "] .. currentSpecID .. ':' .. specname .. L["  The Alternative ClassID is "] .. currentclassId, GNOME)
  elseif string.lower(msg) == "help" then
    PrintGnomeHelp()
  elseif string.lower(msg) == "cleanorphans" or string.lower(msg) == "clean" then
    GSE.CleanOrphanSequences()
  elseif string.lower(msg) == "forceclean" then
    GSE.CleanOrphanSequences()
    GSE.CleanMacroLibrary(true)
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    GSE.Print(GSExportSequence(string.sub(msg,8)))
  elseif string.lower(msg) == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  else
    GSE.ListSequences(GetSpecialization())
  end
end

GSE.Print(GSEOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSEOptions.CommandColour .. L["/gs help|r to get started."], GNOME)

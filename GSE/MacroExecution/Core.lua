local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD, GCD_Update_Timer

local usoptions = GSE.UnsavedOptions

local function UpdateIcon(self)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = GSELibrary[button][GSGetActiveSequenceVersion(button)][step], false, ''
  for cmd, etc in gmatch(sequence or '', '/(%w+)%s+([^\n]+)') do
    if Statics.CastCmds[strlower(cmd)] then
      local spell, target = SecureCmdOptionParse(etc)
      GSE.TraceSequence(button, step, spell)
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
end


local function prepareKeyPress(KeyPress)
  if GSEOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 0)
    KeyPress = "/run sfx=GetCVar(\"Sound_EnableSFX\");\n/run ers=GetCVar(\"Sound_EnableErrorSpeech\");\n/console Sound_EnableSFX 0\n/console Sound_EnableErrorSpeech 0\n" .. KeyPress
  end
  if GSEOptions.requireTarget then
    -- see #20 prevent target hopping
    KeyPress = "/stopmacro [@playertarget, noexists]\n" .. KeyPress
  end
  return GSE.UnEscapeString(KeyPress)
end

local function prepareKeyRelease(KeyRelease)
  if GSEOptions.requireTarget then
    -- see #20 prevent target hopping
    KeyRelease = KeyRelease .. "\n/stopmacro [@playertarget, noexists]"
  end
  if GSEOptions.use11 then
    KeyRelease = KeyRelease .. "\n/use [combat] 11"
  end
  if GSEOptions.use12 then
    KeyRelease = KeyRelease .. "\n/use [combat] 12"
  end
  if GSEOptions.use13 then
    KeyRelease = KeyRelease .. "\n/use [combat] 13"
  end
  if GSEOptions.use14 then
    KeyRelease = KeyRelease .. "\n/use [combat] 14"
  end
  if GSEOptions.use2 then
    KeyRelease = KeyRelease .. "\n/use [combat] 2"
  end
  if GSEOptions.use1 then
    KeyRelease = KeyRelease .. "\n/use [combat] 1"
  end
  if GSEOptions.use6 then
    KeyRelease = KeyRelease .. "\n/use [combat] 6"
  end
  if GSEOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    KeyRelease = KeyRelease .. "\n/run SetCVar(\"Sound_EnableSFX\",sfx);\n/run SetCVar(\"Sound_EnableErrorSpeech\",ers);"
  end
  if GSEOptions.hideUIErrors then
    KeyRelease = KeyRelease .. "\n/script UIErrorsFrame:Hide();"
    -- potentially change this to UIErrorsFrame:Hide()
  end
  if GSEOptions.clearUIErrors then
    -- potentially change this to UIErrorsFrame:Clear()
    KeyRelease = KeyRelease .. "\n/run UIErrorsFrame:Clear()"
  end
  return GSE.UnEscapeString(KeyRelease)
end

local OnClick = [=[
local step = self:GetAttribute('step')
local loopstart = self:GetAttribute('loopstart') or 1
local loopstop = self:GetAttribute('loopstop') or #macros + 1
local loopiter = self:GetAttribute('loopiter') or 1
local looplimit = self:GetAttribute('looplimit') or 1
loopstart = tonumber(loopstart)
loopstop = tonumber(loopstop)
loopiter = tonumber(loopiter)
looplimit = tonumber(looplimit)
step = tonumber(step)
self:SetAttribute('macrotext', self:GetAttribute('KeyPress') .. macros[step] .. self:GetAttribute('KeyRelease'))
%s
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:CallMethod('UpdateIcon')
]=]



local function createButton(name, sequence)
  GSE.FixSequence(sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSE.UnEscapeSequence(sequence))) .. ']=======])')
  button:SetAttribute('step', 1)
  button:SetAttribute('KeyPress','\n' .. prepareKeyPress(sequence.KeyPress or ''))
  GSE.PrintDebugMessage(L["createButton KeyPress: "] .. button:GetAttribute('KeyPress'))
  button:SetAttribute('KeyRelease', '\n' .. prepareKeyRelease(sequence.KeyRelease or ''))
  GSE.PrintDebugMessage(L["createButton KeyRelease: "] .. button:GetAttribute('KeyRelease'))
  if GSE.isLoopSequence(sequence) then
    if GSE.isEmpty(sequence.StepFunction) then
      button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopSequential))
    else
      button:WrapScript(button, 'OnClick', format(OnClick, Statics.LoopPriority))
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
  else
    button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
  end
  button.UpdateIcon = UpdateIcon
end




local function prepareLogin()
  if not InCombatLockdown() then
    IgnoreMacroUpdates = true
    if not GSE.isEmpty(GSELibrary[2]) then
      local forremoval = {}
      local toprocess = {}
      for name, version in pairs(GSEOptions.ActiveSequenceVersions) do

        if GSE.isEmpty(GSELibrary[name][version]) then
          -- This value is missing.
          -- check if there is a version.
          ver = GSGetNextSequenceVersion(name)
          if ver then
            -- current version is broken but sequence exists.
            GSEOptions.ActiveSequenceVersions[name] = ver
            toprocess[name] = true
          else
            -- WHole Sequence Tree is no longer present.
            forremoval[name] = true
          end
        else
          toprocess[name] = true
        end
      end
      for name,_ in pairs(toprocess) do
        local macroIndex = GetMacroIndexByName(name)
        if macroIndex and macroIndex ~= 0 then
          if not GSE.ModifiedSequences[name] then
            GSE.ModifiedSequences[name] = true
            EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. name)
          end
          _G[name]:UpdateIcon()
        elseif GSE.ModifiedSequences[name] then
          GSE.ModifiedSequences[name] = nil
        end
      end
      for name,_ in pairs(forremoval) do
        if not GSE.isEmpty(name) then
          GSEOptions.ActiveSequenceVersions[name] = nil
        end
      end
      GSReloadSequences()
    end
    IgnoreMacroUpdates = false
  else
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
  end
end

local function processPlayerEnterWorld()
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

local function processAddonLoaded()
  if not GSE.isEmpty(GnomeOptions) then
    -- save temporary values the AddinPacks gets wiped from persisited memory
    for k,v in pairs(GnomeOptions) do
      if k == "SequenceLibrary" then
        -- Merge Sequence Library
        if not GSE.isEmpty(v) then
          for sname,sversion in pairs(v) do
            if not GSE.isEmpty(sversion) then
              for sver, sequence in pairs(sversion) do
                GSE.AddSequenceToCollection(sname, sequence, sver)
              end
            end
          end
        end
      elseif k == "ActiveSequenceVersions" then
        -- Merge Active Sequences History if locally set version is greater than the loaded in
        for n,ver in pairs(v) do
          if  GSE.isEmpty(GSEOptions.ActiveSequenceVersions[n]) then
            GSEOptions.ActiveSequenceVersions[n] = ver
          elseif ver > GSEOptions.ActiveSequenceVersions[n] then
            GSEOptions.ActiveSequenceVersions[n] = ver
          end
        end
      else
        GSEOptions[k] = v
      end
    end
    -- Add Macro Stubs for all current spec'd macros.
    for k,v in pairs(GSEOptions.ActiveSequenceVersions) do
      if GSE.isEmpty(GSELibrary[k]) then
        GSEOptions.ActiveSequenceVersions[k] = nil
      end
    end
  end
  if GSE.isEmpty(GSEOptions.SequenceLibrary[GSE.GetCurrentClassID()]) then
    StaticPopup_Show ("GSE-SampleMacroDialog")
  end
  GSE.PrintDebugMessage(L["I am loaded"])
  GSE.ReloadSequences()
  GSE:SendMessage(Statics.CoreLoadedMessage)
end

local function processUnitSpellcast(addon)
  if addon == "player" then
    local _, GCD_Timer = GetSpellCooldown(61304)
    GCD = true
    GCD_Update_Timer = C_Timer.After(GCD_Timer, function () GCD = nil; GSE.PrintDebugMessage("GCD OFF") end)
    GSE.PrintDebugMessage(L["GCD Delay:"] .. " " .. GCD_Timer)
  end
end


local IgnoreMacroUpdates = false
local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(self, event, addon)
  if (event == 'UPDATE_MACROS' or event == 'PLAYER_LOGIN') and not IgnoreMacroUpdates then
    prepareLogin()
  elseif event == 'PLAYER_REGEN_ENABLED' then
    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
    self:GetScript('OnEvent')(self, 'UPDATE_MACROS')
    if GSEOptions.resetOOC then
      GSE.ResetButtons()
    end
    f:RegisterEvent('PLAYER_REGEN_ENABLED')
  elseif event == 'PLAYER_LOGOUT' then
    GSPrepareLogout(GSEOptions.saveAllMacrosLocal)
  elseif event == 'PLAYER_ENTERING_WORLD' then
    processPlayerEnterWorld()
  elseif event == 'ADDON_LOADED' and addon == "GS-Core" then
    processAddonLoaded()
  elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
    processUnitSpellcast(addon)
  end
end)
f:RegisterEvent('UPDATE_MACROS')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGOUT')
f:RegisterEvent('PLAYER_ENTERING_WORLD')
f:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
f:RegisterEvent('PLAYER_REGEN_ENABLED')


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

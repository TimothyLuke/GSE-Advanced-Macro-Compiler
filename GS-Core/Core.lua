seterrorhandler(_ERRORMESSAGE)

local GNOME, _ = ...

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")
local AceEvent = LibStub("AceEvent-3.0")

local GCD, GCD_Update_Timer

local function GSisLoopSequence(sequence)
  local loopcheck = false
  if not GSisEmpty(sequence.loopstart) then
    loopcheck = true
  end
  if not GSisEmpty(sequence.loopstop) then
    loopcheck = true
  end
  if not GSisEmpty(sequence.looplimit) then
    loopcheck = true
  end
  return loopcheck
end


local function GSTraceSequence(button, step, task)
  if GSDebugSequenceEx then
    -- Note to self do i care if its a loop sequence?
    local isUsable, notEnoughMana = IsUsableSpell(task)
    local usableOutput, manaOutput, GCDOutput, CastingOutput
    if isUsable then
      usableOutput = GSMasterOptions.CommandColour .. "Able To Cast" .. GSStaticStringRESET
    else
      usableOutput =  GSMasterOptions.UNKNOWN .. "Not Able to Cast" .. GSStaticStringRESET
    end
    if notEnoughMana then
      manaOutput = GSMasterOptions.UNKNOWN .. "Resources Not Available".. GSStaticStringRESET
    else
      manaOutput =  GSMasterOptions.CommandColour .. "Resources Available" .. GSStaticStringRESET
    end
    local castingspell, _, _, _, _, _, castspellid, _ = UnitCastingInfo("player")
    if not GSisEmpty(castingspell) then
      CastingOutput = GSMasterOptions.UNKNOWN .. "Casting " .. castingspell .. GSStaticStringRESET
    else
      CastingOutput = GSMasterOptions.CommandColour .. "Not actively casting anything else." .. GSStaticStringRESET
    end
    GCDOutput =  GSMasterOptions.CommandColour .. "GCD Free" .. GSStaticStringRESET
    if GCD then
      GCDOutput = GSMasterOptions.UNKNOWN .. "GCD In Cooldown" .. GSStaticStringRESET
    end
    GSPrintDebugMessage(button .. "," .. step .. "," .. (task and task or "nil")  .. "," .. usableOutput .. "," .. manaOutput .. "," .. GCDOutput .. "," .. CastingOutput, GSStaticSequenceDebug)
  end
end

local function UpdateIcon(self)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = GSMasterOptions.SequenceLibrary[button][GSGetActiveSequenceVersion(button)][step], false, ''
  for cmd, etc in gmatch(sequence or '', '/(%w+)%s+([^\n]+)') do
    if GSStaticCastCmds[strlower(cmd)] then
      local spell, target = SecureCmdOptionParse(etc)
      GSTraceSequence(button, step, spell)
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

local cvar_Sound_EnableSFX = GetCVar("Sound_EnableSFX")
local cvar_Sound_EnableErrorSpeech = GetCVar("Sound_EnableErrorSpeech")


local function preparePreMacro(premacro)
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 0)
    premacro = "/run sfx=GetCVar(\"Sound_EnableSFX\");\n/run ers=GetCVar(\"Sound_EnableErrorSpeech\");\n/console Sound_EnableSFX 0\n/console Sound_EnableErrorSpeech 0\n" .. premacro
  end
  if GSMasterOptions.requireTarget then
    -- see #20 prevent target hopping
    premacro = "/stopmacro [@playertarget, noexists]\n" .. premacro
  end
  return GSTRUnEscapeString(premacro)
end

local function preparePostMacro(postmacro)
  if GSMasterOptions.requireTarget then
    -- see #20 prevent target hopping
    postmacro = postmacro .. "\n/stopmacro [@playertarget, noexists]"
  end
  if GSMasterOptions.use11 then
    postmacro = postmacro .. "\n/use [combat] 11"
  end
  if GSMasterOptions.use12 then
    postmacro = postmacro .. "\n/use [combat] 12"
  end
  if GSMasterOptions.use13 then
    postmacro = postmacro .. "\n/use [combat] 13"
  end
  if GSMasterOptions.use14 then
    postmacro = postmacro .. "\n/use [combat] 14"
  end
  if GSMasterOptions.use2 then
    postmacro = postmacro .. "\n/use [combat] 2"
  end
  if GSMasterOptions.use1 then
    postmacro = postmacro .. "\n/use [combat] 1"
  end
  if GSMasterOptions.use6 then
    postmacro = postmacro .. "\n/use [combat] 6"
  end
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    postmacro = postmacro .. "\n/run SetCVar(\"Sound_EnableSFX\",sfx);\n/run SetCVar(\"Sound_EnableErrorSpeech\",ers);"
  end
  if GSMasterOptions.hideUIErrors then
    postmacro = postmacro .. "\n/script UIErrorsFrame:Hide();"
    -- potentially change this to UIErrorsFrame:Hide()
  end
  if GSMasterOptions.clearUIErrors then
    -- potentially change this to UIErrorsFrame:Clear()
    postmacro = postmacro .. "\n/run UIErrorsFrame:Clear()"
  end
  return GSTRUnEscapeString(postmacro)
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
self:SetAttribute('macrotext', self:GetAttribute('PreMacro') .. macros[step] .. self:GetAttribute('PostMacro'))
%s
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:CallMethod('UpdateIcon')
]=]

function GSSplitMeIntolines(str)
  GSPrintDebugMessage(L["Entering GSSplitMeIntolines with :"] .. "\n" .. str, GNOME)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    GSPrintDebugMessage(L["Line : "] .. line, GNOME)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local function GSFixSequence(sequence)
  for k,v in pairs(GSStaticCleanStrings) do
    GSPrintDebugMessage(L["Testing String: "] .. v, GNOME)
    if not GSisEmpty(sequence.PreMacro) then sequence.PreMacro = string.gsub(sequence.PreMacro, v, "") end
    if not GSisEmpty(sequence.PostMacro) then sequence.PostMacro = string.gsub(sequence.PostMacro, v, "") end
  end
end


local function createButton(name, sequence)
  GSFixSequence(sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSTRUnEscapeSequence(sequence))) .. ']=======])')
  button:SetAttribute('step', 1)
  button:SetAttribute('PreMacro','\n' .. preparePreMacro(sequence.PreMacro or ''))
  GSPrintDebugMessage(L["createButton PreMacro: "] .. button:GetAttribute('PreMacro'))
  button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
  GSPrintDebugMessage(L["createButton PostMacro: "] .. button:GetAttribute('PostMacro'))
  if GSisLoopSequence(sequence) then
    if GSisEmpty(sequence.StepFunction) then
      button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopSequential))
    else
      button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopPriority))
    end
    if not GSisEmpty(sequence.loopstart) then
      button:SetAttribute('loopstart', sequence.loopstart)
    end
    if not GSisEmpty(sequence.loopstop) then
      button:SetAttribute('loopstop', sequence.loopstop)
    end
    if not GSisEmpty(sequence.looplimit) then
      button:SetAttribute('looplimit', sequence.looplimit)
    end
  else
    button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
  end
  button.UpdateIcon = UpdateIcon
end

function GSReloadSequences()
  GSPrintDebugMessage(L["Reloading Sequences"])
  for name, version in pairs(GSMasterOptions.ActiveSequenceVersions) do
    GSPrintDebugMessage(name .. " " .. version )
    if not GSisEmpty(GSMasterOptions.SequenceLibrary[name]) then
      vers = GSGetActiveSequenceVersion(name)
      GSPrintDebugMessage(vers)
      if not GSisEmpty(GSMasterOptions.SequenceLibrary[name][vers]) then
        GSUpdateSequence(name, GSMasterOptions.SequenceLibrary[name][vers])
      else
        GSMasterOptions.ActiveSequenceVersions[name] = nil
        GSPrintDebugMessage(L["Removing "] .. name .. L[" From library"])
      end
    end
  end
end

local function deleteMacroStub(sequenceName)
  local mname, _, mbody = GetMacroInfo(sequenceName)
  if mname == sequenceName then
    trimmedmbody = mbody:gsub("[^%w ]", "")
    compar = '#showtooltip\n/click ' .. mname
    trimmedcompar = compar:gsub("[^%w ]", "")
    if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
      GSPrint(L[" Deleted Orphaned Macro "] .. mname, GNOME)
      DeleteMacro(sequenceName)
    end
  end
end

function GSToggleDisabledSequence(SequenceName)
  if GSMasterOptions.DisabledSequences[SequenceName] then
    -- Sequence has potentially been Disabled
    if GSMasterOptions.DisabledSequences[SequenceName] == true then
      -- Definately disabled - enabling
      GSMasterOptions.DisabledSequences[SequenceName] = nil
      GSCheckMacroCreated(SequenceName)
      GSPrint(GSMasterOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been enabled.  The Macro stub is now available in your Macro interface."], GNOME)
    else
      -- Disabling
      GSMasterOptions.DisabledSequences[SequenceName] = true
      deleteMacroStub(SequenceName)
      GSPrint(GSMasterOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been disabled.  The Macro stub for this sequence will be deleted and will not be recreated until you re-enable this sequence.  It will also not appear in the /gs list until it is recreated."], GNOME)
    end
  else
    -- disabliong
    GSMasterOptions.DisabledSequences[SequenceName] = true
    deleteMacroStub(SequenceName)
    GSPrint(GSMasterOptions.EmphasisColour .. SequenceName .. "|r " .. L["has been disabled.  The Macro stub for this sequence will be deleted and will not be recreated until you re-enable this sequence.  It will also not appear in the /gs list until it is recreated."], GNOME)
  end
  GSReloadSequences()
end

local function cleanOrphanSequences()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
  local todelete = {}
  for macid = 1, maxmacros do
    local found = false
    local mname, mtexture, mbody = GetMacroInfo(macid)
    if not GSisEmpty(mname) then
      for name, _ in pairs(GSMasterOptions.ActiveSequenceVersions) do
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
    deleteMacroStub(k)
  end
end

local function CleanMacroLibrary(logout)
  -- clean out the sequences database except for the current version
  local tempTable = {}
  for name, versiontable in pairs(GSMasterOptions.SequenceLibrary) do
    GSPrintDebugMessage(L["Testing "] .. name )

    if not GSisEmpty(GSMasterOptions.ActiveSequenceVersions[name]) then
      GSPrintDebugMessage(L["Active Version "] .. GSMasterOptions.ActiveSequenceVersions[name])
    else
      GSPrintDebugMessage(L["No Active Version"] .. " " .. name)
    end
    for version, sequence in pairs(versiontable) do
      GSPrintDebugMessage(L["Cycle Version "] .. version )
      GSPrintDebugMessage(L["Source "] .. sequence.source)
      if sequence.source == GSStaticSourceLocal then
        -- Save user created entries.  If they are in a mod dont save them as they will be reloaded next load.
        GSPrintDebugMessage("sequence.source == GSStaticSourceLocal")
        if GSisEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSTRUnEscapeSequence(sequence)
      elseif GSMasterOptions.ActiveSequenceVersions[name] == version and not logout  then
        GSPrintDebugMessage("GSMasterOptions.ActiveSequenceVersions[name] == version and not logout")
        if GSisEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSTRUnEscapeSequence(sequence)
      elseif sequence.source == GSStaticSourceTransmission then
        if GSisEmpty(tempTable[name]) then
          tempTable[name] = {}
        end
        tempTable[name][version] = GSTRUnEscapeSequence(sequence)
      else
        GSPrintDebugMessage(L["Removing "] .. name .. ":" .. version)
      end
    end
  end
  GSMasterOptions.SequenceLibrary = nil
  GSMasterOptions.SequenceLibrary = tempTable
end

function GSPrepareLogout(deletenonlocalmacros)
  CleanMacroLibrary(deletenonlocalmacros)
  if GSMasterOptions.deleteOrphansOnLogout then
    cleanOrphanSequences()
  end
  GnomeOptions = GSMasterOptions
end

local function prepareLogin()
  if not InCombatLockdown() then
    IgnoreMacroUpdates = true
    if not GSisEmpty(GSMasterOptions.SequenceLibrary[2]) then
      local forremoval = {}
      local toprocess = {}
      for name, version in pairs(GSMasterOptions.ActiveSequenceVersions) do

        if GSisEmpty(GSMasterOptions.SequenceLibrary[name][version]) then
          -- This value is missing.
          -- check if there is a version.
          ver = GSGetNextSequenceVersion(name)
          if ver then
            -- current version is broken but sequence exists.
            GSMasterOptions.ActiveSequenceVersions[name] = ver
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
          if not GSModifiedSequences[name] then
            GSModifiedSequences[name] = true
            EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. name)
          end
          _G[name]:UpdateIcon()
        elseif GSModifiedSequences[name] then
          GSModifiedSequences[name] = nil
        end
      end
      for name,_ in pairs(forremoval) do
        if not GSisEmpty(name) then
          GSMasterOptions.ActiveSequenceVersions[name] = nil
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
  GSPrintAvailable = true
  GSPerformPrint()
  -- check macro stubs
  for k,v in pairs(GSMasterOptions.ActiveSequenceVersions) do
    sequence = GSMasterOptions.SequenceLibrary[k][v]
    if sequence.specID == GSGetCurrentSpecID() or sequence.specID == GSGetCurrentClassID() then
      if GSMasterOptions.DisabledSequences[k] == true then
        deleteMacroStub(k)
      else
        GSCheckMacroCreated(k)
      end
    end
  end
end

local function processAddonLoaded()
  if not GSisEmpty(GnomeOptions) then
    -- save temporary values the AddinPacks gets wiped from persisited memory
    for k,v in pairs(GnomeOptions) do
      if k == "SequenceLibrary" then
        -- Merge Sequence Library
        if not GSisEmpty(v) then
          for sname,sversion in pairs(v) do
            if not GSisEmpty(sversion) then
              for sver, sequence in pairs(sversion) do
                GSAddSequenceToCollection(sname, sequence, sver)
              end
            end
          end
        end
      elseif k == "ActiveSequenceVersions" then
        -- Merge Active Sequences History if locally set version is greater than the loaded in
        for n,ver in pairs(v) do
          if  GSisEmpty(GSMasterOptions.ActiveSequenceVersions[n]) then
            GSMasterOptions.ActiveSequenceVersions[n] = ver
          elseif ver > GSMasterOptions.ActiveSequenceVersions[n] then
            GSMasterOptions.ActiveSequenceVersions[n] = ver
          end
        end
      else
        GSMasterOptions[k] = v
      end
    end
    -- Add Macro Stubs for all current spec'd macros.
    for k,v in pairs(GSMasterOptions.ActiveSequenceVersions) do
      if GSisEmpty(GSMasterOptions.SequenceLibrary[k]) then
        GSMasterOptions.ActiveSequenceVersions[k] = nil
      end
    end
  end
  GSPrintDebugMessage(L["I am loaded"])
  GSReloadSequences()
  GnomeOptions = GSMasterOptions
  AceEvent:SendMessage(GSStaticCoreLoadedMessage)
end

local function processUnitSpellcast(addon)
  if addon == "player" then
    local _, GCD_Timer = GetSpellCooldown(61304)
    GCD = true
    GCD_Update_Timer = C_Timer.After(GCD_Timer, function () GCD = nil; GSPrintDebugMessage("GCD OFF") end)
    GSPrintDebugMessage(L["GCD Delay:"] .. " " .. GCD_Timer)
  end
end

local function ResetButtons()
  for k,v in pairs(GSMasterOptions.ActiveSequenceVersions) do
    if GSisSpecIDForCurrentClass(GSMasterOptions.SequenceLibrary[k][v].specID) then
      button = _G[k]
      button:SetAttribute("step",1)
      UpdateIcon(button)
    end
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
    if GSMasterOptions.resetOOC then
      ResetButtons()
    end
    f:RegisterEvent('PLAYER_REGEN_ENABLED')
  elseif event == 'PLAYER_LOGOUT' then
    GSPrepareLogout(GSMasterOptions.saveAllMacrosLocal)
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


function GSExportSequence(sequenceName)
  --- Creates a string representation of the a Sequence that can be shared as a string.
  --      Accepts <code>SequenceName</code>
  if GSisEmpty(GSMasterOptions.ActiveSequenceVersions[sequenceName]) then
    return GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. L[" Sequence named "] .. sequenceName .. L[" is unknown."]
  else
    return GSExportSequencebySeq(GSMasterOptions.SequenceLibrary[sequenceName][GSGetActiveSequenceVersion(sequenceName)], sequenceName)
  end
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSExportSequencebySeq(sequence, sequenceName)
  GSPrintDebugMessage("GSExportSequencebySeq Sequence Name: " .. sequenceName)
  local disabledseq = ""
  if GSMasterOptions.DisabledSequences[sequenceName] then
    disabledseq = GSMasterOptions.UNKNOWN .. "-- " .. L["This Sequence is currently Disabled Locally."] .. GSStaticStringRESET .. "\n"
  end
  local helptext = "helpTxt = \"" .. GSMasterOptions.INDENT .. (GSisEmpty(sequence.helpTxt) and "No Help Information" or sequence.helpTxt) .. GSStaticStringRESET .. "\",\n"
  local specversion = "version=" .. GSMasterOptions.NUMBER  ..(GSisEmpty(sequence.version) and "1" or sequence.version ) .. GSStaticStringRESET ..",\n"
  local source = "source = \"" .. GSMasterOptions.INDENT .. (GSisEmpty(sequence.source) and "Unknown Source" or sequence.source) .. GSStaticStringRESET .. "\",\n"
  if not GSisEmpty(sequence.authorversion) then
    source = source .. "authorversion = \"" .. GSMasterOptions.INDENT .. sequence.authorversion .. GSStaticStringRESET .. "\",\n"
  end
  local steps = ""
  if not GSisEmpty(sequence.StepFunction) then
    if  sequence.StepFunction == GSStaticPriority then
     steps = "StepFunction = " .. GSMasterOptions.EQUALS .. "GSStaticPriority" .. GSStaticStringRESET .. ",\n"
    else
     steps = "StepFunction = [[" .. GSMasterOptions.EQUALS .. sequence.StepFunction .. GSStaticStringRESET .. "]],\n"
    end
  end
  local internalloop = ""
  if GSisLoopSequence(sequence) then
    if not GSisEmpty(sequence.loopstart) then
      internalloop = internalloop .. "loopstart=" .. GSMasterOptions.EQUALS .. sequence.loopstart .. GSStaticStringRESET .. ",\n"
    end
    if not GSisEmpty(sequence.loopstop) then
      internalloop = internalloop .. "loopstop=" .. GSMasterOptions.EQUALS .. sequence.loopstop .. GSStaticStringRESET .. ",\n"
    end
    if not GSisEmpty(sequence.looplimit) then
      internalloop = internalloop .. "looplimit=" .. GSMasterOptions.EQUALS .. sequence.looplimit .. GSStaticStringRESET .. ",\n"
    end
  end

  --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. helptext .. steps )
  local returnVal = (disabledseq .. "Sequences['" .. GSMasterOptions.EmphasisColour .. sequenceName .. GSStaticStringRESET .. "'] = {\nauthor=\"" .. GSMasterOptions.AuthorColour .. (GSisEmpty(sequence.author) and "Unknown Author" or sequence.author) .. GSStaticStringRESET .. "\",\n" .. (GSisEmpty(sequence.specID) and "-- Unknown specID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "specID=" .. GSMasterOptions.NUMBER  .. sequence.specID .. GSStaticStringRESET ..",\n") .. specversion .. source .. helptext .. steps .. internalloop)
  if not GSisEmpty(sequence.icon) then
     returnVal = returnVal .. "icon=" .. GSMasterOptions.CONCAT .. (tonumber(sequence.icon) and sequence.icon or "'".. sequence.icon .. "'") .. GSStaticStringRESET ..",\n"
  end
  if not GSisEmpty(sequence.lang) then
    returnVal = returnVal .. "lang=\"" .. GSMasterOptions.STANDARDFUNCS .. sequence.lang .. GSStaticStringRESET .. "\",\n"
  end
  returnVal = returnVal .. "PreMacro=[[\n" .. (GSisEmpty(sequence.PreMacro) and "" or sequence.PreMacro) .. "]]," .. "\n\"" .. table.concat(sequence,"\",\n\"") .. "\",\n"
  returnVal = returnVal .. "PostMacro=[[\n" .. (GSisEmpty(sequence.PostMacro) and "" or sequence.PostMacro) .. "]],\n}"
  return returnVal
end

local function ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(GSMasterOptions.SequenceLibrary) do
    if GSMasterOptions.DisabledSequences[name] then
      GSPrint(GSMasterOptions.CommandColour .. name ..'|r ' .. L["is currently disabled from use."], GNOME)
    elseif not GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].specID) then
      local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence[GSGetActiveSequenceVersion(name)].specID)
      GSPrintDebugMessage(L["Sequence Name: "] .. name)
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSPrintDebugMessage(L["No Specialisation information for sequence "] .. name .. L[". Overriding with information for current spec "] .. specname)
      if sequence[GSGetActiveSequenceVersion(name)].specID == currentSpecID or string.upper(txt) == specclass then
        GSPrint(GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. GSMasterOptions.INDENT .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. GSStaticStringRESET .. ' ' .. GSMasterOptions.EmphasisColour .. specclass .. '|r ' .. specname .. ' ' .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME)
        GSregisterSequence(name, (GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      elseif txt == "all" or sequence[GSGetActiveSequenceVersion(name)].specID == 0  then
        GSPrint(GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt or L["No Help Information "] .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME)
      elseif sequence[GSGetActiveSequenceVersion(name)].specID == currentclassId then
        GSPrint(GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. ' ' .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ', GNOME )
        GSregisterSequence(name, (GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      end
    else
      GSPrint(GSMasterOptions.CommandColour .. name .. L["|r Incomplete Sequence Definition - This sequence has no further information "] .. GSMasterOptions.AuthorColour .. L["Unknown Author|r "], GNOME )
    end
  end
  ShowMacroFrame()
end

function GSUpdateSequence(name,sequence)
    local button = _G[name]
    -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
    if GSTranslatorAvailable and GSisSpecIDForCurrentClass(sequence.specID) then
      sequence = GSTranslateSequence(sequence, name)
    end
    if GSisEmpty(_G[name]) then
      createButton(name, sequence)
    else
      button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(GSTRUnEscapeSequence(sequence))) .. ']=======])')
      button:SetAttribute("step",1)
      button:SetAttribute('PreMacro',preparePreMacro(sequence.PreMacro or '') .. '\n')
      GSPrintDebugMessage(L["GSUpdateSequence PreMacro updated to: "] .. button:GetAttribute('PreMacro'))
      button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
      GSPrintDebugMessage(L["GSUpdateSequence PostMacro updated to: "] .. button:GetAttribute('PostMacro'))
      button:UnwrapScript(button,'OnClick')
      if GSisLoopSequence(sequence) then
        if GSisEmpty(sequence.StepFunction) then
          button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopSequential))
        else
          button:WrapScript(button, 'OnClick', format(OnClick, GSStaticLoopPriority))
        end
      else
        button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
      end

    end
end

function GSDebugDumpButton(SequenceName)
  GSPrint("Button name: "  .. SequenceName)
  GSPrint(_G[SequenceName]:GetScript('OnClick'))
  GSPrint("PreMacro" .. _G[SequenceName]:GetAttribute('PreMacro'))
  GSPrint("PostMacro" .. _G[SequenceName]:GetAttribute('PostMacro'))
  GSPrint(format(OnClick, GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].StepFunction or 'step = step % #macros + 1'))
end

local function PrintGnomeHelp()
  GSPrint(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
  GSPrint(L["This is a small addon that allows you create a sequence of macros to be executed at the push of a button."], GNOME)
  GSPrint(L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."], GNOME)
  GSPrint(L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."], GNOME)
  GSPrint(L["To get started "] .. GSMasterOptions.CommandColour .. L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."], GNOME)
  GSPrint(GSMasterOptions.CommandColour .. L["/gs listall|r will produce a list of all available macros with some help information."], GNOME)
  GSPrint(L["To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar."], GNOME)
  GSPrint(L["The command "] .. GSMasterOptions.CommandColour .. L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."], GNOME)
  GSPrint(L["The command "] .. GSMasterOptions.CommandColour .. L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."], GNOME)
end

SLASH_GNOME1, SLASH_GNOME2, SLASH_GNOME3 = "/gnome", "/gs", "/gnomesequencer"
SlashCmdList["GNOME"] = function (msg, editbox)
  if string.lower(msg) == "listall" then
    ListSequences("all")
  elseif string.lower(msg) == "class" or string.lower(msg) == string.lower(UnitClass("player")) then
    local _, englishclass = UnitClass("player")
    ListSequences(englishclass)
  elseif string.lower(msg) == "showspec" then
    local currentSpec = GetSpecialization()
    local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
    local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
    GSPrint(L["Your current Specialisation is "] .. currentSpecID .. ':' .. specname .. L["  The Alternative ClassID is "] .. currentclassId, GNOME)
  elseif string.lower(msg) == "help" then
    PrintGnomeHelp()
  elseif string.lower(msg) == "cleanorphans" or string.lower(msg) == "clean" then
    cleanOrphanSequences()
  elseif string.lower(msg) == "forceclean" then
    cleanOrphanSequences()
    CleanMacroLibrary(true)
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    GSPrint(GSExportSequence(string.sub(msg,8)))
  elseif string.lower(msg) == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  else
    ListSequences(GetSpecialization())
  end
end

GSPrint(GSMasterOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSMasterOptions.CommandColour .. L["/gs help|r to get started."], GNOME)

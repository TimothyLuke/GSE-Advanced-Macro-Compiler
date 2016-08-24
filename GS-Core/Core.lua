seterrorhandler(_ERRORMESSAGE)

local GNOME, _ = ...

local ModifiedSequences = {} -- [sequenceName] = true if we've already modified this sequence
local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")


local function UpdateIcon(self)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = GSMasterOptions.SequenceLibrary[button][GSGetActiveSequenceVersion(button)][step], false, ''
  for cmd, etc in gmatch(sequence or '', '/(%w+)%s+([^\n]+)') do
    if GSStaticCastCmds[strlower(cmd)] then
      local spell, target = SecureCmdOptionParse(etc)
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

local function preparePreMacro(premacro)
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 0)
    premacro = "/console Sound_EnableErrorSpeech 0\n" .. premacro
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
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    postmacro = postmacro .. "\n/console Sound_EnableErrorSpeech 1"
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
self:SetAttribute('macrotext', self:GetAttribute('PreMacro') .. macros[step] .. self:GetAttribute('PostMacro'))
%s
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil')
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
  button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
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


local function cleanOrphanSequences()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
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
        trimmedmbody = mbody:gsub("[^%w ]", "")
        compar = '#showtooltip\n/click ' .. mname
        trimmedcompar = compar:gsub("[^%w ]", "")
        if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
          print(GSMasterOptions.TitleColour .. GNOME .. ':|r' .. L[" Deleted Orphaned Macro "] .. mname)
          DeleteMacro(macid)
        end
      end
    end
  end
end

local function CleanMacroLibrary(logout)
  -- clean out the sequences database except for the current version
  local tempTable = {}
  for name, versiontable in pairs(GSMasterOptions.SequenceLibrary) do

    for version, sequence in ipairs(versiontable) do
      if GSMasterOptions.SequenceLibrary[name][version].source == GSStaticSourceLocal or (GSMasterOptions.ActiveSequenceVersions[name] == version and not logout ) then
        -- Save user created entries.  If they are in a mod dont save them as they will be reloaded next load.
        tempTable[name] = {}
        tempTable[name][version] = GSMasterOptions.SequenceLibrary[name][version]
      else
        GSPrintDebugMessage(L["Removing "] .. name .. ":" .. version)
      end
    end
  end
  GSMasterOptions.SequenceLibrary = nil
  GSMasterOptions.SequenceLibrary = tempTable
end

local IgnoreMacroUpdates = false
local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(self, event, addon)
  if (event == 'UPDATE_MACROS' or event == 'PLAYER_LOGIN') and not IgnoreMacroUpdates then
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
            if not ModifiedSequences[name] then
              ModifiedSequences[name] = true
              EditMacro(macroIndex, nil, nil, '#showtooltip\n/click ' .. name)
            end
            _G[name]:UpdateIcon()
          elseif ModifiedSequences[name] then
            ModifiedSequences[name] = nil
          end
        end
        for name,_ in pairs(forremoval) do
          if not GSisEmpty(name) then
            GSMasterOptions.ActiveSequenceVersions[name] = nil
          end
        end
      end
      IgnoreMacroUpdates = false
    else
      self:RegisterEvent('PLAYER_REGEN_ENABLED')
    end
  elseif event == 'PLAYER_REGEN_ENABLED' then
    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
    self:GetScript('OnEvent')(self, 'UPDATE_MACROS')
  elseif event == 'PLAYER_LOGOUT' then
    -- Delete "LiveTest" macro from Macrolist as it is not persisted
    GnomeOptions = GSMasterOptions
    if GSMasterOptions.saveAllMacrosLocal then
      CleanMacroLibrary(true)
    end
    if GSMasterOptions.deleteOrphansOnLogout then
      cleanOrphanSequences()
    end
    -- clean out the sequences database except for the local version prior to saving
  elseif event == 'ADDON_LOADED' and addon == "GS-Core" then
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
      for k,v in pairs(GSMasterOptions.ActiveSequenceVersions) do
        if GSisEmpty(GSMasterOptions.SequenceLibrary[k]) then
          GSMasterOptions.ActiveSequenceVersions[k] = nil
        end
      end
    end
    GSPrintDebugMessage(L["I am loaded"])
    GSReloadSequences()
  end
end)
f:RegisterEvent('UPDATE_MACROS')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGOUT')


----------------------------
-- Draik's Mods
----------------------------

function GSExportSequence(sequenceName)
  if GSisEmpty(GSMasterOptions.ActiveSequenceVersions[sequenceName]) then
    return GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. L[" Sequence named "] .. sequenceName .. L[" is unknown."]
  else
    return GSExportSequencebySeq(GSMasterOptions.SequenceLibrary[sequenceName][GSGetActiveSequenceVersion(sequenceName)], sequenceName)
  end
end

function GSExportSequencebySeq(sequence, sequenceName)
  GSPrintDebugMessage("GSExportSequencebySeq Sequence Name: " .. sequenceName)
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
  --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. helptext .. steps )
  local returnVal = ("Sequences['" .. GSMasterOptions.EmphasisColour .. sequenceName .. GSStaticStringRESET .. "'] = {\nauthor=\"" .. GSMasterOptions.AuthorColour .. (GSisEmpty(sequence.author) and "Unknown Author" or sequence.author) .. GSStaticStringRESET .. "\",\n" .. (GSisEmpty(sequence.specID) and "-- Unknown specID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "specID=" .. GSMasterOptions.NUMBER  .. sequence.specID .. GSStaticStringRESET ..",\n") .. specversion .. source .. helptext .. steps )
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

function GSsetMacroLocation()
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  local returnval = 1
  if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSMasterOptions.overflowPersonalMacros then
   returnval = nil
  end
  return returnval
end

local function GSregisterSequence(sequenceName, icon)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  local numAccountMacros, numCharacterMacros = GetNumMacros()
  if sequenceIndex > 0 then
    -- Sequence exists do nothing
    GSPrintDebugMessage(L["Moving on - "] .. sequenceName .. L[" already exists."], GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSMasterOptions.overflowPersonalMacros then
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSMasterOptions.EmphasisColour .. numCharacterMacros .. L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] .. GSMasterOptions.CommandColour .. L["/gs|r again."])
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSMasterOptions.overflowPersonalMacros then
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["Close to Maximum Macros.|r  You can have a maximum of "].. MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] .. GSMasterOptions.EmphasisColour .. numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS .. L[" macros per Account.  You currently have "] .. GSMasterOptions.EmphasisColour .. numAccountMacros .. L["|r. As a result this macro was not created.  Please delete some macros and reenter "] .. GSMasterOptions.CommandColour .. L["/gs|r again."])
    else
      sequenceid = CreateMacro(sequenceName, (GSMasterOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), '#showtooltip\n/click ' .. sequenceName, GSsetMacroLocation() )
      ModifiedSequences[sequenceName] = true
    end
  end
end


local function ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(GSMasterOptions.SequenceLibrary) do
    if not GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].specID) then
      local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence[GSGetActiveSequenceVersion(name)].specID)
      GSPrintDebugMessage(L["Sequence Name: "] .. name)
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSPrintDebugMessage(L["No Specialisation information for sequence "] .. name .. L[". Overriding with information for current spec "] .. specname)
      if sequence[GSGetActiveSequenceVersion(name)].specID == currentSpecID or string.upper(txt) == specclass then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. GSMasterOptions.INDENT .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. GSStaticStringRESET .. ' ' .. GSMasterOptions.EmphasisColour .. specclass .. '|r ' .. specname .. ' ' .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ' )
        GSregisterSequence(name, (GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      elseif txt == "all" or sequence[GSGetActiveSequenceVersion(name)].specID == 0  then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt or L["No Help Information "] .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ' )
      elseif sequence[GSGetActiveSequenceVersion(name)].specID == currentclassId then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. L["Version="] .. sequence[GSGetActiveSequenceVersion(name)].version  .. " " .. sequence[GSGetActiveSequenceVersion(name)].helpTxt .. ' ' .. GSMasterOptions.AuthorColour .. L["Contributed by: "] .. sequence[GSGetActiveSequenceVersion(name)].author ..'|r ' )
        GSregisterSequence(name, (GSisEmpty(sequence[GSGetActiveSequenceVersion(name)].icon) and strsub(specicon, 17) or sequence[GSGetActiveSequenceVersion(name)].icon))
      end
    else
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name .. L["|r Incomplete Sequence Definition - This sequence has no further information "] .. GSMasterOptions.AuthorColour .. L["Unknown Author|r "] )
    end
  end
  ShowMacroFrame()
end

local function checkCurrentClass(specID)
  local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
  if specID > 15 then
    GSPrintDebugMessage(L["Checking if specID "] .. specID .. " " .. specclass .. L[" equals "] .. currentenglishclass)
  else
    GSPrintDebugMessage(L["Checking if specID "] .. specID .. L[" equals currentclassid "] .. currentclassId)
  end
  return (specclass==currentenglishclass or specID==currentclassId)
end


function GSUpdateSequence(name,sequence)
    local button = _G[name]
    -- only translate a sequence if the option to use the translator is on, there is a translator available and the sequence matches the current class
    if GSMasterOptions.useTranslator and GSTranslatorAvailable and checkCurrentClass(sequence.specID) then
      sequence = GSTranslateSequence(sequence)
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
    end
    if name == "LiveTest" then
     local sequenceIndex = GetMacroIndexByName("LiveTest")
     if sequenceIndex > 0 then
      -- Sequence exists do nothing
      GSPrintDebugMessage(L["Moving on - "] .. name .. L[" already exists."], GNOME)
     else
      -- Create Sequence as a player sequence
      sequenceid = CreateMacro("LiveTest", GSMasterOptions.SequenceLibrary["LiveTest"][1].icon, '#showtooltip\n/click ' .. "LiveTest", false)
      ModifiedSequences["LiveTest"] = true
     end
    end
end

local function PrintGnomeHelp()
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r GnomeSequencer was originally written by semlar of wowinterface.com."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r This is a small addon that allows you create a sequence of macros to be executed at the push of a button."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r To get started "] .. GSMasterOptions.CommandColour .. L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."])
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. L["/gs listall|r will produce a list of all available macros with some help information."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r The command "] .. GSMasterOptions.CommandColour .. L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."])
  print(GSMasterOptions.TitleColour .. GNOME .. L[":|r The command "] .. GSMasterOptions.CommandColour .. L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."])
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
    print(GSMasterOptions.TitleColour .. GNOME .. L[":|r Your current Specialisation is "] .. currentSpecID, ':', specname, L["  The Alternative ClassID is "] , currentclassId)
  elseif string.lower(msg) == "help" then
    PrintGnomeHelp()
  elseif string.lower(msg) == "cleanorphans" or string.lower(msg) == "clean" then
    cleanOrphanSequences()
  elseif string.lower(msg) == "forceclean" then
    cleanOrphanSequences()
    CleanMacroLibrary(true)
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    print(GSExportSequence(string.sub(msg,8)))
  elseif string.lower(msg) == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  else
    ListSequences(GetSpecialization())
  end
end

print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["GnomeSequencer-Enhanced loaded.|r  Type "] .. GSMasterOptions.CommandColour .. L["/gs help|r to get started."])

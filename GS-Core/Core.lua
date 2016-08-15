seterrorhandler(_ERRORMESSAGE)

local GNOME, Sequences = ...

local ModifiedSequences = {} -- [sequenceName] = true if we've already modified this sequence
local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")

local function UpdateIcon(self)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = Sequences[button][step], false, ''
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
  return premacro
end

local function preparePostMacro(postmacro)
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    postmacro = "/console Sound_EnableErrorSpeech 1\n" .. postmacro
  end
  if GSMasterOptions.hideUIErrors then
    postmacro = "/script UIErrorsFrame:Hide();\n" .. postmacro
    -- potentially change this to UIErrorsFrame:Hide()
  end
  if GSMasterOptions.clearUIErrors then
    -- potentially change this to UIErrorsFrame:Clear()
    postmacro = "/run UIErrorsFrame:Clear()\n" .. postmacro
  end
  if GSMasterOptions.requireTarget then
    -- see #20 prevent target hopping
    postmacro = "/stopmacro [@playertarget, noexists]\n" .. postmacro
  end
  if GSMasterOptions.use11 then
    postmacro = "/use [combat] 11\n" .. postmacro
  end
  if GSMasterOptions.use12 then
    postmacro = "/use [combat] 12\n" .. postmacro
  end
  if GSMasterOptions.use13 then
    postmacro = "/use [combat] 13\n" .. postmacro
  end
  if GSMasterOptions.use14 then
    postmacro = "/use [combat] 14\n" .. postmacro
  end
  if GSMasterOptions.use2 then
    postmacro = "/use [combat] 2\n" .. postmacro
  end
  return postmacro
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
  GSPrintDebugMessage("Entering GSSplitMeIntolines with : \n" .. str, GNOME)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    GSPrintDebugMessage("Line : " .. line, GNOME)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end



local function GSFixSequence(sequence)
  for k,v in pairs(GSStaticCleanStrings) do
    GSPrintDebugMessage("Testing String: " .. v, GNOME)
    if not GSisEmpty(sequence.PreMacro) then sequence.PreMacro = string.gsub(sequence.PreMacro, v, "") end
    if not GSisEmpty(sequence.PostMacro) then sequence.PostMacro = string.gsub(sequence.PostMacro, v, "") end
  end
end

local function createButton(name, sequence)
  GSFixSequence(sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(sequence)) .. ']=======])')
  button:SetAttribute('step', 1)
  button:SetAttribute('PreMacro','\n' .. preparePreMacro(sequence.PreMacro or ''))
  GSPrintDebugMessage("createButton PreMacro: " .. button:GetAttribute('PreMacro'))
  button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
  GSPrintDebugMessage("createButton PostMacro: " .. button:GetAttribute('PostMacro'))
  button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
  button.UpdateIcon = UpdateIcon
end

function GSReloadSequences()
  GSPrintDebugMessage("Reloading Sequences")
  for name, sequence in pairs(Sequences) do
    GSUpdateSequence(name, sequence)
  end
end


local function cleanOrphanSequences()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
  for macid = 1, maxmacros do
    local found = false
    local mname, mtexture, mbody = GetMacroInfo(macid)
    if not GSisEmpty(mname) then
      for name, sequence in pairs(Sequences) do
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
          print(GSMasterOptions.TitleColour .. GNOME .. ':|r Deleted Orphaned Macro ' .. mname)
          DeleteMacro(macid)
        end
      end
    end
  end
end

local IgnoreMacroUpdates = false
local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(self, event)
  if (event == 'UPDATE_MACROS' or event == 'PLAYER_LOGIN') and not IgnoreMacroUpdates then
    if not InCombatLockdown() then
      IgnoreMacroUpdates = true
      for name, sequence in pairs(Sequences) do
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
    if GSMasterOptions.cleanTempMacro then
      DeleteMacro("LiveTest")
    end
    if GSMasterOptions.deleteOrphansOnLogout then
      cleanOrphanSequences()
    end
  elseif event == 'ADDON_LOADED' then
    if not GSisEmpty(GnomeOptions) then
      -- save temporary values the AddinPacks gets wiped from persisited memory
      local addins = GSMasterOptions.AddInPacks
      GSMasterOptions = GnomeOptions
      GSMasterOptions.AddInPacks = addins
      -- All these options were added in 1.2
      if GSisEmpty(GSMasterOptions.KEYWORD) then
        GSMasterOptions.TitleColour = "|cFFFF0000"
        GSMasterOptions.AuthorColour = "|cFF00D1FF"
        GSMasterOptions.CommandColour = "|cFF00FF00"
        GSMasterOptions.NormalColour = "|cFFFFFFFF"
        GSMasterOptions.EmphasisColour = "|cFFFFFF00"
        GSMasterOptions.overflowPersonalMacros = false
        GSMasterOptions.KEYWORD = "|cff88bbdd"
        GSMasterOptions.UNKNOWN = "|cffff6666"
        GSMasterOptions.CONCAT = "|cffcc7777"
        GSMasterOptions.NUMBER = "|cffffaa00"
        GSMasterOptions.STRING = "|cff888888"
        GSMasterOptions.COMMENT = "|cff55cc55"
        GSMasterOptions.INDENT = "|cffccaa88"
        GSMasterOptions.EQUALS = "|cffccddee"
        GSMasterOptions.STANDARDFUNCS = "|cff55ddcc"
        GSMasterOptions.WOWSHORTCUTS = "|cffddaaff"
      end
    end
    if IsAddOnLoaded(GNOME) then
      GSPrintDebugMessage("I am loaded")
      for name, sequence in pairs(Sequences) do
        GSUpdateSequence(name,sequence)
      end
    end
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
  if GSisEmpty(Sequences[sequenceName]) then
    return GSMasterOptions.TitleColour .. GNOME .. ':|r Sequence named ' .. sequenceName .. ' is unknown.'
  else
    return GSExportSequencebySeq(Sequences[sequenceName], sequenceName)
  end
end

function GSExportSequencebySeq(sequence, sequenceName)
  GSPrintDebugMessage("GSExportSequencebySeq Sequence Name: " .. sequenceName)
  --local helptext = "helpTxt = '" .. sequence.helpTxt .. "',\n"
  local helptext = "helpTxt = \"" .. GSMasterOptions.INDENT .. (GSisEmpty(sequence.helpTxt) and "No Help Information" or sequence.helpTxt) .. GSStaticStringRESET .. "\",\n"
  local steps = ""
  if not GSisEmpty(sequence.StepFunction) then
    if  sequence.StepFunction == GSStaticPriority then
     steps = "StepFunction = " .. GSMasterOptions.EQUALS .. "GSStaticPriority" .. GSStaticStringRESET .. ",\n"
    else
     steps = "StepFunction = [[" .. GSMasterOptions.EQUALS .. sequence.StepFunction .. GSStaticStringRESET .. "]],\n"
    end
  end
  --local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. sequence.author .."\",\n" .."specID="..sequence.specID ..",\n" .. helptext .. steps )
  local returnVal = ("Sequences['" .. GSMasterOptions.EmphasisColour .. sequenceName .. GSStaticStringRESET .. "'] = {\nauthor=\"" .. GSMasterOptions.AuthorColour .. (GSisEmpty(sequence.author) and "Unknown Author" or sequence.author) .. GSStaticStringRESET .. "\",\n" .. (GSisEmpty(sequence.specID) and "-- Unknown specID.  This could be a GS sequence and not a GS-E one.  Care will need to be taken. \n" or "specID=" .. GSMasterOptions.NUMBER  .. sequence.specID .. GSStaticStringRESET ..",\n") .. helptext .. steps )
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

local function GSsetMacroLocation()
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
    GSPrintDebugMessage("Moving on - " .. sequenceName .. " already exists.", GNOME)
  else
    -- Create Sequence as a player sequence
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and not GSMasterOptions.overflowPersonalMacros then
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. 'Close to Maximum Personal Macros.|r  You can have a maximum of '.. MAX_CHARACTER_MACROS .. ' macros per character.  You currently have ' .. GSMasterOptions.EmphasisColour .. numCharacterMacros .."|r.  As a result this macro was not created.  Please delete some macros and reenter " .. GSMasterOptions.CommandColour .. '/gs|r again.')
    elseif numAccountMacros >= MAX_ACCOUNT_MACROS - 1 and GSMasterOptions.overflowPersonalMacros then
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. 'Close to Maximum Macros.|r  You can have a maximum of '.. MAX_CHARACTER_MACROS .. ' macros per character.  You currently have ' .. GSMasterOptions.EmphasisColour .. numCharacterMacros .."|r.  You can also have a  maximum of ".. MAX_ACCOUNT_MACROS .. ' macros per Account.  You currently have ' .. GSMasterOptions.EmphasisColour .. numAccountMacros .."|r. As a result this macro was not created.  Please delete some macros and reenter " .. GSMasterOptions.CommandColour .. '/gs|r again.')
    else
      sequenceid = CreateMacro(sequenceName, (GSMasterOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon), '#showtooltip\n/click ' .. sequenceName, GSsetMacroLocation() )
      ModifiedSequences[sequenceName] = true
    end
  end
end


local function ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(Sequences) do
    if not GSisEmpty(sequence.specID) then
      local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence.specID)
      GSPrintDebugMessage("Sequence Name: " .. name)
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSPrintDebugMessage("No Specialisation information for sequence " .. name .. ". Overriding with information for current spec " .. specname)
      if sequence.specID == currentSpecID or string.upper(txt) == specclass then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. sequence.helpTxt .. ' ' .. GSMasterOptions.EmphasisColour .. specclass .. '|r ' .. specname .. ' ' .. GSMasterOptions.AuthorColour .. 'Contributed by: ' .. sequence.author ..'|r ' )
        GSregisterSequence(name, (GSisEmpty(sequence.icon) and strsub(specicon, 17) or sequence.icon))
      elseif txt == "all" or sequence.specID == 0  then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. sequence.helpTxt or 'No Help Information ' .. GSMasterOptions.AuthorColour .. 'Contributed by: ' .. sequence.author ..'|r ' )
      elseif sequence.specID == currentclassId then
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r ' .. sequence.helpTxt .. ' ' .. GSMasterOptions.AuthorColour .. 'Contributed by: ' .. sequence.author ..'|r ' )
        GSregisterSequence(name, (GSisEmpty(sequence.icon) and strsub(specicon, 17) or sequence.icon))
      end
    else
      print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. name ..'|r Incomplete Sequence Definition - This sequence has no further information ' .. GSMasterOptions.AuthorColour .. 'Unknown Author|r ' )
    end
  end
  ShowMacroFrame()
end

local function checkCurrentClass(specID)
  local _, specname, specdescription, specicon, _, specrole, specclass = GetSpecializationInfoByID(specID)
  if specID > 15 then
    GSPrintDebugMessage("Checking if specID " .. specID .. " " .. specclass .. " equals " .. currentenglishclass)
  else
    GSPrintDebugMessage("Checking if specID " .. specID .. " equals currentclassid " .. currentclassId)
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
        button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(sequence)) .. ']=======])')
        button:SetAttribute("step",1)
        button:SetAttribute('PreMacro',preparePreMacro(sequence.PreMacro or '') .. '\n')
        GSPrintDebugMessage("GSUpdateSequence PreMacro updated to: " .. button:GetAttribute('PreMacro'))
        button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
        GSPrintDebugMessage("GSUpdateSequence PostMacro updated to: " .. button:GetAttribute('PostMacro'))
    end
    if name == "LiveTest" then
     local sequenceIndex = GetMacroIndexByName("LiveTest")
     if sequenceIndex > 0 then
      -- Sequence exists do nothing
      GSPrintDebugMessage("Moving on - " .. name .. " already exists.", GNOME)
     else
      -- Create Sequence as a player sequence
      sequenceid = CreateMacro("LiveTest", GSMasterSequences["LiveTest"].icon, '#showtooltip\n/click ' .. "LiveTest", false)
      ModifiedSequences["LiveTest"] = true
     end
    end
end

local function PrintGnomeHelp()
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r GnomeSequencer was originally written by semlar of wowinterface.com.')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r This is a small addon that allows you create a sequence of macros to be executed at the push of a button.')
  print(GSMasterOptions.TitleColour .. GNOME .. ":|r Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something.")
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r This version has been modified by Draik of Nagrand to serve as a collection of macros that will be updated over time. ')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r To get started ' .. GSMasterOptions.CommandColour .. '/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface.')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.CommandColour .. '/gs listall|r will produce a list of all available macros with some help information.')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar.')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r The command ' .. GSMasterOptions.CommandColour .. '/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros.')
  print(GSMasterOptions.TitleColour .. GNOME .. ':|r The command ' .. GSMasterOptions.CommandColour .. '/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them.')
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
    print(GSMasterOptions.TitleColour .. GNOME .. ':|r Your current Specialisation is ', currentSpecID, ':', specname, "  The Alternative ClassID is " , currentclassId)
  elseif string.lower(msg) == "help" then
    PrintGnomeHelp()
  elseif string.lower(msg) == "cleanorphans" then
    cleanOrphanSequences()
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    print(GSExportSequence(string.sub(msg,8)))
  elseif string.lower(msg) == "showdebugoutput" then
    StaticPopup_Show ("GS-DebugOutput")
  else
    ListSequences(GetSpecialization())
  end
end

if GetLocale() ~= "enUS" then
  -- We need to load in temporarily the current locale translation tables.
  -- we should also look at cacheing this
  local i = 0
  for k,v in pairs(GSAvailableLanguages[GSTRStaticKey]["enUS"]) do
    --print(k .. " " ..v)
    local spellname = GetSpellInfo(k)
		if spellname then
      GSAvailableLanguages[GSTRStaticKey][GetLocale()][k] = spellname
      GSAvailableLanguages[GSTRStaticHash][GetLocale()][spellname] = k
      GSAvailableLanguages[GSTRStaticShadow][GetLocale()][spellname] = string.lower(k)
		end
    i = i + 1
  end
end

print(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. 'GnomeSequencer-Enhanced loaded.|r  Type ' .. GSMasterOptions.CommandColour .. '/gs help|r to get started.')

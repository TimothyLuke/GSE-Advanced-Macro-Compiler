seterrorhandler(_ERRORMESSAGE)

local GNOME, Sequences = ...

local ModifiedSequences = {} -- [sequenceName] = true if we've already modified this sequence
local _, _, currentclassId = UnitClass("player")


local function isempty(s)
  return s == nil or s == ''
end

local CastCmds = { use = true, cast = true, spell = true }

local function UpdateIcon(self)
  local step = self:GetAttribute('step') or 1
  local button = self:GetName()
  local sequence, foundSpell, notSpell = Sequences[button][step], false, ''
  for cmd, etc in gmatch(sequence or '', '/(%w+)%s+([^\n]+)') do
    if CastCmds[strlower(cmd)] then
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
    premacro = premacro .. "\n/console Sound_EnableSFX 0"
  end
  return premacro
end

local function preparePostMacro(postmacro)
  if GSMasterOptions.hideSoundErrors then
    -- potentially change this to SetCVar("Sound_EnableSFX", 1)
    postmacro = postmacro .. "\n/console Sound_EnableSFX 1"
  end
  if GSMasterOptions.hideUIErrors then
    postmacro = postmacro .. "\n/script UIErrorsFrame:Hide();"
    -- potentially change this to UIErrorsFrame:Hide()
  end
  if GSMasterOptions.clearUIErrors then
    -- potentially change this to UIErrorsFrame:Clear()
    postmacro = postmacro .. "\n/run UIErrorsFrame:Clear()"
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


local function createButton(name, sequence)
  local button = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
  button:SetAttribute('type', 'macro')
  button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(sequence)) .. ']=======])')
  button:SetAttribute('step', 1)
  button:SetAttribute('PreMacro', preparePreMacro(sequence.PreMacro or '') .. '\n')
  button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
  button:WrapScript(button, 'OnClick', format(OnClick, sequence.StepFunction or 'step = step % #macros + 1'))
  button.UpdateIcon = UpdateIcon
end

function GSReloadSequences()
  GSPrintDebugMessage("Reloading Sequences")
  for name, sequence in pairs(Sequences) do
    createButton(name, sequence)
  end
end


local function cleanOrphanSequences()
  local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
  for macid = 1, maxmacros do
    local found = false
    local mname, mtexture, mbody = GetMacroInfo(macid)
    if not isempty(mname) then
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
          print('|cffff0000' .. GNOME .. ':|r Deleted Orphaned Macro ' .. mname)
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
    if not isempty(GnomeOptions) then
      -- save temporary values the AddinPacks gets wiped from persisited memory
      local addins = GSMasterOptions.AddInPacks
      GSMasterOptions = GnomeOptions
      GSMasterOptions.AddInPacks = addins
    end
    for name, sequence in pairs(Sequences) do
      createButton(name, sequence)
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
  if isempty(Sequences[sequenceName]) then
    return '|cffff0000' .. GNOME .. ':|r Sequence named ' .. sequenceName .. ' is unknown.'
  else
    local helptext = "helpTxt = '" .. Sequences[sequenceName].helpTxt .. "',\n"
    local steps = ""
    if not isempty(Sequences[sequenceName].StepFunction) then
      if  Sequences[sequenceName].StepFunction == GSStaticPriority then
       steps = "StepFunction = GSStaticPriority,\n"
      else
       steps = Sequences[sequenceName].StepFunction .. "',\n"
      end
    end
    local returnVal = ("Sequences['" .. sequenceName .. "'] = {\n" .."author=\"".. Sequences[sequenceName].author .."\",\n" .."specID="..Sequences[sequenceName].specID ..",\n" .. helptext .. steps .. "PreMacro=[[\n" .. Sequences[sequenceName].PreMacro .. "]],")
    if not isempty(Sequences[sequenceName].icon) then
       returnVal = returnVal .. "\nicon='"..Sequences[sequenceName].icon .."',"
    end
    returnVal = returnVal .. "\n\"" .. table.concat(Sequences[sequenceName],"\",\n\"") .. "\",\n"
    returnVal = returnVal .. "PostMacro=[[\n" .. Sequences[sequenceName].PostMacro .. "]],\n}"
    return returnVal
  end
end


local function GSregisterSequence(sequenceName, icon)
  local sequenceIndex = GetMacroIndexByName(sequenceName)
  if sequenceIndex > 0 then
    -- Sequence exists do nothing
  else
    -- Create Sequence as a player sequence
    sequenceid = CreateMacro(sequenceName, icon, '#showtooltip\n/click ' .. sequenceName, 1)
    ModifiedSequences[sequenceName] = true
  end
end


local function ListSequences(txt)
  local currentSpec = GetSpecialization()

  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
  for name, sequence in pairs(Sequences) do
    local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(sequence.specID)
    GSPrintDebugMessage("Sequence Name: " .. name)
    if isempty(sid) then
      sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(currentSpecID)
      GSPrintDebugMessage("No Specialisation information for sequence " .. name .. ". Overriding with information for current spec " .. specname)
    else
      GSPrintDebugMessage("specname: " .. specname .. " specdescription: " ..  specdescription .. " specicon: " .. specicon .. " specrole: " .. specrole .. " specclass: " .. specclass)
    end
    if isempty(sequence.specID) or isempty(sequence.author) then
      print('|cffff0000' .. GNOME .. ':|r |cFF00FF00' .. name ..'|r Incomplete Sequence Definition - This sequence has no further information ' .. ' |cFFFFFF00' .. ' |cFF0000FF Unknown Author|r ' )
    else
      if sequence.specID == currentSpecID or string.upper(txt) == specclass then
        print('|cffff0000' .. GNOME .. ':|r |cFF00FF00' .. name ..'|r ' .. sequence.helpTxt .. ' |cFFFFFF00' .. specclass .. ' ' .. specname .. ' |cFF0000FFContributed by: ' .. sequence.author ..'|r ' )
        GSregisterSequence(name, (isempty(sequence.icon) and strsub(specicon, 17) or sequence.icon))
      elseif txt == "all" or sequence.specID == 0  then
        print('|cffff0000' .. GNOME .. ':|r |cFF00FF00' .. name ..'|r ' .. sequence.helpTxt or 'No Help Information' .. ' |cFFFFFF00' .. ' |cFF0000FFContributed by: ' .. sequence.author ..'|r ' )
      elseif sequence.specID == currentclassId then
        print('|cffff0000' .. GNOME .. ':|r |cFF00FF00' .. name ..'|r ' .. sequence.helpTxt .. ' |cFFFFFF00' .. ' |cFF0000FFContributed by: ' .. sequence.author ..'|r ' )
        GSregisterSequence(name, (isempty(sequence.icon) and strsub(specicon, 17) or sequence.icon))
      end
    end
  end
  ShowMacroFrame()
end

function GSUpdateSequence(name,sequence)
    local button = _G[name]
    if button==nil then
        createButton(name, sequence)
    else
        button:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(sequence)) .. ']=======])')
        button:SetAttribute("step",1)
        button:SetAttribute('PreMacro', preparePreMacro(sequence.PreMacro or '') .. '\n')
        button:SetAttribute('PostMacro', '\n' .. preparePostMacro(sequence.PostMacro or ''))
    end
    if name == "LiveTest" then
     local sequenceIndex = GetMacroIndexByName("LiveTest")
     if sequenceIndex > 0 then
      -- Sequence exists do nothing
     else
      -- Create Sequence as a player sequence
      sequenceid = CreateMacro("LiveTest", GSMasterSequences["LiveTest"].icon, '#showtooltip\n/click ' .. "LiveTest", false)
      ModifiedSequences["LiveTest"] = true
     end
    end
end

local function PrintGnomeHelp()
  print('|cffff0000' .. GNOME .. ':|r GnomeSequencer was originally written by semlar of wowinterface.com.')
  print('|cffff0000' .. GNOME .. ':|r This is a small addon that allows you create a sequence of macros to be executed at the push of a button.')
  print('|cffff0000' .. GNOME .. ":|r Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something.")
  print('|cffff0000' .. GNOME .. ':|r This version has been modified by Draik of Nagrand to serve as a collection of macros that will be updated over time. ')
  print('|cffff0000' .. GNOME .. ':|r To get started |cFF00FF00/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface.')
  print('|cffff0000' .. GNOME .. ':|r |cFF00FF00/gs listall|r will produce a list of all available macros with some help information.')
  print('|cffff0000' .. GNOME .. ':|r To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar.')
  print('|cffff0000' .. GNOME .. ':|r The command |cFF00FF00/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros.')
  print('|cffff0000' .. GNOME .. ':|r The command |cFF00FF00/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them.')
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
    print('|cffff0000' .. GNOME .. ':|r Your current Specialisation is ', currentSpecID, ':', specname, "  The Alternative ClassID is " , currentclassId)
  elseif string.lower(msg) == "help" then
    PrintGnomeHelp()
  elseif string.lower(msg) == "cleanorphans" then
    cleanOrphanSequences()
  elseif string.lower(string.sub(msg,1,6)) == "export" then
    print(GSExportSequence(string.sub(msg,8)))
  else
    ListSequences(GetSpecialization())
  end
end

print('|cffff0000' .. GNOME .. ':|r GnomeSequencer-Enhanced loaded.  type |cFF00FF00/gs help|r to get started.')

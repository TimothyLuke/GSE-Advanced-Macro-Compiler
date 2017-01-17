local GSE = GSE
local Statics = GSE.Static

local GNOME = Statics.DebugModules["Translator"]
local locale = GetLocale();
local L = GSE.L

if GetLocale() ~= "enUS" then
  -- We need to load in temporarily the current locale translation tables.
  -- we should also look at cacheing this
  if GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][GetLocale()]) then
    GSE.TranslatorLanguageTables[Statics.TranslationKey][GetLocale()] = {}
    GSE.TranslatorLanguageTables[Statics.TranslationHash][GetLocale()] = {}
    GSE.TranslatorLanguageTables[Statics.TranslationShadow][GetLocale()] = {}
    GSE.PrintDebugMessage("Adding missing Language :" .. GetLocale(), GNOME )
    local i = 0
    for k,v in pairs(GSE.TranslatorLanguageTables[Statics.TranslationKey]["enUS"]) do
      GSE.PrintDebugMessage(i.. " " .. k .. " " ..v)
      local spellname = GetSpellInfo(k)
      if spellname then
        GSE.TranslatorLanguageTables[Statics.TranslationKey][GetLocale()][k] = spellname
        GSE.TranslatorLanguageTables[Statics.TranslationHash][GetLocale()][spellname] = k
        GSE.TranslatorLanguageTables[Statics.TranslationShadow][GetLocale()][spellname] = string.lower(k)
      end
      i = i + 1
    end
    GSE.AdditionalLanguagesAvailable = true
  end
end

function GSE.ListCachedLanguages()
  t = {}
  i = 1
  for name, _ in pairs(GSE.TranslatorLanguageTables[Statics.TranslationKey]) do
    t[i] = name
    GSE.PrintDebugMessage("found " .. name, GNOME)
    i = i + 1
  end
  return t
end

function GSE.TranslateSequence(sequence, sequenceName)
  if not GSE.isEmpty(sequence) then
    return GSE.TranslateSequenceFromTo(sequence, "enUS", GetLocale(), sequenceName)
  else
    return sequence
  end
end

function GSE.TranslateSequenceFromTo(sequence, fromLocale, toLocale, sequenceName)
  GSE.PrintDebugMessage("GSE.TranslateSequenceFromTo  From: " .. fromLocale .. " To: " .. toLocale, GNOME)
  -- check if fromLocale exists
  if GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][fromLocale]) then
    GSE.Print(L["Source Language "] .. fromLocale .. L[" is not available.  Unable to translate sequence "] ..  sequenceName)
    return sequence
  end
  if GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][fromLocale]) then
    GSE.Print(L["Target Language "] .. fromLocale .. L[" is not available.  Unable to translate sequence "] ..  sequenceName)
    return sequence
  end


  for k,v in ipairs(sequence) do
    -- Translate sequence
    sequence[k] = GSE.TranslateString(v, fromLocale, toLocale)
  end


  if not GSE.isEmpty(sequence.KeyRelease) then
    for k,v in pairs(sequence.KeyRelease) do
      sequence.KeyRelease[k] = GSE.TranslateString(v, fromLocale, toLocale)
    end
  else
    GSE.PrintDebugMessage("empty Keyrelease in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.KeyPress) then
    GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.KeyPress) do
      -- Translate KeyRelease
      sequence.KeyPress[k] = GSE.TranslateString(v, fromLocale, toLocale)
    end
  else
    GSE.PrintDebugMessage("empty Keypress in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.PreMacro) then
      GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.PreMacro) do
      -- Translate KeyRelease
      sequence.PreMacro[k] = GSE.TranslateString(v, fromLocale, toLocale)
    end
  else
    GSE.PrintDebugMessage("empty Keypress in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.PostMacro) do
      -- Translate KeyRelease
      sequence.PostMacro[k] = GSE.TranslateString(v, fromLocale, toLocale)
    end
  else
    GSE.PrintDebugMessage("empty Keypress in translate", Statics.Translate)
  end

  -- check for blanks
  for i, v in ipairs(sequence) do
    if v == "" then
      sequence[i] = nil
    end
  end
  return sequence
end

function GSE.TranslateString(instring, fromLocale, toLocale, cleanNewLines)
  instring = GSE.UnEscapeString(instring)
  GSE.PrintDebugMessage("Entering GSE.TranslateString with : \n" .. instring .. "\n " .. fromLocale .. " " .. toLocale, GNOME)
  local output = ""
  if not GSE.isEmpty(instring) then
    for cmd, etc in string.gmatch(instring or '', '/(%w+)%s+([^\n]+)') do
      GSE.PrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
      output = output..GSEOptions.WOWSHORTCUTS .. "/" .. cmd .. Statics.StringReset .. " "
      if Statics.CastCmds[string.lower(cmd)] then
        if not cleanNewLines then
          etc = string.match(etc, "^%s*(.-)%s*$")
        end
        if string.sub(etc, 1, 1) == "!" then
          etc = string.sub(etc, 2)
          output = output .. "!"
        end
        local foundspell, returnval = GSE.TranslateSpell(etc, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
        if foundspell then
          output = output ..GSEOptions.KEYWORD .. returnval .. Statics.StringReset
        else
          GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
          output = output  .. etc
        end
      -- check for cast Sequences
      elseif string.lower(cmd) == "castsequence" then
        GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
        for _, w in ipairs(GSE.split(etc,",")) do
          --look for conditionals at the startattack
          local conditionals, mods, uetc = GSE.GetConditionalsFromString(w)
          if conditionals then
            output = output ..GSEOptions.STANDARDFUNCS .. mods .. Statics.StringReset .. " "
          end

          if not cleanNewLines then
            w = string.match(uetc, "^%s*(.-)%s*$")
          end
          if string.sub(uetc, 1, 1) == "!" then
            uetc = string.sub(uetc, 2)
            output = output .. "!"
          end
          local foundspell, returnval = GSE.TranslateSpell(uetc, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
          output = output ..  GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. ", "
        end
        local resetleft = string.find(output, ", , ")
        if not GSE.isEmpty(resetleft) then
          output = string.sub(output, 1, resetleft -1)
        end
        if string.sub(output, string.len(output)-1) == ", " then
          output = string.sub(output, 1, string.len(output)-2)
        end
      else
        -- pass it through
        output = output .. " " .. etc
      end
    end
    -- If nothing was found pass throught
    if output == "" then
      output = instring
    end
  elseif cleanNewLines then
    output = output .. instring
  end
  GSE.PrintDebugMessage("Exiting GSE.TranslateString with : \n" .. output, GNOME)
  -- check for random , at the end
  if string.sub(output, string.len(output)-1) == ", " then
    output = string.sub(output, 1, string.len(output)-2)
  end
  output = string.gsub(output, "\\s+", " ")
  return output
end

function GSE.TranslateSpell(str, fromLocale, toLocale, cleanNewLines)
  local output = ""
  local found = false
  -- check for cases like /cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar
  if not cleanNewLines then
    str = string.match(str, "^%s*(.-)%s*$")
  end
  GSE.PrintDebugMessage("GSE.TranslateSpell Attempting to translate " .. str, GNOME)
  if string.sub(str, string.len(str)) == "," then
    str = string.sub(str, 1, string.len(str)-1)
  end
  if string.match(str, ";") then
    GSE.PrintDebugMessage("GSE.TranslateSpell found ; in " .. str .. " about to do recursive call.", GNOME)
    for _, w in ipairs(GSE.split(str,";")) do
      found, returnval = GSE.TranslateSpell((cleanNewLines and w or string.match(w, "^%s*(.-)%s*$")), fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
      output = output ..  GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. "; "
    end
    if string.sub(output, string.len(output)-1) == "; " then
      output = string.sub(output, 1, string.len(output)-2)
    end
  else
    local conditionals, mods, etc = GSE.GetConditionalsFromString(str)
    if conditionals then
      output = output .. mods .. " "
      GSE.PrintDebugMessage("GSE.TranslateSpell conditionals found ", GNOME)
    end
    GSE.PrintDebugMessage("output: " .. output .. " mods: " .. mods .. " etc: " .. etc, GNOME)
    if not cleanNewLines then
      etc = string.match(etc, "^%s*(.-)%s*$")
    end
    etc = string.gsub (etc, "!", "")
    local foundspell = GSE.TranslatorLanguageTables[Statics.TranslationHash][fromLocale][etc]
    if GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell]) then
      foundspell = false
    end
    if foundspell then
      GSE.PrintDebugMessage("Translating Spell ID : " .. foundspell , GNOME )
      GSE.PrintDebugMessage(" to " .. (GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell]) and " but its not in [Statics.TranslationKey][" .. toLocale .. "]" or GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell]) , GNOME)
      output = output .. GSEOptions.KEYWORD .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell] .. Statics.StringReset
      found = true
    else
      GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale .. " Hash table checking shadow table", GNOME)
      -- try the shadow table
      local nfoundspell = GSE.TranslatorLanguageTables[Statics.TranslationShadow][fromLocale][string.lower(etc)]
      if GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationShadow][toLocale][foundspell]) then
        nfoundspell = false
      end
      if nfoundspell then
        GSE.PrintDebugMessage("Translating from the shadow table for  Spell ID : " .. nfoundspell .. " to " .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][nfoundspell], GNOME)
        output = output  .. GSEOptions.KEYWORD .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][nfoundspell] .. Statics.StringReset
        found = true
      else
        GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
        output = output  .. GSEOptions.UNKNOWN .. etc .. Statics.StringReset
        if GSE.isEmpty(GSEOptions.UnfoundSpells) then
          GSEOptions.UnfoundSpells = {}
        end
        GSEOptions.UnfoundSpells [etc] = true
      end
    end
  end
  return found, output
end

function GSE.GetConditionalsFromString(str)
  GSE.PrintDebugMessage("Entering GSE.GetConditionalsFromString with : " .. str, GNOME)
  --check for conditionals
  local found = false
  local mods = ""
  local leftstr
  local rightstr
  local leftfound = false
  for i = 1, #str do
    local c = str:sub(i,i)
    if c == "[" and not leftfound then
      leftfound = true
      leftstr = i
    end
    if c == "]" then
      rightstr = i
    end
  end
  GSE.PrintDebugMessage("checking left : " .. (leftstr and leftstr or "nope"), GNOME)
  GSE.PrintDebugMessage("checking right : " .. (rightstr and rightstr or "nope"), GNOME)
  if rightstr and leftstr then
     found = true
     GSE.PrintDebugMessage("We have left and right stuff", GNOME)
     mods = string.sub(str, leftstr, rightstr)
     GSE.PrintDebugMessage("mods changed to: " .. mods, GNOME)
     str = string.sub(str, rightstr + 1)
     GSE.PrintDebugMessage("str changed to: " .. str, GNOME)
  end
  if not cleanNewLines then
    str = string.match(str, "^%s*(.-)%s*$")
  end
  -- Check for resets
  GSE.PrintDebugMessage("checking for reset= in " .. str, GNOME)
  local resetleft = string.find(str, "reset=")
  if not GSE.isEmpty(resetleft) then
    GSE.PrintDebugMessage("found reset= at" .. resetleft, GNOME)
  end

  local rightfound = false
  local resetright = 0
  if resetleft then
    for i = 1, #str do
      local c = str:sub(i,i)
      if c == " " then
        if not rightfound then
          resetright = i
          rightfound = true
        end
      end
    end
    mods = mods .. " " .. string.sub(str, resetleft, resetright)
    GSE.PrintDebugMessage("reset= mods changed to: " .. mods, GNOME)
    str = string.sub(str, resetright + 1)
    GSE.PrintDebugMessage("reset= test str changed to: " .. str, GNOME)
    found = true
  end

  mods = GSEOptions.COMMENT .. mods .. Statics.StringReset
  return found, mods, str
end


--- This option reports on language table errors and ommissions.  It is accessible
-- via the command line /gs compilemissingspells and saves this informationm into
-- GSE.lua under GSEOptions.UnfoundSpellIDs, GSEOptions.UnfoundSpells and GSEOptions.ErroneousSpellID
-- This information is used by the GSEUtils that generates the enUS.lua, enUSHash.lua and enUSSHADOW.lua files.
function GSE.ReportUnfoundSpells()
  GSEOptions.UnfoundSpells = {}
  for classid, macroset in ipairs(GSELibrary) do
    for name, version in pairs(macroset) do
      for v, sequence in ipairs(version) do
        GSE.TranslateSequenceFromTo(sequence, "enUS", "enUS", name)
      end
    end
  end
  GSEOptions.UnfoundSpellIDs = {}

  for _,spell in pairs(GSEOptions.UnfoundSpells) do
    GSEOptions.UnfoundSpellIDs[spell] = GetSpellInfo(spell)
  end

  GSEOptions.ErroneousSpellID = {}
  for k,v in pairs(GSE.TranslatorLanguageTables[Statics.TranslationHash]["enUS"]) do
    local name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(v)
    if GSE.isEmpty(spellID) then
      GSEOptions.ErroneousSpellID[v] = true
    end

  end
end

GSE.TranslatorAvailable = true

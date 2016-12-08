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
    GSE.PrintDebugMessage(L["Adding missing Language :"] .. GetLocale(), GNOME )
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
    if (GSE.isEmpty(sequence.Lang) and "enUS" or sequence.Lang) ~= locale then
      --GSE.PrintDebugMessage((GSE.isEmpty(sequence.Lang) and "enUS" or sequence.Lang) .. " ~=" .. locale, GNOME)
      return GSE.TranslateSequenceFromTo(sequence, (GSE.isEmpty(sequence.Lang) and "enUS" or sequence.Lang), locale, sequenceName)
    else
      GSE.PrintDebugMessage((GSE.isEmpty(sequence.Lang) and "enUS" or sequence.Lang) .. " ==" .. locale, GNOME)
      return sequence
    end
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
  local lines = table.concat(sequence,"\n")
  GSE.PrintDebugMessage("lines: " .. lines, GNOME)

  lines = GSE.TranslateString(lines, fromLocale, toLocale)
  --TODO add PreMacro and PostMacro
  if not GSE.isEmpty(sequence.KeyRelease) then
    print("Keyrelease has stuff in translate")
    for k,v in pairs(sequence.KeyRelease) do
      -- Translate KeyRelease

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

  for i, v in ipairs(sequence) do sequence[i] = nil end
  GSE.lines(sequence, lines)
  -- check for blanks
  for i, v in ipairs(sequence) do
    if v == "" then
      sequence[i] = nil
    end
  end
  sequence.Lang = toLocale
  return sequence
end

function GSE.TranslateString(instring, fromLocale, toLocale, cleanNewLines)
  instring = GSE.UnEscapeString(instring)
  GSE.PrintDebugMessage("Entering GSE.anslateString with : \n" .. instring .. "\n " .. fromLocale .. " " .. toLocale, GNOME)

  local output = ""
  local stringlines = GSE.SplitMeIntolines(instring)
  for _,v in ipairs(stringlines) do
    --print ("v = ".. v)
    if not GSE.isEmpty(v) then
      for cmd, etc in gmatch(v or '', '/(%w+)%s+([^\n]+)') do
        GSE.PrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
        output = output..GSEOptions.WOWSHORTCUTS .. "/" .. cmd .. Statics.StringReset .. " "
        if Statics.CastCmds[strlower(cmd)] then
          if not cleanNewLines then
            etc = string.match(etc, "^%s*(.-)%s*$")
          end
          if string.sub(etc, 1, 1) == "!" then
            etc = string.sub(etc, 2)
            output = output .. "!"
          end
          local foundspell, returnval = GSE.TranslateSpell(etc, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
          if foundspell then
            output = output ..GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. "\n"
          else
            GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
            output = output  .. etc .. "\n"
          end
        -- check for cast Sequences
        elseif strlower(cmd) == "castsequence" then
          GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
          --look for conditionals at the startattack
          local conditionals, mods, uetc = GSE.GetConditionalsFromString(etc)
          if conditionals then
            output = output ..GSEOptions.STANDARDFUNCS .. mods .. Statics.StringReset .. " "
          end
          for _, w in ipairs(GSE.split(uetc,",")) do
            if not cleanNewLines then
              w = string.match(w, "^%s*(.-)%s*$")
            end
            if string.sub(w, 1, 1) == "!" then
              w = string.sub(w, 2)
              output = output .. "!"
            end
            local foundspell, returnval = GSE.TranslateSpell(w, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
            output = output ..  GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. ", "
          end
          local resetleft = string.find(output, ", , ")
          if not GSE.isEmpty(resetleft) then
            output = string.sub(output, 1, resetleft -1)
          end
          if string.sub(output, strlen(output)-1) == ", " then
            output = string.sub(output, 1, strlen(output)-2)
          end
          output = output .. "\n"
        else
          -- pass it through
          output = output  .. etc .. "\n"
        end
      end
    elseif cleanNewLines then
      output = output .. v
    end
  end
  GSE.PrintDebugMessage("Exiting GSE.anslateString with : \n" .. output, GNOME)
  -- check for random , at the end
  if string.sub(output, strlen(output)-1) == ", " then
    output = string.sub(output, 1, strlen(output)-2)
  end
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
  if string.sub(str, strlen(str)) == "," then
    str = string.sub(str, 1, strlen(str)-1)
  end
  if string.match(str, ";") then
    GSE.PrintDebugMessage("GSE.TranslateSpell found ; in " .. str .. " about to do recursive call.", GNOME)
    for _, w in ipairs(GSE.split(str,";")) do
      found, returnval = GSE.TranslateSpell((cleanNewLines and w or string.match(w, "^%s*(.-)%s*$")), fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
      output = output ..  GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. "; "
    end
    if string.sub(output, strlen(output)-1) == "; " then
      output = string.sub(output, 1, strlen(output)-2)
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
    if foundspell then
      GSE.PrintDebugMessage("Translating Spell ID : " .. foundspell , GNOME )
      GSE.PrintDebugMessage(" to " .. (GSE.isEmpty(GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell]) and " but its not in [Statics.TranslationKey][" .. toLocale .. "]" or GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell]) , GNOME)
      output = output .. GSEOptions.KEYWORD .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][foundspell] .. Statics.StringReset
      found = true
    else
      GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale .. " Hash table checking shadow table", GNOME)
      -- try the shadow table
      local nfoundspell = GSE.TranslatorLanguageTables[Statics.TranslationShadow][fromLocale][string.lower(etc)]
      if nfoundspell then
        GSE.PrintDebugMessage("Translating from the shadow table for  Spell ID : " .. nfoundspell .. " to " .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][nfoundspell], GNOME)
        output = output  .. GSEOptions.KEYWORD .. GSE.TranslatorLanguageTables[Statics.TranslationKey][toLocale][nfoundspell] .. Statics.StringReset
        found = true
      else
        GSE.PrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
        output = output  .. GSEOptions.UNKNOWN .. etc .. Statics.StringReset
        GSE.UnfoundSpells [#GSE.UnfoundSpells + 1] = etc
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



function GSE.ReportUnfoundSpells()
  for name,version in pairs(GSELibrary) do
    for v, sequence in ipairs(version) do
      GSE.TranslateSequenceFromTo(sequence, "enUS", "enUS", name)
    end
  end
  GSE.UnfoundSpellIds = {}

  for _,spell in pairs(GSE.UnfoundSpells) do
    GSE.UnfoundSpellIds[spell] = GetSpellInfo(spell)
  end
end

GSE.TranslatorAvailable = true

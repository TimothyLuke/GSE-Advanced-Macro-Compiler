local GNOME, language = ...
local locale = GetLocale();

function GSTRisempty(s)
  return s == nil or s == ''
end


function GSTranslateSequence(sequence)

  if not GSTRisempty(sequence) then
    if (GSTRisempty(sequence.locale) and "enUS" or sequence.locale) ~= locale then
      --GSPrintDebugMessage((GSTRisempty(sequence.locale) and "enUS" or sequence.locale) .. " ~=" .. locale, GNOME)
      return GSTranslateSequenceFromTo(sequence, (GSTRisempty(sequence.locale) and "enUS" or sequence.locale), locale)
    else
      GSPrintDebugMessage((GSTRisempty(sequence.locale) and "enUS" or sequence.locale) .. " ==" .. locale, GNOME)
      return sequence
    end
  end
end

function GSTranslateSequenceFromTo(sequence, fromLocale, toLocale)
  GSPrintDebugMessage("GSTranslateSequenceFromTo  From: " .. fromLocale .. " To: " .. toLocale, GNOME)
  local lines = table.concat(sequence,"\n")
  GSPrintDebugMessage("lines: " .. lines, GNOME)

  lines = GSTranslateString(lines, fromLocale, toLocale)
  if not GSTRisempty(sequence.PostMacro) then
    -- Translate PostMacro
    sequence.PostMacro = GSTranslateString(sequence.PostMacro, fromLocale, toLocale)
  end
  if not GSTRisempty(sequence.PreMacro) then
    -- Translate PostMacro
    sequence.PreMacro = GSTranslateString(sequence.PreMacro, fromLocale, toLocale)
  end

  -- this approach was too intensive  It started with the list of words and tried a straight regex find replace.
  -- the new approach to use GSTranslateString instead iterates over the words of the macro instead.
  --for sid, term in pairs(language[toLocale]) do
  --  if not GSTRisempty(sid) then
  --    GSPrintDebugMessage("sid: " .. sid, GNOME)
  --    if not GSTRisempty(term) then
  --      GSPrintDebugMessage(toLocale .. ": " .. term, GNOME)
  --      GSPrintDebugMessage(fromLocale .. ": " .. language[fromLocale][sid], GNOME)
  --    end
  --    -- Translate PreMacro
  --    if not GSTRisempty(sequence.PreMacro) then
  --      GSPrintDebugMessage("Original PreMacro: " .. sequence.PreMacro, GNOME)
  --      sequence.PreMacro = string.gsub(sequence.PreMacro, language[toLocale][sid], term)
  --      GSPrintDebugMessage("Translated PreMacro: " .. sequence.PreMacro, GNOME)
  --    end
  --    if not GSTRisempty(sequence.PostMacro) then
  --      -- Translate PostMacro
  --      sequence.PostMacro = string.gsub(sequence.PostMacro, language[toLocale][sid], term)
  --    end
  --    -- Translate Sequence Steps
  --    lines = string.gsub(lines, language[toLocale][sid], term)
  --    --clear untranslated lines
  --  end
  --end
  for i, v in ipairs(sequence) do sequence[i] = nil end
  GSTRlines(sequence, lines)
  sequence.locale = toLocale
  return sequence
end

function GSTranslateString(instring, fromLocale, toLocale)
  GSPrintDebugMessage("Entering GSTranslateString with : \n" .. instring .. "\n " .. fromLocale .. " " .. toLocale, GNOME)
  local output = ""
  local stringlines = GSTRSplitMeIntolines(instring)
  for _,v in ipairs(stringlines) do
    for cmd, etc in gmatch(v or '', '/(%w+)%s+([^\n]+)') do
      -- figure out what to do with conditionals eg [mod:alt] etc
      local conditionals, mods, etc = GSTRGetConditionalsFromString(etc)
      output = output .. "/" .. cmd .. " "
      if conditionals then
        output = output .. mods .. " "
      end
      -- handle cast commands
      if GSStaticCastCmds[strlower(cmd)] then
        if string.sub(etc, 1, 1) == "!" then
          etc = string.sub(etc, 2)
          output = output .. "!"
        end
        local foundspell = GSTRFindSpellIDByName(language[fromLocale], etc)
        if foundspell then
          output = output  .. language[toLocale][foundspell] .. ",\n"
          GSPrintDebugMessage("Translating Spell ID : " .. foundspell .. " to " .. language[toLocale][foundspell], GNOME)
        else
          GSPrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
          output = output  .. etc .. "\n"
        end
      end
      -- check for cast Sequences
      if strlower(cmd) == "castsequence" then
        for _, w in ipars(etc:split(",")) do
          if string.sub(w, 1, 1) == "!" then
            w = string.sub(w, 2)
            output = output .. "!"
          end
          local foundspell = GSTRFindSpellIDByName(language[fromLocale], w)
          if foundspell then
            output = output ..  language[toLocale][foundspell] ..", "
          else
            output = output .. w
          end
        end
        output = output .. "\n"
      end
    end
  end
  GSPrintDebugMessage("Exiting GSTranslateString with : \n" .. output, GNOME)
  return output
end

function GSTRSplitMeIntolines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)r?n", helper)))
  return t
end

function GSTRGetConditionalsFromString(str)
  local found = false
  local mods = ""

  local leftstr = string.find("str", "(\\[)")
  local rightstr = string.find("str", "(\\])")
  if rightstr and leftstr then
     mods = string.sub(str, 1, leftstr)
     str = string.sub(str, rightstr)
  end
  return found, mods, str
end

function GSTranslateGetLocaleSpellNameTable()
  local spelltable = {}
  for k,v in pairs(language["enUS"]) do
      --print(k)
      local spellname = GetSpellInfo(k)
      spelltable[k] = spellname
  end
  -- local checker
  -- for i = 1, 300000 do
  --   checker = (GetSpellInfo(i))
  --   if checker then
  --     spelltable[i] = checker
  --   end
  -- end
  return spelltable
end

function GSTRlines(tab, str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end


if GSTRisempty(language[locale]) then
  -- Load the current locale into the language SetAttribute
  if GSCore then
    GSPrintDebugMessage("Loading Spells for language " .. locale, GNOME)
  end
  language[locale] = GSTranslateGetLocaleSpellNameTable()
end

function GSTRFindSpellIDByName (list, spell)
  local spellid
  for k, l in pairs(list) do
    if l == spell then
      spellid = k
    end
  end
  return spellid
end

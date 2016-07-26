local GNOME, language = ...
local locale = GetLocale();

function GSTRisempty(s)
  return s == nil or s == ''
end


function GSTranslateSequence(sequence)
  if (sequence, GSTRisempty(sequence.locale) and "enUS" or sequence.locale) ~= locale then
    GSPrintDebugMessage(GSTRisempty(sequence.locale) and "enUS" or sequence.locale) .. " ~=" .. locale, GNOME)
    return GSTranslateSequenceFromTo(sequence, GSTRisempty(sequence.locale) and "enUS" or sequence.locale), locale)
  else
    GSPrintDebugMessage(GSTRisempty(sequence.locale) and "enUS" or sequence.locale) .. " ==" .. locale, GNOME)
    return sequence
  end
end

function GSTranslateSequenceFromTo(sequence, fromLocale, toLocale)
  for sid, term in pairs(language[toLocale]) do
    -- Translate PreMacro
    sequence.PreMacro = string.gsub(sequence.PreMacro, language[toLocale][sid], term)
    -- Translate PostMacro
    sequence.PostMacro = string.gsub(sequence.PostMacro, language[toLocale][sid], term)
    -- Translate Sequence Steps
    local lines = table.concat(sequence,"\n")
    lines = string.gsub(lines, language[toLocale][sid], term)
    --clear untranslated lines
    for i, v in ipairs(sequence) do sequence = nil end
    GSTRlines(sequence, lines)
  end
  sequence.locale = toLocale
  return sequence
end

function GSTranslateGetLocaleSpellNameTable()
  local spelltable = {}
  local checker
  for i = 1, 300000 do
    checker = (GetSpellInfo(i))
    if checker then
      spelltable[i] = checker
    end
  end
  return spelltable
end

function GSTRlines(tab, str)
  local function helper(line)
    table.insert(tab, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  GST = t
end


if GSTRisempty() then
  -- Load the current locale into the language SetAttribute
  GSPrintDebugMessage("Loading Spells for language " .. locale, GNOME)
  language[locale] = GSTranslateGetLocaleSpellNameTable()
end

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
  for sid, term in pairs(language[toLocale]) do
    if not GSTRisempty(sid) then
      GSPrintDebugMessage("sid: " .. sid, GNOME)
      if not GSTRisempty(term) then
        GSPrintDebugMessage(toLocale .. ": " .. term, GNOME)
        GSPrintDebugMessage(fromLocale .. ": " .. language[fromLocale][sid], GNOME)
      end
      -- Translate PreMacro
      if not GSTRisempty(sequence.PreMacro) then
        GSPrintDebugMessage("Original PreMacro: " .. sequence.PreMacro, GNOME)
        sequence.PreMacro = string.gsub(sequence.PreMacro, language[toLocale][sid], term)
        GSPrintDebugMessage("Translated PreMacro: " .. sequence.PreMacro, GNOME)
      end
      if not GSTRisempty(sequence.PostMacro) then
        -- Translate PostMacro
        sequence.PostMacro = string.gsub(sequence.PostMacro, language[toLocale][sid], term)
      end
      -- Translate Sequence Steps
      lines = string.gsub(lines, language[toLocale][sid], term)
      --clear untranslated lines
    end
  end
  for i, v in ipairs(sequence) do sequence = nil end
  GSTRlines(sequence, lines)
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


if GSTRisempty(language[locale]) then
  -- Load the current locale into the language SetAttribute
  if GSCore then
    GSPrintDebugMessage("Loading Spells for language " .. locale, GNOME)
  end
  language[locale] = GSTranslateGetLocaleSpellNameTable()
end

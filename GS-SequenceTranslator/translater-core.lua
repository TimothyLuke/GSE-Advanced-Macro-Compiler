local GNOME, language = ...
local locale = GetLocale();

function GSTranslateSequence(sequence)
    return GSTranslateSequenceFromTo(sequence, isempty(sequence.locale) and "enUS" or sequence.locale), locale)
  end
end

function GSTranslateSequenceFromTo(sequence, fromLocale, toLocale)
  for sid, term in pairs(language[toLocale]) do
    sequence = string.gsub(sequence, language[toLocale][sid], term)
  end
  sequence.locale = toLocale
  return sequence
end

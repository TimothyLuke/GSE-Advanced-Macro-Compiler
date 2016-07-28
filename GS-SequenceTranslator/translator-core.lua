local GNOME, language = ...
local locale = GetLocale();


function GSTRisempty(s)
  return s == nil or s == ''
end

function GSTRListCachedLanguages()
  t = {}
  i = 1
  for name, _ in pairs(language[GSTRStaticKey]) do
    t[i] = name
  end
  return t
end

function GSTranslateSequence(sequence)

  if not GSTRisempty(sequence) then
    if (GSTRisempty(sequence.lang) and "enUS" or sequence.lang) ~= locale then
      --GSPrintDebugMessage((GSTRisempty(sequence.lang) and "enUS" or sequence.lang) .. " ~=" .. locale, GNOME)
      return GSTranslateSequenceFromTo(sequence, (GSTRisempty(sequence.lang) and "enUS" or sequence.lang), locale)
    else
      GSPrintDebugMessage((GSTRisempty(sequence.lang) and "enUS" or sequence.lang) .. " ==" .. locale, GNOME)
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
  for i, v in ipairs(sequence) do sequence[i] = nil end
  GSTRlines(sequence, lines)
  -- check for blanks
  for i, v in ipairs(sequence) do
    if v == "" then
      sequence[i] = nil
    end
  end
  sequence.lang = toLocale
  return sequence
end

function GSTranslateString(instring, fromLocale, toLocale)
  GSPrintDebugMessage("Entering GSTranslateString with : \n" .. instring .. "\n " .. fromLocale .. " " .. toLocale, GNOME)
  local output = ""
  local stringlines = GSTRSplitMeIntolines(instring)
  for _,v in ipairs(stringlines) do
    if not GSTRisempty(v) then
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
          local foundspell = language[GSTRStaticHash][fromLocale][etc]
          if foundspell then
            output = output  .. language[GSTRStaticKey][toLocale][foundspell] .. "\n"
            GSPrintDebugMessage("Translating Spell ID : " .. foundspell .. " to " .. language[GSTRStaticKey][toLocale][foundspell], GNOME)
          else
            GSPrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
            output = output  .. etc .. "\n"
          end
        end
        -- check for cast Sequences
        if strlower(cmd) == "castsequence" then
          for _, w in ipairs(GSTRsplit(etc,",")) do
            if string.sub(w, 1, 1) == "!" then
              w = string.sub(w, 2)
              output = output .. "!"
            end
            local foundspell = language[GSTRStaticHash][fromLocale][w]
            if foundspell then
              output = output ..  language[GSTRStaticKey][toLocale][foundspell] ..", "
            else
              output = output .. w
            end
          end
          output = output .. "\n"
        end
      end
    end
  end
  GSPrintDebugMessage("Exiting GSTranslateString with : \n" .. output, GNOME)
  return output
end

function GSTRSplitMeIntolines(str)
  GSPrintDebugMessage("Entering GSTRSplitMeIntolines with : \n" .. str, GNOME)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    GSPrintDebugMessage("Line : " .. line, GNOME)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function GSTRGetConditionalsFromString(str)
  GSPrintDebugMessage("Entering GSTRGetConditionalsFromString with : " .. str, GNOME)
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
  GSPrintDebugMessage("checking left : " .. (leftstr and leftstr or "nope"), GNOME)
  GSPrintDebugMessage("checking right : " .. (rightstr and rightstr or "nope"), GNOME)
  if rightstr and leftstr then
     found = true
     GSPrintDebugMessage("We have left and right stuff", GNOME)
     mods = string.sub(str, leftstr, rightstr)
     GSPrintDebugMessage("mods changed to: " .. mods, GNOME)
     str = string.sub(str, rightstr + 1)
     GSPrintDebugMessage("str changed to: " .. str, GNOME)
  end
  return found, mods, str
end

function GSTranslateGetLocaleSpellNameTable()
  local spelltable = {}
  local hashtable = {}
  for k,v in pairs(language[GSTRStaticKey]["enUS"]) do
      --print(k)
      local spellname = GetSpellInfo(k)
      spelltable[k] = spellname
      hashtable[spellname] = k
  end
  return spelltable, hashtable
end

function GSTRlines(tab, str)
  local function helper(line) table.insert(tab, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
end


if GSTRisempty(GSTRListCachedLanguages()[locale]) then
  -- Load the current locale into the language SetAttribute
  if GSCore then
    GSPrintDebugMessage("Loading Spells for language " .. locale, GNOME)
  end
  language[GSTRStaticKey][locale], language[GSTRStaticHash][locale] = GSTranslateGetLocaleSpellNameTable()
end

function GSTRsplit(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
  return elements
end

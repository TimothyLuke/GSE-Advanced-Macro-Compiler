local GNOME = "GS-SequenceTranslator"
local locale = GetLocale();
local L = GSL

function GSTRListCachedLanguages()
  t = {}
  i = 1
  for name, _ in pairs(language[GSTRStaticKey]) do
    t[i] = name
    GSPrintDebugMessage("found " .. name, GNOME)
    i = i + 1
  end
  return t
end

function GSTranslateSequence(sequence, sequenceName)

  if not GSisEmpty(sequence) then
    if (GSisEmpty(sequence.lang) and "enUS" or sequence.lang) ~= locale then
      --GSPrintDebugMessage((GSisEmpty(sequence.lang) and "enUS" or sequence.lang) .. " ~=" .. locale, GNOME)
      return GSTranslateSequenceFromTo(sequence, (GSisEmpty(sequence.lang) and "enUS" or sequence.lang), locale, sequenceName)
    else
      GSPrintDebugMessage((GSisEmpty(sequence.lang) and "enUS" or sequence.lang) .. " ==" .. locale, GNOME)
      return sequence
    end
  end
end

function GSTranslateSequenceFromTo(sequence, fromLocale, toLocale, sequenceName)
  GSPrintDebugMessage("GSTranslateSequenceFromTo  From: " .. fromLocale .. " To: " .. toLocale, GNOME)
  -- check if fromLocale exists
  if GSisEmpty(GSAvailableLanguages[GSTRStaticKey][fromLocale]) then
    GSPrint(L["Source Language "] .. fromLocale .. L[" is not available.  Unable to translate sequence "] ..  sequenceName)
    return sequence
  end
  if GSisEmpty(GSAvailableLanguages[GSTRStaticKey][fromLocale]) then
    GSPrint(L["Target language "] .. fromLocale .. L[" is not available.  Unable to translate sequence "] ..  sequenceName)
    return sequence
  end



  local lines = table.concat(sequence,"\n")
  GSPrintDebugMessage("lines: " .. lines, GNOME)

  lines = GSTranslateString(lines, fromLocale, toLocale)
  if not GSisEmpty(sequence.PostMacro) then
    -- Translate PostMacro
    sequence.PostMacro = GSTranslateString(sequence.PostMacro, fromLocale, toLocale)
  end
  if not GSisEmpty(sequence.PreMacro) then
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

function GSTranslateString(instring, fromLocale, toLocale, cleanNewLines)
  instring = GSTRUnEscapeString(instring)
  GSPrintDebugMessage("Entering GSTranslateString with : \n" .. instring .. "\n " .. fromLocale .. " " .. toLocale, GNOME)

  local output = ""
  local stringlines = GSTRSplitMeIntolines(instring)
  for _,v in ipairs(stringlines) do
    --print ("v = ".. v)
    if not GSisEmpty(v) then
      for cmd, etc in gmatch(v or '', '/(%w+)%s+([^\n]+)') do
        GSPrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
        output = output..GSMasterOptions.WOWSHORTCUTS .. "/" .. cmd .. GSStaticStringRESET .. " "
        if GSStaticCastCmds[strlower(cmd)] then
          if not cleanNewLines then
            etc = string.match(etc, "^%s*(.-)%s*$")
          end
          if string.sub(etc, 1, 1) == "!" then
            etc = string.sub(etc, 2)
            output = output .. "!"
          end
          local foundspell, returnval = GSTRTranslateSpell(etc, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
          if foundspell then
            output = output ..GSMasterOptions.KEYWORD .. returnval .. GSStaticStringRESET .. "\n"
          else
            GSPrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
            output = output  .. etc .. "\n"
          end
        -- check for cast Sequences
        elseif strlower(cmd) == "castsequence" then
          GSPrintDebugMessage("attempting to split : " .. etc, GNOME)
          --look for conditionals at the startattack
          local conditionals, mods, uetc = GSTRGetConditionalsFromString(etc)
          if conditionals then
            output = output ..GSMasterOptions.STANDARDFUNCS .. mods .. GSStaticStringRESET .. " "
          end
          for _, w in ipairs(GSTRsplit(uetc,",")) do
            if not cleanNewLines then
              w = string.match(w, "^%s*(.-)%s*$")
            end
            if string.sub(w, 1, 1) == "!" then
              w = string.sub(w, 2)
              output = output .. "!"
            end
            local foundspell, returnval = GSTRTranslateSpell(w, fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
            output = output ..  GSMasterOptions.KEYWORD .. returnval .. GSStaticStringRESET .. ", "
          end
          local resetleft = string.find(output, ", , ")
          if not GSisEmpty(resetleft) then
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
  GSPrintDebugMessage("Exiting GSTranslateString with : \n" .. output, GNOME)
  -- check for random , at the end
  if string.sub(output, strlen(output)-1) == ", " then
    output = string.sub(output, 1, strlen(output)-2)
  end
  return output
end

function GSTRTranslateSpell(str, fromLocale, toLocale, cleanNewLines)
  local output = ""
  local found = false
  -- check for cases like /cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar
  if not cleanNewLines then
    str = string.match(str, "^%s*(.-)%s*$")
  end
  GSPrintDebugMessage("GSTRTranslateSpell Attempting to translate " .. str, GNOME)
  if string.sub(str, strlen(str)) == "," then
    str = string.sub(str, 1, strlen(str)-1)
  end
  if string.match(str, ";") then
    GSPrintDebugMessage("GSTRTranslateSpell found ; in " .. str .. " about to do recursive call.", GNOME)
    for _, w in ipairs(GSTRsplit(str,";")) do
      found, returnval = GSTRTranslateSpell((cleanNewLines and w or string.match(w, "^%s*(.-)%s*$")), fromLocale, toLocale, (cleanNewLines and cleanNewLines or false))
      output = output ..  GSMasterOptions.KEYWORD .. returnval .. GSStaticStringRESET .. "; "
    end
    if string.sub(output, strlen(output)-1) == "; " then
      output = string.sub(output, 1, strlen(output)-2)
    end
  else
    local conditionals, mods, etc = GSTRGetConditionalsFromString(str)
    if conditionals then
      output = output .. mods .. " "
      GSPrintDebugMessage("GSTRTranslateSpell conditionals found ", GNOME)
    end
    GSPrintDebugMessage("output: " .. output .. " mods: " .. mods .. " etc: " .. etc, GNOME)
    if not cleanNewLines then
      etc = string.match(etc, "^%s*(.-)%s*$")
    end
    etc = string.gsub (etc, "!", "")
    local foundspell = GSAvailableLanguages[GSTRStaticHash][fromLocale][etc]
    if foundspell then
      GSPrintDebugMessage("Translating Spell ID : " .. foundspell , GNOME )
      GSPrintDebugMessage(" to " .. (GSisEmpty(GSAvailableLanguages[GSTRStaticKey][toLocale][foundspell]) and " but its not in [GSTRStaticKey][" .. toLocale .. "]" or GSAvailableLanguages[GSTRStaticKey][toLocale][foundspell]) , GNOME)
      output = output .. GSMasterOptions.KEYWORD .. GSAvailableLanguages[GSTRStaticKey][toLocale][foundspell] .. GSStaticStringRESET
      found = true
    else
      GSPrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale .. " Hash table checking shadow table", GNOME)
      -- try the shadow table
      local nfoundspell = GSAvailableLanguages[GSTRStaticShadow][fromLocale][string.lower(etc)]
      if nfoundspell then
        GSPrintDebugMessage("Translating from the shadow table for  Spell ID : " .. nfoundspell .. " to " .. GSAvailableLanguages[GSTRStaticKey][toLocale][nfoundspell], GNOME)
        output = output  .. GSMasterOptions.KEYWORD .. GSAvailableLanguages[GSTRStaticKey][toLocale][nfoundspell] .. GSStaticStringRESET
        found = true
      else
        GSPrintDebugMessage("Did not find : " .. etc .. " in " .. fromLocale, GNOME)
        output = output  .. GSMasterOptions.UNKNOWN .. etc .. GSStaticStringRESET
        GSTRUnfoundSpells [#GSTRUnfoundSpells + 1] = etc
      end
    end
  end
  return found, output
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
  if not cleanNewLines then
    str = string.match(str, "^%s*(.-)%s*$")
  end
  -- Check for resets
  GSPrintDebugMessage("checking for reset= in " .. str, GNOME)
  local resetleft = string.find(str, "reset=")
  if not GSisEmpty(resetleft) then
    GSPrintDebugMessage("found reset= at" .. resetleft, GNOME)
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
    GSPrintDebugMessage("reset= mods changed to: " .. mods, GNOME)
    str = string.sub(str, resetright + 1)
    GSPrintDebugMessage("reset= test str changed to: " .. str, GNOME)
    found = true
  end

  mods = GSMasterOptions.COMMENT .. mods .. GSStaticStringRESET
  return found, mods, str
end

function GSTRlines(tab, str)
  local function helper(line) table.insert(tab, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
end


function GSTRsplit(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
  return elements
end


function GSTRReportUnfoundSpells()
  GSTRUnfoundSpells = nil
  GSTRUnfoundSpells = {}

  for name,version in pairs(GSMasterOptions.SequenceLibrary) do
    for v, sequence in ipairs(version) do
      GSTranslateSequenceFromTo(sequence, "enUS", "enUS", name)
    end
  end
  GSTRUnfoundSpellIds = {}

  for _,spell in pairs(GSTRUnfoundSpells) do
    GSTRUnfoundSpellIds[spell] = GetSpellInfo(spell)
  end
end

GSTranslatorAvailable = true
-- Reloading Sequences as Translator is now here.
GSReloadSequences()

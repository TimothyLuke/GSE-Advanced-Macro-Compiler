local GSE = GSE
local Statics = GSE.Static

local GNOME = Statics.DebugModules["Translator"]

local L = GSE.L


--- GSE.TranslateSequence will translate from local spell name to spell id and back again.\
-- mode of "STRING" will return local names where mode "ID" will return id's

function GSE.TranslateSequence(sequence, sequenceName, mode)
  GSE.PrintDebugMessage("GSE.TranslateSequence  Mode: " .. mode, GNOME)


  for k,v in ipairs(sequence) do
    -- Translate sequence
    sequence[k] = GSE.TranslateString(v, mode)
  end


  if not GSE.isEmpty(sequence.KeyRelease) then
    for k,v in pairs(sequence.KeyRelease) do
      sequence.KeyRelease[k] = GSE.TranslateString(v, mode)
    end
  else
    GSE.PrintDebugMessage("empty Keyrelease in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.KeyPress) then
    GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.KeyPress) do
      -- Translate KeyRelease
      sequence.KeyPress[k] = GSE.TranslateString(v, mode)
    end
  else
    GSE.PrintDebugMessage("empty Keypress in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.PreMacro) then
      GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.PreMacro) do
      -- Translate KeyRelease
      sequence.PreMacro[k] = GSE.TranslateString(v, mode)
    end
  else
    GSE.PrintDebugMessage("empty Keypress in translate", Statics.Translate)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    GSE.PrintDebugMessage("Keypress has stuff in translate", Statics.Translate)
    for k,v in pairs(sequence.PostMacro) do
      -- Translate KeyRelease
      sequence.PostMacro[k] = GSE.TranslateString(v, mode)
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

function GSE.TranslateString(instring, mode, cleanNewLines)
  instring = GSE.UnEscapeString(instring)
  GSE.PrintDebugMessage("Entering GSE.TranslateString with : \n" .. instring .. "\n " .. mode, GNOME)
  local output = ""
  if not GSE.isEmpty(instring) then
    if GSE.isEmpty(string.find(instring, '--', 1, true)) then
      for cmd, etc in string.gmatch(instring or '', '/(%w+)%s+([^\n]+)') do
        GSE.PrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
        output = output..GSEOptions.WOWSHORTCUTS .. "/" .. cmd .. Statics.StringReset .. " "
        if string.lower(cmd) == "use" then
          local conditionals, mods, trinketstuff = GSE.GetConditionalsFromString(etc)
          if conditionals then
            output = output .. mods .. " "
            GSE.PrintDebugMessage("GSE.TranslateSpell conditionals found ", GNOME)
          end
          GSE.PrintDebugMessage("output: " .. output .. " mods: " .. mods .. " etc: " .. etc, GNOME)

          local trinketfound, trinketval = GSE.DecodeTrinket(trinketstuff, mode)
          if trinketfound then
            output = output ..  GSEOptions.KEYWORD .. trinketval .. Statics.StringReset
          else
            output = output  .. GSEOptions.UNKNOWN .. trinketstuff .. Statics.StringReset
          end
        elseif Statics.CastCmds[string.lower(cmd)] then
          if not cleanNewLines then
            etc = string.match(etc, "^%s*(.-)%s*$")
          end
          if string.sub(etc, 1, 1) == "!" then
            etc = string.sub(etc, 2)
            output = output .. "!"
          end
          local foundspell, returnval = GSE.TranslateSpell(etc, mode, (cleanNewLines and cleanNewLines or false))
          if foundspell then
            output = output ..GSEOptions.KEYWORD .. returnval .. Statics.StringReset
          else
            GSE.PrintDebugMessage("Did not find : " .. etc , GNOME)
            output = output  .. etc
          end
        -- check for cast Sequences
        elseif string.lower(cmd) == "castsequence" then
          GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
          for x,y in ipairs(GSE.split(etc,";")) do
            for _, w in ipairs(GSE.SplitCastSequence(y,",")) do
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
              local foundspell, returnval = GSE.TranslateSpell(uetc, mode, (cleanNewLines and cleanNewLines or false))
              output = output ..  GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. ", "
            end
            output = output .. ";"
          end
          output = string.sub(output, 1, string.len(output) -1)
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
    else
      GSE.PrintDebugMessage("Detected Comment " .. string.find(instring, '--', 1, true), GNOME)
      output = output ..  GSEOptions.CONCAT .. instring .. Statics.StringReset
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
  output = string.gsub(output, ", ;", "; ")

  output = string.gsub(output, "  ", " ")
  return output
end

function GSE.TranslateSpell(str, mode, cleanNewLines)
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
      found, returnval = GSE.TranslateSpell((cleanNewLines and w or string.match(w, "^%s*(.-)%s*$")), mode, (cleanNewLines and cleanNewLines or false))
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
    local foundspell = GSE.GetSpellId(etc, mode)
    if foundspell then
      GSE.PrintDebugMessage("Translating Spell ID : " .. etc .. " to " .. foundspell , GNOME )
      output = output .. GSEOptions.KEYWORD .. foundspell .. Statics.StringReset
      found = true
    else
      GSE.PrintDebugMessage("Did not find : " .. etc .. ".  Spell may no longer exist", GNOME)
      output = output  .. GSEOptions.UNKNOWN .. etc .. Statics.StringReset
      if GSE.isEmpty(GSEOptions.UnfoundSpells) then
        GSEOptions.UnfoundSpells = {}
      end
      GSEOptions.UnfoundSpells [etc] = true
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

end


function GSE.DecodeTrinket(slot, mode)
  local found = false
  local returnval
  if mode == "STRING" then
    for k,v in ipairs(Statics.CharacterDollSlot) do
      if tonumber(slot) == k then
        returnval = v
        found = true
      end
    end
  else
    for k,v in pairs(Statics.CharacterDollSlotReverse) do
      if string.lower(slot) == k then
        returnval = v
        found = true
      end
    end
  end
  return found, returnval
end

--- Converts a string spell name to an id and back again.
function GSE.GetSpellId(spellstring, mode, trinketmode)
  local returnval = ""
  local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellstring)
  if mode == "STRING" then
    returnval = name
  else
    returnval = spellId
    -- Check for overides like Crusade and Avenging Wrath
    if not GSE.isEmpty(Statics.BaseSpellTable[returnval]) then
      returnval = Statics.BaseSpellTable[returnval]
    end
  end
  if not GSE.isEmpty(returnval) then
    GSE.PrintDebugMessage("Converted " .. spellstring .. " to " .. returnval .. " using mode " .. mode, "Translator")
  else
    if not GSE.isEmpty(spellstring) then
      GSE.PrintDebugMessage(spellstring .. " was not found" , "Translator")
    else
      GSE.PrintDebugMessage("Nothing was there to be found" , "Translator")
    end
  end
  return returnval
end

--- takes a section of a sequence and returns the spells used.
function GSE.IdentifySpells(tab)
  local foundspells = {}
  local returnval = ""
  for _,p in ipairs(tab) do
    -- run a regex to find all spell id's from the table and add them to the table foundspells
    for m in string.gmatch( p, "%w%d+" ) do

      foundspells[m] = 1
    end
  end

  for k,v in pairs(foundspells) do
   if not GSE.isEmpty(GSE.GetSpellId(k, "STRING", false)) then
     returnval = returnval .. '<a href="http://www.wowdb.com/spells/' .. k .. '">' .. GSE.GetSpellId(k, "STRING", false) .. '</a>, '
   end
  end

  return string.sub(returnval, 1, string.len(returnval) - 2), foundspells
end

GSE.TranslatorAvailable = true

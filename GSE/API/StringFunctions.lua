local GSE = GSE
local Statics = GSE.Static


--- remove WoW Text Markup from a sequence
function GSE.UnEscapeSequence(sequence)

  local retseq = GSE.UnEscapeTable(sequence)
  for k,v in pairs(sequence) do
    if type (k) == "string" then
      retseq[k] = v
    end
  end
  if not GSE.isEmpty(sequence.KeyPress) then
    retseq.KeyPress = GSE.UnEscapeTable(sequence.KeyPress)
  end
  if not GSE.isEmpty(sequence.KeyRelease) then
    retseq.KeyRelease = GSE.UnEscapeTable(sequence.KeyRelease)
  end
  if not GSE.isEmpty(sequence.PreMacro) then
    retseq.PreMacro = GSE.UnEscapeTable(sequence.PreMacro)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    retseq.PostMacro = GSE.UnEscapeTable(sequence.PostMacro)
  end

  return retseq
end

function GSE.UnEscapeTable(tab)
  local newtab = {}
  for k,v in ipairs(tab) do
    -- print (k .. " " .. v)
    local cleanstring = GSE.UnEscapeString(v)
    if not GSE.isEmpty(cleanstring) then
      newtab[k] = cleanstring
    end
  end
  return newtab
end

--- remove WoW Text Markup from a string
function GSE.UnEscapeString(str)

    for k, v in pairs(Statics.StringFormatEscapes) do
        str = string.gsub(str, k, v)
    end
    return str
end

--- Add ths lines of a string as individual entries.
function GSE.lines(tab, str)
  local function helper(line)
    table.insert(tab, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
end

--- Checks for nil or empty variables.
function GSE.isEmpty(s)
  return s == nil or s == ''
end

--- Convert a string to an array of lines
function GSE.SplitMeIntolines(str)
  GSE.PrintDebugMessage("Entering GSTRSplitMeIntolines with : \n" .. str, GNOME)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    GSE.PrintDebugMessage("Line : " .. line, GNOME)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

--- This function splits a castsequence into its parts where a split() cant.
function GSE.SplitCastSequence(str)
  local tab = {}
  local slen = string.len(str)
  local modblock = false
  local start = 1
  GSE.PrintDebugMessage (slen, "Storage")
  for i=1,slen,1 do
    if string.sub(str, i, i) == "[" then
      modblock = true
      GSE.PrintDebugMessage("in mod at " .. i, "Storage")
    elseif string.sub(str, i, i) == "]" then
      modblock = false
      GSE.PrintDebugMessage ("leaving mod at " .. i, "Storage")
    elseif string.sub(str, i, i) == "," and not modblock then
      table.insert(tab, string.sub(str, start, i-1))
      start = i+1
      GSE.PrintDebugMessage("found terminator at " .. i, "Storage")
    end

  end
  table.insert(tab, string.sub(str, start))
  return tab
end


--- Split a string into an array based on the deliminter specified.
-- Not currently used
function GSE.split(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
  return elements
end


function GSE.FixQuotes(source)
  source = string.gsub(source, "%‘", "'")
  source = string.gsub(source, "%’", "'")
  source = string.gsub(source, "%”", "\"")
  return source
end

function GSE.CleanStrings(source)
  for k,v in pairs(Statics.CleanStrings) do

    if source == v then
      source = ""
    else
      source = string.gsub(source, v, "")
    end
  end
  return source
end

function GSE.CleanMacroVersion(macroversion)
  if not GSE.isEmpty(macroversion.KeyPress) then
    macroversion.KeyPress = GSE.CleanStringsArray(macroversion.KeyPress)
  end
  if not GSE.isEmpty(macroversion.KeyRelease) then
    macroversion.KeyRelease = GSE.CleanStringsArray(macroversion.KeyRelease)
  end
  return macroversion
end

function GSE.CleanStringsArray(tabl)
  for k,v in ipairs(tabl) do
    local tempval = GSE.CleanStrings(v)
    if tempval == [[""]] then
      tabl[k] = nil
    else
      tabl[k] = tempval
    end
  end
  return tabl
end


function GSE.pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end


function GSE.formatModVersion(vers)
  vers = tostring(vers)
  vers = string.sub(vers, 1, 1) .. "." .. string.sub(vers, 2, 2) .. "." .. string.sub(vers, 3)
  return vers
end

--- This function removes any hidden characters from a string.
function GSE.StripControlandExtendedCodes( str )
  local s = ""
  for i = 1, str:len() do
	  if str:byte(i) >= 32 and str:byte(i) <= 126 then -- space through to normal en character
      s = s .. str:sub(i,i)
    elseif str:byte(i) == 194 and str:byte(i+1) == 160 then -- Fix for IE/Edge
      s = s .. " "
    elseif str:byte(i) == 160 and str:byte(i-1) == 194 then -- Fix for IE/Edge
      s = s .. " "
    elseif str:byte(i) == 10 then -- leave line breaks unix style
      s = s .. str:sub(i,i)
    elseif str:byte(i) == 13 then -- leave line breaks windows style
      s = s .. str:sub(i, str:byte(10))
    elseif str:byte(i) >= 128 then -- extended characters including accented characters for intenational languages
      s = s .. str:sub(i,i)
    else -- convert everything else to whitespace
      s = s .. " "
	  end
  end
  return s
end

function GSE.TrimWhiteSpace(str)
  return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function GSE.Dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. GSE.Dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function GSE.FindGlobalObject(name)
    local a = _G
    for key in string.gmatch(name, "([^%.]+)(%.?)") do
        if a[key] then
            a = a[key]
        else
            return nil
        end
    end
    return a
end

function GSE.ObjectExists(name)
    return type(GSE.FindGlobalObject(name)) ~= 'nil'
end

function GSE.ExportSequenceWLMFormat(sequence, sequencename)
    local returnstring = "<h1>sequencename</h1><h3>Talents</h3><p>" .. (GSE.isEmpty(sequence.Talents) and "?,?,?,?,?,?,?" or sequence.Talents) .. "</p>\n"
    if not GSE.isEmpty(sequence.Help) then
      returnstring = "<h3>Usage Information</h3><p>" .. sequence.Help .. "</p>\n"
    end
    returnstring = returnstring .. "<p>This macro contains " .. (table.getn(sequence.MacroVersions) > 1 and table.getn(sequence.MacroVersions) .. "macro versions." or "1 macro version.") .. string.format(L["This Sequence was exported from GSE %s."], GSE.formatModVersion(GSE.VersionString)) .. "\n"
    if (table.getn(sequence.MacroVersions) > 1) then
      returnstring = returnstring .. "<ul>"
      for k,v in pairs(sequence.MacroVersions) do
        if not GSE.isEmpty(sequence.Default) then
          if sequence.Default == k then
            returnstring = returnstring .. "<li>The Default macro is " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Raid) then
          if sequence.Raid == k then
            returnstring = returnstring .. "<li>Raids use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.PVP) then
          if sequence.PVP == k then
            returnstring = returnstring .. "<li>PVP uses version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Dungeon) then
          if sequence.Dungeon == k then
            returnstring = returnstring .. "<li>Normal Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Heroic) then
          if sequence.Heroic == k then
            returnstring = returnstring .. "<li>Heroic Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Mythic) then
          if sequence.Mythic == k then
            returnstring = returnstring .. "<li>Mythic Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Arena) then
          if sequence.Arena == k then
            returnstring = returnstring .. "<li>Arenas use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Timewalking) then
          if sequence.Timewalking == k then
            returnstring = returnstring .. "<li>Timewalking Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.MythicPlus) then
          if sequence.MythicPlus == k then
            returnstring = returnstring .. "<li>Mythic+ Dungeons use version " .. k .. "</li>\n"
          end
        end
        if not GSE.isEmpty(sequence.Party) then
          if sequence.Party == k then
            returnstring = returnstring .. "<li>Open World Parties use version " .. k .. "</li>\n"
          end
        end
      end

      returnstring = returnstring .. "</UL></p>\n"
    end
    for k,v in pairs(sequence.MacroVersions) do
      returnstring = returnstring .. "<h4>Macro Version ".. k .. "</h4>\n"
      returnstring = returnstring .. "<p><strong>Step Function: </strong>" .. v.StepFunction .. "<br/>\n"
      if not GSE.isEmpty(v.PreMacro) then
        if table.getn(v.PreMacro) > 0 then
          returnstring = returnstring .. "<strong>Pre Macro: </strong>" .. GSE.IdentifySpells(v.PreMacro) .. "<br/>\n"
        end
      end
      if not GSE.isEmpty(v.KeyPress) then
        if table.getn(v.KeyPress) > 0 then
          returnstring = returnstring .. "<strong>KeyPress: </strong>" .. GSE.IdentifySpells(v.KeyPress) .. "<br/>\n"
        end
      end
      returnstring = returnstring .. "<strong>Main Sequence: </strong>" .. GSE.IdentifySpells(v) .. "<br/>\n"
      if not GSE.isEmpty(v.KeyRelease) then
        if table.getn(v.KeyRelease) > 0 then
          returnstring = returnstring .. "<strong>KeyPress: </strong>" .. GSE.IdentifySpells(v.KeyPress) .. "<br/>\n"
        end
      end
      if not GSE.isEmpty(v.PostMacro) then
        if table.getn(v.PostMacro) > 0 then
          returnstring = returnstring .. "<strong>Post Macro: </strong>" .. GSE.IdentifySpells(v.PostMacro) .. "<br/>\n"
        end
      end
    end
    returnstring = returnstring .. "</p>"
    return returnstring
end

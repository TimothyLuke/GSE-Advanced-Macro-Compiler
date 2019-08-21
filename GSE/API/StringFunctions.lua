local GSE = GSE
local Statics = GSE.Static


--- Remove WoW Text Markup from a sequence.
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
    --print (k .. " " .. v)
    local cleanstring = GSE.UnEscapeString(v)
    if not GSE.isEmpty(cleanstring) then
      newtab[k] = cleanstring
    end
  end
  return newtab
end

--- Remove WoW Text Markup from a string.
function GSE.UnEscapeString(str)

    for k, v in pairs(Statics.StringFormatEscapes) do
        str = string.gsub(str, k, v)
    end
    return str
end

--- Add the lines of a string as individual entries.
function GSE.lines(tab, str)
  local function helper(line)
    table.insert(tab, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
end

--- Convert a string to an array of lines.
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

--- This function splits a castsequence into its parts where a split() can't.
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
  local i = 0      -- Iterator variable
  local iter = function ()   -- Iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

--- This function removes any hidden characters from a string.
function GSE.StripControlandExtendedCodes( str )
  local s = ""
  for i = 1, str:len() do
	  if str:byte(i) >= 32 and str:byte(i) <= 126 then -- Space through to normal EN character
      s = s .. str:sub(i,i)
    elseif str:byte(i) == 194 and str:byte(i+1) == 160 then -- Fix for IE/Edge
      s = s .. " "
    elseif str:byte(i) == 160 and str:byte(i-1) == 194 then -- Fix for IE/Edge
      s = s .. " "
    elseif str:byte(i) == 10 then -- Leave line breaks Unix style
      s = s .. str:sub(i,i)
    elseif str:byte(i) == 13 then -- Leave line breaks Windows style
      s = s .. str:sub(i, str:byte(10))
    elseif str:byte(i) >= 128 then -- Extended characters including accented characters for international languages
      s = s .. str:sub(i,i)
    else -- Convert everything else to whitespace
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

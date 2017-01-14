local GSE = GSE
local Statics = GSE.Static


--- remove WoW Text Markup from a sequence
function GSE.UnEscapeSequence(sequence)
  local retseq = GSE.UnEscapeTable(sequence)

  --retseq.StepFunction = sequence.StepFunction
  for k,v in pairs(sequence) do
    if type (k) == string then
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

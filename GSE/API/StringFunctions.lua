local GSE = GSE
local Statics = GSE.Static


--- remove WoW Text Markup from a sequence
function GSE.UnEscapeSequence(sequence)
  GSE.UnEscapeTable(sequence)
  if not GSE.isEmpty(sequence.KeyPress) then
    GSE.UnEscapeTable(sequence.KeyPress)
  end
  if not GSE.isEmpty(sequence.KeyRelease) then
    GSE.UnEscapeTable(sequence.KeyRelease)
  end
  if not GSE.isEmpty(sequence.PreMacro) then
    GSE.UnEscapeTable(sequence.PreMacro)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    GSE.UnEscapeTable(sequence.PostMacro)
  end
  return sequence
end

function GSE.UnEscapeTable(tab)
  local i = 1
  for _,v in ipairs(tab) do
    --print (i .. " " .. v)
    tab[i] = GSE.UnEscapeString(v)
    i = i + 1
  end
end

--- remove WoW Text Markup from a string
function GSE.UnEscapeString(str)
    for k, v in pairs(Statics.StringFormatEscapes) do
        str = gsub(str, k, v)
    end
    return str
end


--- Format the text against the GSE Sequence Spec.
function GSE.parsetext(editbox)
  if GSEOptions.RealtimeParse then
    text = GSE.UnEscapeString(editbox:GetText())
    returntext = GSE.TranslateString(text , GetLocale(), GetLocale(), true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext)+2)
  end
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
    GSEPrintDebugMessage("Line : " .. line, GNOME)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end



--- Split a string into an array based on the deliminter specified.
function GSE.split(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
  return elements
end


function GSE.FixQuotes(source)
  source = string.gsub(source, "%‘", "'")
  source = string.gsub(value, "%”", "\"")
end

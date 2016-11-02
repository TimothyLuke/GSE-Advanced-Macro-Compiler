local GSE = GSE
local Statics = GSE.Static


--- remove WoW Text Markup from a sequence
function GSE.UnEscapeSequence(sequence)
  local i = 1
  for _,v in ipairs(sequence) do
    --print (i .. " " .. v)
    sequence[i] = GSE.UnEscapeString(v)
    i = i + 1
  end
  if not GSE.isEmpty(sequence.PreMacro) then
    sequence.PreMacro = GSE.UnEscapeString(sequence.PreMacro)
  end
  if not GSE.isEmpty(sequence.PostMacro) then
    sequence.PostMacro = GSE.UnEscapeString(sequence.PostMacro)
  end
  return sequence
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
  if GSMasterOptions.RealtimeParse then
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


--- Split a string into an array based on the deliminter specified.
function GSE.split(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
  return elements
end

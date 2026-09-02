local _, GSE = ...
local Statics = GSE.Static

--- Remove WoW Text Markup from a sequence.  Deprecated Use GSE.UnEscapeTableRecursive
function GSE.UnEscapeSequence(sequence)
    local retseq = GSE.UnEscapeTable(sequence)
    return retseq
end

--- Deprecated Use GSE.UnEscapeTableRecursive instead
function GSE.UnEscapeTable(tab)
    return GSE.UnEscapeTableRecursive(tab)
end

--- Remove WoW Text Markup from a string.
function GSE.UnEscapeString(str)
    if type(str) ~= "string" then
        return str
    end
    -- Strip doubled escapes (e.g. round-tripped through SetText) before single ones
    str = string.gsub(str, "||[cC]%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "||r", "")
    str = string.gsub(str, "|[cC]%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    for k, v in pairs(Statics.StringFormatEscapes) do
        str = string.gsub(str, k, v)
    end
    str = string.gsub(str, "||", "|")
    return str
end

function GSE.UnEscapeTableRecursive(tab)
    for k, v in pairs(tab) do
        if type(v) == "table" then
            tab[k] = GSE.UnEscapeTableRecursive(v)
        elseif type(v) == "string" then
            tab[k] = GSE.UnEscapeString(v)
        end
    end

    for k, v in ipairs(tab) do
        if type(v) == "table" then
            tab[k] = GSE.UnEscapeTableRecursive(v)
        elseif type(v) == "string" then
            tab[k] = GSE.UnEscapeString(v)
        end
    end
    return tab
end

--- Decode editor/IndentationLib colour markup back to plain text.
function GSE.DecodeEditorText(text)
    if type(text) ~= "string" then return text end
    if not (text:find("|[cC]%x%x%x%x%x%x%x%x") or text:find("||[cC]%x%x%x%x%x%x%x%x") or text:find("|r", 1, true) or text:find("||r", 1, true) or text:find("||", 1, true)) then
        return text
    end

    local function stripMarkup(value)
        value = value:gsub("||[cC]%x%x%x%x%x%x%x%x", "")
        value = value:gsub("||r", "")
        value = value:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
        value = value:gsub("|r", "")
        value = value:gsub("||", "|")
        return value
    end

    if IndentationLib and IndentationLib.decode then
        local ok, decoded = pcall(IndentationLib.decode, text)
        if ok and type(decoded) == "string" then
            text = decoded
        else
            text = stripMarkup(text)
        end
    else
        text = stripMarkup(text)
    end

    text = stripMarkup(text)
    if GSE.UnEscapeString then
        local ok, decoded = pcall(GSE.UnEscapeString, text)
        if ok and type(decoded) == "string" then text = decoded end
    end
    return text
end

--- Decode markup from a macro command block and repair command slashes.
function GSE.DecodeMacroEditorText(text)
    text = GSE.DecodeEditorText(text)
    if type(text) ~= "string" then return text end
    text = text:gsub("(^[ \t]*)|([%a]+)", "%1/%2")
    text = text:gsub("(\n[ \t]*)|([%a]+)", "%1/%2")
    return text
end

--- Count macro editor text while ignoring full Lua-style note lines.
function GSE.GetMacroEditorTextLength(text)
    text = GSE.DecodeMacroEditorText(text)
    if type(text) ~= "string" or text == "" then return 0 end

    local countedLines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        if not line:match("^%s*%-%-") then
            table.insert(countedLines, line)
        end
    end
    return string.len(table.concat(countedLines, "\n"))
end
-- WoW's macro parser reads `#showtooltip` / `#show` as icon-and-tooltip
-- directives. GSE never puts a sequence action through that parser -- an
-- action body is handed to a secure button as `macrotext` -- so the directive
-- does nothing inside a sequence. Worse, its leading `#` made the body fail
-- the "starts with /" test that gates BOTH spell-name -> ID compilation and
-- macrotext-vs-macro-name detection, so a `#showtooltip`-led block kept raw
-- locale spell names and was filed as the NAME of an in-game macro.
-- GSE.ApplyShowTooltipToAction strips the directive and, when its argument
-- resolves, keeps the author's intent by promoting it to the block icon.
local SHOWTOOLTIP_DIRECTIVE = "^%s*#showtooltip%s*(.-)%s*$"
local SHOW_DIRECTIVE = "^%s*#show%s*(.-)%s*$"

-- Order matters: `#showtooltip Spell` also matches the shorter `#show`
-- pattern, which would capture "tooltip Spell" as the argument.
local function matchShowTooltipDirective(line)
    if type(line) ~= "string" then return nil end
    local argument = line:match(SHOWTOOLTIP_DIRECTIVE)
    if argument then return argument end
    return line:match(SHOW_DIRECTIVE)
end

--- Split a macro body into the part GSE executes and the #showtooltip / #show
--- directive it ignores. Returns body, directiveArgument, found. The argument
--- is nil for a bare `#showtooltip` (which asks for exactly the automatic icon
--- GSE already derives) and, when several directives are present, is the first
--- one that carried an argument.
function GSE.SplitShowTooltipDirectives(text)
    if type(text) ~= "string" or text == "" then return text, nil, false end
    if not text:find("#show", 1, true) then return text, nil, false end

    local kept = {}
    local argument
    local found = false
    for _, line in ipairs(GSE.SplitMeIntoLines(text)) do
        local directive = matchShowTooltipDirective(line)
        if directive then
            found = true
            if argument == nil and directive ~= "" then argument = directive end
        else
            table.insert(kept, line)
        end
    end
    if not found then return text, nil, false end
    return table.concat(kept, "\n"), argument, true
end

--- First character GSE actually acts on in a macro body, skipping the
--- #showtooltip / #show lines it never executes and any leading blank lines.
--- "" when there is no actionable content.
function GSE.GetMacroBodyLeadChar(text)
    if type(text) ~= "string" or text == "" then return "" end
    for _, line in ipairs(GSE.SplitMeIntoLines(text)) do
        if not matchShowTooltipDirective(line) then
            local trimmed = line:gsub("^%s+", "")
            if trimmed ~= "" then return string.sub(trimmed, 1, 1) end
        end
    end
    return ""
end

--- Is this body macro TEXT (slash commands GSE compiles and runs), as opposed
--- to the NAME of an in-game macro or a `=`-prefixed GSE variable?
function GSE.IsMacroTextBody(text)
    return GSE.GetMacroBodyLeadChar(text) == "/"
end

--- Strip #showtooltip / #show from a sequence action, promoting a resolvable
--- directive argument to the block icon. Only touches Action/Repeat blocks:
--- a managed in-game macro IS run through WoW's parser, where the directive is
--- meaningful and must survive.
function GSE.ApplyShowTooltipToAction(action)
    if type(action) ~= "table" then return false end
    if action.Type ~= Statics.Actions.Action and action.Type ~= Statics.Actions.Repeat then
        return false
    end

    local changed = false
    for _, key in ipairs({"macro", "macrotext"}) do
        local body = action[key]
        if type(body) == "string" and body ~= "" then
            local stripped, argument, found = GSE.SplitShowTooltipDirectives(body)
            if found then
                local iconInfo
                if argument and GSE.GetShowTooltipIconInfo then
                    iconInfo = GSE.GetShowTooltipIconInfo(argument, true)
                end
                local resolvedIcon = iconInfo and iconInfo.iconID or nil
                -- An argument we cannot resolve is usually a spell name from
                -- another client's locale. Dropping the line would destroy the
                -- only record of the author's icon, so leave it in place for a
                -- client -- or the website, which holds every locale -- that can
                -- resolve it. The directive is inert either way, and
                -- GSE.GetMacroBodyLeadChar already looks past it.
                if argument == nil or resolvedIcon then
                    if action[key] ~= stripped then
                        action[key] = stripped
                        changed = true
                    end
                    if resolvedIcon and not action.IconUserSelected then
                        -- `#showtooltip Spell` is an explicit icon choice, so it
                        -- lands the same way the icon picker's does. Once the
                        -- line is gone it cannot be re-derived, and Reset Icons
                        -- still clears it.
                        if action.Icon ~= resolvedIcon then action.Icon = resolvedIcon end
                        action.IconUserSelected = true
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

function GSE.StoreMacroEditorText(text, mode)
    text = GSE.DecodeMacroEditorText(text)
    if type(text) ~= "string" then return "" end
    if GSE.IsMacroTextBody(text) and GSE.CompileMacroText then
        text = GSE.DecodeMacroEditorText(GSE.CompileMacroText(text, mode or Statics.TranslatorMode.ID))
    end
    return text
end

--- Remove leaked editor markup from imported or loaded sequence data.
function GSE.SanitizeSequenceEditorMarkup(node, macroTextContext)
    if type(node) ~= "table" then return false end
    local changed = false
    local macroTextKeys = {
        macro = true,
        macrotext = true,
        text = true,
        managedMacro = true,
        manageMacro = true
    }
    local macroTextContainers = {
        KeyPress = true,
        KeyRelease = true
    }

    for k, v in pairs(node) do
        if type(v) == "table" then
            if GSE.SanitizeSequenceEditorMarkup(v, macroTextContext or macroTextContainers[k]) then
                changed = true
            end
        elseif type(v) == "string" then
            local repaired
            if macroTextContext or macroTextKeys[k] then
                repaired = GSE.DecodeMacroEditorText(v)
            elseif k == "funct" then
                repaired = GSE.DecodeEditorText(v)
            end
            if repaired and repaired ~= v then
                node[k] = repaired
                changed = true
            end
        end
    end
    -- After the markup repair above, so the directive match sees plain text.
    if GSE.ApplyShowTooltipToAction(node) then
        changed = true
    end
    return changed
end

--- Add the lines of a string as individual entries.
function GSE.lines(tab, str)
    if type(str) ~= "string" then str = str and tostring(str) or "" end
    local function helper(line)
        table.insert(tab, line)
        return ""
    end
    helper((str:gsub("(.-)\r?\n", helper)))
end

--- Convert a string to an array of lines.
function GSE.SplitMeIntoLines(str)
    --GSE.PrintDebugMessage("Entering GSTRSplitMeIntoLines with : \n" .. str, GNOME)
    local t = {}
    if type(str) ~= "string" then
        if str == nil then return t end
        str = tostring(str)
    end
    local function helper(line)
        table.insert(t, line)
        --@debug@
        GSE.PrintDebugMessage("Line : " .. line, Statics.GSEString)
        --@end-debug@
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
    --@debug@
    GSE.PrintDebugMessage(slen, "Storage")
    --@end-debug@
    for i = 1, slen, 1 do
        if string.sub(str, i, i) == "[" then
            modblock = true
            --@debug@
            GSE.PrintDebugMessage("in mod at " .. i, "Storage")
            --@end-debug@
        elseif string.sub(str, i, i) == "]" then
            modblock = false
            --@debug@
            GSE.PrintDebugMessage("leaving mod at " .. i, "Storage")
            --@end-debug@
        elseif string.sub(str, i, i) == "," and not modblock then
            table.insert(tab, string.sub(str, start, i - 1))
            start = i + 1
            --@debug@
            GSE.PrintDebugMessage("found terminator at " .. i, "Storage")
            --@end-debug@
        end
    end
    table.insert(tab, string.sub(str, start))
    return tab
end

function GSE.FixQuotes(source)
    source = string.gsub(source, "%‘", "'")
    source = string.gsub(source, "%’", "'")
    source = string.gsub(source, "%”", '"')
    return source
end

function GSE.CleanStrings(source)
    for _, v in pairs(Statics.CleanStrings) do
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
    for k, v in ipairs(tabl) do
        local tempval = GSE.CleanStrings(v)
        if tempval == [[""]] then
            tabl[k] = nil
        else
            tabl[k] = tempval
        end
    end
    return tabl
end

--- This function removes any hidden characters from a string.
function GSE.StripControlandExtendedCodes(str)
    local s = ""
    for i = 1, str:len() do
        if str:byte(i) >= 32 and str:byte(i) <= 126 then -- Space through to normal EN character
            s = s .. str:sub(i, i)
        elseif str:byte(i) == 194 and str:byte(i + 1) == 160 then -- Fix for IE/Edge
            s = s .. " "
        elseif str:byte(i) == 160 and str:byte(i - 1) == 194 then -- Fix for IE/Edge
            s = s .. " "
        elseif str:byte(i) == 10 then -- Leave line breaks Unix style
            s = s .. str:sub(i, i)
        elseif str:byte(i) == 13 then -- Leave line breaks Windows style
            s = s .. str:sub(i, str:byte(10))
        elseif str:byte(i) >= 128 then -- Extended characters including accented characters for international languages
            s = s .. str:sub(i, i)
        else -- Convert everything else to whitespace
            s = s .. " "
        end
    end
    return s
end

--- Remove the whitespace from the end of a string
function GSE.TrimWhiteSpace(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

--- Dump a table out to a string representation.
function GSE.Dump(node)
    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    if GSE.isEmpty(node) then
        output_str = "nil"
    end
    while true do
        local size = 0
        if type(node) == "table" then
            for _, _ in pairs(node) do
                size = size + 1
            end

            local cur_index = 1
            for k, v in pairs(node) do
                if (cache[node] == nil) or (cur_index >= cache[node]) then
                    if (string.find(output_str, "}", output_str:len())) then
                        output_str = output_str .. ",\n"
                    elseif not (string.find(output_str, "\n", output_str:len())) then
                        output_str = output_str .. "\n"
                    end

                    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                    table.insert(output, output_str)
                    output_str = ""

                    local key
                    if (type(k) == "number" or type(k) == "boolean") then
                        key = "[" .. tostring(k) .. "]"
                    else
                        key = '["' .. tostring(k) .. '"]'
                    end

                    if (type(v) == "number" or type(v) == "boolean") then
                        output_str = output_str .. string.rep("\t", depth) .. key .. " = " .. tostring(v)
                    elseif (type(v) == "table") then
                        output_str = output_str .. string.rep("\t", depth) .. key .. " = {\n"
                        table.insert(stack, node)
                        table.insert(stack, v)
                        cache[node] = cur_index + 1
                        break
                    else
                        if #GSE.SplitMeIntoLines(v) > 1 then
                            output_str =
                                output_str .. string.rep("\t", depth) .. key .. " = [[\n" .. tostring(v) .. "\n]]"
                        else
                            output_str = output_str .. string.rep("\t", depth) .. key .. ' = "' .. tostring(v) .. '"'
                        end
                    end

                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}"
                    else
                        output_str = output_str .. ","
                    end
                else
                    -- close the table
                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}"
                    end
                end

                cur_index = cur_index + 1
            end
        end
        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str)
    output_str = table.concat(output)
    return output_str
end

--- Return an object from the Global namespace or else return nil
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

--- Check if an object exists in the global space with the specified name. Returns a boolean
function GSE.ObjectExists(name)
    return type(GSE.FindGlobalObject(name)) ~= "nil"
end

--- Get the current time as a 14-digit UTC timestamp string (YYYYMMDDHHMMSS).
-- Sourced from the WoW realm clock via GetServerTime() so timestamps written
-- by characters in different real-world timezones remain lexicographically
-- comparable. The "!" prefix to date() switches to gmtime; without it the
-- format would use the player's client local time and a UTC+10 player editing
-- at 23:00 would produce a "later" stamp than a UTC-5 player editing 5 min
-- later at 09:00 their time, breaking server-side newer-wins resolution of
-- multi-account upload conflicts.
function GSE.GetTimestamp()
    return date("!%Y%m%d%H%M%S", GetServerTime())
end

--- decode a timestamp into a table
function GSE.DecodeTimeStamp(stamp)
    local tab = {}
    tab.year = stamp:sub(1, 4)
    tab.month = stamp:sub(5, 6)
    tab.day = stamp:sub(7, 8)
    tab.hour = stamp:sub(9, 10)
    tab.minute = stamp:sub(11, 12)
    tab.sec = stamp:sub(13, 14)
    return tab
end

--- Check is the value is present and if it is actually a number.
function GSE.isNaN(v)
    return type(v) ~= "number" or GSE.isEmpty(v)
end

function GSE.ConcatIndexed(tab, template)
    template = template or "%d %s\n"
    local tt = {}
    for k, v in ipairs(tab) do
        tt[#tt + 1] = template:format(k, v)
    end
    return table.concat(tt)
end

function GSE.TableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

function GSE.pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0 -- Iterator variable
    local iter = function()
        -- Iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function GSE.TableDiff(t1, t2)
    local diff = {}
    local bool = false
    for i, v in pairs(t1) do
        if t2 and type(v) == "table" then
            local deep_diff = GSE.TableDiff(t1[i], t2[i])
            if deep_diff then
                diff[i] = deep_diff
                bool = true
            end
        elseif t2 then
            if t1[i] ~= t2[i] then
                diff[i] = t1[i] .. " -- not [" .. t2[i] .. "]"
                bool = true
            end
        else
            diff[i] = t1[i]
            bool = true
        end
    end

    if bool then
        return diff
    end
end

--- Remove the comments from a GSE Variable before attempting to execute it
function GSE.RemoveComments(str)
    if GSE.isEmpty(str) then
        return str
    end
    local tab = str
    if type(str) ~= "table" then
        tab = GSE.SplitMeIntoLines(str)
    end

    for i = #tab, 1, -1 do
        local teststring = tab[i]
        if GSE.isEmpty(teststring) then
            table.remove(tab, i)
        else
            teststring = GSE.UnEscapeString(GSE.TrimWhiteSpace(teststring))
            teststring = teststring:gsub("^%s*", "")
            if string.sub(teststring, 1, 2) == "--" then
                table.remove(tab, i)
            end
        end
    end

    return table.concat(tab, "\n")
end

function GSE.GUIGetColour(option)
    -- hex = string.gsub(option, "#","")
    return tonumber("0x" .. string.sub(option, 5, 6)) / 255, tonumber("0x" .. string.sub(option, 7, 8)) / 255, tonumber(
        "0x" .. string.sub(option, 9, 10)
    ) / 255
end


function GSE.GetMacroStringFormat()
    local CVarValue = C_CVar.GetCVar("ActionButtonUseKeyDown") and "DOWN" or "UP"
    local state = GSEOptions.CvarActionButtonState and GSEOptions.CvarActionButtonState or CVarValue
    return state
end

function GSE.SafeConcat(tab, delimiter)
    local output = ""
    for k, v in pairs(tab) do
        if type(k) == "number" then
            if k > 1 then
                output = output .. delimiter .. v
            else
                output = v
            end
        end
    end
    return output
end

function GSE.NewTable()
    return {}
end

function GSE.FlattenTable(v)
    local res = {}
    local function flatten(v)
        if v.type then
            table.insert(res, v)
            return
        end
        if v.Interval then
            table.insert(res, v)
            return
        end
        for _, v2 in ipairs(v) do
            flatten(v2)
        end
    end
    flatten(v)
    return res
end

function GSE.AlphabeticalTableSortAlgorithm(a, b)
    local function padnum(d)
        local dec, n = string.match(d, "(%.?)0*(.+)")
        return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n)
    end
    return tostring(a):gsub("%.?%d+", padnum) .. ("%3d"):format(#b) <
        tostring(b):gsub("%.?%d+", padnum) .. ("%3d"):format(#a)
end

function GSE.SortTableAlphabetical(o)
    table.sort(o, GSE.AlphabeticalTableSortAlgorithm)
    return o
end

function GSE.CountTableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

GSE.DebugProfile("StringFunctions")

local GSE = GSE
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
    for k, v in pairs(Statics.StringFormatEscapes) do
        str = string.gsub(str, k, v)
    end
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
    --GSE.PrintDebugMessage("Entering GSTRSplitMeIntolines with : \n" .. str, GNOME)
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
    GSE.PrintDebugMessage(slen, "Storage")
    for i = 1, slen, 1 do
        if string.sub(str, i, i) == "[" then
            modblock = true
            GSE.PrintDebugMessage("in mod at " .. i, "Storage")
        elseif string.sub(str, i, i) == "]" then
            modblock = false
            GSE.PrintDebugMessage("leaving mod at " .. i, "Storage")
        elseif string.sub(str, i, i) == "," and not modblock then
            table.insert(tab, string.sub(str, start, i - 1))
            start = i + 1
            GSE.PrintDebugMessage("found terminator at " .. i, "Storage")
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

function GSE.TrimWhiteSpace(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function GSE.Dump(node)
    --     local s = '{ \n'
    --     for k, v in pairs(node) do
    --         if type(k) ~= 'number' then
    --             k = '"' .. k .. '"'
    --         end
    --         s = s .. '[' .. k .. '] = '
    --         if GSE.isEmpty(v) then
    --             s = s .. '"",\n'
    --         elseif type(v) == 'string' then
    --             s = s .. '[[' .. GSE.Dump(v) .. ']],\n'
    --         else
    --             s = s .. GSE.Dump(v) .. ',\n'
    --         end
    --     end
    --     return s .. '} '
    -- else
    --     return GSE.TranslateString(tostring(o) , "STRING", true)
    -- end

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
                        output_str = output_str .. string.rep("\t", depth) .. key .. ' = "' .. tostring(v) .. '"'
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
    return type(GSE.FindGlobalObject(name)) ~= "nil"
end

function GSE.GetTimestamp()
    return date("%Y%m%d%H%M%S")
end

function GSE.DecodeTimeStamp(stamp)
    local tab = {}
    tab.year = stamp:sub(1, 4)
    tab.month = stamp:sub(5, 2)
    tab.day = stamp:sub(7, 2)
    tab.hour = stamp:sub(9, 2)
    tab.hour = stamp:sub(11, 2)
    tab.sec = stamp:sub(13, 2)
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

-- local tab1 = { "abcd", "edge"}
-- local tab2 = { "abcd", "ed"}
-- GSE.Print(GSE.Dump(GSE.TableDiff(tab1, tab2)))

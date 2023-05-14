local GSE = GSE
local Statics = GSE.Static

local GNOME = Statics.DebugModules["Translator"]

local L = GSE.L

--- GSE.TranslateSequence will translate from local spell name to spell id and back again.\
-- Mode of "STRING" will return local names where mode "ID" will return id's
-- dropAbsolute will remove "$$" from the start of lines.
function GSE.TranslateSequence(tab, mode, dropAbsolute)
    GSE.PrintDebugMessage("GSE.TranslateSequence  Mode: " .. mode, GNOME)
    for k, v in ipairs(tab) do
        -- Translate Sequence
        if type(v) == "table" then
            tab[k] = GSE.TranslateSequence(v, mode, dropAbsolute)
        else
            local translation = GSE.TranslateString(v, mode, nil, dropAbsolute)
            tab[k] = translation
        end
    end

    -- Check for blanks
    for i, v in ipairs(tab) do
        if GSE.isEmpty(v) or v == "" then
            tab[i] = nil
        end
    end
    return tab
end

function GSE.ProcessLoopVariables(action, id)
    local temp = GSE.ProcessVariables(GSE.SplitMeIntolines(action), {["LID"] = id})
    return table.concat(temp, "\n")
end

--- This function interates through each line in lines and does a string replace on each varible in the variableTable
function GSE.ProcessVariables(lines, variableTable)
    --print("GSE.ProcessVariables(lines, variableTable)")
    local returnLines = {}
    --print(GSE.isEmpty(variableTable))
    for _, line in ipairs(lines) do
        if line ~= "/click GSE.Pause" then
            if not GSE.isEmpty(variableTable) then
                for key, value in pairs(variableTable) do
                    if type(value) == "string" then
                        local functline = value
                        if string.sub(functline, 1, 10) == "function()" then
                            functline = string.sub(functline, 11)
                            functline = functline:sub(1, -4)
                            local funct = loadstring(functline)
                            --print(type(functline))
                            if funct ~= nil then
                                value = funct
                            end
                        end
                    end
                    --print("updated Type: ".. type(value))
                    --print(value)
                    if type(value) == "function" then
                        value = value()
                    end
                    if type(value) == "boolean" then
                        value = tostring(value)
                    end
                    line = string.gsub(line, string.format("~~%s~~", key), value)
                end
            end

            for key, value in pairs(Statics.SystemVariables) do
                if type(value) == "function" then
                    value = value()
                end
                local oldline = line
                line = string.gsub(line, string.format("~~%s~~", key), value)
            end
        end
        table.insert(returnLines, line)
    end
    return returnLines
end

function GSE.TranslateString(instring, mode, cleanNewLines, dropAbsolute)
    instring = GSE.UnEscapeString(instring)
    GSE.PrintDebugMessage("Entering GSE.TranslateString with : \n" .. instring .. "\n " .. mode, GNOME)
    local output = ""
    if not GSE.isEmpty(instring) then
        local absolute = false
        if instring:find("$$", 1, true) then
            GSE.PrintDebugMessage("Setting Absolute", GNOME)
            absolute = true
            output = string.gsub(instring, "%$%$", "")
        elseif GSE.isEmpty(string.find(instring, "--", 1, true)) then
            for cmd, etc in string.gmatch(instring or "", "/(%w+)%s+([^\n]+)") do
                GSE.PrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
                output = output .. GSEOptions.WOWSHORTCUTS .. "/" .. cmd .. Statics.StringReset .. " "
                if string.lower(cmd) == "use" then
                    local conditionals, mods, trinketstuff = GSE.GetConditionalsFromString(etc)
                    if conditionals then
                        output = output .. mods .. " "
                        GSE.PrintDebugMessage("GSE.TranslateSpell conditionals found ", GNOME)
                    end
                    GSE.PrintDebugMessage("output: " .. output .. " mods: " .. mods .. " etc: " .. etc, GNOME)

                    output = output .. GSEOptions.KEYWORD .. trinketstuff .. Statics.StringReset
                elseif Statics.CastCmds[string.lower(cmd)] then
                    -- Check for cast Sequences
                    if not cleanNewLines then
                        etc = string.match(etc, "^%s*(.-)%s*$")
                    end
                    if string.sub(etc, 1, 1) == "!" then
                        etc = string.sub(etc, 2)
                        output = output .. "!"
                    end
                    local foundspell, returnval =
                        GSE.TranslateSpell(etc, mode, (cleanNewLines and cleanNewLines or false), absolute)
                    if foundspell then
                        output = output .. GSEOptions.KEYWORD .. returnval .. Statics.StringReset
                    else
                        GSE.PrintDebugMessage("Did not find : " .. etc, GNOME)
                        output = output .. etc
                    end
                elseif string.lower(cmd) == "castsequence" then
                    GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
                    for _, y in ipairs(GSE.split(etc, ";")) do
                        for _, w in ipairs(GSE.SplitCastSequence(y, ",")) do
                            -- Look for conditionals at the startattack
                            local conditionals, mods, uetc = GSE.GetConditionalsFromString(w)
                            if conditionals then
                                output = output .. GSEOptions.STANDARDFUNCS .. mods .. Statics.StringReset .. " "
                            end

                            uetc = uetc:gsub("^%s*", "")
                            if string.sub(uetc, 1, 1) == "!" then
                                uetc = string.sub(uetc, 2)
                                output = output .. "!"
                            end
                            local foundspell, returnval =
                                GSE.TranslateSpell(uetc, mode, (cleanNewLines and cleanNewLines or false), absolute)
                            output = output .. GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. ", "
                        end
                        output = output .. ";"
                    end
                    output = string.sub(output, 1, string.len(output) - 1)
                    local resetleft = string.find(output, ", , ")
                    if not GSE.isEmpty(resetleft) then
                        output = string.sub(output, 1, resetleft - 1)
                    end
                    if string.sub(output, string.len(output) - 1) == ", " then
                        output = string.sub(output, 1, string.len(output) - 2)
                    end
                elseif string.lower(cmd) == "click" then
                    local trimRight = string.find(etc, " LeftButton")
                    if not GSE.isEmpty(trimRight) then
                        etc = string.sub(etc, 1, trimRight - 1)
                    end
                    if mode == Statics.TranslatorMode.String then
                        if tonumber(GetCVar("ActionButtonUseKeyDown")) == 1 then
                            etc = etc .. " LeftButton t"
                        end
                    end
                    output = output .. " " .. etc
                else
                    -- Pass it through
                    output = output .. " " .. etc
                end
            end
            -- look for single line commands and mark them up
            for _, v in ipairs(Statics.MacroCommands) do
                output = string.gsub(output, "/" .. v, GSEOptions.WOWSHORTCUTS .. "/" .. v .. Statics.StringReset)
            end
        else
            GSE.PrintDebugMessage("Detected Comment " .. string.find(instring, "--", 1, true), GNOME)
            output = output .. GSEOptions.CONCAT .. instring .. Statics.StringReset
        end
        -- If nothing was found, pass through
        if output == "" then
            output = instring
            -- look for single line commands and mark them up
            for _, v in ipairs(Statics.MacroCommands) do
                output = string.gsub(output, "/" .. v, GSEOptions.WOWSHORTCUTS .. "/" .. v .. Statics.StringReset)
            end
        end

        if GSE.isEmpty(dropAbsolute) then
            dropAbsolute = false
        end
        if absolute and not dropAbsolute then
            output = "$$" .. output
        end
    elseif cleanNewLines then
        output = output .. instring
    end
    GSE.PrintDebugMessage("Exiting GSE.TranslateString with : \n" .. output, GNOME)
    -- Check for random "," at the end
    if string.sub(output, string.len(output) - 1) == ", " then
        output = string.sub(output, 1, string.len(output) - 2)
    end
    output = string.gsub(output, ", ;", "; ")

    output = string.gsub(output, "  ", " ")
    return output
end

function GSE.TranslateSpell(str, mode, cleanNewLines, absolute)
    local output = ""
    local found = false
    -- Check for cases like /cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar
    if not cleanNewLines then
        str = string.match(str, "^%s*(.-)%s*$")
    end
    GSE.PrintDebugMessage("GSE.TranslateSpell Attempting to translate " .. str, GNOME)
    if string.sub(str, string.len(str)) == "," then
        str = string.sub(str, 1, string.len(str) - 1)
    end
    if string.match(str, ";") then
        GSE.PrintDebugMessage("GSE.TranslateSpell found ; in " .. str .. " about to do recursive call.", GNOME)
        for _, w in ipairs(GSE.split(str, ";")) do
            local returnval
            found, returnval =
                GSE.TranslateSpell(
                (cleanNewLines and w or string.match(w, "^%s*(.-)%s*$")),
                mode,
                (cleanNewLines and cleanNewLines or false)
            )
            output = output .. GSEOptions.KEYWORD .. returnval .. Statics.StringReset .. "; "
        end
        if string.sub(output, string.len(output) - 1) == "; " then
            output = string.sub(output, 1, string.len(output) - 2)
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
        if mode == Statics.TranslatorMode.Current then
            if GSEOptions.showCurrentSpells then
                local test = tonumber(etc)
                if test then
                    local currentSpell = FindSpellOverrideByID(test)
                    if currentSpell then
                        etc = currentSpell
                    end
                end
            end
        end
        local foundspell = GSE.GetSpellId(etc, mode, absolute)

        -- print("Foudn Spell: " .. foundspell .. " etc:" .. etc .. " mode:" .. mode .. " str:" .. str)

        if foundspell then
            GSE.PrintDebugMessage("Translating Spell ID : " .. etc .. " to " .. foundspell, GNOME)
            output = output .. GSEOptions.KEYWORD .. foundspell .. Statics.StringReset
            found = true
        else
            GSE.PrintDebugMessage("Did not find : " .. etc .. ".  Spell may no longer exist", GNOME)
            output = output .. GSEOptions.UNKNOWN .. etc .. Statics.StringReset
        end
    end
    return found, output
end

function GSE.GetConditionalsFromString(str)
    GSE.PrintDebugMessage("Entering GSE.GetConditionalsFromString with : " .. str, GNOME)
    -- Check for conditionals
    local found = false
    local mods = ""
    local leftstr
    local rightstr
    local leftfound = false
    for i = 1, #str do
        local c = str:sub(i, i)
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
    -- if not cleanNewLines then
    --     str = string.match(str, "^%s*(.-)%s*$")
    -- end
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
            local c = str:sub(i, i)
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

local function ClassicGetSpellInfo(spellID, absolute, mode)
    local name, rank, icon, castTime, minRange, maxRange, sid = GetSpellInfo(spellID)
    -- only check rank if classic.
    if GSE.GameMode <= 3 then
        -- print("Did rank check found: " .. (rank or "No Rank"))
        if GSE.isEmpty(rank) then
            if GSE.GetCurrentClassID() ~= 1 and GSE.GetCurrentClassID() ~= 4 then
                if
                    pcall(
                        function()
                            tonumber(spellID)
                        end
                    )
                 then
                    rank = GetSpellSubtext(spellID)
                end
            else
                rank = nil
            end
        end
    else
        -- Do override check.
        if not absolute and not GSE.isEmpty(sid) and mode ~= Statics.TranslatorMode.Current then
            local returnval = sid
            if FindBaseSpellByID(returnval) then
                returnval = FindBaseSpellByID(returnval)
            end
            -- Still need Heart of Azeroth overrides.
            if not GSE.isEmpty(Statics.BaseSpellTable[returnval]) then
                returnval = Statics.BaseSpellTable[returnval]
            end
            name, rank, icon, castTime, minRange, maxRange, sid = GetSpellInfo(returnval)
        end
    end
    -- allows for a trinket to be part of a castsequence.
    if tostring(spellID) == "13" or tostring(spellID) == "14" then
        name = tostring(spellID)
        sid = tonumber(spellID)
    end
    return name, rank, icon, castTime, minRange, maxRange, sid
end

--- Test override of GetSpellInfo
function GSE.ClassicGetSpellInfo(spellID, mode)
    return ClassicGetSpellInfo(spellID, mode)
end

--- Converts a string spell name to an id and back again.
function GSE.GetSpellId(spellstring, mode, absolute)
    if GSE.isEmpty(mode) then
        mode = Statics.TranslatorMode.ID
    end
    if GSE.isEmpty(GSESpellCache) then
        GSESpellCache = {
            ["enUS"] = {}
        }
    end

    if GSE.isEmpty(GSESpellCache[GetLocale()]) then
        GSESpellCache[GetLocale()] = {}
    end
    local returnval
    local name, rank, icon, castTime, minRange, maxRange, spellId = ClassicGetSpellInfo(spellstring, absolute, mode)
    if mode ~= Statics.TranslatorMode.ID then
        if not GSE.isEmpty(rank) then
            returnval = name .. "(" .. rank .. ")"
        else
            returnval = name
        end
    else
        returnval = spellId
        if GSE.GameMode > 2 then
            -- If we are not in classic
            -- Check for overrides like Crusade and Avenging Wrath.
            if not absolute and not GSE.isEmpty(returnval) then
                if FindBaseSpellByID(returnval) then
                    returnval = FindBaseSpellByID(returnval)
                end
                -- Still need Heart of Azeroth overrides.
                if not GSE.isEmpty(Statics.BaseSpellTable[returnval]) then
                    returnval = Statics.BaseSpellTable[returnval]
                end
            end
        end
    end
    if not GSE.isEmpty(returnval) then
        if mode == Statics.TranslatorMode.ID and tonumber(spellstring) == nil then
            if
                GSE.isEmpty(GSESpellCache[GetLocale()][spellstring]) == true or
                    GSESpellCache[GetLocale()][spellstring] ~= returnval
             then
                GSESpellCache[GetLocale()][spellstring] = returnval
            end
        end
        GSE.PrintDebugMessage(
            "Converted " .. spellstring .. " to " .. returnval .. " using mode " .. mode,
            "Translator"
        )
    else
        if not GSE.isEmpty(spellstring) then
            GSE.PrintDebugMessage(spellstring .. " was not found", "Translator")
            if not GSE.isEmpty(GSESpellCache[GetLocale()][spellstring]) then
                returnval = GSESpellCache[GetLocale()][spellstring]
            end
            if GSE.isEmpty(returnval) then
                -- hail mary - try the enUS cache
                if not GSE.isEmpty(GSESpellCache["enUS"][spellstring]) then
                    returnval = GSESpellCache["enUS"][spellstring]
                end
            end
        else
            GSE.PrintDebugMessage("Nothing was there to be found", "Translator")
        end
    end
    -- print("returning " .. returnval .. " from " .. spellstring)
    return returnval
end

--- Takes a section of a sequence and returns the spells used.
function GSE.IdentifySpells(tab)
    local foundspells = {}
    local returnval = ""
    for _, p in ipairs(tab) do
        -- Run a regex to find all spell id's from the table and add them to the table foundspells
        for m in string.gmatch(p, "%w%d+") do
            foundspells[m] = 1
        end
    end

    for k, _ in pairs(foundspells) do
        if not GSE.isEmpty(GSE.GetSpellId(k, Statics.TranslatorMode.Current, false)) then
            local wowheaddata = "spell=" .. k
            -- local domain = "www"
            if GSE.GameMode == 1 then
                --domain = "classic"
                wowheaddata = wowheaddata .. "?domain=classic"
            elseif GSE.GameMode == 2 then
                wowheaddata = wowheaddata .. "?domain=classic"
            --domain = "tbc"
            end
            returnval =
                returnval ..
                '<a href="http://www.wowhead.com/spell=' ..
                    k ..
                        '" data-wowhead="' ..
                            wowheaddata .. '">' .. GSE.GetSpellId(k, Statics.TranslatorMode.Current, false) .. "</a>, "
        end
    end

    return string.sub(returnval, 1, string.len(returnval) - 2), foundspells
end

GSE.TranslatorAvailable = true

GSE.DebugProfile("Translator")

local GSE = GSE
local Statics = GSE.Static

local GNOME = Statics.DebugModules["Translator"]

local L = GSE.L

local function normaliseSpellIDValue(value)
    if type(value) == "table" then
        value = value.spellID or value.id
    end
    return tonumber(value) or value
end

local function findBaseSpellID(spellID)
    spellID = normaliseSpellIDValue(spellID)
    if not spellID then return nil end

    local FindBaseSpellByID = (C_SpellBook and C_SpellBook.FindBaseSpellByID) or FindBaseSpellByID
    if FindBaseSpellByID then
        local ok, baseSpell = pcall(FindBaseSpellByID, spellID)
        baseSpell = ok and normaliseSpellIDValue(baseSpell) or nil
        if baseSpell and baseSpell ~= 0 then
            return baseSpell
        end
    end

    if not GSE.isEmpty(Statics.BaseSpellTable[spellID]) then
        return Statics.BaseSpellTable[spellID]
    end

    return spellID
end

local function findCurrentSpellID(spellID)
    spellID = normaliseSpellIDValue(spellID)
    if not spellID then return nil end

    local FindSpellOverrideByID = (C_SpellBook and C_SpellBook.FindSpellOverrideByID) or FindSpellOverrideByID
    if FindSpellOverrideByID then
        local ok, currentSpell = pcall(FindSpellOverrideByID, spellID)
        currentSpell = ok and normaliseSpellIDValue(currentSpell) or nil
        if currentSpell and currentSpell ~= 0 then
            return currentSpell
        end
    end

    return spellID
end

local function getSpellInfoID(spell)
    if GSE.isEmpty(spell) or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    local ok, spellinfo = pcall(C_Spell.GetSpellInfo, spell)
    if ok and spellinfo then
        return normaliseSpellIDValue(spellinfo.spellID)
    end
end

local function spellIDIsInSpellBook(spellID)
    if not C_SpellBook or not C_SpellBook.FindSpellBookSlotForSpell then
        return true
    end

    local ok, slot = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID)
    return ok and slot and slot > 0
end

local function canCacheSpellLookup(spellstring, spellID, rawSpellID)
    if tonumber(spellstring) ~= nil or GSE.isEmpty(spellID) then
        return false
    end

    if rawSpellID and rawSpellID ~= spellID then
        return true
    end

    return spellIDIsInSpellBook(spellID)
end

function GSE.GetBaseSpellID(spell)
    local spellID = tonumber(spell) or getSpellInfoID(spell)
    return findBaseSpellID(spellID)
end

function GSE.GetCurrentSpellID(spell)
    local baseSpell = GSE.GetBaseSpellID(spell)
    return findCurrentSpellID(baseSpell)
end

function GSE.SanitizeSpellCache()
    if GSE.isEmpty(GSESpellCache) then return end

    for _, cache in pairs(GSESpellCache) do
        if type(cache) == "table" then
            for spellName, spellID in pairs(cache) do
                local baseSpell = findBaseSpellID(spellID)
                if baseSpell and baseSpell ~= spellID then
                    cache[spellName] = baseSpell
                end
            end
        end
    end
end

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
            table.remove(tab, i)
        end
    end
    return tab
end

function GSE.TranslateString(instring, mode, cleanNewLines, dropAbsolute)
    instring = GSE.UnEscapeString(instring)
    local lines = GSE.SplitMeIntoLines(instring)
    if #lines > 1 then
        local output = {}
        for k, v in ipairs(lines) do
            output[k] = GSE.TranslateString(v, mode, cleanNewLines, dropAbsolute)
        end
        return table.concat(output, "\n")
    else
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
                        if tonumber(trinketstuff) and tonumber(trinketstuff) < 17 then
                            output = output .. GSEOptions.KEYWORD .. trinketstuff .. Statics.StringReset
                        else
                            if not cleanNewLines then
                                trinketstuff = string.match(trinketstuff, "^%s*(.-)%s*$")
                            end
                            if string.sub(trinketstuff, 1, 1) == "!" then
                                trinketstuff = string.sub(trinketstuff, 2)
                                output = output .. "!"
                            end
                            local foundspell, returnval =
                                GSE.TranslateSpell(trinketstuff, mode, (cleanNewLines and cleanNewLines or false), true)
                            if foundspell then
                                output = output .. returnval
                            else
                                GSE.PrintDebugMessage("Did not find : " .. trinketstuff, GNOME)
                                output = output .. trinketstuff
                            end
                        end
                    elseif string.lower(cmd) == "castsequence" then
                        GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
                        for _, y in ipairs(GSE.split(etc, ";")) do
                            for _, w in ipairs(GSE.SplitCastSequence(y)) do
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
                                output = output .. returnval .. ", "
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
                            output = output .. returnval
                        else
                            GSE.PrintDebugMessage("Did not find : " .. etc, GNOME)
                            output = output .. etc
                        end
                    else
                        -- Pass it through
                        output = output .. " " .. etc
                    end
                end
                -- look for single line commands and mark them up
                for _, v in ipairs(Statics.MacroCommands) do
                    output =
                        string.gsub(
                        output,
                        "/" .. v .. " ",
                        GSEOptions.WOWSHORTCUTS .. "/" .. v .. " " .. Statics.StringReset
                    )
                end
            else
                GSE.PrintDebugMessage("Detected Comment " .. string.find(instring, "--", 1, true), GNOME)
                output = output .. GSEOptions.CONCAT .. instring .. Statics.StringReset
            end
            -- If nothing was found, pass through
            if GSE.isEmpty(output) then
                output = instring
                -- look for single line commands and mark them up
                for _, v in ipairs(Statics.MacroCommands) do
                    output =
                        string.gsub(
                        output,
                        "/" .. v .. " ",
                        GSEOptions.WOWSHORTCUTS .. "/" .. v .. " " .. Statics.StringReset
                    )
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

        output = string.gsub(output, "%s+", " ")
        return output
    end
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
                    local currentSpell = GSE.GetCurrentSpellID(test)
                    if currentSpell and currentSpell ~= test then
                        ---@diagnostic disable-next-line: cast-local-type
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

--- Converts a string spell name to an id and back again.
function GSE.GetSpellId(spellstring, mode, absolute)
    if GSE.isEmpty(mode) then
        mode = Statics.TranslatorMode.ID
    end
    -- C_Spell.GetSpellInfo errors on nil / non-string-non-number input.
    -- CreateSpellEditBox calls us with action.spell, which is nil for a
    -- freshly-added Spell action the user hasn't filled in yet.
    if GSE.isEmpty(spellstring) then
        return nil
    end
    if type(spellstring) ~= "string" and type(spellstring) ~= "number" then
        return nil
    end
    if GSE.isEmpty(GSESpellCache) then
        GSESpellCache = {
            ["enUS"] = {}
        }
    end

    if GSE.isEmpty(GSESpellCache[GetLocale()]) then
        GSESpellCache[GetLocale()] = {}
    end
    local returnval, name, rank, spellId, rawSpellId

    local ok, spellinfo = pcall(C_Spell.GetSpellInfo, spellstring)
    if not ok then spellinfo = nil end
    if not spellinfo then
        if type(spellstring) == "string" then
            ---@diagnostic disable-next-line: missing-fields
            spellinfo = {}
            spellinfo.name = spellstring
            if GSESpellCache[GetLocale()][spellstring] then
                spellinfo.spellID = GSESpellCache[GetLocale()][spellstring]
            end
        else
            -- Numeric spell ID that the client doesn't know about: nothing
            -- meaningful to return. Bail rather than indexing nil below.
            return nil
        end
    end
    rank = spellinfo.rank and spellinfo.rank or nil
    rawSpellId = normaliseSpellIDValue(spellinfo.spellID)
    spellId = rawSpellId
    name = spellinfo.name
    if mode ~= Statics.TranslatorMode.ID then
        if not GSE.isEmpty(rank) then
            returnval = name .. "(" .. rank .. ")"
        else
            returnval = name
        end
    else
        returnval = spellId
        -- Check for overrides like Crusade and Avenging Wrath.
        if not absolute and not GSE.isEmpty(returnval) then
            returnval = findBaseSpellID(returnval)
        end
    end
    if not GSE.isEmpty(returnval) then
        if mode == Statics.TranslatorMode.ID and tonumber(spellstring) == nil then
            local existingCache = GSESpellCache[GetLocale()][spellstring]
            if canCacheSpellLookup(spellstring, returnval, rawSpellId) then
                if GSE.isEmpty(existingCache) == true or existingCache ~= returnval then
                    GSESpellCache[GetLocale()][spellstring] = returnval
                end
            elseif not GSE.isEmpty(existingCache) then
                returnval = existingCache
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

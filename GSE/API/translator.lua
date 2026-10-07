local _, GSE = ...
local Statics = GSE.Static

local GNOME = Statics.DebugModules["Translator"]

-- The character's known spell ranks (see "Spell ranks" below). Built on first
-- use and dropped with the translate cache, which SPELLS_CHANGED already clears
-- via GSE.ReloadSequences -- so learning a rank rebuilds it.
local rankIndex
-- The ranked casts of the block being translated (GSE.WithSpellRanks), and a
-- key for them: the same text translates differently under different blocks.
local activeRanks, activeRanksKey = nil, ""
-- Spell IDs whose rank text was asked of the client and has not arrived yet.
local pendingRankData = {}


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
    if GSE.isEmpty(spell) then
        return nil
    end

    local spellinfo = GSE.GetSpellInfo(spell)
    if spellinfo then
        return normaliseSpellIDValue(spellinfo.spellID)
    end
end

local function spellIDIsInSpellBook(spellID)
    -- TBC Classic Anniversary + MoP Classic expose C_SpellBook but not
    -- FindSpellBookSlotForSpell (Retail-only). The unguarded call there
    -- threw `attempt to call a nil value` every CompileMacroText pass —
    -- ~179 spam errors per Notes save in issue #1925. Mirror the
    -- defensive pattern used by findBaseSpellID / findCurrentSpellID
    -- above: prefer C_SpellBook.X, fall back to the legacy top-level
    -- global, and default to true ("treat as in book") when neither
    -- exists. That matches the nil-slot path on Retail, where an
    -- unresolved slot is also reported as in-book by this function.
    local FindSlot = (C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell)
        or FindSpellBookSlotForSpell
    if not FindSlot then
        return true
    end
    local slot = FindSlot(spellID)
    return slot == nil or slot > 0
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

--- Record a locale spell NAME -> spell ID pair in the shared cache.
--
-- This cache is not a lookup shortcut. It is the only way GSE can resolve a
-- spell name written in another client's language: Blizzard's API translates
-- solely between the RUNNING client's locale and IDs, so hand an enUS client a
-- deDE spell name and there is nothing to ask it. A deDE player's cache,
-- broadcast to the group on join (GSE.SendSpellCache), is what lets an enUS
-- player run a sequence written in German. Every pair a client can learn is
-- therefore worth keeping, whichever direction the lookup was asked in.
local function rememberSpellName(spellName, spellID)
    if GSE.isEmpty(spellName) or GSE.isEmpty(spellID) then
        return
    end
    -- The KEY must be a name. A numeric key would be indistinguishable from an
    -- ID to every consumer of this table.
    if tonumber(spellName) ~= nil then
        return
    end
    local baseID = findBaseSpellID(spellID) or spellID
    if not canCacheSpellLookup(spellName, baseID, spellID) then
        return
    end
    local cache = GSESpellCache and GSESpellCache[GetLocale()]
    if type(cache) ~= "table" then
        return
    end
    -- Store the BASE id, matching what GSE.SanitizeSpellCache normalises the
    -- table to on every login.
    if cache[spellName] ~= baseID then
        cache[spellName] = baseID
    end
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
    --@debug@
    GSE.PrintDebugMessage("GSE.TranslateSequence  Mode: " .. mode, GNOME)
    --@end-debug@
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

local function translateStringUncached(instring, mode, cleanNewLines, dropAbsolute)
    instring = GSE.UnEscapeString(instring)
    if type(instring) ~= "string" then return instring and tostring(instring) or "" end
    local lines = GSE.SplitMeIntoLines(instring)
    if #lines > 1 then
        local output = {}
        for k, v in ipairs(lines) do
            output[k] = GSE.TranslateString(v, mode, cleanNewLines, dropAbsolute)
        end
        return table.concat(output, "\n")
    else
        --@debug@
        GSE.PrintDebugMessage("Entering GSE.TranslateString with : \n" .. instring .. "\n " .. mode, GNOME)
        --@end-debug@
        local output = ""
        if not GSE.isEmpty(instring) then
            local absolute = false
            if instring:find("$$", 1, true) then
                --@debug@
                GSE.PrintDebugMessage("Setting Absolute", GNOME)
                --@end-debug@
                absolute = true
                output = string.gsub(instring, "%$%$", "")
            elseif GSE.isEmpty(string.find(instring, "--", 1, true)) then
                for cmd, etc in string.gmatch(instring or "", "/(%w+)%s+([^\n]+)") do
                    --@debug@
                    GSE.PrintDebugMessage("cmd : \n" .. cmd .. " etc: " .. etc, GNOME)
                    --@end-debug@
                    output = output .. GSEOptions.WOWSHORTCUTS .. "/" .. cmd .. Statics.StringReset .. " "
                    if string.lower(cmd) == "use" then
                        local conditionals, mods, trinketstuff = GSE.GetConditionalsFromString(etc)
                        if conditionals then
                            output = output .. mods .. " "
                            --@debug@
                            GSE.PrintDebugMessage("GSE.TranslateSpell conditionals found ", GNOME)
                            --@end-debug@
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
                                --@debug@
                                GSE.PrintDebugMessage("Did not find : " .. trinketstuff, GNOME)
                                --@end-debug@
                                output = output .. trinketstuff
                            end
                        end
                    elseif string.lower(cmd) == "castsequence" then
                        --@debug@
                        GSE.PrintDebugMessage("attempting to split : " .. etc, GNOME)
                        --@end-debug@
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
                        -- Always emit a bare `/click NAME` (down=false). GSE
                        -- sequence buttons now pin useOnKeyDown=false, so a
                        -- key-DOWN forward (`LeftButton t`) would no longer match
                        -- the executor's cast edge. Bare /click resolves on the
                        -- up edge under both ActionButtonUseKeyDown states.
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
                            --@debug@
                            GSE.PrintDebugMessage("Did not find : " .. etc, GNOME)
                            --@end-debug@
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
                --@debug@
                GSE.PrintDebugMessage("Detected Comment " .. string.find(instring, "--", 1, true), GNOME)
                --@end-debug@
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
        --@debug@
        GSE.PrintDebugMessage("Exiting GSE.TranslateString with : \n" .. output, GNOME)
        --@end-debug@
        -- Check for random "," at the end
        if string.sub(output, string.len(output) - 1) == ", " then
            output = string.sub(output, 1, string.len(output) - 2)
        end
        output = string.gsub(output, ", ;", "; ")

        output = string.gsub(output, "%s+", " ")
        return output
    end
end

local translateCache = {}
function GSE.ClearTranslateStringCache()
    translateCache = {}
    rankIndex = nil
end

function GSE.TranslateString(instring, mode, cleanNewLines, dropAbsolute)
    if type(instring) ~= "string" then
        return translateStringUncached(instring, mode, cleanNewLines, dropAbsolute)
    end
    local key = instring .. "\30" .. tostring(mode) .. "\30" ..
        tostring(cleanNewLines) .. "\30" .. tostring(dropAbsolute) .. "\30" .. activeRanksKey
    local cached = translateCache[key]
    if cached ~= nil then
        return cached
    end
    local result = translateStringUncached(instring, mode, cleanNewLines, dropAbsolute)
    translateCache[key] = result
    return result
end

function GSE.TranslateSpell(str, mode, cleanNewLines, absolute)
    local output = ""
    local found = false
    -- Check for cases like /cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar
    if not cleanNewLines then
        str = string.match(str, "^%s*(.-)%s*$")
    end
    --@debug@
    GSE.PrintDebugMessage("GSE.TranslateSpell Attempting to translate " .. str, GNOME)
    --@end-debug@
    if string.sub(str, string.len(str)) == "," then
        str = string.sub(str, 1, string.len(str) - 1)
    end
    if string.match(str, ";") then
        --@debug@
        GSE.PrintDebugMessage("GSE.TranslateSpell found ; in " .. str .. " about to do recursive call.", GNOME)
        --@end-debug@
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
            --@debug@
            GSE.PrintDebugMessage("GSE.TranslateSpell conditionals found ", GNOME)
            --@end-debug@
        end
        --@debug@
        GSE.PrintDebugMessage("output: " .. output .. " mods: " .. mods .. " etc: " .. etc, GNOME)
        --@end-debug@
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
            --@debug@
            GSE.PrintDebugMessage("Translating Spell ID : " .. etc .. " to " .. foundspell, GNOME)
            --@end-debug@
            output = output .. GSEOptions.KEYWORD .. foundspell .. Statics.StringReset
            found = true
        else
            --@debug@
            GSE.PrintDebugMessage("Did not find : " .. etc .. ".  Spell may no longer exist", GNOME)
            --@end-debug@
            output = output .. GSEOptions.UNKNOWN .. etc .. Statics.StringReset
        end
    end
    return found, output
end

function GSE.GetConditionalsFromString(str)
    --@debug@
    GSE.PrintDebugMessage("Entering GSE.GetConditionalsFromString with : " .. str, GNOME)
    --@end-debug@
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
    --@debug@
    GSE.PrintDebugMessage("checking left : " .. (leftstr and leftstr or "nope"), GNOME)
    --@end-debug@
    --@debug@
    GSE.PrintDebugMessage("checking right : " .. (rightstr and rightstr or "nope"), GNOME)
    --@end-debug@
    if rightstr and leftstr then
        found = true
        --@debug@
        GSE.PrintDebugMessage("We have left and right stuff", GNOME)
        --@end-debug@
        mods = string.sub(str, leftstr, rightstr)
        --@debug@
        GSE.PrintDebugMessage("mods changed to: " .. mods, GNOME)
        --@end-debug@
        str = string.sub(str, rightstr + 1)
        str = string.gsub(str, "^%s+", "")
        --@debug@
        GSE.PrintDebugMessage("str changed to: " .. str, GNOME)
        --@end-debug@
    end
    -- if not cleanNewLines then
    --     str = string.match(str, "^%s*(.-)%s*$")
    -- end
    -- Check for resets
    --@debug@
    GSE.PrintDebugMessage("checking for reset= in " .. str, GNOME)
    --@end-debug@
    local resetleft = string.find(str, "reset=")
    if not GSE.isEmpty(resetleft) then
        --@debug@
        GSE.PrintDebugMessage("found reset= at" .. resetleft, GNOME)
        --@end-debug@
    end

    if resetleft then
        local resetright = string.find(str, "%s", resetleft) or (string.len(str) + 1)
        local resetmod = string.sub(str, resetleft, resetright - 1)
        if not GSE.isEmpty(mods) then
            mods = mods .. " "
        end
        mods = mods .. resetmod
        --@debug@
        GSE.PrintDebugMessage("reset= mods changed to: " .. mods, GNOME)
        --@end-debug@
        str = string.sub(str, resetright)
        str = string.gsub(str, "^%s+", "")
        --@debug@
        GSE.PrintDebugMessage("reset= test str changed to: " .. str, GNOME)
        --@end-debug@
        found = true
    end

    mods = GSEOptions.COMMENT .. mods .. Statics.StringReset
    return found, mods, str
end

--- Converts a string spell name to an id and back again.
--- Find a spell ID for a name in ANY locale table we hold.
--
-- The point of receiving other players' caches is that their locale's names
-- become resolvable here, and the old fallback never reached them: it tried
-- GSESpellCache[GetLocale()] and then "the enUS cache" -- which on an enUS
-- client is the SAME table twice, so a deDE name from a group member's cache
-- could never be found. Try this client's locale first (most likely, and the
-- authoritative one), then enUS, then everything else.
--
-- It also stopped indexing a locale table that does not exist. A client whose
-- cache arrived entirely from a foreign group member has no ["enUS"] key, and
-- the old line indexed it unguarded.
local function lookupCachedSpellID(spellName)
    if GSE.isEmpty(spellName) or type(GSESpellCache) ~= "table" then
        return nil
    end
    for _, locale in ipairs({GetLocale(), "enUS"}) do
        local cache = GSESpellCache[locale]
        if type(cache) == "table" and not GSE.isEmpty(cache[spellName]) then
            return cache[spellName]
        end
    end
    for locale, cache in pairs(GSESpellCache) do
        if locale ~= GetLocale() and locale ~= "enUS" and type(cache) == "table" then
            if not GSE.isEmpty(cache[spellName]) then
                return cache[spellName]
            end
        end
    end
    return nil
end

-- Spell ranks.
--
-- Vanilla-era clients give every rank of a spell its own spell ID -- WoW
-- Forever ships the original ones (Frostbolt Rank 1 is 116, Rank 2 is 205) --
-- and C_Spell.GetSpellSubtext(id) names the rank an ID is: "Rank 2". That is
-- the Retail-API equivalent of the GetSpellSubtext call the Classic code used
-- before #1471 removed it. A macro picks a rank by writing it,
-- `/cast Frostbolt(Rank 1)`; a bare `/cast Frostbolt` means the highest rank
-- the character knows. Druid form abilities can carry a qualifier after the
-- rank, `Maul(Rank 1)(Bear)`, which is kept and written back out.
--
-- How GSE keeps that:
--   * Storage is always a spell ID, so it translates between locales. A
--     written rank stores THAT rank's ID, which is what carries the rank.
--   * A bare name stays rankless. Its stored ID may be any rank's -- whatever
--     the author's client resolved -- so an ID alone cannot say whether a rank
--     was asked for. The BLOCK says so: `Ranks` lists the IDs of its ranked
--     casts (`{205}`, or `{"6807(Bear)"}` with a trailing qualifier). An ID
--     not on that list compiles to the bare name.
--   * Compiling caps a written rank at what the character knows: asked for
--     Rank 10 while knowing Rank 8, it casts 8, then 9 once learned, then 10
--     -- and stays on 10 after Rank 11 is learned.
--
-- Nothing here is keyed on the game version. On a client without ranks no
-- spell has a numbered subtext, no `Ranks` list is ever written, and every
-- path falls through to the unranked one.

local function rankNumber(text)
    return type(text) == "string" and tonumber(text:match("(%d+)")) or nil
end

local function getSpellSubtext(spellID)
    local GetSubtext = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext
    if not GetSubtext or not spellID then return nil end
    local ok, subtext = pcall(GetSubtext, spellID)
    if ok and type(subtext) == "string" and subtext ~= "" then
        return subtext
    end
    -- Empty until the client has loaded that spell's data. Ask for it; the
    -- spellbook rows below cover every rank the character actually knows, and
    -- SPELL_DATA_LOAD_RESULT recompiles once the rest arrives
    -- (GSE.SpellRankDataLoaded).
    if C_Spell and C_Spell.RequestLoadSpellData and not pendingRankData[spellID] then
        pendingRankData[spellID] = true
        pcall(C_Spell.RequestLoadSpellData, spellID)
    end
    return nil
end

--- SPELL_DATA_LOAD_RESULT for a spell whose rank we were waiting on. Returns
-- true when sequences need recompiling: until that rank could be read, a cast
-- capped at it may have compiled to a higher one.
function GSE.SpellRankDataLoaded(spellID)
    spellID = tonumber(spellID)
    if spellID and pendingRankData[spellID] then
        pendingRankData[spellID] = nil
        return true
    end
    return false
end

local function isSpellKnown(spellID)
    if not spellID then return false end
    local IsKnown = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    if not IsKnown then return false end
    local ok, known = pcall(IsKnown, spellID)
    return ok and known == true
end

-- Every known rank in the spellbook: byName[name] sorted low to high, and
-- byID[spellID]. The same entries are shared by both.
local function buildRankIndex()
    local byName, byID = {}, {}
    local function add(name, spellID, subtext)
        spellID = tonumber(normaliseSpellIDValue(spellID))
        local rank = rankNumber(subtext)
        if GSE.isEmpty(name) or not spellID or not rank then return end
        local entry = {spellID = spellID, rank = rank, subtext = subtext, name = name}
        byName[name] = byName[name] or {}
        table.insert(byName[name], entry)
        byID[spellID] = entry
    end

    -- Same API split as getPlayerSpells in GSE_QoL/QoL.lua: require every
    -- modern function the loop calls, since some Classic clients ship a
    -- partial C_SpellBook.
    local numSkillLines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
    local skillLineInfo = C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo
    local itemInfo = C_SpellBook and C_SpellBook.GetSpellBookItemInfo
    if numSkillLines and skillLineInfo and itemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local futureSpell = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        for line = 1, numSkillLines() do
            local lineinfo = skillLineInfo(line)
            if not lineinfo then break end
            local offset = lineinfo.itemIndexOffset or 0
            for i = 1, lineinfo.numSpellBookItems or 0 do
                local info = itemInfo(i + offset, bank)
                -- A greyed-out, not-yet-learned rank is not castable.
                if info and (futureSpell == nil or info.itemType ~= futureSpell) then
                    add(info.name, info.spellID, info.subName)
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName and GetSpellBookItemInfo then
        local bookType = BOOKTYPE_SPELL or "spell"
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSlots = GetSpellTabInfo(tab)
            for i = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
                local itemType, spellID = GetSpellBookItemInfo(i, bookType)
                if itemType == "SPELL" then
                    local name, subtext = GetSpellBookItemName(i, bookType)
                    add(name, spellID, subtext)
                end
            end
        end
    end

    for _, ranks in pairs(byName) do
        table.sort(ranks, function(a, b) return a.rank < b.rank end)
    end
    return {byName = byName, byID = byID}
end

local function getRankIndex()
    if not rankIndex then
        local ok, index = pcall(buildRankIndex)
        rankIndex = ok and index or {byName = {}, byID = {}}
    end
    return rankIndex
end

local function knownRanks(name)
    if GSE.isEmpty(name) then return nil end
    return getRankIndex().byName[name]
end

--- The rank number of a spell ID, or nil for a spell without ranks.
local function rankOf(spellID)
    spellID = tonumber(spellID)
    if not spellID then return nil end
    local entry = getRankIndex().byID[spellID]
    return (entry and entry.rank) or rankNumber(getSpellSubtext(spellID))
end

--- The rank line for a spell ID, as this client writes it ("Rank 2"), or nil
-- for a spell without ranks. For tooltips that only have an ID to go on.
function GSE.GetSpellRankText(spellID)
    spellID = tonumber(spellID)
    if not rankOf(spellID) then return nil end
    local entry = getRankIndex().byID[spellID]
    return (entry and entry.subtext) or getSpellSubtext(spellID)
end

--- Split a written rank off a spell.
-- "Maul(Rank 1)(Bear)" -> "Maul", 1, "(Rank 1)", "(Bear)"
-- The rank is the right-most bracket holding a number; anything after it is
-- tail. A bracket with no number is part of the name, which keeps
-- "Faerie Fire (Feral)" whole. Returns nil for a spell with no rank.
function GSE.SplitSpellRank(spellstring)
    if type(spellstring) ~= "string" then return nil end
    local rest, tail = spellstring, ""
    while true do
        local base, group = rest:match("^(.-)%s*(%b())$")
        if GSE.isEmpty(base) then return nil end
        local rank = rankNumber(group)
        if rank then
            return base, rank, group, tail
        end
        rest, tail = base, group .. tail
    end
end

--- A block's `Ranks` list as a lookup: spellID -> trailing qualifier ("" for
-- none), plus a stable key for the translate cache.
local function rankSet(ranks)
    if type(ranks) ~= "table" then return nil, "" end
    local set, keys = nil, {}
    for _, entry in ipairs(ranks) do
        local spellID = tonumber(entry) or tonumber(tostring(entry):match("^(%d+)"))
        if spellID then
            set = set or {}
            set[spellID] = tonumber(entry) and "" or tostring(entry):match("^%d+(.*)$")
            keys[#keys + 1] = tostring(entry)
        end
    end
    table.sort(keys)
    return set, table.concat(keys, ",")
end

--- Run fn with a block's ranked casts in force, so every spell ID it
-- translates knows whether it was written with a rank.
function GSE.WithSpellRanks(ranks, fn, ...)
    local previous, previousKey = activeRanks, activeRanksKey
    activeRanks, activeRanksKey = rankSet(ranks)
    local function restore(ok, ...)
        activeRanks, activeRanksKey = previous, previousKey
        if not ok then error((...), 0) end
        return ...
    end
    return restore(pcall(fn, ...))
end

--- The ID of an exact written rank -- "Frostbolt", 2 -> 205 -- or nil.
local function exactRankID(name, rank, group)
    for _, entry in ipairs(knownRanks(name) or {}) do
        if entry.rank == rank then
            return entry.spellID
        end
    end
    -- A rank this character does not know is not in its spellbook. The
    -- client may still resolve the written form; accept it only if it
    -- really is that rank.
    local exact = getSpellInfoID(name .. group)
    if exact and rankOf(exact) == rank then
        return exact
    end
    return nil
end

--- The ID to cast for a requested rank: the highest rank this character
-- knows that is not above it. Returns spellID, rank -- or nil if it knows none.
local function cappedRank(name, requestedID)
    -- The exact rank, when known. Asked by ID as well as through the
    -- spellbook, as a spellbook showing only top ranks omits the rest.
    if isSpellKnown(requestedID) then
        return requestedID, rankOf(requestedID)
    end
    local requested = rankOf(requestedID)
    local best
    for _, entry in ipairs(knownRanks(name) or {}) do
        -- An unreadable request is a rank not yet learned, and ranks are
        -- learned in order, so every known one is below it.
        if not requested or entry.rank <= requested then
            best = entry
        end
    end
    if best then
        return best.spellID, best.rank
    end
    return nil
end

--- "(Rank N)" as this client writes it.
local function formatRank(spellID, rank)
    local entry = getRankIndex().byID[spellID]
    local subtext = (entry and entry.subtext) or getSpellSubtext(spellID)
    if subtext then
        return "(" .. subtext .. ")"
    end
    if rank then
        return "(" .. (_G.RANK or "Rank") .. " " .. rank .. ")"
    end
    return ""
end

--- GSE.GetSpellId for a stored ID the block says was written with a rank.
local function translateRankedID(spellID, tail, mode)
    if mode == Statics.TranslatorMode.ID then
        return spellID
    end
    local info = GSE.GetSpellInfo(spellID)
    if not info or GSE.isEmpty(info.name) then
        return nil
    end
    rememberSpellName(info.name, spellID)
    if mode == Statics.TranslatorMode.String then
        -- Compiling: what the character actually has, capped at the rank
        -- written. Knowing none of it, write the request out as it stands.
        local castID, castRank = cappedRank(info.name, spellID)
        if castID then
            return info.name .. formatRank(castID, castRank) .. tail
        end
    end
    -- Displaying: the rank that was asked for.
    return info.name .. formatRank(spellID, rankOf(spellID)) .. tail
end

--- GSE.GetSpellId for a spell typed with its rank: "Frostbolt(Rank 2)".
local function translateRankedName(name, rank, group, tail, mode)
    local spellID = exactRankID(name, rank, group)
    if not spellID then
        -- Neither this character nor the client knows that rank. Leave the
        -- text as written rather than store a different rank's ID.
        return nil
    end
    if mode == Statics.TranslatorMode.ID then
        return spellID
    end
    return translateRankedID(spellID, tail, mode)
end

--- The `Ranks` list for text as the user typed it: the ID of every cast
-- written with a rank. Takes a whole macro, or a single spell as typed into
-- a Spell block. Returns nil when nothing is ranked.
--
-- previous and stored guard a re-save: previous is the block's old list and
-- stored the ID form just saved. A cast whose rank this client could not yet
-- read was SHOWN without it, so its absence from the typed text is not the
-- user removing it -- it is kept while its ID is still in the block.
function GSE.GetRankedSpellIDs(text, previous, stored)
    if type(text) ~= "string" then return nil end
    local ranks, seen = {}, {}
    local function consider(spell)
        local _, _, etc = GSE.GetConditionalsFromString(spell)
        etc = (etc or ""):gsub("^%s*!?%s*", ""):gsub("%s+$", "")
        local name, rank, group, tail = GSE.SplitSpellRank(etc)
        if not name or tonumber(name) then return end
        local spellID = exactRankID(name, rank, group)
        local entry = spellID and (tail == "" and spellID or spellID .. tail)
        if entry and not seen[entry] then
            seen[entry] = true
            ranks[#ranks + 1] = entry
        end
    end

    if not text:find("^%s*/") then
        consider(text)
    else
        for _, line in ipairs(GSE.SplitMeIntoLines(text)) do
            local cmd, etc = line:match("^%s*/(%w+)%s+(.+)$")
            cmd = cmd and string.lower(cmd)
            if cmd == "castsequence" then
                for _, clause in ipairs(GSE.split(etc, ";")) do
                    for _, spell in ipairs(GSE.SplitCastSequence(clause)) do
                        consider(spell)
                    end
                end
            elseif cmd and Statics.CastCmds[cmd] then
                for _, spell in ipairs(GSE.split(etc, ";")) do
                    consider(spell)
                end
            end
        end
    end
    if type(previous) == "table" and stored ~= nil then
        stored = tostring(stored)
        for _, entry in ipairs(previous) do
            local spellID = tonumber(entry) or tonumber(tostring(entry):match("^(%d+)"))
            if spellID and not seen[entry] and not rankOf(spellID)
                and stored:find("%f[%d]" .. spellID .. "%f[%D]") then
                seen[entry] = true
                ranks[#ranks + 1] = entry
            end
        end
    end
    return #ranks > 0 and ranks or nil
end

--- The value a Spell block's button should cast on this character.
-- A cast on the block's `Ranks` list resolves to the highest rank known up to
-- the one written; anything else resolves to the highest known, the same as
-- `/cast <name>`. Spells without ranks come back exactly as before.
function GSE.GetCastableSpell(value, ranks)
    local set = rankSet(ranks)
    local spellID = tonumber(value)
    if not spellID then
        local name, rank, group = GSE.SplitSpellRank(value)
        if name and not tonumber(name) then
            spellID = exactRankID(name, rank, group)
            if spellID then
                set = set or {}
                set[spellID] = ""
            end
        end
    end
    if spellID and set and set[spellID] then
        local info = GSE.GetSpellInfo(spellID)
        return (info and cappedRank(info.name, spellID)) or spellID
    end
    local spell = GSE.GetSpellId(value, Statics.TranslatorMode.ID) or
        GSE.GetSpellId(value, Statics.TranslatorMode.String)
    local info = tonumber(spell) and GSE.GetSpellInfo(spell)
    local top = info and knownRanks(info.name)
    return (top and top[#top].spellID) or spell
end

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
    -- Ranks: an ID the block marks as ranked, or a name typed with its rank.
    -- Both are handled apart because the rank must survive the round trip,
    -- and the name cache below is keyed on bare names.
    local numericSpell = tonumber(spellstring)
    if numericSpell and activeRanks and activeRanks[numericSpell] then
        return translateRankedID(numericSpell, activeRanks[numericSpell], mode)
    end
    local rankedName, rankValue, rankGroup, rankTail = GSE.SplitSpellRank(spellstring)
    if rankedName and not tonumber(rankedName) then
        return translateRankedName(rankedName, rankValue, rankGroup, rankTail, mode)
    end
    local returnval, name, spellId, rawSpellId

    local spellinfo = GSE.GetSpellInfo(spellstring)
    -- Whether the CLIENT resolved this, as opposed to the fallback below
    -- reflecting the input back with an ID read out of the cache. Only a real
    -- client resolution teaches us anything new.
    local resolvedFromClient = spellinfo ~= nil
    if not spellinfo then
        if type(spellstring) == "string" then
            ---@diagnostic disable-next-line: missing-fields
            spellinfo = {}
            spellinfo.name = spellstring
            -- Any locale's table, not just this client's: a name the client
            -- cannot resolve is very often a name from someone else's locale,
            -- which is the whole reason those tables are shared.
            spellinfo.spellID = lookupCachedSpellID(spellstring) or spellinfo.spellID
        else
            -- Numeric spell ID that the client doesn't know about: nothing
            -- meaningful to return. Bail rather than indexing nil below.
            return nil
        end
    end
    rawSpellId = normaliseSpellIDValue(spellinfo.spellID)
    spellId = rawSpellId
    name = spellinfo.name
    -- Learn the pair here, before the mode branch, because a successful lookup
    -- yields BOTH halves whichever way round it was asked. The write below is
    -- gated on ID mode, so everything GSE translates the other way was
    -- discarded: rendering a sequence's macro body runs CompileMacroText in
    -- String mode (Storage.lua), which turns every stored ID back into a name
    -- and threw that pair away. On a deDE client those are exactly the deDE
    -- name -> ID pairs an enUS group member has no other way to obtain.
    if resolvedFromClient then
        rememberSpellName(name, rawSpellId)
    end
    if mode ~= Statics.TranslatorMode.ID then
        -- No rank is appended here: a spell written without one means the
        -- highest rank known, which is what a bare name already casts.
        returnval = name
    else
        returnval = spellId
        -- Check for overrides like Crusade and Avenging Wrath. A rank is
        -- already the exact spell and must not collapse to its first rank.
        if not absolute and not GSE.isEmpty(returnval) and not rankOf(returnval) then
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
        --@debug@
        GSE.PrintDebugMessage(
            "Converted " .. spellstring .. " to " .. returnval .. " using mode " .. mode,
            "Translator"
        )
        --@end-debug@
    else
        if not GSE.isEmpty(spellstring) then
            --@debug@
            GSE.PrintDebugMessage(spellstring .. " was not found", "Translator")
            --@end-debug@
            -- Last resort: any locale table we hold. This is where a name
            -- from another client's language gets resolved.
            returnval = lookupCachedSpellID(spellstring)
        else
            --@debug@
            GSE.PrintDebugMessage("Nothing was there to be found", "Translator")
            --@end-debug@
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

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Translator") end


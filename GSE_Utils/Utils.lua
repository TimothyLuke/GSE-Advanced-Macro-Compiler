local GSE = GSE
local Statics = GSE.Static
local L = GSE.L

local GNOME = "Storage"

function GSE.ImportLegacyStorage(Library)
    if GSE.isEmpty(GSESequences) then
        GSESequences = {}
    end
    for i = 0, 13 do
        if GSE.isEmpty(GSESequences[i]) then
            GSESequences[i] = {}
        end
    end

    if not GSE.isEmpty(Library) then
        for k, v in pairs(Library) do
            for i, j in pairs(v) do
                local compressedVersion = GSE.EncodeMessage({i, j})
                GSESequences[k][i] = compressedVersion
            end
        end
    end
    GSELegacyLibraryBackup = GSELibrary
    GSELibrary = nil
end

--- Add a sequence to the library
function GSE.OOCAddSequenceToCollection(sequenceName, sequence, classid)
    -- Check its not a GSE2 Sequence
    if GSE.isEmpty(sequence.Macros) then
        GSE.Print(string.format("%s " .. L["was unable to be interpreted."], sequenceName), L["Unrecognised Import"])
        return
    end
    -- check for version flags.
    if sequence.MetaData.EnforceCompatability and not string.match(GSE.VersionString, "development") then
        if GSE.ParseVersion(sequence.MetaData.GSEVersion) > (GSE.VersionNumber) then
            GSE.Print(
                string.format(
                    L[
                        "This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."
                    ],
                    sequence.MetaData.GSEVersion
                )
            )
            GSE.PrintDebugMessage(
                "Macro Version " .. sequence.MetaData.GSEVersion .. " Required Version: " .. GSE.VersionString,
                "Storage"
            )
            return
        end
    end

    GSE.PrintDebugMessage("Attempting to import " .. sequenceName, "Storage")
    GSE.PrintDebugMessage("Classid not supplied - " .. tostring(GSE.isEmpty(classid)), "Storage")
    -- Remove Spaces or commas from SequenceNames and replace with _'s
    sequenceName = string.gsub(sequenceName, " ", "_")
    sequenceName = string.gsub(sequenceName, ",", "_")

    -- check Sequence TOC matches the current TOC
    local gameversion, build, date, tocversion = GetBuildInfo()
    if GSE.isEmpty(sequence.MetaData.TOC) or sequence.MetaData.TOC ~= tocversion then
        GSE.Print(
            string.format(
                L["WARNING ONLY"] ..
                    ": " ..
                        L[
                            "Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."
                        ],
                sequenceName
            )
        )
    end

    -- Check for collisions
    local found = false
    if (GSE.isEmpty(classid) or classid == 0) and not GSE.isEmpty(sequence.MetaData.SpecID) then
        classid = tonumber(GSE.GetClassIDforSpec(sequence.MetaData.SpecID))
    elseif GSE.isEmpty(sequence.MetaData.SpecID) then
        sequence.MetaData.SpecID = GSE.GetCurrentClassID()
        classid = GSE.GetCurrentClassID()
    end
    GSE.PrintDebugMessage("Classid now - " .. classid, "Storage")
    if GSE.isEmpty(GSE.Library[classid]) then
        GSE.Library[classid] = {}
    end
    if not GSE.isEmpty(GSE.Library[classid][sequenceName]) then
        found = true
        GSE.PrintDebugMessage("Macro Exists", "Storage")
    end
    if found then
        -- Check if modified
        if GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].ManualIntervention) then
            -- Macro hasnt been touched.
            GSE.PrintDebugMessage(L["No changes were made to "] .. sequenceName, "Storage")
        else
            -- Perform choice.
            -- First check if GUI.
            if GSE.GUI then
                -- Show dialog.
                GSE.GUIShowCompareWindow(sequenceName, classid, sequence)
            else
                GSE.PerformMergeAction(GSEOptions.DefaultImportAction, classid, sequenceName, sequence)
            end
        end
    else
        GSE.PrintDebugMessage("Creating New Macro", "Storage")
        -- New Sequence
        GSE.PerformMergeAction("REPLACE", classid, sequenceName, sequence)
    end
    if classid == GSE.GetCurrentClassID() or classid == 0 then
        GSE.PrintDebugMessage("As its the current class updating buttons", "Storage")
        GSE.UpdateSequence(sequenceName, sequence.Macros[sequence.MetaData.Default])
    end
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, sequenceName)
end

function GSE.OOCPerformMergeAction(action, classid, sequenceName, newSequence)
    if GSE.isEmpty(newSequence.LastUpdated) then
        newSequence.LastUpdated = GSE.GetTimestamp()
    end
    if sequenceName:len() > 28 then
        local tempseqName = sequenceName:sub(1, 28)
        GSE.Print(
            string.format(
                L[
                    "Your sequence name was longer than 27 characters.  It has been shortened from %s to %s so that your macro will work."
                ],
                sequenceName,
                tempseqName
            ),
            "GSE Storage"
        )
        sequenceName = tempseqName
    end
    if action == "MERGE" then
        for k, v in ipairs(newSequence.Macros) do
            GSE.PrintDebugMessage("adding " .. k, "Storage")
            table.insert(GSE.Library[classid][sequenceName].Macros, v)
        end
        GSE.PrintDebugMessage("Finished colliding entry entry", "Storage")
        GSE.Print(string.format(L["Extra Macro Versions of %s has been added."], sequenceName), GNOME)
        GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
    elseif action == "REPLACE" then
        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSE.PrintDebugMessage("About to encode: Sequence " .. sequenceName)
        GSE.PrintDebugMessage(" New Entry: " .. GSE.Dump(GSE.Library[classid][sequenceName]), "Storage")
        GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
        GSE.Print(sequenceName .. L[" was updated to new version."], "GSE Storage")
    elseif action == "RENAME" then
        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
        GSE.Print(sequenceName .. L[" was imported as a new macro."], "GSE Storage")
        GSE.PrintDebugMessage(
            "Sequence " .. sequenceName .. " New Entry: " .. GSE.Dump(GSE.Library[classid][sequenceName]),
            "Storage"
        )
    else
        GSE.Print(L["No changes were made to "] .. sequenceName, GNOME)
    end
    GSE.Library[classid][sequenceName]["MetaData"].ManualIntervention = false
    GSE.PrintDebugMessage(
        "Sequence " .. sequenceName .. " Finalised Entry: " .. GSE.Dump(GSE.Library[classid][sequenceName]),
        "Storage"
    )
    GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, sequenceName)
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
    for k, v in pairs(Sequences) do
        GSE.AddSequenceToCollection(k, v)
    end
end

--- Add a macro for a sequence and register it in the list of known sequences
function GSE.CreateMacroIcon(sequenceName, icon, forceglobalstub)
    local sequenceIndex = GetMacroIndexByName(sequenceName)
    local numAccountMacros, numCharacterMacros = GetNumMacros()
    if sequenceIndex > 0 then
        -- Sequence exists, do nothing
        GSE.PrintDebugMessage("Moving on - macro for " .. sequenceName .. " already exists.", GNOME)
    else
        -- Create Sequence as a player sequence
        if numCharacterMacros >= MAX_CHARACTER_MACROS and not GSEOptions.overflowPersonalMacros and not forceglobalstub then
            GSE.Print(
                GSEOptions.AuthorColour ..
                    L["Close to Maximum Personal Macros.|r  You can have a maximum of "] ..
                        MAX_CHARACTER_MACROS ..
                            L[" macros per character.  You currently have "] ..
                                GSEOptions.EmphasisColour ..
                                    numCharacterMacros ..
                                        L[
                                            "|r.  As a result this macro was not created.  Please delete some macros and reenter "
                                        ] ..
                                            GSEOptions.CommandColour .. L["/gse|r again."],
                GNOME
            )
        elseif numAccountMacros >= MAX_ACCOUNT_MACROS and GSEOptions.overflowPersonalMacros then
            GSE.Print(
                L["Close to Maximum Macros.|r  You can have a maximum of "] ..
                    MAX_CHARACTER_MACROS ..
                        L[" macros per character.  You currently have "] ..
                            GSEOptions.EmphasisColour ..
                                numCharacterMacros ..
                                    L["|r.  You can also have a  maximum of "] ..
                                        MAX_ACCOUNT_MACROS ..
                                            L[" macros per Account.  You currently have "] ..
                                                GSEOptions.EmphasisColour ..
                                                    numAccountMacros ..
                                                        L[
                                                            "|r. As a result this macro was not created.  Please delete some macros and reenter "
                                                        ] ..
                                                            GSEOptions.CommandColour .. L["/gse|r again."],
                GNOME
            )
        else
            CreateMacro(
                sequenceName,
                (GSEOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon),
                GSE.CreateMacroString(sequenceName),
                (forceglobalstub and false or GSE.SetMacroLocation())
            )
        end
    end
end

local function fixContainer(v)
    local fixedTable = {}
    for k, val in pairs(v) do
        if type(v[k]) == "table" then
            if tonumber(k) then
                fixedTable[tonumber(k)] = {}
                fixedTable[tonumber(k)] = fixContainer(val)
            else
                fixedTable[k] = fixContainer(val)
            end
        else
            fixedTable[k] = val
        end
    end
    for k, val in ipairs(v) do
        if type(v[k]) == "table" then
            fixedTable[k] = fixContainer(val)
        else
            fixedTable[k] = val
        end
    end
    return fixedTable
end

function GSE.processWAGOImport(input, dontencode)
    for k, v in ipairs(input) do
        if type(v) == "table" then
            input[k] = fixContainer(v)
        end
    end
    for k, v in pairs(input) do
        if type(v) == "table" then
            input[k] = fixContainer(v)
        end
    end
    if dontencode then
        return input
    else
        return GSE.EncodeMessage(input)
    end
end

--- Load a serialised Sequence
function GSE.ImportSerialisedSequence(importstring, forcereplace)
    local decompresssuccess, actiontable
    if type(importstring) == "table" then
        decompresssuccess, actiontable = true, importstring
    else
        decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    end
    GSE.PrintDebugMessage(string.format("Decomsuccess: %s ", tostring(decompresssuccess)), Statics.SourceTransmission)

    if decompresssuccess and actiontable then
        if actiontable.type == "COLLECTION" then
            actiontable = actiontable.payload
            for _, v in pairs(actiontable["Variables"]) do
                GSE.ImportSerialisedSequence(v, forcereplace)
            end
            for _, v in pairs(actiontable["Sequences"]) do
                GSE.ImportSerialisedSequence(v, forcereplace)
            end
            for _, v in pairs(actiontable["Macros"]) do
                GSE.ImportSerialisedSequence(v, forcereplace)
            end
            GSE:SendMessage(Statics.Messages.COLLECTION_IMPORTED)
        elseif actiontable.objectType == "MACRO" then
            actiontable.objectType = nil
            local oocaction = {
                ["action"] = "importmacro",
                ["node"] = actiontable
            }
            table.insert(GSE.OOCQueue, oocaction)
        elseif actiontable.objectType == "VARIABLE" then
            actiontable.objectType = nil
            local oocaction = {
                ["action"] = "updatevariable",
                ["variable"] = actiontable,
                ["name"] = actiontable.name
            }
            table.insert(GSE.OOCQueue, oocaction)
        else
            actiontable.objectType = nil
            GSE.PrintDebugMessage(
                string.format(
                    "tablerows: %s   type cell1 %s cell2 %s",
                    #actiontable,
                    type(actiontable[1]),
                    type(actiontable[2])
                ),
                Statics.SourceTransmission
            )
            local k, v = actiontable[1], actiontable[2]
            if actiontable.MetaData and actiontable.MetaData.Name then
                k = actiontable.MetaData.Name
                v = actiontable
            end
            local seqName = k
            v = GSE.processWAGOImport(v, true)

            if v.MetaData.GSEVersion and v.MetaData.GSEVersion > 3200 then
                if v.MetaData.GSEVersion < math.floor(GSE.VersionNumber/ 100) * 100 then
                    v.MetaData.Disabled = true
                end
            else
                GSE.Print(
                        L["This macro is not compatible with this version of the game and cannot be imported."],
                        L["Import"]
                    )
                return
            end
            if forcereplace then
                GSE.PerformMergeAction("REPLACE", GSE.GetClassIDforSpec(v.MetaData.SpecID), seqName, v)
            else
                GSE.AddSequenceToCollection(seqName, v)
            end

            GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, seqName)
        end
    else
        GSE.Print(L["Unable to interpret sequence."], GNOME)
        decompresssuccess = false
    end

    return decompresssuccess
end

--- This function removes any macro stubs that do not relate to a GSE macro
function GSE.CleanOrphanSequences()
    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    local todelete = {}
    for macid = 1, maxmacros do
        local found = false
        local mname, mtexture, mbody = GetMacroInfo(macid)
        if not GSE.isEmpty(mname) then
            if not GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][mname]) then
                found = true
            end
            if not GSE.isEmpty(GSE.Library[0][mname]) then
                found = true
            end

            if not found then
                -- Check if body is a gs one and delete the orphan
                todelete[mname] = true
            end
        end
    end
    for k, _ in pairs(todelete) do
        GSE.DeleteMacroStub(k)
    end
end

--- This function dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)
    GSE.Print("====================================\nStart GSE Button Dump\n====================================")
    GSE.Print("Button name: " .. SequenceName)
    GSE.Print("Step Id: " .. _G[SequenceName]:GetAttribute("step"))
    GSE.Print("ms: " .. _G[SequenceName]:GetAttribute("ms"))
    GSE.Print("====================================\nStep\n====================================")
    GSE.Print(GSE.SequencesExec[SequenceName][_G[SequenceName]:GetAttribute("step")])
    GSE.Print("====================================\nEnd GSE Button Dump\n====================================")
end

--- Moves Macros hidden in Global Macros to their appropriate class.
function GSE.MoveMacroToClassFromGlobal()
    for k, v in pairs(GSE.Library[0]) do
        if not GSE.isEmpty(v.SpecID) and tonumber(v.SpecID) > 0 then
            if v.SpecID < 13 then
                GSE.Library[v.SpecID][k] = v
                GSE.Print(string.format(L["Moved %s to class %s."], k, Statics.SpecIDList[v.SpecID]))
                GSE.Library[0][k] = nil
            else
                GSE.Library[GSE.GetClassIDforSpec(v.SpecID)][k] = v
                GSE.Print(
                    string.format(L["Moved %s to class %s."], k, Statics.SpecIDList[GSE.GetClassIDforSpec(v.SpecID)])
                )
                GSE.Library[0][k] = nil
            end
        end
    end
    GSE.ReloadSequences()
end

-- ============================================================
-- Sequence error checker: module-level helpers
-- ============================================================

--- MetaData keys that store Macros array index references.
local seqContextKeys = {
    "Default", "Scenario", "Arena", "PVP", "Raid",
    "Normal", "Mythic", "Timewalking", "Party"
}

--- Set of valid WoW macro slash commands (warcraft.wiki.gg/wiki/Macro_commands).
-- Built once at load time from Statics + comprehensive wiki list.
local validMacroSlashCmds = (function()
    local s = {}
    for cmd in pairs(Statics.CastCmds or {}) do s[cmd] = true end
    for _, cmd in ipairs(Statics.MacroCommands or {}) do s[cmd] = true end
    for _, cmd in ipairs({
        -- Combat / casting
        "castrandom", "castsequence", "changeactionbar", "stopcasting",
        "stopspelltarget", "swapactionbar", "userandom", "spell",
        -- Targeting
        "tar", "targetexact", "targetenemyplayer", "targetfriendplayer",
        "targetparty", "targetraid", "targetlastenemy", "targetlastfriend",
        "targetlasttarget",
        -- Pet
        "petassist", "petautocasttoggle", "petdefensive", "petdismiss",
        "petfollow", "petmoveto", "petpassive", "petstay",
        -- System
        "console", "click", "disableaddons", "enableaddons", "help",
        "logout", "macrohelp", "played", "quit", "random", "reload",
        "run", "script", "stopmacro", "time", "timetest", "who",
        -- Character / inventory
        "equip", "equipset", "equipslot", "friend", "follow", "ignore",
        "inspect", "leavevehicle", "randompet", "removefriend", "settitle",
        "trade", "unignore", "summonpet", "dismisspet", "randomfavoritepet",
        -- UI / Blizzard frames
        "achievements", "calendar", "guildfinder", "dungeonfinder", "loot",
        "macro", "raidfinder", "share", "stopwatch",
        -- Chat (full names and abbreviations)
        "afk", "announce", "battleground", "emote", "dnd", "guild",
        "join", "leave", "party", "raid", "rw", "reply", "say",
        "whisper", "yell", "s", "y", "g", "p", "bg", "i", "o", "me",
        -- Party / Raid
        "clearworldmarker", "invite", "readycheck", "requestinvite",
        "targetmarker", "uninvite", "worldmarker", "raidinfo", "promote",
        "ffa", "master", "mainassist", "mainassistoff", "maintank",
        "maintankoff",
        -- Guild
        "guilddemote", "guilddisband", "guildinfo", "guildinvite",
        "guildleader", "guildquit", "guildmotd", "guildpromote",
        "guildroster", "guildremove",
        -- PvP
        "duel", "forfeit", "pvp", "wargame",
        -- Miscellaneous
        "in", "showtooltip", "show",
    }) do
        s[cmd] = true
    end
    return s
end)()

--- Returns (ipairsCount, totalNumericCount, maxNumericIndex) for a table.
-- Reveals array gaps: if totalNumericCount > ipairsCount, there are unreachable entries.
local function arrayStats(t)
    local ipCount = 0
    for _ in ipairs(t) do ipCount = ipCount + 1 end
    local numCount, maxIdx = 0, 0
    for k in pairs(t) do
        if type(k) == "number" and k >= 1 then
            numCount = numCount + 1
            if k > maxIdx then maxIdx = k end
        end
    end
    return ipCount, numCount, maxIdx
end

--- Inspects one sequence for structural and content issues.
-- Returns a list of human-readable issue strings (empty = no problems).
local function checkSeqStructure(classlibid, seqname, seq) -- luacheck: ignore classlibid seqname
    local issues = {}

    if type(seq) ~= "table" then
        table.insert(issues, L["Sequence is not a table"])
        return issues
    end

    -- Top-level required tables
    if GSE.isEmpty(seq.MetaData) or type(seq.MetaData) ~= "table" then
        table.insert(issues, L["Missing MetaData table"])
        return issues
    end
    if type(seq.Macros) ~= "table" then
        table.insert(issues, L["Missing or invalid Macros table"])
        return issues
    end

    -- Required MetaData fields
    if GSE.isEmpty(seq.MetaData.SpecID) then
        table.insert(issues, L["MetaData.SpecID is missing"])
    end

    -- Macros array analysis
    local macIp, macNum, macMax = arrayStats(seq.Macros)
    if macNum == 0 then
        table.insert(issues, L["Macros array is empty (no versions defined)"])
        return issues
    end
    if macNum > macIp then
        table.insert(issues, string.format(
            L["Macros array has gaps: %d version(s) reachable of %d total (max index %d)"],
            macIp, macNum, macMax))
    end

    -- MetaData context version references must point to existing Macros entries
    for _, ctxKey in ipairs(seqContextKeys) do
        local val = seq.MetaData[ctxKey]
        if not GSE.isEmpty(val) then
            local idx = tonumber(val)
            if idx and (idx < 1 or idx > macMax or seq.Macros[idx] == nil) then
                table.insert(issues, string.format(
                    L["MetaData.%s = %d references a non-existent Macros version (max valid index: %d)"],
                    ctxKey, idx, macMax))
            end
        end
    end

    -- Valid Action types
    local validTypes = {
        [Statics.Actions.Loop]   = true,
        [Statics.Actions.If]     = true,
        [Statics.Actions.Repeat] = true,
        [Statics.Actions.Action] = true,
        [Statics.Actions.Pause]  = true,
        [Statics.Actions.Embed]  = true,
    }

    -- Inspect every Macro version (including those beyond array gaps)
    for macIdx, macVer in pairs(seq.Macros) do
        if type(macIdx) == "number" then
            if type(macVer) ~= "table" then
                table.insert(issues, string.format(L["Macros[%d] is not a table"], macIdx))
            elseif type(macVer.Actions) ~= "table" then
                table.insert(issues, string.format(
                    L["Macros[%d].Actions is missing or not a table"], macIdx))
            else
                -- Actions array gap detection
                local actIp, actNum, actMax = arrayStats(macVer.Actions)
                if actNum > actIp then
                    table.insert(issues, string.format(
                        L["Macros[%d].Actions has gaps: %d reachable of %d total (max index %d)"],
                        macIdx, actIp, actNum, actMax))
                end

                -- Inspect every Action (including those beyond gaps)
                for actIdx, action in pairs(macVer.Actions) do
                    if type(actIdx) == "number" and type(action) == "table" then
                        if GSE.isEmpty(action.Type) then
                            table.insert(issues, string.format(
                                L["Macros[%d].Actions[%d] is missing Type field"],
                                macIdx, actIdx))
                        elseif not validTypes[action.Type] then
                            table.insert(issues, string.format(
                                L["Macros[%d].Actions[%d] has unrecognized Type: '%s'"],
                                macIdx, actIdx, tostring(action.Type)))
                        else
                            -- Type-specific required fields
                            if action.Type == Statics.Actions.If then
                                if GSE.isEmpty(action.Variable) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (If) is missing the Variable field"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Embed then
                                if GSE.isEmpty(action.Sequence) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (Embed) is missing the Sequence field"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Pause then
                                if GSE.isEmpty(action.Clicks) and GSE.isEmpty(action.MS) then
                                    table.insert(issues, string.format(
                                        L["Macros[%d].Actions[%d] (Pause) has neither Clicks nor MS"],
                                        macIdx, actIdx))
                                end
                            elseif action.Type == Statics.Actions.Action then
                                if not GSE.isEmpty(action.macro) then
                                    local raw = tostring(action.macro)
                                    if raw:sub(1, 1) == "/" then
                                        -- 255-character WoW macro block limit
                                        local unesc = GSE.UnEscapeString(raw)
                                        if #unesc > 255 then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] macro text exceeds 255 characters (%d chars)"],
                                                macIdx, actIdx, #unesc))
                                        end
                                        -- Unbalanced conditional bracket check
                                        local opens, closes = 0, 0
                                        for _ in raw:gmatch("%[") do opens  = opens  + 1 end
                                        for _ in raw:gmatch("%]") do closes = closes + 1 end
                                        if opens ~= closes then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] macro text has unbalanced brackets (%d '[' vs %d ']')"],
                                                macIdx, actIdx, opens, closes))
                                        end
                                        -- Unknown slash command check
                                        local cmd = raw:match("^/(%a+)")
                                        if cmd and not validMacroSlashCmds[cmd:lower()] then
                                            table.insert(issues, string.format(
                                                L["Macros[%d].Actions[%d] uses unrecognized slash command: /%s"],
                                                macIdx, actIdx, cmd))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return issues
end

--- Scans all sequences in GSE.Library for structural and content issues,
-- then checks GSESequences entries for valid encoding.
function GSE.ScanMacrosForErrors()
    GSE.Print(L["Scanning GSE.Library for structural and content issues..."])
    local totalIssues = 0

    -- 1. Structural / content checks on GSE.Library (all class IDs, including 0 = global)
    for classlibid = 0, 13 do
        local classlib = GSE.Library[classlibid]
        if classlib and type(classlib) == "table" then
            for seqname, seq in pairs(classlib) do
                local issues = checkSeqStructure(classlibid, seqname, seq)

                if #issues > 0 then
                    totalIssues = totalIssues + #issues
                    GSE.Print(
                        string.format(L["Issues found in '%s' (class library %d):"], seqname, classlibid),
                        "Error"
                    )
                    for _, issue in ipairs(issues) do
                        GSE.Print("  - " .. issue)
                    end
                    GSE.Print(
                        string.format(
                            L["To attempt automatic repair run: %s/run GSE.FixSequenceStructure(%d, \"%s\")%s"],
                            GSEOptions.CommandColour,
                            classlibid,
                            seqname,
                            Statics.StringReset
                        )
                    )
                end

                -- Runtime compile check for each reachable Macro version
                if type(seq) == "table" and type(seq.Macros) == "table" then
                    for macvidx, macroversion in ipairs(seq.Macros) do
                        if type(macroversion) == "table" and type(macroversion.Actions) == "table" then
                            local ok, err = pcall(GSE.CompileTemplate, macroversion)
                            if not ok then
                                totalIssues = totalIssues + 1
                                GSE.Print(
                                    string.format(
                                        L["Compile error in Macros[%d] of '%s': %s"],
                                        macvidx, seqname, tostring(err)
                                    ),
                                    "Error"
                                )
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Name collision checks (WW / PVP clash with WoW built-ins)
    for classlibid = 0, 13 do
        local classlib = GSE.Library[classlibid]
        if classlib and type(classlib) == "table" then
            for seqname, _ in pairs(classlib) do
                if seqname == "WW" then
                    GSE.Print(
                        string.format(
                            L[
                                "Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."
                            ],
                            GSEOptions.CommandColour,
                            Statics.StringReset
                        ),
                        "Error"
                    )
                elseif seqname == "PVP" then
                    GSE.Print(
                        string.format(
                            L[
                                "Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."
                            ],
                            GSEOptions.CommandColour,
                            Statics.StringReset
                        ),
                        "Error"
                    )
                end
            end
        end
    end

    -- 3. GSESequences encoding check (existing behaviour: remove malformed entries)
    for classlibid, classlib in ipairs(GSESequences) do
        for k, v in pairs(classlib) do
            if string.sub(v, 1, 6) ~= "!GSE3!" then
                GSESequences[classlibid][k] = nil
                GSE.Print(L["Removed unreadable sequence "] .. k, Statics.DebugModules["Storage"])
            end
        end
    end

    if totalIssues == 0 then
        GSE.Print(L["Finished scanning for errors.  If no other messages then no errors were found."])
    else
        GSE.Print(string.format(L["%d issue(s) found.  See above for details and fix commands."], totalIssues))
    end
end

--- Repairs structural issues in a sequence in GSE.Library:
-- 1. Clears OOC queue entries for the sequence
-- 2. Re-indexes the Macros array to remove numeric gaps
-- 3. Re-indexes each Macro version's Actions array to remove gaps
-- 4. Updates MetaData context version references to match the new indices
-- 5. Saves the repaired sequence and queues a recompile
-- Usage: /run GSE.FixSequenceStructure(classLibraryID, "SequenceName")
function GSE.FixSequenceStructure(classlibid, seqname)
    classlibid = tonumber(classlibid)
    if not classlibid or not GSE.Library[classlibid] then
        GSE.Print(string.format(L["Invalid class library ID: %s"], tostring(classlibid)))
        return
    end
    local seq = GSE.Library[classlibid][seqname]
    if GSE.isEmpty(seq) then
        GSE.Print(string.format(L["Sequence '%s' not found in class library %d."], seqname, classlibid))
        return
    end

    -- 1. Remove any pending OOC queue entries for this sequence
    local kept = {}
    for _, entry in ipairs(GSE.OOCQueue) do
        local entryName = entry.sequencename or entry.name
        if entryName ~= seqname then
            table.insert(kept, entry)
        end
    end
    local removed = #GSE.OOCQueue - #kept
    GSE.OOCQueue = kept
    if removed > 0 then
        GSE.Print(string.format(L["Cleared %d pending queue entries for '%s'."], removed, seqname))
    end

    -- 2. Re-index Macros array (compact gaps into a clean 1..n sequence)
    if type(seq.Macros) == "table" then
        local oldMacroKeys = {}
        for k in pairs(seq.Macros) do
            if type(k) == "number" and k >= 1 then
                table.insert(oldMacroKeys, k)
            end
        end
        table.sort(oldMacroKeys)

        -- Build old→new index mapping and compacted Macros table
        local macroIndexMap = {}
        local newMacros = {}
        for newIdx, oldIdx in ipairs(oldMacroKeys) do
            macroIndexMap[oldIdx] = newIdx
            newMacros[newIdx] = seq.Macros[oldIdx]
        end
        seq.Macros = newMacros

        -- 3. Re-index Actions arrays within each Macro version
        for _, macroversion in ipairs(seq.Macros) do
            if type(macroversion) == "table" and type(macroversion.Actions) == "table" then
                local oldActKeys = {}
                for k in pairs(macroversion.Actions) do
                    if type(k) == "number" and k >= 1 then
                        table.insert(oldActKeys, k)
                    end
                end
                table.sort(oldActKeys)

                local newActions = {}
                for newIdx, oldIdx in ipairs(oldActKeys) do
                    newActions[newIdx] = macroversion.Actions[oldIdx]
                end
                macroversion.Actions = newActions
            end
        end

        -- 4. Update MetaData context version references using the old→new mapping
        local maxNewIdx = #seq.Macros
        for _, ctxKey in ipairs(seqContextKeys) do
            local val = seq.MetaData[ctxKey]
            if not GSE.isEmpty(val) then
                local oldIdx = tonumber(val)
                if oldIdx then
                    if macroIndexMap[oldIdx] then
                        seq.MetaData[ctxKey] = macroIndexMap[oldIdx]
                    else
                        -- Was pointing to a gap or beyond the end; clamp to max valid index
                        local clamped = maxNewIdx > 0 and maxNewIdx or nil
                        GSE.Print(string.format(
                            L["MetaData.%s remapped from non-existent version %d to %d."],
                            ctxKey, oldIdx, clamped or 0
                        ))
                        seq.MetaData[ctxKey] = clamped
                    end
                end
            end
        end
    end

    -- 5. Save repaired sequence and trigger recompile
    GSE.ReplaceSequence(classlibid, seqname, seq)
    if classlibid == GSE.GetCurrentClassID() or classlibid == 0 then
        GSE.ReloadSequences()
        GSE.Print(string.format(
            L["'%s' has been repaired and queued for recompile.  Leave combat or /reload to apply."],
            seqname
        ))
    else
        GSE.Print(string.format(
            L["'%s' repaired. Sequence is for class %d; button will update when that class is played."],
            seqname, classlibid
        ))
    end
end

--- This creates a pretty export for WLM Forums
function GSE.ExportSequenceHumanReadableFormat(sequence, sequencename)
    local returnstring =
        "# " ..
        sequencename ..
            "\n\n## Talents: " ..
                (GSE.isEmpty(sequence["MetaData"].Talents) and "?,?,?,?,?,?,?" or GSE.Dump(sequence["MetaData"].Talents)) ..
                    "\n\n"
    if not GSE.isEmpty(sequence["MetaData"].Help) then
        returnstring = "\n\n## Usage Information\n" .. sequence["MetaData"].Help .. "\n\n"
    end
    returnstring =
        returnstring ..
        "This macro contains " ..
            (#sequence.Macros > 1 and #sequence.Macros .. " macro templates. " or "1 macro template. ") ..
                string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. "\n\n"
    if (#sequence.Macros > 1) then
        for k, _ in pairs(sequence.Macros) do
            if not GSE.isEmpty(sequence["MetaData"].Default) then
                if sequence["MetaData"].Default == k then
                    returnstring = returnstring .. "- The Default macro template is " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Raid) then
                if sequence["MetaData"].Raid == k then
                    returnstring = returnstring .. "- Raids use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].PVP) then
                if sequence["MetaData"].PVP == k then
                    returnstring = returnstring .. "- PVP uses template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Dungeon) then
                if sequence["MetaData"].Dungeon == k then
                    returnstring = returnstring .. "- Normal Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Heroic) then
                if sequence["MetaData"].Heroic == k then
                    returnstring = returnstring .. "- Heroic Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Mythic) then
                if sequence["MetaData"].Mythic == k then
                    returnstring = returnstring .. "- Mythic Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Arena) then
                if sequence["MetaData"].Arena == k then
                    returnstring = returnstring .. "- Arenas use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Timewalking) then
                if sequence["MetaData"].Timewalking == k then
                    returnstring = returnstring .. "- Timewalking Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].MythicPlus) then
                if sequence["MetaData"].MythicPlus == k then
                    returnstring = returnstring .. "- Mythic+ Dungeons use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Party) then
                if sequence["MetaData"].Party == k then
                    returnstring = returnstring .. "- Open World Parties use template " .. k .. "\n"
                end
            end
            if not GSE.isEmpty(sequence["MetaData"].Scenario) then
                if sequence["MetaData"].Scenario == k then
                    returnstring = returnstring .. "- Scenarios use template " .. k .. "\n"
                end
            end
        end
    end

    return returnstring
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequence(sequence, sequenceName, verbose)
    local returnVal
    if verbose then
        GSE.PrintDebugMessage("ExportSequence Sequence Name: " .. sequenceName, "Storage")
        returnVal = GSE.Dump(GSE.UnEscapeTable(GSE.TranslateSequence(sequence, Statics.TranslatorMode.Current))) .. "\n"
    else
        returnVal =
            GSE.EncodeMessage(
            {sequenceName, GSE.UnEscapeTable(GSE.TranslateSequence(sequence, Statics.TranslatorMode.ID))}
        )
    end

    return returnVal
end

function GSE.PrintGnomeHelp()
    GSE.Print(L["GnomeSequencer was originally written by semlar of wowinterface.com."], GNOME)
    GSE.Print(
        L[
            "GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."
        ],
        GNOME
    )
    GSE.Print(
        L[
            "Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."
        ],
        GNOME
    )
    GSE.Print(
        L[
            "This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."
        ],
        GNOME
    )
    GSE.Print(
        L["To get started "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse cleanorphans|r will loop through your macros and delete any left over GSE macros that no longer have a sequence to match them."
                ],
        GNOME
    )
    GSE.Print(
        L["The command "] ..
            GSEOptions.CommandColour ..
                L[
                    "/gse checksequencesforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."
                ],
        GNOME
    )
end

GSE:RegisterChatCommand("gse", "GSSlash")

-- Functions

--- This function finds a macro by name.  It checks current class first then global
function GSE.FindSequence(sequenceName)
    local returnVal
    if not GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][sequenceName]) then
        returnVal = GSE.Library[GSE.GetCurrentClassID()][sequenceName]
    elseif not GSE.isEmpty(GSE.Library[0][sequenceName]) then
        returnVal = GSE.Library[0][sequenceName]
    end
    if GSE.isEmpty(returnVal) then
        -- Thius is a sequence for another class
        for i = 1, 14, 1 do
            if GSESequences[i] and GSESequences[i][sequenceName] then
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(GSESequences[i][sequenceName])
                if localsuccess then
                    returnVal = uncompressedVersion
                end
            end
        end
    end
    return returnVal
end

--- Handle slash commands
function GSE:GSSlash(input)
    local _, _, currentclassId = UnitClass("player")
    local params = GSE.split(input, " ")
    if #params > 1 then
        input = params[1]
    end
    local command = string.lower(input)
    if command == "showspec" then
        if GSE.GameMode < 7 then
            GSE.Print(L["Your ClassID is "] .. currentclassId .. " " .. Statics.SpecIDList[currentclassId], GNOME)
        else
            local currentSpec = GetSpecialization()
            local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
            local _, specname, _, _, _, _, _ = GetSpecializationInfoByID(currentSpecID)
            GSE.Print(
                L["Your current Specialisation is "] ..
                    currentSpecID .. ":" .. specname .. L["  The Alternative ClassID is "] .. currentclassId,
                GNOME
            )
        end
    elseif command == "help" then
        GSE.PrintGnomeHelp()
    elseif command == "cleanorphans" or command == "clean" then
        GSE.CleanOrphanSequences()
    elseif command == "forceclean" then
        GSE.CleanOrphanSequences()
        GSE.CleanMacroLibrary(true)
        if not InCombatLockdown() then
            if not GSE.isEmpty(GSE_C["KeyBindings"]) then
                for _, specData in pairs(GSE_C["KeyBindings"]) do
                    for key, _ in pairs(specData) do
                        if key ~= "LoadOuts" then SetBinding(key) end
                    end
                    if not GSE.isEmpty(specData["LoadOuts"]) then
                        for _, loadoutData in pairs(specData["LoadOuts"]) do
                            for key, _ in pairs(loadoutData) do SetBinding(key) end
                        end
                    end
                end
            end
            GSE_C["KeyBindings"] = {}
            GSE_C["ActionBarBinds"] = {}
            GSE.ReloadOverrides()
        end
    elseif command == "export" then
        if GSE.Patron then
            GSE.CheckGUI()
            if GSE.UnsavedOptions["GUI"] and GSE.GUIAdvancedExport then
                GSE.GUIAdvancedExport(GSE.GUIExportframe)
                GSE.GUIExportframe:Show()
            end
        end
    elseif command == "showdebugoutput" then
        StaticPopup_Show("GS-DebugOutput")
    elseif command == "record" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUIRecordFrame:Show()
        end
    elseif command == "debug" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUIShowDebugWindow()
        end
    elseif command == "variables" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.ShowVariables()
        end
    elseif command == "resetoptions" then
        GSE.SetDefaultOptions()
        GSE.Print(L["Options have been reset to defaults."])
        StaticPopup_Show("GSE_ConfirmReloadUIDialog")
    elseif command == "movelostmacros" then
        GSE.MoveMacroToClassFromGlobal()
    elseif command == "checksequencesforerrors" then
        GSE.ScanMacrosForErrors()
    elseif command == "compressstring" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUICompressFrame:Show()
        end
    elseif command == "recompilesequences" then
        GSE.ReloadSequences()
    elseif string.lower(command) == "clearoocqueue" then
        GSE.OOCQueue = {}
    elseif string.lower(command) == "import" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.ShowImport()
        end
    elseif string.lower(command) == "bind" then
        -- /gse bind spec sequence key
        local spec = tostring(params[2])
        local sequence = tostring(params[3])
        local physicalkey = tostring(params[4])
        if spec and sequence and physicalkey then
            GSE_C["KeyBindings"][tostring(spec)][physicalkey] = sequence
            GSE.ReloadKeyBindings()
        else
           GSE.Print("Invalid Bind - /gse bind spec sequence key")
        end
    else
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.ShowMenu()
        end
    end
end

local colorTable = {}

local tokens = IndentationLib.tokens

colorTable[tokens.TOKEN_SPECIAL] = GSEOptions.WOWSHORTCUTS
colorTable[tokens.TOKEN_KEYWORD] = GSEOptions.KEYWORD
colorTable[tokens.TOKEN_UNKNOWN] = GSEOptions.UNKNOWN
colorTable[tokens.TOKEN_COMMENT_SHORT] = GSEOptions.COMMENT
colorTable[tokens.TOKEN_COMMENT_LONG] = GSEOptions.COMMENT

local stringColor = GSEOptions.NormalColour
colorTable[tokens.TOKEN_STRING] = stringColor
colorTable[".."] = stringColor

local tableColor = GSEOptions.CONCAT
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = GSEOptions.STRING
colorTable["]"] = GSEOptions.STRING

local arithmeticColor = GSEOptions.NUMBER
colorTable[tokens.TOKEN_NUMBER] = arithmeticColor
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor

local logicColor1 = GSEOptions.EQUALS
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1

local logicColor2 = GSEOptions.EQUALS
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2

local castColor = GSEOptions.UNKNOWN
colorTable["/cast"] = castColor

colorTable[0] = "|r"

Statics.IndentationColorTable = colorTable

GSE.Utils = true

local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

--- Delete a sequence starting with the macro and then the sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
    GSE.DeleteMacroStub(sequenceName)
    GSE.Library[tonumber(classid)][sequenceName] = nil
    GSE3Storage[tonumber(classid)][sequenceName] = nil
end

function GSE.ImportLegacyStorage(Library)
    if GSE.isEmpty(GSE3Storage) then
        GSE3Storage = {}
    end
    for i = 0, 13 do
        if GSE.isEmpty(GSE3Storage[i]) then
            GSE3Storage[i] = {}
        end
    end

    if not GSE.isEmpty(Library) then
        for k, v in pairs(Library) do
            for i, j in pairs(v) do
                local compressedVersion = GSE.EncodeMessage({i, j})
                GSE3Storage[k][i] = compressedVersion
            end
        end
    end
    GSELegacyLibraryBackup = GSELibrary
    GSELibrary = nil
end

function GSE.CloneSequence(orig, keepcomments)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[GSE.CloneSequence(orig_key)] = GSE.CloneSequence(orig_value)
        end
        setmetatable(copy, GSE.CloneSequence(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    -- if not GSE.isEmpty(keepcomments) then
    --     for k,v in ipairs(copy.Macros) do
    --         -- TODO Strip COmments
    --     end
    -- end
    return copy
end

--- Add a sequence to the library
function GSE.AddSequenceToCollection(sequenceName, sequence, classid)
    local vals = {}
    vals.action = "Save"
    vals.sequencename = sequenceName
    vals.sequence = sequence
    vals.classid = classid
    table.insert(GSE.OOCQueue, vals)
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
    sequenceName = string.upper(sequenceName)

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
end

function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
    local vals = {}
    vals.action = "MergeSequence"
    vals.sequencename = sequenceName
    vals.newSequence = newSequence
    vals.classid = classid
    vals.mergeaction = action
    table.insert(GSE.OOCQueue, vals)
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
        GSE3Storage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
    elseif action == "REPLACE" then
        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSE.PrintDebugMessage("About to encode: Sequence " .. sequenceName)
        GSE.PrintDebugMessage(" New Entry: " .. GSE.Dump(GSE.Library[classid][sequenceName]), "Storage")
        GSE3Storage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
        GSE.Print(sequenceName .. L[" was updated to new version."], "GSE Storage")
    elseif action == "RENAME" then
        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSE3Storage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
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
    if GSE.GUI then
        local event = {}
        event.action = "openviewer"
        table.insert(GSE.OOCQueue, event)
    end
end

--- Load a collection of Sequences
function GSE.ImportMacroCollection(Sequences)
    for k, v in pairs(Sequences) do
        GSE.AddSequenceToCollection(k, v)
    end
end

--- Replace a current version of a Macro
function GSE.ReplaceMacro(classid, sequenceName, sequence)
    GSE3Storage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
    GSE.Library[classid][sequenceName] = sequence
end

--- Load the GSEStorage into a new table.
function GSE.LoadStorage(destination)
    if GSE.isEmpty(destination) then
        destination = {}
    end
    if GSE.isEmpty(GSE3Storage) then
        GSE3Storage = {}
        for iind = 0, 13 do
            GSE3Storage[iind] = {}
        end
    end
    for k, v in ipairs(GSE3Storage) do
        if GSE.isEmpty(destination[k]) then
            destination[k] = {}
        end
        for i, j in pairs(v) do
            local status, err =
                pcall(
                function()
                    local localsuccess, uncompressedVersion = GSE.DecodeMessage(j)
                    destination[k][i] = uncompressedVersion[2]
                end
            )
            if err then
                GSE.Print(
                    "There was an error processing " ..
                        i .. ", You will need to reimport this macro from another source.",
                    err
                )
            end
        end
    end
end

--- Load a collection of Sequences
function GSE.ImportCompressedMacroCollection(Sequences)
    for _, v in ipairs(Sequences) do
        GSE.ImportSerialisedSequence(v)
    end
end
--- Return the Active Sequence Version for a Sequence.
function GSE.GetActiveSequenceVersion(sequenceName)
    local classid = GSE.GetCurrentClassID()
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][sequenceName]) then
        classid = 0
    end
    -- Set to default or 1 if no default
    local vers = 1
    if GSE.isEmpty(GSE.Library[classid][sequenceName]) then
        return
    end
    if not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Default) then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Default
    end
    if not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Scenario) and GSE.inScenario then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Scenario
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Arena) and GSE.inArena then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Arena
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].PVP) and GSE.inArena then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Arena
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].PVP) and GSE.PVPFlag then
        vers = GSE.Library[classid][sequenceName]["MetaData"].PVP
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Raid) and GSE.inRaid then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Raid
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Mythic) and GSE.inMythic then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Mythic
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].MythicPlus) and GSE.inMythicPlus then
        vers = GSE.Library[classid][sequenceName]["MetaData"].MythicPlus
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Heroic) and GSE.inHeroic then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Heroic
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Dungeon) and GSE.inDungeon then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Dungeon
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Timewalking) and GSE.inTimeWalking then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Timewalking
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Party) and GSE.inParty then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Party
    end
    if vers == 0 then
        vers = 1
    end
    return vers
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

--- Load a serialised Sequence
function GSE.ImportSerialisedSequence(importstring, createicon)
    local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    GSE.PrintDebugMessage(string.format("Decomsuccess: %s ", tostring(decompresssuccess)), Statics.SourceTransmission)
    if
        (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and
            (type(actiontable[2]) == "table")
     then
        GSE.PrintDebugMessage(
            string.format(
                "tablerows: %s   type cell1 %s cell2 %s",
                table.getn(actiontable),
                type(actiontable[1]),
                type(actiontable[2])
            ),
            Statics.SourceTransmission
        )
        local seqName = string.upper(actiontable[1])
        GSE.AddSequenceToCollection(seqName, actiontable[2])
        if createicon then
            GSE.CheckMacroCreated(seqName, true)
        end
    else
        GSE.Print(L["Unable to interpret sequence."], GNOME)
        decompresssuccess = false
    end

    return decompresssuccess
end

function GSE.ReloadSequences()
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) then
        GSE.PerformReloadSequences()
        GSE.UnsavedOptions.ReloadQueued = true
    end
end

function GSE.PerformReloadSequences()
    GSE.PrintDebugMessage("Reloading Sequences", Statics.DebugModules["Storage"])

    for name, sequence in pairs(GSE.Library[GSE.GetCurrentClassID()]) do
        -- check that the macro exists.  This will cause an issue if people are calling macros that are in GSE but there is no macro stub made.
        local sequenceIndex = GetMacroIndexByName(name)
        if sequenceIndex > 0 then
            GSE.UpdateSequence(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
        end
    end
    if GSEOptions.CreateGlobalButtons then
        if not GSE.isEmpty(GSE.Library[0]) then
            for name, sequence in pairs(GSE.Library[0]) do
                -- check that the macro exists.  This will cause an issue if people are calling macros that are in GSE but there is no macro stub made.
                local sequenceIndex = GetMacroIndexByName(name)
                if sequenceIndex > 0 then
                    GSE.UpdateSequence(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
                end
            end
        end
    end
    local vals = {}
    vals.action = "FinishReload"
    table.insert(GSE.OOCQueue, vals)
end

function GSE.PrepareLogout(deletenonlocalmacros)
    GSE.CleanMacroLibrary(deletenonlocalmacros)
    if GSEOptions.deleteOrphansOnLogout then
        GSE.CleanOrphanSequences()
    end
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

--- This function is used to clean the local sequence library
function GSE.CleanMacroLibrary(forcedelete)
    -- Clean out the sequences database except for the current version
    if forcedelete then
        GSE3Storage[GSE.GetCurrentClassID()] = nil
        GSE3Storage[GSE.GetCurrentClassID()] = {}
        GSE.Library[GSE.GetCurrentClassID()] = nil
        GSE.Library[GSE.GetCurrentClassID()] = {}
    end
end

--- This function resets a gsebutton back to its initial setting
function GSE.ResetButtons()
    for k, _ in pairs(GSE.UsedSequences) do
        local gsebutton = _G[k]
        if gsebutton:GetAttribute("combatreset") == true then
            gsebutton:SetAttribute("step", 1)
            GSE.UpdateIcon(gsebutton, true)
            GSE.UsedSequences[k] = nil
        end
    end
end

--- This functions schedules an update to a sequence in the OOCQueue.
function GSE.UpdateSequence(name, sequence)
    local vals = {}
    vals.action = "UpdateSequence"
    vals.name = name
    vals.macroversion = sequence
    table.insert(GSE.OOCQueue, vals)
end

--- This function updates the button for an existing sequence.  It is called from the OOC queue
function GSE.OOCUpdateSequence(name, sequence)
    if GSE.isEmpty(sequence) then
        return
    end
    if GSE.isEmpty(name) then
        return
    end
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][name]) and GSE.isEmpty(GSE.Library[0][name]) then
        return
    end

    local combatReset = false
    if GSE.isEmpty(sequence.InbuiltVariables) then
        sequence.InbuiltVariables = {["Combat"] = false}
    end
    if sequence.InbuiltVariables.Combat or GSE.GetResetOOC() then
        combatReset = true
    end

    local compiledTemplate = GSE.CompileTemplate(sequence)
    local actionCount = table.getn(compiledTemplate)
    if actionCount > 255 then
        GSE.Print(
            string.format(
                L[
                    "%s macro may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this macro."
                ],
                name,
                actionCount
            ),
            "MACRO ERROR"
        )
    end
    GSE.CreateGSE3Button(compiledTemplate, name, combatReset)
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

--- Return whether to store the macro in Personal Character Macros or Account Macros
function GSE.SetMacroLocation()
    local numAccountMacros, numCharacterMacros = GetNumMacros()
    local returnval = 1
    if numCharacterMacros >= MAX_CHARACTER_MACROS - 1 and GSEOptions.overflowPersonalMacros then
        returnval = nil
    end
    return returnval
end

function GSE.CreateMacroString(macroname)
    local returnVal = "#showtooltip\n/click "
    local state = GSE.GetMacroStringFormat()
    local t = state == "DOWN" and "t" or "f"

    if GSE.GetMacroStringFormat() == "DOWN" or GSEOptions.MacroResetModifiers["LeftButton"] then
        returnVal = returnVal .. "[button:1] " .. macroname .. " LeftButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["RightButton"] then
        returnVal = returnVal .. "[button:2] " .. macroname .. " RightButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["MiddleButton"] then
        returnVal = returnVal .. "[button:3] " .. macroname .. " MiddleButton " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["Button4"] then
        returnVal = returnVal .. "[button:4] " .. macroname .. " Button4 " .. t .. "; "
    end
    if GSEOptions.MacroResetModifiers["Button5"] then
        returnVal = returnVal .. "[button:5] " .. macroname .. " Button5 " .. t .. "; "
    end
    if GSEOptions.virtualButtonSupport then
        returnVal = returnVal .. "[nobutton:1] " .. macroname .. "; "
    end

    returnVal = returnVal .. macroname
    return returnVal
end

function GSE.UpdateMacroString()
    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    for macid = 1, maxmacros do
        local mname, _, _ = GetMacroInfo(macid)
        if not GSE.isEmpty(mname) then
            if not GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][mname]) then
                EditMacro(macid, nil, nil, GSE.CreateMacroString(mname))
                GSE.PrintDebugMessage(string.format("Updating macro %s to %s", mname, GSE.CreateMacroString(mname)))
            end
            if not GSE.isEmpty(GSE.Library[0]) then
                if not GSE.isEmpty(GSE.Library[0][mname]) then
                    EditMacro(macid, nil, nil, GSE.CreateMacroString(mname))
                    GSE.PrintDebugMessage(string.format("Updating macro %s to %s", mname, GSE.CreateMacroString(mname)))
                end
            end
        end
    end
end

--- Add a Create Macro to the Out of Combat Queue
function GSE.CheckMacroCreated(SequenceName, create)
    local vals = {}
    vals.action = "CheckMacroCreated"
    vals.sequencename = SequenceName
    vals.create = create
    table.insert(GSE.OOCQueue, vals)
end

--- Check if a macro has been created and if the create flag is true and the macro hasn't been created, then create it.
function GSE.OOCCheckMacroCreated(SequenceName, create)
    local found = false

    local macroIndex = GetMacroIndexByName(SequenceName)
    if macroIndex and macroIndex ~= 0 then
        found = true
        if create then
            EditMacro(macroIndex, nil, nil, GSE.CreateMacroString(SequenceName))
        end
    else
        if create then
            GSE.CreateMacroIcon(SequenceName, Statics.QuestionMark)
            found = true
        end
    end
    return found
end

--- This removes a macro Stub.
function GSE.DeleteMacroStub(sequenceName)
    local mname, _, mbody = GetMacroInfo(sequenceName)
    if mname == sequenceName then
        local trimmedmbody = mbody:gsub("[^%w ]", "")
        local compar = GSE.CreateMacroString(mname)
        local trimmedcompar = compar:gsub("[^%w ]", "")
        if string.lower(trimmedmbody) == string.lower(trimmedcompar) then
            GSE.Print(L[" Deleted Orphaned Macro "] .. mname, GNOME)
            DeleteMacro(sequenceName)
        end
    end
end

--- This returns a list of Sequence Names for the current spec
function GSE.GetSequenceNames(Library)
    if not Library then
        Library = GSE.Library
    end
    local keyset = {}
    for k, _ in pairs(Library) do
        if GSE.isEmpty(GSEOptions.filterList) then
            GSEOptions.filterList = {}
            GSEOptions.filterList[Statics.Spec] = true
            GSEOptions.filterList[Statics.Class] = true
            GSEOptions.filterList[Statics.All] = false
            GSEOptions.filterList[Statics.Global] = true
        end
        if GSEOptions.filterList[Statics.All] or k == GSE.GetCurrentClassID() then
            for i, j in pairs(Library[k]) do
                local disable = 0
                if j.DisableEditor then
                    disable = 1
                end
                local keyLabel = k .. "," .. i .. "," .. disable
                if k == GSE.GetCurrentClassID() and GSEOptions.filterList["Class"] then
                    keyset[keyLabel] = i
                elseif k == GSE.GetCurrentClassID() and not GSEOptions.filterList["Class"] then
                    if j.MetaData.SpecID == GSE.GetCurrentSpecID() or j.MetaData.SpecID == GSE.GetCurrentClassID() then
                        keyset[keyLabel] = i
                    end
                else
                    keyset[keyLabel] = i
                end
            end
        else
            if k == 0 and GSEOptions.filterList[Statics.Global] then
                for i, j in pairs(Library[k]) do
                    local disable = 0
                    if j.DisableEditor then
                        disable = 1
                    end
                    local keyLabel = k .. "," .. i .. "," .. disable
                    keyset[keyLabel] = i
                end
            end
        end
    end

    return keyset
end

--- Return the Macro Icon for the specified Sequence
function GSE.GetMacroIcon(classid, sequenceIndex)
    classid = tonumber(classid)
    GSE.PrintDebugMessage("sequenceIndex: " .. (GSE.isEmpty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
    classid = tonumber(classid)
    local macindex = GetMacroIndexByName(sequenceIndex)
    local a, iconid, c = GetMacroInfo(macindex)
    if not GSE.isEmpty(a) then
        GSE.PrintDebugMessage(
            "Macro Found " ..
                a ..
                    " with iconid " ..
                        (GSE.isEmpty(iconid) and "of no value" or iconid) ..
                            " " .. (GSE.isEmpty(iconid) and L["with no body"] or c),
            GNOME
        )
    else
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        return GSEOptions.DefaultDisabledMacroIcon
    end

    local sequence = GSE.Library[classid][sequenceIndex]
    if GSE.isEmpty(sequence) then
        GSE.PrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex, GNOME)
        return GSEOptions.DefaultDisabledMacroIcon
    end
    if GSE.isEmpty(sequence.Icon) and GSE.isEmpty(iconid) then
        GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.Metadata.SpecID, GNOME)
        if sequence.Metadata.SpecID == 0 then
            return "INV_MISC_QUESTIONMARK"
        else
            local _, _, _, specicon, _, _, _ =
                GetSpecializationInfoByID(
                (GSE.isEmpty(sequence.Metadata.SpecID) and GSE.GetCurrentSpecID() or sequence.Metadata.SpecID)
            )
            GSE.PrintDebugMessage("No Sequence Icon setting to " .. strsub(specicon, 17), GNOME)
            return strsub(specicon, 17)
        end
    elseif GSE.isEmpty(iconid) and not GSE.isEmpty(sequence.Icon) then
        return sequence.Icon
    else
        return iconid
    end
end

--- Load in the sample macros for the current class.
function GSE.LoadSampleMacros(classID)
    if not GSE.isEmpty(Statics.SampleMacros[classID]) then
        GSE.ImportCompressedMacroCollection(Statics.SampleMacros[classID])
        GSE.Print(L["The Sample Macros have been reloaded."])
    else
        GSE.Print(L["No Sample Macros are available yet for this class."])
    end
end

function GSE.UpdateIcon(self, reset)
    local step = self:GetAttribute("step") or 1
    local gsebutton = self:GetName()
    local executionseq = GSE.SequencesExec[gsebutton]
    local commandline, foundSpell, notSpell = executionseq[step], false, ""
    for cmd, etc in gmatch(commandline or "", "/(%w+)%s+([^\n]+)") do
        if Statics.CastCmds[strlower(cmd)] or strlower(cmd) == "castsequence" then
            local spell, target = SecureCmdOptionParse(etc)
            if not reset then
                GSE.TraceSequence(gsebutton, step, spell)
            end
            if spell then
                if GetSpellInfo(spell) then
                    SetMacroSpell(gsebutton, spell, target)
                    foundSpell = true
                    break
                elseif notSpell == "" then
                    notSpell = spell
                end
            end
            if strlower(cmd) == "castsequence" then
                local index, csitem, csspell = QueryCastSequence(etc)
                if not GSE.isEmpty(csitem) then
                    SetMacroSpell(gsebutton, csitem, target)
                    foundSpell = true
                end
                if not GSE.isEmpty(csspell) then
                    SetMacroSpell(gsebutton, csspell, target)
                    foundSpell = true
                end
            end
        end
    end
    if not foundSpell then
        SetMacroItem(gsebutton, notSpell)
    end
    if not reset then
        GSE.UsedSequences[gsebutton] = true
    end
end

--- Takes a collection of Sequences and returns a list of names
function GSE.GetSequenceNamesFromLibrary(library)
    local sequenceNames = {}
    for k, _ in pairs(library) do
        table.insert(sequenceNames, k)
    end
    return sequenceNames
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

--- This function returns in addition to the stepfunction for the KeyBind to Reset a sequence
function GSE.GetMacroResetImplementation()
    local activemods = {}
    local returnstring = ""
    local flagactive = false

    -- Extra null check just in case.
    if GSE.isEmpty(GSEOptions.MacroResetModifiers) then
        GSE.resetMacroResetModifiers()
    end

    for k, v in pairs(GSEOptions.MacroResetModifiers) do
        if v == true then
            flagactive = true
            if string.find(k, "Button") then
                table.insert(activemods, 'GetMouseButtonClicked() == "' .. k .. '"')
            else
                table.insert(activemods, "Is" .. k .. "KeyDown() == true")
            end
        end
    end
    if flagactive then
        returnstring = string.format(Statics.MacroResetSkeleton, table.concat(activemods, " and "))
    end
    return returnstring
end

--- This function finds a macro by name.  It checks current class first then global
function GSE.FindMacro(sequenceName)
    local returnVal = {}
    if not GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][sequenceName]) then
        returnVal = GSE.Library[GSE.GetCurrentClassID()][sequenceName]
    elseif not GSE.isEmpty(GSE.Library[0][sequenceName]) then
        returnVal = GSE.Library[0][sequenceName]
    end
    return returnVal
end

--- This function scans all macros in the library and reports on corrupt macros.
function GSE.ScanMacrosForErrors()
    for classlibid, classlib in ipairs(GSE.Library) do
        for seqname, seq in pairs(classlib) do
            for macroversionid, macroversion in ipairs(seq) do
                local status, error = pcall(GSE.CheckSequence, macroversion)
                if not status then
                    GSE.Print(string.format(L["Error found in version %i of %s."], macroversionid, seqname), "Error")
                    GSE.Print(
                        string.format(
                            L[
                                "To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"
                            ],
                            GSEOptions.CommandColour,
                            classlibid,
                            seqname,
                            Statics.StringReset
                        )
                    )
                end
            end
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
    GSE.Print(L["Finished scanning for errors.  If no other messages then no errors were found."])
end

--- This function takes a text string and compresses it without loading it to the library
function GSE.CompressSequenceFromString(importstring)
    local importStr = GSE.StripControlandExtendedCodes(importstring)
    local returnstr = ""
    local functiondefinition = GSE.FixQuotes(importStr) .. [===[
  return Sequences
  ]===]

    local fake_globals =
        setmetatable(
        {
            Sequences = {}
        },
        {
            __index = _G
        }
    )
    local func, err = loadstring(functiondefinition, "Storage")
    if func then
        -- Make the compiled function see this table as its "globals"
        setfenv(func, fake_globals)

        local TempSequences = assert(func())
        if not GSE.isEmpty(TempSequences) then
            for k, v in pairs(TempSequences) do
                returnstr = GSE.ExportSequence(v, k, false, "ID", false)
            end
        end
    end
    return returnstr
end

--- This function takes a text string and decompresses it without loading it to the library
function GSE.DecompressSequenceFromString(importstring)
    local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    local returnstr = ""
    local seqName = ""
    if
        (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and
            (type(actiontable[2]) == "table")
     then
        seqName = string.upper(actiontable[1])
        returnstr = GSE.Dump(actiontable[2])
    end
    return returnstr, seqName, decompresssuccess
end

--- This function allows the player to toggle Target Protection from the LDB Plugin.
function GSE.ToggleTargetProtection()
    if GSE.isEmpty(GSE.GetRequireTarget()) then
        GSE.SetRequireTarget(true)
    else
        GSE.SetRequireTarget(false)
    end
    GSE.ReloadSequences()
end

--- This creates a pretty export for WLM Forums
function GSE.ExportSequenceWLMFormat(sequence, sequencename)
    local returnstring =
        "# " ..
        sequencename ..
            "\n\n## Talents: " ..
                (GSE.isEmpty(sequence["MetaData"].Talents) and "?,?,?,?,?,?,?" or sequence["MetaData"].Talents) ..
                    "\n\n"
    if not GSE.isEmpty(sequence["MetaData"].Help) then
        returnstring = "\n\n## Usage Information\n" .. sequence["MetaData"].Help .. "\n\n"
    end
    returnstring =
        returnstring ..
        "This macro contains " ..
            (table.getn(sequence.Macros) > 1 and table.getn(sequence.Macros) .. " macro templates. " or
                "1 macro template. ") ..
                string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. "\n\n"
    if (table.getn(sequence.Macros) > 1) then
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

function GSE.GetSequenceSummary()
    local returntable = {}
    for k, v in ipairs(GSE.Library) do
        returntable[k] = {}
        for i, j in pairs(v) do
            returntable[k][i] = {}
            returntable[k][i].Help = j["MetaData"].Help
            returntable[k][i].LastUpdated = j["MetaData"].LastUpdated
        end
    end
    return returntable
end

local function fixLine(line, KeyPress, KeyRelease)
    local action = {}
    action["Type"] = Statics.Actions.Action
    if KeyPress then
        -- print("KeyPress false")
        table.insert(action, [[~~KeyPress~~]])
    end
    table.insert(action, line)
    if KeyRelease then
        -- print("KeyRelease false")
        table.insert(action, [[~~KeyRelease~~]])
    end

    if string.sub(line, 1, 13) == "/click pause" then
        action = {}
        action["Type"] = Statics.Actions.Pause
        if string.sub(line, 14) == "~~GCD~~" then
            action["MS"] = GSE.GetGCD() * 1000
        else
            local mynumber = tonumber(string.sub(line, 14))

            if GSE.isEmpty(mynumber) then
                action["MS"] = 10
                GSE.Print(L["Error processing Custom Pause Value.  You will need to recheck your macros."], "Storage")
            else
                action["MS"] = tonumber(string.sub(line, 14)) * 1000
            end
        end
    end
    return action
end

local function buildAction(action, metaData, variables)
    if action.Type == Statics.Actions.Loop then
        -- we have a loop within a loop
        return GSE.processAction(action, metaData, variables)
    else
        if GSE.GetRequireTarget() then
            -- See #20 prevent target hopping
            table.insert(action, 1, "/stopmacro [@playertarget, noexists]")
        end

        for k, v in ipairs(action) do
            action[k] = GSE.TranslateString(v, "STRING", nil, true)
        end

        if not GSE.isEmpty(metaData) then
            if metaData.Ring1 or (metaData.Ring1 == nil and GSE.GetUse11()) then
                table.insert(action, "/use [combat,nochanneling] 11")
            end
            if metaData.Ring2 or (metaData.Ring2 == nil and GSE.GetUse12()) then
                table.insert(action, "/use [combat,nochanneling] 12")
            end
            if metaData.Trinket1 or (metaData.Trinket1 == nil and GSE.GetUse13()) then
                table.insert(action, "/use [combat,nochanneling] 13")
            end
            if metaData.Trinket2 or (metaData.Trinket2 == nil and GSE.GetUse14()) then
                table.insert(action, "/use [combat,nochanneling] 14")
            end
            if metaData.Neck or (metaData.Neck == nil and GSE.GetUse2()) then
                table.insert(action, "/use [combat,nochanneling] 2")
            end
            if metaData.Head or (metaData.Head == nil and GSE.GetUse1()) then
                table.insert(action, "/use [combat,nochanneling] 1")
            end
            if metaData.Belt or (metaData.Belt == nil and GSE.GetUse6()) then
                table.insert(action, "/use [combat,nochanneling] 6")
            end
        end
        if GSEOptions.hideUIErrors then
            table.insert(action, "/script UIErrorsFrame:Hide();")
        -- Potentially change this to UIErrorsFrame:Hide()
        end
        if GSEOptions.clearUIErrors then
            -- Potentially change this to UIErrorsFrame:Clear()
            table.insert(action, "/run UIErrorsFrame:Clear()")
        end

        return GSE.SafeConcat(action, "\n")
    end
end

local function processRepeats(actionList)
    local inserts = {}
    local removes = {}
    for k, v in ipairs(actionList) do
        if type(v) == "table" then
            table.insert(inserts, {Action = v.Action, Interval = v.Interval, Start = k})
            table.insert(removes, k)
        end
    end

    for i = #removes, 1, -1 do
        table.remove(actionList, removes[i])
    end

    for _, v in ipairs(inserts) do
        local startInterval = v["Interval"]
        if startInterval == 1 then
            startInterval = 2
        end
        local insertcount = math.ceil((#actionList - v["Start"]) / startInterval)
        insertcount = math.ceil((#actionList + insertcount - v["Start"]) / startInterval)
        local interval = v["Interval"]
        table.insert(actionList, v["Start"], v["Action"])
        for i = 1, insertcount do
            local insertpos = v["Start"] + i * interval
            table.insert(actionList, insertpos, v["Action"])
        end
    end
    return actionList
end

function GSE.processAction(action, metaData, variables)
    if action.Disabled then
        return
    end
    if action.Type == Statics.Actions.Loop then
        local actionList = {}
        -- setup the interation
        for id, v in ipairs(action) do
            local builtaction = GSE.processAction(v, metaData, variables)
            if type(builtaction) == "table" and GSE.isEmpty(builtaction.Interval) then
                for _, j in ipairs(builtaction) do
                    table.insert(actionList, j)
                end
            elseif type(builtaction) == "table" and builtaction.Interval then
                builtaction.Action = GSE.ProcessLoopVariables(builtaction.Action, id)
                table.insert(actionList, builtaction)
            else
                if builtaction then
                    builtaction = GSE.ProcessLoopVariables(builtaction, id)
                end
                table.insert(actionList, builtaction)
            end
        end
        local returnActions = {}
        local loop = tonumber(action.Repeat)
        if GSE.isEmpty(loop) or loop < 1 then
            loop = 1
        end
        for _ = 1, loop do
            if action.StepFunction == Statics.Priority or action.StepFunction == Statics.ReversePriority then
                local limit = 1
                local step = 1
                local looplimit = 0
                for x = 1, table.getn(actionList) do
                    looplimit = looplimit + x
                end
                if action.StepFunction == Statics.Priority then
                    for _ = 1, looplimit do
                        table.insert(returnActions, actionList[step])
                        if step == limit then
                            limit = limit % #actionList + 1
                            step = 1
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                        else
                            step = step + 1
                        end
                    end
                else
                    for _ = looplimit, 1, -1 do
                        table.insert(returnActions, actionList[step])
                        if step == 1 then
                            limit = limit % #actionList + 1
                            step = limit
                            GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                        else
                            step = step - 1
                        end
                    end
                end
            elseif action.StepFunction == Statics.Random then
                for _ = 1, #actionList do
                    local randomAction = math.random(1, #actionList)
                    table.insert(returnActions, actionList[randomAction])
                    table.remove(actionList, randomAction)
                end
            else
                for _, v in ipairs(actionList) do
                    table.insert(returnActions, v)
                end
            end
        end

        -- process repeats for the block
        return processRepeats(returnActions)
    elseif action.Type == Statics.Actions.Pause then
        local PauseActions = {}
        local clicks = action.Clicks and action.Clicks or 0
        if not GSE.isEmpty(action.Variable) then
            if action.Variable == "GCD" then
                clicks = GSE.GetGCD() * 1000 / GSE.GetClickRate()
            else
                local funcline = GSE.RemoveComments(variables[action.Variable])

                funcline = string.sub(table.concat(funcline, "\n"), 11)
                funcline = funcline:sub(1, -4)
                funcline = loadstring(funcline)
                local value
                if funcline ~= nil then
                    value = funcline
                    value = value()
                end
                clicks = tonumber(value) / GSE.GetClickRate()
            end
        elseif not GSE.isEmpty(action.MS) then
            if action.MS == "GCD" or action.MS == "~~GCD~~" then
                clicks = GSE.GetGCD() * 1000 / GSE.GetClickRate()
            else
                clicks = action.MS and action.MS and 1000 -- pause for 1 second if no ms specified.
                clicks = math.ceil(clicks / GSE.GetClickRate())
            end
        end
        if clicks > 1 then
            for loop = 1, clicks do
                table.insert(PauseActions, "/click GSE.Pause")
                GSE.PrintDebugMessage(loop, "Storage1")
            end
        end
        -- print(#PauseActions, GSE.Dump(action))
        return PauseActions
    elseif action.Type == Statics.Actions.Repeat then
        if GSE.isEmpty(action.Interval) then
            if not GSE.isEmpty(action.Repeat) then
                action.Interval = action.Repeat
                action.Repeat = nil
            else
                action.Interval = 2
            end
        end
        local returnAction = {
            ["Action"] = buildAction(action, metaData),
            ["Interval"] = action.Interval
        }
        return returnAction
    elseif action.Type == Statics.Actions.If then
        if GSE.isEmpty(action.Variable) then
            GSE.Print(L["If Blocks Require a variable."], L["Macro Compile Error"])
            return
        end

        local funcline = GSE.RemoveComments(variables[action.Variable])

        funcline = string.sub(funcline, 11)
        funcline = funcline:sub(1, -4)
        funcline = loadstring(funcline)
        local value
        if funcline ~= nil then
            value = funcline
            value = value()
        end

        local actions
        if type(value) == "boolean" then
            if value == true then
                actions = action[1]
            else
                actions = action[2]
            end
        else
            GSE.Print(
                string.format(
                    L["Boolean not found.  There is a problem with %s not returning true or false."],
                    action.Variable
                ),
                L["Macro Compile Error"]
            )
            return
        end

        local actionList = {}
        for _, v in ipairs(actions) do
            local builtaction = GSE.processAction(v, metaData, variables)
            if type(builtaction) == "table" and GSE.isEmpty(builtaction.Interval) then
                for _, j in ipairs(builtaction) do
                    table.insert(actionList, j)
                end
            else
                table.insert(actionList, builtaction)
            end
        end

        -- process repeats for the block
        return processRepeats(actionList)
    elseif action.Type == Statics.Actions.Action then
        return buildAction(action, metaData)
    end
end

--- Compiles a macro template into a macro
function GSE.CompileTemplate(macro)
    if #macro.Actions < 1 then
        -- return early nothing to compile
        return {}
    end
    -- print(#macro.Actions)
    local template = GSE.CloneSequence(macro)
    setmetatable(
        template.Actions,
        {
            __index = function(t, k)
                for _, v in ipairs(k) do
                    if not t then
                        error("attempt to index nil")
                    end
                    t = rawget(t, v)
                end
                return t
            end,
            __newindex = function(t, key, v)
                local last_k
                for _, k in ipairs(key) do
                    k, last_k = last_k, k
                    if k ~= nil then
                        local parent_t = t
                        t = rawget(parent_t, k)
                        if t == nil then
                            t = {}
                            rawset(parent_t, k, t)
                        end
                        if type(t) ~= "table" then
                            error("Unexpected subtable", 2)
                        end
                    end
                end
                rawset(t, last_k, v)
            end
        }
    )

    local actions = {
        ["Type"] = "Loop",
        ["Repeat"] = "1"
    }
    for _, action in ipairs(template.Actions) do
        table.insert(actions, GSE.TranslateSequence(action, Statics.TranslatorMode.String, true))
    end
    local compiledMacro = GSE.processAction(actions, template.InbuiltVariables, template.Variables)

    local variables = {}

    for k, v in pairs(template.Variables) do
        if type(v) == "table" then
            for i, j in ipairs(v) do
                template.Variables[k][i] = GSE.TranslateString(j, Statics.TranslatorMode.String, nil, true)
            end
            variables[k] = GSE.RemoveComments(template.Variables[k])
        end
    end

    return GSE.UnEscapeTable(GSE.ProcessVariables(compiledMacro, variables)), template
end

local function PCallCreateGSE3Button(macro, name, combatReset)
    if GSE.isEmpty(macro) then
        print("Macro missing for ", name)
        return
    end
    if GSE.isEmpty(combatReset) then
        combatReset = false
    end

    -- name = name .. "T"
    GSE.SequencesExec[name] = macro

    -- if button already exists no need to recreate it.  Maybe able to create this in combat.
    if GSE.isEmpty(_G[name]) then
        local gsebutton = CreateFrame("Button", name, nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        gsebutton:SetAttribute("type", "macro")
        gsebutton:SetAttribute("step", 1)
        gsebutton.UpdateIcon = GSE.UpdateIcon
        gsebutton:RegisterForClicks("AnyUp", "AnyDown")
        gsebutton:SetAttribute("combatreset", combatReset)

        local stepfunction =
            (GSEOptions.DebugPrintModConditionsOnKeyPress and Statics.PrintKeyModifiers or "") ..
            GSE.GetMacroResetImplementation() .. Statics.GSE3OnClick
        gsebutton:WrapScript(gsebutton, "OnClick", stepfunction)
    end
    _G[name]:Execute(
        "name, macros = self:GetName(), newtable([=======[" ..
            strjoin("]=======],[=======[", unpack(macro)) .. "]=======])"
    )
    if combatReset then
        _G[name]:SetAttribute("step", 1)
    end
    GSE.UpdateIcon(_G[name], true)
end

--- Build GSE3 Executable Buttons
function GSE.CreateGSE3Button(macro, name, combatReset)
    local status, err = pcall(PCallCreateGSE3Button, macro, name, combatReset)
    if err or not status then
        GSE.Print(
            string.format(
                "%s " ..
                    L["was unable to be programmed.  This macro will not fire until errors in the macro are corrected."],
                name
            ),
            "BROKEN MACRO"
        )
    end
end

--- Creates a string representation of the a Sequence that can be shared as a string.
--      Accepts a <code>sequence table</code> and a <code>SequenceName</code>
function GSE.ExportSequence(sequence, sequenceName, verbose)
    local returnVal
    if verbose then
        GSE.PrintDebugMessage("ExportSequence Sequence Name: " .. sequenceName, "Storage")
        returnVal = GSE.Dump(GSE.TranslateSequence(sequence, Statics.TranslatorMode.Current)) .. "\n"
    else
        returnVal = GSE.EncodeMessage({sequenceName, sequence})
    end

    return returnVal
end

GSE.DebugProfile("Storage")

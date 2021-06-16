local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

--- Delete a sequence starting with the macro and then the sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
    GSE.DeleteMacroStub(sequenceName)
    GSE.Library[tonumber(classid)][sequenceName] = nil
    GSEStorage[tonumber(classid)][sequenceName] = nil
end

function GSE.ImportLegacyStorage(Library)
    if GSE.isEmpty(GSEStorage) then
        GSEStorage = {}
    end
    for i = 0, 12 do
        if GSE.isEmpty(GSEStorage[i]) then
            GSEStorage[i] = {}
        end
    end

    if not GSE.isEmpty(Library) then
        for k, v in pairs(Library) do

            for i, j in pairs(v) do
                local compressedVersion = GSE.EncodeMessage({i, j})
                GSEStorage[k][i] = compressedVersion
            end
        end
    end
    GSELegacyLibraryBackup = GSELibrary
    GSELibrary = nil
end

-- function GSE.CloneSequence(sequence, keepcomments)
--     local newsequence = {}

--     for k, v in pairs(sequence) do
--         newsequence[k] = v
--     end

--     newsequence.MacroVersions = {}
--     for k, v in ipairs(sequence.MacroVersions) do
--         newsequence.MacroVersions[tonumber(k)] = GSE.CloneMacroVersion(v, keepcomments)
--     end

--     return newsequence
-- end
function GSE.CloneSequence(orig, keepcomments)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
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

-- --- This function clones the Macro Version part of a sequence.
-- function GSE.CloneMacroVersion(macroversion, keepcomments)
--     local retseq = {}
--     for k, v in ipairs(macroversion) do
--         if GSE.isEmpty(string.find(v, '--', 1, true)) then
--             table.insert(retseq, v)
--         else
--             if not GSE.isEmpty(keepcomments) then
--                 table.insert(retseq, v)
--             else
--                 GSE.PrintDebugMessage(string.format("comment found %s", v), "Storage")
--             end
--         end
--     end

--     for k, v in pairs(macroversion) do
--         GSE.PrintDebugMessage(string.format("Processing Key: %s KeyType: %s valuetype: %s", k, type(k), type(v)),
--             "Storage")
--         if type(k) == "string" and type(v) == "string" then
--             if GSE.isEmpty(string.find(v, '--', 1, true)) then
--                 retseq[k] = v
--             else
--                 if not GSE.isEmpty(keepcomments) then
--                     table.insert(retseq, v)
--                 else
--                     GSE.PrintDebugMessage(string.format("comment found %s", v), "Storage")
--                 end
--             end
--         elseif type(k) == "string" and type(v) == "boolean" then
--             retseq[k] = v
--         elseif type(k) == "string" and type(v) == "number" then
--             retseq[k] = v
--         elseif type(k) == "string" and type(v) == "table" then
--             retseq[k] = {}
--             for i, x in ipairs(v) do
--                 if GSE.isEmpty(string.find(x, '--', 1, true)) then
--                     table.insert(retseq[k], x)
--                 else
--                     if not GSE.isEmpty(keepcomments) then
--                         table.insert(retseq[k], x)
--                     else
--                         GSE.PrintDebugMessage(string.format("comment found %s", x), "Storage")
--                     end
--                 end
--             end
--         end
--     end

--     return retseq

-- end

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
    -- check for version flags.
    if sequence.EnforceCompatability then
        if GSE.ParseVersion(sequence.GSEVersion) > (GSE.VersionNumber) then
            GSE.Print(string.format(
                          L["This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."],
                          sequence.GSEVersion))
            GSE.PrintDebugMessage("Macro Version " .. sequence.GSEVersion .. " Required Version: " .. GSE.VersionString,
                "Storage")
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
    if GSE.isEmpty(sequence.TOC) or sequence.TOC ~= tocversion then
        GSE.Print(string.format(L["WARNING ONLY"] .. ": " ..
                                    L["Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."],
                      sequenceName))
    end

    -- Check for collisions
    local found = false
    if (GSE.isEmpty(classid) or classid == 0) and not GSE.isEmpty(sequence.SpecID) then
        classid = tonumber(GSE.GetClassIDforSpec(sequence.SpecID))
    elseif GSE.isEmpty(sequence.SpecID) then
        sequence.SpecID = GSE.GetCurrentClassID()
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
        GSE.UpdateSequence(sequenceName, sequence.MacroVersions[sequence.Default])
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
        GSE.Print(string.format(
                      L["Your sequence name was longer than 27 characters.  It has been shortened from %s to %s so that your macro will work."],
                      sequenceName, tempseqName), "GSE Storage")
        sequenceName = tempseqName
    end
    if action == "MERGE" then
        for k, v in ipairs(newSequence.MacroVersions) do
            GSE.PrintDebugMessage("adding " .. k, "Storage")
            table.insert(GSE.Library[classid][sequenceName]["MetaData"].MacroVersions, v)
        end
        GSE.PrintDebugMessage("Finished colliding entry entry", "Storage")
        GSE.Print(string.format(L["Extra Macro Versions of %s has been added."], sequenceName), GNOME)
        GSEStorage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
    elseif action == "REPLACE" then
        if GSE.isEmpty(newSequence.Author) then
            -- Set to Unknown Author
            newSequence.Author = "Unknown Author"
        end
        if GSE.isEmpty(newSequence.Talents) then
            -- Set to currentSpecID
            newSequence.Talents = "?,?,?,?,?,?,?"
        end

        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSE.PrintDebugMessage("About to encode: Sequence " .. sequenceName)
        GSE.PrintDebugMessage(" New Entry: " .. GSE.Dump(GSE.Library[classid][sequenceName]), "Storage")
        GSEStorage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
        GSE.Print(sequenceName .. L[" was updated to new version."], "GSE Storage")
    elseif action == "RENAME" then
        if GSE.isEmpty(newSequence.Author) then
            -- Set to Unknown Author
            newSequence.Author = "Unknown Author"
        end
        if GSE.isEmpty(newSequence.Talents) then
            -- Set to currentSpecID
            newSequence.Talents = "?,?,?,?,?,?,?"
        end

        GSE.Library[classid][sequenceName] = {}
        GSE.Library[classid][sequenceName] = newSequence
        GSEStorage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, GSE.Library[classid][sequenceName]})
        GSE.Print(sequenceName .. L[" was imported as a new macro."], "GSE Storage")
        GSE.PrintDebugMessage("Sequence " .. sequenceName .. " New Entry: " ..
                                  GSE.Dump(GSE.Library[classid][sequenceName]), "Storage")
    else
        GSE.Print(L["No changes were made to "] .. sequenceName, GNOME)
    end
    GSE.Library[classid][sequenceName]["MetaData"].ManualIntervention = false
    GSE.PrintDebugMessage("Sequence " .. sequenceName .. " Finalised Entry: " ..
                              GSE.Dump(GSE.Library[classid][sequenceName]), "Storage")
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
    GSEStorage[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
    GSE.Library[classid][sequenceName] = sequence
end

--- Load the GSEStorage into a new table.
function GSE.LoadStorage(destination)
    if GSE.isEmpty(destination) then
        destination = {}
    end
    if GSE.isEmpty(GSE3Storage) then
        GSE3Storage = {}
        for iind=0, 12 do
            GSE3Storage[iind] = {}
        end
    end
    for k, v in ipairs(GSE3Storage) do
        if GSE.isEmpty(destination[k]) then
            destination[k] = {}
        end
        for i, j in pairs(v) do
            local status, err = pcall(function()
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(j)
                destination[k][i] = uncompressedVersion[2]
            end)
            if err then
                GSE.Print("There was an error processing " .. i .. ', You will need to reimport this macro from another source.', err )
            end
        end
    end
end

--- Load a collection of Sequences
function GSE.ImportCompressedMacroCollection(Sequences)
    for _,v in ipairs(Sequences) do
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
    if not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Arena) and GSE.inArena then
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
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Scenario) and GSE.inScenario then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Scenario
    elseif not GSE.isEmpty(GSE.Library[classid][sequenceName]["MetaData"].Party) and GSE.inParty then
        vers = GSE.Library[classid][sequenceName]["MetaData"].Party
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
                GSEOptions.AuthorColour .. L["Close to Maximum Personal Macros.|r  You can have a maximum of "] ..
                    MAX_CHARACTER_MACROS .. L[" macros per character.  You currently have "] ..
                    GSEOptions.EmphasisColour .. numCharacterMacros ..
                    L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] ..
                    GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
        elseif numAccountMacros >= MAX_ACCOUNT_MACROS and GSEOptions.overflowPersonalMacros then
            GSE.Print(L["Close to Maximum Macros.|r  You can have a maximum of "] .. MAX_CHARACTER_MACROS ..
                          L[" macros per character.  You currently have "] .. GSEOptions.EmphasisColour ..
                          numCharacterMacros .. L["|r.  You can also have a  maximum of "] .. MAX_ACCOUNT_MACROS ..
                          L[" macros per Account.  You currently have "] .. GSEOptions.EmphasisColour ..
                          numAccountMacros ..
                          L["|r. As a result this macro was not created.  Please delete some macros and reenter "] ..
                          GSEOptions.CommandColour .. L["/gs|r again."], GNOME)
        else
            CreateMacro(sequenceName,
                             (GSEOptions.setDefaultIconQuestionMark and "INV_MISC_QUESTIONMARK" or icon),
                             GSE.CreateMacroString(sequenceName), (forceglobalstub and false or GSE.SetMacroLocation()))
        end
    end
end

--- Load a serialised Sequence
function GSE.ImportSerialisedSequence(importstring, createicon)
    local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    GSE.PrintDebugMessage(string.format("Decomsuccess: %s ", tostring(decompresssuccess)), Statics.SourceTransmission)
    if (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and
        (type(actiontable[2]) == "table") then
        GSE.PrintDebugMessage(string.format("tablerows: %s   type cell1 %s cell2 %s", table.getn(actiontable),
                                  type(actiontable[1]), type(actiontable[2])), Statics.SourceTransmission)
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

--- Load a GSE Sequence Collection from a String
function GSE.ImportSequence(importStr, legacy, createicon)
    local success, returnmessage = false, ""
    importStr = GSE.StripControlandExtendedCodes(importStr)
    local functiondefinition = GSE.FixQuotes(importStr) .. [===[
  return Sequences
  ]===]

    GSE.PrintDebugMessage(functiondefinition, "Storage")
    local fake_globals = setmetatable({
        Sequences = {}
    }, {
        __index = _G
    })
    local func, err = loadstring(functiondefinition, "Storage")
    if func then
        -- Make the compiled function see this table as its "globals"
        setfenv(func, fake_globals)

        local TempSequences = assert(func())
        if not GSE.isEmpty(TempSequences) then
            local newkey = ""
            for k, v in pairs(TempSequences) do
                if legacy then
                    v = GSE.ConvertLegacySequence(v)
                end
                GSE.AddSequenceToCollection(string.upper(k), v)
                if GSE.isEmpty(v.Icon) then
                    -- Set a default icon
                    v.Icon = GSE.GetDefaultIcon()
                end
                newkey = k
            end
            if createicon then
                GSE.CheckMacroCreated(string.upper(newkey), true)
            end
            success = true
        end
    else
        GSE.Print(err, GNOME)
        returnmessage = err

    end
    return success, returnmessage
end

function GSE.ReloadSequences()
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) then
        GSE.PerformReloadSequences()
        GSE.UnsavedOptions.ReloadQueued = true
    end
end

function GSE.PerformReloadSequences()
    GSE.PrintDebugMessage("Reloading Sequences")
    for name, sequence in pairs(GSE.Library[GSE.GetCurrentClassID()]) do
        GSE.UpdateSequence(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
    end
    if GSEOptions.CreateGlobalButtons then
        if not GSE.isEmpty(GSE.Library[0]) then
            for name, sequence in pairs(GSE.Library[0]) do
                GSE.UpdateSequence(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
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
        GSEStorage[GSE.GetCurrentClassID()] = nil
        GSEStorage[GSE.GetCurrentClassID()] = {}
        GSE.Library[GSE.GetCurrentClassID()] = nil
        GSE.Library[GSE.GetCurrentClassID()] = {}
    end
end

--- This function resets a gsebutton back to its initial setting
function GSE.ResetButtons()
    for k,_ in pairs(GSE.UsedSequences) do
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
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()][name]) then
        return
    end
    GSE.CreateGSE3Button(GSE.CompileTemplate(sequence), name)
end

--- This function dumps what is currently running on an existing button.
function GSE.DebugDumpButton(SequenceName)

    GSE.Print("====================================\nStart GSE Button Dump\n====================================")
    GSE.Print("Button name: " .. SequenceName)
    GSE.Print("KeyPress" .. _G[SequenceName]:GetAttribute('KeyPress'))
    GSE.Print("KeyRelease" .. _G[SequenceName]:GetAttribute('KeyRelease'))
    GSE.Print("Clicks" .. _G[SequenceName]:GetAttribute('clicks'))
    GSE.Print("ms" .. _G[SequenceName]:GetAttribute('ms'))
    GSE.Print("====================================\nStepFunction\n====================================")
    GSE.Print(GSE.SequencesExec[SequenceName][_G[SequenceName]:GetAttribute('step')])
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
    return string.format(
               "#showtooltip\n/click [button:2] %s RightButton; [button:3] %s MiddleButton; [button:4] %s Button4; [button:5] %s Button5; %s",
               macroname, macroname, macroname, macroname, macroname)
end

function GSE.UpdateMacroString()
    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    for macid = 1, maxmacros do
        local mname, mtexture, mbody = GetMacroInfo(macid)
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

--- Not Used
function GSE.GetDefaultIcon()
    local currentSpec = GetSpecialization()
    local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or ""
    local _, _, _, defaulticon, _, _, _ = GetSpecializationInfoByID(currentSpecID)
    return strsub(defaulticon, 17)
end

--- This returns a list of Sequence Names for the current spec
function GSE.GetSequenceNames()
    local keyset = {}
    for k,_ in pairs(GSE.Library) do
        if GSE.isEmpty(GSEOptions.filterList) then
            GSEOptions.filterList = {}
            GSEOptions.filterList[Statics.Spec] = true
            GSEOptions.filterList[Statics.Class] = true
            GSEOptions.filterList[Statics.All] = false
            GSEOptions.filterList[Statics.Global] = true
        end
        if GSEOptions.filterList[Statics.All] or k == GSE.GetCurrentClassID() then
            for i, j in pairs(GSE.Library[k]) do
                local disable = 0
                if j.DisableEditor then
                    disable = 1
                end
                local keyLabel = k .. "," .. i .. "," .. disable
                if k == GSE.GetCurrentClassID() and GSEOptions.filterList["Class"] then
                    keyset[keyLabel] = i
                elseif k == GSE.GetCurrentClassID() and not GSEOptions.filterList["Class"] then
                    if j.SpecID == GSE.GetCurrentSpecID() or j.SpecID == GSE.GetCurrentClassID() then
                        keyset[keyLabel] = i
                    end
                else
                    keyset[keyLabel] = i
                end
            end
        else
            if k == 0 and GSEOptions.filterList[Statics.Global] then
                for i, j in pairs(GSE.Library[k]) do
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
        GSE.PrintDebugMessage("Macro Found " .. a .. " with iconid " ..
                                  (GSE.isEmpty(iconid) and "of no value" or iconid) .. " " ..
                                  (GSE.isEmpty(iconid) and L["with no body"] or c), GNOME)
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
        GSE.PrintDebugMessage("SequenceSpecID: " .. sequence.SpecID, GNOME)
        if sequence.SpecID == 0 then
            return "INV_MISC_QUESTIONMARK"
        else
            local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID(
                                                   (GSE.isEmpty(sequence.SpecID) and GSE.GetCurrentSpecID() or
                                                       sequence.SpecID))
            GSE.PrintDebugMessage("No Sequence Icon setting to " .. strsub(specicon, 17), GNOME)
            return strsub(specicon, 17)
        end
    elseif GSE.isEmpty(iconid) and not GSE.isEmpty(sequence.Icon) then

        return sequence.Icon
    else
        return iconid
    end
end

--- This converts a legacy GS/GSE1 sequence to a new GSE2
function GSE.ConvertLegacySequence(sequence)
    local GSStaticPriority = Statics.PriorityImplementation
    local returnSequence = {}
    if not GSE.isEmpty(sequence.specID) then
        returnSequence.SpecID = sequence.specID
    end
    if not GSE.isEmpty(sequence.author) then
        returnSequence.Author = sequence.author
    end
    if not GSE.isEmpty(sequence.helpTxt) then
        returnSequence.Help = sequence.helpTxt
    end
    returnSequence.Default = 1
    returnSequence.MacroVersions = {}
    returnSequence.MacroVersions[1] = {}
    if not GSE.isEmpty(sequence.PreMacro) then
        returnSequence.MacroVersions[1].KeyPress = GSE.SplitMeIntolines(sequence.PreMacro)
    end
    if not GSE.isEmpty(sequence.PostMacro) then
        returnSequence.MacroVersions[1].KeyRelease = GSE.SplitMeIntolines(sequence.PostMacro)
    end
    if not GSE.isEmpty(sequence.StepFunction) then
        if sequence.StepFunction == GSStaticPriority then
            returnSequence.MacroVersions[1].StepFunction = Statics.Priority
        else
            GSE.Print(L["The Custom StepFunction Specified is not recognised and has been ignored."], GNOME)
            returnSequence.MacroVersions[1].StepFunction = Statics.Sequential
        end
    else
        returnSequence.MacroVersions[1].StepFunction = Statics.Sequential
    end
    if not GSE.isEmpty(sequence.icon) then
        returnSequence.Icon = sequence.icon
    end
    local macroversion = returnSequence.MacroVersions[1]
    local loopstart = tonumber(sequence.loopstart) or 1
    local loopstop = tonumber(sequence.loopstop) or table.getn(sequence)
    if loopstart > 1 then
        macroversion.PreMacro = {}
    end
    if loopstop < table.getn(sequence) then
        macroversion.PostMacro = {}
    end
    for k, v in ipairs(sequence) do
        if k < loopstart then
            table.insert(macroversion.PreMacro, v)
        elseif k > loopstop then
            table.insert(macroversion.PostMacro, v)
        else
            table.insert(macroversion, v)
        end
    end
    return returnSequence
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
    local step = self:GetAttribute('step') or 1
    local gsebutton = self:GetName()
    local executionseq = GSE.SequencesExec[gsebutton]
    local commandline, foundSpell, notSpell = executionseq[step], false, ''
    for cmd, etc in gmatch(commandline or '', '/(%w+)%s+([^\n]+)') do
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
                elseif notSpell == '' then
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
            if v.SpecID < 12 then
                GSE.Library[v.SpecID][k] = v
                GSE.Print(string.format(L["Moved %s to class %s."], k, Statics.SpecIDList[v.SpecID]))
                GSE.Library[0][k] = nil
            else
                GSE.Library[GSE.GetClassIDforSpec(v.SpecID)][k] = v
                GSE.Print(string.format(L["Moved %s to class %s."], k,
                              Statics.SpecIDList[GSE.GetClassIDforSpec(v.SpecID)]))
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
                table.insert(activemods, "GetMouseButtonClicked() == \"" .. k .. "\"")
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

-- --- This function checks a sequence for mod breaking errors.  Use this with a pcall
-- function GSE.CheckSequence(sequence)

--     for k, v in ipairs(sequence) do
--         if type(v) == "table" then
--             GSE.PrintDebugMessage("Macro corrupt at " .. k, "Storage")
--             error("Corrupt MacroVersion")
--         end
--     end
-- end

--- This function scans all macros in the library and reports on corrupt macros.
function GSE.ScanMacrosForErrors()
    for classlibid, classlib in ipairs(GSE.Library) do
        for seqname, seq in pairs(classlib) do
            for macroversionid, macroversion in ipairs(seq) do
                local status, error = pcall(GSE.CheckSequence, macroversion)
                if not status then
                    GSE.Print(string.format(L["Error found in version %i of %s."], macroversionid, seqname), "Error")
                    GSE.Print(string.format(
                                  L["To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"],
                                  GSEOptions.CommandColour, classlibid, seqname, Statics.StringReset))
                end
            end
            if seqname == "WW" then
                GSE.Print(string.format(
                              L["Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."],
                              GSEOptions.CommandColour, Statics.StringReset), "Error")
            elseif seqname == "PVP" then
                GSE.Print(string.format(
                              L["Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."],
                              GSEOptions.CommandColour, Statics.StringReset), "Error")
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

    local fake_globals = setmetatable({
        Sequences = {}
    }, {
        __index = _G
    })
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
    if (decompresssuccess) and (table.getn(actiontable) == 2) and (type(actiontable[1]) == "string") and
        (type(actiontable[2]) == "table") then
        seqName = string.upper(actiontable[1])
        returnstr = GSE.Dump(actiontable[2])
    end
    return returnstr, seqName, decompresssuccess
end

--- This function allows the player to toggle Target Protection from the LDB Plugin.
function GSE.ToggleTargetProtection()
    if GSE.isEmpty(GSEOptions.requireTarget) then
        GSEOptions.requireTarget = true
    else
        GSEOptions.requireTarget = false
    end
    GSE.ReloadSequences()
end

--- This creates a pretty export for WLM Forums
function GSE.ExportSequenceWLMFormat(sequence, sequencename)
    local returnstring = "# " .. sequencename .. "\n\n## Talents: " ..
                             (GSE.isEmpty(sequence["MetaData"].Talents) and "?,?,?,?,?,?,?" or sequence["MetaData"].Talents) .. "\n\n"
    if not GSE.isEmpty(sequence["MetaData"].Help) then
        returnstring = "\n\n## Usage Information\n" .. sequence["MetaData"].Help .. "\n\n"
    end
    returnstring = returnstring .. "This macro contains " ..
                       (table.getn(sequence.Macros) > 1 and table.getn(sequence.Macros) ..
                           " macro templates. " or "1 macro template. ") ..
                       string.format(L["This Sequence was exported from GSE %s."], GSE.VersionString) .. "\n\n"
    if (table.getn(sequence.Macros) > 1) then
        for k,_ in pairs(sequence.Macros) do
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

    -- TODO update for GSE3

    -- for k, v in pairs(sequence.MacroVersions) do
    --     returnstring = returnstring .. "## Macro Version " .. k .. "\n"
    --     returnstring = returnstring .. "<blockquote>\n\n**Step Function:** " .. v.StepFunction .. "\n\n"
    --     if not GSE.isEmpty(v.PreMacro) then
    --         if table.getn(v.PreMacro) > 0 then
    --             returnstring = returnstring .. "**Pre Macro:** " .. GSE.IdentifySpells(v.PreMacro) .. "\n\n"
    --         end
    --     end
    --     if not GSE.isEmpty(v.KeyPress) then
    --         if table.getn(v.KeyPress) > 0 then
    --             spells, _ = GSE.IdentifySpells(v.KeyPress)
    --             if not GSE.isEmpty(spells) then
    --                 returnstring = returnstring .. "**KeyPress:** " .. GSE.IdentifySpells(v.KeyPress) .. "\n\n"
    --             else
    --                 returnstring = returnstring .. "**KeyPress:** Contains various utility functions.\n\n"
    --             end
    --         end
    --     end
    --     returnstring = returnstring .. "**Main Sequence:** " .. GSE.IdentifySpells(v) .. "\n\n"
    --     if not GSE.isEmpty(v.KeyRelease) then
    --         if table.getn(v.KeyRelease) > 0 then
    --             spells, _ = GSE.IdentifySpells(v.KeyRelease)
    --             if not GSE.isEmpty(spells) then
    --                 returnstring = returnstring .. "**KeyRelease:** " .. GSE.IdentifySpells(v.KeyRelease) .. "\n\n"
    --             else
    --                 returnstring = returnstring .. "**KeyRelease:**  Contains various utility functions.\n\n"
    --             end
    --         end
    --     end
    --     if not GSE.isEmpty(v.PostMacro) then
    --         if table.getn(v.PostMacro) > 0 then
    --             returnstring = returnstring .. "**Post Macro:** " .. GSE.IdentifySpells(v.PostMacro) .. "\n\n"
    --         end
    --     end
    --     returnstring = returnstring .. "</blockquote>\n\n"
    -- end

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
        --print("KeyPress false")
        table.insert(action, [[~~KeyPress~~]])
    end
    table.insert(action, line)
    if KeyRelease then
        --print("KeyRelease false")
        table.insert(action, [[~~KeyRelease~~]])
    end

    if string.sub(line, 1, 12) == "/click pause" then
        action = {}
        action["Type"] = Statics.Actions.Pause
        if string.sub(line, 14) == "~~GCD~~" then
            action["MS"] = GSE.GetGCD() * 1000
        else
            local mynumber = tonumber(string.sub(line, 14))

            if GSE.isEmpty(number) then
                action["MS"] = 10
                GSE.Print(L["Error processing Custom Pause Value.  You will need to recheck your macros."], "Storage")
            else
                action["MS"] = tonumber(string.sub(line, 14)) * 1000
            end
            
        end
    end
    return action
end

function GSE.ConvertGSE2(sequence, sequenceName)
    local returnSequence = {}
    returnSequence["MetaData"] = {}
    returnSequence["MetaData"]["Name"] = sequenceName
    returnSequence["MetaData"]["ClassID"] = Statics.SpecIDClassList[sequence.SpecID]
    for k,v in pairs(sequence) do
        if k ~= "MacroVersions" then
            returnSequence["MetaData"][k] = v
        end
    end
    local MacroVersions = {}
    for _,v in ipairs(sequence.MacroVersions) do
        local gse3seq = {}
        gse3seq.Actions = {}
        gse3seq.Variables = {}

        local KeyPress = table.getn(v.KeyPress) > 0
        local KeyRelease = table.getn(v.KeyRelease) > 0

        if KeyPress then
            gse3seq.Variables["KeyPress"] = v.KeyPress
        end
        if KeyRelease then
            gse3seq.Variables["KeyRelease"] = v.KeyRelease
        end
        if table.getn(v.PreMacro) > 0 then
            for _, j in ipairs(v.PreMacro) do
                local action = fixLine(j, KeyPress, KeyRelease)
                table.insert(gse3seq.Actions, action)
            end
        end

        local sequenceactions = {}
        for _, j in ipairs(v) do
            local action = fixLine(j, KeyPress, KeyRelease)
            table.insert(sequenceactions, action)
        end
        if GSE.isEmpty(v.LoopLimit) then
            for _, j in ipairs(sequenceactions) do
                table.insert(gse3seq.Actions, j)
            end
        else
            local loop = {}
            for _, j in ipairs(sequenceactions) do
                table.insert(loop, j)
            end
            loop["Type"] = Statics.Actions.Loop
            loop["StepFunction"] = v.StepFunction
            loop["Repeat"] = v.LoopLimit
            table.insert(gse3seq.Actions, loop)
        end

        if table.getn(v.PostMacro) > 0 then
            for _,j in ipairs(v.PreMacro) do
                local action = fixLine(j, KeyPress, KeyRelease)
                table.insert(gse3seq.Actions, action)
            end
        end

        gse3seq.InbuiltVariables = {}
        
        local function checkParameter(param)
                gse3seq.InbuiltVariables[param] = v[param]
        end

        checkParameter("Combat")
        checkParameter("Ring1")
        checkParameter("Ring2")
        checkParameter("Trinket1")
        checkParameter("Trinket2")
        checkParameter("Neck")
        checkParameter("Head")
        checkParameter("Belt")

        table.insert(MacroVersions, gse3seq)
    end
    returnSequence["Macros"] = MacroVersions
    returnSequence["MetaData"]["Variables"] = nil
    if GSE.isEmpty(sequence["WeakAuras"]) then
        sequence["WeakAuras"] = {}
    end
    returnSequence["WeakAuras"] = sequence["WeakAuras"]
    return returnSequence
end

local function buildAction(action, metaData)
    if GSEOptions.requireTarget then

        -- See #20 prevent target hopping
        table.insert(action, "/stopmacro [@playertarget, noexists]",1)
    end

    if GSEOptions.hideSoundErrors then
        -- Potentially change this to SetCVar("Sound_EnableSFX", 0)
        table.insert(action, "/console Sound_EnableErrorSpeech 0")
        table.insert(action, "/console Sound_EnableSFX 0")
        table.insert(action, '/run ers=GetCVar("Sound_EnableErrorSpeech");')
        table.insert(action, '/run sfx=GetCVar("Sound_EnableSFX");')
    end

    for k,v in ipairs(action) do
        action[k] = GSE.TranslateString(v, "STRING", nil,  true)
    end

    if not GSE.isEmpty(metaData) then
        if metaData.Ring1 or (metaData.Ring1 == nil and GSEOptions.use11) then
            table.insert(action, "/use [combat,nochanneling] 11")
        end
        if metaData.Ring2 or (metaData.Ring2 == nil and GSEOptions.use12) then
            table.insert(action, "/use [combat,nochanneling] 12")
        end
        if metaData.Trinket1 or (metaData.Trinket1 == nil and GSEOptions.use13) then
            table.insert(action, "/use [combat,nochanneling] 13")
        end
        if metaData.Trinket2 or (metaData.Trinket2 == nil and GSEOptions.use14) then
            table.insert(action, "/use [combat,nochanneling] 14")
        end
        if metaData.Neck or (metaData.Neck == nil and GSEOptions.use2) then
            table.insert(action, "/use [combat,nochanneling] 2")
        end
        if metaData.Head or (metaData.Head == nil and GSEOptions.use1) then
            table.insert(action, "/use [combat,nochanneling] 1")
        end
        if metaData.Belt or (metaData.Belt == nil and GSEOptions.use6) then
            table.insert(action, "/use [combat,nochanneling] 6")
        end
    end
    if GSEOptions.hideSoundErrors then
        -- Potentially change this to SetCVar("Sound_EnableSFX", 1)
        table.insert(action, "/run SetCVar(\"Sound_EnableSFX\",sfx);")
        table.insert(action, "/run SetCVar(\"Sound_EnableErrorSpeech\",ers);")
    end
    if GSEOptions.hideUIErrors then
        table.insert(action, "/script UIErrorsFrame:Hide();")
        -- Potentially change this to UIErrorsFrame:Hide()
    end
    if GSEOptions.clearUIErrors then
        -- Potentially change this to UIErrorsFrame:Clear()
        table.insert(action, "/run UIErrorsFrame:Clear()")
    end

    return table.concat(action, "\n")
end

function GSE.CompileAction(action, template)
    local returnAction = buildAction(action, template.InbuiltVariables)
    local variables = {}

    for k,v in pairs(template.Variables) do
        if type(v) == "table" then
            for i,j in ipairs(v) do
                template.Variables[k][i] = GSE.TranslateString(j, "STRING",nil,  true)
            end
            variables[k] = table.concat(template.Variables[k], "\n")
        end
    end
    local returnMacro = {}
    table.insert(returnMacro, returnAction)
    return table.concat(GSE.UnEscapeTable(GSE.ProcessVariables(returnMacro, variables))[1], "\n")
end

local function processAction(action, metaData)

    if action.Type == Statics.Actions.Loop then

        local actionList = {}
        -- setup the interation
        for _, v in ipairs(action) do
            table.insert(actionList, buildAction(v, metaData))
        end
        local returnActions = {}
        local loop = tonumber(action.Repeat)
        for step = 1, loop do
            if action.StepFunction == Statics.Priority then
                for limit = 1, table.getn(actionList) do
                    table.insert(returnActions, actionList[step])
                    if step == limit then
                        limit = limit % #actionList + 1
                        step = 1
                        GSE.PrintDebugMessage("Limit is now " .. limit, "Storage")
                    else
                        step = step % #actionList + 1
                    end
                end
            else
                for _,v in ipairs(actionList) do
                    table.insert(returnActions, v)
                end
            end
        end

        -- process repeats for the block
        local inserts = {}
        for k,v in ipairs(returnActions) do
            if type(v) == "table" then
                local act = v[1]
                local rep =  v.Repeat
                table.insert(inserts, {act, rep} )
                table.remove(returnActions, k)
            end
        end

        for k,v in ipairs(inserts) do
            for i=k, table.getn(returnActions), v[2] do
                table.insert(returnActions, v[1], i)
            end
        end

        return returnActions
    elseif action.Type == Statics.Actions.Pause then
        local PauseActions = {}
        local clicks = action.Clicks
        if GSE.isEmpty(clicks) then
            clicks = action.MS
            if clicks == '~~GCD~~' or clicks == 'GCD' then
                clicks = GSE.GetGCD() * 1000
            else
                clicks = math.ceil(clicks / GSEOptions.msClickRate)
            end
        end
        if clicks > 0 then
            for loop=1,clicks do
                table.insert(PauseActions, "/click nil")
                GSE.PrintDebugMessage(loop, "Storage1")
            end
        end
        return PauseActions
    elseif action.Type == Statics.Actions.Action then
        return buildAction(action, metaData)

    elseif action.Type == Statics.Actions.Repeat then
        return {buildAction(action, metaData), action["Interval"]}

    -- elseif action.Type == Statics.Actions.If then

    end
end

--- Compiles a macro template into a macro
function GSE.CompileTemplate(template)

    -- setmetatable(template, {
    --     __index = function(t, k)
    --       for i,v in ipairs(k) do
    --         if not t then error("attempt to index nil") end
    --         t = rawget(t, v)
    --       end
    --       return t
    --     end
    --     })


    local compiledMacro = {}
    local metaData = {}

    for _, action in ipairs(template.Actions) do
        local compiledAction = processAction(action, template.InbuiltVariables)
        --GSE.Print(compiledAction)
        if type(compiledAction) == "table" then
            for _, value in ipairs(compiledAction) do
                table.insert(compiledMacro, value)
            end
        else
            table.insert(compiledMacro, compiledAction)
        end
    end
    local variables = {}

    for k,v in pairs(template.Variables) do
        if type(v) == "table" then
            for i,j in ipairs(v) do
                template.Variables[k][i] = GSE.TranslateString(j, "STRING",nil,  true)
            end
            variables[k] = table.concat(template.Variables[k], "\n")
        end
    end

    return GSE.UnEscapeTable(GSE.ProcessVariables(compiledMacro, variables)), template
end

--- Build GSE3 Executable Buttons
function GSE.CreateGSE3Button(macro, name)
    if GSE.isEmpty(macro) then
        print("Macro missing for ", name)
        return
    end
    -- name = name .. "T"
    GSE.SequencesExec[name] = macro

    -- if button already exists no need to recreate it.  Maybe able to create this in combat.
    if GSE.isEmpty(_G[name]) then

        local gsebutton = CreateFrame('Button', name, nil, 'SecureActionButtonTemplate,SecureHandlerBaseTemplate')
        gsebutton:SetAttribute('type', 'macro')
        gsebutton:SetAttribute('step', 1)
        gsebutton:UnwrapScript(gsebutton, 'OnClick')
        gsebutton.UpdateIcon = GSE.UpdateIcon

        if GSEOptions.useExternalMSTimings then
            gsebutton:SetAttribute("ms", GSEOptions.msClickRate)
         else
            gsebutton:SetAttribute("ms", 100)
        end

        local stepfunction = (GSEOptions.DebugPrintModConditionsOnKeyPress and Statics.PrintKeyModifiers or "") .. GSE.GetMacroResetImplementation() .. Statics.GSE3OnClick
        gsebutton:WrapScript(gsebutton, 'OnClick', stepfunction)
    end
    _G[name]:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(macro)) .. ']=======])')
    GSE.UpdateIcon(_G[name], true)
end
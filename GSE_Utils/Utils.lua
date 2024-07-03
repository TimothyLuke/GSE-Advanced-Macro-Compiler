local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

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

--- Load a serialised Sequence
function GSE.ImportSerialisedSequence(importstring, createicon)
    local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
    GSE.PrintDebugMessage(string.format("Decomsuccess: %s ", tostring(decompresssuccess)), Statics.SourceTransmission)
    if decompresssuccess then
        if actiontable.objectType == "MACRO" then
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
            if GSE.GUI and GSE.GUIEditFrame:IsVisible() then
                GSE.ShowSequences()
            end
            if GSE.GUI and GSE.GUIVariableFrame:IsVisible() then
                GSE.ShowVariables()
            end
            if GSE.GUI and GSE.GUIMacroFrame:IsVisible() then
                GSE.ShowMacros()
            end
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
                    "/gse checkmacrosforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."
                ],
        GNOME
    )
end

GSE:RegisterChatCommand("gse", "GSSlash")

-- Functions

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

--- Handle slash commands
function GSE:GSSlash(input)
    local _, _, currentclassId = UnitClass("player")
    local params = GSE.split(input, " ")
    if table.getn(params) > 1 then
        input = params[1]
    end
    local command = string.lower(input)
    if command == "showspec" then
        local currentSpec = GetSpecialization()
        local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
        local _, specname, _, _, _, _, _ = GetSpecializationInfoByID(currentSpecID)
        GSE.Print(
            L["Your current Specialisation is "] ..
                currentSpecID .. ":" .. specname .. L["  The Alternative ClassID is "] .. currentclassId,
            GNOME
        )
    elseif command == "help" then
        GSE.PrintGnomeHelp()
    elseif command == "cleanorphans" or command == "clean" then
        GSE.CleanOrphanSequences()
    elseif command == "forceclean" then
        GSE.CleanOrphanSequences()
        GSE.CleanMacroLibrary(true)
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
    elseif command == "checkmacrosforerrors" then
        GSE.ScanMacrosForErrors()
    elseif command == "compressstring" then
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUICompressFrame:Show()
        end
    elseif command == "dumpmacro" then
        GSE_C[params[2]] = {}
        GSE_C[params[2]].name = params[2]
        GSE_C[params[2]].sequence = GSE.FindMacro(params[2])
        GSE_C[params[2]].button = _G[params[2]]
    elseif command == "recompilesequences" then
        GSE.ReloadSequences()
    elseif string.lower(command) == "clearoocqueue" then
        GSE.OOCQueue = {}
    elseif string.lower(command) == "retro" then
        local loaded, _ = LoadAddOn("GSE2")
        if loaded then
            GSE.Print(
                string.format(
                    L[
                        "GSE2 Retro interface loaded.  Type `%s/gse2 import%s` to import an old GSE2 string or `%s/gse2 edit%s` to mock up a new template using the GSE2 editor."
                    ],
                    GSEOptions.CommandColour,
                    Statics.StringReset,
                    GSEOptions.CommandColour,
                    Statics.StringReset
                ),
                "GSE2"
            )
        end
    else
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            _G["GSE_Menu"]:Show()
        end
    end
end

LibStub("AceConfig-3.0"):RegisterOptionsTable("GSE", GSE.GetOptionsTable(), {"gseo"})

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

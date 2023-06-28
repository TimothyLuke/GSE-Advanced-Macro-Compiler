local GNOME, _ = ...

local GSE = GSE

local currentclassDisplayName, currentenglishclass, currentclassId = UnitClass("player")
local L = GSE.L
local Statics = GSE.Static

local GCD

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
    if GSE.UnsavedOptions.DebugSequenceExecution and not GSE.isEmpty(task) then
        local spell = task
        local csindex, csitem, csspell = QueryCastSequence(task)
        if not GSE.isEmpty(csitem) then
            spell = csitem
        end
        if not GSE.isEmpty(csitem) then
            spell = csspell
        end

        local isUsable, notEnoughMana = IsUsableSpell(spell)
        local usableOutput, manaOutput, GCDOutput, CastingOutput
        if isUsable then
            usableOutput = GSEOptions.CommandColour .. "Able To Cast" .. Statics.StringReset
        else
            usableOutput = GSEOptions.UNKNOWN .. "Not Able to Cast" .. Statics.StringReset
        end
        if notEnoughMana then
            manaOutput = GSEOptions.UNKNOWN .. "Resources Not Available" .. Statics.StringReset
        else
            manaOutput = GSEOptions.CommandColour .. "Resources Available" .. Statics.StringReset
        end
        local castingspell

        if GSE.GameMode == 1 then
            castingspell, _, _, _, _, _, _, _ = CastingInfo()
        else
            castingspell, _, _, _, _, _, _, _ = UnitCastingInfo("player")
        end
        if not GSE.isEmpty(castingspell) then
            CastingOutput = GSEOptions.UNKNOWN .. "Casting " .. castingspell .. Statics.StringReset
        else
            CastingOutput = GSEOptions.CommandColour .. "Not actively casting anything else." .. Statics.StringReset
        end
        GCDOutput = GSEOptions.CommandColour .. "GCD Free" .. Statics.StringReset
        if GCD then
            GCDOutput = GSEOptions.UNKNOWN .. "GCD In Cooldown" .. Statics.StringReset
        end

        local fullBlock = ""

        if GSEOptions.showFullBlockDebug then
            fullBlock =
                "\n" ..
                GSE.SequencesExec[button][step] ..
                    GSEOptions.EmphasisColour ..
                        "\n============================================================================================\n" ..
                            Statics.StringReset
        end
        GSE.PrintDebugMessage(
            table.concat(
                {
                    GSEOptions.AuthorColour,
                    button,
                    Statics.StringReset,
                    ",",
                    step,
                    ",",
                    (spell and spell or "nil"),
                    (csindex and
                        " from castsequence " ..
                            (csspell and csspell or csitem) .. " (item " .. csindex .. " in castsequence.) " or
                        ""),
                    ",",
                    usableOutput,
                    ",",
                    manaOutput,
                    ",",
                    GCDOutput,
                    ",",
                    CastingOutput,
                    fullBlock
                }
            ),
            Statics.SequenceDebug
        )
    end
end

function GSE:UNIT_FACTION()
    -- local pvpType, ffa, _ = GetZonePVPInfo()
    if UnitIsPVP("player") then
        GSE.PVPFlag = true
    else
        GSE.PVPFlag = false
    end
    GSE.PrintDebugMessage("PVP Flag toggled to " .. tostring(GSE.PVPFlag), Statics.DebugModules["API"])
    GSE.ReloadSequences()
end

function GSE:ZONE_CHANGED_NEW_AREA()
    local _, type, difficulty, _, _, _, _, _, _ = GetInstanceInfo()
    if type == "pvp" then
        GSE.PVPFlag = true
    else
        GSE.PVPFlag = false
    end
    if difficulty == 23 then -- Mythic 5 player
        GSE.inMythic = true
    else
        GSE.inMythic = false
    end
    if difficulty == 1 then -- Normal
        GSE.inDungeon = true
    else
        GSE.inDungeon = false
    end
    if difficulty == 2 then -- Heroic
        GSE.inHeroic = true
    else
        GSE.inHeroic = false
    end
    if difficulty == 8 then -- Mythic+
        GSE.inMythicPlus = true
    else
        GSE.inMythicPlus = false
    end

    if difficulty == 24 or difficulty == 33 then -- Timewalking  24 Dungeon, 33 raid
        GSE.inTimeWalking = true
    else
        GSE.inTimeWalking = false
    end
    if type == "raid" then
        GSE.inRaid = true
    else
        GSE.inRaid = false
    end
    if IsInGroup() then
        GSE.inParty = true
    else
        GSE.inParty = false
    end
    if type == "arena" then
        GSE.inArena = true
    else
        GSE.inArena = false
    end
    if type == "scenario" or difficulty == 167 or difficulty == 152 then
        GSE.inScenario = true
    else
        GSE.inScenario = false
    end

    GSE.PrintDebugMessage(
        table.concat(
            {
                "PVP: ",
                tostring(GSE.PVPFlag),
                " inMythic: ",
                tostring(GSE.inMythic),
                " inRaid: ",
                tostring(GSE.inRaid),
                " inDungeon ",
                tostring(GSE.inDungeon),
                " inHeroic ",
                tostring(GSE.inHeroic),
                " inArena ",
                tostring(GSE.inArena),
                " inTimeWalking ",
                tostring(GSE.inTimeWalking),
                " inMythicPlus ",
                tostring(GSE.inMythicPlus),
                " inScenario ",
                tostring(GSE.inScenario)
            }
        ),
        Statics.DebugModules["API"]
    )
    -- Force Reload of all Sequences
    GSE.UnsavedOptions.ReloadQueued = nil
    GSE.ReloadSequences()
end

function GSE:PLAYER_ENTERING_WORLD()
    GSE.PerformOneOffEvents()
    GSE.PrintAvailable = true
    GSE.PerformPrint()
    GSE.currentZone = GetRealZoneText()
    GSE:ZONE_CHANGED_NEW_AREA()
end

function GSE:ADDON_LOADED(event, addon)
    GSE.LoadStorage(GSE.Library)

    if GSE.isEmpty(GSE3Storage[GSE.GetCurrentClassID()]) then
        GSE3Storage[GSE.GetCurrentClassID()] = {}
    end
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()]) then
        GSE.Library[GSE.GetCurrentClassID()] = {}
    end
    if GSE.isEmpty(GSE.Library[0]) then
        GSE.Library[0] = {}
    end

    GSE.PrintDebugMessage("I am loaded")

    GSE:SendMessage(Statics.CoreLoadedMessage)

    -- Register the Sample Macros
    local seqnames = {}
    table.insert(seqnames, "Assorted Sample Macros")
    GSE.RegisterAddon("Samples", GSE.VersionString, seqnames)

    GSE:RegisterMessage(Statics.ReloadMessage, "processReload")

    table.insert(seqnames, "GSE2 Macros")
    GSE.RegisterAddon("GSE2Library", GSE.VersionString, seqnames)

    GSE:RegisterMessage(Statics.ReloadMessage, "processReload")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("GSE", GSE.GetOptionsTable(), {"gseo"})
    if addon == GNOME then
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSE", "|cffff0000GSE:|r Advanced Macro Compiler")
        if not GSEOptions.HideLoginMessage then
            GSE.Print(
                GSEOptions.AuthorColour ..
                    L["GSE: Advanced Macro Compiler loaded.|r  Type "] ..
                        GSEOptions.CommandColour .. L["/gse help|r to get started."],
                GNOME
            )
        end
    end
    if GSE.isEmpty(GSEOptions) then
        GSE.SetDefaultOptions()
    end

    -- Added in 2.1.0
    if GSE.isEmpty(GSEOptions.MacroResetModifiers) then
        GSEOptions.MacroResetModifiers = {}
        GSEOptions.MacroResetModifiers["LeftButton"] = false
        GSEOptions.MacroResetModifiers["RighttButton"] = false
        GSEOptions.MacroResetModifiers["MiddleButton"] = false
        GSEOptions.MacroResetModifiers["Button4"] = false
        GSEOptions.MacroResetModifiers["Button5"] = false
        GSEOptions.MacroResetModifiers["LeftAlt"] = false
        GSEOptions.MacroResetModifiers["RightAlt"] = false
        GSEOptions.MacroResetModifiers["Alt"] = false
        GSEOptions.MacroResetModifiers["LeftControl"] = false
        GSEOptions.MacroResetModifiers["RightControl"] = false
        GSEOptions.MacroResetModifiers["Control"] = false
        GSEOptions.MacroResetModifiers["LeftShift"] = false
        GSEOptions.MacroResetModifiers["RightShift"] = false
        GSEOptions.MacroResetModifiers["Shift"] = false
        GSEOptions.MacroResetModifiers["LeftAlt"] = false
        GSEOptions.MacroResetModifiers["RightAlt"] = false
        GSEOptions.MacroResetModifiers["AnyMod"] = false
    end

    -- Fix issue where IsAnyShiftKeyDown() was referenced instead of IsShiftKeyDown() #327
    if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyShift"]) then
        GSEOptions.MacroResetModifiers["Shift"] = GSEOptions.MacroResetModifiers["AnyShift"]
        GSEOptions.MacroResetModifiers["AnyShift"] = nil
    end
    if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyControl"]) then
        GSEOptions.MacroResetModifiers["Control"] = GSEOptions.MacroResetModifiers["AnyControl"]
        GSEOptions.MacroResetModifiers["AnyControl"] = nil
    end
    if not GSE.isEmpty(GSEOptions.MacroResetModifiers["AnyAlt"]) then
        GSEOptions.MacroResetModifiers["Alt"] = GSEOptions.MacroResetModifiers["AnyAlt"]
        GSEOptions.MacroResetModifiers["AnyAlt"] = nil
    end

    if GSE.isEmpty(GSEOptions.showMiniMap) then
        GSEOptions.showMiniMap = {
            hide = true
        }
    end
end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, action)
    -- UPDATE for GSE3
    if unit == "player" then
        local _, GCD_Timer = GetSpellCooldown(61304)
        GCD = true
        C_Timer.After(
            GCD_Timer,
            function()
                GCD = nil
                GSE.PrintDebugMessage("GCD OFF")
            end
        )
        GSE.PrintDebugMessage("GCD Delay:" .. " " .. GCD_Timer)
        GSE.CurrentGCD = GCD_Timer

        local elements = GSE.split(action, "-")
        local spell, _, _, _, _, _ = GetSpellInfo(elements[6])
        local fskilltype, fspellid = GetSpellBookItemInfo(spell)
        if not GSE.isEmpty(fskilltype) then
            if GSE.RecorderActive then
                GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                    GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n"
                )
            end
        end
    end
end

function GSE:PLAYER_REGEN_ENABLED(unit, event, addon)
    GSE:UnregisterEvent("PLAYER_REGEN_ENABLED")
    GSE.ResetButtons()
    GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function GSE:PLAYER_LOGOUT()
    GSE.PrepareLogout()
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
    GSE.ReloadSequences()
end

function GSE:PLAYER_LEVEL_UP()
    GSE.ReloadSequences()
end

function GSE:CHARACTER_POINTS_CHANGED()
    GSE.ReloadSequences()
end

function GSE:SPELLS_CHANGED()
    GSE.ReloadSequences()
end

function GSE:ACTIVE_TALENT_GROUP_CHANGED()
    GSE.ReloadSequences()
end

function GSE:PLAYER_PVP_TALENT_UPDATE()
    GSE.ReloadSequences()
end

function GSE:SPEC_INVOLUNTARILY_CHANGED()
    GSE.ReloadSequences()
end

function GSE:PLAYER_TALENT_UPDATE()
    GSE.ReloadSequences()
end

function GSE:TRAIT_NODE_CHANGED()
    GSE.ReloadSequences()
end
function GSE:TRAIT_NODE_CHANGED_PARTIAL()
    GSE.ReloadSequences()
end
function GSE:TRAIT_NODE_ENTRY_UPDATED()
    GSE.ReloadSequences()
end
function GSE:TRAIT_TREE_CHANGED()
    GSE:UnregisterEvent("TRAIT_TREE_CHANGED")
    GSE.ReloadSequences()
    GSE:RegisterEvent("TRAIT_TREE_CHANGED")
end

function GSE:PLAYER_TARGET_CHANGED()
    GSE:UnregisterEvent("PLAYER_TARGET_CHANGED")
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) and not InCombatLockdown() then
        GSE.ReloadSequences()
    end
    GSE:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function GSE:TRAIT_CONFIG_UPDATED()
    GSE:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    GSE.ReloadSequences()
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")
end
function GSE:ACTIVE_COMBAT_CONFIG_CHANGED()
    GSE.ReloadSequences()
end

function GSE:GROUP_ROSTER_UPDATE(...)
    -- Serialisation stuff
    GSE.sendVersionCheck()
    for k, _ in pairs(GSE.UnsavedOptions["PartyUsers"]) do
        if not (UnitInParty(k) or UnitInRaid(k)) then
            -- Take them out of the list
            GSE.UnsavedOptions["PartyUsers"][k] = nil
        end
    end
    local channel
    if IsInRaid() then
        channel =
            (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
            "RAID"
    else
        channel =
            (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
            "PARTY"
    end
    if #GSE.UnsavedOptions["PartyUsers"] > 1 then
        GSE.SendSpellCache(channel)
    end
    -- Group Team stuff
    GSE:ZONE_CHANGED_NEW_AREA()
end

function GSE:GUILD_ROSTER_UPDATE(...)
    -- Serialisation stuff
    GSE.sendVersionCheck("GUILD")
end

GSE:RegisterEvent("GROUP_ROSTER_UPDATE")
GSE:RegisterEvent("PLAYER_LOGOUT")
GSE:RegisterEvent("PLAYER_ENTERING_WORLD")
GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
GSE:RegisterEvent("ADDON_LOADED")
GSE:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GSE:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GSE:RegisterEvent("UNIT_FACTION")
GSE:RegisterEvent("PLAYER_LEVEL_UP")
GSE:RegisterEvent("GUILD_ROSTER_UPDATE")
GSE:RegisterEvent("PLAYER_TARGET_CHANGED")

if GSE.GameMode > 8 then
    GSE:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    GSE:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    GSE:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
end

if GSE.GameMode >= 10 then
    GSE:RegisterEvent("PLAYER_TALENT_UPDATE")
    GSE:RegisterEvent("SPEC_INVOLUNTARILY_CHANGED")
    GSE:RegisterEvent("TRAIT_NODE_CHANGED")
    GSE:RegisterEvent("TRAIT_NODE_CHANGED_PARTIAL")
    GSE:RegisterEvent("TRAIT_NODE_ENTRY_UPDATED")
    GSE:RegisterEvent("TRAIT_TREE_CHANGED")
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")
    GSE:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
end

if GSE.GameMode <= 3 then
    GSE:RegisterEvent("CHARACTER_POINTS_CHANGED")
    GSE:RegisterEvent("SPELLS_CHANGED")
end

local function PrintGnomeHelp()
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
--- Handle slash commands
function GSE:GSSlash(input)
    local params = GSE.split(input, " ")
    if table.getn(params) > 1 then
        input = params[1]
    end
    local command = string.lower(input)
    if command == "showspec" then
        if GSE.GameMode == 1 then
            GSE.Print(L["Your ClassID is "] .. currentclassId .. " " .. Statics.SpecIDList[currentclassId], GNOME)
        else
            local currentSpec = GetSpecialization()
            local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
            local _, specname, specdescription, specicon, _, specrole, specclass =
                GetSpecializationInfoByID(currentSpecID)
            GSE.Print(
                L["Your current Specialisation is "] ..
                    currentSpecID .. ":" .. specname .. L["  The Alternative ClassID is "] .. currentclassId,
                GNOME
            )
        end
    elseif command == "help" then
        PrintGnomeHelp()
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
    elseif command == "resetoptions" then
        GSE.SetDefaultOptions()
        GSE.Print(L["Options have been reset to defaults."])
        StaticPopup_Show("GSE_ConfirmReloadUIDialog")
    elseif command == "updatemacrostrings" then
        -- Convert macros to new format in a one off run.
        GSE.UpdateMacroString()
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
            local GSE2 = GSE2
            GSE2.GUIShowViewer()
        end
    else
        GSE.CheckGUI()
        if GSE.UnsavedOptions["GUI"] then
            GSE.GUIShowViewer()
        end
    end
end

function GSE:processReload(action, arg)
    if arg == "Samples" then
        GSE.LoadSampleMacros(GSE.GetCurrentClassID())
    end
    if arg == "GSE2Library" then
        GSE.UpdateGSE2LibrarytoGSE3()
    end
end

function GSE:OnEnable()
    GSE.StartOOCTimer()
end

--- Start the OOC Queue Timer
function GSE.StartOOCTimer()
    GSE.OOCTimer =
        GSE:ScheduleRepeatingTimer("ProcessOOCQueue", GSEOptions.OOCQueueDelay and GSEOptions.OOCQueueDelay or 7)
end

--- Stop the OOC Queue Timer
function GSE.StopOOCTimer()
    GSE:CancelTimer(GSE.OOCTimer)
    GSE.OOCTimer = nil
end

function GSE:ProcessOOCQueue()
    -- check ZONE_CHANGED_NEW_AREA issues
    if GSE.currentZone ~= GetRealZoneText() then
        GSE:ZONE_CHANGED_NEW_AREA()
        GSE.currentZone = GetRealZoneText()
    end
    for k, v in ipairs(GSE.OOCQueue) do
        if not InCombatLockdown() then
            if v.action == "UpdateSequence" then
                GSE.OOCUpdateSequence(v.name, v.macroversion)
            elseif v.action == "Save" then
                GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
            elseif v.action == "Replace" then
                if GSE.isEmpty(GSE.Library[v.classid][v.sequencename]) then
                    GSE.AddSequenceToCollection(v.sequencename, v.sequence, v.classid)
                else
                    GSE.ReplaceMacro(v.classid, v.sequencename, v.sequence)
                    GSE.UpdateSequence(v.sequencename, v.sequence.Macros[GSE.GetActiveSequenceVersion(v.sequencename)])
                end
                if v.checkmacro then
                    GSE.CheckMacroCreated(v.sequencename, v.checkmacro)
                end
            elseif v.action == "openviewer" then
                GSE.CheckGUI()
                GSE.GUIShowViewer()
            elseif v.action == "CheckMacroCreated" then
                GSE.OOCCheckMacroCreated(v.sequencename, v.create)
            elseif v.action == "MergeSequence" then
                GSE.OOCPerformMergeAction(v.mergeaction, v.classid, v.sequencename, v.newSequence)
            elseif v.action == "FinishReload" then
                GSE.UnsavedOptions.ReloadQueued = nil
            end
            GSE.OOCQueue[k] = nil
        end
    end
    if not GSE.isEmpty(GSE.GCDLDB) then
        GSE.GCDLDB.value = GSE.GetGCD()
        GSE.GCDLDB.text = string.format("GCD: %ss", GSE.GetGCD())
    end
end

function GSE.prepareTooltipOOCLine(tooltip, OOCEvent, row, oockey)
    tooltip:SetCell(row, 1, L[OOCEvent.action], "LEFT", 1)
    if OOCEvent.action == "UpdateSequence" then
        tooltip:SetCell(row, 3, OOCEvent.name, "RIGHT", 1)
    elseif OOCEvent.action == "Save" then
        tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
    elseif OOCEvent.action == "Replace" then
        tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
    elseif OOCEvent.action == "CheckMacroCreated" then
        tooltip:SetCell(row, 3, OOCEvent.sequencename, "RIGHT", 1)
    end
    tooltip:SetLineScript(
        row,
        "OnMouseUp",
        function()
            table.remove(GSE.OOCQueue, oockey)
        end
    )
end

function GSE.CheckOOCQueueStatus()
    local output
    if GSE.isEmpty(GSE.OOCTimer) then
        output = GSEOptions.UNKNOWN .. L["Paused"] .. Statics.StringReset
    else
        if InCombatLockdown() then
            output = GSEOptions.TitleColour .. L["Paused - In Combat"] .. Statics.StringReset
        else
            output = GSEOptions.CommandColour .. L["Running"] .. Statics.StringReset
        end
    end
    return output
end

function GSE.ToggleOOCQueue()
    if GSE.isEmpty(GSE.OOCTimer) then
        GSE.StartOOCTimer()
    else
        GSE.StopOOCTimer()
    end
end

function GSE.CheckGUI()
    local loaded, reason = LoadAddOn("GSE_GUI")
    if not loaded then
        if reason == "DISABLED" then
            GSE.PrintDebugMessage("GSE GUI Disabled", "GSE_GUI")
            GSE.Print(
                L["The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."]
            )
        elseif reason == "MISSING" then
            GSE.Print(L["The GUI is missing.  Please ensure that your GSE install is complete."])
        elseif reason == "CORRUPT" then
            GSE.Print(L["The GUI is corrupt.  Please ensure that your GSE install is complete."])
        elseif reason == "INTERFACE_VERSION" then
            GSE.Print(L["The GUI needs updating.  Please ensure that your GSE install is complete."])
        end
    end
    return loaded
end

GSE.DebugProfile("Events")

local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local GNOME = "Storage"

--- Delete a sequence from the library
function GSE.DeleteSequence(classid, sequenceName)
    GSE.Library[tonumber(classid)][sequenceName] = nil
    GSESequences[tonumber(classid)][sequenceName] = nil
end

local missingVariables = {}
local function manageMissingVariable(varname)
    if not missingVariables[varname] then
        GSE.Print(L["Missing Variable "] .. varname, "GSE " .. Statics.DebugModules["API"])
        missingVariables[varname] = 0
    end
    missingVariables[varname] = missingVariables[varname] + 1
    if missingVariables[varname] > 100 then
        GSE.Print(L["Missing Variable "] .. varname, "GSE " .. Statics.DebugModules["API"])
        missingVariables[varname] = 0
    end
end

function GSE.CloneSequence(orig)
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

function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
    local vals = {}
    vals.action = "MergeSequence"
    vals.sequencename = sequenceName
    vals.newSequence = newSequence
    vals.classid = classid
    vals.mergeaction = action
    table.insert(GSE.OOCQueue, vals)
end

--- Replace a current version of a Macro
function GSE.ReplaceSequence(classid, sequenceName, sequence)
    GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
    GSE.Library[classid][sequenceName] = sequence
    GSE:SendMessage(Statics.SEQUENCE_UPDATED, sequenceName)
end

--- Load the GSEStorage into a new table.
function GSE.LoadStorage(destination)
    GSE.LoadVariables()
    if GSE.isEmpty(destination) then
        destination = {}
    end
    if GSE.isEmpty(GSESequences) then
        GSESequences = {}
        for iind = 0, 13 do
            GSESequences[iind] = {}
        end
    end
    for k = 0, 13 do
        if GSE.isEmpty(destination[k]) then
            destination[k] = {}
        end
        local v = GSESequences[k]
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

--- Load the GSEVariables
function GSE.LoadVariables()
    if GSE.isEmpty(GSEVariables) then
        GSEVariables = {}
    end
    for k, v in pairs(GSEVariables) do
        local status, err =
            pcall(
            function()
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(v)
                GSE.V[k] = loadstring("return " .. uncompressedVersion.funct)()
                if type(GSE.V[k]()) == "boolean" then
                    GSE.BooleanVariables["GSE.V['" .. k .. "']()"] = "GSE.V['" .. k .. "']()"
                end
            end
        )
        if err then
            GSE.Print(
                "There was an error processing " ..
                    k .. ", You will need to correct errors in this variable from another source.",
                err
            )
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

function GSE.ReloadSequences()
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) then
        GSE.PerformReloadSequences()
        GSE.UnsavedOptions.ReloadQueued = true
    end
    GSE.ManageMacros()
end

function GSE.PerformReloadSequences(force)
    GSE.PrintDebugMessage("Reloading Sequences", Statics.DebugModules["Storage"])
    local func = GSE.UpdateSequence
    if force then
        func = GSE.OOCUpdateSequence
    end
    for name, sequence in pairs(GSE.Library[GSE.GetCurrentClassID()]) do
        if not sequence.MetaData.Disabled then
            func(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
        end
    end
    if not GSE.isEmpty(GSE.Library[0]) then
        for name, sequence in pairs(GSE.Library[0]) do
            if GSE.isEmpty(sequence.MetaData.Disabled) then
                func(name, sequence.Macros[GSE.GetActiveSequenceVersion(name)])
            end
        end
    end
    local vals = {}
    vals.action = "FinishReload"
    table.insert(GSE.OOCQueue, vals)
end

--- This function is used to clean the local sequence library
function GSE.CleanMacroLibrary(forcedelete)
    -- Clean out the sequences database except for the current version
    if forcedelete then
        GSESequences[GSE.GetCurrentClassID()] = nil
        GSESequences[GSE.GetCurrentClassID()] = {}
        GSE.Library[GSE.GetCurrentClassID()] = nil
        GSE.Library[GSE.GetCurrentClassID()] = {}
        if GSE.GUI and GSE.GUI.Editors then
            for k, _ in GSE.GUI.Editors do
                k:Hide()
                k:ReleaseChildren()
                k:Release()
            end
            GSE.GUI.Editors = {}
        end
    end
end

--- This function resets a gsebutton back to its initial setting
function GSE.ResetButtons()
    for k, _ in pairs(GSE.UsedSequences) do
        local gsebutton = _G[k]
        gsebutton:SetAttribute("step", 1)
        GSE.UpdateIcon(gsebutton, true)
        GSE.UsedSequences[k] = nil
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
    local actionCount = #compiledTemplate
    if actionCount > 64516 then
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
    if GSE.GUI and not GSE.isEmpty(GSE.GUIEditFrame) then
        if not GSE.isEmpty(GSE.GUIEditFrame.IsVisible) then
            if GSE.GUIEditFrame:IsVisible() then
                GSE.GUIEditFrame:SetStatusText(name .. " " .. L["Saved"])
                C_Timer.After(
                    5,
                    function()
                        GSE.GUIEditFrame:SetStatusText("")
                    end
                )
                GSE.ShowSequences()
            end
        end
    end
end

--- Return whether to store the macro in Personal Character Macros or Account Macros
function GSE.SetMacroLocation()
    local numAccountMacros, numCharacterMacros = GetNumMacros()
    local returnval
    returnval = 1
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
    if GSE.isEmpty(GSEOptions.filterList) then
        GSEOptions.filterList = {}
        GSEOptions.filterList[Statics.Spec] = true
        GSEOptions.filterList[Statics.Class] = true
        GSEOptions.filterList[Statics.All] = false
        GSEOptions.filterList[Statics.Global] = true
    end
    local keyset = {}
    for k, _ in pairs(Library) do
        if GSEOptions.filterList[Statics.All] or k == GSE.GetCurrentClassID() then
            for i, j in pairs(Library[k]) do
                local disable = 0
                if j.DisableEditor then
                    disable = 1
                end
                local keyLabel = k .. "," .. j.MetaData.SpecID .. "," .. i .. "," .. disable
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
                    local keyLabel = k .. "," .. j.MetaData.SpecID .. "," .. i .. "," .. disable
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

function GSE.GetSpellsFromString(str)
    local spellinfo = {}
    if string.sub(str, 14) == "/click GSE.Pau" then
        spellinfo.name = "GSE Pause"
        spellinfo.iconID = Statics.ActionsIcons.Pause
    else
        for cmd, oetc in gmatch(str or "", "/(%w+)%s+([^\n]+)") do
            if strlower(cmd) == "castsequence" then
                local returnspells = {}
                local processed = {}
                for _, y in ipairs(GSE.split(oetc, ";")) do
                    for _, v in ipairs(GSE.SplitCastSequence(y)) do
                        local _, _, etc = GSE.GetConditionalsFromString(v)
                        local elements = GSE.split(etc, ",")

                        for _, v1 in ipairs(elements) do
                            local spellstuff = C_Spell.GetSpellInfo(string.trim(v1))
                            if spellstuff and spellstuff.name and not processed[v1] then
                                table.insert(returnspells, spellstuff)
                                processed[v1] = true
                            end
                        end
                    end
                end
                return returnspells
            elseif Statics.CastCmds[strlower(cmd)] then
                local _, _, etc = GSE.GetConditionalsFromString("/" .. cmd .. " " .. oetc)
                if string.sub(etc, 1, 1) == "/" then
                    etc = oetc
                end
                if cmd and etc and strlower(cmd) == "use" and tonumber(etc) and tonumber(etc) <= 16 then
                    -- we have a trinket
                else
                    local spell, _ = SecureCmdOptionParse(etc)
                    if spell then
                        spellinfo = C_Spell.GetSpellInfo(spell)
                    end
                end
            end
        end
    end
    if spellinfo and spellinfo.name then
        return spellinfo
    end
end

function GSE.UpdateIcon(self, reseticon)
    local step = self:GetAttribute("step") or 1
    local iteration = self:GetAttribute("iteration") or 1
    if iteration > 1 then
        step = step + iteration * 254
    end
    local gsebutton = self:GetName()
    if not reseticon and self:GetAttribute("combatreset") == true then
        GSE.UsedSequences[gsebutton] = true
    end
    local mods = self:GetAttribute("localmods") or nil

    local executionseq = GSE.SequencesExec[gsebutton]
    local foundSpell =
        executionseq and executionseq[step] and executionseq[step].spell and executionseq[step].spell or ""
    local spellinfo = {}
    spellinfo.iconID = Statics.QuestionMarkIconID

    local reset = self:GetAttribute("combatreset") and self:GetAttribute("combatreset") or false
    if reseticon == true then
        spellinfo.name = gsebutton
        spellinfo.iconID = "Interface\\Addons\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.blp"
        foundSpell = gsebutton
    elseif executionseq[step].type == "macro" and executionseq[step].macrotext then
        spellinfo = GSE.GetSpellsFromString(executionseq[step].macrotext)
        if spellinfo and #spellinfo > 1 then
            spellinfo = spellinfo[1]
        end
        if spellinfo and spellinfo.name then
            foundSpell = spellinfo.name
        end
    elseif executionseq[step].type == "macro" then
        local mname, micon = GetMacroInfo(executionseq[step].macro)
        if mname then
            spellinfo.name = mname
            spellinfo.iconID = micon
            foundSpell = spellinfo.name
        end
    elseif executionseq[step].type == "item" then
        local mname, _, _, _, _, _, _, _, _, micon = C_Item.GetItemInfo(GSE.UnEscapeString(executionseq[step].item))
        if mname then
            spellinfo.name = mname
            spellinfo.iconID = micon
            foundSpell = spellinfo.name
        end
    elseif executionseq[step].type == "spell" then
        spellinfo = C_Spell.GetSpellInfo(GSE.UnEscapeString(executionseq[step].spell))
        if spellinfo then
            foundSpell = spellinfo.name
        else
            GSE.Print("Unable to find spell: " .. GSE.UnEscapeString(executionseq[step].spell) .. " from " .. self:GetName() .. " - Compiled Step " .. step)
        end
    end
    if executionseq[step].Icon then
        if not spellinfo then
            spellinfo = {}
        end
        spellinfo.iconID = executionseq[step].Icon
    end
    if mods then
        local modlist = {}
        for _, j in ipairs(strsplittable("|", mods)) do
            local a, b = string.split("=", j)
            if a == "MOUSEBUTTON" then
                modlist[a] = b
            else
                modlist[a] = b == "true" and true or false
            end
        end
        if WeakAuras then
            WeakAuras.ScanEvents("GSE_MODS_VISIBLE", gsebutton, modlist)
        end
    end
    if spellinfo and spellinfo.iconID then
        if WeakAuras then
            WeakAuras.ScanEvents("GSE_SEQUENCE_ICON_UPDATE", gsebutton, spellinfo)
        end

        if GSE.ButtonOverrides then
            for k, v in pairs(GSE.ButtonOverrides) do
                if v == gsebutton and _G[k] then
                    if
                        string.sub(k, 1, 5) == "ElvUI" or string.sub(k, 1, 4) == "CPB_" or string.sub(k, 1, 3) == "BT4" or
                            string.sub(k, 1, 4) == "NDui"
                     then
                        _G[k].icon:SetTexture(spellinfo.iconID)
                    else
                        if GSE.GameMode == 11 then
                            local parent, slot = _G[k] and _G[k]:GetParent():GetParent(), _G[k] and _G[k]:GetID()
                            local page = parent and parent:GetAttribute("actionpage")
                            local action = page and slot and slot > 0 and (slot + page * 12 - 12)
                            if action then
                                local at = GetActionInfo(action)
                                if GSE.isEmpty(at) then
                                    _G[k].icon:SetTexture(spellinfo.iconID)

                                    _G[k].icon:Show()
                                    _G[k].TextOverlayContainer.Count:SetText(gsebutton)
                                    _G[k].TextOverlayContainer.Count:SetTextScale(0.6)
                                end
                            end
                        else
                            if _G[k] then
                                if not InCombatLockdown() then
                                    _G[k]:Show()
                                end
                                _G[k].icon:SetTexture(spellinfo.iconID)
                                _G[k].icon:Show()
                            -- _G[k].TextOverlayContainer.Count:SetText(gsebutton)
                            -- _G[k].TextOverlayContainer.Count:SetTextScale(0.6)
                            end
                        end
                    end
                end
            end
        end
    end
    if not reset then
        GSE.UsedSequences[gsebutton] = true
    end
    if GSE.Utils then
        GSE.TraceSequence(gsebutton, step, foundSpell)
    end
    GSE.WagoAnalytics:Switch(gsebutton .. "_" .. GSE.GetCurrentClassID(), true)
end

--- Takes a collection of Sequences and returns a list of names
function GSE.GetSequenceNamesFromLibrary(library)
    local sequenceNames = {}
    for k, _ in pairs(library) do
        table.insert(sequenceNames, k)
    end
    return sequenceNames
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
        (decompresssuccess) and (#actiontable == 2) and (type(actiontable[1]) == "string") and
            (type(actiontable[2]) == "table")
     then
        seqName = actiontable[1]
        returnstr = GSE.Dump(actiontable[2])
    end
    return returnstr, seqName, decompresssuccess
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

local function buildAction(action, metaData, variables)
    if action.Type == Statics.Actions.Loop then
        -- we have a loop within a loop
        return GSE.processAction(action, metaData, variables)
    else
        if GSE.isEmpty(action.type) then
            action.type = "spell"
        end
        local spelllist = {}
        for k, v in pairs(action) do
            local value = v
            if k == "Disabled" or type(value) == "boolean" or k == "Type" or k == "Interval" then
                -- we dont want to do anything here
            else
                if string.sub(value, 1, 1) == "=" then
                    xpcall(
                        function()
                            local tempval = loadstring("return " .. string.sub(value, 2, string.len(value)))()
                            if tempval then
                                value = tostring(tempval)
                            else
                                GSE.Print(L["There was an error processing "] .. value, Statics.DebugModules["API"])
                            end
                        end,
                        function(err)
                            manageMissingVariable(string.sub(value, 2, string.len(value)))
                        end
                    )
                end

                if k == "spell" then
                    spelllist[k] = GSE.GetSpellId(value, Statics.TranslatorMode.String)
                elseif k == "macro" then
                    if string.sub(GSE.UnEscapeString(value), 1, 1) == "/" then
                        -- we have a line of macrotext
                        spelllist["macrotext"] =
                            GSE.UnEscapeString(GSE.CompileMacroText(value, Statics.TranslatorMode.String))
                    else
                        spelllist[k] = value
                    end
                    spelllist["unit"] = nil
                else
                    spelllist[k] = value
                end
            end
        end
        return spelllist
    end
end

local function processRepeats(actionList)
    local inserts = {}
    local removes = {}
    for k, v in ipairs(actionList) do
        if type(v) == "table" and v.Action and v.Interval then
            table.insert(inserts, {Action = v.Action, Interval = v.Interval + 1, Start = k})
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
        for _, v in ipairs(action) do
            local builtaction = GSE.processAction(v, metaData, variables)
            table.insert(actionList, builtaction)
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
                for x = 1, #actionList do
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
        return processRepeats(GSE.FlattenTable(returnActions))
    elseif action.Type == Statics.Actions.Pause then
        local PauseActions = {}
        local clicks = action.Clicks and action.Clicks or 0
        if not GSE.isEmpty(action.MS) then
            if action.MS == "GCD" or action.MS == "~~GCD~~" then
                clicks = GSE.GetGCD() * 1000 / GSE.GetClickRate()
            else
                clicks = action.MS and action.MS and 1000 -- pause for 1 second if no ms specified.
                clicks = math.ceil(clicks / GSE.GetClickRate())
            end
        end
        if clicks > 1 then
            for loop = 1, clicks do
                table.insert(PauseActions, {["type"] = "click"})
                GSE.PrintDebugMessage(loop, "Storage1")
            end
        end
        -- print(#PauseActions, GSE.Dump(action))
        return PauseActions
    elseif action.Type == Statics.Actions.If then
        -- process repeats for the block
        if GSE.isEmpty(action.Variable) then
            GSE.Print(L["If Blocks Require a variable."], L["Macro Compile Error"])
            return
        end
        local funct = action.Variable
        if string.sub(funct, 1, 1) == "=" then
            funct = string.sub(funct, 2, string.len(funct))
        end

        local val = loadstring("return " .. funct)()

        local actions
        if val then
            actions = action[1]
        else
            if action[2] then
                actions = action[2]
            else
                return
            end
        end

        local actionList = {}
        for _, v in ipairs(actions) do
            local builtaction = GSE.processAction(v, metaData, variables)
            table.insert(actionList, builtaction)
        end

        return actionList
    elseif action.Type == Statics.Actions.Action then
        local builtstuff = buildAction(action, metaData)
        return builtstuff
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
            ["Interval"] = tonumber(action.Interval)
        }

        return returnAction
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
        table.insert(actions, action)
    end
    local compiledMacro = GSE.processAction(actions, template.InbuiltVariables, template.Variables)

    return processRepeats(GSE.FlattenTable(compiledMacro)), template
end

local function PCallCreateGSE3Button(spelllist, name, combatReset)
    if GSE.isEmpty(spelllist) then
        GSE.Print("Macro missing for " .. name)
        return
    end

    for k, v in ipairs(spelllist) do
        if v.type == "macro" then
            spelllist[k].unit = nil
        end
    end

    if GSE.isEmpty(combatReset) then
        combatReset = false
    end

    -- name = name .. "T"
    GSE.SequencesExec[name] = spelllist
    local gsebutton = _G[name]
    local buttoncreate = GSE.isEmpty(gsebutton)
    -- if button already exists no need to recreate it.  Maybe able to create this in combat.
    if buttoncreate then
        gsebutton = CreateFrame("Button", name, nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        gsebutton:SetAttribute("type", "spell")
        gsebutton:SetAttribute("step", 1)
        gsebutton:SetAttribute("name", name)
        gsebutton.UpdateIcon = GSE.UpdateIcon
        gsebutton:RegisterForClicks("AnyUp", "AnyDown")

        gsebutton:SetAttribute("combatreset", combatReset)
    end

    for k, v in pairs(spelllist[1]) do
        if k == "macrotext" then
            gsebutton:SetAttribute("macro", nil)
            gsebutton:SetAttribute("unit", nil)
        elseif k == "macro" then
            gsebutton:SetAttribute("macrotext", nil)
            gsebutton:SetAttribute("unit", nil)
        end
        gsebutton:SetAttribute(k, v)
    end

    gsebutton:SetAttribute("stepped", false)
    local steps = {}

    for k, v in ipairs(spelllist) do
        local line
        steps[k] = {}
        for i, j in pairs(v) do
            line = i .. "\002" .. j
            tinsert(steps[k], line)
        end
    end

    local compressedsteps = {}
    for _, v in ipairs(steps) do
        table.insert(compressedsteps, string.join("|", unpack(v)))
    end
    local bigsequence = {}

    local finalsteps = 1
    local temptable = {}
    for k, v in ipairs(compressedsteps) do
        table.insert(temptable, v)
        finalsteps = finalsteps + 1
        if finalsteps == 254 or k == #compressedsteps then
            table.insert(bigsequence, string.join("\001", unpack(temptable)))
            temptable = {}
            finalsteps = 1
        end
    end

    local executestring =
        "compressedspelllist = newtable([=======[" ..
        string.join("]=======],[=======[", unpack(bigsequence)) ..
            "]=======])" ..
                [==[
maxsequences = 1
spelllist = newtable()
for k,v in ipairs(compressedspelllist) do
    tinsert(spelllist, newtable())
    for x, y in ipairs(newtable(strsplit("\001",v))) do
        tinsert(spelllist[k], newtable())
        for _,j in ipairs(newtable(strsplit("|",y))) do
            local a,b = strsplit("\002",j)
            spelllist[k][x][a] = b
        end
    end
    maxsequences = k
end
]==]

    gsebutton:Execute(executestring)
    if combatReset then
        _G[name]:SetAttribute("step", 1)
        _G[name]:SetAttribute("iteration", 1)
    end

    local clickexecution =
        GSE.GetMacroResetImplementation() ..
        [=[
    local mods = "RALT=" .. tostring(IsRightAltKeyDown()) .. "|" ..
    "LALT=".. tostring(IsLeftAltKeyDown()) .. "|" ..
    "AALT=" .. tostring(IsAltKeyDown()) .. "|" ..
    "RCTRL=" .. tostring(IsRightControlKeyDown()) .. "|" ..
    "LCTRL=" .. tostring(IsLeftControlKeyDown()) .. "|" ..
    "ACTRL=" .. tostring(IsControlKeyDown()) .. "|" ..
    "RSHIFT=" .. tostring(IsRightShiftKeyDown()) .. "|" ..
    "LSHIFT=" .. tostring(IsLeftShiftKeyDown()) .. "|" ..
    "ASHIFT=" .. tostring(IsShiftKeyDown()) .. "|" ..
    "AMOD=" .. tostring(IsModifierKeyDown()) .. "|" ..
    "MOUSEBUTTON=" .. GetMouseButtonClicked()
    self:SetAttribute('localmods', mods)
    local step = self:GetAttribute('step')
    local iteration = self:GetAttribute('iteration') or 1
    step = tonumber(step)
    iteration = tonumber(iteration)
    for k,v in pairs(spelllist[iteration][step]) do
        if k == "macrotext" then
            self:SetAttribute("macro", nil )
            self:SetAttribute("unit", nil )
        elseif k == "macro" then
            self:SetAttribute("macrotext", nil )
            self:SetAttribute("unit", nil )
        elseif k == "Icon" then
            -- skip
        end
        self:SetAttribute(k, v )
    end

    if step < #spelllist[iteration] then
        step = step % #spelllist[iteration] + 1
    else
        iteration = iteration % maxsequences + 1
        step = 1
    end
    self:SetAttribute('step', step)
    self:SetAttribute('iteration', iteration)
    self:CallMethod('UpdateIcon')
    ]=]
    if GSEOptions.Multiclick then
        clickexecution =
            GSE.GetMacroResetImplementation() ..
            [=[
    local mods = "RALT=" .. tostring(IsRightAltKeyDown()) .. "|" ..
    "LALT=".. tostring(IsLeftAltKeyDown()) .. "|" ..
    "AALT=" .. tostring(IsAltKeyDown()) .. "|" ..
    "RCTRL=" .. tostring(IsRightControlKeyDown()) .. "|" ..
    "LCTRL=" .. tostring(IsLeftControlKeyDown()) .. "|" ..
    "ACTRL=" .. tostring(IsControlKeyDown()) .. "|" ..
    "RSHIFT=" .. tostring(IsRightShiftKeyDown()) .. "|" ..
    "LSHIFT=" .. tostring(IsLeftShiftKeyDown()) .. "|" ..
    "ASHIFT=" .. tostring(IsShiftKeyDown()) .. "|" ..
    "AMOD=" .. tostring(IsModifierKeyDown()) .. "|" ..
    "MOUSEBUTTON=" .. GetMouseButtonClicked()
    self:SetAttribute('localmods', mods)
    local iteration = self:GetAttribute('iteration') or 1
    local step = self:GetAttribute('step')
    step = tonumber(step)
    iteration = tonumber(iteration)
    if self:GetAttribute('stepped') then
        self:SetAttribute('stepped', false)
    else
        for k,v in pairs(spelllist[iteration][step]) do
            if k == "macrotext" then
                self:SetAttribute("macro", nil )
                self:SetAttribute("unit", nil )
            elseif k == "macro" then
                self:SetAttribute("macrotext", nil )
                self:SetAttribute("unit", nil )
            elseif k == "Icon" then
                -- skip
            end
            self:SetAttribute(k, v )
        end

        self:SetAttribute('stepped', true)
        if step < #spelllist[iteration] then
            step = step % #spelllist[iteration] + 1
        else
            iteration = iteration % maxsequences + 1
            step = 1
        end

        self:SetAttribute('step', step)
        self:SetAttribute('iteration', iteration)
        self:CallMethod('UpdateIcon')
    end
    ]=]
    end
    if GSEOptions.DebugPrintModConditionsOnKeyPress then
        clickexecution = Statics.PrintKeyModifiers .. clickexecution
    end
    if buttoncreate then
        gsebutton:WrapScript(gsebutton, "OnClick", clickexecution)
    end
    GSE.UpdateIcon(_G[name], true)
end

--- Build GSE3 Executable Buttons
function GSE.CreateGSE3Button(spelllist, name, combatReset)
    local status, err = pcall(PCallCreateGSE3Button, spelllist, name, combatReset)
    if err or not status then
        GSE.Print(
            string.format(
                "%s " ..
                    L["was unable to be programmed.  This macro will not fire until errors in the macro are corrected."],
                name
            ),
            "BROKEN MACRO"
        )
        print(err)
    end
end

function GSE.UpdateVariable(variable, name, status)
    local compressedvariable = GSE.EncodeMessage(variable)
    GSEVariables[name] = compressedvariable
    local actualfunct, error = loadstring("return " .. variable.funct)
    if error then
        print(error)
    end
    if type(actualfunct) == "function" then
        GSE.V[name] = actualfunct()
    end
    if GSE.V[name] and type(GSE.V[name]()) == "boolean" then
        GSE.BooleanVariables["GSE.V['" .. name .. "']()"] = "GSE.V['" .. name .. "']()"
    end
    GSE:SendMessage(Statics.VARIABLE_UPDATED, name)
end

function GSE.UpdateMacro(node, category)
    if not InCombatLockdown() then
        GSE:UnregisterEvent("UPDATE_MACROS")
        local slot = GetMacroIndexByName(node.name)
        if slot > 0 then
            EditMacro(slot, node.name, node.icon, node.text)
        else
            node.value = CreateMacro(node.name, node.icon, node.text, category)
            if category then
                local char, realm = UnitFullName("player")
                GSEMacros[char .. "-" .. realm][node.name] = node
            else
                GSEMacros[node.name] = node
            end
        end
        GSE:RegisterEvent("UPDATE_MACROS")
        GSE:SendMessage(Statics.VARIABLE_UPDATED, node.name)
    end
    return node
end

function GSE.ImportMacro(node)
    local characterMacro = false
    local source = GSEMacros
    if node.category == "p" then
        characterMacro = true
        local char, realm = UnitFullName("player")
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        source = GSEMacros[char .. "-" .. realm]
    end
    node.category = nil

    source[node.name] = GSE.UpdateMacro(node, characterMacro)
    GSE.Print(L["Macro"] .. " " .. node.name .. L[" was imported."], L["Macros"])
    GSE.ManageMacros()
    GSE:SendMessage(Statics.VARIABLE_UPDATED, node.name)
end

function GSE.CompileMacroText(text, mode)
    if GSE.isEmpty(mode) then
        mode = Statics.TranslatorMode.ID
    end
    local lines = GSE.SplitMeIntoLines(text)
    for k, v in ipairs(lines) do
        local value = GSE.UnEscapeString(v)
        if mode == Statics.TranslatorMode.String then
            if string.sub(value, 1, 1) == "=" then
                local functionresult, error = loadstring("return " .. string.sub(value, 2, string.len(value)))

                if error then
                    GSE.Print(L["There was an error processing "] .. v, L["Variables"])
                    GSE.Print(error, L["Variables"])
                end
                if functionresult and type(functionresult) == "function" then
                    if pcall(functionresult) then
                        value = functionresult()
                    else
                        value = ""
                    end
                end
            end
            if value and string.len(value) > 2 and string.sub(value, 1, 2) == "--" then
                lines[k] = "" -- strip the comments
            else
                if value then
                    lines[k] = GSE.TranslateString(value, mode, false)
                else
                    lines[k] = ""
                end
            end
        else
            lines[k] = GSE.TranslateString(value, mode, false)
        end
    end
    local finallines = {}
    for _, v in ipairs(lines) do
        if not GSE.isEmpty(v) then
            table.insert(finallines, v)
        end
    end
    return table.concat(finallines, "\n")
end

function GSE.ManageMacros()
    for k, v in pairs(GSEMacros) do
        if v.Managed then
            local macroIndex = GetMacroIndexByName(k)
            if macroIndex ~= v.value then
                v.value = macroIndex
                GSEMacros[k].value = macroIndex
            end
            local node = {
                ["name"] = k,
                ["value"] = v.value,
                ["icon"] = v.icon,
                ["text"] = GSE.CompileMacroText(
                    (v.managedMacro and v.managedMacro or v.text),
                    Statics.TranslatorMode.String
                )
            }
            GSE.UpdateMacro(node)
        else
            local slot = GetMacroIndexByName(k)
            if slot then
                local mname, micon, mbody = GetMacroInfo(slot)
                if mname then
                    GSEMacros[mname] = {
                        ["name"] = mname,
                        ["value"] = slot,
                        ["icon"] = micon,
                        ["text"] = mbody,
                        ["manageMacro"] = mbody
                    }
                else
                    GSEMacros[k] = nil
                end
            else
                if type(GSEMacros[k]) ~= "table" then
                    GSEMacros[k] = nil
                end
            end
        end
    end
    local char, realm = UnitFullName("player")
    if GSE.isEmpty(realm) then
        realm = string.gsub(GetRealmName(), "%s*", "")
    end

    if GSEMacros[char .. "-" .. realm] then
        for k, v in pairs(GSEMacros[char .. "-" .. realm]) do
            if k == "value" then
                GSEMacros[char .. "-" .. realm][k] = nil
            else
                if v.Managed then
                    local macroIndex = GetMacroIndexByName(k)
                    if macroIndex ~= v.value then
                        v.value = macroIndex
                        GSEMacros[char .. "-" .. realm][k].value = macroIndex
                    end
                    local node = {
                        ["name"] = k,
                        ["value"] = v.value,
                        ["icon"] = v.icon,
                        ["text"] = GSE.CompileMacroText(
                            (v.managedMacro and v.managedMacro or v.text),
                            Statics.TranslatorMode.String
                        )
                    }
                    GSE.UpdateMacro(node)
                else
                    local slot = GetMacroIndexByName(k)
                    if slot then
                        local mname, micon, mbody = GetMacroInfo(slot)
                        if mname then
                            GSEMacros[char .. "-" .. realm][mname] = {
                                ["name"] = mname,
                                ["value"] = slot,
                                ["icon"] = micon,
                                ["text"] = mbody,
                                ["manageMacro"] = mbody
                            }
                        else
                            GSEMacros[char .. "-" .. realm][k] = nil
                        end
                    else
                        if type(GSEMacros[char .. "-" .. realm][k]) ~= "table" then
                            GSEMacros[char .. "-" .. realm][k] = nil
                        end
                    end
                end
            end
        end
    end
end

function GSE.CheckVariable(vartext)
    local actualfunct, error = loadstring("return " .. vartext)
    return actualfunct, error
end

GSE.DebugProfile("Storage")

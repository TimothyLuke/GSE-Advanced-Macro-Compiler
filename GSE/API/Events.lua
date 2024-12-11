local GNOME, _ = ...

local GSE = GSE

local L = GSE.L
local Statics = GSE.Static

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
    if type == "scenario" or difficulty == 167 or difficulty == 152 or difficulty == 208 then
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

local function GetSpec()
    if GSE.GameMode < 7 then
        return "1"
    else
        return tostring(GetSpecialization())
    end
end

local function playerSpec()
    if GSE.GameMode < 3 then
        return 1
    else
        return PlayerUtil.GetCurrentSpecID()
    end
end

local SHBT = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate,SecureFrameTemplate")

local function overrideActionButton(savedBind, force)
    if GSE.isEmpty(GSE.ButtonOverrides) then
        GSE.ButtonOverrides = {}
    end
    local Button = savedBind.Bind
    if not _G[Button] then
        return
    end
    local Sequence = savedBind.Sequence
    local state =
        savedBind.State and savedBind.State or string.sub(Button, 1, 3) == "BT4" and "0" or
        string.sub(Button, 1, 4) == "CPB_" and "" or
        "1"

    if
        (string.sub(Button, 1, 4) == "CPB_" or string.sub(Button, 1, 3) == "BT4") and
            not GSEOptions.DisableExperimentalLAB
     then
        if _G[Button] and _G[Button].SetState then
            _G[Button]:SetAttribute("gse-button", Sequence)
            _G[Button]:SetState(
                state,
                "click",
                {
                    func = function(self)
                        if not InCombatLockdown() then
                            self:SetAttribute("type", "click")
                            self:SetAttribute("clickbutton", _G[self:GetAttribute("gse-button")])
                        end
                    end,
                    tooltip = "GSE: " .. Sequence,
                    texture = "Interface\\Addons\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.blp"
                }
            )
            GSE.ButtonOverrides[Button] = Sequence
            _G[Button]:SetAttribute("type", "click")
            _G[Button]:SetAttribute("clickbutton", _G[Sequence])
        end
    elseif string.sub(Button, 1, 5) == "ElvUI" or GSEOptions.DisableExperimentalLAB then
        if _G[Button] and _G[Button].SetState then
            _G[Button]:SetAttribute("gse-button", Sequence)
            _G[Button]:SetState(
                state,
                "custom",
                {
                    func = function(self)
                        if not InCombatLockdown() then
                            self:SetAttribute("type", "click")
                            self:SetAttribute("clickbutton", _G[self:GetAttribute("gse-button")])
                        end
                    end,
                    tooltip = "GSE: " .. Sequence,
                    texture = "Interface\\Addons\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.blp",
                    type = "click",
                    clickbutton = _G[Sequence]
                }
            )
            GSE.ButtonOverrides[Button] = Sequence
            _G[Button]:SetAttribute("type", "click")
            _G[Button]:SetAttribute("clickbutton", _G[Sequence])

            SHBT:WrapScript(
                _G[Button],
                "OnClick",
                [[
                type = self:GetAttribute("type")
                if type == "custom" then
                    self:SetAttribute("type", "click")
                end
            ]]
            )
        end
    else
        if not InCombatLockdown() then
            if (not GSE.ButtonOverrides[Button] or force) then
                SHBT:WrapScript(
                    _G[Button],
                    "OnClick",
                    [[
    local parent, slot = self and self:GetParent():GetParent(), self and self:GetID()
    local page = parent and parent:GetAttribute("actionpage")
    local action = page and slot and slot > 0 and (slot + page*12 - 12)
    if action or HasOverrideActionBar() then
        if HasOverrideActionBar() then
            _G["OverrideActionBarButton2"]:Click()
        else
            local at, id = GetActionInfo(action)
            if at and id then
                self:SetAttribute("type", "action")
                self:SetAttribute('action', action)
            else
                self:SetAttribute("type", "click")
            end
        end
    end
]]
                )
                _G[Button]:SetAttribute("type", "click")

                GSE.ButtonOverrides[Button] = Sequence

            --if number and GetBindingByKey(number) and string.upper(GetBindingByKey(number)) == string.upper(Button) then
            --SetBindingClick(number, Button, _G[Button])
            --end
            end

            _G[Button]:SetAttribute("clickbutton", _G[Sequence])
        end
    end
end
local function LoadOverrides(force)
    if GSE.isEmpty(GSE.ButtonOverrides) then
        GSE.ButtonOverrides = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        GSE_C["ActionBarBinds"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
        GSE_C["ActionBarBinds"]["Specialisations"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()]) then
        GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
        GSE_C["ActionBarBinds"]["LoadOuts"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()]) then
        GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()] = {}
    end
    if not InCombatLockdown() then
        for k, _ in pairs(GSE.ButtonOverrides) do
            -- revert all buttons
            if string.sub(k, 1, 5) == "ElvUI" or string.sub(k, 1, 4) == "CPB_" or string.sub(k, 1, 3) == "BT4" then
                local state = "1"
                --_G[Button]:GetAttribute("state"),
                if string.sub(k, 1, 3) == "BT4" then
                    state = "0"
                elseif string.sub(k, 1, 4) == "CPB_" then
                    state = ""
                end
                _G[k]:SetState(state, "action", tonumber(string.match(k, "%d+$")))
            else
                _G[k]:SetAttribute("type", "action")
            end
        end
        GSE.ButtonOverrides = {}

        for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()]) do
            overrideActionButton(v, force)
        end
        if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
            local selected = playerSpec() and tostring(C_ClassTalents.GetLastSelectedSavedConfigID(playerSpec()))

            if
                selected and GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()] and
                    GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()][selected]
             then
                GSE.PrintDebugMessage("changing from " .. tostring(GSE.GetSelectedLoadoutConfigID()), "EVENTS")
                for k, v in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()][selected]) do
                    overrideActionButton(v, force)
                    GSE.ButtonOverrides[v.Sequence] = k
                end
            end
        end
    end
end

local function LoadKeyBindings(payload)
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE.isEmpty(GSE_C["KeyBindings"]) then
        GSE_C["KeyBindings"] = {}
    end

    if GSE.isEmpty(GSE_C["KeyBindings"][GetSpec()]) then
        GSE_C["KeyBindings"][GetSpec()] = {}
    end

    for k, v in pairs(GSE_C["KeyBindings"][GetSpec()]) do
        if k ~= "LoadOuts" and not InCombatLockdown() then
            SetBindingClick(k, v, _G[v])
        end
    end

    if payload and not InCombatLockdown() then
        if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
            local selected = playerSpec() and tostring(C_ClassTalents.GetLastSelectedSavedConfigID(playerSpec()))
            if
                selected and GSE_C["KeyBindings"][GetSpec()]["LoadOuts"] and
                    GSE_C["KeyBindings"][GetSpec()]["LoadOuts"][selected]
             then
                GSE.PrintDebugMessage(
                    "changing from " .. tostring(payload) .. " " .. tostring(GSE.GetSelectedLoadoutConfigID()),
                    "EVENTS"
                )
                for k, v in pairs(GSE_C["KeyBindings"][GetSpec()]["LoadOuts"][selected]) do
                    SetBinding(k)
                    SetBindingClick(k, v, _G[v])
                end
            end
        end
    end
end
function GSE.ReloadOverrides(force)
    LoadOverrides(force)
end

function GSE.ReloadKeyBindings()
    LoadKeyBindings(true)
end
function GSE:PLAYER_ENTERING_WORLD()
    GSE.PrintAvailable = true
    GSE.PerformPrint()
    GSE.currentZone = GetRealZoneText()
    GSE.PlayerEntered = true
    LoadKeyBindings(GSE.PlayerEntered)
    GSE.PerformReloadSequences(true)

    LoadOverrides()
    GSE:ZONE_CHANGED_NEW_AREA()
    if ConsolePort then
        C_Timer.After(
            10,
            function()
                LoadOverrides()
            end
        )
    end
end

function GSE:ADDON_LOADED(event, addon)
    if addon == GNOME then
        GSE.setupLAB()
        local char = UnitFullName("player")
        local realm = GetRealmName()

        GSE.PerformOneOffEvents()
        if GSE_C and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][char .. "-" .. realm] then
            GSE_C["KeyBindings"][char .. "-" .. realm] = nil
        end

        if GSE.isEmpty(GSESpellCache) then
            GSESpellCache = {
                ["enUS"] = {}
            }
        end

        if GSE.isEmpty(GSESpellCache[GetLocale()]) then
            GSESpellCache[GetLocale()] = {}
        end

        GSE.LoadStorage(GSE.Library)

        if GSE.isEmpty(GSESequences[GSE.GetCurrentClassID()]) then
            GSESequences[GSE.GetCurrentClassID()] = {}
        end
        if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()]) then
            GSE.Library[GSE.GetCurrentClassID()] = {}
        end
        if GSE.isEmpty(GSE.Library[0]) then
            GSE.Library[0] = {}
        end
        if GSE.isEmpty(GSEVariables) then
            GSEVariables = {}
        end
        if GSE.isEmpty(GSEMacros) then
            GSEMacros = {}
        end
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        GSE.PrintDebugMessage("I am loaded")

        GSE:SendMessage(Statics.CoreLoadedMessage)

        -- Register the Sample Macros
        if not GSEOptions.HideLoginMessage then
            GSE.Print(
                L["Advanced Macro Compiler loaded.|r  Type "] ..
                    GSEOptions.CommandColour .. L["/gse help|r to get started."],
                Statics.GSEString
            )
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

        if GSEOptions.shownew then
            GSE:ShowUpdateNotes()
        end
        GSE:RegisterEvent("UPDATE_MACROS")
        GSE.WagoAnalytics:Switch("minimapIcon", GSEOptions.showMiniMap.hide)
    end
end

function GSE:PLAYER_REGEN_ENABLED(unit, event, addon)
    GSE:UnregisterEvent("PLAYER_REGEN_ENABLED")
    GSE.ResetButtons()
    GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function GSE:PLAYER_LOGOUT()
    if not GSE.UnsavedOptions["GUI"] then
        if GSE["MenuFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations) then
                GSEOptions.frameLocations = {}
            end

            if GSE.isEmpty(GSEOptions.frameLocations.menu) then
                GSEOptions.frameLocations.menu = {}
            end
            GSEOptions.frameLocations.menu.top = GSE.MenuFrame.frame:GetTop()
            GSEOptions.frameLocations.menu.left = GSE.MenuFrame.frame:GetLeft()
        end
        if GSE["GUIEditFrame"] and GSE.GUIEditFrame.frame then
            if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
                GSEOptions.frameLocations.sequenceeditor = {}
            end
            GSEOptions.frameLocations.sequenceeditor.top = GSE.GUIEditFrame.frame:GetTop()
            GSEOptions.frameLocations.sequenceeditor.left = GSE.GUIEditFrame.frame:GetLeft()
        end
        if GSE["GUIVariableFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.variablesframe) then
                GSEOptions.frameLocations.variablesframe = {}
            end

            GSEOptions.frameLocations.variablesframe.top = GSE.GUIVariableFrame.frame:GetTop()
            GSEOptions.frameLocations.variablesframe.left = GSE.GUIVariableFrame.frame:GetLeft()
        end
        if GSE["GUIMacroFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.macroframe) then
                GSEOptions.frameLocations.macroframe = {}
            end
            GSEOptions.frameLocations.macroframe.top = GSE.GUIMacroFrame.frame:GetTop()
            GSEOptions.frameLocations.macroframe.left = GSE.GUIMacroFrame.frame:GetLeft()
        end
        if GSE["GUIDebugFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.debug) then
                GSEOptions.frameLocations.debug = {}
            end
            GSEOptions.frameLocations.debug.top = GSE.GUIDebugFrame.frame:GetTop()
            GSEOptions.frameLocations.debug.left = GSE.GUIDebugFrame.frame:GetLeft()
        end
        if GSE["GUIkeybindingframe"] then
            if GSE.isEmpty(GSEOptions.frameLocations.keybindingframe) then
                GSEOptions.frameLocations.keybindingframe = {}
            end
            GSEOptions.frameLocations.keybindingframe.top = GSE.GUIkeybindingframe.frame:GetTop()
            GSEOptions.frameLocations.keybindingframe.left = GSE.GUIkeybindingframe.frame:GetLeft()
        end
    end
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
    if GSE.isEmpty(GSE_C["KeyBindings"][GetSpec()]) then
        GSE_C["KeyBindings"][GetSpec()] = {}
    end
    if not InCombatLockdown() then
        LoadKeyBindings(GSE.PlayerEntered)
        GSE.ReloadSequences()
        LoadOverrides()
    end
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
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_PVP_TALENT_UPDATE()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:SPEC_INVOLUNTARILY_CHANGED()
    GSE.ReloadSequences(GSE.PlayerEntered)
    LoadOverrides()
end

function GSE:TRAIT_NODE_CHANGED()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_TARGET_CHANGED()
    GSE:UnregisterEvent("PLAYER_TARGET_CHANGED")
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) and not InCombatLockdown() then
        GSE.ReloadSequences()
    end
    GSE:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function GSE:TRAIT_CONFIG_UPDATED(_, payload)
    GSE:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")
end
function GSE:ACTIVE_COMBAT_CONFIG_CHANGED()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_TALENT_UPDATE()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences(GSE.PlayerEntered)
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
    local _, _, difficulty, _, _, _, _, _, _ = GetInstanceInfo()
    -- dont trigger the normal things if in a delve
    if difficulty ~= 208 then
        GSE:ZONE_CHANGED_NEW_AREA()
    end
end

function GSE:GUILD_ROSTER_UPDATE(...)
    -- Serialisation stuff
    GSE.sendVersionCheck("GUILD")
end

function GSE:UPDATE_MACROS()
    GSE.ManageMacros()
end

GSE:RegisterEvent("GROUP_ROSTER_UPDATE")
GSE:RegisterEvent("PLAYER_LOGOUT")
GSE:RegisterEvent("PLAYER_ENTERING_WORLD")
GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
GSE:RegisterEvent("ADDON_LOADED")
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

if GSE.GameMode > 10 then
    GSE:RegisterEvent("PLAYER_TALENT_UPDATE")
    GSE:RegisterEvent("SPEC_INVOLUNTARILY_CHANGED")
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")

    GSE:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
end

if GSE.GameMode <= 3 then
    GSE:RegisterEvent("CHARACTER_POINTS_CHANGED")
    GSE:RegisterEvent("SPELLS_CHANGED")
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
                    GSE.ReplaceSequence(v.classid, v.sequencename, v.sequence)
                    GSE.UpdateSequence(v.sequencename, v.sequence.Macros[GSE.GetActiveSequenceVersion(v.sequencename)])
                end
            elseif v.action == "updatevariable" then
                GSE.UpdateVariable(v.variable, v.name)
            elseif v.action == "updatemacro" then
                GSE.UpdateMacro(v.node)
            elseif v.action == "importmacro" then
                GSE.ImportMacro(v.node)
            elseif v.action == "managemacros" then
                GSE.ManageMacros()
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

function GSE.ToggleOOCQueue()
    if GSE.isEmpty(GSE.OOCTimer) then
        GSE.StartOOCTimer()
    else
        GSE.StopOOCTimer()
    end
end

function GSE.CheckGUI()
    local loaded, reason = C_AddOns.LoadAddOn("GSE_GUI")
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

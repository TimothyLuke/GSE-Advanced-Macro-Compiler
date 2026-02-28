local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local function sequenceExists(seqName)
    for _, classLib in pairs(GSE.Library or {}) do
        if classLib[seqName] then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- buildKeybindMenu()  →  full KEYBINDINGS tree node
-- ---------------------------------------------------------------------------
local function buildKeybindMenu()
    local tree = {
        {
            value = "AO",
            text = L["Actionbar Overrides"],
            icon = Statics.Icons.Button,
            children = {
                {
                    value = "NAO",
                    text = L["New Actionbar Override"],
                    icon = Statics.ActionsIcons.Add
                }
            }
        },
        {
            value = "KB",
            text = L["Keybindings"],
            icon = Statics.ActionsIcons.Key,
            children = {
                {
                    value = "NKB",
                    text = L["New KeyBind"],
                    icon = Statics.ActionsIcons.Add
                }
            }
        }
    }

    -- Actionbar Overrides nodes
    for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
        local currentspecid = tonumber(k)
        local node
        if GetSpecializationInfo then
            local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
            node = {
                value = k,
                text = speclabel,
                icon = specIcon,
                children = {}
            }
        else
            node = tree[1]
        end
        local aoOrphans = {}
        for i, j in GSE.pairsByKeys(v) do
            if not sequenceExists(j["Sequence"]) then
                table.insert(aoOrphans, i)
            else
                table.insert(
                    node["children"],
                    {
                        value = i .. "\001" .. j["Sequence"],
                        text = j["Bind"] ..
                            " " .. GSEOptions.KEYWORD .. "(" .. j["Sequence"] .. ")" .. Statics.StringReset
                    }
                )
            end
        end
        for _, i in ipairs(aoOrphans) do v[i] = nil end

        if
            GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["LoadOuts"] and
                GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]
         then
            for i, j in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]) do
                local success, result =
                    pcall(
                    function()
                        local loadout = C_Traits.GetConfigInfo(i)
                        local specnode = {
                            value = i,
                            text = "|cffffcc00" .. loadout.name .. Statics.StringReset,
                            children = {},
                            icon = Statics.Icons.Talents
                        }
                        local loOrphans = {}
                        for l, m in GSE.pairsByKeys(j) do
                            if not sequenceExists(m.Sequence) then
                                table.insert(loOrphans, l)
                            else
                                local nodelabel = l .. " " .. GSEOptions.KEYWORD .. "(" .. m.Sequence
                                if m and m.State then
                                    nodelabel = nodelabel .. " - " .. L["Button State"] .. ": " .. m.State
                                end
                                nodelabel = nodelabel .. "" .. ")" .. Statics.StringReset
                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "\001" .. m.Sequence,
                                        text = nodelabel
                                    }
                                )
                            end
                        end
                        for _, l in ipairs(loOrphans) do j[l] = nil end
                        table.insert(node["children"], specnode)
                    end
                )
                if not success then
                    GSE.PrintDebugMessage(result, "ACTIONBAR OVERRIDES MENU")
                end
            end
        end
        if GetSpecializationInfo then
            table.insert(tree[1]["children"], node)
        end
    end

    -- Keybinding nodes
    for k, v in pairs(GSE_C["KeyBindings"]) do
        local currentspecid = tonumber(k)
        local node
        if GetSpecializationInfo then
            local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
            node = {
                value = k,
                text = speclabel,
                icon = specIcon,
                children = {}
            }
        else
            node = tree[2]
        end
        local kbOrphans = {}
        for i, j in GSE.pairsByKeys(v) do
            if i ~= "LoadOuts" then
                if not sequenceExists(j) then
                    table.insert(kbOrphans, i)
                else
                    table.insert(
                        node["children"],
                        {
                            value = i .. "\001" .. j,
                            text = i .. " " .. GSEOptions.KEYWORD .. "(" .. j .. ")" .. Statics.StringReset
                        }
                    )
                end
            end
        end
        for _, i in ipairs(kbOrphans) do
            if not InCombatLockdown() then SetBinding(i) end
            v[i] = nil
        end

        if
            GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(currentspecid)] and
                GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"]
         then
            for i, j in pairs(GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"]) do
                local success =
                    pcall(
                    function()
                        local loadout = C_Traits.GetConfigInfo(i)
                        local specnode = {
                            value = i,
                            text = "|cffffcc00" .. loadout.name .. Statics.StringReset,
                            children = {},
                            icon = Statics.Icons.Talents
                        }
                        local loKbOrphans = {}
                        for l, m in GSE.pairsByKeys(j) do
                            if not sequenceExists(m) then
                                table.insert(loKbOrphans, l)
                            else
                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "\001" .. m,
                                        text = l .. " " .. GSEOptions.KEYWORD .. "(" .. m .. ")" .. Statics.StringReset
                                    }
                                )
                            end
                        end
                        for _, l in ipairs(loKbOrphans) do
                            if not InCombatLockdown() then SetBinding(l) end
                            j[l] = nil
                        end
                        table.insert(node["children"], specnode)
                    end
                )
                if not success then
                    GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"][i] = nil
                end
            end
        end
        if GetSpecializationInfo then
            table.insert(tree[2]["children"], node)
        end
    end

    return {
        value = "KEYBINDINGS",
        text = L["Keybindings"],
        icon = Statics.Icons.Keybindings,
        children = tree
    }
end

-- ---------------------------------------------------------------------------
-- showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
-- ---------------------------------------------------------------------------
local function showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
    if type == "KB" then
        if not specialization then
            if GSE.GameMode < 10 then
                specialization = 1
            else
                if GSE.GameMode < 12 then
                    specialization = GetSpecialization()
                else
                    specialization = C_SpecializationInfo.GetSpecialization()
                end
            end
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()

        local keybind = AceGUI:Create("ControllerKeybinding")
        keybind:SetLabel(L["Keybind"])
        if not GSE.isEmpty(bind) then
            keybind:SetKey(bind)
        end
        keybind:SetFullWidth(true)
        keybind:SetCallback(
            "OnKeyChanged",
            function(self, _, key)
                bind = key
            end
        )
        keybind:SetLabel(L["Set Key to Bind"])

        local SequenceListbox = AceGUI:Create("Dropdown")
        SequenceListbox:SetFullWidth(true)
        SequenceListbox:SetLabel(L["Sequence"])
        local names = {}
        for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
            names[k] = k
        end
        for k, _ in pairs(GSESequences[0]) do
            names[k] = k
        end
        SequenceListbox:SetList(names)
        SequenceListbox:SetValue(button)
        SequenceListbox:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                button = key
            end
        )

        local TalentLoadOutList = AceGUI:Create("Dropdown")
        TalentLoadOutList:SetFullWidth(true)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = { ["All"] = L["All Talent Loadouts"] }
        if C_ClassTalents then
            for _, v in ipairs(
                C_ClassTalents.GetConfigIDsBySpecID(
                    GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
                )
            ) do
                local loadoutinfo = C_Traits.GetConfigInfo(v)
                loadouts[tostring(v)] = loadoutinfo.name
            end
        end
        TalentLoadOutList:SetList(loadouts)
        if loadout then
            TalentLoadOutList:SetValue(loadout)
        else
            TalentLoadOutList:SetValue("All")
        end
        TalentLoadOutList:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                if key == "All" then
                    loadout = nil
                else
                    loadout = key
                end
            end
        )

        local savebutton = AceGUI:Create("Button")
        savebutton:SetText(L["Save"])
        savebutton:SetCallback(
            "OnClick",
            function()
                if not GSE.isEmpty(SequenceListbox:GetValue()) and not GSE.isEmpty(keybind:GetKey()) then
                    local destination = GSE_C["KeyBindings"][tostring(specialization)]
                    if loadout ~= "ALL" and loadout then
                        if GSE.isEmpty(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"]) then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] = {}
                        end
                        if GSE.isEmpty(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = {}
                        end
                        destination = GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                    end
                    if initialbind and bind ~= initialbind and not InCombatLockdown() then
                        SetBinding(initialbind)
                        destination[bind] = nil
                    end
                    if destination then
                        destination[bind] = button
                    else
                        GSE.PrintDebugMessage(
                            "Error Saving Keybind " .. bind .. " " .. button,
                            Statics.DebugModules.Storage
                        )
                    end
                    editframe.ManageTree()
                    local keypath
                    if loadout ~= "ALL" and loadout then
                        if GetSpecialization then
                            keypath = table.concat({"KEYBINDINGS", "KB", specialization, loadout, bind}, "\001")
                        else
                            keypath = table.concat({"KEYBINDINGS", "KB", loadout, bind}, "\001")
                        end
                    else
                        if GetSpecialization then
                            keypath = table.concat({"KEYBINDINGS", "KB", specialization, bind}, "\001")
                        else
                            keypath = table.concat({"KEYBINDINGS", "KB", bind}, "\001")
                        end
                    end
                    if keypath then
                        editframe.treeContainer:SelectByValue(keypath)
                    end
                    GSE.ReloadKeyBindings()
                end
            end
        )

        local delbutton = AceGUI:Create("Button")
        delbutton:SetText(L["Delete"])
        delbutton:SetCallback(
            "OnClick",
            function()
                if initialbind and not InCombatLockdown() then
                    SetBinding(initialbind)
                end
                if loadout ~= "ALL" and loadout then
                    GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] = nil
                    local empty = true
                    for _, _ in pairs(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) do
                        empty = false
                    end
                    if empty then
                        GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = nil
                    end
                else
                    if
                        GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                            GSE_C["KeyBindings"][tostring(specialization)][initialbind]
                     then
                        GSE_C["KeyBindings"][tostring(specialization)][initialbind] = nil
                    end
                end
                rightContainer:ReleaseChildren()
                editframe.ManageTree()
            end
        )

        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        row:AddChild(keybind)
        row:AddChild(SequenceListbox)
        row:AddChild(TalentLoadOutList)

        local row2 = AceGUI:Create("SimpleGroup")
        row2:SetFullWidth(true)
        row2:SetLayout("Flow")
        row2:AddChild(savebutton)
        row2:AddChild(delbutton)
        rightContainer:AddChild(row)
        rightContainer:AddChild(row2)

    elseif type == "AO" then

        if not button then
            button = {}
        end
        if button.Bind then
            bind = button.Bind
        end
        if not specialization then
            if GSE.GameMode < 10 then
                specialization = 1
            else
                if GSE.GameMode < 12 then
                    specialization = GetSpecialization()
                else
                    specialization = C_SpecializationInfo.GetSpecialization()
                end
            end
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()

        local LABButtonState = AceGUI:Create("Dropdown")
        LABButtonState:SetFullWidth(true)
        LABButtonState:SetLabel(L["Button State"])
        LABButtonState:SetDisabled(true)
        if bind and _G[bind] and _G[bind].state_types then
            local states = {["Default"] = "Default"}
            local default =
                string.sub(bind, 1, 3) == "BT4" and "0" or string.sub(bind, 1, 4) == "NDui_" and "2" or
                string.sub(bind, 1, 4) == "CPB_" and "" or
                "1"
            for k, _ in pairs(_G[bind].state_types) do
                if k ~= default and k ~= bind then
                    states[k] = k
                end
            end
            LABButtonState:SetList(states)
            LABButtonState:SetDisabled(false)
        end
        if button and button.State then
            LABButtonState:SetValue(tostring(button.State))
        else
            LABButtonState:SetValue("Default")
        end

        local ActionButtonList = AceGUI:Create("Dropdown")
        ActionButtonList:SetFullWidth(true)
        ActionButtonList:SetLabel(L["Actionbar Buttons"])
        local buttonnames = {
            "ActionButton",
            "MultiBarBottomLeftButton",
            "MultiBarBottomRightButton",
            "MultiBar5Button",
            "MultiBar6Button",
            "MultiBar7Button",
            "MultiBarLeftButton",
            "MultiBarRightButton"
        }
        local buttonlist = {}

        if ElvUI then
            for i = 15, 1, -1 do
                table.insert(buttonnames, 1, "ElvUI_Bar" .. i .. "Button")
            end
        end
        if NDui then
            for i = 15, 1, -1 do
                table.insert(buttonnames, 1, "NDui_ActionBar" .. i .. "Button")
            end
        end
        for _, v in ipairs(buttonnames) do
            for i = 1, 12 do
                if _G[v .. i] then
                    buttonlist[v .. i] = v .. i
                end
            end
        end
        if ConsolePort then
            buttonlist["CPB_PADDUP"] = "CPB_PADDUP"
            buttonlist["CPB_PADDLEFT"] = "CPB_PADDLEFT"
            buttonlist["CPB_PADDDOWN"] = "CPB_PADDDOWN"
            buttonlist["CPB_PADDRIGHT"] = "CPB_PADDRIGHT"
            buttonlist["CPB_PADLSHOULDER"] = "CPB_PADLSHOULDER"
            buttonlist["CPB_PADRSHOULDER"] = "CPB_PADRSHOULDER"
            buttonlist["CPB_PADRTRIGGER"] = "CPB_PADRTRIGGER"
            buttonlist["CPB_PADLTRIGGER"] = "CPB_PADLTRIGGER"
            buttonlist["CPB_PAD1"] = "CPB_PAD1"
            buttonlist["CPB_PAD2"] = "CPB_PAD2"
            buttonlist["CPB_PAD3"] = "CPB_PAD3"
            buttonlist["CPB_PAD4"] = "CPB_PAD4"
        end
        if Bartender4 then
            local v = "BT4Button"
            for i = 1, 180 do
                if _G[v .. i] and _G[v .. i]:IsShown() then
                    buttonlist[v .. i] = v .. i
                end
            end
        end
        if Dominos then
            -- IDs 1-24 and 73-132 are Dominos-owned frames; the other ID ranges
            -- reuse standard Blizzard frame names already captured above.
            for i = 1, 24 do
                if _G["DominosActionButton" .. i] then
                    buttonlist["DominosActionButton" .. i] = "DominosActionButton" .. i
                end
            end
            for i = 73, 132 do
                if _G["DominosActionButton" .. i] then
                    buttonlist["DominosActionButton" .. i] = "DominosActionButton" .. i
                end
            end
        end

        -- Add any buttons referenced in saved AO data that exist in _G but weren't auto-detected
        if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
            if not GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
                for _, buttons in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
                    for buttonName, _ in pairs(buttons) do
                        if _G[buttonName] and not buttonlist[buttonName] then
                            buttonlist[buttonName] = buttonName
                        end
                    end
                end
            end
            if not GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
                for _, loadouts in pairs(GSE_C["ActionBarBinds"]["LoadOuts"]) do
                    for _, buttons in pairs(loadouts) do
                        for buttonName, _ in pairs(buttons) do
                            if _G[buttonName] and not buttonlist[buttonName] then
                                buttonlist[buttonName] = buttonName
                            end
                        end
                    end
                end
            end
        end

        local striplist = {}
        if bind then
            buttonlist[bind] = bind
        end
        for k, _ in pairs(buttonlist) do
            table.insert(striplist, k)
        end
        ActionButtonList:SetList(buttonlist, GSE.SortTableAlphabetical(striplist))
        ActionButtonList:SetValue(bind)
        ActionButtonList:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                bind = key
                button.Bind = key
                if button.State then
                    bind = key .. "-" .. button.State
                end
                if _G[key].state_types then
                    local states = {["Default"] = "Default"}
                    local default =
                        string.sub(bind, 1, 3) == "BT4" and "0" or string.sub(bind, 1, 4) == "NDui_" and "2" or
                        string.sub(bind, 1, 4) == "CPB_" and "" or
                        "1"
                    for k, _ in pairs(_G[bind].state_types) do
                        if k ~= default and k ~= bind then
                            states[k] = k
                        end
                    end
                    LABButtonState:SetList(states)
                    LABButtonState:SetDisabled(false)
                else
                    LABButtonState:SetDisabled(true)
                    button.State = nil
                end
            end
        )
        LABButtonState:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                local default =
                    string.sub(ActionButtonList:GetValue(), 1, 3) == "BT4" and "0" or
                    string.sub(ActionButtonList:GetValue(), 1, 4) == "CPB_" and "" or
                    string.sub(ActionButtonList:GetValue(), 1, 4) == "NDui_" and "2" or
                    "1"
                if key == default or key == "Default" then
                    button["State"] = nil
                    bind = button["Bind"]
                else
                    button["State"] = key
                    bind = button["Bind"] .. "-" .. button["State"]
                end
            end
        )

        local SequenceListbox = AceGUI:Create("Dropdown")
        SequenceListbox:SetFullWidth(true)
        SequenceListbox:SetLabel(L["Sequence"])
        local names = {}
        for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
            names[k] = k
        end
        for k, _ in pairs(GSESequences[0]) do
            names[k] = k
        end
        SequenceListbox:SetList(names)
        if button and button.Sequence then
            SequenceListbox:SetValue(button.Sequence)
        end
        SequenceListbox:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                button.Sequence = key
            end
        )

        local TalentLoadOutList = AceGUI:Create("Dropdown")
        TalentLoadOutList:SetFullWidth(true)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = { ["All"] = L["All Talent Loadouts"] }
        if C_ClassTalents then
            for _, v in ipairs(
                C_ClassTalents.GetConfigIDsBySpecID(
                    GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
                )
            ) do
                local loadoutinfo = C_Traits.GetConfigInfo(v)
                loadouts[tostring(v)] = loadoutinfo.name
            end
        end
        TalentLoadOutList:SetList(loadouts)
        if loadout then
            TalentLoadOutList:SetValue(loadout)
        else
            TalentLoadOutList:SetValue("All")
        end
        TalentLoadOutList:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                if key == "All" then
                    loadout = nil
                else
                    loadout = key
                end
            end
        )

        local savebutton = AceGUI:Create("Button")
        savebutton:SetText(L["Save"])
        savebutton:SetCallback(
            "OnClick",
            function()
                if not GSE.isEmpty(SequenceListbox:GetValue()) and not GSE.isEmpty(ActionButtonList:GetValue()) then
                    local destination = GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)]
                    if loadout ~= "ALL" and loadout then
                        if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
                            GSE_C["ActionBarBinds"]["LoadOuts"] = {}
                        end
                        if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)]) then
                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)] = {}
                        end
                        if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]) then
                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout] = {}
                        end
                        destination = GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]
                    end
                    destination[bind] = button
                    if bind ~= initialbind then
                        showKeybind(editframe, bind, button, specialization, loadout, "AO", rightContainer)
                    end
                    GSE.ReloadOverrides()
                    GSE.UpdateIcon(_G[button.Sequence])
                    editframe.ManageTree()
                    if loadout ~= "ALL" and loadout then
                        if GetSpecialization then
                            editframe.treeContainer:SelectByPath("KEYBINDINGS", "AO", specialization, loadout, bind)
                        else
                            editframe.treeContainer:SelectByPath("KEYBINDINGS", "AO", loadout, bind)
                        end
                    else
                        if GetSpecialization then
                            editframe.treeContainer:SelectByPath("KEYBINDINGS", "AO", specialization, bind)
                        else
                            editframe.treeContainer:SelectByPath("KEYBINDINGS", "AO", bind)
                        end
                    end
                end
            end
        )

        local delbutton = AceGUI:Create("Button")
        delbutton:SetText(L["Delete"])
        delbutton:SetCallback(
            "OnClick",
            function()
                if loadout ~= "ALL" and loadout then
                    GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout][bind] = nil
                    local empty = true
                    for _, _ in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]) do
                        empty = false
                    end
                    if empty then
                        GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout] = nil
                    end
                else
                    GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)][bind] = nil
                end
                GSE.ButtonOverrides[bind] = nil
                _G[bind]:SetAttribute("gse-button", nil)
                _G[bind]:SetAttribute("type", "action")
                SecureHandlerUnwrapScript(_G[bind], "OnClick")
                SecureHandlerUnwrapScript(_G[bind], "OnEnter")
                rightContainer:ReleaseChildren()
                editframe.ManageTree()
            end
        )

        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        row:AddChild(ActionButtonList)
        row:AddChild(SequenceListbox)
        row:AddChild(TalentLoadOutList)
        row:AddChild(LABButtonState)

        local row2 = AceGUI:Create("SimpleGroup")
        row2:SetFullWidth(true)
        row2:SetLayout("Flow")
        row2:AddChild(savebutton)
        row2:AddChild(delbutton)
        rightContainer:AddChild(row)
        rightContainer:AddChild(row2)
    end
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupKeybind(editframe)
    editframe.showKeybind = function(bind, button, specialization, loadout, type, rightContainer)
        showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
    end
    editframe.buildKeybindMenu = buildKeybindMenu
end

local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local loaded

local keybindingframe = AceGUI:Create("Frame")
keybindingframe:Hide()
keybindingframe.frame:SetClampedToScreen(true)
keybindingframe.panels = {}
keybindingframe.frame:EnableGamePadButton(true)
keybindingframe.frame:SetFrameStrata("MEDIUM")

if
    GSEOptions.frameLocations and GSEOptions.frameLocations.keybindingframe and
        GSEOptions.frameLocations.keybindingframe.left and
        GSEOptions.frameLocations.keybindingframe.top
 then
    keybindingframe:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.keybindingframe.left,
        GSEOptions.frameLocations.keybindingframe.top
    )
end
GSE.GUIkeybindingframe = keybindingframe

if GSE.isEmpty(GSEOptions.keybindingHeight) then
    GSEOptions.keybindingHeight = 500
end
if GSE.isEmpty(GSEOptions.keybindingWidth) then
    GSEOptions.keybindingWidth = 700
end
keybindingframe.Height = GSEOptions.keybindingHeight
keybindingframe.Width = GSEOptions.keybindingWidth
if keybindingframe.Height < 500 then
    keybindingframe.Height = 500
    GSEOptions.keybindingHeight = keybindingframe.Height
end
if keybindingframe.Width < 700 then
    keybindingframe.Width = 700
    GSEOptions.keybindingWidth = keybindingframe.Width
end
keybindingframe.frame:SetClampRectInsets(-10, -10, -10, -10)
keybindingframe.frame:SetHeight(GSEOptions.keybindingHeight)
keybindingframe.frame:SetWidth(GSEOptions.keybindingWidth)

keybindingframe:SetTitle(L["Keybindings"])
keybindingframe:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(keybindingframe)
        keybindingframe:Hide()
    end
)

keybindingframe:SetLayout("Flow")
keybindingframe:SetAutoAdjustHeight(false)

local basecontainer = AceGUI:Create("SimpleGroup")
basecontainer:SetLayout("Flow")
basecontainer:SetAutoAdjustHeight(false)
basecontainer:SetHeight(keybindingframe.Height - 100)
basecontainer:SetFullWidth(true)
keybindingframe:AddChild(basecontainer)

local leftScrollContainer = AceGUI:Create("SimpleGroup")
leftScrollContainer:SetWidth(300)

leftScrollContainer:SetHeight(keybindingframe.Height - 90)
leftScrollContainer:SetLayout("Fill") -- important!

local treeContainer = AceGUI:Create("TreeGroup")
treeContainer:SetFullHeight(true)
treeContainer:SetFullWidth(true)
keybindingframe.treeContainer = treeContainer

basecontainer:AddChild(treeContainer)

keybindingframe:DoLayout()
keybindingframe.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        keybindingframe.Height = height
        keybindingframe.Width = width
        if keybindingframe.Height > GetScreenHeight() then
            keybindingframe.Height = GetScreenHeight() - 10
            keybindingframe:SetHeight(keybindingframe.Height)
        end
        if keybindingframe.Height < 500 then
            keybindingframe.Height = 500
            keybindingframe:SetHeight(keybindingframe.Height)
        end
        if keybindingframe.Width < 700 then
            keybindingframe.Width = 700
            keybindingframe:SetWidth(keybindingframe.Width)
        end
        GSEOptions.keybindingHeight = keybindingframe.Height
        GSEOptions.keybindingWidth = keybindingframe.Width
        leftScrollContainer:SetHeight(keybindingframe.Height - 90)
        keybindingframe:DoLayout()
    end
)

local function showKeybind(bind, button, specialization, loadout, type, rightContainer)
    if type == "KB" then
        if not specialization then
            if GSE.GameMode > 10 then
                specialization = GetSpecialization()
            else
                specialization = 1
            end
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()
        local keybind = AceGUI:Create("ControllerKeybinding")
        keybind:SetLabel(L["Keybind"])
        if not GSE.isEmpty(bind) then
            keybind:SetKey(bind)
        end
        keybind:SetWidth(300)
        keybind:SetCallback(
            "OnKeyChanged",
            function(self, _, key)
                bind = key
            end
        )

        keybind:SetLabel(L["Set Key to Bind"])
        local SequenceListbox = AceGUI:Create("Dropdown")

        SequenceListbox:SetWidth(300)
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

        TalentLoadOutList:SetWidth(300)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = {
            ["All"] = L["All Talent Loadouts"]
        }
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
                    if initialbind and bind ~= initialbind then
                        SetBinding(initialbind)
                        destination[bind] = nil
                    end
                    if loadout ~= "ALL" and loadout then
                        destination[bind] = button
                        if
                            tostring(C_ClassTalents.GetLastSelectedSavedConfigID(PlayerUtil.GetCurrentSpecID())) ==
                                loadout
                         then
                            SetBinding(bind)
                            SetBindingClick(bind, button, _G[button])
                        end
                    else
                        destination[bind] = button
                        SetBinding(bind)
                        SetBindingClick(bind, button, _G[button])
                    end
                    if bind ~= initialbind then
                        showKeybind(bind, button, specialization, loadout)
                    end
                    local widget = specialization .. bind
                    if loadout then
                        widget = widget .. loadout
                    end
                    keybindingframe:clearpanels(nil, false, widget)
                    GSE.ShowKeyBindings()
                    -- trigger a reload of KeyBindings
                    GSE.ReloadKeyBindings()
                end
            end
        )

        local delbutton = AceGUI:Create("Button")
        delbutton:SetText(L["Delete"])

        delbutton:SetCallback(
            "OnClick",
            function()
                if initialbind then
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
                    GSE_C["KeyBindings"][tostring(specialization)][initialbind] = nil
                end
                rightContainer:ReleaseChildren()
                GSE.ShowKeyBindings()
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
            if GSE.GameMode > 10 then
                specialization = GetSpecialization()
            else
                specialization = 1
            end
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()
        local LABButtonState = AceGUI:Create("Dropdown")
        LABButtonState:SetWidth(300)
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

        ActionButtonList:SetWidth(300)
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
            -- buttonlist["CPB_PADDUP_SHIFT"] = "CPB_PADDUP_SHIFT"
            -- buttonlist["CPB_PADDUP_CTRL_SHIFT"] = "CPB_PADDUP_CTRL_SHIFT"
            -- buttonlist["CPB_PADDUP_CTRL"] = "CPB_PADDUP_CTRL"
            buttonlist["CPB_PADDLEFT"] = "CPB_PADDLEFT"
            -- buttonlist["CPB_PADDLEFT_SHIFT"] = "CPB_PADDLEFT_SHIFT"
            -- buttonlist["CPB_PADDLEFT_CTRL_SHIFT"] = "CPB_PADDLEFT_CTRL_SHIFT"
            -- buttonlist["CPB_PADDLEFT_CTRL"] = "CPB_PADDLEFT_CTRL"
            buttonlist["CPB_PADDDOWN"] = "CPB_PADDDOWN"
            -- buttonlist["CPB_PADDDOWN_SHIFT"] = "CPB_PADDDOWN_SHIFT"
            -- buttonlist["CPB_PADDDOWN_CTRL_SHIFT"] = "CPB_PADDDOWN_CTRL_SHIFT"
            -- buttonlist["CPB_PADDDOWN_CTRL"] = "CPB_PADDDOWN_CTRL"
            buttonlist["CPB_PADLSHOULDER"] = "CPB_PADLSHOULDER"
            -- buttonlist["CPB_PADLSHOULDER_SHIFT"] = "CPB_PADLSHOULDER_SHIFT"
            -- buttonlist["CPB_PADLSHOULDER_CTRL_SHIFT"] = "CPB_PADLSHOULDER_CTRL_SHIFT"
            -- buttonlist["CPB_PADLSHOULDER_CTRL"] = "CPB_PADLSHOULDER_CTRL"
            buttonlist["CPB_PADRSHOULDER"] = "CPB_PADRSHOULDER"
            -- buttonlist["CPB_PADRSHOULDER_SHIFT"] = "CPB_PADRSHOULDER_SHIFT"
            -- buttonlist["CPB_PADRSHOULDER_CTRL_SHIFT"] = "CPB_PADRSHOULDER_CTRL_SHIFT"
            -- buttonlist["CPB_PADRSHOULDER_CTRL"] = "CPB_PADRSHOULDER_CTRL"
            buttonlist["CPB_PADRTRIGGER"] = "CPB_PADRTRIGGER"
            -- buttonlist["CPB_PADRTRIGGER_SHIFT"] = "CPB_PADRTRIGGER_SHIFT"
            -- buttonlist["CPB_PADRTRIGGER_CTRL_SHIFT"] = "CPB_PADRTRIGGER_CTRL_SHIFT"
            -- buttonlist["CPB_PADRTRIGGER_CTRL"] = "CPB_PADRTRIGGER_CTRL"
            buttonlist["CPB_PADLTRIGGER"] = "CPB_PADLTRIGGER"
            -- buttonlist["CPB_PADLTRIGGER_SHIFT"] = "CPB_PADLTRIGGER_SHIFT"
            -- buttonlist["CPB_PADLTRIGGER_CTRL_SHIFT"] = "CPB_PADLTRIGGER_CTRL_SHIFT"
            -- buttonlist["CPB_PADLTRIGGER_CTRL"] = "CPB_PADLTRIGGER_CTRL"
            buttonlist["CPB_PAD1"] = "CPB_PAD1"
            -- buttonlist["CPB_PAD1_SHIFT"] = "CPB_PAD1_SHIFT"
            -- buttonlist["CPB_PAD1_CTRL_SHIFT"] = "CPB_PAD1_CTRL_SHIFT"
            -- buttonlist["CPB_PAD1_CTRL"] = "CPB_PAD1_CTRL"
            buttonlist["CPB_PAD2"] = "CPB_PAD2"
            -- buttonlist["CPB_PAD2_SHIFT"] = "CPB_PAD2_SHIFT"
            -- buttonlist["CPB_PAD2_CTRL_SHIFT"] = "CPB_PAD2_CTRL_SHIFT"
            -- buttonlist["CPB_PAD2_CTRL"] = "CPB_PAD2_CTRL"
            buttonlist["CPB_PAD3"] = "CPB_PAD3"
            -- buttonlist["CPB_PAD3_SHIFT"] = "CPB_PAD3_SHIFT"
            -- buttonlist["CPB_PAD3_CTRL_SHIFT"] = "CPB_PAD3_CTRL_SHIFT"
            -- buttonlist["CPB_PAD3_CTRL"] = "CPB_PAD3_CTRL"
            buttonlist["CPB_PAD4"] = "CPB_PAD4"
        -- buttonlist["CPB_PAD4_SHIFT"] = "CPB_PAD4_SHIFT"
        -- buttonlist["CPB_PAD4_CTRL_SHIFT"] = "CPB_PAD4_CTRL_SHIFT"
        -- buttonlist["CPB_PAD4_CTRL"] = "CPB_PAD4_CTRL"
        end

        if Bartender4 then
            local v = "BT4Button"
            for i = 1, 180 do
                if _G[v .. i] and _G[v .. i]:IsShown() then
                    buttonlist[v .. i] = v .. i
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

        SequenceListbox:SetWidth(300)
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

        TalentLoadOutList:SetWidth(300)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = {
            ["All"] = L["All Talent Loadouts"]
        }
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
                    if loadout ~= "ALL" and loadout then
                        destination[bind] = button
                    else
                        destination[bind] = button
                    end
                    if bind ~= initialbind then
                        showKeybind(bind, button, specialization, loadout)
                    end
                    local widget = specialization .. bind
                    if loadout then
                        widget = widget .. loadout
                    end
                    keybindingframe:clearpanels(nil, false, widget)
                    GSE.ShowKeyBindings()
                    -- trigger a reload of KeyBindings
                    GSE.ReloadOverrides()
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
                rightContainer:ReleaseChildren()
                GSE.ShowKeyBindings()
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

    loaded = true
end

treeContainer:SetCallback(
    "OnGroupSelected",
    function(container, event, group, ...)
        if loaded then
            container:ReleaseChildren()
            loaded = nil
        end
        local unique = {("\001"):split(group)}
        local bind, specialization, loadout, type, button
        type = unique[1]

        specialization = unique[2]
        local mbutton = GetMouseButtonClicked()
        if mbutton == "RightButton" then
        else
            if specialization == "NKB" then
                local rightContainer = AceGUI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                showKeybind(nil, nil, nil, nil, "KB", rightContainer)
                container:AddChild(rightContainer)
            elseif specialization == "NAO" then
                local rightContainer = AceGUI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                showKeybind(nil, nil, nil, nil, "AO", rightContainer)
                container:AddChild(rightContainer)
            else
                local key

                if #unique == 4 then
                    key = GSE.split(unique[4], "-")
                    bind = key[1]
                    button = key[2]
                    loadout = unique[3]
                else
                    key = GSE.split(unique[3], "-")
                    bind = key[1]
                    button = key[2]
                end

                if bind and button and specialization and type then
                    local rightContainer = AceGUI:Create("SimpleGroup")
                    rightContainer:SetFullWidth(true)
                    rightContainer:SetLayout("List")
                    showKeybind(bind, button, specialization, loadout, type, rightContainer)
                    container:AddChild(rightContainer)
                end
            end
        end
    end
)
local function buildKeybindMenu()
    local tree = {
        {
            value = "AO",
            text = L["Actionbar Overrides"],
            icon = Statics.ActionsIcons.Down,
            children = {
                {
                    value = "NAO",
                    text = L["New Actionbar Override"]
                }
            }
        },
        {
            value = "KB",
            text = L["Keybindings"],
            icon = Statics.ActionsIcons.Down,
            children = {
                {
                    value = "NKB",
                    text = L["New KeyBind"]
                }
            }
        }
    }
    for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
        local currentspecid = tonumber(k)
        if GetSpecializationInfo then
            local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
            local node = {
                value = k,
                text = speclabel,
                icon = specIcon,
                children = {}
            }

            for i, j in GSE.pairsByKeys(v) do
                table.insert(
                    node["children"],
                    {
                        value = i .. "-" .. j["Sequence"],
                        text = j["Bind"] ..
                            " " .. GSEOptions.KEYWORD .. "(" .. j["Sequence"] .. ")" .. Statics.StringReset
                    }
                )
            end

            if
                GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["LoadOuts"] and
                    GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]
             then
                for i, j in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]) do
                    local success =
                        pcall(
                        function()
                            local loadout = C_Traits.GetConfigInfo(i)
                            local specnode = {
                                value = i,
                                text = loadout.name,
                                children = {}
                            }

                            for l, m in GSE.pairsByKeys(j) do
                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "-" .. m,
                                        text = l .. " " .. GSEOptions.KEYWORD .. "(" .. m .. ")" .. Statics.StringReset
                                    }
                                )
                            end
                            table.insert(node["children"], specnode)
                        end
                    )
                    if not success then
                        GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"][i] = nil
                    end
                end
            end
            table.insert(tree[1]["children"], node)
        end
    end
    for k, v in pairs(GSE_C["KeyBindings"]) do
        local currentspecid = tonumber(k)
        if GetSpecializationInfo then
            local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
            local node = {
                value = k,
                text = speclabel,
                icon = specIcon,
                children = {}
            }

            for i, j in GSE.pairsByKeys(v) do
                if i ~= "LoadOuts" then
                    table.insert(
                        node["children"],
                        {
                            value = i .. "-" .. j,
                            text = i .. " " .. GSEOptions.KEYWORD .. "(" .. j .. ")" .. Statics.StringReset
                        }
                    )
                end
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
                                text = loadout.name,
                                children = {}
                            }

                            for l, m in GSE.pairsByKeys(j) do
                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "-" .. m,
                                        text = l .. " " .. GSEOptions.KEYWORD .. "(" .. m .. ")" .. Statics.StringReset
                                    }
                                )
                            end
                            table.insert(node["children"], specnode)
                        end
                    )
                    if not success then
                        GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"][i] = nil
                    end
                end
            end
            table.insert(tree[2]["children"], node)
        end
    end

    treeContainer:SetTree(tree)
end

function keybindingframe:clearpanels(widget, selected, key)
    for k, _ in pairs(keybindingframe.panels) do
        local widkey = widget and widget:GetKey() or key
        if k == widkey then
            if selected then
                --keybindingframe.showMacro(widget.node)
                keybindingframe.panels[k]:SetClicked(true)
            else
                keybindingframe.panels[k]:SetClicked(false)
            end
        else
            keybindingframe.panels[k]:SetClicked(false)
        end
    end
end

function GSE.ShowKeyBindings()
    buildKeybindMenu()
    keybindingframe:Show()
end

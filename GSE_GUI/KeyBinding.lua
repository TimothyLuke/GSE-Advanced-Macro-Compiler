local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

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
leftScrollContainer:SetWidth(200)

leftScrollContainer:SetHeight(keybindingframe.Height - 90)
leftScrollContainer:SetLayout("Fill") -- important!

basecontainer:AddChild(leftScrollContainer)

local leftscroll = AceGUI:Create("ScrollFrame")
leftscroll:SetLayout("List") -- probably?
leftscroll:SetWidth(200)
leftscroll:SetHeight(keybindingframe.Height - 90)
leftScrollContainer:AddChild(leftscroll)

local spacer = AceGUI:Create("Label")
spacer:SetWidth(10)
basecontainer:AddChild(spacer)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(keybindingframe.Width - 290)

rightContainer:SetLayout("List")
rightContainer:SetHeight(keybindingframe.Height - 90)
basecontainer:AddChild(rightContainer)
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
        rightContainer:SetWidth(keybindingframe.Width - 290)
        rightContainer:SetHeight(keybindingframe.Height - 90)
        leftScrollContainer:SetHeight(keybindingframe.Height - 90)
        keybindingframe:DoLayout()
    end
)

local function showKeybind(bind, button, specialization, loadout, type)
    if type == "KB" then
        if not specialization then
            specialization = GetSpecialization()
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()
        local keybind = AceGUI:Create("ControllerKeybinding")
        keybind:SetLabel(L["Keybind"])
        if not GSE.isEmpty(bind) then
            keybind:SetKey(bind)
        end
        keybind:SetWidth(400)
        keybind:SetCallback(
            "OnKeyChanged",
            function(self, _, key)
                bind = key
            end
        )

        keybind:SetLabel(L["Set Key to Bind"])
        local SequenceListbox = AceGUI:Create("Dropdown")

        SequenceListbox:SetWidth(400)
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

        TalentLoadOutList:SetWidth(400)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = {
            ["All"] = L["All Talent Loadouts"]
        }
        for _, v in ipairs(
            C_ClassTalents.GetConfigIDsBySpecID(
                GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
            )
        ) do
            local loadoutinfo = C_Traits.GetConfigInfo(v)
            loadouts[tostring(v)] = loadoutinfo.name
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
        if not specialization then
            specialization = GetSpecialization()
        end
        local initialbind = bind
        rightContainer:ReleaseChildren()

        local ActionButtonList = AceGUI:Create("Dropdown")

        ActionButtonList:SetWidth(400)
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

        for _, v in ipairs(buttonnames) do
            for i = 1, 12 do
                if _G[v .. i] then
                    buttonlist[v .. i] = v .. i
                end
            end
        end
        if ConsolePort then
            buttonlist["CPB_PADDUP"] = "CPB_PADDUP"
            buttonlist["CPB_PADDUP_SHIFT"] = "CPB_PADDUP_SHIFT"
            buttonlist["CPB_PADDUP_CTRL_SHIFT"] = "CPB_PADDUP_CTRL_SHIFT"
            buttonlist["CPB_PADDUP_CTRL"] = "CPB_PADDUP_CTRL"
            buttonlist["CPB_PADDLEFT"] = "CPB_PADDLEFT"
            buttonlist["CPB_PADDLEFT_SHIFT"] = "CPB_PADDLEFT_SHIFT"
            buttonlist["CPB_PADDLEFT_CTRL_SHIFT"] = "CPB_PADDLEFT_CTRL_SHIFT"
            buttonlist["CPB_PADDLEFT_CTRL"] = "CPB_PADDLEFT_CTRL"
            buttonlist["CPB_PADDDOWN"] = "CPB_PADDDOWN"
            buttonlist["CPB_PADDDOWN_SHIFT"] = "CPB_PADDDOWN_SHIFT"
            buttonlist["CPB_PADDDOWN_CTRL_SHIFT"] = "CPB_PADDDOWN_CTRL_SHIFT"
            buttonlist["CPB_PADDDOWN_CTRL"] = "CPB_PADDDOWN_CTRL"
            buttonlist["CPB_PADLSHOULDER"] = "CPB_PADLSHOULDER"
            buttonlist["CPB_PADLSHOULDER_SHIFT"] = "CPB_PADLSHOULDER_SHIFT"
            buttonlist["CPB_PADLSHOULDER_CTRL_SHIFT"] = "CPB_PADLSHOULDER_CTRL_SHIFT"
            buttonlist["CPB_PADLSHOULDER_CTRL"] = "CPB_PADLSHOULDER_CTRL"
            buttonlist["CPB_PADRSHOULDER"] = "CPB_PADRSHOULDER"
            buttonlist["CPB_PADRSHOULDER_SHIFT"] = "CPB_PADRSHOULDER_SHIFT"
            buttonlist["CPB_PADRSHOULDER_CTRL_SHIFT"] = "CPB_PADRSHOULDER_CTRL_SHIFT"
            buttonlist["CPB_PADRSHOULDER_CTRL"] = "CPB_PADRSHOULDER_CTRL"
            buttonlist["CPB_PADRTRIGGER"] = "CPB_PADRTRIGGER"
            buttonlist["CPB_PADRTRIGGER_SHIFT"] = "CPB_PADRTRIGGER_SHIFT"
            buttonlist["CPB_PADRTRIGGER_CTRL_SHIFT"] = "CPB_PADRTRIGGER_CTRL_SHIFT"
            buttonlist["CPB_PADRTRIGGER_CTRL"] = "CPB_PADRTRIGGER_CTRL"
            buttonlist["CPB_PADLTRIGGER"] = "CPB_PADLTRIGGER"
            buttonlist["CPB_PADLTRIGGER_SHIFT"] = "CPB_PADLTRIGGER_SHIFT"
            buttonlist["CPB_PADLTRIGGER_CTRL_SHIFT"] = "CPB_PADLTRIGGER_CTRL_SHIFT"
            buttonlist["CPB_PADLTRIGGER_CTRL"] = "CPB_PADLTRIGGER_CTRL"
            buttonlist["CPB_PAD1"] = "CPB_PAD1"
            buttonlist["CPB_PAD1_SHIFT"] = "CPB_PAD1_SHIFT"
            buttonlist["CPB_PAD1_CTRL_SHIFT"] = "CPB_PAD1_CTRL_SHIFT"
            buttonlist["CPB_PAD1_CTRL"] = "CPB_PAD1_CTRL"
            buttonlist["CPB_PAD2"] = "CPB_PAD2"
            buttonlist["CPB_PAD2_SHIFT"] = "CPB_PAD2_SHIFT"
            buttonlist["CPB_PAD2_CTRL_SHIFT"] = "CPB_PAD2_CTRL_SHIFT"
            buttonlist["CPB_PAD2_CTRL"] = "CPB_PAD2_CTRL"
            buttonlist["CPB_PAD3"] = "CPB_PAD3"
            buttonlist["CPB_PAD3_SHIFT"] = "CPB_PAD3_SHIFT"
            buttonlist["CPB_PAD3_CTRL_SHIFT"] = "CPB_PAD3_CTRL_SHIFT"
            buttonlist["CPB_PAD3_CTRL"] = "CPB_PAD3_CTRL"
            buttonlist["CPB_PAD4"] = "CPB_PAD4"
            buttonlist["CPB_PAD4_SHIFT"] = "CPB_PAD4_SHIFT"
            buttonlist["CPB_PAD4_CTRL_SHIFT"] = "CPB_PAD4_CTRL_SHIFT"
            buttonlist["CPB_PAD4_CTRL"] = "CPB_PAD4_CTRL"
        end

        if Bartender4 then
            local v = "BT4Button"
            for i = 1, 180 do
                if _G[v .. i] and _G[v .. i]:IsShown() then
                    buttonlist[v .. i] = v .. i
                end
            end
        end
        ActionButtonList:SetList(buttonlist)
        ActionButtonList:SetValue(bind)
        ActionButtonList:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                bind = key
            end
        )

        local SequenceListbox = AceGUI:Create("Dropdown")

        SequenceListbox:SetWidth(400)
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

        TalentLoadOutList:SetWidth(400)
        TalentLoadOutList:SetLabel(L["Talent Loadout"])
        local loadouts = {
            ["All"] = L["All Talent Loadouts"]
        }
        for _, v in ipairs(
            C_ClassTalents.GetConfigIDsBySpecID(
                GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
            )
        ) do
            local loadoutinfo = C_Traits.GetConfigInfo(v)
            loadouts[tostring(v)] = loadoutinfo.name
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

        local row2 = AceGUI:Create("SimpleGroup")
        row2:SetFullWidth(true)
        row2:SetLayout("Flow")

        row2:AddChild(savebutton)
        row2:AddChild(delbutton)
        rightContainer:AddChild(row)
        rightContainer:AddChild(row2)
    end

    rightContainer:SetWidth(keybindingframe.Width - 290)
end

local function buildKeybindHeader(specialization, bind, button, loadout, type)
    if GSE.isEmpty(type) then
        type = "KB"
    end
    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)

    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    local origjustificationH = font:GetJustifyH()
    local origjustificationV = font:GetJustifyV()
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    local selpanel = AceGUI:Create("SelectablePanel")
    local key = specialization .. bind
    if loadout then
        key = key .. loadout
    end
    selpanel:SetKey(key)
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(20)
    selpanel:SetAutoAdjustHeight(true)
    selpanel:SetLayout("List")

    keybindingframe.panels[specialization .. bind] = selpanel

    local hlabel = AceGUI:Create("Label")

    hlabel:SetText(bind .. " - " .. GSEOptions.KEYWORD .. "(" .. button .. ")" .. Statics.StringReset)
    hlabel:SetWidth(199)
    hlabel:SetFontObject(font)
    hlabel:SetFont(fontName, fontHeight + 2, fontFlags)

    selpanel:AddChild(hlabel)
    selpanel:SetCallback(
        "OnClick",
        function(widget, _, selected, callbutton)
            keybindingframe:clearpanels(widget, selected)
            if callbutton == "RightButton" then
                MenuUtil.CreateContextMenu(
                    selpanel,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Manage Macros"])
                        rootDescription:CreateButton(
                            L["New KeyBind"],
                            function()
                                showKeybind(nil, nil, nil, nil, "KB")
                            end
                        )
                        rootDescription:CreateButton(
                            L["New Actionbar Override"],
                            function()
                                showKeybind(nil, nil, nil, nil, "AO")
                            end
                        )
                        rootDescription:CreateButton(
                            L["Delete"],
                            function()
                                if type == "KB" then
                                    SetBinding(bind)

                                    local destination = GSE_C["KeyBindings"][tostring(specialization)]
                                    if loadout ~= "ALL" and loadout then
                                        destination =
                                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                                        destination[bind] = nil
                                        local empty = true
                                        for _, _ in pairs(
                                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                                        ) do
                                            empty = false
                                        end
                                        if empty then
                                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = nil
                                        end
                                    else
                                        destination[bind] = nil
                                    end
                                elseif type == "AO" then
                                    local destination =
                                        GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)]
                                    if loadout ~= "ALL" and loadout then
                                        destination =
                                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]
                                        destination[bind] = nil
                                        local empty = true
                                        for _, _ in pairs(
                                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]
                                        ) do
                                            empty = false
                                        end
                                        if empty then
                                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout] = nil
                                        end
                                    else
                                        destination[bind] = nil
                                    end
                                    GSE.ButtonOverrides[bind] = nil
                                end
                                GSE.ShowKeyBindings()
                            end
                        )
                    end
                )
            else
                showKeybind(bind, button, specialization, loadout, type)
            end
        end
    )

    leftscroll:AddChild(selpanel)
    font:SetJustifyH(origjustificationH)
    font:SetJustifyV(origjustificationV)
end

local function buildKeybindMenu()
    leftscroll:ReleaseChildren()
    local newButton = AceGUI:Create("Button")
    newButton:SetText(L["New KeyBind"])
    newButton:SetCallback(
        "OnClick",
        function()
            showKeybind(nil, nil, nil, nil, "KB")
        end
    )
    leftscroll:AddChild(newButton)
    local newActionButton = AceGUI:Create("Button")
    newActionButton:SetText(L["New Actionbar Override"])
    newActionButton:SetCallback(
        "OnClick",
        function()
            showKeybind(nil, nil, nil, nil, "AO")
        end
    )
    leftscroll:AddChild(newActionButton)
    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    local KeyBindheader = AceGUI:Create("Label")
    KeyBindheader:SetText(L["Keybindings"])
    KeyBindheader:SetFont(fontName, fontHeight + 6, fontFlags)
    KeyBindheader:SetColor(GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS))
    leftscroll:AddChild(KeyBindheader)
    local specid = 0
    for k, v in pairs(GSE_C["KeyBindings"]) do
        local currentspecid = tonumber(k)
        if specid ~= currentspecid then
            specid = currentspecid
            local _, speclabel = GetSpecializationInfo(currentspecid)

            local sectionspacer1 = AceGUI:Create("Label")
            sectionspacer1:SetText(" ")
            sectionspacer1:SetFont(fontName, 4, fontFlags)
            leftscroll:AddChild(sectionspacer1)
            local sectionheader = AceGUI:Create("Label")
            sectionheader:SetText(speclabel)
            sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
            sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
            leftscroll:AddChild(sectionheader)
            local sectionspacer2 = AceGUI:Create("Label")
            sectionspacer2:SetText(" ")
            sectionspacer2:SetFont(fontName, 2, fontFlags)
            leftscroll:AddChild(sectionspacer2)
        end

        for i, j in pairs(v) do
            if i ~= "LoadOuts" then
                buildKeybindHeader(k, i, j)
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
                        local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
                        local sectionspacer3 = AceGUI:Create("Label")
                        sectionspacer3:SetText(" ")
                        sectionspacer3:SetFont(fontName, 4, fontFlags)
                        leftscroll:AddChild(sectionspacer3)
                        local sectionheader2 = AceGUI:Create("Label")
                        local loadout = C_Traits.GetConfigInfo(i)
                        sectionheader2:SetText(loadout.name)
                        sectionheader2:SetFont(fontName, fontHeight, fontFlags)
                        sectionheader2:SetColor(GSE.GUIGetColour(GSEOptions.STANDARDFUNCS))
                        leftscroll:AddChild(sectionheader2)
                        local sectionspacer4 = AceGUI:Create("Label")
                        sectionspacer4:SetText(" ")
                        sectionspacer4:SetFont(fontName, 2, fontFlags)
                        leftscroll:AddChild(sectionspacer4)
                        for l, m in pairs(j) do
                            buildKeybindHeader(currentspecid, l, m, i)
                        end
                    end
                )
                if not success then
                    GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"][i] = nil
                end
            end
        end
    end
    local actionHeader = AceGUI:Create("Label")
    actionHeader:SetText(L["Actionbar Overrides"])
    actionHeader:SetFont(fontName, fontHeight + 6, fontFlags)
    actionHeader:SetColor(GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS))
    leftscroll:AddChild(actionHeader)

    for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
        local currentspecid = tonumber(k)
        if specid ~= currentspecid then
            specid = currentspecid
            local _, speclabel = GetSpecializationInfo(currentspecid)

            local sectionspacer1 = AceGUI:Create("Label")
            sectionspacer1:SetText(" ")
            sectionspacer1:SetFont(fontName, 4, fontFlags)
            leftscroll:AddChild(sectionspacer1)
            local sectionheader = AceGUI:Create("Label")
            sectionheader:SetText(speclabel)
            sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
            sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
            leftscroll:AddChild(sectionheader)
            local sectionspacer2 = AceGUI:Create("Label")
            sectionspacer2:SetText(" ")
            sectionspacer2:SetFont(fontName, 2, fontFlags)
            leftscroll:AddChild(sectionspacer2)
        end

        for i, j in pairs(v) do
            buildKeybindHeader(k, i, j, nil, "AO")
        end
        if
            GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["LoadOuts"] and
                GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]
         then
            for i, j in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]) do
                local success =
                    pcall(
                    function()
                        local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
                        local sectionspacer3 = AceGUI:Create("Label")
                        sectionspacer3:SetText(" ")
                        sectionspacer3:SetFont(fontName, 4, fontFlags)
                        leftscroll:AddChild(sectionspacer3)
                        local sectionheader2 = AceGUI:Create("Label")
                        local loadout = C_Traits.GetConfigInfo(i)
                        sectionheader2:SetText(loadout.name)
                        sectionheader2:SetFont(fontName, fontHeight, fontFlags)
                        sectionheader2:SetColor(GSE.GUIGetColour(GSEOptions.STANDARDFUNCS))
                        leftscroll:AddChild(sectionheader2)
                        local sectionspacer4 = AceGUI:Create("Label")
                        sectionspacer4:SetText(" ")
                        sectionspacer4:SetFont(fontName, 2, fontFlags)
                        leftscroll:AddChild(sectionspacer4)
                        for l, m in pairs(j) do
                            buildKeybindHeader(currentspecid, l, m, i, "AO")
                        end
                    end
                )
            end
        end
    end
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

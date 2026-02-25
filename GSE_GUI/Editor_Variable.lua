local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- ---------------------------------------------------------------------------
-- buildVariablesMenu()  →  tree node for the Variables section
-- ---------------------------------------------------------------------------
local function buildVariablesMenu()
    local tree = {
        value = "VARIABLES",
        text = L["Variables"],
        icon = Statics.Icons.Variables,
        children = {
            {
                value = "NEWVARIABLES",
                text = L["New Variable"],
                icon = Statics.ActionsIcons.Add
            }
        }
    }
    for k, _ in pairs(GSEVariables) do
        local node = {
            value = k,
            text = "|CFFFFFFFF" .. k .. Statics.StringReset
        }
        table.insert(tree.children, node)
    end
    return tree
end

-- ---------------------------------------------------------------------------
-- showVariable(editframe, name, container)
-- Renders the variable editor into container.
-- ---------------------------------------------------------------------------
local function showVariable(editframe, name, container)
    editframe.SequenceName = name
    local implementation = AceGUI:Create("EditBox")
    local variable = {
        ["funct"] = [[function()
    return true
end]],
        ["comments"] = ""
    }
    if not GSE.isEmpty(GSEVariables[name]) then
        local status, err =
            pcall(
            function()
                local _, uncompressedVersion = GSE.DecodeMessage(GSEVariables[name])
                variable = uncompressedVersion
            end
        )
        if err then
            print(err)
        end
    end

    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel(L["Name"])
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(150)
    keyEditBox:SetText(name)
    local currentKey = name
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            local orig = GSEVariables[currentKey]
            GSEVariables[text] = orig
            GSEVariables[currentKey] = nil
            currentKey = text
            local implementationText = [[=GSE.V.]] .. text .. [[()]]
            implementation:SetText(implementationText)
        end
    )

    local authoreditbox = AceGUI:Create("EditBox")
    authoreditbox:SetLabel(L["Author"])
    authoreditbox:SetWidth(250)
    authoreditbox:DisableButton(true)
    authoreditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Author"], L["The author of this Variable."], editframe)
        end
    )
    authoreditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    if not GSE.isEmpty(variable.Author) then
        authoreditbox:SetText(variable.Author)
    else
        authoreditbox:SetText(GSE.GetCharacterName())
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            variable.Author = key
        end
    )
    container:AddChild(keyEditBox)
    container:AddChild(authoreditbox)

    local commentsEditBox = AceGUI:Create("MultiLineEditBox")
    commentsEditBox:SetLabel(L["Help Information"])
    commentsEditBox:SetNumLines(3)
    commentsEditBox:SetFullWidth(true)
    commentsEditBox:DisableButton(true)
    commentsEditBox:SetText(variable.comments)
    commentsEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            variable.comments = text
        end
    )
    commentsEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            variable.comments = commentsEditBox:GetText()
        end
    )
    container:AddChild(commentsEditBox)

    -- Event Callback Section ─────────────────────────────────────────────────
    local eventCallbackGroup = AceGUI:Create("SimpleGroup")
    eventCallbackGroup:SetLayout("Flow")
    eventCallbackGroup:SetFullWidth(true)

    local eventToggle = AceGUI:Create("CheckBox")
    eventToggle:SetLabel(L["Execute on Event"])
    eventToggle:SetWidth(180)
    local isEventEnabled = variable.eventEnabled or false
    eventToggle:SetValue(isEventEnabled)
    eventToggle:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Execute on Event"],
                L["When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."],
                editframe
            )
        end
    )
    eventToggle:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local eventDropdown = AceGUI:Create("Dropdown")
    eventDropdown:SetLabel(L["Trigger Events"])
    eventDropdown:SetRelativeWidth(0.75)
    eventDropdown:SetMultiselect(true)
    eventDropdown:SetList(Statics.VariableEventList)
    eventDropdown:SetDisabled(not isEventEnabled)

    if not GSE.isEmpty(variable.eventNames) then
        for _, evtName in ipairs(variable.eventNames) do
            eventDropdown:SetItemValue(evtName, true)
        end
    end

    eventToggle:SetCallback(
        "OnValueChanged",
        function(obj, event, val)
            variable.eventEnabled = val
            eventDropdown:SetDisabled(not val)
            if not val then
                variable.eventNames = {}
                for key, _ in pairs(Statics.VariableEventList) do
                    eventDropdown:SetItemValue(key, false)
                end
            end
        end
    )

    eventDropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if GSE.isEmpty(variable.eventNames) then
                variable.eventNames = {}
            end
            if checked then
                local found = false
                for _, v in ipairs(variable.eventNames) do
                    if v == key then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(variable.eventNames, key)
                end
            else
                for i, v in ipairs(variable.eventNames) do
                    if v == key then
                        table.remove(variable.eventNames, i)
                        break
                    end
                end
            end
        end
    )
    eventDropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Trigger Events"],
                L["The WoW events or GSE messages that will trigger this variable's function. Multiple events can be selected."],
                editframe
            )
        end
    )
    eventDropdown:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    eventCallbackGroup:AddChild(eventToggle)
    eventCallbackGroup:AddChild(eventDropdown)
    container:AddChild(eventCallbackGroup)
    -- ────────────────────────────────────────────────────────────────────────

    local valueEditBox = AceGUI:Create("MultiLineEditBox")
    valueEditBox:SetLabel(L["Variable"])
    valueEditBox:SetNumLines(15)
    valueEditBox:SetFullWidth(true)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(variable.funct)
    valueEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            variable.funct = IndentationLib.encode(text)
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            local variabletext = IndentationLib.decode(valueEditBox:GetText())
            variable.funct = variabletext
        end
    )
    IndentationLib.enable(valueEditBox.editBox, Statics.IndentationColorTable, 4)
    container:AddChild(valueEditBox)

    implementation:SetLabel(L["Implementation Link"])
    implementation:DisableButton(true)
    local implementationText = [[=GSE.V.]] .. name .. [[()]]
    implementation:SetText(implementationText)
    implementation:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            implementation:SetText(implementationText)
        end
    )
    container:AddChild(implementation)

    local currentOutput = AceGUI:Create("EditBox")
    currentOutput:SetLabel(L["Current Value"])
    currentOutput:DisableButton(true)
    local outputText = L["Not Yet Active"]
    if GSE.V[name] and type(GSE.V[name]) == "function" then
        outputText = GSE.V[name]()
    end
    currentOutput:SetText(tostring(outputText))
    currentOutput:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            currentOutput:SetText(outputText)
        end
    )
    container:AddChild(currentOutput)

    local spacer2 = AceGUI:Create("Label")
    spacer2:SetWidth(10)
    container:AddChild(spacer2)

    local buttonRow = AceGUI:Create("SimpleGroup")
    buttonRow:SetLayout("Flow")
    buttonRow:SetWidth(400)

    local deleteRowButton = AceGUI:Create("Button")
    deleteRowButton:SetText(L["Delete Variable"])
    deleteRowButton:SetWidth(150)
    deleteRowButton:SetCallback(
        "OnClick",
        function()
            GSEVariables[keyEditBox:GetText()] = nil
            if editframe.loaded then
                container:ReleaseChildren()
                editframe.loaded = nil
            end
            editframe:ManageTree()
        end
    )
    deleteRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], editframe)
        end
    )
    deleteRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    buttonRow:AddChild(deleteRowButton)

    local spacer3 = AceGUI:Create("Label")
    spacer3:SetWidth(10)
    buttonRow:AddChild(spacer3)

    local lastSaved = AceGUI:Create("Label")
    if variable.LastUpdated then
        local updated = GSE.DecodeTimeStamp(variable.LastUpdated)
        lastSaved:SetText(
            L["Last Updated"] ..
                " " ..
                    updated.month ..
                        "/" .. updated.day .. "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
        )
    end

    local savebutton = AceGUI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback(
        "OnClick",
        function()
            local checkvariable, error = GSE.CheckVariable(valueEditBox:GetText())
            if checkvariable then
                editframe:SetStatusText(L["Save pending for "] .. keyEditBox:GetText())
                variable.LastUpdated = GSE.GetTimestamp()
                local updated = GSE.DecodeTimeStamp(variable.LastUpdated)
                local oocaction = {
                    ["action"] = "updatevariable",
                    ["variable"] = variable,
                    ["name"] = keyEditBox:GetText()
                }
                table.insert(GSE.OOCQueue, oocaction)
                lastSaved:SetText(
                    L["Last Updated"] ..
                        " " ..
                            updated.month ..
                                "/" ..
                                    updated.day ..
                                        "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
                )
            else
                GSE.Print(
                    L["There is an error in the sequence that needs to be corrected before it can be saved."],
                    Statics.DebugModules["Editor"]
                )
                GSE.Print(error, Statics.DebugModules["Editor"])
            end
        end
    )
    savebutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Save"], L["Save the changes made to this variable."], editframe)
        end
    )
    savebutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    buttonRow:AddChild(savebutton)
    container:AddChild(buttonRow)
    container:AddChild(lastSaved)
end

-- ---------------------------------------------------------------------------
-- Public installer — call once per editframe
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupVariable(editframe)
    editframe.showVariable = function(name, container)
        showVariable(editframe, name, container)
    end
    editframe.buildVariablesMenu = buildVariablesMenu
end

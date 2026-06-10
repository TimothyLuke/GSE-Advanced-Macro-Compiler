local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local function SetEditBoxLabelGap(widget, gap)
    if not (widget and widget.label and widget.editBox and widget.frame) then return end
    local labelHeight = widget.label:GetStringHeight()
    if not labelHeight or labelHeight <= 0 then labelHeight = 12 end
    local g = gap or (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    widget.editBox:ClearAllPoints()
    widget.editBox:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 4, -(labelHeight + g))
    widget.editBox:SetPoint("RIGHT", widget.frame, "RIGHT", -4, 0)
end

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
    for k, _ in pairs(GSEVariables or {}) do
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
    local implementation = UI:Create("EditBox")
    local currentKey = name ~= "NEWVARIABLES" and name or nil
    local variable = {
        ["funct"] = [[function()
    return true
end]],
        ["comments"] = ""
    }
    if GSEVariables and not GSE.isEmpty(GSEVariables[name]) then
        local status, err =
            pcall(
            function()
                local _, uncompressedVersion = GSE.DecodeMessage(GSEVariables[name])
                variable = uncompressedVersion
            end
        )
        if err then
            GSE.Print(err, Statics.DebugModules["Editor"])
        end
    end

    local keyEditBox = UI:Create("EditBox")
    keyEditBox:SetCompactNoLabel(true)
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(250)
    keyEditBox:SetHeight(24)
    keyEditBox:SetText(name)
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            local implementationText = [[=GSE.V.]] .. text .. [[()]]
            implementation:SetText(implementationText)
        end
    )

    local authoreditbox = UI:Create("EditBox")
    authoreditbox:SetCompactNoLabel(true)
    authoreditbox:SetWidth(250)
    authoreditbox:SetHeight(24)
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
        variable.Author = GSE.GetCharacterName()
        authoreditbox:SetText(variable.Author)
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            variable.Author = key
        end
    )
    local function createInlineFieldRow(labelText, field)
        local row = UI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetHeight(28)
        row:SetLayout("Flow")
        if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
        if row.SetFlowGap then row:SetFlowGap(8) end
        if row.SetFlowVAlign then row:SetFlowVAlign("MIDDLE") end

        local label = UI:Create("Label")
        label:SetText(labelText)
        label:SetWidth(80)
        label:SetHeight(22)
        if label.SetJustifyV then label:SetJustifyV("MIDDLE") end

        row:AddChild(label)
        row:AddChild(field)
        return row
    end

    container:AddChild(createInlineFieldRow(L["Name"], keyEditBox))
    container:AddChild(createInlineFieldRow(L["Author"], authoreditbox))

    local commentsEditBox = UI:Create("MultiLineEditBox")
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
    -- Helpers: convert between the array stored in variable.eventNames and the
    -- comma-separated string shown in the edit box.
    local function parseEventNames(text)
        local names = {}
        for token in text:gmatch("[^,%s]+") do
            if token ~= "" then
                table.insert(names, token)
            end
        end
        return names
    end

    local function formatEventNames(names)
        if GSE.isEmpty(names) then return "" end
        return table.concat(names, ", ")
    end

    local isEventEnabled = variable.eventEnabled or false

    local eventToggle = UI:Create("CheckBox")
    eventToggle:SetLabel(L["Execute on Event"])
    eventToggle:SetWidth(150)
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

    -- Text box: editable, comma-separated list of event names.
    local eventEditBox = UI:Create("EditBox")
    eventEditBox:SetLabel(L["Trigger Events"])
    eventEditBox:SetWidth(210)
    eventEditBox:SetHeight(30)
    if eventEditBox.SetFlowFillRemaining then eventEditBox:SetFlowFillRemaining(true) end
    eventEditBox:DisableButton(true)
    eventEditBox:SetDisabled(not isEventEnabled)
    eventEditBox:SetText(formatEventNames(variable.eventNames))
    eventEditBox:SetCallback(
        "OnTextChanged",
        function(obj, event, text)
            variable.eventNames = parseEventNames(text)
        end
    )
    eventEditBox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Trigger Events"],
                L["Comma-separated list of WoW events or GSE messages that trigger this variable. You can type names directly or pick from the list on the right."],
                editframe
            )
        end
    )
    eventEditBox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    eventEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            -- Validate each manually entered event name and show type hints in the
            -- status bar: WoW events → RegisterEvent, everything else → RegisterMessage.
            local names = parseEventNames(eventEditBox:GetText())
            if GSE.isEmpty(names) then return end
            local parts = {}
            for _, evtName in ipairs(names) do
                local tag
                if Statics.InternalMessages[evtName] then
                    tag = "[GSE Msg]"
                elseif C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(evtName) then
                    tag = "[WoW Event]"
                else
                    tag = "[Addon Msg]"
                end
                table.insert(parts, evtName .. " " .. tag)
            end
            editframe:SetStatusText(table.concat(parts, "  |  "))
        end
    )

    -- Dropdown: single-select, appends the chosen event to the text box.
    local eventDropdown = UI:Create("Dropdown")
    eventDropdown:SetLabel(L["Add from List"])
    eventDropdown:SetWidth(300)
    eventDropdown:SetHeight(30)
    if eventDropdown.SetMaxVisibleItems then eventDropdown:SetMaxVisibleItems(20) end
    local eventOrder = {}
    for key, _ in pairs(Statics.VariableEventList or {}) do
        table.insert(eventOrder, key)
    end
    eventDropdown:SetList(Statics.VariableEventList, GSE.SortTableAlphabetical(eventOrder))
    eventDropdown:SetDisabled(not isEventEnabled)
    eventDropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if GSE.isEmpty(key) then return end
            local current = parseEventNames(eventEditBox:GetText())
            local found = false
            for _, v in ipairs(current) do
                if v == key then found = true; break end
            end
            if not found then
                table.insert(current, key)
                variable.eventNames = current
                eventEditBox:SetText(formatEventNames(current))
            end
        end
    )
    eventDropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Add from List"],
                L["Select a known WoW event or GSE message to append it to the Trigger Events box."],
                editframe
            )
        end
    )
    eventDropdown:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    eventToggle:SetCallback(
        "OnValueChanged",
        function(obj, event, val)
            variable.eventEnabled = val
            eventEditBox:SetDisabled(not val)
            eventDropdown:SetDisabled(not val)
            if not val then
                variable.eventNames = {}
                eventEditBox:SetText("")
            end
        end
    )

    local eventCallbackGroup = UI:Create("SimpleGroup")
    eventCallbackGroup:SetLayout("Flow")
    eventCallbackGroup:SetFullWidth(true)
    if eventCallbackGroup.SetFlowPadding then eventCallbackGroup:SetFlowPadding(0, 8, 8, 8) end
    if eventCallbackGroup.SetFlowGap    then eventCallbackGroup:SetFlowGap(4) end
    if eventCallbackGroup.SetFlowVAlign then eventCallbackGroup:SetFlowVAlign("MIDDLE") end
    eventCallbackGroup:AddChild(eventToggle)
    -- The dropdown/editbox carry labels above their boxes (~14px), pushing those
    -- boxes down. Nudge the checkbox down so its box lines up with them on one row.
    if eventToggle.SetFlowOffset then eventToggle:SetFlowOffset(0, -8) end
    eventCallbackGroup:AddChild(eventDropdown)
    eventCallbackGroup:AddChild(eventEditBox)
    container:AddChild(eventCallbackGroup)
    -- ────────────────────────────────────────────────────────────────────────

    local valueEditBox = UI:Create("MultiLineEditBox")
    valueEditBox:SetLabel(L["Variable"])
    valueEditBox:SetNumLines(11)
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
    valueEditBox:SetCallback(
        "OnRelease",
        function(widget)
            if widget and widget.editBox and IndentationLib and IndentationLib.disable then
                IndentationLib.disable(widget.editBox)
            end
        end
    )
    container:AddChild(valueEditBox)

    implementation:SetLabel(L["Implementation Link"])
    implementation:SetCompactNoLabel(false)
    implementation:SetWidth(210)
    implementation:SetHeight(32)
    implementation:DisableButton(true)
    SetEditBoxLabelGap(implementation, 2)
    local implementationText = [[=GSE.V.]] .. name .. [[()]]
    implementation:SetText(implementationText)

    local currentOutput = UI:Create("EditBox")
    currentOutput:SetLabel(L["Current Value"])
    currentOutput:SetCompactNoLabel(false)
    currentOutput:SetWidth(360)
    if currentOutput.SetFlowFillRemaining then currentOutput:SetFlowFillRemaining(true) end
    currentOutput:SetHeight(32)
    currentOutput:DisableButton(true)
    SetEditBoxLabelGap(currentOutput, 2)

    local outputText = L["Not Yet Active"]
    local function setCurrentOutput(value)
        outputText = tostring(value)
        currentOutput:SetText(outputText)
        if currentOutput.editBox and currentOutput.editBox.SetCursorPosition then
            currentOutput.editBox:SetCursorPosition(0)
        end
    end

    -- Initial value: the no-argument call of the live variable.
    if GSE.V[name] and type(GSE.V[name]) == "function" then
        setCurrentOutput(GSE.V[name]())
    else
        setCurrentOutput(L["Not Yet Active"])
    end

    -- The Implementation box is editable so a variable that takes arguments can
    -- be tested -- type e.g. =GSE.V.Prescience(2) and press Enter to re-evaluate
    -- it into Current Value. GSE.EvaluateVariableExpression compiles against the
    -- real GSE namespace so GSE.V resolves.
    implementation:SetCallback(
        "OnEnterPressed",
        function(self, event, text)
            local ok, result = GSE.EvaluateVariableExpression(text)
            if ok then
                setCurrentOutput(result)
            else
                setCurrentOutput(L["There was an error processing "] .. tostring(result))
            end
        end
    )

    currentOutput:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            currentOutput:SetText(outputText)
            if currentOutput.editBox and currentOutput.editBox.SetCursorPosition then
                currentOutput.editBox:SetCursorPosition(0)
            end
        end
    )

    local implementationOutputRow = UI:Create("SimpleGroup")
    implementationOutputRow:SetFullWidth(true)
    implementationOutputRow:SetHeight(38)
    implementationOutputRow:SetLayout("Flow")
    if implementationOutputRow.SetFlowPadding then implementationOutputRow:SetFlowPadding(0, 0, 20, 0) end
    if implementationOutputRow.SetFlowGap then implementationOutputRow:SetFlowGap(16) end
    if implementationOutputRow.SetFlowVAlign then implementationOutputRow:SetFlowVAlign("TOP") end

    implementationOutputRow:AddChild(implementation)
    implementationOutputRow:AddChild(currentOutput)
    container:AddChild(implementationOutputRow)

    local buttonRow = UI:Create("SimpleGroup")
    buttonRow:SetLayout("Flow")
    buttonRow:SetWidth(400)
    if buttonRow.SetFlowOffset then buttonRow:SetFlowOffset(-4, 0) end
    if buttonRow.SetFlowPadding then buttonRow:SetFlowPadding(0, 0, 0, 0) end
    if buttonRow.SetFlowGap then buttonRow:SetFlowGap(10) end

    local deleteRowButton = UI:Create("Button")
    deleteRowButton:SetText(L["Delete Variable"])
    deleteRowButton:SetWidth(150)
    deleteRowButton:SetCallback(
        "OnClick",
        function()
            -- Canonical helper clears GSEVariables, GSE.V cache, and the
            -- Companion PlatformID sidecar. Previously inlined
            -- `GSEVariables[k] = nil` left orphans the next sync had to
            -- scrub.
            GSE.DeleteVariable(keyEditBox:GetText())
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

    local savebutton = UI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback(
        "OnClick",
        function()
            local checkvariable, error = GSE.CheckVariable(valueEditBox:GetText())
            if checkvariable then
                local saveName = keyEditBox:GetText()
                if GSE.isEmpty(saveName) then
                    GSE.Print("The variable name cannot be empty.", Statics.DebugModules["Editor"])
                    return
                end
                editframe:SetStatusText(L["Save pending for "] .. keyEditBox:GetText())
                variable.LastUpdated = GSE.GetTimestamp()
                local updated = GSE.DecodeTimeStamp(variable.LastUpdated)
                local oocaction = {
                    ["action"] = "updatevariable",
                    ["variable"] = variable,
                    ["name"] = saveName
                }
                GSE.EnqueueOOC(oocaction)
                if not GSE.isEmpty(currentKey) and currentKey ~= saveName and GSEVariables and not GSE.isEmpty(GSEVariables[currentKey]) then
                    GSE.EnqueueOOC(
                        {
                            ["action"] = "deletevariable",
                            ["variablename"] = currentKey
                        }
                    )
                end
                currentKey = saveName
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
    buttonRow:AddChild(deleteRowButton)
    container:AddChild(buttonRow)

    -- Dependencies — styled table matching the sequence metadata window
    local varDeps    = variable.Dependencies
    local dependents = GSE.GetVariableDependents(name)

    if GSE.GUI.CreateDependencyWindow then
        local heading = L["Used by Sequences"] .. ":"
        local fmt     = GSE.GUI.FormatDependencyTimestamp or function() return "" end

        local rows = {}
        for _, entry in ipairs(dependents.sequences) do
            local seq     = GSE.Library and GSE.Library[entry.classid] and GSE.Library[entry.classid][entry.name]
            local author  = seq and (seq.Author or (seq.MetaData and seq.MetaData.Author)) or ""
            local updated = seq and fmt(seq.LastUpdated or (seq.MetaData and seq.MetaData.LastUpdated)) or ""
            rows[#rows+1] = { name = entry.name, author = author, updated = updated }
        end

        GSE.GUI.CreateDependencyWindow(container, heading, rows, { hideAuthor = false, hideType = true })
    end
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
end
table.insert(ns.deferred, setup)

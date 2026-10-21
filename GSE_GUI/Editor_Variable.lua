local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- The Save button under the Notes - Help page's box, with its gap.
local NOTES_SAVE_ROW_HEIGHT = 34

-- The Implementation Link is what the author pastes into a macro block, so it
-- has to be valid Lua for ANY name they gave the variable. Built by blind
-- concatenation as =GSE.V.<name>(), a name that is not a bare identifier --
-- "SLG-SBAssist-LvL" -- came out as =GSE.V.SLG-SBAssist-LvL(), which parses as
-- subtraction ending in a nil call, throws, and is swallowed as a missing
-- variable: the editor's Current Value box worked (it indexes GSE.V[name])
-- while the sequence produced nothing. Bracket-index anything that is not a
-- valid identifier, the way GSE already references variables internally.
local function VariableImplementationLink(name)
    name = tostring(name or "")
    if name:match("^[%a_][%w_]*$") then
        return "=GSE.V." .. name .. "()"
    end
    return "=GSE.V['" .. name:gsub("'", "\\'") .. "']()"
end

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
-- buildVariablesMenu()  →  tree node for the Variables section, and where each
-- variable sits in it
-- ---------------------------------------------------------------------------
-- A variable is filed under the class it is scoped to, Global last, as a
-- sequence is. Returns the node, and "VARIABLES\001<name>" -> the node's path
-- through its class folder, for selecting a variable by name.
local function buildVariablesMenu(editframe)
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
    local folders, byClass, paths = {}, {}, {}
    -- Alphabetical, the same order and the same comparison the sequence tree
    -- uses. pairs() gave hash order, so the list shuffled between sessions.
    for k, _ in GSE.pairsByKeys(GSE.Store("variable") or {}, GSE.AlphabeticalTableSortAlgorithm) do
        local classid = GSE.ElementScopeClass("variable", k) or 0
        local folder = byClass[classid]
        if not folder then
            folder = GSE.GUI.ClassFolder(classid)
            byClass[classid] = folder
            folders[#folders + 1] = folder
        end
        table.insert(folder.children, {
            value = k,
            text = "|CFFFFFFFF" .. k .. Statics.StringReset,
            children = GSE.GUI.ElementTreeNodes(editframe, editframe.variableVersions(k))
        })
        paths["VARIABLES\001" .. k] = "VARIABLES\001" .. folder.value .. "\001" .. k
    end
    GSE.GUI.SortClassFolders(folders)
    for _, folder in ipairs(folders) do table.insert(tree.children, folder) end
    return tree, paths
end

-- ---------------------------------------------------------------------------
-- showVariable(editframe, name, container, selected)
-- Renders the variable editor into container, on version `selected`.
--
-- A variable is scoped and versioned as a sequence is (GSE.UpgradeVariable):
-- MetaData carries its name, author, scope, help and which version runs where,
-- Versions what runs. The element being edited is kept on the editframe as a
-- draft, so choosing another version redraws the page without losing edits.
-- ---------------------------------------------------------------------------
-- The variable being edited, kept on the editframe as a draft so its
-- Configuration and Notes - Help pages, and a version switch, share edits.
-- storedKey is the name it is stored under (nil for a new one).
local function variableDraft(editframe, name)
    local draft = editframe.variableDraft
    if not (draft and draft.name == name) then
        local variable = {
            MetaData = {Default = 1},
            Versions = {{funct = [[function()
    return true
end]]}},
        }
        if GSE.Store("variable") and not GSE.isEmpty(GSE.Store("variable")[name]) then
            local status, err =
                pcall(
                function()
                    local _, uncompressedVersion = GSE.DecodeMessage(GSE.Store("variable")[name])
                    variable = uncompressedVersion
                end
            )
            if err then
                GSE.Print(err, Statics.DebugModules["Editor"])
            end
        end
        local storedKey = name ~= "NEWVARIABLES" and name or nil
        draft = {name = name, storedKey = storedKey, variable = GSE.UpgradeVariable(variable, storedKey)}
        editframe.variableDraft = draft
    end
    return draft
end

-- A version's editor keeps its function as coloured text until the box loses
-- focus; take every version back to plain Lua before it is copied or saved.
local function settleDraft(draft)
    for _, v in ipairs(draft.variable.Versions) do
        if type(v.funct) == "string" then v.funct = IndentationLib.decode(v.funct) end
    end
end

-- A variable's versions, for its tree nodes: the draft's while it is being
-- edited (so an unsaved New Version shows), else the stored ones. A stored
-- variable is decoded once per change to what is stored, not per tree build.
local storedVersions = {}
local function variableVersions(editframe, name)
    local draft = editframe.variableDraft
    if draft and draft.name == name then return draft.variable.Versions end
    local stored = GSE.Store("variable") and GSE.Store("variable")[name]
    if GSE.isEmpty(stored) then return nil end
    local cached = storedVersions[name]
    if cached and cached.stored == stored then return cached.versions end
    local pok, ok, decoded = pcall(GSE.DecodeMessage, stored)
    if not (pok and ok and type(decoded) == "table") then return nil end
    local versions = GSE.UpgradeVariable(decoded, name).Versions
    storedVersions[name] = {stored = stored, versions = versions}
    return versions
end

-- New Version: a copy of the Default version, at the end. Returns its index.
local function newVariableVersion(editframe, name)
    local draft = variableDraft(editframe, name)
    settleDraft(draft)
    local versions = draft.variable.Versions
    local default = tonumber(draft.variable.MetaData.Default) or 1
    local copy = GSE.CloneSequence(versions[default] or versions[1] or {})
    copy.Label = nil
    table.insert(versions, copy)
    editframe:SetStatusText(L["Save pending for "] .. draft.name)
    return #versions
end

-- Save the draft under saveName: every version has to compile, not only the
-- one on screen. A rename deletes the old name. Returns true when queued.
local function saveVariable(editframe, draft)
    settleDraft(draft)
    -- A name typed on the Configuration page, wherever Save is pressed.
    local saveName = draft.pendingName or draft.name
    local variable = draft.variable
    for index, v in ipairs(variable.Versions) do
        local ok, err = GSE.CheckVariable(v.funct or "")
        if not ok then
            GSE.Print(
                L["There is an error in the sequence that needs to be corrected before it can be saved."],
                Statics.DebugModules["Editor"]
            )
            GSE.Print(string.format("%s %d: %s", L["Version"], index, tostring(err)), Statics.DebugModules["Editor"])
            return false
        end
    end
    if GSE.isEmpty(saveName) then
        GSE.Print("The variable name cannot be empty.", Statics.DebugModules["Editor"])
        return false
    end
    editframe:SetStatusText(L["Save pending for "] .. saveName)
    variable.LastUpdated = GSE.GetTimestamp()
    -- The build that saved it, as the sequence editor stamps
    -- MetaData.GSEVersion.
    variable.GSEVersion = GSE.VersionNumber
    variable.MetaData.Name = saveName
    GSE.EnqueueOOC({
        ["action"] = "updatevariable",
        ["variable"] = GSE.CloneSequence(variable),
        ["name"] = saveName
    })
    local oldKey = draft.storedKey
    if not GSE.isEmpty(oldKey) and oldKey ~= saveName and GSE.Store("variable") and not GSE.isEmpty(GSE.Store("variable")[oldKey]) then
        GSE.EnqueueOOC({
            ["action"] = "deletevariable",
            ["variablename"] = oldKey
        })
    end
    draft.storedKey = saveName
    draft.name = saveName
    draft.pendingName = nil
    return true
end

-- Save, centred on its own row; `extra`, when given, is another button beside it.
local function addSaveRow(editframe, container, draft, extra)
    local buttonRow = UI:Create("SimpleGroup")
    buttonRow:SetLayout("Flow")
    buttonRow:SetFullWidth(true)
    if buttonRow.SetFlowHAlign then buttonRow:SetFlowHAlign("CENTER") end
    if buttonRow.SetFlowPadding then buttonRow:SetFlowPadding(0, 0, 0, 0) end
    if buttonRow.SetFlowGap then buttonRow:SetFlowGap(10) end
    local savebutton = UI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback("OnClick", function() saveVariable(editframe, draft) end)
    savebutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Save"], L["Save the changes made to this variable."], editframe)
    end)
    savebutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    buttonRow:AddChild(savebutton)
    if extra then buttonRow:AddChild(extra) end
    container:AddChild(buttonRow)
end

-- The variable's Configuration page: what it is called, who wrote it, where
-- it loads, which version runs where, and what uses it.
local function showVariable(editframe, name, container)
    editframe.SequenceName = name
    local currentKey = name ~= "NEWVARIABLES" and name or nil
    local draft = variableDraft(editframe, name)
    local variable = draft.variable
    local function redraw()
        container:ReleaseChildren()
        showVariable(editframe, name, container)
        if container.DoLayout then container:DoLayout() end
    end

    local keyEditBox = UI:Create("EditBox")
    keyEditBox:SetCompactNoLabel(true)
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(250)
    keyEditBox:SetHeight(24)
    keyEditBox:SetText(draft.pendingName or name)
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            draft.pendingName = (text ~= draft.name) and text or nil
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
    if GSE.isEmpty(variable.MetaData.Author) then
        variable.MetaData.Author = GSE.GetCharacterName()
    end
    authoreditbox:SetText(variable.MetaData.Author)
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            variable.MetaData.Author = key
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
    local scopeDropdown
    if GSE.GUI.DrawElementScope then
        scopeDropdown = GSE.GUI.DrawElementScope(editframe, container, variable,
            currentKey and GSE.SuggestElementScope and GSE.SuggestElementScope("variable", currentKey), redraw)
    end
    if currentKey and GSE.GUI.DrawElementCollections then
        GSE.GUI.DrawElementCollections(container, "variable", currentKey)
    end

    -- Which version runs where: Default and the context overrides.
    if GSE.GUI.DrawElementVersionConfig then
        local configGap = UI:Create("Spacer")
        configGap:SetHeight(8)
        container:AddChild(configGap)
        GSE.GUI.DrawElementVersionConfig(editframe, container, variable, nil, scopeDropdown)
    end

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
            GSE.DeleteVariable(draft.storedKey or name)
            editframe.variableDraft = nil
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
    addSaveRow(editframe, container, draft, deleteRowButton)

    -- Dependencies — styled table matching the sequence metadata window
    local varDeps    = variable.Dependencies
    local dependents = GSE.GetVariableDependents(name)

    if GSE.GUI.CreateDependencyWindow then
        local heading = L["Used by Sequences"] .. ":"
        local fmt     = GSE.GUI.FormatDependencyTimestamp or function() return "" end

        local rows = {}
        for _, entry in ipairs(dependents.sequences) do
            local seq     = GSE.Library and GSE.Library[entry.classid] and GSE.Library[entry.classid][entry.id]
            local author  = seq and (seq.Author or (seq.MetaData and seq.MetaData.Author)) or ""
            local updated = seq and fmt(seq.LastUpdated or (seq.MetaData and seq.MetaData.LastUpdated)) or ""
            rows[#rows+1] = { name = entry.name, author = author, updated = updated }
        end

        GSE.GUI.CreateDependencyWindow(container, heading, rows, { hideAuthor = false, hideType = true })
    end
end

-- One version's page: its label, the events it runs on, its function, and a
-- box to try it in. Returns the version shown (the first, when `index` is gone).
local function showVariableVersion(editframe, name, container, index)
    editframe.SequenceName = name
    local draft = variableDraft(editframe, name)
    local variable = draft.variable
    index = tonumber(index) or 1
    if not variable.Versions[index] then index = 1 end
    local version = variable.Versions[index]

    if GSE.GUI.DrawElementVersionHeader then
        GSE.GUI.DrawElementVersionHeader(editframe, container, variable, index, function()
            editframe:SetStatusText(L["Save pending for "] .. draft.name)
        end, function(shown)
            if editframe.ManageTree then editframe.ManageTree() end
            GSE.GUI.SelectEditorTreePath(editframe, "VARIABLES\001" .. name .. "\001" .. shown)
        end)
    end

    -- Event Callback Section ─────────────────────────────────────────────────
    -- The events a version runs on: listed one to a line, each removable, and
    -- added from a combo box that offers the known ones and takes any other
    -- name typed into it.
    local isEventEnabled = version.eventEnabled or false

    -- What GSE registers a name as: a GSE message, a WoW event, or anything
    -- else as an addon message (GSE.RegisterVariableEvents decides the same).
    local function eventKind(evtName)
        if Statics.InternalMessages[evtName] then return L["GSE Message"] end
        if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(evtName) then
            return L["WoW Event"]
        end
        return L["Addon Message"]
    end

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

    local addEvent = UI:Create("ComboBox")
    addEvent:SetLabel(L["Add Trigger Event"])
    addEvent:SetWidth(300)
    if addEvent.SetFlowFillRemaining then addEvent:SetFlowFillRemaining(true) end
    local eventOrder = {}
    for key, _ in pairs(Statics.VariableEventList or {}) do
        table.insert(eventOrder, key)
    end
    addEvent:SetList(Statics.VariableEventList, GSE.SortTableAlphabetical(eventOrder))
    addEvent:SetPlaceholder(L["Pick one, or type an event's name and press Enter"])
    addEvent:SetDisabled(not isEventEnabled)
    addEvent:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Add Trigger Event"],
                L["Pick a WoW event or GSE message from the list, or type the name of one that is not listed and press Enter."],
                editframe
            )
        end
    )
    addEvent:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local eventRow = UI:Create("SimpleGroup")
    eventRow:SetLayout("Flow")
    eventRow:SetFullWidth(true)
    if eventRow.SetFlowPadding then eventRow:SetFlowPadding(0, 8, 8, 0) end
    if eventRow.SetFlowGap then eventRow:SetFlowGap(8) end
    if eventRow.SetFlowVAlign then eventRow:SetFlowVAlign("BOTTOM") end
    eventRow:AddChild(eventToggle)
    eventRow:AddChild(addEvent)
    container:AddChild(eventRow)

    -- The list itself, redrawn in place as events come and go.
    local eventList = UI:Create("SimpleGroup")
    eventList:SetLayout("List")
    eventList:SetFullWidth(true)
    if eventList.SetListPadding then eventList:SetListPadding(158, 0, 8, 4) end
    if eventList.SetListGap then eventList:SetListGap(2) end
    container:AddChild(eventList)

    local function drawEventList()
        eventList:ReleaseChildren()
        local names = version.eventNames or {}
        if #names == 0 then
            local none = UI:Create("Label")
            none:SetText("|cFF9D9D9D" .. L["No trigger events."] .. "|r")
            none:SetFullWidth(true)
            eventList:AddChild(none)
        end
        for i, evtName in ipairs(names) do
            local row = UI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetFullWidth(true)
            if row.SetFlowGap then row:SetFlowGap(8) end
            if row.SetFlowVAlign then row:SetFlowVAlign("MIDDLE") end
            local remove = UI:Create("Button")
            remove:SetText(L["Remove"])
            remove:SetWidth(80)
            remove:SetDisabled(not version.eventEnabled)
            remove:SetCallback("OnClick", function()
                table.remove(version.eventNames, i)
                drawEventList()
            end)
            local text = UI:Create("Label")
            text:SetText("|cFFFFFFFF" .. evtName .. "|r  |cFF9D9D9D" .. eventKind(evtName) .. "|r")
            text:SetWidth(420)
            row:AddChild(remove)
            row:AddChild(text)
            eventList:AddChild(row)
        end
        if container.DoLayout then container:DoLayout() end
    end
    drawEventList()

    addEvent:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if GSE.isEmpty(key) then return end
            version.eventNames = version.eventNames or {}
            for _, v in ipairs(version.eventNames) do
                if v == key then return end
            end
            table.insert(version.eventNames, key)
            drawEventList()
        end
    )

    eventToggle:SetCallback(
        "OnValueChanged",
        function(obj, event, val)
            version.eventEnabled = val
            addEvent:SetDisabled(not val)
            if not val then version.eventNames = {} end
            drawEventList()
        end
    )
    -- ────────────────────────────────────────────────────────────────────────

    local valueEditBox = UI:Create("MultiLineEditBox")
    valueEditBox:SetLabel(L["Variable"])
    valueEditBox:SetNumLines(11)
    valueEditBox:SetFullWidth(true)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(version.funct or "")
    valueEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            version.funct = IndentationLib.encode(text)
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            local variabletext = IndentationLib.decode(valueEditBox:GetText())
            version.funct = variabletext
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

    local implementation = UI:Create("EditBox")
    implementation:SetLabel(L["Implementation Link"])
    implementation:SetCompactNoLabel(false)
    implementation:SetWidth(210)
    implementation:SetHeight(32)
    implementation:DisableButton(true)
    SetEditBoxLabelGap(implementation, 2)
    local implementationText = VariableImplementationLink(draft.name)
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
        -- One value: a variable that returns nothing reads as nil.
        setCurrentOutput((GSE.V[name]()))
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

    addSaveRow(editframe, container, draft)
    return index
end


-- The variable's Notes - Help page: its Help Link, and Help Information
-- (MetaData.Notes, read-only once GSE.Tools has rendered Help), with a Save
-- as on its Configuration page. height: the room the page has.
local function showVariableNotes(editframe, name, container, height)
    editframe.SequenceName = name
    local draft = variableDraft(editframe, name)
    local meta = draft.variable.MetaData
    GSE.GUI.DrawNotesPage(editframe, container, {
        meta = meta,
        key = "Notes",
        readOnly = not GSE.isEmpty(meta.Help) and meta.Help or nil,
        linkTip = L["Website or forum URL where a player can get more information or ask questions about this variable."],
        height = height - NOTES_SAVE_ROW_HEIGHT,
    })
    local savebutton = UI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback("OnClick", function() saveVariable(editframe, draft) end)
    savebutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Save"], L["Save the changes made to this variable."], editframe)
    end)
    savebutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    -- Centred, as the Configuration page's Save / Delete Variable row is.
    local buttonRow = UI:Create("SimpleGroup")
    buttonRow:SetLayout("Flow")
    buttonRow:SetFullWidth(true)
    if buttonRow.SetFlowHAlign then buttonRow:SetFlowHAlign("CENTER") end
    if buttonRow.SetFlowPadding then buttonRow:SetFlowPadding(0, 0, 0, 0) end
    buttonRow:AddChild(savebutton)
    container:AddChild(buttonRow)
end

-- ---------------------------------------------------------------------------
-- Public installer — call once per editframe
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupVariable(editframe)
    -- Opened from the tree. A variable's Configuration and Notes - Help pages
    -- share one draft, so moving between them keeps unsaved edits; another
    -- variable is read afresh.
    editframe.showVariable = function(name, container)
        showVariable(editframe, name, container)
    end
    editframe.showVariableVersion = function(name, container, index)
        return showVariableVersion(editframe, name, container, index)
    end
    editframe.variableVersions = function(name) return variableVersions(editframe, name) end
    editframe.newVariableVersion = function(name) return newVariableVersion(editframe, name) end
    editframe.showVariableNotes = function(name, container, height)
        showVariableNotes(editframe, name, container, height)
    end
    editframe.buildVariablesMenu = function() return buildVariablesMenu(editframe) end
end
end
table.insert(ns.deferred, setup)

local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local MIN_FIELD_WIDTH = 160
local CONFIG_CONTENT_LEFT_PADDING = GSE.GUI.CONTENT_PADDING and (GSE.GUI.CONTENT_PADDING + 10) or 30
local FIELD_WIDTH = 220
local MAX_FIELD_WIDTH = 190
local DROPDOWN_VISUAL_WIDTH_OFFSET = 15
local ROW_HEIGHT = 48
local INLINE_ROW_HEIGHT = 30
local INLINE_CONTROL_Y_OFFSET = 2
local METADATA_LABEL_WIDTH = 130
local METADATA_SINGLE_COLUMN_LABEL_WIDTH = 170
local METADATA_VERSION_ROW_INDENT = 10
local FIELD_SPACER = 30
local FORM_SIDE_PADDING = 24
local FIELD_COLUMN_EXTRA_WIDTH = 12
local CENTER_COLUMN_HALF_GAP = 5
local METADATA_SECTION_GAP = 8
local METADATA_HEADER_HEIGHT = 24
local DEPENDENCY_WINDOW_HEIGHT = 118
local DEPENDENCY_NAME_WIDTH = 190
local DEPENDENCY_TYPE_WIDTH = 45
local DEPENDENCY_AUTHOR_WIDTH = 170
local DEPENDENCY_DATE_WIDTH = 130
local DEPENDENCY_DATE_LEFT_OFFSET = 25
local DEPENDENCY_COLUMN_GAP_WIDTH = 8
local DEPENDENCY_TABLE_LEFT = 10
local DEPENDENCY_HEADER_TOP = -4
local DEPENDENCY_HEADER_HEIGHT = 15
-- Must clear the header band drawn on the box frame (DEPENDENCY_HEADER_TOP 4
-- + DEPENDENCY_HEADER_HEIGHT 15) -- at 8 the first row overlapped the column
-- titles. The scroll content already starts inset below the frame top, so the
-- padding needed here is less than the band's full 19.
local DEPENDENCY_DATA_TOP_PADDING = 12
local METADATA_BOTTOM_PADDING = 12
local METADATA_LAYOUT_GAP_ALLOWANCE = 24
local CONFIG_TAB_ROW_HEIGHT = 42
local CONFIG_TAB_BUTTON_WIDTH = 118
local CONFIG_TAB_BUTTON_HEIGHT = 28
local CONFIG_TAB_VISUAL_GAP = 2
local CONFIG_TAB_TEMPLATE_SIDE_PAD = 10
local CONFIG_TAB_GAP = CONFIG_TAB_VISUAL_GAP - (CONFIG_TAB_TEMPLATE_SIDE_PAD * 2)
local NOTES_HELP_LINES = 19
-- Height of the read-only rendered notes panel. Matched to the editable box it
-- stands in for -- NativeUI's SetNumLines(n) is n * 16 + frameContentTop(28) --
-- so the tab keeps the same shape whether the sequence carries website notes
-- or locally typed help.
local NOTES_RENDERED_HEIGHT = (NOTES_HELP_LINES * 16) + 28
local NOTES_RENDERED_SIDE_ALLOWANCE = 60
-- Grey (WoW's "poor" quality colour) for the read-only hint beside the heading,
-- so it reads as a state note and not as part of the author's own text.
local NOTES_READONLY_HINT_COLOUR = "|cFF9D9D9D"

local GUIDrawMetadataEditor
-- Forward-declared: currentConfigSubTab decides the landing tab from it, and
-- sits above the notes helpers that define it.
local markdownNotesText

local function T(key)
    local value = L[key]
    if value == nil or value == true then return key end
    return value
end

local function inlineFieldRow(labelText, control, labelWidth)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(INLINE_ROW_HEIGHT)
    if row.SetFlowGap then row:SetFlowGap(8) end
    if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end

    local label = UI:Create("Label")
    label:SetText(labelText)
    label:SetWidth(labelWidth or METADATA_LABEL_WIDTH)
    row:AddChild(label)
    if control.SetFlowOffset then control:SetFlowOffset(0, INLINE_CONTROL_Y_OFFSET) end
    row:AddChild(control)
    return row
end

local function versionValue(metadata, key)
    local value = metadata and metadata[key]
    if GSE.isEmpty(value) then value = metadata and metadata.Default or 1 end
    return tostring(value)
end

local function metadataContentWidth(editframe, container)
    local width = editframe and editframe.metadataContentWidth or 0
    if width <= 0 then
        width = container and container.frame and container.frame.GetWidth and container.frame:GetWidth() or 0
    end
    if width <= 0 and editframe then
        local treeWidth = editframe.treeContainer and editframe.treeContainer.GetTreeWidth and editframe.treeContainer:GetTreeWidth() or 0
        width = (editframe.Width or 700) - treeWidth - 72
    end

    return width
end

local function formFieldWidth(editframe, container)
    local width = metadataContentWidth(editframe, container)
    local available = math.floor((width - FIELD_SPACER - FORM_SIDE_PADDING) / 2)
    local centerAligned = math.floor(width / 2) - CENTER_COLUMN_HALF_GAP - METADATA_LABEL_WIDTH - 8
    return math.min(MAX_FIELD_WIDTH, math.max(MIN_FIELD_WIDTH, math.min(available, centerAligned)))
end

local function disableTextWrap(widget)
    local fontString = widget and (widget.text or widget.label)
    if fontString and fontString.SetWordWrap then fontString:SetWordWrap(false) end
end

local function setEditBoxLabelGap(widget, gap)
    if not (widget and widget.label and widget.editBox and widget.frame) then return end
    local labelHeight = widget.label:GetStringHeight()
    if not labelHeight or labelHeight <= 0 then labelHeight = 12 end
    local g = gap or (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    widget.editBox:ClearAllPoints()
    widget.editBox:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 4, -(labelHeight + g))
    widget.editBox:SetPoint("RIGHT", widget.frame, "RIGHT", -4, 0)
end

local function addDependencyLine(container, text)
    local label = UI:Create("Label")
    label:SetFullWidth(true)
    if label.SetColor then label:SetColor(1, 1, 1, 1) end
    disableTextWrap(label)
    label:SetText(text)
    container:AddChild(label)
end

local function dependencyColumnLabel(text, width, justify)
    local label = UI:Create("Label")
    label:SetText(text or "")
    label:SetWidth(width)
    if label.SetHeight then label:SetHeight(16) end
    if label.SetColor then label:SetColor(1, 1, 1, 1) end
    if label.SetJustifyH then label:SetJustifyH(justify or "LEFT") end
    disableTextWrap(label)
    return label
end

local function trimDependencyColon(text)
    return tostring(text or ""):gsub(":%s*$", "")
end

local function formatDependencyTimestamp(timestamp)
    if GSE.isEmpty(timestamp) or not GSE.DecodeTimeStamp then return "" end
    local ok, updated = pcall(GSE.DecodeTimeStamp, tostring(timestamp))
    if not ok or type(updated) ~= "table" then return "" end
    return updated.month .. "/" .. updated.day .. "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
end

GSE.GUI.FormatDependencyTimestamp = formatDependencyTimestamp

local function storedVariableInfo(name)
    if GSE.isEmpty(GSEVariables) or GSE.isEmpty(GSEVariables[name]) then return nil end

    local stored = GSEVariables[name]
    if type(stored) == "table" then return stored end
    if not GSE.DecodeMessage then return nil end

    local ok, success, decoded = pcall(function() return GSE.DecodeMessage(stored) end)
    if ok and success and type(decoded) == "table" then return decoded end
    return nil
end

local function isStoredMacroNode(node)
    return type(node) == "table" and (
        node.text ~= nil or
        node.icon ~= nil or
        node.value ~= nil or
        node.Managed ~= nil or
        node.managedMacro ~= nil or
        node.manageMacro ~= nil
    )
end

local function currentCharacterMacroBucket()
    if not UnitFullName then return nil end
    local char, realm = UnitFullName("player")
    if GSE.isEmpty(realm) and GetRealmName then
        realm = string.gsub(GetRealmName(), "%s*", "")
    end
    if GSE.isEmpty(char) or GSE.isEmpty(realm) then return nil end
    return char .. "-" .. realm
end

local function storedMacroInfo(name)
    if GSE.isEmpty(GSEMacros) then return nil end
    if isStoredMacroNode(GSEMacros[name]) then return GSEMacros[name] end

    local currentBucket = currentCharacterMacroBucket()
    if currentBucket and type(GSEMacros[currentBucket]) == "table" and isStoredMacroNode(GSEMacros[currentBucket][name]) then
        return GSEMacros[currentBucket][name]
    end

    for _, bucket in pairs(GSEMacros) do
        if type(bucket) == "table" and isStoredMacroNode(bucket[name]) then
            return bucket[name]
        end
    end
    return nil
end

local function addDependencyRow(container, name, dependencyType, author, updated, hideAuthor, hideType)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    -- 16 fits the single line of GameFont text; 22 + list gap read as
    -- double-spaced rows.
    row:SetHeight(16)
    if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
    if row.SetFlowGap then row:SetFlowGap(DEPENDENCY_COLUMN_GAP_WIDTH) end
    if row.SetFlowVAlign then row:SetFlowVAlign("MIDDLE") end
    row:AddChild(dependencyColumnLabel(name, DEPENDENCY_NAME_WIDTH))
    if not hideType then
        row:AddChild(dependencyColumnLabel(dependencyType, DEPENDENCY_TYPE_WIDTH, "CENTER"))
    end
    if not hideAuthor then
        row:AddChild(dependencyColumnLabel(author, DEPENDENCY_AUTHOR_WIDTH))
    end
    if not (hideType and hideAuthor) then
        -- Spacer + its trailing flow gap must equal DEPENDENCY_DATE_LEFT_OFFSET so the
        -- date cell lines up under the header (which adds the raw offset, no extra gap).
        row:AddChild(dependencyColumnLabel("", DEPENDENCY_DATE_LEFT_OFFSET - DEPENDENCY_COLUMN_GAP_WIDTH))
    end
    row:AddChild(dependencyColumnLabel(updated, DEPENDENCY_DATE_WIDTH))
    container:AddChild(row)
end

local function addDependencyVariableRow(container, name)
    local variable = storedVariableInfo(name)
    local exists = variable ~= nil
    local displayName = exists and name or ("|cFFFF0000" .. name .. " (!)|r")
    local author = exists and (variable.Author or (variable.MetaData and variable.MetaData.Author) or "") or ""
    local updated = exists and formatDependencyTimestamp(variable.LastUpdated or (variable.MetaData and variable.MetaData.LastUpdated)) or ""

    addDependencyRow(container, displayName, "V", author, updated)
end

local function addDependencyMacroRow(container, name)
    local slot = GetMacroIndexByName and GetMacroIndexByName(name)
    local onChar = slot and slot > 0
    local macro = storedMacroInfo(name)
    local displayName = name
    if not onChar then
        displayName = macro and ("|cFFFFFF00" .. name .. " (stored)|r") or ("|cFFFF0000" .. name .. " (!)|r")
    end
    local author = macro and (macro.Author or (macro.MetaData and macro.MetaData.Author) or "") or ""
    local updated = macro and formatDependencyTimestamp(macro.LastUpdated or (macro.MetaData and macro.MetaData.LastUpdated)) or ""

    addDependencyRow(container, displayName, "M", author, updated)
end

local function addDependencyHeaderColumn(frame, text, left, width, justify)
    if not frame then return end
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, DEPENDENCY_HEADER_TOP + 1)
    label:SetWidth(width)
    label:SetHeight(DEPENDENCY_HEADER_HEIGHT)
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("MIDDLE")
    if label.SetWordWrap then label:SetWordWrap(false) end
    label:SetText(text)
end

local function applyDependencyHeader(dependencyBox, hideAuthor, hideType)
    if not (dependencyBox and dependencyBox.frame) then return end
    local frame = dependencyBox.frame

    local tint = frame:CreateTexture(nil, "BACKGROUND")
    tint:SetPoint("TOPLEFT",  frame, "TOPLEFT",  5, DEPENDENCY_HEADER_TOP)
    tint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, DEPENDENCY_HEADER_TOP)
    tint:SetHeight(DEPENDENCY_HEADER_HEIGHT)
    tint:SetColorTexture(0.42, 0.42, 0.42, 0.28)

    local typeLeft   = DEPENDENCY_TABLE_LEFT + DEPENDENCY_NAME_WIDTH + DEPENDENCY_COLUMN_GAP_WIDTH
    local authorLeft = hideType
        and typeLeft
        or  (typeLeft + DEPENDENCY_TYPE_WIDTH + DEPENDENCY_COLUMN_GAP_WIDTH)
    local dateLeft   = authorLeft
        + (hideAuthor and 0 or (DEPENDENCY_AUTHOR_WIDTH + DEPENDENCY_COLUMN_GAP_WIDTH))
        + ((hideType and hideAuthor) and 0 or DEPENDENCY_DATE_LEFT_OFFSET)

    addDependencyHeaderColumn(frame, T("Name"), DEPENDENCY_TABLE_LEFT, DEPENDENCY_NAME_WIDTH)
    if not hideType then
        addDependencyHeaderColumn(frame, T("Type"), typeLeft, DEPENDENCY_TYPE_WIDTH, "CENTER")
    end
    if not hideAuthor then
        addDependencyHeaderColumn(frame, T("Author"), authorLeft, DEPENDENCY_AUTHOR_WIDTH)
    end
    addDependencyHeaderColumn(frame, T("Date Last Updated"), dateLeft, DEPENDENCY_DATE_WIDTH)
end

local pveVersionConfigs = {
    {key="PVESolo",     label=T("Solo"),        tip=T("The version of this sequence to use while solo in PvE.")},
    {key="Scenario",    label=T("Delves/Scenarios"), tip=T("The version of this sequence to use in Delves and Scenarios.")},
    {key="Timewalking", label=T("Timewalking"), tip=T("The version of this sequence to use when in time walking dungeons.")},
    {key="Dungeon",     label=T("Dungeon"),     tip=T("The version of this sequence to use in normal dungeons.")},
    {key="MythicPlus",  label=T("Mythic+"),     tip=T("The version of this sequence to use in Mythic+ Dungeons.")},
    {key="Raid",        label=T("Raid"),        tip=T("The version of this sequence that will be used when you enter raids.")},
}

local pvpVersionConfigs = {
    {key="PVP",         label=T("Solo"),        tip=T("The version of this sequence to use in PVP.")},
    {key="Arena",       label=T("Arena"),       tip=T("The version of this sequence to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default.")},
}

local function dependencyData(editframe)
    local raw = editframe.Sequence.MetaData and editframe.Sequence.MetaData.Dependencies
    local deps = raw
    -- Hide placeholder macro names (e.g. "Need Stuff Here", the default block text)
    -- by building a filtered copy. Existing sequences with stale deps still display
    -- correctly without needing to recompute and re-save them.
    if raw and type(raw.Macros) == "table" and GSE.PlaceholderMacroNames then
        local filtered = {}
        for _, m in ipairs(raw.Macros) do
            if not GSE.PlaceholderMacroNames[m] then
                table.insert(filtered, m)
            end
        end
        if #filtered ~= #raw.Macros then
            deps = { Variables = raw.Variables, Sequences = raw.Sequences, Macros = filtered }
        end
    end
    local hasDeps = deps and
        ((type(deps.Variables) == "table" and #deps.Variables > 0) or
         (type(deps.Sequences) == "table" and #deps.Sequences > 0) or
         (type(deps.Macros)    == "table" and #deps.Macros    > 0))
    local usedBy = GSE.GetSequenceDependents(editframe.SequenceName) or {}
    return deps, hasDeps, usedBy
end

local function addDependencyLabels(editframe, container, deps, hasDeps, usedBy, includeHeading)
    if not (hasDeps or #usedBy > 0) then return end

    if includeHeading ~= false then
        local depHeading = UI:Create("Heading")
        depHeading:SetText(L["Dependencies"])
        depHeading:SetFullWidth(true)
        disableTextWrap(depHeading)
        container:AddChild(depHeading)
    end

    if hasDeps then
        if deps.Macros and #deps.Macros > 0 then
            for _, mname in ipairs(deps.Macros) do
                addDependencyMacroRow(container, mname)
            end
        end

        if deps.Variables and #deps.Variables > 0 then
            for _, vname in ipairs(deps.Variables) do
                addDependencyVariableRow(container, vname)
            end
        end

        if deps.Sequences and #deps.Sequences > 0 then
            addDependencyLine(container, L["Embeds Sequences:"])
            for _, sname in ipairs(deps.Sequences) do
                local exists = false
                for chkclass = 0, 13 do
                    if GSESequences[chkclass] and not GSE.isEmpty(GSESequences[chkclass][sname]) then
                        exists = true
                        break
                    end
                end
                addDependencyLine(container, (exists and "  " or "  |cFFFF0000") .. sname .. (exists and "" or " (!)|r"))
            end
        end
    end

    if #usedBy > 0 then
        addDependencyLine(container, L["Embedded by:"])
        for _, entry in ipairs(usedBy) do
            addDependencyLine(container, "  " .. entry.name .. " (" .. L["Class"] .. " " .. entry.classid .. ")")
        end
    end
end

local function addMetadataSpacer(container, height)
    local spacer = UI:Create("Spacer")
    spacer:SetHeight(height or METADATA_SECTION_GAP)
    container:AddChild(spacer)
end

local function nudgeWidgetScrollBar(scrollWidget, yOffset)
    local scrollbar = scrollWidget and scrollWidget.scrollbar
    if not (scrollbar and scrollbar.GetNumPoints and scrollbar.GetPoint and scrollbar.ClearAllPoints and scrollbar.SetPoint) then return end

    local points = {}
    for pointIndex = 1, scrollbar:GetNumPoints() do
        local point, relativeTo, relativePoint, xOffset, yPointOffset = scrollbar:GetPoint(pointIndex)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOffset = xOffset or 0,
            yOffset = (yPointOffset or 0) - (yOffset or 0)
        }
    end

    scrollbar:ClearAllPoints()
    for _, pointData in ipairs(points) do
        if pointData.relativeTo then
            scrollbar:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.xOffset, pointData.yOffset)
        else
            scrollbar:SetPoint(pointData.point, pointData.xOffset, pointData.yOffset)
        end
    end
end

local function metadataColumn(width, height)
    local column = UI:Create("SimpleGroup")
    column:SetLayout("List")
    column:SetWidth(width)
    if height then column:SetHeight(height) end
    if column.SetListPadding then column:SetListPadding(0, 0, 0, 0) end
    if column.SetListGap then column:SetListGap(0) end
    return column
end

local function metadataHeading(text, width)
    local heading = UI:Create("Heading")
    heading:SetText(text)
    heading:SetWidth(width)
    heading:SetHeight(METADATA_HEADER_HEIGHT)
    disableTextWrap(heading)
    return heading
end

local function metadataVersionAreaHeight(editframe)
    local minHeight =
        (METADATA_HEADER_HEIGHT + 10 + (#pveVersionConfigs * INLINE_ROW_HEIGHT)) +
        METADATA_SECTION_GAP +
        (METADATA_HEADER_HEIGHT + 10 + (#pvpVersionConfigs * INLINE_ROW_HEIGHT))

    return minHeight
end

local function addDependencyWindow(editframe, container, deps, hasDeps, usedBy)
    -- Build dynamic heading: strip "Requires " prefix from labels since we add it once ourselves
    local hasMacros = deps and deps.Macros    and #deps.Macros    > 0
    local hasVars   = deps and deps.Variables and #deps.Variables > 0
    local headingText = T("Dependencies")
    if hasMacros or hasVars then
        local parts = {}
        local function stripRequires(s)
            return (trimDependencyColon(s):gsub("^[Rr]equires%s+", ""))
        end
        if hasMacros then parts[#parts+1] = stripRequires(T("Requires Macros:"))    end
        if hasVars   then parts[#parts+1] = stripRequires(T("Requires Variables:")) end
        headingText = headingText .. " " .. "Required" .. ": " .. table.concat(parts, ", ")
    end
    local depHeading = UI:Create("Label")
    depHeading:SetText(headingText)
    depHeading:SetFullWidth(true)
    if depHeading.SetJustifyV then depHeading:SetJustifyV("BOTTOM") end
    if depHeading.label and depHeading.frame then
        depHeading.label:ClearAllPoints()
        depHeading.label:SetPoint("TOPLEFT", depHeading.frame, "TOPLEFT", 2, 0)
        depHeading.label:SetPoint("BOTTOMRIGHT", depHeading.frame, "BOTTOMRIGHT", 0, 0)
    end
    disableTextWrap(depHeading)
    container:AddChild(depHeading)

    local dependencyBox = UI:Create("InlineGroup")
    dependencyBox:SetTitle(" ")
    dependencyBox:SetFullWidth(true)
    dependencyBox:SetHeight(DEPENDENCY_WINDOW_HEIGHT)
    dependencyBox:SetLayout("Fill")
    if dependencyBox.SetListPadding then dependencyBox:SetListPadding(0, 0, 0, 0) end
    if dependencyBox.title then dependencyBox.title:SetText("") end
    applyDependencyHeader(dependencyBox)

    local dependencyScroll = UI:Create("ScrollFrame")
    dependencyScroll:SetFullWidth(true)
    dependencyScroll:SetFullHeight(true)
    dependencyScroll:SetLayout("List")
    if dependencyScroll.SetScrollBarEnabled then dependencyScroll:SetScrollBarEnabled(true) end
    if dependencyScroll.SetListPadding then dependencyScroll:SetListPadding(2, DEPENDENCY_DATA_TOP_PADDING, 4, 2) end
    if dependencyScroll.SetListGap then dependencyScroll:SetListGap(0) end
    nudgeWidgetScrollBar(dependencyScroll, 3)

    addDependencyLabels(editframe, dependencyScroll, deps, hasDeps, usedBy, false)

    dependencyBox:AddChild(dependencyScroll)
    container:AddChild(dependencyBox)
end

local function currentConfigSubTab(editframe)
    -- A tab click belongs to the sequence it was made on. Without this the
    -- first Config click would stick for every sequence opened afterwards and
    -- the notes default below would fire exactly once per editor session.
    if editframe.ConfigurationSubTabFor ~= editframe.OrigSequenceName then
        editframe.ConfigurationSubTabFor = editframe.OrigSequenceName
        editframe.ConfigurationSubTab = nil
    end
    local tab = editframe.ConfigurationSubTab
    -- A sequence installed from gse.tools opens ON its notes: they are the
    -- author's documentation for it, and they are read-only here, so the
    -- config form is the wrong first screen. An explicit click still wins --
    -- this only decides where a freshly selected sequence lands.
    if tab == nil and markdownNotesText(editframe.Sequence) then tab = "notes" end
    if tab ~= "notes" then tab = "metadata" end
    editframe.ConfigurationSubTab = tab
    return tab
end

local function redrawConfigurationSubTab(editframe, container, tab)
    if currentConfigSubTab(editframe) == tab then return end
    editframe.ConfigurationSubTab = tab

    local function redraw()
        if not container or not container.ReleaseChildren then return end
        container:ReleaseChildren()
        GUIDrawMetadataEditor(editframe, container)
        if container.DoLayout then container:DoLayout() end
    end

    C_Timer.After(0, redraw)
end

local function addConfigurationTabs(editframe, container)
    local activeTab = currentConfigSubTab(editframe)
    local tabRow = UI:Create("SimpleGroup")
    tabRow:SetLayout("Flow")
    tabRow:SetFullWidth(true)
    tabRow:SetHeight(CONFIG_TAB_ROW_HEIGHT)
    if tabRow.SetFlowGap then tabRow:SetFlowGap(CONFIG_TAB_GAP) end
    if tabRow.SetFlowPadding then tabRow:SetFlowPadding(0, 0, 0, 0) end

    local tabs = {
        {id = "metadata", text = T("Config")},
        {id = "notes", text = T("Notes")}
    }

    for _, tab in ipairs(tabs) do
        local button = UI:Create("PanelTabButton")
        button:SetText(tab.text)
        button:SetWidth(CONFIG_TAB_BUTTON_WIDTH)
        button:SetHeight(CONFIG_TAB_BUTTON_HEIGHT)
        if button.SetElvUIBackgroundShown then button:SetElvUIBackgroundShown(false) end
        if button.SetSelected then button:SetSelected(activeTab == tab.id) end
        button:SetCallback("OnClick", function()
            redrawConfigurationSubTab(editframe, container, tab.id)
        end)
        tabRow:AddChild(button)
    end

    container:AddChild(tabRow)
end

local function addSequenceNameEditor(editframe, container)
    local nameeditbox = UI:Create("EditBox")
    nameeditbox:SetLabel(T("Sequence Name"))
    setEditBoxLabelGap(nameeditbox, 2)
    nameeditbox:SetWidth(math.min(320, math.max(220, math.floor(metadataContentWidth(editframe, container) / 2))))
    nameeditbox:DisableButton(true)
    nameeditbox:SetText(editframe.SequenceName or editframe.OrigSequenceName or "")
    nameeditbox:SetCallback("OnTextChanged", function()
        local sequenceName = nameeditbox:GetText() or ""
        if GSE.UnEscapeString then
            sequenceName = GSE.UnEscapeString(sequenceName)
        end
        editframe.SequenceName = sequenceName
        editframe.newname = sequenceName ~= (editframe.OrigSequenceName or "")
    end)
    nameeditbox:SetCallback("OnEnter", function()
        GSE.CreateToolTip(
            T("Sequence Name"),
            T(
                "The name of your sequence.  This name has to be unique and can only be used for one object.\nYou can copy this entire sequence by changing the name and choosing Save."
            ),
            editframe
        )
    end)
    nameeditbox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    editframe.nameeditbox = nameeditbox
    container:AddChild(nameeditbox)
end

local function addAuthorEditor(editframe, container)
    local authoreditbox = UI:Create("EditBox")
    authoreditbox:SetLabel(T("Author"))
    setEditBoxLabelGap(authoreditbox, 2)
    authoreditbox:SetWidth(math.min(320, math.max(220, math.floor(metadataContentWidth(editframe, container) / 2))))
    authoreditbox:DisableButton(true)
    authoreditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(T("Author"), T("The author of this sequence."), editframe)
        end
    )
    authoreditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    if not GSE.isEmpty(editframe.Sequence.MetaData.Author) then
        authoreditbox:SetText(editframe.Sequence.MetaData.Author)
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Author = key
        end
    )
    container:AddChild(authoreditbox)
end

local function addHelpLinkEditor(editframe, container)
    local helplinkeditbox = UI:Create("EditBox")
    helplinkeditbox:SetLabel(T("Help Link"))
    setEditBoxLabelGap(helplinkeditbox, 2)
    helplinkeditbox:SetWidth(math.min(320, math.max(220, math.floor(metadataContentWidth(editframe, container) / 2))))
    helplinkeditbox:DisableButton(true)
    helplinkeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                T("Help Link"),
                T("Website or forum URL where a player can get more information or ask questions about this sequence."),
                editframe
            )
        end
    )
    helplinkeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if GSE.isEmpty(editframe.Sequence.MetaData.Helplink) then
        editframe.Sequence.MetaData.Helplink = "https://discord.gg/gseunited"
    end
    helplinkeditbox:SetText(editframe.Sequence.MetaData.Helplink)
    helplinkeditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Helplink = key
        end
    )
    container:AddChild(helplinkeditbox)
end

-- gse.tools keeps the author's notes as markdown in MetaData.Notes and renders
-- them to WoW escape sequences into MetaData.Help on every write. So Notes
-- means "this text came from the website" and Help is the rendering to show.
-- Returns the text to render, or nil when the sequence has no website notes.
--
-- This is also why the box is read-only in that case: an in-game edit only
-- changes Help, the server rebuilds Help from the untouched Notes on the next
-- sync, and the typing is silently discarded. Better to not offer the field.
function markdownNotesText(sequence)
    local meta = sequence and sequence.MetaData
    if not meta or GSE.isEmpty(meta.Notes) then return nil end
    -- Help is the rendering; fall back to the markdown source if a record ever
    -- arrives without one so the notes are still readable, just unformatted.
    if not GSE.isEmpty(meta.Help) then return meta.Help end
    return meta.Notes
end

-- Read-only rendered notes. The text is already WoW escape sequences, so a
-- FontString shows the author's headings, emphasis and links as formatting --
-- an EditBox would print the raw |cFFffff00... codes, which is the whole
-- reason this replaces the editable box rather than just disabling it.
--
-- The label is given an explicit width BEFORE its text: Label:SetText measures
-- GetStringHeight at the frame's current width, and the list layout reads that
-- height back rather than re-measuring, so a full-width label would be sized
-- for the placeholder width and clip its last lines.
-- `label` is the field name; the read-only hint is appended here so the three
-- editors that show notes cannot drift apart on wording or colour.
local function addRenderedNotesPanel(container, label, text, options)
    local gap        = (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    local boxHeight  = (options and options.height) or NOTES_RENDERED_HEIGHT
    local width      = options and options.width or 0
    if width <= 0 then
        width = container and container.frame and container.frame.GetWidth and container.frame:GetWidth() or 0
    end
    width = math.max(120, width - NOTES_RENDERED_SIDE_ALLOWANCE)

    local wrapper = UI:Create("SimpleGroup")
    wrapper:SetLayout("List")
    wrapper:SetFullWidth(true)
    if wrapper.SetListPadding then wrapper:SetListPadding(0, 0, 0, 0) end
    if wrapper.SetListGap     then wrapper:SetListGap(gap) end

    if not GSE.isEmpty(label) then
        local headingLabel = UI:Create("Label")
        headingLabel:SetText(
            label .. "   " .. NOTES_READONLY_HINT_COLOUR ..
                T("Read only - these notes are edited on gse.tools") .. Statics.StringReset
        )
        headingLabel:SetFullWidth(true)
        if headingLabel.SetFontObject then headingLabel:SetFontObject(GameFontNormalSmall) end
        if headingLabel.SetHeight then headingLabel:SetHeight(20) end
        if headingLabel.SetJustifyV then headingLabel:SetJustifyV("BOTTOM") end
        if headingLabel.label and headingLabel.frame then
            headingLabel.label:ClearAllPoints()
            headingLabel.label:SetPoint("TOPLEFT",     headingLabel.frame, "TOPLEFT",     2, 0)
            headingLabel.label:SetPoint("BOTTOMRIGHT", headingLabel.frame, "BOTTOMRIGHT", 0, 0)
        end
        disableTextWrap(headingLabel)
        wrapper:AddChild(headingLabel)
    end

    local box = UI:Create("InlineGroup")
    box:SetTitle(" ")
    box:SetFullWidth(true)
    box:SetHeight(boxHeight)
    box:SetLayout("Fill")
    if box.title then box.title:SetText("") end
    if box.SetListPadding then box:SetListPadding(0, 0, 0, 0) end

    local scroll = UI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("List")
    if scroll.SetScrollBarEnabled then scroll:SetScrollBarEnabled(true) end
    if scroll.SetListPadding then scroll:SetListPadding(6, 6, 6, 6) end
    if scroll.SetListGap then scroll:SetListGap(0) end
    nudgeWidgetScrollBar(scroll, 3)

    local body = UI:Create("Label")
    if body.SetFontObject then body:SetFontObject(GameFontHighlight) end
    body:SetWidth(width)
    body:SetText(text)
    scroll:AddChild(body)

    box:AddChild(scroll)
    wrapper:AddChild(box)
    container:AddChild(wrapper)
    return wrapper
end

local function addHelpInformationEditor(editframe, container)
    local rendered = markdownNotesText(editframe.Sequence)
    if rendered then
        addRenderedNotesPanel(
            container,
            T("Help Information"),
            rendered,
            {width = metadataContentWidth(editframe, container)}
        )
        return
    end

    local helpeditbox = UI:Create("MultiLineEditBox")
    helpeditbox:SetLabel(T("Help Information"))
    helpeditbox:SetWidth(FIELD_WIDTH)
    helpeditbox:DisableButton(true)
    helpeditbox:SetNumLines(NOTES_HELP_LINES)
    helpeditbox:SetFullWidth(true)
    helpeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                T("Help Information"),
                T("Notes and help on how this sequence works.  What things to remember.  This information is shown in the sequence browser."),
                editframe
            )
        end
    )
    helpeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if not GSE.isEmpty(editframe.Sequence.MetaData.Help) then
        helpeditbox:SetText(editframe.Sequence.MetaData.Help)
    end
    helpeditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Help = key
        end
    )
    container:AddChild(helpeditbox)
end

local function drawNotesTab(editframe, container)
    addSequenceNameEditor(editframe, container)

    local spacer = UI:Create("Spacer")
    spacer:SetHeight(8)
    container:AddChild(spacer)

    addHelpInformationEditor(editframe, container)

    spacer = UI:Create("Spacer")
    spacer:SetHeight(8)
    container:AddChild(spacer)

    addAuthorEditor(editframe, container)
    addHelpLinkEditor(editframe, container)
end

local function drawMetadataTab(editframe, container)
    -- Default frame size = 700 w x 500 h
    local fieldWidth = formFieldWidth(editframe, container)
    local dropdownWidth = fieldWidth + DROPDOWN_VISUAL_WIDTH_OFFSET
    local contentWidth = metadataContentWidth(editframe, container)
    local labelWidth = math.min(
        METADATA_SINGLE_COLUMN_LABEL_WIDTH,
        math.max(METADATA_LABEL_WIDTH, contentWidth - dropdownWidth - FIELD_COLUMN_EXTRA_WIDTH - 12)
    )
    local columnExtraWidth = FIELD_COLUMN_EXTRA_WIDTH
    local fieldColumnWidth = labelWidth + 8 + dropdownWidth + columnExtraWidth
    local versionAreaHeight = metadataVersionAreaHeight(editframe)

    local disableSequence = UI:Create("CheckBox")
    disableSequence:SetLabel(T("Disable Sequence"))
    disableSequence:SetWidth(170)
    disableSequence:SetHeight(24)
    disableSequence:SetValue(editframe.Sequence.MetaData.Disabled)
    disableSequence:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Disabled = key
        end
    )
    disableSequence:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(T("Disable Sequence"), T("Do not compile this Sequence at startup."), editframe)
        end
    )
    disableSequence:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local speciddropdown = UI:Create("Dropdown")
    speciddropdown:SetLabel(T("Specialization/Class ID"))
    speciddropdown:SetWidth(dropdownWidth)
    if speciddropdown.SetDropdownStyle then speciddropdown:SetDropdownStyle(true) end
    speciddropdown:SetList(GSE.GetSpecNames())
    speciddropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            local sid = Statics.SpecIDHashList[key]
            editframe.Sequence.MetaData.SpecID = sid

            if tonumber(sid) > 12 then
                editframe.ClassID = GSE.GetClassIDforSpec(tonumber(sid))
            else
                editframe.ClassID = tonumber(sid)
            end
        end
    )
    speciddropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                T("Specialization/Class ID"),
                T("What class or spec is this sequence for?  If it is for all classes choose Global."),
                editframe
            )
        end
    )
    speciddropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    speciddropdown:SetValue(Statics.SpecIDList[editframe.Sequence.MetaData.SpecID])

    local disableRow = UI:Create("SimpleGroup")
    disableRow:SetLayout("Flow")
    disableRow:SetFullWidth(true)
    disableRow:SetHeight(INLINE_ROW_HEIGHT)
    if disableRow.SetFlowPadding then disableRow:SetFlowPadding(0, 2, 0, 0) end
    if disableRow.SetFlowVAlign then disableRow:SetFlowVAlign("CENTER") end
    disableRow:AddChild(disableSequence)
    container:AddChild(disableRow)
    addMetadataSpacer(container, 4)

    local specColumn = metadataColumn(fieldColumnWidth, INLINE_ROW_HEIGHT)
    specColumn:AddChild(inlineFieldRow(T("Specialization/Class ID"), speciddropdown, labelWidth))
    if specColumn.SetFlowOffset then specColumn:SetFlowOffset(METADATA_VERSION_ROW_INDENT, 0) end
    container:AddChild(specColumn)
    addMetadataSpacer(container, 4)

    local defaultdropdown = UI:Create("Dropdown")
    defaultdropdown:SetLabel(T("Default Version"))
    defaultdropdown:SetWidth(dropdownWidth)
    if defaultdropdown.SetDropdownStyle then defaultdropdown:SetDropdownStyle(true) end

    defaultdropdown:SetList(editframe.GetVersionList())
    defaultdropdown:SetValue(tostring(editframe.Sequence.MetaData.Default))
    defaultdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Default = tonumber(key)
        end
    )
    defaultdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                T("Default Version"),
                T("The version of this sequence that will be used where no other version has been configured."),
                editframe
            )
        end
    )
    defaultdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    local defaultColumn = metadataColumn(fieldColumnWidth, INLINE_ROW_HEIGHT)
    defaultColumn:AddChild(inlineFieldRow(T("Default Version"), defaultdropdown, labelWidth))
    if defaultColumn.SetFlowOffset then defaultColumn:SetFlowOffset(METADATA_VERSION_ROW_INDENT, 0) end
    container:AddChild(defaultColumn)
    addMetadataSpacer(container, METADATA_SECTION_GAP)

    local function versionDropdown(cfg)
        local dd = UI:Create("Dropdown")
        dd:SetLabel(cfg.label)
        dd:SetWidth(dropdownWidth)
        if dd.SetDropdownStyle then dd:SetDropdownStyle(true) end
        dd:SetList(editframe.GetVersionList())
        dd:SetValue(versionValue(editframe.Sequence.MetaData, cfg.key))
        local metaKey = cfg.key
        dd:SetCallback(
            "OnValueChanged",
            function(obj, event, key)
                if editframe.Sequence.MetaData.Default == tonumber(key) then
                    editframe.Sequence.MetaData[metaKey] = nil
                else
                    editframe.Sequence.MetaData[metaKey] = tonumber(key)
                    -- PVP also mirrors editframe.PVP (original behaviour)
                    if metaKey == "PVP" then
                        editframe.PVP = tonumber(key)
                    end
                end
            end
        )
        dd:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(cfg.label, cfg.tip, editframe)
            end
        )
        dd:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        local row = inlineFieldRow(cfg.label, dd, labelWidth)
        if row.SetFlowOffset then row:SetFlowOffset(METADATA_VERSION_ROW_INDENT, 0) end
        return row
    end

    local versionColumn = metadataColumn(fieldColumnWidth, versionAreaHeight)
    versionColumn:AddChild(metadataHeading(T("PvE"), fieldColumnWidth))
    addMetadataSpacer(versionColumn, 10)
    for _, cfg in ipairs(pveVersionConfigs) do
        versionColumn:AddChild(versionDropdown(cfg))
    end

    addMetadataSpacer(versionColumn, METADATA_SECTION_GAP)
    versionColumn:AddChild(metadataHeading(T("PvP"), fieldColumnWidth))
    addMetadataSpacer(versionColumn, 10)
    for _, cfg in ipairs(pvpVersionConfigs) do
        versionColumn:AddChild(versionDropdown(cfg))
    end

    container:AddChild(versionColumn)

    local deps, hasDeps, usedBy = dependencyData(editframe)
    addMetadataSpacer(container, METADATA_SECTION_GAP)
    addDependencyWindow(editframe, container, deps, hasDeps, usedBy)
end

GUIDrawMetadataEditor = function(editframe, container)
    -- Re-apply padding each render (covers tab switching via redrawConfigurationSubTab)
    if container.SetListPadding then container:SetListPadding(CONFIG_CONTENT_LEFT_PADDING, 15, CONFIG_CONTENT_LEFT_PADDING, CONFIG_CONTENT_LEFT_PADDING) end
    addConfigurationTabs(editframe, container)

    local spacer = UI:Create("Spacer")
    spacer:SetHeight(4)
    container:AddChild(spacer)

    if currentConfigSubTab(editframe) == "metadata" then
        drawMetadataTab(editframe, container)
    else
        drawNotesTab(editframe, container)
    end
end

function GSE.GUI.SetupMetadata(editframe)
    editframe.GUIDrawMetadataEditor = function(container)
        GUIDrawMetadataEditor(editframe, container)
    end
end

-- Shared: the read-only rendered notes panel, for the macro and variable
-- editors. `text` must already be WoW escape sequences (the server renders the
-- markdown: MetaData.Notes -> MetaData.Help for sequences, comments ->
-- commentsHelp for macros and variables).
function GSE.GUI.CreateReadOnlyNotesPanel(container, label, text, options)
    return addRenderedNotesPanel(container, label, text, options)
end

-- Shared: lets Editor_Variable (and others) build the same styled dependency box.
-- rows = list of {name, depType, author, updated} tables.
-- heading = string already built by caller.
function GSE.GUI.CreateDependencyWindow(container, heading, rows, options)
    local hideAuthor = options and options.hideAuthor
    local hideType   = options and options.hideType
    local gap        = (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    -- Shorter default than the metadata window so it doesn't overrun the bottom
    -- of the editor frame. Sized for the column header + ~3 rows; scrolls beyond.
    local boxHeight  = (options and options.height) or 86
    -- Optional right inset so callers can align the panel with boxes above that
    -- reserve a scrollbar gutter (e.g. the macro page's editable boxes).
    local rightInset = options and options.rightInset

    -- Wrapper keeps heading flush against the box regardless of parent listGap
    local wrapper = UI:Create("SimpleGroup")
    wrapper:SetLayout("List")
    wrapper:SetFullWidth(true)
    if wrapper.SetListPadding then wrapper:SetListPadding(0, 0, 0, 0) end
    if wrapper.SetListGap     then wrapper:SetListGap(gap) end
    if rightInset and wrapper.SetListRightInset then wrapper:SetListRightInset(rightInset) end

    local depLabel = UI:Create("Label")
    depLabel:SetText(heading)
    depLabel:SetFullWidth(true)
    if depLabel.SetFontObject then depLabel:SetFontObject(GameFontNormal) end
    if depLabel.SetHeight then depLabel:SetHeight(20) end
    if depLabel.SetJustifyV then depLabel:SetJustifyV("BOTTOM") end
    if depLabel.label and depLabel.frame then
        depLabel.label:ClearAllPoints()
        depLabel.label:SetPoint("TOPLEFT",     depLabel.frame, "TOPLEFT",     2, 0)
        depLabel.label:SetPoint("BOTTOMRIGHT", depLabel.frame, "BOTTOMRIGHT", 0, 0)
    end
    disableTextWrap(depLabel)
    wrapper:AddChild(depLabel)

    local depBox = UI:Create("InlineGroup")
    depBox:SetTitle(" ")
    depBox:SetFullWidth(true)
    depBox:SetHeight(boxHeight)
    depBox:SetLayout("Fill")
    if depBox.title then depBox.title:SetText("") end
    if depBox.SetListPadding then depBox:SetListPadding(0, 0, 0, 0) end
    applyDependencyHeader(depBox, hideAuthor, hideType)

    local depScroll = UI:Create("ScrollFrame")
    depScroll:SetFullWidth(true)
    depScroll:SetFullHeight(true)
    depScroll:SetLayout("List")
    if depScroll.SetScrollBarEnabled then depScroll:SetScrollBarEnabled(true) end
    if depScroll.SetListPadding then depScroll:SetListPadding(2, DEPENDENCY_DATA_TOP_PADDING, 4, 2) end
    if depScroll.SetListGap then depScroll:SetListGap(0) end
    nudgeWidgetScrollBar(depScroll, 3)

    for _, row in ipairs(rows) do
        addDependencyRow(depScroll, row.name, row.depType, row.author or "", row.updated or "", hideAuthor, hideType)
    end

    depBox:AddChild(depScroll)
    wrapper:AddChild(depBox)
    container:AddChild(wrapper)
end
end
table.insert(ns.deferred, setup)

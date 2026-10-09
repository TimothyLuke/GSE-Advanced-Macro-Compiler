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
-- Three rows: box chrome 24 (scroll inset 14 top, 10 bottom, measured) + data
-- top padding 12 + 3 x 16-high rows + 2 bottom padding. Scrolls beyond that;
-- the same height as the macro and variable pages' Used by Sequences box.
local DEPENDENCY_WINDOW_HEIGHT = 86
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
-- The header block (Author / Help Link / Notes): label beside a fixed box.
local HEADER_ROW_HEIGHT = 26
local HEADER_LABEL_WIDTH = 70
local HEADER_FIELD_WIDTH = 360
-- Gap between the two columns (Specialization / Disable Sequence, PvE / PvP).
local METADATA_COLUMN_GAP = 24
-- The drag icon's slot under PvP: at least this tall.
local DRAG_SLOT_MIN_HEIGHT = 150
-- Narrowest a version dropdown may shrink to keep PvE and PvP side by side.
local MIN_COLUMN_DROPDOWN_WIDTH = 130
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
    if GSE.isEmpty(GSE.Store("variable")) or GSE.isEmpty(GSE.Store("variable")[name]) then return nil end

    local stored = GSE.Store("variable")[name]
    if type(stored) == "table" then return stored end
    if not GSE.DecodeMessage then return nil end

    local ok, success, decoded = pcall(function() return GSE.DecodeMessage(stored) end)
    if ok and success and type(decoded) == "table" then return decoded end
    return nil
end

local function isStoredMacroNode(node)
    return GSE.IsStoredMacroNode(node)
end

local function currentCharacterMacroBucket()
    return GSE.CharacterMacroBucketKey and GSE.CharacterMacroBucketKey() or nil
end

local function storedMacroInfo(name)
    if GSE.isEmpty(GSE.Store("macro")) then return nil end
    if isStoredMacroNode(GSE.Store("macro")[name]) then return GSE.Store("macro")[name] end

    local currentBucket = currentCharacterMacroBucket()
    if currentBucket and type(GSE.Store("macro")[currentBucket]) == "table" and isStoredMacroNode(GSE.Store("macro")[currentBucket][name]) then
        return GSE.Store("macro")[currentBucket][name]
    end

    for _, bucket in pairs(GSE.Store("macro")) do
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

-- The version rows are NOT listed here any more. They are built from
-- GSE.GetContextVersionDisplay(), which is derived from the same key list the
-- runtime resolves against, because the hand-maintained table this replaced had
-- drifted away from it: it offered a PVESolo row for a context GSE does not
-- have, and had no row at all for Mythic, Heroic or Party, which GSE does
-- honour. A sequence carrying one of those was unreadable and uneditable here,
-- and refused to let its version be deleted while naming a row that was not on
-- the screen (#2023). Labels come from the same place, so the row you are told
-- to change is the row you can see.
local pveVersionConfigs, pvpVersionConfigs = {}, {}
for _, entry in ipairs(GSE.GetContextVersionDisplay()) do
    local cfg = {key = entry.key, label = T(entry.label), tip = T(entry.tip)}
    table.insert(entry.section == "PVP" and pvpVersionConfigs or pveVersionConfigs, cfg)
end

-- Widest of the metadata row labels in the Label widget's font (GameFontNormal),
-- so a narrow page can shrink the label column without wrapping a label.
local labelProbe
local function longestLabelWidth()
    labelProbe = labelProbe or UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelProbe:SetFont(GameFontNormal:GetFont())
    local widest = 0
    local function measure(text)
        labelProbe:SetText(text)
        widest = math.max(widest, labelProbe:GetStringWidth() or 0)
    end
    measure(T("Specialization/Class ID"))
    measure(T("Default Version"))
    for _, cfg in ipairs(pveVersionConfigs) do measure(cfg.label) end
    for _, cfg in ipairs(pvpVersionConfigs) do measure(cfg.label) end
    return math.ceil(widest) + 6
end

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
    local usedBy = GSE.GetSequenceDependents(editframe.SequenceID or editframe.SequenceName) or {}
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
                -- An Embed names what it embeds; any class will do.
                local exists = GSE.FindSequenceId(sname, nil, true) ~= nil
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
        local point, relativeTo, relativePoint, pointXOffset, yPointOffset = scrollbar:GetPoint(pointIndex)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOffset = pointXOffset or 0,
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

-- PvE | PvP rows' width watchers (ours, not pooled), one per row frame.
local versionRowWatchers = setmetatable({}, {__mode = "k"})
-- PvE | PvP side by side in one full-width row, each column half of the row's
-- real width (the container stretches after layout, so a width worked out
-- while drawing comes out short). Below minWidth the columns keep minWidth and
-- the Flow wraps the second under the first. onSplit(columnWidth), when
-- given, runs after each split. Returns a function that splits the row at its
-- current width.
local function addVersionColumns(container, leftColumn, rightColumn, minWidth, onSplit)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    if row.SetFlowGap then row:SetFlowGap(METADATA_COLUMN_GAP) end
    if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
    row:AddChild(leftColumn)
    row:AddChild(rightColumn)
    container:AddChild(row)

    local lastWidth
    local function split(rowWidth)
        if not (rowWidth and rowWidth > 0) then return end
        local width = math.max(minWidth, math.floor((rowWidth - METADATA_COLUMN_GAP) / 2))
        if width == lastWidth then return end
        lastWidth = width
        leftColumn:SetWidth(width)
        rightColumn:SetWidth(width)
        if onSplit then onSplit(width) end
        -- SetWidth re-lays only the row. If the first pass wrapped PvP under
        -- PvE, the page still holds that taller row and leaves a gap below it.
        if row.parent and row.parent.DoLayout then row.parent:DoLayout() end
    end
    local watcher = versionRowWatchers[row.frame]
    if not watcher then
        watcher = CreateFrame("Frame")
        versionRowWatchers[row.frame] = watcher
    end
    watcher:SetParent(row.frame)
    watcher:ClearAllPoints()
    watcher:SetAllPoints(row.frame)
    watcher:SetScript("OnSizeChanged", function(_, w) split(w) end)
    row:SetCallback("OnRelease", function()
        watcher:SetScript("OnSizeChanged", nil)
        watcher:ClearAllPoints()
        watcher:SetParent(UIParent)
    end)
    return function() split(row.frame:GetWidth()) end
end

-- The width a column's version dropdown comes out at: its row is the column
-- less the row indent, and the dropdown fills that after its label and the
-- row's 8 gap. The centred rows above use it so all the dropdowns match.
local function columnDropdownWidth(columnWidth, labelWidth)
    return math.max(MIN_COLUMN_DROPDOWN_WIDTH, columnWidth - METADATA_VERSION_ROW_INDENT - labelWidth - 8)
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
    -- No scrollbar: the box holds three rows; the mouse wheel scrolls past that.
    if dependencyScroll.SetScrollBarEnabled then dependencyScroll:SetScrollBarEnabled(false) end
    if dependencyScroll.SetListPadding then dependencyScroll:SetListPadding(2, DEPENDENCY_DATA_TOP_PADDING, 4, 2) end
    if dependencyScroll.SetListGap then dependencyScroll:SetListGap(0) end

    addDependencyLabels(editframe, dependencyScroll, deps, hasDeps, usedBy, false)

    dependencyBox:AddChild(dependencyScroll)
    container:AddChild(dependencyBox)
    return dependencyBox
end

-- The sequence's icon, top right of the Config tab row. Dragging it onto any
-- action button puts the sequence on that button (GSE.BeginSequenceDrag in
-- GSE/API/Events.lua). One frame, reused: it is re-parented onto each tab row
-- and taken back off when the row is released, so it never rides along on a
-- recycled widget.
local DRAG_ICON_SIZE = 28
-- "DRAG ME!" badge on the big icon: text padding, and how far its bottom
-- hangs below the icon's bottom edge.
local DRAG_BADGE_PAD_X = 7
local DRAG_BADGE_PAD_Y = 4
local DRAG_BADGE_DROP = 1
local sequenceDragIcon
local sequenceDragArea

-- Blizzard's action button art (ActionButtonTemplate on Retail, Forever and
-- Classic Era): a 45x45 icon under a 46x45 frame and mouseover glow anchored
-- TOPLEFT, with the icon masked to the frame's rounded corners. Scaled here to
-- whatever size the icon is drawn at. A client without the atlas shows the
-- plain icon.
local BUTTON_ART_SIZE, BUTTON_ART_FRAME_WIDTH = 45, 46
-- The icon mask is 64x64 centred on the 45x45 icon (measured on Forever's
-- ActionButton1); sized to the icon instead, its transparent margin shrank the
-- icon and left a dark ring inside the frame.
local BUTTON_ART_MASK_SIZE = 64
local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Once the sequence is on an action button, the icon mirrors that button: its
-- frame and skin (whatever bar addon or skin drew it), its icon as it changes
-- while the sequence runs, its proportions, and its key label. Each piece is
-- copied from the matching piece of the bar button and scaled to the icon's
-- size; anchors to the bar button (or its text overlay) become anchors to the
-- icon, anchors to the bar button's icon become anchors to ours.
-- Only a button actually drawing the sequence counts: an override can point at
-- a slot that shows nothing (an empty slot whose icon is hidden, seen on
-- Forever), and mirroring that drew an empty frame.
local function barButtonFor(id)
    for name, seq in pairs(GSE.ButtonOverrides or {}) do
        local b = seq == id and _G[name]
        if b and b.icon and b:IsVisible() and b.icon:IsShown() and b.icon:GetTexture() then return b end
    end
end

local KEY_NUDGE_X = 2
local function barHotKey(b)
    return (b.TextOverlayContainer and b.TextOverlayContainer.HotKey) or b.HotKey
end

local function copyTextureLook(dst, src)
    local atlas = src.GetAtlas and src:GetAtlas()
    if atlas then dst:SetAtlas(atlas) else dst:SetTexture(src:GetTexture()) end
    dst:SetTexCoord(src:GetTexCoord())
    dst:SetVertexColor(src:GetVertexColor())
    dst:SetAlpha(src:GetAlpha())
    if src.GetBlendMode then dst:SetBlendMode(src:GetBlendMode()) end
end

local function placeLike(dst, src, b, scale)
    dst:ClearAllPoints()
    local n = src.GetNumPoints and src:GetNumPoints() or 0
    for i = 1, n do
        local point, rel, relPoint, x, y = src:GetPoint(i)
        local target = (rel == b.icon) and sequenceDragIcon.texture or sequenceDragIcon
        dst:SetPoint(point, target, relPoint, (x or 0) * scale, (y or 0) * scale)
    end
    if n == 0 then dst:SetPoint("CENTER") end
    if n < 2 and dst.SetSize then dst:SetSize(src:GetWidth() * scale, src:GetHeight() * scale) end
end

local function setIconMask(on)
    local icon, mask = sequenceDragIcon, sequenceDragIcon.mask
    if not mask or icon.maskOn == on then return end
    if on then icon.texture:AddMaskTexture(mask) else icon.texture:RemoveMaskTexture(mask) end
    icon.maskOn = on
end

local function mirrorHotKey(b, scale)
    local hk, mine = barHotKey(b), sequenceDragIcon.hotKey
    local text = hk and hk:IsShown() and hk:GetText()
    if not text or text == "" or text == RANGE_INDICATOR then mine:Hide() return end
    local file, fontSize, flags = hk:GetFont()
    if file then mine:SetFont(file, math.max(8, (fontSize or 10) * scale), flags or "") end
    mine:SetTextColor(hk:GetTextColor())
    mine:SetJustifyH(hk:GetJustifyH())
    mine:SetText(text)
    mine:SetSize(0, 0) -- sized to its text
    -- Place the drawn glyph, not the label's box: on the bar the box (10px tall
    -- for a 12pt font) is not where the key is drawn. Measure the glyph's right
    -- and top edges from the live bar button's corner and scale those gaps.
    local bRight, bTop = b:GetRight(), b:GetTop()
    local left, right, top, bottom = hk:GetLeft(), hk:GetRight(), hk:GetTop(), hk:GetBottom()
    mine:ClearAllPoints()
    if bRight and bTop and left and right and top and bottom then
        local sw, sh = hk:GetStringWidth() or 0, hk:GetStringHeight() or 0
        local jh, jv = hk:GetJustifyH(), hk:GetJustifyV()
        local glyphRight = (jh == "LEFT" and left + sw) or (jh == "CENTER" and (left + right + sw) / 2) or right
        local glyphTop = (jv == "TOP" and top) or (jv == "BOTTOM" and bottom + sh) or ((top + bottom + sh) / 2)
        -- KEY_NUDGE_X: a visual nudge on top of the measured gap, set by eye.
        mine:SetPoint("TOPRIGHT", sequenceDragIcon, "TOPRIGHT",
            -(bRight - glyphRight) * scale - KEY_NUDGE_X, -(bTop - glyphTop) * scale)
    else
        placeLike(mine, hk, b, scale)
        mine:SetSize(0, 0)
    end
    mine:Show()
end

-- Blizzard's default look, for a sequence not on any button yet.
local function applyDefaultLook(size)
    local icon = sequenceDragIcon
    icon:SetSize(size, size)
    icon.texture:SetTexCoord(0, 1, 0, 1)
    if icon.mask then
        icon.mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
        icon.mask:ClearAllPoints()
        icon.mask:SetPoint("CENTER", icon.texture, "CENTER")
        local maskSize = size * BUTTON_ART_MASK_SIZE / BUTTON_ART_SIZE
        icon.mask:SetSize(maskSize, maskSize)
        setIconMask(true)
    end
    local frameWidth = size * BUTTON_ART_FRAME_WIDTH / BUTTON_ART_SIZE
    icon.frameArt:ClearAllPoints()
    icon.glow:ClearAllPoints()
    icon.glow:SetVertexColor(1, 1, 1)
    icon.glow:SetAlpha(1)
    if hasAtlas("UI-HUD-ActionBar-IconFrame") then
        icon.frameArt:SetAtlas("UI-HUD-ActionBar-IconFrame")
        icon.frameArt:SetVertexColor(1, 1, 1)
        icon.frameArt:SetAlpha(1)
        icon.frameArt:SetBlendMode("BLEND")
        icon.frameArt:SetPoint("TOPLEFT")
        icon.frameArt:SetSize(frameWidth, size)
        icon.frameArt:Show()
        icon.glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        icon.glow:SetBlendMode("BLEND")
        icon.glow:SetPoint("TOPLEFT")
        icon.glow:SetSize(frameWidth, size)
    else
        icon.frameArt:Hide()
        icon.glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        icon.glow:SetBlendMode("ADD")
        icon.glow:SetAllPoints()
    end
    icon.hotKey:Hide()
end

local function applyMirrorLook(b, size)
    local icon = sequenceDragIcon
    local bw, bh = b:GetWidth(), b:GetHeight()
    if not (bw and bh and bh > 0) then return false end
    local scale = size / bh
    icon:SetSize(bw * scale, size)
    icon.texture:SetTexture(b.icon:GetTexture())
    icon.texture:SetTexCoord(b.icon:GetTexCoord())
    if icon.mask and b.IconMask then
        -- A mask only takes its shape: no colour, blend or coords to copy.
        local maskAtlas = b.IconMask.GetAtlas and b.IconMask:GetAtlas()
        local maskFile = not maskAtlas and b.IconMask.GetTexture and b.IconMask:GetTexture()
        if maskAtlas then icon.mask:SetAtlas(maskAtlas) elseif maskFile then icon.mask:SetTexture(maskFile) end
        placeLike(icon.mask, b.IconMask, b, scale)
        setIconMask(true)
    else
        setIconMask(false)
    end
    local normal = b.GetNormalTexture and b:GetNormalTexture()
    if icon.frameArt then
        if normal and normal:IsShown() and (normal:GetAtlas() or normal:GetTexture()) then
            copyTextureLook(icon.frameArt, normal)
            placeLike(icon.frameArt, normal, b, scale)
            icon.frameArt:Show()
        else
            icon.frameArt:Hide()
        end
    end
    local highlight = b.GetHighlightTexture and b:GetHighlightTexture()
    if icon.glow and highlight and (highlight:GetAtlas() or highlight:GetTexture()) then
        copyTextureLook(icon.glow, highlight)
        placeLike(icon.glow, highlight, b, scale)
    end
    mirrorHotKey(b, scale)
    return true
end

-- Live updates from the mirrored button: GSE sets its icon as the sequence
-- steps, and WoW sets its key label when the binding changes. Hooked once per
-- button; only the button currently mirrored is followed.
local hookedBarButtons = {}
local function followBarButton(b)
    if hookedBarButtons[b] then return end
    hookedBarButtons[b] = true
    hooksecurefunc(b.icon, "SetTexture", function(_, texture)
        if sequenceDragIcon.mirrorOf == b then sequenceDragIcon.texture:SetTexture(texture) end
    end)
    local hk = barHotKey(b)
    if hk then
        hooksecurefunc(hk, "SetText", function()
            if sequenceDragIcon.mirrorOf == b then mirrorHotKey(b, sequenceDragIcon:GetHeight() / b:GetHeight()) end
        end)
    end
end

local function setDragIconSize(size)
    local icon = sequenceDragIcon
    icon.lastSize = size
    local b = icon.sequenceId and barButtonFor(icon.sequenceId)
    if b and applyMirrorLook(b, size) then
        icon.mirrorOf = b
        followBarButton(b)
    else
        icon.mirrorOf = nil
        applyDefaultLook(size)
    end
end

-- Every icon the sequence's blocks offer, in every version, in order, as
-- {name, iconID} -- each block's Select Icon choices (GSE.GetActionIconCandidates).
local iconProbe
local function sequenceIconChoices(sequence)
    local choices, seen = {}, {}
    -- One picture arrives as a file ID, a numeric string or a texture path;
    -- compare by the file ID the texture resolves to.
    iconProbe = iconProbe or UIParent:CreateTexture()
    local function add(info)
        local icon = type(info) == "table" and info.iconID
        if not icon or GSE.IsFallbackIcon(icon) then return end
        icon = tonumber(icon) or icon
        iconProbe:SetTexture(icon)
        local key = (iconProbe.GetTextureFileID and iconProbe:GetTextureFileID()) or icon
        if not seen[key] then
            seen[key] = true
            choices[#choices + 1] = {name = info.name or "", iconID = icon}
        end
    end
    local function walk(actions)
        if type(actions) ~= "table" then return end
        for _, action in ipairs(actions) do
            if type(action) == "table" then
                if action.type == "spell" or action.type == "macro" then
                    for _, info in ipairs(GSE.GetActionIconCandidates(action)) do add(info) end
                end
                walk(action)
            end
        end
    end
    for _, version in ipairs(type(sequence) == "table" and sequence.Versions or {}) do
        if type(version) == "table" then walk(version.Actions) end
    end
    return choices
end

-- The icon the drag icon shows: the player's base icon, else the first block's.
local function dragIconTexture(editframe)
    local id = editframe.SequenceID
    return GSE.GetSequenceBaseIcon(id) or GSE.GetSequenceFirstBlockIcon(editframe.Sequence)
        or GSE.GetSequenceStartIcon(id) or Statics.Icons.GSE_Logo_Dark
end

local function attachSequenceDragIcon(editframe, hostRow)
    if not sequenceDragIcon then
        sequenceDragIcon = CreateFrame("Button", nil, UIParent)
        sequenceDragIcon.texture = sequenceDragIcon:CreateTexture(nil, "ARTWORK")
        sequenceDragIcon.texture:SetAllPoints()
        -- The default look needs Blizzard's action button atlases; a mirrored
        -- look copies whatever the bar button has, so the pieces always exist.
        if sequenceDragIcon.CreateMaskTexture and hasAtlas("UI-HUD-ActionBar-IconFrame-Mask") then
            sequenceDragIcon.mask = sequenceDragIcon:CreateMaskTexture()
            sequenceDragIcon.mask:SetAllPoints(sequenceDragIcon.texture)
        end
        sequenceDragIcon.frameArt = sequenceDragIcon:CreateTexture(nil, "OVERLAY")
        sequenceDragIcon.glow = sequenceDragIcon:CreateTexture(nil, "HIGHLIGHT")
        sequenceDragIcon.hotKey = sequenceDragIcon:CreateFontString(nil, "OVERLAY",
            _G.NumberFontNormalSmallGray and "NumberFontNormalSmallGray" or "GameFontNormalSmall")
        sequenceDragIcon.hotKey:SetDrawLayer("OVERLAY", 7)
        sequenceDragIcon.hotKey:Hide()
        -- "DRAG ME!" badge across the bottom edge of the big Config icon
        -- (centreSequenceDragIcon shows it). A child frame so it draws over the
        -- icon's frame art; it takes no mouse, so dragging still grabs the icon.
        -- A thin red line through behind the text, 12 past it each side.
        local badge = CreateFrame("Frame", nil, sequenceDragIcon)
        badge.strip = badge:CreateTexture(nil, "BACKGROUND")
        badge.strip:SetColorTexture(0.45, 0.12, 0.12, 0.6)
        badge.strip:SetPoint("TOP", badge, "CENTER", 0, 0)
        badge.strip:SetPoint("LEFT", badge, "LEFT", -12, 0)
        badge.strip:SetPoint("RIGHT", badge, "RIGHT", 12, 0)
        badge.strip:SetHeight(2)
        badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge.text:SetPoint("CENTER", 0, 0)
        badge.text:SetText(L["DRAG ME!"])
        badge:Hide()
        sequenceDragIcon.dragLabel = badge
        -- Assigning the sequence to a button (drag, or the right-click picker)
        -- changes what the icon mirrors.
        hooksecurefunc(GSE, "CreateActionBarOverride", function()
            C_Timer.After(0, function()
                if sequenceDragIcon:IsShown() and sequenceDragIcon.lastSize then
                    setDragIconSize(sequenceDragIcon.lastSize)
                end
            end)
        end)
        -- Right-click: pick the sequence's base icon from the icons it uses.
        sequenceDragIcon:RegisterForClicks("RightButtonUp")
        sequenceDragIcon:SetScript("OnClick", function(self, button)
            local frame = self.editframe
            local id = frame and frame.SequenceID
            if button ~= "RightButton" or not id then return end
            local function pick(icon)
                GSE.SetSequenceBaseIcon(id, icon)
                self.texture:SetTexture(dragIconTexture(frame))
                if self.lastSize then setDragIconSize(self.lastSize) end
            end
            -- The editor's own icon menu, as on a block's icon (titled "Select Base Icon"),
            -- each spell's icon and name.
            GSE.OpenContextMenu(self, function(_, root)
                root:CreateTitle(L["Select Base Icon"])
                for _, v in ipairs(sequenceIconChoices(frame.Sequence)) do
                    root:CreateButton("|T" .. v.iconID .. ":0|t " .. v.name, function() pick(v.iconID) end)
                end
                -- Any icon at all, through GSE QoL's picker, as on a block's menu.
                if GSE.ShowIconPicker then
                    root:CreateDivider()
                    root:CreateButton(L["Choose any icon..."], function() GSE.ShowIconPicker(pick) end)
                end
            end)
        end)
        sequenceDragIcon:RegisterForDrag("LeftButton")
        sequenceDragIcon:SetScript("OnDragStart", function(self)
            -- The dragged image is whatever this icon shows right now.
            if self.sequenceId then GSE.BeginSequenceDrag(self.sequenceId, self.texture:GetTexture()) end
        end)
        sequenceDragIcon:SetScript("OnDragStop", function()
            GSE.FinishSequenceDrag()
        end)
        -- The editor's own tooltip, placed as every other field's on the page.
        sequenceDragIcon:SetScript("OnEnter", function(self)
            -- DRAG ME! turns red and grows 12% while the mouse is over the icon.
            if self.dragLabel and self.dragLabel.text then
                local face, size, flags = GameFontNormalSmall:GetFont()
                self.dragLabel.text:SetFont(face, size * 1.12, flags or "")
                self.dragLabel.text:SetTextColor(1, 0.2, 0.2)
            end
            GSE.CreateToolTip(L["Put on an Action Button"], (self.sequenceId
                and L["Drag this onto any action button to put the sequence on it. The button's slot must be empty, and you must be out of combat."]
                or L["Only a saved sequence for this character's class can be put on an action button."])
                .. "\n\n" .. L["Right Click to choose No Combat Base Icon"],
                self.editframe)
        end)
        sequenceDragIcon:SetScript("OnLeave", function(self)
            if self.dragLabel and self.dragLabel.text then
                self.dragLabel.text:SetFont(GameFontNormalSmall:GetFont())
                self.dragLabel.text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
            end
            GSE.ClearTooltip(self.editframe)
        end)
    end
    local id = editframe.SequenceID
    -- Draggable only when the sequence has a live button: saved, and of this
    -- character's class.
    local live = id and _G[id] and GSE.SequencesExec and GSE.SequencesExec[id] and true or false
    sequenceDragIcon.sequenceId = live and id or nil
    sequenceDragIcon.editframe = editframe
    -- The first block's icon from the editor's own copy (it carries the icons
    -- the editor filled in; the stored copy may not), else the start icon.
    sequenceDragIcon.texture:SetTexture(dragIconTexture(editframe))
    sequenceDragIcon.texture:SetDesaturated(not live)
    sequenceDragIcon:SetParent(hostRow.frame)
    sequenceDragIcon:SetFrameLevel(hostRow.frame:GetFrameLevel() + 5)
    setDragIconSize(DRAG_ICON_SIZE)
    sequenceDragIcon.dragLabel:Hide()
    sequenceDragIcon:ClearAllPoints()
    sequenceDragIcon:SetPoint("TOPRIGHT", hostRow.frame, "TOPRIGHT", -FORM_SIDE_PADDING, 0)
    sequenceDragIcon:Show()
    hostRow:SetCallback("OnRelease", function()
        sequenceDragIcon:Hide()
        sequenceDragIcon:SetParent(UIParent)
        sequenceDragIcon:ClearAllPoints()
        if sequenceDragArea then sequenceDragArea:ClearAllPoints() end
    end)
end

-- The icon sits centred in its slot under the PvP versions, as big as the slot
-- allows. The area frame (ours, not pooled) covers the slot widget's frame, so
-- it follows the layout and window resizes.
local DRAG_ICON_BIG = 128
local DRAG_ICON_MARGIN = 16
local function centreSequenceDragIcon(slot)
    if not (sequenceDragIcon and slot) then return end
    local function fitIcon(w, h)
        if not (w and h and w > 0 and h > 0) then return end
        local size = math.floor(math.min(DRAG_ICON_BIG, w - DRAG_ICON_MARGIN, h - DRAG_ICON_MARGIN))
        setDragIconSize(math.max(DRAG_ICON_SIZE, size))
    end
    if not sequenceDragArea then
        sequenceDragArea = CreateFrame("Frame")
        sequenceDragArea:SetScript("OnSizeChanged", function(_, w, h) fitIcon(w, h) end)
    end
    sequenceDragArea:SetParent(slot.frame:GetParent())
    sequenceDragArea:ClearAllPoints()
    sequenceDragArea:SetAllPoints(slot.frame)
    sequenceDragIcon:ClearAllPoints()
    sequenceDragIcon:SetPoint("CENTER", sequenceDragArea, "CENTER")
    -- OnSizeChanged does not fire when the area comes out the same size as last
    -- time, and attachSequenceDragIcon has just set the icon back to its small
    -- size.
    fitIcon(sequenceDragArea:GetSize())
    -- The badge straddles the icon's bottom edge, centred, sized to its text.
    -- Only when the icon can actually be dragged.
    local badge = sequenceDragIcon.dragLabel
    badge.text:SetFont(GameFontNormalSmall:GetFont())
    badge:SetSize(math.ceil(badge.text:GetStringWidth()) + DRAG_BADGE_PAD_X * 2,
        math.ceil(badge.text:GetStringHeight()) + DRAG_BADGE_PAD_Y * 2)
    badge:ClearAllPoints()
    badge:SetPoint("BOTTOM", sequenceDragIcon, "BOTTOM", 0, -DRAG_BADGE_DROP)
    badge:SetShown(sequenceDragIcon.sequenceId ~= nil)
end

-- "Disable Sequence", centred at the bottom of the Config page. A real child
-- of that row, released with it; sized to its label (the widget's
-- frame is only the check square) so the text fits.
local function createDisableSequenceCheckbox(editframe)
    local disableSequence = UI:Create("CheckBox")
    disableSequence:SetLabel(T("Disable Sequence"))
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
    local labelWidth = disableSequence.text and disableSequence.text:GetStringWidth() or 0
    disableSequence:SetWidth(math.ceil((disableSequence.checkbg and disableSequence.checkbg:GetWidth() or 24) + labelWidth))
    -- The label is anchored to the box's vertical centre, but the font's glyphs
    -- do not centre on the square's art; offset tuned in game until the text
    -- sits centred on the box. The widget is pooled, so put the widget's own
    -- anchor back on release.
    local text, check = disableSequence.text, disableSequence.checkbg
    if text and check then
        text:ClearAllPoints()
        text:SetPoint("LEFT", check, "RIGHT", 0, 2)
        disableSequence:SetCallback("OnRelease", function()
            text:ClearAllPoints()
            text:SetPoint("LEFT", check, "RIGHT", 0, 0)
        end)
    end
    return disableSequence
end

local function addSequenceNameEditor(editframe, container, width)
    local nameeditbox = UI:Create("EditBox")
    -- Compact: the label sits beside the box (headerFieldRow), not above.
    nameeditbox:SetLabel("")
    if nameeditbox.SetCompactNoLabel then nameeditbox:SetCompactNoLabel(true) end
    nameeditbox:SetWidth(width)
    -- Row height, not the 48 an EditBox keeps for a label above it: the
    -- row centres on its tallest child, so 48 pushed the line 13 low.
    nameeditbox:SetHeight(HEADER_ROW_HEIGHT)
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

local function addAuthorEditor(editframe, container, width)
    local authoreditbox = UI:Create("EditBox")
    if width then
        -- Compact: the label sits beside the box (headerFieldRow), not above.
        authoreditbox:SetLabel("")
        if authoreditbox.SetCompactNoLabel then authoreditbox:SetCompactNoLabel(true) end
        authoreditbox:SetWidth(width)
        -- Row height, not the 48 an EditBox keeps for a label above it: the
        -- row centres on its tallest child, so 48 pushed the line 13 low.
        authoreditbox:SetHeight(HEADER_ROW_HEIGHT)
    else
        authoreditbox:SetLabel(T("Author"))
        setEditBoxLabelGap(authoreditbox, 2)
        authoreditbox:SetWidth(math.min(320, math.max(220, math.floor(metadataContentWidth(editframe, container) / 2))))
    end
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

-- The rule itself (which host, what replaces it) lives in Storage.lua with
-- the load-time heal; this box only applies it as you type.
local HELPLINK_DEFAULT = GSE.HelplinkDefault
local helplinkAllowed = GSE.HelplinkAllowed

local function addHelpLinkEditor(editframe, container, width)
    local helplinkeditbox = UI:Create("EditBox")
    if width then
        -- Compact: the label sits beside the box (headerFieldRow), not above.
        helplinkeditbox:SetLabel("")
        if helplinkeditbox.SetCompactNoLabel then helplinkeditbox:SetCompactNoLabel(true) end
        helplinkeditbox:SetWidth(width)
        -- Row height, not the 48 an EditBox keeps for a label above it: the
        -- row centres on its tallest child, so 48 pushed the line 13 low.
        helplinkeditbox:SetHeight(HEADER_ROW_HEIGHT)
    else
        helplinkeditbox:SetLabel(T("Help Link"))
        setEditBoxLabelGap(helplinkeditbox, 2)
        helplinkeditbox:SetWidth(math.min(320, math.max(220, math.floor(metadataContentWidth(editframe, container) / 2))))
    end
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

    if GSE.isEmpty(editframe.Sequence.MetaData.Helplink) or not helplinkAllowed(editframe.Sequence.MetaData.Helplink) then
        editframe.Sequence.MetaData.Helplink = HELPLINK_DEFAULT
    end
    helplinkeditbox:SetText(editframe.Sequence.MetaData.Helplink)
    helplinkeditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            if not helplinkAllowed(key) then
                -- SetText re-fires this callback with the default, which
                -- passes, so there is no loop.
                editframe.Sequence.MetaData.Helplink = HELPLINK_DEFAULT
                helplinkeditbox:SetText(HELPLINK_DEFAULT)
                return
            end
            editframe.Sequence.MetaData.Helplink = key
        end
    )
    container:AddChild(helplinkeditbox)
end

-- Links in a note. The server's rendering is plain escape-coded text, which a
-- FontString draws but cannot click; every http(s) address in it is wrapped
-- in a gseurl hyperlink (blue), and clicking one opens a popup with the
-- address selected for Ctrl+C -- WoW cannot open a browser itself.
local NOTES_LINK_COLOUR = "|cff4fb8ff"

local function notesLink(url, label)
    return NOTES_LINK_COLOUR .. "|Hgseurl:" .. url .. "|h" .. (label or url) .. "|h|r"
end

local function linkifyNotes(text)
    text = tostring(text or "")
    -- Named links first, parked behind placeholders so the bare-address pass
    -- below does not find their addresses again inside the link code.
    local parked = {}
    local function park(url, label)
        parked[#parked + 1] = notesLink(url, label)
        return "\1" .. #parked .. "\1"
    end
    -- [Ko-Fi](https://ko-fi.com/...) as gse.tools renders it: the name in a
    -- colour code, then the address in brackets. The name becomes the link.
    text = text:gsub("|c%x%x%x%x%x%x%x%x([^|]-)|r%s*%((https?://[^%s%)|]+)%)", function(label, url)
        return park(url, label)
    end)
    -- The same, if any arrives as raw Markdown.
    text = text:gsub("%[([^%]]+)%]%((https?://[^%s%)|]+)%)", function(label, url)
        return park(url, label)
    end)
    -- Every other bare address.
    text = text:gsub("(https?://[^%s|%)%]\"'<>]+)", function(url)
        -- Sentence punctuation after an address is not part of it.
        local trail = url:match("[%.,;:!%?]+$") or ""
        if trail ~= "" then url = url:sub(1, #url - #trail) end
        return notesLink(url) .. trail
    end)
    return (text:gsub("\1(%d+)\1", function(n) return parked[tonumber(n)] end))
end

StaticPopupDialogs["GSE_COPY_NOTES_LINK"] = {
    text = T("Copy this link with Ctrl+C:"),
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 360,
    OnShow = function(self, data)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        if not editBox then return end
        editBox:SetText(data or "")
        editBox:HighlightText()
        editBox:SetFocus()
        -- Typing over it would lose the address; put it back.
        editBox:SetScript("OnTextChanged", function(box, userInput)
            if userInput then
                box:SetText(data or "")
                box:HighlightText()
            end
        end)
    end,
    OnHide = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        if editBox then editBox:SetScript("OnTextChanged", nil) end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- The note is drawn in a frame of our own laid over the body label rather than
-- in the label itself: a hyperlink is only clickable in a frame with its
-- hyperlinks and mouse enabled, and the label is pooled -- switching those on
-- would ride along to whatever the label is used for next. A child frame the
-- pool did not create is hidden on reuse; this one is cached per label frame
-- and shown again when the notes panel takes that label.
local notesTextFrames = setmetatable({}, {__mode = "k"})

local function notesTextFrame(body)
    local host = body.frame
    local entry = notesTextFrames[host]
    if not entry then
        local frame = CreateFrame("Frame", nil, host)
        frame:SetAllPoints(host)
        frame:EnableMouse(true)
        frame:SetHyperlinksEnabled(true)
        local fontString = frame:CreateFontString(nil, "ARTWORK")
        fontString:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        fontString:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        fontString:SetJustifyH("LEFT")
        fontString:SetJustifyV("TOP")
        fontString:SetWordWrap(true)
        frame:SetScript("OnHyperlinkClick", function(_, link)
            local url = type(link) == "string" and link:match("^gseurl:(.+)$")
            if url then StaticPopup_Show("GSE_COPY_NOTES_LINK", nil, nil, url) end
        end)
        frame:SetScript("OnHyperlinkEnter", function(self, link)
            local url = type(link) == "string" and link:match("^gseurl:(.+)$")
            if not url then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(T("Click to copy this link"))
            GameTooltip:AddLine(url, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
        entry = {frame = frame, text = fontString}
        notesTextFrames[host] = entry
    end
    entry.frame:Show()
    return entry
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
    -- The action-block teal rail down the left edge, set on purpose. It used to
    -- show only when the box happened to be a recycled block frame.
    if box.SetLeftBorderColor then box:SetLeftBorderColor(0.00, 0.784, 0.784, 1, 3) end

    local scroll = UI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("List")
    if scroll.SetScrollBarEnabled then scroll:SetScrollBarEnabled(true) end
    if scroll.SetListPadding then scroll:SetListPadding(6, 6, 6, 6) end
    if scroll.SetListGap then scroll:SetListGap(0) end
    nudgeWidgetScrollBar(scroll, 3)

    local body = UI:Create("Label")
    -- Gold base text, set explicitly: the server's rendering marks emphasis in
    -- white, and it only stands out against a gold base. SetFontObject alone
    -- came out gold on a recycled label and white on a fresh one, so the same
    -- note looked styled one time and flat the next.
    local bodyFont = GameFontNormal
    if body.SetFontObject then body:SetFontObject(bodyFont) end
    local bodyText = body.label or body.text
    if bodyText and bodyText.SetFont and bodyFont and bodyFont.GetFont then
        local file, size, flags = bodyFont:GetFont()
        if file then bodyText:SetFont(file, size, flags or "") end
    end
    if body.SetColor and bodyFont and bodyFont.GetTextColor then
        body:SetColor(bodyFont:GetTextColor())
    end
    body:SetWidth(width)
    if bodyText and bodyText.SetWordWrap then bodyText:SetWordWrap(true) end
    text = linkifyNotes(text)
    -- The label only holds the space; the overlay draws the note, links and all.
    body:SetText("")
    local overlay = notesTextFrame(body)
    if bodyFont and bodyFont.GetFont then
        local file, size, flags = bodyFont:GetFont()
        if file then overlay.text:SetFont(file, size, flags or "") end
        overlay.text:SetTextColor(bodyFont:GetTextColor())
    end
    overlay.text:SetText(text)
    -- Height from a ruler, not from the label: a Label sizes itself to its own
    -- measurement when its text is set, and until the layout anchors it that
    -- measurement is one line -- which clipped the note to an ellipsis, every
    -- time on a tab swap. A detached FontString given the same font and the
    -- known width measures the wrapped text correctly straight away.
    local rulerText = GSE.GUI.NotesRuler
    if not rulerText then
        rulerText = UIParent:CreateFontString(nil, "ARTWORK")
        rulerText:Hide()
        GSE.GUI.NotesRuler = rulerText
    end
    if bodyText and bodyText.GetFont then
        local file, size, flags = bodyText:GetFont()
        if file then rulerText:SetFont(file, size, flags or "") end
    end
    rulerText:SetWordWrap(true)
    rulerText:SetWidth(width)
    rulerText:SetText(text)
    local measured = rulerText:GetStringHeight()
    if measured and measured > 0 and body.SetHeight then body:SetHeight(math.ceil(measured) + 4) end
    scroll:AddChild(body)

    box:AddChild(scroll)
    wrapper:AddChild(box)
    container:AddChild(wrapper)

    return wrapper
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
    -- Two columns (PvE | PvP, Specialization | Disable Sequence). When the page
    -- is too narrow for the full sizes, shrink the label column down to the
    -- longest label, then the dropdowns down to MIN_COLUMN_DROPDOWN_WIDTH,
    -- before giving up and letting the Flow rows wrap the second column below.
    -- The two rows size their height from the real layout, so either way the
    -- section below starts right after them.
    -- The page's full-width rows span the content width less the side paddings
    -- the editor applies (CONFIG_CONTENT_LEFT_PADDING each side); PvE and PvP
    -- each take half of that, so the drag icon centres in the right half.
    local pageWidth = contentWidth - 2 * CONFIG_CONTENT_LEFT_PADDING
    local halfColumnWidth = math.floor((pageWidth - METADATA_COLUMN_GAP) / 2)
    local columnRoom = halfColumnWidth - METADATA_VERSION_ROW_INDENT - 8 - columnExtraWidth
    if labelWidth + dropdownWidth > columnRoom then
        local longest = longestLabelWidth()
        labelWidth = math.max(longest, math.min(labelWidth, columnRoom - dropdownWidth))
        dropdownWidth = math.max(MIN_COLUMN_DROPDOWN_WIDTH, math.min(dropdownWidth, columnRoom - labelWidth))
    end
    local fieldColumnWidth = labelWidth + 8 + dropdownWidth + columnExtraWidth


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


    -- Specialization and Default Version: centred on the page, one above the other.
    local specRow = inlineFieldRow(T("Specialization/Class ID"), speciddropdown, labelWidth)
    if specRow.SetFlowHAlign then specRow:SetFlowHAlign("CENTER") end
    container:AddChild(specRow)

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
    local defaultRow = inlineFieldRow(T("Default Version"), defaultdropdown, labelWidth)
    if defaultRow.SetFlowHAlign then defaultRow:SetFlowHAlign("CENTER") end
    container:AddChild(defaultRow)
    -- 8 between Default Version and the PvE / PvP headings.
    addMetadataSpacer(container, 8)

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
        -- The dropdown runs to the right edge of its half of the page.
        if dd.SetFlowFillRemaining then dd:SetFlowFillRemaining(true) end
        local row = inlineFieldRow(cfg.label, dd, labelWidth)
        if row.SetFlowOffset then row:SetFlowOffset(METADATA_VERSION_ROW_INDENT, 0) end
        return row
    end

    -- PvE and PvP side by side; the drag icon's slot under PvP.
    local headerBlock = METADATA_HEADER_HEIGHT + 10
    local pveHeight = headerBlock + #pveVersionConfigs * INLINE_ROW_HEIGHT
    local columnWidth = math.max(fieldColumnWidth, halfColumnWidth)
    local pveColumn = metadataColumn(columnWidth, pveHeight)
    local pveHeading = metadataHeading(T("PvE"), columnWidth)
    pveHeading:SetFullWidth(true)
    pveColumn:AddChild(pveHeading)
    addMetadataSpacer(pveColumn, 10)
    for _, cfg in ipairs(pveVersionConfigs) do
        pveColumn:AddChild(versionDropdown(cfg))
    end

    local pvpRowsHeight = headerBlock + #pvpVersionConfigs * INLINE_ROW_HEIGHT
    local dragSlotHeight = math.max(DRAG_SLOT_MIN_HEIGHT, pveHeight - pvpRowsHeight)
    local pvpColumn = metadataColumn(columnWidth, pvpRowsHeight + dragSlotHeight)
    local pvpHeading = metadataHeading(T("PvP"), columnWidth)
    pvpHeading:SetFullWidth(true)
    pvpColumn:AddChild(pvpHeading)
    addMetadataSpacer(pvpColumn, 10)
    for _, cfg in ipairs(pvpVersionConfigs) do
        pvpColumn:AddChild(versionDropdown(cfg))
    end
    local dragSlot = UI:Create("SimpleGroup")
    dragSlot:SetFullWidth(true)
    dragSlot:SetHeight(dragSlotHeight)
    pvpColumn:AddChild(dragSlot)

    local splitColumns = addVersionColumns(container, pveColumn, pvpColumn, fieldColumnWidth, function(width)
        local ddWidth = columnDropdownWidth(width, labelWidth)
        speciddropdown:SetWidth(ddWidth)
        defaultdropdown:SetWidth(ddWidth)
    end)

    if GSE.GUI.DrawElementCollections and editframe.SequenceID then
        GSE.GUI.DrawElementCollections(container, "sequence", editframe.SequenceID, editframe.ClassID)
    end

    local deps, hasDeps, usedBy = dependencyData(editframe)
    addDependencyWindow(editframe, container, deps, hasDeps, usedBy)

    -- Disable Sequence, centred at the bottom of the page, 8 below Dependencies.
    addMetadataSpacer(container, 8)
    local disableRow = UI:Create("SimpleGroup")
    disableRow:SetLayout("Flow")
    disableRow:SetFullWidth(true)
    if disableRow.SetFlowPadding then disableRow:SetFlowPadding(0, 0, 0, 0) end
    if disableRow.SetFlowHAlign then disableRow:SetFlowHAlign("CENTER") end
    disableRow:AddChild(createDisableSequenceCheckbox(editframe))
    container:AddChild(disableRow)
    centreSequenceDragIcon(dragSlot)
    splitColumns()
end

-- Notes written on gse.tools arrive as markdown in MetaData.Notes, and the
-- server renders them to WoW escape sequences into MetaData.Help on every
-- write. So Notes means "this text came from the website" and Help is the
-- rendering to show. Returns the text to render, or nil when the sequence has
-- no website notes. Read-only in that case: an in-game edit only changes Help,
-- and the server rebuilds Help from the untouched Notes on the next sync.
local function websiteNotesText(sequence)
    local meta = sequence and sequence.MetaData
    if not meta or GSE.isEmpty(meta.Notes) then return nil end
    -- Fall back to the markdown source if a record arrives without a rendering.
    if not GSE.isEmpty(meta.Help) then return meta.Help end
    return meta.Notes
end

-- Help Information, as on the macro and variable pages: the GSE.Tools notes
-- read-only when the sequence has them, else MetaData.Help to type into.
local HELP_BOX_LINES = 3
local HELP_PANEL_HEIGHT = 120
local function addHelpInformationBox(editframe, container)
    local rendered = websiteNotesText(editframe.Sequence)
    if rendered then
        GSE.GUI.CreateReadOnlyNotesPanel(container, T("Help Information"), rendered,
            {height = HELP_PANEL_HEIGHT, editframe = editframe})
        return
    end
    local helpeditbox = UI:Create("MultiLineEditBox")
    helpeditbox:SetLabel(T("Help Information"))
    -- Explicit SetFont: a recycled widget's font was restored with SetFont,
    -- which SetFontObject does not override.
    if helpeditbox.label and helpeditbox.label.SetFont then
        helpeditbox.label:SetFont(GameFontNormalSmall:GetFont())
    end
    helpeditbox:SetNumLines(HELP_BOX_LINES)
    helpeditbox:SetFullWidth(true)
    helpeditbox:DisableButton(true)
    helpeditbox:SetText(editframe.Sequence.MetaData.Help or "")
    helpeditbox:SetCallback("OnTextChanged", function(_, _, text)
        editframe.Sequence.MetaData.Help = text
    end)
    helpeditbox:SetCallback("OnEnter", function()
        GSE.CreateToolTip(T("Help Information"),
            T("Notes and help on how this sequence works.  What things to remember.  This information is shown in the sequence browser."),
            editframe)
    end)
    helpeditbox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    container:AddChild(helpeditbox)
end

-- Widest header label in its font (GameFontNormalSmall), so no label wraps.
local function headerLabelWidth()
    labelProbe = labelProbe or UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelProbe:SetFont(GameFontNormalSmall:GetFont())
    local widest = HEADER_LABEL_WIDTH
    for _, key in ipairs({"Sequence Name", "Author", "Help Link"}) do
        labelProbe:SetText(T(key))
        widest = math.max(widest, math.ceil(labelProbe:GetStringWidth() or 0) + 4)
    end
    return widest
end

-- One "Label  [field]" line of the header block: a small label right-aligned
-- beside the box, the row centred on the page.
local function headerFieldRow(container, labelText, labelWidth)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(HEADER_ROW_HEIGHT)
    if row.SetFlowGap then row:SetFlowGap(6) end
    if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
    if row.SetFlowHAlign then row:SetFlowHAlign("CENTER") end
    if row.SetFlowVAlign then row:SetFlowVAlign("CENTER") end
    local label = UI:Create("Label")
    label:SetText(labelText)
    label:SetWidth(labelWidth or HEADER_LABEL_WIDTH)
    if label.SetJustifyH then label:SetJustifyH("RIGHT") end
    -- Text centred in the label box, level with the text in the field beside it.
    if label.SetJustifyV then label:SetJustifyV("MIDDLE") end
    -- An explicit SetFont: a recycled Label comes back with its font set by
    -- SetFont, which SetFontObject does not override.
    local fs = label.label or label.text
    if fs and fs.SetFont and GameFontNormalSmall then
        local face, size, flags = GameFontNormalSmall:GetFont()
        if face then fs:SetFont(face, size, flags or "") end
    end
    row:AddChild(label)
    container:AddChild(row)
    return row
end

-- One page (it replaces the Config and Notes tabs): Sequence Name, Author and
-- Help Link at the top, the Help Information box, then the settings.
GUIDrawMetadataEditor = function(editframe, container)
    if container.SetListPadding then container:SetListPadding(CONFIG_CONTENT_LEFT_PADDING, 5, CONFIG_CONTENT_LEFT_PADDING, CONFIG_CONTENT_LEFT_PADDING) end

    local header = UI:Create("SimpleGroup")
    header:SetLayout("List")
    header:SetFullWidth(true)
    if header.SetListGap then header:SetListGap(2) end
    if header.SetListPadding then header:SetListPadding(0, 0, 0, 0) end
    local labelWidth = headerLabelWidth()
    local nameRow = headerFieldRow(header, T("Sequence Name"), labelWidth)
    addSequenceNameEditor(editframe, nameRow, HEADER_FIELD_WIDTH)
    addAuthorEditor(editframe, headerFieldRow(header, T("Author"), labelWidth), HEADER_FIELD_WIDTH)
    addHelpLinkEditor(editframe, headerFieldRow(header, T("Help Link"), labelWidth), HEADER_FIELD_WIDTH)
    container:AddChild(header)
    -- The drag icon's frame is owned here and released with this block.
    attachSequenceDragIcon(editframe, header)

    addMetadataSpacer(container, 8)
    addHelpInformationBox(editframe, container)

    addMetadataSpacer(container, 16)
    drawMetadataTab(editframe, container)
end

-- ---------------------------------------------------------------------------
-- Variables and macros: scope, versions and version selection
-- ---------------------------------------------------------------------------
-- A variable or macro is scoped and versioned as a sequence is (MetaData.SpecID,
-- Versions, MetaData.Default and the context overrides). These draw the same
-- controls the sequence Configuration tab does, bound to any such element, so
-- the three editors look and behave alike.

local ELEMENT_LABEL_WIDTH = 150
local ELEMENT_DROPDOWN_WIDTH = 250
-- The centred Default Version dropdown, as wide as the Config page's fields.
local ELEMENT_DEFAULT_DROPDOWN_WIDTH = MAX_FIELD_WIDTH + DROPDOWN_VISUAL_WIDTH_OFFSET

-- { ["1"] = "1 - Label", ... } for a version dropdown.
local function elementVersionList(element)
    local list, order = {}, {}
    for i, v in ipairs(element.Versions or {}) do
        local key = tostring(i)
        list[key] = (type(v) == "table" and not GSE.isEmpty(v.Label)) and (key .. " - " .. v.Label) or key
        order[#order + 1] = key
    end
    return list, order
end

--- The scope picker: Global, a class, or a spec. `suggestion`, when given, is
--- { specID, reason } -- a scope the element's users all share -- offered for the
--- author to take with one click; nothing is ever moved without them.
function GSE.GUI.DrawElementScope(editframe, container, element, suggestion, onChange)
    element.MetaData = element.MetaData or {}
    local dd = UI:Create("Dropdown")
    dd:SetWidth(ELEMENT_DEFAULT_DROPDOWN_WIDTH)
    if dd.SetDropdownStyle then dd:SetDropdownStyle(true) end
    dd:SetList(GSE.GetSpecNames())
    dd:SetValue(Statics.SpecIDList[tonumber(element.MetaData.SpecID) or 0])
    dd:SetCallback("OnValueChanged", function(_, _, key)
        element.MetaData.SpecID = Statics.SpecIDHashList[key]
        if onChange then onChange() end
    end)
    dd:SetCallback("OnEnter", function()
        GSE.CreateToolTip(T("Specialization/Class ID"),
            T("What class or spec is this for?  If it is for all classes choose Global.  It is only loaded for that class."),
            editframe)
    end)
    dd:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    -- Centred, with the label and dropdown widths of the Default Version row
    -- below it, so the two line up as on the sequence Configuration page.
    local scopeRow = inlineFieldRow(T("Specialization/Class ID"), dd, longestLabelWidth())
    -- Sized with the version dropdowns by DrawElementVersionConfig; forgotten
    -- when released, as the pooled widget then belongs to someone else.
    editframe.elementScopeDropdown = dd
    dd:SetCallback("OnRelease", function()
        if editframe.elementScopeDropdown == dd then editframe.elementScopeDropdown = nil end
    end)
    if scopeRow.SetFlowHAlign then scopeRow:SetFlowHAlign("CENTER") end
    container:AddChild(scopeRow)

    local current = tonumber(element.MetaData.SpecID) or 0
    if suggestion and suggestion.specID and suggestion.specID ~= current then
        local row = UI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        if row.SetFlowGap then row:SetFlowGap(8) end
        local hint = UI:Create("Label")
        hint:SetText(suggestion.reason)
        hint:SetWidth(360)
        local use = UI:Create("Button")
        use:SetText(string.format(T("Use %s"), Statics.SpecIDList[suggestion.specID] or tostring(suggestion.specID)))
        use:SetWidth(160)
        use:SetCallback("OnClick", function()
            element.MetaData.SpecID = suggestion.specID
            if onChange then onChange() end
        end)
        row:AddChild(hint)
        row:AddChild(use)
        container:AddChild(row)
    end
end

--- "From collections: A, B" -- the collections an element came through
--- (collection provenance, GSE.ElementCollections). Nothing when there are none.
function GSE.GUI.DrawElementCollections(container, kind, ref, classid)
    local cols = GSE.ElementCollections and GSE.ElementCollections(kind, ref, classid)
    if not cols then return end
    local names = {}
    for key, name in pairs(cols) do
        names[#names + 1] = name or key
    end
    table.sort(names)
    local text = UI:Create("Label")
    text:SetText(table.concat(names, ", "))
    text:SetWidth(ELEMENT_DROPDOWN_WIDTH + 200)
    container:AddChild(inlineFieldRow(T("From collections"), text, ELEMENT_LABEL_WIDTH))
end

--- The version bar: choose which version to edit, label it, copy it into a new
--- one, or delete it. `onSelect(index)` redraws the editor on that version;
--- `onChange()`, when given, runs after the versions themselves change.
function GSE.GUI.DrawElementVersionBar(editframe, container, element, selected, onSelect, onChange)
    element.Versions = element.Versions or {{}}
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    if row.SetFlowGap then row:SetFlowGap(8) end
    if row.SetFlowVAlign then row:SetFlowVAlign("BOTTOM") end

    local pick = UI:Create("Dropdown")
    pick:SetLabel(T("Version"))
    pick:SetWidth(180)
    if pick.SetDropdownStyle then pick:SetDropdownStyle(true) end
    pick:SetList(elementVersionList(element))
    pick:SetValue(tostring(selected))
    pick:SetCallback("OnValueChanged", function(_, _, key) onSelect(tonumber(key) or 1) end)

    local label = UI:Create("EditBox")
    label:SetLabel(T("Version Label"))
    label:SetWidth(200)
    label:DisableButton(true)
    label:SetText(element.Versions[selected] and element.Versions[selected].Label or "")
    label:SetCallback("OnTextChanged", function(_, _, text)
        if element.Versions[selected] then
            element.Versions[selected].Label = (text ~= "") and text or nil
        end
    end)
    label:SetCallback("OnEditFocusLost", function() if onChange then onChange() end end)
    -- 6 right, to even the space either side of the box: the dropdown's art
    -- runs to its frame's edge, the box's sits inset in its own and the
    -- button's art inset again, so the gaps read ~6 and ~17 (measured off an
    -- in-game screenshot). The offset moves only the box, so both become ~11.
    if label.SetFlowOffset then label:SetFlowOffset(6, 0) end

    local add = UI:Create("Button")
    add:SetText(T("New") .. " " .. T("Version"))
    add:SetWidth(130)
    add:SetCallback("OnClick", function()
        table.insert(element.Versions, GSE.CloneSequence(element.Versions[selected] or {}))
        element.Versions[#element.Versions].Label = nil
        if onChange then onChange() end
        onSelect(#element.Versions)
    end)
    add:SetCallback("OnEnter", function()
        GSE.CreateToolTip(T("New") .. " " .. T("Version"), T("Copy the selected version into a new one."), editframe)
    end)
    add:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local del = UI:Create("Button")
    del:SetText(T("Delete Version"))
    del:SetWidth(130)
    del:SetDisabled(#element.Versions < 2)
    del:SetCallback("OnClick", function()
        if #element.Versions < 2 then return end
        -- Refused, not repointed, while anything selects it -- as for a sequence.
        local blocking = GSE.VersionReferencesInUse(element.MetaData, selected)
        if #blocking > 0 then
            editframe:SetStatusText(string.format(T("Version %d is still selected for: %s"),
                selected, table.concat(blocking, ", ")))
            return
        end
        GSE.ShiftVersionReferencesAfterDelete(element.MetaData, selected)
        table.remove(element.Versions, selected)
        if onChange then onChange() end
        onSelect(math.min(selected, #element.Versions))
    end)

    -- The row aligns frame bottoms. The label box's frame is 48 high (label
    -- above, box 13 down, 22 high), so its box centres 24 above the bottom; the
    -- 24-high dropdown and buttons centre 12 above it. Raising those 12 lines
    -- all four up and keeps the label at the top of the row.
    -- 2 short of that in practice (tuned in game): the drawn art sits high in
    -- each frame.
    for _, w in ipairs({pick, add, del}) do
        if w.SetFlowOffset then w:SetFlowOffset(0, 10) end
    end
    row:AddChild(pick)
    row:AddChild(label)
    row:AddChild(add)
    row:AddChild(del)
    container:AddChild(row)
end

--- Which version runs where: Default, then the PvE and PvP context overrides.
--- A context set to the Default version is cleared, as the sequence editor does.
--- `onChange()`, when given, runs after any of them changes.
function GSE.GUI.DrawElementVersionConfig(editframe, container, element, onChange)
    element.MetaData = element.MetaData or {}
    local meta = element.MetaData
    local list, order = elementVersionList(element)

    -- Laid out as the sequence Configuration page: Default Version centred,
    -- then PvE | PvP side by side, each dropdown running to its column's edge.
    local labelWidth = longestLabelWidth()
    local function dropdown(labelText, tip, value, set, fill)
        local dd = UI:Create("Dropdown")
        dd:SetWidth(ELEMENT_DEFAULT_DROPDOWN_WIDTH)
        if dd.SetDropdownStyle then dd:SetDropdownStyle(true) end
        dd:SetList(list, order)
        dd:SetValue(value)
        dd:SetCallback("OnValueChanged", function(_, _, key)
            set(tonumber(key))
            if onChange then onChange() end
        end)
        dd:SetCallback("OnEnter", function() GSE.CreateToolTip(labelText, tip, editframe) end)
        dd:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        if fill and dd.SetFlowFillRemaining then dd:SetFlowFillRemaining(true) end
        return inlineFieldRow(labelText, dd, labelWidth)
    end

    local defaultRow = dropdown(T("Default Version"), T("The version used where no other version has been configured."),
        tostring(meta.Default or 1), function(n) meta.Default = n end)
    if defaultRow.SetFlowHAlign then defaultRow:SetFlowHAlign("CENTER") end
    container:AddChild(defaultRow)
    -- 8 between Default Version and the PvE / PvP headings.
    addMetadataSpacer(container, 8)

    local headerBlock = METADATA_HEADER_HEIGHT + 10
    local columnHeight = headerBlock + math.max(#pveVersionConfigs, #pvpVersionConfigs) * INLINE_ROW_HEIGHT
    local minWidth = labelWidth + 8 + MIN_COLUMN_DROPDOWN_WIDTH + FIELD_COLUMN_EXTRA_WIDTH
        + METADATA_VERSION_ROW_INDENT
    local columns = {}
    for i, section in ipairs({{T("PvE"), pveVersionConfigs}, {T("PvP"), pvpVersionConfigs}}) do
        local column = metadataColumn(minWidth, columnHeight)
        local heading = metadataHeading(section[1], minWidth)
        heading:SetFullWidth(true)
        column:AddChild(heading)
        addMetadataSpacer(column, 10)
        for _, cfg in ipairs(section[2]) do
            local key = cfg.key
            local row = dropdown(cfg.label, cfg.tip, versionValue(meta, key), function(n)
                meta[key] = (n ~= tonumber(meta.Default)) and n or nil
            end, true)
            if row.SetFlowOffset then row:SetFlowOffset(METADATA_VERSION_ROW_INDENT, 0) end
            column:AddChild(row)
        end
        columns[i] = column
    end
    local defaultDropdown = defaultRow.children and defaultRow.children[2]
    addVersionColumns(container, columns[1], columns[2], minWidth, function(width)
        local ddWidth = columnDropdownWidth(width, labelWidth)
        if defaultDropdown then defaultDropdown:SetWidth(ddWidth) end
        if editframe.elementScopeDropdown then editframe.elementScopeDropdown:SetWidth(ddWidth) end
    end)()
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
--
-- The panel measures the note's height at its width, so it needs the real
-- content width. options.editframe, when given, supplies it the way the
-- sequence page does (metadataContentWidth); otherwise the container's current
-- width is used, which is still 0 on a page that has not been laid out yet.
function GSE.GUI.CreateReadOnlyNotesPanel(container, label, text, options)
    options = options or {}
    if not options.width and options.editframe then
        options.width = metadataContentWidth(options.editframe, container)
    end
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
    -- No scrollbar, as on the Configuration page; the mouse wheel scrolls.
    if depScroll.SetScrollBarEnabled then depScroll:SetScrollBarEnabled(false) end
    if depScroll.SetListPadding then depScroll:SetListPadding(2, DEPENDENCY_DATA_TOP_PADDING, 4, 2) end
    if depScroll.SetListGap then depScroll:SetListGap(0) end

    for _, row in ipairs(rows) do
        addDependencyRow(depScroll, row.name, row.depType, row.author or "", row.updated or "", hideAuthor, hideType)
    end

    depBox:AddChild(depScroll)
    wrapper:AddChild(depBox)
    container:AddChild(wrapper)
end
end
table.insert(ns.deferred, setup)

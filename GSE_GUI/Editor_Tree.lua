local GSE = GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- Single padding value for all sides of every editor section panel.
-- Change this one number to adjust Config/Notes/Macros/Variables/Keybindings/AO/Skyriding.
GSE.GUI.CONTENT_PADDING = 20
local CONFIG_CONTENT_LEFT_PADDING = GSE.GUI.CONTENT_PADDING

local function SmoothEditorScrollFrame(scrollWidget)
    if not scrollWidget or scrollWidget.gseSmoothMouseWheel then return end
    scrollWidget.gseSmoothMouseWheel = true
end

GSE.GUI.SmoothEditorScrollFrame = SmoothEditorScrollFrame

local function ReportMacroOptionWarningsForText(text)
    if type(text) ~= "string" or text == "" then return end
    if GSE.DecodeMacroEditorText then text = GSE.DecodeMacroEditorText(text) end
    if GSE.UnEscapeString then text = GSE.UnEscapeString(text) end
    if type(text) ~= "string" or string.sub(text, 1, 1) ~= "/" then return end

    local lines = GSE.SplitMeIntoLines and GSE.SplitMeIntoLines(text) or {}
    for _, line in ipairs(lines) do
        local rest = string.match(line or "", "^%s*/%a+%s+(.*)")
        if rest and rest ~= "" and GSE.SafeSecureCmdOptionParse then
            GSE.SafeSecureCmdOptionParse(rest, false)
        end
    end
end

local function ReportMacroOptionWarningsForActionList(actions)
    if type(actions) ~= "table" then return end
    for _, action in ipairs(actions) do
        if type(action) == "table" then
            ReportMacroOptionWarningsForText(action.macro)
            if action.Type == Statics.Actions.Loop then
                ReportMacroOptionWarningsForActionList(action)
            elseif action.Type == Statics.Actions.If then
                ReportMacroOptionWarningsForActionList(action[1])
                ReportMacroOptionWarningsForActionList(action[2])
            end
        end
    end
end

local function ReportMacroOptionWarningsForSequence(sequence)
    if type(sequence) ~= "table" or type(sequence.Versions) ~= "table" then return end
    for _, versionData in pairs(sequence.Versions) do
        if type(versionData) == "table" then
            ReportMacroOptionWarningsForActionList(versionData.Actions)
        end
    end
end

local RESOURCE_LINKS = {
    {
        title = "GSE Tools - Official GSE Sequence Repository",
        icon = "Interface\\Addons\\GSE_GUI\\Assets\\GSE-Logo.png",
        url = "https://gse.tools"
    },
    {
        title = "TimothyLuke's GitHub - GSE Addon Repository / Issues",
        icon = Statics.Icons.Github,
        iconOffsetX = 2,
        url = "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler"
    },
    {
        title = "GSE Official Addon / Tools / CompApp",
        icon = "Interface\\Addons\\GSE_GUI\\Assets\\discord.png",
        iconOffsetX = -3,
        url = "https://discord.com/invite/yUS9R4ZXZA"
    },
    {
        title = "GSE United - User/Creator Discord Community",
        icon = Statics.Icons.GSEUnited,
        iconSize = 58,
        rowHeight = 58,
        iconOffsetX = -10,
        contentOffsetX = -12,
        url = "https://discord.gg/gseunited"
    },
    {
        title = "Oak - YouTube",
        icon = Statics.Icons.Oak,
        url = "https://www.youtube.com/@oakensoul"
    },
    {
        title = "GSE Addon Patreon",
        icon = Statics.Icons.Patreon,
        rowOffsetY = 3,
        contentOffsetX = 0,
        url = "https://www.patreon.com/TimothyLuke"
    }
}

local resourcesFrame
local RESOURCE_GOLD = {1, 0.82, 0, 1}
local RESOURCE_BUTTON_TEXT = "|cFFFFFFFFGS|r|cFF00FFFFE|r|cFFFFFFFF:|r |cFFFFD100Resources|r"
local RESOURCE_BUTTON_WIDTH = 145
-- Width/height give the row's Flow layout (icon + URL box + Copy button) enough
-- room not to wrap the Copy button onto a second line, accounting for the
-- popup's border insets. Pair with RESOURCE_BODY_WIDTH below if adjusting.
local RESOURCE_FRAME_WIDTH = 640
local RESOURCE_FRAME_HEIGHT = 480
local RESOURCE_ROW_HEIGHT = 53
local RESOURCE_ICON_SIZE = 46
local RESOURCE_BODY_WIDTH = 278
local RESOURCE_COPY_WIDTH = 64
local RESOURCE_ROW_OFFSET_X = 8
local RESOURCE_ROW_STACK_LIFT = 10
local RESOURCE_ROW_FLOW_GAP = 2
local RESOURCE_COPY_OFFSET_Y = -8
local EDITOR_FOOTER_BUTTON_GAP = 6

local function SetResourceFrameTextColor(text, color)
    if not (text and text.SetTextColor and color) then return end
    if GSE.IsEllesmereUILoaded and GSE.IsEllesmereUILoaded() then
        text:SetTextColor(1, 1, 1, 1)
    else
        text:SetTextColor(unpack(color))
    end
end

local function GetResourceEditBox(editBox)
    if not editBox then return nil end
    return editBox.editBox or editBox.editbox or editBox
end

local function CopyResourceLink(editBox, link)
    local copied = false
    if C_Clipboard and C_Clipboard.SetClipboard then
        copied = pcall(function() C_Clipboard.SetClipboard(link) end)
    elseif SetClipboard then
        copied = pcall(function() SetClipboard(link) end)
    end

    local nativeEditBox = GetResourceEditBox(editBox)
    if nativeEditBox then
        nativeEditBox:SetFocus()
        nativeEditBox:HighlightText()
    end

    if resourcesFrame and resourcesFrame.SetStatusText then
        resourcesFrame:SetStatusText(copied and "Link copied." or "Link selected. Press Ctrl+C to copy.")
    end
end

local function SetResourceVersionTextHover(hovered)
    if not (resourcesFrame and resourcesFrame.statustext) then return end
    if resourcesFrame.statustext.GetFont and resourcesFrame.statustext.SetFont then
        if not resourcesFrame.versionTextBaseFont then
            local fontFile, fontSize, fontFlags = resourcesFrame.statustext:GetFont()
            if fontFile and fontSize then resourcesFrame.versionTextBaseFont = {fontFile, fontSize, fontFlags} end
        end
        if resourcesFrame.versionTextBaseFont then
            resourcesFrame.statustext:SetFont(
                resourcesFrame.versionTextBaseFont[1],
                hovered and math.floor((resourcesFrame.versionTextBaseFont[2] * 1.14) + 0.5) or resourcesFrame.versionTextBaseFont[2],
                resourcesFrame.versionTextBaseFont[3]
            )
            return
        end
    end
    if resourcesFrame.statustext.SetScale then resourcesFrame.statustext:SetScale(hovered and 1.08 or 1) end
end

local function UpdateResourceVersionHitBox()
    if not (resourcesFrame and resourcesFrame.versionHitBox and resourcesFrame.statustext) then return end
    local textWidth = resourcesFrame.statustext.GetStringWidth and resourcesFrame.statustext:GetStringWidth() or 0
    local textHeight = resourcesFrame.statustext.GetStringHeight and resourcesFrame.statustext:GetStringHeight() or 0
    resourcesFrame.versionHitBox:ClearAllPoints()
    resourcesFrame.versionHitBox:SetSize(math.max(1, math.ceil(textWidth)), math.max(12, math.ceil(textHeight) + 6))
    resourcesFrame.versionHitBox:SetPoint("CENTER", resourcesFrame.statustext, "CENTER", 0, 0)
end

-- Generic: wire a FontString so double-clicking it opens the version copy
-- popup. Mirrors the popup's hover/tooltip behavior using the FontString's
-- own font (not the resourcesFrame globals) so it works on any host frame.
local function AttachVersionLinkHitBox(parentFrame, statusText)
    if not (parentFrame and statusText) then return nil end
    local hitBox = CreateFrame("Button", nil, parentFrame)
    hitBox:RegisterForClicks("LeftButtonUp")
    hitBox:EnableMouse(true)

    local baseFont
    local function setHover(hovered)
        if not (statusText.GetFont and statusText.SetFont) then return end
        if not baseFont then
            local f, s, x = statusText:GetFont()
            if f and s then baseFont = {f, s, x} end
        end
        if baseFont then
            statusText:SetFont(baseFont[1], hovered and math.floor((baseFont[2] * 1.14) + 0.5) or baseFont[2], baseFont[3])
        end
    end

    local function resize()
        local w = statusText.GetStringWidth  and statusText:GetStringWidth()  or 0
        local h = statusText.GetStringHeight and statusText:GetStringHeight() or 0
        hitBox:ClearAllPoints()
        hitBox:SetSize(math.max(1, math.ceil(w)), math.max(12, math.ceil(h) + 6))
        hitBox:SetPoint("CENTER", statusText, "CENTER", 0, 0)
    end

    hitBox:SetScript("OnMouseDown", function(self)
        local now = GetTime and GetTime() or 0
        if now - (self.lastClick or 0) <= 0.35 then
            self.lastClick = 0
            if GSE.GUIShowVersionCopyWindow then GSE.GUIShowVersionCopyWindow() end
            return
        end
        self.lastClick = now
    end)
    hitBox:SetScript("OnEnter", function(self)
        setHover(true); resize()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("GSE Version")
        GameTooltip:AddLine("Double-click: Copy version", 1, 1, 1)
        GameTooltip:Show()
    end)
    hitBox:SetScript("OnLeave", function()
        setHover(false); resize()
        if GameTooltip then GameTooltip:Hide() end
    end)

    if hitBox.SetFrameLevel and parentFrame.GetFrameLevel then
        hitBox:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 80)
    end
    resize()
    hitBox.Resize = resize
    return hitBox
end
GSE.GUI.AttachVersionLinkHitBox = AttachVersionLinkHitBox

local function EnsureResourceVersionHitBox()
    if not (resourcesFrame and resourcesFrame.frame and resourcesFrame.statustext) then return end
    resourcesFrame.statustext:ClearAllPoints()
    resourcesFrame.statustext:SetPoint("BOTTOMLEFT", resourcesFrame.frame, "BOTTOMLEFT", 14, 21)
    resourcesFrame.statustext:SetPoint("TOPRIGHT", resourcesFrame.frame, "BOTTOMRIGHT", -14, 47)
    resourcesFrame.statustext:SetJustifyH("CENTER")
    resourcesFrame.statustext:SetJustifyV("MIDDLE")

    if not resourcesFrame.versionHitBox then
        resourcesFrame.versionHitBox = CreateFrame("Button", nil, resourcesFrame.frame)
        resourcesFrame.versionHitBox:RegisterForClicks("LeftButtonUp")
        resourcesFrame.versionHitBox:EnableMouse(true)
        resourcesFrame.versionHitBox:SetScript(
            "OnMouseDown",
            function()
                local now = GetTime and GetTime() or 0
                if now - (resourcesFrame.lastVersionClick or 0) <= 0.35 then
                    resourcesFrame.lastVersionClick = 0
                    if GSE.GUIShowVersionCopyWindow then GSE.GUIShowVersionCopyWindow() end
                    return
                end
                resourcesFrame.lastVersionClick = now
            end
        )
        resourcesFrame.versionHitBox:SetScript(
            "OnEnter",
            function(self)
                SetResourceVersionTextHover(true)
                UpdateResourceVersionHitBox()
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetText("GSE Version")
                GameTooltip:AddLine("Double-click: Copy version", 1, 1, 1)
                GameTooltip:Show()
            end
        )
        resourcesFrame.versionHitBox:SetScript(
            "OnLeave",
            function()
                SetResourceVersionTextHover(false)
                UpdateResourceVersionHitBox()
                if GameTooltip then GameTooltip:Hide() end
            end
        )
    end

    UpdateResourceVersionHitBox()
    if resourcesFrame.versionHitBox.SetFrameLevel and resourcesFrame.frame.GetFrameLevel then
        resourcesFrame.versionHitBox:SetFrameLevel((resourcesFrame.frame:GetFrameLevel() or 0) + 80)
    end
    resourcesFrame.versionHitBox:Show()
end

local function PrepareResourceEditBox(editBox)
    local nativeEditBox = GetResourceEditBox(editBox)
    if not nativeEditBox then return end

    nativeEditBox:SetAutoFocus(false)
    nativeEditBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    nativeEditBox:SetCursorPosition(0)
    nativeEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    nativeEditBox:SetScript("OnEscapePressed", function(self)
        self:HighlightText(0, 0)
        self:ClearFocus()
    end)
    nativeEditBox:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
end

local function CreateResourceRow(parent, resource, index)
    local row = UI:Create("SimpleGroup")
    local rowHeight = resource.rowHeight or RESOURCE_ROW_HEIGHT
    row:SetFullWidth(true)
    row:SetHeight(rowHeight)
    row:SetFlowOffset(RESOURCE_ROW_OFFSET_X, (((index or 1) - 1) * RESOURCE_ROW_STACK_LIFT) + (resource.rowOffsetY or 0))
    row:SetLayout("Flow")
    row:SetFlowPadding(0, 0, 0, 0)
    row:SetFlowGap(RESOURCE_ROW_FLOW_GAP)
    row:SetFlowVAlign("CENTER")

    local icon = UI:Create("Icon")
    icon:SetImage(resource.icon)
    local iconSize = resource.iconSize or RESOURCE_ICON_SIZE
    icon:SetImageSize(iconSize, iconSize)
    icon:SetHoverImageSize(iconSize, iconSize)
    icon:SetFlowOffset(resource.iconOffsetX or 0, resource.iconOffsetY or 0)
    icon:SetHoverLocked(true)
    if icon.SetElvUISubduedIcon then icon:SetElvUISubduedIcon(false) end
    if icon.SetElvUIIconBackgroundShown then icon:SetElvUIIconBackgroundShown(false) end
    row:AddChild(icon)

    local contentOffsetX = resource.contentOffsetX or 0
    local contentOffsetY = resource.contentOffsetY or 0

    local body = UI:Create("SimpleGroup")
    -- Fill the space between the icon and the right-pinned Copy button so the
    -- URL box adapts to the popup's real content width (UI-scale independent).
    -- RESOURCE_BODY_WIDTH stays as the fallback width before the flow lays out.
    body:SetWidth(RESOURCE_BODY_WIDTH)
    body:SetFlowFillRemaining(true)
    body:SetHeight(rowHeight)
    body:SetFlowOffset(contentOffsetX, contentOffsetY)
    body:SetLayout("List")
    body:SetListPadding(0, 1, 0, 0)
    body:SetListGap(2)

    local title = UI:Create("Label")
    title:SetText(resource.title)
    title:SetFullWidth(true)
    title:SetHeight(20)
    title:SetFontObject(GameFontNormal)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    if GSE.IsEllesmereUILoaded and GSE.IsEllesmereUILoaded() then
        title:SetColor(1, 1, 1, 1)
    else
        title:SetColor(unpack(RESOURCE_GOLD))
    end
    if title.text and title.text.SetWordWrap then title.text:SetWordWrap(false) end
    body:AddChild(title)

    local editBox = UI:Create("EditBox")
    editBox:SetCompactNoLabel(true)
    editBox:SetFullWidth(true)
    editBox:SetHeight(26)
    editBox:SetText(resource.url)
    PrepareResourceEditBox(editBox)
    body:AddChild(editBox)

    row:AddChild(body)

    local copyButton = UI:Create("Button")
    copyButton:SetText("Copy")
    copyButton:SetWidth(RESOURCE_COPY_WIDTH)
    copyButton:SetHeight(24)
    -- Pin Copy to the row's right edge. Right-aligned flow children skip the
    -- wrap check, so Copy can never spill onto the next row's icon. The body
    -- (flowFillRemaining) reserves this width, so the two never overlap. X
    -- offset is fixed (not contentOffsetX) so every row's Copy lines up.
    copyButton:SetFlowRightAlign(true)
    copyButton:SetFlowOffset(0, contentOffsetY + RESOURCE_COPY_OFFSET_Y)
    copyButton:SetCallback("OnClick", function() CopyResourceLink(editBox, resource.url) end)
    row:AddChild(copyButton)

    parent:AddChild(row)
end

local function ReleaseEditorFooterButtons(editframe)
    if editframe and editframe.SetFooterShown then editframe:SetFooterShown(false) end
end

local function PositionEditorFooterButtons(editframe)
    if editframe and editframe.SetFooterShown then editframe:SetFooterShown(true) end
end

-- Render the resource rows (and optional subtitle) into any AceGUI container.
-- Used by ShowResourcesPopup AND by the Settings panel's Resources canvas so
-- both surfaces present identical content from one source.
local function DrawResourcesContent(container, opts)
    if not (container and container.AddChild) then return end
    opts = opts or {}
    local showSubtitle = opts.showSubtitle
    if showSubtitle == nil then showSubtitle = true end

    if showSubtitle then
        local subtitle = UI:Create("Heading")
        subtitle:SetText("Copy and Paste Links")
        subtitle:SetFullWidth(true)
        subtitle:SetHeight(22)
        subtitle:SetFontObject(GameFontHighlightSmall)
        subtitle:SetJustifyH("CENTER")
        subtitle:SetJustifyV("MIDDLE")
        container:AddChild(subtitle)
    end

    for index, resource in ipairs(RESOURCE_LINKS) do
        CreateResourceRow(container, resource, index)
    end
end

GSE.GUI.DrawResourcesContent = DrawResourcesContent
-- Also expose the popup dimensions so external callers can size their own
-- container to match the popup's "as a group" footprint.
GSE.GUI.RESOURCE_FRAME_WIDTH  = RESOURCE_FRAME_WIDTH
GSE.GUI.RESOURCE_FRAME_HEIGHT = RESOURCE_FRAME_HEIGHT

local function ShowResourcesPopup(owner)
    if not resourcesFrame then
        resourcesFrame = UI:Create("Frame")
        resourcesFrame:SetTitle("Resources")
        resourcesFrame:SetSize(RESOURCE_FRAME_WIDTH, RESOURCE_FRAME_HEIGHT)
        resourcesFrame:SetLayout("List")
        -- Left/right content padding for THIS popup only (the editor/debugger
        -- windows are unaffected). 20 each side, restoring the earlier margin.
        resourcesFrame:SetListPadding(20, 12, 20, 8)
        resourcesFrame:SetListGap(8)
        resourcesFrame:SetResizable(false)
        -- TOOLTIP strata sits above the Blizzard Settings panel
        -- (FULLSCREEN_DIALOG); frameLevel 200 lifts the popup above other
        -- TOOLTIP-strata frames like the GSE menu so it isn't obscured.
        UI.MakePopup(resourcesFrame.frame, {frameLevel = 200})

        if resourcesFrame.titletext then
            SetResourceFrameTextColor(resourcesFrame.titletext, RESOURCE_GOLD)
        end

        DrawResourcesContent(resourcesFrame)
    end

    resourcesFrame:SetStatusText("GSE: " .. tostring(GSE.VersionString or ""))
    resourcesFrame:ClearAllPoints()
    -- Position the Resources popup near screen centre, nudged 15px right of
    -- centre, regardless of which frame opened it.
    resourcesFrame:SetPoint("CENTER", UIParent, "CENTER", 15, 0)
    resourcesFrame:Show()
    EnsureResourceVersionHitBox()
end

GSE.GUI.ShowResourcesPopup = ShowResourcesPopup

local function GetSequenceEditorOptions()
    if not GSEOptions then return nil end
    if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
    if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
        GSEOptions.frameLocations.sequenceeditor = {}
    end
    return GSEOptions.frameLocations.sequenceeditor
end

local function SequenceEditorPathExists(path)
    if GSE.isEmpty(path) then return false end
    local unique = {("\001"):split(path)}
    if unique[1] ~= "Sequences" or #unique < 4 then return false end

    local elements = GSE.split(unique[3] or "", ",")
    local classid = tonumber(elements[1])
    local sequenceName = elements[3]
    if not classid or GSE.isEmpty(sequenceName) then return false end
    if not (GSESequences and GSESequences[classid] and GSESequences[classid][sequenceName]) then return false end

    local key = unique[#unique]
    if key == "config" then return true end
    local version = tonumber(key)
    if not version then return false end

    GSE.EnsureSequenceLoaded(classid, sequenceName)
    local loadedSeq = GSE.Library[classid] and GSE.Library[classid][sequenceName]
    return loadedSeq and loadedSeq.Versions and loadedSeq.Versions[version] ~= nil
end

local function SaveLastSequenceEditorPath(group, unique)
    if unique[1] ~= "Sequences" or #unique < 4 or unique[#unique] == "newversion" then return end
    local opts = GetSequenceEditorOptions()
    if opts then opts.lastSequencePath = group end
end

function GSE.GUI.GetLastSequenceEditorPath()
    local opts = GetSequenceEditorOptions()
    local path = opts and opts.lastSequencePath
    if SequenceEditorPathExists(path) then return path end
    if opts then opts.lastSequencePath = nil end
    return nil
end

function GSE.GUI.SelectEditorTreePath(editor, path)
    if not (editor and editor.treeContainer and path) then return end
    editor.forceTreeSelection = true
    editor.treeContainer:SelectByValue(path)
end

-- ---------------------------------------------------------------------------
-- Right-click context menus, keyed by tree "area" (unique[1])
-- ---------------------------------------------------------------------------

local function onRightClick_KEYBINDINGS(editframe, container, group, unique)
    if #unique <= 3 then return end
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateButton(L["New KeyBind"], function()
                local rightContainer = UI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                editframe.showKeybind(nil, nil, nil, nil, "KB", rightContainer)
            end)
            rootDescription:CreateButton(L["New Actionbar Override"], function()
                local rightContainer = UI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                editframe.showKeybind(nil, nil, nil, nil, "AO", rightContainer)
            end)
            rootDescription:CreateButton(L["Delete"], function()
                local bind, specialization, loadout, kbtype
                kbtype = unique[2]
                specialization = unique[3]
                if GetSpecialization then
                    bind = unique[4]
                    if unique[6] then loadout = unique[6] end
                else
                    specialization = "1"
                    if unique[5] then
                        loadout = unique[5]
                        bind = unique[4]
                    else
                        loadout = unique[4]
                        bind = unique[3]
                    end
                end
                if kbtype == "KB" then
                    SetBinding(bind)
                    if loadout and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                    then
                        if GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] = nil
                        end
                        local empty = true
                        for _, _ in pairs(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) do
                            empty = false
                        end
                        if empty then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = nil
                        end
                    else
                        if GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                           GSE_C["KeyBindings"][tostring(specialization)][bind]
                        then
                            GSE_C["KeyBindings"][tostring(specialization)][bind] = nil
                        end
                    end
                elseif kbtype == "AO" then
                    if loadout and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                    then
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
                end
                editframe.ManageTree()
                GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, bind)
            end)
        end
    )
end

local function onRightClick_Sequences(editframe, container, group, unique, classid, sequencename)
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Sequence Editor"])
            rootDescription:CreateButton(L["New"], function()
                if editframe.loaded then
                    container:ReleaseChildren()
                    editframe.loaded = nil
                end
                local rightContainer = UI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                GSE.GUILoadEditor(editframe)
                container:AddChild(rightContainer)
            end)
            if not GSE.isEmpty(sequencename) then
                local rcSeq = GSE.FindSequence(sequencename)
                -- Protected/foreign content (noExport) is not owned by this user,
                -- so it cannot be copied — the Duplicate option is shown greyed out.
                local isProtected = rcSeq and rcSeq.MetaData and rcSeq.MetaData.noExport
                local dupButton = rootDescription:CreateButton(L["Duplicate"], function()
                    UI.ShowInputDialog({
                        owner      = editframe,
                        title      = L["Duplicate"],
                        prompt     = L["Enter NEW Name for the Duplicated Sequence:"],
                        note       = L["-sequence will receive a new gse.tools id-"],
                        default    = sequencename .. "Copy",
                        acceptText = L["Create"],
                        maxLetters = 60,
                        onAccept   = function(name)
                            GSE.GUIDuplicateSequence(editframe, classid, sequencename, name)
                        end,
                    })
                end)
                if dupButton and dupButton.SetEnabled then
                    dupButton:SetEnabled(not isProtected)
                end
                if not isProtected then
                    rootDescription:CreateButton(L["Export"], function()
                        GSE.GUIExport(classid, sequencename, "SEQUENCE")
                    end)
                end
                rootDescription:CreateButton(L["Send"], function()
                    GSE.GUIShowTransmissionGui(sequencename, editframe)
                end)
                if GSE.Patron then
                    rootDescription:CreateButton(
                        string.format(L["Open %s in New Window"], sequencename),
                        function()
                            local targetGroup = group
                            if unique[1] == "Sequences" and #unique == 3 then
                                targetGroup = group .. "\001config"
                            elseif unique[#unique] == "newversion" then
                                targetGroup = table.concat({unique[1], unique[2], unique[3], "config"}, "\001")
                            end

                            local editor = GSE.CreateEditor()
                            editor.ManageTree()
                            editor:Show()
                            C_Timer.After(0, function()
                                if GSE.GUI.SelectEditorTreePath then
                                    GSE.GUI.SelectEditorTreePath(editor, targetGroup)
                                end
                            end)
                        end
                    )
                end
                rootDescription:CreateButton(L["Chat Link"], function()
                    GSE.UI.ShowLinkDialog({
                        owner      = editframe,
                        title      = L["Chat Link"],
                        prompt     = L["Copy this Link and Paste into a Chat Window."],
                        link       = GSE.SequenceChatPattern(sequencename, classid),
                        buttonText = CLOSE,
                        note       = L["Text selected. Press Ctrl+C to Copy"],
                    })
                end)
            end
            rootDescription:CreateButton(L["Keybindings"], function()
                GSE.ShowKeyBindings()
            end)
            if not GSE.isEmpty(sequencename) then
                rootDescription:CreateButton(L["Delete"], function()
                    editframe.GUIDeleteSequence(classid, sequencename)
                end)
            end
        end
    )
end

local function onRightClick_VARIABLES(editframe, container, group, unique, key)
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Manage Variables"])
            local varOk, varDecoded = GSE.DecodeMessage(GSEVariables[key])
            if not (varOk and varDecoded and varDecoded.MetaData and varDecoded.MetaData.noExport) then
                rootDescription:CreateButton(L["Export Variable"], function()
                    GSE.GUIExport(nil, key, "VARIABLE")
                end)
            end
            rootDescription:CreateButton(L["Delete"], function()
                GSE.DeleteVariable(key)
                editframe.ManageTree()
            end)
        end
    )
end

-- ---------------------------------------------------------------------------
-- Left-click handlers, keyed by area
-- ---------------------------------------------------------------------------

local SECTION_HEADER_HEIGHT  = 40   -- space above the grey line
local SECTION_HEADER_LEFT    = 10   -- right shift
local SECTION_ICON_SIZE      = 28   -- icon size
local SECTION_FONT_HEIGHT    = 30   -- text row height
local SECTION_HEADER_TOP     = 10   -- container top padding for any grey-line section header

local function addSectionDivider(container, title, icon)
    if title then
        -- Account for container top padding so content centres in the full visible space
        local containerTop = GSE.GUI.CONTENT_PADDING or 20
        local totalSpace   = containerTop + SECTION_HEADER_HEIGHT
        local top = math.max(0, math.floor(totalSpace / 2 - SECTION_FONT_HEIGHT / 2) - containerTop)

        local headerRow = UI:Create("SimpleGroup")
        headerRow:SetFullWidth(true)
        headerRow:SetHeight(SECTION_HEADER_HEIGHT)
        headerRow:SetLayout("Flow")
        if headerRow.SetFlowGap     then headerRow:SetFlowGap(10) end
        if headerRow.SetFlowPadding then headerRow:SetFlowPadding(SECTION_HEADER_LEFT, top, 0, 0) end

        if icon then
            local titleIcon = UI:Create("Icon")
            titleIcon:SetImage(icon)
            titleIcon:SetImageSize(SECTION_ICON_SIZE, SECTION_ICON_SIZE)
            if titleIcon.SetHoverImageSize then titleIcon:SetHoverImageSize(SECTION_ICON_SIZE, SECTION_ICON_SIZE) end
            titleIcon:SetWidth(SECTION_ICON_SIZE + 2)
            titleIcon:SetHeight(SECTION_FONT_HEIGHT)
            if titleIcon.SetHoverLocked then titleIcon:SetHoverLocked(true) end
            headerRow:AddChild(titleIcon)
        end

        local heading = UI:Create("Heading")
        heading:SetText(title)
        heading:SetWidth(400)
        heading:SetHeight(SECTION_FONT_HEIGHT)
        if heading.SetJustifyH then heading:SetJustifyH("LEFT") end
        if heading.SetJustifyV then heading:SetJustifyV("MIDDLE") end
        if heading.SetColor    then heading:SetColor(1, 1, 1, 1) end
        if heading.frame then
            local fs = heading.frame.GetFontString and heading.frame:GetFontString()
            if not fs then fs = heading.label or heading.text end
            if fs and fs.SetFont then
                local face, size, flags = GameFontNormalHuge:GetFont()
                if face then fs:SetFont(face, size or 16, flags) end
            end
        end
        headerRow:AddChild(heading)
        container:AddChild(headerRow)
    end

    local divider = UI:Create("SimpleGroup")
    divider:SetFullWidth(true)
    divider:SetHeight(1)
    local line = divider.frame and divider.frame:CreateTexture(nil, "ARTWORK")
    if line then
        line:SetAllPoints(divider.frame)
        line:SetColorTexture(1, 1, 1, 0.22)
    end
    container:AddChild(divider)
end


-- Add a scrollable content area as a child of the tree-group's right pane
-- and return the inner ScrollFrame for callers to add page content into.
-- This is used by the Variables / Macros / Keybindings click handlers — none
-- of which had a scroll wrapper before. With MIN_EDITOR_HEIGHT now 500 (was
-- 800), their content can easily exceed the visible height; adding the
-- scroll here keeps everything reachable. Sequences already has its own
-- staticHeader+scrollcontainer pattern in onClick_Sequences so it isn't
-- routed through this helper.
local function makeScrollableRightPane(container)
    -- Outer Fill wrapper takes the whole right pane.
    local outer = UI:Create("SimpleGroup")
    outer:SetFullWidth(true)
    outer:SetFullHeight(true)
    outer:SetLayout("Fill")

    -- ScrollFrame inside the wrapper holds the page content. AceGUI's
    -- ScrollFrame uses List layout for children by default and engages
    -- scrollbars automatically when content height exceeds the frame.
    local scroll = UI:Create("ScrollFrame")
    if scroll.SetScrollStep  then scroll:SetScrollStep(96) end
    if scroll.SetListPadding then
        scroll:SetListPadding(CONFIG_CONTENT_LEFT_PADDING, SECTION_HEADER_TOP, CONFIG_CONTENT_LEFT_PADDING, CONFIG_CONTENT_LEFT_PADDING)
    end
    outer:AddChild(scroll)
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)

    container:AddChild(outer)
    SmoothEditorScrollFrame(scroll)
    return scroll
end


-- ---------------------------------------------------------------------------
-- InitEditorFooterButtons(editframe)
-- Creates footer buttons ONCE and registers them with AddFooterChild.
-- Guarded by editframe.footerInitialized so repeat calls are no-ops.
-- onClick_Sequences must NEVER call AddFooterChild itself — only SetFooterShown.
-- ---------------------------------------------------------------------------
local function InitEditorFooterButtons(editframe)
    if editframe.footerInitialized then return end
    editframe.footerInitialized = true

    local editOptionsbutton = UI:Create("Button")
    editOptionsbutton:SetText(L["Options"])
    editOptionsbutton:SetWidth(100)
    if editOptionsbutton.SetElvUIBackgroundShown then editOptionsbutton:SetElvUIBackgroundShown(true) end
    editOptionsbutton:SetCallback("OnClick", function() GSE.OpenOptionsPanel(editframe) end)
    editOptionsbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Options"], L["Opens the GSE Options window"], editframe)
    end)
    editOptionsbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local resourcesButton = UI:Create("Button")
    resourcesButton:SetText(RESOURCE_BUTTON_TEXT)
    resourcesButton:SetWidth(RESOURCE_BUTTON_WIDTH)
    if resourcesButton.SetElvUIBackgroundShown then resourcesButton:SetElvUIBackgroundShown(true) end
    resourcesButton:SetCallback("OnClick", function() GSE.GUI.ShowResourcesPopup(editframe) end)
    resourcesButton:SetCallback("OnEnter", function()
        GSE.CreateToolTip("Resources", "All GSE Support, Tools, Sequences, Community, Patreon Links.", editframe)
    end)
    resourcesButton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local transbutton = UI:Create("Button")
    transbutton:SetText(L["Send"])
    transbutton:SetWidth(100)
    if transbutton.SetElvUIBackgroundShown then transbutton:SetElvUIBackgroundShown(true) end
    transbutton:SetCallback("OnClick", function()
        GSE.GUIShowTransmissionGui(editframe.ClassID .. "," .. editframe.SequenceName, editframe)
    end)
    transbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(
            L["Send"],
            L["Send this macro to another GSE player who is on the same server as you are."],
            editframe
        )
    end)
    transbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local savebutton = UI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(100)
    if savebutton.SetElvUIBackgroundShown then savebutton:SetElvUIBackgroundShown(true) end
    savebutton:SetCallback(
        "OnClick",
        function()
            if editframe.RefreshMacroLimitSaveState and not editframe:RefreshMacroLimitSaveState() then
                GSE.Print(
                    L["One or more MacroBlocks are over 255 characters. Shorten them before saving."],
                    "ERROR"
                )
                return
            end
            if GSE.isEmpty(editframe.invalidPause) then
                local _, _, _, tocversion = GetBuildInfo()
                editframe.Sequence.MetaData.ManualIntervention = true
                editframe.Sequence.MetaData.GSEVersion = GSE.VersionNumber
                editframe.Sequence.MetaData.EnforceCompatability = true
                editframe.Sequence.MetaData.TOC = tocversion
                editframe.SequenceName = GSE.UnEscapeString(editframe.SequenceName or "")
                editframe.save = true
                ReportMacroOptionWarningsForSequence(editframe.Sequence)
                local queued = editframe.GUIUpdateSequenceDefinition(
                    editframe.ClassID,
                    editframe.SequenceName,
                    editframe.Sequence
                )
                if queued then
                    if GSE.ProcessOOCQueue and not (InCombatLockdown and InCombatLockdown()) then
                        C_Timer.After(0, function()
                            if not (InCombatLockdown and InCombatLockdown()) then
                                GSE:ProcessOOCQueue()
                            end
                        end)
                    end
                    editframe:SetStatusText(L["Save pending for "] .. editframe.SequenceName)
                    editframe.newname = nil
                else
                    editframe.save = nil
                end
            else
                GSE.Print(
                    L["Error processing Custom Pause Value.  You will need to recheck your macros."],
                    "ERROR"
                )
            end
        end
    )
    savebutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Save"], L["Save the changes made to this macro"], editframe)
    end)
    savebutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    editframe.SaveButton = savebutton

    -- Export reads editframe.ClassID / editframe.SequenceName at click time so it
    -- always reflects the currently-loaded sequence, not a stale init-time closure.
    local exportbutton = UI:Create("Button")
    exportbutton:SetText(L["Export"])
    exportbutton:SetWidth(100)
    if exportbutton.SetElvUIBackgroundShown then exportbutton:SetElvUIBackgroundShown(true) end
    exportbutton:SetCallback("OnClick", function()
        local sequence = GSE.FindSequence and GSE.FindSequence(editframe.SequenceName)
        if sequence and sequence.MetaData and sequence.MetaData.noExport then
            if editframe.SetStatusText then editframe:SetStatusText(L["This sequence is unable to be exported."]) end
            return
        end
        GSE.GUIExport(editframe.ClassID, editframe.SequenceName, "SEQUENCE")
    end)
    exportbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Export"], L["Export this sequence."], editframe)
    end)
    exportbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local debugbutton = UI:Create("Button")
    debugbutton:SetText(L["Debug"])
    debugbutton:SetWidth(100)
    if debugbutton.SetElvUIBackgroundShown then debugbutton:SetElvUIBackgroundShown(true) end
    debugbutton:SetCallback("OnClick", function()
        if GSE.GUIDebugFrame and GSE.GUIDebugFrame.IsShown and GSE.GUIDebugFrame:IsShown() then
            if GSE.GUICloseDebugWindow then
                GSE.GUICloseDebugWindow()
            else
                GSE.GUIDebugFrame:Hide()
            end
            return
        end
        if GSE.GUIShowDebugWindow then GSE.GUIShowDebugWindow() end
    end)
    debugbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Debug"], L["Open or close the sequence debugger."], editframe)
    end)
    debugbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local reloadbutton = UI:Create("Button")
    reloadbutton:SetText(L["Reload"])
    reloadbutton:SetWidth(100)
    if reloadbutton.SetElvUIBackgroundShown then reloadbutton:SetElvUIBackgroundShown(true) end
    reloadbutton:SetCallback("OnClick", function()
        if ReloadUI then ReloadUI() end
    end)
    reloadbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Reload"], L["Reload the user interface."], editframe)
    end)
    reloadbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local delbutton = UI:Create("Button")
    delbutton:SetText(L["Delete Sequence"])
    delbutton:SetWidth(130)
    if delbutton.SetElvUIBackgroundShown then delbutton:SetElvUIBackgroundShown(true) end
    delbutton:SetCallback("OnClick", function()
        local seqname = editframe.SequenceName
        local cid = editframe.ClassID
        editframe.GUIDeleteSequence(cid, seqname)
        editframe.ManageTree()
    end)
    delbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Delete Sequence"], L["Delete this sequence.  This is not able to be undone."], editframe)
    end)
    delbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    editframe.PositionEditorFooterButtons = PositionEditorFooterButtons
    if editframe.SetFooterHeight then editframe:SetFooterHeight(52) end
    if editframe.SetFooterBottomOffset then editframe:SetFooterBottomOffset(30) end
    if editframe.SetFooterContentGap then editframe:SetFooterContentGap(6) end
    if editframe.SetFooterGap then editframe:SetFooterGap(EDITOR_FOOTER_BUTTON_GAP) end
    if editframe.SetFooterRowGap then editframe:SetFooterRowGap(4) end
    if editframe.SetFooterAlignment then editframe:SetFooterAlignment("CENTER") end
    -- Reset to a fresh table so AddFooterChild never inserts into sectionFooterChildrenCache
    -- if ShowSectionFooter ran before this initializer.
    editframe.footerChildren = {}
    if editframe.AddFooterChild then
        editframe:AddFooterChild(savebutton, 1)
        editframe:AddFooterChild(delbutton, 1)
        editframe:AddFooterChild(exportbutton, 1)
        editframe:AddFooterChild(editOptionsbutton, 1)
        editframe:AddFooterChild(resourcesButton, 1)
        editframe:AddFooterChild(transbutton, 2)
        editframe:AddFooterChild(reloadbutton, 2)
        editframe:AddFooterChild(debugbutton, 2)
    end
    -- Cache the sequence button set so ShowSequenceFooter / ShowSectionFooter
    -- can swap footerChildren without ever creating or destroying widgets.
    editframe.sequenceFooterChildrenCache = editframe.footerChildren
end

-- ---------------------------------------------------------------------------
-- InitSectionFooterButtons(editframe)
-- Creates the section-page footer (Resources button, centered) ONCE.
-- Guarded by editframe.sectionFooterInitialized.
-- ---------------------------------------------------------------------------
local function InitSectionFooterButtons(editframe)
    if editframe.sectionFooterInitialized then return end
    editframe.sectionFooterInitialized = true

    local resourcesButton = UI:Create("Button")
    resourcesButton:SetText(RESOURCE_BUTTON_TEXT)
    resourcesButton:SetWidth(RESOURCE_BUTTON_WIDTH)
    if resourcesButton.SetElvUIBackgroundShown then resourcesButton:SetElvUIBackgroundShown(true) end
    resourcesButton:SetCallback("OnClick", function() GSE.GUI.ShowResourcesPopup(editframe) end)
    resourcesButton:SetCallback("OnEnter", function()
        GSE.CreateToolTip("Resources", "All GSE Support, Tools, Sequences, Community, Patreon Links.", editframe)
    end)
    resourcesButton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    -- Register directly with the footer frame so layoutFooterChildren can position it,
    -- but store in a SEPARATE cache — never mixed into sequenceFooterChildrenCache.
    resourcesButton.footerRow = 1
    resourcesButton.parent = editframe
    if editframe.footer and resourcesButton.frame then
        resourcesButton.frame:SetParent(editframe.footer)
    end
    editframe.sectionFooterChildrenCache = { resourcesButton }
end

-- ---------------------------------------------------------------------------
-- ShowSequenceFooter / ShowSectionFooter
-- Swap footerChildren between the two cached sets, then trigger layout.
-- NEVER call AddFooterChild after init — that appends and causes duplicates.
-- ---------------------------------------------------------------------------
local function HideFooterCache(cache)
    if not cache then return end
    for _, child in ipairs(cache) do
        if child.frame then child.frame:Hide() end
    end
end

local function ShowSequenceFooter(editframe)
    InitEditorFooterButtons(editframe)
    HideFooterCache(editframe.sectionFooterChildrenCache)
    editframe.footerChildren = editframe.sequenceFooterChildrenCache
    if editframe.SetFooterShown then editframe:SetFooterShown(true) end
    if editframe.DoFooterLayout then editframe:DoFooterLayout() end
end

local function ShowSectionFooter(editframe)
    InitSectionFooterButtons(editframe)
    HideFooterCache(editframe.sequenceFooterChildrenCache)
    editframe.footerChildren = editframe.sectionFooterChildrenCache
    if editframe.SetFooterHeight then editframe:SetFooterHeight(52) end
    if editframe.SetFooterBottomOffset then editframe:SetFooterBottomOffset(30) end
    if editframe.SetFooterContentGap then editframe:SetFooterContentGap(6) end
    if editframe.SetFooterGap then editframe:SetFooterGap(EDITOR_FOOTER_BUTTON_GAP) end
    if editframe.SetFooterRowGap then editframe:SetFooterRowGap(4) end
    if editframe.SetFooterAlignment then editframe:SetFooterAlignment("CENTER") end
    if editframe.SetFooterShown then editframe:SetFooterShown(true) end
    if editframe.DoFooterLayout then editframe:DoFooterLayout() end
end

local function onClick_KEYBINDINGS(editframe, container, group, unique)
    if not unique or #unique < 2 then return end
    ShowSectionFooter(editframe)

    local bind, loadout, kbtype, button
    kbtype = unique[2]
    local specialization = unique[3]
    -- Use the same API check as buildKeybindMenu: GetSpecializationInfo determines
    -- whether a spec-level intermediate node was inserted into the tree.
    if GetSpecializationInfo then
        bind = unique[4]
        if #unique == 6 then
            loadout = unique[4]
            bind = unique[5]
            if unique[2] == "AO" and bind then
                button = GSE_C["ActionBarBinds"]["LoadOuts"][specialization][loadout][bind]
            else
                button = unique[6]
            end
        else
            if unique[2] == "AO" and bind then
                local aoSpecs = GSE_C["ActionBarBinds"]["Specialisations"]
                button = aoSpecs and aoSpecs[specialization] and aoSpecs[specialization][bind]
            else
                button = unique[5]
            end
        end
    else
        specialization = "1"
        bind = unique[3]
        button = unique[4]
        if kbtype == "AO" and bind then
            local aoSpecs = GSE_C["ActionBarBinds"]["Specialisations"]
            button = aoSpecs and aoSpecs[specialization] and aoSpecs[specialization][bind]
        end
    end

    local function makeRightContainer(withDivider)
        -- Build a scrollable wrapper inside the right pane. The scroll engages
        -- automatically if the keybind form (which can include many rows for
        -- spec + button combinations) exceeds the editor's visible height.
        local rc = makeScrollableRightPane(container)
        if withDivider then
            addSectionDivider(rc, withDivider.title, withDivider.icon)
        end
        return rc
    end

    if unique[#unique] == "SKYRIDING" then
        if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
        local rc = makeRightContainer()
        if GSE.DrawSkyridingKeybindEditor then
            GSE.DrawSkyridingKeybindEditor(rc)
        end
        editframe.loaded = true
        editframe:SetTitle("GSE: " .. (L["Keybindings"] or "Keybindings") .. ": " .. (L["Skyriding / Vehicle Keybinds"] or "Skyriding"))
    elseif unique[#unique] == "NKB" then
        if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
        local rc = makeRightContainer({title = L["Keybindings"] or "Keybindings", icon = Statics.Icons.Keybindings})
        editframe.showKeybind(nil, nil, nil, nil, "KB", rc)
        editframe.loaded = true
        editframe:SetTitle("GSE: " .. (L["Keybindings"] or "Keybindings") .. ": " .. (L["New KeyBind"] or "New Keybind"))
    elseif unique[#unique] == "NAO" then
        if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
        local rc = makeRightContainer({title = L["Actionbar Overrides"] or "Actionbar Overrides", icon = Statics.Icons.Button})
        editframe.showKeybind(nil, nil, nil, nil, "AO", rc)
        editframe.loaded = true
        editframe:SetTitle("GSE: " .. (L["Actionbar Overrides"] or "Actionbar Overrides") .. ": " .. (L["New Actionbar Override"] or "New Override"))
    else
        if bind and button and kbtype then
            if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
            local rc = makeRightContainer()
            editframe.showKeybind(bind, button, specialization, loadout, kbtype, rc)
            editframe.loaded = true
            editframe:SetTitle("GSE: " .. (L["Keybindings"] or "Keybindings") .. ": " .. (bind or L["Keybind"] or "Keybind"))
        end
    end
end

local function onClick_Sequences(editframe, container, group, unique, path, key, classid, sequencename)
    if #unique < 3 then return end
    SaveLastSequenceEditorPath(group, unique)
    ReleaseEditorFooterButtons(editframe)

    -- The native widget layer has no widget pool, so stale child frames must be
    -- cleared even if a prior draw failed before setting loaded.
    container:ReleaseChildren()
    editframe.loaded = nil

    -- Helper that returns the right pane's actual usable height. Querying
    -- the AceGUI container's content frame gives us a number that matches
    -- the real visible area regardless of which frame template the editor
    -- uses (ButtonFrameTemplate on retail = ~70 px chrome; BasicFrameTemplate
    -- WithInset on MoP / Classic = ~85-95 px chrome). A fixed offset can't
    -- satisfy both; the prior 70 worked on retail but cut MoP content off.
    -- The PANE_BOTTOM_MARGIN trims inner-pane padding so the content frame
    -- doesn't overflow the editor's bottom chrome (sub-panels were rendering
    -- ~20 px past the visible area before this margin was applied).
    local PANE_BOTTOM_MARGIN = 20
    local function getScrollAreaHeight()
        local pane = (container and container.content) or (container and container.frame)
        if pane and pane.GetHeight then
            local h = pane:GetHeight()
            if h and h > 100 then return math.max(80, h - PANE_BOTTOM_MARGIN) end
        end
        -- Conservative fallback (slightly larger than the old -70 so MoP
        -- doesn't clip if the query fails entirely).
        return math.max(80, (editframe.Height or 760) - 85 - PANE_BOTTOM_MARGIN)
    end
    editframe.GetScrollAreaHeight = getScrollAreaHeight

    local basecontainer = UI:Create("SimpleGroup")
    basecontainer:SetLayout("List")
    basecontainer:SetFullWidth(true)
    basecontainer:SetHeight(getScrollAreaHeight())
    local staticHeaderContainer = UI:Create("SimpleGroup")
    staticHeaderContainer:SetFullWidth(true)
    staticHeaderContainer:SetHeight(0)
    staticHeaderContainer:SetLayout("List")

    local scrollcontainer = UI:Create("SimpleGroup")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetHeight(getScrollAreaHeight())
    scrollcontainer:SetLayout("Fill")
    editframe.scrollStatus = {}
    local contentcontainer = UI:Create("ScrollFrame")
    if contentcontainer.SetScrollStep then contentcontainer:SetScrollStep(96) end
    scrollcontainer:AddChild(contentcontainer)
    contentcontainer:SetFullWidth(true)
        contentcontainer:SetFullHeight(true)
        contentcontainer:SetStatusTable(editframe.scrollStatus)
    editframe.scroller = scrollcontainer
    editframe.scrollContainer = contentcontainer
    editframe.staticHeaderContainer = staticHeaderContainer
    editframe.baseContainer = basecontainer   -- needed by OnSizeChanged to update height on resize
    editframe.staticHeaderHeight = 0
    editframe.SetStaticHeaderHeight = function(_, height)
        height = tonumber(height) or 0
        editframe.staticHeaderHeight = height
        staticHeaderContainer:SetHeight(height)
        scrollcontainer:SetHeight(math.max(80, getScrollAreaHeight() - height))
        if contentcontainer.DoLayout then contentcontainer:DoLayout() end
        if scrollcontainer.DoLayout then scrollcontainer:DoLayout() end
        if basecontainer.DoLayout then basecontainer:DoLayout() end
    end
    SmoothEditorScrollFrame(contentcontainer)
    container:AddChild(basecontainer)
    basecontainer:AddChild(staticHeaderContainer)
    basecontainer:AddChild(scrollcontainer)
    editframe.SequenceName = sequencename

    -- Navigate to sequence-level node -> auto-select config.
    -- Defer SelectByValue to the next frame so that Button_OnClick's Expand_OnClick
    -- fires on the still-valid frame before RefreshTree recycles the button pool.
    if unique[1] == "Sequences" and #unique == 3 then
        C_Timer.After(0, function()
            container:ReleaseChildren()
            editframe.treeContainer:SelectByValue(group .. "\001config")
        end)
        return
    elseif key == "config" then
        if editframe.staticHeaderContainer then editframe.staticHeaderContainer:ReleaseChildren() end
        if editframe.SetStaticHeaderHeight then editframe:SetStaticHeaderHeight(0) end
        -- Pull content flush to the top of the content pane for config
        if container.SetListPadding then container:SetListPadding(0, 0, 0, 0) end
        if editframe.OrigSequenceName ~= sequencename then
            GSE.GUILoadEditor(editframe, path[#path])
        end
        local treeWidth = editframe.treeContainer and editframe.treeContainer.GetTreeWidth and editframe.treeContainer:GetTreeWidth() or 0
        -- Chrome allowance (editor borders + scrollbar) is ~50, not 80; the extra 30
        -- left the content container narrower than its pane, padding the right side.
        local configContentWidth = math.max(620, (editframe.Width or 800) - treeWidth - 50)
        editframe.metadataContentWidth = configContentWidth
        if contentcontainer.SetWidth then contentcontainer:SetWidth(configContentWidth) end
        if contentcontainer.SetListGap then contentcontainer:SetListGap(2) end
        editframe.GUIDrawMetadataEditor(contentcontainer)
        editframe.metadataContentWidth = nil
        -- Apply padding AFTER draw — GUIDrawMetadataEditor resets it internally
        -- Match GUIDrawMetadataEditor's own padding exactly (Editor_Metadata line ~896:
        -- left=right=30, top=15) so the area stays put and left/right padding are equal
        -- whether drawn here on entry or re-drawn on tab switch.
        if contentcontainer.SetListPadding then contentcontainer:SetListPadding(CONFIG_CONTENT_LEFT_PADDING + 10, 15, CONFIG_CONTENT_LEFT_PADDING + 10, CONFIG_CONTENT_LEFT_PADDING + 10) end
        if contentcontainer.DoLayout then contentcontainer:DoLayout() end
        editframe:SetTitle(L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["Configuration"] .. ")")
        ShowSequenceFooter(editframe)   -- full editor buttons (Save/Delete/Export/...) on the config page
        if editframe.RefreshMacroLimitSaveState then editframe:RefreshMacroLimitSaveState() end
    elseif key == "newversion" then
        if editframe.OrigSequenceName ~= sequencename then
            GSE.GUILoadEditor(editframe, path[#path])
        end
        ShowSequenceFooter(editframe)
        if editframe.RefreshMacroLimitSaveState then editframe:RefreshMacroLimitSaveState() end
        table.insert(
            editframe.Sequence.Versions,
            GSE.CloneSequence(editframe.Sequence.Versions[editframe.Sequence.MetaData.Default])
        )
        editframe.GUIDrawMacroEditor(contentcontainer, #editframe.Sequence.Versions, table.concat(path, "\001"))
        editframe:SetTitle(
            L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["New"] .. " " .. L["Version"] .. ")"
        )
    else
        if editframe.OrigSequenceName ~= sequencename then
            GSE.GUILoadEditor(editframe, path[#path])
        end
        if container.SetListPadding then container:SetListPadding(nil, nil, nil, nil) end
        ShowSequenceFooter(editframe)
        if editframe.RefreshMacroLimitSaveState then editframe:RefreshMacroLimitSaveState() end
        editframe.GUIDrawMacroEditor(contentcontainer, key, table.concat(path, "\001"))
        local version = editframe.Sequence and editframe.Sequence.Versions and editframe.Sequence.Versions[tonumber(key) or key]
        local versionName = version and version.Label
        if GSE.isEmpty(versionName) then
            versionName = tostring(key) == "1" and L["Default"] or L["Version"]
        end
        editframe:SetTitle(
            L["Sequence Editor"] .. ": " .. sequencename .. " (v" .. key .. ":" .. versionName .. ")"
        )
    end
    -- All onClick_Sequences pages (config + versions) now use the full editor
    -- footer, so position the buttons on every path.
    PositionEditorFooterButtons(editframe)
    editframe.loaded = true
end

local function onClick_VARIABLES(editframe, container, group, unique, key)
    if #unique <= 1 then return end
    ShowSectionFooter(editframe)
    if key == "NEWVARIABLES" then
        GSE.GUINewVariablePrompt(editframe)
        return
    end
    if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
    -- Wrap the variable form in a ScrollFrame so it remains reachable when
    -- the editor is sized small. Padding is set on the inner scroll pane,
    -- so we no longer need it on the outer container.
    local scrollPane = makeScrollableRightPane(container)
    addSectionDivider(scrollPane, L["Variables"] or "Variables", Statics.Icons.Variables)
    editframe:SetTitle("GSE: " .. (L["Variables"] or "Variables") .. ": " .. (key or ""))
    editframe.showVariable(key, scrollPane)
    editframe.loaded = true
end

local function getFirstMacroPath(scope)
    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    local function findInRange(parent, firstSlot, lastSlot)
        for macid = firstSlot, lastSlot do
            local mname = GetMacroInfo(macid)
            if mname then return "Macro\001" .. parent .. "\001" .. macid end
        end
    end

    if scope == "A" then
        return findInRange("A", 1, MAX_ACCOUNT_MACROS)
    elseif scope == "P" then
        return findInRange("P", MAX_ACCOUNT_MACROS + 1, maxmacros)
    end

    return findInRange("A", 1, MAX_ACCOUNT_MACROS) or findInRange("P", MAX_ACCOUNT_MACROS + 1, maxmacros)
end

local function onClick_Macro(editframe, container, group, unique, key)
    if #unique < 3 then
        local firstMacroPath = getFirstMacroPath(unique[2])
        if firstMacroPath then editframe.treeContainer:SelectByValue(firstMacroPath) end
        return
    end
    if #unique ~= 3 then return end
    ShowSectionFooter(editframe)
    local mtext
    local macroID = tonumber(key)
    if not macroID then return end
    local mname, micon, matext = GetMacroInfo(macroID)
    if not mname then return end
    if unique[2] == "A" then
        if GSEMacros[mname] and GSEMacros[mname].text then
            mtext = GSEMacros[mname].text
        else
            mtext = matext
        end
    else
        local char, realm = UnitFullName("player")
        if GSEMacros[char .. "-" .. realm] and GSEMacros[char .. "-" .. realm][mname] and
           GSEMacros[char .. "-" .. realm][mname].text
        then
            mtext = GSEMacros[char .. "-" .. realm][mname].text
        else
            mtext = matext
        end
    end
    local node = {
        value = macroID,
        name = mname,
        icon = micon,
        text = mtext
    }
    if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
    -- Scroll wrapper keeps the macro view (header + buttons + edit box) usable
    -- when the editor frame is sized small.
    local scrollPane = makeScrollableRightPane(container)
    editframe:SetTitle("GSE: " .. (L["Macros"] or "Macros") .. ": " .. (mname or ""))
    editframe.showMacro(node, scrollPane)
    editframe.loaded = true
end

-- ---------------------------------------------------------------------------
-- ManageTree(editframe)
-- Builds the full sequence tree and wires up OnGroupSelected.
-- ---------------------------------------------------------------------------
local function ManageTree(editframe)
    local treeContainer = editframe.treeContainer

    -- Build sequence sub-tree
    local tree = {
        {
            value = "NewSequence",
            text = L["New Sequence"],
            icon = Statics.ActionsIcons.Add
        },
        {
            value = "Import",
            text = L["Import"],
            icon = Statics.Icons.Import
        }
    }

    local classtree = {}
    local names = GSE.GetSequenceNames()

    for k, _ in GSE.pairsByKeys(names, GSE.AlphabeticalTableSortAlgorithm) do
        local elements = GSE.split(k, ",")
        local tclassid = tonumber(elements[1])
        local specid = tonumber(elements[2])
        if tclassid and GSE.isEmpty(classtree[tclassid]) then
            classtree[tclassid] = {}
        end
        if specid and GSE.isEmpty(classtree[tclassid][specid]) then
            classtree[tclassid][specid] = {}
        end
        local node = {
            value = k,
            text = elements[3],
            children = {
                {
                    text = L["Configuration"],
                    value = "config",
                    icon = Statics.ActionsIcons.Settings
                }
            }
        }

        local id, _, _, sicon = GetSpecializationInfoForSpecID(specid)
        if id then
            node.icon = sicon
        else
            node.icon = GSE.GetClassIcon(tclassid)
        end

        GSE.EnsureSequenceLoaded(tclassid, elements[3])
        local loadedSeq = GSE.Library[tclassid] and GSE.Library[tclassid][elements[3]]
        if loadedSeq then
            for i, j in ipairs(loadedSeq["Versions"]) do
                table.insert(node.children, {
                    value = i,
                    text = editframe.BuildVersionLabel(tostring(i), j.Label)
                })
            end
        end
        table.insert(node.children, {
            text = L["New"] .. " " .. L["Version"],
            value = "newversion",
            icon = Statics.ActionsIcons.Add
        })
        table.insert(classtree[tclassid][specid], node)
    end

    local subtree = {
        value = "Sequences",
        text = L["Sequences"],
        icon = Statics.Icons.Sequences,
        children = {}
    }
    for k, v in pairs(classtree) do
        local tnode = {}
        if k > 0 then
            local classinfo, classfile = GetClassInfo(k)
            local text =
                C_ClassColor and
                WrapTextInColorCode(classinfo, C_ClassColor.GetClassColor(classfile):GenerateHexColor()) or
                classinfo
            tnode = {
                value = k,
                text = text,
                icon = GSE.GetClassIcon(k),
                children = {}
            }
        elseif k == 0 then
            tnode = {
                value = "GLOBAL",
                text = L["Global"],
                children = {}
            }
        end
        for _, j in pairs(v) do
            for _, h in ipairs(j) do
                table.insert(tnode.children, h)
            end
        end
        table.insert(subtree.children, tnode)
    end

    table.insert(tree, subtree)
    table.insert(tree, editframe.buildKeybindMenu())
    table.insert(tree, editframe.buildVariablesMenu())
    table.insert(tree, editframe.buildMacroMenu())

    treeContainer:SetTree(tree)
    treeContainer:SetCallback(
        "OnClick",
        function(container, event, group)
            if group == "Import" and GSE.ShowImport then
                GSE.ShowImport()
            end
        end
    )
    treeContainer:SetCallback(
        "OnButtonDrop",
        function(container, event, srcValue, dstValue)
            -- Parse the uniquevalue paths (segments separated by \001)
            local srcParts = {("\001"):split(srcValue)}
            local dstParts = {("\001"):split(dstValue)}

            -- Both must be Sequences > class > sequence > numeric version index
            if srcParts[1] ~= "Sequences" or dstParts[1] ~= "Sequences" then return end
            if #srcParts ~= 4 or #dstParts ~= 4 then return end

            local srcIdx = tonumber(srcParts[4])
            local dstIdx = tonumber(dstParts[4])
            -- config ("config") and New Version ("newversion") are non-numeric; reject them
            if not srcIdx or not dstIdx or srcIdx == dstIdx then return end

            -- Must be the same sequence node (srcParts[2] and [3] must match dstParts)
            if srcParts[2] ~= dstParts[2] or srcParts[3] ~= dstParts[3] then return end

            -- Resolve classid and sequence name from the sequence key "classid,specid,name"
            local elements = GSE.split(srcParts[3], ",")
            local classid = tonumber(elements[1])
            local seqname = elements[3]
            if not classid or not seqname then return end

            -- Resolve classid and sequence name from the sequence key "classid,specid,name"
            -- GUILoadEditor decodes a fresh copy into editframe.Sequence, separate from
            -- GSE.Library.  We must modify editframe.Sequence (the working copy the Save
            -- button will persist) rather than auto-saving — reorder is a pending edit.
            -- We also update the Library copy so ManageTree() shows the new order in the
            -- tree (Library is an in-memory display cache; GSESequences is only written
            -- on explicit Save).
            local isLoadedSeq = tostring(editframe.ClassID) == tostring(classid)
                and editframe.SequenceName == seqname
                and not GSE.isEmpty(editframe.Sequence)

            if not isLoadedSeq then return end  -- only reorder the currently open sequence

            local seq = editframe.Sequence
            if not seq.Versions then return end
            local vers = seq.Versions
            if srcIdx < 1 or srcIdx > #vers or dstIdx < 1 or dstIdx > #vers then return end

            -- Capture the current tree selection so we can restore it after the reorder.
            local treeStatus = container.status or container.localstatus
            local currentSelected = treeStatus and treeStatus.selected

            -- Reorder: remove source and insert at destination
            local moved = table.remove(vers, srcIdx)
            table.insert(vers, dstIdx, moved)

            -- Remap a single version index through the move.
            local function remapVersionIndex(v)
                if not v then return v end
                if v == srcIdx then
                    return dstIdx
                elseif srcIdx < dstIdx and v > srcIdx and v <= dstIdx then
                    return v - 1
                elseif srcIdx > dstIdx and v >= dstIdx and v < srcIdx then
                    return v + 1
                end
                return v
            end

            -- Update all MetaData fields that hold a version index.
            -- Context keys that equal Default are stored as nil; re-apply that rule
            -- after remapping (mirrors the editor's OnValueChanged logic).
            seq.MetaData.Default = remapVersionIndex(seq.MetaData.Default)
            local contextKeys = {
                "Raid", "Arena", "Mythic", "MythicPlus", "PVP",
                "Heroic", "Dungeon", "Timewalking", "Party", "Scenario",
            }
            for _, k in ipairs(contextKeys) do
                local remapped = remapVersionIndex(seq.MetaData[k])
                if remapped == seq.MetaData.Default then
                    seq.MetaData[k] = nil
                else
                    seq.MetaData[k] = remapped
                end
            end

            -- Mirror the reorder into the Library copy so ManageTree() draws the
            -- correct order.  This does NOT persist to GSESequences.
            GSE.EnsureSequenceLoaded(classid, seqname)
            local libSeq = GSE.Library[classid] and GSE.Library[classid][seqname]
            if libSeq and libSeq.Versions then
                local libMoved = table.remove(libSeq.Versions, srcIdx)
                table.insert(libSeq.Versions, dstIdx, libMoved)
                libSeq.MetaData.Default = seq.MetaData.Default
                for _, k in ipairs(contextKeys) do
                    libSeq.MetaData[k] = seq.MetaData[k]
                end
            end

            -- Rebuild the tree, then re-select the previously selected node so the
            -- right panel redraws automatically via OnGroupSelected.  If the selection
            -- was a numeric version of this sequence, remap its index to the new position.
            editframe.ManageTree()

            if currentSelected then
                local newSelected = currentSelected
                local selParts = {("\001"):split(currentSelected)}
                if selParts[1] == "Sequences" and #selParts == 4
                        and selParts[2] == srcParts[2] and selParts[3] == srcParts[3] then
                    local selIdx = tonumber(selParts[4])
                    if selIdx then
                        selParts[4] = tostring(remapVersionIndex(selIdx))
                        newSelected = table.concat(selParts, "\001")
                    end
                end
                container:SelectByValue(newSelected)
            end
        end
    )
    treeContainer:SetCallback(
        "OnGroupSelected",
        function(container, event, group, ...)
            local unique = {("\001"):split(group)}
            local key = unique[#unique]
            local elements, classid, sequencename
            local area = unique[1]


            if area == "Sequences" then
                if unique[3] then
                    elements = GSE.split(unique[3], ",")
                    if #elements >= 3 then
                        classid = elements[1]
                        sequencename = elements[3]
                    end
                end
            end

            local forceTreeSelection = editframe.forceTreeSelection
            editframe.forceTreeSelection = nil
            local mbutton = forceTreeSelection and nil or GetMouseButtonClicked()

            if mbutton == "RightButton" then
                -- Dispatch table for right-click by area
                if area == "KEYBINDINGS" then
                    onRightClick_KEYBINDINGS(editframe, container, group, unique)
                elseif area == "Sequences" then
                    onRightClick_Sequences(editframe, container, group, unique, classid, sequencename)
                elseif area == "VARIABLES" then
                    onRightClick_VARIABLES(editframe, container, group, unique, key)
                end
                -- area == "Macro": no right-click menu
            elseif mbutton == "LeftButton" and IsShiftKeyDown() then
                if classid and sequencename then
                    GSE.UI.ShowLinkDialog({
                        owner      = editframe,
                        title      = L["Chat Link"],
                        prompt     = L["Copy this Link and Paste into a Chat Window."],
                        link       = GSE.SequenceChatPattern(sequencename, classid),
                        buttonText = CLOSE,
                        note       = L["Text selected. Press Ctrl+C to Copy"],
                    })
                end
            else
                -- Save last visited node for restore on reload (exclude Keybindings)
                if area ~= "KEYBINDINGS" and area ~= "NewSequence" and area ~= "Import" then
                    local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
                    if seOpts then
                        seOpts.lastArea    = area
                        seOpts.lastKey     = key
                        seOpts.lastClassId = classid
                    end
                end

                -- Left-click dispatch table
                if area == "NewSequence" then
                    GSE.GUILoadEditor(editframe)
                elseif area == "Import" then
                    GSE.ShowImport()
                elseif area == "KEYBINDINGS" then
                    local path = unique
                    onClick_KEYBINDINGS(editframe, container, group, unique)
                elseif area == "Sequences" then
                    local path = GSE.CloneSequence(unique)
                    table.remove(path, #path)
                    onClick_Sequences(editframe, container, group, unique, path, key, classid, sequencename)
                elseif area == "VARIABLES" then
                    onClick_VARIABLES(editframe, container, group, unique, key)
                elseif area == "Macro" then
                    onClick_Macro(editframe, container, group, unique, key)
                else
                    editframe:SetTitle(L["Sequence Editor"])
                end
            end
        end
    )
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupTree(editframe)
    editframe.ManageTree = function()
        ManageTree(editframe)
    end

    -- Restore last visited node after the tree finishes building
    editframe.RestoreLastNode = function()
        local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
        if not seOpts then return end
        local area    = seOpts.lastArea
        local key     = seOpts.lastKey
        local classid = seOpts.lastClassId
        if not area then return end

        local container = editframe.treeContent or editframe.rightPanel
        if not container then return end

        if area == "Sequences" and key and classid then
            local unique = {classid, key}
            local path = {classid}
            onClick_Sequences(editframe, container, nil, unique, path, key, classid, key)
        elseif area == "VARIABLES" and key then
            onClick_VARIABLES(editframe, container, nil, nil, key)
        elseif area == "Macro" and key then
            onClick_Macro(editframe, container, nil, nil, key)
        elseif area == "KEYBINDINGS" then
            onClick_KEYBINDINGS(editframe, container, nil, nil)
        end
    end
end

-- Expose section header helper for reuse outside Editor_Tree
GSE.GUI.AddSectionHeader = function(container, title, icon)
    local pad = GSE.GUI.CONTENT_PADDING or 20
    if container.SetListPadding then
        container:SetListPadding(pad, SECTION_HEADER_TOP, pad, pad)
    end
    addSectionDivider(container, title, icon)
end

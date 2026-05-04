local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local FRAME_DISPLACEMENT = 30
local DEFAULT_HEIGHT = 500
local DEFAULT_WIDTH = 700
local TOOLBAR_OFFSET = 100
local SCROLLCONTAINER_OFFSET = 120


function GSE.CreateIconControl(action, version, keyPath, sequence, frame)
    local lbl = AceGUI:Create("InteractiveLabel")
    lbl:SetFontObject(GameFontNormalLarge)
    lbl:SetWidth(25)
    lbl:SetHeight(25)

    -- Derives the display icon for the block.  Called once on creation and
    -- again whenever the spell/item/toy field changes (via RefreshIcon).
    -- Honours a manually-assigned action.Icon; otherwise infers from the
    -- spell, item, toy, or macro content.
    local function refreshIcon()
        local iconID = Statics.QuestionMarkIconID
        if action.Icon then
            iconID = action.Icon
        elseif action.type == "spell" then
            local si = action.spell and C_Spell.GetSpellInfo(action.spell)
            if si and si.iconID then iconID = si.iconID end
        elseif action.type == "item" or action.type == "toy" then
            local itemKey = action.item or action.toy
            if itemKey then
                local icon = select(10, GetItemInfo(itemKey))
                if icon then iconID = icon end
            end
        elseif action.type == "macro" then
            local macro = action.macro and GSE.UnEscapeString(action.macro) or ""
            if string.sub(macro, 1, 1) == "/" then
                local spellstuff = GSE.GetSpellsFromString(macro)
                if spellstuff and #spellstuff > 1 then spellstuff = spellstuff[1] end
                if spellstuff and spellstuff.iconID then iconID = spellstuff.iconID end
            elseif string.sub(macro, 1, 1) == "=" then
                -- Variable reference: the raw text has no slash commands to parse,
                -- so fall back to the compiled output which expands the variable.
                local compiled = GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                if compiled and string.sub(compiled, 1, 1) == "/" then
                    local spellstuff = GSE.GetSpellsFromString(compiled)
                    if spellstuff and #spellstuff > 1 then spellstuff = spellstuff[1] end
                    if spellstuff and spellstuff.iconID then iconID = spellstuff.iconID end
                end
            else
                -- External WoW macro name: look up its icon.
                local macindex = GetMacroIndexByName(macro)
                local _, micon = GetMacroInfo(macindex)
                if micon then iconID = micon end
            end
        end
        lbl:SetText("|T" .. iconID .. ":0|t")
    end

    -- Expose so callers can refresh the icon after the spell field changes.
    lbl.RefreshIcon = refreshIcon
    refreshIcon()

    local spellinfolist = {}
    if action.type == "macro" then
        local macro = GSE.UnEscapeString(action.macro)
        if string.sub(macro, 1, 1) == "/" then
            local lines = GSE.SplitMeIntoLines(macro)
            for _, v in ipairs(lines) do
                local spellinfo = GSE.GetSpellsFromString(v)
                if spellinfo and #spellinfo > 1 then
                    for _, j in ipairs(spellinfo) do
                        if j and j.iconID then
                            table.insert(spellinfolist, j)
                        end
                    end
                else
                    if spellinfo and spellinfo.iconID then
                        table.insert(spellinfolist, spellinfo)
                    end
                end
            end
        else
            local spellinfo = {}
            spellinfo.name = action.macro
            local macindex = GetMacroIndexByName(spellinfo.name)
            local _, iconid, _ = GetMacroInfo(macindex)
            if macindex and iconid then
                spellinfo.iconID = iconid
                table.insert(spellinfolist, spellinfo)
            end
        end
    elseif action.type == "Spell" then
        local spellinfo = C_Spell.GetSpellInfo(action.spell)
        if spellinfo and spellinfo.iconID then
            table.insert(spellinfolist, spellinfo)
        end
    end

    lbl:SetCallback("OnClick", function(widget, button)
        MenuUtil.CreateContextMenu(frame, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Select Icon"])
            for _, v in pairs(spellinfolist) do
                rootDescription:CreateButton(
                    "|T" .. v.iconID .. ":0|t " .. v.name,
                    function()
                        lbl:SetText("|T" .. v.iconID .. ":0|t")
                        sequence.Versions[version].Actions[keyPath].Icon = v.iconID
                    end
                )
            end
            -- Extension point: QoL and other modules append extra items here.
            if GSE.OnBuildIconMenu then
                GSE.OnBuildIconMenu(rootDescription, lbl, sequence, version, keyPath)
            end
        end)
    end)
    return lbl
end
local function BuildVersionLabel(version, label, excludekey)
    version = tostring(version)
    if not label then
        if version == "1" then
            label = L["Default"]
        else
            label = L["Version"]
        end
    end
    if excludekey then
        return label
    else
        return version .. " - " .. label
    end
end
function GSE.CreateEditor()
    if GSE.isEmpty(GSE.GUI.editors) then
        GSE.GUI.editors = {}
    end
    if GSE.GUI.editors[1] and not GSE.Patron then
        return GSE.GUI.editors[1]
    end
    local editframe = AceGUI:Create("Frame")
    table.insert(GSE.GUI.editors, editframe)
    editframe:Hide()
    editframe.frame:SetFrameStrata("MEDIUM")
    editframe.frame:SetClampedToScreen(true)
    editframe.Sequence = {}
    editframe.Sequence.Versions = {}
    editframe.SequenceName = ""
    editframe.Raid = 1
    editframe.PVP = 1
    editframe.Mythic = 1
    editframe.Dungeon = 1
    editframe.Heroic = 1
    editframe.Party = 1
    editframe.Arena = 1
    editframe.Timewalking = 1
    editframe.MythicPlus = 1
    editframe.Scenario = 1
    editframe.ClassID = GSE.GetCurrentClassID()
    editframe.save = false
    editframe.statusText = "GSE: " .. GSE.VersionString
    editframe.booleanFunctions = {}
    editframe.frame:SetClampRectInsets(-10, -10, -10, -10)

    local function GetVersionList()
        if not #editframe.Sequence.Versions then
            return {}
        end
        local tabl = {}
        for k, v in ipairs(editframe.Sequence.Versions) do
            tabl[tostring(k)] = v.Label and tostring(k) .. " - " .. v.Label or tostring(k)
        end
        return tabl
    end
    editframe.GetVersionList = GetVersionList

    local function GUIConfirmDeleteSequence(classid, sequenceName)
        GSE.DeleteSequence(classid, sequenceName)
        for _, v in ipairs(GSE.GUI.editors) do
            v.ManageTree()
        end
    end

    --- This function pops up a confirmation dialog.
    local function GUIDeleteSequence(classid, sequenceName)
        StaticPopupDialogs["GSE-DeleteMacroDialog"].text =
            string.format(
            L[
                "Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."
            ],
            sequenceName
        )
        StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
            GUIConfirmDeleteSequence(classid, sequenceName)
        end

        StaticPopup_Show("GSE-DeleteMacroDialog")
    end
    editframe.GUIDeleteSequence = GUIDeleteSequence

    --- This function then deletes the macro.

    if
        GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor and
            GSEOptions.frameLocations.sequenceeditor.left and
            GSEOptions.frameLocations.sequenceeditor.top
     then
        local editorleft = GSEOptions.frameLocations.sequenceeditor.left
        local editortop = GSEOptions.frameLocations.sequenceeditor.top

        if #GSE.GUI.editors > 0 then
            editorleft = editorleft + FRAME_DISPLACEMENT
            editortop = editortop - FRAME_DISPLACEMENT
            editframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", editorleft, editortop)
            GSEOptions.frameLocations.sequenceeditor.left = editorleft
            GSEOptions.frameLocations.sequenceeditor.top = editortop
        else
            editframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", editorleft, editortop)
        end
    end
    local seOpts = GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor or {}
    editframe.Height = seOpts.height or 500
    editframe.Width = seOpts.width or 700

    if editframe.Height < DEFAULT_HEIGHT then
        editframe.Height = DEFAULT_HEIGHT
        GSEOptions.frameLocations.sequenceeditor.height = editframe.Height
    end
    if editframe.Width < DEFAULT_WIDTH then
        editframe.Width = DEFAULT_WIDTH
        GSEOptions.frameLocations.sequenceeditor.width = editframe.Width
    end
    editframe.frame:SetHeight(editframe.Height)
    editframe.frame:SetWidth(editframe.Width)
    editframe:SetTitle(L["Sequence Editor"])
    editframe:SetCallback(
        "OnClose",
        function(self)
            -- When minimizing we hide the frame which triggers OnHide→OnClose.
            -- Skip all cleanup so the frame stays usable for restore.
            if self.isMinimizing then return end

            self.OrigSequenceName = nil
            GSE.ClearTooltip(editframe)
            if GSE.isEmpty(GSEOptions.frameLocations) then
                GSEOptions.frameLocations = {}
            end
            if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
                GSEOptions.frameLocations.sequenceeditor = {}
            end

            local left, bottom, w, h = self.frame:GetRect()
            GSEOptions.frameLocations.sequenceeditor.left = left
            GSEOptions.frameLocations.sequenceeditor.top = bottom + h
            GSEOptions.frameLocations.sequenceeditor.height = h
            GSEOptions.frameLocations.sequenceeditor.width = w
            if self.treeContainer then
                GSEOptions.frameLocations.sequenceeditor.treeWidth = self.treeContainer:GetTreeWidth()
            end
            self:Hide()
            self.Sequence = nil
            self.SequenceName = nil
            self.Raid = nil
            self.PVP = nil
            self.Mythic = nil
            self.Dungeon = nil
            self.Heroic = nil
            self.Party = nil
            self.Arena = nil
            self.Timewalking = nil
            self.MythicPlus = nil
            self.Scenario = nil
            self.ClassID = nil
            self.save = nil
            self.statusText = nil
            self.booleanFunctions = nil
            if self.minimizedWidget then
                self.minimizedWidget.editframe = nil
                self.minimizedWidget:Hide()
                self.minimizedWidget = nil
            end
            if self.PreviewFrame then
                self.PreviewFrame:Hide()
                self.PreviewFrame = nil
            end
            self:ReleaseChildren()
            for k, v in ipairs(GSE.GUI.editors) do
                if editframe == v then
                    table.remove(GSE.GUI.editors, k)
                end
            end
            -- need to clear the onSizeChanged else the old OnSizeChanged method will reapplu when we recreate the frame.
            self.frame:SetScript(
                "OnSizeChanged",
                function(self, width, height)
                end
            )

            AceGUI:Release(self)
        end
    )

    -- Small draggable widget shown when the editor is minimized
    local minimizedWidget = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    minimizedWidget:SetSize(220, 34)
    minimizedWidget:SetFrameStrata("HIGH")
    minimizedWidget:SetMovable(true)
    minimizedWidget:EnableMouse(true)
    minimizedWidget:RegisterForDrag("LeftButton")
    minimizedWidget:SetClampedToScreen(true)
    minimizedWidget:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    minimizedWidget:SetBackdropColor(0, 0, 0, 0.85)
    minimizedWidget:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    minimizedWidget:Hide()

    local minWidgetIcon = minimizedWidget:CreateTexture(nil, "ARTWORK")
    minWidgetIcon:SetSize(22, 22)
    minWidgetIcon:SetPoint("LEFT", minimizedWidget, "LEFT", 6, 0)
    minWidgetIcon:SetTexture(Statics.Icons.GSE_Logo_Dark)

    local minWidgetTitle = minimizedWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minWidgetTitle:SetPoint("LEFT", minWidgetIcon, "RIGHT", 6, 0)
    minWidgetTitle:SetPoint("RIGHT", minimizedWidget, "RIGHT", -6, 0)
    minWidgetTitle:SetJustifyH("LEFT")
    minWidgetTitle:SetWordWrap(false)

    minimizedWidget.editframe = editframe
    minimizedWidget:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    minimizedWidget:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    minimizedWidget:SetScript("OnClick", function(self)
        self:Hide()
        if self.editframe then
            self.editframe:Show()
            if self.previewWasVisible and self.editframe.PreviewFrame then
                self.editframe.PreviewFrame:Show()
            end
        end
        self.previewWasVisible = nil
    end)
    editframe.minimizedWidget = minimizedWidget

    -- Minimize button at the top-right corner of the editor frame
    local minimizeBtn = CreateFrame("Button", nil, editframe.frame, "UIPanelButtonTemplate")
    minimizeBtn:SetSize(26, 22)
    minimizeBtn:SetText("\226\136\146") -- Unicode minus sign (−)
    minimizeBtn:SetPoint("TOPRIGHT", editframe.frame, "TOPRIGHT", -5, -5)
    minimizeBtn:SetFrameLevel(editframe.frame:GetFrameLevel() + 10)
    minimizeBtn:SetScript("OnClick", function()
        minWidgetTitle:SetText(editframe.SequenceName or "")
        minimizedWidget.previewWasVisible = editframe.PreviewFrame and editframe.PreviewFrame:IsVisible()
        if editframe.PreviewFrame then
            editframe.PreviewFrame:Hide()
        end
        minimizedWidget:ClearAllPoints()
        local x = editframe.frame:GetLeft()
        local y = editframe.frame:GetTop()
        if x and y then
            minimizedWidget:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        else
            minimizedWidget:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        -- Set flag so OnClose (fired by AceGUI's OnHide→OnClose chain) skips cleanup
        editframe.isMinimizing = true
        editframe:Hide()
        editframe.isMinimizing = nil
        minimizedWidget:Show()
    end)

    -- If the editor is re-shown via any path (e.g. minimap button re-click) always
    -- dismiss the minimized widget so they never appear simultaneously.
    editframe.frame:HookScript("OnShow", function()
        minimizedWidget:Hide()
    end)

    editframe:SetLayout("Flow")
    editframe.panels = {}

    local function GUIUpdateSequenceDefinition(classid, SequenceName, sequence)
        sequence.LastUpdated = GSE.GetTimestamp()

        if not GSE.isEmpty(SequenceName) then
            if GSE.isEmpty(classid) then
                classid = GSE.GetCurrentClassID()
            end
            sequence.MetaData.Name = SequenceName
            if not GSE.isEmpty(SequenceName) then
                local vals = {}
                vals.action = "Replace"
                vals.sequencename = SequenceName
                vals.sequence = sequence
                vals.classid = classid

                if GSE.ObjectExists(SequenceName) and editframe.newname then
                    editframe:SetStatusText(
                        string.format(L["Sequence Name %s is in Use. Please choose a different name."], SequenceName)
                    )
                    editframe.nameeditbox:SetText(
                        GSEOptions.UNKNOWN .. editframe.nameeditbox:GetText() .. Statics.StringReset
                    )
                    editframe.nameeditbox:SetFocus()
                    return
                end
                GSE.EnqueueOOC(vals)
                editframe:SetStatusText(L["Save pending for "] .. SequenceName)
            end
        end
    end
    editframe.GUIUpdateSequenceDefinition = GUIUpdateSequenceDefinition

    local basecontainer = AceGUI:Create("SimpleGroup")
    basecontainer:SetLayout("Fill")
    basecontainer:SetFullHeight(true)
    basecontainer:SetFullWidth(true)
    editframe:AddChild(basecontainer)

    local treeContainer = AceGUI:Create("GSE-TreeGroup")
    treeContainer:SetFullHeight(true)
    treeContainer:SetFullWidth(true)
    local seTreeWidth = GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor and GSEOptions.frameLocations.sequenceeditor.treeWidth
    if seTreeWidth then
        treeContainer:SetTreeWidth(seTreeWidth, true)
    end

    editframe.treeContainer = treeContainer

    basecontainer:AddChild(treeContainer)
    local function ChooseVersion(container, version, scrollpos, path)
        container:ReleaseChildren()
        editframe.DrawSequenceEditor(container, version, path)
        if not GSE.isEmpty(editframe.scrollContainer) and scrollpos > 0 then
            editframe.scrollContainer:SetScroll(scrollpos)
        end
        editframe.scrollContainer:DoLayout()
    end
    local function drawRawEditor(container, version, tablestring, path)
        container:ReleaseChildren()

        local seqTableEditbox = AceGUI:Create("MultiLineEditBox")
        seqTableEditbox:SetLabel(L["Sequence"])
        seqTableEditbox:DisableButton(true)
        seqTableEditbox:SetNumLines(35)
        seqTableEditbox:SetRelativeWidth(0.95)
        seqTableEditbox:SetText(tablestring)

        IndentationLib.enable(seqTableEditbox.editBox, Statics.IndentationColorTable, 4)

        local compileButton = AceGUI:Create("Button")
        compileButton:SetText(L["Compile"])
        compileButton:SetWidth(130)
        compileButton:SetCallback(
            "OnClick",
            function()
                local tab
                local load = "return " .. seqTableEditbox:GetText()
                local func, err = loadstring(load)
                if err or not func then
                    GSE.Print(L["Unable to process content.  Fix table and try again."], L["Raw Editor"])
                    if err then
                        GSE.Print(err, L["Raw Editor"])
                    end
                else
                    tab = func()
                    if not GSE.isEmpty(tab) then
                        editframe.Sequence.Versions[version] = tab
                        treeContainer:SelectByValue(path .. "\001" .. version)
                    else
                        GSE.Print(L["Unable to process content.  Fix table and try again."], L["Raw Editor"])
                    end
                end
            end
        )
        compileButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local cancelButton = AceGUI:Create("Button")
        cancelButton:SetText(L["Cancel"])
        cancelButton:SetWidth(130)
        cancelButton:SetCallback(
            "OnClick",
            function()
                treeContainer:SelectByValue(path .. "\001" .. version)
            end
        )
        cancelButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        container:AddChild(seqTableEditbox)

        local toolcontainer = AceGUI:Create("InlineGroup")
        toolcontainer:SetLayout("Flow")

        toolcontainer:SetFullWidth(true)
        toolcontainer:AddChild(compileButton)
        toolcontainer:AddChild(cancelButton)
        container:AddChild(toolcontainer)
    end
    local function DrawSequenceEditor(tcontainer, version, path)
    local function GetBlockToolbar(
            version,
            path,
            treepath,
            includeAdd,
            headingLabel,
            container,
            disableMove,
            disableDelete,
            dontDeleteLastParent)
            local layoutcontainer = AceGUI:Create("SimpleGroup")

            local lastPath = path[#path]

            local parentPath = GSE.CloneSequence(path)
            local blocksThisLevel

            if #parentPath == 1 then
                blocksThisLevel = #editframe.Sequence.Versions[version].Actions
            else
                if GSE.isEmpty(dontDeleteLastParent) then
                    parentPath[#parentPath] = nil
                end
                blocksThisLevel = #editframe.Sequence.Versions[version].Actions[parentPath]
            end
            layoutcontainer:SetLayout("Flow")
            layoutcontainer:SetFullWidth(true)
            layoutcontainer:SetHeight(30)
            local moveUpButton, moveDownButton

            if GSE.isEmpty(disableMove) then
                moveUpButton = AceGUI:Create("Icon")
                moveDownButton = AceGUI:Create("Icon")
                moveUpButton:SetImageSize(30, 30)
                moveUpButton:SetWidth(30)
                moveUpButton:SetHeight(30)
                moveUpButton:SetImage(Statics.ActionsIcons.Up)

                moveUpButton:SetCallback(
                    "OnClick",
                    function()
                        local original = GSE.CloneSequence(editframe.Sequence.Versions[version].Actions[path])
                        local destinationPath = {}
                        for k, v in ipairs(path) do
                            if k == #path then
                                v = v - 1
                            end
                            table.insert(destinationPath, v)
                        end

                        editframe.Sequence.Versions[version].Actions[path] =
                            GSE.CloneSequence(editframe.Sequence.Versions[version].Actions[destinationPath])
                        editframe.Sequence.Versions[version].Actions[destinationPath] = original
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                moveUpButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Move Up"], L["Move this block up one block."], editframe)
                    end
                )
                moveUpButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                moveUpButton:SetCallback(
                    "OnRelease",
                    function(self)
                        self:SetDisabled(false)
                    end
                )

                moveDownButton:SetImageSize(30, 30)
                moveDownButton:SetWidth(30)
                moveDownButton:SetHeight(30)
                moveDownButton:SetImage(Statics.ActionsIcons.Down)

                moveDownButton:SetCallback(
                    "OnClick",
                    function()
                        local original = GSE.CloneSequence(editframe.Sequence.Versions[version].Actions[path])
                        local destinationPath = {}
                        for k, v in ipairs(path) do
                            if k == #path then
                                v = v + 1
                            end
                            table.insert(destinationPath, v)
                        end

                        editframe.Sequence.Versions[version].Actions[path] =
                            GSE.CloneSequence(editframe.Sequence.Versions[version].Actions[destinationPath])
                        editframe.Sequence.Versions[version].Actions[destinationPath] = original
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                moveDownButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Move Down"], L["Move this block down one block."], editframe)
                    end
                )
                moveDownButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                moveDownButton:SetCallback(
                    "OnRelease",
                    function(self)
                        self:SetDisabled(false)
                    end
                )
            end

            local deleteBlockButton
            if not disableDelete then
                deleteBlockButton = AceGUI:Create("Icon")
                deleteBlockButton:SetImageSize(30, 30)
                deleteBlockButton:SetWidth(30)
                deleteBlockButton:SetHeight(30)
                deleteBlockButton:SetImage(Statics.ActionsIcons.Delete)

                deleteBlockButton:SetCallback(
                    "OnClick",
                    function()
                        container:ReleaseChildren()
                        local delPath = {}
                        local delObj
                        for k, v in ipairs(path) do
                            if k == #path then
                                delObj = v
                            else
                                table.insert(delPath, v)
                            end
                        end
                        table.remove(editframe.Sequence.Versions[version].Actions[delPath], delObj)
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                deleteBlockButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Delete Block"],
                            L[
                                "Delete this Block from the sequence.  \nWARNING: If this is a loop this will delete all the blocks inside the loop as well."
                            ],
                            editframe
                        )
                    end
                )
                deleteBlockButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            local addLoopButton, addActionButton, addPauseButton, addIfButton, addEmbedButton
            if includeAdd then
                addLoopButton = AceGUI:Create("Icon")
                addActionButton = AceGUI:Create("Icon")
                addPauseButton = AceGUI:Create("Icon")
                addIfButton = AceGUI:Create("Icon")
                addEmbedButton = AceGUI:Create("Icon")
                addActionButton:SetImageSize(30, 30)
                addActionButton:SetWidth(30)
                addActionButton:SetHeight(30)
                addActionButton:SetImage(Statics.ActionsIcons.Action)

                addActionButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["macro"] = "Need Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                        if #path > 1 then
                            table.insert(
                                editframe.Sequence.Versions[version].Actions[parentPath],
                                lastPath + 1,
                                newAction
                            )
                        else
                            table.insert(editframe.Sequence.Versions[version].Actions, lastPath + 1, newAction)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                addActionButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
                    end
                )
                addActionButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addLoopButton:SetImageSize(30, 30)
                addLoopButton:SetWidth(30)
                addLoopButton:SetHeight(30)
                addLoopButton:SetImage(Statics.ActionsIcons.Loop)

                addLoopButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            [1] = {
                                ["macro"] = "Need Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            },
                            ["StepFunction"] = Statics.Sequential,
                            ["Type"] = Statics.Actions.Loop,
                            ["Repeat"] = 2
                        }

                        -- setmetatable(newAction, Statics.TableMetadataFunction)
                        if #path > 1 then
                            table.insert(
                                editframe.Sequence.Versions[version].Actions[parentPath],
                                lastPath + 1,
                                newAction
                            )
                        else
                            table.insert(editframe.Sequence.Versions[version].Actions, lastPath + 1, newAction)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                addLoopButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
                    end
                )
                addLoopButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addPauseButton:SetImageSize(30, 30)
                addPauseButton:SetWidth(30)
                addPauseButton:SetHeight(30)
                addPauseButton:SetImage(Statics.ActionsIcons.Pause)

                addPauseButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["Variable"] = "GCD",
                            ["Type"] = Statics.Actions.Pause
                        }
                        if #path > 1 then
                            table.insert(
                                editframe.Sequence.Versions[version].Actions[parentPath],
                                lastPath + 1,
                                newAction
                            )
                        else
                            table.insert(editframe.Sequence.Versions[version].Actions, lastPath + 1, newAction)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                addPauseButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
                    end
                )
                addPauseButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addIfButton:SetImageSize(30, 30)
                addIfButton:SetWidth(30)
                addIfButton:SetHeight(30)
                addIfButton:SetImage(Statics.ActionsIcons.If)

                addIfButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            [1] = {
                                {
                                    ["macro"] = "Need True Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                }
                            },
                            [2] = {
                                {
                                    ["macro"] = "Need False Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                }
                            },
                            ["Type"] = Statics.Actions.If
                        }
                        if #path > 1 then
                            table.insert(
                                editframe.Sequence.Versions[version].Actions[parentPath],
                                lastPath + 1,
                                newAction
                            )
                        else
                            table.insert(editframe.Sequence.Versions[version].Actions, lastPath + 1, newAction)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                addIfButton:SetCallback(
                    "OnEnter",
                    function()
                        if GSE.TableLength(editframe.booleanFunctions) > 0 then
                            GSE.CreateToolTip(
                                L["Add If"],
                                L[
                                    "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                                ],
                                editframe
                            )
                        else
                            GSE.CreateToolTip(
                                L["Add If"],
                                L[
                                    "If Blocks require a variable that returns either true or false.  Create the variable first."
                                ],
                                editframe
                            )
                        end
                    end
                )
                addIfButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addEmbedButton:SetImageSize(30, 30)
                addEmbedButton:SetWidth(30)
                addEmbedButton:SetHeight(30)
                addEmbedButton:SetImage(Statics.ActionsIcons.Embed)

                addEmbedButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["Type"] = Statics.Actions.Embed
                        }
                        if #path > 1 then
                            table.insert(
                                editframe.Sequence.Versions[version].Actions[parentPath],
                                lastPath + 1,
                                newAction
                            )
                        else
                            table.insert(editframe.Sequence.Versions[version].Actions, lastPath + 1, newAction)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                )
                addEmbedButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Add Embed"],
                            L[
                                "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                            ],
                            editframe
                        )
                    end
                )
                addEmbedButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            -- Build patheditbox widget up front so it can be inserted early in the layout
            local textpath = GSE.SafeConcat(path, ".")
            local patheditbox
            if GSE.isEmpty(disableMove) then
                patheditbox = AceGUI:Create("EditBox")
                patheditbox:SetWidth(40)
                patheditbox:SetCallback(
                    "OnEnterPressed",
                    function(obj, event, key)
                        if not editframe.reloading then
                            local destinationPath = GSE.split(key, ".")
                            for k, v in ipairs(destinationPath) do
                                destinationPath[k] = tonumber(v)
                            end
                            local testpath = GSE.CloneSequence(destinationPath)
                            table.remove(testpath, #testpath)
                            local sourcepath = GSE.CloneSequence(path)
                            for k, v in ipairs(sourcepath) do
                                sourcepath[k] = tonumber(v)
                            end
                            table.remove(sourcepath, #sourcepath)
                            if #testpath > 0 then
                                -- check that the path exists
                                if
                                    GSE.isEmpty(editframe.Sequence.Versions[version].Actions[testpath]) or
                                        type(editframe.Sequence.Versions[version].Actions[testpath]) ~= "table"
                                    then
                                    GSE.Print(L["Error: Destination path not found."])
                                    return
                                end
                            end

                            if #sourcepath > 0 then
                                -- check that the path exists  If this has happened we have a big problem
                                if
                                    GSE.isEmpty(editframe.Sequence.Versions[version].Actions[sourcepath]) or
                                        type(editframe.Sequence.Versions[version].Actions[sourcepath]) ~= "table"
                                    then
                                    GSE.Print(L["Error: Source path not found."])
                                    return
                                end
                            end

                            if string.sub(key, 1, string.len(textpath)) == textpath then
                                GSE.Print(L["Error: You cannot move a container to be a child within itself."])
                                return
                            end

                            local insertActions =
                                GSE.CloneSequence(editframe.Sequence.Versions[version].Actions[path])
                            local endPoint = tonumber(destinationPath[#destinationPath])

                            local pathPoint = tonumber(path[#path])

                            if #sourcepath > 0 then
                                table.remove(editframe.Sequence.Versions[version].Actions[sourcepath], pathPoint)
                            else
                                table.remove(editframe.Sequence.Versions[version].Actions, pathPoint)
                            end
                            if #testpath > 0 then
                                if endPoint > #testpath + 1 then
                                    endPoint = #testpath + 1
                                end
                                table.insert(
                                    editframe.Sequence.Versions[version].Actions[testpath],
                                    endPoint,
                                    insertActions
                                )
                            else
                                if endPoint > #editframe.Sequence.Versions[version].Actions + 1 then
                                    endPoint = #editframe.Sequence.Versions[version].Actions + 1
                                end
                                table.insert(editframe.Sequence.Versions[version].Actions, endPoint, insertActions)
                            end
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )
                patheditbox:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Block Path"],
                            L[
                                "The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.\nEG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block."
                            ],
                            editframe
                        )
                    end
                )
                patheditbox:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                patheditbox:DisableButton(true)
                patheditbox:SetText(textpath)
            end

            -- Build disableBlock widget up front so it can be inserted near the end
            local disableBlock, highlightTexture
            if GSE.isEmpty(disableMove) then
                disableBlock = AceGUI:Create("CheckBox")
                disableBlock:SetType("checkbox")
                disableBlock:SetWidth(130)
                disableBlock:SetTriState(false)
                disableBlock:SetLabel(L["Disable Block"])
                disableBlock:SetValue(editframe.Sequence.Versions[version].Actions[path].Disabled)
                highlightTexture = container.frame:CreateTexture(nil, "BACKGROUND")
                highlightTexture:SetAllPoints(true)

                disableBlock:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[path].Disabled = value
                        if value == true then
                            highlightTexture:SetColorTexture(1, 0, 0, 0.15)
                        else
                            highlightTexture:SetColorTexture(1, 0, 0, 0)
                        end
                    end
                )
                if editframe.Sequence.Versions[version].Actions[path].Disabled == true then
                    highlightTexture:SetColorTexture(1, 0, 0, 0.15)
                else
                    highlightTexture:SetColorTexture(1, 0, 0, 0)
                end

                container:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        highlightTexture:SetColorTexture(0, 0, 0, 0)
                    end
                )
                disableBlock:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Disable Block"],
                            L[
                                "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
                            ],
                            editframe
                        )
                    end
                )
                disableBlock:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            -- 1. Up / Down
            if GSE.isEmpty(disableMove) then
                moveUpButton:SetDisabled(lastPath == 1)
                moveDownButton:SetDisabled(lastPath == blocksThisLevel)
                layoutcontainer:AddChild(moveUpButton)
                layoutcontainer:AddChild(moveDownButton)
                local spacerlabel1 = AceGUI:Create("Label")
                spacerlabel1:SetWidth(5)
                layoutcontainer:AddChild(spacerlabel1)
            end

            -- 2. Block path
            if GSE.isEmpty(disableMove) then
                layoutcontainer:AddChild(patheditbox)
                local spacerlabelPath = AceGUI:Create("Label")
                spacerlabelPath:SetWidth(5)
                layoutcontainer:AddChild(spacerlabelPath)
            end

            -- 3. Icon + heading
            layoutcontainer:AddChild(headingLabel)

            -- 4. Toolbar add buttons
            if includeAdd then
                local spacerlabel2 = AceGUI:Create("Label")
                spacerlabel2:SetWidth(5)
                layoutcontainer:AddChild(spacerlabel2)
                layoutcontainer:AddChild(addActionButton)
                layoutcontainer:AddChild(addLoopButton)
                layoutcontainer:AddChild(addPauseButton)
                layoutcontainer:AddChild(addIfButton)
                layoutcontainer:AddChild(addEmbedButton)
            end

            -- Returns a finalize function: callers must call it after injecting any
            -- block-specific widgets so that Disable Block and Delete appear last.
            local function finalizeToolbar()
                -- 5. Disable Block
                if GSE.isEmpty(disableMove) then
                    local spacerlabel3 = AceGUI:Create("Label")
                    spacerlabel3:SetWidth(15)
                    layoutcontainer:AddChild(spacerlabel3)
                    layoutcontainer:AddChild(disableBlock)
                end

                -- 6. Delete (last)
                local spacerlabel4 = AceGUI:Create("Label")
                spacerlabel4:SetWidth(15)
                layoutcontainer:AddChild(spacerlabel4)
                if not disableDelete then
                    layoutcontainer:AddChild(deleteBlockButton)
                end
            end

            return layoutcontainer, finalizeToolbar
        end
        local function drawAction(pcontainer, action, version, keyPath, treepath)

            -- Workaround for vanishing label ace3 bug
            local label = AceGUI:Create("Label")
            label:SetFontObject(GameFontNormalLarge)
            pcontainer:AddChild(label)

            local hlabelIcon = AceGUI:Create("Icon")
            hlabelIcon:SetImage(Statics.ActionsIcons[action.Type] or Statics.ActionsIcons.Action)
            hlabelIcon:SetImageSize(15, 15)
            hlabelIcon:SetWidth(15)
            hlabelIcon:SetHeight(20)
            hlabelIcon.image:SetTexCoord(0.16, 0.84, 0.16, 0.84)
            hlabelIcon.image:SetDesaturated(true)
            hlabelIcon.image:ClearAllPoints()
            hlabelIcon.image:SetPoint("BOTTOMLEFT", hlabelIcon.frame, "BOTTOMLEFT", 0, 3)
            hlabelIcon.frame:EnableMouse(false)
            hlabelIcon:SetCallback("OnRelease", function(self)
                self.image:SetDesaturated(false)
                self.image:ClearAllPoints()
                self.image:SetPoint("TOP", 0, -5)
            end)

            local hlabelText = AceGUI:Create("Label")
            hlabelText:SetText(action.Type == Statics.Actions.Repeat and Statics.Actions.Action or Statics.Actions[action.Type])
            hlabelText:SetFontObject(GameFontNormalLarge)
            hlabelText:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
            hlabelText:SetWidth(80)

            local hlabel = AceGUI:Create("SimpleGroup")
            hlabel:SetLayout("Flow")
            hlabel:SetWidth(115)
            hlabel:SetHeight(30)
            hlabel:AddChild(hlabelIcon)
            hlabel:AddChild(hlabelText)
            local includeAdd = true

            if action.Type == Statics.Actions.Pause then
                local block = AceGUI:Create("InlineGroup")

                block:SetLayout("List")
                block:SetFullWidth(true)
                local linegroup1 = AceGUI:Create("SimpleGroup")

                linegroup1:SetLayout("Flow")
                linegroup1:SetFullWidth(true)

                local clicksdropdown = AceGUI:Create("Dropdown")
                clicksdropdown:SetLabel(L["Measure"])
                clicksdropdown:SetRelativeWidth(0.24)
                local clickdroplist = {
                    [L["Clicks"]] = L["How many macro Clicks to pause for?"],
                    [L["Milliseconds"]] = L["How many milliseconds to pause for?"],
                    ["GCD"] = L["Pause for the GCD."]
                }
                for k, _ in pairs(editframe.numericFunctions) do
                    clickdroplist[k] = L["Local Function: "] .. k
                end
                clicksdropdown:SetList(clickdroplist)
                clicksdropdown:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Pause"],
                            L[
                                "A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.\nIf using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box."
                            ],
                            editframe
                        )
                    end
                )
                if not GSE.isEmpty(action.Variable) then
                    if action.Variable == "GCD" then
                        clicksdropdown:SetValue(action.Variable)
                    elseif not GSE.isEmpty(editframe.numericFunctions[action.Variable]) then
                        clicksdropdown:SetValue(action.Variable)
                    else
                        action.Variable = nil
                    end
                elseif GSE.isEmpty(action.MS) then
                    clicksdropdown:SetValue(L["Clicks"])
                else
                    clicksdropdown:SetValue(L["Milliseconds"])
                    if action.MS == "~~GCD~~" or action.MS == "GCD" then
                        clicksdropdown:SetValue("GCD")
                        action.Variable = "GCD"
                        action.MS = nil
                    end
                end
                clicksdropdown:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                linegroup1:AddChild(clicksdropdown)
                local spacerlabel1 = AceGUI:Create("Label")
                spacerlabel1:SetWidth(5)
                linegroup1:AddChild(spacerlabel1)

                local msvalueeditbox = AceGUI:Create("EditBox")
                msvalueeditbox:SetLabel()

                msvalueeditbox:SetWidth(100)
                msvalueeditbox.editbox:SetNumeric(true)
                msvalueeditbox:DisableButton(true)
                local value = GSE.isEmpty(action.MS) and action.Clicks or action.MS
                if not GSE.isEmpty(action.Clicks) or GSE.isEmpty(action.MS) then
                    msvalueeditbox:SetDisabled(false)
                else
                    msvalueeditbox:SetDisabled(true)
                end
                msvalueeditbox:SetText(value)
                msvalueeditbox:SetCallback(
                    "OnTextChanged",
                    function(self, event, text)
                        local returnAction = {}
                        returnAction["Type"] = action.Type
                        if clicksdropdown:GetValue() == L["Clicks"] then
                            returnAction["Clicks"] = tonumber(text)
                        else
                            returnAction["MS"] = tonumber(text)
                        end
                        editframe.Sequence.Versions[version].Actions[keyPath] = returnAction
                        editframe:SetStatusText(editframe.statusText)
                    end
                )

                msvalueeditbox:SetCallback(
                    "OnRelease",
                    function(self, event, text)
                        msvalueeditbox.editbox:SetNumeric(false)
                    end
                )
                clicksdropdown:SetCallback(
                    "OnValueChanged",
                    function(self, event, text)
                        --editframe.Sequence.Versions[version].Variables[keyEditBox:GetText()] = valueEditBox:GetText()
                        local returnAction = {}
                        returnAction["Type"] = action.Type
                        if text == L["Clicks"] then
                            returnAction["Clicks"] = tonumber(msvalueeditbox:GetText())
                            msvalueeditbox:SetDisabled(false)
                        elseif text == L["Milliseconds"] then
                            returnAction["MS"] = tonumber(msvalueeditbox:GetText())
                            msvalueeditbox:SetDisabled(false)
                        else
                            returnAction["Variable"] = text
                            msvalueeditbox:SetDisabled(true)
                        end

                        editframe.Sequence.Versions[version].Actions[keyPath] = returnAction
                    end
                )
                if clicksdropdown:GetValue() == L["Milliseconds"] or clicksdropdown:GetValue() == L["Clicks"] then
                    msvalueeditbox:SetDisabled(false)
                else
                    msvalueeditbox:SetDisabled(true)
                end
                linegroup1:AddChild(msvalueeditbox)

                local toolbarGroup, finalizeToolbar = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, linegroup1)
                finalizeToolbar()
                block:AddChild(toolbarGroup)
                block:AddChild(linegroup1)
                pcontainer:AddChild(block)
            elseif action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then
                local macroPanel = AceGUI:Create("InlineGroup")
                if GSE.isEmpty(action.type) then
                    action.type = "macro"
                    action.macro = ""
                end
                macroPanel:SetLayout("List")
                macroPanel:SetFullWidth(true)
                macroPanel:SetAutoAdjustHeight(true)

                local linegroup1, finalizeToolbar = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)
                finalizeToolbar()

                macroPanel:AddChild(linegroup1)

                local compiledMacro = AceGUI:Create("Label")
                compiledMacro:SetFullHeight(true)

                local spellEditBox, macroeditbox =
                    GSE.CreateSpellEditBox(action, version, keyPath, editframe.Sequence, compiledMacro, editframe.frame)

                local unitEditBox = AceGUI:Create("EditBox")
                unitEditBox:SetLabel(L["Unit Name"])

                unitEditBox:SetWidth(250)
                unitEditBox:DisableButton(true)
                unitEditBox:SetText(action.unit)
                --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Versions[version])
                unitEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].unit = value
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Versions[version])
                    end
                )
                unitEditBox:SetCallback(
                    "OnEditFocusLost",
                    function()
                    end
                )
                local typegroup = AceGUI:Create("SimpleGroup")
                typegroup:SetFullWidth(true)
                typegroup:SetLayout("Flow")
                local actionicon = GSE.CreateIconControl(action, version, keyPath, editframe.Sequence, macroPanel.frame)
                typegroup:AddChild(actionicon)
                -- Refresh the icon when the user finishes editing the spell/item/toy field.
                spellEditBox:SetCallback("OnEditFocusLost", function()
                    actionicon:RefreshIcon()
                end)
                local spellradio = AceGUI:Create("CheckBox")
                spellradio:SetType("radio")
                spellradio:SetLabel(L["Spell"])
                spellradio:SetValue((action.type and action.type == "spell" or false))
                spellradio:SetWidth(70)
                local itemradio = AceGUI:Create("CheckBox")
                itemradio:SetType("radio")
                itemradio:SetLabel(L["Item"])
                itemradio:SetValue((action.type and action.type == "item" or false))
                itemradio:SetWidth(70)
                local macroradio = AceGUI:Create("CheckBox")
                macroradio:SetType("radio")
                macroradio:SetLabel(L["Macro"])
                macroradio:SetValue((action.type and action.type == "macro" or false))
                macroradio:SetWidth(70)
                local petradio = AceGUI:Create("CheckBox")
                petradio:SetType("radio")
                petradio:SetLabel(L["Pet"])
                petradio:SetValue((action.type and action.type == "pet" or false))
                petradio:SetWidth(70)
                local toyradio = AceGUI:Create("CheckBox")
                toyradio:SetType("radio")
                toyradio:SetLabel(L["Toy"])
                toyradio:SetValue((action.type and action.type == "toy" or false))
                toyradio:SetWidth(70)
                typegroup:AddChild(macroradio)
                typegroup:AddChild(spellradio)
                typegroup:AddChild(itemradio)
                typegroup:AddChild(petradio)
                typegroup:AddChild(toyradio)

                local spellcontainer = AceGUI:Create("SimpleGroup")
                spellcontainer:SetLayout("List")
                spellcontainer:SetFullWidth(true)

                -- Callback factory for action-type radio buttons.
                -- Each entry: which radio widget, which action.type string, which action
                -- field receives the text value, and which edit box to read it from.
                -- macroradio also clears action.unit (original behaviour preserved).
                local radioConfigs = {
                    { radio = spellradio, type = "spell", actionField = "spell",  sourceBox = spellEditBox  },
                    { radio = itemradio,  type = "item",  actionField = "item",   sourceBox = spellEditBox  },
                    { radio = petradio,   type = "pet",   actionField = "action", sourceBox = spellEditBox  },
                    { radio = toyradio,   type = "toy",   actionField = "toy",    sourceBox = spellEditBox  },
                    { radio = macroradio, type = "macro", actionField = "macro",  sourceBox = macroeditbox, clearUnit = true },
                }
                local actionTypeFields = {"spell", "macro", "item", "toy", "action"}

                local function makeRadioCallback(cfg)
                    return function(sel, object, value)
                        if value ~= true then return end
                        for _, other in ipairs(radioConfigs) do
                            if other.radio ~= cfg.radio then
                                other.radio:SetValue(false)
                            end
                        end
                        for _, field in ipairs(actionTypeFields) do
                            action[field] = nil
                        end
                        if cfg.clearUnit then action.unit = nil end
                        action[cfg.actionField] = cfg.sourceBox:GetText()
                        action.type = cfg.type
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                end

                for _, cfg in ipairs(radioConfigs) do
                    cfg.radio:SetCallback("OnValueChanged", makeRadioCallback(cfg))
                end

                spellcontainer:AddChild(typegroup)
                if action.type == "macro" then
                    local macrolayout = AceGUI:Create("SimpleGroup")
                    macrolayout:SetLayout("Flow")
                    macrolayout:SetFullWidth(true)
                    local compiledmacrotext =
                        GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                    local lenMacro = string.len(compiledmacrotext)
                    local charcount
                    if lenMacro > 255 then
                        charcount =
                            string.format(
                            GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                            lenMacro
                        )
                    else
                        charcount = string.format(L["%s/255 Characters Used"], lenMacro)
                    end
                    compiledmacrotext = compiledmacrotext .. "\n\n" .. charcount

                    compiledMacro:SetText(compiledmacrotext)
                    compiledMacro.label:SetNonSpaceWrap(true)
                    compiledMacro:SetRelativeWidth(0.45)

                    local spacerm = AceGUI:Create("Label")
                    spacerm:SetRelativeWidth(0.03)
                    macrolayout:AddChild(macroeditbox)
                    macrolayout:AddChild(spacerm)
                    macrolayout:AddChild(compiledMacro)

                    spellcontainer:AddChild(macrolayout)
                else
                    local editcontainer = AceGUI:Create("SimpleGroup")
                    editcontainer:SetLayout("Flow")
                    editcontainer:SetFullWidth(true)
                    editcontainer:AddChild(spellEditBox)
                    editcontainer:AddChild(unitEditBox)
                    spellcontainer:AddChild(editcontainer)
                end

                macroPanel:AddChild(spellcontainer)
                local typerow = AceGUI:Create("SimpleGroup")
                typerow:SetLayout("Flow")
                typerow:SetFullWidth(true)
                local actiontype = AceGUI:Create("CheckBox")
                actiontype:SetType("checkbox")
                actiontype:SetLabel(L["Repeat"])
                actiontype:SetValue(action.Type == Statics.Actions.Repeat and true or false)
                actiontype:SetWidth(70)

                local interval = AceGUI:Create("EditBox")
                interval:SetWidth(30)
                interval:SetText(action.Interval and action.Interval or 3)
                interval:SetDisabled(action.Type == Statics.Actions.Action and true or false)
                interval:DisableButton(true)
                interval.editbox:SetNumeric(true)
                interval:SetCallback(
                    "OnRelease",
                    function(self, event, text)
                        interval.editbox:SetNumeric(false)
                    end
                )
                interval:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].Interval = value
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Versions[version])
                    end
                )
                actiontype:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            editframe.Sequence.Versions[version].Actions[keyPath].Type = Statics.Actions.Repeat
                            interval:SetDisabled(false)
                        else
                            editframe.Sequence.Versions[version].Actions[keyPath].Type = Statics.Actions.Action
                            interval:SetDisabled(true)
                        end
                    end
                )
                typerow:AddChild(actiontype)
                typerow:AddChild(interval)
                macroPanel:AddChild(typerow)
                pcontainer:AddChild(macroPanel)
            elseif action.Type == Statics.Actions.Loop then
                local layout3 = AceGUI:Create("InlineGroup")
                layout3:SetFullWidth(true)
                layout3:SetLayout("List")
                local linegroup1, finalizeToolbar = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, layout3)

                local stepdropdown = AceGUI:Create("Dropdown")
                stepdropdown:SetLabel(L["Step Function"])
                stepdropdown:SetWidth(200)
                stepdropdown:SetList(
                    {
                        [Statics.Sequential] = L["Sequential (1 2 3 4)"],
                        [Statics.Priority] = L["Priority List (1 12 123 1234)"],
                        [Statics.ReversePriority] = L["Reverse Priority (1 21 321 4321)"],
                        [Statics.Random] = L["Random - It will select .... a spell, any spell"]
                    }
                )
                stepdropdown:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Step Function"],
                            L[
                                "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
                            ],
                            editframe
                        )
                    end
                )
                stepdropdown:SetValue(action.StepFunction)
                stepdropdown:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                stepdropdown:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].StepFunction = value
                    end
                )

                local looplimit = AceGUI:Create("EditBox")
                looplimit:SetLabel(L["Repeat"])
                looplimit:DisableButton(true)
                looplimit:SetMaxLetters(4)
                looplimit:SetWidth(100)

                if type(action.Repeat) ~= "number" or action.Repeat < 1 then
                    action.Repeat = 1
                end
                looplimit:SetText(action.Repeat)
                looplimit:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Repeat"], L["How many times does this action repeat"], editframe)
                    end
                )
                looplimit:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                looplimit:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        value = tonumber(value)
                        if type(value) == "number" and value > 0 then
                            editframe.Sequence.Versions[version].Actions[keyPath].Repeat = value
                        end
                    end
                )

                local spacerlabel1 = AceGUI:Create("Label")
                spacerlabel1:SetWidth(15)
                linegroup1:AddChild(spacerlabel1)
                linegroup1:AddChild(stepdropdown)
                local spacerlabel2 = AceGUI:Create("Label")
                spacerlabel2:SetWidth(5)
                linegroup1:AddChild(spacerlabel2)
                linegroup1:AddChild(looplimit)
                finalizeToolbar()

                layout3:AddChild(linegroup1)
                local macroGroup = AceGUI:Create("SimpleGroup")
                macroGroup:SetFullWidth(true)
                macroGroup:SetLayout("List")
                for key, act in ipairs(action) do
                    local newKeyPath = {}
                    for _, v in ipairs(keyPath) do
                        table.insert(newKeyPath, v)
                    end
                    table.insert(newKeyPath, key)
                    drawAction(macroGroup, act, version, newKeyPath)
                end

                layout3:AddChild(macroGroup)
                pcontainer:AddChild(layout3)
            elseif action.Type == Statics.Actions.If then
                local macroPanel = AceGUI:Create("InlineGroup")
                macroPanel:SetFullWidth(true)
                macroPanel:SetLayout("List")
                macroPanel:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        macroPanel.frame:SetBackdrop(nil)
                    end
                )
                local linegroup1, finalizeToolbar = GetBlockToolbar(version, keyPath, treepath, false, hlabel, macroPanel)
                finalizeToolbar()

                local booleanEditBox = AceGUI:Create("EditBox")
                booleanEditBox:SetLabel(L["Variable"])
                booleanEditBox:SetWidth(250)
                booleanEditBox:DisableButton(true)
                booleanEditBox:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Variable"],
                            L["Enter the implementation link for this variable. Use '= true' or '= false' to test."],
                            editframe
                        )
                    end
                )
                if not GSE.isEmpty(action.Variable) then
                    booleanEditBox:SetText(action.Variable)
                else
                    booleanEditBox:SetText("= true")
                    action.Variable = "= true"
                end
                booleanEditBox:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                booleanEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].Variable = value
                        action.Variable = value
                    end
                )
                if GSE.Patron then
                    booleanEditBox.editbox:SetScript(
                        "OnTabPressed",
                        function(widget, button, down)
                            MenuUtil.CreateContextMenu(
                                editframe.frame,
                                function(ownerRegion, rootDescription)
                                    rootDescription:CreateTitle(L["Insert GSE Variable"])
                                    for k, _ in pairs(GSEVariables) do
                                        rootDescription:CreateButton(
                                            k,
                                            function()
                                                booleanEditBox:SetText([[=GSE.V["]] .. k .. [["]()]])
                                                editframe.Sequence.Versions[version].Actions[keyPath].Variable =
                                                    [[=GSE.V["]] .. k .. [["]()]]
                                                action.Variable = [[=GSE.V["]] .. k .. [["]()]]
                                            end
                                        )
                                    end
                                    rootDescription:CreateTitle(L["Insert Test Case"])
                                    rootDescription:CreateButton(
                                        "True",
                                        function()
                                            booleanEditBox:SetText([[= true]])
                                            editframe.Sequence.Versions[version].Actions[keyPath].Variable = [[= true]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                    rootDescription:CreateButton(
                                        "False",
                                        function()
                                            booleanEditBox:SetText([[= false]])
                                            editframe.Sequence.Versions[version].Actions[keyPath].Variable = [[= false]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
                linegroup1:AddChild(booleanEditBox)

                local trueKeyPath = GSE.CloneSequence(keyPath)
                table.insert(trueKeyPath, 1)
                local trueGroup = AceGUI:Create("InlineGroup")
                trueGroup:SetFullWidth(true)
                trueGroup:SetLayout("List")

                local tlabel = AceGUI:Create("Label")
                tlabel:SetText("True")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                tlabel:SetFontObject(GameFontNormalLarge)
                tlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))

                local trueContainer = AceGUI:Create("SimpleGroup")
                trueContainer:SetLayout("Flow")
                trueContainer:SetFullWidth(true)

                local toolbar, finalizeToolbar1 = GetBlockToolbar(version, trueKeyPath, treepath, true, tlabel, trueContainer, true, true, true)
                finalizeToolbar1()
                trueGroup:AddChild(toolbar)

                for key, act in ipairs(action[1]) do
                    local newKeyPath = GSE.CloneSequence(trueKeyPath)
                    table.insert(newKeyPath, key)
                    drawAction(trueGroup, act, version, newKeyPath)
                end

                macroPanel:AddChild(linegroup1)

                trueContainer:AddChild(trueGroup)
                macroPanel:AddChild(trueContainer)

                -- macroPanel:AddChild(falseGroup)
                local falseKeyPath = GSE.CloneSequence(keyPath)
                table.insert(falseKeyPath, 2)
                local falsegroup = AceGUI:Create("InlineGroup")
                falsegroup:SetFullWidth(true)
                falsegroup:SetLayout("List")

                local flabel = AceGUI:Create("Label")
                flabel:SetText("False")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                flabel:SetFontObject(GameFontNormalLarge)
                flabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
                local falsecontainer = AceGUI:Create("SimpleGroup")
                falsecontainer:SetFullWidth(true)
                falsecontainer:SetLayout("Flow")

                local toolbar2, finalizeToolbar2 = GetBlockToolbar(version, falseKeyPath, treepath, true, flabel, falsecontainer, true, true, true)
                finalizeToolbar2()
                falsegroup:AddChild(toolbar2)

                for key, act in ipairs(action[2]) do
                    local newKeyPath = GSE.CloneSequence(falseKeyPath)
                    table.insert(newKeyPath, key)
                    drawAction(falsegroup, act, version, newKeyPath)
                end

                falsecontainer:AddChild(falsegroup)
                macroPanel:AddChild(falsecontainer)
                pcontainer:AddChild(macroPanel)
            elseif action.Type == Statics.Actions.Embed then
                local macroPanel = AceGUI:Create("InlineGroup")
                macroPanel:SetFullWidth(true)
                macroPanel:SetLayout("List")
                macroPanel:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        macroPanel.frame:SetBackdrop(nil)
                    end
                )
                local linegroup1, finalizeToolbar = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)
                finalizeToolbar()
                macroPanel:AddChild(linegroup1)
                local SequenceDropDown = AceGUI:Create("Dropdown")
                SequenceDropDown:SetFullWidth(true)

                local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
                for k, v in GSE.pairsByKeys(GSE.GetSequenceNames(), GSE.AlphabeticalTableSortAlgorithm) do
                    if v ~= editframe.Sequence.MetaData.Name then
                        local elements = GSE.split(k, ",")
                        local classid, specid = tonumber(elements[1]), tonumber(elements[2])

                        if cid ~= classid then
                            local classinfo, classfile = GetClassInfo(cid)
                            local val = C_ClassColor and WrapTextInColorCode(classinfo, C_ClassColor.GetClassColor(classfile):GenerateHexColor()) or L["Global"]
                            local key = classid .. val

                            SequenceDropDown:AddItem(key, val)
                            SequenceDropDown:SetItemDisabled(key, true)
                            cid = classid
                        end
                        if GetSpecializationInfoByID then
                            if sid ~= specid and sid > 13 and specid > 13 then
                                local val = select(2, GetSpecializationInfoByID(specid))
                                local key = specid .. val

                                SequenceDropDown:AddItem(key, val)
                                SequenceDropDown:SetItemDisabled(key, true)
                                sid = specid
                            end
                        end
                        SequenceDropDown:AddItem(v, v)
                    end
                end
                for k, _ in pairs(GSESequences[0]) do
                    SequenceDropDown:AddItem(k, k)
                end
                SequenceDropDown:SetMultiselect(false)
                SequenceDropDown:SetLabel(L["Sequence"])
                if action.Sequence then
                    SequenceDropDown:SetValue(action.Sequence)
                end
                SequenceDropDown:SetCallback(
                    "OnValueChanged",
                    function(obj, event, key, checked)
                        editframe.Sequence.Versions[version].Actions[keyPath] = {
                            ["Type"] = Statics.Actions.Embed,
                            ["Sequence"] = key
                        }
                    end
                )


                macroPanel:AddChild(SequenceDropDown)
                pcontainer:AddChild(macroPanel)
            end
        end
        if GSE.isEmpty(editframe.Sequence.Versions[version].Actions) then
            editframe.Sequence.Versions[version].Actions = {
                [1] = {
                    ["macro"] = "Need Macro Here",
                    ["Type"] = Statics.Actions.Action
                }
            }
        end

        local macro = editframe.Sequence.Versions[version].Actions

        local font = CreateFont("seqPanelFont")
        font:SetFontObject(GameFontNormal)
        font:SetJustifyV("BOTTOM")

        for key, action in ipairs(macro) do
            local macroPanel = AceGUI:Create("SimpleGroup")
            macroPanel:SetFullWidth(true)
            macroPanel:SetLayout("List")
            local keyPath = {
                [1] = key
            }
            drawAction(macroPanel, action, version, keyPath, path)

            tcontainer:AddChild(macroPanel)
        end
    end
    editframe.DrawSequenceEditor = function(...)
        DrawSequenceEditor(...)
    end
    local function GUIDrawMacroEditor(container, version, path)
        version = tonumber(version)

        if GSE.isEmpty(editframe.Sequence) then
            editframe.Sequence = {
                ["MetaData"] = {
                    ["Author"] = GSE.GetCharacterName(),
                    ["Default"] = 1,
                    ["SpecID"] = GSE.GetCurrentSpecID(),
                    ["GSEVersion"] = GSE.VersionString
                },
                ["Versions"] = {
                    [1] = {
                        ["Actions"] = {
                            [1] = {
                                ["macro"] = "Need Macro Here",
                                ["type"] = "spell",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        ["InbuiltVariables"] = {}
                    }
                }
            }
        end
        local macrocontainer = AceGUI:Create("InlineGroup")
        macrocontainer:SetTitle(L["Sequence"])
        macrocontainer:SetFullWidth(true)
        setmetatable(editframe.Sequence.Versions[version].Actions, Statics.TableMetadataFunction)
        editframe.booleanFunctions = {}
        editframe.numericFunctions = {}

        local layoutcontainer = AceGUI:Create("SimpleGroup")

        layoutcontainer:SetFullWidth(true)
        layoutcontainer:SetLayout("Flow")

        local linegroup1 = AceGUI:Create("SimpleGroup")
        linegroup1:SetLayout("Flow")

        linegroup1:SetFullWidth(true)

        local spacerlabel1 = AceGUI:Create("Label")
        spacerlabel1:SetWidth(5)

        local basespellspacer = AceGUI:Create("Label")
        basespellspacer:SetWidth(5)

        local spacerlabel7 = AceGUI:Create("Label")
        spacerlabel7:SetWidth(10)

        local delversionbutton = AceGUI:Create("Button")
        delversionbutton:SetText(L["Delete Version"])
        delversionbutton:SetWidth(130)
        delversionbutton:SetCallback(
            "OnClick",
            function()
                version = tonumber(version)
                local sequence = editframe.Sequence
                if #sequence.Versions <= 1 then
                    GSE.Print(
                        L["This is the only version of this macro.  Delete the entire macro to delete this version."]
                    )
                    return
                end
                if sequence.MetaData.Default == version then
                    GSE.Print(
                        L[
                            "You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."
                        ]
                    )
                    return
                end
                local printtext = L["Macro Version %d deleted."]
                if sequence.MetaData.PVP == version then
                    sequence.MetaData.PVP = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["PVP setting changed to Default."]
                end
                if sequence.MetaData.Arena == version then
                    sequence.MetaData.Arena = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Arena setting changed to Default."]
                end
                if sequence.MetaData.Raid == version then
                    sequence.MetaData.Raid = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Raid setting changed to Default."]
                end
                if sequence.MetaData.Mythic == version then
                    sequence.MetaData.Mythic = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Mythic setting changed to Default."]
                end
                if sequence.MetaData.Heroic == version then
                    sequence.MetaData.Heroic = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Heroic setting changed to Default."]
                end
                if sequence.MetaData.Dungeon == version then
                    sequence.MetaData.Dungeon = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Dungeon setting changed to Default."]
                end
                if sequence.MetaData.Party == version then
                    sequence.MetaData.Party = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Party setting changed to Default."]
                end
                if sequence.MetaData.MythicPlus == version then
                    sequence.MetaData.MythicPlus = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Mythic+ setting changed to Default."]
                end
                if sequence.MetaData.Timewalking == version then
                    sequence.MetaData.Timewalking = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Timewalking setting changed to Default."]
                end
                if sequence.MetaData.Scenario == version then
                    sequence.MetaData.Scenario = sequence.MetaData.Default
                    printtext = printtext .. " " .. L["Delves and Scenarios setting changed to Default."]
                end

                if sequence.MetaData.Default > 1 then
                    sequence.MetaData.Default = tonumber(sequence.MetaData.Default) - 1
                else
                    sequence.MetaData.Default = 1
                end

                if
                    not GSE.isEmpty(sequence.MetaData.PVP) and sequence.MetaData.PVP > 1 and
                        sequence.MetaData.PVP >= version
                 then
                    sequence.MetaData.PVP = tonumber(sequence.MetaData.PVP) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Arena) and sequence.MetaData.Arena > 1 and
                        sequence.MetaData.Arena >= version
                 then
                    sequence.MetaData.Arena = tonumber(sequence.MetaData.Arena) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Raid) and sequence.MetaData.Raid > 1 and
                        sequence.MetaData.Raid >= version
                 then
                    sequence.MetaData.Raid = tonumber(sequence.MetaData.Raid) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Mythic) and sequence.MetaData.Mythic > 1 and
                        sequence.MetaData.Mythic >= version
                 then
                    sequence.MetaData.Mythic = tonumber(sequence.MetaData.Mythic) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.MythicPlus) and sequence.MetaData.MythicPlus > 1 and
                        sequence.MetaData.MythicPlus >= version
                 then
                    sequence.MetaData.MythicPlus = tonumber(sequence.MetaData.MythicPlus) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Timewalking) and sequence.MetaData.Timewalking > 1 and
                        sequence.MetaData.Timewalking >= version
                 then
                    sequence.MetaData.Timewalking = tonumber(sequence.MetaData.Timewalking) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Heroic) and sequence.MetaData.Heroic > 1 and
                        sequence.MetaData.Heroic >= version
                 then
                    sequence.MetaData.Heroic = tonumber(sequence.MetaData.Heroic) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Dungeon) and sequence.MetaData.Dungeon > 1 and
                        sequence.MetaData.Dungeon >= version
                 then
                    sequence.MetaData.Dungeon = tonumber(sequence.MetaData.Dungeon) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Party) and sequence.MetaData.Party > 1 and
                        sequence.MetaData.Party >= version
                 then
                    sequence.MetaData.Party = tonumber(sequence.MetaData.Party) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Scenario) and sequence.MetaData.Scenario > 1 and
                        sequence.MetaData.Scenario >= version
                 then
                    sequence.MetaData.Scenario = tonumber(sequence.MetaData.Scenario) - 1
                end
                table.remove(sequence.Versions, version)
                printtext = printtext .. " " .. L["This change will not come into effect until you save this macro."]
                editframe.ManageTree()
                treeContainer:SelectByValue(path)
                editframe:SetStatusText(string.format(printtext, version))
                C_Timer.After(
                    5,
                    function()
                        editframe:SetStatusText(editframe.statusText)
                    end
                )
            end
        )
        delversionbutton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Delete Version"],
                    L[
                        "Delete this version of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
                    ],
                    editframe
                )
            end
        )
        delversionbutton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local delspacerlabel = AceGUI:Create("Label")
        delspacerlabel:SetWidth(5)

        local raweditbutton = AceGUI:Create("Button")
        raweditbutton:SetText(L["Raw Edit"])
        raweditbutton:SetWidth(100)
        raweditbutton:SetCallback(
            "OnClick",
            function()
                drawRawEditor(
                    macrocontainer,
                    version,
                    GSE.Dump(GSE.UnEscapeTableRecursive(editframe.Sequence.Versions[version])),
                    path
                )

                GSE.WagoAnalytics:Switch("Raw Edit", true)
            end
        )
        raweditbutton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Raw Edit"],
                    L[
                        "Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."
                    ],
                    editframe
                )
            end
        )
        raweditbutton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local previewMacro = AceGUI:Create("Button")
        previewMacro:SetText(L["Compiled Template"])
        previewMacro:SetWidth(150)
        previewMacro:SetCallback(
            "OnClick",
            function()
                local GSE3Macro = GSE.CompileTemplate(editframe.Sequence.Versions[version])
                GSE.GUIShowCompiledMacroGui(GSE3Macro, editframe.SequenceName .. " : " .. version, editframe)
                GSE.WagoAnalytics:Switch("Compile Template", true)
            end
        )
        previewMacro:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Compiled Template"], L["Show the compiled version of this macro."], editframe)
            end
        )
        previewMacro:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local spacerlabel2 = AceGUI:Create("Label")
        spacerlabel2:SetWidth(6)

        local addLoopButton = AceGUI:Create("Icon")
        local addActionButton = AceGUI:Create("Icon")
        local addPauseButton = AceGUI:Create("Icon")
        local addIfButton = AceGUI:Create("Icon")
        local addEmbedButton = AceGUI:Create("Icon")

        addActionButton:SetImageSize(30, 30)
        addActionButton:SetWidth(30)
        addActionButton:SetHeight(30)
        addActionButton:SetImage(Statics.ActionsIcons.Action)

        addActionButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["macro"] = "Need Stuff Here",
                    ["type"] = "macro",
                    ["Type"] = Statics.Actions.Action
                }
                table.insert(editframe.Sequence.Versions[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addActionButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
            end
        )
        addActionButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addLoopButton:SetImageSize(30, 30)
        addLoopButton:SetWidth(30)
        addLoopButton:SetHeight(30)
        addLoopButton:SetImage(Statics.ActionsIcons.Loop)

        addLoopButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = {
                        ["macro"] = "Need Stuff Here",
                        ["type"] = "macro",
                        ["Type"] = Statics.Actions.Action
                    },
                    ["StepFunction"] = Statics.Sequential,
                    ["Type"] = Statics.Actions.Loop,
                    ["Repeat"] = 2
                }
                -- setmetatable(newAction, Statics.TableMetadataFunction)
                table.insert(editframe.Sequence.Versions[version].Actions, 1, newAction)
                if not editframe.scrollstatus then
                    editframe.scrollStatus = {}
                end
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addLoopButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
            end
        )
        addLoopButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addPauseButton:SetImageSize(30, 30)
        addPauseButton:SetWidth(30)
        addPauseButton:SetHeight(30)
        addPauseButton:SetImage(Statics.ActionsIcons.Pause)

        addPauseButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["Variable"] = "GCD",
                    ["Type"] = Statics.Actions.Pause
                }
                table.insert(editframe.Sequence.Versions[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addPauseButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
            end
        )
        addPauseButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addIfButton:SetImageSize(30, 30)
        addIfButton:SetWidth(30)
        addIfButton:SetHeight(30)
        addIfButton:SetImage(Statics.ActionsIcons.If)

        addIfButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = {
                        [1] = {
                            ["macro"] = "Need True Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    [2] = {
                        [1] = {
                            ["macro"] = "Need False Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    ["Type"] = Statics.Actions.If
                }
                table.insert(editframe.Sequence.Versions[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addIfButton:SetCallback(
            "OnEnter",
            function()
                if #editframe.booleanFunctions > 0 then
                    GSE.CreateToolTip(
                        L["Add If"],
                        L[
                            "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                        ],
                        editframe
                    )
                else
                    GSE.CreateToolTip(
                        L["Add If"],
                        L["If Blocks require a variable that returns either true or false.  Create the variable first."],
                        editframe
                    )
                end
            end
        )
        addIfButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addEmbedButton:SetImageSize(30, 30)
        addEmbedButton:SetWidth(30)
        addEmbedButton:SetHeight(30)
        addEmbedButton:SetImage(Statics.ActionsIcons.Embed)

        addEmbedButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["Type"] = Statics.Actions.Embed
                }
                table.insert(editframe.Sequence.Versions[version].Actions, 1, newAction)
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addEmbedButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Add Embed"],
                    L[
                        "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                    ],
                    editframe
                )
            end
        )
        addEmbedButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        local linegroup3 = AceGUI:Create("SimpleGroup")
        linegroup3:SetLayout("Flow")
        linegroup3:SetFullWidth(true)

        local versionLabel = AceGUI:Create("EditBox")
        versionLabel:SetWidth(200)
        versionLabel:SetLabel(L["Version"] .. " " .. L["Name"])
        versionLabel:SetText(BuildVersionLabel(version, editframe.Sequence.Versions[version].Label, true))
        versionLabel:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                editframe.Sequence.Versions[version].Label = text
            end
        )
        versionLabel:DisableButton(true)

        local spacerlabel3 = AceGUI:Create("Label")
        spacerlabel3:SetWidth(6)

        linegroup1:AddChild(addActionButton)
        linegroup1:AddChild(addLoopButton)
        linegroup1:AddChild(addPauseButton)
        linegroup1:AddChild(addIfButton)
        linegroup1:AddChild(addEmbedButton)
        linegroup1:AddChild(versionLabel)
        linegroup1:AddChild(spacerlabel1)
        linegroup1:AddChild(basespellspacer)
        linegroup1:AddChild(previewMacro)
        linegroup1:AddChild(delspacerlabel)
        if GSE.Patron or GSE.Developer then
            linegroup1:AddChild(raweditbutton)
        end

        linegroup1:AddChild(spacerlabel7)
        linegroup1:AddChild(delversionbutton)
        layoutcontainer:AddChild(linegroup1)

        DrawSequenceEditor(macrocontainer, version, path)
        if not editframe.Sequence.MetaData.DisableEditor then
            layoutcontainer:AddChild(macrocontainer)
        end

        local toolbarcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
        toolbarcontainer:SetFullWidth(true)
        toolbarcontainer:SetLayout("list")

        local toolbarrow1 = AceGUI:Create("SimpleGroup")
        toolbarrow1:SetLayout("Flow")
        toolbarrow1:SetFullWidth(true)

        if GSE.isEmpty(editframe.Sequence.Versions[version].InbuiltVariables) then
            editframe.Sequence.Versions[version].InbuiltVariables = {}
        end
        local combatresetcheckbox = AceGUI:Create("CheckBox")
        combatresetcheckbox:SetType("checkbox")
        combatresetcheckbox:SetWidth(78)
        combatresetcheckbox:SetTriState(true)
        combatresetcheckbox:SetLabel(L["Combat"])
        toolbarrow1:AddChild(combatresetcheckbox)
        combatresetcheckbox:SetValue(editframe.Sequence.Versions[version].InbuiltVariables.Combat)
        combatresetcheckbox:SetCallback(
            "OnValueChanged",
            function(sel, object, value)
                editframe.Sequence.Versions[version].InbuiltVariables.Combat = value
            end
        )
        combatresetcheckbox:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Combat"], L["Reset this macro when you exit combat."], editframe)
            end
        )
        combatresetcheckbox:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local headingspace1 = AceGUI:Create("Label")
        headingspace1:SetText(" ")
        local heading1 = AceGUI:Create("Label")
        heading1:SetText(L["Resets"])
        --toolbarcontainer:AddChild(toolbarrow2)
        toolbarcontainer:AddChild(headingspace1)
        toolbarcontainer:AddChild(heading1)
        toolbarcontainer:AddChild(toolbarrow1)
        layoutcontainer:AddChild(toolbarcontainer)
        container:AddChild(layoutcontainer)
    end

    editframe.frame:SetScript(
        "OnSizeChanged",
        function(self, width, height)
            editframe.Height = height
            editframe.Width = width
            if editframe.Height > GetScreenHeight() then
                editframe.Height = GetScreenHeight() - 10
                editframe:SetHeight(editframe.Height)
            end
            if editframe.Height < 500 then
                editframe.Height = 500
                editframe:SetHeight(editframe.Height)
            end
            if editframe.Width < 700 then
                editframe.Width = 700
                editframe:SetWidth(editframe.Width)
            end
            GSEOptions.frameLocations.sequenceeditor.height = editframe.Height
            GSEOptions.frameLocations.sequenceeditor.width = editframe.Width
            if editframe.scroller then
                editframe.scroller:SetHeight(editframe.Height - SCROLLCONTAINER_OFFSET)
                editframe.scroller:DoLayout()
            end
        end
    )

    if GSE.isEmpty(GSE.CreateSpellEditBox) then
        GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro, frame)
            local spellEditBox = AceGUI:Create("EditBox")

            spellEditBox:SetWidth(250)
            spellEditBox:DisableButton(true)

            if GSE.isEmpty(sequence.Versions[version].Actions[keyPath].type) then
                sequence.Versions[version].Actions[keyPath].type = "spell"
            end
            if GSE.isEmpty(action.type) then
                action.type = "spell"
            end

            local spelltext

            if action.toy then
                spelltext = action.toy
                spellEditBox:SetLabel(L["Toy"])
            elseif action.item then
                spelltext = action.item
                spellEditBox:SetLabel(L["Item"])
            elseif action.macro then
                if string.sub(GSE.UnEscapeString(action.macro), 1, 1) == "/" then
                    spelltext = GSE.CompileMacroText(action.macro, Statics.TranslatorMode.Current)
                else
                    spelltext = GSE.UnEscapeString(action.macro)
                end
            elseif action.action then
                spellEditBox:SetLabel(L["Pet Ability"])
                spelltext = action.action
            else
                spellEditBox:SetLabel(L["Spell"])
                local translatedSpell = GSE.GetSpellId(action.spell, Statics.TranslatorMode.Current)
                if translatedSpell then
                    spelltext = translatedSpell
                else
                    spelltext = action.spell
                end
            end

            spellEditBox:SetText(spelltext)

            spellEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    if sequence.Versions[version].Actions[keyPath].type == "pet" then
                        sequence.Versions[version].Actions[keyPath].action = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "macro" then
                        if string.sub(value, 1, 1) == "/" then
                            sequence.Versions[version].Actions[keyPath].macro =
                                GSE.TranslateString(value, Statics.TranslatorMode.Current)
                        else
                            sequence.Versions[version].Actions[keyPath].macro = value
                        end
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                        sequence.Versions[version].Actions[keyPath].unit = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "item" then
                        sequence.Versions[version].Actions[keyPath].item = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "toy" then
                        sequence.Versions[version].Actions[keyPath].toy = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                    else
                        local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                        if storedValue then
                            sequence.Versions[version].Actions[keyPath].spell = storedValue
                        else
                            sequence.Versions[version].Actions[keyPath].spell = value
                        end
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    end

                end
            )
            spellEditBox:SetCallback(
                "OnEditFocusLost",
                function()
                end
            )
            local macroEditBox = AceGUI:Create("MultiLineEditBox")
            macroEditBox:SetLabel(L["Macro Name or Macro Commands"])
            macroEditBox:DisableButton(true)
            macroEditBox:SetNumLines(5)
            macroEditBox:SetRelativeWidth(0.5)
            macroEditBox:SetText(spelltext)
            macroEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    if string.sub(value, 1, 1) == "/" then
                        sequence.Versions[version].Actions[keyPath].macro =
                            GSE.CompileMacroText(value, Statics.TranslatorMode.ID)
                    else
                        sequence.Versions[version].Actions[keyPath].macro = value
                    end
                    sequence.Versions[version].Actions[keyPath].spell = nil
                    sequence.Versions[version].Actions[keyPath].action = nil
                    sequence.Versions[version].Actions[keyPath].item = nil
                    sequence.Versions[version].Actions[keyPath].toy = nil
                    local compiledmacrotext =
                        GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                    local lenMacro = string.len(compiledmacrotext)
                    local charcount
                    if lenMacro > 255 then
                        charcount =
                            string.format(
                            GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                            lenMacro
                        )
                    else
                        charcount = string.format(L["%s/255 Characters Used"], lenMacro)
                    end
                    compiledmacrotext = compiledmacrotext .. "\n\n" .. charcount
                    compiledMacro:SetText(compiledmacrotext)
                end
            )
            return spellEditBox, macroEditBox
        end
    end

    -- Expose helpers needed by the refactored tree module
    editframe.BuildVersionLabel = BuildVersionLabel
    editframe.GUIDrawMacroEditor = GUIDrawMacroEditor

    -- Install refactored modules — each overrides the matching editframe method
    -- with a cleanly separated implementation. The original closure versions above
    -- remain as a safety fallback and are superseded by these calls.
    GSE.GUI.SetupMetadata(editframe)
    GSE.GUI.SetupVariable(editframe)
    GSE.GUI.SetupKeybind(editframe)
    GSE.GUI.SetupMacro(editframe)
    GSE.GUI.SetupTree(editframe)

    function editframe:remoteSequenceUpdated(seqName)
        if seqName == editframe.SequenceName then
            if editframe.save then
                editframe:SetStatusText(seqName .. " " .. L["Saved"])
                editframe.save = nil
                C_Timer.After(
                    5,
                    function()
                        editframe:SetStatusText("")
                    end
                )
            else
                editframe:SetStatusText(
                    seqName .. " " .. L["modified in other window.  This view is now behind the current sequence."]
                )
            end
        end
        editframe.ManageTree()
    end

    return editframe
end

function GSE.ShowSequences()
    if not InCombatLockdown() or (GSE.PlayerSpellsLoaded and GSE.PlayerSpellsLoaded()) then
        local editframe = GSE.CreateEditor()
        editframe.ManageTree()
        editframe.treeContainer:SelectByValue("Sequences\001" .. GSE.GetCurrentClassID())
        editframe:Show()
    else
        GSE.Print(
            L[
                "You cannot open a new Sequence Editor window while you are in combat.  Please exit combat and then try again."
            ],
            Statics.DebugModules["Editor"]
        )
    end
end

local function remoteSeqences(message, seqName)
    if message == Statics.Messages.SEQUENCE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function remoteVariables(message, seqName)
    if message == Statics.Messages.VARIABLE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function collectionImported(message)
    if message == Statics.Messages.COLLECTION_IMPORTED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v.ManageTree()
            end
        end
    end
end

GSE:RegisterMessage(Statics.Messages.SEQUENCE_UPDATED, remoteSeqences)
GSE:RegisterMessage(Statics.Messages.VARIABLE_UPDATED, remoteVariables)
GSE:RegisterMessage(Statics.Messages.COLLECTION_IMPORTED, collectionImported)

--- Create a brand-new sequence with the given name and navigate to it.
-- Called by the GSE_NEW_SEQUENCE_NAME StaticPopup OnAccept / Enter handler.
function GSE.GUICreateNewSequence(editor, name, recordedstring)
    local classid = GSE.GetCurrentClassID()
    local sequence = {
        ["MetaData"] = {
            ["Author"]     = GSE.GetCharacterName(),
            ["Default"]    = 1,
            ["SpecID"]     = GSE.GetCurrentSpecID(),
            ["GSEVersion"] = GSE.VersionString,
            ["Name"]       = name,
        },
        ["Versions"] = {
            [1] = {
                ["Actions"] = {
                    [1] = { ["macro"] = "Need Macro Here", ["Type"] = Statics.Actions.Action }
                }
            }
        }
    }
    if not GSE.isEmpty(recordedstring) then
        sequence.Versions[1]["Actions"] = nil
        local recordedMacro = {}
        for _, v in ipairs(GSE.SplitMeIntoLines(recordedstring)) do
            local spellid = GSE.TranslateString(v, Statics.TranslatorMode.ID)
            if spellid then
                table.insert(recordedMacro, { ["Type"] = Statics.Actions.Action, ["type"] = "macro", ["macro"] = spellid })
            end
        end
        sequence.Versions[1]["Actions"] = recordedMacro
    end
    if GSE.isEmpty(sequence.WeakAuras) then sequence.WeakAuras = {} end
    GSESequences[classid][name] = GSE.EncodeMessage({name, sequence})
    GSE.Library[classid][name]  = sequence
    editor:SetStatusText("GSE: " .. GSE.VersionString)
    editor.SequenceName     = name
    editor.OrigSequenceName = name
    editor.Sequence         = sequence
    editor.ClassID          = classid
    editor.ManageTree()
    editor.treeContainer:SelectByValue(
        table.concat({"Sequences", classid, classid .. "," .. GSE.GetCurrentSpecID() .. "," .. name .. ",0", "config"}, "\001")
    )
end

--- Create a brand-new variable with the given name and navigate to it.
-- Called by the GSE_NEW_VARIABLE_NAME StaticPopup OnAccept / Enter handler.
function GSE.GUICreateNewVariable(editor, name)
    local defaultVariable = {
        ["funct"]    = "function()\n    return true\nend",
        ["comments"] = "",
        ["Author"]   = GSE.GetCharacterName(),
    }
    GSE.UpdateVariable(defaultVariable, name)
    editor.ManageTree()
    editor.treeContainer:SelectByValue("VARIABLES\001" .. name)
end

function GSE.GUILoadEditor(editor, key, recordedstring)
    if GSE.isEmpty(key) then
        StaticPopup_Show("GSE_NEW_SEQUENCE_NAME", nil, nil, {editor = editor, recordedstring = recordedstring})
        return
    end

    local elements = GSE.split(key, ",")
    local classid = tonumber(elements[1])
    local sequenceName = elements[3]

    local _, seq = GSE.DecodeMessage(GSESequences[classid][sequenceName])
    local sequence
    if seq then
        sequence = seq[2]
    end

    if GSE.isEmpty(sequence.WeakAuras) then
        sequence.WeakAuras = {}
    end
    editor:SetStatusText("GSE: " .. GSE.VersionString)
    editor.SequenceName = sequenceName
    editor.OrigSequenceName = sequenceName
    editor.Sequence = sequence
    editor.ClassID = classid
end

function GSE.ShowKeyBindings()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("KEYBINDINGS")
    editor:Show()
end

function GSE.ShowVariables()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("VARIABLES")
    editor:Show()
end

function GSE.ShowMacros()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("Macro")
    editor:Show()
end

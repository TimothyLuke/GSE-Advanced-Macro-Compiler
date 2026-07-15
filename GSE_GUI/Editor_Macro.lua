local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local DecodeMacroEditorText = GSE.DecodeMacroEditorText
local StoreMacroEditorText = GSE.StoreMacroEditorText

local function SetEditBoxLabelGap(widget, gap)
    if not (widget and widget.label and widget.editBox and widget.frame) then return end
    local labelHeight = widget.label:GetStringHeight()
    if not labelHeight or labelHeight <= 0 then labelHeight = 12 end
    local g = gap or (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    widget.editBox:ClearAllPoints()
    widget.editBox:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 4, -(labelHeight + g))
    widget.editBox:SetPoint("RIGHT", widget.frame, "RIGHT", -4, 0)
end

local function SetMultiLineLabelGap(widget, gap)
    if not (widget and widget.label and widget.scrollBG and widget.frame) then return end
    local labelHeight = widget.labelHeight or widget.label:GetStringHeight()
    if not labelHeight or labelHeight <= 0 then labelHeight = 12 end
    local scrollBarReserve = widget.scrollBarReserve or 24
    local g = gap or (UI.NativeStyle and UI.NativeStyle.labelBoxGap) or 2
    widget.scrollBG:ClearAllPoints()
    widget.scrollBG:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 0, -(labelHeight + g))
    widget.scrollBG:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -scrollBarReserve, 0)
end

local function SetMultiLineContentPadding(widget, padding)
    if not (widget and widget.scrollBG and widget.scrollFrame) then return end
    padding = padding or 2
    widget.leftOffset = padding
    widget.rightOffset = padding
    widget.verticalOffset = padding
    widget.scrollFrame:ClearAllPoints()
    widget.scrollFrame:SetPoint("TOPLEFT", widget.scrollBG, "TOPLEFT", padding, -padding)
    widget.scrollFrame:SetPoint("BOTTOMRIGHT", widget.scrollBG, "BOTTOMRIGHT", -padding, padding)
end

local function SetMacroTextCounter(widget, text)
    if text == nil and widget and widget.GetText then
        text = widget:GetText()
    end
    if GSE.GUI and GSE.GUI.SetMacroCountText then
        -- Show the COMPILED body length so the indicator matches the over-limit
        -- trigger (UpdateMacroLimitState) and what WoW enforces on the slot.
        -- Fall back to the raw typed length only if the compiled-length helper
        -- isn't loaded (e.g. a partial install).
        local lenMacro = (GSE.GUI.GetCompiledMacroBodyLength and GSE.GUI.GetCompiledMacroBodyLength(text or ""))
            or GSE.GetMacroEditorTextLength(text or "")
        GSE.GUI.SetMacroCountText(widget, lenMacro)
    end
    if GSE.GUI and GSE.GUI.UpdateMacroLimitState then
        GSE.GUI.UpdateMacroLimitState(widget, text)
    end
end

local function ConfigureCompiledMacroLabel(widget)
    if not widget then return end
    widget:SetFullWidth(true)
    if widget.label then
        if widget.label.SetWordWrap then widget.label:SetWordWrap(true) end
        if widget.label.SetNonSpaceWrap then widget.label:SetNonSpaceWrap(true) end
    end
    widget.OnWidthSet = function(self)
        if not (self.label and self.label.GetStringHeight) then return end
        local height = math.max(20, self.label:GetStringHeight() + 2)
        self.height = height
        self.frame:SetHeight(height)
    end
end

local function SetCompiledMacroText(widget, text)
    if not widget then return end
    widget:SetText(text)
    if widget.OnWidthSet then widget:OnWidthSet(widget.frame and widget.frame:GetWidth()) end
    if widget.parent and widget.parent.DoLayout then widget.parent:DoLayout() end
end

local function ConfigureMacroFieldLabel(widget)
    if widget and widget.label and widget.label.SetFontObject then widget.label:SetFontObject(GameFontNormalSmall) end
end

-- ---------------------------------------------------------------------------
-- buildMacroMenu()  →  "Macros" tree node
-- ---------------------------------------------------------------------------
local function buildMacroMenu()
    local maxAccountMacros = GSE.GetMaxAccountMacros()
    local maxmacros = maxAccountMacros + GSE.GetMaxCharacterMacros() + 2
    local tree = {
        value = "Macro",
        text = L["Macros"],
        icon = Statics.Icons.Macros,
        children = {
            {
                value = "A",
                text = L["Account Macros"],
                icon = Statics.Icons.Account,
                children = {}
            },
            {
                value = "P",
                text = L["Character Macros"],
                icon = Statics.Icons.Personal,
                children = {}
            }
        }
    }

    for macid = 1, maxmacros do
        local mname, micon = GetMacroInfo(macid)
        if mname then
            local node = {
                text = mname,
                value = macid,
                icon = micon
            }
            if macid <= maxAccountMacros then
                table.insert(tree.children[1].children, node)
            else
                table.insert(tree.children[2].children, node)
            end
        end
    end
    return tree
end

-- ---------------------------------------------------------------------------
-- showMacro(editframe, node, container)
-- ---------------------------------------------------------------------------
local function showMacro(editframe, node, container)
    -- Section header — uses the GSE macro asset icon, not the individual macro's WoW icon
    if GSE.GUI.AddSectionHeader then
        GSE.GUI.AddSectionHeader(container, L["Macros"] or "Macros", GSE.Static.Icons.Macros)
    end
    local char, realm = UnitFullName("player")

    local source = GSEMacros
    if node.value > GSE.GetMaxAccountMacros() then
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        source = GSEMacros[char .. "-" .. realm]
    end

    local manageGSE = UI:Create("CheckBox")
    manageGSE:SetType("radio")
    manageGSE:SetLabel(L["Manage Macro with GSE"])
    manageGSE:SetTriState(false)

    if GSE.isEmpty(source[node.name]) then
        source[node.name] = node
        manageGSE:SetValue(false)
    else
        if GSE.isEmpty(source[node.name].Managed) then
            manageGSE:SetValue(false)
        else
            manageGSE:SetValue(source[node.name].Managed)
        end
    end
    local managed = false
    if source[node.name] and source[node.name].Managed then
        managed = source[node.name].Managed
    end
    editframe.activeMacroName = node.name

    local headerGroup = UI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    -- Top-align the icon with the Macro Name field (top of the stack to its right).
    if headerGroup.SetFlowVAlign then headerGroup:SetFlowVAlign("TOP") end
    if headerGroup.SetFlowGap    then headerGroup:SetFlowGap(12) end

    local nameeditbox = UI:Create("EditBox")
    nameeditbox:SetLabel(L["Macro Name"])
    ConfigureMacroFieldLabel(nameeditbox)
    SetEditBoxLabelGap(nameeditbox, 2)
    nameeditbox:SetWidth(250)
    -- Fit the field to label+box (default frame is controlHeight*2=48, leaving ~12px
    -- dead space below the box). Trimming it pulls the Author field up.
    if nameeditbox.SetHeight then nameeditbox:SetHeight(36) end
    nameeditbox:SetCallback(
        "OnEnterPressed",
        function(self, _, text)
            local slot = GetMacroIndexByName(node.name)
            if slot then
                local oldName = node.name
                EditMacro(slot, text)
                node.name = text
                -- Clear the platform-id sidecar entry under the old name so
                -- the next Companion sync mints a fresh server identity.
                -- See Editor_Variable / Editor sequence rename for the
                -- v4↔v5 bouncing pattern this prevents.
                if oldName ~= text and GSEMacroPlatformIDs then
                    GSEMacroPlatformIDs[oldName] = nil
                end
            end
        end
    )
    nameeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Macro Name"],
                L[
                    "The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."
                ],
                editframe
            )
        end
    )
    nameeditbox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    nameeditbox:DisableButton(false)
    nameeditbox:SetText(node.name)

    -- Author — shown on the first macro page even before "Manage Macro with GSE" is
    -- checked. source[node.name] is always populated above, so writing .Author here
    -- is safe in the unmanaged state too.
    local authoreditbox = UI:Create("EditBox")
    authoreditbox:SetLabel(L["Author"])
    ConfigureMacroFieldLabel(authoreditbox)
    SetEditBoxLabelGap(authoreditbox, 2)
    authoreditbox:SetWidth(250)
    authoreditbox:DisableButton(true)
    authoreditbox:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Author"], L["The author of this Macro."], editframe)
    end)
    authoreditbox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    if not GSE.isEmpty(node.Author) then
        authoreditbox:SetText(node.Author)
    else
        authoreditbox:SetText(GSE.GetCharacterName())
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            node.Author = key
            source[node.name].Author = key
        end
    )

    local iconpicker = UI:Create("Icon")
    iconpicker:SetImageSize(80, 80)
    iconpicker.frame:RegisterForDrag("LeftButton")
    iconpicker.frame:SetScript(
        "OnDragStart",
        function()
            local sequencename = nameeditbox:GetText()
            if not GSE.isEmpty(sequencename) then
                local macroIndex = GetMacroIndexByName(sequencename)
                if macroIndex and macroIndex ~= 0 then
                    PickupMacro(sequencename)
                end
            end
        end
    )
    iconpicker:SetImage(node.icon)
    iconpicker:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Macro Icon"],
                L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."],
                editframe
            )
        end
    )
    iconpicker:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    -- Nudge the icon up 5px so its top lines up with the Macro Name field top.
    if iconpicker.SetFlowOffset then iconpicker:SetFlowOffset(0, 5) end
    -- Name + Author stacked to the right of the icon. Both boxes share the column's
    -- left edge, so they align with no manual indent.
    local fieldsColumn = UI:Create("SimpleGroup")
    fieldsColumn:SetLayout("List")
    fieldsColumn:SetWidth(260)
    if fieldsColumn.SetListGap     then fieldsColumn:SetListGap(8) end
    if fieldsColumn.SetListPadding then fieldsColumn:SetListPadding(0, 0, 0, 0) end
    fieldsColumn:AddChild(nameeditbox)
    fieldsColumn:AddChild(authoreditbox)
    -- Nudge both fields up 5; then a little extra per field (Name +2, Author +5).
    if fieldsColumn.SetFlowOffset then fieldsColumn:SetFlowOffset(0, 5) end
    if nameeditbox.SetFlowOffset   then nameeditbox:SetFlowOffset(0, 1) end
    if authoreditbox.SetFlowOffset then authoreditbox:SetFlowOffset(0, 4) end
    -- Nudge the "Manage Macro with GSE" checkbox right 2px (positive x = right).
    if manageGSE.SetFlowOffset     then manageGSE:SetFlowOffset(2, 0) end

    headerGroup:AddChild(iconpicker)
    headerGroup:AddChild(fieldsColumn)
    container:AddChild(manageGSE)
    container:AddChild(headerGroup)

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    local origjustificationH = font:GetJustifyH()
    local origjustificationV = font:GetJustifyV()
    font:SetJustifyH("CENTER")
    font:SetJustifyV("MIDDLE")

    -- Help Information shows on the first macro page too (matching the managed page).
    -- source[node.name] is always populated above, so writing .comments is safe even
    -- before "Manage Macro with GSE" is checked.
    local commentsEditBox = UI:Create("MultiLineEditBox")
    commentsEditBox:SetLabel(L["Help Information"])
    ConfigureMacroFieldLabel(commentsEditBox)
    SetMultiLineLabelGap(commentsEditBox, 2)
    SetMultiLineContentPadding(commentsEditBox, 2)
    commentsEditBox:SetNumLines(3)
    commentsEditBox:SetFullWidth(true)
    commentsEditBox:DisableButton(true)
    if source[node.name].comments then
        commentsEditBox:SetText(source[node.name].comments)
    end
    commentsEditBox:SetCallback("OnTextChanged", function(self, event, text)
        source[node.name].comments = text
    end)
    commentsEditBox:SetCallback("OnEditFocusLost", function()
        source[node.name].comments = commentsEditBox:GetText()
    end)
    container:AddChild(commentsEditBox)

    if managed then
        local managedMacro = UI:Create("MultiLineEditBox")
        managedMacro:SetLabel(L["Macro"])
        ConfigureMacroFieldLabel(managedMacro)
        SetMultiLineLabelGap(managedMacro, 2)
        SetMultiLineContentPadding(managedMacro, 2)
        local managedtext =
            (source[node.name].managedMacro and
            DecodeMacroEditorText(GSE.CompileMacroText(
                (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                Statics.TranslatorMode.Current
            )) or DecodeMacroEditorText(node.text))
        managedMacro:SetText(managedtext)
        managedMacro:SetNumLines(8)
        managedMacro:SetFullWidth(true)
        SetMacroTextCounter(managedMacro, managedtext)

        local compiledMacro = UI:Create("Label")
        ConfigureCompiledMacroLabel(compiledMacro)

        local compiledtext =
            (source[node.name].managedMacro and
            DecodeMacroEditorText(GSE.CompileMacroText(
                (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                Statics.TranslatorMode.String
            )) or DecodeMacroEditorText(node.text))
        SetCompiledMacroText(compiledMacro, compiledtext)

        -- Compile the authored macro to its spell-name form and queue the in-game
        -- macro update. Split out of OnTextChanged so it can run either live
        -- (real-time parsing on) or once on focus-loss / accept (real-time parsing
        -- off). The authored macro (managedMacro, the ID form) is always stored in
        -- OnTextChanged regardless of this setting, so nothing the user types is
        -- ever lost; only the derived compile + macro refresh are deferred.
        local function commitManagedMacroCompile(displayText)
            local compiled = DecodeMacroEditorText(GSE.CompileMacroText(displayText, Statics.TranslatorMode.String))
            source[node.name].text = compiled
            SetCompiledMacroText(compiledMacro, compiled)
            GSE.EnqueueOOC({["action"] = "updatemacro", ["node"] = source[node.name]})
        end

        managedMacro:SetCallback(
            "OnTextChanged",
            function(self, _, text)
                SetMacroTextCounter(managedMacro, text)
                editframe:SetStatusText(L["Save pending for "] .. node.name)
                -- Always persist the authored macro so nothing is lost.
                source[node.name].managedMacro = StoreMacroEditorText(text, Statics.TranslatorMode.ID)
                if GSE.ShouldTranslateLive() then
                    -- Live: compile + queue the in-game macro update on every change.
                    commitManagedMacroCompile(text)
                end
                -- When not live, the compile + macro refresh run on focus-loss /
                -- accept (handlers below), keeping typing responsive.
            end
        )

        managedMacro:SetCallback(
            "OnEditFocusLost",
            function()
                -- Always reconcile on focus-loss so the compiled macro is current
                -- regardless of mode/combat (a harmless repeat when live already ran).
                commitManagedMacroCompile(managedMacro:GetText())
            end
        )

        managedMacro:SetCallback(
            "OnEnterPressed",
            function(self, _, text)
                commitManagedMacroCompile(text)
            end
        )

        if GSE.Patron then
            managedMacro.editBox:SetScript(
                "OnTabPressed",
                function(widget, button, down)
                    MenuUtil.CreateContextMenu(
                        editframe.frame,
                        function(ownerRegion, rootDescription)
                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(k, function()
                                    managedMacro.editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                end)
                            end
                            rootDescription:CreateTitle(L["Insert GSE Sequence"])
                            for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
                                rootDescription:CreateButton(k, function()
                                    if GSE.GetMacroStringFormat() == "DOWN" then
                                        managedMacro.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                                    else
                                        managedMacro.editBox:Insert("\n/click " .. k)
                                    end
                                end)
                            end
                            for k, _ in pairs(GSESequences[0]) do
                                rootDescription:CreateButton(k, function()
                                    if GSE.GetMacroStringFormat() == "DOWN" then
                                        managedMacro.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                                    else
                                        managedMacro.editBox:Insert("\n/click " .. k)
                                    end
                                end)
                            end
                        end
                    )
                end
            )
        end

        -- Match the unmanaged page exactly: show the accept button and drop the
        -- trailing Spacer (the unmanaged page has neither a "Template" label nor a
        -- spacer, so its "Used by Sequences" panel sits one row higher).
        managedMacro:DisableButton(false)
        -- Push the Macro box down 3px (negative y = down) for a little breathing
        -- room below Help Information.
        if managedMacro.SetFlowOffset then managedMacro:SetFlowOffset(0, -3) end
        container:AddChild(managedMacro)
        -- "Compiled Macro" preview removed from the page. compiledMacro stays as an
        -- unattached label so the managedMacro OnTextChanged callback can still write
        -- to it; source[node.name].text (set there) is the value that actually matters.
    else
        font:SetJustifyH(origjustificationH)
        font:SetJustifyV(origjustificationV)

        local macro = UI:Create("MultiLineEditBox")
        macro:SetLabel(L["Macro"])
        ConfigureMacroFieldLabel(macro)
        SetMultiLineLabelGap(macro, 2)
        SetMultiLineContentPadding(macro, 2)
        macro:SetText(DecodeMacroEditorText(node.text))
        macro:SetNumLines(8)
        macro:SetFullWidth(true)
        SetMacroTextCounter(macro)
        macro:SetCallback("OnTextChanged", function(self, _, text)
            SetMacroTextCounter(macro, text)
        end)
        macro:SetCallback(
            "OnEnterPressed",
            function(self, _, text)
                editframe:SetStatusText(L["Save pending for "] .. node.name)
                node.text = StoreMacroEditorText(text, Statics.TranslatorMode.String)
                local oocaction = {
                    ["action"] = "updatemacro",
                    ["node"] = node
                }
                GSE.EnqueueOOC(oocaction)
            end
        )
        macro:DisableButton(false)
        -- Push the Macro box down 3px (negative y = down) to match the managed page.
        if macro.SetFlowOffset then macro:SetFlowOffset(0, -3) end
        container:AddChild(macro)
    end

    -- "Used by Sequences" panel at the bottom of every macro page — lists the
    -- sequences that embed this macro. Same styled table as the variable page.
    if GSE.GUI.CreateDependencyWindow and GSE.GetMacroDependents then
        local heading = (L["Used by Sequences"] or "Used by Sequences") .. ":"
        local fmt     = GSE.GUI.FormatDependencyTimestamp or function() return "" end
        local rows = {}
        for _, entry in ipairs(GSE.GetMacroDependents(node.name)) do
            local seq     = GSE.Library and GSE.Library[entry.classid] and GSE.Library[entry.classid][entry.name]
            local author  = seq and (seq.Author or (seq.MetaData and seq.MetaData.Author)) or ""
            local updated = seq and fmt(seq.LastUpdated or (seq.MetaData and seq.MetaData.LastUpdated)) or ""
            rows[#rows+1] = { name = entry.name, author = author, updated = updated }
        end
        GSE.GUI.CreateDependencyWindow(container, heading, rows, { hideAuthor = false, hideType = true, rightInset = 38 })
    end

    manageGSE:SetCallback(
        "OnValueChanged",
        function(self, _, value)
            if GSE.isEmpty(source[node.name]) then
                source[node.name] = {}
            end
            source[node.name].Managed = value
            for k, v in pairs(node) do
                source[node.name][k] = v
            end
            source[node.name].managedMacro =
                GSE.TranslateString(
                (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                Statics.TranslatorMode.ID
            )
            source[node.name].text =
                GSE.UnEscapeString(
                GSE.TranslateString(source[node.name].managedMacro, Statics.TranslatorMode.Current)
            )
            if not value and editframe.pendingSaveName == node.name then
                editframe:SetStatusText(editframe.statusText or ("GSE: " .. GSE.VersionString))
            end
            local function redrawMacroPanel()
                if container.ReleaseChildren then container:ReleaseChildren() end
                showMacro(editframe, node, container)
                editframe.loaded = true
                if container.DoLayout then container:DoLayout() end
                if editframe.scroller and editframe.scroller.DoLayout then editframe.scroller:DoLayout() end
                if editframe.treeContainer and editframe.treeContainer.DoLayout then editframe.treeContainer:DoLayout() end
                if editframe.DoLayout then editframe:DoLayout() end
            end
            C_Timer.After(0.01, redrawMacroPanel)
        end
    )
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupMacro(editframe)
    editframe.showMacro = function(node, container)
        showMacro(editframe, node, container)
    end
    editframe.buildMacroMenu = buildMacroMenu
end
end
table.insert(ns.deferred, setup)

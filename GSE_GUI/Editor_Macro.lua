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

-- Read-only rendered notes stand in for a 3-line editable box. Taller than the
-- box because rendered notes are prose: NativeUI's SetNumLines(3) is 76px, which
-- shows barely two wrapped lines once the panel's own padding is taken out.
local INLINE_NOTES_PANEL_HEIGHT = 120

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

    -- Alphabetical within each group. The loop above walks WoW's macro slots,
    -- which is creation order, and a node's value is its slot id -- so sorting
    -- what is displayed leaves what each node points at alone.
    local function byName(a, b)
        return GSE.AlphabeticalTableSortAlgorithm(a.text or "", b.text or "")
    end
    table.sort(tree.children[1].children, byName)
    table.sort(tree.children[2].children, byName)
    return tree
end

-- ---------------------------------------------------------------------------
-- showMacro(editframe, node, container, selected)
--
-- `node` is the WoW macro as the tree found it: { value = slot, name, icon,
-- text }. What GSE keeps for it is the stored macro under that name, in the
-- current shape (GSE.UpgradeMacro): MetaData for its author, scope, help and
-- which version runs where, Versions for its text. The page edits the stored
-- macro in place, on version `selected`, and every change is written back to
-- WoW through updatemacro -- which puts in the macro book whatever the version
-- that runs now compiles to (GSE.MacroText). A macro runs by its WoW name, so
-- editing a version that does not run now changes nothing in game.
--
-- A sealed (protected) macro has no source to show: it gets its WoW text only.
-- ---------------------------------------------------------------------------
local function showMacro(editframe, node, container, selected)
    -- Section header — uses the GSE macro asset icon, not the individual macro's WoW icon
    if GSE.GUI.AddSectionHeader then
        GSE.GUI.AddSectionHeader(container, L["Macros"] or "Macros", GSE.Static.Icons.Macros)
    end
    local charKey = GSE.CharacterMacroBucketKey()

    local source = GSE.Store("macro")
    if node.value > GSE.GetMaxAccountMacros() then
        if GSE.isEmpty(GSE.Store("macro")[charKey]) then
            GSE.Store("macro")[charKey] = {}
        end
        source = GSE.Store("macro")[charKey]
    end

    local element = source[node.name]
    local sealed = type(element) == "table" and type(element.GSEProtected) == "string"
    if sealed then
        element = nil
    else
        if not GSE.IsStoredMacroNode(element) then
            element = GSE.NewMacroNode(node.name, node.icon, node.text, node.value)
            source[node.name] = element
        end
        GSE.UpgradeMacro(element, node.name)
    end

    selected = tonumber(selected) or 1
    if element and not element.Versions[selected] then selected = 1 end
    editframe.macroSelected = selected
    local version = element and element.Versions[selected]
    local managed = element and element.Managed or false
    editframe.activeMacroName = node.name

    -- Write the stored macro back to WoW (and stamp it) after a change.
    local function commit()
        if element then GSE.EnqueueOOC({["action"] = "updatemacro", ["node"] = element}) end
    end
    local function redraw(newSelected)
        if container.ReleaseChildren then container:ReleaseChildren() end
        showMacro(editframe, node, container, newSelected or editframe.macroSelected)
        editframe.loaded = true
        if container.DoLayout then container:DoLayout() end
        if editframe.scroller and editframe.scroller.DoLayout then editframe.scroller:DoLayout() end
        if editframe.treeContainer and editframe.treeContainer.DoLayout then editframe.treeContainer:DoLayout() end
        if editframe.DoLayout then editframe:DoLayout() end
    end

    local manageGSE = UI:Create("CheckBox")
    manageGSE:SetType("radio")
    manageGSE:SetLabel(L["Manage Macro with GSE"])
    manageGSE:SetTriState(false)
    manageGSE:SetValue(managed and true or false)

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
            local oldName = node.name
            if GSE.isEmpty(text) or text == oldName then return end
            -- The stored macro is keyed by its WoW name: it moves with the
            -- rename, and cannot move onto another one.
            if source[text] ~= nil then
                editframe:SetStatusText(string.format(L["A macro named %s already exists."], text))
                nameeditbox:SetText(oldName)
                return
            end
            local slot = GetMacroIndexByName(oldName)
            if slot and slot > 0 then
                EditMacro(slot, text)
                node.name = text
                if not sealed then
                    source[text], source[oldName] = source[oldName], nil
                    element.name, element.MetaData.Name = text, text
                end
                -- Clear the platform-id sidecar entry under the old name so
                -- the next Companion sync mints a fresh server identity.
                -- See Editor_Variable / Editor sequence rename for the
                -- v4↔v5 bouncing pattern this prevents.
                if GSE.Store("macroPid") then
                    GSE.Store("macroPid")[oldName] = nil
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
    -- checked; every stored macro carries one in MetaData.
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
    if element then
        if GSE.isEmpty(element.MetaData.Author) then
            element.MetaData.Author = GSE.GetCharacterName()
        end
        authoreditbox:SetText(element.MetaData.Author)
        authoreditbox:SetCallback(
            "OnTextChanged",
            function(obj, event, key)
                element.MetaData.Author = key
            end
        )
        authoreditbox:SetCallback("OnEditFocusLost", commit)
    else
        authoreditbox:SetText("")
        authoreditbox:SetDisabled(true)
    end

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
    if element then container:AddChild(manageGSE) end
    container:AddChild(headerGroup)

    if element then
        -- Scope: which class or spec loads it. It still runs by its WoW name.
        if GSE.GUI.DrawElementScope then
            GSE.GUI.DrawElementScope(editframe, container, element,
                GSE.SuggestElementScope and GSE.SuggestElementScope("macro", node.name),
                function() commit(); redraw() end)
        end

        -- Help written on gse.tools arrives as markdown in MetaData.Notes, with
        -- the server's WoW-escape rendering alongside in MetaData.Help. Show the
        -- rendering read-only: raw markdown is unreadable in-game, and an in-game
        -- edit is discarded anyway -- the server re-derives Help from Notes,
        -- which is only editable on the website.
        if not GSE.isEmpty(element.MetaData.Help) and GSE.GUI.CreateReadOnlyNotesPanel then
            GSE.GUI.CreateReadOnlyNotesPanel(
                container,
                L["Help Information"],
                element.MetaData.Help,
                {height = INLINE_NOTES_PANEL_HEIGHT}
            )
        else
            local commentsEditBox = UI:Create("MultiLineEditBox")
            commentsEditBox:SetLabel(L["Help Information"])
            ConfigureMacroFieldLabel(commentsEditBox)
            SetMultiLineLabelGap(commentsEditBox, 2)
            SetMultiLineContentPadding(commentsEditBox, 2)
            commentsEditBox:SetNumLines(3)
            commentsEditBox:SetFullWidth(true)
            commentsEditBox:DisableButton(true)
            commentsEditBox:SetText(element.MetaData.Notes or "")
            commentsEditBox:SetCallback("OnTextChanged", function(self, event, text)
                element.MetaData.Notes = text
            end)
            commentsEditBox:SetCallback("OnEditFocusLost", function()
                element.MetaData.Notes = commentsEditBox:GetText()
                commit()
            end)
            container:AddChild(commentsEditBox)
        end

        -- Which version this page edits.
        if GSE.GUI.DrawElementVersionBar then
            GSE.GUI.DrawElementVersionBar(editframe, container, element, selected, redraw, commit)
        end
    end

    if managed then
        local managedMacro = UI:Create("MultiLineEditBox")
        managedMacro:SetLabel(L["Macro"])
        ConfigureMacroFieldLabel(managedMacro)
        SetMultiLineLabelGap(managedMacro, 2)
        SetMultiLineContentPadding(managedMacro, 2)
        local authored = version.managedMacro or version.text or ""
        local managedtext = DecodeMacroEditorText(GSE.CompileMacroText(authored, Statics.TranslatorMode.Current))
        managedMacro:SetText(managedtext)
        managedMacro:SetNumLines(8)
        managedMacro:SetFullWidth(true)
        SetMacroTextCounter(managedMacro, managedtext)

        -- Compile the authored version to its spell-name form and queue the
        -- in-game macro update. Split out of OnTextChanged so it can run either
        -- live (real-time parsing on) or once on focus-loss / accept (real-time
        -- parsing off). The authored macro (managedMacro, the ID form) is always
        -- stored in OnTextChanged regardless of this setting, so nothing the
        -- user types is ever lost; only the derived compile + macro refresh are
        -- deferred.
        local function commitManagedMacroCompile(displayText)
            version.text = DecodeMacroEditorText(GSE.CompileMacroText(displayText, Statics.TranslatorMode.String))
            commit()
        end

        managedMacro:SetCallback(
            "OnTextChanged",
            function(self, _, text)
                SetMacroTextCounter(managedMacro, text)
                editframe:SetStatusText(L["Save pending for "] .. node.name)
                -- Always persist the authored macro so nothing is lost.
                version.managedMacro = StoreMacroEditorText(text, Statics.TranslatorMode.ID)
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
                -- Opening the Tab line builder takes focus off the box, so this
                -- fires at the START of a build. Compiling then would queue an
                -- in-game macro update per pick off half-built text.
                --
                -- Unlike Editor.lua's guard, this cannot simply wait for "the
                -- next real focus loss": the box does not necessarily regain
                -- focus when the menu closes, and what is deferred here is the
                -- compiled macro WoW actually fires, not a repaint. So retry
                -- once the session's deadline passes. The session zeroes the
                -- deadline on a terminal pick, so the usual path is one short
                -- hop, and re-reading GetText() at that point picks up
                -- everything the builder wrote.
                local eb = managedMacro.editBox or managedMacro.editbox
                local until_ = (eb and eb.gseTabSessionUntil) or 0
                if until_ > GetTime() then
                    C_Timer.After((until_ - GetTime()) + 0.1, function()
                        if (eb.gseTabSessionUntil or 0) > GetTime() then return end
                        commitManagedMacroCompile(managedMacro:GetText())
                    end)
                    return
                end
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

        -- Tab line builder. Pass the WIDGET, not its editbox -- the builder
        -- resolves widget.editBox. Variables are offered here and not on the
        -- unmanaged page below: a managed macro's text is compiled through
        -- GSE.CompileMacroText, which evaluates a leading "=".
        if GSE.OnEditorMacroTab then
            GSE.OnEditorMacroTab(managedMacro, editframe.frame, {variables = true})
        end

        -- Match the unmanaged page exactly: show the accept button and drop the
        -- trailing Spacer (the unmanaged page has neither a "Template" label nor a
        -- spacer, so its "Used by Sequences" panel sits one row higher).
        managedMacro:DisableButton(false)
        -- Push the Macro box down 3px (negative y = down) for a little breathing
        -- room below Help Information.
        if managedMacro.SetFlowOffset then managedMacro:SetFlowOffset(0, -3) end
        container:AddChild(managedMacro)
    else
        local macro = UI:Create("MultiLineEditBox")
        macro:SetLabel(L["Macro"])
        ConfigureMacroFieldLabel(macro)
        SetMultiLineLabelGap(macro, 2)
        SetMultiLineContentPadding(macro, 2)
        macro:SetText(DecodeMacroEditorText((version and version.text) or node.text or ""))
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
                local stored = StoreMacroEditorText(text, Statics.TranslatorMode.String)
                if version then
                    version.text = stored
                    commit()
                else
                    -- Sealed: only the WoW macro itself can be changed.
                    node.text = stored
                    GSE.EnqueueOOC({["action"] = "updatemacro", ["node"] = node})
                end
            end
        )
        -- Same builder as the managed page, minus GSE variables: this text goes
        -- to the in-game macro as written, so a "=GSE.V[...]()" line would never
        -- be evaluated.
        if GSE.OnEditorMacroTab then
            GSE.OnEditorMacroTab(macro, editframe.frame)
        end
        macro:DisableButton(false)
        -- Push the Macro box down 3px (negative y = down) to match the managed page.
        if macro.SetFlowOffset then macro:SetFlowOffset(0, -3) end
        container:AddChild(macro)
    end

    -- Which version runs where: Default and the context overrides.
    if element and GSE.GUI.DrawElementVersionConfig then
        local configHeading = UI:Create("Heading")
        configHeading:SetText(L["Configuration"])
        configHeading:SetFullWidth(true)
        container:AddChild(configHeading)
        GSE.GUI.DrawElementVersionConfig(editframe, container, element, commit)
    end

    -- "Used by Sequences" panel at the bottom of every macro page — lists the
    -- sequences that embed this macro. Same styled table as the variable page.
    if GSE.GUI.CreateDependencyWindow and GSE.GetMacroDependents then
        local heading = (L["Used by Sequences"] or "Used by Sequences") .. ":"
        local fmt     = GSE.GUI.FormatDependencyTimestamp or function() return "" end
        local rows = {}
        for _, entry in ipairs(GSE.GetMacroDependents(node.name)) do
            local seq     = GSE.Library and GSE.Library[entry.classid] and GSE.Library[entry.classid][entry.id]
            local author  = seq and (seq.Author or (seq.MetaData and seq.MetaData.Author)) or ""
            local updated = seq and fmt(seq.LastUpdated or (seq.MetaData and seq.MetaData.LastUpdated)) or ""
            rows[#rows+1] = { name = entry.name, author = author, updated = updated }
        end
        GSE.GUI.CreateDependencyWindow(container, heading, rows, { hideAuthor = false, hideType = true, rightInset = 38 })
    end

    manageGSE:SetCallback(
        "OnValueChanged",
        function(self, _, value)
            if not element then return end
            element.Managed = value or nil
            element.icon, element.value = node.icon, node.value
            -- Every version gets an authored form (spell IDs) and the text it
            -- compiles to, so either kind of page can show any version.
            for _, v in ipairs(element.Versions) do
                v.managedMacro = GSE.TranslateString(v.managedMacro or v.text or "", Statics.TranslatorMode.ID)
                v.text = GSE.UnEscapeString(GSE.TranslateString(v.managedMacro, Statics.TranslatorMode.Current))
            end
            if not value and editframe.pendingSaveName == node.name then
                editframe:SetStatusText(editframe.statusText or ("GSE: " .. GSE.VersionString))
            end
            commit()
            C_Timer.After(0.01, function() redraw() end)
        end
    )
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupMacro(editframe)
    editframe.showMacro = function(node, container)
        -- Opened from the tree: start on the version that runs now.
        local stored = GSE.Store("macro")
        local charKey = GSE.CharacterMacroBucketKey()
        local element = (node.value > GSE.GetMaxAccountMacros())
            and (stored[charKey] or {})[node.name] or stored[node.name]
        local selected = 1
        if type(element) == "table" and type(element.Versions) == "table" then
            selected = GSE.GetActiveVersion(element.MetaData)
        end
        showMacro(editframe, node, container, selected)
    end
    editframe.buildMacroMenu = buildMacroMenu
end
end
table.insert(ns.deferred, setup)

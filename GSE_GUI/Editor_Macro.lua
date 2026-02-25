local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- ---------------------------------------------------------------------------
-- buildMacroMenu()  →  "Macros" tree node
-- ---------------------------------------------------------------------------
local function buildMacroMenu()
    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
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
            if macid <= MAX_ACCOUNT_MACROS then
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
    local char, realm = UnitFullName("player")

    local source = GSEMacros
    if node.value > MAX_ACCOUNT_MACROS then
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        source = GSEMacros[char .. "-" .. realm]
    end

    local manageGSE = AceGUI:Create("CheckBox")
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

    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")

    local nameeditbox = AceGUI:Create("EditBox")
    nameeditbox:SetLabel(L["Macro Name"])
    nameeditbox:SetWidth(250)
    nameeditbox:SetCallback(
        "OnEnterPressed",
        function(self, _, text)
            local slot = GetMacroIndexByName(node.name)
            if slot then
                EditMacro(slot, text)
                node.name = text
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

    local spacerlabel = AceGUI:Create("Label")
    spacerlabel:SetWidth(10)

    local iconpicker = AceGUI:Create("Icon")
    iconpicker:SetImageSize(40, 40)
    iconpicker:SetLabel(L["Macro Icon"])
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
    headerGroup:AddChild(iconpicker)
    headerGroup:AddChild(spacerlabel)
    headerGroup:AddChild(nameeditbox)
    container:AddChild(headerGroup)
    container:AddChild(manageGSE)

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    local origjustificationH = font:GetJustifyH()
    local origjustificationV = font:GetJustifyV()
    font:SetJustifyH("CENTER")
    font:SetJustifyV("MIDDLE")

    if managed then
        local authoreditbox = AceGUI:Create("EditBox")
        authoreditbox:SetLabel(L["Author"])
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
        container:AddChild(authoreditbox)

        local commentsEditBox = AceGUI:Create("MultiLineEditBox")
        commentsEditBox:SetLabel(L["Help Information"])
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

        local managedMacro = AceGUI:Create("MultiLineEditBox")
        managedMacro:SetLabel(L["Macro Template"])
        local managedtext =
            (source[node.name].managedMacro and
            GSE.CompileMacroText(
                (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                Statics.TranslatorMode.Current
            ) or node.text)
        managedMacro:SetText(managedtext)
        managedMacro:SetNumLines(8)
        managedMacro:SetFullWidth(true)

        local compiledMacro = AceGUI:Create("Label")
        compiledMacro:SetWidth(editframe.Width - 200)

        local heading2 = AceGUI:Create("Heading")
        heading2:SetText(L["Compiled Macro"])
        heading2:SetFullWidth(true)

        local compiledtext =
            (source[node.name].managedMacro and
            GSE.CompileMacroText(
                (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                Statics.TranslatorMode.String
            ) or node.text)
        compiledMacro:SetText(compiledtext)

        local compiledlinecount = AceGUI:Create("Label")
        compiledlinecount:SetWidth(editframe.Width - 200)
        compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(compiledtext)))
        compiledlinecount:ClearAllPoints()
        compiledlinecount:SetPoint("CENTER")
        compiledlinecount:SetFontObject(font)
        compiledlinecount:SetFont(fontName, fontHeight, fontFlags)

        managedMacro:SetCallback(
            "OnTextChanged",
            function(self, _, text)
                editframe:SetStatusText(L["Save pending for "] .. node.name)
                source[node.name].managedMacro = GSE.CompileMacroText(text, Statics.TranslatorMode.ID)
                local compiled = GSE.CompileMacroText(text, Statics.TranslatorMode.String)
                compiledMacro:SetText(compiled)
                compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(compiled)))
                local oocaction = {
                    ["action"] = "updatemacro",
                    ["node"] = source[node.name],
                    ["status"] = editframe:SetStatusText()
                }
                table.insert(GSE.OOCQueue, oocaction)
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

        managedMacro:DisableButton(true)
        container:AddChild(managedMacro)
        container:AddChild(heading2)
        local inlinecompiled = AceGUI:Create("InlineGroup")
        inlinecompiled:SetFullWidth(true)
        inlinecompiled:AddChild(compiledMacro)
        container:AddChild(inlinecompiled)
        container:AddChild(AceGUI:Create("Spacer"))
        container:AddChild(compiledlinecount)
    else
        local linecount = AceGUI:Create("Label")
        linecount:SetWidth(editframe.Width - 200)
        linecount:SetText(string.format(L["%s/255 Characters Used"], string.len(node.text)))
        linecount:ClearAllPoints()
        linecount:SetPoint("CENTER")
        linecount:SetFontObject(font)
        linecount:SetFont(fontName, fontHeight, fontFlags)
        font:SetJustifyH(origjustificationH)
        font:SetJustifyV(origjustificationV)

        local macro = AceGUI:Create("MultiLineEditBox")
        macro:SetLabel(L["Macro"])
        macro:SetText(node.text)
        macro:SetNumLines(8)
        macro:SetFullWidth(true)
        macro:SetCallback(
            "OnEnterPressed",
            function(self, _, text)
                editframe:SetStatusText(L["Save pending for "] .. node.name)
                node.text = GSE.CompileMacroText(text, Statics.TranslatorMode.String)
                local oocaction = {
                    ["action"] = "updatemacro",
                    ["node"] = node,
                    ["status"] = editframe:SetStatusText()
                }
                table.insert(GSE.OOCQueue, oocaction)
            end
        )
        macro:SetCallback(
            "OnTextChanged",
            function(self, _, text)
                local length = string.len(text)
                local line = string.format(L["%s/255 Characters Used"], length)
                if length > 255 then
                    line = GSEOptions.UNKNOWN .. line .. Statics.StringReset
                end
                linecount:SetText(line)
            end
        )
        macro:DisableButton(false)
        container:AddChild(macro)
        container:AddChild(linecount)
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
            showMacro(editframe, node, container)
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

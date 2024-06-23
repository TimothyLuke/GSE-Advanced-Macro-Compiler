local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local macroframe = AceGUI:Create("Frame")
macroframe:Hide()
macroframe.panels = {}

macroframe.frame:SetFrameStrata("MEDIUM")
if
    GSEOptions.frameLocations and GSEOptions.frameLocations.macroframe and GSEOptions.frameLocations.macroframe.left and
        GSEOptions.frameLocations.macroframe.top
 then
    macroframe:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.macroframe.left,
        GSEOptions.frameLocations.macroframe.top
    )
end
GSE.GUIMacroFrame = macroframe

if GSE.isEmpty(GSEOptions.macroHeight) then
    GSEOptions.macroHeight = 500
end
if GSE.isEmpty(GSEOptions.macroWidth) then
    GSEOptions.macroWidth = 700
end
macroframe.Height = GSEOptions.macroHeight
macroframe.Width = GSEOptions.macroWidth
if macroframe.Height < 500 then
    macroframe.Height = 500
    GSEOptions.macroHeight = macroframe.Height
end
if macroframe.Width < 700 then
    macroframe.Width = 700
    GSEOptions.macroWidth = macroframe.Width
end
macroframe.frame:SetClampRectInsets(-10, -10, -10, -10)
macroframe.frame:SetHeight(GSEOptions.editorHeight)
macroframe.frame:SetWidth(GSEOptions.editorWidth)

macroframe:SetTitle(L["Macros"])
macroframe:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(macroframe)
        macroframe:Hide()
    end
)

macroframe:SetLayout("Flow")
macroframe:SetAutoAdjustHeight(false)

local basecontainer = AceGUI:Create("SimpleGroup")
basecontainer:SetLayout("Flow")
basecontainer:SetAutoAdjustHeight(false)
basecontainer:SetHeight(macroframe.Height - 100)
basecontainer:SetFullWidth(true)
macroframe:AddChild(basecontainer)

local leftScrollContainer = AceGUI:Create("SimpleGroup")
leftScrollContainer:SetWidth(200)

leftScrollContainer:SetHeight(macroframe.Height - 90)
leftScrollContainer:SetLayout("Fill") -- important!

basecontainer:AddChild(leftScrollContainer)

local leftscroll = AceGUI:Create("ScrollFrame")
leftscroll:SetLayout("List") -- probably?
leftscroll:SetWidth(200)
leftscroll:SetHeight(macroframe.Height - 90)
leftScrollContainer:AddChild(leftscroll)

local spacer = AceGUI:Create("Label")
spacer:SetWidth(10)
basecontainer:AddChild(spacer)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(macroframe.Width - 250)

rightContainer:SetLayout("List")
rightContainer:SetHeight(macroframe.Height - 90)
basecontainer:AddChild(rightContainer)

macroframe.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        macroframe.Height = height
        macroframe.Width = width
        if macroframe.Height > GetScreenHeight() then
            macroframe.Height = GetScreenHeight() - 10
            macroframe:SetHeight(macroframe.Height)
        end
        if macroframe.Height < 500 then
            macroframe.Height = 500
            macroframe:SetHeight(macroframe.Height)
        end
        if macroframe.Width < 700 then
            macroframe.Width = 700
            macroframe:SetWidth(macroframe.Width)
        end
        GSEOptions.macroHeight = macroframe.Height
        GSEOptions.macroWidth = macroframe.Width
        rightContainer:SetWidth(macroframe.Width - 250)
        rightContainer:SetHeight(macroframe.Height - 90)

        macroframe:DoLayout()
    end
)

local function showMacro(node)
    rightContainer:ReleaseChildren()
    local headerGroup = AceGUI:Create("KeyGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")

    local nameeditbox = AceGUI:Create("EditBox")
    nameeditbox:SetLabel(L["Macro Name"])
    nameeditbox:SetWidth(250)
    nameeditbox:SetCallback(
        "OnEnterPressed",
        function(self, _, text)
            local slot = GetMacroIndexByName(node.name)
            -- TODO Need to queue this
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
                macroframe
            )
        end
    )
    nameeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(macroframe)
        end
    )

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
                macroframe
            )
        end
    )
    iconpicker:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(macroframe)
        end
    )
    headerGroup:AddChild(iconpicker)
    headerGroup:AddChild(spacerlabel)
    headerGroup:AddChild(nameeditbox)

    rightContainer:AddChild(headerGroup)

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    local origjustificationH = font:GetJustifyH()
    local origjustificationV = font:GetJustifyV()
    font:SetJustifyH("CENTER")
    font:SetJustifyV("MIDDLE")

    local linecount = AceGUI:Create("Label")
    linecount:SetWidth(macroframe.Width - 200)
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
    macro:SetNumLines(5)
    macro:SetWidth(macroframe.Width - 200)
    macro:SetCallback(
        "OnEnterPressed",
        function(self, _, text)
            node.text = text
            local oocaction = {
                ["action"] = "updatemacro",
                ["node"] = node
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
    rightContainer:AddChild(macro)
    rightContainer:AddChild(linecount)
    local heading = AceGUI:Create("Heading")
    heading:SetText(L["Manage Macro"])
    heading:SetWidth(macroframe.Width - 200)
    rightContainer:AddChild(heading)
    local manageGSE = AceGUI:Create("CheckBox")
    manageGSE:SetType("radio")
    manageGSE:SetLabel(L["Manage Macro with GSE"])
    manageGSE:SetTriState(false)
    local char, realm = UnitFullName("player")

    local source = GSEMacros
    if node.value > MAX_ACCOUNT_MACROS then
        if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
            GSEMacros[char .. "-" .. realm] = {}
        end
        source = GSEMacros[char .. "-" .. realm]
    end

    if GSE.isEmpty(source[node.name]) then
        source[node.name] = {}
        manageGSE:SetValue(false)
    else
        if GSE.isEmpty(source[node.name].Disabled) then
            manageGSE:SetValue(false)
        else
            manageGSE:SetValue(source[node.name].Disabled)
        end
    end

    local disabled = false
    if source[node.name] and source[node.name].Disabled then
        disabled = source[node.name].Disabled
    end

    local managedMacro = AceGUI:Create("MultiLineEditBox")
    managedMacro:SetLabel(L["Macro Template"])
    local managedtext =
        (source[node.name].managedMacro and
        GSE.CompileMacroText(source[node.name].managedMacro, Statics.TranslatorMode.Current) or
        node.text)
    managedMacro:SetText(managedtext)
    managedMacro:SetNumLines(5)
    managedMacro:SetDisabled(not disabled)
    managedMacro:SetWidth(macroframe.Width - 200)

    local compileButton = AceGUI:Create("Button")
    compileButton:SetText(L["Compile"])

    local compiledMacro = AceGUI:Create("Label")
    compiledMacro:SetWidth(macroframe.Width - 200)

    local heading2 = AceGUI:Create("Heading")
    heading2:SetText(L["Compiled Macro"])
    heading2:SetWidth(macroframe.Width - 200)

    compiledMacro:SetText(managedtext)

    local compiledlinecount = AceGUI:Create("Label")
    compiledlinecount:SetWidth(macroframe.Width - 200)
    compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(managedtext)))
    compiledlinecount:ClearAllPoints()
    compiledlinecount:SetPoint("CENTER")
    compiledlinecount:SetFontObject(font)
    compiledlinecount:SetFont(fontName, fontHeight, fontFlags)

    managedMacro:SetCallback(
        "OnTextChanged",
        function(self, _, text)
            source[node.name].managedMacro = GSE.CompileMacroText(text, Statics.TranslatorMode.ID)
            local compiled = GSE.CompileMacroText(text, Statics.TranslatorMode.Current)
            compiledMacro:SetText(compiled)
            compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(compiled)))
        end
    )

    managedMacro:DisableButton(true)
    manageGSE:SetCallback(
        "OnValueChanged",
        function(self, _, value)
            if GSE.isEmpty(source[node.name]) then
                source[node.name] = {}
            end

            source[node.name].Disabled = value
            disabled = not value
            managedMacro:SetDisabled(disabled)
            source[node.name].managedMacro = GSE.CompileMacroText(managedMacro:GetText(), Statics.TranslatorMode.ID)
        end
    )

    rightContainer:AddChild(manageGSE)

    rightContainer:AddChild(managedMacro)
    rightContainer:AddChild(heading2)
    rightContainer:AddChild(compiledMacro)
    rightContainer:AddChild(compiledlinecount)
end

local function buildMacroHeader(node)
    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)

    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    local origjustificationH = font:GetJustifyH()
    local origjustificationV = font:GetJustifyV()
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    local selpanel = AceGUI:Create("SelectablePanel")

    selpanel:SetKey(node.value)
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(20)
    selpanel:SetAutoAdjustHeight(false)
    selpanel:SetLayout("List")

    macroframe.panels[node.value] = selpanel
    selpanel:SetCallback(
        "OnClick",
        function(widget, _, selected, button)
            macroframe:clearpanels(widget, selected)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(
                    selpanel,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Sequence Editor"])
                        rootDescription:CreateButton(
                            L["New"],
                            function()
                                GSE.GUILoadEditor()
                            end
                        )
                        rootDescription:CreateButton(
                            L["Import"],
                            function()
                                macroframe:Hide()
                                GSE.GUIImportFrame:Show()
                            end
                        )
                        -- rootDescription:CreateButton(
                        --     L["Delete"],
                        --     function()
                        --         GSE.GUIDeleteSequence(classid, sequencename)
                        --     end
                        -- )
                    end
                )
            else
                showMacro(node)
            end
        end
    )

    local hlabel = AceGUI:Create("Label")

    hlabel:SetText("|T" .. node.icon .. ":15:15|t " .. node.name)
    hlabel:SetWidth(199)
    hlabel:SetFontObject(font)
    hlabel:SetFont(fontName, fontHeight + 2, fontFlags)

    selpanel:AddChild(hlabel)

    leftscroll:AddChild(selpanel)
    font:SetJustifyH(origjustificationH)
    font:SetJustifyV(origjustificationV)
end

local function buildMacroMenu()
    leftscroll:ReleaseChildren()

    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    local accountlabelflag = false
    local personallabelflag = false
    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    for macid = 1, maxmacros do
        local mname, micon, mtext = GetMacroInfo(macid)
        if mname then
            if macid <= MAX_ACCOUNT_MACROS and accountlabelflag == false then
                local sectionheader = AceGUI:Create("Label")
                sectionheader:SetText(L["Account Macros"])
                sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
                sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
                leftscroll:AddChild(sectionheader)
                leftscroll:AddChild(AceGUI:Create("Spacer"))
                accountlabelflag = true
            elseif macid > MAX_ACCOUNT_MACROS and personallabelflag == false then
                if accountlabelflag then
                    leftscroll:AddChild(AceGUI:Create("Spacer"))
                end
                local sectionheader = AceGUI:Create("Label")
                sectionheader:SetText(L["Character Macros"])
                sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
                sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
                leftscroll:AddChild(sectionheader)
                leftscroll:AddChild(AceGUI:Create("Spacer"))
                personallabelflag = true
            end

            buildMacroHeader(
                {
                    value = macid,
                    name = mname,
                    icon = micon,
                    text = mtext
                }
            )
        end
    end
end

function macroframe:clearpanels(widget, selected)
    for k, _ in pairs(macroframe.panels) do
        if k == widget:GetKey() then
            if selected then
                --macroframe.showMacro(widget.node)
                macroframe.panels[k]:SetClicked(true)
            else
                macroframe.panels[k]:SetClicked(false)
            end
        else
            macroframe.panels[k]:SetClicked(false)
        end
    end
end

function GSE.ShowMacros()
    buildMacroMenu()
    macroframe:Show()
end

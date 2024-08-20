local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local variablesframe = AceGUI:Create("Frame")
variablesframe:Hide()
variablesframe.panels = {}
variablesframe.frame:SetClampedToScreen(true)
variablesframe.frame:SetFrameStrata("MEDIUM")
if
    GSEOptions.frameLocations and GSEOptions.frameLocations.variablesframe and
        GSEOptions.frameLocations.variablesframe.left and
        GSEOptions.frameLocations.variablesframe.top
 then
    variablesframe:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.variablesframe.left,
        GSEOptions.frameLocations.variablesframe.top
    )
end
GSE.GUIVariableFrame = variablesframe

if GSE.isEmpty(GSEOptions.menuHeight) then
    GSEOptions.menuHeight = 500
end
if GSE.isEmpty(GSEOptions.menuWidth) then
    GSEOptions.menuWidth = 700
end
variablesframe.Height = GSEOptions.menuHeight
variablesframe.Width = GSEOptions.menuWidth
if variablesframe.Height < 500 then
    variablesframe.Height = 500
    GSEOptions.menuWidth = variablesframe.Height
end
if variablesframe.Width < 700 then
    variablesframe.Width = 700
    GSEOptions.menuWidth = variablesframe.Width
end
variablesframe.frame:SetClampRectInsets(-10, -10, -10, -10)
variablesframe.frame:SetHeight(GSEOptions.editorHeight)
variablesframe.frame:SetWidth(GSEOptions.editorWidth)

variablesframe:SetTitle(L["Variables"])
variablesframe:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(variablesframe)
        variablesframe:Hide()
    end
)

variablesframe:SetLayout("Flow")
variablesframe:SetAutoAdjustHeight(false)

local basecontainer = AceGUI:Create("SimpleGroup")
basecontainer:SetLayout("Flow")
basecontainer:SetAutoAdjustHeight(false)
basecontainer:SetHeight(variablesframe.Height - 100)
basecontainer:SetFullWidth(true)
variablesframe:AddChild(basecontainer)

local leftScrollContainer = AceGUI:Create("SimpleGroup")
leftScrollContainer:SetWidth(200)

leftScrollContainer:SetHeight(variablesframe.Height - 90)
leftScrollContainer:SetLayout("Fill") -- important!

basecontainer:AddChild(leftScrollContainer)

local leftscroll = AceGUI:Create("ScrollFrame")
leftscroll:SetLayout("List") -- probably?
leftscroll:SetWidth(200)
-- probably?
leftScrollContainer:AddChild(leftscroll)

local spacer = AceGUI:Create("Label")
spacer:SetWidth(10)
basecontainer:AddChild(spacer)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(variablesframe.Width - 290)

rightContainer:SetLayout("List")
rightContainer:SetHeight(variablesframe.Height - 90)
basecontainer:AddChild(rightContainer)

variablesframe.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        variablesframe.Height = height
        variablesframe.Width = width
        if variablesframe.Height > GetScreenHeight() then
            variablesframe.Height = GetScreenHeight() - 10
            variablesframe:SetHeight(variablesframe.Height)
        end
        if variablesframe.Height < 500 then
            variablesframe.Height = 500
            variablesframe:SetHeight(variablesframe.Height)
        end
        if variablesframe.Width < 700 then
            variablesframe.Width = 700
            variablesframe:SetWidth(variablesframe.Width)
        end
        GSEOptions.menuHeight = variablesframe.Height
        GSEOptions.menuWidth = variablesframe.Width

        rightContainer:SetWidth(variablesframe.Width - 290)
        rightContainer:SetHeight(variablesframe.Height - 90)
        leftscroll:SetHeight(variablesframe.Height - 90)
        variablesframe:DoLayout()
    end
)

local function createVariableHeader(name, variable)
    local selpanel = AceGUI:Create("SelectablePanel")
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(90)
    variablesframe.panels[name] = selpanel
    local label = AceGUI:Create("Label")
    local font = CreateFont("seqPanelFont")
    label:SetFontObject(font)
    label:SetText(name)
    selpanel.label = label
    selpanel:SetCallback(
        "OnClick",
        function(widget, _, selected, button)
            variablesframe:clearpanels(widget, selected)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(
                    leftscroll,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Manage Variables"])
                        rootDescription:CreateButton(
                            L["Export Variable"],
                            function()
                                GSE.GUIExport(nil, name, "VARIABLE")
                            end
                        )
                        rootDescription:CreateButton(
                            L["Delete"],
                            function()
                                GSE.V[name] = nil
                                GSEVariables[name] = nil
                                GSE.ShowVariables()
                            end
                        )
                    end
                )
            end
            if button == "LeftButton" then
                variablesframe.showVariable(name, selpanel.label)
                widget:SetClicked(true)
            end
        end
    )

    font:SetFontObject(GameFontNormal)
    local origjustifyV = font:GetJustifyV()
    local origjustifyH = font:GetJustifyH()
    font:SetJustifyV("BOTTOM")

    selpanel:AddChild(label)

    font:SetJustifyV(origjustifyV)
    font:SetJustifyH(origjustifyH)
    return selpanel
end

local function listVariables()
    leftscroll:ReleaseChildren()

    local menuRow = AceGUI:Create("SimpleGroup")
    menuRow:SetLayout("Flow")

    local newButton = AceGUI:Create("Button")
    newButton:SetText(L["New"])
    newButton:SetWidth(90)
    newButton:SetCallback(
        "OnClick",
        function()
            variablesframe.newVariable()
        end
    )

    newButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    menuRow:AddChild(newButton)

    local importButton = AceGUI:Create("Button")
    importButton:SetText(L["Import"])
    importButton:SetWidth(90)
    importButton:SetCallback(
        "OnClick",
        function()
            GSE.ShowImport()
        end
    )

    importButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    menuRow:AddChild(importButton)
    leftscroll:AddChild(menuRow)

    for k, _ in pairs(GSEVariables) do
        local header = createVariableHeader(k)
        leftscroll:AddChild(header)
    end
end

function variablesframe.showVariable(name, label)
    rightContainer:ReleaseChildren()
    local variable = {
        ["funct"] = [[function()
    return true
end]],
        ["comments"] = ""
    }
    if not GSE.isEmpty(GSEVariables[name]) then
        local status, err =
            pcall(
            function()
                local _, uncompressedVersion = GSE.DecodeMessage(GSEVariables[name])
                variable = uncompressedVersion
            end
        )
        if err then
            print(err)
        end
    end

    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel(L["Name"])
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(150)
    keyEditBox:SetText(name)
    local currentKey = name
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            local orig = GSEVariables[currentKey]
            GSEVariables[text] = orig
            GSEVariables[currentKey] = nil
            currentKey = text
            label:SetText(text)
        end
    )

    local authoreditbox = AceGUI:Create("EditBox")
    authoreditbox:SetLabel(L["Author"])
    authoreditbox:SetWidth(250)
    authoreditbox:DisableButton(true)
    authoreditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Author"], L["The author of this Variable."], variablesframe)
        end
    )
    authoreditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    if not GSE.isEmpty(variable.Author) then
        authoreditbox:SetText(variable.Author)
    else
        authoreditbox:SetText(GSE.GetCharacterName())
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            variable.Author = key
        end
    )
    rightContainer:AddChild(keyEditBox)
    rightContainer:AddChild(authoreditbox)

    local commentsEditBox = AceGUI:Create("MultiLineEditBox")
    commentsEditBox:SetLabel(L["Help Information"])
    commentsEditBox:SetNumLines(7)
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

    rightContainer:AddChild(commentsEditBox)

    local valueEditBox = AceGUI:Create("MultiLineEditBox")
    valueEditBox:SetLabel(L["Variable"])
    valueEditBox:SetNumLines(15)
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

    rightContainer:AddChild(valueEditBox)

    local implementation = AceGUI:Create("EditBox")
    implementation:SetLabel(L["Implementation Link"])
    implementation:DisableButton(true)
    local implementationText = [[=GSE.V.]] .. name .. [[()]]
    implementation:SetText(implementationText)
    implementation:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            implementation:SetText(implementationText)
        end
    )
    rightContainer:AddChild(implementation)

    local currentOutput = AceGUI:Create("EditBox")
    currentOutput:SetLabel(L["Current Value"])
    currentOutput:DisableButton(true)
    local outputText = L["Not Yet Active"]
    if GSE.V[name] and type(GSE.V[name]) == "function" then
        outputText = GSE.V[name]()
    end

    currentOutput:SetText(outputText)
    currentOutput:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            currentOutput:SetText(outputText)
        end
    )
    rightContainer:AddChild(currentOutput)

    local spacer2 = AceGUI:Create("Label")
    spacer2:SetWidth(10)
    rightContainer:AddChild(spacer2)

    local buttonRow = AceGUI:Create("SimpleGroup")
    buttonRow:SetLayout("Flow")
    buttonRow:SetWidth(400)

    local deleteRowButton = AceGUI:Create("Button")
    deleteRowButton:SetText(L["Delete Variable"])
    deleteRowButton:SetWidth(150)
    deleteRowButton:SetCallback(
        "OnClick",
        function()
            GSEVariables[keyEditBox:GetText()] = nil
            rightContainer:ReleaseChildren()
            listVariables()
        end
    )
    deleteRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], variablesframe)
        end
    )
    deleteRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    buttonRow:AddChild(deleteRowButton)

    local spacer3 = AceGUI:Create("Label")
    spacer3:SetWidth(10)
    buttonRow:AddChild(spacer3)

    local lastSaved = AceGUI:Create("Label")
    if variable.LastUpdated then
        local updated = GSE.DecodeTimeStamp(variable.LastUpdated)
        lastSaved:SetText(
            L["Last Updated"] ..
                " " ..
                    updated.month ..
                        "/" .. updated.day .. "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
        )
    end

    local savebutton = AceGUI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback(
        "OnClick",
        function()
            variablesframe:SetStatusText(L["Save pending for "] .. keyEditBox:GetText())
            variable.LastUpdated = GSE.GetTimestamp()
            local updated = GSE.DecodeTimeStamp(variable.LastUpdated)

            local oocaction = {
                ["action"] = "updatevariable",
                ["variable"] = variable,
                ["name"] = keyEditBox:GetText()
            }
            table.insert(GSE.OOCQueue, oocaction)
            lastSaved:SetText(
                L["Last Updated"] ..
                    " " ..
                        updated.month ..
                            "/" .. updated.day .. "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
            )
        end
    )

    savebutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Save"], L["Save the changes made to this variable."], variablesframe)
        end
    )
    savebutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    buttonRow:AddChild(savebutton)
    rightContainer:AddChild(buttonRow)
    rightContainer:AddChild(lastSaved)
    rightContainer:SetWidth(variablesframe.Width - 290)
end

function variablesframe.newVariable()
    local header = createVariableHeader("MyNewVar" .. math.random(100))
    leftscroll:AddChild(header)
end

leftscroll.frame:SetScript(
    "OnMouseDown",
    function(Self, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(
                leftscroll,
                function(ownerRegion, rootDescription)
                    rootDescription:CreateTitle(L["Variable Menu"])
                    rootDescription:CreateButton(
                        L["New"],
                        function()
                            variablesframe.newVariable()
                        end
                    )
                    rootDescription:CreateButton(
                        L["Import"],
                        function()
                            GSE.ShowImport()
                        end
                    )
                end
            )
        end
    end
)

function variablesframe:clearpanels(widget, selected)
    for k, _ in pairs(variablesframe.panels) do
        if k == widget:GetKey() then
            if selected then
                variablesframe.showVariable(widget, GSEVariables[widget].label)
                variablesframe.panels[k]:SetClicked(true)
            else
                variablesframe.panels[k]:SetClicked(false)
            end
        else
            variablesframe.panels[k]:SetClicked(false)
        end
    end
end

function GSE.ShowVariables()
    listVariables()
    variablesframe:Show()
end

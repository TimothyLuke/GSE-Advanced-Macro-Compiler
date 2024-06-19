local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local variablesframe = AceGUI:Create("Frame")
variablesframe:Hide()
variablesframe.panels = {}

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

if GSE.isEmpty(GSEOptions.editorHeight) then
    GSEOptions.editorHeight = 500
end
if GSE.isEmpty(GSEOptions.editorWidth) then
    GSEOptions.editorWidth = 700
end
variablesframe.Height = GSEOptions.editorHeight
variablesframe.Width = GSEOptions.editorWidth
if variablesframe.Height < 500 then
    variablesframe.Height = 500
    GSEOptions.editorHeight = variablesframe.Height
end
if variablesframe.Width < 700 then
    variablesframe.Width = 700
    GSEOptions.editorWidth = variablesframe.Width
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
leftscroll:SetLayout("Flow") -- probably?
leftScrollContainer:AddChild(leftscroll)

local spacer = AceGUI:Create("Label")
spacer:SetWidth(10)
basecontainer:AddChild(spacer)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(variablesframe.Width - 290)

rightContainer:SetLayout("List")
rightContainer:SetHeight(variablesframe.Height - 90)
basecontainer:AddChild(rightContainer)

local colorTable = {}

local tokens = IndentationLib.tokens

colorTable[tokens.TOKEN_SPECIAL] = GSEOptions.WOWSHORTCUTS
colorTable[tokens.TOKEN_KEYWORD] = GSEOptions.KEYWORD
colorTable[tokens.TOKEN_UNKNOWN] = GSEOptions.UNKNOWN
colorTable[tokens.TOKEN_COMMENT_SHORT] = GSEOptions.COMMENT
colorTable[tokens.TOKEN_COMMENT_LONG] = GSEOptions.COMMENT

local stringColor = GSEOptions.NormalColour
colorTable[tokens.TOKEN_STRING] = stringColor
colorTable[".."] = stringColor

local tableColor = GSEOptions.CONCAT
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = GSEOptions.STRING
colorTable["]"] = GSEOptions.STRING

local arithmeticColor = GSEOptions.NUMBER
colorTable[tokens.TOKEN_NUMBER] = arithmeticColor
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor

local logicColor1 = GSEOptions.EQUALS
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1

local logicColor2 = GSEOptions.EQUALS
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2

local castColor = GSEOptions.UNKNOWN
colorTable["/cast"] = castColor

colorTable[0] = "|r"

local function createVariableHeader(name, variable)
    local selpanel = AceGUI:Create("SelectablePanel")
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(90)
    variablesframe.panels[name] = selpanel
    selpanel:SetCallback(
        "OnClick",
        function(widget, _, selected, button)
            variablesframe:clearpanels(widget, selected)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(
                    leftscroll,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Export"])
                        rootDescription:CreateButton(
                            L["Export Variable"],
                            function()
                                print("Coming Soon")
                            end
                        )
                    end
                )
            end
            if button == "LeftButton" then
                variablesframe.showVariable(name)
                widget:SetClicked(true)
            end
        end
    )

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    local origjustifyV = font:GetJustifyV()
    local origjustifyH = font:GetJustifyH()
    font:SetJustifyV("BOTTOM")

    local label = AceGUI:Create("Label")
    label:SetFontObject(font)
    label:SetText(name)
    selpanel:AddChild(label)

    font:SetJustifyV(origjustifyV)
    font:SetJustifyH(origjustifyH)
    return selpanel
end

local function listVariables()
    leftscroll:ReleaseChildren()

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
    leftscroll:AddChild(newButton)

    local importButton = AceGUI:Create("Button")
    importButton:SetText(L["Import"])
    importButton:SetWidth(90)
    importButton:SetCallback(
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
    leftscroll:AddChild(importButton)

    for k, _ in pairs(GSEVariables) do
        local header = createVariableHeader(k)
        leftscroll:AddChild(header)
    end
end

function variablesframe.showVariable(name)
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
            GSEVariables[text] = GSE.CloneSequence(GSEVariables[currentKey])
            GSEVariables[currentKey] = nil
            currentKey = text
        end
    )

    rightContainer:AddChild(keyEditBox)

    local commentsEditBox = AceGUI:Create("MultiLineEditBox")
    commentsEditBox:SetLabel(L["Help Information"])
    commentsEditBox:SetNumLines(7)
    commentsEditBox:SetWidth(variablesframe.Width - 250)
    commentsEditBox:DisableButton(true)
    commentsEditBox:SetText(variable.comments)
    commentsEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            variable.funct = text
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
    valueEditBox:SetWidth(variablesframe.Width - 250)
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
    IndentationLib.enable(valueEditBox.editBox, colorTable, 4)

    rightContainer:AddChild(valueEditBox)

    local implementation = AceGUI:Create("EditBox")
    implementation:SetLabel(L["Implementation Link"])
    implementation:DisableButton(true)
    local implementationText = [[=GSE.V["]] .. name .. [["]()]]
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

    local savebutton = AceGUI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(150)
    savebutton:SetCallback(
        "OnClick",
        function()
            variable.LastUpdated = GSE.GetTimestamp()
            local compressedvariable = GSE.EncodeMessage(variable)
            GSEVariables[name] = compressedvariable
            GSE.V[name] = loadstring(variable.funct)
            if GSE.V[name] and type(GSE.V[name]()) == "boolean" then
                table.insert(GSE.BooleanVariables, name)
            end
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
                            print("Coming Soon")
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
                showVariable(widget, (GSEVariables[widget] and GSEVariables[widget] or nil))
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

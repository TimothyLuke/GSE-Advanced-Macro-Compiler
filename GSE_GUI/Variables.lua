local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local variablesframe = AceGUI:Create("Frame")
variablesframe:Hide()
variablesframe.panels = {}

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
        -- if editframe.save then
        --     local event = {}
        --     event.action = "openviewer"
        --     table.insert(GSE.OOCQueue, event)
        -- else
        --     if not editframe.AdvancedEditor then
        --         GSE.GUIShowViewer()
        --     end
        -- end
    end
)

variablesframe:SetLaayout("Flow")

local leftScrollCOntainer = AceGUI:Create("SimpleGroup")
leftScrollCOntainer:SetWidth(200)
leftScrollCOntainer:SetFullHeight(true) -- probably?
leftScrollCOntainer:SetLayout("Fill") -- important!

variablesframe:AddChild(leftScrollCOntainer)

local leftscroll = AceGUI:Create("ScrollFrame")
leftscroll:SetLayout("List") -- probably?
leftScrollCOntainer:AddChild(leftscroll)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(variablesframe.width - 200)
rightContainer:SetFullHeight(true) -- probably?
rightContainer:SetLayout("List")
variablesframe:AddChild(rightContainer)

local function showVariable(name)
    rightContainer:Release()
    local variable = {
        ["funct"] = [[function ()
            
        end]],
        ["comments"] = ""
    }
    if not GSE.isEmpty(GSEVariables[name]) then
        local status, err =
            pcall(
            function()
                local _, uncompressedVersion = GSE.DecodeMessage(v)
                variable = uncompressedVersion
            end
        )
    end
    rightContainer.variable = variable
    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel()
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(50)
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
    commentsEditBox:SetLabel()
    commentsEditBox:SetNumLines(5)
    commentsEditBox:SetWidth(variablesframe.width - 200)
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
    valueEditBox:SetLabel()
    valueEditBox:SetNumLines(10)
    valueEditBox:SetWidth(variablesframe.width - 200)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(variable.funct)
    valueEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            variable.funct = text
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            variable.funct = valueEditBox:GetText()
        end
    )

    rightContainer:AddChild(valueEditBox)

    local testRowButton = AceGUI:Create("Icon")
    testRowButton:SetImageSize(20, 20)
    testRowButton:SetWidth(20)
    testRowButton:SetHeight(20)
    testRowButton:SetImage("Interface\\Icons\\inv_misc_punchcards_blue")

    testRowButton:SetCallback(
        "OnClick",
        function()
            local val = valueEditBox:GetText()
            if type(val) == "string" then
                local functline = GSE.RemoveComments(val)
                if string.sub(functline, 1, 9) == "function(" then
                    functline = string.sub(functline, 11)
                    functline = functline:sub(1, -4)
                    functline = loadstring(functline)
                    -- print(type(functline))
                    if functline ~= nil then
                        val = functline
                    end
                end
            end
            -- print("updated Type: ".. type(value))
            -- print(value)
            if type(val) == "function" then
                val = val()
            end

            if type(val) == "boolean" then
                val = tostring(val)
            end

            StaticPopupDialogs["GSE-GenericMessage"].text =
                string.format(
                L["The current result of variable |cff0000ff~~%s~~|r is |cFF00D1FF%s|r"],
                keyEditBox:GetText(),
                val
            )
            StaticPopup_Show("GSE-GenericMessage")
        end
    )
    testRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Test Variable"], L["Show the current value of this variable."], editframe)
        end
    )
    testRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    rightContainer:AddChild(testRowButton)

    local deleteRowButton = AceGUI:Create("Icon")
    deleteRowButton:SetImageSize(20, 20)
    deleteRowButton:SetWidth(20)
    deleteRowButton:SetHeight(20)
    deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    deleteRowButton:SetCallback(
        "OnClick",
        function()
            GSEVariables[keyEditBox:GetText()] = nil
            rightContainer:ReleaseChildren()
        end
    )
    deleteRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], editframe)
        end
    )
    deleteRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(variablesframe)
        end
    )
    rightContainer:AddChild(deleteRowButton)

    local savebutton = AceGUI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(100)
    savebutton:SetCallback(
        "OnClick",
        function()
            local compressedvariable = GSE.EncodeMessage(variable)
            GSEVariables[name] = compressedvariable
            GSE.V[name] = loadstring(variable.funct)
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
    rightContainer:AddChild(savebutton)
end

local function createVariableHeader(name, variable)
    local selpanel = AceGUI:Create("SelectablePanel")
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(100)
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
                                print("Clicked button 2")
                            end
                        )
                    end
                )
            end
            if button == "LeftButton" then
                showVariable(name, (GSEVariables[name] and GSEVariables[name] or nil))
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

local function newVariable()
    local header = createVariableHeader("MyNewVar" .. math.random(100))
    leftscroll:AddChild(header)
end

local function listVariables()
    leftscroll:Release()
    for k, _ in pairs(GSEVariables) do
        local header = createVariableHeader(k)
        leftscroll:AddChild(header)
    end
end

leftscroll:SetScript(
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
                            newVariable()
                        end
                    )
                    rootDescription:CreateButton(
                        L["Import"],
                        function()
                            print("Clicked button 1")
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

local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local remoteFrame = AceGUI:Create("Frame")
remoteFrame:Hide()
remoteFrame.GSEUser = ""
remoteFrame.SequenceList = {}

remoteFrame:SetStatusText(L["Select a Sequence"])
remoteFrame:SetCallback("OnClose", function(widget)
    remoteFrame:Hide()
end)
remoteFrame:SetLayout("List")

remoteFrame.Height = GSEOptions.editorHeight
remoteFrame.Width = GSEOptions.editorWidth

local layoutcontainer = AceGUI:Create("SimpleGroup")
layoutcontainer:SetFullWidth(true)
layoutcontainer:SetHeight(remoteFrame.Height - 320)
layoutcontainer:SetLayout("Flow") -- Important!

local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
scrollcontainer:SetFullWidth(true)
-- scrollcontainer:SetFullHeight(true) -- Probably?
-- scrollcontainer:SetWidth(remoteFrame.Width )
scrollcontainer:SetHeight(remoteFrame.Height - 320)
scrollcontainer:SetLayout("Fill") -- Important!

local contentcontainer = AceGUI:Create("ScrollFrame")
scrollcontainer:AddChild(contentcontainer)
layoutcontainer:AddChild(scrollcontainer)
remoteFrame:AddChild(layoutcontainer)

local function addKeyPairRow(container, rowWidth, SequenceName, Help, ClassID)
    local linegroup1 = AceGUI:Create("SimpleGroup")
    linegroup1:SetLayout("Flow")
    linegroup1:SetWidth(rowWidth)
    rowWidth = rowWidth - 70

    local keyEditBox = AceGUI:Create("Label")
    keyEditBox:SetText(SequenceName)
    keyEditBox:SetWidth(rowWidth * 0.25)

    linegroup1:AddChild(keyEditBox)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local helpLabel = AceGUI:Create("Label")
    helpLabel:SetText(Help)
    helpLabel:SetWidth(rowWidth * 0.75)
    linegroup1:AddChild(helpLabel)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(8)
    linegroup1:AddChild(spacerlabel2)

    local testRowButton = AceGUI:Create("Icon")
    testRowButton:SetImageSize(20, 20)
    testRowButton:SetWidth(20)
    testRowButton:SetHeight(20)
    testRowButton:SetImage("Interface\\Icons\\inv_misc_punchcards_blue")

    testRowButton:SetCallback("OnClick", function()
        GSE.RequestSequence(ClassID, SequenceName, remoteFrame.GSEUser)
    end)
    testRowButton:SetCallback('OnEnter', function()
        GSE.CreateToolTip(L["Request Macro"], L["Request that the user sends you a copy of this macro."], remoteFrame)
    end)
    testRowButton:SetCallback('OnLeave', function()
        GSE.ClearTooltip(remoteFrame)
    end)
    linegroup1:AddChild(testRowButton)

    -- local deleteRowButton = AceGUI:Create("Icon")
    -- deleteRowButton:SetImageSize(20, 20)
    -- deleteRowButton:SetWidth(20)
    -- deleteRowButton:SetHeight(20)
    -- deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    -- deleteRowButton:SetCallback("OnClick", function()
    --     editframe.Sequence.Variables[keyEditBox:GetText()] = nil
    --     linegroup1:ReleaseChildren()
    -- end)
    -- deleteRowButton:SetCallback('OnEnter', function()
    --     GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], editframe)
    -- end)
    -- deleteRowButton:SetCallback('OnLeave', function()
    --     GSE.ClearTooltip(editframe)
    -- end)
    -- linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
end

function GSE.ShowRemoteWindow(SequenceList, GSEUser)
    local classlinegroup = AceGUI:Create("SimpleGroup")
    classlinegroup:SetLayout("Flow")
    local columnWidth = remoteFrame.Width - 55

    classlinegroup:SetWidth(remoteFrame.Width - 50)

    local nameLabel = AceGUI:Create("Heading")
    nameLabel:SetText(L["Name"])
    nameLabel:SetWidth((columnWidth - 25) * 0.25)
    classlinegroup:AddChild(nameLabel)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    classlinegroup:AddChild(spacerlabel1)

    local valueLabel = AceGUI:Create("Heading")
    valueLabel:SetText(L["Help Information"])
    valueLabel:SetWidth((columnWidth - 45) * 0.75 - 18)
    classlinegroup:AddChild(valueLabel)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(5)
    classlinegroup:AddChild(spacerlabel2)

    local delLabel = AceGUI:Create("Heading")
    delLabel:SetText(L["Actions"])
    delLabel:SetWidth(25)
    classlinegroup:AddChild(delLabel)

    contentcontainer:AddChild(classlinegroup)

    remoteFrame.SequenceList = SequenceList
    remoteFrame.GSEUser = GSEUser
    for ClassID, v in ipairs(remoteFrame.SequenceList) do
        local lClassID = tonumber(ClassID)
        local linegroup1 = AceGUI:Create("SimpleGroup")
        linegroup1:SetLayout("Flow")
        linegroup1:SetWidth(columnWidth)
        if lClassID > 0 then
            local classbutton = AceGUI:Create("Icon")
            classbutton:SetImageSize(20, 20)
            classbutton:SetWidth(20)
            classbutton:SetHeight(20)
            classbutton:SetImage(GSE.GetClassIcon(lClassID))
            linegroup1:AddChild(classbutton)
        end
        local classLabel = AceGUI:Create("Label")
        classLabel:SetText(Statics.SpecIDList[lClassID])
        linegroup1:AddChild(classLabel)
        contentcontainer:AddChild(linegroup1)
        for name, value in pairs(v) do
            local desc = value.Help

            if GSE.isEmpty(value.Help) then
                desc = L["No Help Information "]
            end

            addKeyPairRow(contentcontainer, columnWidth, name, desc, lClassID)
        end
    end
    remoteFrame:SetTitle(string.format(L["GSE - %s's Macros"], remoteFrame.GSEUser))

    remoteFrame:Show()
end

remoteFrame:SetCallback("OnClose", function(self)
    GSE.ClearTooltip(remoteFrame)
    contentcontainer:ReleaseChildren()
    remoteFrame:Hide()
end)

local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local cacheFrame = AceGUI:Create("Frame")
cacheFrame:Hide()
GSE.GUICacheFrame = cacheFrame
function GSE.GUICreateCacheTabs()
    local tabl = {}

    for key, _ in pairs(GSESpellCache) do
        table.insert(
            tabl,
            {
                text = key,
                value = key
            }
        )
    end
    return tabl
end

function GSE.GUISelectCacheTab(container, event, group)
    if not GSE.isEmpty(container) then
        cacheFrame.reloading = true
        container:ReleaseChildren()
        cacheFrame.SelectedTab = group
        GSE:GUIDrawSpellCacheEditor(container, group)
        cacheFrame.reloading = false
    end
end

local function addKeyPairRow(container, rowWidth, key, value, language)
    local blank = false

    if GSE.isEmpty(key) then
        blank = true
    end
    if GSE.isEmpty(value) then
        blank = true
    end
    if GSE.isEmpty(language) then
        blank = true
    end
    if blank == true then
        return
    end

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    linegroup1:SetWidth(rowWidth)
    rowWidth = rowWidth - 70

    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel()
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(rowWidth * 0.50)
    keyEditBox:SetText(key)
    local currentKey = key
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            GSESpellCache[language][text] = GSESpellCache[language][currentKey]
            GSESpellCache[language][currentKey] = nil
            currentKey = text
        end
    )
    linegroup1:AddChild(keyEditBox)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueEditBox = AceGUI:Create("EditBox")
    valueEditBox:SetLabel()
    valueEditBox:SetWidth(rowWidth * 0.50)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(value)
    valueEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            GSESpellCache[language][currentKey] = text
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            valueEditBox:SetText(GSESpellCache[language][currentKey])
        end
    )

    linegroup1:AddChild(valueEditBox)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(15)
    linegroup1:AddChild(spacerlabel2)

    local deleteRowButton = AceGUI:Create("Icon")
    deleteRowButton:SetImageSize(20, 20)
    deleteRowButton:SetWidth(20)
    deleteRowButton:SetHeight(20)
    deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    deleteRowButton:SetCallback(
        "OnClick",
        function()
            GSESpellCache[language][currentKey] = nil
            linegroup1:ReleaseChildren()
        end
    )

    linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
    return keyEditBox
end

function GSE:GUIDrawSpellCacheEditor(container, language)
    local maxWidth = container.frame:GetWidth()
    local scrollcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetHeight(cacheFrame.Height - 110)
    scrollcontainer:SetLayout("Fill") -- Important!

    local contentcontainer = AceGUI:Create("ScrollFrame") -- "InlineGroup" is also good
    contentcontainer:SetWidth(maxWidth)
    contentcontainer:SetAutoAdjustHeight(true)
    scrollcontainer:AddChild(contentcontainer)
    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    local columnWidth = maxWidth - 55

    linegroup1:SetWidth(columnWidth + 5)

    local nameLabel = AceGUI:Create("Heading")
    nameLabel:SetText(L["Spell Name"])
    nameLabel:SetWidth(columnWidth * 0.48)
    linegroup1:AddChild(nameLabel)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueLabel = AceGUI:Create("Heading")
    valueLabel:SetText(L["Spell ID"])
    valueLabel:SetWidth(columnWidth * 0.47)
    linegroup1:AddChild(valueLabel)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(5)
    linegroup1:AddChild(spacerlabel2)

    local delLabel = AceGUI:Create("Heading")
    delLabel:SetText(L["Actions"])
    delLabel:SetWidth(columnWidth * 0.10)
    linegroup1:AddChild(delLabel)
    contentcontainer:AddChild(linegroup1)
    for key, value in pairs(GSESpellCache[language]) do
        addKeyPairRow(contentcontainer, columnWidth, key, value, language)
    end
    container:AddChild(scrollcontainer)
end

if GSE.isEmpty(GSEOptions.editorHeight) then
    GSEOptions.editorHeight = 500
end
if GSE.isEmpty(GSEOptions.editorWidth) then
    GSEOptions.editorWidth = 700
end
cacheFrame.Height = GSEOptions.editorHeight
cacheFrame.Width = GSEOptions.editorWidth
if cacheFrame.Height < 500 then
    cacheFrame.Height = 500
    GSEOptions.editorHeight = cacheFrame.Height
end
if cacheFrame.Width < 700 then
    cacheFrame.Width = 700
    GSEOptions.editorWidth = cacheFrame.Width
end
cacheFrame.frame:SetClampRectInsets(-10, -10, -10, -10)
cacheFrame.frame:SetHeight(GSEOptions.editorHeight)
cacheFrame.frame:SetWidth(GSEOptions.editorWidth)
cacheFrame:SetTitle(L["Spell Cache Editor"])
cacheFrame:SetCallback(
    "OnClose",
    function(self)
        cacheFrame:Hide()
    end
)
cacheFrame:SetLayout("List")
cacheFrame.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        cacheFrame.Height = height
        cacheFrame.Width = width
        if cacheFrame.Height > GetScreenHeight() then
            cacheFrame.Height = GetScreenHeight() - 10
            cacheFrame:SetHeight(cacheFrame.Height)
        end
        if cacheFrame.Height < 500 then
            cacheFrame.Height = 500
            cacheFrame:SetHeight(cacheFrame.Height)
        end
        if cacheFrame.Width < 700 then
            cacheFrame.Width = 700
            cacheFrame:SetWidth(cacheFrame.Width)
        end
        GSEOptions.editorHeight = cacheFrame.Height
        GSEOptions.editorWidth = cacheFrame.Width
        GSE.GUISelectEditorTab(cacheFrame.ContentContainer, "Resize", cacheFrame.SelectedTab)
        cacheFrame:DoLayout()
    end
)

local tabgrp = AceGUI:Create("TabGroup")
tabgrp:SetLayout("Flow")
tabgrp:SetTabs(GSE.GUICreateCacheTabs())
cacheFrame.ContentContainer = tabgrp
tabgrp:SetCallback(
    "OnGroupSelected",
    function(container, event, group)
        GSE.GUISelectCacheTab(container, event, group)
    end
)

tabgrp:SetFullWidth(true)
tabgrp:SetFullHeight(true)

tabgrp:SelectTab("config")
cacheFrame:AddChild(tabgrp)

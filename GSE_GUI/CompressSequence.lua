local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L


local compressframe = AceGUI:Create("Frame")
compressframe.AutoCreateIcon = true

compressframe:Hide()


compressframe:SetTitle(L["Gnome Sequencer: Compress a Sequence String."])
compressframe:SetStatusText(L["Compress Sequence from Forums"])
compressframe:SetCallback("OnClose", function(widget)  compressframe:Hide(); end)
compressframe:SetLayout("List")

local importsequencebox = AceGUI:Create("MultiLineEditBox")
importsequencebox:SetLabel(L["Sequence to Compress."])
importsequencebox:SetNumLines(20)
importsequencebox:DisableButton(true)
importsequencebox:SetFullWidth(true)
compressframe:AddChild(importsequencebox)

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")


local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Compress"])
recbutton:SetWidth(150)
recbutton:SetCallback("OnClick", function() importsequencebox:SetText(GSE.CompressSequenceFromString(importsequencebox:GetText())) end)
recButtonGroup:AddChild(recbutton)

compressframe:AddChild(recButtonGroup)
GSE.GUICompressFrame = compressframe

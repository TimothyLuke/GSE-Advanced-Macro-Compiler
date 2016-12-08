local GNOME,_ = ...

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()



local versionframe = AceGUI:Create("Frame")
GSE.GUIVersionFrame = versionframe
versionframe:Hide()

versionframe:SetTitle(L["Manage Versions"])
versionframe:SetStatusText(L["Gnome Sequencer: Sequence Version Manager"])
versionframe:SetCallback("OnClose", function(widget)  versionframe:Hide(); GSE.GUIViewFrame:Show() end)
versionframe:SetLayout("List")

local columnGroup = AceGUI:Create("SimpleGroup")
columnGroup:SetFullWidth(true)
columnGroup:SetLayout("Flow")

local leftGroup = AceGUI:Create("SimpleGroup")
leftGroup:SetFullWidth(true)
leftGroup:SetLayout("List")

local rightGroup = AceGUI:Create("SimpleGroup")
rightGroup:SetFullWidth(true)
rightGroup:SetLayout("List")

local activesequencebox = AceGUI:Create("MultiLineEditBox")
activesequencebox:SetLabel(L["Active Version: "])
activesequencebox:SetNumLines(10)
activesequencebox:DisableButton(true)
activesequencebox:SetFullWidth(true)
leftGroup:AddChild(activesequencebox)

local otherversionlistbox = AceGUI:Create("Dropdown")
otherversionlistbox:SetLabel(L["Select Other Version"])
otherversionlistbox:SetWidth(150)
otherversionlistbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:ChangeOtherSequence(key) end)
rightGroup:AddChild(otherversionlistbox)

local otherSequenceVersions = AceGUI:Create("MultiLineEditBox")
otherSequenceVersions:SetNumLines(11)
otherSequenceVersions:DisableButton(true)
otherSequenceVersions:SetFullWidth(true)
rightGroup:AddChild(otherSequenceVersions)

columnGroup:AddChild(leftGroup)
columnGroup:AddChild(rightGroup)

versionframe:AddChild(columnGroup)

local othersequencebuttonGroup = AceGUI:Create("SimpleGroup")
othersequencebuttonGroup:SetFullWidth(true)
othersequencebuttonGroup:SetLayout("Flow")

local actbutton = AceGUI:Create("Button")
actbutton:SetText(L["Make Active"])
actbutton:SetWidth(150)
actbutton:SetCallback("OnClick", function() GSSE:SetActiveSequence(otherversionlistboxvalue) end)
othersequencebuttonGroup:AddChild(actbutton)

local delbutton = AceGUI:Create("Button")
delbutton:SetText(L["Delete Version"])
delbutton:SetWidth(150)
delbutton:SetCallback("OnClick", function()
  if not GSE.isEmpty(otherversionlistboxvalue) then
    GSDeleteSequenceVersion(currentSequence, otherversionlistboxvalue)
    otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
    otherSequenceVersions:SetText("")
  end
end)
othersequencebuttonGroup:AddChild(delbutton)


versionframe:AddChild(othersequencebuttonGroup)

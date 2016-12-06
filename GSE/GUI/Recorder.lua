local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local recordframe = AceGUI:Create("Frame")
recordframe:Hide()
GSE.GUIRecordFrame = recordframe
local recbuttontext = L["Record"]

-- Record Frame

recordframe:SetTitle(L["Record Macro"])
recordframe:SetStatusText(L["Gnome Sequencer: Record your rotation to a macro."])
recordframe:SetCallback("OnClose", function(widget)  recordframe:Hide(); end)
recordframe:SetLayout("List")

local recordsequencebox = AceGUI:Create("MultiLineEditBox")
recordsequencebox:SetLabel(L["Actions"])
recordsequencebox:SetNumLines(20)
recordsequencebox:DisableButton(true)
recordsequencebox:SetFullWidth(true)
recordframe:AddChild(recordsequencebox)
GSE.GUIRecordFrame.RecordSequenceBox = recordsequencebox

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")


local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Record"])
recbutton:SetWidth(150)
recbutton:SetCallback("OnClick", function() GSE.GUIManageRecord() end)
recButtonGroup:AddChild(recbutton)

local createmacrobutton = AceGUI:Create("Button")
createmacrobutton:SetText(L["Create Macro"])
createmacrobutton:SetWidth(150)
createmacrobutton:SetCallback("OnClick", function()
  GSE.GUILoadEditor( nil, GSE.GUIRecordFrame, recordsequencebox:GetText())
end)
createmacrobutton:SetDisabled(true)
recButtonGroup:AddChild(createmacrobutton)

recordframe:AddChild(recButtonGroup)

function GSE.GUIManageRecord()
  if recbuttontext == L["Record"] then
    recbuttontext = L["Stop"]
    createmacrobutton:SetDisabled(false)
    GSE.RecorderActive = true
  else
    recbuttontext = L["Record"]
    GSE.RecorderActive = false
  end
  recbutton:SetText(recbuttontext)
end

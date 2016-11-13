local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local recordframe = AceGUI:Create("Frame")
GSE.GUI.RecordFrame = recordframe
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

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")


local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Record"])
recbutton:SetWidth(150)
recbutton:SetCallback("OnClick", function() GSSE:ManageRecord() end)
recButtonGroup:AddChild(recbutton)

local createmacrobutton = AceGUI:Create("Button")
createmacrobutton:SetText(L["Create Macro"])
createmacrobutton:SetWidth(150)
createmacrobutton:SetCallback("OnClick", function() GSSE:SaveRecordMacro() end)
createmacrobutton:SetDisabled(true)
recButtonGroup:AddChild(createmacrobutton)

recordframe:AddChild(recButtonGroup)


function GSE.GUI.SaveRecordMacro()
  GSE.GUI.LoadEditor( nil, recordsequencebox:GetText())
  recordframe:Hide()

end

function GSE.GUI.ManageRecord()
  if recbuttontext == L["Record"] then
    GSSE:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
    recbuttontext = L["Stop"]
    createmacrobutton:SetDisabled(false)
  else
    recbuttontext = L["Record"]
    GSSE:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED')
  end
  recbutton:SetText(recbuttontext)
end

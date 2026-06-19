local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local UI = GSE.UI
local L = GSE.L

local recordframe = UI:Create("Frame")
recordframe:Hide()
recordframe.frame:SetFrameStrata("MEDIUM")
recordframe.frame:SetClampedToScreen(true)
recordframe.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
recordframe.frame:SetSize(560, 560)
GSE.GUIRecordFrame = recordframe
local recbuttontext = L["Record"]

-- Record Frame

recordframe:SetTitle(L["Record Macro"])
recordframe:SetStatusText(L["GSE: Record your rotation to a macro."])
recordframe:SetCallback(
  "OnClose",
  function(widget)
    recordframe:Hide()
  end
)
recordframe:SetLayout("List")

local recordsequencebox = UI:Create("MultiLineEditBox")
recordsequencebox:SetLabel(L["Actions"])
recordsequencebox:SetNumLines(20)
recordsequencebox:DisableButton(true)
recordsequencebox:SetFullWidth(true)
recordframe:AddChild(recordsequencebox)
GSE.GUIRecordFrame.RecordSequenceBox = recordsequencebox

local recButtonGroup = UI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")

local recbutton = UI:Create("Button")
recbutton:SetText(L["Record"])
recbutton:SetWidth(150)
recbutton:SetCallback(
  "OnClick",
  function()
    GSE.GUIManageRecord()
  end
)
recButtonGroup:AddChild(recbutton)

local createmacrobutton = UI:Create("Button")
createmacrobutton:SetText(L["Create Macro"])
createmacrobutton:SetWidth(150)
createmacrobutton:SetCallback(
  "OnClick",
  function()
    recordframe:Hide()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    GSE.GUILoadEditor(editor, nil, recordsequencebox:GetText())
  end
)
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

if recordframe and recordframe.frame and GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(recordframe.frame)
end
end
table.insert(ns.deferred, setup)

local GNOME,_ = ...
local Statics = GSE.Static
local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local compareframe = AceGUI:Create("Frame")
compareframe:Hide()
compareframe.ChosenAction = "MERGE"

GSE.GUICompareFrame = compareframe

compareframe:SetTitle(L["Sequence Compare"])

compareframe:SetCallback("OnClose", function (self)
  compareframe:Hide();
  if compareframe.action then
    -- Some action was taken, so wait for the OOC Queue to process.
    local event = {}
    event.action = "openviewer"
    table.insert(GSE.OOCQueue, event)
  else
    GSE.GUIShowViewer()
  end
end)

compareframe:SetLayout("List")

local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")


leftColumn = AceGUI:Create("MultiLineEditBox")
compareframe.OrigText = leftColumn
leftColumn:SetRelativeWidth(0.5)
leftColumn:SetFullHeight(true)
leftColumn:SetNumLines(25)
leftColumn:DisableButton(true)
leftColumn:SetLabel(L["Local Macro"])

rightColumn = AceGUI:Create("MultiLineEditBox")
compareframe.NewText = rightColumn
rightColumn:SetRelativeWidth(0.5)
rightColumn:SetFullHeight(true)
rightColumn:SetNumLines(25)
rightColumn:DisableButton(true)
rightColumn:SetLabel(L["Updated Macro"])

headerGroup:AddChild(leftColumn)
headerGroup:AddChild(rightColumn)

compareframe:AddChild (headerGroup)

local actionButtonGroup = AceGUI:Create("SimpleGroup")
actionButtonGroup:SetWidth(602)
actionButtonGroup:SetLayout("Flow")
actionButtonGroup:SetHeight(15)

local actionLabel = AceGUI:Create("Label")
actionLabel:SetText(L["Choose import action:"] .. "   ")

actionButtonGroup:AddChild(actionLabel)

if GSE.isEmpty(GSEOptions.DefaultImportAction) then
  GSEOptions.DefaultImportAction = "MERGE"
end

local actionChoiceRadio = AceGUI:Create("Dropdown")
actionChoiceRadio:SetList({
  ["MERGE"] = L["Merge"],
  ["REPLACE"] = L["Replace"],
  ["IGNORE"] = L["Ignore"],
  ["RENAME"] = L["Rename New Macro"]
})
actionChoiceRadio:SetValue(GSEOptions.DefaultImportAction)

actionButtonGroup:AddChild(actionChoiceRadio)

local nameeditbox = AceGUI:Create("EditBox")

actionChoiceRadio:SetCallback("OnValueChanged", function (obj,event,key)
    compareframe.ChosenAction = key
    if key == "RENAME" then
      nameeditbox:SetDisabled(false)
      nameeditbox:SetText(compareframe.sequenceName)
    else
      nameeditbox:SetDisabled(true)
    end
end)


nameeditbox:SetLabel(L["New Sequence Name"])
nameeditbox:SetWidth(250)
nameeditbox:SetCallback("OnTextChanged", function(obj, event, key)
  compareframe.sequenceName = key
end)
--nameeditbox:SetScript("OnEditFocusLost", function()
--  editframe:SetText(string.upper(editframe:GetText()))
--  editframe.SequenceName = nameeditbox:GetText()
--end)
nameeditbox:SetDisabled(true)
nameeditbox:DisableButton( true)
nameeditbox:SetText(compareframe.sequenceName)

actionButtonGroup:AddChild(nameeditbox)


local actionbutton = AceGUI:Create("Button")
actionbutton:SetText(L["Continue"])
actionbutton:SetWidth(150)
actionbutton:SetCallback("OnClick", function()
  compareframe:Hide()
  GSE.PerformMergeAction(compareframe.ChosenAction, compareframe.classid, compareframe.sequenceName, GSE.GUICompareFrame.NewSequence)
end)

actionButtonGroup:AddChild(actionbutton)
compareframe:AddChild (actionButtonGroup)



function GSE.GUIShowCompareWindow(sequenceName, classid, newsequence)
  GSE.GUICompareFrame.NewSequence = newsequence
  GSE.GUICompareFrame.OrigText:SetText(GSE.ExportSequence(GSE.Library[classid][sequenceName], sequenceName, true, "STRING", true))
  GSE.GUICompareFrame.NewText:SetText(GSE.ExportSequence(newsequence, sequenceName, true, "STRING", true))
  GSE.GUICompareFrame:Show()
  GSE.GUICompareFrame.classid = classid
  GSE.GUICompareFrame.sequenceName = sequenceName
end

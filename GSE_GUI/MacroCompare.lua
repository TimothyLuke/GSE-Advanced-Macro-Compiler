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
    -- SOme action was taken so wait for the OOC Queue to process.
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

origscrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
origscrollcontainer:SetFullWidth(true)
origscrollcontainer:SetFullHeight(true) -- probably?
origscrollcontainer:SetLayout("Fill") -- important!

origlabel = AceGUI:Create("Label")
origlabel:SetText(L["Local Macro"])
origscrollcontainer:AddChild(origlabel)

origSequenceText = AceGUI:Create("Label")
compareframe.OrigText = origSequenceText
origscrollcontainer:AddChild(origSequenceText)

newscrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
newscrollcontainer:SetFullWidth(true)
newscrollcontainer:SetFullHeight(true) -- probably?
newscrollcontainer:SetLayout("Fill") -- important!

newlabel = AceGUI:Create("Label")
newlabel:SetText(L["Updated Macro"])
newscrollcontainer:AddChild(newlabel)


newSequenceText = AceGUI:Create("Label")
compareframe.NewText = newSequenceText
newscrollcontainer:AddChild(newSequenceText)

headerGroup:AddChild(origscrollcontainer)
headerGroup:AddChild(newscrollcontainer)

compareframe:AddChild (headerGroup)

local actionButtonGroup = AceGUI:Create("SimpleGroup")
actionButtonGroup:SetWidth(602)
actionButtonGroup:SetLayout("Flow")
actionButtonGroup:SetHeight(15)

local actionLabel = AceGUI:Create("Label")
actionLabel:SetText(L["Choose import action:"] .. "   ")

actionButtonGroup:AddChild(actionLabel)

if GSE.isEmpty(GSEOptions.DefaultImportAction)
  GSEOptions.DefaultImportAction = "MERGE"
end

actionChoiceRadio:SetList({
  ["MERGE"] = L["Merge"],
  ["REPLACE"] = L["Replace"],
  ["IGNORE"] = L["Ignore"]
})
actionChoiceRadio:SetValue(GSEOptions.DefaultImportAction)
actionChoiceRadio:SetCallback("OnValueChanged", function (obj,event,key)
    compareframe.ChosenAction = key
end)

local actionbutton = AceGUI:Create("Button")
actionbutton:SetText(L["Continue"])
actionbutton:SetWidth(150)
actionbutton:SetCallback("OnClick", function()
  GSE.PerformMergeAction(compareframe.ChosenAction, compareframe.classid, compareframe.sequenceName, newSequence)
end)

function GSE.GUIShowCompareWindow(sequenceName, classid, newsequence)
  GSE.GUICompareFrame.OrigText:SetText(GSE.ExportSequence(GSELibrary[classid][sequenceName], sequenceName, false, "STRING"))
  GSE.GUICompareFrame.NewText:SetText(newsequence, sequenceName, false, "STRING"))
  GSE.GUICompareFrame:Show()
  GSE.GUICompareFrame.classid = classid
  GSE.GUICompareFrame.sequenceName = sequenceName
end

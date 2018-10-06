local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local exportframe = AceGUI:Create("Frame")
exportframe:Hide()
exportframe.classid = 0
exportframe.sequencename = ""

exportframe:SetTitle(L["Gnome Sequencer: Export a Sequence String."])
exportframe:SetStatusText(L["Export a Sequence"])
exportframe:SetCallback("OnClose", function(widget)  exportframe:Hide() end)
exportframe:SetLayout("List")

local exportsequencebox = AceGUI:Create("MultiLineEditBox")
exportsequencebox:SetLabel(L["Sequence"])
exportsequencebox:SetNumLines(22)
exportsequencebox:DisableButton(true)
exportsequencebox:SetFullWidth(true)
exportframe:AddChild(exportsequencebox)

local wlmforumexportcheckbox = AceGUI:Create("CheckBox")
wlmforumexportcheckbox:SetType("checkbox")

wlmforumexportcheckbox:SetLabel(L["Format export for WLM Forums"])
exportframe:AddChild(wlmforumexportcheckbox)
wlmforumexportcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
  GSE.GUIUpdateExportBox()
end)
wlmforumexportcheckbox:SetValue( GSEOptions.UseWLMExportFormat)

local enforceCompatabilityCheckbox = AceGUI:Create("CheckBox")
enforceCompatabilityCheckbox:SetType("checkbox")

enforceCompatabilityCheckbox:SetLabel(L["Enforce GSE minimum version for this macro"])
exportframe:AddChild(enforceCompatabilityCheckbox)
enforceCompatabilityCheckbox:SetCallback("OnValueChanged", function (sel, object, value)
  if value then
    exportframe.sequence.EnforceCompatability = true
  else
    exportframe.sequence.EnforceCompatability = false
  end
  exportframe.sequence.GSEVersion = GSE.VersionString
  GSE.GUIUpdateExportBox()
end)

local readOnlyCheckBox = AceGUI:Create("CheckBox")
readOnlyCheckBox:SetType("checkbox")
readOnlyCheckBox:SetLabel(L["Export Macro Read Only"])
exportframe:AddChild(readOnlyCheckBox)


local disableEditorCheckBox = AceGUI:Create("CheckBox")
disableEditorCheckBox:SetType("checkbox")
disableEditorCheckBox:SetLabel(L["Disable Editor"])
disableEditorCheckBox:SetDisabled(true)
exportframe:AddChild(disableEditorCheckBox)

readOnlyCheckBox:SetCallback("OnValueChanged", function (sel, object, value)
  if value then
    exportframe.sequence.ReadOnly = true
    disableEditorCheckBox:SetDisabled(false)
  else
    exportframe.sequence.ReadOnly = false
    exportframe.sequence.DisableEditor = nil
    disableEditorCheckBox:SetDisabled(true)
  end
  GSE.GUIUpdateExportBox()
end)

disableEditorCheckBox:SetCallback("OnValueChanged", function (sel, object, value)
  if value then
    exportframe.sequence.DisableEditor = true
  else
    exportframe.sequence.DisableEditor = false
  end
  GSE.GUIUpdateExportBox()
end)

GSE.GUIExportframe = exportframe

exportframe.ExportSequenceBox = exportsequencebox

function GSE.GUIUpdateExportBox()
  if wlmforumexportcheckbox:GetValue() then
    local exporttext = "`" .. GSE.ExportSequence(GSE.GUIExportframe.sequence, exportframe.sequencename, GSEOptions.UseVerboseExportFormat, "ID", false) .."`"
    exporttext = exporttext .. GSE.ExportSequenceWLMFormat(GSE.GUIExportframe.sequence, exportframe.sequencename)
    GSE.GUIExportframe.ExportSequenceBox:SetText(exporttext)
  else
    GSE.GUIExportframe.ExportSequenceBox:SetText(GSE.ExportSequence(GSE.GUIExportframe.sequence, exportframe.sequencename, GSEOptions.UseVerboseExportFormat, "ID", false))
  end
end

function GSE.GUIExportSequence(classid, sequencename)
  GSE.GUIExportframe.classid = classid
  GSE.GUIExportframe.sequencename = sequencename
  GSE.GUIExportframe.sequence = GSE.CloneSequence(GSELibrary[tonumber(exportframe.classid)][exportframe.sequencename])
  GSE.GUIUpdateExportBox()
  GSE.GUIExportframe:Show()
end

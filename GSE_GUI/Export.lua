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
exportframe:SetCallback(
  "OnClose",
  function(widget)
    exportframe:Hide()
  end
)
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
wlmforumexportcheckbox:SetCallback(
  "OnValueChanged",
  function(sel, object, value)
    GSE.GUIUpdateExportBox()
  end
)
wlmforumexportcheckbox:SetValue(GSEOptions.UseWLMExportFormat)

local readOnlyCheckBox = AceGUI:Create("CheckBox")
readOnlyCheckBox:SetType("checkbox")
readOnlyCheckBox:SetLabel(L["Export Macro Read Only"])
exportframe:AddChild(readOnlyCheckBox)

local disableEditorCheckBox = AceGUI:Create("CheckBox")
disableEditorCheckBox:SetType("checkbox")
disableEditorCheckBox:SetLabel(L["Disable Editor"])
disableEditorCheckBox:SetDisabled(true)
exportframe:AddChild(disableEditorCheckBox)

readOnlyCheckBox:SetCallback(
  "OnValueChanged",
  function(sel, object, value)
    if value then
      exportframe.sequence.MetaData.ReadOnly = true
      disableEditorCheckBox:SetDisabled(false)
    else
      exportframe.sequence.MetaData.ReadOnly = false
      exportframe.sequence.MetaData.DisableEditor = false
      disableEditorCheckBox:SetDisabled(true)
    end
    GSE.GUIUpdateExportBox()
  end
)

disableEditorCheckBox:SetCallback(
  "OnValueChanged",
  function(sel, object, value)
    if value then
      exportframe.sequence.MetaData.DisableEditor = true
    else
      exportframe.sequence.MetaData.DisableEditor = false
    end
    GSE.GUIUpdateExportBox()
  end
)

GSE.GUIExportframe = exportframe

exportframe.ExportSequenceBox = exportsequencebox

function GSE.GUIUpdateExportBox()
  if wlmforumexportcheckbox:GetValue() then
    local exporttext =
      "```\n" ..
      GSE.ExportSequence(
        GSE.GUIExportframe.sequence,
        exportframe.sequencename,
        GSEOptions.UseVerboseExportFormat,
        "ID",
        false
      ) ..
        "\n```\n\n"
    exporttext = exporttext .. GSE.ExportSequenceWLMFormat(GSE.GUIExportframe.sequence, exportframe.sequencename)
    GSE.GUIExportframe.ExportSequenceBox:SetText(exporttext)
  else
    GSE.GUIExportframe.ExportSequenceBox:SetText(
      GSE.ExportSequence(
        GSE.GUIExportframe.sequence,
        exportframe.sequencename,
        GSEOptions.UseVerboseExportFormat,
        "ID",
        false
      )
    )
  end
end

function GSE.GUIExportSequence(classid, sequencename)
  local _, _, _, tocversion = GetBuildInfo()
  GSE.GUIExportframe.classid = classid
  GSE.GUIExportframe.sequencename = sequencename
  GSE.GUIExportframe.sequence = GSE.CloneSequence(GSE.Library[tonumber(exportframe.classid)][exportframe.sequencename])
  GSE.GUIExportframe.sequence.MetaData.GSEVersion = GSE.VersionNumber
  GSE.GUIExportframe.sequence.MetaData.EnforceCompatability = true
  GSE.GUIExportframe.sequence.MetaData.TOC = tocversion
  GSE.GUIUpdateExportBox()
  GSE.GUIExportframe:Show()
end

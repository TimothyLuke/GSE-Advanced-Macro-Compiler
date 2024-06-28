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
exportframe.frame:SetFrameStrata("MEDIUM")
exportframe:SetTitle(L["GSE: Export a Sequence String."])
exportframe:SetStatusText(L["Export a Sequence"])
exportframe:SetCallback(
  "OnClose",
  function(widget)
    exportframe:Hide()
  end
)
exportframe:SetLayout("List")

local exportsequencebox = AceGUI:Create("MultiLineEditBox")
exportsequencebox:SetLabel(L["Variable"])
exportsequencebox:SetNumLines(22)
exportsequencebox:DisableButton(true)
exportsequencebox:SetFullWidth(true)

local function CreateSequenceExport(type)
  exportframe:ReleaseChildren()

  exportsequencebox:SetLabel(L["Sequence"])

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

  local function GUIUpdateExportBox()
    local exportsequence = GSE.CloneSequence(GSE.GUIExportframe.sequence)
    exportsequence.objectType = type

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
      exportsequencebox:SetText(exporttext)
    else
      exportsequencebox:SetText(
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
      GUIUpdateExportBox()
    end
  )

  disableEditorCheckBox:SetCallback(
    "OnValueChanged",
    function(sel, object, value)
      if value then
        exportframe.sequence.MetaData.DisableEditor = true
      else
        exportframe.sequence.MetaData.DisableEditor = false
        exportframe.sequence.MetaData.AllowVariables = false
      end
      GUIUpdateExportBox()
    end
  )

  disableEditorCheckBox:SetDisabled(GSE.GUIExportframe.sequence.MetaData.DisableEditor)
  readOnlyCheckBox:SetDisabled(GSE.GUIExportframe.sequence.MetaData.ReadOnly)
  GUIUpdateExportBox()
end
GSE.GUIExportframe = exportframe

local function CreateVariableExport(objectname, type)
  exportframe:ReleaseChildren()
  exportsequencebox:SetLabel(L["Variable"])
  exportframe:AddChild(exportsequencebox)

  local localsuccess, uncompressedVersion = GSE.DecodeMessage(GSEVariables[objectname])
  uncompressedVersion.objectType = type
  uncompressedVersion.name = objectname
  exportsequencebox:SetText(GSE.EncodeMessage(uncompressedVersion))
end

local function CreateMacroExport(category, objectname, type)
  local source = GSEMacros
  if category == "p" then
    local char, realm = UnitFullName("player")
    source = GSEMacros[char .. "-" .. realm]
  end
  local exportobject = GSE.CloneSequence(source[objectname])
  exportobject.objectType = type
  exportobject.category = category
  local exportstring = GSE.EncodeMessage(exportobject)
  exportframe:ReleaseChildren()
  exportsequencebox:SetLabel(L["Macro"])
  exportframe:AddChild(exportsequencebox)
  exportsequencebox:SetText(exportstring)
end

function GSE.GUIExport(category, objectname, type)
  local _, _, _, tocversion = GetBuildInfo()
  GSE.GUIExportframe.classid = category

  if GSE.isEmpty(type) then
    type = "SEQUENCE"
  end
  GSE.GUIExportframe.type = type
  if type == "SEQUENCE" then
    GSE.GUIExportframe.sequencename = objectname
    GSE.GUIExportframe.sequence =
      GSE.CloneSequence(GSE.Library[tonumber(exportframe.classid)][exportframe.sequencename])
    GSE.GUIExportframe.sequence.MetaData.GSEVersion = GSE.VersionNumber
    GSE.GUIExportframe.sequence.MetaData.EnforceCompatability = true
    GSE.GUIExportframe.sequence.MetaData.TOC = tocversion
    CreateSequenceExport(type)
  elseif type == "VARIABLE" then
    CreateVariableExport(objectname, type)
  elseif type == "MACRO" then
    CreateMacroExport(category, objectname, type)
  end
  GSE.GUIExportframe:Show()
end

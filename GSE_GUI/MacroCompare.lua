local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

local function DisableCompareColoring(widget)
  if widget and widget.editBox and IndentationLib and IndentationLib.disable then
    IndentationLib.disable(widget.editBox)
  end
end

function GSE.GUIShowCompareWindow(sequenceName, classid, newsequence)
  local compareframe = UI:Create("Frame")
  compareframe:Hide()
  if GSE.isEmpty(GSEOptions.DefaultImportAction) then
    GSEOptions.DefaultImportAction = "MERGE"
  end
  compareframe.ChosenAction = GSEOptions.DefaultImportAction
  compareframe.frame:SetFrameStrata("MEDIUM")
  compareframe.frame:SetClampedToScreen(true)

  compareframe:SetTitle(L["Sequence Compare"] .. " - " .. sequenceName)

  compareframe:SetCallback(
    "OnClose",
    function(self)
      DisableCompareColoring(compareframe.OrigText)
      DisableCompareColoring(compareframe.NewText)
      compareframe:Hide()
      GSE.ShowSequences()
      UI:Release(self)
    end
  )

  compareframe:SetLayout("List")

  local headerGroup = UI:Create("SimpleGroup")
  headerGroup:SetFullWidth(true)
  headerGroup:SetLayout("Flow")

  local leftColumn = UI:Create("MultiLineEditBox")
  compareframe.OrigText = leftColumn
  leftColumn:SetRelativeWidth(0.5)
  leftColumn:SetFullHeight(true)
  leftColumn:SetNumLines(25)
  leftColumn:DisableButton(true)
  leftColumn:SetLabel(L["Local Macro"])
  IndentationLib.enable(leftColumn.editBox, Statics.IndentationColorTable, 4)
  leftColumn:SetCallback("OnRelease", DisableCompareColoring)

  local rightColumn = UI:Create("MultiLineEditBox")
  compareframe.NewText = rightColumn
  rightColumn:SetRelativeWidth(0.5)
  rightColumn:SetFullHeight(true)
  rightColumn:SetNumLines(25)
  rightColumn:DisableButton(true)
  rightColumn:SetLabel(L["Updated Macro"])
  IndentationLib.enable(rightColumn.editBox, Statics.IndentationColorTable, 4)
  rightColumn:SetCallback("OnRelease", DisableCompareColoring)

  headerGroup:AddChild(leftColumn)
  headerGroup:AddChild(rightColumn)

  compareframe:AddChild(headerGroup)

  local actionButtonGroup = UI:Create("SimpleGroup")
  actionButtonGroup:SetWidth(602)
  actionButtonGroup:SetLayout("Flow")
  actionButtonGroup:SetHeight(15)

  local actionLabel = UI:Create("Label")
  actionLabel:SetText(L["Choose import action:"] .. "   ")

  actionButtonGroup:AddChild(actionLabel)

  local actionChoiceRadio = UI:Create("Dropdown")
  actionChoiceRadio:SetList(
    {
      ["MERGE"] = L["Merge"],
      ["REPLACE"] = L["Replace"],
      ["IGNORE"] = L["Ignore"],
      ["RENAME"] = L["Rename New Macro"]
    }
  )
  actionChoiceRadio:SetValue(GSEOptions.DefaultImportAction)

  actionButtonGroup:AddChild(actionChoiceRadio)

  local nameeditbox = UI:Create("EditBox")

  actionChoiceRadio:SetCallback(
    "OnValueChanged",
    function(obj, event, key)
      compareframe.ChosenAction = key
      if key == "RENAME" then
        nameeditbox:SetDisabled(false)
        nameeditbox:SetText(compareframe.sequenceName)
      else
        nameeditbox:SetDisabled(true)
      end
    end
  )

  nameeditbox:SetLabel(L["New Sequence Name"])
  nameeditbox:SetWidth(250)
  nameeditbox:SetCallback(
    "OnTextChanged",
    function(obj, event, key)
      compareframe.sequenceName = key
    end
  )

  nameeditbox:SetDisabled(true)
  nameeditbox:DisableButton(true)
  nameeditbox:SetText(compareframe.sequenceName)

  actionButtonGroup:AddChild(nameeditbox)

  local actionbutton = UI:Create("Button")
  actionbutton:SetText(L["Continue"])
  actionbutton:SetWidth(150)
  actionbutton:SetCallback(
    "OnClick",
    function()
      DisableCompareColoring(compareframe.OrigText)
      DisableCompareColoring(compareframe.NewText)
      compareframe:Hide()
      GSE.PerformMergeAction(
        compareframe.ChosenAction,
        compareframe.classid,
        compareframe.sequenceName,
        compareframe.NewSequence
      )
    end
  )

  actionButtonGroup:AddChild(actionbutton)
  compareframe:AddChild(actionButtonGroup)

  compareframe.NewSequence = newsequence

  GSE.EnsureSequenceLoaded(classid, sequenceName)
  if newsequence.MetaData.DisableEditor or GSE.Library[classid][sequenceName].MetaData.DisableEditor then
    GSE.PerformMergeAction("REPLACE", classid, sequenceName, newsequence)
  else
    actionChoiceRadio:SetList(
      {
        ["MERGE"] = L["Merge"],
        ["REPLACE"] = L["Replace"],
        ["IGNORE"] = L["Ignore"],
        ["RENAME"] = L["Rename New Macro"]
      }
    )
    compareframe.OrigText:SetText(GSE.ExportSequence(GSE.Library[classid][sequenceName], sequenceName, true))
    compareframe.NewText:SetText(GSE.ExportSequence(newsequence, sequenceName, true))
    compareframe:Show()
    if compareframe.frame and GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(compareframe.frame) end
    compareframe.sequenceName = sequenceName
  end
end
end
table.insert(ns.deferred, setup)

local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local LibQTip = LibStub("LibQTip-1.0")

--- This function pops up a confirmation dialog.
function GSE.GUIDeleteSequence(classid, sequenceName)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].text =
    string.format(
    L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."],
    sequenceName
  )
  StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
    GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  end

  StaticPopup_Show("GSE-DeleteMacroDialog")
end

--- This function then deletes the macro.
function GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  GSE.DeleteSequence(classid, sequenceName)
  GSE.ShowSequences()
end

--- Format the text against the GSE Sequence Spec.
function GSE.GUIParseText(editbox)
  if GSEOptions.RealtimeParse then
    local text = GSE.UnEscapeString(editbox:GetText())
    local returntext = GSE.TranslateString(text, "STRING", true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext) + 2)
  end
end

function GSE.GUILoadEditor(key, recordedstring)
  local classid
  local sequenceName
  local sequence
  if GSE.isEmpty(key) then
    classid = GSE.GetCurrentClassID()
    sequenceName = "NEW_SEQUENCE"
    sequence = {
      ["MetaData"] = {
        ["Author"] = GSE.GetCharacterName(),
        ["Talents"] = GSE.GetCurrentTalents(),
        ["Default"] = 1,
        ["SpecID"] = GSE.GetCurrentSpecID(),
        ["GSEVersion"] = GSE.VersionString,
        ["Name"] = sequenceName
      },
      ["Macros"] = {
        [1] = {
          ["Actions"] = {
            [1] = {
              ["macro"] = "Need Macro Here",
              ["Type"] = Statics.Actions.Action
            }
          }
        }
      }
    }
    if not GSE.isEmpty(recordedstring) then
      sequence.Macros[1]["Actions"] = nil
      local recordedMacro = {}
      for _, v in ipairs(GSE.SplitMeIntoLines(recordedstring)) do
        print(v)
        local spellid = GSE.TranslateString(v, Statics.TranslatorMode.ID)
        if spellid then
          local action = {
            ["Type"] = Statics.Actions.Action,
            ["type"] = "macro",
            ["macro"] = spellid
          }
          table.insert(recordedMacro, action)
        end
      end
      sequence.Macros[1]["Actions"] = recordedMacro
    end
    GSE.GUIEditFrame.NewSequence = true
  else
    local elements = GSE.split(key, ",")
    classid = tonumber(elements[1])
    sequenceName = elements[3]
    --sequence = GSE.CloneSequence(GSE.Library[classid][sequenceName], true)
    local _, seq = GSE.DecodeMessage(GSESequences[classid][sequenceName])
    if seq then
      sequence = seq[2]
      GSE.GUIEditFrame.NewSequence = false
    end
  end
  if GSE.isEmpty(sequence.WeakAuras) then
    sequence.WeakAuras = {}
  end
  GSE.GUIEditFrame:SetStatusText("GSE: " .. GSE.VersionString)
  GSE.GUIEditFrame.SequenceName = sequenceName
  GSE.GUIEditFrame.Sequence = sequence
  GSE.GUIEditFrame.ClassID = classid
  GSE.GUIEditorPerformLayout()
  GSE.GUIEditFrame.ContentContainer:SelectTab("config")
  if sequence.ReadOnly then
    GSE.GUIEditFrame.SaveButton:SetDisabled(true)
    GSE.GUIEditFrame:SetStatusText(
      "GSE: " .. GSE.VersionString .. " " .. L["This sequence is Read Only and unable to be edited."]
    )
  end
  GSE.GUIEditFrame:Show()
end

function GSE:OnInitialize()
  GSE.GUIRecordFrame:Hide()
  GSE.GUIVersionFrame:Hide()
  GSE.GUIEditFrame:Hide()
end

function GSE.OpenOptionsPanel()
  Settings.OpenToCategory("|cFFFFFFFFGS|r|cFF00FFFFE|r")
end

function GSE.CreateToolTip(title, tip, GSEFrame)
  GSE.ClearTooltip(GSEFrame)
  local tooltip = LibQTip:Acquire("GSE", 1, "CENTER")

  GSEFrame.tooltip = tooltip
  tooltip:AddHeader(GSEOptions.TitleColour .. title .. Statics.StringReset)
  tooltip:AddLine(tip)
  tooltip:SmartAnchorTo(GSEFrame.frame)

  tooltip:Show()
end

function GSE.ClearTooltip(GSEFrame)
  LibQTip:Release(GSEFrame.tooltip)
  GSEFrame.tooltip = nil
end

function GSE.ShowSequenceList(SequenceTable, GSEUser, channel)
  if GSE.UnsavedOptions["GUI"] then
    GSE.ShowRemoteWindow(SequenceTable, GSEUser, channel)
  else
    for _, v in ipairs(SequenceTable) do
      for i, j in pairs(v) do
        local msg = i .. " "
        if not GSE.isEmpty(j.Help) then
          msg = msg .. j.Help
        end
        GSE.Print(msg, "TRANSMISSION")
      end
    end
  end
end

function GSE.GUIShowSpellCacheWindow()
  GSE.GUICacheFrame:Show()
end

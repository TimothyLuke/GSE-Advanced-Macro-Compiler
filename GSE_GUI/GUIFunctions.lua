local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local LibQTip = LibStub("LibQTip-1.0")

--- Format the text against the GSE Sequence Spec.
function GSE.GUIParseText(editbox)
  if GSEOptions.RealtimeParse then
    local text = GSE.UnEscapeString(editbox:GetText())
    local returntext = GSE.TranslateString(text, "STRING", true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext) + 2)
  end
end

function GSE:OnInitialize()
  GSE.GUIRecordFrame:Hide()
  GSE.GUIVersionFrame:Hide()
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

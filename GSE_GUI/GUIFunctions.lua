local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local LibQTip = LibStub("LibQTip-2.0")

local function AnchorTooltipToCursor(tooltip)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()

  tooltip:ClearAllPoints()
  tooltip:SetClampedToScreen(true)
  tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 16, (y / scale) - 16)
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

function GSE:OnInitialize()
  GSE.GUIRecordFrame:Hide()
  GSE.GUIVersionFrame:Hide()
end

function GSE.OpenOptionsPanel(editor)
  if GSE.OpenRegisteredOptionsPanel then
    return GSE.OpenRegisteredOptionsPanel(editor)
  end
end

function GSE.CreateToolTip(title, tip, GSEFrame)
  GSE.ClearTooltip(GSEFrame)
  local tooltip = LibQTip:AcquireTooltip("GSE", 1, "CENTER")

  GSEFrame.tooltip = tooltip
  tooltip:AddHeadingRow(GSEOptions.TitleColour .. title .. Statics.StringReset)
  tooltip:AddRow(tip)
  AnchorTooltipToCursor(tooltip)
  tooltip:SetScript("OnUpdate", AnchorTooltipToCursor)

  tooltip:Show()
end

function GSE.ClearTooltip(GSEFrame)
  if GSEFrame.tooltip then
    GSEFrame.tooltip:SetScript("OnUpdate", nil)
    GSEFrame.tooltip:Release()
  end
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
  if not GSE.GUICacheFrame then
    GSE.Print(L["The GSE_GUI Module needs to be enabled to edit the spell cache."], L["Options"])
    return
  end

  local frame = GSE.GUICacheFrame.frame
  if frame then
    -- Conditional center: only anchor the frame if it has no points yet, so
    -- a user's saved drag position isn't clobbered every time the cache
    -- window is reopened.
    local needsCenter = frame.GetNumPoints and frame:GetNumPoints() == 0
    GSE.UI.MakePopup(frame, {center = needsCenter})
  end

  GSE.GUICacheFrame:Show()
  if frame and frame.Raise then frame:Raise() end
end

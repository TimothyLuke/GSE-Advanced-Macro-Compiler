local GSE = GSE

local Statics = GSE.Static

local L = GSE.L
function GSE.GUIShowCompiledMacroGui(spelllist, title, editframe)
  local AceGUI = LibStub("AceGUI-3.0")

  local PreviewFrame = AceGUI:Create("Frame")
  PreviewFrame.frame:SetFrameStrata("MEDIUM")

  PreviewFrame.frame:SetClampedToScreen(true)
  PreviewFrame:SetTitle(L["Compiled Template"])
  PreviewFrame:SetCallback(
    "OnClose",
    function(widget)
      PreviewFrame:Hide()
    end
  )
  PreviewFrame:SetLayout("List")
  PreviewFrame.frame:SetClampRectInsets(-10, -10, -10, -10)
  PreviewFrame:SetWidth(280)
  PreviewFrame:SetHeight(700)
  PreviewFrame:Hide()

  local PreviewLabel = AceGUI:Create("MultiLineEditBox")
  PreviewLabel:SetWidth(270)
  PreviewLabel:SetNumLines(40)
  PreviewLabel:DisableButton(true)

  PreviewFrame.PreviewLabel = PreviewLabel
  PreviewFrame:AddChild(PreviewLabel)

  IndentationLib.enable(PreviewLabel.editBox, Statics.IndentationColorTable, 4)

  PreviewFrame.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
      PreviewLabel:SetWidth(width - 30)
      PreviewLabel:SetHeight(height - 80)
    end
  )

  PreviewFrame.text = IndentationLib.encode(GSE.Dump(spelllist))

  local count = #spelllist
  PreviewLabel:SetLabel(L["Compiled"] .. " " .. count .. " " .. L["Actions"])
  if editframe:IsVisible() then
    local point, relativeTo, relativePoint, xOfs, yOfs = editframe:GetPoint()
    PreviewFrame:ClearAllPoints()
    PreviewFrame:SetPoint("TOPLEFT", editframe.frame, editframe.Width + 10, 0)
  end

  if not GSE.isEmpty(spelllist) then
    PreviewLabel:SetText(PreviewFrame.text)
  end
  -- PreviewLabel:SetCallback(
  --   "OnTextChanged",
  --   function()
  --     PreviewLabel:SetText(PreviewFrame.text)
  --   end
  -- )
  PreviewFrame:SetStatusText(title)
  PreviewFrame:Show()
end

local GSE = GSE

local Statics = GSE.Static

local L = GSE.L

local AceGUI = LibStub("AceGUI-3.0")

if GSE.isEmpty(GSEOptions.editorWidth) then
	GSEOptions.editorWidth = 700
end
if GSE.isEmpty(GSEOptions.menuWidth) then
	GSEOptions.menuWidth = 700
end

local PreviewFrame = AceGUI:Create("Frame")
GSE.MacroPreviewFrame = PreviewFrame

PreviewFrame:SetTitle(L["Compiled Template"])
PreviewFrame:SetCallback("OnClose", function(widget) PreviewFrame:Hide() end)
PreviewFrame:SetLayout("List")
PreviewFrame:SetWidth(290)
PreviewFrame:SetHeight(700)
PreviewFrame:Hide()


local PreviewLabel = AceGUI:Create("MultiLineEditBox")
PreviewLabel:SetWidth(270)
PreviewLabel:SetNumLines(40)
PreviewLabel:DisableButton(true)

PreviewFrame.PreviewLabel = PreviewLabel
PreviewFrame:AddChild(PreviewLabel)


PreviewFrame.frame:SetScript("OnSizeChanged", function(self, width, height)
    PreviewLabel:SetWidth(width - 20)
end)


function GSE.GUIShowCompiledMacroGui(label, title)
  PreviewFrame.text = GSE.ConcatIndexed(label, GSEOptions.AuthorColour .. "Step %d" .. Statics.StringReset .."\n%s\n--------------------------------------\n")
  local count = #label
  PreviewLabel:SetLabel(L["Compiled"] .. " " .. count .. " " .. L["Actions"])
  if GSE.GUIViewFrame:IsVisible() then
    local point, relativeTo, relativePoint, xOfs, yOfs = GSE.GUIViewFrame:GetPoint()
    PreviewFrame:ClearAllPoints()
    PreviewFrame:SetPoint(point, xOfs + 150 + (GSEOptions.menuWidth / 2), yOfs)
  end
  if GSE.GUIEditFrame:IsVisible() then
    local point, relativeTo, relativePoint, xOfs, yOfs = GSE.GUIEditFrame:GetPoint()
    PreviewFrame:ClearAllPoints()
    PreviewFrame:SetPoint(point, xOfs + 150 + (GSEOptions.editorWidth / 2), yOfs)
  end

  if not GSE.isEmpty(label) then
    PreviewLabel:SetText(PreviewFrame.text)
  end
  PreviewLabel:SetCallback("OnTextChanged", function()
    PreviewLabel:SetText(PreviewFrame.text)
  end)
  PreviewFrame:Show()
  PreviewFrame:SetStatusText(title)
end




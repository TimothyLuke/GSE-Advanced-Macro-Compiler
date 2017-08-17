local GSE = GSE

local Statics = GSE.Static

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject(L["GSE"] .." ".. L["GnomeSequencer-Enhanced"], {type = "data source", text = "/gse"})
local LibQTip = LibStub('LibQTip-1.0')
local LibSharedMedia = LibStub('LibSharedMedia-3.0')

local baseFont = CreateFont("baseFont")

-- CHeck for ElvUI
if GSE.isEmpty(ElvUI) then
  baseFont:SetFont(GameTooltipText:GetFont(), 10)
elseif LibSharedMedia:IsValid('font', ElvUI[1].db.general.font) then
  baseFont:SetFont(LibSharedMedia:Fetch('font', ElvUI[1].db.general.font), 10)
else
  baseFont:SetFont(GameTooltipText:GetFont(), 10)
end

function dataobj:OnEnter()
  -- Acquire a tooltip with 3 columns, respectively aligned to left, center and right
  --local tooltip = LibQTip:Acquire("GSSE", 3, "LEFT", "CENTER", "RIGHT")
  local tooltip = LibQTip:Acquire("GSSE", 3, "LEFT", "CENTER", "RIGHT")
  tooltip:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
  self.tooltip = tooltip

  tooltip:Clear()
  tooltip:SetFont(baseFont)
  --tooltip:SetHeaderFont(red17font)
  local y,x = tooltip:AddLine()
  tooltip:SetCell(y, 1, L["GSE: Left Click to open the Sequence Editor"],"CENTER", 3)
  y,x = tooltip:AddLine()
  tooltip:SetCell(y, 1, L["GSE: Middle Click to open the Transmission Interface"],"CENTER", 3)
  y,x = tooltip:AddLine()
  tooltip:SetCell(y, 1, L["GSE: Right Click to open the Sequence Debugger"],"CENTER", 3)

  -- If in party add other users and their versions
  if not GSE.isEmpty(GSE.UnsavedOptions["PartyUsers"]) and GSEOptions.showGSEUsers then
    tooltip:AddSeparator()
    y,x = tooltip:AddLine()
    tooltip:SetCell(L["GSE Users"],"CENTER", 3)
    for k,v in pairs(GSE.UnsavedOptions["PartyUsers"]) do
      tooltip:AddLine(k, nil, v)
    end
  end


  -- Show GSE OOCQueue Information
  if GSEOptions.showGSEoocqueue then
    tooltip:AddSeparator()
    y,x = tooltip:AddLine()
    tooltip:SetCell(y, 1, string.format(L["There GSE Out of Combat queue is %s"], GSE.CheckOOCQueueStatus()),"CENTER", 3)
    tooltip:SetLineScript(y, "OnMouseUp", GSE.ToggleOOCQueue())
    tooltip:AddSeparator()
    y,x = tooltip:AddLine()
    if table.getn(GSE.OOCQueue) > 0 then
      tooltip:SetCell(y, 1, string.format(L["There are %i events in out of combat queue"], table.getn(GSE.OOCQueue)),"CENTER", 3)
      for k,v in ipairs(GSE.OOCQueue) do
        y,x = tooltip:AddLine()
        GSE.prepareTooltipOOCLine(tooltip, v, y, k)
      end
    else
      -- No Items
      tooltip:SetCell(y, 1, string.format(L["There are no events in out of combat queue"]),"CENTER", 3)
    end
  end

  tooltip:AddSeparator()
  y,x = tooltip:AddLine()
  tooltip:SetCell(y, 1, string.format(L["GSE Version: %s"], GSE.formatModVersion(GSE.VersionString)),"CENTER", 3)
  -- Use smart anchoring code to anchor the tooltip to our frame
  tooltip:SmartAnchorTo(self)


  -- Show it, et voil� !
  tooltip:Show()
end

function dataobj:OnLeave()
  -- Release the tooltip
  LibQTip:Release(self.tooltip)
  self.tooltip = nil
end

-- function dataobj:OnTooltipShow()
--
-- end

function dataobj:OnClick(button)
  if button == "LeftButton" then
    GSE.GUIShowViewer()
  elseif button == "MiddleButton" then
    GSE.GUIShowTransmissionGui()
  elseif button == "RightButton" then
    GSE.GUIShowDebugWindow()
  end
end

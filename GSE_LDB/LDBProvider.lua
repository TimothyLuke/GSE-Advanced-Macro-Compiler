local GSE = GSE

local Statics = GSE.Static
local L = GSE.L

local iconSource = Statics.Icons.GSE_Logo_Dark

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

local function handleLeave(self)
  -- Dont close the tooltip if mouseover
  if self.tooltip and not self.tooltip:IsMouseOver() then
    self.tooltip:Release()
    self.tooltip = nil
  end
  return true
end


local function dataObject_OnLeave(self)
  -- this may throw an error - capture the error silently
  pcall(handleLeave, self)
end


local dataobj =
  ldb:NewDataObject(
  L["GSE"] .. " " .. L["Gnome Sequencer Enhanced"],
  {
    type = "data source",
    text = "GSE",
    icon = iconSource,
    OnLeave = dataObject_OnLeave
  }
)
local LibQTip = LibStub("LibQTip-2.0")
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

local icon = LibStub("LibDBIcon-1.0")
icon:Register(L["GSE"] .. " " .. L["Gnome Sequencer Enhanced"], dataobj, GSEOptions.showMiniMap)

local LibDBCompartment = LibStub:GetLibrary("LibDBCompartment-1.0")
LibDBCompartment:Register(L["GSE"], dataobj)
local baseFont = CreateFont("baseFont")

-- Check for ElvUI
if GSE.isEmpty(ElvUI) then
  baseFont:SetFont(GameTooltipText:GetFont(), 10, "")
elseif LibSharedMedia:IsValid("font", ElvUI[1].db.general.font) then
  baseFont:SetFont(LibSharedMedia:Fetch("font", ElvUI[1].db.general.font), 10, "")
else
  baseFont:SetFont(GameTooltipText:GetFont(), 10, "")
end

local function CheckOOCQueueStatus()
  local output
  if GSE.isEmpty(GSE.OOCTimer) then
    output = GSEOptions.UNKNOWN .. L["Paused"] .. Statics.StringReset
  else
    if InCombatLockdown() then
      output = GSEOptions.TitleColour .. L["Paused - In Combat"] .. Statics.StringReset
    else
      output = GSEOptions.CommandColour .. L["Running"] .. Statics.StringReset
    end
  end
  return output
end

local function prepareTooltipOOCLine(row, OOCEvent, oockey)
  local x = row:GetCell(1)
  x:SetText(OOCEvent.action)
  x:SetJustifyH("LEFT")
  if OOCEvent.action == "UpdateSequence" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.name)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "Save" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.sequencename)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "Replace" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.sequencename)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "CheckMacroCreated" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.sequencename)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "updatemacro" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.node.name)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "updatevariable" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.name)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "importmacro" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.node.name)
    x:SetJustifyH("RIGHT")
  elseif OOCEvent.action == "MergeSequence" then
    x = row:GetCell(3)
    x:SetText(OOCEvent.sequencename)
    x:SetJustifyH("RIGHT")
  end
  row:SetScript(
    "OnMouseDown",
    function()
      table.remove(GSE.OOCQueue, oockey)
    end
  )
end

function dataobj:OnEnter()
  -- Acquire a tooltip with 3 columns, respectively aligned to left, center and right
  --local tooltip = LibQTip:Acquire("GSSE", 3, "LEFT", "CENTER", "RIGHT")
  local tooltip = LibQTip:AcquireTooltip("GSE", 3, "LEFT", "CENTER", "RIGHT")
  self.tooltip = tooltip
  tooltip:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
  tooltip:EnableMouse(true)
  tooltip:SmartAnchorTo(self)
  tooltip.OnRelease = handleLeave
  tooltip:SetAutoHideDelay(1, self)
  tooltip:Clear()
  tooltip:SetDefaultFont(baseFont)
  --tooltip:SetHeaderFont(red17font)
  local y = tooltip:AddRow()
  local x = y:GetCell(1)
  x:SetColSpan(3)
  x:SetText(L["GSE: Left Click to open the Sequence Editor"])
  x:SetJustifyH("CENTER")

  y = tooltip:AddRow()
  x = y:GetCell(1)
  x:SetColSpan(3)
  x:SetText(L["GSE: Middle Click to open the Keybinding Interface"])
  x:SetJustifyH("CENTER")

  y = tooltip:AddRow()
  x = y:GetCell(1)
  x:SetColSpan(3)
  x:SetText(L["GSE: Right Click to open the Sequence Debugger"])
  x:SetJustifyH("CENTER")

  -- If in party, add other users and their versions
  if not GSE.isEmpty(GSE.UnsavedOptions["PartyUsers"]) and GSEOptions.showGSEUsers then
    tooltip:AddSeparator()
    y = tooltip:AddHeadingRow()
    x = y:GetCell(1)
    x:SetColSpan(3)
    x:SetText(L["GSE Users"])
    x:SetJustifyH("CENTER")

    for k, v in pairs(GSE.UnsavedOptions["PartyUsers"]) do
      local userline = tooltip:AddRow(k, nil, v)
      userline:SetScript("OnMouseDown",
        function(obj, button)
          GSE.RequestSequenceList(k)
        end
      )
    end
  end

  tooltip:AddSeparator()
  y = tooltip:AddRow()
  x = y:GetCell(1)
  x:SetColSpan(3)
  x:SetFormattedText("GCD: %ss", GSE.GetGCD())
  x:SetJustifyH("CENTER")
  
  -- Show GSE OOCQueue Information
  if GSEOptions.showGSEoocqueue then
    tooltip:AddSeparator()
    local OOCLine = tooltip:AddRow()
    local OOCx = OOCLine:GetCell(1)
    OOCx:SetColSpan(3)
    OOCx:SetFormattedText(L["The GSE Out of Combat queue is %s"], CheckOOCQueueStatus())
    OOCx:SetJustifyH("CENTER")
    OOCLine:SetScript(
      "OnMouseDown",
      function(obj, button)
        GSE.ToggleOOCQueue()
        OOCx:SetFormattedText(L["The GSE Out of Combat queue is %s"], CheckOOCQueueStatus())
      end
    )
    tooltip:AddSeparator()
    y = tooltip:AddRow()
    if #GSE.OOCQueue > 0 then
      x = y:GetCell(1)
      x:SetColSpan(3)
      x:SetFormattedText(L["There are %i events in out of combat queue"], #GSE.OOCQueue)
      x:SetJustifyH("CENTER")
      y:SetScript(
        "OnMouseDown",
        function()
          GSE.OOCQueue = {}
        end
      )
      for k, v in ipairs(GSE.OOCQueue) do
        y = tooltip:AddRow()
        prepareTooltipOOCLine(y, v, k)
      end
    else
      -- No Items
      x = y:GetCell(1)
      x:SetColSpan(3)
      x:SetText(L["There are no events in out of combat queue"])
      x:SetJustifyH("CENTER")
    end
  end

  tooltip:AddSeparator()
  y, _ = tooltip:AddRow()
  x = y:GetCell(1)
  x:SetColSpan(3)
  x:SetFormattedText(L["GSE Version: %s"], GSE.VersionString)
  x:SetJustifyH("CENTER")

    -- Use smart anchoring code to anchor the tooltip to our frame
  tooltip:SmartAnchorTo(self)

  -- Show it, et voil� !
  tooltip:Show()

end


function dataobj:OnLeave()
  dataObject_OnLeave(self)
end


function dataobj:OnClick(button)
  if GSE.CheckGUI() then
    if button == "LeftButton" then
      GSE.ShowSequences()
    elseif button == "MiddleButton" then
      GSE.ShowKeyBindings()
    elseif button == "RightButton" then
      GSE.GUIShowDebugWindow()
    end
  end
end


function GSE.miniMapShow()
  icon:Show(L["GSE"] .. " " .. L["Gnome Sequencer Enhanced"])
end

function GSE.miniMapHide()
  icon:Hide(L["GSE"] .. " " .. L["Gnome Sequencer Enhanced"])
end

--- This shows or hides the minimap icon.
function GSE.MiniMapControl(show)
  -- print(show)
  if show then
    GSE.miniMapHide()
  else
    GSE.miniMapShow()
  end
end

-- GSE.MiniMapControl(GSEOptions.showMiniMap.hide)

local GCDLDB =
  ldb:NewDataObject(
  L["GSE"] .. ": " .. L["Current GCD"],
  {
    type = "data source",
    text = string.format("GCD: %ss", GSE.GetGCD()),
    icon = iconSource,
    value = GSE.GetGCD(),
    suffix = "s"
  }
)

GSE.GCDLDB = GCDLDB

GSE.LDB = true

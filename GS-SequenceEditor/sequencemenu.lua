local GNOME,_ = ...

local L = GSL
local AceGUI = LibStub("AceGUI-3.0")
-- local LAB = LibStub("LibActionButton-1.0")
-- local SecureHeader = CreateFrame("Frame", "GSSEButtonSecureHeader", UIParent, "SecureHandlerStateTemplate")
-- RegisterStateDriver(SecureHeader, "page", "[mod:alt]2;1")
-- SecureHeader:SetAttribute("_onstate-page", [[
--     self:SetAttribute("state", newstate)
--     control:ChildUpdate("state", newstate)
-- ]])
--
-- local buttonIndex = 0
--
-- local function CreateMenuItem(SequenceName)
--   buttonIndex = buttonIndex + 1
--   local button = LAB:CreateButton(1, "RBButton"..buttonIndex, SecureHeader)
--   button:DisableDragNDrop(true)
--
--   button:SetState(1, "macro" ,'#showtooltip\n/click ' .. SequenceName)
--   button:SetState(2, "macro" ,'#showtooltip\n/click ' .. SequenceName)
--   button:SetMovable(true)
--   button:SetClampedToScreen(true)
-- 	button:SetScript("OnDragStart", function(self) if self:IsMovable() and IsAltKeyDown() then self.isMoving = true; self:StartMoving(); end end)
-- 	button:SetScript("OnDragStop",  function(self) if self:IsMovable() and self.isMoving == true then self:StopMovingOrSizing(); self:SavePosition() end end )
--   button:SetAttribute('macro','#showtooltip\n/click ' .. SequenceName)
--   button:SetPoint("CENTER", UIParent)
--   button:SetNormalTexture("Interface\\icons\\INV_MISC_QUESTIONMARK")
--   button:Show()
--
-- end
--
--
-- CreateMenuItem("DB_Ret")
newFrame = AceGUI:Create("Frame")
newFrame:SetTitle(L["Sequence Debugger"])
newFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"])
newFrame:SetCallback("OnClose", function(widget) GSDebugFrame:Hide()  end)
newFrame:SetLayout("List")

ActionButton = AceGUI:Create("ActionSlot")
ActionButton:SetText("macro:DB_Ret")
newFrame:AddChild(ActionButton)
newFrame:Show()

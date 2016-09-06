local GSSE = GSSE
local GNOME = GSStaticSourceTransmission
local GSStaticPrefix = "GS-E"
local GSEVersion = GetAddOnMetadata("GS-Core", "Version")
local GSold = false
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")

GSPrintDebugMessage("GS-Core Version " .. GSEVersion, GNOME)

StaticPopupDialogs['GSE_UPDATE_AVAILABLE'] = {
	text = L["GS-E is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."],
	hasEditBox = 1,
	OnShow = function(self)
		self.editBox:SetAutoFocus(false)
		self.editBox.width = self.editBox:GetWidth()
		self.editBox:Width(220)
		self.editBox:SetText("https://mods.curse.com/addons/wow/gnomesequencer-enhanced")
		self.editBox:HighlightText()
		ChatEdit_FocusActiveWindow();
	end,
	OnHide = function(self)
		self.editBox:Width(self.editBox.width or 50)
		self.editBox.width = nil
	end,
	hideOnEscape = 1,
	button1 = OKAY,
	EditBoxOnEnterPressed = function(self)
		ChatEdit_FocusActiveWindow();
		self:GetParent():Hide();
	end,
	EditBoxOnEscapePressed = function(self)
		ChatEdit_FocusActiveWindow();
		self:GetParent():Hide();
	end,
	EditBoxOnTextChanged = function(self)
		if(self:GetText() ~= "https://mods.curse.com/addons/wow/gnomesequencer-enhanced") then
			self:SetText("https://mods.curse.com/addons/wow/gnomesequencer-enhanced")
		end
		self:HighlightText()
		self:ClearFocus()
		ChatEdit_FocusActiveWindow();
	end,
	OnEditFocusGained = function(self)
		self:HighlightText()
	end,
	showAlert = 1,
}

local function performVersionCheck(version)
	if(tonumber(version) ~= nil and tonumber(version) > tonumber(GSEVersion)) then
		if not GSold then
		  GSPrint(L["GS-E is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."], GSStaticSourceTransmission)
		  GSold = true
		  if((tonumber(message) - tonumber(version)) >= 0.05) then
			  StaticPopup_Show('GSE_UPDATE_AVAILABLE')
		  end
		end
	end

end

function GSSE:OnCommReceived(prefix, message, distribution, sender)
  GSPrintDebugMessage("GSSE:onCommReceived", GNOME)
  GSPrintDebugMessage(prefix .. " " .. message .. " " .. distribution .. " " .. sender, GNOME)
  local t = GSSE:Deserialize(message)
  if t.Command == "GS-E_VERSIONCHK" then
    if not GSold then
			performVersionCheck(t.Version)
		end
  end
end



local function sendVersionCheck()
  if not GSold then
		local _, instanceType = IsInInstance()
	  local t = {}
	  t.Command = "GS-E_VERSIONCHK"
	  t.Version = GSEVersion
	  transmission = GSSE:Serialize(t)
		if IsInRaid() then
			SendAddonMessage(GSStaticPrefix, transmission, (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID")
		elseif IsInGroup() then
			SendAddonMessage(GSStaticPrefix, transmission, (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY")
		end
	end
end

function GSSE:GROUP_ROSTER_UPDATE(...)
	sendVersionCheck()
end


GSSE:RegisterComm("GS-E")
GSSE:RegisterEvent("GROUP_ROSTER_UPDATE")

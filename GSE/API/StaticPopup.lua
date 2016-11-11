local GSE = GSE
local L = GSE.L


StaticPopupDialogs["GSE_ConfirmReloadUIDialog"] = {
  text = L["You need to reload the User Interface to complete this task.  Would you like to do this now?"],
  button1 = L["Yes"],
  button2 = L["No"],
  OnAccept = function()
      ReloadUI();
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

StaticPopupDialogs["GS-DebugOutput"] = {
  text = L["Dump of GS Debug messages"],
  button1 = L["Update"],
  button2 = L["Close"],
  OnAccept = function(self, data)
      self.editBox:SetText(GSE.DebugOutput)
  end,
	OnShow = function (self, data)
    self.editBox:SetText(GSE.DebugOutput)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	hasEditBox = true,
}

StaticPopupDialogs['GSE_UPDATE_AVAILABLE'] = {
	text = L["GSE is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."],
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


StaticPopupDialogs["GSE-SampleMacroDialog"] = {
  text = L["There are No Macros Loaded for this class.  Would you like to load the Sample Macro?"],
  button1 = L["Load"],
  button2 = L["Close"],
  OnAccept = function(self, data)
      GSE.LoadSampleMacros(GSE.GetCurrentClassID())
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

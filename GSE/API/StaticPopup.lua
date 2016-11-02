local GSE = GSE
local L = GSE.L


StaticPopupDialogs["GSEConfirmReloadUI"] = {
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
      self.editBox:SetText(GSDebugOutput)
  end,
	OnShow = function (self, data)
    self.editBox:SetText(GSDebugOutput)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	hasEditBox = true,
}

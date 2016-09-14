local GSSE = GSSE
local GNOME = GSStaticSourceTransmission
local GSStaticPrefix = "GS-E"
local GSEVersion = GetAddOnMetadata("GS-Core", "Version")
local GSold = false
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")

local transauthor = GetUnitName("player", true) .. '@' .. GetRealmName()
local transauthorlen = string.len(transauthor)

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

local function sendMessage(tab, channel)
  local _, instanceType = IsInInstance()
	local transmission = GSSE:Serialize(tab)
	if GSisEmpty(channel) then
		if IsInRaid() then
			channel = (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID"
		elseif
		  channel = (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
		end
  end
	SendAddonMessage(GSStaticPrefix, transmission, channel)

end


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

function GSEncodeSequence(Sequence)
  --clean sequence
  eSequence = GSTRUnEscapeSequence(Sequence)
  --remove version and source
  eSequence.version = nil
  eSequence.source = GSStaticSourceTransmission
  eSequence.authorversion = nil


  local one = libS:Serialize(eSequence)
  local two = libC:CompressHuffman(one)
  local final = libCE:Encode(two)
  return final
end

function GSDecodeSequence(data)
  -- Decode the compressed data
  local one = libCE:Decode(data)

  --Decompress the decoded data
  local two, message = libC:Decompress(one)
  if(not two) then
  	GSPrintDebugMessage ("YourAddon: error decompressing: " .. message, "GS-Transmission")
  	return
  end

  -- Deserialize the decompressed data
  local success, final = libS:Deserialize(two)
  if (not success) then
  	GSPrintDebugMessage ("YourAddon: error deserializing " .. final, "GS-Transmission")
  	return
  end

  GSPrintDebugMessage ("final data: " .. final, "GS-Transmission")
  return final
end

function GSTransmitSequence(SequenceName, channel)
  local t = {}
	t.Command = "GS-E_TRANSMITSEQUENCE"
	t.SequenceName = SequenceName
	t.Sequence = GSEncodeSequence(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)])
	SendMessage(t, channel)
end

local function ReceiveSequence(SequenceName, Sequence)
  local sequence = GSDecodeSequence(Sequence)
  local version = GSGetNextSequenceVersion(SequenceName)
	sequence.version = version
	GSAddSequenceToCollection(SequenceName, sequence, version)
end


function GSSE:OnCommReceived(prefix, message, distribution, sender)
  GSPrintDebugMessage("GSSE:onCommReceived", GNOME)
  GSPrintDebugMessage(prefix .. " " .. message .. " " .. distribution .. " " .. sender, GNOME)
  local success, t = GSSE:Deserialize(message)
  if success then
		if t.Command == "GS-E_VERSIONCHK" then
	    if not GSold then
				performVersionCheck(t.Version)
			end
	  elseif t.Command == "GS-E_TRANSMITSEQUENCE" then
      if sender ~= GetUnitName("player", true) then
        ReceiveSequence(t.SequenceName, t.Sequence)
			else
        GSPrintDebugMessage("Ignoring Sequence from me.", GNOME)
			end
    end
	end
end


local function sendVersionCheck()
  if not GSold then
		local _, instanceType = IsInInstance()
	  local t = {}
	  t.Command = "GS-E_VERSIONCHK"
	  t.Version = GSEVersion
	  SendMessage(t)
	end
end

function GSSE:GROUP_ROSTER_UPDATE(...)
	sendVersionCheck()
end


GSSE:RegisterComm("GS-E")
GSSE:RegisterEvent("GROUP_ROSTER_UPDATE")

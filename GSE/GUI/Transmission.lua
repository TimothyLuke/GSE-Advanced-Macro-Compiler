local GSE = GSE

local Statics = GSE.Static


local GNOME = GSStaticSourceTransmission
local GSStaticPrefix = "GS-E"

local GSold = false
local L = GSE.L
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local AceGUI = LibStub("AceGUI-3.0")
local Completing = LibStub("AceGUI-3.0-Completing-EditBox")
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()
local LibQTip = LibStub('LibQTip-1.0')
local LibSharedMedia = LibStub('LibSharedMedia-3.0')

local dataobj = ldb:NewDataObject(L["GnomeSequencer-Enhanced"], {type = "data source", text = "/gse"})

local transauthor = GetUnitName("player", true) .. '@' .. GetRealmName()
local transauthorlen = string.len(transauthor)

Completing:Register ("ExampleAll", AUTOCOMPLETE_LIST.WHISPER)


GSE.PrintDebugMessage("GS-Core Version " .. GSE.VersionString, GNOME)


local function GSSendMessage(tab, channel, target)
  local _, instanceType = IsInInstance()
  local transmission = GSEncodeMessage(tab)
  GSE.PrintDebugMessage(transmission, GNOME)
  if GSE.isEmpty(channel) then
  if IsInRaid() then
  channel = (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID"
  else
    channel = (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
  end
  end
  GSE:SendCommMessage(GSStaticPrefix, transmission, channel, target)

end

local function performVersionCheck(version)
  if(tonumber(version) ~= nil and tonumber(version) > tonumber(GSE.VersionString)) then
  if not GSold then
    GSE.Print(L["GS-E is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."], GSStaticSourceTransmission)
    GSold = true
    if((tonumber(message) - tonumber(version)) >= 5) then
    StaticPopup_Show('GSE_UPDATE_AVAILABLE')
    end
  end
  end
end

function GSE.EncodeMessage(Sequence)
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

function GSE.DecodeMessage(data)
  -- Decode the compressed data
  local one = libCE:Decode(data)

  --Decompress the decoded data
  local two, message = libC:Decompress(one)
  if(not two) then
  	GSE.PrintDebugMessage ("YourAddon: error decompressing: " .. message, "GS-Transmission")
  	return
  end

  -- Deserialize the decompressed data
  local success, final = libS:Deserialize(two)
  if (not success) then
  	GSE.PrintDebugMessage ("YourAddon: error deserializing " .. final, "GS-Transmission")
  	return
  end

  GSE.PrintDebugMessage ("Data Finalised", "GS-Transmission")
  return success, final
end

function GSE.TransmitSequence(SequenceName, channel, target)
  local t = {}
  t.Command = "GS-E_TRANSMITSEQUENCE"
  t.SequenceName = SequenceName
  t.Sequence = GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)]
  GSSendMessage(t, channel, target)
  GSE.GUI.TranmissionFrame:SetStatusText(SequenceName .. L[" sent"])
end

local function ReceiveSequence(SequenceName, Sequence, sender)
  local version = GSGetNextSequenceVersion(SequenceName)
  Sequence.version = version
  Sequence.source = GSStaticSourceTransmission
  GSAddSequenceToCollection(SequenceName, Sequence, version)
  GSE.Print(L["Received Sequence "] .. SequenceName .. L[" from "] .. sender ..  L[" saved as version "] .. version)
end


function GSE:OnCommReceived(prefix, message, distribution, sender)
  GSE.PrintDebugMessage("GSSE:onCommReceived", GNOME)
  GSE.PrintDebugMessage(prefix .. " " .. message .. " " .. distribution .. " " .. sender, GNOME)
  local success, t = GSDecodeMessage(message)
  if success then
  if t.Command == "GS-E_VERSIONCHK" then
      if not GSold then
  performVersionCheck(t.Version)
  end
    elseif t.Command == "GS-E_TRANSMITSEQUENCE" then
  if sender ~= GetUnitName("player", true) then
        ReceiveSequence(t.SequenceName, t.Sequence, sender)
  else
        GSE.PrintDebugMessage("Ignoring Sequence from me.", GNOME)
  end
    end
  end
end


local function sendVersionCheck()
  if not GSold then
  local _, instanceType = IsInInstance()
    local t = {}
    t.Command = "GS-E_VERSIONCHK"
    t.Version = GSE.VersionString
    GSSendMessage(t)
  end
end

function GSE:GROUP_ROSTER_UPDATE(...)
  sendVersionCheck()
end


GSE:RegisterComm("GS-E")
GSE:RegisterEvent("GROUP_ROSTER_UPDATE")
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
  local tooltip = LibQTip:Acquire("GSSE", 1,"CENTER")
  self.tooltip = tooltip

  tooltip:Clear()
  tooltip:SetFont(baseFont)
  --tooltip:SetHeaderFont(red17font)
  tooltip:AddLine(L["GS-E: Left Click to open the Sequence Editor"])
  tooltip:AddLine(L["GS-E: Middle Click to open the Transmission Interface"])
  tooltip:AddLine(L["GS-E: Right Click to open the Sequence Debugger"])

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
    GSGuiShowViewer()
  elseif button == "MiddleButton" then
    GSShowTransmissionGui()
  elseif button == "RightButton" then
    GSDebugFrame:Show()
  end
end

local transSequencevalue = ""

local tranmissionFrame = AceGUI:Create("Frame")
tranmissionFrame:SetTitle(L["Send To"])
tranmissionFrame:SetCallback("OnClose", function(widget) tranmissionFrame:Hide() end)
tranmissionFrame:SetLayout("List")
tranmissionFrame:SetWidth(290)
tranmissionFrame:SetHeight(190)
tranmissionFrame:Hide()
GSE.GUI.TranmissionFrame = transmissionframe

local SequenceListbox = AceGUI:Create("Dropdown")
SequenceListbox:SetLabel(L["Load Sequence"])
SequenceListbox:SetWidth(250)
SequenceListbox:SetCallback("OnValueChanged", function (obj,event,key) transSequencevalue = key end)
tranmissionFrame:AddChild(SequenceListbox)

local playereditbox = AceGUI:Create("EditBoxExampleAll")
playereditbox:SetLabel(L["Send To"])
playereditbox:SetWidth(250)
playereditbox:DisableButton(true)
tranmissionFrame:AddChild(playereditbox)

local sendbutton = AceGUI:Create("Button")
sendbutton:SetText(L["Send"])
sendbutton:SetWidth(250)
sendbutton:SetCallback("OnClick", function() GSTransmitSequence(transSequencevalue, "WHISPER", playereditbox:GetText()) end)
tranmissionFrame:AddChild(sendbutton)

function GSShowTransmissionGui(SequenceName)
  if GSE.GUI.ViewFrame:IsVisible() then
    local point, relativeTo, relativePoint, xOfs, yOfs = GSE.GUI.viewframe:GetPoint()
  --	GSE.GUI.TranmissionFrame:SetPoint("CENTRE" , (left/2)+(width/2), bottom )
  GSE.GUI.TranmissionFrame:SetPoint(point, xOfs + 500, yOfs + 155)

  end
  if GSE.GUI.EditFrame:IsVisible() then
  local point, relativeTo, relativePoint, xOfs, yOfs = GSE.GUI.EditFrame:GetPoint()
  --	GSE.GUI.TranmissionFrame:SetPoint("CENTRE" , (left/2)+(width/2), bottom )
  GSE.GUI.TranmissionFrame:SetPoint(point, xOfs + 500, yOfs + 155)

  end

  local names = GSE.getSequenceNames()
  SequenceListbox:SetList(names)
  if not GSE.isEmpty(SequenceName) then
  SequenceListbox:SetValue(SequenceName)
  transSequencevalue = SequenceName
  end
  tranmissionFrame:Show()
  GSE.GUI.TranmissionFrame:SetStatusText(L["Ready to Send"])
end

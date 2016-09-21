local GSSE = GSSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")

local onpause = false

function GSSE:GUIUpdateOutput()
  GSDebugOutputTextbox:SetText(GSDebugOutputTextbox:GetText() .. GSDebugOutput)
  GSDebugOutput = ""
end

function GSSE:EnableGuiDebugView()
  if GSMasterOptions.debugSequenceEx then
    --Disable
    GSMasterOptions.debugSequenceEx = true
    GSDebugEnableViewButton:SetText(L["Disable"])
    GSDebugPauseViewButton:SetDisabled(false)
    self:CancelTimer(self.GUIUpdateTimer)
  else
    --enable
    GSMasterOptions.debugSequenceEx = false
    GSDebugEnableViewButton:SetText(L["Enable"])
    self.GUIUpdateTimer = self:ScheduleRepeatingTimer("GUIUpdateOutput", 5)
    GSDebugPauseViewButton:SetDisabled(true)
  end
end

function GSSE:PauseGuiDebugView()
  if onpause then
    GSDebugEnableViewButton:SetText(L["Resume"])
    self:CancelTimer(self.GUIUpdateTimer)
    onpause = false
  else
    GSDebugEnableViewButton:SetText(L["Pause"])
    self.GUIUpdateTimer = self:ScheduleRepeatingTimer("GUIUpdateOutput", 5)
    onpause = true
  end

end

function GSSE:OptionsGuiDebugView()

end

GSDebugGSDebugFrame = AceGUI:Create("GSDebugFrame")
GSDebugFrame:SetTitle(L["Sequence Debugger"])
GSDebugFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"])
GSDebugFrame:SetCallback("OnClose", function(widget) GSDebugFrame:Hide();  GSMasterOptions.debugSequenceEx = false; GSSE:EnableGuiDebugView() end)
GSDebugFrame:SetLayout("List")
GSDebugFrame:Hide()

GSDebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSDebugOutputTextbox:SetLabel(L["Output"])
GSDebugOutputTextbox:SetNumLines(20)
GSDebugOutputTextbox:DisableButton(true)
GSDebugOutputTextbox:SetFullWidth(true)
GSDebugFrame:AddChild(GSDebugOutputTextbox)

local buttonGroup = AceGUI:Create("SimpleGroup")
buttonGroup:SetFullWidth(true)
buttonGroup:SetLayout("Flow")

local GSDebugEnableViewButton = AceGUI:Create("Button")
if GSMasterOptions.debugSequenceEx then
  GSDebugEnableViewButton:SetText(L["Disable"])
else
  GSDebugEnableViewButton:SetText(L["Enable"])
end

GSDebugEnableViewButton:SetWidth(150)
GSDebugEnableViewButton:SetCallback("OnClick", function() GSSE:EnableGuiDebugView() end)
buttonGroup:AddChild(GSDebugEnableViewButton)

local GSDebugPauseViewButton = AceGUI:Create("Button")
GSDebugPauseViewButton:SetText(L["Pause"])
GSDebugPauseViewButton:SetWidth(150)
GSDebugPauseViewButton:SetCallback("OnClick", function() GSSE:PauseGuiDebugView() end)
GSDebugPauseViewButton:SetDisabled(true)
buttonGroup:AddChild(GSDebugPauseViewButton)

local GSDebugClearViewButton = AceGUI:Create("Button")
GSDebugClearViewButton:SetText(L["Clear"])
GSDebugClearViewButton:SetWidth(150)
GSDebugClearViewButton:SetCallback("OnClick", function() GSDebugOutputTextbox:SetText() end)
buttonGroup:AddChild(GSDebugClearViewButton)

local GSDebugOptionsViewButton = AceGUI:Create("Button")
GSDebugOptionsViewButton:SetText(L["Options"])
GSDebugOptionsViewButton:SetWidth(150)
GSDebugOptionsViewButton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)
buttonGroup:AddChild(GSDebugOptionsViewButton)

GSDebugFrame:AddChild(buttonGroup)

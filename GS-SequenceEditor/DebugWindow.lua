local GSSE = GSSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")

local onpause = false

GSDebugFrame = AceGUI:Create("Frame")
GSDebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSDebugEnableViewButton = AceGUI:Create("Button")
GSDebugPauseViewButton = AceGUI:Create("Button")


function GSShowDebugWindow()
  GSDebugFrame:Show()
end


function GSSE:GUIUpdateOutput()
  GSDebugOutputTextbox:SetText(GSDebugOutputTextbox:GetText() .. GSDebugOutput)
  GSDebugOutput = ""
end

function GSSE:EnableGuiDebugView()
  if GSMasterOptions.debugSequenceEx then
    --Disable
    GSMasterOptions.debugSequenceEx = false
    GSDebugEnableViewButton:SetText(L["Disable"])
    GSDebugPauseViewButton:SetText(L["Pause"])
    GSDebugPauseViewButton:SetDisabled(true)
    self:CancelTimer(self.GUIUpdateTimer)
    onpause = false
  else
    --enable
    GSMasterOptions.debugSequenceEx = true
    GSDebugEnableViewButton:SetText(L["Enable"])
    self.GUIUpdateTimer = self:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    GSDebugPauseViewButton:SetDisabled(false)
  end
end

function GSSE:PauseGuiDebugView()
  if onpause then
    GSDebugPauseViewButton:SetText(L["Pause"])
    self.GUIUpdateTimer = self:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    onpause = false
  else
    GSDebugPauseViewButton:SetText(L["Resume"])
    self:CancelTimer(self.GUIUpdateTimer)
    onpause = true
  end
end

function GSSE:OptionsGuiDebugView()

end


GSDebugFrame:SetTitle(L["Sequence Debugger"])
GSDebugFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"])
GSDebugFrame:SetCallback("OnClose", function(widget) GSDebugFrame:Hide();  GSMasterOptions.debugSequenceEx = false; GSSE:EnableGuiDebugView() end)
GSDebugFrame:SetLayout("List")
GSDebugFrame:Hide()


GSDebugOutputTextbox:SetLabel(L["Output"])
GSDebugOutputTextbox:SetNumLines(25)
GSDebugOutputTextbox:DisableButton(true)
GSDebugOutputTextbox:SetFullWidth(true)
GSDebugFrame:AddChild(GSDebugOutputTextbox)

local buttonGroup = AceGUI:Create("SimpleGroup")
buttonGroup:SetFullWidth(true)
buttonGroup:SetLayout("Flow")


GSDebugEnableViewButton:SetWidth(150)
GSDebugEnableViewButton:SetCallback("OnClick", function() GSSE:EnableGuiDebugView() end)
buttonGroup:AddChild(GSDebugEnableViewButton)

GSDebugPauseViewButton:SetText(L["Pause"])
GSDebugPauseViewButton:SetWidth(150)
GSDebugPauseViewButton:SetCallback("OnClick", function() GSSE:PauseGuiDebugView() end)
buttonGroup:AddChild(GSDebugPauseViewButton)

if GSMasterOptions.debugSequenceEx then
  GSDebugEnableViewButton:SetText(L["Disable"])
  GSDebugPauseViewButton:SetDisabled(false)
else
  GSDebugEnableViewButton:SetText(L["Enable"])
  GSDebugPauseViewButton:SetDisabled(true)
end

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

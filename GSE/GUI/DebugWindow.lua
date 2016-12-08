local GSE = GSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local onpause = false

DebugFrame = AceGUI:Create("Frame")
GSE.DebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSDebugEnableViewButton = AceGUI:Create("Button")
GSDebugPauseViewButton = AceGUI:Create("Button")

GSE.GUIDebugFrame = DebugFrame

function GSE.GUIShowDebugWindow()
  DebugFrame:Show()
end


function GSE.GUIUpdateOutput()
  GSE.DebugOutputTextbox:SetText(GSE.DebugOutputTextbox:GetText() .. GSE.DebugOutput)
  GSE.DebugOutput = ""
end

function GSE.GUIEnableDebugView()
  if GSDebugSequenceEx then
    --Disable
    GSDebugSequenceEx = false
    GSDebugEnableViewButton:SetText(L["Enable"])
    GSDebugPauseViewButton:SetText(L["Pause"])
    GSDebugPauseViewButton:SetDisabled(true)
    self:CancelTimer(self.GUIUpdateTimer)
    onpause = false
  else
    --enable
    GSDebugSequenceEx = true
    GSDebugEnableViewButton:SetText(L["Disable"])
    self.GUIUpdateTimer = self:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    GSDebugPauseViewButton:SetDisabled(false)
  end
end

function GSE:PauseGuiDebugView()
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

DebugFrame:SetTitle(L["Sequence Debugger"])
local _, GCD_Timer = GetSpellCooldown(61304)
DebugFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] .. " GCD:" .. GCD_Timer)
DebugFrame:SetCallback("OnClose", function(widget) DebugFrame:Hide()  end)
DebugFrame:SetLayout("List")
DebugFrame:Hide()


GSE.DebugOutputTextbox:SetLabel(L["Output"])
GSE.DebugOutputTextbox:SetNumLines(25)
GSE.DebugOutputTextbox:DisableButton(true)
GSE.DebugOutputTextbox:SetFullWidth(true)
DebugFrame:AddChild(GSE.DebugOutputTextbox)

local buttonGroup = AceGUI:Create("SimpleGroup")
buttonGroup:SetFullWidth(true)
buttonGroup:SetLayout("Flow")


GSDebugEnableViewButton:SetWidth(150)
GSDebugEnableViewButton:SetCallback("OnClick", function() GSE.GUIEnableDebugView() end)
buttonGroup:AddChild(GSDebugEnableViewButton)

GSDebugPauseViewButton:SetText(L["Pause"])
GSDebugPauseViewButton:SetWidth(150)
GSDebugPauseViewButton:SetCallback("OnClick", function() GSE.GUIPauseDebugView() end)
buttonGroup:AddChild(GSDebugPauseViewButton)

if GSDebugSequenceEx then
  GSDebugEnableViewButton:SetText(L["Disable"])
  GSDebugPauseViewButton:SetDisabled(false)
else
  GSDebugEnableViewButton:SetText(L["Enable"])
  GSDebugPauseViewButton:SetDisabled(true)
end

local GSDebugClearViewButton = AceGUI:Create("Button")
GSDebugClearViewButton:SetText(L["Clear"])
GSDebugClearViewButton:SetWidth(150)
GSDebugClearViewButton:SetCallback("OnClick", function() GSE.DebugOutputTextbox:SetText('') end)
buttonGroup:AddChild(GSDebugClearViewButton)

local GSDebugOptionsViewButton = AceGUI:Create("Button")
GSDebugOptionsViewButton:SetText(L["Options"])
GSDebugOptionsViewButton:SetWidth(150)
GSDebugOptionsViewButton:SetCallback("OnClick", function() GSE.GUIOptionsDebugView() end)
buttonGroup:AddChild(GSDebugOptionsViewButton)

DebugFrame:AddChild(buttonGroup)

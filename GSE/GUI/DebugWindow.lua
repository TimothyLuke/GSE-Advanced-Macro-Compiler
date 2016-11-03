local GSSE = GSSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = GSL

local onpause = false

GSDebugFrame = AceGUI:Create("Frame")
GSE.DebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSDebugEnableViewButton = AceGUI:Create("Button")
GSDebugPauseViewButton = AceGUI:Create("Button")


function GSShowDebugWindow()
  GSDebugFrame:Show()
end


function GSSE:GUIUpdateOutput()
  GSE.DebugOutputTextbox:SetText(GSE.DebugOutputTextbox:GetText() .. GSE.DebugOutput)
  GSE.DebugOutput = ""
end

function GSSE:EnableGuiDebugView()
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
  local config = LibStub:GetLibrary("AceConfigDialog-3.0")
  config:Open("GSSE")
  --config:SelectGroup("GSSE", "Debug")

end


GSDebugFrame:SetTitle(L["Sequence Debugger"])
local _, GCD_Timer = GetSpellCooldown(61304)
GSDebugFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] .. " GCD:" .. GCD_Timer)
GSDebugFrame:SetCallback("OnClose", function(widget) GSDebugFrame:Hide()  end)
GSDebugFrame:SetLayout("List")
GSDebugFrame:Hide()


GSE.DebugOutputTextbox:SetLabel(L["Output"])
GSE.DebugOutputTextbox:SetNumLines(25)
GSE.DebugOutputTextbox:DisableButton(true)
GSE.DebugOutputTextbox:SetFullWidth(true)
GSDebugFrame:AddChild(GSE.DebugOutputTextbox)

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
GSDebugOptionsViewButton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)
buttonGroup:AddChild(GSDebugOptionsViewButton)

GSDebugFrame:AddChild(buttonGroup)

local GSE = GSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local onpause = false

DebugFrame = AceGUI:Create("Frame")
DebugFrame.DebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSE.GUIDebugFrame.DebugEnableViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugPauseViewButton = AceGUI:Create("Button")
DebugFrame.DebugEnableViewButton = GSE.GUIDebugFrame.DebugEnableViewButton
DebugFrame.DebugPauseViewButton = GSE.GUIDebugFrame.DebugPauseViewButton

GSE.GUIDebugFrame = DebugFrame

function GSE.GUIShowDebugWindow()
  DebugFrame:Show()
end


function GSE.GUIUpdateOutput()
  GSE.GUIDebugFrame.DebugOutputTextbox:SetText(GSE.GUIDebugFrame.DebugOutputTextbox:GetText() .. GSE.DebugOutput)
  GSE.DebugOutput = ""
end

function GSE.GUIEnableDebugView()
  if GSE.UnsavedOptions["DebugSequenceExecution"] then
    --Disable
    GSE.UnsavedOptions["DebugSequenceExecution"] = false
    GSE.GUIDebugFrame.GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Enable"])
    GSE.GUIDebugFrame.DebugPauseViewButton:SetText(L["Pause"])
    GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(true)
    GSE:CancelTimer(self.GUIUpdateTimer)
    onpause = false
  else
    --enable
    GSE.UnsavedOptions["DebugSequenceExecution"] = true
    GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Disable"])
    GSE.GUIUpdateTimer = GSE:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(false)
  end
end

function GSE:PauseGuiDebugView()
  if onpause then
    GSE.GUIDebugFrame.DebugPauseViewButton:SetText(L["Pause"])
    GSE.GUIUpdateTimer = GSE:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    onpause = false
  else
    GSE.GUIDebugFrame.DebugPauseViewButton:SetText(L["Resume"])
    GSE:CancelTimer(GSE.GUIUpdateTimer)
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


GSE.GUIDebugFrame.DebugEnableViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugEnableViewButton:SetCallback("OnClick", function() GSE.GUIEnableDebugView() end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugEnableViewButton)

GSE.GUIDebugFrame.DebugPauseViewButton:SetText(L["Pause"])
GSE.GUIDebugFrame.DebugPauseViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugPauseViewButton:SetCallback("OnClick", function() GSE.GUIPauseDebugView() end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugPauseViewButton)

if GSE.UnsavedOptions["DebugSequenceExecution"] then
  GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Disable"])
  GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(false)
else
  GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Enable"])
  GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(true)
end

local GSE.GUIDebugFrame.DebugClearViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugClearViewButton:SetText(L["Clear"])
GSE.GUIDebugFrame.DebugClearViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugClearViewButton:SetCallback("OnClick", function() GSE.DebugOutputTextbox:SetText('') end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugClearViewButton)

local GSE.GUIDebugFrame.DebugOptionsViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugOptionsViewButton:SetText(L["Options"])
GSE.GUIDebugFrame.OptionsViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugOptionsViewButton:SetCallback("OnClick", function() GSE.GUIOptionsDebugView() end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugOptionsViewButton)

DebugFrame:AddChild(buttonGroup)

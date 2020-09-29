local GSE = GSE
local GNOME, _ = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local onpause = false

DebugFrame = AceGUI:Create("Frame")
GSE.GUIDebugFrame = DebugFrame
DebugFrame.DebugOutputTextbox = AceGUI:Create("MultiLineEditBox")
GSE.GUIDebugFrame.DebugEnableViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugPauseViewButton = AceGUI:Create("Button")



function GSE.GUIShowDebugWindow()
  DebugFrame:Show()
end


function GSE.GUIUpdateOutput()
  GSE.GUIDebugFrame.DebugOutputTextbox:SetText(GSE.GUIDebugFrame.DebugOutputTextbox:GetText() .. GSE.DebugOutput)
  GSE.DebugOutput = ""
end

function GSE.GUIEnableDebugView()
  if GSE.UnsavedOptions["DebugSequenceExecution"] then
    -- Disable
    GSE.UnsavedOptions["DebugSequenceExecution"] = false
    GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Enable"])
    GSE.GUIDebugFrame.DebugPauseViewButton:SetText(L["Pause"])
    GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(true)
    GSE:CancelTimer(GSE.GUIUpdateTimer)
    onpause = false
  else
    -- Enable
    GSE.UnsavedOptions["DebugSequenceExecution"] = true
    GSE.GUIDebugFrame.DebugEnableViewButton:SetText(L["Disable"])
    GSE.GUIUpdateTimer = GSE:ScheduleRepeatingTimer("GUIUpdateOutput", 1)
    GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(false)
  end
end

function GSE.GUIPauseDebugView()
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
local GCD_Timer = GSE.GetGCD()
DebugFrame:SetStatusText(L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] .. "   GCD: " .. GCD_Timer)
DebugFrame:SetCallback("OnClose", function(widget) DebugFrame:Hide()  end)
DebugFrame:SetLayout("List")
DebugFrame:Hide()


GSE.GUIDebugFrame.DebugOutputTextbox:SetLabel(L["Output"])
GSE.GUIDebugFrame.DebugOutputTextbox:SetNumLines(25)
GSE.GUIDebugFrame.DebugOutputTextbox:DisableButton(true)
GSE.GUIDebugFrame.DebugOutputTextbox:SetFullWidth(true)
DebugFrame:AddChild(GSE.GUIDebugFrame.DebugOutputTextbox)

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

GSE.GUIDebugFrame.DebugClearViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugClearViewButton:SetText(L["Clear"])
GSE.GUIDebugFrame.DebugClearViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugClearViewButton:SetCallback("OnClick", function() GSE.GUIDebugFrame.DebugOutputTextbox:SetText('') end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugClearViewButton)

GSE.GUIDebugFrame.DebugOptionsViewButton = AceGUI:Create("Button")
GSE.GUIDebugFrame.DebugOptionsViewButton:SetText(L["Options"])
GSE.GUIDebugFrame.DebugOptionsViewButton:SetWidth(150)
GSE.GUIDebugFrame.DebugOptionsViewButton:SetCallback("OnClick", function() GSE.OpenOptionsPanel() end)
buttonGroup:AddChild(GSE.GUIDebugFrame.DebugOptionsViewButton)

DebugFrame:AddChild(buttonGroup)

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local expframe = AceGUI:Create("Frame")
expframe:Hide()


expframe:SetTitle("Gnome Sequencer: Expiment.")
expframe:SetStatusText("Experiment")
expframe:SetCallback("OnClose", function(widget)  expframe:Hide() end)
expframe:SetLayout("List")

local selpanel = AceGUI:Create("SelectablePanel")
selpanel:SetKey("key1")
selpanel:SetHeight(100)
selpanel:SetWidth(200)

local label = AceGUI:Create("Label")
label:SetText("Hello World")
selpanel:AddChild(label)

expframe:AddChild(selpanel)

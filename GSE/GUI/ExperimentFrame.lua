local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local expframe = AceGUI:Create("Frame")
expframe.panels = {}
expframe.CurentSelected = ""

function expframe:clearpanels(widget)
  print("widget = " .. widget:GetKey())
  for k,v in pairs(expframe.panels) do
    print("k " .. k)
    if k == widget:GetKey() then
      print ("matching key")
      expframe.CurentSelected = widget:GetKey()

    else
      print ("other widget key")
      print("reprinting k " .. k)
      local wid = expframe.panels[k]
      wid:SetClicked(false)
    end
  end
end


expframe:SetTitle("Gnome Sequencer: Expiment.")
expframe:SetStatusText("Experiment")
expframe:SetCallback("OnClose", function(widget)  expframe:Hide() end)
expframe:SetLayout("List")

local selpanel = AceGUI:Create("SelectablePanel")
selpanel:SetKey("key1")
selpanel:SetHeight(100)
selpanel:SetWidth(200)
expframe.panels[selpanel:GetKey()] = selpanel
selpanel:SetCallback("OnClick", function(widget)
  expframe:clearpanels(widget)
end)

local label = AceGUI:Create("Label")
label:SetText("Hello World")
selpanel:AddChild(label)

expframe:AddChild(selpanel)

local selpanel2 = AceGUI:Create("SelectablePanel")
selpanel2:SetKey("key2")
selpanel2:SetHeight(100)
selpanel2:SetWidth(200)
expframe.panels[selpanel2:GetKey()] = selpanel2
selpanel2:SetCallback("OnClick", function(widget)
  expframe:clearpanels(widget)
end)

local label2 = AceGUI:Create("Label")
label2:SetText("Hello World2")
selpanel2:AddChild(label2)

expframe:AddChild(selpanel2)

local selpanel3 = AceGUI:Create("SelectablePanel")
selpanel3:SetKey("key3")
selpanel3:SetHeight(100)
selpanel3:SetWidth(200)
expframe.panels[selpanel2:GetKey()] = selpanel3
selpanel3:SetCallback("OnClick", function(widget)
  expframe:clearpanels(widget)
end)

local label3 = AceGUI:Create("Label")
label3:SetText("Hello World3")
selpanel3:AddChild(label3)

expframe:AddChild(selpanel3)

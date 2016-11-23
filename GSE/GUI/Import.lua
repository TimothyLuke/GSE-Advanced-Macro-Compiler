local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local importframe = AceGUI:Create("Frame")
importframe:Hide()
GSE.GUI.ImportFrame = importframe
local recbuttontext = L["Import"]

-- Record Frame

importframe:SetTitle(L["Import] Macro"])
importframe:SetStatusText(L["Import Macro from Forums"])
importframe:SetCallback("OnClose", function(widget)  importframe:Hide(); end)
importframe:SetLayout("List")

local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")

local defaultradio = AceGUI:Create("CheckBox")
defaultradio:SetType("radio")
defaultradio:SetLabel(L["GSE Macro"])
defaultradio:SetValue(true)
defaultradio:SetWidth(250)
defaultradio:SetCallback("OnValueChanged", function (obj,event,key) GSE.GUI.ToggleImportDefault(0)  end)

local legacyradio = AceGUI:Create("CheckBox")
legacyradio:SetType("radio")
legacyradio:SetLabel(L["Legacy GS/GSE1 Macro"])
legacyradio:SetValue(false)
legacyradio:SetWidth(250)
legacyradio:SetCallback("OnValueChanged", function (obj,event,key) GSE.GUI.ToggleImportDefault(1)  end)


specClassGroup:AddChild(defaultradio)
specClassGroup:AddChild(legacyradio)

importframe:AddChild(headerGroup)

local importsequencebox = AceGUI:Create("MultiLineEditBox")
importsequencebox:SetLabel(L["Macro Collection to Import."])
importsequencebox:SetNumLines(20)
importsequencebox:DisableButton(true)
importsequencebox:SetFullWidth(true)
importframe:AddChild(importsequencebox)

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")


local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Import"])
recbutton:SetWidth(150)
recbutton:SetCallback("OnClick", function() GSE.GUI.ImportSequence() end)
recButtonGroup:AddChild(recbutton)

importframe:AddChild(recButtonGroup)


function GSE.GUI.ToggleImportDefault(switchstate)
  if buttonname == 1 then
      legacyradio:SetValue(true)
      defaultradio:SetValue(false)
    else
      legacyradio:SetValue(false)
      defaultradio:SetValue(true)
  end
end

function GSE.GUI.ImportSequence()
  local success, message = GSE.ImportSequence(importsequencebox:GetText(), legacyradio:GetValue())
  if success then
    StaticPopup_Show ("GSE-MacroImportSuccess")
    GSE.GUI.ImportFrame:Hide()
    GSE.GUI.ViewFrame:Show()
  else
    StaticPopup_Show ("GSE-MacroImportFailure")
  end
end

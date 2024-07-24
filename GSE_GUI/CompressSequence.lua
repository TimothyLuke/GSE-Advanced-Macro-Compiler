local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local compressframe = AceGUI:Create("Frame")
compressframe.frame:SetFrameStrata("MEDIUM")
compressframe.frame:SetClampedToScreen(true)
compressframe:Hide()

compressframe:SetTitle(L["Gnome Sequencer: Compress a Sequence String."])
compressframe:SetStatusText(L["Compress Sequence from Forums"])
compressframe:SetCallback(
  "OnClose",
  function(widget)
    compressframe:Hide()
  end
)
compressframe:SetLayout("List")

local importsequencebox = AceGUI:Create("MultiLineEditBox")
importsequencebox:SetLabel(L["Sequence to Compress."])
importsequencebox:SetNumLines(20)
importsequencebox:DisableButton(true)
importsequencebox:SetFullWidth(true)
compressframe:AddChild(importsequencebox)

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetFullWidth(true)
recButtonGroup:SetLayout("Flow")

local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Compress"])
recbutton:SetWidth(150)
recbutton:SetCallback(
  "OnClick",
  function()
    importsequencebox:SetText(GSE.EncodeMessage(importsequencebox:GetText()))
  end
)
local decbutton = AceGUI:Create("Button")
decbutton:SetText(L["Decompress"])
decbutton:SetWidth(150)
decbutton:SetCallback(
  "OnClick",
  function()
    local success, returnval = GSE.DecodeMessage(importsequencebox:GetText())
    if success then
      importsequencebox:SetText(IndentationLib.encode(GSE.Dump(returnval)))
    else
      GSE.Print("Cant interpret that sequence.")
    end
  end
)
recButtonGroup:AddChild(recbutton)
recButtonGroup:AddChild(decbutton)

compressframe:AddChild(recButtonGroup)
GSE.GUICompressFrame = compressframe

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local importframe = AceGUI:Create("Frame")
importframe.AutoCreateIcon = true

importframe:Hide()

importframe:SetTitle(L["GSE: Import a Macro String."])
importframe:SetStatusText(L["Import Macro from Forums"])
importframe:SetCallback(
  "OnClose",
  function(widget)
    importframe:Hide()
    GSE.GUIShowViewer()
  end
)
importframe:SetLayout("List")

local importsequencebox = AceGUI:Create("MultiLineEditBox")
importsequencebox:SetLabel(L["Macro Collection to Import."])
importsequencebox:SetNumLines(20)
importsequencebox:DisableButton(true)
importsequencebox:SetFullWidth(true)
importframe:AddChild(importsequencebox)

local createicondropdown = AceGUI:Create("CheckBox")
createicondropdown:SetLabel(L["Automatically Create Macro Icon"])
createicondropdown:SetWidth(250)
createicondropdown:SetType("checkbox")
createicondropdown:SetValue(true)
createicondropdown:SetCallback(
  "OnValueChanged",
  function(obj, event, key)
    importframe.AutoCreateIcon = key
  end
)
importframe:AddChild(createicondropdown)

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")

local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Import"])
recbutton:SetWidth(150)
recbutton:SetCallback(
  "OnClick",
  function()
    GSE.GUIImportSequence()
  end
)
recButtonGroup:AddChild(recbutton)

--local testbutton = AceGUI:Create("Button")
--testbutton:SetText("Test")
--testbutton:SetWidth(150)
--testbutton:SetCallback("OnClick", function()
--  GSE.Print(GSE.StripControlandExtendedCodes(importsequencebox:GetText()))
--  for i=69,85 do
--    GSE.Print(string.byte(importsequencebox:GetText(), i))
--  end
--  GSE.Print("Next")
--  for i=69,85 do
--    GSE.Print(string.byte(GSE.StripControlandExtendedCodes(importsequencebox:GetText()), i))
--  end
--end)
--recButtonGroup:AddChild(testbutton)

importframe:AddChild(recButtonGroup)
GSE.GUIImportFrame = importframe

-- function GSE.GUIToggleImportDefault(switchstate)
--   if switchstate == 1 then
--       legacyradio:SetValue(true)
--       defaultradio:SetValue(false)
--     else
--       legacyradio:SetValue(false)
--       defaultradio:SetValue(true)
--   end
-- end

function GSE.GUIImportSequence()
  local importstring = importsequencebox:GetText()
  importstring = GSE.TrimWhiteSpace(importstring)
  -- Either a compressed import or a failed copy
  local success = GSE.ImportSerialisedSequence(importstring, importframe.AutoCreateIcon)
  if success then
    importsequencebox:SetText("")
    GSE.GUIImportFrame:Hide()
  else
    StaticPopup_Show("GSE-MacroImportFailure")
  end
end

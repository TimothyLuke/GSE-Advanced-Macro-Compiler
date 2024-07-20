local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local Statics = GSE.Static

local whatsnewframe = AceGUI:Create("Frame")

whatsnewframe:Hide()

whatsnewframe:SetTitle(L["GSE: Whats New in "] .. C_AddOns.GetAddOnMetadata("GSE", "Version"))
whatsnewframe:SetStatusText(L["Changes Left Side, Changes Right Side, Many Changes!!!! Handle It!"])
whatsnewframe:SetCallback(
  "OnClose",
  function(widget)
    whatsnewframe:Hide()
  end
)

local scrollContainer = AceGUI:Create("SimpleGroup")
scrollContainer:SetFullWidth(true)

scrollContainer:SetHeight(whatsnewframe.frame:GetHeight() - 120)
scrollContainer:SetLayout("Fill") -- important!

whatsnewframe:AddChild(scrollContainer)
local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()

local scroll = AceGUI:Create("ScrollFrame")
scroll:SetLayout("List") -- probably?
scrollContainer:AddChild(scroll)
scroll:SetFullWidth(true)

local label = AceGUI:Create("Label")
scroll:AddChild(label)
label:SetFullWidth(true)
label:SetFont(fontName, fontHeight + 2, fontFlags)

local shownew = AceGUI:Create("CheckBox")
shownew:SetLabel(L["Show next time you login."])
shownew:SetValue(GSEOptions.shownew)
shownew:SetCallback(
  "OnValueChanged",
  function(obj, event, key)
    GSEOptions.shownew = key
  end
)
scroll:AddChild(shownew)

function GSE.ShowUpdateNotes()
  label:SetText(L["WhatsNew"])
  whatsnewframe:Show()
end

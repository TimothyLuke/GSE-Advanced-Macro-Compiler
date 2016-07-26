local GNOME,_ = ...
GSTR = LibStub("AceAddon-3.0"):NewAddon("GSTR", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

GSTranslatorGUILoaded = false

local frame = AceGUI:Create("Frame")
local curentSequence
frame:SetTitle("Sequence Viewer")
frame:SetStatusText("Gnome Sequencer: Language Locale Extractor")
frame:SetCallback("OnClose", function(widget) frame:Hide() end)
frame:SetLayout("List")

local localebox = AceGUI:Create("EditBox")
localebox:SetLabel("Locale")
localebox:SetText(GetLocale())
localeBox:DisableButton(true)
localebox:SetWidth(250)
frame:AddChild(localebox)

local outputBox = AceGUI:Create("MultiLineEditBox")
outputBox:SetLabel("Sequence")
outputBox:SetNumLines(25)
outputBox:DisableButton(true)
outputBox:SetFullWidth(true)
frame:AddChild(outputBox)

-------------end editor-----------------
-- Slash Commands

GSSE:RegisterChatCommand("gstr", "GSSlash")


function GSTR:GSSlash(input)
  if GSTranslatorAvailable then
    outputBox:SetText(table.concat(GSTranslateGetLocaleSpellNameTable(), "\n"))
    if input == "hide" then
        frame:Hide()
    else
        frame:Show()
    end
  end
end

GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")


-- Create Dialog

local textstore  -- temporary text box on the dialog used for input.

local frame = AceGUI:Create("Frame")
frame:SetTitle("Sequence Editor")
frame:SetStatusText("Gnome Sequencer: Sequence Editor")

frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
frame:SetLayout("Flow")

local editbox = AceGUI:Create("EditBox")
editbox:SetLabel("Load Sequence")
editbox:SetWidth(200)
editbox:SetCallback("OnEnterPressed", function(widget, event, text) textStore
frame:AddChild(editbox)

local button = AceGUI:Create("Button")
button:SetText("Load")
button:SetWidth(200)
button:SetCallback("OnClick", function() loadSequence(textstore) end)
frame:AddChild(button)

local sequencebox = AceGUI:Create("MultiLineEditBox")
sequencebox:SetLabel("Load Sequence")
frame:AddChild(sequencebox)

-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions


local function loadSequence(SequenceName)
    sequencebox:SetText(GSExportSequence(SequenceName))
end

function GSSE:GSSlash(input)
    if input == "hide" then
        frame:Hide()
    else
        frame:Show()
    end
end

function GSSE:OnInitialize()
    frame:Hide()
end
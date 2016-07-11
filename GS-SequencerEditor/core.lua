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

local updbutton = AceGUI:Create("Button")
updbutton:SetText("Test")
updbutton:SetWidth(200)
updbutton:SetCallback("OnClick", function() updateSequence(sequencebox:GetText()) end)
frame:AddChild(button)


-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions


local function loadSequence(SequenceName)
    sequencebox:SetText(GSExportSequence(SequenceName))
end

local function updateSequence(sequenceText)
    GSUpdateSequence("LiveTest", sequenceText)
    local sequenceIndex = GetMacroIndexByName(sequenceName)
    if sequenceIndex > 0 then
      -- Sequence exists do nothing
    else
      -- Create Sequence as a player sequence
      sequenceid = CreateSequence("LiveTest", icon, '#showtooltip\n/click ' .. "LiveTest", 0)
      ModifiedMacros["LiveTest"] = true
    end
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


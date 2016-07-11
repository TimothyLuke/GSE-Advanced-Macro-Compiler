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
    editbox:SetText("LiveTest")
end

local function updateSequence(sequenceText)
    
    local sequenceIndex = GetMacroIndexByName(sequenceName)
    GSUpdateSequence("LiveTest", sequenceText)
    GSMasterSequences["LiveTest"].specID = getSpecID()
    GSMasterSequences["LiveTest"].helpTxt = "Talents: " .. getCurrentTalents()
    GSMasterSequences["LiveTest"].icon = getMacroIcon(sequenceIndex)
    loadSequence("LiveTest")
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

local function getCurrentTalents()
  local talents = ""
  for talentTier = 1, MAX_TALENT_TIERS do
    local available, selected = GetTalentTierInfo(talentTier, 1)
    talents = talents .. (available and selected or "0")
  end
  return talents
end

local function getSpecID()
    local currentSpec = GetSpecialization()
    return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
end

local function getMacroIcon(sequenceIndex)
  if isempty(sequenceIndex) then
    local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID(getSpecID())
    return strsub(specicon, 17)  
  else
    return GetMacroIconInfo(sequenceIndex)
  end
end

local function isempty(s)
  return s == nil or s == ''
end

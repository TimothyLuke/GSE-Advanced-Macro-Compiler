local GNOME,_ = ...
GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function GSSE:getSequenceNames()
  local keyset={}
  local n=0

  for k,v in pairs(GSMasterSequences) do
    n=n+1
    keyset[k]=k
  end
  return keyset
end


-- Create Viewer Dialog

local frame = AceGUI:Create("Frame")
local curentSequence 
frame:SetTitle("Sequence Viewer")
frame:SetStatusText("Gnome Sequencer: Sequence Viewer")
frame:SetCallback("OnClose", function(widget) frame:Hide() end)
frame:SetLayout("List")

local names = GSSE:getSequenceNames()
local listbox = AceGUI:Create("Dropdown")
listbox:SetLabel("Load Sequence")
listbox:SetWidth(250)
listbox:SetList(names)
listbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)
frame:AddChild(listbox)

local sequencebox = AceGUI:Create("MultiLineEditBox")
sequencebox:SetLabel("Sequence")
sequencebox:SetNumLines(20)
sequencebox:DisableButton(true)
sequencebox:SetFullWidth(true)
frame:AddChild(sequencebox)

local updbutton = AceGUI:Create("Button")
updbutton:SetText("Edit")
updbutton:SetWidth(200)
updbutton:SetCallback("OnClick", function() GSSE:updateSequence(currentSequence) end)
frame:AddChild(updbutton)
-------------end viewer-------------
-------------begin editor--------------------
local editframe = AceGUI:Create("Frame")
local stepvalue

editframe:SetTitle("Sequence Editor")
editframe:SetStatusText("Gnome Sequencer: Sequence Editor")
editframe:SetCallback("OnClose", function(widget) GSSE:closeEditor() end)
editframe:SetLayout("List")

local nameeditbox = AceGUI:Create("EditBox")
nameeditbox:SetLabel("Sequence Name")
nameeditbox:SetWidth(250)
editframe:AddChild(nameeditbox)

local stepdropdown = AceGUI:Create("Dropdown")
stepdropdown:SetLabel("Step Function")
stepdropdown:SetWidth(250)
stepdropdown:SetList({
  ["1"] = "Sequential (1 2 3 4)",
  ["2"] = "Priority List (1 12 123 1234)",

})
stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key end)
editframe:AddChild(stepdropdown)

local premacrobox = AceGUI:Create("MultiLineEditBox")
premacrobox:SetLabel("PreMacro")
premacrobox:SetNumLines(3)
premacrobox:DisableButton(true)
premacrobox:SetFullWidth(true)
editframe:AddChild(premacrobox)


local spellbox = AceGUI:Create("MultiLineEditBox")
spellbox:SetLabel("Sequence")
spellbox:SetNumLines(9)
spellbox:DisableButton(true)
spellbox:SetFullWidth(true)
editframe:AddChild(spellbox)

local postmacrobox = AceGUI:Create("MultiLineEditBox")
postmacrobox:SetLabel("PostMacro")
postmacrobox:SetNumLines(3)
postmacrobox:DisableButton(true)
postmacrobox:SetFullWidth(true)
editframe:AddChild(postmacrobox)

local eupdbutton = AceGUI:Create("Button")
eupdbutton:SetText("Save")
eupdbutton:SetWidth(200)
eupdbutton:SetCallback("OnClick", function() GSSE:eupdateSequence(currentSequence) end)
editframe:AddChild(eupdbutton)


-------------end editor-----------------
-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions


function GSSE:loadSequence(SequenceName)
    sequencebox:SetText(GSExportSequence(SequenceName))
end

function GSSE:updateSequence(SequenceName)
    frame:Hide()
    GSMasterSequences["LiveTest"] = GSMasterSequences[SequenceName]
    GSMasterSequences["LiveTest"].author = GetUnitName("player", true) .. '@' .. GetRealmName()
    GSMasterSequences["LiveTest"].specID = GSSE:getSpecID()
    GSMasterSequences["LiveTest"].helpTxt = "Talents: " .. GSSE:getCurrentTalents()
    GSMasterSequences["LiveTest"].icon = GSSE:getMacroIcon(sequenceIndex)
    GSUpdateSequence("LiveTest", GSMasterSequences["LiveTest"])

    GSSE:loadSequence("LiveTest")

   -- show editor
   nameeditbox:SetText("LiveTest")
   if GSSE:isempty(GSMasterSequences["LiveTest"].StepFunction) then
     stepdropdown:SetValue("1")
   else
     stepdropdown:SetValue("2")
   end
   if GSSE:isempty(GSMasterSequences["LiveTest"].PreMacro) then
   else
     premacrobox:SetText(GSMasterSequences["LiveTest"].PreMacro)
   end
   if GSSE:isempty(GSMasterSequences["LiveTest"].PostMacro) then
   else
     postmacrobox:SetText(GSMasterSequences["LiveTest"].PostMacro)
   end
   spellbox:SetText(table.concat(GSMasterSequences["LiveTest"],"\n"))

   editframe:Show()
end

function GSSE:eupdateSequence(SequenceName)
    --process Lines
    
    -- update sequence
    --GSUpdateSequence("LiveTest", GSMasterSequences["LiveTest"])

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
    editframe:Hide()
    print('|cffff0000' .. GNOME .. ':|r The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type |cFF00FF00/gsse |r to get started.')
end

function GSSE:getCurrentTalents()
  local talents = ""
  for talentTier = 1, MAX_TALENT_TIERS do
    local available, selected = GetTalentTierInfo(talentTier, 1)
    talents = talents .. (available and selected or "0")
  end
  return talents
end

function GSSE:getSpecID()
    local currentSpec = GetSpecialization()
    return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
end

function GSSE:getMacroIcon(sequenceIndex)
  if GSSE:isempty(sequenceIndex) then
    local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID(GSSE:getSpecID())
    return strsub(specicon, 17)  
  else
    local _, iconpath, _ =  GetMacroInfo(sequenceIndex)
    return iconpath
  end
end

function GSSE:isempty(s)
  return s == nil or s == ''
end

function GSSE:closeEditor()

end

function GSSE:lines(str)
  local t = {}
  local function helper(line) 
    if string.lower(string.sub(line,1,6)) == "sequen" then
    elseif string.lower(string.sub(line,1,6)) == "\"/cast" then
      --print ("format" .. string.format(string.gsub(line, "\"", "")))
      table.insert(t, string.format(string.gsub(line, "\"", "")))
    else
      --print ("Line 1,6 " .. string.lower(string.sub(line,1,5)))
      table.insert(t, line) 
    end
    return "" 
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  GST = t
  return t
end
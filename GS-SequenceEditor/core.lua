local GNOME,_ = ...
GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

GSSequenceEditorLoaded = false

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

local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")

local firstheadercolumn = AceGUI:Create("SimpleGroup")
--firstheadercolumn:SetFullWidth(true)
firstheadercolumn:SetLayout("List")

editframe:SetTitle("Sequence Editor")
editframe:SetStatusText("Gnome Sequencer: Sequence Editor")
editframe:SetCallback("OnClose", function() GSSE:eupdateSequence(currentSequence, GSSequenceEditorLoaded) end)
editframe:SetLayout("List")

local nameeditbox = AceGUI:Create("EditBox")
nameeditbox:SetLabel("Sequence Name")
nameeditbox:SetWidth(250)
firstheadercolumn:AddChild(nameeditbox)

local stepdropdown = AceGUI:Create("Dropdown")
stepdropdown:SetLabel("Step Function")
stepdropdown:SetWidth(250)
stepdropdown:SetList({
  ["1"] = "Sequential (1 2 3 4)",
  ["2"] = "Priority List (1 12 123 1234)",

})

stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key end)
firstheadercolumn:AddChild(stepdropdown)

local specClassGroup = AceGUI:Create("SimpleGroup")
specClassGroup:SetFullWidth(true)
specClassGroup:SetLayout("Flow")

local specradio = AceGUI:Create("CheckBox")
specradio:SetType("radio")
specradio:SetLabel("Specialization Specific Macro")
specradio:SetValue(true)
specradio:SetWidth(250)
specradio:SetCallback("OnValueChanged", function (obj,event,key) GSSE:toggleClasses("spec")  end)

local classradio = AceGUI:Create("CheckBox")
classradio:SetType("radio")
classradio:SetLabel("Classwide Macro")
classradio:SetValue(false)
classradio:SetWidth(250)
classradio:SetCallback("OnValueChanged", function (obj,event,key) GSSE:toggleClasses("class")  end)


specClassGroup:AddChild(specradio)
specClassGroup:AddChild(classradio)


headerGroup:AddChild(firstheadercolumn)

local iconpicker = AceGUI:Create("Icon")
--iconpicker:SetImage()
iconpicker:SetLabel("Macro Icon")


headerGroup:AddChild(iconpicker)
editframe:AddChild(specClassGroup)
editframe:AddChild(headerGroup)

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

--local eupdbutton = AceGUI:Create("Button")
--eupdbutton:SetText("Save")
--eupdbutton:SetWidth(200)
--eupdbutton:SetCallback("OnClick", function() GSSE:eupdateSequence(currentSequence) end)
--editframe:AddChild(eupdbutton)


-------------end editor-----------------
-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions


function GSSE:loadSequence(SequenceName)
    sequencebox:SetText(GSExportSequence(SequenceName))
end

function GSSE:toggleClasses(buttonname)
  if buttonname == "class" then
    classradio:SetValue(true)
    specradio:SetValue(false)
  else
    classradio:SetValue(false)
    specradio:SetValue(true)
  end
end

function GSSE:updateSequence(SequenceName)
    frame:Hide()
    GSMasterSequences["LiveTest"] = GSMasterSequences[SequenceName]
    GSMasterSequences["LiveTest"].author = GetUnitName("player", true) .. '@' .. GetRealmName()
    GSMasterSequences["LiveTest"].specID = GSSE:getSpecID()
    GSMasterSequences["LiveTest"].helpTxt = "Talents: " .. GSSE:getCurrentTalents()
    GSPrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
    GSMasterSequences["LiveTest"].icon = GSSE:getMacroIcon(SequenceName)
    GSPrintDebugMessage("returned icon: " .. GSMasterSequences["LiveTest"].icon, GNOME)
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
   iconpicker:SetImage("Interface\\Icons\\" .. GSMasterSequences["LiveTest"].icon)
   editframe:Show()
end

function GSSE:eupdateSequence(SequenceName, loaded)
    --process Lines
    if loaded then
      for i, v in ipairs(GSMasterSequences["LiveTest"]) do GSMasterSequences["LiveTest"][i] = nil end
      GSSE:lines(GSMasterSequences["LiveTest"], spellbox:GetText())
      -- update sequence
      if stepvalue == "2" then
        GSMasterSequences["LiveTest"].StepFunction = GSStaticPriority
      else
        GSMasterSequences["LiveTest"].StepFunction = nil
      end
      GSMasterSequences["LiveTest"].PreMacro = premacrobox:GetText()
      GSMasterSequences["LiveTest"].specID = GSSE:getSpecID()
      GSMasterSequences["LiveTest"].PostMacro = postmacrobox:GetText()
      GSUpdateSequence("LiveTest", GSMasterSequences["LiveTest"])
      GSSE:loadSequence("LiveTest")
      editframe:Hide()
      frame:Show()
    else
      GSSequenceEditorLoaded = true
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

function GSSE:getSpecID(forceSpec)
    GSPrintDebugMessage("Spec = " .. tostring(specradio:GetValue()), GNOME)
    GSPrintDebugMessage("Class = " .. tostring(classradio:GetValue()), GNOME)
    if specradio:GetValue() or forceSpec then
      local currentSpec = GetSpecialization()
      return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or "None"
    else
      local _, _, currentclassId = UnitClass("player")
      return currentclassId
    end
end

function GSSE:getMacroIcon(sequenceIndex)
  GSPrintDebugMessage("sequenceIndex: " .. (GSSE:isempty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
  GSPrintDebugMessage("Icon: " .. (GSSE:isempty(GSMasterSequences[sequenceIndex].icon) and "none" or GSMasterSequences[sequenceIndex].icon))
  if GSSE:isempty(GSMasterSequences[sequenceIndex].icon) then
    GSPrintDebugMessage("SequenceSpecID: " .. GSMasterSequences[sequenceIndex].specID, GNOME)
    local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSSE:isempty(GSMasterSequences[sequenceIndex].specID) and GSSE:getSpecID(true) or GSMasterSequences[sequenceIndex].specID))
    GSPrintDebugMessage("No Sequence Icon setting to " .. (GSSE:isempty(strsub(specicon, 17)) and "No value" or strsub(specicon, 17)), GNOME)
    return strsub(specicon, 17)
  else
    local macindex = GetMacroIndexByName(sequenceIndex)
    local a, iconpath, c =  GetMacroInfo(macindex)
    GSPrintDebugMessage("Macro Found " .. a .. " " .. (GSSE:isempty(iconpath) and "No value" or iconpath) .. " " .. c, GNOME)
--    if GSSE:isempty(iconpath) then
      return GSMasterSequences[sequenceIndex].icon
--    else
--      return iconpath
    end
  end
end

function GSSE:isempty(s)
  return s == nil or s == ''
end

function GSSE:closeEditor()

end

function GSSE:lines(tab, str)
  local function helper(line)
    table.insert(tab, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  GST = t
end

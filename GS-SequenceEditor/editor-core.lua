local GNOME,_ = ...
GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local currentSequence = ""

GSSequenceEditorLoaded = false
local sequenceboxtext = AceGUI:Create("MultiLineEditBox")
local remotesequenceboxtext = AceGUI:Create("MultiLineEditBox")
local boxes = {}

function GSSE:parsetext(editbox, char)
  if char == " " then
    print("char == space")
    --Do Nothing!
  elseif char == string.char(10) or char == string.char(13) then
    print("char == new line")
  else
    print("retranslating")
    text = GSTRUnEscapeString(editbox:GetText())
    print("text = " .. text)
    returntext = GSTranslateString(text .. char, GetLocale(), GetLocale(), true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext)+2)
  end
  --editbox:SetCursorPosition(-1)
end

function GSSE:getSequenceNames()
  local keyset={}
  local n=0

  for k,v in pairs(GSMasterSequences) do
    n=n+1
    keyset[k]=k
  end
  return keyset
end
-- Create functions for tabs
function GSSE:drawstandardwindow(container)
  local sequencebox = AceGUI:Create("MultiLineEditBox")
  sequencebox:SetLabel("Sequence")
  sequencebox:SetNumLines(20)
  sequencebox:DisableButton(true)
  sequencebox:SetFullWidth(true)
  sequencebox:SetText(sequenceboxtext:GetText())
  container:AddChild(sequencebox)

  local updbutton = AceGUI:Create("Button")
  updbutton:SetText("Create / Edit")
  updbutton:SetWidth(200)
  updbutton:SetCallback("OnClick", function() GSSE:updateSequence(currentSequence) end)
  container:AddChild(updbutton)
  sequenceboxtext = sequencebox
end

function GSSE:drawsecondarywindow(container)
  local languages = GSTRListCachedLanguages()
  local listbox = AceGUI:Create("Dropdown")
  listbox:SetLabel("Choose Language")
  listbox:SetWidth(250)
  listbox:SetList(languages)
  listbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadTranslatedSequence(GSTRListCachedLanguages()[key]) end)
  container:AddChild(listbox)

  local remotesequencebox = AceGUI:Create("MultiLineEditBox")
  remotesequencebox:SetLabel("Translated Sequence")
  remotesequencebox:SetText(remotesequenceboxtext:GetText())
  remotesequencebox:SetNumLines(20)
  remotesequencebox:DisableButton(true)
  remotesequencebox:SetFullWidth(true)
  container:AddChild(remotesequencebox)
  remotesequenceboxtext = remotesequencebox

end

-- Callback function for OnGroupSelected
function GSSE:SelectGroup(container, event, group)
   local tremote = remotesequenceboxtext:GetText()
   local tlocal = sequenceboxtext:GetText()
   container:ReleaseChildren()
   GSPrintDebugMessage("Selecting tab: " .. group, GNOME)
   if group == "localtab" then
      GSSE:drawstandardwindow(container)
   elseif group == "remotetab" then
      GSSE:drawsecondarywindow(container)
   end
   remotesequenceboxtext:SetText(tremote)
   sequenceboxtext:SetText(tlocal)
end
-- function that draws the widgets for the first tab


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
--listbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)
frame:AddChild(listbox)



if GSTranslatorAvailable and GSMasterOptions.useTranslator then
  local tab =  AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({{text=GetLocale(), value="localtab"}, {text="Translate to", value="remotetab"}})
  -- Register callback
  tab:SetCallback("OnGroupSelected",  function (container, event, group) GSSE:SelectGroup(container, event, group) end)
  -- Set initial Tab (this will fire the OnGroupSelected callback)
  tab:SelectTab("localtab")
  tab:SetFullWidth(true)
  -- add to the frame container
  frame:AddChild(tab)
else
  GSSE:drawstandardwindow(frame)
end

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
editframe:SetStatusText("Gnome Sequencer: Sequence Editor. Press the Close button to Save -->")
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
--iconpicker:OnClick(MacroPopupButton_SelectTexture(editframe:GetID() + (FauxScrollFrame_GetOffset(MacroPopupScrollFrame) * NUM_ICONS_PER_ROW)))

headerGroup:AddChild(iconpicker)
editframe:AddChild(headerGroup)
editframe:AddChild(specClassGroup)

local premacrobox = AceGUI:Create("MultiLineEditBox")
premacrobox:SetLabel("PreMacro")
premacrobox:SetNumLines(3)
premacrobox:DisableButton(true)
premacrobox:SetFullWidth(true)
--premacrobox.editBox:SetScript("OnLeave", OnTextChanged)

editframe:AddChild(premacrobox)
premacrobox.editBox:SetScript( "OnChar",  function(self, c) GSSE:parsetext(self, c) end)


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

-------------end editor-----------------
-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions



function GSSE:loadTranslatedSequence(key)
  GSPrintDebugMessage("GSTranslateSequenceFromTo(GSMasterSequences[" .. currentSequence .."], (GSisEmpty(GSMasterSequences[" .. currentSequence .. "].lang) and GSMasterSequences[" .. currentSequence .. "].lang or GetLocale()), key)" , GNOME)
  remotesequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterSequences[currentSequence], (GSisEmpty(GSMasterSequences[currentSequence].lang) and GetLocale() or GSMasterSequences[currentSequence].lang ), key), currentSequence))
end

function GSSE:loadSequence(SequenceName)
  GSPrintDebugMessage("GSSE:loadSequence " .. SequenceName)
  if GSTranslatorAvailable and GSMasterOptions.useTranslator then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterSequences[SequenceName], (GSisEmpty(GSMasterSequences[SequenceName].lang) and "enUS" or GSMasterSequences[SequenceName].lang), GetLocale()), SequenceName))
  else
    sequenceboxtext:SetText(GSExportSequence(SequenceName))
  end
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
  if GSisEmpty(SequenceName) then
    local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID(GSSE:getSpecID())
    SequenceName = "LiveTest"
    GSMasterSequences[SequenceName] = {
    specID = GSSE:getSpecID(),
  	author = "Draik",
    icon = 134400,
  	helpTxt = "Completely New GS Macro.",
  	"/cast Auto Attack",
  	}
    GSSE:loadSequence("LiveTest")
  end
  GSPrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
  frame:Hide()
  GSMasterSequences["LiveTest"] = GSMasterSequences[SequenceName]
  GSMasterSequences["LiveTest"].author = GetUnitName("player", true) .. '@' .. GetRealmName()
  reticon = GSSE:getMacroIcon(SequenceName)
  -- if string prefix with "Interface\\Icons\\" if number make it a number
  if not tonumber(reticon) then
    -- we have a starting
    reticon = "Interface\\Icons\\" .. reticon
  end
  GSPrintDebugMessage("returned icon: " .. reticon, GNOME)
  GSMasterSequences["LiveTest"].icon = reticon
  GSUpdateSequence("LiveTest", GSMasterSequences["LiveTest"])
  GSSE:loadSequence("LiveTest")

   -- show editor
  nameeditbox:SetText("LiveTest")
  if GSisEmpty(GSMasterSequences["LiveTest"].StepFunction) then
   stepdropdown:SetValue("1")
  else
   stepdropdown:SetValue("2")
  end
  if GSisEmpty(GSMasterSequences["LiveTest"].PreMacro) then
    GSPrintDebugMessage("Moving on - LiveTest.PreMacro already exists.", GNOME)
  else
   premacrobox:SetText(GSMasterSequences["LiveTest"].PreMacro)
  end
  if GSisEmpty(GSMasterSequences["LiveTest"].PostMacro) then
    GSPrintDebugMessage("Moving on - LiveTest.PosMacro already exists.", GNOME)
  else
   postmacrobox:SetText(GSMasterSequences["LiveTest"].PostMacro)
  end
  spellbox:SetText(table.concat(GSMasterSequences["LiveTest"],"\n"))
  iconpicker:SetImage(GSMasterSequences["LiveTest"].icon)
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
      GSMasterSequences["LiveTest"].helpTxt = "Talents: " .. GSSE:getCurrentTalents()
      if not tonumber(GSMasterSequences["LiveTest"].icon) then
        GSPrintDebugMessage("String Icon " .. GSMasterSequences["LiveTest"].icon .. " Checking for Interface\\Icons\\   strsub value: " .. strsub(GSMasterSequences["LiveTest"].icon,1 , 9), GNOME)
        if strsub(GSMasterSequences["LiveTest"].icon,1 , 9) == "Interface" then
          GSMasterSequences["LiveTest"].icon = strsub(GSMasterSequences["LiveTest"].icon, 17)
        end
      end
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
      if not InCombatLockdown() then
        frame:Show()
      else
        print(GSMasterOptions.TitleColour .. GNOME .. ':|r Please wait till you have left combat before using the Sequence Editor.')
      end
    end
end

function GSSE:OnInitialize()
    frame:Hide()
    editframe:Hide()
    print(GSMasterOptions.TitleColour .. GNOME .. ':|r The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type ' .. GSMasterOptions.CommandColour .. '/gsse |r to get started.')
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
  GSPrintDebugMessage("sequenceIndex: " .. (GSisEmpty(sequenceIndex) and "No value" or sequenceIndex), GNOME)
  GSPrintDebugMessage("Icon: " .. (GSisEmpty(GSMasterSequences[sequenceIndex].icon) and "none" or GSMasterSequences[sequenceIndex].icon))
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSisEmpty(a) then
    GSPrintDebugMessage("Macro Found " .. a .. " with iconid " .. (GSisEmpty(iconid) and "of no value" or iconid) .. " " .. (GSisEmpty(iconid) and "with no body" or c), GNOME)
  else
    GSPrintDebugMessage("No Macro Found. Possibly different spec for Sequence " .. sequenceIndex , GNOME)
  end
  if GSisEmpty(GSMasterSequences[sequenceIndex].icon) and GSisEmpty(iconid) then
    GSPrintDebugMessage("SequenceSpecID: " .. GSMasterSequences[sequenceIndex].specID, GNOME)
    local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSisEmpty(GSMasterSequences[sequenceIndex].specID) and GSSE:getSpecID(true) or GSMasterSequences[sequenceIndex].specID))
    GSPrintDebugMessage("No Sequence Icon setting to " .. (GSisEmpty(strsub(specicon, 17)) and "No value" or strsub(specicon, 17)), GNOME)
    return strsub(specicon, 17)
  elseif GSisEmpty(iconid) and not GSisEmpty(GSMasterSequences[sequenceIndex].icon) then

      return GSMasterSequences[sequenceIndex].icon
  else
      return iconid
  end
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


function GSSE:PLAYER_LOGOUT()
    GSEditorOpt = GSEditorOptions
end

function GSSE:ADDON_LOADED()
  if GSisEmpty(GSEditorOpt) then
    GSEditorOpt = GSEditorOptions
  else
    GSEditorOptions = GSEditorOpt
  end
end

GSSE:RegisterEvent('ADDON_LOADED')
GSSE:RegisterEvent('PLAYER_LOGOUT')

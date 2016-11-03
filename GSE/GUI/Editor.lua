local GNOME,_ = ...

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()


local currentSequence = ""
local importStr = ""
local otherversionlistboxvalue = ""

local editframe = AceGUI:Create("Frame")
local recordframe = AceGUI:Create("Frame")


local boxes = {}
local specdropdownvalue = 0



local viewiconpicker = AceGUI:Create("Icon")

local editOptionsbutton = AceGUI:Create("Button")
editOptionsbutton:SetText(L["Options"])
editOptionsbutton:SetWidth(250)
editOptionsbutton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)

local transbutton = AceGUI:Create("Button")
transbutton:SetText(L["Send"])
transbutton:SetWidth(150)
transbutton:SetCallback("OnClick", function() GSShowTransmissionGui(currentSequence) end)

local iconpicker = AceGUI:Create("Icon")
iconpicker:SetLabel(L["Macro Icon"])
--iconpicker:OnClick(MacroPopupButton_SelectTexture(editframe:GetID() + (FauxScrollFrame_GetOffset(MacroPopupScrollFrame) * NUM_ICONS_PER_ROW)))
iconpicker.frame:RegisterForDrag("LeftButton")
iconpicker.frame:SetScript("OnDragStart", function()
  if not GSE.isEmpty(currentSequence) then
    PickupMacro(currentSequence)
  end
end)
iconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)


viewiconpicker:SetLabel(L["Macro Icon"])
--iconpicker:OnClick(MacroPopupButton_SelectTexture(editframe:GetID() + (FauxScrollFrame_GetOffset(MacroPopupScrollFrame) * NUM_ICONS_PER_ROW)))
viewiconpicker.frame:RegisterForDrag("LeftButton")
viewiconpicker.frame:SetScript("OnDragStart", function()
  if not GSE.isEmpty(currentSequence) then
    PickupMacro(currentSequence)
  end
end)
viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)


-- Create functions for tabs
function GSSE:drawstandardwindow(container)
  sequencebox = AceGUI:Create("MultiLineEditBox")
  sequencebox:SetLabel(L["Sequence"])
  sequencebox:SetNumLines(18)
  sequencebox:DisableButton(true)
  sequencebox:SetFullWidth(true)
  sequencebox:SetText(sequenceboxtext:GetText())
  sequencebox:SetCallback("OnEnter", function() sequencebox:HighlightText(0, string.len(sequencebox:GetText())) end)

  container:AddChild(sequencebox)

  local buttonGroup = AceGUI:Create("SimpleGroup")
  buttonGroup:SetFullWidth(true)
  buttonGroup:SetLayout("Flow")

  local newbutton = AceGUI:Create("Button")
  newbutton:SetText(L["New"])
  newbutton:SetWidth(150)
  newbutton:SetCallback("OnClick", function() GSSE:LoadEditor(nil) end)
  buttonGroup:AddChild(newbutton)

  local updbutton = AceGUI:Create("Button")
  updbutton:SetText(L["Edit"])
  updbutton:SetWidth(150)
  updbutton:SetCallback("OnClick", function() GSSE:LoadEditor(currentSequence) end)
  buttonGroup:AddChild(updbutton)

  local impbutton = AceGUI:Create("Button")
  impbutton:SetText(L["Import"])
  impbutton:SetWidth(150)
  impbutton:SetCallback("OnClick", function() importStr = sequenceboxtext:GetText(); GSSE:importSequence() end)
  buttonGroup:AddChild(impbutton)

  local tranbutton = AceGUI:Create("Button")
  tranbutton:SetText(L["Send"])
  tranbutton:SetWidth(150)
  tranbutton:SetCallback("OnClick", function() GSShowTransmissionGui(currentSequence) end)
  buttonGroup:AddChild(tranbutton)

  local versbutton = AceGUI:Create("Button")
  versbutton:SetText(L["Manage Versions"])
  versbutton:SetWidth(150)
  versbutton:SetCallback("OnClick", function() GSSE:ManageSequenceVersion() end)
  buttonGroup:AddChild(versbutton)

  disableSeqbutton = AceGUI:Create("Button")
  disableSeqbutton:SetText(L["Disable Sequence"])
  disableSeqbutton:SetWidth(150)
  disableSeqbutton:SetCallback("OnClick", function() GSSE:DisableSequence(currentSequence) end)
  buttonGroup:AddChild(disableSeqbutton)

  local eOptionsbutton = AceGUI:Create("Button")
  eOptionsbutton:SetText(L["Options"])
  eOptionsbutton:SetWidth(150)
  eOptionsbutton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)
  buttonGroup:AddChild(eOptionsbutton)

  local recordwindowbutton = AceGUI:Create("Button")
  recordwindowbutton:SetText(L["Record Macro"])
  recordwindowbutton:SetWidth(150)
  recordwindowbutton:SetCallback("OnClick", function() frame:Hide(); recordframe:Show() end)
  buttonGroup:AddChild(recordwindowbutton)

  container:AddChild(buttonGroup)

  sequenceboxtext = sequencebox
end

function GSSE:drawsecondarywindow(container)
  local languages = GSTRListCachedLanguages()
  local listbox = AceGUI:Create("Dropdown")
  listbox:SetLabel(L["Choose Language"])
  listbox:SetWidth(150)
  listbox:SetList(languages)
  listbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadTranslatedSequence(GSTRListCachedLanguages()[key]) end)
  container:AddChild(listbox)

  local remotesequencebox = AceGUI:Create("MultiLineEditBox")
  remotesequencebox:SetLabel(L["Translated Sequence"])
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
   GSE.PrintDebugMessage(L["Selecting tab: "] .. group, GNOME)
   if group == "localtab" then
      GSSE:drawstandardwindow(container)
   elseif group == "remotetab" then
      GSSE:drawsecondarywindow(container)
   end
   remotesequenceboxtext:SetText(tremote)
   sequenceboxtext:SetText(tlocal)
end
-- function that draws the widgets for the first tab



local curentSequence
frame:SetTitle(L["Sequence Viewer"])
frame:SetStatusText(L["Gnome Sequencer: Sequence Viewer"])
frame:SetCallback("OnClose", function(widget) frame:Hide() end)
frame:SetLayout("List")
GSSE.viewframe = frame
GSSE.editframe = editframe

local viewerheadergroup = AceGUI:Create("SimpleGroup")
viewerheadergroup:SetFullWidth(true)
viewerheadergroup:SetLayout("Flow")


GSSequenceListbox = AceGUI:Create("Dropdown")
GSSequenceListbox:SetLabel(L["Load Sequence"])
GSSequenceListbox:SetWidth(250)
GSSequenceListbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)

local spacerlabel = AceGUI:Create("Label")
spacerlabel:SetWidth(300)
viewerheadergroup:AddChild(GSSequenceListbox)
viewerheadergroup:AddChild(spacerlabel)
viewerheadergroup:AddChild(viewiconpicker)
frame:AddChild(viewerheadergroup)



if GSTranslatorAvailable and GSEOptions.useTranslator and GSAdditionalLanguagesAvailable then
  local tab =  AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({{text=GetLocale(), value="localtab"}, {text=L["Translate to"], value="remotetab"}})
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

local stepvalue = 1

editscroll = AceGUI:Create("ScrollFrame")
editscroll:SetLayout("Flow") -- probably?
editscroll:SetFullWidth(true)
editscroll:SetHeight(340)


local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")

local firstheadercolumn = AceGUI:Create("SimpleGroup")
--firstheadercolumn:SetFullWidth(true)
firstheadercolumn:SetLayout("List")

editframe:SetTitle(L["Sequence Editor"])
--editframe:SetStatusText(L["Gnome Sequencer: Sequence Editor."])
editframe:SetCallback("OnClose", function (self) editframe:Hide();  frame:Show(); end)
editframe:SetLayout("List")

local nameeditbox = AceGUI:Create("EditBox")
nameeditbox:SetLabel(L["Sequence Name"])
nameeditbox:SetWidth(250)
nameeditbox:SetCallback("OnTextChanged", function(self) currentSequence = self:GetText(); end)
nameeditbox:DisableButton( true)


firstheadercolumn:AddChild(nameeditbox)


local stepdropdown = AceGUI:Create("Dropdown")
stepdropdown:SetLabel(L["Step Function"])
stepdropdown:SetWidth(250)
stepdropdown:SetList({
  ["1"] = L["Sequential (1 2 3 4)"],
  ["2"] = L["Priority List (1 12 123 1234)"],

})

stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key; GSE.PrintDebugMessage("StepValue Set: " .. stepvalue, GNOME) end)
firstheadercolumn:AddChild(stepdropdown)

headerGroup:AddChild(firstheadercolumn)

local middleColumn = AceGUI:Create("SimpleGroup")
middleColumn:SetWidth(252)
middleColumn:SetLayout("List")


GSSE:getSpecNames()

local speciddropdown = AceGUI:Create("Dropdown")
speciddropdown:SetLabel(L["Specialisation / Class ID"])
speciddropdown:SetWidth(250)
speciddropdown:SetList(GSSE:getSpecNames())
speciddropdown:SetCallback("OnValueChanged", function (obj,event,key) specdropdownvalue = key;  end)

local helpeditbox = AceGUI:Create("EditBox")
helpeditbox:SetLabel(L["Help Information"])
helpeditbox:SetWidth(250)
helpeditbox:DisableButton( true)

middleColumn:AddChild(helpeditbox)
middleColumn:AddChild(speciddropdown)

headerGroup:AddChild(middleColumn)
headerGroup:AddChild(iconpicker)
editframe:AddChild(headerGroup)



local KeyPressbox = AceGUI:Create("MultiLineEditBox")
KeyPressbox:SetLabel(L["KeyPress"])
KeyPressbox:SetNumLines(2)
KeyPressbox:DisableButton(true)
KeyPressbox:SetFullWidth(true)
--KeyPressbox.editBox:SetScript("OnLeave", OnTextChanged)

editscroll:AddChild(KeyPressbox)
KeyPressbox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
KeyPressbox.editBox:SetScript("OnTextChanged", function () end)

local spellbox = AceGUI:Create("MultiLineEditBox")
spellbox:SetLabel(L["Sequence"])
spellbox:SetNumLines(10)
spellbox:DisableButton(true)
spellbox:SetFullWidth(true)
spellbox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
spellbox.editBox:SetScript("OnTextChanged", function () end)

local loopGroup = AceGUI:Create("SimpleGroup")
loopGroup:SetFullWidth(true)
loopGroup:SetLayout("Flow")

editscroll:AddChild(loopGroup)

local loopstart = AceGUI:Create("EditBox")
loopstart:SetLabel(L["Inner Loop Start"])
loopstart:DisableButton(true)
loopstart:SetMaxLetters(3)
loopstart.editbox:SetNumeric()
loopGroup:AddChild(loopstart)

local loopstop = AceGUI:Create("EditBox")
loopstop:SetLabel(L["Inner Loop End"])
loopstop:DisableButton(true)
loopstop:SetMaxLetters(3)
loopstop.editbox:SetNumeric()
loopGroup:AddChild(loopstop)

local looplimit = AceGUI:Create("EditBox")
looplimit:SetLabel(L["Inner Loop Limit"])
looplimit:DisableButton(true)
looplimit:SetMaxLetters(4)
looplimit.editbox:SetNumeric()
loopGroup:AddChild(looplimit)
editscroll:AddChild(spellbox)


local KeyReleasebox = AceGUI:Create("MultiLineEditBox")
KeyReleasebox:SetLabel(L["KeyRelease"])
KeyReleasebox:SetNumLines(2)
KeyReleasebox:DisableButton(true)
KeyReleasebox:SetFullWidth(true)
KeyReleasebox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
KeyReleasebox.editBox:SetScript("OnTextChanged", function () end)

editscroll:AddChild(KeyReleasebox)
editframe:AddChild(editscroll)

local editButtonGroup = AceGUI:Create("SimpleGroup")
editButtonGroup:SetWidth(302)
editButtonGroup:SetLayout("Flow")

local savebutton = AceGUI:Create("Button")
savebutton:SetText(L["Save"])
savebutton:SetWidth(150)
savebutton:SetCallback("OnClick", function() GSSE:UpdateSequenceDefinition(currentSequence) end)
editButtonGroup:AddChild(savebutton)

editButtonGroup:AddChild(transbutton)



editframe:AddChild(editButtonGroup)
-------------end editor-----------------

local versionframe = AceGUI:Create("Frame")
versionframe:SetTitle(L["Manage Versions"])
versionframe:SetStatusText(L["Gnome Sequencer: Sequence Version Manager"])
versionframe:SetCallback("OnClose", function(widget)  versionframe:Hide(); frame:Show() end)
versionframe:SetLayout("List")

local columnGroup = AceGUI:Create("SimpleGroup")
columnGroup:SetFullWidth(true)
columnGroup:SetLayout("Flow")

local leftGroup = AceGUI:Create("SimpleGroup")
leftGroup:SetFullWidth(true)
leftGroup:SetLayout("List")

local rightGroup = AceGUI:Create("SimpleGroup")
rightGroup:SetFullWidth(true)
rightGroup:SetLayout("List")

local activesequencebox = AceGUI:Create("MultiLineEditBox")
activesequencebox:SetLabel(L["Active Version: "])
activesequencebox:SetNumLines(10)
activesequencebox:DisableButton(true)
activesequencebox:SetFullWidth(true)
leftGroup:AddChild(activesequencebox)

local otherversionlistbox = AceGUI:Create("Dropdown")
otherversionlistbox:SetLabel(L["Select Other Version"])
otherversionlistbox:SetWidth(150)
otherversionlistbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:ChangeOtherSequence(key) end)
rightGroup:AddChild(otherversionlistbox)

local otherSequenceVersions = AceGUI:Create("MultiLineEditBox")
otherSequenceVersions:SetNumLines(11)
otherSequenceVersions:DisableButton(true)
otherSequenceVersions:SetFullWidth(true)
rightGroup:AddChild(otherSequenceVersions)

columnGroup:AddChild(leftGroup)
columnGroup:AddChild(rightGroup)

versionframe:AddChild(columnGroup)

local othersequencebuttonGroup = AceGUI:Create("SimpleGroup")
othersequencebuttonGroup:SetFullWidth(true)
othersequencebuttonGroup:SetLayout("Flow")

local actbutton = AceGUI:Create("Button")
actbutton:SetText(L["Make Active"])
actbutton:SetWidth(150)
actbutton:SetCallback("OnClick", function() GSSE:SetActiveSequence(otherversionlistboxvalue) end)
othersequencebuttonGroup:AddChild(actbutton)

local delbutton = AceGUI:Create("Button")
delbutton:SetText(L["Delete Version"])
delbutton:SetWidth(150)
delbutton:SetCallback("OnClick", function()
  if not GSE.isEmpty(otherversionlistboxvalue) then
    GSDeleteSequenceVersion(currentSequence, otherversionlistboxvalue)
    otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
    otherSequenceVersions:SetText("")
  end
end)
othersequencebuttonGroup:AddChild(delbutton)


versionframe:AddChild(othersequencebuttonGroup)
-- Record Frame

recordframe:SetTitle(L["Record Macro"])
recordframe:SetStatusText(L["Gnome Sequencer: Record your rotation to a macro."])
recordframe:SetCallback("OnClose", function(widget)  frame:Hide(); end)
recordframe:SetLayout("List")

local recordsequencebox = AceGUI:Create("MultiLineEditBox")
recordsequencebox:SetLabel(L["Actions"])
recordsequencebox:SetNumLines(20)
recordsequencebox:DisableButton(true)
recordsequencebox:SetFullWidth(true)
recordframe:AddChild(recordsequencebox)

local recButtonGroup = AceGUI:Create("SimpleGroup")
recButtonGroup:SetLayout("Flow")


local recbutton = AceGUI:Create("Button")
recbutton:SetText(L["Record"])
recbutton:SetWidth(150)
recbutton:SetCallback("OnClick", function() GSSE:ManageRecord() end)
recButtonGroup:AddChild(recbutton)

local createmacrobutton = AceGUI:Create("Button")
createmacrobutton:SetText(L["Create Macro"])
createmacrobutton:SetWidth(150)
createmacrobutton:SetCallback("OnClick", function() GSSE:SaveRecordMacro() end)
createmacrobutton:SetDisabled(true)
recButtonGroup:AddChild(createmacrobutton)

recordframe:AddChild(recButtonGroup)


-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

function GSSE:SaveRecordMacro()
  GSSE:LoadEditor( nil, recordsequencebox:GetText())
  recordframe:Hide()

end
local recbuttontext = L["Record"]
function GSSE:ManageRecord()
  if recbuttontext == L["Record"] then
    GSSE:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
    recbuttontext = L["Stop"]
    createmacrobutton:SetDisabled(false)
  else
    recbuttontext = L["Record"]
    GSSE:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED')
  end
  recbutton:SetText(recbuttontext)
end

function GSSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
  if unit ~= "player" then  return end
  recordsequencebox:SetText(recordsequencebox:GetText() .. "/cast " .. spell .. "\n")
end

-- Functions
function GSSE:SetActiveSequence(key)
  GSSetActiveSequenceVersion(currentSequence, key)
  GSUpdateSequence(currentSequence, GSEOptions.SequenceLibrary[currentSequence][key])
  activesequencebox:SetLabel(L["Active Version: "] .. GSGetActiveSequenceVersion(currentSequence) )
  activesequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], GetLocale(), GetLocale()), currentSequence))
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
end

function GSSE:ChangeOtherSequence(key)
  otherversionlistboxvalue = key
  otherSequenceVersions:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[currentSequence][key], (GSE.isEmpty(GSEOptions.SequenceLibrary[currentSequence][key].lang) and GetLocale() or GSEOptions.SequenceLibrary[currentSequence][key].lang ), GetLocale()), currentSequence))
end

function GSUpdateSequenceList()
  local names = GSSE:getSequenceNames()
  GSSequenceListbox:SetList(names)
end

function GSSE:ManageSequenceVersion()
  frame:Hide()
  versionframe:SetTitle(L["Manage Versions"] .. ": " .. currentSequence )
  activesequencebox:SetLabel(L["Active Version: "] .. GSGetActiveSequenceVersion(currentSequence) )
  activesequencebox:SetText(sequenceboxtext:GetText())
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
  versionframe:Show()
end

function GSSE:loadTranslatedSequence(key)
  GSE.PrintDebugMessage(L["GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary["] .. currentSequence .. L["], (GSE.isEmpty(GSEOptions.SequenceLibrary["] .. currentSequence .. L["].lang) and GSEOptions.SequenceLibrary["] .. currentSequence .. L["].lang or GetLocale()), key)"] , GNOME)
  remotesequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], (GSE.isEmpty(GSEOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang) and "enUS" or GSEOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang ), key), currentSequence))
end

function GSSE:loadSequence(SequenceName)
  GSE.PrintDebugMessage(L["GSSE:loadSequence "] .. SequenceName)
  if GSAdditionalLanguagesAvailable and GSEOptions.useTranslator then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)], (GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].lang) and "enUS" or GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].lang), GetLocale()), SequenceName))
  elseif GSTranslatorAvailable then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)], GetLocale(), GetLocale()), SequenceName))
  else
    sequenceboxtext:SetText(GSExportSequence(SequenceName))
  end
  if GSEOptions.DisabledSequences[SequenceName] then
    disableSeqbutton:SetText(L["Enable Sequence"])
    viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
    reticon = GSSE:getMacroIcon(SequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    viewiconpicker:SetImage(reticon)
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

function GSSE:LoadEditor(SequenceName, recordstring)
  if not GSE.isEmpty(SequenceName) then
    nameeditbox:SetText(SequenceName)
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].StepFunction) then
     stepdropdown:SetValue("1")
     stepvalue = 1
    else
     stepdropdown:SetValue("2")
     stepvalue = 2
    end
    GSE.PrintDebugMessage("StepValue: " .. stepvalue, GNOME)
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PreMacro) then
      GSE.PrintDebugMessage(L["Moving on - LiveTest.PreMacro already exists."], GNOME)
    else
     premacrobox:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PreMacro)
    end
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PostMacro) then
      GSE.PrintDebugMessage(L["Moving on - LiveTest.PosMacro already exists."], GNOME)
    else
     postmacrobox:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PostMacro)
    end
    spellbox:SetText(table.concat(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)],"\n"))
    reticon = GSSE:getMacroIcon(SequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].helpTxt) then
      helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
    else
      helpeditbox:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].helpTxt)
    end
    iconpicker:SetImage(reticon)
    GSE.PrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
    speciddropdown:SetValue(GSSpecIDList[GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID])
    specdropdownvalue = GSSpecIDList[GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID]
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].loopstart) then
      loopstart:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].loopstart)
    end
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].loopstop) then
      loopstop:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].loopstop)
    end
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].looplimit) then
      looplimit:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].looplimit)
    end
  elseif not GSE.isEmpty(recordstring) then
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
    helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
    spellbox:SetText(recordstring)
  else
    GSE.PrintDebugMessage(L["No Sequence Icon setting to "] , GNOME)
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
    helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
  end
  frame:Hide()
  editframe:Show()

end

function GSSE:UpdateSequenceDefinition(SequenceName)
  -- Changes have been made so save them
  if not GSE.isEmpty(SequenceName) then
    nextVal = GSGetNextSequenceVersion(currentSequence)
    local sequence = {}
    GSSE:lines(sequence, spellbox:GetText())
    -- update sequence
    if tonumber(stepvalue) == 2 then
      sequence.StepFunction = GSStaticPriority
      GSE.PrintDebugMessage("Setting GSStaticPriority.  Inside the Logic Point")
    else
      sequence.StepFunction = nil
    end
    GSE.PrintDebugMessage("StepValue Saved: " .. stepvalue, GNOME)
    sequence.PreMacro = premacrobox:GetText()
    sequence.author = GetUnitName("player", true) .. '@' .. GetRealmName()
    sequence.source = GSStaticSourceLocal
    sequence.specID = GSSpecIDHashList[specdropdownvalue]
    sequence.helpTxt = helpeditbox:GetText()
    if not tonumber(sequence.icon) then
      sequence.icon = "INV_MISC_QUESTIONMARK"
    end
    if not GSE.isEmpty(loopstart:GetText()) then
      sequence.loopstart = loopstart:GetText()
    end
    if not GSE.isEmpty(loopstop:GetText()) then
      sequence.loopstop = loopstop:GetText()
    end
    if not GSE.isEmpty(looplimit:GetText()) then
      sequence.looplimit = looplimit:GetText()
    end
    sequence.PostMacro = postmacrobox:GetText()
    sequence.version = nextVal
    GSTRUnEscapeSequence(sequence)
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName]) then
      -- this is new
      GSE.PrintDebugMessage(L["Creating New Sequence."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSEOptions.SequenceLibrary[SequenceName][nextVal])
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(SequenceName)
      GSE.Print(L["Sequence Saved as version "] .. nextVal, GNOME)
    else
      GSE.PrintDebugMessage(L["Updating due to new version."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSEOptions.SequenceLibrary[SequenceName][nextVal])
      GSE.Print(L["Sequence Saved as version "] .. nextVal, GNOME)
    end

  end
end

function GSGuiShowViewer()
  if not InCombatLockdown() then
    currentSequence = ""
    local names = GSSE:getSequenceNames()
    GSSequenceListbox:SetList(names)
    sequenceboxtext:SetText("")
    frame:Show()
  else
    GSE.Print(L["Please wait till you have left combat before using the Sequence Editor."], GNOME)
  end

end

function GSSE:GSSlash(input)
    if input == "hide" then
      frame:Hide()
    elseif input == "record" then
      recordframe:Show()
    elseif input == "debug" then
      GSShowDebugWindow()
    else
      GSGuiShowViewer()
    end
end



function GSSE:OnInitialize()
    recordframe:Hide()
    versionframe:Hide()
    editframe:Hide()
    frame:Hide()
    GSE.Print(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSEOptions.CommandColour .. L["/gsse |r to get started."], GNOME)
end

function GSSE:getCurrentTalents()
  local talents = ""
  for talentTier = 1, MAX_TALENT_TIERS do
    local available, selected = GetTalentTierInfo(talentTier, 1)
    talents = talents .. (available and selected or "?" .. ",")
  end
  return talents
end

function GSSE:getMacroIcon(sequenceIndex)
  GSE.PrintDebugMessage(L["sequenceIndex: "] .. (GSE.isEmpty(sequenceIndex) and L["No value"] or sequenceIndex), GNOME)
  if not GSE.isEmpty(GSGetActiveSequenceVersion(currentSequence)) then
    if not GSE.isEmpty(GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) then
      GSE.PrintDebugMessage(L["Icon: "] .. GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon, GNOME)
    else
      GSE.PrintDebugMessage(L["Icon: "] .. L["none"], GNOME)
    end
  end
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSE.isEmpty(a) then
    GSE.PrintDebugMessage(L["Macro Found "] .. a .. L[" with iconid "] .. (GSE.isEmpty(iconid) and L["of no value"] or iconid) .. " " .. (GSE.isEmpty(iconid) and L["with no body"] or c), GNOME)
  else
    GSE.PrintDebugMessage(L["No Macro Found. Possibly different spec for Sequence "] .. sequenceIndex , GNOME)
  end
  if GSE.isEmpty(GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) and GSE.isEmpty(iconid) then
    GSE.PrintDebugMessage("SequenceSpecID: " .. GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID, GNOME)
    if GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID == 0 then
      return "INV_MISC_QUESTIONMARK"
    else
      local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSE.isEmpty(GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID) and GSE.GetCurrentSpecID() or GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID))
      GSE.PrintDebugMessage(L["No Sequence Icon setting to "] .. strsub(specicon, 17), GNOME)
      return strsub(specicon, 17)
    end
  elseif GSE.isEmpty(iconid) and not GSE.isEmpty(GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) then

      return GSEOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon
  else
      return iconid
  end
end

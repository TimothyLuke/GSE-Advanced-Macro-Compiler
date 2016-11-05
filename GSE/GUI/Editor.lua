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



-- Create functions for tabs



-- function that draws the widgets for the first tab





GSE.GUI.editframe = editframe


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


local speciddropdown = AceGUI:Create("Dropdown")
speciddropdown:SetLabel(L["Specialisation / Class ID"])
speciddropdown:SetWidth(250)
speciddropdown:SetList(GSE.GetSpecNames())
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

-- Slash Commands

GSE:RegisterChatCommand("gsse", "GSSlash")

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
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].KeyPress) then
      GSE.PrintDebugMessage(L["Moving on - LiveTest.KeyPress already exists."], GNOME)
    else
     KeyPressbox:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].KeyPress)
    end
    if GSE.isEmpty(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].KeyRelease) then
      GSE.PrintDebugMessage(L["Moving on - LiveTest.PosMacro already exists."], GNOME)
    else
     KeyReleasebox:SetText(GSEOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].KeyRelease)
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
    sequence.KeyPress = KeyPressbox:GetText()
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
    sequence.KeyRelease = KeyReleasebox:GetText()
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

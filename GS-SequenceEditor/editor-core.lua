local GNOME,_ = ...
GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = GSL
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local currentSequence = ""
local importStr = ""
local otherversionlistboxvalue = ""
local frame = AceGUI:Create("Frame")
local editframe = AceGUI:Create("Frame")

local sequenceboxtext = AceGUI:Create("MultiLineEditBox")
local remotesequenceboxtext = AceGUI:Create("MultiLineEditBox")
local boxes = {}
local specdropdownvalue = 0

function GSGetDefaultIcon()
  local currentSpec = GetSpecialization()
  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or ""
  local _, _, _, defaulticon, _, _, _ = GetSpecializationInfoByID(currentSpecID)
  return strsub(defaulticon, 17)
end

function GSSE:parsetext(editbox)
  if GSMasterOptions.RealtimeParse then
    text = GSTRUnEscapeString(editbox:GetText())
    returntext = GSTranslateString(text , GetLocale(), GetLocale(), true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext)+2)
  end
end


function GSSE:getSequenceNames()
  local keyset={}
  local currentSpec = GetSpecialization()
  local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or ""
  if not GSisEmpty(currentSpecID) then
    local _, _, _, _, _, _, pspecclass = GetSpecializationInfoByID(currentSpecID)
    for k,v in pairs(GSMasterOptions.ActiveSequenceVersions) do
      --print (table.getn(GSMasterOptions.SequenceLibrary[k]))
      if not GSisEmpty(GSMasterOptions.SequenceLibrary[k]) then
        local sid, specname, specdescription, specicon, sbackground, specrole, specclass = GetSpecializationInfoByID(GSMasterOptions.SequenceLibrary[k][v].specID)
        if GSMasterOptions.filterList["All"] then
          keyset[k]=k
        elseif GSMasterOptions.SequenceLibrary[k][v].specID == 0 then
          keyset[k]=k
        elseif GSMasterOptions.filterList["Class"]  then
          if pspecclass == specclass then
            keyset[k]=k
          end
        elseif GSMasterOptions.SequenceLibrary[k][v].specID == currentSpecID then
          keyset[k]=k
        else
          -- do nothing
          GSPrintDebugMessage (k .. L[" not added to list."], "GS-SequenceEditor")
        end
      else
        GSPrint(L["No Sequences present so none displayed in the list."] .. ' ' .. k, GNOME)
      end
    end
  end
  -- Filter Keyset
  return keyset
end

function GSSE:getSpecNames()
  local keyset={}
  for k,v in pairs(GSSpecIDList) do
    keyset[v] = v
  end
  return keyset
end

function GSSE:DisableSequence(currentSeq)
  GSToggleDisabledSequence(currentSeq)
  if GSMasterOptions.DisabledSequences[currentSeq] then
    disableSeqbutton:SetText(L["Enable Sequence"])
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
  end
  sequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)], (GSisEmpty(GSMasterOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)].lang) and "enUS" or GSMasterOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)].lang), GetLocale()), currentSeq))
end

local editOptionsbutton = AceGUI:Create("Button")
editOptionsbutton:SetText(L["Options"])
editOptionsbutton:SetWidth(250)
editOptionsbutton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)

local transbutton = AceGUI:Create("Button")
transbutton:SetText(L["Send"])
transbutton:SetWidth(150)
transbutton:SetCallback("OnClick", function() GSShowTransmissionGui(currentSequence) end)


-- Create functions for tabs
function GSSE:drawstandardwindow(container)
  sequencebox = AceGUI:Create("MultiLineEditBox")
  sequencebox:SetLabel(L["Sequence"])
  sequencebox:SetNumLines(20)
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
   GSPrintDebugMessage(L["Selecting tab: "] .. group, GNOME)
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

GSSequenceListbox = AceGUI:Create("Dropdown")
GSSequenceListbox:SetLabel(L["Load Sequence"])
GSSequenceListbox:SetWidth(250)
GSSequenceListbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)
frame:AddChild(GSSequenceListbox)



if GSTranslatorAvailable and GSMasterOptions.useTranslator and GSAdditionalLanguagesAvailable then
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

editscrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
editscrollcontainer:SetFullWidth(true)
editscrollcontainer:SetFullHeight(true) -- probably?
editscrollcontainer:SetLayout("Fill") -- important!

editscroll = AceGUI:Create("ScrollFrame")
editscroll:SetLayout("Flow") -- probably?
editscrollcontainer:AddChild(editscroll)


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
editframe:AddChild(editscrollcontainer)

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

stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key; GSPrintDebugMessage("StepValue Set: " .. stepvalue, GNOME) end)
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


local iconpicker = AceGUI:Create("Icon")
--iconpicker:SetImage()
iconpicker:SetLabel(L["Macro Icon"])
--iconpicker:OnClick(MacroPopupButton_SelectTexture(editframe:GetID() + (FauxScrollFrame_GetOffset(MacroPopupScrollFrame) * NUM_ICONS_PER_ROW)))
headerGroup:AddChild(middleColumn)
headerGroup:AddChild(iconpicker)
editscroll:AddChild(headerGroup)



local premacrobox = AceGUI:Create("MultiLineEditBox")
premacrobox:SetLabel(L["PreMacro"])
premacrobox:SetNumLines(2)
premacrobox:DisableButton(true)
premacrobox:SetFullWidth(true)
--premacrobox.editBox:SetScript("OnLeave", OnTextChanged)

editscroll:AddChild(premacrobox)
premacrobox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
premacrobox.editBox:SetScript("OnTextChanged", function () end)

local spellbox = AceGUI:Create("MultiLineEditBox")
spellbox:SetLabel(L["Sequence"])
spellbox:SetNumLines(10)
spellbox:DisableButton(true)
spellbox:SetFullWidth(true)
spellbox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
spellbox.editBox:SetScript("OnTextChanged", function () end)
editscroll:AddChild(spellbox)

local loopGroup = AceGUI:Create("SimpleGroup")
loopGroup:SetFullWidth(true)
loopGroup:SetLayout("Flow")

editscroll:AddChild(loopGroup)

local loopstart = AceGUI:Create("MultiLineEditBox")
loopstart:SetLabel(L["Inner Loop Start"])
loopstart:DisableButton(true)
loopstart:SetMaxLetters(3)
loopstart:SetNumeric()
loopGroup:AddChild(loopstart)

local loopstop = AceGUI:Create("MultiLineEditBox")
loopstop:SetLabel(L["Inner Loop End"])
loopstop:DisableButton(true)
loopstop:SetMaxLetters(3)
loopstop:SetNumeric()
loopGroup:AddChild(loopstop)

local looplimit = AceGUI:Create("MultiLineEditBox")
looplimit:SetLabel(L["Inner Loop Limit"])
looplimit:DisableButton(true)
looplimit:SetMaxLetters(4)
looplimit:SetNumeric()
loopGroup:AddChild(looplimit)


local postmacrobox = AceGUI:Create("MultiLineEditBox")
postmacrobox:SetLabel(L["PostMacro"])
postmacrobox:SetNumLines(2)
postmacrobox:DisableButton(true)
postmacrobox:SetFullWidth(true)
postmacrobox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
postmacrobox.editBox:SetScript("OnTextChanged", function () end)

editscroll:AddChild(postmacrobox)

local editButtonGroup = AceGUI:Create("SimpleGroup")
editButtonGroup:SetWidth(302)
editButtonGroup:SetLayout("Flow")

local savebutton = AceGUI:Create("Button")
savebutton:SetText(L["Save"])
savebutton:SetWidth(150)
savebutton:SetCallback("OnClick", function() GSSE:UpdateSequenceDefinition(currentSequence) end)
editButtonGroup:AddChild(savebutton)

editButtonGroup:AddChild(transbutton)



editscroll:AddChild(editButtonGroup)
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
  if not GSisEmpty(otherversionlistboxvalue) then
    GSDeleteSequenceVersion(currentSequence, otherversionlistboxvalue)
    otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
    otherSequenceVersions:SetText("")
  end
end)
othersequencebuttonGroup:AddChild(delbutton)



versionframe:AddChild(othersequencebuttonGroup)

-- Slash Commands

GSSE:RegisterChatCommand("gsse", "GSSlash")

-- Functions
function GSSE:SetActiveSequence(key)
  GSSetActiveSequenceVersion(currentSequence, key)
  GSUpdateSequence(currentSequence, GSMasterOptions.SequenceLibrary[currentSequence][key])
  activesequencebox:SetLabel(L["Active Version: "] .. GSGetActiveSequenceVersion(currentSequence) )
  activesequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], GetLocale(), GetLocale()), currentSequence))
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
end

function GSSE:ChangeOtherSequence(key)
  otherversionlistboxvalue = key
  otherSequenceVersions:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[currentSequence][key], (GSisEmpty(GSMasterOptions.SequenceLibrary[currentSequence][key].lang) and GetLocale() or GSMasterOptions.SequenceLibrary[currentSequence][key].lang ), GetLocale()), currentSequence))
end

function GSUpdateSequenceList()
  local names = GSSE:getSequenceNames()
  GSSequenceListbox:SetList(names)
end

function GSSE:importSequence()
  local functiondefinition =  importStr .. [===[

  return Sequences
  ]===]
  GSPrintDebugMessage (functiondefinition, "GS-SequenceEditor")
  local fake_globals = setmetatable({
    Sequences = {},
    }, {__index = _G})
  local func, err = loadstring (functiondefinition, "GS-SequenceEditor")
  if func then
    -- Make the compiled function see this table as its "globals"
    setfenv (func, fake_globals)

    local TempSequences = assert(func())
    if not GSisEmpty(TempSequences) then
      local newkey = ""
      for k,v in pairs(TempSequences) do

        if GSisEmpty(v.version) then
          v.version = GSGetNextSequenceVersion(k)
        end
        v.source = GSStaticSourceLocal
        GSAddSequenceToCollection(k, v, v.version)
        GSUpdateSequence(k, GSMasterOptions.SequenceLibrary[k][v.version])
        if GSisEmpty(v.icon) then
          -- Set a default icon
          v.icon = GSGetDefaultIcon()
        end
        GSCheckMacroCreated(k)
        newkey = k
        GSPrint(L["Imported new sequence "] .. k, GNOME)
      end
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(newkey)

    end
  else
    GSPrintDebugMessage (err, GNOME)
  end

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
  GSPrintDebugMessage(L["GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary["] .. currentSequence .. L["], (GSisEmpty(GSMasterOptions.SequenceLibrary["] .. currentSequence .. L["].lang) and GSMasterOptions.SequenceLibrary["] .. currentSequence .. L["].lang or GetLocale()), key)"] , GNOME)
  remotesequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], (GSisEmpty(GSMasterOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang) and "enUS" or GSMasterOptions.SequenceLibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang ), key), currentSequence))
end

function GSSE:loadSequence(SequenceName)
  GSPrintDebugMessage(L["GSSE:loadSequence "] .. SequenceName)
  if GSAdditionalLanguagesAvailable and GSMasterOptions.useTranslator then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)], (GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].lang) and "enUS" or GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].lang), GetLocale()), SequenceName))
  elseif GSTranslatorAvailable then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)], GetLocale(), GetLocale()), SequenceName))
  else
    sequenceboxtext:SetText(GSExportSequence(SequenceName))
  end
  if GSMasterOptions.DisabledSequences[SequenceName] then
    disableSeqbutton:SetText(L["Enable Sequence"])
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
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

function GSSE:LoadEditor(SequenceName)
  if not GSisEmpty(SequenceName) then
    nameeditbox:SetText(SequenceName)
    if GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].StepFunction) then
     stepdropdown:SetValue("1")
     stepvalue = 1
    else
     stepdropdown:SetValue("2")
     stepvalue = 2
    end
    GSPrintDebugMessage("StepValue: " .. stepvalue, GNOME)
    if GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PreMacro) then
      GSPrintDebugMessage(L["Moving on - LiveTest.PreMacro already exists."], GNOME)
    else
     premacrobox:SetText(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PreMacro)
    end
    if GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PostMacro) then
      GSPrintDebugMessage(L["Moving on - LiveTest.PosMacro already exists."], GNOME)
    else
     postmacrobox:SetText(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].PostMacro)
    end
    spellbox:SetText(table.concat(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)],"\n"))
    reticon = GSSE:getMacroIcon(SequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    if GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].helpTxt) then
      helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
    else
      helpeditbox:SetText(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].helpTxt)
    end
    iconpicker:SetImage(reticon)
    GSPrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
    speciddropdown:SetValue(GSSpecIDList[GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID])
    specdropdownvalue = GSSpecIDList[GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID]
    if not GSisEmpty(sequence.loopstart) then
      loopstart.SetText(sequence.loopstart)
    end
    if not GSisEmpty(sequence.loopstop) then
      loopstart.SetText(sequence.loopstop)
    end
    if not GSisEmpty(sequence.looplimit) then
      loopstart.SetText(sequence.looplimit)
    end
  else
    GSPrintDebugMessage(L["No Sequence Icon setting to "] , GNOME)
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
    helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
  end
  frame:Hide()
  editframe:Show()

end

function GSSE:UpdateSequenceDefinition(SequenceName)
  -- Changes have been made so save them
  if not GSisEmpty(SequenceName) then
    nextVal = GSGetNextSequenceVersion(currentSequence)
    local sequence = {}
    GSSE:lines(sequence, spellbox:GetText())
    -- update sequence
    if tonumber(stepvalue) == 2 then
      sequence.StepFunction = GSStaticPriority
      GSPrintDebugMessage("Setting GSStaticPriority.  Inside the Logic Point")
    else
      sequence.StepFunction = nil
    end
    GSPrintDebugMessage("StepValue Saved: " .. stepvalue, GNOME)
    sequence.PreMacro = premacrobox:GetText()
    sequence.author = GetUnitName("player", true) .. '@' .. GetRealmName()
    sequence.source = GSStaticSourceLocal
    sequence.specID = GSSpecIDHashList[specdropdownvalue]
    sequence.helpTxt = helpeditbox:GetText()
    if not tonumber(sequence.icon) then
      sequence.icon = "INV_MISC_QUESTIONMARK"
    end
    if not GSisEmpty(loopstart:GetText()) then
      sequence.loopstart = loopstart:GetText()
    end
    if not GSisEmpty(loopstop:GetText()) then
      sequence.loopstop = loopstop:GetText()
    end
    if not GSisEmpty(looplimit:GetText()) then
      sequence.looplimit = looplimit:GetText()
    end
    sequence.PostMacro = postmacrobox:GetText()
    sequence.version = nextVal
    GSTRUnEscapeSequence(sequence)
    if GSisEmpty(GSMasterOptions.SequenceLibrary[SequenceName]) then
      -- this is new
      GSPrintDebugMessage(L["Creating New Sequence."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSMasterOptions.SequenceLibrary[SequenceName][nextVal])
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(SequenceName)
      GSPrint(L["Sequence Saved as version "] .. nextVal, GNOME)
    else
      GSPrintDebugMessage(L["Updating due to new version."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSMasterOptions.SequenceLibrary[SequenceName][nextVal])
      GSPrint(L["Sequence Saved as version "] .. nextVal, GNOME)
    end

  end
end

function GSGuiShowViewer()
  if not InCombatLockdown() then
    local names = GSSE:getSequenceNames()
    GSSequenceListbox:SetList(names)
    frame:Show()
  else
    GSPrint(L["Please wait till you have left combat before using the Sequence Editor."], GNOME)
  end

end

function GSSE:GSSlash(input)
    if input == "hide" then
      frame:Hide()
    elseif input == "debug" then
      GSShowDebugWindow()
    else
      GSGuiShowViewer()
    end
end



function GSSE:OnInitialize()
    versionframe:Hide()
    editframe:Hide()
    frame:Hide()
    GSPrint(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSMasterOptions.CommandColour .. L["/gsse |r to get started."], GNOME)
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
  GSPrintDebugMessage(L["sequenceIndex: "] .. (GSisEmpty(sequenceIndex) and L["No value"] or sequenceIndex), GNOME)
  GSPrintDebugMessage(L["Icon: "] .. (GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) and L["none"] or GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon))
  local macindex = GetMacroIndexByName(sequenceIndex)
  local a, iconid, c =  GetMacroInfo(macindex)
  if not GSisEmpty(a) then
    GSPrintDebugMessage(L["Macro Found "] .. a .. L[" with iconid "] .. (GSisEmpty(iconid) and L["of no value"] or iconid) .. " " .. (GSisEmpty(iconid) and L["with no body"] or c), GNOME)
  else
    GSPrintDebugMessage(L["No Macro Found. Possibly different spec for Sequence "] .. sequenceIndex , GNOME)
  end
  if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) and GSisEmpty(iconid) then
    GSPrintDebugMessage("SequenceSpecID: " .. GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID, GNOME)
    if GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID == 0 then
      return "INV_MISC_QUESTIONMARK"
    else
      local _, _, _, specicon, _, _, _ = GetSpecializationInfoByID((GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID) and GSGetCurrentSpecID() or GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].specID))
      GSPrintDebugMessage(L["No Sequence Icon setting to "] .. strsub(specicon, 17), GNOME)
      return strsub(specicon, 17)
    end
  elseif GSisEmpty(iconid) and not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon) then

      return GSMasterOptions.SequenceLibrary[sequenceIndex][GSGetActiveSequenceVersion(currentSequence)].icon
  else
      return iconid
  end
end

function GSSE:lines(tab, str)
  local function helper(line)
    table.insert(tab, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  GST = t
end

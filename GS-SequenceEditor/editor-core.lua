local GNOME,_ = ...
GSSE = LibStub("AceAddon-3.0"):NewAddon("GSSE", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local currentSequence = ""
local importStr = ""
local otherversionlistboxvalue = ""
local currentFingerprint = ""

GSSequenceEditorLoaded = false
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

function GSEncodeSequence(Sequence)
  --clean sequence
  Sequence = GSTRUnEscapeSequence(Sequence)
  --remove version and source
  Sequence.version = nil
  Sequence.source = GSStaticSourceTransmission
  Sequence.authorversion = nil
  Sequence.author = GetUnitName("player", true) .. '@' .. GetRealmName()


  local one = libS:Serialize(Sequence)
  local two = LibSyncC:CompressHuffman(one)
  local final = LibSyncCE:Encode(two)
  return final
end

function GSDecodeSequence(data)
  -- Decode the compressed data
  local one = libCE:Decode(data)

  --Decompress the decoded data
  local two, message = libC:Decompress(one)
  if(not two) then
  	GSPrintDebugMessage ("YourAddon: error decompressing: " .. message, "GS-Transmission")
  	return
  end

  -- Deserialize the decompressed data
  local success, final = libS:Deserialize(two)
  if (not success) then
  	GSPrintDebugMessage ("YourAddon: error deserializing " .. final, "GS-Transmission")
  	return
  end

  GSPrintDebugMessage ("final data: " .. final, "GS-Transmission")
  return final
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
        GSPrint(GSMasterOptions.TitleColour .. GNOME .. L[":|rNo Sequences present so none displayed in the list."] .. ' ' .. k)
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

  container:AddChild(buttonGroup)

  sequenceboxtext = sequencebox
end

function GSSE:drawsecondarywindow(container)
  local languages = GSTRListCachedLanguages()
  local listbox = AceGUI:Create("Dropdown")
  listbox:SetLabel(L["Choose Language"])
  listbox:SetWidth(250)
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


local frame = AceGUI:Create("Frame")
local curentSequence
frame:SetTitle(L["Sequence Viewer"])
frame:SetStatusText(L["Gnome Sequencer: Sequence Viewer"])
frame:SetCallback("OnClose", function(widget) frame:Hide() end)
frame:SetLayout("List")


local listbox = AceGUI:Create("Dropdown")
listbox:SetLabel(L["Load Sequence"])
listbox:SetWidth(250)
listbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)
frame:AddChild(listbox)



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
local editframe = AceGUI:Create("Frame")
local stepvalue

local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")

local firstheadercolumn = AceGUI:Create("SimpleGroup")
--firstheadercolumn:SetFullWidth(true)
firstheadercolumn:SetLayout("List")

editframe:SetTitle(L["Sequence Editor"])
editframe:SetStatusText(L["Gnome Sequencer: Sequence Editor. Press the Close button to Save -->"])
editframe:SetCallback("OnClose", function() GSSE:UpdateSequenceDefinition(currentSequence, GSSequenceEditorLoaded) end)
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

stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key;  end)
firstheadercolumn:AddChild(stepdropdown)

GSSE:getSpecNames()

local speciddropdown = AceGUI:Create("Dropdown")
speciddropdown:SetLabel(L["Specialisation / Class ID"])
speciddropdown:SetWidth(250)
speciddropdown:SetList(GSSE:getSpecNames())
speciddropdown:SetCallback("OnValueChanged", function (obj,event,key) specdropdownvalue = key;  end)

headerGroup:AddChild(firstheadercolumn)

local iconpicker = AceGUI:Create("Icon")
--iconpicker:SetImage()
iconpicker:SetLabel(L["Macro Icon"])
--iconpicker:OnClick(MacroPopupButton_SelectTexture(editframe:GetID() + (FauxScrollFrame_GetOffset(MacroPopupScrollFrame) * NUM_ICONS_PER_ROW)))
headerGroup:AddChild(speciddropdown)
headerGroup:AddChild(iconpicker)
editframe:AddChild(headerGroup)


local premacrobox = AceGUI:Create("MultiLineEditBox")
premacrobox:SetLabel(L["PreMacro"])
premacrobox:SetNumLines(3)
premacrobox:DisableButton(true)
premacrobox:SetFullWidth(true)
--premacrobox.editBox:SetScript("OnLeave", OnTextChanged)

editframe:AddChild(premacrobox)
premacrobox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
premacrobox.editBox:SetScript("OnTextChanged", function () end)

local spellbox = AceGUI:Create("MultiLineEditBox")
spellbox:SetLabel(L["Sequence"])
spellbox:SetNumLines(9)
spellbox:DisableButton(true)
spellbox:SetFullWidth(true)
spellbox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
spellbox.editBox:SetScript("OnTextChanged", function () end)
editframe:AddChild(spellbox)

local postmacrobox = AceGUI:Create("MultiLineEditBox")
postmacrobox:SetLabel(L["PostMacro"])
postmacrobox:SetNumLines(3)
postmacrobox:DisableButton(true)
postmacrobox:SetFullWidth(true)
postmacrobox.editBox:SetScript( "OnLeave",  function(self) GSSE:parsetext(self) end)
postmacrobox.editBox:SetScript("OnTextChanged", function () end)

editframe:AddChild(postmacrobox)

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
activesequencebox:SetNumLines(11)
activesequencebox:DisableButton(true)
activesequencebox:SetFullWidth(true)
leftGroup:AddChild(activesequencebox)

local otherSequenceVersions = AceGUI:Create("MultiLineEditBox")
otherSequenceVersions:SetLabel(L["Other Versions"])
otherSequenceVersions:SetNumLines(11)
otherSequenceVersions:DisableButton(true)
otherSequenceVersions:SetFullWidth(true)
rightGroup:AddChild(otherSequenceVersions)

local otherversionlistbox = AceGUI:Create("Dropdown")
otherversionlistbox:SetWidth(250)
otherversionlistbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:ChangeOtherSequence(key) end)
rightGroup:AddChild(otherversionlistbox)

columnGroup:AddChild(leftGroup)
columnGroup:AddChild(rightGroup)

versionframe:AddChild(columnGroup)

local othersequencebuttonGroup = AceGUI:Create("SimpleGroup")
othersequencebuttonGroup:SetFullWidth(true)
othersequencebuttonGroup:SetLayout("Flow")

local actbutton = AceGUI:Create("Button")
actbutton:SetText(L["Make Active"])
actbutton:SetWidth(200)
actbutton:SetCallback("OnClick", function() GSSE:SetActiveSequence(otherversionlistboxvalue) end)
othersequencebuttonGroup:AddChild(actbutton)

local delbutton = AceGUI:Create("Button")
delbutton:SetText(L["Delete Version"])
delbutton:SetWidth(200)
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
      end
      names = GSSE:getSequenceNames()
      listbox:SetList(names)
      listbox:SetValue(newkey)
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
    else
     stepdropdown:SetValue("2")
    end
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
    iconpicker:SetImage(reticon)
    GSPrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
    speciddropdown:SetValue(GSSpecIDList[GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID])
    specdropdownvalue = GSSpecIDList[GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)].specID]
    currentFingerprint = GSEncodeSequence(GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)])
  else
    GSPrintDebugMessage(L["No Sequence Icon setting to "] , GNOME)
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
  end
  frame:Hide()
  editframe:Show()
  GSPrintDebugMessage(L["Setting Editor clean "], GNOME )

end

function GSSE:UpdateSequenceDefinition(SequenceName, loaded)
    --process Lines
    if loaded then
      -- Changes have been made so save them
      if not GSisEmpty(SequenceName) then
        nextVal = GSGetNextSequenceVersion(currentSequence)
        local sequence = {}
        GSSE:lines(sequence, spellbox:GetText())
        -- update sequence
        if stepvalue == "2" then
          sequence.StepFunction = GSStaticPriority
        else
          sequence.StepFunction = nil
        end
        sequence.PreMacro = premacrobox:GetText()
        sequence.author = GetUnitName("player", true) .. '@' .. GetRealmName()
        sequence.source = GSStaticSourceLocal
        sequence.specID = GSSpecIDHashList[specdropdownvalue]
        sequence.helpTxt = "Talents: " .. GSSE:getCurrentTalents()
        if not tonumber(sequence.icon) then
          sequence.icon = "INV_MISC_QUESTIONMARK"
        end
        sequence.PostMacro = postmacrobox:GetText()
        sequence.version = nextVal
        GSTRUnEscapeSequence(sequence)

        newFingerprint = GSEncodeSequence(sequence)
        if newFingerprint ~= currentFingerprint then
          GSAddSequenceToCollection(SequenceName, sequence, nextVal)
          GSSE:loadSequence(SequenceName)
          GSCheckMacroCreated(SequenceName)
        end
      end
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
        local names = GSSE:getSequenceNames()
        listbox:SetList(names)
        frame:Show()
      else
        GSPrint(GSMasterOptions.TitleColour .. GNOME .. L[":|r Please wait till you have left combat before using the Sequence Editor."])
      end
    end
end


function GSSE:OnInitialize()
    versionframe:Hide()
    editframe:Hide()
    frame:Hide()
    GSPrint(GSMasterOptions.TitleColour .. GNOME .. L[":|r The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSMasterOptions.CommandColour .. L["/gsse |r to get started."])
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

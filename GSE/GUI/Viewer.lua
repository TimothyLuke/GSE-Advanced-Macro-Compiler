local GNOME,_ = ...

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()


local viewframe = AceGUI:Create("Frame")
GSE.GUI.ViewFrame = viewframe
local sequenceboxtext = AceGUI:Create("MultiLineEditBox")
local remotesequenceboxtext = AceGUI:Create("MultiLineEditBox")

local curentSequence

function GSE.GUI.DrawStandardViewerWindow(container)
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
  impbutton:SetCallback("OnClick", function() GSE.ImportSequence(sequenceboxtext:GetText()) end)
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
  recordwindowbutton:SetCallback("OnClick", function() viewframe:Hide(); recordframe:Show() end)
  buttonGroup:AddChild(recordwindowbutton)

  container:AddChild(buttonGroup)

  sequenceboxtext = sequencebox
end

function GSE.GUI.DrawSecondaryViewerWindow(container)
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
function GSE.GUI.SelectGroup(container, event, group)
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

viewframe:SetTitle(L["Sequence Viewer"])
viewframe:SetStatusText(L["Gnome Sequencer: Sequence Viewer"])
viewframe:SetCallback("OnClose", function(widget) viewframe:Hide() end)
viewframe:SetLayout("List")


local viewerheadergroup = AceGUI:Create("SimpleGroup")
viewerheadergroup:SetFullWidth(true)
viewerheadergroup:SetLayout("Flow")


GSSequenceListbox = AceGUI:Create("Dropdown")
GSSequenceListbox:SetLabel(L["Load Sequence"])
GSSequenceListbox:SetWidth(250)
GSSequenceListbox:SetCallback("OnValueChanged", function (obj,event,key) GSSE:loadSequence(key) currentSequence = key end)

local spacerlabel = AceGUI:Create("Label")
spacerlabel:SetWidth(300)


local viewiconpicker = AceGUI:Create("Icon")
viewiconpicker:SetLabel(L["Macro Icon"])
viewiconpicker.frame:RegisterForDrag("LeftButton")
viewiconpicker.frame:SetScript("OnDragStart", function()
  if not GSE.isEmpty(currentSequence) then
    PickupMacro(currentSequence)
  end
end)
viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)

viewerheadergroup:AddChild(GSSequenceListbox)
viewerheadergroup:AddChild(spacerlabel)
viewerheadergroup:AddChild(viewiconpicker)
viewframe:AddChild(viewerheadergroup)

if GSEOptions.useTranslator and GSAdditionalLanguagesAvailable then
  local tab =  AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({{text=GetLocale(), value="localtab"}, {text=L["Translate to"], value="remotetab"}})
  -- Register callback
  tab:SetCallback("OnGroupSelected",  function (container, event, group) GSE.GUI.SelectGroup(container, event, group) end)
  -- Set initial Tab (this will fire the OnGroupSelected callback)
  tab:SelectTab("localtab")
  tab:SetFullWidth(true)
  -- add to the frame container
  viewframe:AddChild(tab)
else
   GSE.GUI.DrawStandardViewerWindow(viewframe)
end

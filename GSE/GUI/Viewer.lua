local GNOME,_ = ...

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()
local editkey = ""

local viewframe = AceGUI:Create("Frame")
GSE.GUIViewFrame = viewframe

viewframe:Hide()
local sequenceboxtext = AceGUI:Create("MultiLineEditBox")
local remotesequenceboxtext = AceGUI:Create("MultiLineEditBox")


viewframe.SequenceName = ""
viewframe.ClassID = 0

function GSE.GUIDrawStandardViewerWindow(container)
  local sequencebox = AceGUI:Create("MultiLineEditBox")
  sequencebox:SetLabel(L["Sequence"])
  sequencebox:SetNumLines(18)
  sequencebox:DisableButton(true)
  sequencebox:SetFullWidth(true)
  sequencebox:SetText(sequenceboxtext:GetText())
  sequencebox:SetCallback("OnEnter", function() sequencebox:HighlightText(0, string.len(sequencebox:GetText())) end)

  container:AddChild(sequencebox)

  viewframe.SequenceTextbox = sequencebox

  local buttonGroup = AceGUI:Create("SimpleGroup")
  buttonGroup:SetFullWidth(true)
  buttonGroup:SetLayout("Flow")

  local newbutton = AceGUI:Create("Button")
  newbutton:SetText(L["New"])
  newbutton:SetWidth(150)
  newbutton:SetCallback("OnClick", function() GSE.GUILoadEditor(nil, viewframe) end)
  buttonGroup:AddChild(newbutton)

  local updbutton = AceGUI:Create("Button")
  updbutton:SetText(L["Edit"])
  updbutton:SetWidth(150)
  updbutton:SetCallback("OnClick", function() GSE.GUILoadEditor(editkey, viewframe) end)
  updbutton:SetDisabled(true)
  buttonGroup:AddChild(updbutton)
  viewframe.EditButton = updbutton

  local impbutton = AceGUI:Create("Button")
  impbutton:SetText(L["Import"])
  impbutton:SetWidth(150)
  impbutton:SetCallback("OnClick", function() GSE.GUIViewFrame:Hide(); GSE.GUIImportFrame:Show() end)
  buttonGroup:AddChild(impbutton)

  local expbutton = AceGUI:Create("Button")
  expbutton:SetText(L["Export"])
  expbutton:SetWidth(150)
  expbutton:SetCallback("OnClick", function()
    GSE.GUIExportSequence(viewframe.Classid, viewframe.SequenceName)
  end)
  expbutton:AddChild(impbutton)
  viewframe.ExportButton = expbutton

  local tranbutton = AceGUI:Create("Button")
  tranbutton:SetText(L["Send"])
  tranbutton:SetWidth(150)
  tranbutton:SetCallback("OnClick", function() GSE.GUIShowTransmissionGui(viewframe.SequenceName) end)
  buttonGroup:AddChild(tranbutton)

  disableSeqbutton = AceGUI:Create("Button")
  GSE.GUIConfigureMacroButton(disableSeqbutton)
  disableSeqbutton:SetWidth(150)
  buttonGroup:AddChild(disableSeqbutton)
  viewframe.MacroIconButton = disableSeqbutton
  local eOptionsbutton = AceGUI:Create("Button")
  eOptionsbutton:SetText(L["Options"])
  eOptionsbutton:SetWidth(150)
  eOptionsbutton:SetCallback("OnClick", function() GSE.OpenOptionsPanel() end)
  buttonGroup:AddChild(eOptionsbutton)

  local recordwindowbutton = AceGUI:Create("Button")
  recordwindowbutton:SetText(L["Record Macro"])
  recordwindowbutton:SetWidth(150)
  recordwindowbutton:SetCallback("OnClick", function() GSE.GUIViewFrame:Hide(); GSE.GUIRecordFrame:Show() end)
  buttonGroup:AddChild(recordwindowbutton)

  container:AddChild(buttonGroup)

  sequenceboxtext = sequencebox
end

function GSE.GUIDrawSecondaryViewerWindow(container)
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
  viewframe.SequenceTextbox = remotesequenceboxtext
end

-- Callback function for OnGroupSelected
function GSE.GUISelectGroup(container, event, group)
   local tremote = remotesequenceboxtext:GetText()
   local tlocal = sequenceboxtext:GetText()
   container:ReleaseChildren()
   GSE.PrintDebugMessage("Selecting tab: " .. group, GNOME)
   if group == "localtab" then
      GSSE:drawstandardwindow(container)
   elseif group == "remotetab" then
      GSSE:drawsecondarywindow(container)
   end
   remotesequenceboxtext:SetText(tremote)
   sequenceboxtext:SetText(tlocal)
end

viewframe:SetTitle(L["Sequence Viewer"])

function GSE.GUIViewerLayout(mcontainer)
  mcontainer:SetStatusText(L["Gnome Sequencer: Sequence Viewer"])
  mcontainer:SetCallback("OnClose", function(widget) viewframe:Hide() end)
  mcontainer:SetLayout("List")


  local viewerheadergroup = AceGUI:Create("SimpleGroup")
  viewerheadergroup:SetFullWidth(true)
  viewerheadergroup:SetLayout("Flow")


  local GSSequenceListbox = AceGUI:Create("Dropdown")
  GSSequenceListbox:SetLabel(L["Load Sequence"])
  GSSequenceListbox:SetWidth(250)
  GSSequenceListbox:SetCallback("OnValueChanged", function (obj,event,key)
    local elements = GSE.split(key, ",")
    viewframe.SequenceName = elements[2]
    viewframe.Classid = tonumber(elements[1])
    editkey = key
    GSE.GUILoadSequence(key)
    viewframe.EditButton:SetDisabled(false)

  end)

  viewframe.SequenceListbox = GSSequenceListbox
  local spacerlabel = AceGUI:Create("Label")
  spacerlabel:SetWidth(300)


  local viewiconpicker = AceGUI:Create("Icon")
  viewiconpicker:SetLabel(L["Macro Icon"])
  viewiconpicker.frame:RegisterForDrag("LeftButton")
  viewiconpicker.frame:SetScript("OnDragStart", function()
    if not GSE.isEmpty(viewframe.SequenceName) then
      PickupMacro(viewframe.SequenceName)
    end
  end)
  viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  GSE.GUIViewFrame.Icon = viewiconpicker

  viewerheadergroup:AddChild(GSSequenceListbox)
  viewerheadergroup:AddChild(spacerlabel)
  viewerheadergroup:AddChild(viewiconpicker)
  mcontainer:AddChild(viewerheadergroup)

  -- TODO Enable langyuages Tabs.
  if GSEOptions.useTranslator and GSE.AdditionalLanguagesAvailable then
    local tab =  AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    -- Setup which tabs to show
    tab:SetTabs({{text=GetLocale(), value="localtab"}, {text=L["Translate to"], value="remotetab"}})
    -- Register callback
    tab:SetCallback("OnGroupSelected",  function (container, event, group) GSE.GUISelectGroup(container, event, group) end)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    tab:SelectTab("localtab")
    tab:SetFullWidth(true)
    -- add to the frame container
    mcontainer:AddChild(tab)
  else
     GSE.GUIDrawStandardViewerWindow(mcontainer)
  end
end

function GSE.GUIShowViewer()
  local names = GSE.GetSequenceNames()
  sequenceboxtext:SetText("")
  viewframe:ReleaseChildren()
  GSE.GUIViewerLayout(viewframe)
  viewframe.SequenceListbox:SetList(names)
  viewframe:Show()
end

function GSE.GUIConfigureMacroButton(button)
  if GSE.CheckMacroCreated(GSE.GUIViewFrame.SequenceName) then
    button:SetText(L["Delete Icon"])
    button:SetCallback("OnClick", function()
      GSE.DeleteMacroStub(viewframe.SequenceName)
      GSE.GUIConfigureMacroButton(button)
      GSE.GUIViewFrame.Icon:SetImage(GSE.GetMacroIcon(classid, sequenceName))
    end)
  else
    disableSeqbutton:SetText(L["Create Icon"])
    disableSeqbutton:SetCallback("OnClick", function()
      GSE.CheckMacroCreated(GSE.GUIViewFrame.SequenceName, true)
      GSE.GUIConfigureMacroButton(button)
      GSE.GUIViewFrame.Icon:SetImage(GSE.GetMacroIcon(classid, sequenceName))
    end)
  end
  if GSE.isEmpty(GSE.GUIViewFrame.SequenceName) then
    button:SetDisabled(true)
  else
    button:SetDisabled(false)
  end

end

function GSE.GUILoadSequence(key)
  local elements = GSE.split(key, ",")
  classid = tonumber(elements[1])
  sequenceName = elements[2]

  GSE.PrintDebugMessage("GSSE:loadSequence " .. sequenceName)
  if GSEOptions.useTranslator then
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequence(GSE.TranslateSequenceFromTo(GSELibrary[classid][sequenceName], (GSE.isEmpty(GSELibrary[classid][sequenceName].Lang) and "enUS" or GSELibrary[classid][sequenceName].Lang), GetLocale()), sequenceName))
  --TODO Fix this so the translator works.
elseif GSE.TranslatorAvailable then
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequence(GSE.TranslateSequenceFromTo(GSELibrary[classid][sequenceName], GetLocale(), GetLocale()), sequenceName))
  else
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequence(GSELibrary[classid][sequenceName]),sequenceName)
  end
  GSE.GUIConfigureMacroButton(viewframe.MacroIconButton)
  GSE.GUIViewFrame.Icon:SetImage(GSE.GetMacroIcon(classid, sequenceName))
end

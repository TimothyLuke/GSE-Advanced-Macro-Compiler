local GNOME,_ = ...
local Statics = GSE.Static
local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()



local otherversionlistboxvalue = ""
local default = 1
local raid = 1
local pvp = 1
local mythic = 1
local classid = GSE.GetCurrentClassID()

local editframe = AceGUI:Create("Frame")
editframe:Hide()
GSE.GUIEditFrame = editframe
editframe.Sequence = {}
editframe.Sequence.MacroVersions = {}
editframe.SequenceName = ""
editframe.Default = 1
editframe.Raid = 1
editframe.PVP = 1
editframe.Mythic = 1
editframe.ClassID = classid

editframe:SetTitle(L["Sequence Editor"])
--editframe:SetStatusText(L["Gnome Sequencer: Sequence Editor."])
editframe:SetCallback("OnClose", function (self) editframe:Hide();  GSE.GUIViewFrame:Show(); end)
editframe:SetLayout("List")

local sequence = editframe.Sequence
local currentSequence = editframe.SequenceName
local specdropdownvalue = editframe.SpecID


function GSE.GUICreateEditorTabs()
  local tabl = {
    {
      text=L["Configuration"],
      value="config"
    },
  }
  for k,v in ipairs(editframe.Sequence.MacroVersions) do
    local insline = {}
    insline.text = tostring(k)
    insline.value = tostring(k)
    table.insert(tabl, insline)
  end
  table.insert(tabl,   {
      text=L["New"],
      value="new"
    }  )
  return tabl
end

function GSE.GUIEditorPerformLayout(frame)
  frame:ReleaseChildren()
  local headerGroup = AceGUI:Create("SimpleGroup")
  headerGroup:SetFullWidth(true)
  headerGroup:SetLayout("Flow")


  local nameeditbox = AceGUI:Create("EditBox")
  nameeditbox:SetLabel(L["Sequence Name"])
  nameeditbox:SetWidth(250)
  nameeditbox:SetCallback("OnTextChanged", function() currentSequence = nameeditbox:GetText(); end)
  nameeditbox:DisableButton( true)
  nameeditbox:SetText(editframe.SequenceName)
  editframe.nameeditbox = nameeditbox
  headerGroup:AddChild(nameeditbox)

  local spacerlabel = AceGUI:Create("Label")
  spacerlabel:SetWidth(300)
  headerGroup:AddChild(spacerlabel)

  local iconpicker = AceGUI:Create("Icon")
  iconpicker:SetLabel(L["Macro Icon"])
  iconpicker.frame:RegisterForDrag("LeftButton")
  iconpicker.frame:SetScript("OnDragStart", function()
    if not GSE.isEmpty(editframe.SequenceName) then
      PickupMacro(editframe.SequenceName)
    end
  end)
  iconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  headerGroup:AddChild(iconpicker)
  editframe.iconpicker = iconpicker

  frame:AddChild(headerGroup)

  local tabgrp =  AceGUI:Create("TabGroup")
  tabgrp:SetLayout("Flow")
  tabgrp:SetTabs(GSE.GUICreateEditorTabs())
  editframe.ContentContainer = tabgrp


  tabgrp:SetCallback("OnGroupSelected",  function (container, event, group) GSE.GUISelectEditorTab(container, event, group) end)
  tabgrp:SetFullWidth(true)
  tabgrp:SetFullHeight(true)

  tabgrp:SelectTab("config")
  frame:AddChild(tabgrp)



  local editOptionsbutton = AceGUI:Create("Button")
  editOptionsbutton:SetText(L["Options"])
  editOptionsbutton:SetWidth(150)
  editOptionsbutton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)

  local transbutton = AceGUI:Create("Button")
  transbutton:SetText(L["Send"])
  transbutton:SetWidth(150)
  transbutton:SetCallback("OnClick", function() GSE.GUIShowTransmissionGui(currentSequence) end)

  local editButtonGroup = AceGUI:Create("SimpleGroup")
  editButtonGroup:SetWidth(452)
  editButtonGroup:SetLayout("Flow")
  editButtonGroup:SetHeight(15)

  local savebutton = AceGUI:Create("Button")
  savebutton:SetText(L["Save"])
  savebutton:SetWidth(150)
  savebutton:SetCallback("OnClick", function() GSE.GUIUpdateSequenceDefinition(currentSequence) end)
  editButtonGroup:AddChild(savebutton)

  editButtonGroup:AddChild(transbutton)
  editButtonGroup:AddChild(editOptionsbutton)
  frame:AddChild(editButtonGroup)

end

function GSE.GetVersionList()
  local tabl = {}
  classid = tonumber(classid)
  for k,v in ipairs(editframe.Sequence.MacroVersions) do
    tabl[tostring(k)] = tostring(k)
  end
  return tabl
end

function GSE:GUIDrawMetadataEditor(container)
  editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))

  local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
  scrollcontainer:SetFullWidth(true)
  scrollcontainer:SetHeight(260)
  scrollcontainer:SetLayout("Fill") -- important!

  local contentcontainer = AceGUI:Create("ScrollFrame")
  scrollcontainer:AddChild(contentcontainer)


  local speciddropdown = AceGUI:Create("Dropdown")
  speciddropdown:SetLabel(L["Specialisation / Class ID"])
  speciddropdown:SetWidth(250)
  speciddropdown:SetList(GSE.GetSpecNames())
  speciddropdown:SetCallback("OnValueChanged", function (obj,event,key) specdropdownvalue = key;  end)
  contentcontainer:AddChild(speciddropdown)
  speciddropdown:SetValue(editframe.Sequence.SpecID)

  local langeditbox = AceGUI:Create("EditBox")
  langeditbox:SetLabel(L["Language"])
  langeditbox:SetWidth(250)
  langeditbox:DisableButton( true)
  contentcontainer:AddChild(langeditbox)
  langeditbox:SetText(editframe.Sequence.Lang)

  local talentseditbox = AceGUI:Create("EditBox")
  talentseditbox:SetLabel(L["Talents"])
  talentseditbox:SetWidth(250)
  talentseditbox:DisableButton( true)
  contentcontainer:AddChild(talentseditbox)
  talentseditbox:SetText(editframe.Sequence.Talents)

  local helpeditbox = AceGUI:Create("MultiLineEditBox")
  helpeditbox:SetLabel(L["Help Information"])
  helpeditbox:SetWidth(250)
  helpeditbox:DisableButton( true)
  helpeditbox:SetNumLines(4)
  helpeditbox:SetFullWidth(true)
  if not GSE.isEmpty(editframe.Sequence.Help) then
    helpeditbox:SetText(editframe.Sequence.Help)
  end
  contentcontainer:AddChild(helpeditbox)

  local helplinkeditbox = AceGUI:Create("EditBox")
  helplinkeditbox:SetLabel(L["Help Link"])
  helplinkeditbox:SetWidth(250)
  helplinkeditbox:DisableButton( true)
  if not GSE.isEmpty(editframe.Sequence.Helplink) then
    helplinkeditbox:SetText(editframe.Sequence.Helplink)
  end
  contentcontainer:AddChild(helplinkeditbox)

  local defaultdropdown = AceGUI:Create("Dropdown")
  defaultdropdown:SetLabel(L["Default Version"])
  defaultdropdown:SetWidth(250)
  defaultdropdown:SetList(GSE.GetVersionList())
  defaultdropdown:SetValue(tostring(editframe.Default))
  contentcontainer:AddChild(defaultdropdown)

  local raiddropdown = AceGUI:Create("Dropdown")
  raiddropdown:SetLabel(L["Raid"])
  raiddropdown:SetWidth(250)
  raiddropdown:SetList(GSE.GetVersionList())
  raiddropdown:SetValue(tostring(editframe.Raid))
  contentcontainer:AddChild(raiddropdown)

  local mythicdropdown = AceGUI:Create("Dropdown")
  mythicdropdown:SetLabel(L["Mythic"])
  mythicdropdown:SetWidth(250)
  mythicdropdown:SetList(GSE.GetVersionList())
  mythicdropdown:SetValue(tostring(editframe.Mythic))
  contentcontainer:AddChild(mythicdropdown)

  local pvpdropdown = AceGUI:Create("Dropdown")
  pvpdropdown:SetLabel(L["PVP"])
  pvpdropdown:SetWidth(250)
  pvpdropdown:SetList(GSE.GetVersionList())
  pvpdropdown:SetValue(tostring(editframe.PVP))
  contentcontainer:AddChild(pvpdropdown)
  container:AddChild(scrollcontainer)
end
function GSE:GUIDrawMacroEditor(container, macroversion)

  local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
  scrollcontainer:SetFullWidth(true)
  --scrollcontainer:SetFullHeight(true) -- probably?
  scrollcontainer:SetHeight(260)
  scrollcontainer:SetLayout("Fill") -- important!

  local contentcontainer = AceGUI:Create("ScrollFrame")
  scrollcontainer:AddChild(contentcontainer)

  if GSE.isEmpty(macroversion) then
    local editmacroversion = 0
    local editmacro = {}
    editmacro.PreMacro = {}
    editmacro.PostMacro = {}
    editmacro.KeyPress = {}
    editmacro.KeyRelease = {}
    editmacro.StepFunction = "Sequential"
    editmacro[1] = "/say Hello"
    macroversion = editmacro
  end

  local stepdropdown = AceGUI:Create("Dropdown")
  stepdropdown:SetLabel(L["Step Function"])
  stepdropdown:SetWidth(250)
  stepdropdown:SetList({
    ["Sequential"] = L["Sequential (1 2 3 4)"],
    ["Priority"] = L["Priority List (1 12 123 1234)"],

  })
  stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key; GSE.PrintDebugMessage("StepValue Set: " .. stepvalue, GNOME) end)
  stepdropdown:SetValue(macroversion.StepFunction)
  contentcontainer:AddChild(stepdropdown)

  local KeyPressbox = AceGUI:Create("MultiLineEditBox")
  KeyPressbox:SetLabel(L["KeyPress"])
  KeyPressbox:SetNumLines(2)
  KeyPressbox:DisableButton(true)
  KeyPressbox:SetFullWidth(true)
  KeyPressbox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  contentcontainer:AddChild(KeyPressbox)

  local PreMacro = AceGUI:Create("MultiLineEditBox")
  PreMacro:SetLabel(L["PreMacro"])
  PreMacro:SetNumLines(2)
  PreMacro:DisableButton(true)
  PreMacro:SetFullWidth(true)
  PreMacro.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(PreMacro) end)
  contentcontainer:AddChild(PreMacro)

  local spellbox = AceGUI:Create("MultiLineEditBox")
  spellbox:SetLabel(L["Sequence"])
  spellbox:SetNumLines(10)
  spellbox:DisableButton(true)
  spellbox:SetFullWidth(true)
  spellbox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  spellbox.editBox:SetScript("OnTextChanged", function () end)
  contentcontainer:AddChild(spellbox)

  local looplimit = AceGUI:Create("EditBox")
  looplimit:SetLabel(L["Inner Loop Limit"])
  looplimit:DisableButton(true)
  looplimit:SetMaxLetters(4)
  looplimit.editbox:SetNumeric()
  contentcontainer:AddChild(looplimit)

  local PostMacro = AceGUI:Create("MultiLineEditBox")
  PostMacro:SetLabel(L["PostMacro"])
  PostMacro:SetNumLines(2)
  PostMacro:DisableButton(true)
  PostMacro:SetFullWidth(true)
  PostMacro.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(PostMacro) end)
  contentcontainer:AddChild(PostMacro)

  local KeyReleasebox = AceGUI:Create("MultiLineEditBox")
  KeyReleasebox:SetLabel(L["KeyRelease"])
  KeyReleasebox:SetNumLines(2)
  KeyReleasebox:DisableButton(true)
  KeyReleasebox:SetFullWidth(true)
  KeyReleasebox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  KeyReleasebox.editBox:SetScript("OnTextChanged", function () end)
  contentcontainer:AddChild(KeyReleasebox)
  container:AddChild(scrollcontainer)
end

function GSE.GUISelectEditorTab(container, event, group)
  container:ReleaseChildren()
  editframe.nameeditbox:SetText(GSE.GUIEditFrame.SequenceName)
  editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))
  if group == "config" then
    GSE:GUIDrawMetadataEditor(container)
  elseif group == "new" then
    GSE:GUIDrawMacroEditor(container, nil)
  else
    GSE:GUIDrawMacroEditor(container, k)
  end
end


-- Create functions for tabs



-- function that draws the widgets for the first tab




-------------end viewer-------------
-------------begin editor--------------------

-- local stepvalue = 1
--
--
--
-- local headerGroup = AceGUI:Create("SimpleGroup")
-- headerGroup:SetFullWidth(true)
-- headerGroup:SetLayout("Flow")
--
-- local firstheadercolumn = AceGUI:Create("SimpleGroup")
-- --firstheadercolumn:SetFullWidth(true)
-- firstheadercolumn:SetLayout("List")
--
--
--
--
--
-- firstheadercolumn:AddChild(nameeditbox)
--
-- firstheadercolumn:AddChild(stepdropdown)
--
-- headerGroup:AddChild(firstheadercolumn)
--
-- local middleColumn = AceGUI:Create("SimpleGroup")
-- middleColumn:SetWidth(252)
-- middleColumn:SetLayout("List")
--
--
--
-- middleColumn:AddChild(helpeditbox)
-- middleColumn:AddChild(speciddropdown)
--
-- headerGroup:AddChild(middleColumn)
-- headerGroup:AddChild(iconpicker)
-- editframe:AddChild(headerGroup)
--
--
--
-- --KeyPressbox.editBox:SetScript("OnLeave", OnTextChanged)
--
-- editscroll:AddChild(KeyPressbox)
-- KeyPressbox.editBox:SetScript("OnTextChanged", function () end)
--
--
-- local loopGroup = AceGUI:Create("SimpleGroup")
-- loopGroup:SetFullWidth(true)
-- loopGroup:SetLayout("Flow")
--
-- editscroll:AddChild(loopGroup)
--
-- local loopstart = AceGUI:Create("EditBox")
-- loopstart:SetLabel(L["Inner Loop Start"])
-- loopstart:DisableButton(true)
-- loopstart:SetMaxLetters(3)
-- loopstart.editbox:SetNumeric()
-- loopGroup:AddChild(loopstart)
--
-- local loopstop = AceGUI:Create("EditBox")
-- loopstop:SetLabel(L["Inner Loop End"])
-- loopstop:DisableButton(true)
-- loopstop:SetMaxLetters(3)
-- loopstop.editbox:SetNumeric()
-- loopGroup:AddChild(loopstop)
--
--
--
--
-- editscroll:AddChild(KeyReleasebox)
-- editframe:AddChild(editscroll)
--
-------------end editor-----------------

-- Slash Commands

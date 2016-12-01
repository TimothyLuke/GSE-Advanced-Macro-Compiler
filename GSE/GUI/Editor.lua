local GNOME,_ = ...

local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()



local importStr = ""
local otherversionlistboxvalue = ""
local default = 1
local raid = 1
local pvp = 1
local mythic = 1

local editframe = AceGUI:Create("Frame")
editframe:Hide()
GSE.GUIEditFrame = editframe
editframe.Sequence = {}
editframe.SequenceName = ""
editframe.SpecID = GSE.GetCurrentClassID()
editframe.Default = 1
editframe.Raid = 1
editframe.PVP = 1
editframe.Mythic = 1


editframe:SetTitle(L["Sequence Editor"])
--editframe:SetStatusText(L["Gnome Sequencer: Sequence Editor."])
editframe:SetCallback("OnClose", function (self) editframe:Hide();  GSE.GUIViewFrame:Show(); end)
editframe:SetLayout("List")

local sequence = editframe.Sequence
local currentSequence = editframe.SequenceName
local specdropdownvalue = editframe.SpecID

local tabset = {
  {
    text=L["Configuration"],
    value="config"
  },
}


local tabgrp =  AceGUI:Create("TabGroup")
tabgrp:SetLayout("Flow")
tabgrp:SetTabs(GSE.GUICreateEditorTabs(tabset))



tabgrp:SetCallback("OnGroupSelected",  function (container, event, group) GSE.GUISelectEditorTab(container, event, group) end)
tabgrp:SetFullWidth(true)
editframe:AddChild(tabgrp)

function GSE.GUICreateEditorTabs(tab)
  for k,v in ipairs(editframe.Sequence.MacroVersions) do
    local insline = {}
    insline.text = k
    insline.value = "v" .. k
    table.insert(tab, insline)
  end
  table.insert(tab,   {
      text=L["New"],
      value="new"
    }  )
  return tab
end


function GSE:GUIDrawMetadataEditor(container)
  local nameeditbox = AceGUI:Create("EditBox")
  nameeditbox:SetLabel(L["Sequence Name"])
  nameeditbox:SetWidth(250)
  nameeditbox:SetCallback("OnTextChanged", function() currentSequence = nameeditbox:GetText(); end)
  nameeditbox:DisableButton( true)
  container:AddChild(nameeditbox)

  local iconpicker = AceGUI:Create("Icon")
  iconpicker:SetLabel(L["Macro Icon"])
  iconpicker.frame:RegisterForDrag("LeftButton")
  iconpicker.frame:SetScript("OnDragStart", function()
    if not GSE.isEmpty(currentSequence) then
      PickupMacro(currentSequence)
    end
  end)
  iconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  container:AddChild(iconpicker)

  local speciddropdown = AceGUI:Create("Dropdown")
  speciddropdown:SetLabel(L["Specialisation / Class ID"])
  speciddropdown:SetWidth(250)
  speciddropdown:SetList(GSE.GetSpecNames())
  speciddropdown:SetCallback("OnValueChanged", function (obj,event,key) specdropdownvalue = key;  end)
  container:AddChild(speciddropdown)

  local langeditbox = AceGUI:Create("EditBox")
  langeditbox:SetLabel(L["Language"])
  langeditbox:SetWidth(250)
  langeditbox:DisableButton( true)
  container:AddChild(langeditbox)

  local talentseditbox = AceGUI:Create("EditBox")
  talentseditbox:SetLabel(L["Talents Information"])
  talentseditbox:SetWidth(250)
  talentseditbox:DisableButton( true)
  container:AddChild(talentseditbox)

  local helpeditbox = AceGUI:Create("MultiLineEditBox")
  helpeditbox:SetLabel(L["Help Information"])
  helpeditbox:SetWidth(250)
  helpeditbox:DisableButton( true)
  helpeditbox:SetNumLines(4)
  helpeditbox:SetFullWidth(true)
  container:AddChild(helpeditbox)

  local helplinkeditbox = AceGUI:Create("EditBox")
  helplinkeditbox:SetLabel(L["Talents Information"])
  helplinkeditbox:SetWidth(250)
  helplinkeditbox:DisableButton( true)
  container:AddChild(helplinkeditbox)

  local defaultdropdown = AceGUI:Create("Dropdown")
  defaultdropdown:SetLabel(L["Default Version"])
  defaultdropdown:SetWidth(250)
  defaultdropdown:SetList(GSE.GetVersionList())
  defaultdropdown:SetValue(default)
  container:AddChild(defaultdropdown)

  local raiddropdown = AceGUI:Create("Dropdown")
  raiddropdown:SetLabel(L["Raid"])
  raiddropdown:SetWidth(250)
  raiddropdown:SetList(GSE.GetVersionList())
  raiddropdown:SetValue(raid)
  container:AddChild(raiddropdown)

  local mythicdropdown = AceGUI:Create("Dropdown")
  mythicdropdown:SetLabel(L["Mythic"])
  mythicdropdown:SetWidth(250)
  mythicdropdown:SetList(GSE.GetVersionList())
  mythicdropdown:SetValue(mythic)
  container:AddChild(mythicdropdown)

  local pvpdropdown = AceGUI:Create("Dropdown")
  pvpdropdown:SetLabel(L["PVP"])
  pvpdropdown:SetWidth(250)
  pvpdropdown:SetList(GSE.GetVersionList())
  pvpdropdown:SetValue(pvp)
  container:AddChild(pvpdropdown)

end

function GSE:GUIDrawMacroEditor(container, macroversion)
  local editscroll = AceGUI:Create("ScrollFrame")
  editscroll:SetLayout("Flow") -- probably?
  editscroll:SetFullWidth(true)
  editscroll:SetHeight(340)


  local stepdropdown = AceGUI:Create("Dropdown")
  stepdropdown:SetLabel(L["Step Function"])
  stepdropdown:SetWidth(250)
  stepdropdown:SetList({
    ["1"] = L["Sequential (1 2 3 4)"],
    ["2"] = L["Priority List (1 12 123 1234)"],

  })
  stepdropdown:SetCallback("OnValueChanged", function (obj,event,key) stepvalue = key; GSE.PrintDebugMessage("StepValue Set: " .. stepvalue, GNOME) end)

  local KeyPressbox = AceGUI:Create("MultiLineEditBox")
  KeyPressbox:SetLabel(L["KeyPress"])
  KeyPressbox:SetNumLines(2)
  KeyPressbox:DisableButton(true)
  KeyPressbox:SetFullWidth(true)
  KeyPressbox.editBox:SetScript( "OnLeave",  function(self) GSE.GUIparsetext(KeyPressbox) end)

  local PreMacro = AceGUI:Create("MultiLineEditBox")
  PreMacro:SetLabel(L["KeyPress"])
  PreMacro:SetNumLines(2)
  PreMacro:DisableButton(true)
  PreMacro:SetFullWidth(true)
  PreMacro.editBox:SetScript( "OnLeave",  function(self) GSE.GUIparsetext(PreMacro) end)

  local spellbox = AceGUI:Create("MultiLineEditBox")
  spellbox:SetLabel(L["Sequence"])
  spellbox:SetNumLines(10)
  spellbox:DisableButton(true)
  spellbox:SetFullWidth(true)
  spellbox.editBox:SetScript( "OnLeave",  function(self) GSE.GUIparsetext(KeyPressbox) end)
  spellbox.editBox:SetScript("OnTextChanged", function () end)

  local looplimit = AceGUI:Create("EditBox")
  looplimit:SetLabel(L["Inner Loop Limit"])
  looplimit:DisableButton(true)
  looplimit:SetMaxLetters(4)
  looplimit.editbox:SetNumeric()
  loopGroup:AddChild(looplimit)
  editscroll:AddChild(spellbox)

  local PostMacro = AceGUI:Create("MultiLineEditBox")
  PostMacro:SetLabel(L["KeyPress"])
  PostMacro:SetNumLines(2)
  PostMacro:DisableButton(true)
  PostMacro:SetFullWidth(true)
  PostMacro.editBox:SetScript( "OnLeave",  function(self) GSE.GUIparsetext(PostMacro) end)

  local KeyReleasebox = AceGUI:Create("MultiLineEditBox")
  KeyReleasebox:SetLabel(L["KeyRelease"])
  KeyReleasebox:SetNumLines(2)
  KeyReleasebox:DisableButton(true)
  KeyReleasebox:SetFullWidth(true)
  KeyReleasebox.editBox:SetScript( "OnLeave",  function(self) GSE.GUIparsetext(KeyPressbox) end)
  KeyReleasebox.editBox:SetScript("OnTextChanged", function () end)

end

function GSE.GUISelectEditorTab(container, event, group)
  container:ReleaseChildren()

end



local boxes = {}
local specdropdownvalue = 0


local editOptionsbutton = AceGUI:Create("Button")
editOptionsbutton:SetText(L["Options"])
editOptionsbutton:SetWidth(250)
editOptionsbutton:SetCallback("OnClick", function() GSSE:OptionsGuiDebugView() end)

local transbutton = AceGUI:Create("Button")
transbutton:SetText(L["Send"])
transbutton:SetWidth(150)
transbutton:SetCallback("OnClick", function() GSE.GUIShowTransmissionGui(currentSequence) end)




-- Create functions for tabs



-- function that draws the widgets for the first tab




-------------end viewer-------------
-------------begin editor--------------------

local stepvalue = 1



local headerGroup = AceGUI:Create("SimpleGroup")
headerGroup:SetFullWidth(true)
headerGroup:SetLayout("Flow")

local firstheadercolumn = AceGUI:Create("SimpleGroup")
--firstheadercolumn:SetFullWidth(true)
firstheadercolumn:SetLayout("List")





firstheadercolumn:AddChild(nameeditbox)

firstheadercolumn:AddChild(stepdropdown)

headerGroup:AddChild(firstheadercolumn)

local middleColumn = AceGUI:Create("SimpleGroup")
middleColumn:SetWidth(252)
middleColumn:SetLayout("List")



middleColumn:AddChild(helpeditbox)
middleColumn:AddChild(speciddropdown)

headerGroup:AddChild(middleColumn)
headerGroup:AddChild(iconpicker)
editframe:AddChild(headerGroup)



--KeyPressbox.editBox:SetScript("OnLeave", OnTextChanged)

editscroll:AddChild(KeyPressbox)
KeyPressbox.editBox:SetScript("OnTextChanged", function () end)


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




editscroll:AddChild(KeyReleasebox)
editframe:AddChild(editscroll)

local editButtonGroup = AceGUI:Create("SimpleGroup")
editButtonGroup:SetWidth(302)
editButtonGroup:SetLayout("Flow")

local savebutton = AceGUI:Create("Button")
savebutton:SetText(L["Save"])
savebutton:SetWidth(150)
savebutton:SetCallback("OnClick", function() GSE.GUIUpdateSequenceDefinition(currentSequence) end)
editButtonGroup:AddChild(savebutton)

editButtonGroup:AddChild(transbutton)



editframe:AddChild(editButtonGroup)
-------------end editor-----------------

-- Slash Commands

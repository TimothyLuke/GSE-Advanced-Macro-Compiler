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
KeyPressbox.editBox:SetScript( "OnLeave",  function(self) GSE.GUI.parsetext(self) end)
KeyPressbox.editBox:SetScript("OnTextChanged", function () end)

local spellbox = AceGUI:Create("MultiLineEditBox")
spellbox:SetLabel(L["Sequence"])
spellbox:SetNumLines(10)
spellbox:DisableButton(true)
spellbox:SetFullWidth(true)
spellbox.editBox:SetScript( "OnLeave",  function(self) GSE.GUI.parsetext(self) end)
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
KeyReleasebox.editBox:SetScript( "OnLeave",  function(self) GSE.GUI.parsetext(self) end)
KeyReleasebox.editBox:SetScript("OnTextChanged", function () end)

editscroll:AddChild(KeyReleasebox)
editframe:AddChild(editscroll)

local editButtonGroup = AceGUI:Create("SimpleGroup")
editButtonGroup:SetWidth(302)
editButtonGroup:SetLayout("Flow")

local savebutton = AceGUI:Create("Button")
savebutton:SetText(L["Save"])
savebutton:SetWidth(150)
savebutton:SetCallback("OnClick", function() GSE.GUI.UpdateSequenceDefinition(currentSequence) end)
editButtonGroup:AddChild(savebutton)

editButtonGroup:AddChild(transbutton)



editframe:AddChild(editButtonGroup)
-------------end editor-----------------

-- Slash Commands

GSE:RegisterChatCommand("gsse", "GSSlash")



function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
  if unit ~= "player" then  return end
  recordsequencebox:SetText(recordsequencebox:GetText() .. "/cast " .. spell .. "\n")
end

-- Functions



function GSE:GSSlash(input)
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



function GSE:OnInitialize()
    recordframe:Hide()
    versionframe:Hide()
    editframe:Hide()
    frame:Hide()
    GSE.Print(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSEOptions.CommandColour .. L["/gsse |r to get started."], GNOME)
end

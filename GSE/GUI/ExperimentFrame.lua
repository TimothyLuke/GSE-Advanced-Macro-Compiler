local GSE = GSE

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local viewframe = AceGUI:Create("Frame")
viewframe.panels = {}
viewframe.CurentSelected = ""
viewframe:Hide()
function viewframe:clearpanels(widget)
  GSE.PrintDebugMessage("widget = " .. widget:GetKey())
  for k,v in pairs(viewframe.panels) do
    print("k " .. k)
    if k == widget:GetKey() then
      print ("matching key")
      viewframe.CurentSelected = widget:GetKey()
      viewframe.panels[k]:SetClicked(true)
    else
      print ("other widget key")
      print("reprinting k " .. k)
      local wid = viewframe.panels[k]
      wid:SetClicked(false)
    end
  end
end

function GSE.GUICreatePanels(frame, container, key)
  local elements = GSE.split(key, ",")
  local classid = tonumber(elements[1])

  local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()



  local selpanel = AceGUI:Create("SelectablePanel")
  selpanel:SetKey(key)
  selpanel:SetFullWidth(true)
  selpanel:SetHeight(300)
  viewframe.panels[key] = selpanel
  selpanel:SetCallback("OnClick", function(widget)
    viewframe:clearpanels(widget)
  end)

  local columngroup = AceGUI:Create("SimpleGroup")
  columngroup:SetFullWidth(true)
  columngroup:SetLayout("Flow")

  local column1 = AceGUI:Create("SimpleGroup")
  column1:SetWidth(520)
  column1:SetLayout("List")

  columngroup:AddChild(column1)


  local label = AceGUI:Create("Label")
  label:SetText(elements[2])
  label:SetFont(fontName, fontHeight + 4 , fontFlags)
  column1:AddChild(label)

  local helplabel = AceGUI:Create("Label")
  local helptext = L["No Help Information Available"]
  if not GSE.isEmpty(GSELibrary[classid][elements[2]].Help) then
    helptext = GSELibrary[classid][elements[2]].Help
  end
  helplabel:SetFullWidth(true)

  helplabel:SetText(helptext )
  column1:AddChild(helplabel)

  local row2 = AceGUI:Create("SimpleGroup")
  row2:SetLayout("Flow")
  row2:SetFullWidth(true)

  local talentsHead = AceGUI:Create("Label")
  talentsHead:SetFont(fontName, fontHeight + 2 , fontFlags)
  talentsHead:SetText(L["Talents"] ..":")
  talentsHead:SetWidth(60)
  row2:AddChild(talentsHead)

  local talentslabel = AceGUI:Create("Label")
  if not GSE.isEmpty(GSELibrary[classid][elements[2]].Talents) then
    talentslabel:SetText(GSELibrary[classid][elements[2]].Talents)
  end
  talentslabel:SetWidth(80)
  row2:AddChild(talentslabel)

  local spacerlabel1 = AceGUI:Create("Label")
  spacerlabel1:SetText("")
  spacerlabel1:SetWidth(5)
  row2:AddChild(spacerlabel1)

  local urlHead = AceGUI:Create("Label")
  urlHead:SetFont(fontName, fontHeight + 2 , fontFlags)
  urlHead:SetText(L["Help URL"] ..":")
  urlHead:SetWidth(70)
  row2:AddChild(urlHead)

  local urlval = "http://www.wowlazymacros.com"
  local urllabel = AceGUI:Create("InteractiveLabel")
  if not GSE.isEmpty(GSELibrary[classid][elements[2]].Helplink) then
   urllabel = GSELibrary[classid][elements[2]].HelpLink
  end
  urllabel:SetText(urlval)
  urllabel:SetCallback("OnClick", function()
    StaticPopupDialogs['GSE_SEQUENCEHELP'].url = urlval
    StaticPopup_Show('GSE_SEQUENCEHELP')
  end)
  urllabel:SetWidth(280)
  row2:AddChild(urllabel)

  column1:AddChild(row2)
  local column2 = AceGUI:Create("SimpleGroup")
  column2:SetWidth(100)
  column2:SetLayout("List")
  columngroup:AddChild(column2)


  local viewiconpicker = AceGUI:Create("Icon")
  viewiconpicker:SetLabel(L["Macro Icon"])
  viewiconpicker.frame:RegisterForDrag("LeftButton")
  viewiconpicker.frame:SetScript("OnDragStart", function()
    if not GSE.isEmpty(viewframe.SequenceName) then
      PickupMacro(viewframe.SequenceName)
    end
  end)
  viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  column2:AddChild(viewiconpicker)

  selpanel:AddChild(columngroup)
  container:AddChild(selpanel)
end

viewframe:SetTitle("Gnome Sequencer: Expiment.")
viewframe:SetStatusText("Experiment")
viewframe:SetCallback("OnClose", function(widget)  viewframe:Hide() end)
viewframe:SetLayout("List")

local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
scrollcontainer:SetFullWidth(true)
scrollcontainer:SetFullHeight(true) -- probably?
scrollcontainer:SetHeight(400)
scrollcontainer:SetLayout("Fill") -- important!

viewframe:AddChild(scrollcontainer)



local contentcontainer = AceGUI:Create("ScrollFrame")
contentcontainer:SetLayout("list")
scrollcontainer:AddChild(contentcontainer)

function showexp()
  local names = GSE.GetSequenceNames()


  for k,v in pairs(names) do
    GSE.GUICreatePanels(viewframe,contentcontainer, k)
  end

  viewframe:Show()
end

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
local arena = 1
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
editframe.Dungeon = 1
editframe.Heroic = 1
editframe.Party = 1
editframe.Arena = 1
editframe.Timewalking = 1
editframe.MythicPlus = 1
editframe.ClassID = classid
editframe.save = false
editframe.SelectedTab = "group"

local fleft, fbottom, fwidth, fheight = editframe.frame:GetBoundsRect()
editframe.Left = fleft
editframe.Bottom = fbottom
editframe.Width = fwidth
editframe.Height = fheight

editframe:SetTitle(L["Sequence Editor"])
--editframe:SetStatusText(L["Gnome Sequencer: Sequence Editor."])
editframe:SetCallback("OnClose", function (self)
  GSE.ClearTooltip(editframe)
  editframe:Hide();
  if editframe.save then
    local event = {}
    event.action = "openviewer"
    table.insert(GSE.OOCQueue, event)
  else
    GSE.GUIShowViewer()
  end
end)
editframe:SetLayout("List")
editframe.frame:SetScript("OnSizeChanged", function ()
  editframe.Left, editframe.Bottom, editframe.Width, editframe.Height = editframe.frame:GetBoundsRect()
  if editframe.Height > GetScreenHeight() then
    editframe.Height = GetScreenHeight() - 10
  end
  GSE.GUISelectEditorTab(editframe.ContentContainer, "Resize", editframe.SelectedTab)
  editframe:DoLayout()
end)


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
  nameeditbox:SetCallback("OnTextChanged", function()
    editframe.SequenceName = nameeditbox:GetText()
  end)
  --nameeditbox:SetScript("OnEditFocusLost", function()
  --  editframe:SetText(string.upper(editframe:GetText()))
  --  editframe.SequenceName = nameeditbox:GetText()
  --end)
  nameeditbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Sequence Name"], L["The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."], editframe)
  end)
  nameeditbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

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
  iconpicker:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Macro Icon"], L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."], editframe)
  end)
  iconpicker:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  headerGroup:AddChild(iconpicker)
  editframe.iconpicker = iconpicker

  frame:AddChild(headerGroup)

  local tabgrp =  AceGUI:Create("TabGroup")
  tabgrp:SetLayout("Flow")
  tabgrp:SetTabs(GSE.GUICreateEditorTabs())
  editframe.ContentContainer = tabgrp


  tabgrp:SetCallback("OnGroupSelected",  function (container, event, group)
    GSE.GUISelectEditorTab(container, event, group)
  end)

  tabgrp:SetFullWidth(true)
  tabgrp:SetFullHeight(true)

  tabgrp:SelectTab("config")
  frame:AddChild(tabgrp)



  local editOptionsbutton = AceGUI:Create("Button")
  editOptionsbutton:SetText(L["Options"])
  editOptionsbutton:SetWidth(150)
  editOptionsbutton:SetCallback("OnClick", function() GSE.OpenOptionsPanel() end)
  editOptionsbutton:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Options"], L["Opens the GSE Options window"], editframe)
  end)
  editOptionsbutton:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local transbutton = AceGUI:Create("Button")
  transbutton:SetText(L["Send"])
  transbutton:SetWidth(150)
  transbutton:SetCallback("OnClick", function() GSE.GUIShowTransmissionGui(editframe.ClassId.. "," ..editframe.SequenceName) end)
  transbutton:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Send"], L["Send this macro to another GSE player who is on the same server as you are."], editframe)
  end)
  transbutton:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)


  local editButtonGroup = AceGUI:Create("SimpleGroup")
  editButtonGroup:SetWidth(602)
  editButtonGroup:SetLayout("Flow")
  editButtonGroup:SetHeight(15)

  local savebutton = AceGUI:Create("Button")
  savebutton:SetText(L["Save"])
  savebutton:SetWidth(150)
  savebutton:SetCallback("OnClick", function()
    editframe.Sequence.ManualIntervention = true
    nameeditbox:SetText(string.upper(nameeditbox:GetText()))
    editframe.SequenceName = nameeditbox:GetText()
    GSE.GUIUpdateSequenceDefinition(editframe.ClassID, editframe.SequenceName, editframe.Sequence)
    editframe.save = true
  end)
  savebutton:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Save"], L["Save the changes made to this macro"], editframe)
  end)
  savebutton:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  editButtonGroup:AddChild(savebutton)
  editframe.SaveButton = savebutton

  local delbutton = AceGUI:Create("Button")
  delbutton:SetText(L["Delete"])
  delbutton:SetWidth(150)
  delbutton:SetCallback("OnClick", function() GSE.GUIDeleteSequence(editframe.ClassID, editframe.SequenceName) end)
  delbutton:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Delete"], L["Delete this macro.  This is not able to be undone."], editframe)
  end)
  delbutton:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  editButtonGroup:AddChild(delbutton)

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
  -- Default frame size = 700 w x 500 h

  editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))


  local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
  scrollcontainer:SetFullWidth(true)
  scrollcontainer:SetHeight(editframe.Height - 260)
  scrollcontainer:SetLayout("Fill") -- Important!

  local contentcontainer = AceGUI:Create("ScrollFrame")
  scrollcontainer:AddChild(contentcontainer)

  local metasimplegroup = AceGUI:Create("SimpleGroup")
  metasimplegroup:SetLayout("Flow")
  metasimplegroup:SetWidth(editframe.Width - 100)

  local speciddropdown = AceGUI:Create("Dropdown")
  speciddropdown:SetLabel(L["Specialisation / Class ID"])
  speciddropdown:SetWidth(200)
  speciddropdown:SetList(GSE.GetSpecNames())
  speciddropdown:SetCallback("OnValueChanged", function (obj,event,key)
    local sid = Statics.SpecIDHashList[key]
    specdropdownvalue = key;
    editframe.SpecID = sid
    editframe.Sequence.SpecID = sid

    if tonumber(sid) > 12 then
      editframe.ClassID = GSE.GetClassIDforSpec(tonumber(sid))
    else
      editframe.ClassID = tonumber(sid)
    end
  end)
  speciddropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Specialisation / Class ID"], L["What class or spec is this macro for?  If it is for all classes choose Global."], editframe)
  end)
  speciddropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  metasimplegroup:AddChild(speciddropdown)
  speciddropdown:SetValue(Statics.SpecIDList[editframe.Sequence.SpecID])


  local spacerlabel1 = AceGUI:Create("Label")
  spacerlabel1:SetWidth(80)
  metasimplegroup:AddChild(spacerlabel1)

  local talentseditbox = AceGUI:Create("EditBox")
  talentseditbox:SetLabel(L["Talents"])
  talentseditbox:SetWidth(200)
  talentseditbox:DisableButton( true)
  metasimplegroup:AddChild(talentseditbox)
  contentcontainer:AddChild(metasimplegroup)
  talentseditbox:SetText(editframe.Sequence.Talents)
  talentseditbox:SetCallback("OnTextChanged", function (obj,event,key)
    editframe.Sequence.Talents = key
  end)
  talentseditbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Talents"], L["What are the preferred talents for this macro?\n'1,2,3,1,2,3,1' means First row choose the first talent, Second row choose the second talent etc"], editframe)
  end)
  talentseditbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local helpeditbox = AceGUI:Create("MultiLineEditBox")
  helpeditbox:SetLabel(L["Help Information"])
  helpeditbox:SetWidth(250)
  helpeditbox:DisableButton( true)
  helpeditbox:SetNumLines(4)
  helpeditbox:SetFullWidth(true)
  helpeditbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Help Information"], L["Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."], editframe)
  end)
  helpeditbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  if not GSE.isEmpty(editframe.Sequence.Help) then
    helpeditbox:SetText(editframe.Sequence.Help)
  end
  helpeditbox:SetCallback("OnTextChanged", function (obj,event,key)
    editframe.Sequence.Help = key
  end)
  contentcontainer:AddChild(helpeditbox)

  local helpgroup1 = AceGUI:Create("SimpleGroup")
  helpgroup1:SetLayout("Flow")
  helpgroup1:SetWidth(editframe.Width - 100)


  local helplinkeditbox = AceGUI:Create("EditBox")
  helplinkeditbox:SetLabel(L["Help Link"])
  helplinkeditbox:SetWidth(250)
  helplinkeditbox:DisableButton( true)
  helplinkeditbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Help Link"], L["Website or forum URL where a player can get more information or ask questions about this macro."], editframe)
  end)
  helplinkeditbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  if not GSE.isEmpty(editframe.Sequence.Helplink) then
    helplinkeditbox:SetText(editframe.Sequence.Helplink)
  end
  helplinkeditbox:SetCallback("OnTextChanged", function (obj,event,key)
    editframe.Sequence.Helplink = key
  end)
  helpgroup1:AddChild(helplinkeditbox)

  local spacerlabel3 = AceGUI:Create("Label")
  spacerlabel3:SetWidth(100)
  helpgroup1:AddChild(spacerlabel3)

  local authoreditbox = AceGUI:Create("EditBox")
  authoreditbox:SetLabel(L["Author"])
  authoreditbox:SetWidth(250)
  authoreditbox:DisableButton( true)
  authoreditbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Author"], L["The author of this macro."], editframe)
  end)
  authoreditbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  if not GSE.isEmpty(editframe.Sequence.Author) then
    authoreditbox:SetText(editframe.Sequence.Author)
  end
  authoreditbox:SetCallback("OnTextChanged", function (obj,event,key)
    editframe.Sequence.Author = key
  end)
  helpgroup1:AddChild(authoreditbox)

  contentcontainer:AddChild(helpgroup1)

  local defgroup1 = AceGUI:Create("SimpleGroup")
  defgroup1:SetLayout("Flow")
  defgroup1:SetWidth(editframe.Width - 100)


  local defaultdropdown = AceGUI:Create("Dropdown")
  defaultdropdown:SetLabel(L["Default Version"])
  defaultdropdown:SetWidth(250)
  defaultdropdown:SetList(GSE.GetVersionList())
  defaultdropdown:SetValue(tostring(editframe.Default))
  defaultdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    editframe.Sequence.Default = tonumber(key)
    editframe.Default = tonumber(key)
  end)
  defaultdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Default Version"], L["The version of this macro that will be used where no other version has been configured."], editframe)
  end)
  defaultdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local spacerlabel4 = AceGUI:Create("Label")
  spacerlabel4:SetWidth(100)

  local raiddropdown = AceGUI:Create("Dropdown")
  raiddropdown:SetLabel(L["Raid"])
  raiddropdown:SetWidth(250)
  raiddropdown:SetList(GSE.GetVersionList())
  raiddropdown:SetValue(tostring(editframe.Raid))
  raiddropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Raid = nil
    else
      editframe.Sequence.Raid = tonumber(key)
      editframe.Raid = tonumber(key)
    end
  end)
  raiddropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Raid"], L["The version of this macro that will be used when you enter raids."], editframe)
  end)
  raiddropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local defgroup2 = AceGUI:Create("SimpleGroup")
  defgroup2:SetLayout("Flow")
  defgroup2:SetWidth(editframe.Width - 100)

  local arenadropdown = AceGUI:Create("Dropdown")
  arenadropdown:SetLabel(L["Arena"])
  arenadropdown:SetWidth(250)
  arenadropdown:SetList(GSE.GetVersionList())
  arenadropdown:SetValue(tostring(editframe.Arena))
  arenadropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Arena"], L["The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."], editframe)
  end)
  arenadropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  arenadropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Arena = nil
    else
      editframe.Sequence.Arena = tonumber(key)
      editframe.Arena = tonumber(key)
    end
  end)


  local mythicdropdown = AceGUI:Create("Dropdown")
  mythicdropdown:SetLabel(L["Mythic"])
  mythicdropdown:SetWidth(250)
  mythicdropdown:SetList(GSE.GetVersionList())
  mythicdropdown:SetValue(tostring(editframe.Mythic))
  mythicdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Mythic = nil
    else
      editframe.Sequence.Mythic = tonumber(key)
      editframe.Mythic = tonumber(key)
    end
  end)
  mythicdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Mythic"], L["The version of this macro to use in Mythic Dungeons."], editframe)
  end)
  mythicdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)


  local spacerlabel5 = AceGUI:Create("Label")
  spacerlabel5:SetWidth(100)

  local pvpdropdown = AceGUI:Create("Dropdown")
  pvpdropdown:SetLabel(L["PVP"])
  pvpdropdown:SetWidth(250)
  pvpdropdown:SetList(GSE.GetVersionList())
  pvpdropdown:SetValue(tostring(editframe.PVP))

  pvpdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.PVP = nil
    else
      editframe.Sequence.PVP = tonumber(key)
      editframe.PVP = tonumber(key)
    end
  end)
  pvpdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["PVP"], L["The version of this macro to use in PVP."], editframe)
  end)
  pvpdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)



  local defgroup3 = AceGUI:Create("SimpleGroup")
  defgroup3:SetLayout("Flow")
  defgroup3:SetWidth(editframe.Width - 100)


  local dungeondropdown = AceGUI:Create("Dropdown")
  dungeondropdown:SetLabel(L["Dungeon"])
  dungeondropdown:SetWidth(250)
  dungeondropdown:SetList(GSE.GetVersionList())
  dungeondropdown:SetValue(tostring(editframe.Dungeon))

  dungeondropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Dungeon = nil
    else
      editframe.Sequence.Dungeon = tonumber(key)
      editframe.Dungeon = tonumber(key)
    end
  end)
  dungeondropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Dungeon"], L["The version of this macro to use in normal dungeons."], editframe)
  end)
  dungeondropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local spacerlabel6 = AceGUI:Create("Label")
  spacerlabel6:SetWidth(100)

  local heroicdropdown = AceGUI:Create("Dropdown")
  heroicdropdown:SetLabel(L["Heroic"])
  heroicdropdown:SetWidth(250)
  heroicdropdown:SetList(GSE.GetVersionList())
  heroicdropdown:SetValue(tostring(editframe.Heroic))
  heroicdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Heroic = nil
    else
      editframe.Sequence.Heroic = tonumber(key)
      editframe.Heroic = tonumber(key)
    end
  end)
  heroicdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Heroic"], L["The version of this macro to use in heroic dungeons."], editframe)
  end)
  heroicdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local defgroup4 = AceGUI:Create("SimpleGroup")
  defgroup4:SetLayout("Flow")
  defgroup4:SetWidth(editframe.Width - 100)

  local partydropdown = AceGUI:Create("Dropdown")
  partydropdown:SetLabel(L["Party"])
  partydropdown:SetWidth(250)
  partydropdown:SetList(GSE.GetVersionList())
  partydropdown:SetValue(tostring(editframe.Party))
  partydropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Party = nil
    else
      editframe.Sequence.Party = tonumber(key)
      editframe.Party = tonumber(key)
    end
  end)
  partydropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Party"], L["The version of this macro to use when in a party in the world."], editframe)
  end)
  partydropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local spacerlabel7 = AceGUI:Create("Label")
  spacerlabel7:SetWidth(100)

  local defgroup5 = AceGUI:Create("SimpleGroup")
  defgroup5:SetLayout("Flow")
  defgroup5:SetWidth(editframe.Width - 100)

  local Timewalkingdropdown = AceGUI:Create("Dropdown")
  Timewalkingdropdown:SetLabel(L["Timewalking"])
  Timewalkingdropdown:SetWidth(250)
  Timewalkingdropdown:SetList(GSE.GetVersionList())
  Timewalkingdropdown:SetValue(tostring(editframe.Timewalking))
  Timewalkingdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.Timewalking = nil
    else
      editframe.Sequence.Timewalking = tonumber(key)
      editframe.Timewalking = tonumber(key)
    end
  end)
  Timewalkingdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Timewalking"], L["The version of this macro to use when in time walking dungeons."], editframe)
  end)
  Timewalkingdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  local spacerlabel8 = AceGUI:Create("Label")
  spacerlabel8:SetWidth(100)

  local mythicplusdropdown = AceGUI:Create("Dropdown")
  mythicplusdropdown:SetLabel(L["Mythic+"])
  mythicplusdropdown:SetWidth(250)
  mythicplusdropdown:SetList(GSE.GetVersionList())
  mythicplusdropdown:SetValue(tostring(editframe.MythicPlus))
  mythicplusdropdown:SetCallback("OnValueChanged", function (obj,event,key)
    if editframe.Sequence.Default == tonumber(key) then
      editframe.Sequence.MythicPlus = nil
    else
      editframe.Sequence.MythicPlus = tonumber(key)
      editframe.MythicPlus = tonumber(key)
    end
  end)
  mythicplusdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Mythic+"], L["The version of this macro to use in Mythic+ Dungeons."], editframe)
  end)
  mythicplusdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  if GSE.GameMode == 1 then
    -- Classic WoW
    defgroup1:AddChild(defaultdropdown)
    defgroup1:AddChild(spacerlabel4)
    defgroup1:AddChild(partydropdown)
    defgroup2:AddChild(dungeondropdown)
    defgroup2:AddChild(spacerlabel5)
    defgroup2:AddChild(raiddropdown)
    defgroup3:AddChild(pvpdropdown)
    defgroup3:AddChild(spacerlabel6)

    contentcontainer:AddChild(defgroup1)
    contentcontainer:AddChild(defgroup2)
    contentcontainer:AddChild(defgroup3)
  else
    defgroup1:AddChild(defaultdropdown)
    defgroup1:AddChild(spacerlabel4)
    defgroup1:AddChild(raiddropdown)
    defgroup2:AddChild(arenadropdown)
    defgroup2:AddChild(spacerlabel5)
    defgroup2:AddChild(pvpdropdown)
    defgroup3:AddChild(mythicdropdown)
    defgroup3:AddChild(spacerlabel6)
    defgroup3:AddChild(mythicplusdropdown)
    defgroup4:AddChild(heroicdropdown)
    defgroup4:AddChild(spacerlabel7)
    defgroup4:AddChild(dungeondropdown)
    defgroup5:AddChild(Timewalkingdropdown)
    defgroup5:AddChild(spacerlabel8)
    defgroup5:AddChild(partydropdown)

    contentcontainer:AddChild(defgroup1)
    contentcontainer:AddChild(defgroup2)
    contentcontainer:AddChild(defgroup3)
    contentcontainer:AddChild(defgroup4)
    contentcontainer:AddChild(defgroup5)
  end

  container:AddChild(scrollcontainer)
end

function GSE:GUIDrawMacroEditor(container, version)
  version = tonumber(version)
  if GSE.isEmpty(editframe.Sequence.MacroVersions[version]) then
    editframe.Sequence.MacroVersions[version] = {}
    editframe.Sequence.MacroVersions[version].PreMacro = {}
    editframe.Sequence.MacroVersions[version].PostMacro = {}
    editframe.Sequence.MacroVersions[version].KeyPress = {}
    editframe.Sequence.MacroVersions[version].KeyRelease = {}
    editframe.Sequence.MacroVersions[version].StepFunction = "Sequential"
    editframe.Sequence.MacroVersions[version][1] = "/say Hello"
  end

  editframe.Sequence.MacroVersions[version] = GSE.TranslateSequence(editframe.Sequence.MacroVersions[version], "From Editor", "STRING")

  local layoutcontainer = AceGUI:Create("SimpleGroup")
  layoutcontainer:SetFullWidth(true)
  layoutcontainer:SetHeight(editframe.Height - 260 )
  layoutcontainer:SetLayout("Flow") -- Important!

  local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
  --scrollcontainer:SetFullWidth(true)
  --scrollcontainer:SetFullHeight(true) -- Probably?
  scrollcontainer:SetWidth(editframe.Width - 200)
  scrollcontainer:SetHeight(editframe.Height - 260)
  scrollcontainer:SetLayout("Fill") -- Important!

  local contentcontainer = AceGUI:Create("ScrollFrame")
  scrollcontainer:AddChild(contentcontainer)

  local linegroup1 = AceGUI:Create("SimpleGroup")
  linegroup1:SetLayout("Flow")
  linegroup1:SetWidth(editframe.Width - 100)

  local stepdropdown = AceGUI:Create("Dropdown")
  stepdropdown:SetLabel(L["Step Function"])
  stepdropdown:SetWidth((editframe.Width - 210) * 0.48)
  stepdropdown:SetList({
    ["Sequential"] = L["Sequential (1 2 3 4)"],
    ["Priority"] = L["Priority List (1 12 123 1234)"],
    ["Random"] = L["Random - It will select .... a spell, any spell"]
  })
  stepdropdown:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Step Function"], L["The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."], editframe)
  end)
  stepdropdown:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  if GSE.isEmpty(editframe.Sequence.MacroVersions[version].StepFunction) then
    editframe.Sequence.MacroVersions[version].StepFunction = "Sequential"
  end
  stepdropdown:SetValue(editframe.Sequence.MacroVersions[version].StepFunction)
  stepdropdown:SetCallback("OnValueChanged", function (sel, object, value)
      editframe.Sequence.MacroVersions[version].StepFunction = value
    end)
  linegroup1:AddChild(stepdropdown)

  local spacerlabel1 = AceGUI:Create("Label")
  spacerlabel1:SetWidth(5)
  linegroup1:AddChild(spacerlabel1)

  local looplimit = AceGUI:Create("EditBox")
  looplimit:SetLabel(L["Inner Loop Limit"])
  looplimit:DisableButton(true)
  looplimit:SetMaxLetters(4)
  looplimit:SetWidth(100)
  looplimit:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Inner Loop Limit"], L["Inner Loop Limit controls how many times the Sequence part of your macro executes \nuntil it goes onto to the PostMacro and then resets to the PreMacro."], editframe)
  end)
  looplimit:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  linegroup1:AddChild(looplimit)
  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version].LoopLimit) then
    looplimit:SetText(tonumber(editframe.Sequence.MacroVersions[version].LoopLimit))
  end
  looplimit.editbox:SetNumeric()
  looplimit:SetCallback("OnTextChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].LoopLimit = value
  end)

  local spacerlabel7 = AceGUI:Create("Label")
  spacerlabel7:SetWidth(5)
  linegroup1:AddChild(spacerlabel7)

  local delversionbutton = AceGUI:Create("Button")
  delversionbutton:SetText(L["Delete Version"])
  delversionbutton:SetWidth(150)
  delversionbutton:SetCallback("OnClick", function()
    GSE.GUIDeleteVersion(version)
  end)
  delversionbutton:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Delete Version"], L["Delete this verion of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."], editframe)
  end)
  delversionbutton:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  linegroup1:AddChild(delversionbutton)

  contentcontainer:AddChild(linegroup1)
  local linegroup2 = AceGUI:Create("SimpleGroup")
  linegroup2:SetLayout("Flow")
  linegroup2:SetWidth(editframe.Width - 100)

  local KeyPressbox = AceGUI:Create("MultiLineEditBox")
  KeyPressbox:SetLabel(L["KeyPress"])
  KeyPressbox:SetNumLines(2)
  KeyPressbox:DisableButton(true)
  KeyPressbox:SetWidth((editframe.Width - 210) * 0.48)
  KeyPressbox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version].KeyPress) then
    KeyPressbox:SetText(table.concat(editframe.Sequence.MacroVersions[version].KeyPress, "\n"))
  end
  KeyPressbox:SetCallback("OnTextChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].KeyPress = GSE.SplitMeIntolines(value)
  end)
  KeyPressbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["KeyPress"], L["These lines are executed every time you click this macro.  They are evaluated by WOW before the line in the Sequence Box."], editframe)
  end)
  KeyPressbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  linegroup2:AddChild(KeyPressbox)

  local spacerlabel2 = AceGUI:Create("Label")
  spacerlabel2:SetWidth(6)
  linegroup2:AddChild(spacerlabel2)

  local PreMacro = AceGUI:Create("MultiLineEditBox")
  PreMacro:SetLabel(L["PreMacro"])
  PreMacro:SetNumLines(2)
  PreMacro:DisableButton(true)
  PreMacro:SetWidth((editframe.Width - 210) * 0.48)
  PreMacro.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(PreMacro) end)
  PreMacro:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["PreMacro"], L["These lines are executed before the lines in the Sequence Box.  If an Inner Loop Limit is not set, these are executed only once.  \nIf an Inner Loop Limit has been set these are executed after the Sequence has been looped through the number of times.  \nThe Sequence will then go on to the Post Macro if it exists then back to the PreMacro."], editframe)
  end)
  PreMacro:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version].PreMacro) then
    PreMacro:SetText(table.concat(editframe.Sequence.MacroVersions[version].PreMacro, "\n"))
  end
  PreMacro:SetCallback("OnTextChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].PreMacro = GSE.SplitMeIntolines(value)
  end)
  linegroup2:AddChild(PreMacro)

  contentcontainer:AddChild(linegroup2)

  local spellbox = AceGUI:Create("MultiLineEditBox")
  spellbox:SetLabel(L["Sequence"])
  spellbox:SetNumLines(8)
  spellbox:DisableButton(true)
  spellbox:SetFullWidth(true)
  spellbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Sequence"], L["The main lines of the macro."], editframe)
  end)
  spellbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  spellbox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version]) then
    spellbox:SetText(table.concat(editframe.Sequence.MacroVersions[version], "\n"))
  end
  spellbox:SetCallback("OnTextChanged", function (sel, object, value)
    for k,v in ipairs(editframe.Sequence.MacroVersions[version]) do
      editframe.Sequence.MacroVersions[version][k] = nil
    end
    local newpairs = GSE.SplitMeIntolines(value)
    for k,v in ipairs(newpairs) do
      editframe.Sequence.MacroVersions[version][k] = v
    end
  end)
  contentcontainer:AddChild(spellbox)

  local linegroup3 = AceGUI:Create("SimpleGroup")
  linegroup3:SetLayout("Flow")
  linegroup3:SetWidth(editframe.Width - 100)

  local KeyReleasebox = AceGUI:Create("MultiLineEditBox")
  KeyReleasebox:SetLabel(L["KeyRelease"])
  KeyReleasebox:SetNumLines(2)
  KeyReleasebox:DisableButton(true)
  KeyReleasebox:SetWidth((editframe.Width - 210) * 0.48)
  KeyReleasebox.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(KeyPressbox) end)
  KeyReleasebox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["KeyRelease"], L["These lines are executed every time you click this macro.  They are evaluated by WOW after the line in the Sequence Box."], editframe)
  end)
  KeyReleasebox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version].KeyRelease) then
    KeyReleasebox:SetText(table.concat(editframe.Sequence.MacroVersions[version].KeyRelease, "\n"))
  end
  KeyReleasebox:SetCallback("OnTextChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].KeyRelease = GSE.SplitMeIntolines(value)
  end)
  linegroup3:AddChild(KeyReleasebox)

  local spacerlabel3 = AceGUI:Create("Label")
  spacerlabel3:SetWidth(6)
  linegroup3:AddChild(spacerlabel3)

  local PostMacro = AceGUI:Create("MultiLineEditBox")
  PostMacro:SetLabel(L["PostMacro"])
  PostMacro:SetNumLines(2)
  PostMacro:DisableButton(true)
  PostMacro:SetWidth((editframe.Width - 210) * 0.48)
  PostMacro.editBox:SetScript( "OnLeave",  function() GSE.GUIParseText(PostMacro) end)
  linegroup3:AddChild(PostMacro)
  if not GSE.isEmpty(editframe.Sequence.MacroVersions[version].PostMacro) then
    PostMacro:SetText(table.concat(editframe.Sequence.MacroVersions[version].PostMacro, "\n"))
  end
  PostMacro:SetCallback("OnTextChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].PostMacro = GSE.SplitMeIntolines(value)
  end)
  PostMacro:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["PostMacro"], L["These lines are executed after the lines in the Sequence Box have been repeated Inner Loop Limit number of times.  If an Inner Loop Limit is not set, these are never executed as the sequence will never stop repeating.\nThe Sequence will then go on to the PreMacro if it exists then back to the Sequence."], editframe)
  end)
  PostMacro:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  contentcontainer:AddChild(linegroup3)

  layoutcontainer:AddChild(scrollcontainer)

  local toolbarcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
  toolbarcontainer:SetWidth(85)

  local heading2 = AceGUI:Create("Label")
  heading2:SetText(L["Resets"])
  toolbarcontainer:AddChild(heading2)

  --local targetresetcheckbox = AceGUI:Create("CheckBox")
  --targetresetcheckbox:SetType("checkbox")
  --targetresetcheckbox:SetWidth(78)
  --targetresetcheckbox:SetTriState(false)
  --targetresetcheckbox:SetLabel(L["Target"])
  --toolbarcontainer:AddChild(targetresetcheckbox)
  --if editframe.Sequence.MacroVersions[version].Target then
  --  targetresetcheckbox:SetValue(true)
  --end
  --targetresetcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
  --  editframe.Sequence.MacroVersions[version].Target = value
  --end)

  local combatresetcheckbox = AceGUI:Create("CheckBox")
  combatresetcheckbox:SetType("checkbox")
  combatresetcheckbox:SetWidth(78)
  combatresetcheckbox:SetTriState(true)
  combatresetcheckbox:SetLabel(L["Combat"])
  toolbarcontainer:AddChild(combatresetcheckbox)
  combatresetcheckbox:SetValue(editframe.Sequence.MacroVersions[version].Combat)
  combatresetcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Combat = value
  end)
  combatresetcheckbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Combat"], L["Reset this macro when you exit combat."], editframe)
  end)
  combatresetcheckbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)


  local headingspace1 = AceGUI:Create("Label")
  headingspace1:SetText(" ")
  toolbarcontainer:AddChild(headingspace1)

  local heading1 = AceGUI:Create("Label")
  heading1:SetText(L["Use"])
  toolbarcontainer:AddChild(heading1)

  local headcheckbox = AceGUI:Create("CheckBox")
  headcheckbox:SetType("checkbox")
  headcheckbox:SetWidth(78)
  headcheckbox:SetTriState(true)
  headcheckbox:SetLabel(L["Head"])
  headcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Head = value
  end)
  headcheckbox:SetValue(editframe.Sequence.MacroVersions[version].Head)
  headcheckbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Head"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  headcheckbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)

  toolbarcontainer:AddChild(headcheckbox)

  local neckcheckbox = AceGUI:Create("CheckBox")
  neckcheckbox:SetType("checkbox")
  neckcheckbox:SetWidth(78)
  neckcheckbox:SetTriState(true)
  neckcheckbox:SetLabel(L["Neck"])
  neckcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Neck = value
  end)
  neckcheckbox:SetValue(editframe.Sequence.MacroVersions[version].Neck)
  neckcheckbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Neck"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  neckcheckbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  toolbarcontainer:AddChild(neckcheckbox)

  local beltcheckbox = AceGUI:Create("CheckBox")
  beltcheckbox:SetType("checkbox")
  beltcheckbox:SetWidth(78)
  beltcheckbox:SetTriState(true)
  beltcheckbox:SetLabel(L["Belt"])
  beltcheckbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Belt = value
  end)
  beltcheckbox:SetValue(editframe.Sequence.MacroVersions[version].Belt)
  beltcheckbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Belt"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  beltcheckbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  toolbarcontainer:AddChild(beltcheckbox)

  local ring1checkbox = AceGUI:Create("CheckBox")
  ring1checkbox:SetType("checkbox")
  ring1checkbox:SetWidth(68)
  ring1checkbox:SetTriState(true)
  ring1checkbox:SetLabel(L["Ring 1"])
  ring1checkbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Ring1 = value
  end)
  ring1checkbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Ring 1"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  ring1checkbox:SetCallback('OnLeave', function ()
    GSE.ClearTooltip(editframe)
  end)
  ring1checkbox:SetValue(editframe.Sequence.MacroVersions[version].Ring1)
  toolbarcontainer:AddChild(ring1checkbox)

  local ring2checkbox = AceGUI:Create("CheckBox")
  ring2checkbox:SetType("checkbox")
  ring2checkbox:SetWidth(68)
  ring2checkbox:SetTriState(true)
  ring2checkbox:SetLabel(L["Ring 2"])
  ring2checkbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Ring2 = value
  end)
  ring2checkbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Ring2 = value
  end)
  ring2checkbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Ring 2"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  ring2checkbox:SetValue(editframe.Sequence.MacroVersions[version].Ring2)
  toolbarcontainer:AddChild(ring2checkbox)

  local trinket1checkbox = AceGUI:Create("CheckBox")
  trinket1checkbox:SetType("checkbox")
  trinket1checkbox:SetWidth(78)
  trinket1checkbox:SetTriState(true)
  trinket1checkbox:SetLabel(L["Trinket 1"])
  trinket1checkbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Trinket1 = value
  end)
  trinket1checkbox:SetValue(editframe.Sequence.MacroVersions[version].Trinket1)
  trinket1checkbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Trinket 1"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  toolbarcontainer:AddChild(trinket1checkbox)

  local trinket2checkbox = AceGUI:Create("CheckBox")
  trinket2checkbox:SetType("checkbox")
  trinket2checkbox:SetWidth(83)
  trinket2checkbox:SetTriState(true)
  trinket2checkbox:SetLabel(L["Trinket 2"])
  trinket2checkbox:SetCallback("OnValueChanged", function (sel, object, value)
    editframe.Sequence.MacroVersions[version].Trinket2 = value
  end)
  trinket2checkbox:SetCallback('OnEnter', function ()
    GSE.CreateToolTip(L["Trinket 2"], L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."], editframe)
  end)
  trinket2checkbox:SetValue(editframe.Sequence.MacroVersions[version].Trinket2)
  toolbarcontainer:AddChild(trinket2checkbox)

  layoutcontainer:AddChild(toolbarcontainer)
  container:AddChild(layoutcontainer)
end

function GSE.GUISelectEditorTab(container, event, group)
  if not  GSE.isEmpty(container) then
    container:ReleaseChildren()
    editframe.SelectedTab = group
    editframe.nameeditbox:SetText(GSE.GUIEditFrame.SequenceName)
    editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))
    if group == "config" then
      GSE:GUIDrawMetadataEditor(container)
    elseif group == "new" then
      -- Copy the Default to a new version
      table.insert(editframe.Sequence.MacroVersions, GSE.CloneMacroVersion(editframe.Sequence.MacroVersions[editframe.Sequence.Default]))

      GSE.GUIEditorPerformLayout(editframe)
      GSE.GUISelectEditorTab(container, event, table.getn(editframe.Sequence.MacroVersions))
    else
      GSE:GUIDrawMacroEditor(container, group)
    end
  end
end

function GSE.GUIDeleteVersion(version)
  version = tonumber(version)
  local sequence = editframe.Sequence
  if table.getn(sequence.MacroVersions) <= 1 then
    GSE.Print(L["This is the only version of this macro.  Delete the entire macro to delete this version."])
    return
  end
  if sequence.Default == version then
    GSE.Print(L["You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."])
    return
  end
  local printtext = L["Macro Version %d deleted."]
  if sequence.PVP == version then
    sequence.PVP = sequence.Default
    printtext = printtext .. " " .. L["PVP setting changed to Default."]
  end
  if sequence.Arena == version then
    sequence.Arena = sequence.Default
    printtext = printtext .. " " .. L["Arena setting changed to Default."]
  end
  if sequence.Raid == version then
    sequence.Raid = sequence.Default
    printtext = printtext .. " " .. L["Raid setting changed to Default."]
  end
  if sequence.Mythic == version then
    sequence.Mythic = sequence.Default
    printtext = printtext .. " " .. L["Mythic setting changed to Default."]
  end
  if sequence.Heroic == version then
    sequence.Heroic = sequence.Default
    printtext = printtext .. " " .. L["Heroic setting changed to Default."]
  end
  if sequence.Dungeon == version then
    sequence.Dungeon = sequence.Default
    printtext = printtext .. " " .. L["Dungeon setting changed to Default."]
  end
  if sequence.Party == version then
    sequence.Party = sequence.Default
    printtext = printtext .. " " .. L["Party setting changed to Default."]
  end
  if sequence.MythicPlus == version then
    sequence.MythicPlus = sequence.Default
    printtext = printtext .. " " .. L["Mythic+ setting changed to Default."]
  end
  if sequence.Timewalking == version then
    sequence.Timewalking = sequence.Default
    printtext = printtext .. " " .. L["Timewalking setting changed to Default."]
  end


  if sequence.Default > 1 then
    sequence.Default = tonumber(sequence.Default) - 1
  else
    sequence.Default = 1
  end

  if not GSE.isEmpty(sequence.PVP) then
    sequence.PVP = tonumber(sequence.PVP) - 1
  end
  if not GSE.isEmpty(sequence.Arena) then
    sequence.Arena = tonumber(sequence.Arena) - 1
  end
  if not GSE.isEmpty(sequence.Raid) then
    sequence.Raid = tonumber(sequence.Raid) - 1
  end
  if not GSE.isEmpty(sequence.Mythic) then
    sequence.Mythic = tonumber(sequence.Mythic) - 1
  end
  if not GSE.isEmpty(sequence.MythicPlus) then
    sequence.MythicPlus = tonumber(sequence.MythicPlus) - 1
  end
  if not GSE.isEmpty(sequence.Timewalking) then
    sequence.Timewalking = tonumber(sequence.Timewalking) - 1
  end
  if not GSE.isEmpty(sequence.Heroic) then
    sequence.Heroic = tonumber(sequence.Heroic) - 1
  end
  if not GSE.isEmpty(sequence.Dungeon) then
    sequence.Dungeon = tonumber(sequence.Dungeon) - 1
  end
  if not GSE.isEmpty(sequence.Party) then
    sequence.Party = tonumber(sequence.Party) - 1
  end

  table.remove(sequence.MacroVersions, version)
  printtext = printtext .. " " .. L["This change will not come into effect until you save this macro."]
  GSE.GUIEditorPerformLayout(editframe)
  GSE.GUIEditFrame.ContentContainer:SelectTab("config")
  GSE.GUIEditFrame:SetStatusText(string.format(printtext, version))
end

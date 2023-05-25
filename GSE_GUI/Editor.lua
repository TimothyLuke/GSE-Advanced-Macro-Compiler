local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local editframe = AceGUI:Create("Frame")
editframe:Hide()
GSE.GUIEditFrame = editframe
editframe.Sequence = {}
editframe.Sequence.Macros = {}
editframe.SequenceName = ""
editframe.Raid = 1
editframe.PVP = 1
editframe.Mythic = 1
editframe.Dungeon = 1
editframe.Heroic = 1
editframe.Party = 1
editframe.Arena = 1
editframe.Timewalking = 1
editframe.MythicPlus = 1
editframe.Scenario = 1
editframe.ClassID = GSE.GetCurrentClassID()
editframe.save = false
editframe.SelectedTab = "group"
editframe.AdvancedEditor = false
editframe.statusText = "GSE: " .. GSE.VersionString
editframe.booleanFunctions = {}

local frameTableUpdated = {}

if GSE.isEmpty(GSEOptions.editorHeight) then
    GSEOptions.editorHeight = 500
end
if GSE.isEmpty(GSEOptions.editorWidth) then
    GSEOptions.editorWidth = 700
end
editframe.Height = GSEOptions.editorHeight
editframe.Width = GSEOptions.editorWidth
if editframe.Height < 500 then
    editframe.Height = 500
    GSEOptions.editorHeight = editframe.Height
end
if editframe.Width < 700 then
    editframe.Width = 700
    GSEOptions.editorWidth = editframe.Width
end
editframe.frame:SetClampRectInsets(-10, -10, -10, -10)
editframe.frame:SetHeight(GSEOptions.editorHeight)
editframe.frame:SetWidth(GSEOptions.editorWidth)
editframe:SetTitle(L["Sequence Editor"])
editframe:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(editframe)
        editframe:Hide()
        if editframe.save then
            local event = {}
            event.action = "openviewer"
            table.insert(GSE.OOCQueue, event)
        else
            if not editframe.AdvancedEditor then
                GSE.GUIShowViewer()
            end
        end
    end
)
editframe:SetLayout("List")
editframe.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        editframe.Height = height
        editframe.Width = width
        if editframe.Height > GetScreenHeight() then
            editframe.Height = GetScreenHeight() - 10
            editframe:SetHeight(editframe.Height)
        end
        if editframe.Height < 500 then
            editframe.Height = 500
            editframe:SetHeight(editframe.Height)
        end
        if editframe.Width < 700 then
            editframe.Width = 700
            editframe:SetWidth(editframe.Width)
        end
        GSEOptions.editorHeight = editframe.Height
        GSEOptions.editorWidth = editframe.Width
        GSE.GUISelectEditorTab(editframe.ContentContainer, "Resize", editframe.SelectedTab)
        editframe:DoLayout()
    end
)

function GSE.GUICreateEditorTabs()
    local tabl = {
        {
            text = L["Configuration"],
            value = "config"
        }
    }
    -- If disabled editor then dont show the internal tabs
    if not editframe.Sequence.MetaData.DisableEditor then
        for k, _ in ipairs(editframe.Sequence.Macros) do
            local insline = {}
            insline.text = tostring(k)
            insline.value = tostring(k)
            table.insert(tabl, insline)
        end
        table.insert(
            tabl,
            {
                text = L["New"],
                value = "new"
            }
        )
        if editframe.Sequence.MetaData.ReadOnly then
            editframe.statusText =
                "GSE: " ..
                GSE.VersionString ..
                    " " ..
                        GSEOptions.UNKNOWN ..
                            L["This sequence is Read Only and unable to be edited."] .. Statics.StringReset
        end
    else
        editframe.statusText =
            "GSE: " ..
            GSE.VersionString ..
                " " .. GSEOptions.UNKNOWN .. L["RESTRICTED: Macro specifics disabled by author."] .. Statics.StringReset
    end
    table.insert(
        tabl,
        {
            text = L["WeakAuras"],
            value = "weakauras"
        }
    )
    return tabl
end

function GSE.GUIEditorPerformLayout(frame)
    frame:ReleaseChildren()

    local headerGroup = AceGUI:Create("KeyGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")

    local nameeditbox = AceGUI:Create("EditBox")
    nameeditbox:SetLabel(L["Sequence Name"])
    nameeditbox:SetWidth(250)
    nameeditbox:SetCallback(
        "OnTextChanged",
        function()
            if not editframe.reloading then
                editframe.SequenceName = nameeditbox:GetText()
            end
        end
    )
    -- nameeditbox:SetScript("OnEditFocusLost", function()
    --  editframe:SetText(string.upper(editframe:GetText()))
    --  editframe.SequenceName = nameeditbox:GetText()
    -- end)
    nameeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Sequence Name"],
                L[
                    "The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."
                ],
                editframe
            )
        end
    )
    nameeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    nameeditbox:DisableButton(true)
    nameeditbox:SetText(editframe.SequenceName)
    editframe.nameeditbox = nameeditbox

    local spacerlabel = AceGUI:Create("Label")
    spacerlabel:SetWidth(10)

    local iconpicker = AceGUI:Create("Icon")
    iconpicker:SetImageSize(40, 40)
    iconpicker:SetLabel(L["Macro Icon"])
    iconpicker.frame:RegisterForDrag("LeftButton")
    iconpicker.frame:SetScript(
        "OnDragStart",
        function()
            if not GSE.isEmpty(editframe.SequenceName) then
                PickupMacro(editframe.SequenceName)
            end
        end
    )
    iconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
    iconpicker:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Macro Icon"],
                L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."],
                editframe
            )
        end
    )
    iconpicker:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    headerGroup:AddChild(iconpicker)
    headerGroup:AddChild(spacerlabel)
    headerGroup:AddChild(nameeditbox)

    editframe.iconpicker = iconpicker

    frame:AddChild(headerGroup)

    local tabgrp = AceGUI:Create("TabGroup")
    tabgrp:SetLayout("Flow")
    tabgrp:SetTabs(GSE.GUICreateEditorTabs())
    editframe.ContentContainer = tabgrp

    tabgrp:SetCallback(
        "OnGroupSelected",
        function(container, event, group)
            GSE.GUISelectEditorTab(container, event, group)
        end
    )

    tabgrp:SetFullWidth(true)
    tabgrp:SetFullHeight(true)

    tabgrp:SelectTab("config")
    frame:AddChild(tabgrp)

    local editOptionsbutton = AceGUI:Create("Button")
    editOptionsbutton:SetText(L["Options"])
    editOptionsbutton:SetWidth(100)
    editOptionsbutton:SetCallback(
        "OnClick",
        function()
            GSE.OpenOptionsPanel()
        end
    )
    editOptionsbutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Options"], L["Opens the GSE Options window"], editframe)
        end
    )
    editOptionsbutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local transbutton = AceGUI:Create("Button")
    transbutton:SetText(L["Send"])
    transbutton:SetWidth(100)
    transbutton:SetCallback(
        "OnClick",
        function()
            GSE.GUIShowTransmissionGui(editframe.ClassID .. "," .. editframe.SequenceName)
        end
    )
    transbutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Send"],
                L["Send this macro to another GSE player who is on the same server as you are."],
                editframe
            )
        end
    )
    transbutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local editButtonGroup = AceGUI:Create("KeyGroup")

    editButtonGroup:SetWidth(602)
    editButtonGroup:SetLayout("Flow")
    editButtonGroup:SetHeight(15)

    local savebutton = AceGUI:Create("Button")
    savebutton:SetText(L["Save"])
    savebutton:SetWidth(100)
    savebutton:SetCallback(
        "OnClick",
        function()
            if GSE.isEmpty(editframe.invalidPause) then
                local gameversion, build, date, tocversion = GetBuildInfo()
                editframe.Sequence.MetaData.ManualIntervention = true
                editframe.Sequence.MetaData.GSEVersion = GSE.VersionNumber
                editframe.Sequence.MetaData.EnforceCompatability = true
                editframe.Sequence.MetaData.TOC = tocversion
                nameeditbox:SetText(string.upper(nameeditbox:GetText()))
                editframe.SequenceName = GSE.UnEscapeString(nameeditbox:GetText())
                GSE.GUIUpdateSequenceDefinition(editframe.ClassID, editframe.SequenceName, editframe.Sequence)
                editframe.save = true
                C_Timer.After(
                    5,
                    function()
                        GSE.GUIEditFrame:SetStatusText(editframe.statusText)
                    end
                )
            else
                GSE.Print(L["Error processing Custom Pause Value.  You will need to recheck your macros."], "ERROR")
            end
        end
    )

    savebutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Save"], L["Save the changes made to this macro"], editframe)
        end
    )
    savebutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    editButtonGroup:AddChild(savebutton)
    editframe.SaveButton = savebutton

    local delbutton = AceGUI:Create("Button")
    delbutton:SetText(L["Delete"])
    delbutton:SetWidth(100)
    delbutton:SetCallback(
        "OnClick",
        function()
            editframe:Hide()
            GSE.GUIDeleteSequence(editframe.ClassID, editframe.SequenceName)
        end
    )
    delbutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete"], L["Delete this macro.  This is not able to be undone."], editframe)
        end
    )
    delbutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    editButtonGroup:AddChild(delbutton)

    editButtonGroup:AddChild(transbutton)
    editButtonGroup:AddChild(editOptionsbutton)
    frame:AddChild(editButtonGroup)
    GSE.GUIEditFrame:SetStatusText(editframe.statusText)
end

function GSE.GetVersionList()
    local tabl = {}
    for k, _ in ipairs(editframe.Sequence.Macros) do
        tabl[tostring(k)] = tostring(k)
    end
    return tabl
end

function GSE:GUIDrawMetadataEditor(container)
    -- Default frame size = 700 w x 500 h

    editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))

    local scrollcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetHeight(editframe.Height - 255)
    scrollcontainer:SetLayout("Fill") -- Important!

    local contentcontainer = AceGUI:Create("ScrollFrame")
    scrollcontainer:AddChild(contentcontainer)

    local metaKeyGroup = AceGUI:Create("KeyGroup")
    metaKeyGroup:SetLayout("Flow")
    metaKeyGroup:SetWidth(editframe.Width - 100)

    local speciddropdown = AceGUI:Create("Dropdown")
    speciddropdown:SetLabel(L["Specialisation / Class ID"])
    speciddropdown:SetWidth(200)
    speciddropdown:SetList(GSE.GetSpecNames())
    speciddropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            local sid = Statics.SpecIDHashList[key]
            editframe.Sequence.MetaData.SpecID = sid

            if tonumber(sid) > 12 then
                editframe.ClassID = GSE.GetClassIDforSpec(tonumber(sid))
            else
                editframe.ClassID = tonumber(sid)
            end
        end
    )
    speciddropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Specialisation / Class ID"],
                L["What class or spec is this macro for?  If it is for all classes choose Global."],
                editframe
            )
        end
    )
    speciddropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    metaKeyGroup:AddChild(speciddropdown)
    speciddropdown:SetValue(Statics.SpecIDList[editframe.Sequence.MetaData.SpecID])

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(80)
    metaKeyGroup:AddChild(spacerlabel1)

    local talentseditbox = AceGUI:Create("EditBox")
    talentseditbox:SetLabel(L["Talents"])
    talentseditbox:SetWidth(250)
    talentseditbox:DisableButton(true)
    metaKeyGroup:AddChild(talentseditbox)
    contentcontainer:AddChild(metaKeyGroup)
    talentseditbox:SetText(editframe.Sequence.MetaData.Talents)
    talentseditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Talents = key
        end
    )
    talentseditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Talents"],
                L[
                    "What are the preferred talents for this macro?\n'1,2,3,1,2,3,1' means First row choose the first talent, Second row choose the second talent etc"
                ],
                editframe
            )
        end
    )
    talentseditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local updateTalents = AceGUI:Create("Button")
    updateTalents:SetText(L["Update Talents"])
    updateTalents:SetWidth(120)
    metaKeyGroup:AddChild(updateTalents)
    updateTalents:SetCallback(
        "OnClick",
        function()
            local key = GSE.GetCurrentTalents()
            talentseditbox:SetText(key)
            editframe.Sequence.MetaData.Talents = key
        end
    )
    updateTalents:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Update Talents"],
                L["Update the stored talents to match the current chosen talents."],
                editframe
            )
        end
    )
    updateTalents:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local helpeditbox = AceGUI:Create("MultiLineEditBox")
    helpeditbox:SetLabel(L["Help Information"])
    helpeditbox:SetWidth(250)
    helpeditbox:DisableButton(true)
    helpeditbox:SetNumLines(4)
    helpeditbox:SetFullWidth(true)
    helpeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Help Information"],
                L[
                    "Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."
                ],
                editframe
            )
        end
    )
    helpeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if not GSE.isEmpty(editframe.Sequence.MetaData.Help) then
        helpeditbox:SetText(editframe.Sequence.MetaData.Help)
    end
    helpeditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Help = key
        end
    )
    contentcontainer:AddChild(helpeditbox)

    local helpgroup1 = AceGUI:Create("KeyGroup")
    helpgroup1:SetLayout("Flow")
    helpgroup1:SetWidth(editframe.Width - 100)

    local helplinkeditbox = AceGUI:Create("EditBox")
    helplinkeditbox:SetLabel(L["Help Link"])
    helplinkeditbox:SetWidth(250)
    helplinkeditbox:DisableButton(true)
    helplinkeditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Help Link"],
                L["Website or forum URL where a player can get more information or ask questions about this macro."],
                editframe
            )
        end
    )
    helplinkeditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if not GSE.isEmpty(editframe.Sequence.MetaData.Helplink) then
        helplinkeditbox:SetText(editframe.Sequence.MetaData.Helplink)
    end
    helplinkeditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Helplink = key
        end
    )
    helpgroup1:AddChild(helplinkeditbox)

    local spacerlabel3 = AceGUI:Create("Label")
    spacerlabel3:SetWidth(100)
    helpgroup1:AddChild(spacerlabel3)

    local authoreditbox = AceGUI:Create("EditBox")
    authoreditbox:SetLabel(L["Author"])
    authoreditbox:SetWidth(250)
    authoreditbox:DisableButton(true)
    authoreditbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Author"], L["The author of this macro."], editframe)
        end
    )
    authoreditbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    if not GSE.isEmpty(editframe.Sequence.MetaData.Author) then
        authoreditbox:SetText(editframe.Sequence.MetaData.Author)
    end
    authoreditbox:SetCallback(
        "OnTextChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Author = key
        end
    )
    helpgroup1:AddChild(authoreditbox)

    contentcontainer:AddChild(helpgroup1)

    local defgroup1 = AceGUI:Create("KeyGroup")
    defgroup1:SetLayout("Flow")
    defgroup1:SetWidth(editframe.Width - 100)

    local defaultdropdown = AceGUI:Create("Dropdown")
    defaultdropdown:SetLabel(L["Default Version"])
    defaultdropdown:SetWidth(250)
    defaultdropdown:SetList(GSE.GetVersionList())
    defaultdropdown:SetValue(tostring(editframe.Sequence.MetaData.Default))
    defaultdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Default = tonumber(key)
        end
    )
    defaultdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Default Version"],
                L["The version of this macro that will be used where no other version has been configured."],
                editframe
            )
        end
    )
    defaultdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local spacerlabel4 = AceGUI:Create("Label")
    spacerlabel4:SetWidth(100)

    local raiddropdown = AceGUI:Create("Dropdown")
    raiddropdown:SetLabel(L["Raid"])
    raiddropdown:SetWidth(250)
    raiddropdown:SetList(GSE.GetVersionList())
    raiddropdown:SetValue(tostring(editframe.Sequence.MetaData.Raid))
    raiddropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Raid = nil
            else
                editframe.Sequence.MetaData.Raid = tonumber(key)
            end
        end
    )
    raiddropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Raid"],
                L["The version of this macro that will be used when you enter raids."],
                editframe
            )
        end
    )
    raiddropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local defgroup2 = AceGUI:Create("KeyGroup")
    defgroup2:SetLayout("Flow")
    defgroup2:SetWidth(editframe.Width - 100)

    local arenadropdown = AceGUI:Create("Dropdown")
    arenadropdown:SetLabel(L["Arena"])
    arenadropdown:SetWidth(250)
    arenadropdown:SetList(GSE.GetVersionList())
    arenadropdown:SetValue(tostring(editframe.Sequence.MetaData.Arena))
    arenadropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Arena"],
                L[
                    "The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."
                ],
                editframe
            )
        end
    )
    arenadropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    arenadropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Arena = nil
            else
                editframe.Sequence.MetaData.Arena = tonumber(key)
            end
        end
    )

    local mythicdropdown = AceGUI:Create("Dropdown")
    mythicdropdown:SetLabel(L["Mythic"])
    mythicdropdown:SetWidth(250)
    mythicdropdown:SetList(GSE.GetVersionList())
    mythicdropdown:SetValue(tostring(editframe.Sequence.MetaData.Mythic))
    mythicdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Mythic = nil
            else
                editframe.Sequence.MetaData.Mythic = tonumber(key)
            end
        end
    )
    mythicdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Mythic"], L["The version of this macro to use in Mythic Dungeons."], editframe)
        end
    )
    mythicdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local spacerlabel5 = AceGUI:Create("Label")
    spacerlabel5:SetWidth(100)

    local pvpdropdown = AceGUI:Create("Dropdown")
    pvpdropdown:SetLabel(L["PVP"])
    pvpdropdown:SetWidth(250)
    pvpdropdown:SetList(GSE.GetVersionList())
    pvpdropdown:SetValue(tostring(editframe.Sequence.MetaData.PVP))

    pvpdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.PVP = nil
            else
                editframe.Sequence.MetaData.PVP = tonumber(key)
                editframe.PVP = tonumber(key)
            end
        end
    )
    pvpdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["PVP"], L["The version of this macro to use in PVP."], editframe)
        end
    )
    pvpdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local defgroup3 = AceGUI:Create("KeyGroup")
    defgroup3:SetLayout("Flow")
    defgroup3:SetWidth(editframe.Width - 100)

    local dungeondropdown = AceGUI:Create("Dropdown")
    dungeondropdown:SetLabel(L["Dungeon"])
    dungeondropdown:SetWidth(250)
    dungeondropdown:SetList(GSE.GetVersionList())
    dungeondropdown:SetValue(tostring(editframe.Sequence.MetaData.Dungeon))

    dungeondropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Dungeon = nil
            else
                editframe.Sequence.MetaData.Dungeon = tonumber(key)
            end
        end
    )
    dungeondropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Dungeon"], L["The version of this macro to use in normal dungeons."], editframe)
        end
    )
    dungeondropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local spacerlabel6 = AceGUI:Create("Label")
    spacerlabel6:SetWidth(100)

    local heroicdropdown = AceGUI:Create("Dropdown")
    heroicdropdown:SetLabel(L["Heroic"])
    heroicdropdown:SetWidth(250)
    heroicdropdown:SetList(GSE.GetVersionList())
    heroicdropdown:SetValue(tostring(editframe.Sequence.MetaData.Heroic))
    heroicdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Heroic = nil
            else
                editframe.Sequence.MetaData.Heroic = tonumber(key)
            end
        end
    )
    heroicdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Heroic"], L["The version of this macro to use in heroic dungeons."], editframe)
        end
    )
    heroicdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local defgroup4 = AceGUI:Create("KeyGroup")
    defgroup4:SetLayout("Flow")
    defgroup4:SetWidth(editframe.Width - 100)

    local partydropdown = AceGUI:Create("Dropdown")
    partydropdown:SetLabel(L["Party"])
    partydropdown:SetWidth(250)
    partydropdown:SetList(GSE.GetVersionList())
    partydropdown:SetValue(tostring(editframe.Sequence.MetaData.Party))
    partydropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Party = nil
            else
                editframe.Sequence.MetaData.Party = tonumber(key)
            end
        end
    )
    partydropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Party"],
                L["The version of this macro to use when in a party in the world."],
                editframe
            )
        end
    )
    partydropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local spacerlabel7 = AceGUI:Create("Label")
    spacerlabel7:SetWidth(100)

    local defgroup5 = AceGUI:Create("KeyGroup")
    defgroup5:SetLayout("Flow")
    defgroup5:SetWidth(editframe.Width - 100)

    local defgroup6 = AceGUI:Create("KeyGroup")
    defgroup6:SetLayout("Flow")
    defgroup6:SetWidth(editframe.Width - 100)

    local Timewalkingdropdown = AceGUI:Create("Dropdown")
    Timewalkingdropdown:SetLabel(L["Timewalking"])
    Timewalkingdropdown:SetWidth(250)
    Timewalkingdropdown:SetList(GSE.GetVersionList())
    Timewalkingdropdown:SetValue(tostring(editframe.Sequence.MetaData.Timewalking))
    Timewalkingdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Timewalking = nil
            else
                editframe.Sequence.MetaData.Timewalking = tonumber(key)
            end
        end
    )
    Timewalkingdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Timewalking"],
                L["The version of this macro to use when in time walking dungeons."],
                editframe
            )
        end
    )
    Timewalkingdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local spacerlabel8 = AceGUI:Create("Label")
    spacerlabel8:SetWidth(100)

    local mythicplusdropdown = AceGUI:Create("Dropdown")
    mythicplusdropdown:SetLabel(L["Mythic+"])
    mythicplusdropdown:SetWidth(250)
    mythicplusdropdown:SetList(GSE.GetVersionList())
    mythicplusdropdown:SetValue(tostring(editframe.Sequence.MetaData.MythicPlus))
    mythicplusdropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.MythicPlus = nil
            else
                editframe.Sequence.MetaData.MythicPlus = tonumber(key)
            end
        end
    )
    mythicplusdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Mythic+"], L["The version of this macro to use in Mythic+ Dungeons."], editframe)
        end
    )
    mythicplusdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local scenariodropdown = AceGUI:Create("Dropdown")
    scenariodropdown:SetLabel(L["Scenario"])
    scenariodropdown:SetWidth(250)
    scenariodropdown:SetList(GSE.GetVersionList())
    scenariodropdown:SetValue(tostring(editframe.Sequence.MetaData.Scenario))
    scenariodropdown:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            if editframe.Sequence.MetaData.Default == tonumber(key) then
                editframe.Sequence.MetaData.Scenario = nil
            else
                editframe.Sequence.MetaData.Scenario = tonumber(key)
            end
        end
    )
    scenariodropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Scenario"], L["The version of this macro to use in Scenarios."], editframe)
        end
    )
    scenariodropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if GSE.GameMode < 4 then
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
        defgroup6:AddChild(scenariodropdown)

        contentcontainer:AddChild(defgroup1)
        contentcontainer:AddChild(defgroup2)
        contentcontainer:AddChild(defgroup3)
        contentcontainer:AddChild(defgroup4)
        contentcontainer:AddChild(defgroup5)
        contentcontainer:AddChild(defgroup6)
    end

    container:AddChild(scrollcontainer)
end

local function ChooseVersionTab(version, scrollpos)
    GSE.GUIEditorPerformLayout(GSE.GUIEditFrame)
    GSE.GUIEditFrame.ContentContainer:SelectTab(tostring(version))
    if not GSE.isEmpty(editframe.scrollContainer) and scrollpos > 0 then
        editframe.scrollContainer:SetScroll(scrollpos)
    end
end

function GSE:GUIDrawMacroEditor(container, version)
    version = tonumber(version)

    if GSE.isEmpty(editframe.Sequence) then
        editframe.Sequence = {
            ["MetaData"] = {
                ["Author"] = GSE.GetCharacterName(),
                ["Talents"] = GSE.GetCurrentTalents(),
                ["Default"] = 1,
                ["SpecID"] = GSE.GetCurrentSpecID(),
                ["GSEVersion"] = GSE.VersionString
            },
            ["Macros"] = {
                [1] = {
                    ["Actions"] = {
                        [1] = {
                            [1] = "/say Hello",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    ["InbuiltVariables"] = {},
                    ["Variables"] = {}
                }
            }
        }
    end

    setmetatable(editframe.Sequence.Macros[version].Actions, Statics.TableMetadataFunction)
    editframe.booleanFunctions = {}
    editframe.numericFunctions = {}
    for k, v in pairs(editframe.Sequence.Macros[version].Variables) do
        if k ~= "" then
            if type(v) == "string" then
                v = {v}
                -- save the fixed variable
                editframe.Sequence.Macros[version].Variables[k] = v
            end
            local value = GSE.SafeConcat(v, " ")
            if type(value) == "string" then
                local functline = value
                if string.sub(functline, 1, 10) == "function()" then
                    functline = string.sub(functline, 11)
                    functline = functline:sub(1, -4)
                    functline = loadstring(functline)
                    --print(type(functline))
                    if functline ~= nil then
                        value = functline
                    end
                end
            end
            if type(value) == "function" then
                value = value()
                if type(value) == "boolean" then
                    editframe.booleanFunctions[k] = k
                end
                if type(value) == "number" then
                    editframe.numericFunctions[k] = k
                end
            end
        end
    end

    local layoutcontainer = AceGUI:Create("KeyGroup")

    layoutcontainer:SetFullWidth(true)
    layoutcontainer:SetHeight(editframe.Height - 230)
    layoutcontainer:SetLayout("Flow") -- Important!

    local scrollcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    -- scrollcontainer:SetFullWidth(true)
    -- scrollcontainer:SetFullHeight(true) -- Probably?
    scrollcontainer:SetWidth(editframe.Width)
    scrollcontainer:SetHeight(editframe.Height - 255)
    scrollcontainer:SetLayout("Fill") -- Important!
    editframe.scrollStatus = {}

    local contentcontainer = AceGUI:Create("ScrollFrame")
    contentcontainer:SetAutoAdjustHeight(true)
    contentcontainer:SetStatusTable(editframe.scrollStatus)
    editframe.scrollContainer = contentcontainer

    scrollcontainer:AddChild(contentcontainer)

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    linegroup1:SetWidth(editframe.Width)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)

    local basespellspacer = AceGUI:Create("Label")
    basespellspacer:SetWidth(5)

    local spacerlabel7 = AceGUI:Create("Label")
    spacerlabel7:SetWidth(10)

    local delversionbutton = AceGUI:Create("Button")
    delversionbutton:SetText(L["Delete Version"])
    delversionbutton:SetWidth(130)
    delversionbutton:SetCallback(
        "OnClick",
        function()
            GSE.GUIDeleteVersion(version)
        end
    )
    delversionbutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Delete Version"],
                L[
                    "Delete this verion of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
                ],
                editframe
            )
        end
    )
    delversionbutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local delspacerlabel = AceGUI:Create("Label")
    delspacerlabel:SetWidth(5)

    local raweditbutton = AceGUI:Create("Button")
    raweditbutton:SetText(L["Raw Edit"])
    raweditbutton:SetWidth(100)
    raweditbutton:SetCallback(
        "OnClick",
        function()
            local GSE3Macro = GSE.UnEscapeTableRecursive(editframe.Sequence.Macros[version])
            _G["GSE3"].TextBox:SetText(GSE.Dump(GSE3Macro))
            _G["GSE3"].Version = version
            _G["GSE3"]:Show()
            editframe.AdvancedEditor = true
            editframe:Hide()
        end
    )
    raweditbutton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Raw Edit"],
                L[
                    "Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."
                ],
                editframe
            )
        end
    )
    raweditbutton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local previewMacro = AceGUI:Create("Button")
    previewMacro:SetText(L["Compiled Template"])
    previewMacro:SetWidth(150)
    previewMacro:SetCallback(
        "OnClick",
        function()
            local GSE3Macro = GSE.CompileTemplate(editframe.Sequence.Macros[version])
            GSE.GUIShowCompiledMacroGui(GSE3Macro, editframe.SequenceName .. " : " .. version)
        end
    )
    previewMacro:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Compiled Template"], L["Show the compiled version of this macro."], editframe)
        end
    )
    previewMacro:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local linegroup2 = AceGUI:Create("KeyGroup")
    linegroup2:SetLayout("Flow")
    linegroup2:SetWidth(editframe.Width)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(6)

    local addRepeatButton = AceGUI:Create("Icon")
    local addLoopButton = AceGUI:Create("Icon")
    local addActionButton = AceGUI:Create("Icon")
    local addPauseButton = AceGUI:Create("Icon")
    local addIfButton = AceGUI:Create("Icon")

    addActionButton:SetImageSize(20, 20)
    addActionButton:SetWidth(20)
    addActionButton:SetHeight(20)
    addActionButton:SetImage(Statics.ActionsIcons.Action)

    addActionButton:SetCallback(
        "OnClick",
        function()
            local newAction = {
                [1] = "/say Hello",
                ["Type"] = Statics.Actions.Action
            }
            table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
            editframe.scrollStatus.scrollvalue = 1
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    addActionButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
        end
    )
    addActionButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    addLoopButton:SetImageSize(20, 20)
    addLoopButton:SetWidth(20)
    addLoopButton:SetHeight(20)
    addLoopButton:SetImage(Statics.ActionsIcons.Loop)

    addLoopButton:SetCallback(
        "OnClick",
        function()
            local newAction = {
                [1] = {
                    [1] = "/say Hello",
                    ["Type"] = Statics.Actions.Action
                },
                ["StepFunction"] = Statics.Sequential,
                ["Type"] = Statics.Actions.Loop,
                ["Repeat"] = 2
            }
            -- setmetatable(newAction, Statics.TableMetadataFunction)
            table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
            editframe.scrollStatus.scrollvalue = 1
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    addLoopButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
        end
    )
    addLoopButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    addRepeatButton:SetImageSize(20, 20)
    addRepeatButton:SetWidth(20)
    addRepeatButton:SetHeight(20)
    addRepeatButton:SetImage(Statics.ActionsIcons.Repeat)

    addRepeatButton:SetCallback(
        "OnClick",
        function()
            local newAction = {
                [1] = "/say Hello",
                ["Type"] = Statics.Actions.Repeat,
                ["Interval"] = 3
            }

            table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
            editframe.scrollStatus.scrollvalue = 1
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    addRepeatButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Add Repeat"], L["Add a Repeat Block."], editframe)
        end
    )
    addRepeatButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    addPauseButton:SetImageSize(20, 20)
    addPauseButton:SetWidth(20)
    addPauseButton:SetHeight(20)
    addPauseButton:SetImage(Statics.ActionsIcons.Pause)

    addPauseButton:SetCallback(
        "OnClick",
        function()
            local newAction = {
                ["Variable"] = "GCD",
                ["Type"] = Statics.Actions.Pause
            }
            table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
            editframe.scrollStatus.scrollvalue = 1
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    addPauseButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
        end
    )
    addPauseButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    addIfButton:SetImageSize(20, 20)
    addIfButton:SetWidth(20)
    addIfButton:SetHeight(20)
    addIfButton:SetImage(Statics.ActionsIcons.If)

    addIfButton:SetCallback(
        "OnClick",
        function()
            if GSE.TableLength(editframe.booleanFunctions) > 0 then
                local newAction = {
                    [1] = {
                        [1] = {
                            [1] = "/say Variable returned True",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    [2] = {
                        [1] = {
                            [1] = "/say Variable returned False",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    ["Type"] = Statics.Actions.If
                }
                table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        end
    )
    addIfButton:SetCallback(
        "OnEnter",
        function()
            if table.getn(editframe.booleanFunctions) > 0 then
                GSE.CreateToolTip(
                    L["Add If"],
                    L[
                        "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                    ],
                    editframe
                )
            else
                GSE.CreateToolTip(
                    L["Add If"],
                    L["If Blocks require a variable that returns either true or false.  Create the variable first."],
                    editframe
                )
            end
        end
    )
    addIfButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    if GSE.TableLength(editframe.booleanFunctions) < 1 then
        addIfButton:SetDisabled(true)
    end

    local linegroup3 = AceGUI:Create("KeyGroup")
    linegroup3:SetLayout("Flow")
    linegroup3:SetWidth(editframe.Width)

    local spacerlabel3 = AceGUI:Create("Label")
    spacerlabel3:SetWidth(6)

    linegroup1:AddChild(addActionButton)
    linegroup1:AddChild(addRepeatButton)
    linegroup1:AddChild(addLoopButton)
    linegroup1:AddChild(addPauseButton)
    linegroup1:AddChild(addIfButton)

    linegroup1:AddChild(spacerlabel1)
    linegroup1:AddChild(basespellspacer)
    linegroup1:AddChild(previewMacro)
    linegroup1:AddChild(delspacerlabel)
    linegroup1:AddChild(raweditbutton)

    linegroup1:AddChild(spacerlabel7)
    linegroup1:AddChild(delversionbutton)
    layoutcontainer:AddChild(linegroup1)

    local macrocontainer = AceGUI:Create("InlineGroup")
    macrocontainer:SetTitle(L["Sequence"])
    macrocontainer:SetWidth(contentcontainer.frame:GetWidth() - 50)
    GSE:DrawSequenceEditor(macrocontainer, version)
    contentcontainer:AddChild(macrocontainer)
    local variableContainer = AceGUI:Create("InlineGroup")
    variableContainer:SetAutoAdjustHeight(true)
    variableContainer:SetTitle(L["Variables"])
    variableContainer:SetWidth(contentcontainer.frame:GetWidth() - 50)
    GSE:GUIDrawVariableEditor(variableContainer, version)
    contentcontainer:AddChild(variableContainer)
    layoutcontainer:AddChild(scrollcontainer)

    local toolbarcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    toolbarcontainer:SetWidth(contentcontainer.frame:GetWidth() - 50)
    toolbarcontainer:SetLayout("list")
    local heading2 = AceGUI:Create("Label")
    heading2:SetText(L["Use"])
    toolbarcontainer:AddChild(heading2)

    local toolbarrow1 = AceGUI:Create("KeyGroup")
    toolbarrow1:SetLayout("Flow")
    toolbarrow1:SetWidth(contentcontainer.frame:GetWidth() - 50)

    if GSE.isEmpty(editframe.Sequence.Macros[version].InbuiltVariables) then
        editframe.Sequence.Macros[version].InbuiltVariables = {}
    end
    local combatresetcheckbox = AceGUI:Create("CheckBox")
    combatresetcheckbox:SetType("checkbox")
    combatresetcheckbox:SetWidth(78)
    combatresetcheckbox:SetTriState(true)
    combatresetcheckbox:SetLabel(L["Combat"])
    toolbarrow1:AddChild(combatresetcheckbox)
    combatresetcheckbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Combat)
    combatresetcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Combat = value
        end
    )
    combatresetcheckbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Combat"], L["Reset this macro when you exit combat."], editframe)
        end
    )
    combatresetcheckbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local headingspace1 = AceGUI:Create("Label")
    headingspace1:SetText(" ")
    local heading1 = AceGUI:Create("Label")
    heading1:SetText(L["Resets"])

    local toolbarrow2 = AceGUI:Create("KeyGroup")
    toolbarrow2:SetLayout("Flow")
    toolbarrow2:SetWidth(editframe.Width)

    local headcheckbox = AceGUI:Create("CheckBox")
    headcheckbox:SetType("checkbox")
    headcheckbox:SetWidth(78)
    headcheckbox:SetTriState(true)
    headcheckbox:SetLabel(L["Head"])
    headcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Head = value
        end
    )
    headcheckbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Head)
    headcheckbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Head"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    headcheckbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    toolbarrow2:AddChild(headcheckbox)

    local neckcheckbox = AceGUI:Create("CheckBox")
    neckcheckbox:SetType("checkbox")
    neckcheckbox:SetWidth(78)
    neckcheckbox:SetTriState(true)
    neckcheckbox:SetLabel(L["Neck"])
    neckcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Neck = value
        end
    )
    neckcheckbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Neck)
    neckcheckbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Neck"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    neckcheckbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    toolbarrow2:AddChild(neckcheckbox)

    local beltcheckbox = AceGUI:Create("CheckBox")
    beltcheckbox:SetType("checkbox")
    beltcheckbox:SetWidth(78)
    beltcheckbox:SetTriState(true)
    beltcheckbox:SetLabel(L["Belt"])
    beltcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Belt = value
        end
    )
    beltcheckbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Belt)
    beltcheckbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Belt"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    beltcheckbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    toolbarrow2:AddChild(beltcheckbox)

    local ring1checkbox = AceGUI:Create("CheckBox")
    ring1checkbox:SetType("checkbox")
    ring1checkbox:SetWidth(68)
    ring1checkbox:SetTriState(true)
    ring1checkbox:SetLabel(L["Ring 1"])
    ring1checkbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Ring1 = value
        end
    )
    ring1checkbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Ring 1"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    ring1checkbox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    ring1checkbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Ring1)
    toolbarrow2:AddChild(ring1checkbox)

    local ring2checkbox = AceGUI:Create("CheckBox")
    ring2checkbox:SetType("checkbox")
    ring2checkbox:SetWidth(68)
    ring2checkbox:SetTriState(true)
    ring2checkbox:SetLabel(L["Ring 2"])
    ring2checkbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Ring2 = value
        end
    )
    ring2checkbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Ring 2"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    ring2checkbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Ring2)
    toolbarrow2:AddChild(ring2checkbox)

    local trinket1checkbox = AceGUI:Create("CheckBox")
    trinket1checkbox:SetType("checkbox")
    trinket1checkbox:SetWidth(78)
    trinket1checkbox:SetTriState(true)
    trinket1checkbox:SetLabel(L["Trinket 1"])
    trinket1checkbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Trinket1 = value
        end
    )
    trinket1checkbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Trinket1)
    trinket1checkbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Trinket 1"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    toolbarrow2:AddChild(trinket1checkbox)

    local trinket2checkbox = AceGUI:Create("CheckBox")
    trinket2checkbox:SetType("checkbox")
    trinket2checkbox:SetWidth(83)
    trinket2checkbox:SetTriState(true)
    trinket2checkbox:SetLabel(L["Trinket 2"])
    trinket2checkbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].InbuiltVariables.Trinket2 = value
        end
    )
    trinket2checkbox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Trinket 2"],
                L[
                    "These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."
                ],
                editframe
            )
        end
    )
    trinket2checkbox:SetValue(editframe.Sequence.Macros[version].InbuiltVariables.Trinket2)
    toolbarrow2:AddChild(trinket2checkbox)

    toolbarcontainer:AddChild(toolbarrow2)
    toolbarcontainer:AddChild(headingspace1)
    toolbarcontainer:AddChild(heading1)
    toolbarcontainer:AddChild(toolbarrow1)
    contentcontainer:AddChild(toolbarcontainer)
    container:AddChild(layoutcontainer)
end

local function addKeyPairRow(container, rowWidth, key, value, version)
    -- print("KEY/VAL", key, value)
    local blank = false
    local oldkey = key
    if GSE.isEmpty(key) then
        key = "MyNewVar" .. math.random(100)
        blank = true
    end
    if GSE.isEmpty(value) then
        value = "My new variable"
        blank = true
    end
    if blank == true then
        editframe.Sequence.Macros[version].Variables[key] = value
        if oldkey ~= key then
            editframe.Sequence.Macros[version].Variables[oldkey] = nil
        end
    end

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    linegroup1:SetWidth(rowWidth)
    rowWidth = rowWidth - 70

    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel()
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(rowWidth * 0.15 + 5)
    keyEditBox:SetText(key)
    local currentKey = key
    keyEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            editframe.Sequence.Macros[version].Variables[text] =
                editframe.Sequence.Macros[version].Variables[currentKey]
            editframe.Sequence.Macros[version].Variables[currentKey] = nil
            currentKey = text
        end
    )
    linegroup1:AddChild(keyEditBox)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueEditBox = AceGUI:Create("MultiLineEditBox")
    valueEditBox:SetLabel()
    valueEditBox:SetNumLines(3)
    valueEditBox:SetWidth(rowWidth * 0.75 + 5)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(value)
    valueEditBox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            editframe.Sequence.Macros[version].Variables[currentKey] = GSE.SplitMeIntolines(text)
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            valueEditBox:SetText(
                GSE.SafeConcat(
                    GSE.TranslateSequence(
                        editframe.Sequence.Macros[version].Variables[currentKey],
                        Statics.TranslatorMode.Current
                    ),
                    "\n"
                )
            )
        end
    )

    linegroup1:AddChild(valueEditBox)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(15)
    linegroup1:AddChild(spacerlabel2)

    local testRowButton = AceGUI:Create("Icon")
    testRowButton:SetImageSize(20, 20)
    testRowButton:SetWidth(20)
    testRowButton:SetHeight(20)
    testRowButton:SetImage("Interface\\Icons\\inv_misc_punchcards_blue")

    testRowButton:SetCallback(
        "OnClick",
        function()
            local val = valueEditBox:GetText()
            if type(val) == "string" then
                local functline = GSE.RemoveComments(val)
                if string.sub(functline, 1, 10) == "function()" then
                    functline = string.sub(functline, 11)
                    functline = functline:sub(1, -4)
                    functline = loadstring(functline)
                    -- print(type(functline))
                    if functline ~= nil then
                        val = functline
                    end
                end
            end
            -- print("updated Type: ".. type(value))
            -- print(value)
            if type(val) == "function" then
                val = val()
            end

            if type(val) == "boolean" then
                val = tostring(val)
            end

            StaticPopupDialogs["GSE-GenericMessage"].text =
                string.format(
                L["The current result of variable |cff0000ff~~%s~~|r is |cFF00D1FF%s|r"],
                keyEditBox:GetText(),
                val
            )
            StaticPopup_Show("GSE-GenericMessage")
        end
    )
    testRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Test Variable"], L["Show the current value of this variable."], editframe)
        end
    )
    testRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    linegroup1:AddChild(testRowButton)

    local deleteRowButton = AceGUI:Create("Icon")
    deleteRowButton:SetImageSize(20, 20)
    deleteRowButton:SetWidth(20)
    deleteRowButton:SetHeight(20)
    deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    deleteRowButton:SetCallback(
        "OnClick",
        function()
            editframe.Sequence.Macros[version].Variables[keyEditBox:GetText()] = nil
            linegroup1:ReleaseChildren()
        end
    )
    deleteRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], editframe)
        end
    )
    deleteRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
    return keyEditBox
end

local function GetBlockToolbar(
    version,
    path,
    width,
    includeAdd,
    headingLabel,
    container,
    disableMove,
    disableDelete,
    dontDeleteLastParent)
    local layoutcontainer = AceGUI:Create("KeyGroup")

    local lastPath = path[#path]

    local parentPath = GSE.CloneSequence(path)
    local blocksThisLevel

    if #parentPath == 1 then
        blocksThisLevel = table.getn(editframe.Sequence.Macros[version].Actions)
    else
        if GSE.isEmpty(dontDeleteLastParent) then
            parentPath[#parentPath] = nil
        end
        blocksThisLevel = table.getn(editframe.Sequence.Macros[version].Actions[parentPath])
    end
    layoutcontainer:SetLayout("Flow")
    layoutcontainer:SetWidth(width)
    layoutcontainer:SetHeight(30)
    local moveUpButton = AceGUI:Create("Icon")
    local moveDownButton = AceGUI:Create("Icon")

    if GSE.isEmpty(disableMove) then
        moveUpButton:SetImageSize(20, 20)
        moveUpButton:SetWidth(20)
        moveUpButton:SetHeight(20)
        moveUpButton:SetImage(Statics.ActionsIcons.Up)

        moveUpButton:SetCallback(
            "OnClick",
            function()
                local original = GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                local destinationPath = {}
                for k, v in ipairs(path) do
                    if k == #path then
                        v = v - 1
                    end
                    table.insert(destinationPath, v)
                end

                editframe.Sequence.Macros[version].Actions[path] =
                    GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[destinationPath])
                editframe.Sequence.Macros[version].Actions[destinationPath] = original
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        moveUpButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Move Up"], L["Move this block up one block."], editframe)
            end
        )
        moveUpButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        moveDownButton:SetImageSize(20, 20)
        moveDownButton:SetWidth(20)
        moveDownButton:SetHeight(20)
        moveDownButton:SetImage(Statics.ActionsIcons.Down)

        moveDownButton:SetCallback(
            "OnClick",
            function()
                local original = GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                local destinationPath = {}
                for k, v in ipairs(path) do
                    if k == #path then
                        v = v + 1
                    end
                    table.insert(destinationPath, v)
                end

                editframe.Sequence.Macros[version].Actions[path] =
                    GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[destinationPath])
                editframe.Sequence.Macros[version].Actions[destinationPath] = original
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        moveDownButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Move Down"], L["Move this block down one block."], editframe)
            end
        )
        moveDownButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
    end

    local deleteBlockButton = AceGUI:Create("Icon")
    deleteBlockButton:SetImageSize(20, 20)
    deleteBlockButton:SetWidth(20)
    deleteBlockButton:SetHeight(20)
    deleteBlockButton:SetImage(Statics.ActionsIcons.Delete)

    deleteBlockButton:SetCallback(
        "OnClick",
        function()
            local delPath = {}
            local delObj
            for k, v in ipairs(path) do
                if k == #path then
                    delObj = v
                else
                    table.insert(delPath, v)
                end
            end
            table.remove(editframe.Sequence.Macros[version].Actions[delPath], delObj)
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    deleteBlockButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Delete Block"],
                L[
                    "Delete this Block from the sequence.  \nWARNING: If this is a loop this will delete all the blocks inside the loop as well."
                ],
                editframe
            )
        end
    )
    deleteBlockButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    local addRepeatButton = AceGUI:Create("Icon")
    local addLoopButton = AceGUI:Create("Icon")
    local addActionButton = AceGUI:Create("Icon")
    local addPauseButton = AceGUI:Create("Icon")
    local addIfButton = AceGUI:Create("Icon")
    if includeAdd then
        addActionButton:SetImageSize(20, 20)
        addActionButton:SetWidth(20)
        addActionButton:SetHeight(20)
        addActionButton:SetImage(Statics.ActionsIcons.Action)

        addActionButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = "/say Hello",
                    ["Type"] = Statics.Actions.Action
                }
                if #path > 1 then
                    table.insert(editframe.Sequence.Macros[version].Actions[parentPath], lastPath + 1, newAction)
                else
                    table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                end
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        addActionButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
            end
        )
        addActionButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addLoopButton:SetImageSize(20, 20)
        addLoopButton:SetWidth(20)
        addLoopButton:SetHeight(20)
        addLoopButton:SetImage(Statics.ActionsIcons.Loop)

        addLoopButton:SetCallback(
            "OnClick",
            function()
                local addPath = {}
                local newAction = {
                    [1] = {
                        [1] = "/say Hello",
                        ["Type"] = Statics.Actions.Action
                    },
                    ["StepFunction"] = Statics.Sequential,
                    ["Type"] = Statics.Actions.Loop,
                    ["Repeat"] = 2
                }

                -- setmetatable(newAction, Statics.TableMetadataFunction)
                if #path > 1 then
                    table.insert(editframe.Sequence.Macros[version].Actions[parentPath], lastPath + 1, newAction)
                else
                    table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                end
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        addLoopButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
            end
        )
        addLoopButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addRepeatButton:SetImageSize(20, 20)
        addRepeatButton:SetWidth(20)
        addRepeatButton:SetHeight(20)
        addRepeatButton:SetImage(Statics.ActionsIcons.Repeat)

        addRepeatButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = "/say Hello",
                    ["Type"] = Statics.Actions.Repeat,
                    ["Repeat"] = 3
                }
                if #path > 1 then
                    table.insert(editframe.Sequence.Macros[version].Actions[parentPath], lastPath + 1, newAction)
                else
                    table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                end
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        addRepeatButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Repeat"], L["Add a Repeat Block."], editframe)
            end
        )
        addRepeatButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        addPauseButton:SetImageSize(20, 20)
        addPauseButton:SetWidth(20)
        addPauseButton:SetHeight(20)
        addPauseButton:SetImage(Statics.ActionsIcons.Pause)

        addPauseButton:SetCallback(
            "OnClick",
            function()
                local addPath = {}
                local newAction = {
                    ["Variable"] = "GCD",
                    ["Type"] = Statics.Actions.Pause
                }
                if #path > 1 then
                    table.insert(editframe.Sequence.Macros[version].Actions[parentPath], lastPath + 1, newAction)
                else
                    table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                end
                ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
            end
        )
        addPauseButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
            end
        )
        addPauseButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addIfButton:SetImageSize(20, 20)
        addIfButton:SetWidth(20)
        addIfButton:SetHeight(20)
        addIfButton:SetImage(Statics.ActionsIcons.If)

        addIfButton:SetCallback(
            "OnClick",
            function()
                if GSE.TableLength(editframe.booleanFunctions) > 0 then
                    local newAction = {
                        [1] = {
                            {
                                [1] = "/say Variable returned True",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        [2] = {
                            {
                                [1] = "/say Variable returned False",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        ["Type"] = Statics.Actions.If
                    }
                    if #path > 1 then
                        table.insert(editframe.Sequence.Macros[version].Actions[parentPath], lastPath + 1, newAction)
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
                end
            end
        )
        addIfButton:SetCallback(
            "OnEnter",
            function()
                if GSE.TableLength(editframe.booleanFunctions) > 0 then
                    GSE.CreateToolTip(
                        L["Add If"],
                        L[
                            "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                        ],
                        editframe
                    )
                else
                    GSE.CreateToolTip(
                        L["Add If"],
                        L["If Blocks require a variable that returns either true or false.  Create the variable first."],
                        editframe
                    )
                end
            end
        )
        addIfButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
    end

    if GSE.isEmpty(disableMove) then
        layoutcontainer:AddChild(moveUpButton)
        layoutcontainer:AddChild(moveDownButton)
        local spacerlabel1 = AceGUI:Create("Label")
        spacerlabel1:SetWidth(5)
        layoutcontainer:AddChild(spacerlabel1)
    end
    layoutcontainer:AddChild(headingLabel)
    if lastPath == 1 then
        moveUpButton:SetDisabled(true)
    elseif lastPath == blocksThisLevel then
        moveDownButton:SetDisabled(true)
    end
    if includeAdd then
        local spacerlabel2 = AceGUI:Create("Label")
        spacerlabel2:SetWidth(5)
        layoutcontainer:AddChild(spacerlabel2)
        layoutcontainer:AddChild(addActionButton)
        layoutcontainer:AddChild(addRepeatButton)
        layoutcontainer:AddChild(addLoopButton)
        layoutcontainer:AddChild(addPauseButton)
        layoutcontainer:AddChild(addIfButton)
    end
    local spacerlabel3 = AceGUI:Create("Label")
    spacerlabel3:SetWidth(30)
    layoutcontainer:AddChild(spacerlabel3)
    if GSE.isEmpty(disableMove) then
        local disableBlock = AceGUI:Create("CheckBox")
        disableBlock:SetType("checkbox")
        disableBlock:SetWidth(130)
        disableBlock:SetTriState(false)
        disableBlock:SetLabel(L["Disable Block"])
        layoutcontainer:AddChild(disableBlock)
        disableBlock:SetValue(editframe.Sequence.Macros[version].Actions[path].Disabled)
        local highlightTexture = container.frame:CreateTexture(nil, "BACKGROUND")
        highlightTexture:SetAllPoints(true)

        disableBlock:SetCallback(
            "OnValueChanged",
            function(sel, object, value)
                editframe.Sequence.Macros[version].Actions[path].Disabled = value
                if value == true then
                    highlightTexture:SetColorTexture(1, 0, 0, 0.15)
                else
                    highlightTexture:SetColorTexture(1, 0, 0, 0)
                end
            end
        )
        if editframe.Sequence.Macros[version].Actions[path].Disabled == true then
            highlightTexture:SetColorTexture(1, 0, 0, 0.15)
        else
            highlightTexture:SetColorTexture(1, 0, 0, 0)
        end

        container:SetCallback(
            "OnRelease",
            function(self, obj, value)
                highlightTexture:SetColorTexture(0, 0, 0, 0)
            end
        )
        disableBlock:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Disable Block"],
                    L[
                        "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
                    ],
                    editframe
                )
            end
        )
        disableBlock:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
    end
    local spacerlabel4 = AceGUI:Create("Label")
    spacerlabel4:SetWidth(15)
    layoutcontainer:AddChild(spacerlabel4)
    if not disableDelete then
        layoutcontainer:AddChild(deleteBlockButton)
    end
    local spacerlabel5 = AceGUI:Create("Label")
    spacerlabel5:SetWidth(15)
    layoutcontainer:AddChild(spacerlabel5)

    local textpath = GSE.SafeConcat(path, ".")
    local patheditbox = AceGUI:Create("EditBox")
    if GSE.isEmpty(disableMove) then
        patheditbox:SetLabel(L["Block Path"])
        patheditbox:SetWidth(80)
        patheditbox:SetCallback(
            "OnEnterPressed",
            function(obj, event, key)
                if not editframe.reloading then
                    -- put the move stuff here.
                    print("moving from " .. textpath .. " to " .. key)
                    local destinationPath = GSE.split(key, ".")
                    for k, v in ipairs(destinationPath) do
                        destinationPath[k] = tonumber(v)
                    end
                    local testpath = GSE.CloneSequence(destinationPath)
                    table.remove(testpath, #testpath)
                    local sourcepath = GSE.CloneSequence(path)
                    for k, v in ipairs(sourcepath) do
                        sourcepath[k] = tonumber(v)
                    end
                    table.remove(sourcepath, #sourcepath)
                    if #testpath > 0 then
                        -- check that the path exists
                        if
                            GSE.isEmpty(editframe.Sequence.Macros[version].Actions[testpath]) or
                                type(editframe.Sequence.Macros[version].Actions[testpath]) ~= "table"
                         then
                            GSE.Print(L["Error: Destination path not found."])
                            return
                        end
                    end

                    if #sourcepath > 0 then
                        -- check that the path exists  If this has happened we have a big problem
                        if
                            GSE.isEmpty(editframe.Sequence.Macros[version].Actions[sourcepath]) or
                                type(editframe.Sequence.Macros[version].Actions[sourcepath]) ~= "table"
                         then
                            GSE.Print(L["Error: Source path not found."])
                            return
                        end
                    end

                    if string.sub(key, 1, string.len(textpath)) == textpath then
                        GSE.Print(L["Error: You cannot move a container to be a child within itself."])
                        return
                    end

                    local insertActions = GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                    local endPoint = tonumber(destinationPath[#destinationPath])

                    local pathPoint = tonumber(path[#path])

                    if #sourcepath > 0 then
                        table.remove(editframe.Sequence.Macros[version].Actions[sourcepath], pathPoint)
                    else
                        table.remove(editframe.Sequence.Macros[version].Actions, pathPoint)
                    end
                    if #testpath > 0 then
                        if endPoint > #testpath + 1 then
                            endPoint = #testpath + 1
                        end
                        table.insert(editframe.Sequence.Macros[version].Actions[testpath], endPoint, insertActions)
                    else
                        if endPoint > #editframe.Sequence.Macros[version].Actions + 1 then
                            endPoint = #editframe.Sequence.Macros[version].Actions + 1
                        end
                        table.insert(editframe.Sequence.Macros[version].Actions, endPoint, insertActions)
                    end
                    ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
                end
            end
        )
        patheditbox:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Block Path"],
                    L[
                        "The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.\nEG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block."
                    ],
                    editframe
                )
            end
        )
        patheditbox:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        -- patheditbox:DisableButton(true)

        patheditbox:SetText(textpath)
        layoutcontainer:AddChild(patheditbox)
    end
    return layoutcontainer
end

local function drawAction(container, action, version, keyPath)
    local maxWidth = container.frame:GetWidth() - 10
    container:SetCallback(
        "OnClick",
        function(widget, _, selected, button)
            --   if button == "RightButton" then
            --   end
        end
    )

    -- Workaround for vanishing label ace3 bug
    local label = AceGUI:Create("Label")
    label:SetFontObject(GameFontNormalLarge)
    container:AddChild(label)

    local hlabel = AceGUI:Create("Label")
    hlabel:SetText(string.format(L["Block Type: %s"], Statics.Actions[action.Type]))
    --hlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
    hlabel:SetFontObject(GameFontNormalLarge)
    hlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
    local includeAdd = true
    -- if action.Type == Statics.Actions.Loop then
    --     includeAdd = true
    -- end

    if action.Type == Statics.Actions.Pause then
        local linegroup1 = AceGUI:Create("KeyGroup")

        linegroup1:SetLayout("Flow")
        linegroup1:SetFullWidth(true)

        local clicksdropdown = AceGUI:Create("Dropdown")
        clicksdropdown:SetLabel(L["Measure"])
        clicksdropdown:SetWidth((editframe.Width) * 0.24)
        local clickdroplist = {
            [L["Clicks"]] = L["How many macro Clicks to pause for?"],
            [L["Milliseconds"]] = L["How many milliseconds to pause for?"],
            ["GCD"] = L["Pause for the GCD."]
            --["Random"] = L["Random - It will select .... a spell, any spell"]
        }
        for k, _ in pairs(editframe.numericFunctions) do
            clickdroplist[k] = L["Local Function: "] .. k
        end
        clicksdropdown:SetList(clickdroplist)
        clicksdropdown:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Step Function"],
                    L[
                        "A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.\nIf using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box."
                    ],
                    editframe
                )
            end
        )
        if not GSE.isEmpty(action.Variable) then
            if action.Variable == "GCD" then
                clicksdropdown:SetValue(action.Variable)
            elseif not GSE.isEmpty(editframe.numericFunctions[action.Variable]) then
                clicksdropdown:SetValue(action.Variable)
            else
                action.Variable = nil
            end
        elseif GSE.isEmpty(action.MS) then
            clicksdropdown:SetValue(L["Clicks"])
        else
            clicksdropdown:SetValue(L["Milliseconds"])
            if action.MS == "~~GCD~~" or action.MS == "GCD" then
                clicksdropdown:SetValue("GCD")
                action.Variable = "GCD"
                action.MS = nil
            end
        end
        clicksdropdown:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        linegroup1:AddChild(clicksdropdown)
        local spacerlabel1 = AceGUI:Create("Label")
        spacerlabel1:SetWidth(5)
        linegroup1:AddChild(spacerlabel1)

        local msvalueeditbox = AceGUI:Create("EditBox")
        msvalueeditbox:SetLabel()

        msvalueeditbox:SetWidth(100)
        msvalueeditbox.editbox:SetNumeric(true)
        msvalueeditbox:DisableButton(true)
        local value = GSE.isEmpty(action.MS) and action.Clicks or action.MS
        if not GSE.isEmpty(action.Clicks) or GSE.isEmpty(action.MS) then
            msvalueeditbox:SetDisabled(false)
        else
            msvalueeditbox:SetDisabled(true)
        end
        msvalueeditbox:SetText(value)
        msvalueeditbox:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                local returnAction = {}
                returnAction["Type"] = action.Type
                if clicksdropdown:GetValue() == L["Clicks"] then
                    returnAction["Clicks"] = tonumber(text)
                else
                    returnAction["MS"] = tonumber(text)
                end
                editframe.Sequence.Macros[version].Actions[keyPath] = returnAction
                GSE.GUIEditFrame:SetStatusText(editframe.statusText)
            end
        )

        msvalueeditbox:SetCallback(
            "OnRelease",
            function(self, event, text)
                msvalueeditbox.editbox:SetNumeric(false)
            end
        )
        clicksdropdown:SetCallback(
            "OnValueChanged",
            function(self, event, text)
                --editframe.Sequence.Macros[version].Variables[keyEditBox:GetText()] = valueEditBox:GetText()
                local returnAction = {}
                returnAction["Type"] = action.Type
                if text == L["Clicks"] then
                    returnAction["Clicks"] = tonumber(msvalueeditbox:GetText())
                    msvalueeditbox:SetDisabled(false)
                elseif text == L["Milliseconds"] then
                    returnAction["MS"] = tonumber(msvalueeditbox:GetText())
                    msvalueeditbox:SetDisabled(false)
                else
                    returnAction["Variable"] = text
                    msvalueeditbox:SetDisabled(true)
                end

                editframe.Sequence.Macros[version].Actions[keyPath] = returnAction
            end
        )
        if clicksdropdown:GetValue() == L["Milliseconds"] or clicksdropdown:GetValue() == L["Clicks"] then
            msvalueeditbox:SetDisabled(false)
        else
            msvalueeditbox:SetDisabled(true)
        end
        linegroup1:AddChild(msvalueeditbox)

        container:AddChild(GetBlockToolbar(version, keyPath, maxWidth, includeAdd, hlabel, linegroup1))
        container:AddChild(linegroup1)
    elseif action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then
        local macroPanel = AceGUI:Create("KeyGroup")

        macroPanel:SetLayout("List")
        macroPanel:SetFullWidth(true)
        macroPanel:SetAutoAdjustHeight(true)

        local linegroup1 = GetBlockToolbar(version, keyPath, maxWidth, includeAdd, hlabel, macroPanel)

        if action.Type == Statics.Actions.Repeat then
            local looplimit = AceGUI:Create("EditBox")
            looplimit:SetLabel(L["Interval"])
            looplimit:DisableButton(true)
            looplimit:SetMaxLetters(4)
            looplimit:SetWidth(100)
            --print(GSE.Dump(action))
            if GSE.isEmpty(action.Interval) and action.Repeat then
                action.Interval = tonumber(action.Repeat)
                action.Repeat = nil
            end
            if type(action.Interval) ~= "number" or action.Interval < 1 then
                action.Interval = 1
            end
            looplimit:SetText(action.Interval)
            looplimit:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Interval"], L["Insert this block again after how many blocks."], editframe)
                end
            )
            looplimit:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )
            looplimit:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    value = tonumber(value)
                    if type(value) == "number" and value > 0 then
                        editframe.Sequence.Macros[version].Actions[keyPath].Interval = value
                    end
                end
            )

            linegroup1:AddChild(looplimit)
        end
        macroPanel:AddChild(linegroup1)
        local valueEditBox = AceGUI:Create("MultiLineEditBox")
        valueEditBox:SetLabel()
        local numlines = #action
        valueEditBox:SetNumLines(numlines)
        valueEditBox:SetWidth(maxWidth)
        valueEditBox:DisableButton(true)
        valueEditBox:SetText(GSE.SafeConcat(GSE.TranslateSequence(action, Statics.TranslatorMode.Current), "\n"))
        --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Macros[version])
        valueEditBox:SetCallback(
            "OnTextChanged",
            function()
                local returnAction = GSE.SplitMeIntolines(valueEditBox:GetText())
                local boxlines = #returnAction
                returnAction["Type"] = action.Type
                editframe.Sequence.Macros[version].Actions[keyPath] = returnAction
                --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Macros[version])
            end
        )
        valueEditBox:SetCallback(
            "OnEditFocusLost",
            function()
                local translatedact =
                    GSE.TranslateSequence(
                    editframe.Sequence.Macros[version].Actions[keyPath],
                    Statics.TranslatorMode.Current
                )

                for k, v in ipairs(translatedact) do
                    if GSE.isEmpty(v) then
                        translatedact[k] = "\n"
                    end
                end
                valueEditBox:SetText(GSE.SafeConcat(translatedact, "\n"))
            end
        )
        -- valueEditBox:SetCallback('OnEnter', function()
        --     GSE.CreateToolTip(L["Compiled Action"], compiledAction, editframe)
        -- end)
        -- valueEditBox:SetCallback('OnLeave', function()
        --     GSE.ClearTooltip(editframe)
        -- end)
        macroPanel:AddChild(valueEditBox)
        container:AddChild(macroPanel)
    elseif action.Type == Statics.Actions.Loop then
        local macroPanel = AceGUI:Create("KeyGroup")

        macroPanel:SetWidth(maxWidth)
        macroPanel:SetLayout("List")
        macroPanel:SetAutoAdjustHeight(true)
        local linegroup1 = GetBlockToolbar(version, keyPath, maxWidth, includeAdd, hlabel, macroPanel)

        local stepdropdown = AceGUI:Create("Dropdown")
        stepdropdown:SetLabel(L["Step Function"])
        stepdropdown:SetWidth((editframe.Width) * 0.24)
        stepdropdown:SetList(
            {
                [Statics.Sequential] = L["Sequential (1 2 3 4)"],
                [Statics.Priority] = L["Priority List (1 12 123 1234)"],
                [Statics.ReversePriority] = L["Reverse Priority (1 21 321 4321)"],
                [Statics.Random] = L["Random - It will select .... a spell, any spell"]
            }
        )
        stepdropdown:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Step Function"],
                    L[
                        "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
                    ],
                    editframe
                )
            end
        )
        stepdropdown:SetValue(action.StepFunction)
        stepdropdown:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        stepdropdown:SetCallback(
            "OnValueChanged",
            function(sel, object, value)
                editframe.Sequence.Macros[version].Actions[keyPath].StepFunction = value
            end
        )

        local looplimit = AceGUI:Create("EditBox")
        looplimit:SetLabel(L["Repeat"])
        looplimit:DisableButton(true)
        looplimit:SetMaxLetters(4)
        looplimit:SetWidth(100)
        --print(GSE.Dump(action))
        if type(action.Repeat) ~= "number" or action.Repeat < 1 then
            action.Repeat = 1
        end
        looplimit:SetText(action.Repeat)
        looplimit:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Repeat"], L["How many times does this action repeat"], editframe)
            end
        )
        looplimit:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        looplimit:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                value = tonumber(value)
                if type(value) == "number" and value > 0 then
                    editframe.Sequence.Macros[version].Actions[keyPath].Repeat = value
                end
            end
        )

        local spacerlabel1 = AceGUI:Create("Label")
        spacerlabel1:SetWidth(15)
        linegroup1:AddChild(spacerlabel1)
        linegroup1:AddChild(stepdropdown)
        local spacerlabel2 = AceGUI:Create("Label")
        spacerlabel2:SetWidth(5)
        linegroup1:AddChild(spacerlabel2)
        linegroup1:AddChild(looplimit)
        container:AddChild(linegroup1)

        local linegroup2 = AceGUI:Create("KeyGroup")
        linegroup2:SetLayout("Flow")
        linegroup2:SetWidth(maxWidth)

        -- local testRowButton = AceGUI:Create("Icon")
        -- testRowButton:SetImageSize(20, 20)
        -- testRowButton:SetWidth(20)
        -- --testRowButton:SetHeight(20)
        -- testRowButton:SetImage("Interface\\Icons\\spell_nature_cyclone")

        local spacerlabel3 = AceGUI:Create("Label")
        spacerlabel3:SetWidth(45)

        local macroGroup = AceGUI:Create("KeyGroup")
        macroGroup:SetWidth(maxWidth - 45)
        macroGroup:SetLayout("List")
        for key, act in ipairs(action) do
            local newKeyPath = {}
            for _, v in ipairs(keyPath) do
                table.insert(newKeyPath, v)
            end
            table.insert(newKeyPath, key)
            drawAction(macroGroup, act, version, newKeyPath)
        end
        -- testRowButton:SetHeight(macroGroup.frame:GetHeight())
        -- linegroup2:AddChild(testRowButton)
        linegroup2:AddChild(spacerlabel3)
        linegroup2:AddChild(macroGroup)
        macroPanel:AddChild(linegroup2)

        macroPanel.frame:SetBackdrop(
            {
                edgeFile = [[Interface/Buttons/WHITE8X8]],
                edgeSize = 1
            }
        )
        macroPanel.frame:SetBackdropBorderColor(1.0, 0.96, 0.41, 0.15)
        macroPanel:SetCallback(
            "OnRelease",
            function(self, obj, value)
                macroPanel.frame:SetBackdrop(nil)
            end
        )
        container:AddChild(macroPanel)
    elseif action.Type == Statics.Actions.If then
        local macroPanel = AceGUI:Create("KeyGroup")
        macroPanel:SetWidth(maxWidth)
        macroPanel:SetLayout("List")
        macroPanel.frame:SetBackdrop(
            {
                edgeFile = [[Interface/Buttons/WHITE8X8]],
                edgeSize = 1
            }
        )
        macroPanel.frame:SetBackdropBorderColor(1.0, 0.96, 0.41, 0.15)
        macroPanel:SetCallback(
            "OnRelease",
            function(self, obj, value)
                macroPanel.frame:SetBackdrop(nil)
            end
        )
        local linegroup1 = GetBlockToolbar(version, keyPath, maxWidth, false, hlabel, macroPanel)

        local booleanDropdown = AceGUI:Create("Dropdown")
        booleanDropdown:SetLabel(L["Boolean Functions"])
        booleanDropdown:SetWidth((editframe.Width) * 0.24)
        booleanDropdown:SetList(editframe.booleanFunctions)
        booleanDropdown:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Boolean Functions"],
                    L["Boolean Functions are GSE variables that return either a true or false value."],
                    editframe
                )
            end
        )
        if not GSE.isEmpty(action.Variable) then
            booleanDropdown:SetValue(action.Variable)
        end
        booleanDropdown:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        booleanDropdown:SetCallback(
            "OnValueChanged",
            function(sel, object, value)
                editframe.Sequence.Macros[version].Actions[keyPath].Variable = value
            end
        )

        linegroup1:AddChild(booleanDropdown)

        local trueKeyPath = GSE.CloneSequence(keyPath)
        table.insert(trueKeyPath, 1)
        local trueGroup = AceGUI:Create("KeyGroup")
        trueGroup:SetWidth(maxWidth - 45)
        trueGroup:SetLayout("List")

        local tlabel = AceGUI:Create("Label")
        tlabel:SetText("True")
        --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
        tlabel:SetFontObject(GameFontNormalLarge)
        tlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))

        local trueContainer = AceGUI:Create("KeyGroup")
        trueContainer:SetLayout("Flow")
        trueContainer:SetWidth(maxWidth)

        local toolbar =
            GetBlockToolbar(version, trueKeyPath, maxWidth - 45, true, tlabel, trueContainer, true, true, true)
        trueGroup:AddChild(toolbar)

        for key, act in ipairs(action[1]) do
            local newKeyPath = GSE.CloneSequence(trueKeyPath)
            table.insert(newKeyPath, key)
            drawAction(trueGroup, act, version, newKeyPath)
        end

        macroPanel:AddChild(linegroup1)

        local trueindentlabel = AceGUI:Create("Label")
        trueindentlabel:SetWidth(45)
        trueContainer:AddChild(trueindentlabel)

        trueContainer:AddChild(trueGroup)
        macroPanel:AddChild(trueContainer)
        trueGroup.frame:SetBackdrop(
            {
                edgeFile = [[Interface/Buttons/WHITE8X8]],
                edgeSize = 1
            }
        )
        trueGroup.frame:SetBackdropBorderColor(1.0, 0.96, 0.41, 0.15)
        trueGroup:SetCallback(
            "OnRelease",
            function(self, obj, value)
                trueGroup.frame:SetBackdrop(nil)
            end
        )
        -- macroPanel:AddChild(falseGroup)
        local falseKeyPath = GSE.CloneSequence(keyPath)
        table.insert(falseKeyPath, 2)
        local falsegroup = AceGUI:Create("KeyGroup")
        falsegroup:SetWidth(maxWidth - 45)
        falsegroup:SetLayout("List")

        local flabel = AceGUI:Create("Label")
        flabel:SetText("False")
        --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
        flabel:SetFontObject(GameFontNormalLarge)
        flabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
        local falsecontainer = AceGUI:Create("KeyGroup")
        falsecontainer:SetWidth(maxWidth)
        falsecontainer:SetLayout("Flow")

        local toolbar2 =
            GetBlockToolbar(version, falseKeyPath, maxWidth - 45, true, flabel, falsecontainer, true, true, true)
        falsegroup:AddChild(toolbar2)
        falsegroup.frame:SetBackdrop(
            {
                edgeFile = [[Interface/Buttons/WHITE8X8]],
                edgeSize = 1
            }
        )
        falsegroup.frame:SetBackdropBorderColor(1.0, 0.96, 0.41, 0.15)
        falsegroup:SetCallback(
            "OnRelease",
            function(self, obj, value)
                falsegroup.frame:SetBackdrop(nil)
            end
        )
        for key, act in ipairs(action[2]) do
            local newKeyPath = GSE.CloneSequence(falseKeyPath)
            table.insert(newKeyPath, key)
            drawAction(falsegroup, act, version, newKeyPath)
        end

        local falseindentlabel = AceGUI:Create("Label")
        falseindentlabel:SetWidth(45)
        falsecontainer:AddChild(falseindentlabel)
        falsecontainer:AddChild(falsegroup)
        macroPanel:AddChild(falsecontainer)
        container:AddChild(macroPanel)
    end
end

function GSE:DrawSequenceEditor(container, version)
    local maxWidth = container.frame:GetWidth() - 50
    if GSE.isEmpty(editframe.Sequence.Macros[version].Actions) then
        editframe.Sequence.Macros[version].Actions = {
            [1] = {
                [1] = "/say Hello",
                ["Type"] = Statics.Actions.Action
            }
        }
    end

    local macro = editframe.Sequence.Macros[version].Actions

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    font:SetJustifyV("BOTTOM")

    for key, action in ipairs(macro) do
        local macroPanel = AceGUI:Create("KeyGroup")
        macroPanel:SetWidth(maxWidth)
        macroPanel:SetLayout("List")
        local keyPath = {
            [1] = key
        }
        drawAction(macroPanel, action, version, keyPath)

        container:AddChild(macroPanel)
    end
end

function GSE:GUIDrawVariableEditor(container, version)
    local maxWidth = container.frame:GetWidth()
    if GSE.isEmpty(editframe.Sequence.Macros[version].Variables) then
        editframe.Sequence.Macros[version].Variables = {}
    end

    local contentcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    contentcontainer:SetWidth(maxWidth)
    contentcontainer:SetAutoAdjustHeight(true)
    local variableLabel = AceGUI:Create("Heading")
    variableLabel:SetText(L["System Variables"])
    variableLabel:SetWidth(contentcontainer.frame:GetWidth())
    contentcontainer:AddChild(variableLabel)

    for key, value in pairs(Statics.SystemVariableDescriptions) do
        local textlabel = AceGUI:Create("Label")
        local tempLabel = GSEOptions.UNKNOWN .. "~~" .. key .. "~~ " .. Statics.StringReset .. value
        textlabel:SetText(tempLabel)
        textlabel:SetWidth(contentcontainer.frame:GetWidth())
        contentcontainer:AddChild(textlabel)
    end

    local uvariableLabel = AceGUI:Create("Heading")
    uvariableLabel:SetText(L["Macro Variables"])
    uvariableLabel:SetWidth(contentcontainer.frame:GetWidth())
    contentcontainer:AddChild(uvariableLabel)

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    local columnWidth = contentcontainer.frame:GetWidth() - 55

    linegroup1:SetWidth(columnWidth + 5)

    local nameLabel = AceGUI:Create("Heading")
    nameLabel:SetText(L["Name"])
    nameLabel:SetWidth(columnWidth * 0.15)
    linegroup1:AddChild(nameLabel)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueLabel = AceGUI:Create("Heading")
    valueLabel:SetText(L["Value"])
    valueLabel:SetWidth(columnWidth * 0.70)
    linegroup1:AddChild(valueLabel)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(5)
    linegroup1:AddChild(spacerlabel2)

    local delLabel = AceGUI:Create("Heading")
    delLabel:SetText(L["Actions"])
    delLabel:SetWidth(columnWidth * 0.10)
    linegroup1:AddChild(delLabel)
    contentcontainer:AddChild(linegroup1)

    for key, value in GSE.pairsByKeys(editframe.Sequence.Macros[version].Variables) do
        if type(value) == "table" then
            addKeyPairRow(
                contentcontainer,
                columnWidth,
                key,
                GSE.SafeConcat(GSE.TranslateSequence(value, Statics.TranslatorMode.Current), "\n"),
                version
            )
        end
    end

    local addVariablsButton = AceGUI:Create("Button")
    addVariablsButton:SetText(L["Add Variable"])
    addVariablsButton:SetWidth(100)
    addVariablsButton:SetCallback(
        "OnClick",
        function()
            local position = container.frame:GetHeight()
            editframe.Sequence.Macros[version].Variables["NewVar" .. math.random(100)] = {[1] = "My New Variable"}
            ChooseVersionTab(version, editframe.scrollStatus.scrollvalue)
        end
    )
    addVariablsButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Add Variable"],
                L[
                    "Add a substitution variable for this macro.  This can either be a straight string swap or can be a function.  If a lua function the function needs to return a value."
                ],
                editframe
            )
        end
    )
    addVariablsButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    container:AddChild(contentcontainer)
    container:AddChild(addVariablsButton)
end

local function addKeyPairWARow(container, rowWidth, key, value)
    -- print("KEY/VAL", key, value)
    if GSE.isEmpty(key) then
        key = ""
    end
    if GSE.isEmpty(value) then
        value = ""
    end
    -- if type(GSE.isEmpty(value)) ~= "string" then
    --   value = ""
    -- end
    -- if type(GSE.isEmpty(key)) ~= "string" then
    --   key = ""
    -- end

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    linegroup1:SetWidth(rowWidth)
    rowWidth = rowWidth - 70

    local keyEditBox = AceGUI:Create("EditBox")
    keyEditBox:SetLabel()
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(rowWidth * 0.25)
    keyEditBox:SetText(key)
    local oldkey = key
    keyEditBox:SetCallback(
        "OnTextChanged",
        function()
            if GSE.isEmpty(editframe.Sequence.WeakAuras[keyEditBox:GetText()]) then
                editframe.Sequence.WeakAuras[keyEditBox:GetText()] = ""
            else
                editframe.Sequence.WeakAuras[keyEditBox:GetText()] = editframe.Sequence.WeakAuras[oldkey]
            end
            editframe.Sequence.WeakAuras[oldkey] = nil
            oldkey = keyEditBox:GetText()
        end
    )
    linegroup1:AddChild(keyEditBox)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueEditBox = AceGUI:Create("MultiLineEditBox")
    valueEditBox:SetLabel()
    valueEditBox:SetNumLines(3)
    valueEditBox:SetDisabled(false)
    valueEditBox:SetWidth(rowWidth * 0.80)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(value)
    valueEditBox:SetCallback(
        "OnTextChanged",
        function()
            editframe.Sequence.WeakAuras[keyEditBox:GetText()] = valueEditBox:GetText()
        end
    )
    linegroup1:AddChild(valueEditBox)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(8)
    linegroup1:AddChild(spacerlabel2)

    local loadWeakAuraButton = AceGUI:Create("Icon")
    loadWeakAuraButton:SetImageSize(20, 20)
    loadWeakAuraButton:SetWidth(20)
    loadWeakAuraButton:SetHeight(20)
    loadWeakAuraButton:SetImage("Interface\\Icons\\spell_chargepositive")

    loadWeakAuraButton:SetCallback(
        "OnClick",
        function()
            GSE.LoadWeakAura(valueEditBox:GetText())
        end
    )
    loadWeakAuraButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Load WeakAura"], L["Load or update this WeakAura into WeakAuras."], editframe)
        end
    )
    loadWeakAuraButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    linegroup1:AddChild(loadWeakAuraButton)

    local deleteRowButton = AceGUI:Create("Icon")
    deleteRowButton:SetImageSize(20, 20)
    deleteRowButton:SetWidth(20)
    deleteRowButton:SetHeight(20)
    deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    deleteRowButton:SetCallback(
        "OnClick",
        function()
            editframe.Sequence.WeakAuras[keyEditBox:GetText()] = nil
            linegroup1:ReleaseChildren()
        end
    )
    deleteRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Delete WeakAura"], L["Delete this WeakAura from the sequence."], editframe)
        end
    )
    deleteRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
end

function GSE:GUIDrawWeakauraStorage(container)
    if GSE.isEmpty(editframe.Sequence.Variables) then
        editframe.Sequence.Variables = {}
    end

    local layoutcontainer = AceGUI:Create("KeyGroup")
    layoutcontainer:SetFullWidth(true)
    layoutcontainer:SetHeight(editframe.Height - 320)
    layoutcontainer:SetLayout("Flow") -- Important!

    local scrollcontainer = AceGUI:Create("KeyGroup") -- "InlineGroup" is also good
    scrollcontainer:SetFullWidth(true)
    -- scrollcontainer:SetFullHeight(true) -- Probably?
    -- scrollcontainer:SetWidth(editframe.Width )
    scrollcontainer:SetHeight(editframe.Height - 320)
    scrollcontainer:SetLayout("Fill") -- Important!

    local contentcontainer = AceGUI:Create("ScrollFrame")
    scrollcontainer:AddChild(contentcontainer)

    local linegroup1 = AceGUI:Create("KeyGroup")
    linegroup1:SetLayout("Flow")
    local columnWidth = contentcontainer.frame:GetWidth()

    linegroup1:SetWidth(editframe.Width - 50)

    local nameLabel = AceGUI:Create("Heading")
    nameLabel:SetText(L["Name"])
    nameLabel:SetWidth((columnWidth - 25) * 0.25)
    linegroup1:AddChild(nameLabel)

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local valueLabel = AceGUI:Create("Heading")
    valueLabel:SetText(L["Value"])
    valueLabel:SetWidth((columnWidth - 25) * 0.75 - 18)
    linegroup1:AddChild(valueLabel)

    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(5)
    linegroup1:AddChild(spacerlabel2)

    local delLabel = AceGUI:Create("Heading")
    delLabel:SetText(L["Actions"])
    delLabel:SetWidth(45)
    linegroup1:AddChild(delLabel)
    contentcontainer:AddChild(linegroup1)
    for key, value in pairs(editframe.Sequence.WeakAuras) do
        addKeyPairWARow(contentcontainer, columnWidth, key, value)
    end

    local addVariablsButton = AceGUI:Create("Button")
    addVariablsButton:SetText(L["Add WeakAura"])
    addVariablsButton:SetWidth(100)
    addVariablsButton:SetCallback(
        "OnClick",
        function()
            addKeyPairWARow(contentcontainer, columnWidth)
        end
    )
    layoutcontainer:AddChild(scrollcontainer)
    layoutcontainer:AddChild(addVariablsButton)
    container:AddChild(layoutcontainer)
end

function GSE.GUISelectEditorTab(container, event, group)
    if not GSE.isEmpty(container) then
        editframe.reloading = true
        container:ReleaseChildren()
        editframe.SelectedTab = group

        editframe.nameeditbox:SetText(GSE.GUIEditFrame.SequenceName)
        editframe.iconpicker:SetImage(GSE.GetMacroIcon(editframe.ClassID, editframe.SequenceName))
        if group == "config" then
            GSE:GUIDrawMetadataEditor(container)
        elseif group == "new" then
            -- elseif group == "variables" then
            --     GSE:GUIDrawVariableEditor(container)
            -- Copy the Default to a new version
            table.insert(
                editframe.Sequence.Macros,
                GSE.CloneSequence(editframe.Sequence.Macros[editframe.Sequence.MetaData.Default])
            )
            GSE.GUISelectEditorTab(container, event, table.getn(editframe.Sequence.Macros))
            GSE.GUIEditorPerformLayout(editframe)
        elseif group == "weakauras" then
            GSE:GUIDrawWeakauraStorage(container)
        else
            GSE:GUIDrawMacroEditor(container, group)
        end
        editframe.reloading = false
    end
end

function GSE.GUIDeleteVersion(version)
    version = tonumber(version)
    local sequence = editframe.Sequence
    if table.getn(sequence.Macros) <= 1 then
        GSE.Print(L["This is the only version of this macro.  Delete the entire macro to delete this version."])
        return
    end
    if sequence.MetaData.Default == version then
        GSE.Print(
            L[
                "You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."
            ]
        )
        return
    end
    local printtext = L["Macro Version %d deleted."]
    if sequence.MetaData.PVP == version then
        sequence.MetaData.PVP = sequence.MetaData.Default
        printtext = printtext .. " " .. L["PVP setting changed to Default."]
    end
    if sequence.MetaData.Arena == version then
        sequence.MetaData.Arena = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Arena setting changed to Default."]
    end
    if sequence.MetaData.Raid == version then
        sequence.MetaData.Raid = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Raid setting changed to Default."]
    end
    if sequence.MetaData.Mythic == version then
        sequence.MetaData.Mythic = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Mythic setting changed to Default."]
    end
    if sequence.MetaData.Heroic == version then
        sequence.MetaData.Heroic = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Heroic setting changed to Default."]
    end
    if sequence.MetaData.Dungeon == version then
        sequence.MetaData.Dungeon = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Dungeon setting changed to Default."]
    end
    if sequence.MetaData.Party == version then
        sequence.MetaData.Party = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Party setting changed to Default."]
    end
    if sequence.MetaData.MythicPlus == version then
        sequence.MetaData.MythicPlus = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Mythic+ setting changed to Default."]
    end
    if sequence.MetaData.Timewalking == version then
        sequence.MetaData.Timewalking = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Timewalking setting changed to Default."]
    end
    if sequence.MetaData.Scenario == version then
        sequence.MetaData.Scenario = sequence.MetaData.Default
        printtext = printtext .. " " .. L["Scenario setting changed to Default."]
    end

    if sequence.MetaData.Default > 1 then
        sequence.MetaData.Default = tonumber(sequence.MetaData.Default) - 1
    else
        sequence.MetaData.Default = 1
    end

    if not GSE.isEmpty(sequence.MetaData.PVP) and sequence.MetaData.PVP > 1 and sequence.MetaData.PVP >= version then
        sequence.MetaData.PVP = tonumber(sequence.MetaData.PVP) - 1
    end
    if not GSE.isEmpty(sequence.MetaData.Arena) and sequence.MetaData.Arena > 1 and sequence.MetaData.Arena >= version then
        sequence.MetaData.Arena = tonumber(sequence.MetaData.Arena) - 1
    end
    if not GSE.isEmpty(sequence.MetaData.Raid) and sequence.MetaData.Raid > 1 and sequence.MetaData.Raid >= version then
        sequence.MetaData.Raid = tonumber(sequence.MetaData.Raid) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.Mythic) and sequence.MetaData.Mythic > 1 and
            sequence.MetaData.Mythic >= version
     then
        sequence.MetaData.Mythic = tonumber(sequence.MetaData.Mythic) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.MythicPlus) and sequence.MetaData.MythicPlus > 1 and
            sequence.MetaData.MythicPlus >= version
     then
        sequence.MetaData.MythicPlus = tonumber(sequence.MetaData.MythicPlus) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.Timewalking) and sequence.MetaData.Timewalking > 1 and
            sequence.MetaData.Timewalking >= version
     then
        sequence.MetaData.Timewalking = tonumber(sequence.MetaData.Timewalking) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.Heroic) and sequence.MetaData.Heroic > 1 and
            sequence.MetaData.Heroic >= version
     then
        sequence.MetaData.Heroic = tonumber(sequence.MetaData.Heroic) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.Dungeon) and sequence.MetaData.Dungeon > 1 and
            sequence.MetaData.Dungeon >= version
     then
        sequence.MetaData.Dungeon = tonumber(sequence.MetaData.Dungeon) - 1
    end
    if not GSE.isEmpty(sequence.MetaData.Party) and sequence.MetaData.Party > 1 and sequence.MetaData.Party >= version then
        sequence.MetaData.Party = tonumber(sequence.MetaData.Party) - 1
    end
    if
        not GSE.isEmpty(sequence.MetaData.Scenario) and sequence.MetaData.Scenario > 1 and
            sequence.MetaData.Scenario >= version
     then
        sequence.MetaData.Scenario = tonumber(sequence.MetaData.Scenario) - 1
    end
    table.remove(sequence.Macros, version)
    printtext = printtext .. " " .. L["This change will not come into effect until you save this macro."]
    GSE.GUIEditorPerformLayout(editframe)
    GSE.GUIEditFrame.ContentContainer:SelectTab("config")
    GSE.GUIEditFrame:SetStatusText(string.format(printtext, version))
    C_Timer.After(
        5,
        function()
            GSE.GUIEditFrame:SetStatusText(editframe.statusText)
        end
    )
end

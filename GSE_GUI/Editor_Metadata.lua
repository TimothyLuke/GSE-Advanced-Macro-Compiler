local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- Data-driven config for the ten context-version dropdowns.
-- Each entry: key=MetaData field, label=display text, tip=tooltip body,
-- grp=which SimpleGroup row (1-6), spacer=whether a spacer follows this widget.
local contextVersionConfigs = {
    {key="Raid",        label=L["Raid"],        tip=L["The version of this macro that will be used when you enter raids."],                                                                                      grp=1, spacer=true},
    {key="Arena",       label=L["Arena"],       tip=L["The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."],                            grp=2, spacer=false},
    {key="Mythic",      label=L["Mythic"],      tip=L["The version of this macro to use in Mythic Dungeons."],                                                                                                  grp=3, spacer=false},
    {key="MythicPlus",  label=L["Mythic+"],     tip=L["The version of this macro to use in Mythic+ Dungeons."],                                                                                                 grp=3, spacer=true},
    {key="PVP",         label=L["PVP"],         tip=L["The version of this macro to use in PVP."],                                                                                                              grp=2, spacer=true},
    {key="Heroic",      label=L["Heroic"],      tip=L["The version of this macro to use in heroic dungeons."],                                                                                                  grp=4, spacer=false},
    {key="Dungeon",     label=L["Dungeon"],     tip=L["The version of this macro to use in normal dungeons."],                                                                                                  grp=4, spacer=true},
    {key="Timewalking", label=L["Timewalking"], tip=L["The version of this macro to use when in time walking dungeons."],                                                                                       grp=5, spacer=false},
    {key="Party",       label=L["Party"],       tip=L["The version of this macro to use when in a party in the world."],                                                                                        grp=5, spacer=true},
    {key="Scenario",    label=L["Scenario"],    tip=L["The version of this macro to use in Scenarios."],                                                                                                        grp=6, spacer=false},
}

local function DrawTalentsEditor(editframe, container)
    local function drawTalent(container, name, talent)
        local row = AceGUI:Create("SimpleGroup")

        local origname = name
        if GSE.isEmpty(name) then
            name = "New Loadout"
        end
        if GSE.isEmpty(talent) then
            talent = {
                ["TalentSet"] = "",
                ["Description"] = ""
            }
        end

        row:SetLayout("Flow")
        row:SetFullWidth(true)

        local txtname = AceGUI:Create("EditBox")
        txtname:SetLabel("")
        txtname:SetRelativeWidth(0.1)
        txtname:SetText(name)
        txtname:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                name = value
                editframe.Sequence.MetaData.Talents[name] = talent
                if editframe.Sequence.MetaData.Talents[origname] then
                    editframe.Sequence.MetaData.Talents[origname] = nil
                end
                origname = name
            end
        )
        txtname:DisableButton(true)
        row:AddChild(txtname)

        local txtloadout = AceGUI:Create("MultiLineEditBox")
        txtloadout:SetLabel("")
        txtloadout:SetRelativeWidth(0.43)
        txtloadout:SetText(talent.TalentSet)
        txtloadout:SetNumLines(3)
        txtloadout:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                talent.TalentSet = value
                editframe.Sequence.MetaData.Talents[name] = talent
            end
        )
        txtloadout:DisableButton(true)
        row:AddChild(txtloadout)

        local txtdescription = AceGUI:Create("MultiLineEditBox")
        txtdescription:SetLabel("")
        txtdescription:SetRelativeWidth(0.43)
        txtdescription:SetNumLines(3)
        txtdescription:SetText(talent.Description)
        txtdescription:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                talent.Description = value
                editframe.Sequence.MetaData.Talents[name] = talent
            end
        )
        txtdescription:DisableButton(true)
        row:AddChild(txtdescription)

        local delete = AceGUI:Create("InteractiveLabel")

        delete:SetImageSize(25, 25)
        delete:SetRelativeWidth(0.04)
        delete:SetImage(Statics.ActionsIcons.Delete)
        delete:SetCallback(
            "OnClick",
            function()
                editframe.Sequence.MetaData.Talents[name] = nil
                row:Release()
                container:DoLayout()
            end
        )
        row:AddChild(delete)
        container:AddChild(row)
    end
    local talents = editframe.Sequence.MetaData.Talents
    if type(talents) == "string" then
        talents = {
            ["Legacy"] = {
                ["TalentSet"] = talents,
                ["Description"] = "Original Sequence Talent Set"
            }
        }
        editframe.Sequence.MetaData.Talents = talents
    end
    if GSE.isEmpty(talents) then
        talents = {}
        editframe.Sequence.MetaData.Talents = talents
    end

    local talentsheader = AceGUI:Create("Heading")
    talentsheader:SetText(L["Talents"])
    talentsheader:SetFullWidth(true)
    container:AddChild(talentsheader)
    local addtalent = AceGUI:Create("Button")
    addtalent:SetText(L["Add Talent Loadout"])
    addtalent:SetCallback(
        "OnClick",
        function()
            drawTalent(container)
        end
    )

    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("Flow")
    header:SetFullWidth(true)
    local lblname = AceGUI:Create("Heading")

    lblname:SetText(L["Name"])
    lblname:SetRelativeWidth(0.1)
    header:AddChild(lblname)

    local lbltalentset = AceGUI:Create("Heading")
    lbltalentset:SetText(L["Talent Loadout"])
    lbltalentset:SetRelativeWidth(0.4)
    header:AddChild(lbltalentset)

    local lblDescription = AceGUI:Create("Heading")
    lblDescription:SetText(L["Help Information"])
    lblDescription:SetRelativeWidth(0.4)
    header:AddChild(lblDescription)
    container:AddChild(header)

    for k, v in pairs(talents) do
        drawTalent(container, k, v)
    end
    container:AddChild(addtalent)
end

local function GUIDrawMetadataEditor(editframe, container)
    -- Default frame size = 700 w x 500 h

    local metaKeyGroup = AceGUI:Create("SimpleGroup")
    metaKeyGroup:SetLayout("Flow")
    metaKeyGroup:SetFullWidth(true)

    local disableSequence = AceGUI:Create("CheckBox")
    disableSequence:SetLabel(L["Disable Sequence"])
    disableSequence:SetWidth(200)
    disableSequence:SetValue(editframe.Sequence.MetaData.Disabled)
    disableSequence:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
            editframe.Sequence.MetaData.Disabled = key
        end
    )
    disableSequence:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Disable Sequence"], L["Do not compile this Sequence at startup."], editframe)
        end
    )
    disableSequence:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    metaKeyGroup:AddChild(disableSequence)
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
    container:AddChild(metaKeyGroup)

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
    container:AddChild(helpeditbox)

    local helpgroup1 = AceGUI:Create("SimpleGroup")
    helpgroup1:SetLayout("Flow")
    helpgroup1:SetFullWidth(true)

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

    if GSE.isEmpty(editframe.Sequence.MetaData.Helplink) then
        editframe.Sequence.MetaData.Helplink = "https://discord.gg/gseunited"
    end
    helplinkeditbox:SetText(editframe.Sequence.MetaData.Helplink)
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

    container:AddChild(helpgroup1)

    -- Build defgroup1..defgroup6 for the version dropdowns
    local defgroups = {}
    for i = 1, 6 do
        local grp = AceGUI:Create("SimpleGroup")
        grp:SetLayout("Flow")
        grp:SetFullWidth(true)
        defgroups[i] = grp
    end

    -- Default version dropdown goes in defgroup1 first
    local defaultdropdown = AceGUI:Create("Dropdown")
    defaultdropdown:SetLabel(L["Default Version"])
    defaultdropdown:SetWidth(250)

    defaultdropdown:SetList(editframe.GetVersionList())
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

    defgroups[1]:AddChild(defaultdropdown)
    defgroups[1]:AddChild(spacerlabel4)

    -- Spacer labels shared between pairs in the same group row.
    -- We track which spacer counter to use per group.
    local spacerCounters = {5, 5, 6, 7, 8, nil}
    -- The original code used spacerlabel5 between Arena/PVP, spacerlabel6 between Mythic/MythicPlus,
    -- spacerlabel7 between Heroic/Dungeon, spacerlabel8 between Timewalking/MythicPlus.
    -- We reproduce these by inserting a width-100 spacer between items when spacer=false but next item exists.

    -- Build dropdowns from contextVersionConfigs, inserting into the right group with spacers.
    -- Original layout per group:
    --   grp1: defaultdropdown, spacer, raiddropdown
    --   grp2: arenadropdown, spacer, pvpdropdown
    --   grp3: mythicdropdown, spacer, mythicplusdropdown
    --   grp4: heroicdropdown, spacer, dungeondropdown
    --   grp5: Timewalkingdropdown, spacer, partydropdown
    --   grp6: scenariodropdown

    -- Group each config by grp number
    local byGroup = {}
    for _, cfg in ipairs(contextVersionConfigs) do
        if not byGroup[cfg.grp] then byGroup[cfg.grp] = {} end
        table.insert(byGroup[cfg.grp], cfg)
    end

    for grpIdx = 1, 6 do
        local cfgs = byGroup[grpIdx]
        if cfgs then
            for cfgPos, cfg in ipairs(cfgs) do
                local dd = AceGUI:Create("Dropdown")
                dd:SetLabel(cfg.label)
                dd:SetWidth(250)
                dd:SetList(editframe.GetVersionList())
                dd:SetValue(tostring(editframe.Sequence.MetaData[cfg.key]))
                local metaKey = cfg.key
                dd:SetCallback(
                    "OnValueChanged",
                    function(obj, event, key)
                        if editframe.Sequence.MetaData.Default == tonumber(key) then
                            editframe.Sequence.MetaData[metaKey] = nil
                        else
                            editframe.Sequence.MetaData[metaKey] = tonumber(key)
                            -- PVP also mirrors editframe.PVP (original behaviour)
                            if metaKey == "PVP" then
                                editframe.PVP = tonumber(key)
                            end
                        end
                    end
                )
                dd:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(cfg.label, cfg.tip, editframe)
                    end
                )
                dd:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                defgroups[grpIdx]:AddChild(dd)

                -- Insert spacer between items in the same group row (matching original layout)
                if cfgPos < #cfgs then
                    local sp = AceGUI:Create("Label")
                    sp:SetWidth(100)
                    defgroups[grpIdx]:AddChild(sp)
                end
            end
        end
    end

    container:AddChild(defgroups[1])
    container:AddChild(defgroups[2])
    container:AddChild(defgroups[3])
    container:AddChild(defgroups[4])
    container:AddChild(defgroups[5])
    container:AddChild(defgroups[6])

    DrawTalentsEditor(editframe, container)
end

function GSE.GUI.SetupMetadata(editframe)
    editframe.DrawTalentsEditor = function(container)
        DrawTalentsEditor(editframe, container)
    end
    editframe.GUIDrawMetadataEditor = function(container)
        GUIDrawMetadataEditor(editframe, container)
    end
end

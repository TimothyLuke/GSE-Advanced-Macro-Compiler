local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.CreateIconControl) then
    GSE.CreateIconControl = function(action, version, keyPath, sequence, frame)
        local lbl = AceGUI:Create("Label")
        lbl:SetFontObject(GameFontNormalLarge)
        lbl:SetWidth(15)
        lbl:SetHeight(15)

        if action.Icon then
            lbl:SetText("|T" .. action.Icon .. ":0|t")
            return lbl
        end
        local spellinfo = {}
        spellinfo.iconID = Statics.QuestionMarkIconID

        if action.type == "macro" then
            local macro = GSE.UnEscapeString(action.macro)
            if string.sub(macro, 1, 1) == "/" then
                local spellstuff = GSE.GetSpellsFromString(macro)
                if spellstuff and #spellstuff > 1 then
                    spellstuff = spellstuff[1]
                end
                if spellstuff then
                    spellinfo = spellstuff
                end
            else
                spellinfo.name = action.macro
                local macindex = GetMacroIndexByName(spellinfo.name)
                local _, iconid, _ = GetMacroInfo(macindex)
                spellinfo.iconID = iconid
            end
        elseif action.type == "Spell" then
            spellinfo = C_Spell.GetSpellInfo(action.spell)
        end
        if spellinfo.iconID then
            lbl:SetText("|T" .. spellinfo.iconID .. ":0|t")
        end
        return lbl
    end
end
local function BuildVersionLabel(version, label, excludekey)
    version = tostring(version)
    if not label then
        if version == "1" then
            label = L["Default"]
        else
            label = L["Version"]
        end
    end
    if excludekey then
        return label
    else
        return version .. " - " .. label
    end
end
function GSE.CreateEditor()
    if GSE.isEmpty(GSE.GUI.editors) then
        GSE.GUI.editors = {}
    end
    if GSE.GUI.editors[1] and not GSE.Patron then
        return GSE.GUI.editors[1]
    end
    local editframe = AceGUI:Create("Frame")
    table.insert(GSE.GUI.editors, editframe)
    editframe:Hide()
    editframe.frame:SetFrameStrata("MEDIUM")
    editframe.frame:SetClampedToScreen(true)
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
    editframe.statusText = "GSE: " .. GSE.VersionString
    editframe.booleanFunctions = {}
    editframe.frame:SetClampRectInsets(-10, -10, -10, -10)

    local function GUIConfirmDeleteSequence(classid, sequenceName)
        GSE.DeleteSequence(classid, sequenceName)
        for _, v in ipairs(GSE.GUI.editors) do
            v.ManageTree()
        end
    end

    --- This function pops up a confirmation dialog.
    local function GUIDeleteSequence(classid, sequenceName)
        StaticPopupDialogs["GSE-DeleteMacroDialog"].text =
            string.format(
            L[
                "Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."
            ],
            sequenceName
        )
        StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
            GUIConfirmDeleteSequence(classid, sequenceName)
        end

        StaticPopup_Show("GSE-DeleteMacroDialog")
    end

    --- This function then deletes the macro.

    if
        GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor and
            GSEOptions.frameLocations.sequenceeditor.left and
            GSEOptions.frameLocations.sequenceeditor.top
     then
        local editorleft = GSEOptions.frameLocations.sequenceeditor.left
        local editortop = GSEOptions.frameLocations.sequenceeditor.top

        if #GSE.GUI.editors > 0 then
            editorleft = editorleft + 30
            editortop = editortop - 30
            editframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", editorleft, editortop)
            GSEOptions.frameLocations.sequenceeditor.left = editorleft
            GSEOptions.frameLocations.sequenceeditor.top = editortop
        else
            editframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", editorleft, editortop)
        end
    end
    editframe.Height = GSEOptions.editorHeight and GSEOptions.editorHeight or 500
    editframe.Width = GSEOptions.editorWidth and GSEOptions.editorWidth or 700

    if editframe.Height < 500 then
        editframe.Height = 500
        GSEOptions.editorHeight = editframe.Height
    end
    if editframe.Width < 700 then
        editframe.Width = 700
        GSEOptions.editorWidth = editframe.Width
    end
    editframe.frame:SetHeight(editframe.Height)
    editframe.frame:SetWidth(editframe.Width)
    editframe:SetTitle(L["Sequence Editor"])
    editframe:SetCallback(
        "OnClose",
        function(self)
            if self.NewSequences then
                for _, v in ipairs(self.NewSequences) do
                    if GSE.Library[v.class] and GSE.Library[v.class][v.name] then
                        GSE.Library[v.class][v.name] = nil
                    end
                    if GSESequences[v.class] and GSESequences[v.class][v.name] then
                        GSESequences[v.class][v.name] = nil
                    end
                end
            end
            self.OrigSequenceName = nil
            GSE.ClearTooltip(editframe)
            if GSE.isEmpty(GSEOptions.frameLocations) then
                GSEOptions.frameLocations = {}
            end
            if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
                GSEOptions.frameLocations.sequenceeditor = {}
            end

            local left, bottom, w, h = self.frame:GetRect()
            GSEOptions.frameLocations.sequenceeditor.left = left
            GSEOptions.frameLocations.sequenceeditor.top = bottom + h
            GSEOptions.editorHeight = h
            GSEOptions.editorWidth = w
            self:Hide()
            self.Sequence = nil
            self.SequenceName = nil
            self.Raid = nil
            self.PVP = nil
            self.Mythic = nil
            self.Dungeon = nil
            self.Heroic = nil
            self.Party = nil
            self.Arena = nil
            self.Timewalking = nil
            self.MythicPlus = nil
            self.Scenario = nil
            self.ClassID = nil
            self.save = nil
            self.statusText = nil
            self.booleanFunctions = nil
            self.NewSequences = nil
            self:ReleaseChildren()
            for k, v in ipairs(GSE.GUI.editors) do
                if editframe == v then
                    table.remove(GSE.GUI.editors, k)
                end
            end
            -- need to clear the onSizeChanged else the old OnSizeChanged method will reapplu when we recreate the frame.
            self.frame:SetScript(
                "OnSizeChanged",
                function(self, width, height)
                end
            )

            AceGUI:Release(self)
        end
    )

    editframe:SetLayout("Flow")
    editframe.panels = {}

    local function GUIUpdateSequenceDefinition(classid, SequenceName, sequence)
        sequence.LastUpdated = GSE.GetTimestamp()

        if not GSE.isEmpty(SequenceName) then
            if GSE.isEmpty(classid) then
                classid = GSE.GetCurrentClassID()
            end
            sequence.MetaData.Name = SequenceName
            if not GSE.isEmpty(SequenceName) then
                local vals = {}
                vals.action = "Replace"
                vals.sequencename = SequenceName
                vals.sequence = sequence
                vals.classid = classid

                if GSE.ObjectExists(SequenceName) and editframe.newname then
                    editframe:SetStatusText(
                        string.format(L["Sequence Name %s is in Use. Please choose a different name."], SequenceName)
                    )
                    editframe.nameeditbox:SetText(
                        GSEOptions.UNKNOWN .. editframe.nameeditbox:GetText() .. Statics.StringReset
                    )
                    editframe.nameeditbox:SetFocus()
                    return
                end

                -- editframe.ManageTree()

                table.insert(GSE.OOCQueue, vals)
                editframe:SetStatusText(L["Save pending for "] .. SequenceName)
            end
        end
    end

    local basecontainer = AceGUI:Create("SimpleGroup")
    basecontainer:SetLayout("Fill")
    basecontainer:SetFullHeight(true)
    basecontainer:SetFullWidth(true)
    -- basecontainer:SetAutoAdjustHeight(false)
    -- basecontainer:SetHeight(editframe.Height - 100)
    -- basecontainer:SetWidth(editframe.Width)
    editframe:AddChild(basecontainer)

    local treeContainer = AceGUI:Create("GSE-TreeGroup")
    treeContainer:SetFullHeight(true)
    treeContainer:SetFullWidth(true)

    editframe.treeContainer = treeContainer

    basecontainer:AddChild(treeContainer)
    local function DrawTalentsEditor(container)
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
    local function GUIDrawMetadataEditor(container)
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

        local defgroup1 = AceGUI:Create("SimpleGroup")
        defgroup1:SetLayout("Flow")
        defgroup1:SetFullWidth(true)

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

        local raiddropdown = AceGUI:Create("Dropdown")
        raiddropdown:SetLabel(L["Raid"])
        raiddropdown:SetWidth(250)
        raiddropdown:SetList(editframe.GetVersionList())
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

        local defgroup2 = AceGUI:Create("SimpleGroup")
        defgroup2:SetLayout("Flow")
        defgroup2:SetFullWidth(true)

        local arenadropdown = AceGUI:Create("Dropdown")
        arenadropdown:SetLabel(L["Arena"])
        arenadropdown:SetWidth(250)
        arenadropdown:SetList(editframe.GetVersionList())
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
        mythicdropdown:SetList(editframe.GetVersionList())
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
        pvpdropdown:SetList(editframe.GetVersionList())
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

        local defgroup3 = AceGUI:Create("SimpleGroup")
        defgroup3:SetLayout("Flow")
        defgroup3:SetFullWidth(true)

        local dungeondropdown = AceGUI:Create("Dropdown")
        dungeondropdown:SetLabel(L["Dungeon"])
        dungeondropdown:SetWidth(250)
        dungeondropdown:SetList(editframe.GetVersionList())
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
        heroicdropdown:SetList(editframe.GetVersionList())
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

        local defgroup4 = AceGUI:Create("SimpleGroup")
        defgroup4:SetLayout("Flow")
        defgroup4:SetFullWidth(true)

        local partydropdown = AceGUI:Create("Dropdown")
        partydropdown:SetLabel(L["Party"])
        partydropdown:SetWidth(250)
        partydropdown:SetList(editframe.GetVersionList())
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

        local defgroup5 = AceGUI:Create("SimpleGroup")
        defgroup5:SetLayout("Flow")
        defgroup5:SetFullWidth(true)

        local defgroup6 = AceGUI:Create("SimpleGroup")
        defgroup6:SetLayout("Flow")
        defgroup6:SetFullWidth(true)

        local Timewalkingdropdown = AceGUI:Create("Dropdown")
        Timewalkingdropdown:SetLabel(L["Timewalking"])
        Timewalkingdropdown:SetWidth(250)
        Timewalkingdropdown:SetList(editframe.GetVersionList())
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
        mythicplusdropdown:SetList(editframe.GetVersionList())
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
        scenariodropdown:SetList(editframe.GetVersionList())
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

        container:AddChild(defgroup1)
        container:AddChild(defgroup2)
        container:AddChild(defgroup3)
        container:AddChild(defgroup4)
        container:AddChild(defgroup5)
        container:AddChild(defgroup6)

        DrawTalentsEditor(container)
    end

    local function ChooseVersion(container, version, scrollpos, path)
        container:ReleaseChildren()
        editframe.DrawSequenceEditor(container, version, path)
        if not GSE.isEmpty(editframe.scrollContainer) and scrollpos > 0 then
            editframe.scrollContainer:SetScroll(scrollpos)
        end
        editframe.scrollContainer:DoLayout()
    end
    local function drawRawEditor(container, version, tablestring, path)
        container:ReleaseChildren()

        local seqTableEditbox = AceGUI:Create("MultiLineEditBox")
        seqTableEditbox:SetLabel(L["Sequence"])
        seqTableEditbox:DisableButton(true)
        seqTableEditbox:SetNumLines(35)
        seqTableEditbox:SetRelativeWidth(0.95)
        --seqTableEditbox:SetHeight(editframe.Height - 250)
        seqTableEditbox:SetText(tablestring)

        IndentationLib.enable(seqTableEditbox.editBox, Statics.IndentationColorTable, 4)

        local compileButton = AceGUI:Create("Button")
        compileButton:SetText(L["Compile"])
        compileButton:SetWidth(130)
        compileButton:SetCallback(
            "OnClick",
            function()
                local tab
                local load = "return " .. seqTableEditbox:GetText()
                local func, err = loadstring(load)
                if err or not func then
                    GSE.Print(L["Unable to process content.  Fix table and try again."], L["GSE Raw Editor"])
                    if err then
                        GSE.Print(err, L["GSE Raw Editor"])
                    end
                else
                    tab = func()
                    if not GSE.isEmpty(tab) then
                        editframe.Sequence.Macros[version] = tab
                        treeContainer:SelectByValue(path .. "\001" .. version)
                    else
                        GSE.Print(L["Unable to process content.  Fix table and try again."], L["GSE Raw Editor"])
                    end
                end
            end
        )
        -- compileButton:SetCallback(
        --     "OnEnter",
        --     function()
        --         GSE.CreateToolTip(
        --             L["Delete Version"],
        --             L[
        --                 "Delete this verion of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
        --             ],
        --             editframe
        --         )
        --     end
        -- )
        compileButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local cancelButton = AceGUI:Create("Button")
        cancelButton:SetText(L["Cancel"])
        cancelButton:SetWidth(130)
        cancelButton:SetCallback(
            "OnClick",
            function()
                treeContainer:SelectByValue(path .. "\001" .. version)
            end
        )
        -- cancelButton:SetCallback(
        --     "OnEnter",
        --     function()
        --         GSE.CreateToolTip(
        --             L["Delete Version"],
        --             L[
        --                 "Delete this verion of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
        --             ],
        --             editframe
        --         )
        --     end
        -- )
        cancelButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        container:AddChild(seqTableEditbox)

        local toolcontainer = AceGUI:Create("InlineGroup")
        toolcontainer:SetLayout("Flow")

        toolcontainer:SetFullWidth(true)
        toolcontainer:AddChild(compileButton)
        toolcontainer:AddChild(cancelButton)
        container:AddChild(toolcontainer)
    end
    local function DrawSequenceEditor(tcontainer, version, path)
        local function drawAction(pcontainer, action, version, keyPath, treepath)
            local function GetBlockToolbar(
                version,
                path,
                includeAdd,
                headingLabel,
                container,
                disableMove,
                disableDelete,
                dontDeleteLastParent)
                local layoutcontainer = AceGUI:Create("SimpleGroup")

                local lastPath = path[#path]

                local parentPath = GSE.CloneSequence(path)
                local blocksThisLevel

                if #parentPath == 1 then
                    blocksThisLevel = #editframe.Sequence.Macros[version].Actions
                else
                    if GSE.isEmpty(dontDeleteLastParent) then
                        parentPath[#parentPath] = nil
                    end
                    blocksThisLevel = #editframe.Sequence.Macros[version].Actions[parentPath]
                end
                layoutcontainer:SetLayout("Flow")
                layoutcontainer:SetFullWidth(true)
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
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                                ["macro"] = "Need Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            }
                            if #path > 1 then
                                table.insert(
                                    editframe.Sequence.Macros[version].Actions[parentPath],
                                    lastPath + 1,
                                    newAction
                                )
                            else
                                table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                            end
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                                    ["macro"] = "Need Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                },
                                ["StepFunction"] = Statics.Sequential,
                                ["Type"] = Statics.Actions.Loop,
                                ["Repeat"] = 2
                            }

                            -- setmetatable(newAction, Statics.TableMetadataFunction)
                            if #path > 1 then
                                table.insert(
                                    editframe.Sequence.Macros[version].Actions[parentPath],
                                    lastPath + 1,
                                    newAction
                                )
                            else
                                table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                            end
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                                table.insert(
                                    editframe.Sequence.Macros[version].Actions[parentPath],
                                    lastPath + 1,
                                    newAction
                                )
                            else
                                table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                            end
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                            local newAction = {
                                [1] = {
                                    {
                                        ["macro"] = "Need True Stuff Here",
                                        ["type"] = "macro",
                                        ["Type"] = Statics.Actions.Action
                                    }
                                },
                                [2] = {
                                    {
                                        ["macro"] = "Need False Stuff Here",
                                        ["type"] = "macro",
                                        ["Type"] = Statics.Actions.Action
                                    }
                                },
                                ["Type"] = Statics.Actions.If
                            }
                            if #path > 1 then
                                table.insert(
                                    editframe.Sequence.Macros[version].Actions[parentPath],
                                    lastPath + 1,
                                    newAction
                                )
                            else
                                table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                            end
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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
                                    L[
                                        "If Blocks require a variable that returns either true or false.  Create the variable first."
                                    ],
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

                                local insertActions =
                                    GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
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
                                    table.insert(
                                        editframe.Sequence.Macros[version].Actions[testpath],
                                        endPoint,
                                        insertActions
                                    )
                                else
                                    if endPoint > #editframe.Sequence.Macros[version].Actions + 1 then
                                        endPoint = #editframe.Sequence.Macros[version].Actions + 1
                                    end
                                    table.insert(editframe.Sequence.Macros[version].Actions, endPoint, insertActions)
                                end
                                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
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

                    patheditbox:DisableButton(true)

                    patheditbox:SetText(textpath)
                    layoutcontainer:AddChild(patheditbox)
                end
                return layoutcontainer
            end

            -- Workaround for vanishing label ace3 bug
            local label = AceGUI:Create("Label")
            label:SetFontObject(GameFontNormalLarge)
            pcontainer:AddChild(label)

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
                local block = AceGUI:Create("InlineGroup")

                block:SetLayout("List")
                block:SetFullWidth(true)
                local linegroup1 = AceGUI:Create("SimpleGroup")

                linegroup1:SetLayout("Flow")
                linegroup1:SetFullWidth(true)

                local clicksdropdown = AceGUI:Create("Dropdown")
                clicksdropdown:SetLabel(L["Measure"])
                clicksdropdown:SetRelativeWidth(0.24)
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
                            L["Pause"],
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
                        editframe:SetStatusText(editframe.statusText)
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

                block:AddChild(GetBlockToolbar(version, keyPath, includeAdd, hlabel, linegroup1))
                block:AddChild(linegroup1)
                pcontainer:AddChild(block)
            elseif action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then
                local macroPanel = AceGUI:Create("InlineGroup")
                if GSE.isEmpty(action.type) then
                    action.type = "macro"
                    action.macro = ""
                end
                macroPanel:SetLayout("List")
                macroPanel:SetFullWidth(true)
                macroPanel:SetAutoAdjustHeight(true)

                local linegroup1 = GetBlockToolbar(version, keyPath, includeAdd, hlabel, macroPanel)

                macroPanel:AddChild(linegroup1)

                local compiledMacro = AceGUI:Create("Label")
                compiledMacro:SetFullHeight(true)

                local spellEditBox, macroeditbox =
                    GSE.CreateSpellEditBox(action, version, keyPath, editframe.Sequence, compiledMacro, editframe.frame)

                local unitEditBox = AceGUI:Create("EditBox")
                unitEditBox:SetLabel(L["Unit Name"])

                unitEditBox:SetWidth(250)
                unitEditBox:DisableButton(true)
                unitEditBox:SetText(action.unit)
                --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Macros[version])
                unitEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Macros[version].Actions[keyPath].unit = value
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Macros[version])
                    end
                )
                unitEditBox:SetCallback(
                    "OnEditFocusLost",
                    function()
                    end
                )
                -- valueEditBox:SetCallback('OnEnter', function()
                --     GSE.CreateToolTip(L["Compiled Action"], compiledAction, editframe)
                -- end)
                -- valueEditBox:SetCallback('OnLeave', function()
                --     GSE.ClearTooltip(editframe)
                -- end)
                local typegroup = AceGUI:Create("SimpleGroup")
                typegroup:SetFullWidth(true)
                typegroup:SetLayout("Flow")
                local actionicon = GSE.CreateIconControl(action, version, keyPath, editframe.Sequence, macroPanel.frame)
                typegroup:AddChild(actionicon)
                local spellradio = AceGUI:Create("CheckBox")
                spellradio:SetType("radio")
                spellradio:SetLabel(L["Spell"])
                spellradio:SetValue((action.type and action.type == "spell" or false))
                spellradio:SetWidth(70)
                local itemradio = AceGUI:Create("CheckBox")
                itemradio:SetType("radio")
                itemradio:SetLabel(L["Item"])
                itemradio:SetValue((action.type and action.type == "item" or false))
                itemradio:SetWidth(70)
                local macroradio = AceGUI:Create("CheckBox")
                macroradio:SetType("radio")
                macroradio:SetLabel(L["Macro"])
                macroradio:SetValue((action.type and action.type == "macro" or false))
                macroradio:SetWidth(70)
                local petradio = AceGUI:Create("CheckBox")
                petradio:SetType("radio")
                petradio:SetLabel(L["Pet"])
                petradio:SetValue((action.type and action.type == "pet" or false))
                petradio:SetWidth(70)
                local toyradio = AceGUI:Create("CheckBox")
                toyradio:SetType("radio")
                toyradio:SetLabel(L["Toy"])
                toyradio:SetValue((action.type and action.type == "toy" or false))
                toyradio:SetWidth(70)
                typegroup:AddChild(macroradio)
                typegroup:AddChild(spellradio)
                typegroup:AddChild(itemradio)
                typegroup:AddChild(petradio)
                typegroup:AddChild(toyradio)

                local spellcontainer = AceGUI:Create("SimpleGroup")
                spellcontainer:SetLayout("List")
                spellcontainer:SetFullWidth(true)

                spellradio:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            itemradio:SetValue(false)
                            macroradio:SetValue(false)
                            toyradio:SetValue(false)
                            petradio:SetValue(false)
                            action.spell = spellEditBox:GetText()
                            action.macro = nil
                            action.item = nil
                            action.toy = nil
                            action.action = nil
                            action.type = "spell"
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )
                itemradio:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            spellradio:SetValue(false)
                            macroradio:SetValue(false)
                            toyradio:SetValue(false)
                            petradio:SetValue(false)
                            action.spell = nil
                            action.macro = nil
                            action.item = spellEditBox:GetText()
                            action.toy = nil
                            action.action = nil
                            action.type = "item"
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )
                petradio:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            spellradio:SetValue(false)
                            macroradio:SetValue(false)
                            toyradio:SetValue(false)
                            itemradio:SetValue(false)
                            action.spell = nil
                            action.macro = nil
                            action.item = nil
                            action.action = spellEditBox:GetText()
                            action.toy = nil
                            action.type = "pet"
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )
                toyradio:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            spellradio:SetValue(false)
                            macroradio:SetValue(false)
                            itemradio:SetValue(false)
                            petradio:SetValue(false)
                            action.spell = nil
                            action.macro = nil
                            action.item = nil
                            action.action = nil
                            action.toy = spellEditBox:GetText()
                            action.type = "toy"
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )
                macroradio:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            spellradio:SetValue(false)
                            toyradio:SetValue(false)
                            itemradio:SetValue(false)
                            petradio:SetValue(false)
                            action.spell = nil
                            action.macro = macroeditbox:GetText()
                            action.item = nil
                            action.action = nil
                            action.toy = nil
                            action.unit = nil
                            action.type = "macro"
                            ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                        end
                    end
                )

                spellcontainer:AddChild(typegroup)
                if action.type == "macro" then
                    local macrolayout = AceGUI:Create("SimpleGroup")
                    macrolayout:SetLayout("Flow")
                    macrolayout:SetFullWidth(true)
                    local compiledmacrotext =
                        GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                    local lenMacro = string.len(compiledmacrotext)
                    local charcount
                    if lenMacro > 255 then
                        charcount =
                            string.format(
                            GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                            lenMacro
                        )
                    else
                        charcount = string.format(L["%s/255 Characters Used"], lenMacro)
                    end
                    compiledmacrotext = compiledmacrotext .. "\n\n" .. charcount

                    compiledMacro:SetText(compiledmacrotext)
                    compiledMacro.label:SetNonSpaceWrap(true)
                    compiledMacro:SetRelativeWidth(0.45)

                    local spacerm = AceGUI:Create("Label")
                    spacerm:SetRelativeWidth(0.03)
                    macrolayout:AddChild(macroeditbox)
                    macrolayout:AddChild(spacerm)
                    macrolayout:AddChild(compiledMacro)

                    spellcontainer:AddChild(macrolayout)
                else
                    local editcontainer = AceGUI:Create("SimpleGroup")
                    editcontainer:SetLayout("Flow")
                    editcontainer:SetFullWidth(true)
                    editcontainer:AddChild(spellEditBox)
                    editcontainer:AddChild(unitEditBox)
                    spellcontainer:AddChild(editcontainer)
                end

                macroPanel:AddChild(spellcontainer)
                local typerow = AceGUI:Create("SimpleGroup")
                typerow:SetLayout("Flow")
                typerow:SetFullWidth(true)
                local actiontype = AceGUI:Create("CheckBox")
                actiontype:SetType("checkbox")
                actiontype:SetLabel(L["Repeat"])
                actiontype:SetValue(action.Type == Statics.Actions.Repeat and true or false)
                actiontype:SetWidth(70)

                local interval = AceGUI:Create("EditBox")
                interval:SetWidth(30)
                interval:SetText(action.Interval and action.Interval or 3)
                interval:SetDisabled(action.Type == Statics.Actions.Action and true or false)
                interval:DisableButton(true)
                interval.editbox:SetNumeric(true)
                interval:SetCallback(
                    "OnRelease",
                    function(self, event, text)
                        interval.editbox:SetNumeric(false)
                    end
                )
                interval:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Macros[version].Actions[keyPath].Interval = value
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Macros[version])
                    end
                )
                actiontype:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        if value == true then
                            editframe.Sequence.Macros[version].Actions[keyPath].Type = Statics.Actions.Repeat
                            interval:SetDisabled(false)
                        else
                            editframe.Sequence.Macros[version].Actions[keyPath].Type = Statics.Actions.Action
                            interval:SetDisabled(true)
                        end
                    end
                )
                typerow:AddChild(actiontype)
                typerow:AddChild(interval)
                macroPanel:AddChild(typerow)
                pcontainer:AddChild(macroPanel)
            elseif action.Type == Statics.Actions.Loop then
                local layout3 = AceGUI:Create("InlineGroup")
                layout3:SetFullWidth(true)
                layout3:SetLayout("List")
                local linegroup1 = GetBlockToolbar(version, keyPath, includeAdd, hlabel, layout3)

                local stepdropdown = AceGUI:Create("Dropdown")
                stepdropdown:SetLabel(L["Step Function"])
                stepdropdown:SetWidth(200)
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

                layout3:AddChild(linegroup1)
                local macroGroup = AceGUI:Create("SimpleGroup")
                macroGroup:SetFullWidth(true)
                macroGroup:SetLayout("List")
                for key, act in ipairs(action) do
                    local newKeyPath = {}
                    for _, v in ipairs(keyPath) do
                        table.insert(newKeyPath, v)
                    end
                    table.insert(newKeyPath, key)
                    drawAction(macroGroup, act, version, newKeyPath)
                end

                layout3:AddChild(macroGroup)
                pcontainer:AddChild(layout3)
            elseif action.Type == Statics.Actions.If then
                local macroPanel = AceGUI:Create("InlineGroup")
                macroPanel:SetFullWidth(true)
                macroPanel:SetLayout("List")
                macroPanel:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        macroPanel.frame:SetBackdrop(nil)
                    end
                )
                local linegroup1 = GetBlockToolbar(version, keyPath, false, hlabel, macroPanel)

                local booleanEditBox = AceGUI:Create("EditBox")
                booleanEditBox:SetLabel(L["Variable"])
                booleanEditBox:SetWidth(250)
                booleanEditBox:DisableButton(true)
                booleanEditBox:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Variable"],
                            L["Enter the implementation link for this variable. Use '= true' or '= false' to test."],
                            editframe
                        )
                    end
                )
                if not GSE.isEmpty(action.Variable) then
                    booleanEditBox:SetText(action.Variable)
                else
                    booleanEditBox:SetText("= true")
                    action.Variable = "= true"
                end
                booleanEditBox:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                booleanEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Macros[version].Actions[keyPath].Variable = value
                        action.Variable = value
                    end
                )
                if GSE.Patron then
                    booleanEditBox.editbox:SetScript(
                        "OnTabPressed",
                        function(widget, button, down)
                            MenuUtil.CreateContextMenu(
                                editframe.frame,
                                function(ownerRegion, rootDescription)
                                    rootDescription:CreateTitle(L["Insert GSE Variable"])
                                    for k, _ in pairs(GSEVariables) do
                                        rootDescription:CreateButton(
                                            k,
                                            function()
                                                booleanEditBox:SetText([[=GSE.V["]] .. k .. [["]()]])
                                                editframe.Sequence.Macros[version].Actions[keyPath].Variable =
                                                    [[=GSE.V["]] .. k .. [["]()]]
                                                action.Variable = [[=GSE.V["]] .. k .. [["]()]]
                                            end
                                        )
                                    end
                                    rootDescription:CreateTitle(L["Insert Test Case"])
                                    rootDescription:CreateButton(
                                        "True",
                                        function()
                                            booleanEditBox:SetText([[= true]])
                                            editframe.Sequence.Macros[version].Actions[keyPath].Variable = [[= true]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                    rootDescription:CreateButton(
                                        "False",
                                        function()
                                            booleanEditBox:SetText([[= false]])
                                            editframe.Sequence.Macros[version].Actions[keyPath].Variable = [[= false]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
                linegroup1:AddChild(booleanEditBox)

                local trueKeyPath = GSE.CloneSequence(keyPath)
                table.insert(trueKeyPath, 1)
                local trueGroup = AceGUI:Create("InlineGroup")
                trueGroup:SetFullWidth(true)
                trueGroup:SetLayout("List")

                local tlabel = AceGUI:Create("Label")
                tlabel:SetText("True")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                tlabel:SetFontObject(GameFontNormalLarge)
                tlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))

                local trueContainer = AceGUI:Create("SimpleGroup")
                trueContainer:SetLayout("Flow")
                trueContainer:SetFullWidth(true)

                local toolbar = GetBlockToolbar(version, trueKeyPath, true, tlabel, trueContainer, true, true, true)
                trueGroup:AddChild(toolbar)

                for key, act in ipairs(action[1]) do
                    local newKeyPath = GSE.CloneSequence(trueKeyPath)
                    table.insert(newKeyPath, key)
                    drawAction(trueGroup, act, version, newKeyPath)
                end

                macroPanel:AddChild(linegroup1)

                trueContainer:AddChild(trueGroup)
                macroPanel:AddChild(trueContainer)

                -- macroPanel:AddChild(falseGroup)
                local falseKeyPath = GSE.CloneSequence(keyPath)
                table.insert(falseKeyPath, 2)
                local falsegroup = AceGUI:Create("InlineGroup")
                falsegroup:SetFullWidth(true)
                falsegroup:SetLayout("List")

                local flabel = AceGUI:Create("Label")
                flabel:SetText("False")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                flabel:SetFontObject(GameFontNormalLarge)
                flabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
                local falsecontainer = AceGUI:Create("SimpleGroup")
                falsecontainer:SetFullWidth(true)
                falsecontainer:SetLayout("Flow")

                local toolbar2 = GetBlockToolbar(version, falseKeyPath, true, flabel, falsecontainer, true, true, true)
                falsegroup:AddChild(toolbar2)

                for key, act in ipairs(action[2]) do
                    local newKeyPath = GSE.CloneSequence(falseKeyPath)
                    table.insert(newKeyPath, key)
                    drawAction(falsegroup, act, version, newKeyPath)
                end

                falsecontainer:AddChild(falsegroup)
                macroPanel:AddChild(falsecontainer)
                pcontainer:AddChild(macroPanel)
            end
        end
        if GSE.isEmpty(editframe.Sequence.Macros[version].Actions) then
            editframe.Sequence.Macros[version].Actions = {
                [1] = {
                    ["macro"] = "Need Macro Here",
                    ["Type"] = Statics.Actions.Action
                }
            }
        end

        local macro = editframe.Sequence.Macros[version].Actions

        local font = CreateFont("seqPanelFont")
        font:SetFontObject(GameFontNormal)
        font:SetJustifyV("BOTTOM")

        for key, action in ipairs(macro) do
            local macroPanel = AceGUI:Create("SimpleGroup")
            macroPanel:SetFullWidth(true)
            macroPanel:SetLayout("List")
            local keyPath = {
                [1] = key
            }
            drawAction(macroPanel, action, version, keyPath, path)

            tcontainer:AddChild(macroPanel)
        end
    end
    editframe.DrawSequenceEditor = function(...)
        DrawSequenceEditor(...)
    end
    local function GUIDrawMacroEditor(container, version, path)
        version = tonumber(version)

        if GSE.isEmpty(editframe.Sequence) then
            editframe.Sequence = {
                ["MetaData"] = {
                    ["Author"] = GSE.GetCharacterName(),
                    ["Talents"] = {},
                    ["Default"] = 1,
                    ["SpecID"] = GSE.GetCurrentSpecID(),
                    ["GSEVersion"] = GSE.VersionString
                },
                ["Macros"] = {
                    [1] = {
                        ["Actions"] = {
                            [1] = {
                                ["macro"] = "Need Macro Here",
                                ["type"] = "spell",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        ["InbuiltVariables"] = {}
                    }
                }
            }
        end
        local macrocontainer = AceGUI:Create("InlineGroup")
        macrocontainer:SetTitle(L["Sequence"])
        macrocontainer:SetFullWidth(true)
        setmetatable(editframe.Sequence.Macros[version].Actions, Statics.TableMetadataFunction)
        editframe.booleanFunctions = {}
        editframe.numericFunctions = {}

        local layoutcontainer = AceGUI:Create("SimpleGroup")

        layoutcontainer:SetFullWidth(true)
        --layoutcontainer:SetHeight(editframe.Height - 220)
        layoutcontainer:SetLayout("Flow") -- Important!

        local linegroup1 = AceGUI:Create("SimpleGroup")
        linegroup1:SetLayout("Flow")

        linegroup1:SetFullWidth(true)

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
                version = tonumber(version)
                local sequence = editframe.Sequence
                if #sequence.Macros <= 1 then
                    GSE.Print(
                        L["This is the only version of this macro.  Delete the entire macro to delete this version."]
                    )
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

                if
                    not GSE.isEmpty(sequence.MetaData.PVP) and sequence.MetaData.PVP > 1 and
                        sequence.MetaData.PVP >= version
                 then
                    sequence.MetaData.PVP = tonumber(sequence.MetaData.PVP) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Arena) and sequence.MetaData.Arena > 1 and
                        sequence.MetaData.Arena >= version
                 then
                    sequence.MetaData.Arena = tonumber(sequence.MetaData.Arena) - 1
                end
                if
                    not GSE.isEmpty(sequence.MetaData.Raid) and sequence.MetaData.Raid > 1 and
                        sequence.MetaData.Raid >= version
                 then
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
                if
                    not GSE.isEmpty(sequence.MetaData.Party) and sequence.MetaData.Party > 1 and
                        sequence.MetaData.Party >= version
                 then
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
                editframe.ManageTree()
                treeContainer:SelectByValue(path)
                editframe:SetStatusText(string.format(printtext, version))
                C_Timer.After(
                    5,
                    function()
                        editframe:SetStatusText(editframe.statusText)
                    end
                )
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
                drawRawEditor(
                    macrocontainer,
                    version,
                    GSE.Dump(GSE.UnEscapeTableRecursive(editframe.Sequence.Macros[version])),
                    path
                )

                GSE.WagoAnalytics:Switch("Raw Edit", true)
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
                GSE.GUIShowCompiledMacroGui(GSE3Macro, editframe.SequenceName .. " : " .. version, editframe)
                GSE.WagoAnalytics:Switch("Compile Template", true)
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

        local spacerlabel2 = AceGUI:Create("Label")
        spacerlabel2:SetWidth(6)

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
                    ["macro"] = "Need Stuff Here",
                    ["type"] = "macro",
                    ["Type"] = Statics.Actions.Action
                }
                table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
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
                        ["macro"] = "Need Stuff Here",
                        ["type"] = "macro",
                        ["Type"] = Statics.Actions.Action
                    },
                    ["StepFunction"] = Statics.Sequential,
                    ["Type"] = Statics.Actions.Loop,
                    ["Repeat"] = 2
                }
                -- setmetatable(newAction, Statics.TableMetadataFunction)
                table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
                if not editframe.scrollstatus then
                    editframe.scrollStatus = {}
                end
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
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
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
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
                local newAction = {
                    [1] = {
                        [1] = {
                            ["macro"] = "Need True Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    [2] = {
                        [1] = {
                            ["macro"] = "Need False Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    ["Type"] = Statics.Actions.If
                }
                table.insert(editframe.Sequence.Macros[version].Actions, 1, newAction)
                editframe.scrollStatus.scrollvalue = 1
                ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            end
        )
        addIfButton:SetCallback(
            "OnEnter",
            function()
                if #editframe.booleanFunctions > 0 then
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

        local linegroup3 = AceGUI:Create("SimpleGroup")
        linegroup3:SetLayout("Flow")
        linegroup3:SetFullWidth(true)

        local versionLabel = AceGUI:Create("EditBox")
        versionLabel:SetWidth(200)
        versionLabel:SetLabel(L["Version"] .. " " .. L["Name"])
        versionLabel:SetText(BuildVersionLabel(version, editframe.Sequence.Macros[version].Label, true))
        versionLabel:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                editframe.Sequence.Macros[version].Label = text
            end
        )
        versionLabel:DisableButton(true)

        local spacerlabel3 = AceGUI:Create("Label")
        spacerlabel3:SetWidth(6)

        linegroup1:AddChild(addActionButton)
        linegroup1:AddChild(addLoopButton)
        linegroup1:AddChild(addPauseButton)
        linegroup1:AddChild(addIfButton)
        linegroup1:AddChild(versionLabel)
        linegroup1:AddChild(spacerlabel1)
        linegroup1:AddChild(basespellspacer)
        linegroup1:AddChild(previewMacro)
        linegroup1:AddChild(delspacerlabel)
        if GSE.Patron or GSE.Developer then
            linegroup1:AddChild(raweditbutton)
        end

        linegroup1:AddChild(spacerlabel7)
        linegroup1:AddChild(delversionbutton)
        layoutcontainer:AddChild(linegroup1)

        DrawSequenceEditor(macrocontainer, version, path)
        if not editframe.Sequence.MetaData.DisableEditor then
            layoutcontainer:AddChild(macrocontainer)
        end

        local toolbarcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
        toolbarcontainer:SetFullWidth(true)
        toolbarcontainer:SetLayout("list")

        local toolbarrow1 = AceGUI:Create("SimpleGroup")
        toolbarrow1:SetLayout("Flow")
        toolbarrow1:SetFullWidth(true)

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
        --toolbarcontainer:AddChild(toolbarrow2)
        toolbarcontainer:AddChild(headingspace1)
        toolbarcontainer:AddChild(heading1)
        toolbarcontainer:AddChild(toolbarrow1)
        layoutcontainer:AddChild(toolbarcontainer)
        container:AddChild(layoutcontainer)
    end

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
            if editframe.scroller then
                editframe.scroller:SetHeight(editframe.Height - 100)
                editframe.scroller:DoLayout()
            end
        end
    )
    local function showKeybind(bind, button, specialization, loadout, type, rightContainer)
        if type == "KB" then
            if not specialization then
                if GSE.GameMode > 10 then
                    specialization = C_Specialization.GetSpecialization()
                else
                    specialization = 1
                end
            end
            local initialbind = bind
            rightContainer:ReleaseChildren()
            local keybind = AceGUI:Create("ControllerKeybinding")
            keybind:SetLabel(L["Keybind"])
            if not GSE.isEmpty(bind) then
                keybind:SetKey(bind)
            end
            keybind:SetFullWidth(true)
            keybind:SetCallback(
                "OnKeyChanged",
                function(self, _, key)
                    bind = key
                end
            )

            keybind:SetLabel(L["Set Key to Bind"])
            local SequenceListbox = AceGUI:Create("Dropdown")

            SequenceListbox:SetFullWidth(true)
            SequenceListbox:SetLabel(L["Sequence"])
            local names = {}

            for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
                names[k] = k
            end
            for k, _ in pairs(GSESequences[0]) do
                names[k] = k
            end

            SequenceListbox:SetList(names)
            SequenceListbox:SetValue(button)
            SequenceListbox:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    button = key
                end
            )

            local TalentLoadOutList = AceGUI:Create("Dropdown")

            TalentLoadOutList:SetFullWidth(true)
            TalentLoadOutList:SetLabel(L["Talent Loadout"])
            local loadouts = {
                ["All"] = L["All Talent Loadouts"]
            }
            if C_ClassTalents then
                for _, v in ipairs(
                    C_ClassTalents.GetConfigIDsBySpecID(
                        GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
                    )
                ) do
                    local loadoutinfo = C_Traits.GetConfigInfo(v)
                    loadouts[tostring(v)] = loadoutinfo.name
                end
            end
            TalentLoadOutList:SetList(loadouts)

            if loadout then
                TalentLoadOutList:SetValue(loadout)
            else
                TalentLoadOutList:SetValue("All")
            end
            TalentLoadOutList:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    if key == "All" then
                        loadout = nil
                    else
                        loadout = key
                    end
                end
            )

            local savebutton = AceGUI:Create("Button")
            savebutton:SetText(L["Save"])

            savebutton:SetCallback(
                "OnClick",
                function()
                    if not GSE.isEmpty(SequenceListbox:GetValue()) and not GSE.isEmpty(keybind:GetKey()) then
                        local destination = GSE_C["KeyBindings"][tostring(specialization)]
                        if loadout ~= "ALL" and loadout then
                            if GSE.isEmpty(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"]) then
                                GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] = {}
                            end
                            if GSE.isEmpty(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) then
                                GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = {}
                            end
                            destination = GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                        end
                        if initialbind and bind ~= initialbind and not InCombatLockdown() then
                            SetBinding(initialbind)
                            destination[bind] = nil
                        end
                        if destination then
                            destination[bind] = button
                        else
                            GSE.PrintDebugMessage(
                                "Error Saving Keybind " .. bind .. " " .. button,
                                Statics.DebugModules.Storage
                            )
                        end
                        editframe.ManageTree()
                        local keypath
                        if loadout ~= "ALL" and loadout then
                            if GetSpecialization then
                                keypath = table.concat({"KEYBINDINGS", "KB", specialization, loadout, bind}, "\001")
                            else
                                keypath = table.concat({"KEYBINDINGS", "KB", loadout, bind}, "\001")
                            end
                        else
                            if GetSpecialization then
                                keypath = table.concat({"KEYBINDINGS", "KB", specialization, bind}, "\001")
                            else
                                keypath = table.concat({"KEYBINDINGS", "KB", bind}, "\001")
                            end
                        end
                        if keypath then
                            treeContainer:SelectByValue(keypath)
                        end
                        GSE.ReloadKeyBindings()
                    -- if bind ~= initialbind then
                    --     showKeybind(bind, button, specialization, loadout)
                    -- end
                    end
                end
            )

            local delbutton = AceGUI:Create("Button")
            delbutton:SetText(L["Delete"])

            delbutton:SetCallback(
                "OnClick",
                function()
                    if initialbind and not InCombatLockdown() then
                        SetBinding(initialbind)
                    end

                    if loadout ~= "ALL" and loadout then
                        GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] = nil
                        local empty = true
                        for _, _ in pairs(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) do
                            empty = false
                        end
                        if empty then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = nil
                        end
                    else
                        if
                            GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                                GSE_C["KeyBindings"][tostring(specialization)][initialbind]
                         then
                            GSE_C["KeyBindings"][tostring(specialization)][initialbind] = nil
                        end
                    end
                    rightContainer:ReleaseChildren()
                    editframe.ManageTree()
                end
            )

            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")

            row:AddChild(keybind)
            row:AddChild(SequenceListbox)
            row:AddChild(TalentLoadOutList)

            local row2 = AceGUI:Create("SimpleGroup")
            row2:SetFullWidth(true)
            row2:SetLayout("Flow")

            row2:AddChild(savebutton)
            row2:AddChild(delbutton)
            rightContainer:AddChild(row)
            rightContainer:AddChild(row2)
        elseif type == "AO" then
            if not button then
                button = {}
            end
            if button.Bind then
                bind = button.Bind
            end

            if not specialization then
                if GSE.GameMode > 10 then
                    specialization = C_Specialization.GetSpecialization()
                else
                    specialization = 1
                end
            end
            local initialbind = bind
            rightContainer:ReleaseChildren()
            local LABButtonState = AceGUI:Create("Dropdown")
            LABButtonState:SetFullWidth(true)
            LABButtonState:SetLabel(L["Button State"])
            LABButtonState:SetDisabled(true)
            if bind and _G[bind] and _G[bind].state_types then
                local states = {["Default"] = "Default"}
                local default =
                    string.sub(bind, 1, 3) == "BT4" and "0" or string.sub(bind, 1, 4) == "NDui_" and "2" or
                    string.sub(bind, 1, 4) == "CPB_" and "" or
                    "1"
                for k, _ in pairs(_G[bind].state_types) do
                    if k ~= default and k ~= bind then
                        states[k] = k
                    end
                end
                LABButtonState:SetList(states)
                LABButtonState:SetDisabled(false)
            end
            if button and button.State then
                LABButtonState:SetValue(tostring(button.State))
            else
                LABButtonState:SetValue("Default")
            end
            local ActionButtonList = AceGUI:Create("Dropdown")

            ActionButtonList:SetFullWidth(true)
            ActionButtonList:SetLabel(L["Actionbar Buttons"])
            local buttonnames = {
                "ActionButton",
                "MultiBarBottomLeftButton",
                "MultiBarBottomRightButton",
                "MultiBar5Button",
                "MultiBar6Button",
                "MultiBar7Button",
                "MultiBarLeftButton",
                "MultiBarRightButton"
            }
            local buttonlist = {}

            if ElvUI then
                for i = 15, 1, -1 do
                    table.insert(buttonnames, 1, "ElvUI_Bar" .. i .. "Button")
                end
            end

            if NDui then
                for i = 15, 1, -1 do
                    table.insert(buttonnames, 1, "NDui_ActionBar" .. i .. "Button")
                end
            end

            for _, v in ipairs(buttonnames) do
                for i = 1, 12 do
                    if _G[v .. i] then
                        buttonlist[v .. i] = v .. i
                    end
                end
            end
            if ConsolePort then
                buttonlist["CPB_PADDUP"] = "CPB_PADDUP"
                buttonlist["CPB_PADDLEFT"] = "CPB_PADDLEFT"
                buttonlist["CPB_PADDDOWN"] = "CPB_PADDDOWN"
                buttonlist["CPB_PADDRIGHT"] = "CPB_PADDRIGHT"
                buttonlist["CPB_PADLSHOULDER"] = "CPB_PADLSHOULDER"
                buttonlist["CPB_PADRSHOULDER"] = "CPB_PADRSHOULDER"
                buttonlist["CPB_PADRTRIGGER"] = "CPB_PADRTRIGGER"
                buttonlist["CPB_PADLTRIGGER"] = "CPB_PADLTRIGGER"
                buttonlist["CPB_PAD1"] = "CPB_PAD1"
                buttonlist["CPB_PAD2"] = "CPB_PAD2"
                buttonlist["CPB_PAD3"] = "CPB_PAD3"
                buttonlist["CPB_PAD4"] = "CPB_PAD4"
            end

            if Bartender4 then
                local v = "BT4Button"
                for i = 1, 180 do
                    if _G[v .. i] and _G[v .. i]:IsShown() then
                        buttonlist[v .. i] = v .. i
                    end
                end
            end

            local striplist = {}
            if bind then
                buttonlist[bind] = bind
            end
            for k, _ in pairs(buttonlist) do
                table.insert(striplist, k)
            end

            ActionButtonList:SetList(buttonlist, GSE.SortTableAlphabetical(striplist))
            ActionButtonList:SetValue(bind)
            ActionButtonList:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    bind = key

                    button.Bind = key
                    if button.State then
                        bind = key .. "-" .. button.State
                    end
                    if _G[key].state_types then
                        local states = {["Default"] = "Default"}

                        local default =
                            string.sub(bind, 1, 3) == "BT4" and "0" or string.sub(bind, 1, 4) == "NDui_" and "2" or
                            string.sub(bind, 1, 4) == "CPB_" and "" or
                            "1"
                        for k, _ in pairs(_G[bind].state_types) do
                            if k ~= default and k ~= bind then
                                states[k] = k
                            end
                        end

                        LABButtonState:SetList(states)
                        LABButtonState:SetDisabled(false)
                    else
                        LABButtonState:SetDisabled(true)
                        button.State = nil
                    end
                end
            )

            LABButtonState:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    local default =
                        string.sub(ActionButtonList:GetValue(), 1, 3) == "BT4" and "0" or
                        string.sub(ActionButtonList:GetValue(), 1, 4) == "CPB_" and "" or
                        string.sub(ActionButtonList:GetValue(), 1, 4) == "NDui_" and "2" or
                        "1"
                    if key == default or key == "Default" then
                        button["State"] = nil
                        bind = button["Bind"]
                    else
                        button["State"] = key
                        bind = button["Bind"] .. "-" .. button["State"]
                    end
                end
            )

            local SequenceListbox = AceGUI:Create("Dropdown")

            SequenceListbox:SetFullWidth(true)
            SequenceListbox:SetLabel(L["Sequence"])
            local names = {}

            for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
                names[k] = k
            end
            for k, _ in pairs(GSESequences[0]) do
                names[k] = k
            end

            SequenceListbox:SetList(names)
            if button and button.Sequence then
                SequenceListbox:SetValue(button.Sequence)
            end
            SequenceListbox:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    button.Sequence = key
                end
            )

            local TalentLoadOutList = AceGUI:Create("Dropdown")

            TalentLoadOutList:SetFullWidth(true)
            TalentLoadOutList:SetLabel(L["Talent Loadout"])
            local loadouts = {
                ["All"] = L["All Talent Loadouts"]
            }
            if C_ClassTalents then
                for _, v in ipairs(
                    C_ClassTalents.GetConfigIDsBySpecID(
                        GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specialization)
                    )
                ) do
                    local loadoutinfo = C_Traits.GetConfigInfo(v)
                    loadouts[tostring(v)] = loadoutinfo.name
                end
            end
            TalentLoadOutList:SetList(loadouts)

            if loadout then
                TalentLoadOutList:SetValue(loadout)
            else
                TalentLoadOutList:SetValue("All")
            end
            TalentLoadOutList:SetCallback(
                "OnValueChanged",
                function(obj, event, key)
                    if key == "All" then
                        loadout = nil
                    else
                        loadout = key
                    end
                end
            )

            local savebutton = AceGUI:Create("Button")
            savebutton:SetText(L["Save"])

            savebutton:SetCallback(
                "OnClick",
                function()
                    if not GSE.isEmpty(SequenceListbox:GetValue()) and not GSE.isEmpty(ActionButtonList:GetValue()) then
                        local destination = GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)]
                        if loadout ~= "ALL" and loadout then
                            if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
                                GSE_C["ActionBarBinds"]["LoadOuts"] = {}
                            end
                            if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)]) then
                                GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)] = {}
                            end
                            if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]) then
                                GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout] = {}
                            end
                            destination = GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]
                        end
                        if loadout ~= "ALL" and loadout then
                            destination[bind] = button
                        else
                            destination[bind] = button
                        end
                        if bind ~= initialbind then
                            showKeybind(bind, button, specialization, loadout)
                        end
                        -- trigger a reload of KeyBindings
                        GSE.ReloadOverrides()

                        GSE.UpdateIcon(_G[button.Sequence])
                        editframe.ManageTree()
                        if loadout ~= "ALL" and loadout then
                            if GetSpecialization then
                                treeContainer:SelectByPath("KEYBINDINGS", "AO", specialization, loadout, bind)
                            else
                                treeContainer:SelectByPath("KEYBINDINGS", "AO", loadout, bind)
                            end
                        else
                            if GetSpecialization then
                                treeContainer:SelectByPath("KEYBINDINGS", "AO", specialization, bind)
                            else
                                treeContainer:SelectByPath("KEYBINDINGS", "AO", bind)
                            end
                        end
                    end
                end
            )

            local delbutton = AceGUI:Create("Button")
            delbutton:SetText(L["Delete"])

            delbutton:SetCallback(
                "OnClick",
                function()
                    if loadout ~= "ALL" and loadout then
                        GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout][bind] = nil
                        local empty = true
                        for _, _ in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout]) do
                            empty = false
                        end
                        if empty then
                            GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout] = nil
                        end
                    else
                        GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)][bind] = nil
                    end
                    GSE.ButtonOverrides[bind] = nil
                    _G[bind]:SetAttribute("type", "action")
                    SecureHandlerUnwrapScript(_G[bind], "OnClick")
                    rightContainer:ReleaseChildren()
                    editframe.ManageTree()
                end
            )

            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")

            row:AddChild(ActionButtonList)
            row:AddChild(SequenceListbox)
            row:AddChild(TalentLoadOutList)
            row:AddChild(LABButtonState)

            local row2 = AceGUI:Create("SimpleGroup")
            row2:SetFullWidth(true)
            row2:SetLayout("Flow")

            row2:AddChild(savebutton)
            row2:AddChild(delbutton)
            rightContainer:AddChild(row)
            rightContainer:AddChild(row2)
        end
    end

    local function showVariable(name, container)
        editframe.SequenceName = name
        local implementation = AceGUI:Create("EditBox")
        local variable = {
            ["funct"] = [[function()
    return true
end]],
            ["comments"] = ""
        }
        if not GSE.isEmpty(GSEVariables[name]) then
            local status, err =
                pcall(
                function()
                    local _, uncompressedVersion = GSE.DecodeMessage(GSEVariables[name])
                    variable = uncompressedVersion
                end
            )
            if err then
                print(err)
            end
        end

        local keyEditBox = AceGUI:Create("EditBox")
        keyEditBox:SetLabel(L["Name"])
        keyEditBox:DisableButton(true)
        keyEditBox:SetWidth(150)
        keyEditBox:SetText(name)
        local currentKey = name
        keyEditBox:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                local orig = GSEVariables[currentKey]
                GSEVariables[text] = orig
                GSEVariables[currentKey] = nil
                currentKey = text
                local implementationText = [[=GSE.V.]] .. text .. [[()]]
                implementation:SetText(implementationText)
            end
        )

        local authoreditbox = AceGUI:Create("EditBox")
        authoreditbox:SetLabel(L["Author"])
        authoreditbox:SetWidth(250)
        authoreditbox:DisableButton(true)
        authoreditbox:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Author"], L["The author of this Variable."], editframe)
            end
        )
        authoreditbox:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        if not GSE.isEmpty(variable.Author) then
            authoreditbox:SetText(variable.Author)
        else
            authoreditbox:SetText(GSE.GetCharacterName())
        end
        authoreditbox:SetCallback(
            "OnTextChanged",
            function(obj, event, key)
                variable.Author = key
            end
        )
        container:AddChild(keyEditBox)
        container:AddChild(authoreditbox)

        local commentsEditBox = AceGUI:Create("MultiLineEditBox")
        commentsEditBox:SetLabel(L["Help Information"])
        commentsEditBox:SetNumLines(7)
        commentsEditBox:SetFullWidth(true)
        commentsEditBox:DisableButton(true)
        commentsEditBox:SetText(variable.comments)
        commentsEditBox:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                variable.comments = text
            end
        )
        commentsEditBox:SetCallback(
            "OnEditFocusLost",
            function()
                variable.comments = commentsEditBox:GetText()
            end
        )

        container:AddChild(commentsEditBox)

        local valueEditBox = AceGUI:Create("MultiLineEditBox")
        valueEditBox:SetLabel(L["Variable"])
        valueEditBox:SetNumLines(15)
        valueEditBox:SetFullWidth(true)
        valueEditBox:DisableButton(true)
        valueEditBox:SetText(variable.funct)
        valueEditBox:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                variable.funct = IndentationLib.encode(text)
            end
        )
        valueEditBox:SetCallback(
            "OnEditFocusLost",
            function()
                local variabletext = IndentationLib.decode(valueEditBox:GetText())
                variable.funct = variabletext
            end
        )
        IndentationLib.enable(valueEditBox.editBox, Statics.IndentationColorTable, 4)

        container:AddChild(valueEditBox)

        implementation:SetLabel(L["Implementation Link"])
        implementation:DisableButton(true)
        local implementationText = [[=GSE.V.]] .. name .. [[()]]
        implementation:SetText(implementationText)
        implementation:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                implementation:SetText(implementationText)
            end
        )
        container:AddChild(implementation)

        local currentOutput = AceGUI:Create("EditBox")
        currentOutput:SetLabel(L["Current Value"])
        currentOutput:DisableButton(true)
        local outputText = L["Not Yet Active"]
        if GSE.V[name] and type(GSE.V[name]) == "function" then
            outputText = GSE.V[name]()
        end
        currentOutput:SetText(tostring(outputText))
        currentOutput:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                currentOutput:SetText(outputText)
            end
        )
        container:AddChild(currentOutput)

        local spacer2 = AceGUI:Create("Label")
        spacer2:SetWidth(10)
        container:AddChild(spacer2)

        local buttonRow = AceGUI:Create("SimpleGroup")
        buttonRow:SetLayout("Flow")
        buttonRow:SetWidth(400)

        local deleteRowButton = AceGUI:Create("Button")
        deleteRowButton:SetText(L["Delete Variable"])
        deleteRowButton:SetWidth(150)
        deleteRowButton:SetCallback(
            "OnClick",
            function()
                GSEVariables[keyEditBox:GetText()] = nil
                if editframe.loaded then
                    container:ReleaseChildren()
                    editframe.loaded = nil
                end
                editframe:ManageTree()
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
        buttonRow:AddChild(deleteRowButton)

        local spacer3 = AceGUI:Create("Label")
        spacer3:SetWidth(10)
        buttonRow:AddChild(spacer3)

        local lastSaved = AceGUI:Create("Label")
        if variable.LastUpdated then
            local updated = GSE.DecodeTimeStamp(variable.LastUpdated)
            lastSaved:SetText(
                L["Last Updated"] ..
                    " " ..
                        updated.month ..
                            "/" .. updated.day .. "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
            )
        end

        local savebutton = AceGUI:Create("Button")
        savebutton:SetText(L["Save"])
        savebutton:SetWidth(150)
        savebutton:SetCallback(
            "OnClick",
            function()
                local checkvariable, error = GSE.CheckVariable(valueEditBox:GetText())
                if checkvariable then
                    editframe:SetStatusText(L["Save pending for "] .. keyEditBox:GetText())
                    variable.LastUpdated = GSE.GetTimestamp()
                    local updated = GSE.DecodeTimeStamp(variable.LastUpdated)

                    local oocaction = {
                        ["action"] = "updatevariable",
                        ["variable"] = variable,
                        ["name"] = keyEditBox:GetText()
                    }
                    table.insert(GSE.OOCQueue, oocaction)
                    lastSaved:SetText(
                        L["Last Updated"] ..
                            " " ..
                                updated.month ..
                                    "/" ..
                                        updated.day ..
                                            "/" .. updated.year .. " " .. updated.hour .. ":" .. updated.minute
                    )
                else
                    GSE.Print(
                        L["There is an error in the sequence that needs to be corrected before it can be saved."],
                        Statics.DebugModules["Editor"]
                    )
                    GSE.Print(error, Statics.DebugModules["Editor"])
                end
            end
        )

        savebutton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Save"], L["Save the changes made to this variable."], editframe)
            end
        )
        savebutton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        buttonRow:AddChild(savebutton)
        container:AddChild(buttonRow)
        container:AddChild(lastSaved)
    end

    local function buildKeybindMenu()
        local tree = {
            {
                value = "AO",
                text = L["Actionbar Overrides"],
                icon = Statics.Icons.Button,
                children = {
                    {
                        value = "NAO",
                        text = L["New Actionbar Override"],
                        icon = Statics.ActionsIcons.Add
                    }
                }
            },
            {
                value = "KB",
                text = L["Keybindings"],
                icon = Statics.ActionsIcons.Key,
                children = {
                    {
                        value = "NKB",
                        text = L["New KeyBind"],
                        icon = Statics.ActionsIcons.Add
                    }
                }
            }
        }
        for k, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"]) do
            local currentspecid = tonumber(k)
            local node
            if GetSpecializationInfo then
                local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
                node = {
                    value = k,
                    text = speclabel,
                    icon = specIcon,
                    children = {}
                }
            else
                node = tree[1]
            end
            for i, j in GSE.pairsByKeys(v) do
                table.insert(
                    node["children"],
                    {
                        value = i .. "\001" .. j["Sequence"],
                        text = j["Bind"] ..
                            " " .. GSEOptions.KEYWORD .. "(" .. j["Sequence"] .. ")" .. Statics.StringReset
                    }
                )
            end

            if
                GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["LoadOuts"] and
                    GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]
             then
                for i, j in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][tostring(currentspecid)]) do
                    local success, result =
                        pcall(
                        function()
                            local loadout = C_Traits.GetConfigInfo(i)
                            local specnode = {
                                value = i,
                                text = "|cffffcc00" .. loadout.name .. Statics.StringReset,
                                children = {},
                                icon = Statics.Icons.Talents
                            }

                            for l, m in GSE.pairsByKeys(j) do
                                local nodelabel = l .. " " .. GSEOptions.KEYWORD .. "(" .. m.Sequence
                                if m and m.State then
                                    nodelabel = nodelabel .. " - " .. L["Button State"] .. ": " .. m.State
                                end
                                nodelabel = nodelabel .. "" .. ")" .. Statics.StringReset

                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "\001" .. m.Sequence,
                                        text = nodelabel
                                    }
                                )
                            end
                            table.insert(node["children"], specnode)
                        end
                    )
                    if not success then
                        GSE.PrintDebugMessage(result, "ACTIONBAR OVERRIDES MENU")
                    end
                end
            end
            if GetSpecializationInfo then
                table.insert(tree[1]["children"], node)
            end
        end
        for k, v in pairs(GSE_C["KeyBindings"]) do
            local currentspecid = tonumber(k)
            local node
            if GetSpecializationInfo then
                local _, speclabel, _, specIcon = GetSpecializationInfo(currentspecid)
                node = {
                    value = k,
                    text = speclabel,
                    icon = specIcon,
                    children = {}
                }
            else
                node = tree[2]
            end
            for i, j in GSE.pairsByKeys(v) do
                if i ~= "LoadOuts" then
                    table.insert(
                        node["children"],
                        {
                            value = i .. "\001" .. j,
                            text = i .. " " .. GSEOptions.KEYWORD .. "(" .. j .. ")" .. Statics.StringReset
                        }
                    )
                end
            end

            if
                GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(currentspecid)] and
                    GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"]
             then
                for i, j in pairs(GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"]) do
                    local success =
                        pcall(
                        function()
                            local loadout = C_Traits.GetConfigInfo(i)
                            local specnode = {
                                value = i,
                                text = "|cffffcc00" .. loadout.name .. Statics.StringReset,
                                children = {},
                                icon = Statics.Icons.Talents
                            }

                            for l, m in GSE.pairsByKeys(j) do
                                table.insert(
                                    specnode["children"],
                                    {
                                        value = l .. "\001" .. m,
                                        text = l .. " " .. GSEOptions.KEYWORD .. "(" .. m .. ")" .. Statics.StringReset
                                    }
                                )
                            end
                            table.insert(node["children"], specnode)
                        end
                    )
                    if not success then
                        GSE_C["KeyBindings"][tostring(currentspecid)]["LoadOuts"][i] = nil
                    end
                end
            end
            if GetSpecializationInfo then
                table.insert(tree[2]["children"], node)
            end
        end

        local returntree = {
            value = "KEYBINDINGS",
            text = L["Keybindings"],
            icon = Statics.Icons.Keybindings,
            children = tree
        }
        ---table.insert(returntree.children, tree)
        return returntree
    end

    local function buildVariablesMenu()
        local tree = {
            value = "VARIABLES",
            text = L["Variables"],
            icon = Statics.Icons.Variables,
            children = {
                {
                    value = "NEWVARIABLES",
                    text = L["New Variable"],
                    icon = Statics.ActionsIcons.Add
                }
            }
        }
        for k, _ in pairs(GSEVariables) do
            local node = {
                value = k,
                text = "|CFFFFFFFF" .. k .. Statics.StringReset
            }
            table.insert(tree.children, node)
        end

        return tree
    end

    local function showMacro(node, container)
        local char, realm = UnitFullName("player")

        local source = GSEMacros
        if node.value > MAX_ACCOUNT_MACROS then
            if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
                GSEMacros[char .. "-" .. realm] = {}
            end
            source = GSEMacros[char .. "-" .. realm]
        end

        local manageGSE = AceGUI:Create("CheckBox")
        manageGSE:SetType("radio")
        manageGSE:SetLabel(L["Manage Macro with GSE"])
        manageGSE:SetTriState(false)

        if GSE.isEmpty(source[node.name]) then
            source[node.name] = node
            manageGSE:SetValue(false)
        else
            if GSE.isEmpty(source[node.name].Managed) then
                manageGSE:SetValue(false)
            else
                manageGSE:SetValue(source[node.name].Managed)
            end
        end
        local managed = false
        if source[node.name] and source[node.name].Managed then
            managed = source[node.name].Managed
        end

        local headerGroup = AceGUI:Create("SimpleGroup")
        headerGroup:SetFullWidth(true)
        headerGroup:SetLayout("Flow")

        local nameeditbox = AceGUI:Create("EditBox")
        nameeditbox:SetLabel(L["Macro Name"])
        nameeditbox:SetWidth(250)
        nameeditbox:SetCallback(
            "OnEnterPressed",
            function(self, _, text)
                local slot = GetMacroIndexByName(node.name)
                -- TODO Need to queue this
                if slot then
                    EditMacro(slot, text)
                    node.name = text
                end
            end
        )

        nameeditbox:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Macro Name"],
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

        nameeditbox:DisableButton(false)
        nameeditbox:SetText(node.name)

        local spacerlabel = AceGUI:Create("Label")
        spacerlabel:SetWidth(10)

        local iconpicker = AceGUI:Create("Icon")
        iconpicker:SetImageSize(40, 40)
        iconpicker:SetLabel(L["Macro Icon"])
        iconpicker.frame:RegisterForDrag("LeftButton")
        iconpicker.frame:SetScript(
            "OnDragStart",
            function()
                local sequencename = nameeditbox:GetText()
                if not GSE.isEmpty(sequencename) then
                    local macroIndex = GetMacroIndexByName(sequencename)
                    if macroIndex and macroIndex ~= 0 then
                        PickupMacro(sequencename)
                    end
                end
            end
        )
        iconpicker:SetImage(node.icon)
        iconpicker:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Macro Icon"],
                    L[
                        "Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."
                    ],
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

        container:AddChild(headerGroup)

        container:AddChild(manageGSE)

        local font = CreateFont("seqPanelFont")
        font:SetFontObject(GameFontNormal)
        local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
        local origjustificationH = font:GetJustifyH()
        local origjustificationV = font:GetJustifyV()
        font:SetJustifyH("CENTER")
        font:SetJustifyV("MIDDLE")

        if managed then
            local authoreditbox = AceGUI:Create("EditBox")
            authoreditbox:SetLabel(L["Author"])
            authoreditbox:SetWidth(250)
            authoreditbox:DisableButton(true)
            authoreditbox:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Author"], L["The author of this Macro."], editframe)
                end
            )
            authoreditbox:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )
            if not GSE.isEmpty(node.Author) then
                authoreditbox:SetText(node.Author)
            else
                authoreditbox:SetText(GSE.GetCharacterName())
            end
            authoreditbox:SetCallback(
                "OnTextChanged",
                function(obj, event, key)
                    node.Author = key
                    source[node.name].Author = key
                end
            )
            container:AddChild(authoreditbox)
            local commentsEditBox = AceGUI:Create("MultiLineEditBox")
            commentsEditBox:SetLabel(L["Help Information"])
            commentsEditBox:SetNumLines(3)
            commentsEditBox:SetFullWidth(true)
            commentsEditBox:DisableButton(true)
            if source[node.name].comments then
                commentsEditBox:SetText(source[node.name].comments)
            end
            commentsEditBox:SetCallback(
                "OnTextChanged",
                function(self, event, text)
                    source[node.name].comments = text
                end
            )
            commentsEditBox:SetCallback(
                "OnEditFocusLost",
                function()
                    source[node.name].comments = commentsEditBox:GetText()
                end
            )

            container:AddChild(commentsEditBox)

            local managedMacro = AceGUI:Create("MultiLineEditBox")
            managedMacro:SetLabel(L["Macro Template"])
            local managedtext =
                (source[node.name].managedMacro and
                GSE.CompileMacroText(
                    (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                    Statics.TranslatorMode.Current
                ) or
                node.text)
            managedMacro:SetText(managedtext)
            managedMacro:SetNumLines(8)
            -- managedMacro:SetWidth(macroframe.Width - 200)
            managedMacro:SetFullWidth(true)

            local compileButton = AceGUI:Create("Button")
            compileButton:SetText(L["Compile"])

            local compiledMacro = AceGUI:Create("Label")
            compiledMacro:SetWidth(editframe.Width - 200)

            local heading2 = AceGUI:Create("Heading")
            heading2:SetText(L["Compiled Macro"])
            heading2:SetFullWidth(true)

            local compiledtext =
                (source[node.name].managedMacro and
                GSE.CompileMacroText(
                    (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                    Statics.TranslatorMode.String
                ) or
                node.text)

            compiledMacro:SetText(compiledtext)

            local compiledlinecount = AceGUI:Create("Label")
            compiledlinecount:SetWidth(editframe.Width - 200)
            compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(compiledtext)))
            compiledlinecount:ClearAllPoints()
            compiledlinecount:SetPoint("CENTER")
            compiledlinecount:SetFontObject(font)
            compiledlinecount:SetFont(fontName, fontHeight, fontFlags)

            managedMacro:SetCallback(
                "OnTextChanged",
                function(self, _, text)
                    editframe:SetStatusText(L["Save pending for "] .. node.name)
                    source[node.name].managedMacro = GSE.CompileMacroText(text, Statics.TranslatorMode.ID)
                    local compiled = GSE.CompileMacroText(text, Statics.TranslatorMode.String)
                    compiledMacro:SetText(compiled)
                    compiledlinecount:SetText(string.format(L["%s/255 Characters Used"], string.len(compiled)))
                    local oocaction = {
                        ["action"] = "updatemacro",
                        ["node"] = source[node.name],
                        ["status"] = editframe:SetStatusText()
                    }
                    table.insert(GSE.OOCQueue, oocaction)
                end
            )
            if GSE.Patron then
                managedMacro.editBox:SetScript(
                    "OnTabPressed",
                    function(widget, button, down)
                        -- if button == "RightButton" then
                        MenuUtil.CreateContextMenu(
                            editframe.frame,
                            function(ownerRegion, rootDescription)
                                rootDescription:CreateTitle(L["Insert GSE Variable"])
                                for k, _ in pairs(GSEVariables) do
                                    rootDescription:CreateButton(
                                        k,
                                        function()
                                            managedMacro.editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        end
                                    )
                                end
                                rootDescription:CreateTitle(L["Insert GSE Sequence"])
                                for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
                                    rootDescription:CreateButton(
                                        k,
                                        function()
                                            if GSE.GetMacroStringFormat() == "DOWN" then
                                                managedMacro.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                                            else
                                                managedMacro.editBox:Insert("\n/click " .. k)
                                            end
                                        end
                                    )
                                end
                                for k, _ in pairs(GSESequences[0]) do
                                    rootDescription:CreateButton(
                                        k,
                                        function()
                                            if GSE.GetMacroStringFormat() == "DOWN" then
                                                managedMacro.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                                            else
                                                managedMacro.editBox:Insert("\n/click " .. k)
                                            end
                                        end
                                    )
                                end
                            end
                        )
                        -- end
                    end
                )
            end

            managedMacro:DisableButton(true)

            container:AddChild(managedMacro)
            container:AddChild(heading2)
            local inlinecompiled = AceGUI:Create("InlineGroup")
            inlinecompiled:SetFullWidth(true)
            inlinecompiled:AddChild(compiledMacro)
            container:AddChild(inlinecompiled)
            container:AddChild(AceGUI:Create("Spacer"))
            container:AddChild(compiledlinecount)
        else
            local linecount = AceGUI:Create("Label")
            linecount:SetWidth(editframe.Width - 200)
            linecount:SetText(string.format(L["%s/255 Characters Used"], string.len(node.text)))
            linecount:ClearAllPoints()
            linecount:SetPoint("CENTER")
            linecount:SetFontObject(font)
            linecount:SetFont(fontName, fontHeight, fontFlags)

            font:SetJustifyH(origjustificationH)
            font:SetJustifyV(origjustificationV)

            local macro = AceGUI:Create("MultiLineEditBox")
            macro:SetLabel(L["Macro"])
            macro:SetText(node.text)
            macro:SetNumLines(8)
            macro:SetFullWidth(true)
            macro:SetCallback(
                "OnEnterPressed",
                function(self, _, text)
                    editframe:SetStatusText(L["Save pending for "] .. node.name)
                    node.text = GSE.CompileMacroText(text, Statics.TranslatorMode.String)
                    local oocaction = {
                        ["action"] = "updatemacro",
                        ["node"] = node,
                        ["status"] = editframe:SetStatusText()
                    }
                    table.insert(GSE.OOCQueue, oocaction)
                end
            )
            macro:SetCallback(
                "OnTextChanged",
                function(self, _, text)
                    local length = string.len(text)
                    local line = string.format(L["%s/255 Characters Used"], length)
                    if length > 255 then
                        line = GSEOptions.UNKNOWN .. line .. Statics.StringReset
                    end
                    linecount:SetText(line)
                end
            )

            macro:DisableButton(false)
            container:AddChild(macro)
            container:AddChild(linecount)
        end
        manageGSE:SetCallback(
            "OnValueChanged",
            function(self, _, value)
                if GSE.isEmpty(source[node.name]) then
                    source[node.name] = {}
                end

                source[node.name].Managed = value
                for k, v in pairs(node) do
                    source[node.name][k] = v
                end
                source[node.name].managedMacro =
                    GSE.TranslateString(
                    (source[node.name].managedMacro and source[node.name].managedMacro or node.text),
                    Statics.TranslatorMode.ID
                )
                source[node.name].text =
                    GSE.UnEscapeString(
                    GSE.TranslateString(source[node.name].managedMacro, Statics.TranslatorMode.Current)
                )
                showMacro(node, container)
            end
        )
    end

    local function buildMacroMenu()
        local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
        local tree = {
            value = "Macro",
            text = L["Macros"],
            icon = Statics.Icons.Macros,
            children = {
                {
                    value = "A",
                    text = L["Account Macros"],
                    icon = Statics.Icons.Account,
                    children = {}
                },
                {
                    value = "P",
                    text = L["Character Macros"],
                    icon = Statics.Icons.Personal,
                    children = {}
                }
            }
        }

        for macid = 1, maxmacros do
            local mname, micon = GetMacroInfo(macid)
            local node
            if mname then
                node = {
                    text = mname,
                    value = macid,
                    icon = micon
                }
                if macid <= MAX_ACCOUNT_MACROS then
                    table.insert(tree.children[1].children, node)
                else
                    table.insert(tree.children[2].children, node)
                end
            end
        end
        return tree
    end
    function editframe.ManageTree()
        local tree = {
            {
                value = "NewSequence",
                text = L["New Sequence"],
                icon = Statics.ActionsIcons.Add
            },
            {
                value = "Import",
                text = L["Import"],
                icon = Statics.Icons.Import
            }
        }

        local classtree = {}

        local names = GSE.GetSequenceNames()

        for k, _ in GSE.pairsByKeys(names, GSE.AlphabeticalTableSortAlgorithm) do
            local elements = GSE.split(k, ",")
            local tclassid = tonumber(elements[1])
            local specid = tonumber(elements[2])
            if tclassid and GSE.isEmpty(classtree[tclassid]) then
                classtree[tclassid] = {}
            end
            if specid and GSE.isEmpty(classtree[tclassid][specid]) then
                classtree[tclassid][specid] = {}
            end
            local node = {
                value = k,
                text = elements[3],
                children = {
                    {
                        text = L["Configuration"],
                        value = "config",
                        icon = Statics.ActionsIcons.Settings
                    }
                }
            }

            local id, _, _, sicon = GetSpecializationInfoForSpecID(specid)
            if id then
                node.icon = sicon
            else
                node.icon = GSE.GetClassIcon(tclassid)
            end

            for i, j in ipairs(GSE.Library[tclassid][elements[3]]["Macros"]) do
                table.insert(
                    node.children,
                    {
                        value = i,
                        text = BuildVersionLabel(tostring(i), j.Label)
                    }
                )
            end
            table.insert(
                node.children,
                {
                    text = L["New"] .. " " .. L["Version"],
                    value = "newversion",
                    icon = Statics.ActionsIcons.Add
                }
            )
            table.insert(classtree[tclassid][specid], node)
        end
        local subtree = {
            value = "Sequences",
            text = L["Sequences"],
            icon = Statics.Icons.Sequences,
            children = {}
        }
        for k, v in pairs(classtree) do
            local tnode = {}
            if k > 0 then
                local classinfo, classfile = GetClassInfo(k)
                local text =
                    C_ClassColor and
                    WrapTextInColorCode(classinfo, C_ClassColor.GetClassColor(classfile):GenerateHexColor()) or
                    classinfo
                tnode = {
                    value = k,
                    text = text,
                    icon = GSE.GetClassIcon(k),
                    children = {}
                }
            elseif k == 0 then
                tnode = {
                    value = "GLOBAL",
                    text = L["Global"],
                    children = {}
                }
            end
            for i, j in pairs(v) do
                local id, sname, _, sicon = GetSpecializationInfoForSpecID(i)

                for _, h in ipairs(j) do
                    table.insert(tnode.children, h)
                end
            end

            table.insert(subtree.children, tnode)
        end
        table.insert(tree, subtree)
        table.insert(tree, buildKeybindMenu())
        local vtree = buildVariablesMenu()
        table.insert(tree, vtree)
        local mtree = buildMacroMenu()
        table.insert(tree, mtree)
        treeContainer:SetTree(tree)
        treeContainer:SetCallback(
            "OnGroupSelected",
            function(container, event, group, ...)
                local unique = {("\001"):split(group)}
                local key = unique[#unique]
                local elements, classid, sequencename
                local area = unique[1]

                if area == "Sequences" then
                    if unique[3] then
                        elements = GSE.split(unique[3], ",")
                        if #elements >= 3 then
                            classid = elements[1]
                            sequencename = elements[3]
                        end
                    end
                end

                local mbutton = GetMouseButtonClicked()
                if mbutton == "RightButton" then
                    if area == "KEYBINDINGS" and #unique > 3 then
                        MenuUtil.CreateContextMenu(
                            editframe.frame,
                            function(ownerRegion, rootDescription)
                                rootDescription:CreateButton(
                                    L["New KeyBind"],
                                    function()
                                        local rightContainer = AceGUI:Create("SimpleGroup")
                                        rightContainer:SetFullWidth(true)
                                        rightContainer:SetLayout("List")
                                        showKeybind(nil, nil, nil, nil, "KB", rightContainer)
                                    end
                                )
                                rootDescription:CreateButton(
                                    L["New Actionbar Override"],
                                    function()
                                        local rightContainer = AceGUI:Create("SimpleGroup")
                                        rightContainer:SetFullWidth(true)
                                        rightContainer:SetLayout("List")
                                        showKeybind(nil, nil, nil, nil, "AO", rightContainer)
                                    end
                                )
                                rootDescription:CreateButton(
                                    L["Delete"],
                                    function()
                                        local bind, specialization, loadout, type
                                        type = unique[2]
                                        specialization = unique[3]
                                        if GetSpecialization then
                                            bind = unique[4]

                                            if unique[6] then
                                                loadout = unique[6]
                                            end
                                        else
                                            specialization = "1"
                                            if unique[5] then
                                                loadout = unique[5]
                                                bind = unique[4]
                                            else
                                                loadout = unique[4]
                                                bind = unique[3]
                                            end
                                        end
                                        if type == "KB" then
                                            SetBinding(bind)
                                            if loadout then
                                                GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] =
                                                    nil
                                                local empty = true
                                                for _, _ in pairs(
                                                    GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                                                ) do
                                                    empty = false
                                                end
                                                if empty then
                                                    GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] =
                                                        nil
                                                end
                                            else
                                                if
                                                    GSE_C["KeyBindings"] and
                                                        GSE_C["KeyBindings"][tostring(specialization)] and
                                                        GSE_C["KeyBindings"][tostring(specialization)][bind]
                                                 then
                                                    GSE_C["KeyBindings"][tostring(specialization)][bind] = nil
                                                end
                                            end
                                        elseif type == "AO" then
                                            if loadout then
                                                GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][loadout][
                                                        bind
                                                    ] = nil
                                                local empty = true
                                                for _, _ in pairs(
                                                    GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][
                                                        loadout
                                                    ]
                                                ) do
                                                    empty = false
                                                end
                                                if empty then
                                                    GSE_C["ActionBarBinds"]["LoadOuts"][tostring(specialization)][
                                                            loadout
                                                        ] = nil
                                                end
                                            else
                                                GSE_C["ActionBarBinds"]["Specialisations"][tostring(specialization)][
                                                        bind
                                                    ] = nil
                                            end
                                            GSE.ButtonOverrides[bind] = nil
                                        end
                                        editframe.ManageTree()
                                        GSE:SendMessage(Statics.VARIABLE_UPDATED, bind)
                                    end
                                )
                            end
                        )
                    elseif area == "Sequences" then
                        MenuUtil.CreateContextMenu(
                            editframe.frame,
                            function(ownerRegion, rootDescription)
                                rootDescription:CreateTitle(L["Sequence Editor"])
                                rootDescription:CreateButton(
                                    L["New"],
                                    function()
                                        if editframe.loaded then
                                            container:ReleaseChildren()
                                            editframe.loaded = nil
                                        end
                                        local rightContainer = AceGUI:Create("SimpleGroup")
                                        rightContainer:SetFullWidth(true)
                                        rightContainer:SetLayout("List")
                                        GSE.GUILoadEditor(editframe)
                                        container:AddChild(rightContainer)
                                    end
                                )
                                if not GSE.isEmpty(sequencename) then
                                    rootDescription:CreateButton(
                                        L["Export"],
                                        function()
                                            GSE.GUIExport(classid, sequencename, "SEQUENCE")
                                        end
                                    )
                                    rootDescription:CreateButton(
                                        L["Send"],
                                        function()
                                            GSE.GUIShowTransmissionGui(sequencename, editframe)
                                        end
                                    )
                                    if GSE.Patron then
                                        rootDescription:CreateButton(
                                            string.format(L["Open %s in New Window"], sequencename),
                                            function()
                                                local editor = GSE.CreateEditor()
                                                editor.ManageTree()
                                                editor.treeContainer:SelectByValue(group)
                                            end
                                        )
                                    end
                                    rootDescription:CreateButton(
                                        L["Chat Link"],
                                        function()
                                            StaticPopupDialogs["GSE_ChatLink"].link =
                                                GSE.SequenceChatPattern(sequencename, classid)
                                            StaticPopup_Show("GSE_ChatLink")
                                        end
                                    )
                                end
                                rootDescription:CreateButton(
                                    L["Keybindings"],
                                    function()
                                        GSE.ShowKeyBindings()
                                    end
                                )
                                if not GSE.isEmpty(sequencename) then
                                    rootDescription:CreateButton(
                                        L["Delete"],
                                        function()
                                            GUIDeleteSequence(classid, sequencename)
                                        end
                                    )
                                end
                            end
                        )
                    elseif area == "VARIABLES" then
                        MenuUtil.CreateContextMenu(
                            editframe.frame,
                            function(ownerRegion, rootDescription)
                                rootDescription:CreateTitle(L["Manage Variables"])
                                rootDescription:CreateButton(
                                    L["Export Variable"],
                                    function()
                                        GSE.GUIExport(nil, key, "VARIABLE")
                                    end
                                )
                                rootDescription:CreateButton(
                                    L["Delete"],
                                    function()
                                        GSE.V[key] = nil
                                        GSEVariables[key] = nil
                                        editframe.ManageTree()
                                    end
                                )
                            end
                        )
                    elseif area == "Macro" then
                    end
                elseif mbutton == "LeftButton" and IsShiftKeyDown() then
                    StaticPopupDialogs["GSE_ChatLink"].link = GSE.SequenceChatPattern(sequencename, classid)
                    StaticPopup_Show("GSE_ChatLink")
                else
                    if area == "NewSequence" then
                        GSE.GUILoadEditor(editframe)
                    elseif area == "Import" then
                        GSE.ShowImport()
                    elseif area == "KEYBINDINGS" and #unique >= 2 then
                        local bind, loadout, type, button
                        type = unique[2]
                        local specialization = unique[3]
                        if GetSpecialization then
                            bind = unique[4]
                            if #unique == 6 then
                                loadout = unique[4]
                                bind = unique[5]
                                if unique[2] == "AO" and bind then
                                    button = GSE_C["ActionBarBinds"]["LoadOuts"][specialization][loadout][bind]
                                else
                                    button = unique[6]
                                end
                            else
                                if unique[2] == "AO" and bind then
                                    button = GSE_C["ActionBarBinds"]["Specialisations"][specialization][bind]
                                else
                                    button = unique[5]
                                end
                            end
                        else
                            specialization = "1"
                            bind = unique[3]
                            button = unique[4]

                            if type == "AO" and bind then
                                button = GSE_C["ActionBarBinds"]["Specialisations"][specialization][bind]
                            end
                        end
                        if unique[#unique] == "NKB" then
                            if editframe.loaded then
                                container:ReleaseChildren()
                                editframe.loaded = nil
                            end
                            local rightContainer = AceGUI:Create("SimpleGroup")
                            rightContainer:SetFullWidth(true)
                            rightContainer:SetLayout("List")
                            showKeybind(nil, nil, nil, nil, "KB", rightContainer)
                            container:AddChild(rightContainer)
                            editframe.loaded = true
                            editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["New KeyBind"])
                        elseif unique[#unique] == "NAO" then
                            if editframe.loaded then
                                container:ReleaseChildren()
                                editframe.loaded = nil
                            end
                            local rightContainer = AceGUI:Create("SimpleGroup")
                            rightContainer:SetFullWidth(true)
                            rightContainer:SetLayout("List")
                            showKeybind(nil, nil, nil, nil, "AO", rightContainer)
                            container:AddChild(rightContainer)
                            editframe.loaded = true
                            editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["New Actionbar Override"])
                        else
                            if bind and button and type then
                                if editframe.loaded then
                                    container:ReleaseChildren()
                                    editframe.loaded = nil
                                end
                                local rightContainer = AceGUI:Create("SimpleGroup")
                                rightContainer:SetFullWidth(true)
                                rightContainer:SetLayout("List")

                                showKeybind(bind, button, specialization, loadout, type, rightContainer)
                                container:AddChild(rightContainer)
                                editframe.loaded = true
                                editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["Keybind"])
                            end
                        end
                    elseif area == "Sequences" and #unique >= 3 then
                        local path = GSE.CloneSequence(unique)
                        table.remove(path, #path)
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
                                GSE.GUIShowTransmissionGui(
                                    editframe.ClassID .. "," .. editframe.SequenceName,
                                    editframe
                                )
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

                        local editButtonGroup = AceGUI:Create("SimpleGroup")

                        -- editButtonGroup:SetWidth(602)
                        editButtonGroup:SetFullWidth(true)
                        editButtonGroup:SetLayout("Flow")
                        editButtonGroup:SetHeight(15)

                        local savebutton = AceGUI:Create("Button")
                        savebutton:SetText(L["Save"])
                        savebutton:SetWidth(100)
                        savebutton:SetCallback(
                            "OnClick",
                            function()
                                if GSE.isEmpty(editframe.invalidPause) then
                                    editframe:SetStatusText(L["Save pending for "] .. editframe.SequenceName)
                                    local _, _, _, tocversion = GetBuildInfo()
                                    editframe.Sequence.MetaData.ManualIntervention = true
                                    editframe.Sequence.MetaData.GSEVersion = GSE.VersionNumber
                                    editframe.Sequence.MetaData.EnforceCompatability = true
                                    editframe.Sequence.MetaData.TOC = tocversion
                                    editframe.SequenceName = GSE.UnEscapeString(editframe.SequenceName)
                                    GUIUpdateSequenceDefinition(
                                        editframe.ClassID,
                                        editframe.SequenceName,
                                        editframe.Sequence
                                    )
                                    editframe.save = true
                                    if editframe.newname then
                                        editframe.newname = nil
                                    -- treeContainer:SelectByValue(
                                    --     table.concat(path, "\001") .. "\001" .. sequencename
                                    -- )
                                    end
                                else
                                    GSE.Print(
                                        L["Error processing Custom Pause Value.  You will need to recheck your macros."],
                                        "ERROR"
                                    )
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
                                local seqname = editframe.SequenceName
                                local classid = editframe.ClassID
                                GUIDeleteSequence(classid, seqname)
                                editframe.ManageTree()
                            end
                        )
                        delbutton:SetCallback(
                            "OnEnter",
                            function()
                                GSE.CreateToolTip(
                                    L["Delete"],
                                    L["Delete this macro.  This is not able to be undone."],
                                    editframe
                                )
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
                        if editframe.loaded then
                            container:ReleaseChildren()
                            editframe.loaded = nil
                        end
                        local basecontainer = AceGUI:Create("SimpleGroup")
                        basecontainer:SetLayout("List")
                        basecontainer:SetFullWidth(true)
                        basecontainer:SetHeight(editframe.Height - 100)
                        local scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
                        scrollcontainer:SetFullWidth(true)
                        scrollcontainer:SetHeight(editframe.Height - 120)
                        scrollcontainer:SetLayout("Fill") -- Important!
                        editframe.scrollStatus = {}
                        local contentcontainer = AceGUI:Create("ScrollFrame")
                        scrollcontainer:AddChild(contentcontainer)
                        contentcontainer:SetFullWidth(true)
                        contentcontainer:SetFullHeight(true)
                        contentcontainer:SetStatusTable(editframe.scrollStatus)
                        editframe.scroller = scrollcontainer
                        editframe.scrollContainer = contentcontainer
                        container:AddChild(basecontainer)
                        basecontainer:AddChild(scrollcontainer)
                        editframe.SequenceName = sequencename

                        if unique[1] == "Sequences" and #unique == 3 then
                            container:ReleaseChildren()
                            treeContainer:SelectByValue(group .. "\001config")
                            return
                        elseif key == "config" then
                            if editframe.OrigSequenceName ~= sequencename then
                                GSE.GUILoadEditor(editframe, path[#path])
                            end
                            local nameeditbox = AceGUI:Create("EditBox")
                            nameeditbox:SetLabel(L["Sequence Name"])
                            nameeditbox:SetWidth(250)
                            nameeditbox:DisableButton(true)
                            nameeditbox:SetText(sequencename)

                            nameeditbox:SetCallback(
                                "OnTextChanged",
                                function()
                                    editframe.SequenceName = nameeditbox:GetText()
                                    editframe.newname = true
                                end
                            )

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
                            editframe.nameeditbox = nameeditbox
                            local headerGroup = AceGUI:Create("SimpleGroup")
                            headerGroup:SetFullWidth(true)
                            headerGroup:SetLayout("Flow")
                            contentcontainer:AddChild(headerGroup)
                            --GSE.GUILoadEditor(editframe, path[#path])

                            headerGroup:AddChild(nameeditbox)
                            GUIDrawMetadataEditor(contentcontainer)
                            editframe:SetTitle(
                                L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["Configuration"] .. ")"
                            )
                        elseif key == "newversion" then
                            if editframe.OrigSequenceName ~= sequencename then
                                GSE.GUILoadEditor(editframe, path[#path])
                            end
                            table.insert(
                                editframe.Sequence.Macros,
                                GSE.CloneSequence(editframe.Sequence.Macros[editframe.Sequence.MetaData.Default])
                            )
                            GUIDrawMacroEditor(contentcontainer, #editframe.Sequence.Macros, table.concat(path, "\001"))
                            editframe:SetTitle(
                                L["Sequence Editor"] ..
                                    ": " .. sequencename .. " (" .. L["New"] .. " " .. L["Version"] .. ")"
                            )
                        else
                            if editframe.OrigSequenceName ~= sequencename then
                                GSE.GUILoadEditor(editframe, path[#path])
                            end
                            GUIDrawMacroEditor(contentcontainer, key, table.concat(path, "\001"))
                            editframe:SetTitle(
                                L["Sequence Editor"] ..
                                    ": " .. sequencename .. " (" .. L["Version"] .. ":" .. key .. ")"
                            )
                        end
                        basecontainer:AddChild(editButtonGroup)

                        editframe.loaded = true
                    elseif area == "VARIABLES" then
                        if #unique > 1 then
                            if editframe.loaded then
                                container:ReleaseChildren()
                                editframe.loaded = nil
                            end
                            showVariable(key, container)
                            editframe.loaded = true
                        end
                    elseif area == "Macro" then
                        if #unique == 3 then
                            local mtext
                            local mname, micon, matext = GetMacroInfo(key)
                            if unique[2] == "A" then
                                if GSEMacros[mname] and GSEMacros[mname].text then
                                    mtext = GSEMacros[mname].text
                                else
                                    mtext = matext
                                end
                            else
                                local char, realm = UnitFullName("player")
                                if
                                    GSEMacros[char .. "-" .. realm] and GSEMacros[char .. "-" .. realm][mname] and
                                        GSEMacros[char .. "-" .. realm][mname].text
                                 then
                                    mtext = GSEMacros[char .. "-" .. realm][mname].text
                                else
                                    mtext = matext
                                end
                            end

                            local node = {
                                value = tonumber(unique[3]),
                                name = mname,
                                icon = micon,
                                text = mtext
                            }
                            if editframe.loaded then
                                container:ReleaseChildren()
                                editframe.loaded = nil
                            end
                            showMacro(node, container)
                            editframe.loaded = true
                        end
                    else
                        editframe:SetTitle(L["Sequence Editor"])
                    end
                end
            end
        )
    end

    function editframe.GetVersionList()
        local tabl = {}
        for k, v in ipairs(editframe.Sequence.Macros) do
            tabl[tostring(k)] = v.Label and tostring(k) .. " - " .. v.Label or tostring(k)
        end
        return tabl
    end

    if GSE.isEmpty(GSE.CreateSpellEditBox) then
        GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro, frame)
            local spellEditBox = AceGUI:Create("EditBox")

            spellEditBox:SetWidth(250)
            spellEditBox:DisableButton(true)

            if GSE.isEmpty(sequence.Macros[version].Actions[keyPath].type) then
                sequence.Macros[version].Actions[keyPath].type = "spell"
            end
            if GSE.isEmpty(action.type) then
                action.type = "spell"
            end

            local spelltext

            if action.toy then
                spelltext = action.toy
                spellEditBox:SetLabel(L["Toy"])
            elseif action.item then
                spelltext = action.item
                spellEditBox:SetLabel(L["Item"])
            elseif action.macro then
                if string.sub(GSE.UnEscapeString(action.macro), 1, 1) == "/" then
                    spelltext = GSE.CompileMacroText(action.macro, Statics.TranslatorMode.Current)
                else
                    spelltext = action.macro
                end
            elseif action.action then
                spellEditBox:SetLabel(L["Pet Ability"])
                spelltext = action.action
            else
                spellEditBox:SetLabel(L["Spell"])
                local translatedSpell = GSE.GetSpellId(action.spell, Statics.TranslatorMode.Current)
                if translatedSpell then
                    spelltext = translatedSpell
                else
                    spelltext = action.spell
                end
            end

            spellEditBox:SetText(spelltext)

            --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Macros[version])
            spellEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    if sequence.Macros[version].Actions[keyPath].type == "pet" then
                        sequence.Macros[version].Actions[keyPath].action = value
                        sequence.Macros[version].Actions[keyPath].spell = nil
                        sequence.Macros[version].Actions[keyPath].macro = nil
                        sequence.Macros[version].Actions[keyPath].item = nil
                        sequence.Macros[version].Actions[keyPath].toy = nil
                    elseif sequence.Macros[version].Actions[keyPath].type == "macro" then
                        if string.sub(value, 1, 1) == "/" then
                            sequence.Macros[version].Actions[keyPath].macro =
                                GSE.TranslateString(value, Statics.TranslatorMode.Current)
                        else
                            sequence.Macros[version].Actions[keyPath].macro = value
                        end
                        sequence.Macros[version].Actions[keyPath].spell = nil
                        sequence.Macros[version].Actions[keyPath].action = nil
                        sequence.Macros[version].Actions[keyPath].item = nil
                        sequence.Macros[version].Actions[keyPath].toy = nil
                        sequence.Macros[version].Actions[keyPath].unit = nil
                    elseif sequence.Macros[version].Actions[keyPath].type == "item" then
                        sequence.Macros[version].Actions[keyPath].item = value
                        sequence.Macros[version].Actions[keyPath].spell = nil
                        sequence.Macros[version].Actions[keyPath].action = nil
                        sequence.Macros[version].Actions[keyPath].macro = nil
                        sequence.Macros[version].Actions[keyPath].toy = nil
                    elseif sequence.Macros[version].Actions[keyPath].type == "toy" then
                        sequence.Macros[version].Actions[keyPath].toy = value
                        sequence.Macros[version].Actions[keyPath].spell = nil
                        sequence.Macros[version].Actions[keyPath].action = nil
                        sequence.Macros[version].Actions[keyPath].macro = nil
                        sequence.Macros[version].Actions[keyPath].item = nil
                    else
                        local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                        if storedValue then
                            sequence.Macros[version].Actions[keyPath].spell = storedValue
                        else
                            sequence.Macros[version].Actions[keyPath].spell = value
                        end
                        sequence.Macros[version].Actions[keyPath].action = nil
                        sequence.Macros[version].Actions[keyPath].macro = nil
                        sequence.Macros[version].Actions[keyPath].item = nil
                        sequence.Macros[version].Actions[keyPath].toy = nil
                    end

                    --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Macros[version])
                end
            )
            spellEditBox:SetCallback(
                "OnEditFocusLost",
                function()
                end
            )
            local macroEditBox = AceGUI:Create("MultiLineEditBox")
            macroEditBox:SetLabel(L["Macro Name or Macro Commands"])
            macroEditBox:DisableButton(true)
            macroEditBox:SetNumLines(5)
            macroEditBox:SetRelativeWidth(0.5)
            macroEditBox:SetText(spelltext)
            macroEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    if string.sub(value, 1, 1) == "/" then
                        sequence.Macros[version].Actions[keyPath].macro =
                            GSE.CompileMacroText(value, Statics.TranslatorMode.ID)
                    else
                        sequence.Macros[version].Actions[keyPath].macro = value
                    end
                    sequence.Macros[version].Actions[keyPath].spell = nil
                    sequence.Macros[version].Actions[keyPath].action = nil
                    sequence.Macros[version].Actions[keyPath].item = nil
                    sequence.Macros[version].Actions[keyPath].toy = nil
                    local compiledmacrotext =
                        GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                    local lenMacro = string.len(compiledmacrotext)
                    local charcount
                    if lenMacro > 255 then
                        charcount =
                            string.format(
                            GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                            lenMacro
                        )
                    else
                        charcount = string.format(L["%s/255 Characters Used"], lenMacro)
                    end
                    compiledmacrotext = compiledmacrotext .. "\n\n" .. charcount
                    compiledMacro:SetText(compiledmacrotext)
                end
            )
            return spellEditBox, macroEditBox
        end
    end

    function editframe:remoteSequenceUpdated(seqName)
        if seqName == editframe.SequenceName then
            if editframe.save then
                editframe:SetStatusText(seqName .. " " .. L["Saved"])
                editframe.save = nil
                C_Timer.After(
                    5,
                    function()
                        editframe:SetStatusText("")
                    end
                )
            else
                editframe:SetStatusText(
                    seqName .. " " .. L["modified in other window.  This view is now behind the current sequence."]
                )
            end
        end
        editframe.ManageTree()
    end

    return editframe
end

function GSE.ShowSequences()
    if not InCombatLockdown() or (GSE.PlayerSpellsLoaded and GSE.PlayerSpellsLoaded()) then
        local editframe = GSE.CreateEditor()
        editframe.ManageTree()
        editframe.treeContainer:SelectByValue("Sequences\001" .. GSE.GetCurrentClassID())
        editframe:Show()
    else
        GSE.Print(
            L[
                "You cannot open a new Sequence Editor window while you are in combat.  Please exit combat and then try again."
            ],
            Statics.DebugModules["Editor"]
        )
    end
end

local function remoteSeqences(message, seqName)
    if message == Statics.SEQUENCE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function remoteVariables(message, seqName)
    if message == Statics.SEQUENCE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function collectionImported(message)
    if message == Statics.COLLECTION_IMPORTED then
        if GSE.GUI.editors and #GSE.GUI.editors then
            for _, v in ipairs(GSE.GUI.editors) do
                v.ManageTree()
            end
        end
    end
end

GSE:RegisterMessage(Statics.SEQUENCE_UPDATED, remoteSeqences)
GSE:RegisterMessage(Statics.VARIABLE_UPDATED, remoteVariables)
GSE:RegisterMessage(Statics.COLLECTION_IMPORTED, collectionImported)

function GSE.GUILoadEditor(editor, key, recordedstring)
    local classid
    local sequenceName
    local sequence
    local newsequence = false
    if GSE.isEmpty(key) then
        classid = GSE.GetCurrentClassID()
        sequenceName = "NEW_SEQUENCE" .. tostring(math.random(20))
        sequence = {
            ["MetaData"] = {
                ["Author"] = GSE.GetCharacterName(),
                ["Talents"] = GSE.GetCurrentTalents(),
                ["Default"] = 1,
                ["SpecID"] = GSE.GetCurrentSpecID(),
                ["GSEVersion"] = GSE.VersionString,
                ["Name"] = sequenceName
            },
            ["Macros"] = {
                [1] = {
                    ["Actions"] = {
                        [1] = {
                            ["macro"] = "Need Macro Here",
                            ["Type"] = Statics.Actions.Action
                        }
                    }
                }
            }
        }
        if not GSE.isEmpty(recordedstring) then
            sequence.Macros[1]["Actions"] = nil
            local recordedMacro = {}
            for _, v in ipairs(GSE.SplitMeIntoLines(recordedstring)) do
                local spellid = GSE.TranslateString(v, Statics.TranslatorMode.ID)
                if spellid then
                    local action = {
                        ["Type"] = Statics.Actions.Action,
                        ["type"] = "macro",
                        ["macro"] = spellid
                    }
                    table.insert(recordedMacro, action)
                end
            end
            sequence.Macros[1]["Actions"] = recordedMacro
        end
        if GSE.isEmpty(editor.NewSequences) then
            editor.NewSequences = {}
        end

        GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
        GSE.Library[classid][sequenceName] = sequence
        table.insert(editor.NewSequences, {["class"] = classid, ["name"] = sequenceName})
        newsequence = true
    else
        local elements = GSE.split(key, ",")
        classid = tonumber(elements[1])
        sequenceName = elements[3]

        local _, seq = GSE.DecodeMessage(GSESequences[classid][sequenceName])
        if seq then
            sequence = seq[2]
        end
    end
    if GSE.isEmpty(sequence.WeakAuras) then
        sequence.WeakAuras = {}
    end
    editor:SetStatusText("GSE: " .. GSE.VersionString)
    editor.SequenceName = sequenceName
    editor.OrigSequenceName = sequenceName
    editor.Sequence = sequence
    editor.ClassID = classid
    if newsequence == true then
        editor.ManageTree()
        local selpath =
            table.concat(
            {
                "Sequences",
                classid,
                classid .. "," .. GSE.GetCurrentSpecID() .. "," .. sequenceName .. ",0",
                "config"
            },
            "\001"
        )
        editor.treeContainer:SelectByValue(selpath)
    end
end

function GSE.ShowKeyBindings()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("KEYBINDINGS")
    editor:Show()
end

function GSE.ShowVariables()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("VARIABLES")
    editor:Show()
end

function GSE.ShowMacros()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("Macro")
    editor:Show()
end

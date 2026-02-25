local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- ---------------------------------------------------------------------------
-- Right-click context menus, keyed by tree "area" (unique[1])
-- ---------------------------------------------------------------------------

local function onRightClick_KEYBINDINGS(editframe, container, group, unique)
    if #unique <= 3 then return end
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateButton(L["New KeyBind"], function()
                local rightContainer = AceGUI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                editframe.showKeybind(nil, nil, nil, nil, "KB", rightContainer)
            end)
            rootDescription:CreateButton(L["New Actionbar Override"], function()
                local rightContainer = AceGUI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                editframe.showKeybind(nil, nil, nil, nil, "AO", rightContainer)
            end)
            rootDescription:CreateButton(L["Delete"], function()
                local bind, specialization, loadout, kbtype
                kbtype = unique[2]
                specialization = unique[3]
                if GetSpecialization then
                    bind = unique[4]
                    if unique[6] then loadout = unique[6] end
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
                if kbtype == "KB" then
                    SetBinding(bind)
                    if loadout and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                    then
                        if GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout][bind] = nil
                        end
                        local empty = true
                        for _, _ in pairs(GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]) do
                            empty = false
                        end
                        if empty then
                            GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout] = nil
                        end
                    else
                        if GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                           GSE_C["KeyBindings"][tostring(specialization)][bind]
                        then
                            GSE_C["KeyBindings"][tostring(specialization)][bind] = nil
                        end
                    end
                elseif kbtype == "AO" then
                    if loadout and GSE_C["KeyBindings"] and GSE_C["KeyBindings"][tostring(specialization)] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"] and
                       GSE_C["KeyBindings"][tostring(specialization)]["LoadOuts"][loadout]
                    then
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
                end
                editframe.ManageTree()
                GSE:SendMessage(Statics.Messages.VARIABLE_UPDATED, bind)
            end)
        end
    )
end

local function onRightClick_Sequences(editframe, container, group, unique, classid, sequencename)
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Sequence Editor"])
            rootDescription:CreateButton(L["New"], function()
                if editframe.loaded then
                    container:ReleaseChildren()
                    editframe.loaded = nil
                end
                local rightContainer = AceGUI:Create("SimpleGroup")
                rightContainer:SetFullWidth(true)
                rightContainer:SetLayout("List")
                GSE.GUILoadEditor(editframe)
                container:AddChild(rightContainer)
            end)
            if not GSE.isEmpty(sequencename) then
                rootDescription:CreateButton(L["Export"], function()
                    GSE.GUIExport(classid, sequencename, "SEQUENCE")
                end)
                rootDescription:CreateButton(L["Send"], function()
                    GSE.GUIShowTransmissionGui(sequencename, editframe)
                end)
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
                rootDescription:CreateButton(L["Chat Link"], function()
                    StaticPopupDialogs["GSE_ChatLink"].link = GSE.SequenceChatPattern(sequencename, classid)
                    StaticPopup_Show("GSE_ChatLink")
                end)
            end
            rootDescription:CreateButton(L["Keybindings"], function()
                GSE.ShowKeyBindings()
            end)
            if not GSE.isEmpty(sequencename) then
                rootDescription:CreateButton(L["Delete"], function()
                    editframe.GUIDeleteSequence(classid, sequencename)
                end)
            end
        end
    )
end

local function onRightClick_VARIABLES(editframe, container, group, unique, key)
    MenuUtil.CreateContextMenu(
        editframe.frame,
        function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Manage Variables"])
            rootDescription:CreateButton(L["Export Variable"], function()
                GSE.GUIExport(nil, key, "VARIABLE")
            end)
            rootDescription:CreateButton(L["Delete"], function()
                GSE.V[key] = nil
                GSEVariables[key] = nil
                editframe.ManageTree()
            end)
        end
    )
end

-- ---------------------------------------------------------------------------
-- Left-click handlers, keyed by area
-- ---------------------------------------------------------------------------

local function onClick_KEYBINDINGS(editframe, container, group, unique)
    if #unique < 2 then return end

    local bind, loadout, kbtype, button
    kbtype = unique[2]
    local specialization = unique[3]
    if C_SpecializationInfo or GetSpecialization then
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
        if kbtype == "AO" and bind then
            button = GSE_C["ActionBarBinds"]["Specialisations"][specialization][bind]
        end
    end

    local function makeRightContainer()
        local rc = AceGUI:Create("SimpleGroup")
        rc:SetFullWidth(true)
        rc:SetLayout("List")
        return rc
    end

    if unique[#unique] == "NKB" then
        if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
        local rc = makeRightContainer()
        editframe.showKeybind(nil, nil, nil, nil, "KB", rc)
        container:AddChild(rc)
        editframe.loaded = true
        editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["New KeyBind"])
    elseif unique[#unique] == "NAO" then
        if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
        local rc = makeRightContainer()
        editframe.showKeybind(nil, nil, nil, nil, "AO", rc)
        container:AddChild(rc)
        editframe.loaded = true
        editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["New Actionbar Override"])
    else
        if bind and button and kbtype then
            if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
            local rc = makeRightContainer()
            editframe.showKeybind(bind, button, specialization, loadout, kbtype, rc)
            container:AddChild(rc)
            editframe.loaded = true
            editframe:SetTitle(L["Sequence Editor"] .. ": " .. L["Keybind"])
        end
    end
end

local function onClick_Sequences(editframe, container, group, unique, path, key, classid, sequencename)
    if #unique < 3 then return end

    local editOptionsbutton = AceGUI:Create("Button")
    editOptionsbutton:SetText(L["Options"])
    editOptionsbutton:SetWidth(100)
    editOptionsbutton:SetCallback("OnClick", function() GSE.OpenOptionsPanel() end)
    editOptionsbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Options"], L["Opens the GSE Options window"], editframe)
    end)
    editOptionsbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local transbutton = AceGUI:Create("Button")
    transbutton:SetText(L["Send"])
    transbutton:SetWidth(100)
    transbutton:SetCallback("OnClick", function()
        GSE.GUIShowTransmissionGui(editframe.ClassID .. "," .. editframe.SequenceName, editframe)
    end)
    transbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(
            L["Send"],
            L["Send this macro to another GSE player who is on the same server as you are."],
            editframe
        )
    end)
    transbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

    local editButtonGroup = AceGUI:Create("SimpleGroup")
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
                editframe.GUIUpdateSequenceDefinition(
                    editframe.ClassID,
                    editframe.SequenceName,
                    editframe.Sequence
                )
                editframe.save = true
                if editframe.newname then
                    editframe.newname = nil
                end
            else
                GSE.Print(
                    L["Error processing Custom Pause Value.  You will need to recheck your macros."],
                    "ERROR"
                )
            end
        end
    )
    savebutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Save"], L["Save the changes made to this macro"], editframe)
    end)
    savebutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    editButtonGroup:AddChild(savebutton)
    editframe.SaveButton = savebutton

    local delbutton = AceGUI:Create("Button")
    delbutton:SetText(L["Delete"])
    delbutton:SetWidth(100)
    delbutton:SetCallback("OnClick", function()
        local seqname = editframe.SequenceName
        local cid = editframe.ClassID
        editframe.GUIDeleteSequence(cid, seqname)
        editframe.ManageTree()
    end)
    delbutton:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Delete"], L["Delete this macro.  This is not able to be undone."], editframe)
    end)
    delbutton:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    editButtonGroup:AddChild(delbutton)
    editButtonGroup:AddChild(transbutton)
    editButtonGroup:AddChild(editOptionsbutton)

    if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end

    local basecontainer = AceGUI:Create("SimpleGroup")
    basecontainer:SetLayout("List")
    basecontainer:SetFullWidth(true)
    basecontainer:SetHeight(editframe.Height - 100) -- TOOLBAR_OFFSET
    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetHeight(editframe.Height - 120) -- SCROLLCONTAINER_OFFSET
    scrollcontainer:SetLayout("Fill")
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

    -- Navigate to class-level node → auto-select config
    if unique[1] == "Sequences" and #unique == 3 then
        container:ReleaseChildren()
        editframe.treeContainer:SelectByValue(group .. "\001config")
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
        nameeditbox:SetCallback("OnTextChanged", function()
            editframe.SequenceName = nameeditbox:GetText()
            editframe.newname = true
        end)
        nameeditbox:SetCallback("OnEnter", function()
            GSE.CreateToolTip(
                L["Sequence Name"],
                L[
                    "The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."
                ],
                editframe
            )
        end)
        nameeditbox:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        editframe.nameeditbox = nameeditbox
        local headerGroup = AceGUI:Create("SimpleGroup")
        headerGroup:SetFullWidth(true)
        headerGroup:SetLayout("Flow")
        contentcontainer:AddChild(headerGroup)
        headerGroup:AddChild(nameeditbox)
        editframe.GUIDrawMetadataEditor(contentcontainer)
        editframe:SetTitle(L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["Configuration"] .. ")")
    elseif key == "newversion" then
        if editframe.OrigSequenceName ~= sequencename then
            GSE.GUILoadEditor(editframe, path[#path])
        end
        table.insert(
            editframe.Sequence.Macros,
            GSE.CloneSequence(editframe.Sequence.Macros[editframe.Sequence.MetaData.Default])
        )
        editframe.GUIDrawMacroEditor(contentcontainer, #editframe.Sequence.Macros, table.concat(path, "\001"))
        editframe:SetTitle(
            L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["New"] .. " " .. L["Version"] .. ")"
        )
    else
        if editframe.OrigSequenceName ~= sequencename then
            GSE.GUILoadEditor(editframe, path[#path])
        end
        editframe.GUIDrawMacroEditor(contentcontainer, key, table.concat(path, "\001"))
        editframe:SetTitle(
            L["Sequence Editor"] .. ": " .. sequencename .. " (" .. L["Version"] .. ":" .. key .. ")"
        )
    end
    basecontainer:AddChild(editButtonGroup)
    editframe.loaded = true
end

local function onClick_VARIABLES(editframe, container, group, unique, key)
    if #unique <= 1 then return end
    if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
    editframe.showVariable(key, container)
    editframe.loaded = true
end

local function onClick_Macro(editframe, container, group, unique, key)
    if #unique ~= 3 then return end
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
        if GSEMacros[char .. "-" .. realm] and GSEMacros[char .. "-" .. realm][mname] and
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
    if editframe.loaded then container:ReleaseChildren(); editframe.loaded = nil end
    editframe.showMacro(node, container)
    editframe.loaded = true
end

-- ---------------------------------------------------------------------------
-- ManageTree(editframe)
-- Builds the full sequence tree and wires up OnGroupSelected.
-- ---------------------------------------------------------------------------
local function ManageTree(editframe)
    local treeContainer = editframe.treeContainer

    -- Build sequence sub-tree
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
            table.insert(node.children, {
                value = i,
                text = editframe.BuildVersionLabel(tostring(i), j.Label)
            })
        end
        table.insert(node.children, {
            text = L["New"] .. " " .. L["Version"],
            value = "newversion",
            icon = Statics.ActionsIcons.Add
        })
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
            for _, h in ipairs(j) do
                table.insert(tnode.children, h)
            end
        end
        table.insert(subtree.children, tnode)
    end

    table.insert(tree, subtree)
    table.insert(tree, editframe.buildKeybindMenu())
    table.insert(tree, editframe.buildVariablesMenu())
    table.insert(tree, editframe.buildMacroMenu())

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
                -- Dispatch table for right-click by area
                if area == "KEYBINDINGS" then
                    onRightClick_KEYBINDINGS(editframe, container, group, unique)
                elseif area == "Sequences" then
                    onRightClick_Sequences(editframe, container, group, unique, classid, sequencename)
                elseif area == "VARIABLES" then
                    onRightClick_VARIABLES(editframe, container, group, unique, key)
                end
                -- area == "Macro": no right-click menu
            elseif mbutton == "LeftButton" and IsShiftKeyDown() then
                StaticPopupDialogs["GSE_ChatLink"].link = GSE.SequenceChatPattern(sequencename, classid)
                StaticPopup_Show("GSE_ChatLink")
            else
                -- Left-click dispatch table
                if area == "NewSequence" then
                    GSE.GUILoadEditor(editframe)
                elseif area == "Import" then
                    GSE.ShowImport()
                elseif area == "KEYBINDINGS" then
                    local path = unique
                    onClick_KEYBINDINGS(editframe, container, group, unique)
                elseif area == "Sequences" then
                    local path = GSE.CloneSequence(unique)
                    table.remove(path, #path)
                    onClick_Sequences(editframe, container, group, unique, path, key, classid, sequencename)
                elseif area == "VARIABLES" then
                    onClick_VARIABLES(editframe, container, group, unique, key)
                elseif area == "Macro" then
                    onClick_Macro(editframe, container, group, unique, key)
                else
                    editframe:SetTitle(L["Sequence Editor"])
                end
            end
        end
    )
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupTree(editframe)
    editframe.ManageTree = function()
        ManageTree(editframe)
    end
end

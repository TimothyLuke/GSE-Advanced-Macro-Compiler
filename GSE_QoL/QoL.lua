local GSE = GSE

local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = GSE.L

local playerSpells = {}

function GSE.PlayerSpellsLoaded()
    return #playerSpells > 0
end

if GSE.GameMode > 10 then
    local function loadPlayerSpells()
        table.wipe(playerSpells)

        for tab = 2, C_SpellBook.GetNumSpellBookSkillLines() do
            local lineinfo = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            local offset = lineinfo.itemIndexOffset

            for i = 0, lineinfo.numSpellBookItems do
                local spellinfo = C_SpellBook.GetSpellBookItemInfo(i + offset, 0)

                local spellName = spellinfo.name
                --local spellID = spellinfo.spellID
                local offspec = spellinfo.isOffSpec
                local passive = spellinfo.isPassive
                if not passive and not offspec and spellName then
                    table.insert(playerSpells, spellName)
                end
            end
        end
        table.sort(playerSpells)
    end

    AceEvent:RegisterEvent("SPELLS_CHANGED", loadPlayerSpells)
    AceEvent:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", loadPlayerSpells)
    AceEvent:RegisterEvent("TRAIT_CONFIG_UPDATED", loadPlayerSpells)
    AceEvent:RegisterEvent("PLAYER_TALENT_UPDATE", loadPlayerSpells)

    GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro, frame)
        if GSE.isEmpty(action.type) then
            action.type = "spell"
        end

        local spellEditBox = AceGUI:Create("EditBox")

        spellEditBox:SetWidth(250)
        spellEditBox:DisableButton(true)
        if #playerSpells < 1 then
            loadPlayerSpells()
        end
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
        --local compiledAction = GSE.CompileAction(action, sequence.Macros[version])
        spellEditBox:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                if sequence.Macros[version].Actions[keyPath].type == "pet" then
                    sequence.Macros[version].Actions[keyPath].action = value
                    sequence.Macros[version].Actions[keyPath].spell = nil
                    sequence.Macros[version].Actions[keyPath].macro = nil
                    sequence.Macros[version].Actions[keyPath].item = nil
                    sequence.Macros[version].Actions[keyPath].toy = nil
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

                --compiledAction = GSE.CompileAction(returnAction, sequence.Macros[version])
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
                value = GSE.UnEscapeString(value)
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
                compiledmacrotext = compiledmacrotext .. "\n\n" .. string.format(L["%s/255 Characters Used"], lenMacro)
                compiledMacro:SetText(compiledmacrotext)
            end
        )

        if GSE.Patron then
            spellEditBox.editbox:SetScript(
                "OnTabPressed",
                function(widget, button, down)
                    -- if button == "RightButton" then
                    MenuUtil.CreateContextMenu(
                        frame,
                        function(ownerRegion, rootDescription)
                            rootDescription:CreateTitle(L["Insert Spell"])
                            for _, v in pairs(playerSpells) do
                                rootDescription:CreateButton(
                                    v,
                                    function()
                                        spellEditBox:SetText(v)
                                        sequence.Macros[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        spellEditBox:SetText("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Macros[version].Actions[keyPath].spell =
                                            "\n" .. [[=GSE.V["]] .. k .. [["]()]]
                                    end
                                )
                            end
                        end
                    )
                end
            )

            macroEditBox.editBox:SetScript(
                "OnTabPressed",
                function(widget, button, down)
                    -- if button == "RightButton" then
                    MenuUtil.CreateContextMenu(
                        frame,
                        function(ownerRegion, rootDescription)
                            rootDescription:CreateTitle(L["Insert Spell"])
                            for _, v in pairs(playerSpells) do
                                rootDescription:CreateButton(
                                    v,
                                    function()
                                        macroEditBox.editBox:Insert(v)
                                        sequence.Macros[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        macroEditBox.editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Macros[version].Actions[keyPath].spell =
                                            "\n" .. [[=GSE.V["]] .. k .. [["]()]]
                                    end
                                )
                            end
                        end
                    )
                end
            )
        end

        return spellEditBox, macroEditBox
    end
end
local function compileExport(exportTable, humanReadable)
    local exportstring =
        GSE.EncodeMessage(
        {
            type = "COLLECTION",
            payload = exportTable
        }
    )

    if humanReadable then
        exportstring = "# UPDATE PACKAGE NAME \n ```\n" .. exportstring .. "\n```\n\n"
        exportstring = exportstring .. "This package consists of " .. exportTable.ElementCount .. " elements.\n"

        local sequenceString = ""
        for k, _ in pairs(exportTable.Sequences) do
            sequenceString = sequenceString .. "- " .. k .. "\n"
        end
        if string.len(sequenceString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Sequences"] .. "\n" .. sequenceString
        end

        local macroString = ""
        for k, _ in pairs(exportTable.Macros) do
            macroString = macroString .. "- " .. k .. "\n"
        end
        if string.len(macroString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Macros"] .. "\n" .. macroString
        end

        local variableString = ""
        for k, _ in pairs(exportTable.Variables) do
            variableString = variableString .. "- " .. k .. "\n"
        end
        if string.len(variableString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Variables"] .. "\n" .. variableString
        end
    end
    return exportstring
end

GSE.GUIAdvancedExport = function(exportframe)
    exportframe:ReleaseChildren()
    exportframe:SetStatusText(L["Advanced Export"])
    local exportTable = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {},
        ["ElementCount"] = 0
    }

    local HeaderRow = AceGUI:Create("SimpleGroup")
    HeaderRow:SetLayout("Flow")
    HeaderRow:SetFullWidth(true)
    local SequenceDropDown = AceGUI:Create("Dropdown")
    local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
    for k, v in GSE.pairsByKeys(GSE.GetSequenceNames(), GSE.AlphabeticalTableSortAlgorithm) do
        local elements = GSE.split(k, ",")
        local classid, specid = tonumber(elements[1]), tonumber(elements[2])
        if cid ~= classid then
            local val = GSE.GetClassName(classid) and GSE.GetClassName(classid) or L["Global"]
            local key = classid .. val

            SequenceDropDown:AddItem(key, val)
            SequenceDropDown:SetItemDisabled(key, true)
            cid = classid
        end
        if GetSpecializationInfoByID then
            if sid ~= specid and sid > 13 and specid > 13 then
                local val = select(2, GetSpecializationInfoByID(specid))
                local key = specid .. val

                SequenceDropDown:AddItem(key, val)
                SequenceDropDown:SetItemDisabled(key, true)
                sid = specid
            end
        end
        SequenceDropDown:AddItem(v, v)
    end
    for k, _ in pairs(GSESequences[0]) do
        SequenceDropDown:AddItem(k, k)
    end
    SequenceDropDown:SetMultiselect(true)
    SequenceDropDown:SetLabel(L["Sequences"])

    local VariableDropDown = AceGUI:Create("Dropdown")
    if not GSE.isEmpty(GSEVariables) then
        for k, _ in pairs(GSEVariables) do
            VariableDropDown:AddItem(k, k)
        end
    end

    local MacroDropDown = AceGUI:Create("Dropdown")

    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    for macid = 1, maxmacros do
        local mname, _, _ = GetMacroInfo(macid)
        if mname then
            MacroDropDown:AddItem(mname, mname)
        end
    end
    MacroDropDown:SetMultiselect(true)
    MacroDropDown:SetLabel(L["Macros"])

    HeaderRow:AddChild(SequenceDropDown)
    HeaderRow:AddChild(MacroDropDown)
    HeaderRow:AddChild(VariableDropDown)
    exportframe:AddChild(HeaderRow)

    local humanexportcheckbox = AceGUI:Create("CheckBox")
    humanexportcheckbox:SetType("checkbox")

    humanexportcheckbox:SetLabel(L["Create Human Readable Export"])
    exportframe:AddChild(humanexportcheckbox)

    humanexportcheckbox:SetValue(GSEOptions.UseWLMExportFormat)

    local exportsequencebox = AceGUI:Create("MultiLineEditBox")
    exportsequencebox:SetLabel(L["Variable"])
    exportsequencebox:SetNumLines(22)
    exportsequencebox:DisableButton(true)
    exportsequencebox:SetFullWidth(true)
    exportframe:AddChild(exportsequencebox)

    VariableDropDown:SetMultiselect(true)
    VariableDropDown:SetLabel(L["Variables"])
    VariableDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(GSEVariables[key])
                uncompressedVersion.objectType = "VARIABLE"
                uncompressedVersion.name = key
                exportTable["Variables"][key] = GSE.EncodeMessage(uncompressedVersion)
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Variables"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    SequenceDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                print(key)
                exportTable["Sequences"][key] =
                    GSE.UnEscapeTable(
                    GSE.TranslateSequence(GSE.CloneSequence(GSE.FindSequence(key)), Statics.TranslatorMode.ID)
                )
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Sequences"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    MacroDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local category = "a"
                local source = GSEMacros[key]
                if GSE.isEmpty(source) then
                    local char, realm = UnitFullName("player")
                    if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
                        GSEMacros[char .. "-" .. realm] = {}
                    end
                    if GSE.isEmpty(GSEMacros[char .. "-" .. realm][key]) then
                        -- need to find the macro as its not managed by GSE
                        source = {}
                        local mslot = GetMacroIndexByName(key)
                        local _, micon, mbody = GetMacroInfo(mslot)
                        source.name = key
                        source.icon = micon
                        source.text = mbody
                        source.managedMacro = GSE.CompileMacroText(mbody, Statics.TranslatorMode.ID)
                        if mslot > MAX_ACCOUNT_MACROS then
                            category = "p"
                        end
                        print("made new")
                    else
                        source = GSEMacros[char .. "-" .. realm][key]
                        category = "p"
                    end
                end
                local exportobject = GSE.CloneSequence(source)
                exportobject.objectType = "MACRO"
                exportobject.category = category
                exportobject.name = key
                exportTable["Macros"][key] = exportobject
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Macros"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    humanexportcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
end

local function ProcessLegacyVariables(lines, variableTable)
    local returnLines = {}
    for _, line in ipairs(lines) do
        if line ~= "/click GSE.Pause" then
            if not GSE.isEmpty(variableTable) then
                for key, value in pairs(variableTable) do
                    if type(value) == "string" then
                        local functline = value
                        if string.sub(functline, 1, 10) == "function()" then
                            GSE.UpdateVariable(value, key)
                            value = '=GSE.V["' .. key '"]()'
                        end
                    end
                    if type(value) == "boolean" then
                        value = tostring(value)
                    end
                    if value == nil then
                        value = ""
                    end
                    if type(value) == "table" then
                        value = GSE.SafeConcat(value, "\n")
                    end

                    line = string.gsub(line, string.format("~~%s~~", key), value)
                end
            end
        end
        table.insert(returnLines, line)
    end
    return GSE.SafeConcat(returnLines, "\n")
end

local function buildAction(action, variables)
    if action.Type == Statics.Actions.Loop then
        -- we have a loop within a loop
        return GSE.processAction(action, variables)
    else
        action.type = "macro"
        local macro = ProcessLegacyVariables(action, variables)

        action.macro = macro
        action.target = " "
        return action
    end
end

local function processAction(action, variables)
    if action.Type == Statics.Actions.Loop then
        local actionList = {}
        -- setup the interation
        for _, v in ipairs(action) do
            local builtaction = processAction(v, variables)
            table.insert(actionList, builtaction)
        end
        -- process repeats for the block
        for k, v in ipairs(actionList) do
            action[k] = v
        end
        return action
    elseif action.Type == Statics.Actions.Pause then
        return action
    elseif action.Type == Statics.Actions.If then
        local actionList = {}
        for _, v in ipairs(action) do
            table.insert(processAction(v, variables))
        end

        -- process repeats for the block
        for k, v in ipairs(actionList) do
            action[k] = v
        end
        return action
    else
        local builtstuff = buildAction(action, variables)
        for k, _ in ipairs(action) do
            action[k] = nil
        end

        return builtstuff
    end
end

function GSE.Update31Actions(sequence)
    local seq = GSE.CloneSequence(sequence)
    for k, _ in ipairs(seq.Macros) do
        setmetatable(seq.Macros[k].Actions, Statics.TableMetadataFunction)
        local actiontable = {}
        for _, j in ipairs(seq.Macros[k].Actions) do
            local processed = processAction(j, seq.Macros[k].Variables)
            table.insert(actiontable, processed)
        end
        seq.Macros[k].Actions = actiontable
        seq.Macros[k].Variables = nil
        seq.Macros[k].InbuiltVariables = nil
    end
    seq.MetaData.Version = 3200
    seq.WeakAuras = nil
    return seq
end

function GSE.CreateIconControl(action, version, keyPath, sequence, frame)
    local lbl = AceGUI:Create("InteractiveLabel")
    lbl:SetFontObject(GameFontNormalLarge)
    lbl:SetWidth(25)
    lbl:SetHeight(25)

    if action.Icon then
        lbl:SetText("|T" .. action.Icon .. ":0|t")
    else
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
    end
    local spellinfolist = {}

    if action.type == "macro" then
        local macro = GSE.UnEscapeString(action.macro)
        if string.sub(macro, 1, 1) == "/" then
            local lines = GSE.SplitMeIntoLines(macro)
            for _, v in ipairs(lines) do
                local spellinfo = GSE.GetSpellsFromString(v)
                if spellinfo and #spellinfo > 1 then
                    for _, j in ipairs(spellinfo) do
                        if j and j.iconID then
                            table.insert(spellinfolist, j)
                        end
                    end
                else
                    if spellinfo and spellinfo.iconID then
                        table.insert(spellinfolist, spellinfo)
                    end
                end
            end
        else
            local spellinfo = {}
            spellinfo.name = action.macro
            local macindex = GetMacroIndexByName(spellinfo.name)
            local _, iconid, _ = GetMacroInfo(macindex)
            if macindex and iconid then
                spellinfo.iconID = iconid
                table.insert(spellinfolist, spellinfo)
            end
        end
    elseif action.type == "Spell" then
        local spellinfo = C_Spell.GetSpellInfo(action.spell)
        if spellinfo and spellinfo.iconID then
            table.insert(spellinfolist, spellinfo)
        end
    end

    lbl:SetCallback(
        "OnClick",
        function(widget, button)
            MenuUtil.CreateContextMenu(
                frame,
                function(ownerRegion, rootDescription)
                    rootDescription:CreateTitle(L["Select Icon"])
                    for _, v in pairs(spellinfolist) do
                        rootDescription:CreateButton(
                            "|T" .. v.iconID .. ":0|t " .. v.name,
                            function()
                                lbl:SetText("|T" .. v.iconID .. ":0|t")
                                sequence.Macros[version].Actions[keyPath].Icon = v.iconID
                            end
                        )
                    end
                end
            )
        end
    )
    return lbl
end

-- Skyriding Bind Bar for Retail
if GSE.GameMode >= 11 then
    local config = LibStub("AceConfig-3.0")
    local dialog = LibStub("AceConfigDialog-3.0")
    local addonName = "|cFFFFFFFFGS|r|cFF00FFFFE|r"
    local OptionsTable = {
        type = "group",
        args = {
            title = {
                name = L["Skyriding / Vehicle Keybinds"],
                desc = L["Override bindings for Skyriding, Vehicle, Possess and Override Bars"],
                order = 1,
                type = "header"
            }
        }
    }

    for i = 1, 12 do
        OptionsTable.args["Skyriding" .. tostring(i)] = {
            name = L["Skyriding Button"] .. " " .. tostring(i),
            type = "keybinding",
            set = function(info, val)
                if GSE.isEmpty(GSEOptions.SkyRidingBinds) then
                    GSEOptions.SkyRidingBinds = {}
                end
                GSEOptions.SkyRidingBinds[tostring(i)] = val
                GSE.UpdateVehicleBar()
            end,
            get = function(info)
                return GSEOptions.SkyRidingBinds and GSEOptions.SkyRidingBinds[tostring(i)] and
                    GSEOptions.SkyRidingBinds[tostring(i)] or
                    ""
            end,
            order = i + 1
        }
    end
    config:RegisterOptionsTable(addonName .. "-Skyriding", OptionsTable)
    dialog:AddToBlizOptions(addonName .. "-Skyriding", OptionsTable.args.title.name, addonName) -- Hidden macro buttons that execute pet battle abilities, to click on them when the player -- enters a pet battle, with the binds assigned by the user in the vehicle binds panel
    ----------------------------------------------------------------------------------------------------------

    -- Pet battle buttons
    local PetBattleButton = {}
    for i = 1, 6 do
        PetBattleButton[i] = CreateFrame("Button", "GSE_PetBattleButton" .. i, nil, "SecureActionButtonTemplate")
        PetBattleButton[i]:RegisterForClicks("AnyDown")
        PetBattleButton[i]:SetAttribute("type", "macro")
        if i <= 3 then
            PetBattleButton[i]:SetAttribute(
                "macrotext",
                "/run PetBattleFrame.BottomFrame.abilityButtons[" .. i .. "]:Click()"
            )
        end
    end

    PetBattleButton[4]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.SwitchPetButton:Click()")
    PetBattleButton[5]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.CatchButton:Click()")
    PetBattleButton[6]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.ForfeitButton:Click()") -- Hidden action bar to click on its buttons when the player enters a vehicle or -- skyriding mount, with the binds assigned by the user in the vehicle binds panel
    -------------------------------------------------------------------------------------------------------

    -- Vehicle/Skyriding bar
    local VehicleBar = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
    VehicleBar:SetAttribute("actionpage", 1)
    VehicleBar:Hide()

    -- Creating buttons
    local VehicleButton = {}
    for i = 1, 12 do
        VehicleButton[i] = CreateFrame("Button", "GSE_VehicleButton" .. i, VehicleBar, "SecureActionButtonTemplate")
        local B = VehicleButton[i]
        B:Hide()
        B:SetID(i)
        B:SetAttribute("type", "action")
        B:SetAttribute("action", i)
        B:SetAttribute("useparent-actionpage", true)
        B:RegisterForClicks("AnyDown")
    end

    -- Table that will store the keybinds for vehicles desired by the user

    function GSE.UpdateVehicleBar()
        local tableval = {}
        for k, v in pairs(GSEOptions.SkyRidingBinds) do
            table.insert(tableval, k .. "\001" .. v)
        end

        local executionString =
            "VehicleKeybindTable = newtable([=======[" ..
            string.join("]=======],[=======[", unpack(tableval)) ..
                "]=======])" ..
                    [[
            VehicleKeybind = newtable()
            for _,v in ipairs(VehicleKeybindTable) do
                local x, y = strsplit("\001",v)
                VehicleKeybind[tonumber(x)] = y
            end

            ]]
        VehicleBar:Execute(executionString) -- Key: Button index / Value: Keybind
    end

    GSE.UpdateVehicleBar()
    -- Triggers
    VehicleBar:SetAttribute(
        "_onattributechanged",
        [[
  -- Actionpage update
  if name == "page" then
    if HasVehicleActionBar() then self:SetAttribute("actionpage", GetVehicleBarIndex())
    elseif HasOverrideActionBar() then self:SetAttribute("actionpage", GetOverrideBarIndex())
    elseif HasBonusActionBar() then self:SetAttribute("actionpage", GetBonusBarIndex())
    else self:SetAttribute("actionpage", GetActionBarPage()) end

  -- Settings binds of higher priority than the normal ones when the player enters a vehicle, to be able to use it
  elseif name == "vehicletype" then
    if value == "vehicle" then -- Vehicles/Skyriding
      for i = 1, 12 do
        if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_VehicleButton"..i) end
      end

    elseif value == "petbattle" then -- Pet battle
      for i = 1, 6 do
        if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_PetBattleButton"..i) end
      end

    elseif value == "none" then -- No vehicle, deleting vehicle binds
      self:ClearBindings()
    end
  end
]]
    )

    -- Actionpage trigger
    RegisterAttributeDriver(
        VehicleBar,
        "page",
        "[vehicleui] A;" ..
            "[possessbar] B;" ..
                "[overridebar] C;" ..
                    "[bonusbar:5] D;" .. -- Skyriding
                        "E"
    )

    -- Vehicle trigger
    RegisterAttributeDriver(
        VehicleBar,
        "vehicletype",
        "[vehicleui][possessbar][overridebar][bonusbar:5] vehicle;" .. "[petbattle] petbattle;" .. "none"
    ) -- Event PET_BATTLE_OPENING_START -- Triggers when a pet battle starts. Used only in MoP because it doesn't have the [petbattle] -- macro condition to detect pet battles from the Restricted Environment like post-MoP expansions.
    ----------------------------------------------------------------------------------------------------------------------

    --[[ Events ]]
    function GSE:PET_BATTLE_OPENING_START()
        VehicleBar:Execute(
            [[
    for i = 1, 6 do
      if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_PetBattleButton"..i) end
    end
  ]]
        )
    end

    -- Event PET_BATTLE_CLOSE
    -- Triggers when a pet battle starts. Used only in MoP because it doesn't have the [petbattle]
    -- macro condition to detect pet battles from the Restricted Environment like post-MoP expansions.
    function GSE:PET_BATTLE_CLOSE()
        VehicleBar:Execute([[ self:ClearBindings() ]])
    end
    GSE:RegisterEvent("PET_BATTLE_OPENING_START")
    GSE:RegisterEvent("PET_BATTLE_CLOSE")
end

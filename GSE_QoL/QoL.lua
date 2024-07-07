local GSE = GSE

local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro)
    local playerSpells = {}

    -- local function spellFilter(self, spellID)
    --     return playerSpells[spellID]
    -- end

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

    if GSE.isEmpty(action.type) then
        action.type = "spell"
    end

    local spellEditBox = AceGUI:Create("EditBox")
    spellEditBox:SetLabel(L["Spell/Item/Macro/Toy/Pet Ability"])

    spellEditBox:SetWidth(250)
    spellEditBox:DisableButton(true)

    loadPlayerSpells()

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
            spelltext = GSE.TranslateString(action.macro, Statics.TranslatorMode.Current)
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
                sequence.Macros[version].Actions[keyPath].macro = GSE.TranslateString(value, Statics.TranslatorMode.ID)
            else
                sequence.Macros[version].Actions[keyPath].macro = value
            end
            sequence.Macros[version].Actions[keyPath].spell = nil
            sequence.Macros[version].Actions[keyPath].action = nil
            sequence.Macros[version].Actions[keyPath].item = nil
            sequence.Macros[version].Actions[keyPath].toy = nil
            local compiledmacrotext =
                GSE.UnEscapeString(GSE.TranslateString(action.macro, Statics.TranslatorMode.String))
            local lenMacro = string.len(compiledmacrotext)
            compiledmacrotext = compiledmacrotext .. "\n\n" .. string.format(L["%s/255 Characters Used"], lenMacro)
            compiledMacro:SetText(compiledmacrotext)
        end
    )
    macroEditBox:SetCallback(
        "OnEditFocusLost",
        function()
            macroEditBox:SetText(GSE.TranslateString(macroEditBox:GetText(), Statics.TranslatorMode.Current))
        end
    )
    if GSE.Patron then
        spellEditBox.editbox:SetScript(
            "OnTabPressed",
            function(widget, button, down)
                -- if button == "RightButton" then
                MenuUtil.CreateContextMenu(
                    spellEditBox,
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
                    spellEditBox,
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
    for k, _ in pairs(GSE3Storage[GSE.GetCurrentClassID()]) do
        SequenceDropDown:AddItem(k, k)
    end
    for k, _ in pairs(GSE3Storage[0]) do
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
                exportTable["Sequences"][key] = GSE.ExportSequence(GSE.FindMacro(key), key, false)
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
                    source = GSEMacros[char .. "-" .. realm][key]
                    category = "p"
                end
                local exportobject = GSE.CloneSequence(source)
                exportobject.objectType = "MACRO"
                exportobject.category = category
                exportobject.name = key
                if GSE.isEmpty(exportobject.managedMacro) then
                    local _, micon, mbody = GetMacroInfo(key)
                    exportobject.icon = micon
                    exportobject.text = mbody
                    exportobject.managedMacro = GSE.CompileMacroText(mbody, Statics.TranslatorMode.ID)
                end
                exportTable["Macros"][key] = GSE.EncodeMessage(exportobject)
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

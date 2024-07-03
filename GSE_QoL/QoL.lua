local GSE = GSE

local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
-- local Completing = LibStub("AceGUI-3.0-Spell-EditBox")
-- GSE.GUIExport(nil, nil, "ADVANCED")
GSE.CreateSpellEditBox = function(action, version, keyPath, sequence)
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
    elseif action.item then
        spelltext = action.item
    elseif action.macro then
        if string.sub(action.macro, 1, 1) == "/" then
            spelltext = GSE.TranslateString(action.macro, Statics.TranslatorMode.Current)
        else
            spelltext = action.macro
        end
    elseif action.action then
        spelltext = action.action
    else
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
            elseif sequence.Macros[version].Actions[keyPath].type == "macro" then
                if string.sub(GSE.UnEscapeString(value), 1, 1) == "/" then
                    sequence.Macros[version].Actions[keyPath].macro =
                        GSE.TranslateString(value, Statics.TranslatorMode.Current)
                else
                    sequence.Macros[version].Actions[keyPath].macro = value
                end
                sequence.Macros[version].Actions[keyPath].spell = nil
                sequence.Macros[version].Actions[keyPath].action = nil
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
                                end
                            )
                        end

                        rootDescription:CreateTitle(L["Insert GSE Variable"])
                        for k, _ in pairs(GSEVariables) do
                            rootDescription:CreateButton(
                                k,
                                function()
                                    spellEditBox:SetText("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                end
                            )
                        end
                        -- rootDescription:CreateTitle(L["Insert GSE Sequence"])
                        -- for k, _ in pairs(GSE3Storage[GSE.GetCurrentClassID()]) do
                        --     rootDescription:CreateButton(
                        --         k,
                        --         function()
                        --             if GSE.GetMacroStringFormat() == "DOWN" then
                        --                 spellEditBox.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                        --             else
                        --                 spellEditBox.editBox:Insert("\n/click " .. k)
                        --             end
                        --         end
                        --     )
                        -- end
                        -- for k, _ in pairs(GSE3Storage[0]) do
                        --     rootDescription:CreateButton(
                        --         k,
                        --         function()
                        --             if GSE.GetMacroStringFormat() == "DOWN" then
                        --                 spellEditBox.editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                        --             else
                        --                 spellEditBox.editBox:Insert("\n/click " .. k)
                        --             end
                        --         end
                        --     )
                        -- end
                    end
                )
                -- end
            end
        )
    end

    return spellEditBox
end

local function compileExport(exportTable, humanReadable)
    return GSE.Dump(exportTable)
end

GSE.GUIAdvancedExport = function(exportframe)
    exportframe:ReleaseChildren()
    exportframe:SetStatusText(L["Advanced Export"])
    local exportTable = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {}
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
                exportTable["Variables"][key] = true
            else
                exportTable["Variables"][key] = false
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    SequenceDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                exportTable["Sequences"][key] = true
            else
                exportTable["Sequences"][key] = false
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    MacroDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                exportTable["Macros"][key] = true
            else
                exportTable["Macros"][key] = false
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
end

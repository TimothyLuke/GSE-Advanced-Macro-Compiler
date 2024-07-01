local GSE = GSE

local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local Completing = LibStub("AceGUI-3.0-Completing-EditBox")

GSE.CreateSpellEditBox = function(action, version, keyPath, sequence)
    local spellEditBox = AceGUI:Create("EditBox")
    spellEditBox:SetLabel(L["Spell/Item/Macro/Toy/Pet Ability"])

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
    elseif action.item then
        spelltext = action.item
    elseif action.macro then
        spelltext = action.macro
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
                sequence.Macros[version].Actions[keyPath].macro = value
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

    return spellEditBox
end

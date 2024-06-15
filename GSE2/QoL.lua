local GSE = GSE

local editframe = GSE.GUIEditFrame
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local Completing = LibStub("AceGUI-3.0-Completing-EditBox")

GSE.CreateSpellEditBox = function(action, version, keyPath)
    local spellEditBox = AceGUI:Create("EditBox")
    spellEditBox:SetLabel(L["Spell/Item/Macro/Toy/Pet Ability"])

    spellEditBox:SetWidth(250)
    spellEditBox:DisableButton(true)

    local spelltext
    if action.spell then
        spelltext = GSE.GetSpellId(action.spell, Statics.TranslatorMode.Current)
    elseif action.item then
        spelltext = action.item
    elseif action.macro then
        spelltext = action.macro
    elseif action.action then
        spelltext = action.action
    else
        spelltext = action.toy
    end

    spellEditBox:SetText(spelltext)
    --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Macros[version])
    spellEditBox:SetCallback(
        "OnTextChanged",
        function(sel, object, value)
            if editframe.Sequence.Macros[version].Actions[keyPath].type == "pet" then
                editframe.Sequence.Macros[version].Actions[keyPath].action = value
                editframe.Sequence.Macros[version].Actions[keyPath].spell = nil
                editframe.Sequence.Macros[version].Actions[keyPath].macro = nil
                editframe.Sequence.Macros[version].Actions[keyPath].item = nil
                editframe.Sequence.Macros[version].Actions[keyPath].toy = nil
            elseif editframe.Sequence.Macros[version].Actions[keyPath].type == "macro" then
                editframe.Sequence.Macros[version].Actions[keyPath].macro = value
                editframe.Sequence.Macros[version].Actions[keyPath].spell = nil
                editframe.Sequence.Macros[version].Actions[keyPath].action = nil
                editframe.Sequence.Macros[version].Actions[keyPath].item = nil
                editframe.Sequence.Macros[version].Actions[keyPath].toy = nil
            elseif editframe.Sequence.Macros[version].Actions[keyPath].type == "item" then
                editframe.Sequence.Macros[version].Actions[keyPath].item = value
                editframe.Sequence.Macros[version].Actions[keyPath].spell = nil
                editframe.Sequence.Macros[version].Actions[keyPath].action = nil
                editframe.Sequence.Macros[version].Actions[keyPath].macro = nil
                editframe.Sequence.Macros[version].Actions[keyPath].toy = nil
            elseif editframe.Sequence.Macros[version].Actions[keyPath].type == "toy" then
                editframe.Sequence.Macros[version].Actions[keyPath].toy = value
                editframe.Sequence.Macros[version].Actions[keyPath].spell = nil
                editframe.Sequence.Macros[version].Actions[keyPath].action = nil
                editframe.Sequence.Macros[version].Actions[keyPath].macro = nil
                editframe.Sequence.Macros[version].Actions[keyPath].item = nil
            else
                local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                if storedValue then
                    editframe.Sequence.Macros[version].Actions[keyPath].spell = storedValue
                end
                editframe.Sequence.Macros[version].Actions[keyPath].action = nil
                editframe.Sequence.Macros[version].Actions[keyPath].macro = nil
                editframe.Sequence.Macros[version].Actions[keyPath].item = nil
                editframe.Sequence.Macros[version].Actions[keyPath].toy = nil
            end

            --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Macros[version])
        end
    )
    spellEditBox:SetCallback(
        "OnEditFocusLost",
        function()
        end
    )

    return spellEditBox
end

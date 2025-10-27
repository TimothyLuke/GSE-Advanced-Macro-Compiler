local GNOME, _ = ...

local GSE = GSE
local GCD

local L = GSE.L
local Statics = GSE.Static

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, spell)
    if GSE.UnsavedOptions.DebugSequenceExecution and not GSE.isEmpty(spell) then
        local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spell)
        local usableOutput, manaOutput, GCDOutput, CastingOutput
        local spellid = GSE.GetSpellId(spell, Statics.TranslatorMode.ID)
        local foundOutput, FoundInSpellBook
        if GSE.GameMode > 5 then
            if spellid then
                FoundInSpellBook = C_SpellBook.FindSpellBookSlotForSpell(spellid)
                if FoundInSpellBook > 0 then
                    foundOutput =
                        GSEOptions.CommandColour .. "(" .. spellid .. ") Found in Spell Book" .. Statics.StringReset
                else
                    foundOutput = GSEOptions.UNKNOWN .. spell .. " Not Found In Spell Book" .. Statics.StringReset
                end
            else
                foundOutput = GSEOptions.UNKNOWN .. spell .. " Not Found In Spell Book" .. Statics.StringReset
            end
        end
        if isUsable then
            usableOutput = GSEOptions.CommandColour .. "Able To Cast" .. Statics.StringReset
        else
            usableOutput = GSEOptions.UNKNOWN .. "Not Able to Cast" .. Statics.StringReset
        end
        if notEnoughMana then
            manaOutput = GSEOptions.UNKNOWN .. "Resources Not Available" .. Statics.StringReset
        else
            manaOutput = GSEOptions.CommandColour .. "Resources Available" .. Statics.StringReset
        end
        local castingspell = UnitCastingInfo("player")

        if not GSE.isEmpty(castingspell) then
            CastingOutput = GSEOptions.UNKNOWN .. "Casting " .. castingspell .. Statics.StringReset
        else
            CastingOutput = GSEOptions.CommandColour .. "Not actively casting anything else." .. Statics.StringReset
        end
        GCDOutput = GSEOptions.CommandColour .. "GCD Free" .. Statics.StringReset
        if GCD then
            GCDOutput = GSEOptions.UNKNOWN .. "GCD In Cooldown" .. Statics.StringReset
        end

        local fullBlock = ""

        GSE.PrintDebugMessage(
            table.concat(
                {
                    GSEOptions.AuthorColour,
                    button,
                    Statics.StringReset,
                    ",",
                    step,
                    ",",
                    tostring(GetServerTime()),
                    ",",
                    (spell and GSE.GetSpellId(spell, Statics.TranslatorMode.Current) or "nil"),
                    ",",
                    foundOutput and foundOutput .. "," or "",
                    usableOutput,
                    ",",
                    manaOutput,
                    ",",
                    GCDOutput,
                    ",",
                    CastingOutput,
                    C_AssistedCombat and C_Spell.GetSpellInfo(C_AssistedCombat.GetNextCastSpell()).name .. "," or "",
                    fullBlock
                }
            ),
            Statics.SequenceDebug
        )
    end
end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, action)
    if unit == "player" then
        local GCD_Timer
        if GSE.GameMode > 1 then
            if C_Spell.GetSpellCooldown then
                GCD_Timer = C_Spell.GetSpellCooldown(61304)["duration"]
            else
                ---@diagnostic disable-next-line: deprecated
                local _, gtime = GetSpellCooldown(61304)
                GCD_Timer = gtime
            end
        else
            GCD_Timer = 1.5
        end
        GCD = true
        C_Timer.After(
            GCD_Timer,
            function()
                GCD = nil
                GSE.PrintDebugMessage("GCD OFF")
            end
        )
        GSE.PrintDebugMessage("GCD Delay:" .. " " .. GCD_Timer)
        GSE.CurrentGCD = GCD_Timer

        local elements = GSE.split(action, "-")

        local foundskill = false
        if GSE.GameMode > 10 then
            local spell

            local found = C_SpellBook.FindSpellBookSlotForSpell(elements[6])
            if found then
                foundskill = true
                spell = C_Spell.GetSpellInfo(elements[6]).name
            end
            if foundskill then
                if GSE.RecorderActive then
                    GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                        GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. spell .. "\n"
                    )
                end
            end
        else
            local spellInfo = C_Spell.GetSpellInfo(elements[6])
            local spell = spellInfo and spellInfo.name
            local fskilltype = spell and GetSpellBookItemInfo(spell)
            if not GSE.isEmpty(fskilltype) then
                if GSE.RecorderActive then
                    GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                        GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n"
                    )
                end
            end
        end
    end
end

if GSE.GameMode < 12 then
    GSE:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

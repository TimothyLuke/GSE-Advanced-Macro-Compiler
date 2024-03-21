local GNOME, _ = ...

local GSE = GSE
local GCD

local L = GSE.L
local Statics = GSE.Static

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, task)
    if GSE.UnsavedOptions.DebugSequenceExecution and not GSE.isEmpty(task) then
        local spell = task
        local csindex, csitem, csspell = QueryCastSequence(task)
        if not GSE.isEmpty(csitem) then
            spell = csitem
        end
        if not GSE.isEmpty(csitem) then
            spell = csspell
        end

        local isUsable, notEnoughMana = IsUsableSpell(spell)
        local usableOutput, manaOutput, GCDOutput, CastingOutput
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
        local castingspell

        if GSE.GameMode == 1 then
            castingspell, _, _, _, _, _, _, _ = CastingInfo()
        else
            castingspell, _, _, _, _, _, _, _ = UnitCastingInfo("player")
        end
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

        if GSEOptions.showFullBlockDebug then
            fullBlock =
                "\n" ..
                GSE.SequencesExec[button][step] ..
                    GSEOptions.EmphasisColour ..
                        "\n============================================================================================\n" ..
                            Statics.StringReset
        end
        GSE.PrintDebugMessage(
            table.concat(
                {
                    GSEOptions.AuthorColour,
                    button,
                    Statics.StringReset,
                    ",",
                    step,
                    ",",
                    (spell and spell or "nil"),
                    (csindex and
                        " from castsequence " ..
                            (csspell and csspell or csitem) .. " (item " .. csindex .. " in castsequence.) " or
                        ""),
                    ",",
                    usableOutput,
                    ",",
                    manaOutput,
                    ",",
                    GCDOutput,
                    ",",
                    CastingOutput,
                    fullBlock
                }
            ),
            Statics.SequenceDebug
        )
    end
end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, action)
    -- UPDATE for GSE3
    if unit == "player" then
        local _, GCD_Timer = GetSpellCooldown(61304)
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
        local spell, _, _, _, _, _ = GetSpellInfo(elements[6])
        local fskilltype, fspellid = GetSpellBookItemInfo(spell)
        if not GSE.isEmpty(fskilltype) then
            if GSE.RecorderActive then
                GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                    GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n"
                )
            end
        end
    end
end

GSE:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

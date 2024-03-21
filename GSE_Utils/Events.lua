local GNOME, _ = ...

local GSE = GSE

local L = GSE.L
local Statics = GSE.Static

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

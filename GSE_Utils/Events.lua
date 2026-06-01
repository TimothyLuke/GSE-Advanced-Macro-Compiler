
local GSE = GSE
local Statics = GSE.Static
local GCD = nil

local SequenceDebugColumns = {
    {label = "Timestamp", width = 9, pixelWidth = 76, min = 65},
    {label = "Step", width = 4, pixelWidth = 40, min = 34},
    {label = "Block", width = 14, pixelWidth = 64, min = 42},
    {label = "Sequence", width = 18, pixelWidth = 104, min = 70},
    {label = "GCD Status", width = 16, pixelWidth = 76, min = 60},
    {label = "Action / Spellbook", width = 40, pixelWidth = 204, min = 130},
    {label = "Castable", width = 16, pixelWidth = 76, min = 60},
    {label = "Resources", width = 20, pixelWidth = 90, min = 70},
    {label = "Casting", width = 30, pixelWidth = 112, min = 75},
    {label = "Next Cast", width = 18, pixelWidth = 90, min = 70}
}
GSE.SequenceDebugColumns = SequenceDebugColumns

local function StripDebugColor(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:gsub("\r", " "):gsub("\n", " ")
end

local function ColumnText(text, width)
    local value = StripDebugColor(text)
    if width and width > 0 and string.len(value) > width then
        value = string.sub(value, 1, math.max(1, width - 1)) .. "~"
    end
    return value .. string.rep(" ", math.max(0, (width or 0) - string.len(value)))
end

function GSE.SequenceDebugColumnHeader()
    local columns = {}
    for i, column in ipairs(SequenceDebugColumns) do
        columns[i] = ColumnText(column.label, column.width)
    end
    return table.concat(columns, " | ")
end

local function SequenceDebugColumnLine(values)
    local columns = {}
    for i, column in ipairs(SequenceDebugColumns) do
        columns[i] = ColumnText(values[i], column.width)
    end
    return table.concat(columns, " | ")
end

local function CurrentDebugTimestamp()
    if date then return date("%H:%M:%S") end
    return tostring(GetServerTime and GetServerTime() or "")
end

local function ColorText(text, color)
    if not color then return tostring(text or "") end
    return color .. tostring(text or "") .. "|r"
end

local function GetSequenceDebugNameWithVersion(sequenceName)
    local cleanName = StripDebugColor(sequenceName)
    if cleanName == "" or cleanName == "nil" then return cleanName end
    if cleanName:match(":%d+$") then return cleanName end

    local version
    if GSE.GetActiveSequenceVersion then
        local ok, result = pcall(GSE.GetActiveSequenceVersion, cleanName)
        if ok and result ~= nil then version = result end
    end

    if version == nil then
        local classid = GSE.GetCurrentClassID and GSE.GetCurrentClassID()
        local sequence = classid and GSE.Library and GSE.Library[classid] and GSE.Library[classid][cleanName]
        if not sequence and GSE.Library and GSE.Library[0] then sequence = GSE.Library[0][cleanName] end
        local metadata = type(sequence) == "table" and sequence.MetaData
        if type(metadata) == "table" and metadata.Default ~= nil then version = metadata.Default end
    end

    if version ~= nil and tostring(version) ~= "" then
        return cleanName .. ":" .. tostring(version)
    end

    return cleanName
end

--- This function is used to debug a sequence and trace its execution.
function GSE.TraceSequence(button, step, spell, blockPath)
    if GSE.UnsavedOptions.DebugSequenceExecution then
        if GSE.isEmpty(spell) then
            spell = "No spell resolved"
        end
        local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spell)
        local usableOutput, manaOutput, GCDOutput, CastingOutput
        local spellid = GSE.GetSpellId(spell, Statics.TranslatorMode.ID)
        local foundOutput, FoundInSpellBook
        if GSE.GameMode > 5 then
            if spellid then
                FoundInSpellBook = C_SpellBook.FindSpellBookSlotForSpell(spellid)
                if FoundInSpellBook and FoundInSpellBook > 0 then
                    foundOutput = "(" .. spellid .. ") Found in Spell Book"
                else
                    foundOutput = spell .. " Not Found In Spell Book"
                end
            else
                foundOutput = spell .. " Not Found In Spell Book"
            end
        end
        if isUsable then
            usableOutput = "Able To Cast"
        else
            usableOutput = "Not Able to Cast"
        end
        if notEnoughMana then
            manaOutput = "Resources Not Available"
        else
            manaOutput = "Resources Available"
        end
        local castingspell = UnitCastingInfo("player")

        if not GSE.isEmpty(castingspell) then
            CastingOutput = "Casting " .. castingspell
        else
            CastingOutput = "Not actively casting anything else."
        end
        GCDOutput = "GCD Free"
        if GCD then
            GCDOutput = "GCD In Cooldown"
        end

        local nextCastSpell = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell and C_AssistedCombat.GetNextCastSpell()
        local nextCastInfo = nextCastSpell and GSE.GetSpellInfo(nextCastSpell)
        local nextCastName = nextCastInfo and nextCastInfo.name or ""
        local actionOutput = ColorText(spell and (GSE.GetSpellId(spell, Statics.TranslatorMode.Current) or spell) or "nil", "|cFFFFF569")
        local spellbookColor = FoundInSpellBook and "|cFF00FF00" or "|cFFFF5555"
        if not GSE.isEmpty(foundOutput) then actionOutput = actionOutput .. ColorText(" - " .. foundOutput, spellbookColor) end
        local usableColor = isUsable and "|cFF00FF00" or "|cFFFF5555"
        local manaColor = notEnoughMana and "|cFFFF5555" or "|cFF00FF00"
        local gcdColor = GCD and "|cFFFFAA00" or "|cFF00FF00"
        local castingColor = GSE.isEmpty(castingspell) and "|cFFAAAAAA" or "|cFF00D1FF"
        local serverTimestamp = tostring(GetServerTime and GetServerTime() or CurrentDebugTimestamp())
        local sequenceOutput = GetSequenceDebugNameWithVersion(button)
        local legacyExportLine = table.concat(
            {
                sequenceOutput,
                StripDebugColor(step),
                serverTimestamp,
                StripDebugColor(spell and (GSE.GetSpellId(spell, Statics.TranslatorMode.Current) or spell) or "nil"),
                StripDebugColor(foundOutput or ""),
                StripDebugColor(usableOutput),
                StripDebugColor(manaOutput),
                StripDebugColor(GCDOutput),
                StripDebugColor(CastingOutput),
                StripDebugColor(nextCastName),
                blockPath and ("block:" .. StripDebugColor(blockPath)) or ""
            },
            ","
        )

        local row = {
            ColorText(CurrentDebugTimestamp(), "|cFFAAAAAA"),
            ColorText(step, "|cFFFFFFFF"),
            ColorText(tostring(blockPath or "none"), "|cFFFFD100"),
            ColorText(sequenceOutput, "|cFF00D1FF"),
            ColorText(GCDOutput, gcdColor),
            actionOutput,
            ColorText(usableOutput, usableColor),
            ColorText(manaOutput, manaColor),
            ColorText(CastingOutput, castingColor),
            ColorText(nextCastName, "|cFFFFD100")
        }

        local canAppendToDebugger =
            type(GSE.GUIDebugAppendEvent) == "function" and type(GSE.GUIDebugIsOpenOrMinimized) == "function" and
            GSE.GUIDebugIsOpenOrMinimized() and not GSE.GUIDebugPaused
        if canAppendToDebugger then
            GSE.GUIDebugAppendEvent(row, legacyExportLine)
        else
            GSE.PrintDebugMessage(SequenceDebugColumnLine(row), Statics.SequenceDebug)
        end
    end
end

function GSE:UNIT_SPELLCAST_SUCCEEDED(event, unit, action, sped)
    if unit == "player" then
        -- Bail out quietly if GSE core did not finish initialising (e.g. the
        -- main GSE addon aborted before GSE.split / GSE.GameMode were defined).
        -- Without this the handler errors on every successful cast in combat
        -- (the reported "Events.lua:186: attempt to call a nil value").
        if type(GSE.split) ~= "function" or GSE.GameMode == nil then
            return
        end
        local GCD_Timer
        local elements = GSE.split(action, "-")
        local successfulSpellID = tonumber(elements and elements[6]) or tonumber(sped) or (elements and elements[6]) or sped
        local successfulSpellName
        if GSE.GameMode > 1 then
            if GSE.GameMode > 11 then
                local spellid = elements[6]
                local cooldownInfo = GSE.GetSpellCooldown(spellid)
                local potentialGCD = cooldownInfo and cooldownInfo.duration or GSE.GetGCD()
                if issecretvalue(potentialGCD)then
                    GCD_Timer = GSE.GetGCD()
                else
                    GCD_Timer = potentialGCD
                end
            else
                GCD_Timer = GSE.GetGCD()
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

        local foundskill = false
        if GSE.GameMode > 10 then
            local spell

            local found = C_SpellBook.FindSpellBookSlotForSpell(elements[6])
            if found then
                foundskill = true
                local spellInfo = GSE.GetSpellInfo(elements[6])
                spell = spellInfo and spellInfo.name
                successfulSpellName = spell
            end
            if foundskill then
                if GSE.RecorderActive then
                    GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                        GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. spell .. "\n"
                    )
                end
            end
        else
            local spellInfo = GSE.GetSpellInfo(elements[6])
            local spell = spellInfo and spellInfo.name
            successfulSpellName = spell
            local fskilltype = spell and GetSpellBookItemInfo(spell)
            if not GSE.isEmpty(fskilltype) then
                if GSE.RecorderActive then
                    GSE.GUIRecordFrame.RecordSequenceBox:SetText(
                        GSE.GUIRecordFrame.RecordSequenceBox:GetText() .. "/cast " .. spell .. "\n"
                    )
                end
            end
        end
        if GSE.GUIDebugMarkSuccessfulCast then
            GSE.GUIDebugMarkSuccessfulCast(successfulSpellID, successfulSpellName)
        end
    end
end
GSE:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

local GSE2 = GSE2
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local LibQTip = LibStub("LibQTip-1.0")

function GSE2.GUILoadEditor(key, incomingframe, incomingSequence)
    local classid
    local sequenceName
    local sequence
    if GSE.isEmpty(key) then
        classid = GSE.GetCurrentClassID()
        sequenceName = "NEW_SEQUENCE"
        sequence = {
            ["Author"] = GSE.GetCharacterName(),
            ["Talents"] = GSE.GetCurrentTalents(),
            ["Default"] = 1,
            ["SpecID"] = GSE.GetCurrentSpecID(),
            ["MacroVersions"] = {
                [1] = {
                    ["PreMacro"] = {},
                    ["PostMacro"] = {},
                    ["KeyPress"] = {},
                    ["KeyRelease"] = {},
                    ["StepFunction"] = "Sequential",
                    [1] = "/say Hello"
                }
            }
        }
        GSE2.GUIEditFrame.NewSequence = true
    else
        sequenceName = key
        sequence = GSE.CloneSequence(incomingSequence, true)
        GSE2.GUIEditFrame.NewSequence = false
    end
    if GSE.isEmpty(sequence.WeakAuras) then
        sequence.WeakAuras = {}
    end
    GSE2.GUIEditFrame:SetStatusText("GSE: " .. GSE.VersionString)
    GSE2.GUIEditFrame.SequenceName = sequenceName
    GSE2.GUIEditFrame.Sequence = sequence
    GSE2.GUIEditFrame.ClassID = classid
    GSE2.GUIEditFrame.Default = sequence.Default
    GSE2.GUIEditFrame.PVP = sequence.PVP or sequence.Default
    GSE2.GUIEditFrame.Mythic = sequence.Mythic or sequence.Default
    GSE2.GUIEditFrame.Raid = sequence.Raid or sequence.Default
    GSE2.GUIEditFrame.Dungeon = sequence.Dungeon or sequence.Default
    GSE2.GUIEditFrame.Heroic = sequence.Heroic or sequence.Default
    GSE2.GUIEditFrame.Party = sequence.Party or sequence.Default
    GSE2.GUIEditFrame.Timewalking = sequence.Timewalking or sequence.Default
    GSE2.GUIEditFrame.MythicPlus = sequence.MythicPlus or sequence.Default
    GSE2.GUIEditFrame.Arena = sequence.Arena or sequence.Default
    GSE2.GUIEditFrame.Scenario = sequence.Scenario or sequence.Default
    GSE2.GUIEditorPerformLayout(GSE2.GUIEditFrame)
    GSE2.GUIEditFrame.ContentContainer:SelectTab("config")
    GSE2.GUIEditFrame.tempVariables = {}
    if not GSE.isEmpty(sequence.Variables) then
        for k, value in pairs(sequence.Variables) do
            local pair = {}
            pair.key = k
            pair.value = value
            table.insert(GSE2.GUIEditFrame.tempVariables, pair)
        end
    end
    if incomingframe then
        incomingframe:Hide()
    end
    if sequence.ReadOnly then
        GSE2.GUIEditFrame.SaveButton:SetDisabled(true)
        GSE2.GUIEditFrame:SetStatusText(
            "GSE: " .. GSE.VersionString .. " " .. L["This sequence is Read Only and unable to be edited."]
        )
    end
    GSE2.GUIEditFrame:Show()
end

function GSE2.GUIUpdateSequenceDefinition(classid, SequenceName, sequence)
    sequence.LastUpdated = GSE.GetTimestamp()
    -- Changes have been made, so save them
    for k, v in ipairs(sequence.MacroVersions) do
        sequence.MacroVersions[k] = GSE.TranslateSequence(v, SequenceName, "ID")
        sequence.MacroVersions[k] = GSE.UnEscapeSequence(sequence.MacroVersions[k])
        for i, j in ipairs(v) do
            GSE.enforceMinimumVersion(sequence, j)
        end
    end

    if not GSE.isEmpty(SequenceName) then
        if GSE.isEmpty(classid) then
            classid = GSE.GetCurrentClassID()
        end
        if not GSE.isEmpty(SequenceName) then
            local vals = {}
            vals.action = "Replace"
            vals.sequencename = SequenceName
            vals.sequence = sequence
            vals.classid = classid
            if GSE2.GUIEditFrame.NewSequence then
                if GSE.ObjectExists(SequenceName) then
                    GSE2.GUIEditFrame:SetStatusText(
                        string.format(L["Sequence Name %s is in Use. Please choose a different name."], SequenceName)
                    )
                    GSE2.GUIEditFrame.nameeditbox:SetText(
                        GSEOptions.UNKNOWN .. GSE.GUIEditFrame.nameeditbox:GetText() .. Statics.StringReset
                    )
                    GSE2.GUIEditFrame.nameeditbox:SetFocus()
                    return
                end
                vals.checkmacro = true
                GSE2.GUIEditFrame.NewSequence = false
            end
            table.insert(GSE.OOCQueue, vals)
            GSE2.GUIEditFrame:SetStatusText(string.format(L["Sequence %s saved."], SequenceName))
        end
    end
end

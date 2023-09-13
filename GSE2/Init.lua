GSE2 = LibStub("AceAddon-3.0"):NewAddon("GSE2", "AceConsole-3.0")
local GSE = GSE
local Statics = GSE.Static

local function fixLine(line, KeyPress, KeyRelease)
    local action = {}
    action["Type"] = Statics.Actions.Action
    if KeyPress then
        -- print("KeyPress false")
        table.insert(action, [[~~KeyPress~~]])
    end
    table.insert(action, line)
    if KeyRelease then
        -- print("KeyRelease false")
        table.insert(action, [[~~KeyRelease~~]])
    end

    if string.sub(line, 1, 12) == "/click pause" then
        action = {}
        action["Type"] = Statics.Actions.Pause
        if string.sub(line, 14) == "~~GCD~~" then
            action["MS"] = GSE.GetGCD() * 1000
        else
            local mynumber = tonumber(string.sub(line, 14))

            if GSE.isEmpty(mynumber) then
                action["MS"] = 10
                GSE.Print(L["Error processing Custom Pause Value.  You will need to recheck your macros."], "Storage")
            else
                action["MS"] = tonumber(string.sub(line, 14)) * 1000
            end
        end
    end
    return action
end

function GSE.ConvertGSE2(sequence, sequenceName)
    local returnSequence = {}
    returnSequence["MetaData"] = {}
    returnSequence["MetaData"]["Name"] = sequenceName
    returnSequence["MetaData"]["ClassID"] = Statics.SpecIDClassList[sequence.SpecID]
    for k, v in pairs(sequence) do
        if k ~= "MacroVersions" then
            returnSequence["MetaData"][k] = v
        end
    end
    local MacroVersions = {}
    for _, v in ipairs(sequence.MacroVersions) do
        local gse3seq = {}
        gse3seq.Actions = {}
        gse3seq.Variables = {}

        if GSE.isEmpty(v.KeyPress) then
            v.KeyPress = {}
        end
        if GSE.isEmpty(v.KeyRelease) then
            v.KeyRelease = {}
        end
        if GSE.isEmpty(v.PreMacro) then
            v.PreMacro = {}
        end
        if GSE.isEmpty(v.PostMacro) then
            v.PostMacro = {}
        end
        local KeyPress = table.getn(v.KeyPress) > 0
        local KeyRelease = table.getn(v.KeyRelease) > 0

        if KeyPress then
            gse3seq.Variables["KeyPress"] = v.KeyPress
        end
        if KeyRelease then
            gse3seq.Variables["KeyRelease"] = v.KeyRelease
        end
        if table.getn(v.PreMacro) > 0 then
            for _, j in ipairs(v.PreMacro) do
                local action = fixLine(j, KeyPress, KeyRelease)
                table.insert(gse3seq.Actions, action)
            end
        end

        local sequenceactions = {}
        for _, j in ipairs(v) do
            local action = fixLine(j, KeyPress, KeyRelease)
            table.insert(sequenceactions, action)
        end
        if GSE.isEmpty(v.LoopLimit) then
            for _, j in ipairs(sequenceactions) do
                table.insert(gse3seq.Actions, j)
            end
        else
            local loop = {}
            for _, j in ipairs(sequenceactions) do
                table.insert(loop, j)
            end
            loop["Type"] = Statics.Actions.Loop
            loop["StepFunction"] = v.StepFunction
            loop["Repeat"] = v.LoopLimit
            table.insert(gse3seq.Actions, loop)
        end

        if table.getn(v.PostMacro) > 0 then
            for _, j in ipairs(v.PostMacro) do
                local action = fixLine(j, KeyPress, KeyRelease)
                table.insert(gse3seq.Actions, action)
            end
        end

        gse3seq.InbuiltVariables = {}

        local function checkParameter(param)
            gse3seq.InbuiltVariables[param] = v[param]
        end

        checkParameter("Combat")
        checkParameter("Ring1")
        checkParameter("Ring2")
        checkParameter("Trinket1")
        checkParameter("Trinket2")
        checkParameter("Neck")
        checkParameter("Head")
        checkParameter("Belt")

        table.insert(MacroVersions, gse3seq)
    end
    returnSequence["Macros"] = MacroVersions
    returnSequence["MetaData"]["Variables"] = nil
    if GSE.isEmpty(sequence["WeakAuras"]) then
        sequence["WeakAuras"] = {}
    end
    returnSequence["WeakAuras"] = sequence["WeakAuras"]
    return returnSequence
end

local GSE = GSE
local Statics = GSE.Static

local L = GSE.L

local function ProcessLegacyVariables(lines, variableTable)
    local returnLines = {}
    for _, line in ipairs(lines) do
        if line ~= "/click GSE.Pause" then
            if not GSE.isEmpty(variableTable) then
                for key, value in pairs(variableTable) do
                    if type(value) == "string" then
                        local functline = value
                        if string.sub(functline, 1, 10) == "function()" then
                            GSE.UpdateVariable(value, key)
                            value = '=GSE.V["' .. key '"]()'
                        end
                    end
                    if type(value) == "boolean" then
                        value = tostring(value)
                    end
                    if value == nil then
                        value = ""
                    end
                    if type(value) == "table" then
                        value = GSE.SafeConcat(value, "\n")
                    end

                    line = string.gsub(line, string.format("~~%s~~", key), value)
                end
            end
        end
        table.insert(returnLines, line)
    end
    return GSE.SafeConcat(returnLines, "\n")
end

local function buildAction(action, variables)
    if action.Type == Statics.Actions.Loop then
        -- we have a loop within a loop
        return GSE.processAction(action, variables)
    else
        action.type = "macro"
        local macro = ProcessLegacyVariables(action, variables)

        action.macro = macro
        action.target = " "
        return action
    end
end

local function processAction(action, variables)
    if action.Type == Statics.Actions.Loop then
        local actionList = {}
        -- setup the interation
        for _, v in ipairs(action) do
            local builtaction = processAction(v, variables)
            table.insert(actionList, builtaction)
        end
        -- process repeats for the block
        for k, v in ipairs(actionList) do
            action[k] = v
        end
        return action
    elseif action.Type == Statics.Actions.Pause then
        return action
    elseif action.Type == Statics.Actions.If then
        local actionList = {}
        for _, v in ipairs(action) do
            table.insert(processAction(v, variables))
        end

        -- process repeats for the block
        for k, v in ipairs(actionList) do
            action[k] = v
        end
        return action
    else
        local builtstuff = buildAction(action, variables)
        for k, _ in ipairs(action) do
            action[k] = nil
        end

        return builtstuff
    end
end
if GSE.isEmpty(GSE.Update31Actions) then
    GSE.Update31Actions = function(sequence)
        local seq = GSE.CloneSequence(sequence)
        for k, _ in ipairs(seq.Macros) do
            setmetatable(seq.Macros[k].Actions, Statics.TableMetadataFunction)
            local actiontable = {}
            for _, j in ipairs(seq.Macros[k].Actions) do
                local processed = processAction(j, seq.Macros[k].Variables)
                table.insert(actiontable, processed)
            end
            seq.Macros[k].Actions = actiontable
            seq.Macros[k].Variables = nil
            seq.Macros[k].InbuiltVariables = nil
        end
        seq.MetaData.Version = 3200
        seq.WeakAuras = nil
        return seq
    end
end

function GSE.PerformOneOffEvents()
    if GSE.isEmpty(GSEOptions.msClickRate) then
        GSEOptions.msClickRate = 250
    end

    --if GSE.isEmpty(GSESequences) then
    GSESequences = {
        [0] = {},
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {},
        [5] = {},
        [6] = {},
        [7] = {},
        [8] = {},
        [9] = {},
        [10] = {},
        [11] = {},
        [12] = {},
        [13] = {}
    }
    --end

    if GSE.isEmpty(GSEOptions.Updates) then
        GSEOptions.Updates = {}
    end

    if GSE.isEmpty(GSEOptions.Updates["3200"]) then
        for i, j in ipairs(GSE3Storage) do
            for k, v in pairs(j) do
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(v)
                if
                    localsuccess and uncompressedVersion[2].MetaData.GSEVersion and
                        tonumber(uncompressedVersion[2].MetaData.GSEVersion) < 3200
                 then
                    local updatedseq = GSE.Update31Actions(uncompressedVersion[2])
                    GSE.AddSequenceToCollection(k, updatedseq)
                else
                    GSESequences[i][k] = v
                end
            end
        end
        for k, v in pairs(GSE3Storage[0]) do
            local localsuccess, uncompressedVersion = GSE.DecodeMessage(v)
            if localsuccess then
                if
                    uncompressedVersion[2].MetaData.GSEVersion and
                        tonumber(uncompressedVersion[2].MetaData.GSEVersion) < 3200
                 then
                    local updatedseq = GSE.Update31Actions(uncompressedVersion[2])
                    GSE.AddSequenceToCollection(k, updatedseq)
                else
                    GSESequences[0][k] = v
                end
            else
                print("decom error")
            end
        end
        GSE3Storage = nil
        GSEOptions.Updates["3200"] = true
    end
end

GSE.DebugProfile("OneOffEvents")

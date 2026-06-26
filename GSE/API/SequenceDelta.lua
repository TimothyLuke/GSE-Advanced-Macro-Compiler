local _, GSE = ...


local floor = math.floor
local sort = table.sort

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = deepcopy(val) end
    return out
end

local function intKeysSorted(t)
    local keys = {}
    for k in pairs(t) do
        if type(k) == "number" and k >= 1 and floor(k) == k then keys[#keys + 1] = k end
    end
    sort(keys)
    return keys
end

local function listOf(t)
    if type(t) ~= "table" then return {} end
    local out = {}
    for _, k in ipairs(intKeysSorted(t)) do out[#out + 1] = t[k] end
    return out
end

local function loopChildren(block)
    if type(block) ~= "table" then return {} end
    return listOf(block)
end

local function ifBranch(block, n)
    local b = (type(block) == "table") and (block[n] or block[tostring(n)]) or nil
    return listOf(b or {})
end

local function clearIntKeys(block)
    for _, k in ipairs(intKeysSorted(block)) do block[k] = nil end
end

local function applyActionList(baseBlocks, overlay)
    local out = {}
    for i = 1, #overlay do
        local el = overlay[i]
        if el["new"] ~= nil then
            out[i] = deepcopy(el["new"])
        else
            local bb = baseBlocks[(el.from or 0) + 1]
            local blk = deepcopy(bb) or {}
            if el.set then for f, v in pairs(el.set) do blk[f] = deepcopy(v) end end
            if el.unset then for _, f in ipairs(el.unset) do blk[f] = nil end end
            if el.children then
                local kids = applyActionList(loopChildren(bb), el.children)
                clearIntKeys(blk)
                for ci = 1, #kids do blk[ci] = kids[ci] end
            end
            if el.branch1 then blk[1] = applyActionList(ifBranch(bb, 1), el.branch1) end
            if el.branch2 then blk[2] = applyActionList(ifBranch(bb, 2), el.branch2) end
            out[i] = blk
        end
    end
    return out
end

function GSE.ApplyDelta(base, delta)
    local out = deepcopy(base or {})
    delta = delta or {}

    if type(delta.versions) == "table" then
        out.Versions = out.Versions or {}
        for k, op in pairs(delta.versions) do
            local vk = tonumber(k) or k
            if op.op == "remove" then
                out.Versions[vk] = nil
            elseif op.op == "add" then
                out.Versions[vk] = deepcopy(op.value)
            else
                local v = out.Versions[vk] or { Actions = {} }
                if op.actions ~= nil then
                    v.Actions = applyActionList(listOf(v.Actions), op.actions)
                end
                if op.inbuiltVariables ~= nil then
                    v.InbuiltVariables = deepcopy(op.inbuiltVariables)
                end
                out.Versions[vk] = v
            end
        end
    end

    if type(delta.top) == "table" then
        for f, val in pairs(delta.top) do out[f] = deepcopy(val) end
    end
    if type(delta.topUnset) == "table" then
        for _, f in ipairs(delta.topUnset) do out[f] = nil end
    end

    return out
end

GSE.ApplySequenceDelta = GSE.ApplyDelta

function GSE.DecodeDelta(b64)
    if type(b64) ~= "string" or b64 == "" then return nil end
    local ok, result = pcall(function()
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecodeBase64(b64))
    end)
    if ok and type(result) == "table" then return result end
    return nil
end

function GSE.ReconstructDeltaFork(entry)
    if type(entry) ~= "table" or type(entry.b) ~= "string" then return nil end
    local ok, decoded = GSE.DecodeMessage(entry.b)
    if not ok or type(decoded) ~= "table" then return nil end
    -- Sequences encode as { name, object }; variables/macros encode as the bare
    -- node. decoded[2] picks the sequence object; the fallback handles nodes.
    local base = decoded[2] or decoded
    local delta = GSE.DecodeDelta(entry.d)
    if type(delta) ~= "table" then return base end -- empty delta → base unchanged
    return GSE.ApplyDelta(base, delta)
end

local function installReconstructed(t, obj)
    if type(obj) ~= "table" then return end
    local meta = obj.MetaData or {}
    local nm = obj.name or meta.Name
    if not nm then return end
    if t == "sequence" then
        local classid = (GSE.GetClassIDforSpec and GSE.GetClassIDforSpec(meta.SpecID)) or 0
        if type(GSE.Library[classid]) ~= "table" then GSE.Library[classid] = {} end
        GSE.Library[classid][nm] = obj
    elseif t == "variable" and GSE.V then
        GSE.V[nm] = obj
    elseif t == "macro" and type(GSEMacros) == "table" then
        GSEMacros[nm] = obj
    end
end

function GSE.LoadDeltaForks()
    if type(GSEDeltas) ~= "table" then return end
    for _, entry in pairs(GSEDeltas) do
        if type(entry) == "table" then
            installReconstructed(entry.t or "sequence", GSE.ReconstructDeltaFork(entry))
        end
    end
end

function GSE.StoreDeltaFork(element)
    if type(element) ~= "table" or not element.GSEDeltaFork then return false end
    local pid = element.platformId
    if type(pid) ~= "string" or pid == "" then return false end
    if type(GSEDeltas) ~= "table" then GSEDeltas = {} end
    local entry = { b = element.base, d = element.delta, t = element.contentType or "sequence" }
    GSEDeltas[pid] = entry
    installReconstructed(entry.t, GSE.ReconstructDeltaFork(entry))
    return true
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("SequenceDelta") end

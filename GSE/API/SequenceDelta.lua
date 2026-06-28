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
                if op.set then for f, val in pairs(op.set) do v[f] = deepcopy(val) end end
                if op.unset then for _, f in ipairs(op.unset) do v[f] = nil end end
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


local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function fingerprint(block)
    if type(block) ~= "table" then return "" end
    local t = block.Type or block.type or ""
    if t == "Loop" or t == "If" then return t .. "|" end
    local s = block.macro or block.macrotext or block.Variable or block.Sequence or ""
    return t .. "|" .. string.sub(tostring(s), 1, 255)
end

local function matchBlocks(baseBlocks, targetBlocks)
    local map, usedBase = {}, {}
    for ti = 1, #targetBlocks do
        if baseBlocks[ti] and not usedBase[ti] and fingerprint(baseBlocks[ti]) == fingerprint(targetBlocks[ti]) then
            map[ti] = ti; usedBase[ti] = true
        end
    end
    for ti = 1, #targetBlocks do
        if not map[ti] then
            local tfp = fingerprint(targetBlocks[ti])
            for bi = 1, #baseBlocks do
                if not usedBase[bi] and fingerprint(baseBlocks[bi]) == tfp then map[ti] = bi; usedBase[bi] = true; break end
            end
        end
    end
    for ti = 1, #targetBlocks do
        if not map[ti] then
            local tt = targetBlocks[ti].Type or targetBlocks[ti].type or ""
            for bi = 1, #baseBlocks do
                if not usedBase[bi] then
                    local bt = baseBlocks[bi].Type or baseBlocks[bi].type or ""
                    if bt == tt then map[ti] = bi; usedBase[bi] = true; break end
                end
            end
        end
    end
    return map
end

local function diffFields(baseB, targetB)
    local set, unset, seen = {}, {}, {}
    for f, v in pairs(targetB) do
        if type(f) ~= "number" then
            seen[f] = true
            if baseB[f] == nil or not deepEqual(baseB[f], v) then set[f] = deepcopy(v) end
        end
    end
    for f in pairs(baseB) do
        if type(f) ~= "number" and not seen[f] then unset[#unset + 1] = f end
    end
    return set, unset
end

local diffActionList
diffActionList = function(baseBlocks, targetBlocks, depth)
    depth = depth or 0
    local map = matchBlocks(baseBlocks, targetBlocks)
    local trivial = (#targetBlocks == #baseBlocks)
    local overlay = {}
    for ti = 1, #targetBlocks do
        local tb = targetBlocks[ti]
        local bi = map[ti]
        if not bi then
            trivial = false
            overlay[ti] = { ["new"] = deepcopy(tb) }
        else
            if bi ~= ti then trivial = false end
            local bb = baseBlocks[bi]
            local el = { from = bi - 1 } -- 0-based for the delta format
            local set, unset = diffFields(bb, tb)
            if next(set) ~= nil then el.set = set; trivial = false end
            if #unset > 0 then el.unset = unset; trivial = false end
            local tt = tb.Type or tb.type or ""
            local bt = bb.Type or bb.type or ""
            if depth < 5 and (tt == "Loop" or bt == "Loop") then
                local cd = diffActionList(loopChildren(bb), loopChildren(tb), depth + 1)
                if cd then el.children = cd; trivial = false end
            end
            if depth < 5 and (tt == "If" or bt == "If") then
                local d1 = diffActionList(ifBranch(bb, 1), ifBranch(tb, 1), depth + 1)
                local d2 = diffActionList(ifBranch(bb, 2), ifBranch(tb, 2), depth + 1)
                if d1 then el.branch1 = d1; trivial = false end
                if d2 then el.branch2 = d2; trivial = false end
            end
            overlay[ti] = el
        end
    end
    if trivial then return nil end
    return overlay
end

function GSE.DiffDelta(base, target)
    base = base or {}
    target = target or {}
    local delta = { v = 1 }

    if type(base.Versions) == "table" or type(target.Versions) == "table" then
        local bV = base.Versions or {}
        local tV = target.Versions or {}
        local versions, allKeys = {}, {}
        for k in pairs(bV) do allKeys[k] = true end
        for k in pairs(tV) do allKeys[k] = true end
        for k in pairs(allKeys) do
            local b, t = bV[k], tV[k]
            if b and not t then
                versions[k] = { op = "remove" }
            elseif not b and t then
                versions[k] = { op = "add", value = deepcopy(t) }
            else
                local vd = {}
                local actions = diffActionList(listOf(b.Actions), listOf(t.Actions), 0)
                if actions then vd.actions = actions end
                if not deepEqual(b.InbuiltVariables or {}, t.InbuiltVariables or {}) then
                    vd.inbuiltVariables = deepcopy(t.InbuiltVariables or {})
                end
                -- generic diff of the version's other fields (Label, StepFunction, …)
                local vset, vunset, vseen = {}, {}, {}
                for f, val in pairs(t) do
                    if f ~= "Actions" and f ~= "InbuiltVariables" then
                        vseen[f] = true
                        if b[f] == nil or not deepEqual(b[f], val) then vset[f] = deepcopy(val) end
                    end
                end
                for f in pairs(b) do
                    if f ~= "Actions" and f ~= "InbuiltVariables" and not vseen[f] then vunset[#vunset + 1] = f end
                end
                if next(vset) ~= nil then vd.set = vset end
                if #vunset > 0 then vd.unset = vunset end
                if next(vd) ~= nil then versions[k] = vd end
            end
        end
        if next(versions) ~= nil then delta.versions = versions end
    end

    local top, topUnset, seen = {}, {}, {}
    for f, v in pairs(target) do
        if f ~= "Versions" then
            seen[f] = true
            if base[f] == nil or not deepEqual(base[f], v) then top[f] = deepcopy(v) end
        end
    end
    for f in pairs(base) do
        if f ~= "Versions" and not seen[f] then topUnset[#topUnset + 1] = f end
    end
    if next(top) ~= nil then delta.top = top end
    if #topUnset > 0 then delta.topUnset = topUnset end

    return delta
end

function GSE.EncodeDelta(delta)
    if type(delta) ~= "table" then return nil end
    local ok, result = pcall(function()
        return C_EncodingUtil.EncodeBase64(C_EncodingUtil.SerializeCBOR(delta))
    end)
    if ok and type(result) == "string" then return result end
    return nil
end

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

local function installReconstructed(t, obj, pid)
    if type(obj) ~= "table" then return end
    if pid then
        obj.MetaData = obj.MetaData or {}
        obj.MetaData.PlatformID = pid
    end
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
    for pid, entry in pairs(GSEDeltas) do
        if type(entry) == "table" then
            installReconstructed(entry.t or "sequence", GSE.ReconstructDeltaFork(entry), pid)
        end
    end
end

function GSE.StoreDeltaFork(element)
    if type(element) ~= "table" or not element.GSEDeltaFork then return false end
    local pid = element.platformId
    if type(pid) ~= "string" or pid == "" then return false end
    if type(GSEDeltas) ~= "table" then GSEDeltas = {} end
    -- src = the upstream (original) platformId, so the delta is self-describing:
    -- the Mod reconstructs from `b`, the website/server resolve `src` and apply.
    local entry = { b = element.base, d = element.delta, t = element.contentType or "sequence", src = element.upstreamId }
    GSEDeltas[pid] = entry
    installReconstructed(entry.t, GSE.ReconstructDeltaFork(entry), pid)
    return true
end

function GSE.UpdateDeltaFork(obj)
    if type(GSEDeltas) ~= "table" or type(obj) ~= "table" then return false end
    local meta = obj.MetaData or {}
    local pid = meta.PlatformID or obj.PlatformID
    if type(pid) ~= "string" or type(GSEDeltas[pid]) ~= "table" then return false end
    local entry = GSEDeltas[pid]
    local ok, decoded = GSE.DecodeMessage(entry.b)
    if not ok or type(decoded) ~= "table" then return false end
    local base = decoded[2] or decoded
    local d = GSE.EncodeDelta(GSE.DiffDelta(base, obj))
    if type(d) ~= "string" then return false end
    entry.d = d
    GSEDeltas[pid] = entry
    return true
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("SequenceDelta") end

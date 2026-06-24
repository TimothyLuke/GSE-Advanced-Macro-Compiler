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

function GSE.ApplySequenceDelta(base, delta)
    local out = deepcopy(base or {})
    delta = delta or {}
    out.Versions = out.Versions or {}

    if type(delta.versions) == "table" then
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

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("SequenceDelta") end

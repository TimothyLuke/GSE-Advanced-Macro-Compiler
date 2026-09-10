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

--- Reconstruct `obj` from its stored delta fork, or nil when it has none.
--
-- The stored blob is only ever the STARTING POINT for content that has been
-- edited locally; GSEDeltas holds the divergence. A load path that assigned
-- the decoded blob straight into the Library would silently discard the edit,
-- so every load path asks this first and prefers what it returns.
function GSE.ApplyStoredDeltaFork(obj, storedBlob)
    if type(GSEDeltas) ~= "table" or type(obj) ~= "table" then return nil end
    local meta = obj.MetaData or {}
    local pid = meta.PlatformID or obj.PlatformID
    if type(pid) ~= "string" or type(GSEDeltas[pid]) ~= "table" then return nil end
    -- The fork describes the divergence from ONE base. If the caller says what
    -- is on disk now and it is not that base, the author has published a new
    -- version since the fork was taken.
    --
    -- Do NOT merge it here. This runs from the load paths -- loadOneClass and
    -- EnsureSequenceLoaded -- where there is no one to ask, and a player who
    -- logs in mid-pull would have the sequence they are holding change shape
    -- under them. Being one version behind is recoverable; that is not.
    --
    -- So park the new blob and keep serving what they had. Nothing is lost:
    -- `b` still holds the base this fork was cut from, so the reconstruction
    -- below is exactly the sequence they were running before the update
    -- landed. GSE.RebaseDeltaFork merges it, and only when the user says so.
    if storedBlob ~= nil and GSEDeltas[pid].b ~= storedBlob then
        GSEDeltas[pid].pending = storedBlob
    elseif storedBlob ~= nil then
        -- Back in step (the update was accepted, or the record was reverted).
        GSEDeltas[pid].pending = nil
    end
    return GSE.ReconstructDeltaFork(GSEDeltas[pid])
end

--- The update waiting on this fork, or nil. The editor asks; nothing else does.
function GSE.PendingDeltaUpdate(pid)
    if type(GSEDeltas) ~= "table" or type(pid) ~= "string" then return nil end
    local entry = GSEDeltas[pid]
    return type(entry) == "table" and entry.pending or nil
end

-- A plain record -- MetaData, InbuiltVariables -- as opposed to a list of
-- blocks. Records merge field by field; lists are merged by mergeActionList or
-- taken whole, because a positional compare of two lists says nothing useful.
local function isRecord(t)
    return type(t) == "table" and t[1] == nil
end

-- Three-way field merge for one block. `old` is the base both sides started
-- from, so "changed" is answerable per field instead of guessed.
-- `skip` names the fields merged elsewhere -- Versions at the top, Actions
-- within a version. Without it they are compared here as ordinary values, and
-- since a list is never a record, every one of them lands as a conflict before
-- the real merge overwrites it.
local mergeFields
mergeFields = function(old, ours, theirs, path, conflicts, skip)
    local out, seen = {}, {}
    for _, t in ipairs({old, ours, theirs}) do
        for f in pairs(t) do
            if type(f) ~= "number" and not (skip and skip[f]) then seen[f] = true end
        end
    end
    for f in pairs(seen) do
        local o, a, b = old[f], ours[f], theirs[f]
        if deepEqual(a, b) then out[f] = deepcopy(a)
        elseif deepEqual(a, o) then out[f] = deepcopy(b)   -- only they moved
        elseif deepEqual(b, o) then out[f] = deepcopy(a)   -- only we moved
        elseif isRecord(a) and isRecord(b) and (o == nil or isRecord(o)) then
            -- Both moved, but this is a record: recurse, or a note the author
            -- changed would conflict with an unrelated field the user changed
            -- and take the whole of MetaData with it.
            out[f] = mergeFields(o or {}, a, b, path .. "/" .. tostring(f), conflicts)
        else
            -- Both moved, differently. Keep the local value -- an override
            -- that an update can silently revert is not an override -- and
            -- record it so the editor can offer the choice.
            out[f] = deepcopy(a)
            conflicts[#conflicts + 1] = {
                path = path, field = f,
                base = deepcopy(o), ours = deepcopy(a), theirs = deepcopy(b),
            }
        end
    end
    return out
end

local mergeActionList
local function mergeBlock(old, ours, theirs, path, conflicts, depth)
    local out = mergeFields(old, ours, theirs, path, conflicts)
    local tt = theirs.Type or theirs.type or ""
    local ot = old.Type or old.type or ""
    if depth < 5 and (tt == "Loop" or ot == "Loop") then
        local merged = mergeActionList(loopChildren(old), loopChildren(ours), loopChildren(theirs),
            path .. "/loop", conflicts, depth + 1)
        for i = 1, #merged do out[i] = merged[i] end
    elseif depth < 5 and (tt == "If" or ot == "If") then
        for n = 1, 2 do
            out[n] = mergeActionList(ifBranch(old, n), ifBranch(ours, n), ifBranch(theirs, n),
                path .. "/if" .. n, conflicts, depth + 1)
        end
    else
        for i, v in ipairs(theirs) do out[i] = deepcopy(v) end
    end
    return out
end

-- Blocks are paired by CONTENT, through the same matchBlocks the differ uses,
-- so a block the author moved or inserted above is found by what it is rather
-- than by an index that no longer means anything.
mergeActionList = function(oldL, ourL, theirL, path, conflicts, depth)
    local mapTheirs = matchBlocks(oldL, theirL)   -- theirIdx -> oldIdx
    local mapOurs = matchBlocks(oldL, ourL)       -- ourIdx   -> oldIdx
    local ourByOld, usedOur, out = {}, {}, {}
    for ourIdx, oldIdx in pairs(mapOurs) do ourByOld[oldIdx] = ourIdx end
    for ti = 1, #theirL do
        local oldIdx = mapTheirs[ti]
        if not oldIdx then
            out[#out + 1] = deepcopy(theirL[ti])          -- the author added it
        else
            local ourIdx = ourByOld[oldIdx]
            if ourIdx then
                usedOur[ourIdx] = true
                out[#out + 1] = mergeBlock(oldL[oldIdx], ourL[ourIdx], theirL[ti],
                    path .. "/" .. ti, conflicts, depth)
            end
            -- else: we deleted this block, so it stays deleted
        end
    end
    for ourIdx = 1, #ourL do                              -- blocks we added
        if not mapOurs[ourIdx] and not usedOur[ourIdx] then out[#out + 1] = deepcopy(ourL[ourIdx]) end
    end
    return out
end

--- Merge the parked update into the fork, keeping what the local edit did.
--
-- Three-way: `old` is the base the fork was cut from (kept in `b` for exactly
-- this), `ours` is the reconstruction, `theirs` is the new version. A field
-- only one side moved takes that side; a field both moved to the same value
-- takes it; a field both moved differently keeps OURS and is reported.
--
-- Re-diffing or replaying instead of merging cannot work: replaying the stored
-- overlay uses positional `from` indices into a block list that no longer
-- exists, and re-diffing ours against the new base just reproduces ours and
-- throws the author's version away.
--
-- Returns merged, conflicts. On success the entry is rebased onto the new
-- blob and `pending` is cleared. Returns nil if either side will not decode,
-- leaving the entry untouched.
function GSE.RebaseDeltaFork(pid, newBlob)
    if type(GSEDeltas) ~= "table" or type(pid) ~= "string" then return nil end
    local entry = GSEDeltas[pid]
    if type(entry) ~= "table" then return nil end
    newBlob = newBlob or entry.pending
    if type(newBlob) ~= "string" then return nil end

    local ours = GSE.ReconstructDeltaFork(entry)
    if type(ours) ~= "table" then return nil end
    local okOld, oldDecoded = GSE.DecodeMessage(entry.b)
    local okNew, newDecoded = GSE.DecodeMessage(newBlob)
    if not okOld or type(oldDecoded) ~= "table" then return nil end
    if not okNew or type(newDecoded) ~= "table" then return nil end
    local old = oldDecoded[2] or oldDecoded
    local theirs = newDecoded[2] or newDecoded

    local conflicts = {}
    local merged = mergeFields(old, ours, theirs, "", conflicts, {Versions = true})
    local oV, aV, bV = old.Versions or {}, ours.Versions or {}, theirs.Versions or {}
    local versions, keys = {}, {}
    for k in pairs(aV) do keys[k] = true end
    for k in pairs(bV) do keys[k] = true end
    for k in pairs(keys) do
        local o, a, b = oV[k] or {}, aV[k], bV[k]
        if a and b then
            local v = mergeFields(o, a, b, "v" .. tostring(k), conflicts, {Actions = true})
            v.Actions = mergeActionList(listOf(o.Actions), listOf(a.Actions), listOf(b.Actions),
                "v" .. tostring(k), conflicts, 0)
            versions[k] = v
        elseif a and not b then
            -- Only ours has it: a version we added stays; one the author
            -- removed and we never touched goes with it.
            if oV[k] == nil then versions[k] = deepcopy(a) end
        elseif b and not a then
            if oV[k] == nil then versions[k] = deepcopy(b) end
        end
    end
    if next(versions) ~= nil then merged.Versions = versions end

    local d = GSE.EncodeDelta(GSE.DiffDelta(theirs, merged))
    if type(d) ~= "string" then return nil end
    GSEDeltas[pid] = {b = newBlob, d = d, t = entry.t, src = entry.src,
        conflicts = (#conflicts > 0) and conflicts or nil}
    return merged, conflicts
end

--- What the local fork changed, per block, for the editor to show.
--
-- The panel beside each block already renders that block's compiled output;
-- this is the same shape of answer for "and what did I change here", so a
-- fork can be read where the edit was made instead of as one opaque blob.
--
-- Returns nil when there is no fork. Otherwise:
--   { top      = { {field, from, to}, ... },
--     versions = { [k] = { [blockIndex] = { {field, from, to}, ... },
--                          added = { [blockIndex] = true } } },
--     conflicts = the list parked by the last merge, or nil }
--
-- `from` is the author's value, `to` is the local one. Blocks are paired by
-- content through matchBlocks, so an edit is reported against the block it was
-- made to even when the author's version has moved it.
function GSE.DescribeForkChanges(pid)
    if type(GSEDeltas) ~= "table" or type(pid) ~= "string" then return nil end
    local entry = GSEDeltas[pid]
    if type(entry) ~= "table" then return nil end
    local ours = GSE.ReconstructDeltaFork(entry)
    if type(ours) ~= "table" then return nil end
    local ok, decoded = GSE.DecodeMessage(entry.b)
    if not ok or type(decoded) ~= "table" then return nil end
    local base = decoded[2] or decoded

    local function fieldList(from, to)
        local out = {}
        local set, unset = diffFields(from, to)
        for f, v in pairs(set) do out[#out + 1] = {field = f, from = from[f], to = v} end
        for _, f in ipairs(unset) do out[#out + 1] = {field = f, from = from[f], to = nil} end
        sort(out, function(a, b) return tostring(a.field) < tostring(b.field) end)
        return out
    end

    local report = {top = {}, versions = {}, conflicts = entry.conflicts}
    for _, e in ipairs(fieldList(base, ours)) do
        if e.field ~= "Versions" then report.top[#report.top + 1] = e end
    end

    local bV, oV = base.Versions or {}, ours.Versions or {}
    for k, ourV in pairs(oV) do
        local baseV = bV[k] or {}
        local blocks, added = {}, {}
        local baseA, ourA = listOf(baseV.Actions), listOf(ourV.Actions)
        local map = matchBlocks(baseA, ourA)           -- ourIdx -> baseIdx
        for i = 1, #ourA do
            local bi = map[i]
            if bi then
                local changes = fieldList(baseA[bi], ourA[i])
                if #changes > 0 then blocks[i] = changes end
            else
                added[i] = true
            end
        end
        if next(blocks) ~= nil or next(added) ~= nil then
            report.versions[k] = {blocks = blocks, added = added}
        end
    end
    return report
end

-- Walk a conflict's path back to the table it names. The paths are the ones
-- the merge wrote: "" is the sequence, "v1" a version, "v1/2" the second block
-- of it, then "/loop/<n>" or "/if1/<n>" for nested lists. listOf copies the
-- array but keeps the element references, so a field written through this
-- lands on the real block.
local function nodeForPath(obj, path)
    if type(obj) ~= "table" then return nil end
    if path == nil or path == "" then return obj end
    local parts = {}
    for seg in string.gmatch(path, "[^/]+") do parts[#parts + 1] = seg end
    local vk = parts[1] and parts[1]:match("^v(.+)$")
    if not vk then return nil end
    local versions = obj.Versions or {}
    local node = versions[tonumber(vk) or vk]
    if type(node) ~= "table" then return nil end
    local i = 2
    if parts[i] then
        node = listOf(node.Actions)[tonumber(parts[i])]
        i = i + 1
    end
    while type(node) == "table" and parts[i] do
        local seg, idx = parts[i], tonumber(parts[i + 1])
        if not idx then return nil end
        if seg == "loop" then
            node = loopChildren(node)[idx]
        elseif seg:match("^if%d+$") then
            node = ifBranch(node, tonumber(seg:sub(3)))[idx]
        else
            return nil
        end
        i = i + 2
    end
    return type(node) == "table" and node or nil
end

--- Take the author's value for ONE conflicted field.
--
-- The merge keeps the local value on a clash and parks the pair, because an
-- override an update can silently revert is not an override. That is a default,
-- not a verdict: this is how the other choice is made, one field at a time,
-- rather than the sequence-wide "keep everything" or "discard everything" that
-- would otherwise be the only options.
--
-- Writes into `obj` and drops the conflict. It does NOT persist -- the caller
-- saves through the normal path (ReplaceSequence), which re-diffs the fork and
-- keeps one story about how an edit is written.
function GSE.ResolveForkConflict(pid, obj, path, field)
    if type(GSEDeltas) ~= "table" or type(pid) ~= "string" then return false end
    local entry = GSEDeltas[pid]
    if type(entry) ~= "table" or type(entry.conflicts) ~= "table" then return false end
    for i, c in ipairs(entry.conflicts) do
        if c.path == path and c.field == field then
            local node = nodeForPath(obj, path)
            if not node then return false end
            -- A nil `theirs` is the author removing the field; honour that.
            node[field] = (c.theirs ~= nil) and deepcopy(c.theirs) or nil
            table.remove(entry.conflicts, i)
            if #entry.conflicts == 0 then entry.conflicts = nil end
            return true
        end
    end
    return false
end

--- Throw the local fork away and go back to the author's version.
--
-- Forgetting alone is not enough: GSE.Library still holds the reconstruction,
-- so the edits stay on screen and in play until something reloads the record.
-- Dropping the decoded copy and re-running the lazy loader is what actually
-- puts the author's version back, and it is the same path a fresh import takes.
function GSE.DiscardDeltaFork(classid, sequenceName)
    classid = tonumber(classid)
    if not classid or type(sequenceName) ~= "string" then return false end
    local seq = GSE.Library and GSE.Library[classid] and GSE.Library[classid][sequenceName]
    local meta = type(seq) == "table" and seq.MetaData or {}
    local pid = meta.PlatformID or (type(seq) == "table" and seq.PlatformID)
    if not GSE.ForgetDeltaFork or not GSE.ForgetDeltaFork(pid) then return false end
    GSE.Library[classid][sequenceName] = nil
    if GSE.EnsureSequenceLoaded then GSE.EnsureSequenceLoaded(classid, sequenceName) end
    return true
end

--- Open a delta fork for content that does not have one yet, keyed by its own
--- PlatformID, using the stored blob as the base.
--
-- The base is carried across VERBATIM, and that is the entire point: for
-- protected content the packed !GSE3!+ blob moves into `b` still sealed. The
-- reconstruct side already copes, because it reads the base through
-- GSE.DecodeMessage, which dispatches the packed envelope to
-- DecodePackedMessage. So an edit to protected content can be persisted
-- without the addon ever producing an envelope.
--
-- Only the divergence lands in `d`, and DiffDelta emits untouched blocks as
-- {from = n} back-references rather than copies, so the delta carries what the
-- user actually typed and not the protected body around it.
--
-- `src` is the upstream this diverged from. Editing in place rather than
-- forking to a new identity means that is the record's own id: "this content,
-- changed locally". Returns false when there is no PlatformID to key by --
-- the caller then falls back to a repack request.
function GSE.SeedDeltaFork(baseBlob, obj, contentType)
    if type(obj) ~= "table" or type(baseBlob) ~= "string" then return false end
    local meta = obj.MetaData or {}
    local pid = meta.PlatformID or obj.PlatformID
    if type(pid) ~= "string" or pid == "" then return false end
    if type(GSEDeltas) ~= "table" then GSEDeltas = {} end
    -- Already forked: this is just another edit on top.
    if type(GSEDeltas[pid]) == "table" then return GSE.UpdateDeltaFork(obj) end
    local ok, decoded = GSE.DecodeMessage(baseBlob)
    if not ok or type(decoded) ~= "table" then return false end
    local base = decoded[2] or decoded
    local d = GSE.EncodeDelta(GSE.DiffDelta(base, obj))
    if type(d) ~= "string" then return false end
    GSEDeltas[pid] = {b = baseBlob, d = d, t = contentType or "sequence", src = pid}
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

local GSE = GSE

local GNOME = "Checksum" -- luacheck: ignore

-- The version tag written into every new checksum.
-- Bump this (e.g. "v2") when the algorithm or salt changes.
-- VerifySequenceChecksum dispatches on the stored tag, so old checksums
-- gracefully degrade to "no_checksum" rather than reporting false tampering.
local CHECKSUM_VERSION = "v1"

-- FNV-1a 32-bit constants.
local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619
local MOD32      = 2 ^ 32

--- FNV-1a 32-bit hash over a string, optionally seeded.
local function fnv1a(str, seed)
    local hash = seed or FNV_OFFSET
    for i = 1, #str do
        hash = bit.bxor(hash, str:byte(i))
        hash = (hash * FNV_PRIME) % MOD32
    end
    return hash
end

--- Canonical serialisation of an arbitrary Lua value to a deterministic string.
-- Only handles the types present in sequence data (string, number, boolean, table).
-- Tables are serialised with sorted keys for stability across Lua versions.
local function canonicalize(val, visited)
    visited = visited or {}
    local t = type(val)
    if t == "string" then
        -- Length-prefixed so "ab"+"c" != "a"+"bc"
        return "s" .. #val .. ":" .. val
    elseif t == "number" then
        return "n" .. tostring(val)
    elseif t == "boolean" then
        return val and "b1" or "b0"
    elseif t == "nil" then
        return "z"
    elseif t == "table" then
        if visited[val] then return "c" end -- cycle guard
        visited[val] = true
        local keys = {}
        for k in pairs(val) do
            keys[#keys + 1] = k
        end
        -- Sort: numbers before strings, then by value, for a stable order.
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta == "number" end
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = canonicalize(k, visited) .. "=" .. canonicalize(val[k], visited)
        end
        visited[val] = nil
        return "t{" .. table.concat(parts, ",") .. "}"
    else
        return "?"
    end
end

--- Per-version algorithm table.
-- Each entry is a function(sequence) → raw hex string | nil.
-- Add a new entry here when bumping CHECKSUM_VERSION; do not modify existing
-- entries, since VerifySequenceChecksum uses them to re-validate old checksums.
local algorithms = {
    ["v1"] = function(sequence)
        if type(sequence.Versions) ~= "table" then return nil end
        -- Salt: stable for the life of a game variant and expansion.
        -- WOW_PROJECT_ID  separates retail from each classic variant.
        -- GetExpansionLevel() changes only on new expansion release (~2 years).
        -- Neither value is session- or character-specific, so the checksum is
        -- reproducible by any client running the same game version.
        local projectID = (WOW_PROJECT_ID or 1)
        local expansion = GetExpansionLevel() or 0
        local salt      = string.format("GSE\226\156\168%d\31%d", projectID, expansion)

        local saltHash  = fnv1a(salt)
        local finalHash = fnv1a(canonicalize(sequence.Versions), saltHash)
        return string.format("%08x", finalHash)
    end,
}

--- Compute a versioned checksum string for a sequence's Versions content.
-- Returns a string like "v1:a3f2b1c9", or nil if the sequence has no Versions.
-- The version prefix lets the algorithm be upgraded in future patches without
-- invalidating existing checksums — superseded versions degrade to "no_checksum".
function GSE.ComputeSequenceChecksum(sequence)
    if type(sequence) ~= "table" then return nil end
    local fn   = algorithms[CHECKSUM_VERSION]
    if not fn then return nil end
    local hash = fn(sequence)
    if not hash then return nil end
    return CHECKSUM_VERSION .. ":" .. hash
end

--- Verify the stored checksum of a sequence.
-- Returns:
--   true           – checksum present, algorithm recognised, hash matches
--   false          – checksum present, algorithm recognised, hash does NOT match
--   "no_checksum"  – no checksum stored, unrecognised version, or algorithm superseded
function GSE.VerifySequenceChecksum(sequence)
    if type(sequence) ~= "table" then return false end
    local stored = type(sequence.MetaData) == "table" and sequence.MetaData.Checksum
    if not stored then return "no_checksum" end

    -- Parse "v1:a3f2b1c9" format.
    local ver, storedHash = stored:match("^(v%d+):(%x+)$")
    if not ver then return "no_checksum" end  -- malformed or pre-versioning value

    local fn = algorithms[ver]
    if not fn then return "no_checksum" end   -- version not in this build → degraded

    local computed = fn(sequence)
    if not computed then return "no_checksum" end

    return computed == storedHash
end

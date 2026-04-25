local GSE = GSE

local GNOME = "Checksum" -- luacheck: ignore

-- The version tag written into every new checksum.
-- Bump this (e.g. "v2") when the algorithm or salt changes.
local CHECKSUM_VERSION = "v1"

-- ── v1: FNV-1a 32-bit ────────────────────────────────────────────────────────

local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619
local MOD32      = 2 ^ 32

local function fnv1a(str, seed)
    local hash = seed or FNV_OFFSET
    for i = 1, #str do
        hash = bit.bxor(hash, str:byte(i))
        hash = (hash * FNV_PRIME) % MOD32
    end
    return hash
end

-- Canonical serialisation used by v1 (length-prefixed, not the JSON form).
local function canonicalize_v1(val, visited)
    visited = visited or {}
    local t = type(val)
    if t == "string"  then return "s" .. #val .. ":" .. val
    elseif t == "number"  then return "n" .. tostring(val)
    elseif t == "boolean" then return val and "b1" or "b0"
    elseif t == "nil"     then return "z"
    elseif t == "table"   then
        if visited[val] then return "c" end
        visited[val] = true
        local keys = {}
        for k in pairs(val) do keys[#keys+1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta == "number" end
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts+1] = canonicalize_v1(k, visited) .. "=" .. canonicalize_v1(val[k], visited)
        end
        visited[val] = nil
        return "t{" .. table.concat(parts, ",") .. "}"
    else
        return "?"
    end
end

-- ── v2: Ed25519 over canonical JSON ──────────────────────────────────────────
-- Canonical form matches the server's canonicalise() in server/lib/checksum.js:
--   - All tables (including array-like) use object map syntax { "key": value }
--   - Integer/numeric keys are converted to their string representation
--   - Keys are sorted lexicographically (string compare)
--   - JS arrays arrive as 1-indexed Lua tables after CBOR round-trip
-- This ensures the canonical string computed here matches what the server signed.

local function json_quote(s)
    -- Produce a JSON-encoded string (with double-quote delimiters and escapes)
    local out = {'"'}
    for i = 1, #s do
        local c = s:byte(i)
        if c == 34 then out[#out+1] = '\\"'
        elseif c == 92 then out[#out+1] = '\\\\'
        elseif c == 8  then out[#out+1] = '\\b'
        elseif c == 9  then out[#out+1] = '\\t'
        elseif c == 10 then out[#out+1] = '\\n'
        elseif c == 12 then out[#out+1] = '\\f'
        elseif c == 13 then out[#out+1] = '\\r'
        elseif c < 32  then out[#out+1] = string.format('\\u%04x', c)
        else out[#out+1] = s:sub(i,i)
        end
    end
    out[#out+1] = '"'
    return table.concat(out)
end

local function json_number(n)
    -- Produce a JSON number matching JSON.stringify behaviour:
    -- integers print without decimal point; very large/small floats use exponential.
    if n ~= n then return "null" end  -- NaN
    if n == math.huge or n == -math.huge then return "null" end
    if math.floor(n) == n and math.abs(n) < 1e15 then
        return string.format("%d", n)
    end
    return tostring(n)  -- Lua's tostring for floats is close enough
end

local function canonicalise_v2(val)
    local t = type(val)
    if t == "string"  then return json_quote(val)
    elseif t == "number"  then return json_number(val)
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "nil"     then return "null"
    elseif t == "table"   then
        -- Collect all keys as strings and sort lexicographically
        local keys = {}
        for k in pairs(val) do keys[#keys+1] = tostring(k) end
        table.sort(keys)  -- lexicographic (same as JS String.prototype sort)
        local parts = {}
        for _, ks in ipairs(keys) do
            local kn = tonumber(ks)
            local v  = (kn ~= nil) and val[kn] or val[ks]
            parts[#parts+1] = json_quote(ks) .. ":" .. canonicalise_v2(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "null"
    end
end

-- Base64url decoder (for v2 signature payload)
local _b64url_lut = {}
do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    for i = 1, #chars do _b64url_lut[chars:sub(i,i)] = i - 1 end
    _b64url_lut["+"] = 62; _b64url_lut["/"] = 63; _b64url_lut["="] = 0
end

local function gsev2_b64url_decode(s)
    -- Accept base64url (- _) or standard base64 (+ /), with or without padding
    local pad = (4 - #s % 4) % 4
    local padded = s .. string.rep("=", pad)
    local out = {}
    for i = 1, #padded, 4 do
        local a = _b64url_lut[padded:sub(i,i)]   or 0
        local b = _b64url_lut[padded:sub(i+1,i+1)] or 0
        local c = _b64url_lut[padded:sub(i+2,i+2)] or 0
        local d = _b64url_lut[padded:sub(i+3,i+3)] or 0
        local n = a*262144 + b*4096 + c*64 + d
        out[#out+1] = string.char(math.floor(n/65536) % 256)
        if padded:sub(i+2,i+2) ~= "=" then
            out[#out+1] = string.char(math.floor(n/256) % 256)
        end
        if padded:sub(i+3,i+3) ~= "=" then
            out[#out+1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

-- Platform Ed25519 public key.
-- Ed25519 public keys are 32-byte little-endian compressed y-coordinates (RFC 8032 §5.1.5).
-- The hex string below is the canonical wire-format representation — each pair is one byte
-- in order, so these bytes are used as-is (no reversal needed).
-- Public key hex: b531cb8b505ae9752b5b789f26085853b0ba5da5d7e7e244975f0545430d683a
local PLATFORM_PUBKEY_LE = {
    0xb5,0x31,0xcb,0x8b,0x50,0x5a,0xe9,0x75,0x2b,0x5b,0x78,0x9f,0x26,0x08,0x58,0x53,
    0xb0,0xba,0x5d,0xa5,0xd7,0xe7,0xe2,0x44,0x97,0x5f,0x05,0x45,0x43,0x0d,0x68,0x3a,
}

local _pubkey_str = nil
local function get_pubkey()
    if not _pubkey_str then
        local t = {}
        for i = 1, 32 do t[i] = string.char(PLATFORM_PUBKEY_LE[i]) end
        _pubkey_str = table.concat(t)
    end
    return _pubkey_str
end

-- ── Algorithm dispatch table ──────────────────────────────────────────────────
-- Each entry: function(sequence) → "hex_or_b64url_hash" | nil
-- Return value is compared to the stored hash portion of the checksum string.
-- (Not used by v2 verify which does the full signature check internally.)

local algorithms = {
    ["v1"] = function(sequence)
        if type(sequence.Versions) ~= "table" then return nil end
        local projectID = (WOW_PROJECT_ID or 1)
        local expansion = GetExpansionLevel() or 0
        local salt      = string.format("GSE\226\156\168%d\31%d", projectID, expansion)
        local saltHash  = fnv1a(salt)
        local finalHash = fnv1a(canonicalize_v1(sequence.Versions), saltHash)
        return string.format("%08x", finalHash)
    end,

    ["v2"] = function(sequence)
        -- v2 is verified via Ed25519, not recomputed; return the stored value
        -- so the comparison is handled by VerifySequenceChecksum directly.
        -- This entry exists only to mark v2 as a recognised version.
        return nil  -- signal: use the dedicated v2 path
    end,
}

-- ── Public API ────────────────────────────────────────────────────────────────

function GSE.ComputeSequenceChecksum(sequence)
    if type(sequence) ~= "table" then return nil end
    local fn = algorithms[CHECKSUM_VERSION]
    if not fn then return nil end
    local hash = fn(sequence)
    if not hash then return nil end
    return CHECKSUM_VERSION .. ":" .. hash
end

--- Verify the stored checksum of a sequence.
-- Returns:
--   true           – checksum present, algorithm recognised, hash/sig matches
--   false          – checksum present but verification fails (tampered or bad sig)
--   "no_checksum"  – no checksum stored or it's malformed / from an unknown version
function GSE.VerifySequenceChecksum(sequence)
    if type(sequence) ~= "table" then return false end
    local stored = type(sequence.MetaData) == "table" and sequence.MetaData.Checksum
    if not stored then return "no_checksum" end

    -- Parse "v<N>:<payload>" where payload is hex or base64url characters.
    -- Pattern accepts letters, digits, +, /, =, - and _ (covers hex AND base64url).
    local ver, payload = stored:match("^(v%d+):([-A-Za-z0-9+/=_]+)$")
    if not ver then return "no_checksum" end  -- malformed value

    -- Unknown versions: treat as a FAILED check, not "no_checksum".
    -- This prevents a forged "v99:anything" from silently passing as unverified.
    if not algorithms[ver] then return false end

    -- v2: Ed25519 signature verification
    if ver == "v2" then
        if type(sequence.Versions) ~= "table" then return false end
        -- GSE_Ed25519Verify is provided by GSE/Lib/ed25519verify.lua
        if type(GSE_Ed25519Verify) ~= "function" then return "no_checksum" end
        -- Decode base64url signature using inline decoder
        local sig_bytes = gsev2_b64url_decode(payload)
        if not sig_bytes or #sig_bytes ~= 64 then return false end

        local canonical = canonicalise_v2(sequence.Versions)

        -- Pure-Lua ed25519 verify in WoW occasionally exceeds the per-
        -- execution instruction budget on imports of larger sequences,
        -- aborting with "script ran too long". Two mitigations:
        --   1. Per-session cache: signatures we've already verified once
        --      this session are trusted on re-import. The cache key MUST
        --      include the full canonical bytes — using only the
        --      canonical's *length* alongside the signature lets a
        --      tampered sequence (same length, same signature, different
        --      content) collide with a previously-cached `true` result
        --      and pass verification incorrectly. busted spec
        --      checksum_spec.lua@191 covers this case.
        --   2. pcall guard: if the verify aborts, downgrade to
        --      "no_checksum" so the import proceeds rather than getting
        --      stuck. The badge will still flag it as unverified.
        GSE._v2VerifyCache = GSE._v2VerifyCache or {}
        local cacheKey = payload .. "@" .. canonical
        if GSE._v2VerifyCache[cacheKey] ~= nil then
            return GSE._v2VerifyCache[cacheKey]
        end
        local ok, result = pcall(GSE_Ed25519Verify, get_pubkey(), canonical, sig_bytes)
        if not ok then
            -- Script-too-long or other runtime error during verify.
            -- Don't fail the whole import — return no_checksum.
            return "no_checksum"
        end
        local verdict = result == true
        GSE._v2VerifyCache[cacheKey] = verdict
        return verdict
    end

    -- v1 (and any other hash-based versions): recompute and compare
    local computed = algorithms[ver](sequence)
    if not computed then return "no_checksum" end
    return computed == payload
end

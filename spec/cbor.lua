-- Minimal CBOR decoder — TEST ONLY (spec/). The Mod decodes deltas in-game with
-- C_EncodingUtil.DeserializeCBOR (Blizzard native); this stand-in lets busted
-- validate the Node CBOR encoder (api/src/lib/cbor.js) + ApplySequenceDelta
-- end-to-end in pure Lua, without that WoW API. Covers exactly what the encoder
-- emits: uint/negint, text/byte strings, arrays, maps (integer keys decode to
-- NUMBER keys — the whole point), bool, null, float64. Validated against RFC
-- 8949 Appendix A vectors in cbordelta_spec.lua.
--
-- IMPORTANT: pure Lua 5.1 — CI runs busted under 5.1, where the bitwise
-- operators (>>, &) and string.unpack do NOT exist. So byte fields are assembled
-- with arithmetic and floats are decoded by hand (math.ldexp). Do not reintroduce
-- 5.3+ syntax here or the whole suite fails to load (the `unexpected symbol near
-- '>'` build break).
local byte, ssub = string.byte, string.sub
local floor, huge = math.floor, math.huge
-- `m * 2^e` instead of math.ldexp: ldexp was REMOVED in Lua 5.3, the `^`
-- operator exists in every version — so this decoder works under 5.1 (CI) AND
-- 5.4 (local busted) unchanged.

local decode_value

-- Big-endian unsigned integer, n bytes.
local function uint_be(s, pos, n)
    local v = 0
    for i = 0, n - 1 do v = v * 256 + byte(s, pos + i) end
    return v
end

-- IEEE-754 binary32 (big-endian) → number.
local function float32(s, pos)
    local b1, b2, b3, b4 = byte(s, pos, pos + 3)
    local sign = (b1 >= 128) and -1 or 1
    local expo = (b1 % 128) * 2 + floor(b2 / 128)
    local mant = (b2 % 128) * 65536 + b3 * 256 + b4
    if expo == 0 then
        if mant == 0 then return sign * 0.0 end
        return sign * mant * 2 ^ -149
    elseif expo == 255 then
        if mant == 0 then return sign * huge end
        return 0 / 0
    end
    return sign * (mant + 2 ^ 23) * 2 ^ (expo - 150)
end

-- IEEE-754 binary64 (big-endian) → number.
local function float64(s, pos)
    local b1, b2, b3, b4, b5, b6, b7, b8 = byte(s, pos, pos + 7)
    local sign = (b1 >= 128) and -1 or 1
    local expo = (b1 % 128) * 16 + floor(b2 / 16)
    local mant = ((((((b2 % 16) * 256 + b3) * 256 + b4) * 256 + b5) * 256 + b6) * 256 + b7) * 256 + b8
    if expo == 0 then
        if mant == 0 then return sign * 0.0 end
        return sign * mant * 2 ^ -1074
    elseif expo == 2047 then
        if mant == 0 then return sign * huge end
        return 0 / 0
    end
    return sign * (mant + 2 ^ 52) * 2 ^ (expo - 1075)
end

local function read_arg(s, pos, info)
    if info < 24 then return info, pos end
    if info == 24 then return byte(s, pos), pos + 1 end
    if info == 25 then return uint_be(s, pos, 2), pos + 2 end
    if info == 26 then return uint_be(s, pos, 4), pos + 4 end
    if info == 27 then return uint_be(s, pos, 8), pos + 8 end
    error("cbor: bad additional-info " .. info)
end

decode_value = function(s, pos)
    local b = byte(s, pos)
    pos = pos + 1
    local major = floor(b / 32)
    local info = b % 32

    if major == 7 then
        if info == 20 then return false, pos end
        if info == 21 then return true, pos end
        if info == 22 or info == 23 then return nil, pos end
        if info == 26 then return float32(s, pos), pos + 4 end
        if info == 27 then return float64(s, pos), pos + 8 end
        error("cbor: unsupported simple/float " .. info)
    end

    local arg
    arg, pos = read_arg(s, pos, info)

    if major == 0 then return arg, pos end
    if major == 1 then return -1 - arg, pos end
    if major == 2 or major == 3 then return ssub(s, pos, pos + arg - 1), pos + arg end
    if major == 4 then
        local t = {}
        for i = 1, arg do t[i], pos = decode_value(s, pos) end
        return t, pos
    end
    if major == 5 then
        local t = {}
        for _ = 1, arg do
            local k, v
            k, pos = decode_value(s, pos)
            v, pos = decode_value(s, pos)
            t[k] = v
        end
        return t, pos
    end
    error("cbor: bad major type " .. major)
end

return {
    decode = function(s) local v = decode_value(s, 1); return v end,
}

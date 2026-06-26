-- Minimal CBOR decoder — TEST ONLY (spec/). The Mod decodes deltas in-game with
-- C_EncodingUtil.DeserializeCBOR (Blizzard native); this stand-in lets busted
-- validate the Node CBOR encoder (api/src/lib/cbor.js) + ApplySequenceDelta
-- end-to-end in pure Lua, without that WoW API. Covers exactly what the encoder
-- emits: uint/negint, text/byte strings, arrays, maps (integer keys decode to
-- NUMBER keys — the whole point), bool, null, float64. Validated against RFC
-- 8949 Appendix A vectors in cbordelta_spec.lua.
local byte, ssub, unpack = string.byte, string.sub, string.unpack

local decode_value

local function read_arg(s, pos, info)
    if info < 24 then return info, pos end
    if info == 24 then return byte(s, pos), pos + 1 end
    if info == 25 then return unpack(">I2", s, pos), pos + 2 end
    if info == 26 then return unpack(">I4", s, pos), pos + 4 end
    if info == 27 then return unpack(">I8", s, pos), pos + 8 end
    error("cbor: bad additional-info " .. info)
end

decode_value = function(s, pos)
    local b = byte(s, pos)
    pos = pos + 1
    local major = b >> 5
    local info = b & 0x1f

    if major == 7 then
        if info == 20 then return false, pos end
        if info == 21 then return true, pos end
        if info == 22 or info == 23 then return nil, pos end
        if info == 26 then return unpack(">f", s, pos), pos + 4 end
        if info == 27 then return unpack(">d", s, pos), pos + 8 end
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

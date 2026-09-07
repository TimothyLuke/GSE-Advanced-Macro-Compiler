local _, GSE = ...

local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift
local schar, ssub, sbyte = string.char, string.sub, string.byte
local concat = table.concat

local MASK = 0xFFFFFFFF

local function add32(a, b) return band(a + b, MASK) end
local function rotl(x, n) return bor(lshift(x, n), rshift(x, 32 - n)) end

local function ld32(s, i)
    local a, b, c, d = sbyte(s, i, i + 3)
    return bor(bor(a, lshift(b, 8)), bor(lshift(c, 16), lshift(d, 24)))
end

local C0, C1, C2, C3 = 1634760805, 857760878, 2036477234, 1797285236

local function qr(w, a, b, c, d)
    w[a] = add32(w[a], w[b]); w[d] = rotl(bxor(w[d], w[a]), 16)
    w[c] = add32(w[c], w[d]); w[b] = rotl(bxor(w[b], w[c]), 12)
    w[a] = add32(w[a], w[b]); w[d] = rotl(bxor(w[d], w[a]), 8)
    w[c] = add32(w[c], w[d]); w[b] = rotl(bxor(w[b], w[c]), 7)
end

local function block(k, ctr, n)
    local s = {
        C0, C1, C2, C3,
        k[1], k[2], k[3], k[4], k[5], k[6], k[7], k[8],
        band(ctr, MASK), n[1], n[2], n[3],
    }
    local w = {}
    for i = 1, 16 do w[i] = s[i] end
    for _ = 1, 10 do
        qr(w, 1, 5, 9, 13); qr(w, 2, 6, 10, 14); qr(w, 3, 7, 11, 15); qr(w, 4, 8, 12, 16)
        qr(w, 1, 6, 11, 16); qr(w, 2, 7, 12, 13); qr(w, 3, 8, 9, 14); qr(w, 4, 5, 10, 15)
    end
    local out = {}
    for i = 1, 16 do
        local v = add32(w[i], s[i])
        out[i] = schar(band(v, 0xFF), band(rshift(v, 8), 0xFF), band(rshift(v, 16), 0xFF), band(rshift(v, 24), 0xFF))
    end
    return concat(out)
end

function GSE.TransformBytes(key, nonce, counter, data)
    local k = {}
    for i = 0, 7 do k[i + 1] = ld32(key, 1 + i * 4) end
    local n = {}
    for i = 0, 2 do n[i + 1] = ld32(nonce, 1 + i * 4) end
    local len = #data
    local out = {}
    local pos = 1
    local ctr = counter
    while pos <= len do
        local ks = block(k, ctr, n)
        local chunk = len - pos + 1
        if chunk > 64 then chunk = 64 end
        for j = 1, chunk do
            out[#out + 1] = schar(band(bxor(sbyte(data, pos + j - 1), sbyte(ks, j)), 0xFF))
        end
        pos = pos + chunk
        ctr = ctr + 1
    end
    return concat(out)
end

local keys = {
    ["1"] = "\062\219\034\238\241\049\089\006\129\129\249\022\151\152\036\030\140\098\198\223\066\041\211\084\233\092\232\202\056\248\123\037",
}

function GSE.DecodePackedMessage(data)
    local id = ssub(data, 8, 8)
    local key = keys[id]
    if not key then error("unsupported encoding") end
    local raw = C_EncodingUtil.DecodeBase64(ssub(data, 9))
    local nonce = ssub(raw, 1, 12)
    local body = ssub(raw, 13)
    local plain = GSE.TransformBytes(key, nonce, 0, body)
    return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(plain))
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Codec") end

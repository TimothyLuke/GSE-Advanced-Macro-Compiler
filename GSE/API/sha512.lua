-- Pure Lua SHA-512 for WoW (LuaJIT + bit library).
-- LuaJIT bit.* operations return signed int32 values; use u32() to normalise
-- to unsigned [0, 2^32) before arithmetic comparisons / additions.
-- Public: GSE_SHA512(str) -> 64-byte binary string

local band, bor, bxor = bit.band, bit.bor, bit.bxor
local rshift, lshift  = bit.rshift, bit.lshift

-- Convert signed int32 result of a bit operation to unsigned [0, 2^32).
local M32 = 0x100000000
local function u32(x)
    if x < 0 then return x + M32 end
    return x
end

-- 64-bit right-rotate of (hi,lo) by n bits; hi,lo must be in [0,2^32).
local function rotr64(hi, lo, n)
    if n == 32 then return lo, hi end
    if n < 32 then
        return u32(bor(rshift(hi, n), lshift(lo, 32-n))),
               u32(bor(rshift(lo, n), lshift(hi, 32-n)))
    end
    n = n - 32
    return u32(bor(rshift(lo, n), lshift(hi, 32-n))),
           u32(bor(rshift(hi, n), lshift(lo, 32-n)))
end

-- 64-bit logical-right-shift of (hi,lo) by n; hi,lo in [0,2^32).
local function shr64(hi, lo, n)
    if n >= 64 then return 0, 0 end
    if n >= 32 then return 0, rshift(hi, n-32) end
    return rshift(hi, n), u32(bor(rshift(lo, n), lshift(hi, 32-n)))
end

-- 64-bit addition mod 2^64; inputs may be signed int32 (normalised here).
local function add64(ah, al, bh, bl)
    if al < 0 then al = al + M32 end
    if bl < 0 then bl = bl + M32 end
    if ah < 0 then ah = ah + M32 end
    if bh < 0 then bh = bh + M32 end
    local lo = al + bl
    local carry = 0
    if lo >= M32 then lo = lo - M32; carry = 1 end
    local hi = (ah + bh + carry) % M32
    return hi, lo
end

-- SHA-512 round constants K[1..80] as {hi,lo} pairs.
local K = {
    {0x428a2f98,0xd728ae22},{0x71374491,0x23ef65cd},{0xb5c0fbcf,0xec4d3b2f},{0xe9b5dba5,0x8189dbbc},
    {0x3956c25b,0xf348b538},{0x59f111f1,0xb605d019},{0x923f82a4,0xaf194f9b},{0xab1c5ed5,0xda6d8118},
    {0xd807aa98,0xa3030242},{0x12835b01,0x45706fbe},{0x243185be,0x4ee4b28c},{0x550c7dc3,0xd5ffb4e2},
    {0x72be5d74,0xf27b896f},{0x80deb1fe,0x3b1696b1},{0x9bdc06a7,0x25c71235},{0xc19bf174,0xcf692694},
    {0xe49b69c1,0x9ef14ad2},{0xefbe4786,0x384f25e3},{0x0fc19dc6,0x8b8cd5b5},{0x240ca1cc,0x77ac9c65},
    {0x2de92c6f,0x592b0275},{0x4a7484aa,0x6ea6e483},{0x5cb0a9dc,0xbd41fbd4},{0x76f988da,0x831153b5},
    {0x983e5152,0xee66dfab},{0xa831c66d,0x2db43210},{0xb00327c8,0x98fb213f},{0xbf597fc7,0xbeef0ee4},
    {0xc6e00bf3,0x3da88fc2},{0xd5a79147,0x930aa725},{0x06ca6351,0xe003826f},{0x14292967,0x0a0e6e70},
    {0x27b70a85,0x46d22ffc},{0x2e1b2138,0x5c26c926},{0x4d2c6dfc,0x5ac42aed},{0x53380d13,0x9d95b3df},
    {0x650a7354,0x8baf63de},{0x766a0abb,0x3c77b2a8},{0x81c2c92e,0x47edaee6},{0x92722c85,0x1482353b},
    {0xa2bfe8a1,0x4cf10364},{0xa81a664b,0xbc423001},{0xc24b8b70,0xd0f89791},{0xc76c51a3,0x0654be30},
    {0xd192e819,0xd6ef5218},{0xd6990624,0x5565a910},{0xf40e3585,0x5771202a},{0x106aa070,0x32bbd1b8},
    {0x19a4c116,0xb8d2d0c8},{0x1e376c08,0x5141ab53},{0x2748774c,0xdf8eeb99},{0x34b0bcb5,0xe19b48a8},
    {0x391c0cb3,0xc5c95a63},{0x4ed8aa4a,0xe3418acb},{0x5b9cca4f,0x7763e373},{0x682e6ff3,0xd6b2b8a3},
    {0x748f82ee,0x5defb2fc},{0x78a5636f,0x43172f60},{0x84c87814,0xa1f0ab72},{0x8cc70208,0x1a6439ec},
    {0x90befffa,0x23631e28},{0xa4506ceb,0xde82bde9},{0xbef9a3f7,0xb2c67915},{0xc67178f2,0xe372532b},
    {0xca273ece,0xea26619c},{0xd186b8c7,0x21c0c207},{0xeada7dd6,0xcde0eb1e},{0xf57d4f7f,0xee6ed178},
    {0x06f067aa,0x72176fba},{0x0a637dc5,0xa2c898a6},{0x113f9804,0xbef90dae},{0x1b710b35,0x131c471b},
    {0x28db77f5,0x23047d84},{0x32caab7b,0x40c72493},{0x3c9ebe0a,0x15c9bebc},{0x431d67c4,0x9c100d4c},
    {0x4cc5d4be,0xcb3e42b6},{0x597f299c,0xfc657e2a},{0x5fcb6fab,0x3ad6faec},{0x6c44198c,0x4a475817},
}

local function load_word(s, pos)
    -- Load a big-endian 64-bit word from string at 1-indexed byte position pos.
    -- Returns (hi, lo) as unsigned [0,2^32).
    local b1,b2,b3,b4 = s:byte(pos, pos+3)
    local b5,b6,b7,b8 = s:byte(pos+4, pos+7)
    local hi = u32(bor(lshift(b1,24), lshift(b2,16), lshift(b3,8), b4))
    local lo = u32(bor(lshift(b5,24), lshift(b6,16), lshift(b7,8), b8))
    return hi, lo
end

local function process_block(H, blk, bpos)
    -- bpos: 1-indexed start of the 128-byte block in blk
    local W = {}
    for i = 1, 16 do
        local h, l = load_word(blk, bpos + (i-1)*8)
        W[i] = {h, l}
    end
    for i = 17, 80 do
        local w15 = W[i-15]; local w2 = W[i-2]
        local r1h, r1l   = rotr64(w15[1], w15[2], 1)
        local r8h, r8l   = rotr64(w15[1], w15[2], 8)
        local s7h, s7l   = shr64 (w15[1], w15[2], 7)
        local s0h = u32(bxor(r1h, r8h, s7h)); local s0l = u32(bxor(r1l, r8l, s7l))

        local r19h,r19l  = rotr64(w2[1], w2[2], 19)
        local r61h,r61l  = rotr64(w2[1], w2[2], 61)
        local s6h, s6l   = shr64 (w2[1], w2[2], 6)
        local s1h = u32(bxor(r19h,r61h,s6h)); local s1l = u32(bxor(r19l,r61l,s6l))

        local wh, wl = add64(W[i-16][1],W[i-16][2], s0h,s0l)
        wh, wl = add64(wh,wl, W[i-7][1],W[i-7][2])
        wh, wl = add64(wh,wl, s1h,s1l)
        W[i] = {wh, wl}
    end

    local ah,al = H[1][1],H[1][2]
    local bh,bl = H[2][1],H[2][2]
    local ch,cl = H[3][1],H[3][2]
    local dh,dl = H[4][1],H[4][2]
    local eh,el = H[5][1],H[5][2]
    local fh,fl = H[6][1],H[6][2]
    local gh,gl = H[7][1],H[7][2]
    local hh,hl = H[8][1],H[8][2]

    for i = 1, 80 do
        local r14h,r14l = rotr64(eh,el,14)
        local r18h,r18l = rotr64(eh,el,18)
        local r41h,r41l = rotr64(eh,el,41)
        local S1h = u32(bxor(r14h,r18h,r41h)); local S1l = u32(bxor(r14l,r18l,r41l))

        local chh = u32(bxor(band(eh,fh), band(u32(bxor(eh,0xFFFFFFFF)), gh)))
        local chl = u32(bxor(band(el,fl), band(u32(bxor(el,0xFFFFFFFF)), gl)))

        local t1h,t1l = add64(hh,hl, S1h,S1l)
        t1h,t1l = add64(t1h,t1l, chh,chl)
        t1h,t1l = add64(t1h,t1l, K[i][1],K[i][2])
        t1h,t1l = add64(t1h,t1l, W[i][1],W[i][2])

        local r28h,r28l = rotr64(ah,al,28)
        local r34h,r34l = rotr64(ah,al,34)
        local r39h,r39l = rotr64(ah,al,39)
        local S0h = u32(bxor(r28h,r34h,r39h)); local S0l = u32(bxor(r28l,r34l,r39l))

        local mjh = u32(bxor(band(ah,bh), band(ah,ch), band(bh,ch)))
        local mjl = u32(bxor(band(al,bl), band(al,cl), band(bl,cl)))
        local t2h,t2l = add64(S0h,S0l, mjh,mjl)

        hh,hl = gh,gl; gh,gl = fh,fl; fh,fl = eh,el
        eh,el = add64(dh,dl, t1h,t1l)
        dh,dl = ch,cl; ch,cl = bh,bl; bh,bl = ah,al
        ah,al = add64(t1h,t1l, t2h,t2l)
    end

    H[1][1],H[1][2] = add64(H[1][1],H[1][2], ah,al)
    H[2][1],H[2][2] = add64(H[2][1],H[2][2], bh,bl)
    H[3][1],H[3][2] = add64(H[3][1],H[3][2], ch,cl)
    H[4][1],H[4][2] = add64(H[4][1],H[4][2], dh,dl)
    H[5][1],H[5][2] = add64(H[5][1],H[5][2], eh,el)
    H[6][1],H[6][2] = add64(H[6][1],H[6][2], fh,fl)
    H[7][1],H[7][2] = add64(H[7][1],H[7][2], gh,gl)
    H[8][1],H[8][2] = add64(H[8][1],H[8][2], hh,hl)
end

local function u32be(n)
    return string.char(
        rshift(n, 24), band(rshift(n, 16), 0xFF),
        band(rshift(n, 8), 0xFF), band(n, 0xFF))
end

function GSE_SHA512(msg)
    local H = {
        {0x6a09e667,0xf3bcc908},{0xbb67ae85,0x84caa73b},
        {0x3c6ef372,0xfe94f82b},{0xa54ff53a,0x5f1d36f1},
        {0x510e527f,0xade682d1},{0x9b05688c,0x2b3e6c1f},
        {0x1f83d9ab,0xfb41bd6b},{0x5be0cd19,0x137e2179},
    }
    local len = #msg
    local pad = msg .. "\128"
    while (#pad % 128) ~= 112 do pad = pad .. "\0" end
    -- Append 128-bit big-endian bit-length (upper 64 bits = 0 for practical messages)
    local bitlen = len * 8
    pad = pad .. "\0\0\0\0\0\0\0\0"
              .. u32be(math.floor(bitlen / M32))
              .. u32be(bitlen % M32)

    for pos = 1, #pad, 128 do
        process_block(H, pad, pos)
    end

    local out = {}
    for i = 1, 8 do
        out[#out+1] = u32be(H[i][1])
        out[#out+1] = u32be(H[i][2])
    end
    return table.concat(out)
end

-- Pure Lua Ed25519 signature verification (RFC 8032).
-- Requires GSE_SHA512 (sha512.lua) loaded before this file.
-- Public: GSE_Ed25519Verify(pubkey_str, message_str, sig_str) -> boolean
-- All arguments are binary strings (32, any length, 64 bytes).

local band, bor, bxor = bit.band, bit.bor, bit.bxor
local rshift, lshift  = bit.rshift, bit.lshift

local M32 = 0x100000000
local function u32(x) if x < 0 then return x + M32 end; return x end

-- ── Field arithmetic mod p = 2^255 - 19 ──────────────────────────────────────
-- Field elements: arrays of 32 unsigned bytes, little-endian.
-- Intermediate values may exceed 255; fe_reduce normalises.

local function fe_from_bytes(s, mask_top)
    -- Decode 32-byte string to field element; optionally clear bit 255
    local f = {}
    for i = 1, 32 do f[i] = s:byte(i) or 0 end
    if mask_top then f[32] = band(f[32], 0x7F) end
    return f
end

local function fe_int(n)
    -- Small non-negative integer n < 256 as a field element
    local f = {}; for i = 1, 32 do f[i] = 0 end; f[1] = n; return f
end

local FE_ZERO = fe_int(0)
local FE_ONE  = fe_int(1)

local function fe_copy(a) local r={}; for i=1,32 do r[i]=a[i] end; return r end

local function fe_reduce(f)
    -- Propagate carries, then reduce mod p = 2^255-19
    local r = {}
    local carry = 0
    for i = 1, 32 do
        local v = f[i] + carry
        r[i] = v % 256
        carry = math.floor(v / 256)
    end
    -- Fold bit 255: if set, clear it and add 19
    local top = band(r[32], 0x80)
    if top ~= 0 then
        r[32] = r[32] - 0x80
        local c = 19
        for i = 1, 32 do
            local v = r[i] + c; r[i] = v % 256; c = math.floor(v/256)
            if c == 0 then break end
        end
    end
    -- One final conditional subtraction if r >= p
    -- p = {ED,FF,...,FF,7F}; r >= p iff r[32]==0x7F and all r[2..31]==0xFF and r[1]>=0xED
    if r[32] == 0x7F then
        local at_p = r[1] >= 0xED
        if at_p then
            for i = 2, 31 do
                if r[i] ~= 0xFF then at_p = false; break end
            end
        end
        if at_p then
            local c = 19
            for i = 1, 32 do
                local v = r[i] + c; r[i] = v % 256; c = math.floor(v/256)
                if c == 0 then break end
            end
            r[32] = r[32] % 128  -- clear any carry into bit 255
        end
    end
    return r
end

local function fe_add(a, b)
    local r = {}; for i=1,32 do r[i]=a[i]+b[i] end; return fe_reduce(r)
end

local function fe_sub(a, b)
    -- a - b mod p: add p to a to avoid underflow
    local r = {}
    r[1]  = a[1]  - b[1]  + 0xED  -- p[1]
    for i = 2, 31 do r[i] = a[i] - b[i] + 0xFF end
    r[32] = a[32] - b[32] + 0x7F
    return fe_reduce(r)
end

local function fe_neg(a) return fe_sub(FE_ZERO, a) end

local function fe_mul(a, b)
    -- Schoolbook 256-bit multiply, then fold high 32 bytes with factor 38
    -- (because 2^256 mod p = 38).
    local c = {}; for i=1,64 do c[i]=0 end
    for i = 1, 32 do
        local ai = a[i]
        if ai ~= 0 then
            for j = 1, 32 do c[i+j-1] = c[i+j-1] + ai * b[j] end
        end
    end
    for i = 1, 32 do
        c[i] = c[i] + c[i+32] * 38
        c[i+32] = 0
    end
    -- Propagate carries in c[1..32]
    local r = {}
    local carry = 0
    for i = 1, 32 do
        local v = c[i] + carry; r[i] = v % 256; carry = math.floor(v/256)
    end
    -- Residual carry * 2^256 ≡ carry*38 mod p
    if carry > 0 then
        local extra = carry * 38
        for i = 1, 32 do
            local v = r[i] + extra; r[i] = v % 256; extra = math.floor(v/256)
            if extra == 0 then break end
        end
    end
    return fe_reduce(r)
end

local function fe_sq(a) return fe_mul(a, a) end

local function fe_eq(a, b)
    local ar = fe_reduce(a); local br = fe_reduce(b)
    for i = 1, 32 do if ar[i] ~= br[i] then return false end end
    return true
end

local function fe_is_neg(f)  -- true if x mod 2 == 1 (odd = "negative" in RFC 8032)
    return fe_reduce(f)[1] % 2 == 1
end

local function fe_to_str(f)
    local r = fe_reduce(f); local s = {}
    for i = 1, 32 do s[i] = string.char(r[i]) end
    return table.concat(s)
end

-- Modular inverse: a^(p-2) mod p via Fermat / standard inversion ladder
local function fe_inv(a)
    local z1   = a
    local z2   = fe_sq(z1)
    local z4   = fe_sq(z2)
    local z8   = fe_sq(z4)
    local z9   = fe_mul(z8, z1)
    local z11  = fe_mul(z9, z2)
    local z22  = fe_sq(z11)
    local t5   = fe_mul(z22, z9)        -- a^(2^5-1)
    local t10  = fe_sq(t5); for _=1,4  do t10=fe_sq(t10) end; t10=fe_mul(t10,t5)
    local t20  = fe_sq(t10);for _=1,9  do t20=fe_sq(t20) end; t20=fe_mul(t20,t10)
    local t40  = fe_sq(t20);for _=1,19 do t40=fe_sq(t40) end; t40=fe_mul(t40,t20)
    local t50  = fe_sq(t40);for _=1,9  do t50=fe_sq(t50) end; t50=fe_mul(t50,t10)
    local t100 = fe_sq(t50);for _=1,49 do t100=fe_sq(t100)end;t100=fe_mul(t100,t50)
    local t200 = fe_sq(t100);for _=1,99 do t200=fe_sq(t200)end;t200=fe_mul(t200,t100)
    local t250 = fe_sq(t200);for _=1,49 do t250=fe_sq(t250)end;t250=fe_mul(t250,t50)
    local r    = fe_sq(t250);for _=1,4  do r   =fe_sq(r)   end;return fe_mul(r,z11)
end

-- sqrt(-1) mod p = 2^((p-1)/4) mod p
-- Big-endian hex: 2b8324804fc1df0b2b4d00993dfbd7a72f431806ad2fe478c4ee1b274a0ea00b
-- Wait: known good value (RFC 8032 §5.1, "I" constant):
-- I = 2^((q-1)/4) mod q where q = 2^255-19
-- Correct byte value (little-endian):
-- sqrt(-1) mod p = 2^((p-1)/4) mod p
-- BE: 2b8324804fc1df0b2b4d00993dfbd7a72f431806ad2fe478c4ee1b274a0ea0b0
-- LE (little-endian, as stored in field element):
local SQRT_M1 = {
    0xb0,0xa0,0x0e,0x4a,0x27,0x1b,0xee,0xc4,0x78,0xe4,0x2f,0xad,0x06,0x18,0x43,0x2f,
    0xa7,0xd7,0xfb,0x3d,0x99,0x00,0x4d,0x2b,0x0b,0xdf,0xc1,0x4f,0x80,0x24,0x83,0x2b,
}

-- ── Curve constants ───────────────────────────────────────────────────────────
-- d = -121665/121666 mod p = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3 (BE)
-- Little-endian (verified with Python: (-121665 * pow(121666, p-2, p)) % p):
local D = {
    0xa3,0x78,0x59,0x13,0xca,0x4d,0xeb,0x75,0xab,0xd8,0x41,0x41,0x4d,0x0a,0x70,0x00,
    0x98,0xe8,0x79,0x77,0x79,0x40,0xc7,0x8c,0x73,0xfe,0x6f,0x2b,0xee,0x6c,0x03,0x52,
}
local D2 = fe_add(D, D)  -- 2*d

-- ── Scalar mod l ──────────────────────────────────────────────────────────────
-- Group order l = 2^252 + 27742317777372353535851937790883648493 (LE):
local L = {
    0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58,0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x10,
}

-- Reduce a 64-byte binary string (SHA-512 output) mod l.  Returns 32-byte LE array.
-- Uses double-and-add over 512 bits (MSB to LSB).
local function sc_reduce64(s)
    local bytes = {}; for i=1,64 do bytes[i] = s:byte(i) end
    local r = {}; for i=1,32 do r[i]=0 end
    for bit_idx = 511, 0, -1 do
        local byte_pos = math.floor(bit_idx/8) + 1
        local bit_val  = math.floor(bytes[byte_pos] / (2^(bit_idx%8))) % 2
        -- r = r * 2
        local carry = 0
        for i = 1, 32 do
            local v = r[i]*2 + carry; r[i] = v%256; carry = math.floor(v/256)
        end
        -- r += bit_val
        if bit_val == 1 then
            local c = 1
            for i = 1, 32 do
                local v = r[i]+c; r[i] = v%256; c = math.floor(v/256)
                if c == 0 then break end
            end
        end
        -- Conditional subtract if r >= l
        local ge = true
        for i = 32, 1, -1 do
            if r[i] < L[i] then ge=false; break
            elseif r[i] > L[i] then break end
        end
        if ge then
            local bw = 0
            for i = 1, 32 do
                local v = r[i]-L[i]-bw
                if v < 0 then v=v+256; bw=1 else bw=0 end
                r[i] = v
            end
        end
    end
    return r
end

-- ── Extended Edwards point arithmetic ────────────────────────────────────────
-- Points: {X, Y, Z, T}  with affine (x,y) = (X/Z, Y/Z) and T = X*Y/Z

local function pt_zero()
    local z={}; for i=1,32 do z[i]=0 end
    local o=fe_copy(FE_ONE)
    return {z, o, o, z}  -- (0,1,1,0) = identity
end

-- Unified point addition: add-2008-hwcd
local function pt_add(P, Q)
    local X1,Y1,Z1,T1 = P[1],P[2],P[3],P[4]
    local X2,Y2,Z2,T2 = Q[1],Q[2],Q[3],Q[4]
    local A  = fe_mul(fe_sub(Y1,X1), fe_sub(Y2,X2))
    local B  = fe_mul(fe_add(Y1,X1), fe_add(Y2,X2))
    local C  = fe_mul(fe_mul(T1,T2), D2)
    local Dv = fe_mul(fe_add(Z1,Z1), Z2)
    local E  = fe_sub(B, A)
    local F  = fe_sub(Dv, C)
    local G  = fe_add(Dv, C)
    local H  = fe_add(B, A)
    return {fe_mul(E,F), fe_mul(G,H), fe_mul(F,G), fe_mul(E,H)}
end

-- Point doubling: dbl-2008-hwcd
local function pt_dbl(P)
    local X,Y,Z = P[1],P[2],P[3]
    local A  = fe_sq(X); local B = fe_sq(Y)
    local C  = fe_add(fe_sq(Z), fe_sq(Z))
    local H  = fe_add(A, B)
    local E  = fe_sub(H, fe_sq(fe_add(X,Y)))
    local G  = fe_sub(A, B); local F = fe_add(C, G)
    return {fe_mul(E,F), fe_mul(G,H), fe_mul(F,G), fe_mul(E,H)}
end

-- Scalar multiply: k (32-byte LE array) times point P
local function pt_mul(k, P)
    local R = pt_zero()
    local Q = {fe_copy(P[1]),fe_copy(P[2]),fe_copy(P[3]),fe_copy(P[4])}
    for i = 1, 32 do
        local b = k[i]
        for _ = 1, 8 do
            if b%2 == 1 then R = pt_add(R, Q) end
            Q = pt_dbl(Q)
            b = math.floor(b/2)
        end
    end
    return R
end

-- Compress a point to a 32-byte string
local function pt_compress(P)
    local zinv = fe_inv(P[3])
    local x    = fe_mul(P[1], zinv)
    local y    = fe_mul(P[2], zinv)
    local ys   = fe_to_str(y)
    local last = ys:byte(32)
    if fe_is_neg(x) then last = last + 0x80 end
    return ys:sub(1,31) .. string.char(last)
end

-- Decompress a 32-byte string to an extended point; returns nil on failure
local function pt_decompress(s)
    if #s ~= 32 then return nil end
    local x_sign = band(s:byte(32), 0x80) ~= 0
    local y = fe_from_bytes(s, true)  -- mask top bit

    -- Recover x: x^2 = (y^2 - 1) / (d*y^2 + 1)
    local y2  = fe_sq(y)
    local u   = fe_sub(y2, FE_ONE)
    local v   = fe_add(fe_mul(D, y2), FE_ONE)

    -- Compute sqrt(u/v) using: x = (u*v^3) * (u*v^7)^((p-5)/8)
    local v2  = fe_sq(v);  local v3 = fe_mul(v,v2);  local v7 = fe_mul(v3,fe_sq(v2))
    local uv7 = fe_mul(u, v7)

    -- Exponentiate by (p-5)/8 = 2^252 - 3  (LE: FD, FF×30, 0F, 00)
    local exp = {}; exp[1]=0xFD; for i=2,31 do exp[i]=0xFF end; exp[32]=0x0F
    local acc = fe_copy(FE_ONE); local pw = fe_copy(uv7)
    for bi = 1, 32 do
        local bv = exp[bi] or 0
        for _ = 1, 8 do
            if bv%2 == 1 then acc = fe_mul(acc, pw) end
            pw = fe_sq(pw); bv = math.floor(bv/2)
        end
    end
    local x = fe_mul(fe_mul(u,v3), acc)

    -- Verify and fix sign
    local x2v = fe_mul(fe_sq(x), v)
    if fe_eq(x2v, u) then
        -- x is correct (up to sign)
    elseif fe_eq(x2v, fe_neg(u)) then
        x = fe_mul(x, SQRT_M1)  -- multiply by sqrt(-1) to get the other square root
    else
        return nil  -- u/v has no square root → point not on curve
    end

    if fe_is_neg(x) ~= x_sign then x = fe_neg(x) end

    -- Reject (0, sign=1)
    if fe_eq(x, FE_ZERO) and x_sign then return nil end

    local one = fe_copy(FE_ONE)
    return {x, y, one, fe_mul(x,y)}
end

-- ── Base point ────────────────────────────────────────────────────────────────
-- Gx LE: 1ad5258f602d56c9b2a7259560c72c695cdcd6fd31e2a4c0fe536ecdd3366921
local GX_LE = {
    0x1a,0xd5,0x25,0x8f,0x60,0x2d,0x56,0xc9,0xb2,0xa7,0x25,0x95,0x60,0xc7,0x2c,0x69,
    0x5c,0xdc,0xd6,0xfd,0x31,0xe2,0xa4,0xc0,0xfe,0x53,0x6e,0xcd,0xd3,0x36,0x69,0x21,
}
-- Gy LE: 5866666666666666666666666666666666666666666666666666666666666666
local GY_LE = {
    0x58,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
    0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
}

local _B = nil
local function get_base()
    if not _B then
        local gx = {}; for i=1,32 do gx[i]=GX_LE[i] end
        local gy = {}; for i=1,32 do gy[i]=GY_LE[i] end
        local one = fe_copy(FE_ONE)
        _B = {gx, gy, one, fe_mul(gx,gy)}
    end
    return _B
end

-- ── Public API ────────────────────────────────────────────────────────────────

function GSE_Ed25519Verify(pubkey, message, sig)
    if #pubkey ~= 32 or #sig ~= 64 then return false end

    local R_bytes = sig:sub(1, 32)
    local S_bytes = sig:sub(33, 64)

    -- Decode R and public key A as points
    local R_pt = pt_decompress(R_bytes)
    if not R_pt then return false end
    local A_pt = pt_decompress(pubkey)
    if not A_pt then return false end

    -- S must be in [0, l)
    local S_arr = {}; for i=1,32 do S_arr[i]=S_bytes:byte(i) end
    local s_lt_l = false
    for i = 32, 1, -1 do
        if S_arr[i] < L[i] then s_lt_l=true; break
        elseif S_arr[i] > L[i] then break end
    end
    if not s_lt_l then return false end

    -- k = SHA-512(R || A || M) mod l
    local h = GSE_SHA512(R_bytes .. pubkey .. message)
    local k = sc_reduce64(h)

    -- Verify: [S]B == R + [k]A
    local B   = get_base()
    local SB  = pt_mul(S_arr, B)
    local kA  = pt_mul(k, A_pt)
    local RkA = pt_add(R_pt, kA)

    return pt_compress(SB) == pt_compress(RkA)
end

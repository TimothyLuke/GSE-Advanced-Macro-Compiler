-- Pure Lua Ed25519 signature verification (RFC 8032).
-- Requires GSE_SHA512 (sha512.lua) loaded before this file.
-- Public: GSE_Ed25519Verify(pubkey_str, message_str, sig_str) -> boolean
-- All arguments are binary strings (32, any length, 64 bytes).
--
-- Speed matters here: a plugin pack carries dozens of signed sequences, and
-- WoW aborts a script run that takes too long (#2163). So:
--   - field elements are 16 limbs of 16 bits (as TweetNaCl), multiplied
--     straight into scratch tables, with no allocation in the hot loops;
--   - [S]B + [k](-A) is one joint pass over 4-bit windows, with the window
--     tables for B and for each public key built once and kept;
--   - the result is compressed and compared with R's bytes, so R is never
--     decompressed.

local floor = math.floor

-- ── Field arithmetic mod p = 2^255 - 19 ──────────────────────────────────────
-- An element is 16 numbers, limb i weighing 2^(16*(i-1)). Limbs may run past
-- 16 bits or go negative between operations: Lua numbers are doubles, exact
-- to 2^53, and fe_mul's products stay well under that.

local function fe_new()
    return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

local function fe_set(o, a)
    for i = 1, 16 do o[i] = a[i] end
end

local function fe_add(o, a, b)
    for i = 1, 16 do o[i] = a[i] + b[i] end
end

local function fe_sub(o, a, b)
    for i = 1, 16 do o[i] = a[i] - b[i] end
end

-- o = a * b. o may be a or b. Written out in full: the loop form ran three
-- times slower, and this is where nearly all the time goes.
local function fe_mul(o, a, b)
    local a1, a2, a3, a4, a5, a6, a7, a8 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]
    local a9, a10, a11, a12, a13, a14, a15, a16 = a[9], a[10], a[11], a[12], a[13], a[14], a[15], a[16]
    local b1, b2, b3, b4, b5, b6, b7, b8 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8]
    local b9, b10, b11, b12, b13, b14, b15, b16 = b[9], b[10], b[11], b[12], b[13], b[14], b[15], b[16]
    -- Column k of the product, with column k+16 folded in at 2^256 = 38 (mod p).
    local t1 = a1*b1
        + 38 * (a2*b16 + a3*b15 + a4*b14 + a5*b13 + a6*b12 + a7*b11 + a8*b10 + a9*b9 + a10*b8 + a11*b7 + a12*b6 + a13*b5 + a14*b4 + a15*b3 + a16*b2)
    local t2 = a1*b2 + a2*b1
        + 38 * (a3*b16 + a4*b15 + a5*b14 + a6*b13 + a7*b12 + a8*b11 + a9*b10 + a10*b9 + a11*b8 + a12*b7 + a13*b6 + a14*b5 + a15*b4 + a16*b3)
    local t3 = a1*b3 + a2*b2 + a3*b1
        + 38 * (a4*b16 + a5*b15 + a6*b14 + a7*b13 + a8*b12 + a9*b11 + a10*b10 + a11*b9 + a12*b8 + a13*b7 + a14*b6 + a15*b5 + a16*b4)
    local t4 = a1*b4 + a2*b3 + a3*b2 + a4*b1
        + 38 * (a5*b16 + a6*b15 + a7*b14 + a8*b13 + a9*b12 + a10*b11 + a11*b10 + a12*b9 + a13*b8 + a14*b7 + a15*b6 + a16*b5)
    local t5 = a1*b5 + a2*b4 + a3*b3 + a4*b2 + a5*b1
        + 38 * (a6*b16 + a7*b15 + a8*b14 + a9*b13 + a10*b12 + a11*b11 + a12*b10 + a13*b9 + a14*b8 + a15*b7 + a16*b6)
    local t6 = a1*b6 + a2*b5 + a3*b4 + a4*b3 + a5*b2 + a6*b1
        + 38 * (a7*b16 + a8*b15 + a9*b14 + a10*b13 + a11*b12 + a12*b11 + a13*b10 + a14*b9 + a15*b8 + a16*b7)
    local t7 = a1*b7 + a2*b6 + a3*b5 + a4*b4 + a5*b3 + a6*b2 + a7*b1
        + 38 * (a8*b16 + a9*b15 + a10*b14 + a11*b13 + a12*b12 + a13*b11 + a14*b10 + a15*b9 + a16*b8)
    local t8 = a1*b8 + a2*b7 + a3*b6 + a4*b5 + a5*b4 + a6*b3 + a7*b2 + a8*b1
        + 38 * (a9*b16 + a10*b15 + a11*b14 + a12*b13 + a13*b12 + a14*b11 + a15*b10 + a16*b9)
    local t9 = a1*b9 + a2*b8 + a3*b7 + a4*b6 + a5*b5 + a6*b4 + a7*b3 + a8*b2 + a9*b1
        + 38 * (a10*b16 + a11*b15 + a12*b14 + a13*b13 + a14*b12 + a15*b11 + a16*b10)
    local t10 = a1*b10 + a2*b9 + a3*b8 + a4*b7 + a5*b6 + a6*b5 + a7*b4 + a8*b3 + a9*b2 + a10*b1
        + 38 * (a11*b16 + a12*b15 + a13*b14 + a14*b13 + a15*b12 + a16*b11)
    local t11 = a1*b11 + a2*b10 + a3*b9 + a4*b8 + a5*b7 + a6*b6 + a7*b5 + a8*b4 + a9*b3 + a10*b2 + a11*b1
        + 38 * (a12*b16 + a13*b15 + a14*b14 + a15*b13 + a16*b12)
    local t12 = a1*b12 + a2*b11 + a3*b10 + a4*b9 + a5*b8 + a6*b7 + a7*b6 + a8*b5 + a9*b4 + a10*b3 + a11*b2 + a12*b1
        + 38 * (a13*b16 + a14*b15 + a15*b14 + a16*b13)
    local t13 = a1*b13 + a2*b12 + a3*b11 + a4*b10 + a5*b9 + a6*b8 + a7*b7 + a8*b6 + a9*b5 + a10*b4 + a11*b3 + a12*b2 + a13*b1
        + 38 * (a14*b16 + a15*b15 + a16*b14)
    local t14 = a1*b14 + a2*b13 + a3*b12 + a4*b11 + a5*b10 + a6*b9 + a7*b8 + a8*b7 + a9*b6 + a10*b5 + a11*b4 + a12*b3 + a13*b2 + a14*b1
        + 38 * (a15*b16 + a16*b15)
    local t15 = a1*b15 + a2*b14 + a3*b13 + a4*b12 + a5*b11 + a6*b10 + a7*b9 + a8*b8 + a9*b7 + a10*b6 + a11*b5 + a12*b4 + a13*b3 + a14*b2 + a15*b1
        + 38 * (a16*b16)
    local t16 = a1*b16 + a2*b15 + a3*b14 + a4*b13 + a5*b12 + a6*b11 + a7*b10 + a8*b9 + a9*b8 + a10*b7 + a11*b6 + a12*b5 + a13*b4 + a14*b3 + a15*b2 + a16*b1
    local c
    for _ = 1, 2 do
        c = floor(t1 / 65536); t1 = t1 - c * 65536; t2 = t2 + c
        c = floor(t2 / 65536); t2 = t2 - c * 65536; t3 = t3 + c
        c = floor(t3 / 65536); t3 = t3 - c * 65536; t4 = t4 + c
        c = floor(t4 / 65536); t4 = t4 - c * 65536; t5 = t5 + c
        c = floor(t5 / 65536); t5 = t5 - c * 65536; t6 = t6 + c
        c = floor(t6 / 65536); t6 = t6 - c * 65536; t7 = t7 + c
        c = floor(t7 / 65536); t7 = t7 - c * 65536; t8 = t8 + c
        c = floor(t8 / 65536); t8 = t8 - c * 65536; t9 = t9 + c
        c = floor(t9 / 65536); t9 = t9 - c * 65536; t10 = t10 + c
        c = floor(t10 / 65536); t10 = t10 - c * 65536; t11 = t11 + c
        c = floor(t11 / 65536); t11 = t11 - c * 65536; t12 = t12 + c
        c = floor(t12 / 65536); t12 = t12 - c * 65536; t13 = t13 + c
        c = floor(t13 / 65536); t13 = t13 - c * 65536; t14 = t14 + c
        c = floor(t14 / 65536); t14 = t14 - c * 65536; t15 = t15 + c
        c = floor(t15 / 65536); t15 = t15 - c * 65536; t16 = t16 + c
        c = floor(t16 / 65536); t16 = t16 - c * 65536; t1 = t1 + 38 * c
    end
    o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8] = t1, t2, t3, t4, t5, t6, t7, t8
    o[9], o[10], o[11], o[12], o[13], o[14], o[15], o[16] = t9, t10, t11, t12, t13, t14, t15, t16
end

local function fe_sq(o, a) fe_mul(o, a, a) end

-- p, as limbs.
local P = {0xffed}
for i = 2, 15 do P[i] = 0xffff end
P[16] = 0x7fff

-- Fully reduced limbs of a, in [0, p).
local function fe_reduce(a)
    local t = {}
    for i = 1, 16 do t[i] = a[i] end
    repeat
        local c = 0
        for i = 1, 16 do
            local v = t[i] + c
            c = floor(v / 65536)
            t[i] = v - c * 65536
        end
        t[1] = t[1] + 38 * c
    until c == 0
    for _ = 1, 2 do
        local ge = true
        for i = 16, 1, -1 do
            if t[i] ~= P[i] then ge = t[i] > P[i]; break end
        end
        if not ge then break end
        local borrow = 0
        for i = 1, 16 do
            local v = t[i] - P[i] - borrow
            if v < 0 then v = v + 65536; borrow = 1 else borrow = 0 end
            t[i] = v
        end
    end
    return t
end

local function fe_to_str(a)
    local t = fe_reduce(a)
    local s = {}
    for i = 1, 16 do
        s[2 * i - 1] = string.char(t[i] % 256)
        s[2 * i] = string.char(floor(t[i] / 256))
    end
    return table.concat(s)
end

local function fe_from_bytes(bytes, mask_top)
    local f = {}
    for i = 1, 16 do f[i] = bytes[2 * i - 1] + 256 * bytes[2 * i] end
    if mask_top then f[16] = f[16] % 0x8000 end
    return f
end

local function fe_from_str(s, mask_top)
    local bytes = {s:byte(1, 32)}
    return fe_from_bytes(bytes, mask_top)
end

local function fe_eq(a, b)
    return fe_to_str(a) == fe_to_str(b)
end

local function fe_is_neg(a)  -- x mod 2 == 1 is "negative" in RFC 8032
    return fe_reduce(a)[1] % 2 == 1
end

-- a^(p-2) = 1/a
local function fe_inv(o, a)
    local z2, z9, z11, t, u = fe_new(), fe_new(), fe_new(), fe_new(), fe_new()
    local function sqn(x, n) for _ = 1, n do fe_sq(x, x) end end
    fe_sq(z2, a)                                  -- 2
    fe_sq(t, z2); fe_sq(t, t)                     -- 8
    fe_mul(z9, t, a)                              -- 9
    fe_mul(z11, z9, z2)                           -- 11
    fe_sq(t, z11); fe_mul(t, t, z9)               -- 2^5 - 1
    fe_set(u, t); sqn(u, 5); fe_mul(u, u, t)      -- 2^10 - 1
    local t10 = fe_new(); fe_set(t10, u)
    sqn(u, 10); fe_mul(u, u, t10)                 -- 2^20 - 1
    local t20 = fe_new(); fe_set(t20, u)
    sqn(u, 20); fe_mul(u, u, t20)                 -- 2^40 - 1
    sqn(u, 10); fe_mul(u, u, t10)                 -- 2^50 - 1
    local t50 = fe_new(); fe_set(t50, u)
    sqn(u, 50); fe_mul(u, u, t50)                 -- 2^100 - 1
    local t100 = fe_new(); fe_set(t100, u)
    sqn(u, 100); fe_mul(u, u, t100)               -- 2^200 - 1
    sqn(u, 50); fe_mul(u, u, t50)                 -- 2^250 - 1
    sqn(u, 5); fe_mul(o, u, z11)                  -- 2^255 - 21
end

-- a^((p-5)/8) = a^(2^252 - 3), for the square root. Only run once per key.
local function fe_pow2523(o, a)
    local c = fe_new()
    fe_set(c, a)
    for e = 250, 0, -1 do
        fe_sq(c, c)
        if e ~= 1 then fe_mul(c, c, a) end
    end
    fe_set(o, c)
end

-- ── Curve constants ───────────────────────────────────────────────────────────
-- d = -121665/121666 mod p, little-endian bytes
local D = fe_from_bytes({
    0xa3,0x78,0x59,0x13,0xca,0x4d,0xeb,0x75,0xab,0xd8,0x41,0x41,0x4d,0x0a,0x70,0x00,
    0x98,0xe8,0x79,0x77,0x79,0x40,0xc7,0x8c,0x73,0xfe,0x6f,0x2b,0xee,0x6c,0x03,0x52,
})
local D2 = fe_new(); fe_add(D2, D, D)

-- sqrt(-1) mod p, little-endian bytes
local SQRT_M1 = fe_from_bytes({
    0xb0,0xa0,0x0e,0x4a,0x27,0x1b,0xee,0xc4,0x78,0xe4,0x2f,0xad,0x06,0x18,0x43,0x2f,
    0xa7,0xd7,0xfb,0x3d,0x99,0x00,0x4d,0x2b,0x0b,0xdf,0xc1,0x4f,0x80,0x24,0x83,0x2b,
})

local FE_ZERO = fe_new()
local FE_ONE = fe_new(); FE_ONE[1] = 1

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
        local byte_pos = floor(bit_idx/8) + 1
        local bit_val  = floor(bytes[byte_pos] / (2^(bit_idx%8))) % 2
        -- r = r * 2
        local carry = 0
        for i = 1, 32 do
            local v = r[i]*2 + carry; r[i] = v%256; carry = floor(v/256)
        end
        -- r += bit_val
        if bit_val == 1 then
            local c = 1
            for i = 1, 32 do
                local v = r[i]+c; r[i] = v%256; c = floor(v/256)
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

local function pt_new()
    return {fe_new(), fe_new(), fe_new(), fe_new()}
end

local function pt_set(R, P)
    for i = 1, 4 do fe_set(R[i], P[i]) end
end

local function pt_identity(R)
    fe_set(R[1], FE_ZERO); fe_set(R[2], FE_ONE); fe_set(R[3], FE_ONE); fe_set(R[4], FE_ZERO)
end

local ta, tb, tc, td, te, tf, tg, th = fe_new(), fe_new(), fe_new(), fe_new(),
    fe_new(), fe_new(), fe_new(), fe_new()

-- R = P + Q (add-2008-hwcd-3; complete, so the identity and P == Q are fine).
-- R may be P or Q.
local function pt_add(R, P, Q)
    fe_sub(ta, P[2], P[1]); fe_sub(tb, Q[2], Q[1]); fe_mul(ta, ta, tb)
    fe_add(tb, P[2], P[1]); fe_add(tc, Q[2], Q[1]); fe_mul(tb, tb, tc)
    fe_mul(tc, P[4], Q[4]); fe_mul(tc, tc, D2)
    fe_mul(td, P[3], Q[3]); fe_add(td, td, td)
    fe_sub(te, tb, ta)
    fe_sub(tf, td, tc)
    fe_add(tg, td, tc)
    fe_add(th, tb, ta)
    fe_mul(R[1], te, tf)
    fe_mul(R[2], tg, th)
    fe_mul(R[3], tf, tg)
    fe_mul(R[4], te, th)
end

-- R = 2P (dbl-2008-hwcd). R may be P.
local function pt_dbl(R, P)
    fe_sq(ta, P[1])
    fe_sq(tb, P[2])
    fe_sq(tc, P[3]); fe_add(tc, tc, tc)
    fe_add(th, ta, tb)
    fe_add(te, P[1], P[2]); fe_sq(te, te); fe_sub(te, th, te)
    fe_sub(tg, ta, tb)
    fe_add(tf, tc, tg)
    fe_mul(R[1], te, tf)
    fe_mul(R[2], tg, th)
    fe_mul(R[3], tf, tg)
    fe_mul(R[4], te, th)
end

-- Compress a point to a 32-byte string
local function pt_compress(P)
    local zinv, x, y = fe_new(), fe_new(), fe_new()
    fe_inv(zinv, P[3])
    fe_mul(x, P[1], zinv)
    fe_mul(y, P[2], zinv)
    local ys   = fe_to_str(y)
    local last = ys:byte(32)
    if fe_is_neg(x) then last = last + 0x80 end
    return ys:sub(1,31) .. string.char(last)
end

-- Decompress a 32-byte string to an extended point; returns nil on failure
local function pt_decompress(s)
    if #s ~= 32 then return nil end
    local x_sign = s:byte(32) >= 0x80
    local y = fe_from_str(s, true)  -- mask top bit

    -- Recover x: x^2 = (y^2 - 1) / (d*y^2 + 1)
    local y2, u, v = fe_new(), fe_new(), fe_new()
    fe_sq(y2, y)
    fe_sub(u, y2, FE_ONE)
    fe_mul(v, D, y2); fe_add(v, v, FE_ONE)

    -- x = (u*v^3) * (u*v^7)^((p-5)/8)
    local v3, v7, x = fe_new(), fe_new(), fe_new()
    fe_sq(v3, v); fe_mul(v3, v3, v)
    fe_sq(v7, v3); fe_mul(v7, v7, v)
    fe_mul(x, u, v7)
    fe_pow2523(x, x)
    fe_mul(x, x, v3); fe_mul(x, x, u)

    -- Verify and fix sign
    local x2v, negu = fe_new(), fe_new()
    fe_sq(x2v, x); fe_mul(x2v, x2v, v)
    fe_sub(negu, FE_ZERO, u)
    if fe_eq(x2v, u) then
        -- x is correct (up to sign)
    elseif fe_eq(x2v, negu) then
        fe_mul(x, x, SQRT_M1)  -- the other square root
    else
        return nil  -- u/v has no square root → point not on curve
    end

    if fe_is_neg(x) ~= x_sign then fe_sub(x, FE_ZERO, x) end

    -- Reject (0, sign=1)
    if x_sign and fe_eq(x, FE_ZERO) then return nil end

    local P = pt_new()
    fe_set(P[1], x); fe_set(P[2], y); fe_set(P[3], FE_ONE); fe_mul(P[4], x, y)
    return P
end

-- tbl[j] = j*P for j = 1..15
local function window_table(P)
    local tbl = {pt_new()}
    pt_set(tbl[1], P)
    for j = 2, 15 do
        tbl[j] = pt_new()
        pt_add(tbl[j], tbl[j - 1], P)
    end
    return tbl
end

-- ── Base point ────────────────────────────────────────────────────────────────
-- Gx LE: 1ad5258f602d56c9b2a7259560c72c695cdcd6fd31e2a4c0fe536ecdd3366921
-- Gy LE: 5866666666666666666666666666666666666666666666666666666666666666

local base_table = nil
local function get_base_table()
    if not base_table then
        local B = pt_new()
        fe_set(B[1], fe_from_bytes({
            0x1a,0xd5,0x25,0x8f,0x60,0x2d,0x56,0xc9,0xb2,0xa7,0x25,0x95,0x60,0xc7,0x2c,0x69,
            0x5c,0xdc,0xd6,0xfd,0x31,0xe2,0xa4,0xc0,0xfe,0x53,0x6e,0xcd,0xd3,0x36,0x69,0x21,
        }))
        fe_set(B[2], fe_from_bytes({
            0x58,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
            0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
        }))
        fe_set(B[3], FE_ONE)
        fe_mul(B[4], B[1], B[2])
        base_table = window_table(B)
    end
    return base_table
end

-- Window tables of -A, per public key. In practice there is one key: the
-- platform's.
local neg_key_tables = {}
local function get_neg_key_table(pubkey)
    local tbl = neg_key_tables[pubkey]
    if tbl == nil then
        local A = pt_decompress(pubkey)
        if A then
            fe_sub(A[1], FE_ZERO, A[1])
            fe_sub(A[4], FE_ZERO, A[4])
            tbl = window_table(A)
        else
            tbl = false
        end
        neg_key_tables[pubkey] = tbl
    end
    return tbl
end

-- 64 four-bit digits of a 32-byte LE array, least significant first.
local function nibbles(k)
    local n = {}
    for i = 1, 32 do
        n[2 * i - 1] = k[i] % 16
        n[2 * i] = floor(k[i] / 16)
    end
    return n
end

-- ── Public API ────────────────────────────────────────────────────────────────

function GSE_Ed25519Verify(pubkey, message, sig)
    if #pubkey ~= 32 or #sig ~= 64 then return false end

    local R_bytes = sig:sub(1, 32)
    local S_bytes = sig:sub(33, 64)

    local negA = get_neg_key_table(pubkey)
    if not negA then return false end

    -- S must be in [0, l)
    local S_arr = {S_bytes:byte(1, 32)}
    local s_lt_l = false
    for i = 32, 1, -1 do
        if S_arr[i] < L[i] then s_lt_l=true; break
        elseif S_arr[i] > L[i] then break end
    end
    if not s_lt_l then return false end

    -- k = SHA-512(R || A || M) mod l
    local k = sc_reduce64(GSE_SHA512(R_bytes .. pubkey .. message))

    -- [S]B + [k](-A) must come out as R.
    local Bt = get_base_table()
    local sn, kn = nibbles(S_arr), nibbles(k)
    local acc = pt_new()
    pt_identity(acc)
    local started = false
    for i = 64, 1, -1 do
        if started then
            pt_dbl(acc, acc); pt_dbl(acc, acc); pt_dbl(acc, acc); pt_dbl(acc, acc)
        end
        if sn[i] ~= 0 then pt_add(acc, acc, Bt[sn[i]]); started = true end
        if kn[i] ~= 0 then pt_add(acc, acc, negA[kn[i]]); started = true end
    end

    return pt_compress(acc) == R_bytes
end

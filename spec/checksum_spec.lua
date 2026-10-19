---@diagnostic disable: undefined-global

-- ── Helper: bytes to lowercase hex ────────────────────────────────────────────
local function to_hex(s)
    local h = ""
    for i = 1, #s do h = h .. string.format("%02x", s:byte(i)) end
    return h
end

-- ── Load modules ──────────────────────────────────────────────────────────────
describe("Checksum API", function()
    setup(function()
        -- bit library shim for Lua 5.3+.
        -- In CI (Lua 5.1 + luabitop) and in WoW (LuaJIT), _G.bit is already provided,
        -- so this block is skipped entirely.
        -- On Lua 5.3+/5.5 without luabitop (local dev), we compile the shim via
        -- load/loadstring so that the 5.3+ operators (&, |, ~, >>, <<) are never
        -- seen by the Lua 5.1 parser — the whole file must be valid Lua 5.1 syntax.
        -- Note: busted sandboxes spec files, so we assign to G explicitly.
        if not _G.bit then
            -- luabitop (Lua 5.1 via luarocks) exposes as require("bit"), not _G.bit
            pcall(function() _G.bit = require("bit") end)
        end
        if not _G.bit then
            local src = [[
                local M = 0xFFFFFFFF
                _G.bit = {
                    band   = function(a, b) return (a & b) & M end,
                    bor    = function(a, ...)
                        local r = a & M
                        for _, v in ipairs({...}) do r = r | (v & M) end
                        return r & M
                    end,
                    bxor   = function(a, ...)
                        local r = a & M
                        for _, v in ipairs({...}) do r = r ~ (v & M) end
                        return r & M
                    end,
                    lshift = function(a, n) return ((a & M) << n) & M end,
                    rshift = function(a, n) return ((a & M) >> n) & M end,
                }
            ]]
            local fn = (loadstring or load)(src)
            if fn then fn() end
            -- If fn is nil the runtime doesn't support 5.3+ syntax (Lua 5.1 without
            -- luabitop).  In that case _G.bit remains nil and the tests will error,
            -- which is the right signal: install luabitop (see ci.yml).
        end

        -- WoW globals needed by Checksum.lua v1 algorithm (must be on G for same reason)
        _G.WOW_PROJECT_ID    = 1
        _G.GetExpansionLevel = function() return 0 end

        require("../spec/mockGSE")
        require("../GSE/API/sha512")
        require("../GSE/API/ed25519verify")
        require("../GSE/API/Checksum")
    end)

    -- ── SHA-512 test vectors ───────────────────────────────────────────────────
    describe("GSE_SHA512", function()
        it("produces the correct hash for an empty string", function()
            -- NIST FIPS 180-4 test vector
            local expected = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce"
                          .. "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
            local h = GSE_SHA512("")
            assert.equal(64, #h)
            assert.equal(expected, to_hex(h))
        end)

        it("produces the correct hash for 'abc'", function()
            -- NIST FIPS 180-4 test vector
            local expected = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                          .. "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
            local h = GSE_SHA512("abc")
            assert.equal(64, #h)
            assert.equal(expected, to_hex(h))
        end)
    end)

    -- ── VerifySequenceChecksum — structural edge cases ─────────────────────────
    describe("VerifySequenceChecksum — structural checks", function()
        it("returns false when sequence is not a table", function()
            assert.is_false(GSE.VerifySequenceChecksum(nil))
            assert.is_false(GSE.VerifySequenceChecksum(42))
        end)

        it("returns 'no_checksum' when MetaData is absent", function()
            assert.equal("no_checksum", GSE.VerifySequenceChecksum({ Versions = {} }))
        end)

        it("returns 'no_checksum' when Checksum field is absent", function()
            assert.equal("no_checksum", GSE.VerifySequenceChecksum({ MetaData = {} }))
        end)

        it("returns 'no_checksum' for a malformed checksum (no colon)", function()
            assert.equal("no_checksum", GSE.VerifySequenceChecksum({
                MetaData = { Checksum = "garbage" },
                Versions = {},
            }))
        end)

        it("returns 'no_checksum' for a malformed checksum (wrong prefix)", function()
            assert.equal("no_checksum", GSE.VerifySequenceChecksum({
                MetaData = { Checksum = "x1:abcdef" },
                Versions = {},
            }))
        end)

        -- ── KEY REQUIREMENT: unregistered version must FAIL, not silently pass ──
        it("returns false for an unregistered algorithm version v6:asdfg", function()
            -- A forged 'v99:anything' must not pass through as 'no_checksum'
            assert.is_false(GSE.VerifySequenceChecksum({
                MetaData = { Checksum = "v6:asdfg" },
                Versions = {},
            }))
        end)

        it("returns false for v99 (another unregistered version)", function()
            assert.is_false(GSE.VerifySequenceChecksum({
                MetaData = { Checksum = "v99:aabbcc112233" },
                Versions = {},
            }))
        end)
    end)

    -- ── v1 checksum (FNV-1a) ──────────────────────────────────────────────────
    describe("VerifySequenceChecksum — v1 (FNV-1a)", function()
        local seq

        before_each(function()
            seq = {
                Versions = {
                    [1] = {
                        Actions  = { [1] = "/cast Fireball" },
                        KeyPress = {},
                    },
                },
            }
        end)

        it("correct v1 checksum verifies as true", function()
            local cs = GSE.ComputeSequenceChecksum(seq)
            assert.is_not_nil(cs)
            assert.is_truthy(cs:match("^v1:"))
            seq.MetaData = { Checksum = cs }
            assert.is_true(GSE.VerifySequenceChecksum(seq))
        end)

        it("tampered action causes v1 verify to return false", function()
            local cs = GSE.ComputeSequenceChecksum(seq)
            seq.Versions[1].Actions[1] = "/cast Pyroblast"  -- tamper
            seq.MetaData = { Checksum = cs }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)

        it("wrong v1 hash value returns false", function()
            seq.MetaData = { Checksum = "v1:00000000" }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)
    end)

    -- ── v2 checksum (Ed25519) ─────────────────────────────────────────────────
    --
    -- Test signature was generated server-side with the dev private key whose
    -- matching public key is embedded in Checksum.lua:
    --   b531cb8b505ae9752b5b789f26085853b0ba5da5d7e7e244975f0545430d683a
    --
    -- Versions table (as Lua after CBOR round-trip):
    --   { [1] = { Actions = { [1] = { action="spell", spell=1234 } }, Label="v1" } }
    -- Canonical JSON:
    --   {"1":{"Actions":{"1":{"action":"spell","spell":1234}},"Label":"v1"}}
    --
    local VALID_VERSIONS = {
        [1] = {
            Actions = { [1] = { action = "spell", spell = 1234 } },
            Label   = "v1",
        },
    }
    local VALID_SIG = "v2:MUw_FfK1rFye_2pwNgghqKwOinj15J5skp3xTl4rbyWqn4Cgm6OkLx8VJ5srlQ0J1YtIbmdsWKuGTskFJBMRAg"

    describe("VerifySequenceChecksum — v2 (Ed25519)", function()
        it("valid platform signature returns true", function()
            local seq = {
                Versions = VALID_VERSIONS,
                MetaData = { Checksum = VALID_SIG },
            }
            assert.is_true(GSE.VerifySequenceChecksum(seq))
        end)

        it("tampered spell ID causes v2 verify to return false", function()
            local tampered = {
                [1] = {
                    Actions = { [1] = { action = "spell", spell = 9999 } },
                    Label   = "v1",
                },
            }
            local seq = {
                Versions = tampered,
                MetaData = { Checksum = VALID_SIG },
            }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)

        it("truncated signature returns false", function()
            local seq = {
                Versions = VALID_VERSIONS,
                MetaData = { Checksum = "v2:AAAA" },
            }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)

        it("correct-length but wrong signature returns false", function()
            -- 88 base64url chars = 66 bytes decoded; wrong content
            local seq = {
                Versions = VALID_VERSIONS,
                MetaData = { Checksum = "v2:" .. string.rep("A", 88) },
            }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)

        it("missing Versions returns false", function()
            local seq = { MetaData = { Checksum = VALID_SIG } }
            assert.is_false(GSE.VerifySequenceChecksum(seq))
        end)
    end)

    -- ── GSE_Ed25519Verify against RFC 8032 §7.1 ───────────────────────────────
    describe("GSE_Ed25519Verify — RFC 8032 test vectors", function()
        local function unhex(h)
            return (h:gsub("..", function(c) return string.char(tonumber(c, 16)) end))
        end
        local vectors = {
            { "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", "",
              "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b" },
            { "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c", "72",
              "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00" },
            { "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025", "af82",
              "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a" },
        }

        it("accepts each vector", function()
            for _, v in ipairs(vectors) do
                assert.is_true(GSE_Ed25519Verify(unhex(v[1]), unhex(v[2]), unhex(v[3])))
            end
        end)

        it("rejects a vector with any one bit of the message, R or S flipped", function()
            local pub, msg, sig = unhex(vectors[3][1]), unhex(vectors[3][2]), unhex(vectors[3][3])
            local function flip(s, i, b)
                return s:sub(1, i - 1) .. string.char((s:byte(i) + b) % 256) .. s:sub(i + 1)
            end
            assert.is_false(GSE_Ed25519Verify(pub, flip(msg, 1, 1), sig))
            assert.is_false(GSE_Ed25519Verify(pub, msg, flip(sig, 1, 1)))    -- R
            assert.is_false(GSE_Ed25519Verify(pub, msg, flip(sig, 40, 4)))  -- S
            -- the same signature under another vector's key
            assert.is_false(GSE_Ed25519Verify(unhex(vectors[1][1]), msg, sig))
        end)

        it("rejects S >= l (a malleated signature)", function()
            local pub, msg, sig = unhex(vectors[1][1]), unhex(vectors[1][2]), unhex(vectors[1][3])
            -- S + l, little-endian byte add
            local L = { 0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58,0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14,
                        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0x10 }
            local out, carry = {}, 0
            for i = 1, 32 do
                local v = sig:byte(32 + i) + L[i] + carry
                out[i] = string.char(v % 256); carry = math.floor(v / 256)
            end
            assert.is_false(GSE_Ed25519Verify(pub, msg, sig:sub(1, 32) .. table.concat(out)))
        end)
    end)
end)

---@diagnostic disable: undefined-global

-- GSE.GameMode gates API availability, not content.
--
-- Forever (1.60.x) is vanilla-era content on Retail's API surface, so taken at
-- face value its major is 1 -- Classic Era -- and every `GameMode > x` test in
-- GSE inverts: retail paths off, classic paths on. It must report the
-- generation whose APIs it actually has.
--
-- Init.lua cannot be loaded here (LibStub, AceEvent/AceComm/AceLocale,
-- WagoAnalytics, C_AddOns), so this lifts the derivation block out of the
-- shipped file and runs it. That means it tests the real source rather than a
-- copy of the rule: change the constants in Init.lua and this fails.
local function derivationChunk()
    local fh = assert(io.open("GSE/API/Init.lua", "r"), "cannot open GSE/API/Init.lua")
    local src = fh:read("*a")
    fh:close()
    local block = src:match("(local FOREVER_MAJOR.-GSE%.GameMode = gameMode)")
    assert(block, "GameMode derivation block not found in Init.lua -- did it get rewritten?")
    -- loadstring on 5.1 (what CI runs), load on 5.4 (what busted runs).
    local compile = loadstring or load
    return assert(compile("local majorVersion, GSE = ...\n" .. block .. "\nreturn GSE.GameMode"))
end

local function gameModeFor(versionString)
    local parts = {}
    for piece in string.gmatch(versionString, "[^.]+") do
        parts[#parts + 1] = piece
    end
    return derivationChunk()(parts, {})
end

describe("GSE.GameMode derivation", function()
    it("reads retail's major directly", function()
        assert.equals(12, gameModeFor("12.1.0"))   -- Midnight, live
        assert.equals(11, gameModeFor("11.0.5"))   -- TWW
        assert.equals(5,  gameModeFor("5.5.4"))    -- MoP Classic
        assert.equals(2,  gameModeFor("2.5.6"))    -- Anniversary
    end)

    it("leaves Classic Era on 1", function()
        assert.equals(1, gameModeFor("1.15.9"))    -- Classic Era, live
        assert.equals(1, gameModeFor("1.12.1"))    -- original vanilla
    end)

    -- The whole point. 1.60.x carries Retail's APIs, so every `> x` test has to
    -- be true for it, which only happens if it reports the API generation.
    it("reports Forever as the API generation it actually has", function()
        assert.equals(12, gameModeFor("1.60.1"))   -- Forever, build 1.60.1.69876
        assert.equals(12, gameModeFor("1.60.5"))   -- a later Forever patch
    end)

    it("keeps every retail gate true on Forever", function()
        local mode = gameModeFor("1.60.1")
        assert.is_true(mode > 10)    -- Settings menu API, Button Binding popup
        assert.is_true(mode >= 11)   -- UNIT_SPELLCAST_EMPOWER_*, Skyriding options
        assert.is_true(mode >= 12)   -- C_SpecializationInfo, retail-only Library walk
        assert.is_false(mode < 7)    -- classic-only paths stay off
        assert.is_false(mode <= 4)
        assert.is_false(mode == 5)   -- not MoP
    end)

    -- Deliberately 12, not "current retail". When The Last Titan adds APIs at
    -- 13 a `>= 13` test must be FALSE on Forever until Forever ships them --
    -- and picking an ordinal ABOVE retail would burn a number retail reaches.
    it("does not claim APIs newer than the generation it has", function()
        assert.is_false(gameModeFor("1.60.1") >= 13)
    end)
end)

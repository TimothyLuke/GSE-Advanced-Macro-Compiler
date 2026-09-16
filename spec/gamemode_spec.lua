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
-- .gitattributes marks *.lua as eol=crlf, so the blob is stored LF and every
-- checkout -- including CI's -- writes CRLF. Any pattern here anchored on "\n"
-- then fails against a "\r\n" file while passing on a freshly written one,
-- which is exactly how this spec went green locally and errored in CI. Normalise
-- once, on read, and let the patterns below stay line-ending agnostic.
local function readInit()
    local fh = assert(io.open("GSE/API/Init.lua", "r"), "cannot open GSE/API/Init.lua")
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function derivationChunk()
    local src = readInit()
    local block = src:match("(local FOREVER_MAJOR.-GSE%.GameMode = gameMode)")
    assert(block, "GameMode derivation block not found in Init.lua -- did it get rewritten?")
    -- loadstring on 5.1 (what CI runs), load on 5.4 (what busted runs).
    local compile = loadstring or load
    return assert(compile("local majorVersion, GSE = ...\n" .. block .. "\nreturn GSE.GameMode"))
end

-- The same lift, extended through GSE.TOCFlavour so the flavour rule is tested
-- from the shipped source as well. Both live in one contiguous block under the
-- FOREVER constants precisely so one extraction covers them.
local function flavourChunk()
    local src = readInit()
    -- Anchored on the final return only, not on the "end" that follows it: the
    -- closing "end" is supplied below, so neither a line ending nor an extra
    -- line inside the function can break the lift.
    local block = src:match('(local FOREVER_MAJOR.-return "exp" %.%. tocMajor)')
    assert(block, "GSE.TOCFlavour block not found in Init.lua -- did it get rewritten?")
    local compile = loadstring or load
    local chunk = assert(compile(
        "local majorVersion, GSE = ...\n" .. block .. "\nend\nreturn GSE.TOCFlavour"))
    return chunk({"12", "1", "0"}, {})
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

-- GSE.TOCFlavour answers "are these two TOCs the same flavour" for a stamped
-- sequence TOC, which is a different question from GameMode's API gating.
describe("GSE.TOCFlavour", function()
    local flavour = flavourChunk()

    it("treats patches of one flavour as the same flavour", function()
        assert.equals(flavour(120001), flavour(120005))   -- both Midnight
        assert.equals(flavour(11509), flavour(11502))     -- both Classic Era
        assert.equals(flavour(16001), flavour(16005))     -- both Forever
    end)

    it("separates different flavours", function()
        assert.are_not.equals(flavour(120001), flavour(110005))  -- Midnight vs TWW
        assert.are_not.equals(flavour(50500), flavour(20405))    -- MoP vs TBC
    end)

    -- The bug this exists for. Both reduce to major 1, so the old
    -- math.floor(toc / 10000) comparison saw them as the same flavour and
    -- crossing between two opposite rulesets warned about nothing.
    it("separates Forever from Classic Era", function()
        assert.are_not.equals(flavour(16001), flavour(11509))
        assert.equals("forever", flavour(16001))
        assert.equals("exp1", flavour(11509))
    end)

    -- Forever's key must never be a number, or it collides with a major that
    -- retail reaches on its own -- the same trap as picking an ordinal above 12.
    it("keys Forever outside the numeric majors", function()
        assert.equals("string", type(flavour(16001)))
        assert.are_not.equals(flavour(16001), flavour(160001))
    end)

    it("returns nil for a missing or unusable TOC", function()
        assert.is_nil(flavour(nil))
        assert.is_nil(flavour(""))
        assert.is_nil(flavour(0))
        assert.is_nil(flavour("nonsense"))
    end)
end)

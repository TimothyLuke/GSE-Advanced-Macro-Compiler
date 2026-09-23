---@diagnostic disable: undefined-global

-- Which "loadout" keybindings and action bar overrides are stored under.
--
-- Retail partitions by saved loadout, which works because a loadout is 1:1 with
-- the build being played. WoW Forever has no saved loadouts -- it has DUAL SPEC
-- and one specialisation per class -- so both builds produced the same key
-- (GetSpec() is always "1" there, and GetLastSelectedSavedConfigID returns
-- nothing). Primary and Secondary shared one set of binds, and switching
-- rebuilt them to exactly what they already were.
--
-- Lifted from the shipped file. .gitattributes marks *.lua eol=crlf; normalise
-- on read (see CLAUDE.md).
local function liftKey(env)
    local fh = assert(io.open("GSE/API/CharacterFunctions.lua", "r"))
    local src = fh:read("*a")
    fh:close()
    src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local block = src:match("(function GSE%.GetBindingLoadoutKey%(%).-\n    return tostring%(saved%)\nend)")
    assert(block, "GetBindingLoadoutKey not found in CharacterFunctions.lua")
    local compile = loadstring or load
    local chunk = assert(compile(
        "local GSE, C_ClassTalents, C_SpecializationInfo, GetNumSpecGroups = ...\n"
        .. block .. "\nreturn GSE.GetBindingLoadoutKey"))
    return chunk(env.GSE, env.C_ClassTalents, env.C_SpecializationInfo, env.GetNumSpecGroups)
end

local function env(specID, savedConfigID, numGroups, activeGroup)
    return {
        GSE = { GetCurrentSpecID = function() return specID end },
        C_ClassTalents = { GetLastSelectedSavedConfigID = function() return savedConfigID end },
        C_SpecializationInfo = { GetActiveSpecGroup = function() return activeGroup end },
        GetNumSpecGroups = function() return numGroups end,
    }
end

describe("GetBindingLoadoutKey", function()
    -- Retail: a real saved loadout always wins, unchanged.
    it("uses the saved loadout id when there is one", function()
        local key = liftKey(env(70, 12345, 1, 1))
        assert.equals("12345", key())
    end)

    it("prefers the saved loadout even on a dual-spec client", function()
        local key = liftKey(env(70, 12345, 2, 2))
        assert.equals("12345", key(), "a real loadout is more specific than a spec group")
    end)

    -- Forever: no loadouts, two spec groups. THE case this exists for.
    it("separates the two spec groups when there are no loadouts", function()
        local primary   = liftKey(env(1486, nil, 2, 1))
        local secondary = liftKey(env(1486, nil, 2, 2))
        assert.are_not.equals(primary(), secondary(),
            "Primary and Secondary must not share one set of binds")
        assert.equals("specgroup:1", primary())
        assert.equals("specgroup:2", secondary())
    end)

    -- Retail with no loadout yet must keep its existing key, or saved binds are
    -- orphaned under a new one.
    it("keeps the old key on a single-group client with no loadout", function()
        local key = liftKey(env(70, nil, 1, 1))
        assert.equals("nil", key(), "unchanged for retail characters without a loadout")
    end)

    -- A group of 1 or 2 must never be mistaken for a config id of 1 or 2.
    it("namespaces the group so it cannot collide with a config id", function()
        local group = liftKey(env(1486, nil, 2, 2))
        local config = liftKey(env(70, 2, 1, 1))
        assert.are_not.equals(group(), config())
        assert.equals("2", config())
    end)

    it("falls back safely when the APIs are missing", function()
        local key = liftKey({ GSE = { GetCurrentSpecID = function() return 1486 end } })
        assert.equals("nil", key())
    end)
end)

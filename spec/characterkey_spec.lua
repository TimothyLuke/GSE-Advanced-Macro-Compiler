---@diagnostic disable: undefined-global

-- Which key a character's macro bucket lives under.
--
-- It used to be built from the character's name and realm, four different
-- ways, and they disagreed. On WoW Forever UnitFullName's second return is the
-- SURNAME ("Bob", "Geldoff"), not the realm, so Forever characters were filed
-- as "Bob-Geldoff". On retail, UnitFullName strips spaces from the realm and
-- GetRealmName does not, and the Mod used both, so a character on a realm with
-- a space in its name had two buckets. It is now the player GUID.
--
-- The migration is the part that must not lose anything: the first call after
-- login folds every legacy-keyed bucket for this character into the GUID one.
--
-- Lifted from the shipped file. .gitattributes marks *.lua eol=crlf; normalise
-- on read (see CLAUDE.md).
local function lift(e)
    local fh = assert(io.open("GSE/API/CharacterFunctions.lua", "r"))
    local src = fh:read("*a")
    fh:close()
    src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local block = src:match("(%-%-%- The one identity.-\nfunction GSE%.CharacterMacroBucket%(create%).-\nend\n)")
    assert(block, "character key block not found in CharacterFunctions.lua")
    -- 5.1's load takes a reader function, so loadstring there and load's env
    -- argument on 5.2+. Either way the chunk sees `e` as its globals, which is
    -- what lets the test read back the GSEMacros the code assigns.
    local chunk
    if loadstring then
        chunk = assert(loadstring(block))
        setfenv(chunk, e)
    else
        chunk = assert(load(block, "characterkey", "t", e))
    end
    chunk()
    return e
end

-- A character: GUID (nil = not yet available), UnitFullName's two returns,
-- GetRealmName, and GetUnitName(true).
local function env(guid, first, second, realmName, fullName, macros)
    local e = {
        GSE = {},
        GSEMacros = macros,
        UnitGUID = function() return guid end,
        UnitFullName = function() return first, second end,
        GetRealmName = function() return realmName end,
        GetUnitName = function() return fullName end,
        UnitName = function() return first end,
    }
    e.GSE.isEmpty = function(v) return v == nil or v == "" end
    -- The code reaches macros through GSE.Store, never the global by name.
    -- Answer from e.GSEMacros so each test reads back what the code wrote;
    -- like the real store, the root is created on demand.
    e.GSE.Store = function(kind)
        assert(kind == "macro", "unexpected store kind " .. tostring(kind))
        if type(e.GSEMacros) ~= "table" then e.GSEMacros = {} end
        return e.GSEMacros
    end
    return setmetatable(e, { __index = _G })
end

local GUID = "Player-4618-00936B90"

describe("CharacterKey", function()
    it("is the player GUID", function()
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", {}))
        assert.equals(GUID, e.GSE.CharacterKey())
    end)

    it("is nil before the player unit exists", function()
        local e = lift(env(nil, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", {}))
        assert.is_nil(e.GSE.CharacterKey())
    end)
end)

describe("CharacterLabel", function()
    -- Forever's name is two words; UnitFullName splits it, GetUnitName does not.
    it("keeps Forever's full two-part name", function()
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", {}))
        assert.equals("Bob Geldoff-Classic Beta PvE", e.GSE.CharacterLabel())
    end)
end)

describe("CharacterMacroBucketKey migration", function()
    it("moves the Forever 'Bob-Geldoff' bucket under the GUID", function()
        local macros = { ["Bob-Geldoff"] = { Pull = { text = "/cast Charge" } } }
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", macros))
        assert.equals(GUID, e.GSE.CharacterMacroBucketKey())
        assert.equals("/cast Charge", e.GSEMacros[GUID].Pull.text)
        assert.is_nil(e.GSEMacros["Bob-Geldoff"])
    end)

    it("recovers the bucket an earlier Forever build wrote", function()
        local macros = { ["Bob Geldoff-Classic Beta PvE"] = { Old = { text = "/say hi" } } }
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", macros))
        e.GSE.CharacterMacroBucketKey()
        assert.equals("/say hi", e.GSEMacros[GUID].Old.text)
        assert.is_nil(e.GSEMacros["Bob Geldoff-Classic Beta PvE"])
    end)

    -- Retail, realm with a space: the Events.lua recipe kept it, the storage
    -- recipe stripped it, so one character had two buckets. Both fold in.
    it("merges both spellings of a spaced realm", function()
        local macros = {
            ["Tim-ArgentDawn"]  = { A = { text = "a" } },
            ["Tim-Argent Dawn"] = { B = { text = "b" } },
        }
        local e = lift(env(GUID, "Tim", "ArgentDawn", "Argent Dawn", "Tim", macros))
        e.GSE.CharacterMacroBucketKey()
        assert.equals("a", e.GSEMacros[GUID].A.text)
        assert.equals("b", e.GSEMacros[GUID].B.text)
        assert.is_nil(e.GSEMacros["Tim-ArgentDawn"])
        assert.is_nil(e.GSEMacros["Tim-Argent Dawn"])
    end)

    it("never overwrites what is already under the GUID", function()
        local macros = {
            [GUID] = { Pull = { text = "current" } },
            ["Bob-Geldoff"] = { Pull = { text = "stale" }, Extra = { text = "kept" } },
        }
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", macros))
        e.GSE.CharacterMacroBucketKey()
        assert.equals("current", e.GSEMacros[GUID].Pull.text)
        assert.equals("kept", e.GSEMacros[GUID].Extra.text)
    end)

    -- Macro names can contain hyphens: an account macro called "Bob-Geldoff"
    -- is a macro, not a bucket, and must survive.
    it("leaves a real macro that happens to share a legacy key", function()
        local macros = { ["Bob-Geldoff"] = { text = "/cast Fireball", value = 3 } }
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", macros))
        e.GSE.CharacterMacroBucketKey()
        assert.equals("/cast Fireball", e.GSEMacros["Bob-Geldoff"].text)
        assert.is_nil(e.GSEMacros[GUID])
    end)

    it("leaves other characters' buckets alone", function()
        local macros = { ["Bernie-Classic Beta PvE"] = { X = { text = "x" } } }
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", macros))
        e.GSE.CharacterMacroBucketKey()
        assert.equals("x", e.GSEMacros["Bernie-Classic Beta PvE"].X.text)
    end)

    -- Too early for a GUID: answer with the key storage always used, so a
    -- write lands where the post-login call will find and migrate it.
    it("falls back to the legacy key before login, without migrating", function()
        local macros = { ["Tim-ArgentDawn"] = { A = { text = "a" } } }
        local e = lift(env(nil, "Tim", "ArgentDawn", "Argent Dawn", "Tim", macros))
        assert.equals("Tim-ArgentDawn", e.GSE.CharacterMacroBucketKey())
        assert.equals("a", e.GSEMacros["Tim-ArgentDawn"].A.text)
    end)
end)

describe("CharacterMacroBucket", function()
    it("returns nil without create when there is nothing", function()
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", {}))
        assert.is_nil(e.GSE.CharacterMacroBucket(false))
    end)

    it("creates the GUID bucket on request", function()
        local e = lift(env(GUID, "Bob", "Geldoff", "Classic Beta PvE", "Bob Geldoff", nil))
        local b = e.GSE.CharacterMacroBucket(true)
        assert.equals(b, e.GSEMacros[GUID])
    end)
end)

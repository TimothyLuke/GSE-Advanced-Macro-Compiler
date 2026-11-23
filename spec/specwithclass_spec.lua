
-- Seven entries in Statics.SpecIDList are disambiguated as "Frost - Mage",
-- because Frost is both a Mage and a Death Knight spec. Either half comes from
-- the client's CONTENT, and a client can have the specialisation API while
-- having no such spec or class to report.
--
-- That is WoW Forever: Retail's API surface on vanilla content, so GameMode is
-- honestly 12, the retail branch is entered, GetSpecializationInfoByID(64) has
-- no Frost Mage to return, and concatenating the nil threw
-- "attempt to concatenate a nil value" as soon as a sequence was created.
--
-- Lifted from the shipped file, so changing it there fails this.
-- .gitattributes marks *.lua eol=crlf; normalise on read (see CLAUDE.md).
local function liftSpecWithClass(specName, className)
    local fh = assert(io.open("GSE/API/Statics.lua", "r"), "cannot open GSE/API/Statics.lua")
    local src = fh:read("*a")
    fh:close()
    src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local block = src:match("(local function specWithClass.-return className and %(specName %.%. \" %- \" %.%. className%) or specName)")
    assert(block, "specWithClass not found in Statics.lua -- did it get rewritten?")
    local compile = loadstring or load
    -- Inject the two lookups the helper closes over.
    local chunk = assert(compile(
        "local determineSpecializationName, determineClassName = ...\n"
        .. block .. "\nend\nreturn specWithClass"))
    return chunk(function() return specName end, function() return className end)
end

-- A spec's name is the client's own. Mists was given the spec's class id in
-- its place -- a number -- and the editor's spec list, which sorts by name,
-- failed on it, so a sequence's Configuration page stopped before its rows
-- (Larry, 2026-11-23).
describe("determineSpecializationName", function()
    local function lift(api)
        local fh = assert(io.open("GSE/API/Statics.lua", "r"), "cannot open GSE/API/Statics.lua")
        local src = fh:read("*a")
        fh:close()
        src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
        local body = assert(src:match("\nlocal function determineSpecializationName%(specID%)\n(.-)\nend\n"),
            "determineSpecializationName not found in Statics.lua")
        local compile = loadstring or load
        local chunk = assert(compile("local GetSpecializationInfoByID = ...\nreturn function(specID)\n" .. body .. "\nend"))
        return chunk(api)
    end

    it("is the client's name for the spec", function()
        local f = lift(function(id) return id, "Arcane", "", 135932, "DAMAGER", "MAGE" end)
        assert.equals("Arcane", f(62))
    end)

    it("is nil for a spec the client does not have, and on a client with no specs", function()
        assert.is_nil(lift(function() return nil end)(577))
        assert.is_nil(lift(function() return 577, "" end)(577))
        assert.is_nil(lift(nil)(62))
    end)

    it("is never the spec's class id", function()
        local fh = assert(io.open("GSE/API/Statics.lua", "r"))
        local src = fh:read("*a"):gsub("\r\n", "\n")
        fh:close()
        local body = assert(src:match("\nlocal function determineSpecializationName%(specID%)\n(.-)\nend\n"))
        assert.is_nil(body:find("SpecIDClassList", 1, true))
        assert.is_nil(body:find("GameMode", 1, true))
    end)

    -- What the number did: the editor sorts a class's specs by name.
    it("gives names the editor's spec list can sort", function()
        local fh = assert(io.open("GSE/API/StringFunctions.lua", "r"))
        local src = fh:read("*a"):gsub("\r\n", "\n")
        fh:close()
        local body = assert(src:match("\nfunction GSE%.AlphabeticalTableSortAlgorithm%(a, b%)\n(.-)\nend\n\nfunction "))
        local sort = assert((loadstring or load)("return function(a, b)\n" .. body .. "\nend"))()
        local f = lift(function(id) return id, ({ [62] = "Arcane", [63] = "Fire", [64] = "Frost" })[id] end)
        local specs = { { name = f(64) }, { name = f(62) }, { name = f(63) } }
        table.sort(specs, function(a, b) return sort(a.name, b.name) end)
        assert.are.same({ "Arcane", "Fire", "Frost" }, { specs[1].name, specs[2].name, specs[3].name })
        assert.is_false(pcall(table.sort, { { name = 8 }, { name = 8 }, { name = "8 - Mage" } },
            function(a, b) return sort(a.name, b.name) end), "the class id as a name fails the sort")
    end)
end)

describe("specWithClass", function()
    it("joins spec and class when the client has both", function()
        local f = liftSpecWithClass("Frost", "Mage")
        assert.equals("Frost - Mage", f(64, 8))
    end)

    -- Forever: the API exists, the content does not.
    it("returns nil when the client has no such spec", function()
        local f = liftSpecWithClass(nil, "Mage")
        assert.is_nil(f(64, 8), "no spec means no entry, not a concatenation error")
    end)

    -- Death Knight on vanilla content: C_CreatureInfo has no class 6.
    it("falls back to the bare spec name when the class is absent", function()
        local f = liftSpecWithClass("Frost", nil)
        assert.equals("Frost", f(251, 6))
    end)

    it("returns nil when the client has neither", function()
        local f = liftSpecWithClass(nil, nil)
        assert.is_nil(f(64, 8))
    end)

    -- The point of returning nil rather than a placeholder: the key is never
    -- set, so a client without specialisations ends up with the class-only
    -- list it should have, instead of rows reading "- Mage" or "Unknown".
    it("never yields a half-built label", function()
        local f = liftSpecWithClass(nil, "Mage")
        local out = f(64, 8)
        assert.is_nil(out)
        f = liftSpecWithClass("Frost", nil)
        assert.equals("Frost", f(64, 8))
    end)
end)

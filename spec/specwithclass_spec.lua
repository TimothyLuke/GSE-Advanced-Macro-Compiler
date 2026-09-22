---@diagnostic disable: undefined-global

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

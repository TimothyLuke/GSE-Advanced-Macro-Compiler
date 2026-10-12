---@diagnostic disable: undefined-global

-- Which talent loadout keybindings and action bar overrides are layered by,
-- on top of the spec's: a saved loadout's config id (Retail), else none.
--
-- A dual-spec client's Primary and Secondary are its specs, not loadouts
-- (GSE.CurrentSpecKey; profiles_spec covers them), so they never reach this.
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
        "local GSE, C_ClassTalents = ...\n"
        .. block .. "\nreturn GSE.GetBindingLoadoutKey"))
    return chunk(env.GSE, env.C_ClassTalents)
end

local function env(specID, savedConfigID)
    return {
        GSE = { GetCurrentSpecID = function() return specID end },
        C_ClassTalents = { GetLastSelectedSavedConfigID = function() return savedConfigID end },
    }
end

describe("GetBindingLoadoutKey", function()
    it("uses the saved loadout id when there is one", function()
        assert.equals("12345", liftKey(env(70, 12345))())
    end)

    -- Retail with no loadout keeps its existing key, or saved binds are
    -- orphaned under a new one; every other client has none.
    it("is the old key with no saved loadout", function()
        assert.equals("nil", liftKey(env(70, nil))())
        assert.equals("nil", liftKey(env(1486, nil))(), "Forever: no loadouts, its spec groups are specs")
    end)

    it("falls back safely when the APIs are missing", function()
        local key = liftKey({ GSE = { GetCurrentSpecID = function() return 1486 end } })
        assert.equals("nil", key())
    end)
end)

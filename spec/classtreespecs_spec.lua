---@diagnostic disable: undefined-global

-- Mapping a one-spec-per-class client's talent TREES onto retail spec ids.
--
-- WoW Forever reports one specialisation per class (Paladin = 1486, Mage =
-- 1482) with Holy/Protection/Retribution exposed as trait groups. Storing the
-- retail id means GetClassIDforSpec, the spec filters, the website and the
-- Companion all keep working with no change — nothing new crosses the wire.
--
-- Lifted from the shipped file so the table and the shape gate are the real
-- ones. .gitattributes marks *.lua eol=crlf; normalise on read (see CLAUDE.md).
local function liftDerive(env)
    local fh = assert(io.open("GSE/API/Statics.lua", "r"), "cannot open GSE/API/Statics.lua")
    local src = fh:read("*a")
    fh:close()
    src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local block = src:match("(local CLASS_TREE_SPECIDS.-\n    return found, classOf, iconOf\nend)")
    assert(block, "CLASS_TREE_SPECIDS / deriveClassTreeSpecs not found in Statics.lua")
    local compile = loadstring or load
    local chunk = assert(compile(
        "local GetSpecializationInfoForClassID, GetNumSpecializationsForClassID,"
        .. " C_ClassTalents, C_Traits, determineClassName, C_SpecializationInfo = ...\n"
        .. block .. "\nreturn deriveClassTreeSpecs, CLASS_TREE_SPECIDS"))
    return chunk(env.GetSpecializationInfoForClassID, env.GetNumSpecializationsForClassID,
                 env.C_ClassTalents, env.C_Traits, env.determineClassName, env.C_SpecializationInfo)
end

-- A client with one spec per class and `groupNames` trees on it.
local function client(specCount, groupNames, classSpec)
    return {
        GetNumSpecializationsForClassID = function() return specCount end,
        GetSpecializationInfoForClassID = function() return classSpec or 1486, "Paladin" end,
        C_ClassTalents = { GetTraitTreeForSpec = function() return 1100 end },
        C_Traits = {
            GetGroupDisplayInfoByTreeID = function()
                local out = {}
                for i, name in ipairs(groupNames) do
                    out[i] = { treeID = 1100, orderIndex = i - 1, groupID = 11000 + i, displayName = name, icon = 135900 + i }
                end
                return out
            end,
        },
        determineClassName = function() return "Paladin" end,
    }
end

describe("class tree specs", function()
    it("maps the three trees onto retail spec ids by orderIndex", function()
        local derive = liftDerive(client(1, {"Holy", "Protection", "Retribution"}))
        local out = derive()
        assert.equals("table", type(out))
        assert.equals("Holy", out[65])
        assert.equals("Protection", out[66])
        assert.equals("Retribution", out[70])
    end)

    -- So GetCurrentSpecID's answer is a real entry, not an unknown number.
    it("registers the class-level spec too", function()
        local derive = liftDerive(client(1, {"Holy", "Protection", "Retribution"}))
        assert.equals("Paladin", derive()[1486])
    end)

    -- Its class too: no table of ours knows the client's class-level ids.
    it("reports the class of each class-level spec", function()
        local env = client(1, {"A", "B", "C"})
        env.GetSpecializationInfoForClassID = function(classID) return 1480 + classID, "Class" .. classID end
        local _, classOf = liftDerive(env)()
        assert.equals(2, classOf[1482])
        assert.equals(8, classOf[1488])
    end)

    -- And each tree's icon (Forever's Holy reports 135920): the client has no
    -- spec record for a retail id to read one from.
    it("reports each tree's icon by the retail id", function()
        local _, _, iconOf = liftDerive(client(1, {"Holy", "Protection", "Retribution"}))()
        assert.equals(135901, iconOf[65])
        assert.equals(135903, iconOf[70])
    end)

    -- The client's own name wins, so the era-correct label appears by itself:
    -- Forever says "Combat", retail calls the same slot Outlaw.
    it("keeps the client's label rather than the retail one", function()
        local env = client(1, {"Assassination", "Combat", "Subtlety"})
        env.GetSpecializationInfoForClassID = function() return 1483, "Rogue" end
        local derive = liftDerive(env)
        local out = derive()
        assert.equals("Combat", out[260], "260 is Outlaw on retail and Combat here")
        assert.equals("Assassination", out[259])
        assert.equals("Subtlety", out[261])
    end)

    -- THE retail safety gate. A retail class has 3-4 specs and its groups are
    -- hero talents; mapping those onto spec ids would rename every spec in the
    -- editor. The shape test must refuse.
    it("refuses a client with more than one spec per class", function()
        -- THREE groups on purpose: if this passed only because the group count
        -- was wrong it would not be testing the spec-count gate at all, and
        -- weakening that gate would go unnoticed.
        local derive = liftDerive(client(3, {"Holy", "Protection", "Retribution"}))
        assert.is_nil(derive(), "retail must be left completely alone")
    end)

    it("refuses a tree whose group count does not match the table", function()
        local derive = liftDerive(client(1, {"Holy", "Protection"}))
        assert.is_nil(derive(), "two groups is not the three this table describes")
        derive = liftDerive(client(1, {"A", "B", "C", "D"}))
        assert.is_nil(derive())
    end)

    -- Forever 1.60.1.70338: the spec count moved into C_SpecializationInfo and
    -- the global went, which registered nothing for any class.
    it("reads the spec count from C_SpecializationInfo when the global is gone", function()
        local env = client(1, {"Holy", "Protection", "Retribution"})
        env.C_SpecializationInfo = { GetNumSpecializationsForClassID = env.GetNumSpecializationsForClassID }
        env.GetNumSpecializationsForClassID = nil
        local found = liftDerive(env)()
        assert.equals("Paladin", found and found[1486])
        assert.equals("Protection", found[66])
    end)

    it("survives a client missing the APIs entirely", function()
        local derive = liftDerive({})
        assert.is_nil(derive())
    end)

    it("covers the nine classes that exist on such a client", function()
        local _, tbl = liftDerive(client(1, {"a", "b", "c"}))
        local n = 0
        for classID, specIDs in pairs(tbl) do
            n = n + 1
            assert.equals(3, #specIDs, "class " .. classID .. " needs three trees")
        end
        assert.equals(9, n, "no Death Knight, Monk, Demon Hunter or Evoker")
        -- Guardian (104) split out of Feral later and has no tree here.
        assert.equals(103, tbl[11][2])
        assert.is_nil((function() for _, v in ipairs(tbl[11]) do if v == 104 then return true end end end)())
    end)
end)

-- A retail spec id on a client that does not know it (WoW Forever): its class
-- comes from GSE.SpecIDClassList, or a Protection Paladin sequence is filed as
-- Global the moment Protection is picked.
describe("GSE.GetClassIDforSpec on a client without retail specs", function()
    it("finds the class from the spec table", function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/CharacterFunctions")
        local savedMode, savedInfo = GSE.GameMode, _G.GetSpecializationInfoByID
        GSE.GameMode = 12
        _G.GetSpecializationInfoByID = function() return nil end
        local ok, err = pcall(function()
            assert.equals(2, GSE.GetClassIDforSpec(66))
            assert.equals(4, GSE.GetClassIDforSpec(260))
            assert.equals(0, GSE.GetClassIDforSpec(999999))
        end)
        GSE.GameMode, _G.GetSpecializationInfoByID = savedMode, savedInfo
        if not ok then error(err, 0) end
    end)
end)

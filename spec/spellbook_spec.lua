---@diagnostic disable: undefined-global
-- getPlayerSpells backs the Patron Tab spell list. It has to work on two
-- different spellbook APIs, and the interesting case is the client that has
-- SOME of the modern one: TBC Classic Anniversary and MoP Classic expose
-- C_SpellBook without all of its functions, so a `C_SpellBook and ...` guard
-- passes there and then finds nothing.
--
-- The function is a local inside GSE_QoL/QoL.lua, and the file needs addon
-- frame plumbing to load whole, so it is sliced out and run against mocked
-- globals — which is also the only way to exercise a Classic client from here.
local function loadGetPlayerSpells(env)
  local f = io.open("GSE_QoL/QoL.lua")
  local src = f:read("*a")
  f:close()
  local s = src:find("local function getPlayerSpells")
  local e = src:find("\nend", src:find("table%.sort%(spells%)"))
  local chunk = src:sub(s, e + 3) .. "\nreturn getPlayerSpells\n"
  env.table, env.ipairs, env.pairs = table, ipairs, pairs
  return assert(load(chunk, "getPlayerSpells", "t", env))()
end

describe(
  "Patron Tab spell list",
  function()
    it(
      "lists castable spells on Retail, skipping passives and off-spec",
      function()
        local spells = loadGetPlayerSpells({
          C_SpellBook = {
            GetNumSpellBookSkillLines = function() return 3 end,
            GetSpellBookSkillLineInfo = function(tab)
              if tab == 2 then return {itemIndexOffset = 0, numSpellBookItems = 3} end
              return {itemIndexOffset = 10, numSpellBookItems = 1}
            end,
            GetSpellBookItemInfo = function(i)
              local rows = {
                [1] = {name = "Shred"},
                [2] = {name = "Thick Hide", isPassive = true},
                [3] = {name = "Rake"},
                [11] = {name = "Chaos Bolt", isOffSpec = true},
              }
              return rows[i]
            end,
          },
        })()
        assert.same({"Rake", "Shred"}, spells)
      end
    )

    it(
      "falls back to the Classic tab API when C_SpellBook is absent",
      function()
        local spells = loadGetPlayerSpells({
          GetNumSpellTabs = function() return 2 end,
          GetSpellTabInfo = function() return "General", nil, 0, 4, false, 0 end,
          GetSpellBookItemName = function(i)
            -- Two ranks of the same spell, then a not-yet-learned row.
            return ({"Sinister Strike", "Sinister Strike", "Stealth", "Dual Wield"})[i], "Rank 2"
          end,
          GetSpellBookItemInfo = function(i) return i == 4 and "FUTURESPELL" or "SPELL" end,
          IsPassiveSpell = function() return false end,
          BOOKTYPE_SPELL = "spell",
        })()
        -- Ranks collapse to one name, and the unlearned spell is not offered.
        assert.same({"Sinister Strike", "Stealth"}, spells)
      end
    )

    it(
      "uses the Classic path when C_SpellBook exists but is incomplete",
      function()
        local spells = loadGetPlayerSpells({
          C_SpellBook = {FindBaseSpellByID = function() end},   -- no skill-line API
          GetNumSpellTabs = function() return 2 end,
          GetSpellTabInfo = function() return "General", nil, 0, 2, false, 0 end,
          GetSpellBookItemName = function(i) return ({"Frostbolt", "Fireball"})[i] end,
          GetSpellBookItemInfo = function() return "SPELL" end,
          IsPassiveSpell = function() return false end,
          BOOKTYPE_SPELL = "spell",
        })()
        assert.same({"Fireball", "Frostbolt"}, spells)
      end
    )

    it(
      "skips another spec's tab on Classic",
      function()
        local spells = loadGetPlayerSpells({
          GetNumSpellTabs = function() return 3 end,
          GetSpellTabInfo = function(tab)
            if tab == 2 then return "Main", nil, 0, 1, false, 0 end
            return "Other Spec", nil, 5, 1, false, 2
          end,
          GetSpellBookItemName = function(i) return i == 1 and "Mangle" or "Moonfire" end,
          GetSpellBookItemInfo = function() return "SPELL" end,
          IsPassiveSpell = function() return false end,
          BOOKTYPE_SPELL = "spell",
        })()
        assert.same({"Mangle"}, spells)
      end
    )

    it(
      "still lists names on a client with no item-info call",
      function()
        local spells = loadGetPlayerSpells({
          GetNumSpellTabs = function() return 2 end,
          GetSpellTabInfo = function() return "General", nil, 0, 1, false, nil end,
          GetSpellBookItemName = function() return "Corruption" end,
          BOOKTYPE_SPELL = "spell",
        })()
        assert.same({"Corruption"}, spells)
      end
    )

    it(
      "returns an empty list rather than erroring with no spellbook API",
      function()
        assert.same({}, loadGetPlayerSpells({})())
      end
    )
  end
)

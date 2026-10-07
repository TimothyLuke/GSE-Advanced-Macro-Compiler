---@diagnostic disable: undefined-global, lowercase-global
-- Spell ranks on a vanilla-content client running Retail's API (WoW Forever).
--
-- The rules under test (see "Spell ranks" in GSE/API/translator.lua):
--   * storage is always a spell ID -- a written rank stores that rank's ID;
--   * a bare name stays rankless, whatever ID it was stored as;
--   * the block's `Ranks` list is what records that a cast was ranked;
--   * compiling casts the highest KNOWN rank not above the one written, and
--     never climbs past it.
--
-- Run: busted spec/spellranks_spec.lua
describe("Spell ranks", function()
  local Statics

  -- Frostbolt ranks 1-5 and Maul ranks 1-2, each its own spell ID as on
  -- Forever, plus a spell with no ranks.
  local spells = {
    [116] = {name = "Frostbolt", subtext = "Rank 1"},
    [205] = {name = "Frostbolt", subtext = "Rank 2"},
    [837] = {name = "Frostbolt", subtext = "Rank 3"},
    [7322] = {name = "Frostbolt", subtext = "Rank 4"},
    [8406] = {name = "Frostbolt", subtext = "Rank 5"},
    [6807] = {name = "Maul", subtext = "Rank 1"},
    [6808] = {name = "Maul", subtext = "Rank 2"},
    [100] = {name = "Charge"},
    -- A Frostbolt rank whose rank text the client has not loaded yet.
    [9999] = {name = "Frostbolt"},
  }
  local order = {116, 205, 837, 7322, 8406, 6807, 6808, 100}
  local known

  local function learn(...)
    for _, id in ipairs({...}) do known[id] = true end
    -- What SPELLS_CHANGED does, via GSE.ReloadSequences.
    GSE.ClearTranslateStringCache()
  end

  local function infoFor(id)
    local s = spells[id]
    return s and {name = s.name, spellID = id, iconID = id}
  end

  local function compile(text, ranks)
    return GSE.UnEscapeString(GSE.WithSpellRanks(ranks, GSE.TranslateString, text, Statics.TranslatorMode.String))
  end

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/Native")
    require("../GSE/API/translator")
    Statics = GSE.Static

    -- Through _G: busted sandboxes this file's globals, and the addon code
    -- reads the real ones.
    _G.Enum = _G.Enum or {}
    Enum.SpellBookSpellBank = {Player = 0}
    Enum.SpellBookItemType = {Spell = 1, FutureSpell = 2}
    -- Forever has no global GetSpellInfo; only C_Spell.
    _G.GetSpellInfo = nil

    _G.C_Spell = {
      -- Retail's shape: no rank field. A name resolves to the highest rank
      -- known; a name with a rank written on it is not understood.
      GetSpellInfo = function(spell)
        if tonumber(spell) then return infoFor(tonumber(spell)) end
        local best
        for _, id in ipairs(order) do
          if spells[id].name == spell and known[id] then best = id end
        end
        return best and infoFor(best)
      end,
      GetSpellSubtext = function(id) return spells[id] and spells[id].subtext end,
    }
    _G.C_SpellBook = {
      GetNumSpellBookSkillLines = function() return 1 end,
      GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #order} end,
      GetSpellBookItemInfo = function(i)
        local id = order[i]
        local s = spells[id]
        return {
          name = s.name,
          spellID = id,
          subName = s.subtext or "",
          itemType = known[id] and Enum.SpellBookItemType.Spell or Enum.SpellBookItemType.FutureSpell,
        }
      end,
      IsSpellKnown = function(id) return known[id] == true end,
    }
  end)

  before_each(function()
    _G.GSESpellCache = {enUS = {}}
    known = {}
    learn(116, 205, 837, 6807, 100)
  end)

  describe("GSE.SplitSpellRank", function()
    it("separates the rank and a druid form qualifier", function()
      assert.are.same({"Maul", 1, "(Rank 1)", "(Bear)"}, {GSE.SplitSpellRank("Maul(Rank 1)(Bear)")})
    end)

    it("keeps a bracket without a number as part of the name", function()
      assert.is_nil(GSE.SplitSpellRank("Faerie Fire (Feral)"))
      assert.are.equal("Faerie Fire (Feral)", (GSE.SplitSpellRank("Faerie Fire (Feral)(Rank 2)")))
    end)

    it("reads a rank in another language by its number", function()
      assert.are.equal(3, select(2, GSE.SplitSpellRank("Frostblitz(Rang 3)")))
    end)
  end)

  describe("storing", function()
    it("stores a written rank as that rank's own spell ID", function()
      assert.are.equal(205, GSE.GetSpellId("Frostbolt(Rank 2)", Statics.TranslatorMode.ID))
    end)

    it("records which casts were written with a rank", function()
      assert.are.same({205}, GSE.GetRankedSpellIDs("Frostbolt(Rank 2)"))
      assert.is_nil(GSE.GetRankedSpellIDs("Frostbolt"))
      assert.are.same(
        {116, "6807(Bear)"},
        GSE.GetRankedSpellIDs("/cast [mod:alt] Frostbolt(Rank 1); Fireball\n/castsequence reset=5 Frostbolt, !Maul(Rank 1)(Bear)")
      )
    end)

    it("stores a ranked /cast line as plain IDs", function()
      local stored = GSE.UnEscapeString(GSE.TranslateString("/cast [combat] Frostbolt(Rank 2)", Statics.TranslatorMode.ID))
      assert.is_not_nil(stored:find("] 205$"))
    end)

    it("does not fold a rank's ID into another rank on re-store", function()
      assert.are.equal(837, GSE.GetSpellId(837, Statics.TranslatorMode.ID))
    end)

    it("keeps a rank this client could not read yet, while the cast is still there", function()
      -- 9999 is a rank whose data has not loaded: it was shown without a rank,
      -- so the re-saved text has none.
      assert.are.same({9999}, GSE.GetRankedSpellIDs("/cast Frostbolt", {9999}, "/cast 9999"))
      -- Removed from the block: gone.
      assert.is_nil(GSE.GetRankedSpellIDs("/cast Fireball", {9999}, "/cast 133"))
      -- A readable rank shown without one was removed by the user: gone.
      assert.is_nil(GSE.GetRankedSpellIDs("/cast Frostbolt", {205}, "/cast 205"))
    end)

    it("leaves a rank nobody can resolve as written, rather than store the wrong one", function()
      assert.is_nil(GSE.GetSpellId("Frostbolt(Rank 9)", Statics.TranslatorMode.ID))
    end)
  end)

  describe("showing in the editor", function()
    it("shows a ranked cast with the rank that was asked for, even one not yet known", function()
      assert.are.equal("Frostbolt(Rank 4)", GSE.WithSpellRanks({7322}, GSE.GetSpellId, 7322, Statics.TranslatorMode.Current))
    end)

    it("shows the same ID without a rank when the block did not ask for one", function()
      assert.are.equal("Frostbolt", GSE.GetSpellId(837, Statics.TranslatorMode.Current))
    end)

    it("keeps a druid form qualifier through the round trip", function()
      assert.are.equal("Maul(Rank 1)(Bear)", GSE.WithSpellRanks({"6807(Bear)"}, GSE.GetSpellId, 6807, Statics.TranslatorMode.Current))
    end)
  end)

  describe("compiling macro text", function()
    it("never adds a rank to a cast written without one", function()
      assert.are.equal("/cast Frostbolt", compile("/cast 837"))
    end)

    it("casts the rank written when it is known", function()
      assert.are.equal("/cast Frostbolt(Rank 2)", compile("/cast 205", {205}))
    end)

    it("steps up one rank at a time and stops at the rank written", function()
      local ranks = {8406}
      assert.are.equal("/cast Frostbolt(Rank 3)", compile("/cast 8406", ranks))
      learn(7322)
      assert.are.equal("/cast Frostbolt(Rank 4)", compile("/cast 8406", ranks))
      learn(8406)
      assert.are.equal("/cast Frostbolt(Rank 5)", compile("/cast 8406", ranks))
      assert.are.equal("/cast Frostbolt(Rank 4)", compile("/cast 7322", {7322}))
    end)

    it("only ranks the casts the block marked", function()
      assert.are.equal(
        "/castsequence Frostbolt(Rank 1), Frostbolt",
        compile("/castsequence 116, 837", {116})
      )
    end)

    it("caps a form ability and keeps its form", function()
      assert.are.equal("/cast Maul(Rank 1)(Bear)", compile("/cast 6808", {"6808(Bear)"}))
    end)

    it("answers spell info for compiled ranked text, for icons and tooltips", function()
      assert.are.equal("Frostbolt", GSE.GetSpellInfo("Frostbolt(Rank 2)").name)
    end)
  end)

  describe("GSE.GetSpellRankText", function()
    it("names the rank of a ranked spell and nothing for one without ranks", function()
      assert.are.equal("Rank 1", GSE.GetSpellRankText(116))
      assert.is_nil(GSE.GetSpellRankText(100))
    end)
  end)

  describe("rank text arriving late", function()
    it("asks for it once and recompiles when it lands", function()
      local requested = 0
      _G.C_Spell.RequestLoadSpellData = function() requested = requested + 1 end
      local shown = GSE.WithSpellRanks({9999}, GSE.GetSpellId, 9999, Statics.TranslatorMode.Current)
      GSE.WithSpellRanks({9999}, GSE.GetSpellId, 9999, Statics.TranslatorMode.Current)
      assert.are.equal(1, requested)
      -- Shown without a rank until then -- the case the save guard covers.
      assert.are.equal("Frostbolt", shown)
      assert.is_true(GSE.SpellRankDataLoaded(9999))
      assert.is_false(GSE.SpellRankDataLoaded(9999))
      assert.is_false(GSE.SpellRankDataLoaded(116))
      _G.C_Spell.RequestLoadSpellData = nil
    end)
  end)

  describe("GSE.GetCastableSpell (Spell blocks)", function()
    it("casts the highest known rank for a spell written without one", function()
      assert.are.equal(837, GSE.GetCastableSpell(116))
      learn(7322)
      assert.are.equal(7322, GSE.GetCastableSpell(116))
    end)

    it("caps a ranked spell at the highest known rank below it", function()
      assert.are.equal(837, GSE.GetCastableSpell(8406, {8406}))
      learn(7322, 8406)
      assert.are.equal(205, GSE.GetCastableSpell(205, {205}))
    end)

    it("leaves a spell without ranks as it was", function()
      assert.are.equal(100, GSE.GetCastableSpell(100))
    end)
  end)
end)

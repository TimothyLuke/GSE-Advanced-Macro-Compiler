-- A spell nothing resolves is not a known spell.
--
-- The editor colours macro text in Current mode. GetSpellId used to hand the
-- typed name back as the answer in every mode but ID, so "Immolation" on a
-- warlock who knows Immolate -- or any typo -- was coloured as a known spell.
--
-- Run: busted spec/unknownspell_spec.lua   /   lua5.1 spec/run51.lua
describe("Unknown spells", function()
  local Statics

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/Native")
    require("../GSE/API/translator")
    Statics = GSE.Static
  end)

  before_each(function()
    -- The client knows Immolate only.
    _G.GetSpellInfo = nil
    _G.C_Spell = {
      GetSpellInfo = function(s)
        if s == "Immolate" or s == 348 then return {name = "Immolate", spellID = 348, iconID = 1} end
        return nil
      end,
    }
    _G.GSESpellCache = {enUS = {}}
    GSE.ClearTranslateStringCache()
  end)

  it("is not found in any mode", function()
    for _, mode in ipairs({Statics.TranslatorMode.Current, Statics.TranslatorMode.String, Statics.TranslatorMode.ID}) do
      assert.is_nil(GSE.GetSpellId("Immolation", mode), mode)
      local found, out = GSE.TranslateSpell("Immolation", mode)
      assert.is_false(found, mode)
      assert.is_truthy(out:find(GSEOptions.UNKNOWN, 1, true), mode .. " coloured as unknown")
    end
  end)

  it("a known spell still is", function()
    local found, out = GSE.TranslateSpell("Immolate", Statics.TranslatorMode.Current)
    assert.is_true(found)
    assert.is_truthy(out:find(GSEOptions.KEYWORD, 1, true))
  end)

  it("/cast shows an unknown spell in the unknown colour, keeping its conditionals", function()
    local out = GSE.TranslateString("/cast [noharm][dead] Immolation", Statics.TranslatorMode.Current)
    assert.is_truthy(out:find(GSEOptions.UNKNOWN .. "Immolation", 1, true))
    assert.is_truthy(out:find("[noharm][dead]", 1, true))
  end)

  it("a name from another locale's cache is still found", function()
    GSESpellCache.deDE = {["Feuerbrand"] = 348}
    assert.are.equal("Feuerbrand", GSE.GetSpellId("Feuerbrand", Statics.TranslatorMode.Current))
    assert.are.equal(348, GSE.GetSpellId("Feuerbrand", Statics.TranslatorMode.ID))
  end)

  it("a Spell block with an unknown name still casts it as typed", function()
    assert.are.equal("Immolation", GSE.GetCastableSpell("Immolation"))
  end)
end)

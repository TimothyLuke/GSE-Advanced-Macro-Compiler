---@diagnostic disable: undefined-global
-- One reader for "what does this macro clause name": conditionals and a
-- castsequence reset= go through GSE.GetConditionalsFromString, then the "!"
-- toggle guard. The icon resolvers in Storage and the Editor and the
-- suppressed-error option preview all read through GSE.GetMacroClauseTarget.
describe(
  "Macro clause target",
  function()
    local savedGetSpellInfo, savedSecureParse
    local known = {
      ["Serpent Sting"] = {name = "Serpent Sting", iconID = 1},
      ["Arcane Shot"] = {name = "Arcane Shot", iconID = 2},
      ["Frostbolt"] = {name = "Frostbolt", iconID = 3},
    }

    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
        require("../GSE/API/Native")
        require("../GSE/API/CharacterFunctions")
        require("../GSE/API/Storage")
        require("../GSE/API/translator")
        savedGetSpellInfo = GSE.GetSpellInfo
        GSE.GetSpellInfo = function(spell) return known[spell] end
        -- SafeSecureCmdOptionParse bails without the global; the preview
        -- path under test never calls it.
        savedSecureParse = _G.SecureCmdOptionParse
        _G.SecureCmdOptionParse = _G.SecureCmdOptionParse or function() end
        -- WoW's global string aliases.
        _G.gmatch = _G.gmatch or string.gmatch
        _G.strlower = _G.strlower or string.lower
      end
    )

    teardown(
      function()
        GSE.GetSpellInfo = savedGetSpellInfo
        _G.SecureCmdOptionParse = savedSecureParse
      end
    )

    it(
      "drops conditionals, reset= and the ! guard",
      function()
        assert.equals("Maul", GSE.GetMacroClauseTarget("[mod:alt] reset=combat/target !Maul"))
        assert.equals("Serpent Sting", GSE.GetMacroClauseTarget("reset=5 Serpent Sting"))
        assert.equals("Arcane Shot", GSE.GetMacroClauseTarget("  Arcane Shot "))
        assert.equals("Frostbolt", GSE.GetMacroClauseTarget("[@focus,harm][] Frostbolt"))
      end
    )

    it(
      "is empty for a clause naming nothing",
      function()
        assert.equals("", GSE.GetMacroClauseTarget("[combat]"))
        assert.equals("", GSE.GetMacroClauseTarget(""))
        assert.equals("", GSE.GetMacroClauseTarget(nil))
      end
    )

    it(
      "is what the suppressed-error option preview returns",
      function()
        assert.equals("Frostbolt", GSE.SafeSecureCmdOptionParse("[mod] reset=combat !Frostbolt; Fireball", true))
        assert.equals("Fireball", GSE.SafeSecureCmdOptionParse("[mod]; Fireball", true))
      end
    )

    it(
      "reads every castsequence element past a reset= clause",
      function()
        local spells = GSE.GetSpellsFromString("/castsequence reset=combat/target Serpent Sting, !Arcane Shot")
        assert.equals(2, #spells)
        assert.equals("Serpent Sting", spells[1].name)
        assert.equals("Arcane Shot", spells[2].name)
      end
    )

    it(
      "moves past a castsequence line naming no known spell",
      function()
        local spells = GSE.GetSpellsFromString("/castsequence reset=5 Nope, Nothing\n/castsequence Frostbolt")
        assert.equals(1, #spells)
        assert.equals("Frostbolt", spells[1].name)
      end
    )
  end
)

describe('API Translator', function()
  setup (function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/Localization/enUS")
    require("../GSE/Localization/enUSHash")
    require("../GSE/Localization/enUSSHADOW")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/translator")
  end)

  it("Passes through non spell commands ", function()
    assert.are.equal("/targetenemy", GSE.TranslateString("/targetenemy", "enUS", "enUS"))

  end)

  it("checks that mods are retained", function()
    local originalstring = '/castsequence [talent:7/3] reset=combat Glacial Advance, [talent:6/1] Frostscythe, Frost Strike, Frost Strike, [talent:6/1] Frostscythe, [talent:6/1] Frostscythe'
    local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

  it("checks that ctrl:mods are retained", function()
    local originalstring = '/castsequence [mod:ctrl] !Rip,Ferocious Bite,Ferocious Bite,Ferocious Bite; [nomod] Rake, shred, shred, shred, shred'
    local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

  -- it("checks that ctrl:mods are retained and reset=target is kept after the mod", function()
  --   local originalstring = '/castsequence [mod:ctrl] reset=target !Rip,Ferocious Bite'
  --   local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
  --   local finalstring = GSE.UnEscapeString(newstring)
  --   assert.are.equal(originalstring, finalstring)
  -- end)
  it("checks that [talent:123] choices are kept within a cast sequence]", function()
    local originalstring = '/castsequence reset=combat Frost Strike, Obliterate, [talent:6/1] Frostscythe'
    local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

end)

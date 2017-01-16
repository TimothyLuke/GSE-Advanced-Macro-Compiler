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
    local originalstring = '/castsequence reset=combat [talent:7/3] Glacial Advance, [talent:6/1] Frostscythe, Frost Strike, Frost Strike, [talent:6/1] Frostscythe, [talent:6/1] Frostscythe'
    local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

end)

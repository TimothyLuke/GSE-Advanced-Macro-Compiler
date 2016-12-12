describe('API Translator', function()
  setup (function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/Localization/enUS")
    require("../GSE/Localization/enUSHash")
    require("../GSE/Localization/enUSSHADOW")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/translator")
  end)

  it("Adds a sequence to the Library", function()
    local Sequences = {}
    Sequences["Test1"] = {
      SpecID = 11,
      Author="UnitTest",
      MacroVersions = {
        {
          StepFunction = "Sequential",
          "/cast Spell1",
          "/cast Spell2",
        },
        {
          StepFunction = "Priority",
          "/cast Spell1",
          "/cast Spell2",
        }

      }
    }
    GSE.OOCAddSequenceToCollection("Test1", Sequences["Test1"], 11)
    assert.are.equal(11, GSELibrary[11]["Test1"].SpecID)

  end)

end)

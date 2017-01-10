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

    L = GSE.L
    L["No Help Information Available"] = "No Help Information Available"
    L["A sequence collision has occured.  Extra versions of this macro have been loaded.  Manage the sequence to determine how to use them "] = "A sequence collision has occured.  Extra versions of this macro have been loaded.  Manage the sequence to determine how to use them "
    L[" was imported with the following errors."] = " was imported with the following errors."

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

  it("Tests that old macros are converted to new macro format", function ()
    local Sequences = {}

    Sequences['DB_Prot_ST'] = {
      author="LNPV",
      specID=66,
      helpTxt = 'Talents: 2332223',
      icon=236264,
      PreMacro=[[
/targetenemy [noharm][dead]
]],
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      PostMacro=[[
/cast Avenging Wrath
/startattack
      ]],
      }
    local newmacro =   GSE.ConvertLegacySequence(Sequences['DB_Prot_ST'])
    assert.are.equal(66, newmacro.SpecID)
    assert.falsy(newmacro.specID)
    assert.falsy(newmacro["MacroVersions"][1].specID)
    assert.falsy(newmacro["MacroVersions"][1].PreMacro)
  end)

  it("Tests that collisions work properly and that a macro imported twice is added as two MacroVersions", function ()
    local Sequences = {}

    Sequences['DB_Prot_ST'] = {
      author="LNPV",
      specID=66,
      helpTxt = 'Talents: 2332223',
      icon=236264,
      PreMacro=[[
/targetenemy [noharm][dead]
]],
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      PostMacro=[[
/cast Avenging Wrath
/startattack
      ]],
      }
    local newmacro =   GSE.ConvertLegacySequence(Sequences['DB_Prot_ST'])
    local newmacro2 =   GSE.ConvertLegacySequence(Sequences['DB_Prot_ST'])

    GSE.OOCAddSequenceToCollection('DB_Prot_ST', newmacro, 11)
    GSE.OOCAddSequenceToCollection('DB_Prot_ST', newmacro2, 11)
    print("about to start asserts.")
    assert.are.equal(66, newmacro.SpecID)
    print("about to start GSELibrary asserts.")
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].PreMacro)
    assert.are.equal("Sequential", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].StepFunction)
    assert.are.equal("/targetenemy [noharm][dead]", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2]["KeyPress"][1])
    assert.are.equal("Talents: 2332223", GSELibrary[11]['DB_Prot_ST'].Help)
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].helpTxt)
  end)

  it("Test importing from the old GSE1", function()
    local GSMasterOptions = {}
    GSMasterOptions.SequenceLibrary = {}
    GSMasterOptions.SequenceLibrary["DB_Prot_ST"] = {}
    GSMasterOptions.SequenceLibrary["DB_Prot_ST"][1] = {
      author="LNPV",
      specID=66,
      helpTxt = 'Talents: 2332223',
      icon=236264,
      PreMacro=[[
/targetenemy [noharm][dead]
]],
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      PostMacro=[[
/cast Avenging Wrath
/startattack
      ]],
    }
    GSMasterOptions.SequenceLibrary["DB_Prot_ST"][2] = {
      author="LNPV",
      specID=66,
      helpTxt = 'Talents: 2332223',
      icon=236264,
      PreMacro=[[
/targetenemy [noharm][dead]
]],
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      PostMacro=[[
/cast Avenging Wrath
/startattack
      ]],
    }

    print ("Initial import tests")
    GSE.OOCAddSequenceToCollection('DB_Prot_ST',  GSE.ConvertLegacySequence(GSMasterOptions.SequenceLibrary["DB_Prot_ST"][1]), 11)
    GSE.OOCAddSequenceToCollection('DB_Prot_ST',  GSE.ConvertLegacySequence(GSMasterOptions.SequenceLibrary["DB_Prot_ST"][2]), 11)
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].PreMacro)
    assert.are.equal("Sequential", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].StepFunction)
    assert.are.equal("/targetenemy [noharm][dead]", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2]["KeyPress"][1])
    assert.are.equal("Talents: 2332223", GSELibrary[11]['DB_Prot_ST'].Help)
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].helpTxt)
    print("Check for Regression")
    assert.are.equal("LNPV", GSMasterOptions.SequenceLibrary["DB_Prot_ST"][1].author)
    assert.are.equal("LNPV", GSMasterOptions.SequenceLibrary["DB_Prot_ST"][2].author)
    assert.are.equal("/cast Avenger's Shield", GSMasterOptions.SequenceLibrary["DB_Prot_ST"][1][1])
    assert.are.equal("/cast Avenger's Shield", GSMasterOptions.SequenceLibrary["DB_Prot_ST"][2][1])
    assert.are.equal("/startattack", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2]["KeyRelease"][2])
    assert.are.equal(236264, GSELibrary[11]['DB_Prot_ST'].Icon)
  end)


  it("Test it handles spaces in the sequence name", function()
    local Sequences = {}
    Sequences["Test 1"] = {
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
    GSE.OOCAddSequenceToCollection("Test 1", Sequences["Test 1"], 11)
    assert.are.equal(11, GSELibrary[11]["Test_1"].SpecID)

  end)


  it("Tests that cloned sequences are possible", function()
    local MacroVersions = {}
    MacroVersions = {
      {
        StepFunction = "Sequential",
        "/cast Spell1",
        "/cast Spell2",
      },
    }


    MacroVersions[2] = GSE.CloneSequence(MacroVersions[1])

    assert.are.equal("Sequential",   MacroVersions[2].StepFunction)
    assert.are.equal("Sequential",   MacroVersions[1].StepFunction)

    Macroversions[2].StepFunction = "Priority"
    assert.are.equal("Priority",   MacroVersions[2].StepFunction)
    assert.are.equal("Sequential",   MacroVersions[1].StepFunction)

    assert.are.same(MacroVersions[1][1], MacroVersions[1][2])
  end)
end)

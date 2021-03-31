describe('API Storage', function()
  setup (function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/translator")

    L = GSE.L
    L["No Help Information Available"] = "No Help Information Available"
    L["A new version of %s has been added."] = "A new version of %s has been added."
    L[" was imported with the following errors."] = " was imported with the following errors."
    L["This Sequence was exported from GSE %s."] = "This Sequence was exported from GSE %s."
    L["Extra Macro Versions of %s has been added."] = "Extra Macro Versions of %s has been added."
    L["No changes were made to "] = "No changes were made to "
    L[" was updated to new version."] = " was updated to new version."
    L["Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."] = "Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."
    L["WARNING ONLY"] = "WARNING ONLY"

    Statics = GSE.Static

    -- OOC Queue Overrides
    function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
      GSE.OOCPerformMergeAction(action, classid, sequenceName, newSequence)
    end

    function GSE.AddSequenceToCollection(sequenceName, sequence, classid)
      print("SequenceName: " .. sequenceName)
      print("classid: " .. classid)
      print("Sequence: ".. GSE.Dump(sequence))

      GSE.OOCAddSequenceToCollection(sequenceName, sequence, classid)
    end

    function GetAddOnMetadata(name, ver)
      return "2000"
    end


  end)

  it("Adds a sequence to the Library", function()
    print("XXXXXX Begin - Adds a sequence to the Library")

    GSE.Library[11] = {}

    testseq = {
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

    GSE.AddSequenceToCollection("TEST1", testseq, 11)
    print (GSE.Dump(GSE.Library))
    assert.are.equal(11, GSE.Library[11]["TEST1"].SpecID)

    print("XXXXXX END - Adds a sequence to the Library")

  end)

  it("Tests that old macros are converted to new macro format", function ()
    local Sequences = {}

    Sequences['DB_PROT_ST'] = {
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
    local newmacro =   GSE.ConvertLegacySequence(Sequences['DB_PROT_ST'])
    assert.are.equal(66, newmacro.SpecID)
    assert.falsy(newmacro.specID)
    assert.falsy(newmacro["MacroVersions"][1].specID)
    assert.falsy(newmacro["MacroVersions"][1].PreMacro)
  end)



  it("Test a troublesome import from the old GSE1", function()

    local GSMasterOptions = {}
    GSMasterOptions.SequenceLibrary = {}
    GSMasterOptions.SequenceLibrary["Rogue_SubST"] = {
      {
        "/cast [combat] Shadow Blades", -- [1]
        "/cast [combat] Symbols of Death", -- [2]
        "/cast [combat] Shadowstrike", -- [3]
        "/cast [combat] Shadowstrike", -- [4]
        "/castsequence  reset=combat  Backstab, Nightblade, Shadow Dance, Backstab, Eviscerate, Backstab, Backstab, Backstab, Nightblade, Backstab, Backstab", -- [5]
        "/castsequence [mod:shift] Vanish, Symbols of Death, Shadowstrike", -- [6]
        ["source"] = "Local",
        ["author"] = "Aaralak@Nagrand",
        ["icon"] = "Ability_Stealth",
        ["version"] = 1,
        ["PreMacro"] = "/cast [@focus, exists, nodead] Tricks of the Trade\n/cast [noform:1, nocombat] Stealth\n/castsequence [form:1, nocombat] reset=combat  Symbols of Death, Shadowstrike\n",
        ["helpTxt"] = "Talents: 1233111",
        ["specID"] = 261,
        ["lang"] = "enUS",
        ["PostMacro"] = "",
      }, -- [1]
    }

    local retseq = GSE.ConvertLegacySequence(GSMasterOptions.SequenceLibrary["Rogue_SubST"][1])
    assert.falsy(retseq.specID)
    assert.falsy(retseq.PreMacro)
    assert.are.equal(retseq.SpecID, GSMasterOptions.SequenceLibrary["Rogue_SubST"][1].specID)


  end)


  it("Test it handles spaces in the sequence name", function()

    GSE.Library[11] = {}

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
    assert.are.equal(11, GSE.Library[11]["TEST_1"].SpecID)

  end)

  it("Test it handles commas in the sequence name", function()

    GSE.Library[11] = {}
    local Sequences = {}
    Sequences["Test,1"] = {
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
    GSE.OOCAddSequenceToCollection("Test,1", Sequences["Test,1"], 11)
    assert.are.equal(11, GSE.Library[11]["TEST_1"].SpecID)

  end)

  it ("tests that clonesequence works", function ()
    local sequence1 = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    local clonedsequence = GSE.CloneSequence(sequence1)


    assert.falsy(clonedsequence.MacroVersions[1].Trinket2)
    assert.True(clonedsequence.MacroVersions[1].Trinket1)

  end)

  it("tests that sequences are merging ", function ()


    GSE.Library[2] = {}
    GSE.Library[2]["SAMPLE"] = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    local TestMacro = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    GSE.PerformMergeAction("MERGE", 2, "SAMPLE", TestMacro)
    assert.are.equal("Priority", GSE.Library[2]["SAMPLE"].MacroVersions[2].StepFunction)
  end)

  it("tests that sequences are replacing ", function ()


    GSE.Library[2] = {}
    GSE.Library[2]["SAMPLE"] = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    local TestMacro = {
      Author="REPLACED",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    GSE.PerformMergeAction("REPLACE", 2, "SAMPLE", TestMacro)
    assert.are.equal("REPLACED", GSE.Library[2]["SAMPLE"].Author)
  end)

  it("tests that sequences are being inserted if they dont exist via a replace ", function ()


    GSE.Library[2] = {}

    local TestMacro = {
      Author="REPLACED",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    GSE.PerformMergeAction("REPLACE", 2, "SAMPLE", TestMacro)
    assert.are.equal("REPLACED", GSE.Library[2]["SAMPLE"].Author)
  end)

  it("tests that sequences are ignoring ", function ()

    GSE.Library[2] = {}
    GSE.Library[2]["SAMPLE"] = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }

    local TestMacro = {
      Author="REPLACED",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          Trinket1 = true,
          Trinket2 = false,
          KeyPress={
            "/targetenemy [noharm][dead]",
          },
          PreMacro = {
            "/say hello"
          },
          "/cast Avenger's Shield",
          "/cast Judgment",
          "/cast Blessed Hammer",
          "/cast Hammer of the Righteous",
          "/cast Consecration",
          "/cast Light of the Protector",
          "/cast Shield of the Righteous",
          "/cast Blinding Light",
          KeyRelease={
            "/cast Avenging Wrath",
            "/cast Eye of Tyr",
            "/startattack",
          },
        }
      }
    }


    GSE.PerformMergeAction("IGNORE", 2, "SAMPLE", TestMacro)
    assert.are.equal("LNPV", GSE.Library[2]["SAMPLE"].Author)
  end)
end)

it("tests that sequences are being inserted if they dont exist via a replace ", function ()


  GSE.Library[2] = {}

  local TestMacro = {
    Author="REPLACED",
    SpecID=66,
    Talents = 'Talents: 3332123',
    Icon=236264,
    Default=1,
    MacroVersions = {
      [1] = {
        StepFunction = "Priority",
        Trinket1 = true,
        Trinket2 = false,
        KeyPress={
          "/targetenemy [noharm][dead]",
        },
        PreMacro = {
          "/say hello"
        },
        "/cast Avenger's Shield",
        "/cast Judgment",
        "/cast Blessed Hammer",
        "/cast Hammer of the Righteous",
        "/cast Consecration",
        "/cast Light of the Protector",
        "/cast Shield of the Righteous",
        "/cast Blinding Light",
        KeyRelease={
          "/cast Avenging Wrath",
          "/cast Eye of Tyr",
          "/startattack",
        },
      }
    }
  }

  GSE.AddSequenceToCollection("SAMPLE", TestMacro, 2)
  assert.are.equal("REPLACED", GSE.Library[2]["SAMPLE"].Author)
end)

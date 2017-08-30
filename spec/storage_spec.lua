describe('API Storage', function()
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
    L["A new version of %s has been added."] = "A new version of %s has been added."
    L[" was imported with the following errors."] = " was imported with the following errors."
    L["This Sequence was exported from GSE %s."] = "This Sequence was exported from GSE %s."

    Statics = GSE.Static

    function GetAddOnMetadata(name, ver)
      return "2000"
    end
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

    Sequences['DB_Prot_ST'][7] = "/say Hello"

    local newmacro2 =   GSE.ConvertLegacySequence(Sequences['DB_Prot_ST'])

    GSE.OOCAddSequenceToCollection('DB_Prot_ST', newmacro, 11)
    GSE.OOCAddSequenceToCollection('DB_Prot_ST', newmacro2, 11)
    print("about to start asserts.")
    assert.are.equal(66, newmacro.SpecID)
    print("about to start GSELibrary asserts.")
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].specID)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].specID)
    assert.are.same({}, GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].specID)
    assert.are.same({}, GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].PreMacro)
    assert.are.equal("Sequential", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].StepFunction)
    assert.are.equal("/targetenemy [noharm][dead]", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2]["KeyPress"][1])
    assert.are.equal("Talents: 2332223", GSELibrary[11]['DB_Prot_ST'].Help)
    assert.falsy(GSELibrary[11]['DB_Prot_ST'].helpTxt)
  end)

  it("Tests that the same macro is not imported twice", function ()
    local Sequences = {}

    Sequence = {
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
    local newmacro =   GSE.ConvertLegacySequence(Sequence)
    local newmacro2 =   GSE.ConvertLegacySequence(Sequence)

    print("Testing that the same macro isnt inserted twice")
    assert.True(GSE.CompareSequence(newmacro,newmacro2))
    print("Adding First")
    GSE.OOCAddSequenceToCollection('DB_Prot', newmacro, 11)
    print ("Complete - added first")
    GSE.OOCAddSequenceToCollection('DB_Prot', newmacro2, 11)
    print("added second - about to start asserts.")
    assert.are.equal(66, newmacro.SpecID)
    print("about to start GSELibrary asserts.")
    assert.falsy(GSELibrary[11]['DB_Prot'].specID)
    assert.falsy(GSELibrary[11]['DB_Prot']["MacroVersions"][1].specID)
    assert.are.same({}, GSELibrary[11]['DB_Prot']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot']["MacroVersions"][2])
    assert.are.equal("Sequential", GSELibrary[11]['DB_Prot']["MacroVersions"][1].StepFunction)
    assert.are.equal("Talents: 2332223", GSELibrary[11]['DB_Prot'].Help)
    assert.falsy(GSELibrary[11]['DB_Prot'].helpTxt)
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
    assert.are.same({}, GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].specID)
    assert.are.same({}, GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2].PreMacro)
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

  it("Test it handles spaces in the sequence name", function()
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


    MacroVersions[2] = GSE.CloneMacroVersion(MacroVersions[1])

    assert.are.equal("Sequential",   MacroVersions[2].StepFunction)
    assert.are.equal("Sequential",   MacroVersions[1].StepFunction)

    MacroVersions[2].StepFunction = "Priority"
    assert.are.equal("Priority",   MacroVersions[2].StepFunction)
    assert.are.equal("Sequential",   MacroVersions[1].StepFunction)

    assert.are.same(MacroVersions[1][1], MacroVersions[2][1])
  end)

  it("Tests that StepFunctions are correctly returned", function()

    assert.are.equal(Statics.PriorityImplementation, GSE.PrepareStepFunction(Statics.Priority, false))
    assert.are.equal("step = step % #macros + 1", GSE.PrepareStepFunction(Statics.Sequential, false))
    assert.are.equal(Statics.LoopPriorityImplementation, GSE.PrepareStepFunction(Statics.Priority, true))
    assert.are.equal(Statics.LoopSequentialImplementation, GSE.PrepareStepFunction(Statics.Sequential, true))
    assert.are.equal(Statics.LoopSequentialImplementation, GSE.PrepareStepFunction(nil, true))
    assert.are.equal('step = step % #macros + 1', GSE.PrepareStepFunction(nil,  false))
    assert.are.equal(Statics.LoopSequentialImplementation, GSE.PrepareStepFunction(nil, true))

  end)

  it("Tests that Priority StepFunctions are correctly returned", function()
    local sequence1 = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
          KeyPress={
            "/targetenemy [noharm][dead]",
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

    local sequence = GSE.CloneMacroVersion(sequence1.MacroVersions[1])
    tempseq = GSE.CloneMacroVersion(sequence)
    local executionseq = {}

    if not GSE.isEmpty(tempseq.PreMacro) then
      pmcount = table.getn(tempseq.PreMacro) + 1
      for k,v in ipairs(tempseq.PreMacro) do
        table.insert(executionseq, v)
      end

    end

    for k,v in ipairs(tempseq) do
      table.insert(executionseq, v)
    end


    if not GSE.isEmpty(tempseq.PostMacro) then
      for k,v in ipairs(tempseq.PostMacro) do
        table.insert(executionseq, v)
      end

    end

    assert.are.equal([[local step = self:GetAttribute('step')
local loopstart = self:GetAttribute('loopstart') or 1
local loopstop = self:GetAttribute('loopstop') or #macros
local loopiter = self:GetAttribute('loopiter') or 1
local looplimit = self:GetAttribute('looplimit') or 0
loopstart = tonumber(loopstart)
loopstop = tonumber(loopstop)
loopiter = tonumber(loopiter)
looplimit = tonumber(looplimit)
step = tonumber(step)
self:SetAttribute('macrotext', self:GetAttribute('KeyPress') .. "\n" .. macros[step] .. "\n" .. self:GetAttribute('KeyRelease'))
  limit = limit or 1
  if step == limit then
    limit = limit % #macros + 1
    step = 1
  else
    step = step % #macros + 1
  end

if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:SetAttribute('loopiter', loopiter)
self:CallMethod('UpdateIcon')
]], string.format(Statics.OnClick, GSE.PrepareStepFunction(sequence.StepFunction,  GSE.IsLoopSequence(sequence))))

  end)

  it("Tests that LoopPriority StepFunctions via just PreMacro work", function()

    local sequence1 = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
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

    local sequence = GSE.CloneMacroVersion(sequence1.MacroVersions[1])
    tempseq = GSE.CloneMacroVersion(sequence)
    local executionseq = {}

    if not GSE.isEmpty(tempseq.PreMacro) then
      pmcount = table.getn(tempseq.PreMacro) + 1
      for k,v in ipairs(tempseq.PreMacro) do
        table.insert(executionseq, v)
      end

    end

    for k,v in ipairs(tempseq) do
      table.insert(executionseq, v)
    end


    if not GSE.isEmpty(tempseq.PostMacro) then
      for k,v in ipairs(tempseq.PostMacro) do
        table.insert(executionseq, v)
      end

    end

    assert.are.equal([[local step = self:GetAttribute('step')
local loopstart = self:GetAttribute('loopstart') or 1
local loopstop = self:GetAttribute('loopstop') or #macros
local loopiter = self:GetAttribute('loopiter') or 1
local looplimit = self:GetAttribute('looplimit') or 0
loopstart = tonumber(loopstart)
loopstop = tonumber(loopstop)
loopiter = tonumber(loopiter)
looplimit = tonumber(looplimit)
step = tonumber(step)
self:SetAttribute('macrotext', self:GetAttribute('KeyPress') .. "\n" .. macros[step] .. "\n" .. self:GetAttribute('KeyRelease'))
  if step < loopstart then
    step = step + 1

  elseif step > loopstop and loopstop == #macros then
    if step >= #macros then
      loopiter = 1
      step = loopstart
      if looplimit > 0 then
        step = 1
        limit = loopstart
      end
    else
      step = step + 1
    end
  elseif step == loopstop then
    if looplimit > 0 then
      if loopiter >= looplimit then
        if loopstop >= #macros then
          step = 1
          limit = loopstart
        else
          step = step + 1
          loopiter = 1
        end
      else
        step = loopstart
        loopiter = loopiter + 1
      end
    else
      step = loopstart
    end
  elseif step >= #macros then
    loopiter = 1
    step = loopstart
    if looplimit > 0 then
      step = 1
      limit = loopstart
    end
  else
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if limit == loopiter then
        loopiter = loopiter + 1
      end
    else
      step = step + 1
    end
  end

if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:SetAttribute('loopiter', loopiter)
self:CallMethod('UpdateIcon')
]], string.format(Statics.OnClick, GSE.PrepareStepFunction(sequence.StepFunction,  GSE.IsLoopSequence(sequence))))


  end)

  it ("tests that Compare Sequence works", function()
    local seqa  = {
      Author="EnixLHQ",
      SpecID=252,
      Help="Run at 80ms",
      Talents="2,2,1,?,?,3,3",
      Helplinlk="https://wowlazymacros.com/forums/topic/unholy-soul-reaper/",
      Icon='INV_MISC_QUESTIONMARK',
      Default=1,
      MacroVersions = {
        [1] = {
          KeyPress={
            "/targetenemy [noharm][dead]",
            "/use [mod:alt] Death Strike",
            "/castsequence  reset=combat  Outbreak, Festering Strike, Festering Strike, null",
          },
          "/cast Scourge Strike",
          "/castsequence Dark Transformation, Outbreak",
          "/castsequence  reset=target  Festering Strike, Festering Strike",
          "/castsequence  reset=target  Festering Strike, Festering Strike, Apocalypse",
          "/castsequence  reset=target  Festering Strike, Festering Strike, Soul Reaper, Outbreak",
          "/cast Summon Gargoyle",
          "/cast Death Coil",
          "/cast Scourge Strike",
        }
      }
    }

  local seqb = {
      Author="EnixLHQ",
      SpecID=252,
      Help="Run at 80ms",
      Talents="2,2,1,?,?,3,3",
      Helplinlk="https://wowlazymacros.com/forums/topic/unholy-soul-reaper/",
      Icon='INV_MISC_QUESTIONMARK',
      Default=1,
      MacroVersions = {
        [1] = {
          KeyPress={
            "/targetenemy [noharm][dead]",
            "/cast [nopet,nomod] Raise Dead",
            "/use [mod:alt] Death Strike",
            "/castsequence  reset=combat  Outbreak, Festering Strike, Festering Strike, null",
          },
          "/cast Scourge Strike",
          "/castsequence Dark Transformation, Outbreak",
          "/castsequence  reset=target  Festering Strike, Festering Strike",
          "/castsequence  reset=target  Festering Strike, Festering Strike, Apocalypse",
          "/castsequence  reset=target  Festering Strike, Festering Strike, Soul Reaper, Outbreak",
          "/cast Summon Gargoyle",
          "/cast Death Coil",
          "/cast Scourge Strike",
        }
      }
    }

    assert.are.equal(false, GSE.CompareSequence(seqa.MacroVersions[1], seqb.MacroVersions[1]))
  end)


  it ("tests that macros are exported correctly", function()
    local sequence1 = {
      Author="LNPV",
      SpecID=66,
      Talents = 'Talents: 3332123',
      Icon=236264,
      Default=1,
      MacroVersions = {
        [1] = {
          StepFunction = "Priority",
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
    local expectedval = [[Sequences['|cFFFFFF00prot|r'] = {
|cffcc7777-- This Sequence was exported from GSE 2.0.00.|r
  Author="|cFF00D1FFLNPV|r",
  SpecID=|cffffaa0066|r,
  Talents = "|cffccaa88Talents: 3332123|r",
  Default=1,
  Icon=|cffcc7777236264|r,
  MacroVersions = {
    [1] = {
      StepFunction = |cffccaa88"Priority"|r,
      KeyPress={
        "|cffddaaff/targetenemy|r [noharm][dead]",
      },
      PreMacro={
        "|cffddaaff/say|r hello",
      },
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddAvenger's Shield|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddJudgment|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddBlessed Hammer|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddHammer of the Righteous|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddConsecration|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddLight of the Protector|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddShield of the Righteous|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddBlinding Light|r|r",
      KeyRelease={
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddAvenging Wrath|r|r",
        "|cffddaaff/cast|r |cff88bbdd|cff88bbddEye of Tyr|r|r",
        "/startattack",
      },
    },
  },
}
]]
    returnval = GSE.ExportSequence(sequence1, "prot")
    print(returnval)
    assert.are.equal(expectedval, returnval)

  end)

  it ("tests that comments are removed from CloneMacroVersion", function()
    local TestMacro = {
      StepFunction = "Priority",
      KeyPress={
        "-- KeyPress Comment",
        "/targetenemy [noharm][dead]",
      },
      PreMacro = {
        "-- Pre Macro Comment",
        "/say hello"
      },
      "-- Sequence Comment",
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Hammer of the Righteous",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      "/cast Blinding Light",
      KeyRelease={
        "-- KeyRelease Comment",
        "/cast Avenging Wrath",
        "/cast Eye of Tyr",
        "/startattack",
      },
      PostMacro = {
        "-- Post Macro Comment",
        "/say hello"
      },

    }

    local returnmacro = GSE.CloneMacroVersion(TestMacro)
    assert.are_not.equals(table.getn(TestMacro.PreMacro), table.getn(returnmacro.PreMacro))
    assert.are_not.equals(table.getn(TestMacro.PostMacro), table.getn(returnmacro.PostMacro))
    assert.are_not.equals(table.getn(TestMacro.KeyPress), table.getn(returnmacro.KeyPress))
    assert.are_not.equals(table.getn(TestMacro.KeyRelease), table.getn(returnmacro.KeyRelease))
    for k,v in ipairs(returnmacro) do
      GSE.PrintDebugMessage(string.format("%s", v), "Test CloneMacroVersion")
    end
    assert.are_not.equals(table.getn(TestMacro), table.getn(returnmacro))

  end)

  it ("handles malformed GSE macros without breaking the mod.", function()
    local GSELibrary = {}
    GSELibrary[0] = {}
    GSELibrary[0]["911ST"] = {
      ["Talents"] = "?,?,?,?,?,?,?",
      ["Default"] = 1,
      ["Author"] = "Unknown Author",
      ["MacroVersions"] = {
        {
          {
            "/cast [@mouseover,help,nodead] Ironbark", -- [1]
            "/cast [@mouseover,help,nodead] Swiftmend", -- [2]
            "/cast [@mouseover,help,nodead] Rejuvenation", -- [3]
            "/cast [@mouseover,help,nodead] Regrowth", -- [4]
            "/cast [@mouseover,dead] Rebirth", -- [5]
            ["source"] = "Local",
            ["author"] = "XXXXXX",
            ["PostMacro"] = "/cast [@mouseover] Rejuvenation\n/cast [@player,combat] Barkskin\n",
            ["version"] = 3,
            ["lang"] = "enUS",
            ["helpTxt"] = "Talents: 1321233",
            ["specID"] = 105,
            ["PreMacro"] = "",
            ["icon"] = "INV_MISC_QUESTIONMARK",
          }, -- [1]
          ["StepFunction"] = "Sequential",
        }, -- [1]
      },
      ["SpecID"] = 0,
    }
    local result, err = pcall(GSE.CheckSequence,GSELibrary[0]["911ST"]["MacroVersions"][1])
    print(err)
    assert.falsy(result)
  end)

  it ("tests that isloopsequence is returning the correct value", function ()
    local normalprioritysequence = {
      Trinket1=false,
      Trinket2=false,
      Head=false,
      Neck=false,
      Belt=false,
      Ring1=false,
      Ring2=false,
      StepFunction = "Priority",
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      PreMacro={
      },
      "/cast [nochanneling] Elemental Blast",
      "/cast [nochanneling] Lava Burst",
      "/cast [nochanneling] Stormkeeper",
      "/cast [nochanneling] Lightning Bolt",
      PostMacro={
      },
      KeyRelease={
      },
    }

    local loopprioritysequence = {
      Trinket1=false,
      Trinket2=false,
      Head=false,
      Neck=false,
      Belt=false,
      Ring1=false,
      Ring2=false,
      StepFunction = "Priority",
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      PreMacro={
        "/cast [nochanneling] Elemental Blast",
      },
      "/cast [nochanneling] Lava Burst",
      "/cast [nochanneling] Stormkeeper",
      "/cast [nochanneling] Lightning Bolt",
      PostMacro={
      },
      KeyRelease={
      },
    }

    assert.falsy(GSE.IsLoopSequence(normalprioritysequence))
    assert.True(GSE.IsLoopSequence(loopprioritysequence))

  end)

  it ("tests that clonesequence works", function ()
    local normalprioritysequence = {
      Trinket1=true,
      Trinket2=false,
      Head=false,
      Neck=false,
      Belt=false,
      Ring1=false,
      Ring2=false,
      StepFunction = "Priority",
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      PreMacro={
      },
      "/cast [nochanneling] Elemental Blast",
      "/cast [nochanneling] Lava Burst",
      "/cast [nochanneling] Stormkeeper",
      "/cast [nochanneling] Lightning Bolt",
      PostMacro={
      },
      KeyRelease={
      },
    }

    local clonedsequence = GSE.CloneSequence(normalprioritysequence)
    assert.falsy(clonedsequence.Trinket2)
    assert.True(clonedsequence.Trinket1)

  end)
end)

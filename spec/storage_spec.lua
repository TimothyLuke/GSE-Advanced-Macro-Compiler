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
    L["A new version of %s has been added."] = "A new version of %s has been added."
    L[" was imported with the following errors."] = " was imported with the following errors."

    Statics = GSE.Static
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
    assert.are.same({}, GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].PreMacro)
    assert.falsy(GSELibrary[11]['DB_Prot_ST']["MacroVersions"][2])
    assert.are.equal("Sequential", GSELibrary[11]['DB_Prot_ST']["MacroVersions"][1].StepFunction)
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

elseif step > loopstop then
  if step >= #macros then
    loopiter = 1
    step = loopstart
    if looplimit > 0 then
      step = 1
    end
  else
    step = step + 1
  end
elseif step == loopstop then
  if looplimit > 0 then
    if loopiter >= looplimit then
      if loopstop >= #macros then
        step = 1
      else
        step = step + 1
      end
      loopiter = 1
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

  seqb = {
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

end)

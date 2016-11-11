local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[6] = {}

local Sequences = Statics.SampleMacros[6]
------------------
----- Death Knight
------------------

Sequences['SAM_FDK2'] = {
  SpecID = 251,
  Author = "Tazkilla",
  Talents = "1,1,1,1,1,3,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [combat] Pillar of Frost",
        "/cast [combat] Anti-Magic Shell"
      },
      StepFunction = "Priority",
      '/castsequence reset=combat Frost Strike',
      '/cast Obliterate',
      '/cast Obliteration',
      '/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Obliterate',
      '/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Howling Blast',
      KeyRelease = {
        "/startattack",
      },
    },
  }
}


Sequences['SAM_DKunholy'] = {
  SpecID = 252,
  Author = "throwryuken",
  Talents = "2,2,2,1,2,1,3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/cast [nochanneling] Raise Dead',
      '/cast [nochanneling] Outbreak',
      '/cast [nochanneling] Dark Transformation',
      '/cast [nochanneling] Festering Strike',
      '/cast [nochanneling] Scourge Strike',
      '/cast [nochanneling] Soul Reaper',
      '/cast [nochanneling] Death Strike',
      '/cast [nochanneling] Summon Gargoyle',
      '/cast [nochanneling] Death Coil',
      KeyRelease = {
        "/startattack",
      },
    },
  }
}


Sequences['SAM_BloodDK'] = {
  StepFunction = "Priority",
  SpecID = 250,
  Author = "Owns",
  Talents = "2,1,1,2,3,3,3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/cast Marrowrend",
      "/castsequence reset=combat Death's Caress, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike",
      '/castsequence reset=combat Blood Boil, Blood Boil, Marrowrend',
      '/castsequence reset=combat Heart Strike, Heart Strike, Heart Strike, Heart Strike, Marrowrend',
      KeyRelease = {
        "/startattack",
      },
    },
  }
}

local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[7] = {}
Statics.SampleMacros[7][1] = [[]]
Statics.SampleMacros[7][2] = [[]]
Statics.SampleMacros[7][3] = [[]]
Statics.SampleMacros[7][4] = [[]]
Statics.SampleMacros[7][5] = [[]]
Statics.SampleMacros[7][6] = [[]]
Statics.SampleMacros[7][7] = [[]]


local Sequences = Statics.SampleMacros[7]

------------------
----- Shaman
------------------
-- Elemental 262

Sequences['SAM_enhsingle'] = {
  SpecID = 263,
  Author = "lloskka",
  Help = "Artifact Order: Doom Winds -> Hammer of Storms -> Gathering Storms -> Wind Strikes -> Wind Surge -> Weapons of the elements -> Elemental Healing -> and all the way to Unleash Doom",
  Talents = "3,1,1,2,1,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/castsequence Boulderfist, Crash Lightning, Stormstrike",
      "/castsequence Boulderfist, Stormstrike, Crash Lightning",
      "/castsequence [nochanneling] Boulderfist, Boulderfist, Crash Lightning",
      "/castsequence Boulderfist, Boulderfist",
      "/cast Lightning Bolt",
      KeyRelease = {
        "/startattack",
        "/cast [combat] Doom Winds",
      },
    }
  }
}

Sequences['SAM_RestoDeeps'] = {
  SpecID = 264,
  Author = "Draik",
  Talents = "3,2,1,1,2,3,3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/cast Chain Lightning',
      '/cast Flame Shock',
      '/cast Earthen Shield Totem',
      '/cast Lava Burst',
      '/cast Lightning Bolt',
      '/cast Lightning Surge Totem',
    }
  }
}

Sequences['SAM_ElemAoE'] = {
  SpecID = 262,
  Author = "Nano",
  Talents = '1,2,1,3,1,1,2',
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/castsequence reset=target/combat Flame Shock, Chain Lightning, Chain Lightning, Chain Lightning',
      '/cast [nochanneling] !Lava Burst',
      KeyRelease = {
        "/cast Elemental Mastery",
        "/cast Blood Fury",
      },
    }
  }
}

Sequences['SAM_Elem'] = {
  SpecID = 262,
  Author = "Nano",
  Talents = '1,2,1,3,1,1,2',
  StepFunction = "Priority",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/castsequence reset=target/combat Flame Shock,Lightning Bolt,Lightning Bolt,Lightning Bolt',
      '/castsequence reset=10 !Earth Shock',
      '/cast [nochanneling] !Lava Burst',
      KeyRelease = {
        "/cast Elemental Mastery",
        "/cast Blood Fury"
      },
    }
  }
}

Sequences['SAM_MC_Surge'] = {
  Author='Maalkomx',
  SpecID=264,
  Talents = '3,3,1,3,3,1,3',
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress={
      },
      "/castsequence [nochanneling]reset=30 Healing Stream Totem",
      "/castsequence [nochanneling,@mouseover,help,nodead]reset=5 !Riptide",
      "/castsequence [nochanneling,@mouseover,help]Healing Surge, Healing Surge, Healing Surge, Healing Surge",
      "/castsequence [nochanneling,@mouseover,help]Healing Surge",
    }
  }
}

Sequences['SAM_MC_Wave'] = {
  Author='Maalkomx',
  SpecID=264,
  Talents = '3,3,1,3,3,1,3',
  Default=1,
  MacroVersions = {
    [1] = {
      "/castsequence [nochanneling]reset=30 Healing Stream Totem",
      "/castsequence [nochanneling,@mouseover,help]reset=5 !Riptide",
      "/castsequence [nochanneling,@mouseover,help]Healing Wave, Healing Wave, Healing Wave, Healing Wave",
      "/castsequence [nochanneling,@mouseover,help]Healing Wave",
    }
  }
}

Sequences['SAM_MC_Chain'] = {
  Author='Maalkomx',
  SpecID=264,
  Talents = '3,3,1,3,3,1,3',
  Default=1,
  MacroVersions = {
    [1] = {
      "/castsequence [nochanneling]reset=30 Healing Stream Totem",
      "/castsequence [nochanneling,@mouseover,help,nodead]reset=5 !Riptide",
      "/castsequence [nochanneling,@mouseover,help]Chain Heal, Chain Heal, Chain Heal, Chain Heal",
      "/castsequence [nochanneling,@mouseover,help]Healing Surge",
    }
  }
}

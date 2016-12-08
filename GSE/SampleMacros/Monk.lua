local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[10] = {}

local Sequences = Statics.SampleMacros[10]
------------------
----- Monk
------------------
-- 268 tank


Sequences['SAM_WW'] = {
  SpecID = 269,
  Author = "John Mets",
  Talents = "Talent are 2 3 2 3 1 2 3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Rising Sun Kick",
      "/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Fists of Fury",
      "/cast Tiger Palm",
      "/cast Touch of Death",
      KeyRelease = {
        "/startattack",
        "/cast [combat] Invoke Xuen, the White Tiger",
        "/cast [combat] Serenity",
        "/cast [combat] Touch of Death",
      },
    }
  }
}

Sequences['SAM_winsingle'] = {
  SpecID = 269,
  Author = "lloskka",
  Talents = "2,3,2,3,2,2,3",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [combat] Touch of Karma"
      },
      '/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm',
      '/castsequence [nochanneling] Tiger Palm, Fists of Fury, Tiger Palm, Blackout Kick',
      '/castsequence [nochanneling] Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick, Fists of Fury, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
      '/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
      KeyRelease = {
        "/startattack",
        "/cast [combat] Invoke Xuen, the White Tiger",
        "/cast [combat] Serenity",
        "/cast [combat] Touch of Death",
      },
    }
  }
}

Sequences['SAM_BrewMaster_ST'] = {
  SpecID = 268,
  Author = "TimothyLuke",
  Talents = "1,1,2,2,3,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/cast Keg Smash",
      "/cast Breath of Fire",
      "/cast Blackout Strike",
      "/cast Rushing Jade Wind",
      "/cast Tiger Palm",
      "/cast Blackout Strike",
      "/cast Blackout Combo",
    }
  }
}

Sequences['SAM_BrewMaster_AoE'] = {
  SpecID = 268,
  Author = "TimothyLuke",
  Talents = "1,1,2,2,3,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/cast Keg Smash",
      "/cast Breath of Fire",
      "/cast Blackout Strike",
      "/cast Chi Burst",
      "/cast Rushing Jade Wind",
      "/cast Tiger Palm",
      "/cast Blackout Strike",
    }
  }
}

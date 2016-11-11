local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[1] = {}

local Sequences = Statics.SampleMacros[1]
------------------
----- Warrior
------------------

Sequences['SAM_Fury1'] = {
  SpecID = 72,
  Author = "Firone - wowlazymacros.com",
  Help = "Single Target",
  Talents = "2,3,3,2,2,2,3",
  Default=1,
  Raid=2,
  Mythic=2,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/cast [combat] Berserker Rage",
        "/cast [combat] Bloodbath",
        "/cast [combat] Avatar",
      },
      [[/cast Execute]],
      [[/castsequence reset=60 Rampage,Battle Cry]],
      [[/cast Rampage]],
      [[/cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar]],
      [[/cast Bloodthirst]],
      [[/cast Raging Blow]],
      [[/cast Furious Slash]],
      KeyRelease = {
        "/startattack",
      },
    }
  }
}

Sequences['SAM_FuryAOE'] = {
  SpecID = 72,
  Author = "Firone - wowlazymacros.com",
  Talents = "2,3,3,2,2,2,3",
  Help = "Fury AOE Macro.  Version 2 has Bladestorm, Dragon Roar, and Battle Cry removed to create better control. Add these to your bars and use manually.",
  Default=1,
  Raid=2,
  Mythic=2,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/cast [combat] Berserker Rage",
      },
      "/cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar",
      "/cast !Whirlwind",
      "/cast !Raging blow",
      "/cast !Bloodthirst",
      KeyRelease = {
        "/cast [combat]Berserker Rage",
      },
    },
    [2] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/cast [modifier:alt]Charge",
        "/cast [combat] Bloodbath",
        "/cast [combat] Avatar",
      },
      '/cast Execute',
      '/castsequence reset=60 Rampage',
      '/cast Rampage',
      '/cast Bloodthirst',
      '/cast Furious Slash',
      KeyRelease = {
        "/startattack",
      },
    },
  }
}


Sequences['SAM_ProtWar'] = {
  SpecID = 73,
  Author = "Suiseiseki - wowlazymacros.com",
  Talents = "1,2,2,3,2,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/castsequence Devastate",
      "/castsequence Shield Slam",
      "/castsequence Revenge",
      "/castsequence Ignore Pain",
      "/castsequence Focused Rage",
      "/castsequence [combat] Thunder Clap, Shield Block",
      "/castsequence [combat] Shockwave",
      "/castsequence Shield Slam",
      '/cast Victory Rush',
      KeyRelease = {
        "/cast [combat] Demoralizing Shout",
        "/cast [combat] Battle Cry",
      },
    }
  }
}

Sequences['SAM_Arms_ST'] = {
  SpecID= 71,
  Author="Hizzi@Nathrezim",
  Talents = "2,1,3,3,2,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/cast [modifier:alt]Charge",
        "/cast [combat] Bloodbath",
        "/cast [combat] Avatar",
        "/cast [combat] Battle Cry",
      },
      "/cast Execute",
      "/cast Rend",
      "/cast Colossus Smash",
      "/cast Overpower",
      "/cast Mortal Strike",
      "/cast Slam",
      KeyRelease={
        "/startattack",
      },
    },
  }
}

Sequences['SAM_Arms_AOE'] = {
  SpecID= 71,
  Author="Hizzi@Nathrezim",
  Talents = "2,1,3,3,2,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/cast [modifier:alt]Charge",
      },
      '/cast !Sweeping Strikes',
      '/cast !Execute',
      '/cast !Cleave',
      '/cast !Whirlwind',
      '/cast !Colossus Smash',
    }
  }
}

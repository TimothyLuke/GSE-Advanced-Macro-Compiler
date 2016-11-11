local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[9] = {}

local Sequences = Statics.SampleMacros[9]
------------------
----- Warlock
------------------
-- Affliction Legion
-- talents 2111212
Sequences['SAM_AFF'] = {
  SpecID = 265,
  Author = "Jimmy",
  Talents = "3,1,3,1,2,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack"
      },
      '/cast [nochanneling] Agony',
      '/cast [nochanneling] Corruption',
      '/cast [nochanneling] Unstable Affliction',
      '/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
      '/cast [nochanneling] Reap Souls',
      KeyRelease = {
        "/startattack",
        "/petattack",
      },
    }
  }
}


Sequences['SAM_AFF2'] = {
  SpecID = 265,
  Author = "Jimmy",
  Talents = "3,1,3,1,2,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
      },
      '/cast [nochanneling] Agony',
      '/cast [nochanneling] Corruption',
      '/cast [nochanneling] Unstable Affliction',
      '/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
      '/cast [nochanneling] Phantom Singularity',
      '/cast [nochanneling] Reap Souls',
      KeyRelease = {
        "/startattack",
        "/petattack",
      },
    }
  }
}


Sequences['SAM_Demon'] = {
  SpecID = 266,
  Author = "Jimmy",
  Talents = "3,2,1,2,2,1,3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
      },
      "/castsequence [nochanneling] Doom,Demonic Empowerment,Demonwrath",
      "/cast [nochanneling] Shadow Bolt",
      "/cast [nochanneling] Shadow Bolt",
      "/cast [nochanneling] Life Tap",
      KeyRelease = {
        "/startattack",
        "/petattack",
      },
    }
  }
}

Sequences['SAM_Destro'] = {
  SpecID = 267,
  Author = "Jimmy",
  Talents = "1,1,1,2,2,1,3",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack"
      },
      "/cast [nochanneling] Conflagrate",
      "/castsequence [nochanneling] Incinerate,Immolate,Incinerate,Immolate,Drain Life",
      KeyRelease = {
        "/startattack",
        "/petattack"
      }
    },
  }
}

Sequences['SAM_DemoSingle'] = {
  Author='twitch.tv/Seydon',
  SpecID=266,
  Talents = '1,1,1,1,2,2,2',
  Icon='Spell_Warlock_Demonbolt',
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress={
        "/cast [nopet] Summon Felguard",
        "/targetenemy [noharm][dead]",
        "/petattack [@target,harm]",
        "/targetenemy [noharm][dead]",
      ]],
      '/castsequence [combat] Call Dreadstalkers, Demonic Empowerment',
      '/castsequence [combat] Summon Doomguard, Demonic Empowerment' ,
      '/castsequence [combat] Grimoire: Felguard, Demonic Empowerment',
      "/castsequence [nochanneling] Doom, Demonbolt, Demonbolt, Demonbolt, Hand of Gul'dan, Demonic Empowerment, Life Tap",
      '/cast [combat] Command Demon',
      KeyRelease={
        "/startattack",
        "/petattack"
      },
    }
  }
}

Sequences['SAM_DemoAoE'] = {
  Author='twitch.tv/Seydon',
  SpecID=266,
  Talents = 'Talents: 1111222',
  Icon="Spell_Warlock_HandofGul'dan",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress={
        "/cast [nopet] Summon Felguard",
        "/targetenemy [noharm][dead]",
        "/petattack [@target,harm]",
      },
      '/castsequence [combat] Call Dreadstalkers, Demonic Empowerment',
      '/castsequence [combat] Summon Infernal, Demonic Empowerment' ,
      '/castsequence [combat] Grimoire: Felguard, Demonic Empowerment',
      "/castsequence [nochanneling] Hand of Gul'dan, Demonic Empowerment, Demonwrath, Demonwrath, Demonwrath, Life Tap",
      '/cast [combat] Command Demon',
      KeyRelease={
        "/startattack",
        "/petattack",
      },
    }
  }
}

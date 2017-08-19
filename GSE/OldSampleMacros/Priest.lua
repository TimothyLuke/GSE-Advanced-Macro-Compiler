local GSE = GSE
local Statics = GSE.Static


local Sequences = Statics.SampleMacros[5]

------------------
----- Priest
------------------


Sequences['SAM_ShadowPriest'] = {
  SpecID = 258,
  Author = "Jimmy",
  Talents = "1,1,1,1,1,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/castsequence [nochanneling] reset=12 Shadow Word: Pain,Vampiric Touch",
      "/castsequence [nochanneling] Mind Spike,Mind Blast,Mind Spike",
      "/cast [nochanneling] Mind Sear",
      KeyRelease = {
        "/startattack"
      },
    }
  }
}

Sequences['SAM_KTN_MouseOver'] = {
  SpecID = 5,
  Author = "KTN",
  Talents = "3,2,1,3,1,3,1",
  Default=1,
  MacroVersions = {
    [1] = {
      '/castsequence [target=mouseover,help,nodead] Power Word: Shield, Plea, Shadow Mend, Shadow Mend',
    }
  }
}

Sequences['SAM_HolyPriesty'] = {
  SpecID = 257,
  Author = "Draik",
  helpTxt = "Talents 3121133",
  Icon = "Ability_Priest_Archangel",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/cast Smite',
      '/cast Holy Fire',
      '/cast Halo',
      '/cast Holy Nova',
      '/cast Holy Word: Chastise',
      KeyRelease = {
        "/startattack",
      },
    }
  }
}

Sequences['SAM_Disc-THeal'] = {
  SpecID = 256,
  Author = "Zole",
  helpTxt = "Heal Target - Talent: 2113121",
  Icon = "Ability_Priest_Atonement",
  Default=1,
  MacroVersions = {
    [1] = {
      '/cast [nochanneling] Power Word: Shield',
      '/castsequence [nochanneling] Plea,Shadow Mend,Shadow Mend',
      '/castsequence [target=targettarget][nochanneling]reset=/target Purge the Wicked,Smite,Smite,Smite,Smite,Smite',
      '/cast [target=targettarget] Penance',
      '/cast [combat][nochanneling] Mindbender',
      '/cast [target=targettarget][nochanneling] Divine Star',
    }
  }
}

Sequences['SAM_Disc-TDPS'] = {
  SpecID = 256,
  Author = "Zole",
  helpTxt = "Dps Target - Talent: 2113121",
  Icon = "Ability_Priest_Atonement",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/cast [nochanneling][@targettarget] Power Word: Shield',
      '/castsequence [nochanneling]reset=/target Purge the Wicked,Smite,Smite,Smite,Smite,Smite',
      '/cast Penance',
      '/cast [combat][nochanneling] Mindbender',
      '/cast [nochanneling] Divine Star',
      KeyRelease = {
        "/startattack",
      },
    }
  }
}

Sequences['SAM_Disc-THealAoe'] = {
  SpecID = 256,
  Author = "Zole",
  helpTxt = "AoE Heal Target - Talent: 2113121",
  Icon = "Ability_Mage_FireStarter",
  Default=1,
  MacroVersions = {
    [1] = {
      '/cast [nochanneling] Power Word: Shield',
      '/castsequence reset=/target[nochanneling] Power Word: Radiance,Plea',
      '/castsequence [target=targettarget][nochanneling]reset=/target Purge the Wicked,Smite,Smite,Smite,Smite,Smite',
      '/cast [target=targettarget] Penance',
      '/cast [combat][nochanneling] Mindbender',
      '/cast [target=targettarget][nochanneling] Divine Star',
    }
  }
}
